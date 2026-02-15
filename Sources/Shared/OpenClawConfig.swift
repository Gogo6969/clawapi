import Foundation
import OSLog

private let logger = Logger(subsystem: "com.clawapi", category: "OpenClawConfig")

/// Reads and writes OpenClaw's openclaw.json to manage the active model.
/// Supports both local and remote (SSH) modes via ConnectionSettings.
public enum OpenClawConfig {

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
    private static func writeConfig(_ data: Data) throws {
        if connectionSettings.mode == .remote {
            try RemoteShell.writeFile(
                data: data,
                path: connectionSettings.remoteConfigPath,
                settings: connectionSettings
            )
        } else {
            try data.write(to: configURL, options: .atomic)
        }
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
    private static func writeAuthProfiles(_ data: Data) throws {
        if connectionSettings.mode == .remote {
            try RemoteShell.writeFile(
                data: data,
                path: connectionSettings.remoteAuthProfilesPath,
                settings: connectionSettings
            )
        } else {
            try data.write(to: authProfilesURL, options: .atomic)
        }
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
        "ollama": "ollama",
    ]

    /// Required provider routing info: baseUrl and API type.
    private static let providerConfig: [String: (baseUrl: String, api: String)] = [
        "openai":    ("https://api.openai.com/v1", "openai-completions"),
        "anthropic": ("https://api.anthropic.com",  "anthropic-messages"),
        "xai":       ("https://api.x.ai/v1",        "openai-completions"),
        "ollama":    ("http://localhost:11434",      "openai-responses"),
    ]

    /// Map ClawAPI scopes to the default model.
    private static let scopeToDefaultModel: [String: String] = [
        "openai": "openai/gpt-4.1",
        "anthropic": "anthropic/claude-sonnet-4-5",
        "claude": "anthropic/claude-sonnet-4-5",
        "xai": "xai/grok-4-fast",
        "groq": "groq/meta-llama/llama-4-scout-17b-16e-instruct",
        "mistral": "mistral/mistral-large-latest",
        "ollama": "ollama/llama3.2:3b",
    ]

    /// Whether a scope requires an API key.
    private static func requiresKey(scope: String) -> Bool {
        ServiceCatalog.find(scope)?.requiresKey ?? true
    }

    /// Check if any enabled provider is missing an auth profile in OpenClaw.
    public static func needsAuthProfileSync(policies: [ScopePolicy]) -> Bool {
        guard isInstalled else { return false }

        let enabled = policies
            .filter { $0.isEnabled && ($0.hasSecret || !requiresKey(scope: $0.scope)) && $0.approvalMode == .auto }

        // Read existing auth-profiles
        guard let data = readAuthProfiles(),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profiles = parsed["profiles"] as? [String: Any] else {
            return enabled.contains { scopeToProvider[$0.scope] != nil }
        }

        for policy in enabled {
            guard let provider = scopeToProvider[policy.scope] else { continue }
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
            if let provider = scopeToProvider[scope] {
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
        return scopeToDefaultModel[policy.scope]
    }

    /// Lightweight sync that only updates the primary model and provider
    /// definitions in openclaw.json — does NOT touch the keychain or
    /// auth-profiles.json.
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

        syncProviderDefinitions(enabledScopes: enabledScopes)

        do {
            try setPrimaryModelAndFallbacks(topModel, fallbacks: fallbackModels,
                                            managedPrefixes: managedProviderPrefixes(from: enabledScopes))
        } catch {
            logger.error("Failed to set primary model: \(error)")
        }

        restartGateway()
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
            guard let provider = scopeToProvider[policy.scope] else { continue }

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
            let providerHasEnabledScope = scopeToProvider
                .filter { $0.value == provider }
                .keys
                .contains { enabledScopes.contains($0) }

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
            logger.error("Failed to write auth-profiles.json: \(error)")
            return
        }

        syncProviderDefinitions(enabledScopes: enabledScopes)

        if let topModel = orderedModels.first {
            let fallbackModels = Array(orderedModels.dropFirst())
            do {
                try setPrimaryModelAndFallbacks(topModel, fallbacks: fallbackModels,
                                                managedPrefixes: managedProviderPrefixes(from: enabledScopes))
            } catch {
                logger.error("Failed to set primary model: \(error)")
            }
        }

        restartGateway()
    }

    // MARK: - Gateway Restart

    /// Restart OpenClaw's gateway so it reloads config from disk.
    /// Runs in background to avoid blocking the UI.
    private static func restartGateway() {
        DispatchQueue.global(qos: .utility).async {
            if connectionSettings.mode == .remote {
                // Remote: restart via SSH
                do {
                    let result = try RemoteShell.execute(
                        command: "bash -lc 'openclaw gateway restart'",
                        settings: connectionSettings
                    )
                    if result.exitCode == 0 {
                        logger.info("Restarted remote OpenClaw gateway")
                    } else {
                        logger.warning("Remote OpenClaw gateway restart exited with \(result.exitCode): \(result.stderr)")
                    }
                } catch {
                    logger.warning("Could not restart remote OpenClaw gateway: \(error.localizedDescription)")
                }
            } else {
                // Local: run process directly
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["openclaw", "gateway", "restart"]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 {
                        logger.info("Restarted OpenClaw gateway")
                    } else {
                        logger.warning("OpenClaw gateway restart exited with \(process.terminationStatus)")
                    }
                } catch {
                    logger.warning("Could not restart OpenClaw gateway: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Provider Definitions Sync

    /// Ensure openclaw.json has correct baseUrl entries for enabled providers.
    private static func syncProviderDefinitions(enabledScopes: Set<String>) {
        guard let data = try? readConfig(),
              var json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
            return
        }

        var modelsSection = json["models"] as? [String: Any] ?? [:]
        var providers = modelsSection["providers"] as? [String: Any] ?? [:]
        var changed = false

        for scope in enabledScopes {
            guard let providerName = scopeToProvider[scope],
                  let config = providerConfig[providerName] else { continue }

            var entry = providers[providerName] as? [String: Any] ?? [:]
            let currentBase = entry["baseUrl"] as? String
            let currentApi = entry["api"] as? String

            let needsFix = currentBase == nil
                || currentBase != config.baseUrl
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
        }

        guard changed else { return }

        modelsSection["providers"] = providers
        json["models"] = modelsSection

        do {
            let newData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            try writeConfig(newData)
        } catch {
            logger.error("Failed to write provider definitions: \(error)")
        }
    }

    // MARK: - Errors

    public enum ConfigError: LocalizedError {
        case notInstalled
        case readFailed
        case parseFailed

        public var errorDescription: String? {
            switch self {
            case .notInstalled: "OpenClaw config not found at ~/.openclaw/openclaw.json"
            case .readFailed: "Failed to read OpenClaw config file"
            case .parseFailed: "Failed to parse OpenClaw config as JSON"
            }
        }
    }
}
