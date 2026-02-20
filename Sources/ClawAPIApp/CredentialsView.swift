import SwiftUI
import Shared

struct CredentialsView: View {
    @EnvironmentObject var store: PolicyStore
    @Binding var selectedTab: AppTab
    @Binding var showingPendingReview: Bool
    @Binding var logsFilter: AuditResult?
    @State private var searchText = ""
    @State private var selectedPolicy: ScopePolicy?
    @State private var showingDeleteAlert = false
    @State private var policyToDelete: ScopePolicy?
    @State private var showModelSwitchTip = false
    @AppStorage("dismissedKeychainBanner") private var dismissedKeychainBanner = false
    @AppStorage("dismissedModelSwitchTip") private var dismissedModelSwitchTip = false
    @AppStorage("dismissedOAuthBanner") private var dismissedOAuthBanner = false
    @State private var showingOAuthSetup = false

    var filteredPolicies: [ScopePolicy] {
        if searchText.isEmpty {
            return store.policies
        }
        return store.policies.filter {
            $0.serviceName.localizedCaseInsensitiveContains(searchText)
            || $0.scope.localizedCaseInsensitiveContains(searchText)
            || $0.preferredFor.contains { tag in
                tag.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status cards row
            HStack(spacing: 16) {
                StatusCard(
                    title: "Providers",
                    value: "\(store.policies.filter(\.isEnabled).count)/\(store.policies.count)",
                    icon: "key.fill",
                    color: .blue
                )

                StatusCard(
                    title: "Pending",
                    value: "\(store.pendingRequests.count)",
                    icon: "clock.fill",
                    color: store.pendingRequests.isEmpty ? .green : .orange
                )
                .help("Click to review pending requests")
                .onTapGesture { showingPendingReview = true }

                StatusCard(
                    title: "Approved",
                    value: "\(store.auditEntries.filter { $0.result == .approved }.count)",
                    icon: "checkmark.shield.fill",
                    color: .green
                )
                .help("Click to see approved requests")
                .onTapGesture { logsFilter = .approved; selectedTab = .logs }

                StatusCard(
                    title: "Denied",
                    value: "\(store.auditEntries.filter { $0.result == .denied }.count)",
                    icon: "xmark.shield.fill",
                    color: .red
                )
                .help("Click to see denied requests")
                .onTapGesture { logsFilter = .denied; selectedTab = .logs }
            }
            .padding()

            // Keychain info banner — shown until dismissed
            if !store.policies.isEmpty && !dismissedKeychainBanner {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.body)
                        .foregroundStyle(.blue)

                    Text("If macOS asks for your login password, click **\"Always Allow\"** to let ClawAPI securely access your credentials.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    Button {
                        withAnimation { dismissedKeychainBanner = true }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss this message")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.06))
            }

            // Sync error banner
            if let error = store.syncError {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.body)
                        .foregroundStyle(.red)

                    Text("Sync failed: \(error)")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    Button {
                        withAnimation { store.syncError = nil }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.08))
            }

            // OAuth cost banner — shown when no OAuth provider is configured
            if !dismissedOAuthBanner && !store.policies.contains(where: { $0.scope == "openai-codex" }) {
                Button {
                    showingOAuthSetup = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cheapest Way to Code with AI")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text("Set up OpenAI Codex (OAuth) — uses ChatGPT Plus ($20/mo) instead of per-token API billing.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("Set Up")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)

                        Button {
                            withAnimation { dismissedOAuthBanner = true }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Dismiss this banner")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.06))
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search providers...", text: $searchText)
                    .textFieldStyle(.plain)
                    .help("Search your connected API providers")
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search filter")
                }
            }
            .padding(8)
            .background(.background.secondary)

            Divider()

            // ALWAYS render a List so macOS TabView sees a greedy NSTableView.
            // When empty, the list has no visible rows but the overlay shows a message.
            // This prevents ContentUnavailableView from hijacking the VStack layout.
            List(selection: $selectedPolicy) {
                ForEach(filteredPolicies) { policy in
                    ScopePolicyRow(policy: policy, store: store, onDelete: {
                        policyToDelete = policy
                        showingDeleteAlert = true
                    }, onModelSwitch: {
                        if !dismissedModelSwitchTip {
                            showModelSwitchTip = true
                        }
                    })
                    .tag(policy)
                }
                .onMove { source, destination in
                    guard searchText.isEmpty else { return }
                    store.movePolicies(fromOffsets: source, toOffset: destination)
                    if !dismissedModelSwitchTip {
                        showModelSwitchTip = true
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .overlay {
                if filteredPolicies.isEmpty {
                    ContentUnavailableView {
                        Label("No Providers", systemImage: "key.slash")
                    } description: {
                        Text(searchText.isEmpty
                            ? "No API providers connected yet. Click + in the toolbar to add one."
                            : "No providers match your search."
                        )
                    }
                }
            }
        }
        .alert("Delete Provider", isPresented: $showingDeleteAlert, presenting: policyToDelete) { policy in
            Button("Delete", role: .destructive) {
                Task {
                    guard await KeychainService.authenticateWithBiometrics(
                        reason: "Authenticate to delete \"\(policy.serviceName)\""
                    ) else { return }
                    store.removePolicy(policy)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { policy in
            Text("Are you sure you want to delete \"\(policy.serviceName)\"? This cannot be undone.")
        }
        .sheet(isPresented: $showModelSwitchTip) {
            ModelSwitchInfoSheet {
                selectedTab = .model
            }
        }
        .sheet(isPresented: $showingOAuthSetup) {
            AddScopeSheet(initialTemplate: ServiceCatalog.all.first { $0.scope == "openai-codex" })
        }
    }
}

// MARK: - Model Switch Info Sheet

private struct ModelSwitchInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dismissedModelSwitchTip") private var dismissedForever = false
    var onCheckSync: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 28)

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
                .padding(.bottom, 14)

            Text("Model Updated")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 8)

            Text("Your new model has been synced to OpenClaw.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)

            // Instructions
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text("Existing chat sessions will continue using their original model.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "bubble.left.fill")
                        .foregroundStyle(.green)
                        .frame(width: 20)
                    Text("To use the new model, start a **new session** in OpenClaw by typing **`/new`** in the chat.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.purple)
                        .frame(width: 20)
                    Text("Verify the active model anytime in the **Sync** tab.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.callout)
            .padding(20)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 32)

            Spacer()

            Toggle("Don't show this again", isOn: $dismissedForever)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

            HStack(spacing: 12) {
                Button("Check Sync") {
                    dismiss()
                    onCheckSync()
                }
                .controlSize(.large)

                Button("Got It") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }

            Spacer().frame(height: 20)
        }
        .frame(width: 500, height: 420)
    }
}

// MARK: - Scope Policy Row

struct ScopePolicyRow: View {
    let policy: ScopePolicy
    let store: PolicyStore
    var onDelete: () -> Void
    var onModelSwitch: () -> Void = {}
    @State private var showAdminKeySheet = false
    /// Bumped when the model catalog loads asynchronously, forcing a re-render.
    @State private var catalogGeneration = 0

    @ViewBuilder
    private var menuContent: some View {
        Button {
            var updated = policy
            updated.isEnabled.toggle()
            store.updatePolicy(updated)
        } label: {
            Label(policy.isEnabled ? "Disable Provider" : "Enable Provider",
                  systemImage: policy.isEnabled ? "pause.circle" : "play.circle")
        }

        Divider()

        Section("Access Mode") {
            Button {
                var updated = policy
                updated.approvalMode = .auto
                store.updatePolicy(updated)
            } label: {
                Label("Auto-Approve", systemImage: "bolt.fill")
            }
            .disabled(policy.approvalMode == .auto)

            Button {
                var updated = policy
                updated.approvalMode = .manual
                store.updatePolicy(updated)
            } label: {
                Label("Require Approval", systemImage: "hand.raised.fill")
            }
            .disabled(policy.approvalMode == .manual)

            Button {
                var updated = policy
                updated.approvalMode = .pending
                store.updatePolicy(updated)
            } label: {
                Label("Queue (Pending)", systemImage: "clock.fill")
            }
            .disabled(policy.approvalMode == .pending)
        }

        if BillingService.supportedScopes.contains(policy.scope) {
            Divider()
            Button {
                showAdminKeySheet = true
            } label: {
                Label(
                    policy.hasAdminSecret ? "Change Admin Key" : "Add Admin Key",
                    systemImage: "key.viewfinder"
                )
            }
        }

        Divider()

        Button("Delete Provider", role: .destructive) {
            onDelete()
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Priority badge
            priorityBadge
                .frame(width: 44)

            statusIcon
                .frame(width: 32, height: 32)
                .background(statusColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(policy.serviceName)
                        .font(.headline)
                    Text(policy.scope)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    // Model picker
                    if !availableModels.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            Picker(selection: Binding(
                                get: { currentModelId },
                                set: { newModel in
                                    guard newModel != currentModelId else { return }
                                    store.selectModel(newModel, for: policy)
                                    onModelSwitch()
                                }
                            )) {
                                ForEach(availableModels) { model in
                                    Text(model.name).tag(model.id)
                                }
                            } label: {
                                EmptyView()
                            }
                            .pickerStyle(.menu)
                            .fixedSize()
                        }
                    }

                    if policy.isEnabled {
                        Label(policy.approvalMode.rawValue.capitalized, systemImage: approvalModeIconName)
                            .font(.caption)
                            .foregroundStyle(approvalModeColor)
                    } else {
                        Label("Disabled", systemImage: "pause.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !policy.allowedDomains.isEmpty {
                        Text(policy.allowedDomains.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if !policy.preferredFor.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(policy.preferredFor, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(tagColor(for: tag).opacity(0.15), in: Capsule())
                                    .foregroundStyle(tagColor(for: tag))
                            }
                        }
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if policy.hasSecret {
                    Label("Secret stored", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if isLocalProvider {
                    Label("Local", systemImage: "desktopcomputer")
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else {
                    Label("No secret", systemImage: "lock.open")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let lastUsed = policy.lastUsedAt {
                    Text(lastUsed, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Big ENABLE / DISABLE button
            Button {
                var updated = policy
                updated.isEnabled.toggle()
                store.updatePolicy(updated)
            } label: {
                Text(policy.isEnabled ? "ENABLED" : "DISABLED")
                    .font(.system(.caption, weight: .heavy))
                    .tracking(0.5)
                    .frame(width: 78, height: 32)
            }
            .buttonStyle(.borderedProminent)
            .tint(policy.isEnabled ? .green : .red)
            .controlSize(.small)
            .disabled(!policy.hasSecret && !isLocalProvider)
            .help(!policy.hasSecret && !isLocalProvider
                ? "No secret stored — add an API key before enabling"
                : policy.isEnabled
                    ? "Disable this provider — OpenClaw won't be able to use it"
                    : "Enable this provider — OpenClaw can use it again")

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
        .opacity(policy.isEnabled ? 1.0 : 0.6)
        .contextMenu { menuContent }
        .sheet(isPresented: $showAdminKeySheet) {
            AdminKeySheet(
                policy: policy,
                onSave: { key in
                    Task {
                        guard await KeychainService.authenticateWithBiometrics(
                            reason: "Authenticate to save admin key"
                        ) else { return }
                        let keychain = KeychainService()
                        try? keychain.saveAdminKey(key, forScope: policy.scope)
                        var updated = policy
                        updated.hasAdminSecret = true
                        store.updatePolicy(updated)
                    }
                },
                onRemove: {
                    Task {
                        guard await KeychainService.authenticateWithBiometrics(
                            reason: "Authenticate to remove admin key"
                        ) else { return }
                        let keychain = KeychainService()
                        try? keychain.deleteAdminKey(forScope: policy.scope)
                        var updated = policy
                        updated.hasAdminSecret = false
                        store.updatePolicy(updated)
                    }
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: ServiceCatalog.catalogDidLoad)) { _ in
            catalogGeneration += 1
        }
    }

    /// Whether this provider is a local provider that doesn't need an API key (e.g. Ollama).
    private var isLocalProvider: Bool {
        !(ServiceCatalog.find(policy.scope)?.requiresKey ?? true)
    }

    // MARK: - Model helpers

    private var availableModels: [ModelOption] {
        // catalogGeneration dependency ensures SwiftUI re-evaluates after async fetch
        _ = catalogGeneration
        return ServiceCatalog.modelsForScope(policy.scope)
    }

    /// The model ID currently in effect (user-selected or default).
    private var currentModelId: String {
        if let selected = policy.selectedModel, !selected.isEmpty {
            return selected
        }
        return availableModels.first(where: \.isDefault)?.id
            ?? availableModels.first?.id
            ?? ""
    }

    /// Display name for the current model.
    private var currentModelName: String {
        if let match = availableModels.first(where: { $0.id == currentModelId }) {
            return match.name
        }
        // If the stored ID doesn't match any known model, show the raw ID
        let id = currentModelId
        if let slash = id.firstIndex(of: "/") {
            return String(id[id.index(after: slash)...])
        }
        return id
    }

    // MARK: - Visual helpers

    @ViewBuilder
    private var priorityBadge: some View {
        if policy.priority == 1 {
            VStack(spacing: 2) {
                Text("#1")
                    .font(.system(.title3, design: .rounded, weight: .black))
                    .foregroundStyle(.white)
                Text("MAIN")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: 44, height: 44)
            .background(.blue, in: RoundedRectangle(cornerRadius: 10))
        } else {
            Text("#\(policy.priority)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var statusIcon: some View {
        Image(systemName: statusIconName)
            .foregroundStyle(statusColor)
    }

    private var statusIconName: String {
        if !policy.isEnabled { return "pause.circle" }
        return approvalModeIconName
    }

    private var statusColor: Color {
        if !policy.isEnabled { return .gray }
        return approvalModeColor
    }

    private var approvalModeIconName: String {
        switch policy.approvalMode {
        case .auto: "bolt.fill"
        case .manual: "hand.raised.fill"
        case .pending: "clock.fill"
        }
    }

    private var approvalModeColor: Color {
        switch policy.approvalMode {
        case .auto: .green
        case .manual: .purple
        case .pending: .orange
        }
    }

    private func tagColor(for tag: String) -> Color {
        switch tag {
        case TaskType.research: .blue
        case TaskType.coding: .purple
        case TaskType.chat: .green
        case TaskType.analysis: .orange
        case TaskType.images: .pink
        case TaskType.audio: .teal
        case TaskType.general: .gray
        default: .secondary
        }
    }
}
