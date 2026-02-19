import Foundation
import OSLog

private let logger = Logger(subsystem: "com.clawapi", category: "OpenClawConfig")

/// Reads and writes OpenClaw's openclaw.json to manage the active model.
/// Supports both local and remote (SSH) modes via ConnectionSettings.
public enum OpenClawConfig {

    /// Posted when a sync write fails. The notification's `object` is the error message (String).
    public static let syncErrorNotification = Notification.Name("OpenClawConfigSyncError")

    /// Post a sync error notification on the main thread.
    private static func postSyncError(_ message: String) {
        logger.error("Sync error: \(message)")
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: syncErrorNotification, object: message)
        }
    }

    /// Current connection settings. Loaded once at startup, updated when the user changes settings.
    nonisolated(unsafe) public static var connectionSettings = ConnectionSettings.load()

    /// Path to OpenClaw's main config file (local mode).
    public static let configURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw")
            .appendingPathComponent("openclaw.json")
    }()

    // MARK: - File I/O Abstraction

    /// Read openclaw.json from local or remote.
    private static func readConfig() throws -> Data {
        if connectionSettings.mode == .remote {
            return try RemoteShell.readFile(
                path: connectionSettings.remoteConfigPath,
                settings: connectionSettings
            )
        }
        return try Data(contentsOf: configURL)
    }

    /// Write openclaw.json to local or remote.
    /// Creates a `.bak` backup before overwriting and validates JSON before writing.
    private static func writeConfig(_ data: Data) throws {
        // Validate: data must be valid JSON
        guard (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw ConfigError.parseFailed
        }

        if connectionSettings.mode == .remote {
            // Back up remote file before overwriting
            _ = try? RemoteShell.execute(
                command: "cp \(connectionSettings.remoteConfigPath) \(connectionSettings.remoteConfigPath).bak",
                settings: connectionSettings
            )
            try RemoteShell.writeFile(
                data: data,
                path: connectionSettings.remoteConfigPath,
                settings: connectionSettings
            )
        } else {
            // Back up local file before overwriting
            let bakURL = configURL.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: bakURL)
            try? FileManager.default.copyItem(at: configURL, to: bakURL)
            try data.write(to: configURL, options: .atomic)
        }
        logger.info("Wrote openclaw.json (backup saved as .bak)")
    }

    /// Read auth-profiles.json from local or remote.
    private static func readAuthProfiles() -> Data? {
        if connectionSettings.mode == .remote {
            return try? RemoteShell.readFile(
                path: connectionSettings.remoteAuthProfilesPath,
                settings: connectionSettings
            )
        }
        return try? Data(contentsOf: authProfilesURL)
    }

    /// Write auth-profiles.json to local or remote.
    /// Creates a `.bak` backup before overwriting and validates JSON before writing.
    private static func writeAuthProfiles(_ data: Data) throws {
        // Validate: data must be valid JSON
        guard (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw ConfigError.parseFailed
        }

        if connectionSettings.mode == .remote {
            // Back up remote file before overwriting
            _ = try? RemoteShell.execute(
                command: "cp \(connectionSettings.remoteAuthProfilesPath) \(connectionSettings.remoteAuthProfilesPath).bak",
                settings: connectionSettings
            )
            try RemoteShell.writeFile(
                data: data,
                path: connectionSettings.remoteAuthProfilesPath,
                settings: connectionSettings
            )
        } else {
            // Back up local file before overwriting
            let bakURL = authProfilesURL.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: bakURL)
            try? FileManager.default.copyItem(at: authProfilesURL, to: bakURL)
            try data.write(to: authProfilesURL, options: .atomic)
        }
        logger.info("Wrote auth-profiles.json (backup saved as .bak)")
    }

    // MARK: - Read

    /// Read the current primary model from OpenClaw's config.
    public static func currentModel() -> String? {
        guard let data = try? readConfig(),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let agents = json["agents"] as? [String: Any],
              let defaults = agents["defaults"] as? [String: Any],
              let model = defaults["model"] as? [String: Any],
              let primary = model["primary"] as? String else {
            return nil
        }
        return primary
    }

    /// Read the current fallback chain.
    public static func currentFallbacks() -> [String] {
        guard let data = try? readConfig(),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let agents = json["agents"] as? [String: Any],
              let defaults = agents["defaults"] as? [String: Any],
              let model = defaults["model"] as? [String: Any],
              let fallbacks = model["fallbacks"] as? [String] else {
            return []
        }
        return fallbacks
    }

    /// Check if OpenClaw config exists (local or remote).
    public static var isInstalled: Bool {
        if connectionSettings.mode == .remote {
            return connectionSettings.hasSSHCredentials &&
                RemoteShell.fileExists(path: connectionSettings.remoteConfigPath, settings: connectionSettings)
        }
        return FileManager.default.fileExists(atPath: configURL.path)
    }

    // MARK: - Write

    /// Set the primary model in OpenClaw's config.
    /// Moves the old primary to the top of the fallback chain.
    public static func setPrimaryModel(_ newModel: String) throws {
        guard isInstalled else {
            throw ConfigError.notInstalled
        }

        guard let data = try? readConfig() else {
            throw ConfigError.readFailed
        }

        guard var json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
            throw ConfigError.parseFailed
        }

        // Navigate to agents.defaults.model
        var agents = json["agents"] as? [String: Any] ?? [:]
        var defaults = agents["defaults"] as? [String: Any] ?? [:]
        var model = defaults["model"] as? [String: Any] ?? [:]
        var fallbacks = model["fallbacks"] as? [String] ?? []

        let oldPrimary = model["primary"] as? String

        // Don't change if already set
        if oldPrimary == newModel {
            logger.info("Model already set to \(newModel)")
            return
        }

        // Remove new model from fallbacks if it's already there
        fallbacks.removeAll { $0 == newModel }

        // Insert old primary at top of fallbacks (if it was set)
        if let old = oldPrimary, !old.isEmpty {
            fallbacks.insert(old, at: 0)
        }

        // Set new primary
        model["primary"] = newModel
        model["fallbacks"] = fallbacks
        defaults["model"] = model
        agents["defaults"] = defaults
        json["agents"] = agents

        // Update meta timestamp
        var meta = json["meta"] as? [String: Any] ?? [:]
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        meta["lastTouchedAt"] = fmt.string(from: Date())
        json["meta"] = meta

        // Write
        let newData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try writeConfig(newData)

        logger.info("Switched OpenClaw model: \(oldPrimary ?? "none") → \(newModel)")
    }

    /// Set the primary model and managed fallbacks in OpenClaw's config.
    /// Managed fallbacks (from ClawAPI providers) are placed at the front
    /// of the fallback chain; any existing non-managed fallbacks are preserved after them.
    /// `managedPrefixes` are provider prefixes (e.g. "openai/", "xai/") — any existing
    /// fallback whose ID starts with a managed prefix is removed (prevents stale models).
    public static func setPrimaryModelAndFallbacks(_ newModel: String, fallbacks managedFallbacks: [String], managedPrefixes: Set<String> = []) throws {
        guard isInstalled else { throw ConfigError.notInstalled }
        guard let data = try? readConfig() else { throw ConfigError.readFailed }
        guard var json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else { throw ConfigError.parseFailed }

        var agents = json["agents"] as? [String: Any] ?? [:]
        var defaults = agents["defaults"] as? [String: Any] ?? [:]
        var model = defaults["model"] as? [String: Any] ?? [:]
        let existingFallbacks = model["fallbacks"] as? [String] ?? []

        let oldPrimary = model["primary"] as? String

        // All models we explicitly manage (primary + fallbacks)
        let managedSet = Set([newModel] + managedFallbacks)

        // Preserve non-managed fallbacks (user's own models in OpenClaw).
        let preservedFallbacks = existingFallbacks.filter { fb in
            if managedSet.contains(fb) { return false }
            for prefix in managedPrefixes {
                if fb.hasPrefix(prefix) { return false }
            }
            return true
        }

        // Build final fallback chain: our managed fallbacks first, then preserved ones
        let finalFallbacks = managedFallbacks + preservedFallbacks

        // Check if anything actually changed
        if oldPrimary == newModel && existingFallbacks == finalFallbacks {
            logger.info("Model and fallbacks already up to date")
            return
        }

        model["primary"] = newModel
        model["fallbacks"] = finalFallbacks
        defaults["model"] = model
        agents["defaults"] = defaults
        json["agents"] = agents

        var meta = json["meta"] as? [String: Any] ?? [:]
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        meta["lastTouchedAt"] = fmt.string(from: Date())
        json["meta"] = meta

        let newData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try writeConfig(newData)

        logger.info("Set OpenClaw model: \(newModel), fallbacks: \(finalFallbacks.joined(separator: ", "))")
    }

    /// Add a model to the fallback chain (if not already present).
    public static func addFallback(_ model: String) throws {
        guard isInstalled else { throw ConfigError.notInstalled }
        guard let data = try? readConfig() else { throw ConfigError.readFailed }
        guard var json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else { throw ConfigError.parseFailed }

        var agents = json["agents"] as? [String: Any] ?? [:]
        var defaults = agents["defaults"] as? [String: Any] ?? [:]
        var modelConfig = defaults["model"] as? [String: Any] ?? [:]
        var fallbacks = modelConfig["fallbacks"] as? [String] ?? []

        let primary = modelConfig["primary"] as? String
        guard model != primary else { return } // Already the primary
        guard !fallbacks.contains(model) else { return } // Already a fallback

        fallbacks.append(model)
        modelConfig["fallbacks"] = fallbacks
        defaults["model"] = modelConfig
        agents["defaults"] = defaults
        json["agents"] = agents

        let newData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try writeConfig(newData)

        logger.info("Added \(model) to OpenClaw fallback chain")
    }

    // MARK: - Auth Profile Sync

    /// Path to OpenClaw's agent-level auth profiles (local mode).
    public static let authProfilesURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw")
            .appendingPathComponent("agents/main/agent/auth-profiles.json")
    }()

    /// Map ClawAPI scopes to OpenClaw provider names for auth profile injection.
    private static let scopeToProvider: [String: String] = [
        "openai": "openai",
        "anthropic": "anthropic",
        "claude": "anthropic",
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
    ]

    /// Look up the OpenClaw provider for a scope, matching on the base name
    /// (e.g. "openai:completions" → "openai" → provider "openai").
    private static func providerForScope(_ scope: String) -> String? {
        if let direct = scopeToProvider[scope] { return direct }
        let base = scope.split(separator: ":").first.map(String.init) ?? scope
        return scopeToProvider[base]
    }

    /// Required provider routing info: baseUrl and API type.
    private static let providerConfig: [String: (baseUrl: String, api: String)] = [
        "openai":              ("https://api.openai.com/v1",                "openai-completions"),
        "anthropic":           ("https://api.anthropic.com",                "anthropic-messages"),
        "xai":                 ("https://api.x.ai/v1",                     "openai-completions"),
        "google":              ("https://generativelanguage.googleapis.com", "google-genai"),
        "mistral":             ("https://api.mistral.ai/v1",               "openai-completions"),
        "groq":                ("https://api.groq.com/openai/v1",          "openai-completions"),
        "openrouter":          ("https://openrouter.ai/api/v1",            "openai-completions"),
        "cerebras":            ("https://api.cerebras.ai/v1",              "openai-completions"),
        "kimi-coding":         ("https://api.moonshot.ai/v1",              "openai-completions"),
        "minimax":             ("https://api.minimax.chat/v1",             "openai-completions"),
        "zai":                 ("https://api.z.ai/v1",                     "openai-completions"),
        "opencode":            ("https://api.opencode.ai/v1",             "openai-completions"),
        "vercel-ai-gateway":   ("https://sdk.vercel.ai/v1",               "openai-completions"),
        "huggingface":         ("https://api-inference.huggingface.co",    "openai-completions"),
        "ollama":              ("http://localhost:11434",                   "openai-responses"),
        "lmstudio":            ("http://localhost:1234/v1",                "openai-completions"),
    ]

    /// Map ClawAPI scopes to the default model.
    private static let scopeToDefaultModel: [String: String] = [
        "openai": "openai/gpt-4.1",
        "anthropic": "anthropic/claude-sonnet-4-5",
        "claude": "anthropic/claude-sonnet-4-5",
        "xai": "xai/grok-4-fast",
        "google-ai": "google/gemini-2.5-pro",
        "groq": "groq/meta-llama/llama-4-scout-17b-16e-instruct",
        "mistral": "mistral/mistral-large-latest",
        "openrouter": "openrouter/auto",
        "cerebras": "cerebras/llama-4-scout-17b-16e-instruct",
        "kimi-coding": "kimi-coding/moonshot-v1-auto",
        "minimax": "minimax/MiniMax-M1",
        "zai": "zai/glm-4-flash",
        "opencode": "opencode/opencode-latest",
        "vercel-ai-gateway": "vercel-ai-gateway/auto",
        "huggingface": "huggingface/meta-llama/Llama-3.3-70B-Instruct",
        "ollama": "ollama/llama3.2:3b",
        "lmstudio": "lmstudio/default",
    ]

    /// Whether a scope requires an API key.
    private static func requiresKey(scope: String) -> Bool {
        ServiceCatalog.find(scope)?.requiresKey ?? true
    }

    /// Check if any enabled provider that requires a key is missing an auth profile.
    /// Keyless providers (like Ollama) are excluded — they don't need Keychain access.
    public static func needsAuthProfileSync(policies: [ScopePolicy]) -> Bool {
        guard isInstalled else { return false }

        // Only check providers that require an API key
        let enabled = policies
            .filter { $0.isEnabled && $0.hasSecret && requiresKey(scope: $0.scope) && $0.approvalMode == .auto }

        guard !enabled.isEmpty else { return false }

        // Read existing auth-profiles
        guard let data = readAuthProfiles(),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profiles = parsed["profiles"] as? [String: Any] else {
            return enabled.contains { providerForScope($0.scope) != nil }
        }

        for policy in enabled {
            guard let provider = providerForScope(policy.scope) else { continue }
            let profileKey = "\(provider):default"
            if profiles[profileKey] == nil {
                return true
            }
        }
        return false
    }

    /// Build provider prefixes from enabled scopes.
    private static func managedProviderPrefixes(from enabledScopes: Set<String>) -> Set<String> {
        var prefixes = Set<String>()
        for scope in enabledScopes {
            if let provider = providerForScope(scope) {
                prefixes.insert("\(provider)/")
            }
        }
        return prefixes
    }

    /// Resolve the model to use for a given policy.
    private static func resolvedModel(for policy: ScopePolicy) -> String? {
        if let selected = policy.selectedModel, !selected.isEmpty {
            return selected
        }
        if let direct = scopeToDefaultModel[policy.scope] { return direct }
        let base = policy.scope.split(separator: ":").first.map(String.init) ?? policy.scope
        return scopeToDefaultModel[base]
    }

    /// Lightweight sync that only updates the primary model and provider
    /// definitions in openclaw.json — does NOT touch the keychain or
    /// auth-profiles.json (except for keyless providers like Ollama).
    public static func syncModelOnly(policies: [ScopePolicy]) {
        guard isInstalled else { return }

        let enabled = policies
            .filter { $0.isEnabled && ($0.hasSecret || !requiresKey(scope: $0.scope)) && $0.approvalMode == .auto }
            .sorted { $0.priority < $1.priority }

        var orderedModels: [String] = []
        for policy in enabled {
            if let model = resolvedModel(for: policy), !orderedModels.contains(model) {
                orderedModels.append(model)
            }
        }

        guard let topModel = orderedModels.first else { return }
        let fallbackModels = Array(orderedModels.dropFirst())
        let enabledScopes = Set(enabled.map(\.scope))

        // Ensure keyless providers (like Ollama) have their auth profile
        // without touching the Keychain
        syncKeylessProfiles(policies: enabled)

        // Create provider entries for providers not already in openclaw.json
        // (e.g. MiniMax, Groq — providers that aren't OpenClaw built-ins).
        syncProviderDefinitions(enabledScopes: enabledScopes, createIfMissing: true)

        do {
            try setPrimaryModelAndFallbacks(topModel, fallbacks: fallbackModels,
                                            managedPrefixes: managedProviderPrefixes(from: enabledScopes))
        } catch {
            postSyncError("Failed to set primary model: \(error.localizedDescription)")
        }

    }

    /// Sync ClawAPI's enabled providers into OpenClaw's auth-profiles.json.
    public static func syncToOpenClaw(
        policies: [ScopePolicy],
        keychain: KeychainService
    ) {
        guard isInstalled else {
            logger.warning("OpenClaw not installed, skipping sync")
            return
        }

        let enabled = policies
            .filter { $0.isEnabled && ($0.hasSecret || !requiresKey(scope: $0.scope)) && $0.approvalMode == .auto }
            .sorted { $0.priority < $1.priority }

        // Read existing auth-profiles (preserve profiles we don't manage)
        var authDoc: [String: Any]
        if let data = readAuthProfiles(),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            authDoc = parsed
        } else {
            authDoc = ["version": 1, "profiles": [:] as [String: Any], "lastGood": [:] as [String: Any], "usageStats": [:] as [String: Any]]
        }

        var profiles = authDoc["profiles"] as? [String: Any] ?? [:]
        var lastGood = authDoc["lastGood"] as? [String: Any] ?? [:]
        var usageStats = authDoc["usageStats"] as? [String: Any] ?? [:]

        var orderedModels: [String] = []
        for policy in enabled {
            if let model = resolvedModel(for: policy), !orderedModels.contains(model) {
                orderedModels.append(model)
            }
        }

        for policy in enabled {
            guard let provider = providerForScope(policy.scope) else { continue }

            let profileKey = "\(provider):default"

            if requiresKey(scope: policy.scope) {
                guard let key = try? keychain.retrieveString(forScope: policy.scope) else { continue }
                profiles[profileKey] = [
                    "type": "api_key",
                    "provider": provider,
                    "key": key,
                ] as [String: Any]
            } else {
                profiles[profileKey] = [
                    "type": "none",
                    "provider": provider,
                ] as [String: Any]
            }

            lastGood[provider] = profileKey
            usageStats[profileKey] = [
                "lastUsed": 0,
                "errorCount": 0,
            ] as [String: Any]

            logger.info("Synced \(policy.scope) → OpenClaw \(provider):default")
        }

        // Remove profiles for providers that are no longer enabled
        let enabledScopes = Set(enabled.map(\.scope))
        var checkedProviders = Set<String>()
        for (scope, provider) in scopeToProvider {
            guard !checkedProviders.contains(provider) else { continue }
            checkedProviders.insert(provider)

            let profileKey = "\(provider):default"
            let providerHasEnabledScope = enabledScopes.contains { providerForScope($0) == provider }

            if !providerHasEnabledScope && profiles[profileKey] != nil {
                if let prof = profiles[profileKey] as? [String: Any],
                   prof["type"] as? String == "api_key" {
                    profiles.removeValue(forKey: profileKey)
                    lastGood.removeValue(forKey: provider)
                    usageStats.removeValue(forKey: profileKey)
                    logger.info("Removed disabled provider \(provider) from OpenClaw auth")
                }
            }
            _ = scope
        }

        authDoc["profiles"] = profiles
        authDoc["lastGood"] = lastGood
        authDoc["usageStats"] = usageStats

        // Write auth-profiles
        do {
            let data = try JSONSerialization.data(withJSONObject: authDoc, options: [.prettyPrinted, .sortedKeys])
            try writeAuthProfiles(data)
            logger.info("Wrote OpenClaw auth-profiles.json")
        } catch {
            postSyncError("Failed to write auth-profiles.json: \(error.localizedDescription)")
            return
        }

        // Create provider entries for providers not already in openclaw.json
        // (e.g. MiniMax, Groq — providers that aren't OpenClaw built-ins).
        syncProviderDefinitions(enabledScopes: enabledScopes, createIfMissing: true)

        if let topModel = orderedModels.first {
            let fallbackModels = Array(orderedModels.dropFirst())
            do {
                try setPrimaryModelAndFallbacks(topModel, fallbacks: fallbackModels,
                                                managedPrefixes: managedProviderPrefixes(from: enabledScopes))
            } catch {
                postSyncError("Failed to set primary model: \(error.localizedDescription)")
            }
        }

    }

    /// Ensure keyless providers (like Ollama) have an auth profile entry
    /// without ever touching the Keychain. This prevents `needsAuthProfileSync`
    /// from returning `true` just because a keyless provider is missing.
    private static func syncKeylessProfiles(policies: [ScopePolicy]) {
        let keyless = policies.filter { !requiresKey(scope: $0.scope) }
        guard !keyless.isEmpty else { return }

        // Read existing auth-profiles
        var authDoc: [String: Any]
        if let data = readAuthProfiles(),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            authDoc = parsed
        } else {
            authDoc = [
                "version": 1,
                "profiles": [:] as [String: Any],
                "lastGood": [:] as [String: Any],
                "usageStats": [:] as [String: Any],
            ]
        }

        var profiles = authDoc["profiles"] as? [String: Any] ?? [:]
        var lastGood = authDoc["lastGood"] as? [String: Any] ?? [:]
        var usageStats = authDoc["usageStats"] as? [String: Any] ?? [:]
        var changed = false

        for policy in keyless {
            guard let provider = providerForScope(policy.scope) else { continue }
            let profileKey = "\(provider):default"

            // Only add if missing — never overwrite an existing profile
            if profiles[profileKey] == nil {
                profiles[profileKey] = [
                    "type": "none",
                    "provider": provider,
                ] as [String: Any]
                lastGood[provider] = profileKey
                usageStats[profileKey] = [
                    "lastUsed": 0,
                    "errorCount": 0,
                ] as [String: Any]
                changed = true
                logger.info("Added keyless profile for \(provider)")
            }
        }

        guard changed else { return }

        authDoc["profiles"] = profiles
        authDoc["lastGood"] = lastGood
        authDoc["usageStats"] = usageStats

        do {
            let data = try JSONSerialization.data(withJSONObject: authDoc, options: [.prettyPrinted, .sortedKeys])
            try writeAuthProfiles(data)
            logger.info("Updated auth-profiles.json with keyless providers")
        } catch {
            postSyncError("Failed to write keyless profiles: \(error.localizedDescription)")
        }
    }

    // MARK: - Gateway Restart

    /// Manually restart the OpenClaw gateway so it reloads config from disk.
    /// Uses SIGHUP for instant hot-reload without dropping WebSocket connections.
    /// Falls back to a full restart if SIGHUP fails.
    /// Returns true if the restart signal was sent successfully.
    @discardableResult
    public static func restartGateway() -> Bool {
        guard isInstalled else { return false }

        if connectionSettings.mode == .remote {
            do {
                let sighup = try RemoteShell.execute(
                    command: "bash -lc 'pkill -HUP -f openclaw-gateway'",
                    settings: connectionSettings
                )
                if sighup.exitCode == 0 {
                    logger.info("Sent SIGHUP to remote OpenClaw gateway")
                    return true
                }
                let result = try RemoteShell.execute(
                    command: "bash -lc 'openclaw gateway restart'",
                    settings: connectionSettings
                )
                if result.exitCode == 0 {
                    logger.info("Restarted remote OpenClaw gateway (fallback)")
                    return true
                }
                logger.warning("Remote gateway restart exited \(result.exitCode)")
            } catch {
                logger.warning("Could not reload remote OpenClaw gateway: \(error.localizedDescription)")
            }
            return false
        } else {
            let sighup = Process()
            sighup.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            sighup.arguments = ["-HUP", "-f", "openclaw-gateway"]
            sighup.standardOutput = FileHandle.nullDevice
            sighup.standardError = FileHandle.nullDevice
            do {
                try sighup.run()
                sighup.waitUntilExit()
                if sighup.terminationStatus == 0 {
                    logger.info("Sent SIGHUP to OpenClaw gateway (hot reload)")
                    return true
                }
            } catch { }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-lc", "openclaw gateway restart"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    logger.info("Restarted OpenClaw gateway (fallback)")
                    return true
                }
            } catch {
                logger.warning("Could not restart OpenClaw gateway: \(error.localizedDescription)")
            }
            return false
        }
    }

    // MARK: - Provider Definitions Sync

    /// Ensure openclaw.json has correct baseUrl entries for enabled providers.
    private static func syncProviderDefinitions(enabledScopes: Set<String>, createIfMissing: Bool = false) {
        guard let data = try? readConfig(),
              var json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
            return
        }

        var modelsSection = json["models"] as? [String: Any] ?? [:]
        var providers = modelsSection["providers"] as? [String: Any] ?? [:]
        var changed = false

        for scope in enabledScopes {
            guard let providerName = providerForScope(scope),
                  let config = providerConfig[providerName] else { continue }

            if var entry = providers[providerName] as? [String: Any] {
                // Update existing provider if baseUrl/api needs fixing
                let currentBase = entry["baseUrl"] as? String
                let currentApi = entry["api"] as? String

                let needsFix = currentBase != config.baseUrl
                    || currentApi != config.api
                    || currentBase?.contains("127.0.0.1") == true
                    || currentBase?.contains("localhost") == true

                if needsFix {
                    entry["baseUrl"] = config.baseUrl
                    entry["api"] = config.api
                    providers[providerName] = entry
                    changed = true
                    logger.info("Fixed OpenClaw provider \(providerName) → \(config.baseUrl) (\(config.api))")
                }
            } else if createIfMissing {
                // Create a new provider entry with an empty (but valid) models array.
                // Only used by Clean Slate where we know the provider must exist.
                providers[providerName] = [
                    "baseUrl": config.baseUrl,
                    "api": config.api,
                    "models": [] as [Any],
                ] as [String: Any]
                changed = true
                logger.info("Created OpenClaw provider \(providerName) → \(config.baseUrl) (\(config.api))")
            }
        }

        guard changed else { return }

        modelsSection["providers"] = providers
        json["models"] = modelsSection

        do {
            let newData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            try writeConfig(newData)
        } catch {
            postSyncError("Failed to write provider definitions: \(error.localizedDescription)")
        }
    }

    // MARK: - Clean Slate

    /// Directory where Clean Slate backups are stored.
    private static var backupDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw")
            .appendingPathComponent("clawapi-backups")
    }

    /// Perform a Clean Slate: back up current OpenClaw config files, then
    /// rewrite them so only the single chosen model and its auth profile remain.
    /// All fallbacks and other provider auth profiles are removed.
    /// Returns the backup folder name on success.
    public static func cleanSlate(policies: [ScopePolicy], keychain: KeychainService) throws -> String {
        guard isInstalled else { throw ConfigError.notInstalled }

        // Determine the primary provider (top-priority enabled + auto)
        let enabled = policies
            .filter { $0.isEnabled && ($0.hasSecret || !requiresKey(scope: $0.scope)) && $0.approvalMode == .auto }
            .sorted { $0.priority < $1.priority }

        guard let topPolicy = enabled.first,
              let topModel = resolvedModel(for: topPolicy) else {
            throw ConfigError.cleanSlateNoProvider
        }

        // --- 1. Create timestamped backup ---
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HHmmss"
        let backupName = "backup-\(fmt.string(from: Date()))"
        let backupDir = backupDirectory.appendingPathComponent(backupName)
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        if connectionSettings.mode == .remote {
            // Back up remote files locally
            if let configData = try? readConfig() {
                try configData.write(to: backupDir.appendingPathComponent("openclaw.json"))
            }
            if let authData = readAuthProfiles() {
                try authData.write(to: backupDir.appendingPathComponent("auth-profiles.json"))
            }
        } else {
            // Copy local files
            let fm = FileManager.default
            if fm.fileExists(atPath: configURL.path) {
                try fm.copyItem(at: configURL, to: backupDir.appendingPathComponent("openclaw.json"))
            }
            if fm.fileExists(atPath: authProfilesURL.path) {
                try fm.copyItem(at: authProfilesURL, to: backupDir.appendingPathComponent("auth-profiles.json"))
            }
        }

        logger.info("Clean Slate backup saved to \(backupName)")

        // --- 2. Rewrite openclaw.json with no fallbacks ---
        do {
            try setPrimaryModelAndFallbacks(topModel, fallbacks: [], managedPrefixes: [])
        } catch {
            throw ConfigError.cleanSlateFailed("Failed to set model: \(error.localizedDescription)")
        }

        // --- 3. Rewrite auth-profiles.json with only the active provider ---
        guard let topProvider = providerForScope(topPolicy.scope) else {
            throw ConfigError.cleanSlateFailed("Unknown provider for scope \(topPolicy.scope)")
        }

        let profileKey = "\(topProvider):default"
        var profile: [String: Any]

        if requiresKey(scope: topPolicy.scope) {
            guard let key = try? keychain.retrieveString(forScope: topPolicy.scope) else {
                throw ConfigError.cleanSlateFailed("Could not read API key from Keychain for \(topPolicy.scope)")
            }
            profile = [
                "type": "api_key",
                "provider": topProvider,
                "key": key,
            ]
        } else {
            profile = [
                "type": "none",
                "provider": topProvider,
            ]
        }

        let authDoc: [String: Any] = [
            "version": 1,
            "profiles": [profileKey: profile],
            "lastGood": [topProvider: profileKey],
            "usageStats": [profileKey: ["lastUsed": 0, "errorCount": 0]],
        ]

        let authData = try JSONSerialization.data(withJSONObject: authDoc, options: [.prettyPrinted, .sortedKeys])
        try writeAuthProfiles(authData)

        // --- 4. Sync provider definitions for just this one provider ---
        // createIfMissing: true because the chosen provider may not already exist
        // in openclaw.json (e.g. MiniMax, Groq, etc. are not built-in providers).
        syncProviderDefinitions(enabledScopes: Set([topPolicy.scope]), createIfMissing: true)

        logger.info("Clean Slate complete: only \(topModel) via \(topProvider) remains")
        return backupName
    }

    /// List available Clean Slate backups, newest first.
    public static func listBackups() -> [(name: String, date: Date)] {
        let fm = FileManager.default
        let dir = backupDirectory
        guard let contents = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HHmmss"

        var results: [(name: String, date: Date)] = []
        for name in contents where name.hasPrefix("backup-") {
            let dateStr = String(name.dropFirst("backup-".count))
            if let date = fmt.date(from: dateStr) {
                results.append((name, date))
            }
        }
        return results.sorted { $0.date > $1.date }
    }

    /// Restore OpenClaw config files from a Clean Slate backup.
    public static func restoreBackup(name: String) throws {
        guard isInstalled else { throw ConfigError.notInstalled }

        let backupDir = backupDirectory.appendingPathComponent(name)
        let fm = FileManager.default

        guard fm.fileExists(atPath: backupDir.path) else {
            throw ConfigError.cleanSlateFailed("Backup \(name) not found")
        }

        let configBackup = backupDir.appendingPathComponent("openclaw.json")
        let authBackup = backupDir.appendingPathComponent("auth-profiles.json")

        if fm.fileExists(atPath: configBackup.path) {
            let data = try Data(contentsOf: configBackup)
            try writeConfig(data)
            logger.info("Restored openclaw.json from \(name)")
        }

        if fm.fileExists(atPath: authBackup.path) {
            let data = try Data(contentsOf: authBackup)
            try writeAuthProfiles(data)
            logger.info("Restored auth-profiles.json from \(name)")
        }

        logger.info("Backup \(name) restored successfully")
    }

    /// Delete a Clean Slate backup.
    public static func deleteBackup(name: String) {
        let backupDir = backupDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: backupDir)
        logger.info("Deleted backup \(name)")
    }

    // MARK: - Errors

    public enum ConfigError: LocalizedError {
        case notInstalled
        case readFailed
        case parseFailed
        case cleanSlateNoProvider
        case cleanSlateFailed(String)

        public var errorDescription: String? {
            switch self {
            case .notInstalled: "OpenClaw config not found at ~/.openclaw/openclaw.json"
            case .readFailed: "Failed to read OpenClaw config file"
            case .parseFailed: "Failed to parse OpenClaw config as JSON"
            case .cleanSlateNoProvider: "No enabled provider to keep — enable at least one provider first"
            case .cleanSlateFailed(let detail): "Clean Slate failed: \(detail)"
            }
        }
    }
}
