import SwiftUI
import Shared

struct ActivityView: View {
    @EnvironmentObject var store: PolicyStore
    @Binding var selectedTab: AppTab
    @Binding var showingPendingReview: Bool
    @Binding var logsFilter: AuditResult?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status cards
                HStack(spacing: 16) {
                    StatusCard(
                        title: "Providers",
                        value: "\(store.policies.filter(\.isEnabled).count)/\(store.policies.count)",
                        icon: "key.fill",
                        color: .blue
                    )
                    .help("Click to view all providers")
                    .onTapGesture { selectedTab = .providers }

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

                // Recent audit activity
                GroupBox {
                    VStack(spacing: 0) {
                        if store.auditEntries.isEmpty {
                            Text("No activity yet")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 100)
                        } else {
                            ForEach(store.auditEntries.prefix(5)) { entry in
                                AuditRow(entry: entry)
                                if entry.id != store.auditEntries.prefix(5).last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Label("Recent Activity", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text("Last 5 events")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .help("Click to see full log history")
                .onTapGesture { logsFilter = nil; selectedTab = .logs }

                // Pending requests
                if !store.pendingRequests.isEmpty {
                    GroupBox {
                        VStack(spacing: 0) {
                            ForEach(store.pendingRequests) { request in
                                PendingRow(request: request)
                                if request.id != store.pendingRequests.last?.id {
                                    Divider()
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Label("Pending Requests", systemImage: "bell.badge")
                            Spacer()
                            Text("\(store.pendingRequests.count) awaiting review")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .help("Requests from OpenClaw that need your approval. Click Approve or Deny for each.")
                }
            }
            .padding()
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(isHovered ? 0.18 : 0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(isHovered ? 0.3 : 0), lineWidth: 1.5)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - Audit Row

struct AuditRow: View {
    let entry: AuditEntry

    var body: some View {
        HStack {
            resultIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.scope)
                    .font(.headline)
                Text(entry.reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.result.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(resultColor)
                Text(entry.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .help("Scope: \(entry.scope) | Host: \(entry.requestingHost) | \(entry.detail ?? "No additional detail")")
    }

    private var resultIcon: some View {
        Image(systemName: resultIconName)
            .foregroundStyle(resultColor)
            .frame(width: 24)
    }

    private var resultIconName: String {
        switch entry.result {
        case .approved: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    private var resultColor: Color {
        switch entry.result {
        case .approved: .green
        case .denied: .red
        case .error: .orange
        }
    }
}

// MARK: - Pending Row

struct PendingRow: View {
    let request: PendingRequest
    @EnvironmentObject var store: PolicyStore

    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundStyle(.orange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.scope)
                    .font(.headline)
                Text(request.reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("From: \(request.requestingHost)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button("Approve") {
                    store.approvePendingRequest(request)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)
                .help("Grant access — ClawAPI will forward this request with credentials")

                Button("Deny") {
                    store.denyPendingRequest(request)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
                .help("Deny access — the request will not be forwarded")
            }
        }
        .padding(.vertical, 6)
    }
}
