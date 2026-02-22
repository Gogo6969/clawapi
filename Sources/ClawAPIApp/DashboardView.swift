import SwiftUI
import Shared

struct ActivityView: View {
    @EnvironmentObject var store: PolicyStore
    @Binding var selectedTab: AppTab
    @Binding var showingPendingReview: Bool
    @State private var filterResult: AuditResult?
    @State private var searchText = ""

    private var filteredEntries: [AuditEntry] {
        store.auditEntries.filter { entry in
            let matchesSearch = searchText.isEmpty
                || entry.scope.localizedCaseInsensitiveContains(searchText)
                || entry.reason.localizedCaseInsensitiveContains(searchText)
                || entry.requestingHost.localizedCaseInsensitiveContains(searchText)

            let matchesFilter = filterResult == nil || entry.result == filterResult

            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        VStack(spacing: 0) {
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
                .help("Filter by approved")
                .onTapGesture { filterResult = filterResult == .approved ? nil : .approved }

                StatusCard(
                    title: "Denied",
                    value: "\(store.auditEntries.filter { $0.result == .denied }.count)",
                    icon: "xmark.shield.fill",
                    color: .red
                )
                .help("Filter by denied")
                .onTapGesture { filterResult = filterResult == .denied ? nil : .denied }
            }
            .padding()

            // Pending requests
            if !store.pendingRequests.isEmpty {
                Divider()
                VStack(spacing: 0) {
                    ForEach(store.pendingRequests) { request in
                        PendingRow(request: request)
                        if request.id != store.pendingRequests.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.05))
            }

            Divider()

            // Search / filter bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search activity...", text: $searchText)
                    .textFieldStyle(.plain)
                    .help("Search by provider, domain, or reason")
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

                Divider()
                    .frame(height: 20)

                Picker("Filter", selection: $filterResult) {
                    Text("All").tag(AuditResult?.none)
                    Label("Approved", systemImage: "checkmark.circle.fill")
                        .tag(AuditResult?.some(.approved))
                    Label("Denied", systemImage: "xmark.circle.fill")
                        .tag(AuditResult?.some(.denied))
                    Label("Error", systemImage: "exclamationmark.triangle.fill")
                        .tag(AuditResult?.some(.error))
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
                .help("Filter log entries by result")
            }
            .padding(8)
            .background(.background.secondary)

            Divider()

            // Full log list
            List {
                ForEach(filteredEntries) { entry in
                    LogEntryRow(entry: entry)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .overlay {
                if filteredEntries.isEmpty {
                    ContentUnavailableView {
                        Label("No Activity", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text(searchText.isEmpty && filterResult == nil
                            ? "No activity yet. Events appear here when you manage providers, run health checks, or use the proxy."
                            : "No entries match your filters. Try adjusting your search or filter."
                        )
                    }
                }
            }
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

// MARK: - Log Entry Row

private struct LogEntryRow: View {
    let entry: AuditEntry

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: resultIcon)
                    .foregroundStyle(resultColor)
                Text(entry.result.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(resultColor)
            }
            .frame(width: 90, alignment: .leading)

            Text(entry.scope)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 120, alignment: .leading)

            Text(entry.requestingHost)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)

            Text(entry.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Text(entry.timestamp, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)

            Text(entry.detail ?? "—")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .trailing)
        }
    }

    private var resultIcon: String {
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
