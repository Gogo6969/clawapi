import SwiftUI
import Shared

struct LogsView: View {
    @EnvironmentObject var store: PolicyStore
    @Binding var selectedTab: AppTab
    @Binding var showingPendingReview: Bool
    @Binding var filterResult: AuditResult?
    @State private var searchText = ""

    var filteredEntries: [AuditEntry] {
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
            // Status cards row
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
                .onTapGesture { filterResult = .approved }

                StatusCard(
                    title: "Denied",
                    value: "\(store.auditEntries.filter { $0.result == .denied }.count)",
                    icon: "xmark.shield.fill",
                    color: .red
                )
                .help("Click to see denied requests")
                .onTapGesture { filterResult = .denied }
            }
            .padding()

            Divider()

            // Search / filter bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search logs...", text: $searchText)
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

            // ALWAYS render a List so macOS TabView sees a greedy NSTableView.
            // When empty, the list has no visible rows but the overlay shows a message.
            // This prevents ContentUnavailableView from hijacking the VStack layout.
            List {
                ForEach(filteredEntries) { entry in
                    LogEntryRow(entry: entry)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .overlay {
                if filteredEntries.isEmpty {
                    ContentUnavailableView {
                        Label("No Logs", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text(searchText.isEmpty && filterResult == nil
                            ? "No activity yet. Logs appear here after ClawAPI handles its first request."
                            : "No logs match your filters. Try adjusting your search or filter."
                        )
                    }
                }
            }
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
