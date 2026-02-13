import SwiftUI
import Shared

struct PendingReviewSheet: View {
    @EnvironmentObject var store: PolicyStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Pending Approvals")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close the review sheet")
            }
            .padding()

            Divider()

            if store.pendingRequests.isEmpty {
                ContentUnavailableView {
                    Label("No Pending Requests", systemImage: "checkmark.circle")
                } description: {
                    Text("All clear! New requests appear here when OpenClaw needs your approval to access an API provider.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.pendingRequests) { request in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(request.scope)
                                        .font(.headline)
                                    Text(request.reason)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(request.requestedAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Label(request.requestingHost, systemImage: "globe")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .help("The API host OpenClaw is trying to access")

                                Spacer()

                                Button("Deny") {
                                    withAnimation {
                                        store.denyPendingRequest(request)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .controlSize(.small)
                                .help("Deny — OpenClaw will not get access")

                                Button("Approve") {
                                    withAnimation {
                                        store.approvePendingRequest(request)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .controlSize(.small)
                                .help("Approve — OpenClaw will receive the credentials")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                if !store.pendingRequests.isEmpty {
                    Button("Deny All") {
                        let requests = store.pendingRequests
                        for request in requests {
                            store.denyPendingRequest(request)
                        }
                    }
                    .tint(.red)
                    .help("Deny all pending requests at once")
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .help("Close the review sheet")
            }
            .padding()
        }
        .frame(width: 550, height: 450)
    }
}
