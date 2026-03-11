import SwiftUI
import Shared

/// Edit/configure an existing OpenClaw agent — model, channels, identity, advanced settings.
struct AgentDetailSheet: View {
    let agent: AgentConfig
    @ObservedObject var store: AgentStore
    @Environment(\.dismiss) private var dismiss

    // Editable copies
    @State private var name: String
    @State private var emoji: String
    @State private var isDefault: Bool
    @State private var primaryModel: String
    @State private var useDefaultModel: Bool
    @State private var workspace: String
    @State private var maxConcurrent: Int

    // Group chat
    @State private var mentionPatterns: String
    @State private var requireMention: Bool

    // Tools
    @State private var toolsAllow: String
    @State private var toolsDeny: String

    // Sandbox
    @State private var sandboxMode: String

    // New binding
    @State private var newBindingChannel: OpenClawChannel = .telegram
    @State private var newBindingAccountId = ""

    // Track if anything changed
    @State private var hasChanges = false

    init(agent: AgentConfig, store: AgentStore) {
        self.agent = agent
        self.store = store

        _name = State(initialValue: agent.name)
        _emoji = State(initialValue: agent.emoji)
        _isDefault = State(initialValue: agent.isDefault)
        _primaryModel = State(initialValue: agent.primaryModel ?? "")
        _useDefaultModel = State(initialValue: agent.primaryModel == nil)
        _workspace = State(initialValue: agent.workspace ?? "")
        _maxConcurrent = State(initialValue: agent.maxConcurrent ?? 4)
        _mentionPatterns = State(initialValue: agent.groupChat?.mentionPatterns?.joined(separator: ", ") ?? "")
        _requireMention = State(initialValue: agent.groupChat?.requireMention ?? false)
        _toolsAllow = State(initialValue: agent.tools?.allow?.joined(separator: ", ") ?? "")
        _toolsDeny = State(initialValue: agent.tools?.deny?.joined(separator: ", ") ?? "")
        _sandboxMode = State(initialValue: agent.sandbox?.mode ?? "off")
    }

