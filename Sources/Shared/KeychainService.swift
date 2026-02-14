import Foundation
import Security
import OSLog

private let logger = Logger(subsystem: "com.clawapi", category: "Keychain")

public struct KeychainService: Sendable {
    private let accessGroup: String

    public init(accessGroup: String = "com.clawapi.shared") {
        self.accessGroup = accessGroup
    }

    // MARK: - Save

    public func save(secret: Data, forScope scope: String) throws {
        // Delete any existing item first
        try? delete(forScope: scope)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ClawAPI",
            kSecAttrAccount as String: scope,
            kSecValueData as String: secret,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        #if !DEBUG
        query[kSecAttrAccessGroup as String] = accessGroup
        #endif

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Keychain save failed for scope '\(scope)': \(status)")
            throw KeychainError.saveFailed(status)
        }
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
        logger.info("Deleted secret for scope '\(scope)'")
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
