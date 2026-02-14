import SwiftUI
import Shared

struct UsageView: View {
    @EnvironmentObject var store: PolicyStore
    @StateObject private var viewModel = UsageViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Credit & Usage")
                        .font(.headline)
                    Text("Check your API credit balances and spending")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await viewModel.refreshAll(policies: store.policies) }
                } label: {
                    Label("Refresh All", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .help("Query all providers for current balance/usage")
            }
            .padding()

            Divider()

            if store.policies.isEmpty {
                ContentUnavailableView {
                    Label("No Providers", systemImage: "chart.bar")
                } description: {
                    Text("Add API providers first to check usage and balances.")
                }
            } else {
                List {
                    // Providers that support billing queries (need admin keys)
                    let adminProviders = store.policies.filter {
                        BillingService.supportedScopes.contains($0.scope)
                    }
                    if !adminProviders.isEmpty {
                        Section("Usage (Admin Key Required)") {
                            ForEach(adminProviders) { policy in
                                UsageRow(
                                    policy: policy,
                                    info: viewModel.results[policy.scope],
                                    isLoading: viewModel.loadingScopes.contains(policy.scope),
                                    onAddAdminKey: { viewModel.showAdminKeySheet(for: policy) },
                                    onRefresh: { Task { await viewModel.refresh(policy: policy) } }
                                )
                            }
                        }
                    }

                    // All other providers — just show dashboard links
                    let otherProviders = store.policies.filter {
                        !BillingService.supportedScopes.contains($0.scope)
                    }
                    if !otherProviders.isEmpty {
                        Section("Other Providers") {
                            ForEach(otherProviders) { policy in
                                DashboardLinkRow(policy: policy)
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .task {
            await viewModel.refreshAll(policies: store.policies)
        }
        .sheet(item: $viewModel.adminKeyTarget) { target in
            AdminKeySheet(
                policy: target,
                onSave: { key in
                    viewModel.saveAdminKey(key, for: target, store: store)
                },
                onRemove: {
                    viewModel.removeAdminKey(for: target, store: store)
                }
            )
        }
    }
}

// MARK: - View Model

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var results: [String: BillingInfo] = [:]
    @Published var loadingScopes: Set<String> = []
    @Published var isLoading = false
    @Published var adminKeyTarget: ScopePolicy?

    private let keychain = KeychainService()

    func refreshAll(policies: [ScopePolicy]) async {
        isLoading = true
        let billingPolicies = policies.filter { BillingService.supportedScopes.contains($0.scope) }

        await withTaskGroup(of: BillingInfo.self) { group in
            for policy in billingPolicies {
                loadingScopes.insert(policy.scope)
                group.addTask { [keychain] in
                    await BillingService.query(scope: policy.scope, keychain: keychain)
                }
            }
            for await info in group {
                results[info.scope] = info
                loadingScopes.remove(info.scope)
            }
        }
        isLoading = false
    }

    func refresh(policy: ScopePolicy) async {
        loadingScopes.insert(policy.scope)
        let info = await BillingService.query(scope: policy.scope, keychain: keychain)
        results[policy.scope] = info
        loadingScopes.remove(policy.scope)
    }

    func showAdminKeySheet(for policy: ScopePolicy) {
        adminKeyTarget = policy
    }

    func saveAdminKey(_ key: String, for policy: ScopePolicy, store: PolicyStore) {
        do {
            try keychain.saveAdminKey(key, forScope: policy.scope)
            var updated = policy
            updated.hasAdminSecret = true
            store.updatePolicy(updated)
            adminKeyTarget = nil
            Task { await refresh(policy: updated) }
        } catch {
            // Error will be visible next time they try to query
        }
    }

    func removeAdminKey(for policy: ScopePolicy, store: PolicyStore) {
        try? keychain.deleteAdminKey(forScope: policy.scope)
        var updated = policy
        updated.hasAdminSecret = false
        store.updatePolicy(updated)
        results[policy.scope] = nil
        adminKeyTarget = nil
    }
}

// MARK: - Usage Row (providers requiring admin keys)

struct UsageRow: View {
    let policy: ScopePolicy
    let info: BillingInfo?
    let isLoading: Bool
    var onAddAdminKey: () -> Void
    var onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.title2)
                .foregroundStyle(policy.hasAdminSecret ? .blue : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(policy.serviceName)
                    .font(.headline)

                if isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let info {
                    if let balance = info.balance {
                        Label(balance, systemImage: "creditcard.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                    if let usage = info.usage {
                        Label(usage, systemImage: "flame.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    if let detail = info.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if let error = info.error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } else if !policy.hasAdminSecret {
                    Text("Add an admin key to check balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let url = BillingService.dashboardURL(for: policy.scope) {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.body)
                        .foregroundStyle(.blue)
                }
                .help("Open billing dashboard in browser")
            }

            if policy.hasAdminSecret {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                }
                .buttonStyle(.borderless)
                .disabled(isLoading)
                .help("Refresh balance")
            }

            Button(action: onAddAdminKey) {
                Label(
                    policy.hasAdminSecret ? "Change Key" : "Add Admin Key",
                    systemImage: policy.hasAdminSecret ? "key.fill" : "key"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(adminKeyHelpText)
        }
        .padding(.vertical, 4)
    }

    private var adminKeyHelpText: String {
        switch policy.scope {
        case "openai": "Requires an Admin API key (sk-admin-...) from platform.openai.com"
        case "xai": "Requires a Management API key from console.x.ai"
        case "anthropic": "Requires an Admin API key (sk-ant-admin-...) from console.anthropic.com"
        case "openrouter": "Requires a Management API key from openrouter.ai"
        default: "Add an admin/management API key for billing queries"
        }
    }
}

// MARK: - Dashboard Link Row (providers without billing API)

struct DashboardLinkRow: View {
    let policy: ScopePolicy

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(policy.serviceName)
                    .font(.headline)
                Text("Check usage on the provider's website")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let url = BillingService.dashboardURL(for: policy.scope) {
                Link(destination: url) {
                    Label("Open Dashboard", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open billing dashboard in browser")
            } else {
                Text("No dashboard URL")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Admin Key Sheet

struct AdminKeySheet: View {
    let policy: ScopePolicy
    var onSave: (String) -> Void
    var onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var adminKey = ""
    @State private var showKey = false

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Admin Key — \(policy.serviceName)")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.borderless)
            }

            // Explanation
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text(explanationText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }

            // Key input
            HStack {
                Group {
                    if showKey {
                        TextField(placeholder, text: $adminKey)
                    } else {
                        SecureField(placeholder, text: $adminKey)
                    }
                }
                .textFieldStyle(.roundedBorder)

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(showKey ? "Hide key" : "Show key")
            }

            HStack {
                if policy.hasAdminSecret {
                    Button("Remove Key", role: .destructive) {
                        onRemove()
                        dismiss()
                    }
                }
                Spacer()
                Button("Save") {
                    onSave(adminKey)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(adminKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private var explanationText: String {
        switch policy.scope {
        case "openai":
            "OpenAI requires a separate Admin API key to check usage. Create one at platform.openai.com/api-keys with admin permissions. It starts with sk-admin-..."
        case "xai":
            "xAI requires a separate Management API key to check your prepaid balance. Get one from console.x.ai under API Management."
        case "anthropic":
            "Anthropic requires a separate Admin API key to check usage. Create one at console.anthropic.com/settings/keys. It starts with sk-ant-admin-..."
        case "openrouter":
            "OpenRouter requires a Management API key to check credits. Get one from openrouter.ai/settings/keys."
        default:
            "Enter the admin or management API key for this provider. This is different from your regular inference API key."
        }
    }

    private var placeholder: String {
        switch policy.scope {
        case "openai": "sk-admin-..."
        case "xai": "Management API key"
        case "anthropic": "sk-ant-admin-..."
        case "openrouter": "Management API key"
        default: "Admin API key"
        }
    }
}
