import Foundation

public enum MockData {
    public static let policies: [ScopePolicy] = [
        ScopePolicy(
            serviceName: "OpenAI",
            scope: "openai",
            allowedDomains: ["api.openai.com"],
            approvalMode: .auto,
            hasSecret: true,
            priority: 1,
            preferredFor: ["coding", "chat", "general"],
            createdAt: Date().addingTimeInterval(-86400 * 30)
        ),
        ScopePolicy(
            serviceName: "xAI (Grok)",
            scope: "xai",
            allowedDomains: ["api.x.ai"],
            approvalMode: .auto,
            hasSecret: true,
            priority: 2,
            preferredFor: ["chat", "research"],
            createdAt: Date().addingTimeInterval(-86400 * 20)
        ),
        ScopePolicy(
            serviceName: "Anthropic",
            scope: "anthropic",
            allowedDomains: ["api.anthropic.com"],
            approvalMode: .auto,
            hasSecret: true,
            priority: 3,
            credentialType: .customHeader,
            customHeaderName: "x-api-key",
            preferredFor: ["coding", "analysis", "chat"],
            createdAt: Date().addingTimeInterval(-86400 * 15)
        ),
        ScopePolicy(
            serviceName: "GitHub",
            scope: "github",
            allowedDomains: ["api.github.com", "github.com"],
            approvalMode: .auto,
            hasSecret: true,
            priority: 4,
            preferredFor: ["coding"],
            createdAt: Date().addingTimeInterval(-86400 * 10)
        ),
        ScopePolicy(
            serviceName: "Perplexity",
            scope: "perplexity",
            allowedDomains: ["api.perplexity.ai"],
            approvalMode: .auto,
            hasSecret: true,
            priority: 5,
            preferredFor: ["research"],
            createdAt: Date().addingTimeInterval(-86400 * 7)
        ),
        ScopePolicy(
            serviceName: "Groq",
            scope: "groq",
            allowedDomains: ["api.groq.com"],
            approvalMode: .auto,
            hasSecret: false,
            isEnabled: false,
            priority: 6,
            preferredFor: ["coding", "chat"],
            createdAt: Date().addingTimeInterval(-86400 * 5)
        ),
    ]

    public static let auditEntries: [AuditEntry] = [
        AuditEntry(
            timestamp: Date().addingTimeInterval(-3600),
            scope: "openai",
            requestingHost: "api.openai.com",
            reason: "Generate code completion",
            result: .approved
        ),
        AuditEntry(
            timestamp: Date().addingTimeInterval(-7200),
            scope: "xai",
            requestingHost: "api.x.ai",
            reason: "Chat completion via Grok",
            result: .approved
        ),
        AuditEntry(
            timestamp: Date().addingTimeInterval(-10800),
            scope: "github",
            requestingHost: "api.github.com",
            reason: "Fetch repository list",
            result: .approved
        ),
        AuditEntry(
            timestamp: Date().addingTimeInterval(-12000),
            scope: "perplexity",
            requestingHost: "api.perplexity.ai",
            reason: "Web search — latest Swift concurrency docs",
            result: .approved
        ),
        AuditEntry(
            timestamp: Date().addingTimeInterval(-14400),
            scope: "anthropic",
            requestingHost: "unknown-host.example.com",
            reason: "Message completion",
            result: .denied,
            detail: "Host not in allowed domains"
        ),
        AuditEntry(
            timestamp: Date().addingTimeInterval(-86400),
            scope: "groq",
            requestingHost: "api.groq.com",
            reason: "Fast inference",
            result: .error,
            detail: "No credential stored"
        ),
    ]

    public static let pendingRequests: [PendingRequest] = [
        PendingRequest(
            scope: "github",
            requestingHost: "api.github.com",
            reason: "Create release tag v2.1.0",
            requestedAt: Date().addingTimeInterval(-120)
        ),
    ]
}
