import SwiftUI
import Shared

/// A single row in the agents list, mimicking the ScopePolicyRow design.
/// Includes a model dropdown picker directly on the row.
struct AgentRow: View {
    let agent: AgentConfig
    let agentBindings: [ChannelBinding]
    let effectiveModel: String
    let allModels: [ModelOption]
    let provider1Model: String?
    var onModelChange: (String) -> Void
    var onEdit: () -> Void
    var onSetDefault: () -> Void
    var onDelete: () -> Void
    var onShowFAQ: () -> Void

    @State private var showingCustomModelInfo = false

    /// Whether the agent uses a custom model that differs from Provider #1's global default.
    private var hasCustomModel: Bool {
        guard let p1 = provider1Model, !p1.isEmpty else { return false }
        return effectiveModel != p1 && effectiveModel != "Not configured"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Emoji badge
            Text(agent.emoji)
                .font(.system(size: 22))
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            // Main content
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(agent.name)
                        .font(.headline)

                    if agent.isDefault {
                        Text("DEFAULT")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.12), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }

                HStack(spacing: 8) {
                    // Model picker — same style as Providers tab
                    if !allModels.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            Picker(selection: Binding(
                                get: { effectiveModel },
                                set: { newModel in
                                    guard newModel != effectiveModel else { return }
                                    onModelChange(newModel)
                                }
                            )) {
                                ForEach(allModels) { model in
                                    Text(model.name).tag(model.id)
                                }
                            } label: {
                                EmptyView()
                            }
                            .pickerStyle(.menu)
                            .frame(width: 190, alignment: .leading)
                            .clipped()
                        }
                        .frame(width: 220, alignment: .leading)
                    } else {
                        // Fallback: show model as text if catalog not loaded yet
                        Label {
                            Text(effectiveModel)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "cpu")
                        }
                        .font(.caption)
                        .foregroundStyle(agent.primaryModel != nil ? .secondary : .tertiary)
                    }

                    // Custom model indicator
                    if hasCustomModel {
                        Button {
                            showingCustomModelInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.borderless)
                        .help("This agent uses its own model")
                        .popover(isPresented: $showingCustomModelInfo, arrowEdge: .bottom) {
                            customModelPopover
                        }
                    }

                    // Channel bindings as colored capsules
                    ForEach(agentBindings.prefix(4)) { binding in
                        HStack(spacing: 3) {
                            Image(systemName: binding.channelIcon)
                                .font(.system(size: 8))
                            Text(binding.channelDisplayName)
                        }
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                        .foregroundStyle(.blue)
                    }

                    if agentBindings.count > 4 {
                        Text("+\(agentBindings.count - 4)")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.12), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Agent ID (monospaced)
            Text(agent.id)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)

            // Menu button
            Menu {
                menuContent
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu { menuContent }
    }

    // MARK: - Custom Model Popover

    @ViewBuilder
    private var customModelPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Custom Model Active", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundStyle(.blue)

            let agentModelName = allModels.first(where: { $0.id == effectiveModel })?.name ?? effectiveModel
            let p1ModelName = allModels.first(where: { $0.id == (provider1Model ?? "") })?.name ?? (provider1Model ?? "unknown")

            Text("This agent uses **\(agentModelName)** instead of the global default (**\(p1ModelName)**).")
                .font(.callout)

            Text("That\u{2019}s normal \u{2014} each agent can have its own model for different tasks (research, coding, marketing, etc.). OpenClaw uses **\(agentModelName)** for this agent.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("To change it, use the model dropdown on this row. To use the global default instead, open Edit Agent and turn on \u{201C}Use default model.\u{201D}")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Divider()

            Button {
                showingCustomModelInfo = false
                onShowFAQ()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "book")
                    Text("Learn more in FAQ \u{2192}")
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 360)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var menuContent: some View {
        Button {
            onEdit()
        } label: {
            Label("Edit Agent", systemImage: "pencil")
        }

        if !agent.isDefault {
            Button {
                onSetDefault()
            } label: {
                Label("Set as Default", systemImage: "star")
            }
        }

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete Agent", systemImage: "trash")
        }
        .disabled(agent.isDefault && true)
    }
}
