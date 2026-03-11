import Foundation

// MARK: - Agent Configuration

/// Represents a single OpenClaw agent from `agents.list[]` in openclaw.json.
/// Each agent is an independent AI persona with its own model, workspace, and channel routing.
public struct AgentConfig: Identifiable, Codable, Sendable, Hashable {
    /// Unique agent identifier — also the directory name under `~/.openclaw/agents/<id>/`.
    public var id: String
    /// Human-readable display name (e.g. "OpenClaw", "Research Bot").
    public var name: String
    /// Emoji avatar for the agent.
    public var emoji: String
    /// Whether this is the default/fallback agent for unmatched messages.
    public var isDefault: Bool
    /// Per-agent primary model override (e.g. "anthropic/claude-opus-4-6").
    /// When nil, inherits `agents.defaults.model.primary`.
    public var primaryModel: String?
    /// Agent workspace directory path.
    public var workspace: String?
    /// Maximum concurrent sessions for this agent.
    public var maxConcurrent: Int?
    /// Group chat settings (mention gating).
    public var groupChat: AgentGroupChat?
    /// Tool allow/deny lists.
    public var tools: AgentToolConfig?
    /// Sandbox configuration.
    public var sandbox: AgentSandboxConfig?

    public init(
        id: String,
        name: String,
        emoji: String = "🤖",
        isDefault: Bool = false,
        primaryModel: String? = nil,
        workspace: String? = nil,
        maxConcurrent: Int? = nil,
        groupChat: AgentGroupChat? = nil,
        tools: AgentToolConfig? = nil,
        sandbox: AgentSandboxConfig? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.isDefault = isDefault
        self.primaryModel = primaryModel
        self.workspace = workspace
        self.maxConcurrent = maxConcurrent
        self.groupChat = groupChat
        self.tools = tools
        self.sandbox = sandbox
    }

    // JSON uses "default" which is a Swift keyword — remap it
    private enum CodingKeys: String, CodingKey {
        case id, name, emoji
        case isDefault = "default"
        case primaryModel = "model"
        case workspace, maxConcurrent, groupChat, tools, sandbox
    }
}

// MARK: - Agent Sub-Configurations

/// Group chat mention gating.
public struct AgentGroupChat: Codable, Sendable, Hashable {
    public var mentionPatterns: [String]?
    public var requireMention: Bool?

    public init(mentionPatterns: [String]? = nil, requireMention: Bool? = nil) {
        self.mentionPatterns = mentionPatterns
        self.requireMention = requireMention
    }
}

/// Tool allow/deny lists for an agent.
public struct AgentToolConfig: Codable, Sendable, Hashable {
    public var allow: [String]?
    public var deny: [String]?

    public init(allow: [String]? = nil, deny: [String]? = nil) {
        self.allow = allow
        self.deny = deny
    }
}

/// Sandbox configuration for an agent.
public struct AgentSandboxConfig: Codable, Sendable, Hashable {
    /// "off", "non-main", "all"
    public var mode: String?
    /// "agent", "session", "shared"
    public var scope: String?

    public init(mode: String? = nil, scope: String? = nil) {
        self.mode = mode
        self.scope = scope
    }
}

// MARK: - Channel Binding

/// Represents a channel-to-agent routing rule from the top-level `bindings[]` in openclaw.json.
public struct ChannelBinding: Identifiable, Codable, Sendable, Hashable {
    public var id: String { "\(agentId):\(channel):\(accountId ?? "default")" }
    public var agentId: String
    public var channel: String
    public var accountId: String?

    public init(agentId: String, channel: String, accountId: String? = nil) {
        self.agentId = agentId
        self.channel = channel
        self.accountId = accountId
    }

    // The JSON structure is: { agentId, match: { channel, accountId? } }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: BindingCodingKeys.self)
        agentId = try container.decode(String.self, forKey: .agentId)
        let match = try container.decode(BindingMatch.self, forKey: .match)
        channel = match.channel
        accountId = match.accountId
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: BindingCodingKeys.self)
        try container.encode(agentId, forKey: .agentId)
        try container.encode(BindingMatch(channel: channel, accountId: accountId), forKey: .match)
    }

    private enum BindingCodingKeys: String, CodingKey {
        case agentId, match
    }

    private struct BindingMatch: Codable {
        var channel: String
        var accountId: String?
    }

    /// Display-friendly channel name.
    public var channelDisplayName: String {
        OpenClawChannel(rawValue: channel)?.displayName ?? channel.capitalized
    }

    /// SF Symbol for the channel.
    public var channelIcon: String {
        OpenClawChannel(rawValue: channel)?.iconName ?? "antenna.radiowaves.left.and.right"
    }
}

// MARK: - Supported Channels

/// All messaging channels supported by OpenClaw.
public enum OpenClawChannel: String, CaseIterable, Sendable, Identifiable {
    case telegram
    case whatsapp
    case slack
    case discord
    case signal
    case imessage
    case irc
    case teams
    case matrix
    case googleChat = "google-chat"
    case webchat
    case nostr
    case line
    case mattermost
    case feishu
    case twitch
    case zalo
    case synologyChat = "synology-chat"
    case tlon
    case nextcloudTalk = "nextcloud-talk"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .telegram: "Telegram"
        case .whatsapp: "WhatsApp"
        case .slack: "Slack"
        case .discord: "Discord"
        case .signal: "Signal"
        case .imessage: "iMessage"
        case .irc: "IRC"
        case .teams: "Microsoft Teams"
        case .matrix: "Matrix"
        case .googleChat: "Google Chat"
        case .webchat: "Webchat"
        case .nostr: "Nostr"
        case .line: "LINE"
        case .mattermost: "Mattermost"
        case .feishu: "Feishu"
        case .twitch: "Twitch"
        case .zalo: "Zalo"
        case .synologyChat: "Synology Chat"
        case .tlon: "Tlon"
        case .nextcloudTalk: "Nextcloud Talk"
        }
    }

    public var iconName: String {
        switch self {
        case .telegram: "paperplane.fill"
        case .whatsapp: "phone.fill"
        case .slack: "number"
        case .discord: "gamecontroller.fill"
        case .signal: "lock.shield.fill"
        case .imessage: "message.fill"
        case .irc: "terminal.fill"
        case .teams: "person.3.fill"
        case .matrix: "square.grid.3x3.fill"
        case .googleChat: "bubble.left.and.bubble.right.fill"
        case .webchat: "globe"
        case .nostr: "antenna.radiowaves.left.and.right"
        case .line: "ellipsis.message.fill"
        case .mattermost: "bubble.left.fill"
        case .feishu: "bird.fill"
        case .twitch: "play.tv.fill"
        case .zalo: "bubble.middle.bottom.fill"
        case .synologyChat: "server.rack"
        case .tlon: "sailboat.fill"
        case .nextcloudTalk: "cloud.fill"
        }
    }
}

// MARK: - Read Result

/// Container for the result of reading agents from OpenClaw config.
public struct AgentReadResult: Sendable {
    public var agents: [AgentConfig]
    public var bindings: [ChannelBinding]
    public var defaultsPrimary: String?
    public var defaultsFallbacks: [String]

    public init(agents: [AgentConfig] = [], bindings: [ChannelBinding] = [],
                defaultsPrimary: String? = nil, defaultsFallbacks: [String] = []) {
        self.agents = agents
        self.bindings = bindings
        self.defaultsPrimary = defaultsPrimary
        self.defaultsFallbacks = defaultsFallbacks
    }
}
