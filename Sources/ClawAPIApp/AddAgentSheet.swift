import SwiftUI
import Shared

/// Multi-step wizard for creating a new OpenClaw agent.
/// Follows the same pattern as AddScopeSheet (provider creation wizard).
struct AddAgentSheet: View {
    @ObservedObject var store: AgentStore
    @Environment(\.dismiss) private var dismiss

    enum Step { case configure, pickModel, success }
    @State private var step: Step = .configure

    // Configure step
    @State private var agentName = ""
    @State private var agentId = ""
    @State private var agentEmoji = "🤖"
    @State private var agentWorkspace = ""
    @State private var idEditedManually = false
    @FocusState private var idFieldFocused: Bool

    // Model step
    @State private var selectedModel: String?
    @State private var useDefault = true

    // Common emojis for quick pick
    private let emojiOptions = ["🤖", "🦞", "🧠", "🔬", "💻", "📊", "🎯", "🛡️",
                                "📝", "🔍", "⚡", "🌐", "🎨", "🏗️", "🧪", "📡"]

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .configure:
                configureView
            case .pickModel:
                pickModelView
            case .success:
                successView
            }
        }
        .frame(width: 520, height: step == .success ? 260 : 520)
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    // MARK: - Step 1: Configure

    private var configureView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("New Agent")
                    .font(.title2)
                    .fontWeight(.semibold)
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

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Agent Name
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("Agent Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            FieldHelp("The display name for this agent. Shown in the agent list and logs. Does not affect how OpenClaw routes messages.")
                        }
                        TextField("e.g. Research Bot", text: $agentName)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: agentName) {
                                if !idEditedManually {
                                    agentId = kebabCase(agentName)
                                }
                            }
                    }

                    // Agent ID
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("Agent ID")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            FieldHelp("The internal identifier and directory name under ~/.openclaw/agents/. Cannot be changed after creation. Used by OpenClaw for routing and session storage.")
                        }
                        TextField("e.g. research-bot", text: $agentId)
                            .textFieldStyle(.roundedBorder)
                            .fontDesign(.monospaced)
                            .focused($idFieldFocused)
                            .onChange(of: agentId) {
                                // Only mark as manually edited when the user is typing in this field
                                if idFieldFocused {
                                    idEditedManually = true
                                }
                            }
                        Text("Auto-generated from the name. Edit to customize.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Emoji Picker
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("Emoji")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            FieldHelp("The avatar icon shown next to the agent name in ClawAPI. Pick one or type your own.")
                        }
                        HStack(spacing: 0) {
                            TextField("\u{1F916}", text: $agentEmoji)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(emojiOptions, id: \.self) { emoji in
                                        Button {
                                            agentEmoji = emoji
                                        } label: {
                                            Text(emoji)
                                                .font(.title3)
                                                .frame(width: 32, height: 32)
                                                .background(
                                                    agentEmoji == emoji
                                                        ? Color.blue.opacity(0.15)
                                                        : Color.clear,
                                                    in: RoundedRectangle(cornerRadius: 6)
                                                )
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                                .padding(.leading, 8)
                            }
                        }
                    }

                    // Workspace (optional)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("Workspace Path")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            FieldHelp("The working directory where this agent runs commands and edits files. Each agent can have its own project folder. Defaults to ~/.openclaw/workspace.")
                        }
                        TextField("Leave empty for default", text: $agentWorkspace)
                            .textFieldStyle(.roundedBorder)
                            .fontDesign(.monospaced)
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Next: Choose Model") {
                    withAnimation { step = .pickModel }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(agentName.isEmpty || agentId.isEmpty)
            }
            .padding(16)
        }
    }

    // MARK: - Step 2: Pick Model

    private var pickModelView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation { step = .configure }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }
                .buttonStyle(.borderless)

                Text(agentEmoji)
                    .font(.title2)
                Text("Model for \(agentName)")
                    .font(.title3)
                    .fontWeight(.semibold)
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

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Default option
                    HStack(spacing: 4) {
                        Toggle("Use default model", isOn: $useDefault)
                            .toggleStyle(.switch)
                        FieldHelp("When ON, this agent uses the global default model (set by Provider #1 in the Providers tab). When OFF, you pick a specific model for this agent \u{2014} that model takes priority over Provider #1.")
                    }

                    if let primary = store.defaultsPrimary {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                            Text("Default: \(primary)")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !useDefault {
                        Divider()

                        Text("Choose a specific model for this agent:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // Model input
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Text("Model ID")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                FieldHelp("Type any model ID manually (e.g. provider/model-name) for models not in the catalog. Useful for newly released or custom-deployed models.")
                            }
                            TextField("e.g. anthropic/claude-opus-4-6", text: Binding(
                                get: { selectedModel ?? "" },
                                set: { selectedModel = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .fontDesign(.monospaced)

                            Text("Enter the full model identifier (provider/model-name).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Quick suggestions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Popular models:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            FlowLayoutAgents(spacing: 6) {
                                ForEach(popularModels, id: \.self) { model in
                                    Button {
                                        selectedModel = model
                                    } label: {
                                        Text(model)
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                selectedModel == model
                                                    ? Color.blue.opacity(0.15)
                                                    : Color.gray.opacity(0.08),
                                                in: Capsule()
                                            )
                                            .foregroundStyle(selectedModel == model ? .blue : .primary)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Button("Back") {
                    withAnimation { step = .configure }
                }
                Spacer()
                Button("Create Agent") {
                    createAgent()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
    }

    // MARK: - Step 3: Success

    private var successView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("\(agentEmoji) \(agentName)")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Agent created successfully")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .padding(.bottom, 20)
        }
        .onAppear {
            // Auto-dismiss after 2 seconds
            Task {
                try? await Task.sleep(for: .seconds(2))
                dismiss()
            }
        }
    }

    // MARK: - Actions

    private func createAgent() {
        let model = useDefault ? nil : selectedModel
        let workspace = agentWorkspace.isEmpty ? nil : agentWorkspace

        store.createAgent(
            id: agentId,
            name: agentName,
            emoji: agentEmoji,
            primaryModel: model,
            workspace: workspace
        )

        withAnimation { step = .success }
    }

    // MARK: - Helpers

    private func kebabCase(_ input: String) -> String {
        input
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private var popularModels: [String] {
        [
            "anthropic/claude-opus-4-6",
            "anthropic/claude-sonnet-4-5",
            "openai/gpt-5.1",
            "openai-codex/gpt-5.3-codex",
            "xai/grok-4-fast",
            "google/gemini-2.5-pro",
            "ollama/llama3.2:3b",
        ]
    }
}

// MARK: - Flow Layout (horizontal wrapping)

/// Simple flow layout for wrapping model suggestion buttons.
struct FlowLayoutAgents: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return ArrangeResult(
            size: CGSize(width: maxWidth, height: totalHeight),
            positions: positions
        )
    }
}
