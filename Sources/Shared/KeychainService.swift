import Foundation
import LocalAuthentication
import Security
import OSLog

private let logger = Logger(subsystem: "com.clawapi", category: "Keychain")

/// In-memory cache for Keychain reads to avoid repeated macOS permission prompts.
/// Keys are cached after the first successful read and invalidated on save/delete.
private final class KeychainCache: @unchecked Sendable {
    static let shared = KeychainCache()
    private var cache: [String: Data] = [:]
    private let lock = NSLock()

    func get(_ scope: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return cache[scope]
    }

    func set(_ scope: String, data: Data) {
        lock.lock()
        defer { lock.unlock() }
        cache[scope] = data
    }

    func remove(_ scope: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: scope)
    }
}

public struct KeychainService: Sendable {
    private let accessGroup: String

    public init(accessGroup: String = "com.clawapi.shared") {
        self.accessGroup = accessGroup
    }

    // MARK: - Biometric Authentication

    /// Authenticate using Touch ID (or password fallback on Macs without Touch ID).
    /// Call this before sensitive Keychain operations (save/delete) in the UI layer.
    /// Returns `true` if authenticated, `false` if denied or unavailable.
    public static func authenticateWithBiometrics(reason: String = "Authenticate to manage API keys") async -> Bool {
        let context = LAContext()
        var error: NSError?

        // Check if biometrics (Touch ID) or device passcode is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            logger.warning("Biometric auth not available: \(error?.localizedDescription ?? "unknown")")
            return true  // Allow operation if no auth mechanism available
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return success
        } catch {
            logger.info("Biometric auth denied: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Save

    public func save(secret: Data, forScope scope: String) throws {
        // Delete any existing item first
        try? delete(forScope: scope)

        // Use SecAccessControl with .userPresence so reads require Touch ID
        // (with automatic password fallback on Macs without Touch ID).
        var cfError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &cfError
        ) else {
            let desc = cfError?.takeRetainedValue().localizedDescription ?? "unknown"
            logger.error("Failed to create access control: \(desc)")
            throw KeychainError.saveFailed(errSecParam)
        }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ClawAPI",
            kSecAttrAccount as String: scope,
            kSecValueData as String: secret,
            kSecAttrAccessControl as String: access,
        ]

        #if !DEBUG
        query[kSecAttrAccessGroup as String] = accessGroup
        #endif

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Keychain save failed for scope '\(scope)': \(status)")
            throw KeychainError.saveFailed(status)
        }
        // Update in-memory cache so subsequent reads don't trigger OS prompts
        KeychainCache.shared.set(scope, data: secret)
        logger.info("Saved secret for scope '\(scope)'")
    }

    public func save(string: String, forScope scope: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try save(secret: data, forScope: scope)
    }

    // MARK: - Retrieve

    public func retrieve(forScope scope: String) throws -> Data {
        // Check in-memory cache first to avoid repeated OS keychain prompts
        if let cached = KeychainCache.shared.get(scope) {
            return cached
        }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ClawAPI",
            kSecAttrAccount as String: scope,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        #if !DEBUG
        query[kSecAttrAccessGroup as String] = accessGroup
        #endif

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                throw KeychainError.notFound
            }
            logger.error("Keychain retrieve failed for scope '\(scope)': \(status)")
            throw KeychainError.retrieveFailed(status)
        }
        // Cache for future reads
        KeychainCache.shared.set(scope, data: data)
        return data
    }

    public func retrieveString(forScope scope: String) throws -> String {
        let data = try retrieve(forScope: scope)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        // Trim whitespace/newlines that may have been pasted with the key
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Delete

    public func delete(forScope scope: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ClawAPI",
            kSecAttrAccount as String: scope,
        ]

        #if !DEBUG
        query[kSecAttrAccessGroup as String] = accessGroup
        #endif

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Keychain delete failed for scope '\(scope)': \(status)")
            throw KeychainError.deleteFailed(status)
        }
        // Invalidate in-memory cache
        KeychainCache.shared.remove(scope)
        logger.info("Deleted secret for scope '\(scope)'")
    }

    // MARK: - Batch preload

    /// Read ALL ClawAPI secrets from the Keychain in a single query.
    /// This triggers at most one macOS permission prompt instead of one per scope.
    /// Results are cached for future individual reads.
    public func preloadAll() {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ClawAPI",
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        #if !DEBUG
        query[kSecAttrAccessGroup as String] = accessGroup
        #endif

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            if status != errSecItemNotFound {
                logger.error("Keychain preloadAll failed: \(status)")
            }
            return
        }

        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                  let data = item[kSecValueData as String] as? Data else { continue }
            KeychainCache.shared.set(account, data: data)
        }
        logger.info("Preloaded \(items.count) secrets from Keychain")
    }

    // MARK: - Check existence

    public func hasSecret(forScope scope: String) -> Bool {
        (try? retrieve(forScope: scope)) != nil
    }

    // MARK: - Admin key helpers

    /// Admin keys are stored under "{scope}-admin" in the Keychain.
    public func saveAdminKey(_ key: String, forScope scope: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try save(string: trimmed, forScope: "\(scope)-admin")
    }

    public func retrieveAdminKey(forScope scope: String) throws -> String {
        try retrieveString(forScope: "\(scope)-admin")
    }

    public func deleteAdminKey(forScope scope: String) throws {
        try delete(forScope: "\(scope)-admin")
    }

    public func hasAdminKey(forScope scope: String) -> Bool {
        (try? retrieve(forScope: "\(scope)-admin")) != nil
    }
}

// MARK: - Errors

public enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case notFound
    case encodingFailed
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status): "Failed to save to Keychain (status: \(status))"
        case .retrieveFailed(let status): "Failed to retrieve from Keychain (status: \(status))"
        case .deleteFailed(let status): "Failed to delete from Keychain (status: \(status))"
        case .notFound: "Item not found in Keychain"
        case .encodingFailed: "Failed to encode string to data"
        case .decodingFailed: "Failed to decode data to string"
        }
    }
}
