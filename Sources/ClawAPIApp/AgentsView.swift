import SwiftUI
import Shared

/// Main "Agents" tab — lists all OpenClaw agents with status cards, search, and CRUD actions.
/// Follows the same layout pattern as CredentialsView (Providers tab).
struct AgentsView: View {
    @StateObject private var agentStore = AgentStore()
    @EnvironmentObject private var policyStore: PolicyStore
    @State private var searchText = ""
    @State private var showingAddAgent = false
    @State private var selectedAgent: AgentConfig?
    @State private var agentToDelete: AgentConfig?
    @State private var showingDeleteConfirm = false
    @State private var showingFAQ = false
    @State private var catalogGeneration = 0

    /// Provider #1's selected model (for custom model detection).
    private var provider1Model: String? {
        policyStore.policies.first?.selectedModel
    }

    /// Flat list of all models across all providers for the row picker.
    private var allModels: [ModelOption] {
        _ = catalogGeneration // trigger re-evaluation when catalog loads
        let catalog = ServiceCatalog.loadCatalogSync()
        return catalog.sorted(by: { $0.key < $1.key }).flatMap(\.value)
    }

    private var filteredAgents: [AgentConfig] {
        guard !searchText.isEmpty else { return agentStore.agents }
        let query = searchText.lowercased()
        return agentStore.agents.filter { agent in
            agent.name.lowercased().contains(query) ||
            agent.id.lowercased().contains(query) ||
            agent.emoji.contains(query) ||
            (agent.primaryModel?.lowercased().contains(query) ?? false) ||
            agentStore.bindingsFor(agentId: agent.id).contains {
                $0.channel.lowercased().contains(query) ||
                $0.channelDisplayName.lowercased().contains(query)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Status Cards
            HStack(spacing: 16) {
                StatusCard(
                    title: "Total Agents",
                    value: "\(agentStore.agents.count)",
                    icon: "person.crop.rectangle.stack",
                    color: .blue
                )
                StatusCard(
                    title: "Channels Bound",
                    value: "\(agentStore.uniqueChannelCount)",
                    icon: "antenna.radiowaves.left.and.right",
                    color: .green
                )
                StatusCard(
                    title: "Default Model",
                    value: shortModelName(agentStore.defaultsPrimary ?? "None"),
                    icon: "cpu",
                    color: .purple
                )
            }
            .padding()

            // MARK: - Sync Error Banner
            if let error = agentStore.syncError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Dismiss") {
                        agentStore.syncError = nil
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.red.opacity(0.06))
            }

            Divider()

            // MARK: - Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search agents by name, ID, model, or channel\u{2026}", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }

                Divider()
                    .frame(height: 20)

                Button {
                    showingAddAgent = true
                } label: {
                    Label("Add Agent", systemImage: "plus")
                }
                .buttonStyle(.borderless)

                Button {
                    agentStore.load()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Reload agents from OpenClaw config")
            }
            .padding(8)
            .background(.background.secondary)

            Divider()

            // MARK: - Agent List
            List {
                ForEach(filteredAgents) { agent in
                    AgentRow(
                        agent: agent,
                        agentBindings: agentStore.bindingsFor(agentId: agent.id),
                        effectiveModel: agentStore.effectiveModel(for: agent),
                        allModels: allModels,
                        provider1Model: provider1Model,
                        onModelChange: { newModel in
                            var updated = agent
                            updated.primaryModel = newModel
                            agentStore.updateAgent(updated)
                        },
                        onEdit: { selectedAgent = agent },
                        onSetDefault: { agentStore.setDefault(agent) },
                        onDelete: {
                            agentToDelete = agent
                            showingDeleteConfirm = true
                        },
                        onShowFAQ: { showingFAQ = true }
                    )
                    .tag(agent.id)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .overlay {
                if filteredAgents.isEmpty {
                    if agentStore.agents.isEmpty {
                        ContentUnavailableView {
                            Label("No Agents", systemImage: "person.crop.rectangle.stack")
                        } description: {
                            Text("Create an agent to route messages from different channels to different AI personas, each with its own model and personality.")
                        } actions: {
                            Button("Add Agent") {
                                showingAddAgent = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddAgent) {
            AddAgentSheet(store: agentStore)
        }
        .sheet(item: $selectedAgent) { agent in
            AgentDetailSheet(agent: agent, store: agentStore)
        }
        .sheet(isPresented: $showingFAQ) {
            FAQView()
        }
        .onReceive(NotificationCenter.default.publisher(for: ServiceCatalog.catalogDidLoad)) { _ in
            catalogGeneration += 1
        }
        .alert("Delete Agent", isPresented: $showingDeleteConfirm, presenting: agentToDelete) { agent in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                agentStore.deleteAgent(agent)
            }
        } message: { agent in
            Text("Delete \"\(agent.name)\"? This removes the agent from the config but preserves its session history on disk.")
        }
    }

    /// Shorten a model ID for the status card (e.g. "openai-codex/gpt-5.3-codex" \u{2192} "gpt-5.3-codex").
    private func shortModelName(_ model: String) -> String {
        if let slash = model.lastIndex(of: "/") {
            return String(model[model.index(after: slash)...])
        }
        return model
    }
}
