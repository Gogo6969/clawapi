import Foundation

/// How a provider authenticates: API key, OAuth flow, or no auth (local).
public enum AuthMethod: Sendable {
    /// Standard API key pasted by the user, stored in Keychain.
    case apiKey
    /// OAuth flow via `openclaw onboard --auth-choice <provider>`.
    /// The associated value is the `--auth-choice` argument (e.g. "openai-codex").
    case oauth(provider: String)
    /// No authentication needed (local providers like Ollama).
    case none
}

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
    /// Whether the provider requires an API key. False for local and OAuth providers.
    public let requiresKey: Bool
    /// How this provider authenticates.
    public let authMethod: AuthMethod

    public init(
        name: String,
        scope: String,
        domains: [String],
        credentialType: CredentialType,
        customHeaderName: String?,
        suggestedTags: [String],
        keyPlaceholder: String,
        requiresKey: Bool = true,
        authMethod: AuthMethod = .apiKey
    ) {
        self.name = name
        self.scope = scope
        self.domains = domains
        self.credentialType = credentialType
        self.customHeaderName = customHeaderName
        self.suggestedTags = suggestedTags
        self.keyPlaceholder = keyPlaceholder
        self.requiresKey = requiresKey
        self.authMethod = authMethod
    }
}

/// Built-in catalog of known AI APIs and common services.
/// Covers all providers that OpenClaw supports out of the box.
public enum ServiceCatalog {

