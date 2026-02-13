import Foundation

/// A known service with pre-filled configuration.
/// Users just pick a service and paste their API key — everything else is automatic.
public struct ServiceTemplate: Sendable, Identifiable {
    public var id: String { scope }
    public let name: String
    public let scope: String
    public let domains: [String]
    public let credentialType: CredentialType
    public let customHeaderName: String?
    public let suggestedTags: [String]
    public let keyPlaceholder: String
}

/// Built-in catalog of known AI APIs and common services.
/// Covers all providers that OpenClaw supports out of the box.
public enum ServiceCatalog {

    public static let all: [ServiceTemplate] = [
        // ── AI / LLM APIs ──
        ServiceTemplate(
            name: "OpenAI",
            scope: "openai",
            domains: ["api.openai.com"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["coding", "chat", "general"],
            keyPlaceholder: "sk-..."
        ),
        ServiceTemplate(
            name: "xAI (Grok)",
            scope: "xai",
            domains: ["api.x.ai"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["chat", "research"],
            keyPlaceholder: "xai-..."
        ),
        ServiceTemplate(
            name: "Anthropic",
            scope: "anthropic",
            domains: ["api.anthropic.com"],
            credentialType: .customHeader,
            customHeaderName: "x-api-key",
            suggestedTags: ["coding", "analysis", "chat"],
            keyPlaceholder: "sk-ant-..."
        ),
        ServiceTemplate(
            name: "Google AI",
            scope: "google-ai",
            domains: ["generativelanguage.googleapis.com"],
            credentialType: .customHeader,
            customHeaderName: "x-goog-api-key",
            suggestedTags: ["research", "chat", "general"],
            keyPlaceholder: "AIza..."
        ),
        ServiceTemplate(
            name: "Mistral",
            scope: "mistral",
            domains: ["api.mistral.ai"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["coding", "chat"],
            keyPlaceholder: "API key"
        ),
        ServiceTemplate(
            name: "Groq",
            scope: "groq",
            domains: ["api.groq.com"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["coding", "chat"],
            keyPlaceholder: "gsk_..."
        ),
        ServiceTemplate(
            name: "Cohere",
            scope: "cohere",
            domains: ["api.cohere.com"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["research", "analysis"],
            keyPlaceholder: "API key"
        ),
        ServiceTemplate(
            name: "Perplexity",
            scope: "perplexity",
            domains: ["api.perplexity.ai"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["research"],
            keyPlaceholder: "pplx-..."
        ),

        // ── Developer APIs ──
        ServiceTemplate(
            name: "GitHub",
            scope: "github",
            domains: ["api.github.com", "github.com"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["coding"],
            keyPlaceholder: "ghp_... or github_pat_..."
        ),

        // ── Media / Other ──
        ServiceTemplate(
            name: "ElevenLabs",
            scope: "elevenlabs",
            domains: ["api.elevenlabs.io"],
            credentialType: .customHeader,
            customHeaderName: "xi-api-key",
            suggestedTags: ["audio"],
            keyPlaceholder: "API key"
        ),
        ServiceTemplate(
            name: "Replicate",
            scope: "replicate",
            domains: ["api.replicate.com"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["images", "general"],
            keyPlaceholder: "r8_..."
        ),
        ServiceTemplate(
            name: "HuggingFace",
            scope: "huggingface",
            domains: ["api-inference.huggingface.co"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["research", "images"],
            keyPlaceholder: "hf_..."
        ),
    ]

    /// Find a template by scope or name (case-insensitive).
    public static func find(_ query: String) -> ServiceTemplate? {
        let q = query.lowercased()
        return all.first { $0.scope == q || $0.name.lowercased() == q }
    }
}
