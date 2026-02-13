import Testing
import Foundation
@testable import Shared

@Suite("PolicyStore Tests")
struct PolicyStoreTests {

    private func makeTempDir() -> URL {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }

    @MainActor
    @Test("Starts empty when no files exist")
    func startsEmpty() {
        let dir = makeTempDir()
        let store = PolicyStore(directory: dir)
        #expect(store.policies.isEmpty)
        #expect(store.auditEntries.isEmpty)
        #expect(store.pendingRequests.isEmpty)
    }

    @MainActor
    @Test("Add and remove policy")
    func addRemovePolicy() {
        let dir = makeTempDir()
        let store = PolicyStore(directory: dir)
        let initial = store.policies.count

        let policy = ScopePolicy(
            serviceName: "Test",
            scope: "test:read",
            allowedDomains: ["test.com"],
            approvalMode: .auto
        )
        store.addPolicy(policy)
        #expect(store.policies.count == initial + 1)

        store.removePolicy(policy)
        #expect(store.policies.count == initial)
    }

    @MainActor
    @Test("Update policy")
    func updatePolicy() {
        let dir = makeTempDir()
        let store = PolicyStore(directory: dir)

        var policy = ScopePolicy(
            serviceName: "Test",
            scope: "test:write",
            approvalMode: .manual
        )
        store.addPolicy(policy)

        policy.approvalMode = .auto
        store.updatePolicy(policy)

        let found = store.policy(forScope: "test:write")
        #expect(found?.approvalMode == .auto)
    }

    @MainActor
    @Test("Persist and reload")
    func persistAndReload() {
        let dir = makeTempDir()

        let store1 = PolicyStore(directory: dir)
        store1.policies = []
        store1.auditEntries = []
        store1.pendingRequests = []
        store1.save()

        let policy = ScopePolicy(serviceName: "Persist", scope: "persist:test", approvalMode: .pending)
        store1.addPolicy(policy)

        let store2 = PolicyStore(directory: dir)
        #expect(store2.policies.count == 1)
        #expect(store2.policies.first?.scope == "persist:test")
    }

    @MainActor
    @Test("Approve pending request creates audit entry")
    func approvePending() {
        let dir = makeTempDir()
        let store = PolicyStore(directory: dir)
        let initialAuditCount = store.auditEntries.count

        let request = PendingRequest(
            scope: "test:approve",
            requestingHost: "test.com",
            reason: "Test approval"
        )
        store.addPendingRequest(request)
        #expect(store.pendingRequests.contains { $0.id == request.id })

        store.approvePendingRequest(request)
        #expect(!store.pendingRequests.contains { $0.id == request.id })
        #expect(store.auditEntries.count == initialAuditCount + 1)
        #expect(store.auditEntries.first?.result == .approved)
    }

    @MainActor
    @Test("Deny pending request creates audit entry")
    func denyPending() {
        let dir = makeTempDir()
        let store = PolicyStore(directory: dir)
        let initialAuditCount = store.auditEntries.count

        let request = PendingRequest(
            scope: "test:deny",
            requestingHost: "evil.com",
            reason: "Test denial"
        )
        store.addPendingRequest(request)
        store.denyPendingRequest(request)

        #expect(!store.pendingRequests.contains { $0.id == request.id })
        #expect(store.auditEntries.count == initialAuditCount + 1)
        #expect(store.auditEntries.first?.result == .denied)
    }

    @MainActor
    @Test("Policy lookup by scope")
    func lookupByScope() {
        let dir = makeTempDir()
        let store = PolicyStore(directory: dir)

        let policy = ScopePolicy(serviceName: "Lookup", scope: "lookup:test", approvalMode: .auto)
        store.addPolicy(policy)

        #expect(store.policy(forScope: "lookup:test") != nil)
        #expect(store.policy(forScope: "nonexistent:scope") == nil)
    }

