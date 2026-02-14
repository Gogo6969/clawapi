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
            name: "Anthropic (Claude)",
            scope: "anthropic",
            domains: ["api.anthropic.com"],
            credentialType: .customHeader,
            customHeaderName: "x-api-key",
            suggestedTags: ["coding", "analysis", "chat"],
            keyPlaceholder: "sk-ant-..."
        ),
        ServiceTemplate(
            name: "Claude",
            scope: "claude",
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
        ServiceTemplate(
            name: "OpenRouter",
            scope: "openrouter",
            domains: ["openrouter.ai"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["general", "chat", "coding"],
            keyPlaceholder: "sk-or-..."
        ),
        ServiceTemplate(
            name: "Cerebras",
            scope: "cerebras",
            domains: ["api.cerebras.ai"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["coding", "chat"],
            keyPlaceholder: "API key"
        ),
        ServiceTemplate(
            name: "Together AI",
            scope: "together",
            domains: ["api.together.xyz"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["coding", "general"],
            keyPlaceholder: "API key"
        ),
        ServiceTemplate(
            name: "Venice AI",
            scope: "venice",
            domains: ["api.venice.ai"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["chat", "general"],
            keyPlaceholder: "API key"
        ),
        ServiceTemplate(
            name: "Moonshot (Kimi)",
            scope: "moonshot",
            domains: ["api.moonshot.ai", "api.moonshot.cn"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["coding", "chat"],
            keyPlaceholder: "sk-..."
        ),
        ServiceTemplate(
            name: "MiniMax",
            scope: "minimax",
            domains: ["api.minimax.io", "api.minimax.chat"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["coding", "chat"],
            keyPlaceholder: "API key"
        ),
        ServiceTemplate(
            name: "Synthetic",
            scope: "synthetic",
            domains: ["api.synthetic.new"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["general", "chat"],
            keyPlaceholder: "API key"
        ),
        ServiceTemplate(
            name: "Z.AI (GLM)",
            scope: "zai",
            domains: ["api.z.ai"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["chat", "coding"],
            keyPlaceholder: "API key"
        ),
        ServiceTemplate(
            name: "OpenCode Zen",
            scope: "opencode",
            domains: ["api.opencode.ai"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["coding"],
            keyPlaceholder: "API key"
        ),
        ServiceTemplate(
            name: "Vercel AI Gateway",
            scope: "vercel-ai-gateway",
            domains: ["sdk.vercel.ai"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["general", "coding"],
            keyPlaceholder: "API key"
        ),
        ServiceTemplate(
            name: "Baidu Qianfan",
            scope: "qianfan",
            domains: ["qianfan.baidubce.com"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["chat", "general"],
            keyPlaceholder: "API key"
        ),
        ServiceTemplate(
            name: "Xiaomi MiMo",
            scope: "xiaomi",
            domains: ["api.xiaomimimo.com"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["coding", "chat"],
            keyPlaceholder: "API key"
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

        // ── Media / Speech ──
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
            name: "Deepgram",
            scope: "deepgram",
            domains: ["api.deepgram.com"],
            credentialType: .bearerToken,
            customHeaderName: nil,
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
