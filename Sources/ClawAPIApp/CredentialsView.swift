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
    @AppStorage("dismissedKeychainBanner") private var dismissedKeychainBanner = false

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
                    ScopePolicyRow(policy: policy, store: store) {
                        policyToDelete = policy
                        showingDeleteAlert = true
                    }
                    .tag(policy)
                }
                .onMove { source, destination in
                    guard searchText.isEmpty else { return }
                    store.movePolicies(fromOffsets: source, toOffset: destination)
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
                store.removePolicy(policy)
            }
            Button("Cancel", role: .cancel) {}
        } message: { policy in
            Text("Are you sure you want to delete \"\(policy.serviceName)\"? This cannot be undone.")
        }
    }
}

// MARK: - Scope Policy Row

struct ScopePolicyRow: View {
    let policy: ScopePolicy
    let store: PolicyStore
    var onDelete: () -> Void

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
            .disabled(!policy.hasSecret)
            .help(!policy.hasSecret
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