    @MainActor
    @Test("Toggle isEnabled and persist")
    func toggleIsEnabled() {
        let dir = makeTempDir()
        let store = PolicyStore(directory: dir)

        var policy = ScopePolicy(serviceName: "Toggle", scope: "toggle:test", approvalMode: .auto)
        #expect(policy.isEnabled == true) // default

        store.addPolicy(policy)

        // Disable
        policy.isEnabled = false
        store.updatePolicy(policy)
        #expect(store.policy(forScope: "toggle:test")?.isEnabled == false)

        // Persist and reload
        let store2 = PolicyStore(directory: dir)
        #expect(store2.policy(forScope: "toggle:test")?.isEnabled == false)

        // Re-enable
        var reloaded = store2.policy(forScope: "toggle:test")!
        reloaded.isEnabled = true
        store2.updatePolicy(reloaded)
        #expect(store2.policy(forScope: "toggle:test")?.isEnabled == true)
    }

    @MainActor
    @Test("Backward compatible decoding without isEnabled field")
    func backwardCompatDecoding() throws {
        let dir = makeTempDir()

        // Write a policy JSON without the isEnabled field (simulates old data)
        let json = """
        [{"id":"00000000-0000-0000-0000-000000000001","serviceName":"Old","scope":"old:test","allowedDomains":[],"approvalMode":"auto","hasSecret":false,"credentialType":"bearer","createdAt":"2024-01-01T00:00:00Z"}]
        """
        let policiesURL = dir.appendingPathComponent("policies.json")
        try json.data(using: .utf8)!.write(to: policiesURL)

        let store = PolicyStore(directory: dir)
        #expect(store.policies.count == 1)
        #expect(store.policies.first?.isEnabled == true) // defaults to true
    }

    // MARK: - Priority Tests

    @MainActor
    @Test("Priorities are normalized after adding policies")
    func prioritiesNormalizedAfterAdd() {
        let dir = makeTempDir()
        let store = PolicyStore(directory: dir)

        let p1 = ScopePolicy(serviceName: "First", scope: "first", approvalMode: .auto)
        let p2 = ScopePolicy(serviceName: "Second", scope: "second", approvalMode: .auto)
        let p3 = ScopePolicy(serviceName: "Third", scope: "third", approvalMode: .auto)

        store.addPolicy(p1)
        store.addPolicy(p2)
        store.addPolicy(p3)

        #expect(store.policies[0].priority == 1)
        #expect(store.policies[1].priority == 2)
        #expect(store.policies[2].priority == 3)
    }

