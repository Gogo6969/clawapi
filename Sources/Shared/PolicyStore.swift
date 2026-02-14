import Foundation
import OSLog

private let logger = Logger(subsystem: "com.clawapi", category: "PolicyStore")

@MainActor
public final class PolicyStore: ObservableObject, Sendable {
    @Published public var policies: [ScopePolicy] = []
    @Published public var auditEntries: [AuditEntry] = []
    @Published public var pendingRequests: [PendingRequest] = []

    private let policiesURL: URL
    private let auditURL: URL
    private let pendingURL: URL

    /// Keychain for syncing to OpenClaw on save.
    public let keychain = KeychainService()

    public init(directory: URL? = nil) {
        let base = directory ?? PolicyStore.defaultDirectory
        self.policiesURL = base.appendingPathComponent("policies.json")
        self.auditURL = base.appendingPathComponent("audit.json")
        self.pendingURL = base.appendingPathComponent("pending.json")

        ensureDirectory(base)
        load()

        // Preload all Keychain secrets in a single query so that
        // subsequent reads (during sync) hit the in-memory cache
        // instead of triggering repeated macOS permission prompts.
        keychain.preloadAll()

        // If any provider is missing an auth profile, do a full sync once
        // (keys come from the preloaded cache, so no extra Keychain prompts).
        if OpenClawConfig.needsAuthProfileSync(policies: policies) {
            OpenClawConfig.syncToOpenClaw(policies: policies, keychain: keychain)
        } else {
            // Lightweight sync: only update model priority in openclaw.json
            OpenClawConfig.syncModelOnly(policies: policies)
        }
    }

    // MARK: - Default directory

    public nonisolated static var defaultDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ClawAPI")
    }

    // MARK: - Load

    public func load() {
        policies = loadJSON(from: policiesURL) ?? []
        auditEntries = loadJSON(from: auditURL) ?? []
        pendingRequests = loadJSON(from: pendingURL) ?? []
        // Normalize priorities for legacy data (where priority may be 0)
        if !policies.isEmpty && policies.contains(where: { $0.priority == 0 }) {
            normalizePriorities()
            saveJSON(policies, to: policiesURL)
        }
        logger.info("Loaded \(self.policies.count) policies, \(self.auditEntries.count) audit entries, \(self.pendingRequests.count) pending requests")
    }

    // MARK: - Save

    public func save(fullSync: Bool = false) {
        saveJSON(policies, to: policiesURL)
        saveJSON(auditEntries, to: auditURL)
        saveJSON(pendingRequests, to: pendingURL)
        logger.info("Saved policy store")

        if fullSync {
            // Full sync: write API keys to auth-profiles.json + update model
            OpenClawConfig.syncToOpenClaw(policies: policies, keychain: keychain)
        } else {
            // Lightweight sync: only update model priority in openclaw.json
            OpenClawConfig.syncModelOnly(policies: policies)
        }
    }

    // MARK: - Policy CRUD

    public func addPolicy(_ policy: ScopePolicy) {
        policies.append(policy)
        normalizePriorities()
        save(fullSync: true)
    }

    public func removePolicy(_ policy: ScopePolicy) {
        policies.removeAll { $0.id == policy.id }
        normalizePriorities()
        save(fullSync: true)
    }

    public func updatePolicy(_ policy: ScopePolicy) {
        if let index = policies.firstIndex(where: { $0.id == policy.id }) {
            policies[index] = policy
            save(fullSync: true)
        }
    }

    /// Change the sub-model for a policy and optionally promote it to #1.
    /// This is a single atomic operation: update model + reorder + ONE lightweight sync.
    /// No keychain access needed — only openclaw.json changes.
    public func selectModel(_ modelId: String, for policy: ScopePolicy) {
        guard let index = policies.firstIndex(where: { $0.id == policy.id }) else { return }
        policies[index].selectedModel = modelId

        // Promote to top if not already #1
        if index != 0 {
            let item = policies.remove(at: index)
            policies.insert(item, at: 0)
        }

        normalizePriorities()
        save()  // Lightweight sync — model+priority only, no keychain
    }

    // MARK: - Priority Management

    /// Reassign priorities 1…N based on current array order.
    public func normalizePriorities() {
        for i in policies.indices {
            policies[i].priority = i + 1
        }
    }

    /// Move a policy to the top of the list (priority #1).
    /// Used when the user selects a sub-model — promotes that provider to primary.
    public func promoteToTop(_ policy: ScopePolicy) {
        guard let index = policies.firstIndex(where: { $0.id == policy.id }),
              index != 0 else { return }
        let item = policies.remove(at: index)
        policies.insert(item, at: 0)
        normalizePriorities()
        save()  // Lightweight sync — model+priority only, no keychain
    }

    /// Reorder policies via drag-and-drop, then normalize and save.
    public func movePolicies(fromOffsets source: IndexSet, toOffset destination: Int) {
        // Replicate Array.move(fromOffsets:toOffset:) which is only available in SwiftUI
        var items = policies
        let moving = source.map { items[$0] }
        // Remove from highest index first to preserve lower indices
        for index in source.sorted().reversed() {
            items.remove(at: index)
        }
        // Calculate insertion point adjusted for removed items
        let insertAt = min(destination - source.filter { $0 < destination }.count, items.count)
        items.insert(contentsOf: moving, at: insertAt)
        policies = items
        normalizePriorities()
        save()
    }

    // MARK: - Audit

    public func addAuditEntry(_ entry: AuditEntry) {
        auditEntries.insert(entry, at: 0)
        save()
    }

    // MARK: - Pending Requests

    public func addPendingRequest(_ request: PendingRequest) {
        pendingRequests.append(request)
        save()
    }

    public func approvePendingRequest(_ request: PendingRequest) {
        pendingRequests.removeAll { $0.id == request.id }
        let entry = AuditEntry(
            scope: request.scope,
            requestingHost: request.requestingHost,
            reason: request.reason,
            result: .approved,
            detail: "Manually approved"
        )
        addAuditEntry(entry)
    }

    public func denyPendingRequest(_ request: PendingRequest) {
        pendingRequests.removeAll { $0.id == request.id }
        let entry = AuditEntry(
            scope: request.scope,
            requestingHost: request.requestingHost,
            reason: request.reason,
            result: .denied,
            detail: "Manually denied"
        )
        addAuditEntry(entry)
    }

    // MARK: - Lookup

    public func policy(forScope scope: String) -> ScopePolicy? {
        policies.first { $0.scope == scope }
    }

    // MARK: - Private helpers

    private func ensureDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func loadJSON<T: Decodable>(from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    private func saveJSON<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else {
            logger.error("Failed to encode data for \(url.lastPathComponent)")
            return
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("Failed to write \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
