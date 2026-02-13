import Foundation

// MARK: - Enums

public enum ScopeApprovalMode: String, Codable, Sendable, CaseIterable {
    case auto
    case manual
    case pending
}

public enum AuditResult: String, Codable, Sendable {
    case approved
    case denied
    case error
}

/// How the credential should be injected into proxied requests.
public enum CredentialType: String, Codable, Sendable, CaseIterable {
    /// Injected as `Authorization: Bearer <secret>`
    case bearerToken = "bearer"
    /// Injected as a custom header (uses `customHeaderName`)
    case customHeader = "header"
    /// Injected as `Cookie: <secret>`
    case cookie = "cookie"
    /// Injected as Basic auth: `Authorization: Basic base64(secret)`
    case basicAuth = "basic"
}

/// Predefined task-type tags for ScopePolicy.preferredFor.
/// Custom strings beyond these are also allowed.
public enum TaskType {
    public static let research = "research"
    public static let coding = "coding"
    public static let chat = "chat"
    public static let analysis = "analysis"
    public static let images = "images"
    public static let audio = "audio"
    public static let general = "general"

    /// All predefined options, in display order.
    public static let allPredefined: [String] = [
        research, coding, chat, analysis, images, audio, general
    ]
}

// MARK: - ScopePolicy

public struct ScopePolicy: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID
    public var serviceName: String
    public var scope: String
    public var allowedDomains: [String]
    public var approvalMode: ScopeApprovalMode
    public var hasSecret: Bool
    public var isEnabled: Bool
    public var priority: Int
    public var credentialType: CredentialType
    public var customHeaderName: String?
    public var preferredFor: [String]
    public var createdAt: Date
    public var lastUsedAt: Date?

    public init(
        id: UUID = UUID(),
        serviceName: String,
        scope: String,
        allowedDomains: [String] = [],
        approvalMode: ScopeApprovalMode = .manual,
        hasSecret: Bool = false,
        isEnabled: Bool = true,
        priority: Int = 0,
        credentialType: CredentialType = .bearerToken,
        customHeaderName: String? = nil,
        preferredFor: [String] = [],
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.serviceName = serviceName
        self.scope = scope
        self.allowedDomains = allowedDomains
        self.approvalMode = approvalMode
        self.hasSecret = hasSecret
        self.isEnabled = isEnabled
        self.priority = priority
        self.credentialType = credentialType
        self.customHeaderName = customHeaderName
        self.preferredFor = preferredFor
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    // Backward-compatible decoding: existing policies.json without isEnabled defaults to true
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        serviceName = try container.decode(String.self, forKey: .serviceName)
        scope = try container.decode(String.self, forKey: .scope)
        allowedDomains = try container.decode([String].self, forKey: .allowedDomains)
        approvalMode = try container.decode(ScopeApprovalMode.self, forKey: .approvalMode)
        hasSecret = try container.decode(Bool.self, forKey: .hasSecret)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        credentialType = try container.decode(CredentialType.self, forKey: .credentialType)
        customHeaderName = try container.decodeIfPresent(String.self, forKey: .customHeaderName)
        preferredFor = try container.decodeIfPresent([String].self, forKey: .preferredFor) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
    }
}

// MARK: - AuditEntry

public struct AuditEntry: Identifiable, Codable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var scope: String
    public var requestingHost: String
    public var reason: String
    public var result: AuditResult
    public var detail: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        scope: String,
        requestingHost: String,
        reason: String,
        result: AuditResult,
        detail: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.scope = scope
        self.requestingHost = requestingHost
        self.reason = reason
        self.result = result
        self.detail = detail
    }
}

// MARK: - PendingRequest

public struct PendingRequest: Identifiable, Codable, Sendable {
    public var id: UUID
    public var scope: String
    public var requestingHost: String
    public var reason: String
    public var requestedAt: Date

    public init(
        id: UUID = UUID(),
        scope: String,
        requestingHost: String,
        reason: String,
        requestedAt: Date = Date()
    ) {
        self.id = id
        self.scope = scope
        self.requestingHost = requestingHost
        self.reason = reason
        self.requestedAt = requestedAt
    }
}

// MARK: - Proxy Request / Response

/// Request from OpenClaw to the ClawAPI proxy.
/// OpenClaw sends this WITHOUT any credentials — ClawAPI injects them.
public struct ProxyRequest: Codable, Sendable {
    /// The scope identifier (matches a ScopePolicy scope, e.g. "x.com", "openai")
    public var scope: String
    /// HTTP method (GET, POST, PUT, DELETE, PATCH)
    public var method: String
    /// The full target URL (e.g. "https://api.x.com/2/tweets")
    public var url: String
    /// Optional extra headers (ClawAPI adds auth headers on top)
    public var headers: [String: String]?
    /// Optional request body (for POST/PUT/PATCH)
    public var body: String?
    /// Reason for the request (for audit logging)
    public var reason: String?

    public init(
        scope: String,
        method: String = "GET",
        url: String,
        headers: [String: String]? = nil,
        body: String? = nil,
        reason: String? = nil
    ) {
        self.scope = scope
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.reason = reason
    }
}

/// Response from the ClawAPI proxy back to OpenClaw.
/// Contains only the target API's response — no credentials leaked.
public struct ProxyResponse: Codable, Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: String?
    public var error: String?

    public init(
        statusCode: Int,
        headers: [String: String] = [:],
        body: String? = nil,
        error: String? = nil
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.error = error
    }
}