    @MainActor
    @Test("Move policies reorders and re-normalizes")
    func movePolicies() {
        let dir = makeTempDir()
        let store = PolicyStore(directory: dir)

        let p1 = ScopePolicy(serviceName: "A", scope: "a", approvalMode: .auto)
        let p2 = ScopePolicy(serviceName: "B", scope: "b", approvalMode: .auto)
        let p3 = ScopePolicy(serviceName: "C", scope: "c", approvalMode: .auto)

        store.addPolicy(p1)
        store.addPolicy(p2)
        store.addPolicy(p3)

        // Move "C" (index 2) to position 0 (top)
        store.movePolicies(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(store.policies[0].scope == "c")
        #expect(store.policies[1].scope == "a")
        #expect(store.policies[2].scope == "b")
        #expect(store.policies[0].priority == 1) // C is now MAIN
        #expect(store.policies[1].priority == 2)
        #expect(store.policies[2].priority == 3)
    }

    @MainActor
    @Test("Remove policy re-normalizes without gaps")
    func removePolicyNormalizesPriority() {
        let dir = makeTempDir()
        let store = PolicyStore(directory: dir)

        let p1 = ScopePolicy(serviceName: "A", scope: "a", approvalMode: .auto)
        let p2 = ScopePolicy(serviceName: "B", scope: "b", approvalMode: .auto)
        let p3 = ScopePolicy(serviceName: "C", scope: "c", approvalMode: .auto)

        store.addPolicy(p1)
        store.addPolicy(p2)
        store.addPolicy(p3)

        // Remove the middle one
        store.removePolicy(store.policies[1])

        #expect(store.policies.count == 2)
        #expect(store.policies[0].priority == 1)
        #expect(store.policies[1].priority == 2)
    }

    @MainActor
    @Test("Priority persists across reload")
    func priorityPersistsAcrossReload() {
        let dir = makeTempDir()
        let store = PolicyStore(directory: dir)

        let p1 = ScopePolicy(serviceName: "A", scope: "a", approvalMode: .auto)
        let p2 = ScopePolicy(serviceName: "B", scope: "b", approvalMode: .auto)

        store.addPolicy(p1)
        store.addPolicy(p2)

        // Move B to top
        store.movePolicies(fromOffsets: IndexSet(integer: 1), toOffset: 0)

        // Reload from disk
        let store2 = PolicyStore(directory: dir)
        #expect(store2.policies[0].scope == "b")
        #expect(store2.policies[0].priority == 1)
        #expect(store2.policies[1].scope == "a")
        #expect(store2.policies[1].priority == 2)
    }

    @MainActor
    @Test("Backward compatible decoding without priority field")
    func backwardCompatDecodingPriority() throws {
        let dir = makeTempDir()

        // Write policies JSON without the priority field (simulates old data)
        let json = """
        [{"id":"00000000-0000-0000-0000-000000000001","serviceName":"Old1","scope":"old1","allowedDomains":[],"approvalMode":"auto","hasSecret":false,"credentialType":"bearer","createdAt":"2024-01-01T00:00:00Z"},{"id":"00000000-0000-0000-0000-000000000002","serviceName":"Old2","scope":"old2","allowedDomains":[],"approvalMode":"auto","hasSecret":false,"credentialType":"bearer","createdAt":"2024-01-01T00:00:00Z"}]
        """
        let policiesURL = dir.appendingPathComponent("policies.json")
        try json.data(using: .utf8)!.write(to: policiesURL)

        let store = PolicyStore(directory: dir)
        #expect(store.policies.count == 2)
        // Legacy data has priority 0, which gets normalized on load to 1, 2
        #expect(store.policies[0].priority == 1)
        #expect(store.policies[1].priority == 2)
    }

    // MARK: - preferredFor Tests

    @MainActor
    @Test("preferredFor defaults to empty array")
    func preferredForDefaultsEmpty() {
        let policy = ScopePolicy(serviceName: "Test", scope: "test", approvalMode: .auto)
        #expect(policy.preferredFor.isEmpty)
    }

    @MainActor
    @Test("preferredFor field persists through save/reload")
    func preferredForPersistence() {
        let dir = makeTempDir()
        let store = PolicyStore(directory: dir)

        let policy = ScopePolicy(
            serviceName: "Tagged",
            scope: "tagged-test",
            approvalMode: .auto,
            preferredFor: ["research", "coding"]
        )
        store.addPolicy(policy)
        #expect(store.policies.first?.preferredFor == ["research", "coding"])

        // Reload from disk
        let store2 = PolicyStore(directory: dir)
        #expect(store2.policies.first?.preferredFor == ["research", "coding"])
    }

    @MainActor
    @Test("preferredFor with custom tags round-trips")
    func preferredForCustomTags() {
        let dir = makeTempDir()
        let store = PolicyStore(directory: dir)

        let policy = ScopePolicy(
            serviceName: "Custom",
            scope: "custom",
            approvalMode: .auto,
            preferredFor: ["coding", "my-special-task", "data-pipeline"]
        )
        store.addPolicy(policy)

        let store2 = PolicyStore(directory: dir)
        #expect(store2.policies.first?.preferredFor == ["coding", "my-special-task", "data-pipeline"])
    }

    @MainActor
    @Test("Backward compatible decoding without preferredFor field")
    func backwardCompatDecodingPreferredFor() throws {
        let dir = makeTempDir()

        let json = """
        [{"id":"00000000-0000-0000-0000-000000000001","serviceName":"Legacy","scope":"legacy","allowedDomains":[],"approvalMode":"auto","hasSecret":false,"credentialType":"bearer","createdAt":"2024-01-01T00:00:00Z"}]
        """
        let policiesURL = dir.appendingPathComponent("policies.json")
        try json.data(using: .utf8)!.write(to: policiesURL)

        let store = PolicyStore(directory: dir)
        #expect(store.policies.count == 1)
        #expect(store.policies.first?.preferredFor == [])
        #expect(store.policies.first?.serviceName == "Legacy")
    }
}
