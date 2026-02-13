import Testing
import Foundation
@testable import Shared

@Suite("Models Tests")
struct ModelsTests {

    @Test("ScopePolicy is Codable")
    func scopePolicyCodable() throws {
        let policy = ScopePolicy(
            serviceName: "GitHub",
            scope: "github:read",
            allowedDomains: ["api.github.com"],
            approvalMode: .auto,
            hasSecret: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(policy)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ScopePolicy.self, from: data)

        #expect(decoded.id == policy.id)
        #expect(decoded.serviceName == "GitHub")
        #expect(decoded.scope == "github:read")
        #expect(decoded.allowedDomains == ["api.github.com"])
        #expect(decoded.approvalMode == .auto)
        #expect(decoded.hasSecret == true)
    }

    @Test("AuditEntry is Codable")
    func auditEntryCodable() throws {
        let entry = AuditEntry(
            scope: "test:read",
            requestingHost: "localhost",
            reason: "unit test",
            result: .approved,
            detail: "test detail"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AuditEntry.self, from: data)

        #expect(decoded.id == entry.id)
        #expect(decoded.scope == "test:read")
        #expect(decoded.result == .approved)
        #expect(decoded.detail == "test detail")
    }

    @Test("PendingRequest is Codable")
    func pendingRequestCodable() throws {
        let request = PendingRequest(
            scope: "aws:s3:read",
            requestingHost: "s3.amazonaws.com",
            reason: "Deploy"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PendingRequest.self, from: data)

        #expect(decoded.id == request.id)
        #expect(decoded.scope == "aws:s3:read")
        #expect(decoded.reason == "Deploy")
    }

    @Test("ScopeApprovalMode all cases")
    func approvalModeCases() {
        let cases = ScopeApprovalMode.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.auto))
        #expect(cases.contains(.manual))
        #expect(cases.contains(.pending))
    }

    @Test("AuditResult raw values")
    func auditResultRawValues() {
        #expect(AuditResult.approved.rawValue == "approved")
        #expect(AuditResult.denied.rawValue == "denied")
        #expect(AuditResult.error.rawValue == "error")
    }

    @Test("MockData is non-empty")
    func mockDataPopulated() {
        #expect(!MockData.policies.isEmpty)
        #expect(!MockData.auditEntries.isEmpty)
        #expect(!MockData.pendingRequests.isEmpty)
    }
}