    /// Only providers that exist in OpenClaw's model catalog.
    /// Kept in sync with `openclaw models list --all --json` providers.
    public static let all: [ServiceTemplate] = [
        // ── AI / LLM APIs (matching OpenClaw providers) ──
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
            name: "Anthropic (Claude)",
            scope: "anthropic",
            domains: ["api.anthropic.com"],
            credentialType: .customHeader,
            customHeaderName: "x-api-key",
            suggestedTags: ["coding", "analysis", "chat"],
            keyPlaceholder: "sk-ant-..."
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
            name: "Kimi (Moonshot)",
            scope: "kimi-coding",
            domains: ["api.moonshot.ai", "api.moonshot.cn"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["coding"],
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
            name: "HuggingFace",
            scope: "huggingface",
            domains: ["api-inference.huggingface.co"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["research", "images"],
            keyPlaceholder: "hf_..."
        ),

        // ── OAuth Providers ──
        ServiceTemplate(
            name: "OpenAI Codex (OAuth)",
            scope: "openai-codex",
            domains: ["api.openai.com"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["coding"],
            keyPlaceholder: "",
            requiresKey: false,
            authMethod: .oauth(provider: "openai-codex")
        ),

        // ── Local Providers ──
        ServiceTemplate(
            name: "Ollama",
            scope: "ollama",
            domains: ["localhost"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["coding", "chat"],
            keyPlaceholder: "",
            requiresKey: false,
            authMethod: .none
        ),
        ServiceTemplate(
            name: "LM Studio",
            scope: "lmstudio",
            domains: ["localhost"],
            credentialType: .bearerToken,
            customHeaderName: nil,
            suggestedTags: ["coding", "chat"],
            keyPlaceholder: "",
            requiresKey: false,
            authMethod: .none
        ),
    ]

    /// Find a template by scope or name (case-insensitive).
    public static func find(_ query: String) -> ServiceTemplate? {
        let q = query.lowercased()
        return all.first { $0.scope == q || $0.name.lowercased() == q }
    }

    // MARK: - Dynamic Model Catalog (from OpenClaw)

    /// Map ClawAPI scopes to OpenClaw provider prefixes.
    /// "google-ai" maps to "google" (different naming conventions).
    private static let scopeToOpenClawProvider: [String: String] = [
        "openai": "openai",
        "anthropic": "anthropic",
        "xai": "xai",
        "google-ai": "google",
        "mistral": "mistral",
        "groq": "groq",
        "openrouter": "openrouter",
        "cerebras": "cerebras",
        "huggingface": "huggingface",
        "kimi-coding": "kimi-coding",
        "minimax": "minimax",
        "zai": "zai",
        "opencode": "opencode",
        "vercel-ai-gateway": "vercel-ai-gateway",
        "ollama": "ollama",
        "lmstudio": "lmstudio",
        "openai-codex": "openai-codex",
        "claude": "anthropic",  // Legacy alias — some policies use "claude" instead of "anthropic"
    ]

    /// Posted on the main thread when the background model catalog fetch completes.
    /// Views can observe this to refresh their model pickers.
    public static let catalogDidLoad = Notification.Name("ServiceCatalogDidLoad")

    /// Cached model catalog (loaded once per app launch from OpenClaw CLI).
    /// Protected by cacheLock — safe for concurrent access.
    nonisolated(unsafe) private static var _cachedModels: [String: [ModelOption]]?
    nonisolated(unsafe) private static var _fetchStarted = false
    private static let cacheLock = NSLock()

    /// Get models for a given scope. Uses OpenClaw's live model catalog.
    /// Returns an empty list until the background fetch completes.
    public static func modelsForScope(_ scope: String) -> [ModelOption] {
        let catalog = loadCatalogIfNeeded()
        return catalog[scope] ?? []
    }

    /// Load the full model catalog from OpenClaw (once, then cached).
    /// First call triggers a background fetch and returns empty immediately
    /// so the UI doesn't block. Subsequent calls return the cached catalog.
    private static func loadCatalogIfNeeded() -> [String: [ModelOption]] {
        cacheLock.lock()
        if let cached = _cachedModels {
            cacheLock.unlock()
            return cached
        }
        if !_fetchStarted {
            _fetchStarted = true
            cacheLock.unlock()
            // Fetch on a background thread, cache when done, notify UI
            DispatchQueue.global(qos: .userInitiated).async {
                let catalog = fetchOpenClawModels()
                // Debug: uncomment to verify catalog loading
                // print("[ServiceCatalog] Loaded \(catalog.count) scopes")
                cacheLock.lock()
                _cachedModels = catalog
                cacheLock.unlock()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: catalogDidLoad, object: nil)
                }
            }
            return [:]
        }
        cacheLock.unlock()
        return [:]  // Fetch in progress, not ready yet
    }

    /// Synchronously load the catalog (for use from background threads like sync).
    public static func loadCatalogSync() -> [String: [ModelOption]] {
        cacheLock.lock()
        if let cached = _cachedModels {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        let catalog = fetchOpenClawModels()
        cacheLock.lock()
        _cachedModels = catalog
        _fetchStarted = true
        cacheLock.unlock()
        return catalog
    }

    /// Force-refresh the model catalog (e.g. on user request or daily).
    public static func refreshModelCatalog() {
        cacheLock.lock()
        _cachedModels = nil
        _fetchStarted = false
        cacheLock.unlock()
    }

    /// Locate the openclaw binary. .app bundles have a minimal PATH,
    /// so we check common Homebrew / nvm / system locations explicitly.
    private static func findOpenClaw() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/openclaw",
            "/usr/local/bin/openclaw",
            "/usr/bin/openclaw",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    /// Fetch all models from `openclaw models list --all --json` and group by scope.
    private static func fetchOpenClawModels() -> [String: [ModelOption]] {
        guard let openclawURL = findOpenClaw() else { return [:] }

        let process = Process()
        process.executableURL = openclawURL
        process.arguments = ["models", "list", "--all", "--json"]
        // Ensure node can find its modules even inside a .app bundle
        var env = ProcessInfo.processInfo.environment
        let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin"]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (extraPaths + [currentPath]).joined(separator: ":")
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return [:]
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            return [:]
        }

        // Group models by OpenClaw provider prefix
        var byProvider: [String: [ModelOption]] = [:]
        for model in models {
            guard let key = model["key"] as? String,
                  let name = model["name"] as? String else { continue }
            let provider = key.split(separator: "/").first.map(String.init) ?? ""
            if provider.isEmpty { continue }
            let option = ModelOption(id: key, name: name)
            byProvider[provider, default: []].append(option)
        }

        // Mark the first model in each provider as the default
        for (provider, options) in byProvider {
            if !options.isEmpty {
                var updated = options
                updated[0] = ModelOption(id: updated[0].id, name: updated[0].name, isDefault: true)
                byProvider[provider] = updated
            }
        }

        // Build scope-keyed catalog using the scope→provider mapping
        var catalog: [String: [ModelOption]] = [:]
        for (scope, provider) in scopeToOpenClawProvider {
            if let options = byProvider[provider] {
                catalog[scope] = options
            }
        }

        // Ollama is local — fetch models from its API instead of the cloud catalog
        let ollamaModels = fetchOllamaModels()
        if !ollamaModels.isEmpty {
            catalog["ollama"] = ollamaModels
        }

        // LM Studio is local — fetch models from its OpenAI-compatible API
        let lmStudioModels = fetchLMStudioModels()
        if !lmStudioModels.isEmpty {
            catalog["lmstudio"] = lmStudioModels
        }

        return catalog
    }

    /// Fetch locally available models from Ollama's REST API (http://localhost:11434/api/tags).
    /// Returns an empty array if Ollama isn't running or has no models pulled.
    private static func fetchOllamaModels() -> [ModelOption] {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3  // Don't hang if Ollama isn't running

        // Synchronous fetch using semaphore (we're already on a background thread).
        // Use nonisolated(unsafe) to satisfy Swift 6 Sendable checking.
        nonisolated(unsafe) var result: [ModelOption] = []
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            defer { semaphore.signal() }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = json["models"] as? [[String: Any]] else {
                return
            }

            var options: [ModelOption] = []
            for model in models {
                guard let name = model["name"] as? String else { continue }
                // Ollama model names look like "llama3.2:3b"
                // Use "ollama/<name>" as the ID for consistency with other providers
                let id = "ollama/\(name)"
                options.append(ModelOption(id: id, name: name))
            }

            // Mark first as default
            if !options.isEmpty {
                options[0] = ModelOption(id: options[0].id, name: options[0].name, isDefault: true)
            }

            result = options
        }
        task.resume()
        semaphore.wait()

        return result
    }

    /// Fetch locally available models from LM Studio's OpenAI-compatible API (http://localhost:1234/v1/models).
    /// Returns an empty array if LM Studio isn't running or has no models loaded.
    private static func fetchLMStudioModels() -> [ModelOption] {
        guard let url = URL(string: "http://localhost:1234/v1/models") else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3  // Don't hang if LM Studio isn't running

        nonisolated(unsafe) var result: [ModelOption] = []
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            defer { semaphore.signal() }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = json["data"] as? [[String: Any]] else {
                return
            }

            var options: [ModelOption] = []
            for model in models {
                guard let modelId = model["id"] as? String else { continue }
                // Use "lmstudio/<id>" as the ID for consistency with other providers
                let id = "lmstudio/\(modelId)"
                options.append(ModelOption(id: id, name: modelId))
            }

            // Mark first as default
            if !options.isEmpty {
                options[0] = ModelOption(id: options[0].id, name: options[0].name, isDefault: true)
            }

            result = options
        }
        task.resume()
        semaphore.wait()

        return result
    }
}

/// A model option for a provider.
public struct ModelOption: Sendable, Identifiable, Hashable {
    public var id: String            // e.g. "openai/gpt-5.1-codex"
    public let name: String          // Display name
    public let isDefault: Bool       // Whether this is the recommended default

    public init(id: String, name: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
    }
}
