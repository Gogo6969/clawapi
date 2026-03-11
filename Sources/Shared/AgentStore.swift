import Foundation
import OSLog

private let logger = Logger(subsystem: "com.clawapi", category: "AgentStore")

/// Manages OpenClaw agent configurations and channel bindings.
/// Reads/writes directly to `~/.openclaw/openclaw.json` via `OpenClawConfig`.
/// Self-contained — does not depend on PolicyStore.
@MainActor
public final class AgentStore: ObservableObject {
    @Published public var agents: [AgentConfig] = []
    @Published public var bindings: [ChannelBinding] = []
    @Published public var defaultsPrimary: String?
    @Published public var defaultsFallbacks: [String] = []
    @Published public var syncError: String?

    public init() {
        load()
    }

    // MARK: - Load

    /// Reload all agents and bindings from OpenClaw config.
    public func load() {
        let result = OpenClawConfig.readAgents()
        agents = result.agents
        bindings = result.bindings
        defaultsPrimary = result.defaultsPrimary
        defaultsFallbacks = result.defaultsFallbacks
        mergeEmoji()
        logger.info("Loaded \(result.agents.count) agents, \(result.bindings.count) bindings")
    }

    // MARK: - Save

    /// Write current agents and bindings to OpenClaw config.
    public func save() {
        do {
            try OpenClawConfig.writeAgentsAndBindings(agents: agents, bindings: bindings)
            saveEmojiMap()
            syncError = nil
            logger.info("Saved \(self.agents.count) agents, \(self.bindings.count) bindings")
        } catch {
            syncError = error.localizedDescription
            logger.error("Save failed: \(error.localizedDescription)")
            // Auto-clear error after 10 seconds
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(10))
                if syncError == error.localizedDescription {
                    syncError = nil
                }
            }
        }
    }

    // MARK: - Agent CRUD

    /// Create a new agent and persist it.
    public func createAgent(
        id: String,
        name: String,
        emoji: String = "🤖",
        primaryModel: String? = nil,
        workspace: String? = nil
    ) {
        // Ensure no duplicate IDs
        guard !agents.contains(where: { $0.id == id }) else {
            syncError = "Agent with ID '\(id)' already exists"
            return
        }

        let isFirst = agents.isEmpty
        let agent = AgentConfig(
            id: id,
            name: name,
            emoji: emoji,
            isDefault: isFirst, // First agent becomes default
            primaryModel: primaryModel,
            workspace: workspace
        )

        agents.append(agent)
        save()

        // Create agent directory structure
        do {
            try OpenClawConfig.createAgentDirectory(agentId: id)
        } catch {
            logger.warning("Could not create agent directory: \(error.localizedDescription)")
        }
    }

    /// Update an existing agent's configuration.
    public func updateAgent(_ agent: AgentConfig) {
        guard let index = agents.firstIndex(where: { $0.id == agent.id }) else {
            syncError = "Agent '\(agent.id)' not found"
            return
        }

        // If this agent is being set as default, unset all others
        if agent.isDefault {
            for i in agents.indices {
                agents[i].isDefault = false
            }
        }

        agents[index] = agent
        save()
    }

    /// Delete an agent and all its bindings.
    /// Does NOT delete the agent directory (preserves session history).
    public func deleteAgent(_ agent: AgentConfig) {
        agents.removeAll { $0.id == agent.id }
        bindings.removeAll { $0.agentId == agent.id }

        // If we deleted the default, promote the first remaining agent
        if agent.isDefault, !agents.isEmpty {
            agents[0].isDefault = true
        }

        save()
    }

    /// Set an agent as the default (unsets all others).
    public func setDefault(_ agent: AgentConfig) {
        for i in agents.indices {
            agents[i].isDefault = (agents[i].id == agent.id)
        }
        save()
    }

    // MARK: - Binding CRUD

    /// Add a channel binding for an agent.
    public func addBinding(agentId: String, channel: String, accountId: String?) {
        let binding = ChannelBinding(
            agentId: agentId,
            channel: channel,
            accountId: accountId?.isEmpty == true ? nil : accountId
        )

        // Don't add duplicates
        guard !bindings.contains(where: { $0.id == binding.id }) else {
            syncError = "This binding already exists"
            return
        }

        bindings.append(binding)
        save()
    }

    /// Remove a channel binding.
    public func removeBinding(_ binding: ChannelBinding) {
        bindings.removeAll { $0.id == binding.id }
        save()
    }

    /// Get all bindings for a specific agent.
    public func bindingsFor(agentId: String) -> [ChannelBinding] {
        bindings.filter { $0.agentId == agentId }
    }

    // MARK: - Emoji Sidecar Storage
    //
    // Emoji is stored in ~/Library/Application Support/WorldAPI/agent-emoji.json
    // because OpenClaw's schema rejects unknown keys like "emoji" in openclaw.json.

    private static let emojiURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("WorldAPI")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("agent-emoji.json")
    }()

    /// Load emoji map from sidecar file.
    private func loadEmojiMap() -> [String: String] {
        guard let data = try? Data(contentsOf: Self.emojiURL),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return map
    }

    /// Save emoji map to sidecar file.
    private func saveEmojiMap() {
        let map = Dictionary(uniqueKeysWithValues: agents.map { ($0.id, $0.emoji) })
        guard let data = try? JSONEncoder().encode(map) else { return }
        try? data.write(to: Self.emojiURL, options: .atomic)
    }

    /// Merge emoji from sidecar into loaded agents.
    private func mergeEmoji() {
        let map = loadEmojiMap()
        for i in agents.indices {
            if let emoji = map[agents[i].id] {
                agents[i].emoji = emoji
            }
        }
    }

    // MARK: - Computed

    /// Number of unique channels currently bound.
    public var uniqueChannelCount: Int {
        Set(bindings.map(\.channel)).count
    }

    /// Effective model for an agent (per-agent override or global default).
    public func effectiveModel(for agent: AgentConfig) -> String {
        agent.primaryModel ?? defaultsPrimary ?? "Not configured"
    }
}
