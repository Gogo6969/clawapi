import Foundation
import OSLog

private let logger = Logger(subsystem: "com.clawapi", category: "PolicyStore")

@MainActor
public final class PolicyStore: ObservableObject, Sendable {
    @Published public var policies: [ScopePolicy] = []
    @Published public var auditEntries: [AuditEntry] = []
    @Published public var pendingRequests: [PendingRequest] = []
    /// The most recent sync error message, or nil if no error. Auto-clears after 10 seconds.
    @Published public var syncError: String?
    /// Health status per provider scope. Updated by checkAllHealth().
    @Published public var healthStatus: [String: ProviderHealth] = [:]
    /// Whether a health check is currently running.
    @Published public var isCheckingHealth = false

    private let policiesURL: URL
    private let auditURL: URL
    private let pendingURL: URL
    private var syncErrorObserver: Any?
    private var healthObserver: Any?

    /// Keychain for syncing to OpenClaw on save.
    public let keychain = KeychainService()

    public init(directory: URL? = nil) {
        let base = directory ?? PolicyStore.defaultDirectory
        self.policiesURL = base.appendingPathComponent("policies.json")
        self.auditURL = base.appendingPathComponent("audit.json")
        self.pendingURL = base.appendingPathComponent("pending.json")

        ensureDirectory(base)
        load()

        // Auto-adopt orphaned OAuth profiles (OAuth profiles in auth-profiles.json
        // with no matching ScopePolicy). This ensures OAuth providers appear in
        // the Providers tab even if the user set them up via OpenClaw CLI.
        let adoption = OpenClawConfig.autoAdoptOAuthProfiles(existingPolicies: policies)
        if !adoption.policies.isEmpty {
            for policy in adoption.policies {
                if policy.scope == adoption.activeScope {
                    // This OAuth provider is the currently active model — insert at #1
                    policies.insert(policy, at: 0)
                    logger.info("Auto-adopted OAuth provider \(policy.scope) as priority #1 (active model)")
                } else {
                    policies.append(policy)
                }
            }
            normalizePriorities()
            saveJSON(policies, to: policiesURL)
            logger.info("Auto-adopted \(adoption.policies.count) orphaned OAuth profile(s)")
        }

        // Listen for sync errors from OpenClawConfig
        syncErrorObserver = NotificationCenter.default.addObserver(
            forName: OpenClawConfig.syncErrorNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let message = notification.object as? String else { return }
            Task { @MainActor [weak self] in
                self?.syncError = message
                // Auto-clear after 10 seconds
                try? await Task.sleep(for: .seconds(10))
                if self?.syncError == message {
                    self?.syncError = nil
                }
            }
        }

        // Only access Keychain if auth profiles actually need syncing.
        // This avoids unnecessary macOS permission prompts on every launch
        // (especially with ad-hoc signing where each rebuild is a new binary).
        let needsSync = OpenClawConfig.needsAuthProfileSync(policies: policies)
        logger.info("Launch sync check: needsAuthProfileSync=\(needsSync)")
        if needsSync {
            keychain.preloadAll()
            OpenClawConfig.syncToOpenClaw(policies: policies, keychain: keychain)
        } else {
            // Lightweight sync: only update model priority in openclaw.json
            OpenClawConfig.syncModelOnly(policies: policies)
        }

        // Derive initial health from audit log (passive — no API calls)
        let scopes = policies.filter(\.isEnabled).map(\.scope)
        healthStatus = ProviderHealthCheck.deriveFromAuditLog(entries: auditEntries, scopes: scopes)

        // Listen for real-time health updates from the daemon proxy
        healthObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(providerHealthNotification.rawValue),
            object: nil,
            queue: .main
        ) { notification in
            guard let info = notification.userInfo,
                  let scope = info["scope"] as? String,
                  let statusCode = info["statusCode"] as? Int else { return }
            Task { @MainActor [weak self] in
                let health = ProviderHealthCheck.classifyStatusCode(statusCode, body: nil)
                self?.healthStatus[scope] = health
            }
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

    // MARK: - Health Checks

    /// Manually check all enabled providers using free GET /models endpoints (no tokens consumed).
    public func checkAllHealth() {
        guard !isCheckingHealth else { return }
        isCheckingHealth = true
        // Mark all enabled providers as "checking"
        for policy in policies where policy.isEnabled {
            healthStatus[policy.scope] = .checking
        }
        Task {
            let results = await ProviderHealthCheck.manualCheckAll(policies: policies, keychain: keychain)
            await MainActor.run {
                for (scope, health) in results {
                    self.healthStatus[scope] = health
                }
                self.isCheckingHealth = false
            }
        }
    }

    /// Update health status when a new audit entry shows a proxy result.
    private func updateHealthFromAudit(_ entry: AuditEntry) {
        guard let detail = entry.detail, detail.contains("Proxied"),
              let arrowRange = detail.range(of: "→ ") else { return }
        let statusStr = String(detail[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard let statusCode = Int(statusStr) else { return }
        healthStatus[entry.scope] = ProviderHealthCheck.classifyStatusCode(statusCode, body: nil)
    }

    // MARK: - Audit

    public func addAuditEntry(_ entry: AuditEntry) {
        auditEntries.insert(entry, at: 0)
        updateHealthFromAudit(entry)
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