    private var agentBindings: [ChannelBinding] {
        store.bindingsFor(agentId: agent.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack(spacing: 10) {
                Text(emoji)
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name.isEmpty ? agent.name : name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Agent: \(agent.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(20)

            Divider()

            // MARK: - Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // SECTION: Identity
                    sectionHeader("Identity", icon: "person.fill")

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("Name").font(.caption).foregroundStyle(.secondary)
                                    FieldHelp("The display name for this agent. Shown in the agent list and logs. Does not affect how OpenClaw routes messages.")
                                }
                                TextField("Agent name", text: $name)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: name) { hasChanges = true }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("Emoji").font(.caption).foregroundStyle(.secondary)
                                    FieldHelp("The avatar icon shown next to the agent name in ClawAPI.")
                                }
                                TextField("\u{1F916}", text: $emoji)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .onChange(of: emoji) { hasChanges = true }
                            }
                        }

                        HStack {
                            HStack(spacing: 4) {
                                Text("Agent ID")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                FieldHelp("The internal identifier and directory name under ~/.openclaw/agents/. Cannot be changed after creation. Used by OpenClaw for routing and session storage.")
                            }
                            Text(agent.id)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            if !agent.isDefault {
                                HStack(spacing: 4) {
                                    Toggle("Default Agent", isOn: $isDefault)
                                        .toggleStyle(.switch)
                                        .controlSize(.small)
                                        .onChange(of: isDefault) { hasChanges = true }
                                    FieldHelp("The default agent receives all messages that don't match a specific channel binding. Only one agent can be the default.")
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Text("DEFAULT")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(.green.opacity(0.12), in: Capsule())
                                        .foregroundStyle(.green)
                                    FieldHelp("The default agent receives all messages that don't match a specific channel binding. Only one agent can be the default.")
                                }
                            }
                        }
                    }

                    Divider()

                    // SECTION: Model
                    HStack(spacing: 6) {
                        sectionHeader("Model Configuration", icon: "cpu")
                        FieldHelp("Pick which AI model this agent uses. If 'Use default model' is ON, the agent inherits Provider #1's model from the Providers tab. If OFF, the model you pick here takes priority.")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 4) {
                            Toggle("Use default model", isOn: $useDefaultModel)
                                .toggleStyle(.switch)
                                .onChange(of: useDefaultModel) { hasChanges = true }
                            FieldHelp("When ON, this agent uses the global default model (set by Provider #1 in the Providers tab). When OFF, you pick a specific model for this agent \u{2014} that model takes priority over Provider #1.")
                        }

                        if let defaultModel = store.defaultsPrimary {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                Text("Default: \(defaultModel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !useDefaultModel {
                            VStack(alignment: .leading, spacing: 8) {
                                // Grouped model pickers by provider — same style as Providers tab
                                ForEach(allModelScopes, id: \.scope) { group in
                                    HStack(spacing: 8) {
                                        Text(group.label)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 90, alignment: .trailing)
                                        HStack(spacing: 4) {
                                            Image(systemName: "cpu")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                            Picker(selection: Binding(
                                                get: {
                                                    // If current model belongs to this scope, show it
                                                    if group.models.contains(where: { $0.id == primaryModel }) {
                                                        return primaryModel
                                                    }
                                                    return ""
                                                },
                                                set: { (newModel: String) in
                                                    guard !newModel.isEmpty else { return }
                                                    primaryModel = newModel
                                                    hasChanges = true
                                                }
                                            )) {
                                                Text("\u{2014}").tag("")
                                                ForEach(group.models) { model in
                                                    Text(model.name).tag(model.id)
                                                }
                                            } label: {
                                                EmptyView()
                                            }
                                            .pickerStyle(.menu)
                                            .frame(width: 200, alignment: .leading)
                                        }

                                        if group.models.contains(where: { $0.id == primaryModel }) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                                .font(.caption)
                                        }
                                    }
                                }

                                // Manual entry fallback
                                HStack(spacing: 8) {
                                    HStack(spacing: 4) {
                                        Text("Custom")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        FieldHelp("Type any model ID manually (e.g. provider/model-name) for models not in the catalog. Useful for newly released or custom-deployed models.")
                                    }
                                    .frame(width: 90, alignment: .trailing)
                                    TextField("provider/model-id", text: $primaryModel)
                                        .textFieldStyle(.roundedBorder)
                                        .fontDesign(.monospaced)
                                        .font(.caption)
                                        .onChange(of: primaryModel) { hasChanges = true }
                                }
                            }
                        }
                    }

                    Divider()

                    // SECTION: Channel Bindings
                    HStack(spacing: 6) {
                        sectionHeader("Channel Bindings", icon: "antenna.radiowaves.left.and.right")
                        FieldHelp("Route messages from specific channels (Telegram, Slack, Discord, etc.) to this agent. Without bindings, only the default agent receives messages. Account ID is optional \u{2014} use it when you have multiple bot accounts on one channel.")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if agentBindings.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(agent.isDefault
                                        ? "No channels bound. As the default agent, this agent receives all incoming messages."
                                        : "No channels bound \u{2014} this agent won\u{2019}t receive direct messages from any channel.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !agent.isDefault {
                                    Text("This agent can still be used as a **sub-agent** \u{2014} your main agent can spawn it via /subagents spawn \(agent.id) or automatically via sessions_spawn. To also receive direct channel messages, bind a channel below or set this agent as default.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 22)
                                }
                            }
                        } else {
                            ForEach(agentBindings) { binding in
                                HStack(spacing: 8) {
                                    Image(systemName: binding.channelIcon)
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                        .frame(width: 20)
                                    Text(binding.channelDisplayName)
                                        .font(.callout)
                                    if let accountId = binding.accountId {
                                        Text(accountId)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .fontDesign(.monospaced)
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        store.removeBinding(binding)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        // Add binding row
                        HStack(spacing: 8) {
                            Picker("", selection: $newBindingChannel) {
                                ForEach(OpenClawChannel.allCases) { channel in
                                    Text(channel.displayName).tag(channel)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 160)

                            TextField("Account ID (optional)", text: $newBindingAccountId)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)

                            Button("Add") {
                                store.addBinding(
                                    agentId: agent.id,
                                    channel: newBindingChannel.rawValue,
                                    accountId: newBindingAccountId.isEmpty ? nil : newBindingAccountId
                                )
                                newBindingAccountId = ""
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    Divider()

                    // SECTION: Advanced
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 16) {
                            // Workspace
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("Workspace Path").font(.caption).foregroundStyle(.secondary)
                                    FieldHelp("The working directory where this agent runs commands and edits files. Each agent can have its own project folder. Defaults to ~/.openclaw/workspace.")
                                }
                                TextField("~/.openclaw/workspace", text: $workspace)
                                    .textFieldStyle(.roundedBorder)
                                    .fontDesign(.monospaced)
                                    .onChange(of: workspace) { hasChanges = true }
                            }

                            // Max concurrent
                            HStack {
                                HStack(spacing: 4) {
                                    Text("Max Concurrent Sessions")
                                        .font(.callout)
                                    FieldHelp("How many conversations this agent handles simultaneously. Extra messages queue up. Default: 4. Increase for high-traffic channels, decrease to limit resource usage.")
                                }
                                Spacer()
                                Stepper(value: $maxConcurrent, in: 1...16) {
                                    Text("\(maxConcurrent)")
                                        .fontDesign(.monospaced)
                                }
                                .onChange(of: maxConcurrent) { hasChanges = true }
                            }

                            // Sandbox
                            HStack {
                                HStack(spacing: 4) {
                                    Text("Sandbox Mode")
                                        .font(.callout)
                                    FieldHelp("Isolates the agent's file system access in a Docker container. Off = full access. Non-Main = sandbox only on non-main git branches. All = always sandboxed. Requires Docker.")
                                }
                                Spacer()
                                Picker("", selection: $sandboxMode) {
                                    Text("Off").tag("off")
                                    Text("Non-Main").tag("non-main")
                                    Text("All").tag("all")
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 200)
                                .onChange(of: sandboxMode) { hasChanges = true }
                            }

                            // Tools
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("Tools Allow (comma-separated)").font(.caption).foregroundStyle(.secondary)
                                    FieldHelp("Whitelist of tools this agent can use (e.g. exec, read, write). If set, the agent can ONLY use these tools. Leave empty to allow all.")
                                }
                                TextField("exec, read, write, edit", text: $toolsAllow)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption)
                                    .fontDesign(.monospaced)
                                    .onChange(of: toolsAllow) { hasChanges = true }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("Tools Deny (comma-separated)").font(.caption).foregroundStyle(.secondary)
                                    FieldHelp("Blacklist of tools this agent cannot use (e.g. browser, admin). Overrides the allow list. Use to block specific dangerous capabilities.")
                                }
                                TextField("browser, admin", text: $toolsDeny)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption)
                                    .fontDesign(.monospaced)
                                    .onChange(of: toolsDeny) { hasChanges = true }
                            }

                            // Group chat
                            Divider()

                            HStack(spacing: 4) {
                                Toggle("Require @mention in groups", isOn: $requireMention)
                                    .toggleStyle(.switch)
                                    .onChange(of: requireMention) { hasChanges = true }
                                FieldHelp("When ON, the agent only responds in group chats when someone @mentions it. When OFF, it responds to every message.")
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("Mention Patterns (comma-separated)").font(.caption).foregroundStyle(.secondary)
                                    FieldHelp("Words or patterns that trigger this agent in group chats (e.g. @bot, hey bot). Comma-separated. Only relevant when Require @mention is ON.")
                                }
                                TextField("@bot, botname", text: $mentionPatterns)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption)
                                    .onChange(of: mentionPatterns) { hasChanges = true }
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Label("Advanced Settings", systemImage: "gearshape.2")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .padding(20)
            }

            Divider()

            // MARK: - Footer
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if hasChanges {
                    Text("Unsaved changes")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Button("Save") {
                    saveChanges()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges)
            }
            .padding(16)
        }
        .frame(width: 560, height: 620)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
    }

    /// Model groups from the ServiceCatalog, one per provider scope.
    private var allModelScopes: [ModelGroup] {
        let catalog = ServiceCatalog.loadCatalogSync()
        // Show only scopes that have models, sorted to put common providers first
        let preferredOrder = ["openai-codex", "openai", "anthropic", "xai", "google",
                              "groq", "mistral", "ollama", "kimi-coding", "minimax"]
        let sorted = catalog.sorted { a, b in
            let ai = preferredOrder.firstIndex(of: a.key) ?? 999
            let bi = preferredOrder.firstIndex(of: b.key) ?? 999
            if ai != bi { return ai < bi }
            return a.key < b.key
        }
        return sorted.compactMap { scope, models in
            guard !models.isEmpty else { return nil }
            let label = ServiceCatalog.all.first(where: { $0.scope == scope })?.name ?? scope.capitalized
            return ModelGroup(scope: scope, label: label, models: models)
        }
    }

    private struct ModelGroup {
        let scope: String
        let label: String
        let models: [ModelOption]
    }

    private func parseCommaList(_ input: String) -> [String]? {
        let items = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return items.isEmpty ? nil : items
    }

    private func saveChanges() {
        var updated = agent
        updated.name = name
        updated.emoji = emoji
        updated.isDefault = isDefault
        updated.primaryModel = useDefaultModel ? nil : (primaryModel.isEmpty ? nil : primaryModel)
        updated.workspace = workspace.isEmpty ? nil : workspace
        updated.maxConcurrent = maxConcurrent == 4 ? nil : maxConcurrent

        // Group chat
        let patterns = parseCommaList(mentionPatterns)
        if patterns != nil || requireMention {
            updated.groupChat = AgentGroupChat(
                mentionPatterns: patterns,
                requireMention: requireMention ? true : nil
            )
        } else {
            updated.groupChat = nil
        }

        // Tools
        let allow = parseCommaList(toolsAllow)
        let deny = parseCommaList(toolsDeny)
        if allow != nil || deny != nil {
            updated.tools = AgentToolConfig(allow: allow, deny: deny)
        } else {
            updated.tools = nil
        }

        // Sandbox
        if sandboxMode != "off" {
            updated.sandbox = AgentSandboxConfig(mode: sandboxMode, scope: agent.sandbox?.scope)
        } else {
            updated.sandbox = nil
        }

        store.updateAgent(updated)
    }
}

// MARK: - Field Help Popover

/// Small "?" button that shows an explanatory popover when clicked.
struct FieldHelp: View {
    let text: String
    @State private var showing = false

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Button {
            showing.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 11))
                .foregroundStyle(.blue.opacity(0.6))
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $showing, arrowEdge: .trailing) {
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(width: 260)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
