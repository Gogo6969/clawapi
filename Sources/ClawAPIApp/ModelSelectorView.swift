import SwiftUI
import Shared

struct ModelSelectorView: View {
    @EnvironmentObject var store: PolicyStore

    private var enabledProviders: [ScopePolicy] {
        store.policies
            .filter { $0.isEnabled && $0.hasSecret && $0.approvalMode == .auto }
            .sorted { $0.priority < $1.priority }
    }

    private var currentModel: String? {
        OpenClawConfig.currentModel()
    }

    private var currentFallbacks: [String] {
        OpenClawConfig.currentFallbacks()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("OpenClaw Sync")
                        .font(.headline)
                    Text("Your models, keys, and priorities — synced to OpenClaw automatically")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if OpenClawConfig.isInstalled {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("Not Installed", systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding()

            Divider()

            List {
                // Current model
                Section("Active Model") {
                    if let model = currentModel {
                        HStack(spacing: 10) {
                            Image(systemName: "brain")
                                .font(.title3)
                                .foregroundStyle(.green)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model)
                                    .font(.system(.body, design: .monospaced, weight: .medium))
                                Text("Primary model in OpenClaw")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text("No model configured in OpenClaw")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !currentFallbacks.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fallback chain:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(Array(currentFallbacks.enumerated()), id: \.offset) { i, fb in
                                HStack(spacing: 6) {
                                    Text("\(i + 1).")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 16, alignment: .trailing)
                                    Text(fb)
                                        .font(.system(.caption, design: .monospaced))
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                // Synced providers
                Section {
                    if enabledProviders.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text("No enabled providers. Add and enable providers in the Providers tab.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(Array(enabledProviders.enumerated()), id: \.element.id) { index, policy in
                            SyncedProviderRow(policy: policy, rank: index + 1, isFirst: index == 0)
                        }
                    }
                } header: {
                    Text("Synced Providers")
                } footer: {
                    if !enabledProviders.isEmpty {
                        Text("ClawAPI writes API keys directly into OpenClaw's auth-profiles.json. The #1 provider's default model becomes OpenClaw's primary model. Reorder in the Providers tab.")
                    }
                }

                // How it works
                Section("How It Works") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(icon: "1.circle.fill", color: .blue,
                                text: "You add API keys in ClawAPI's Providers tab")
                        InfoRow(icon: "2.circle.fill", color: .blue,
                                text: "ClawAPI syncs keys into OpenClaw's auth-profiles.json on every change")
                        InfoRow(icon: "3.circle.fill", color: .blue,
                                text: "The top-priority provider becomes OpenClaw's primary model")
                        InfoRow(icon: "4.circle.fill", color: .green,
                                text: "OpenClaw talks directly to providers using your API keys — fast and native")
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }
}

// MARK: - Synced Provider Row

private struct SyncedProviderRow: View {
    let policy: ScopePolicy
    let rank: Int
    let isFirst: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundStyle(isFirst ? .green : .secondary)
                .frame(width: 32, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(policy.serviceName)
                        .font(.subheadline)
                        .fontWeight(isFirst ? .semibold : .regular)
                    if isFirst {
                        Text("primary")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }

                let defaultModel = ServiceCatalog.modelsForScope(policy.scope).first(where: \.isDefault)
                if let model = defaultModel {
                    Text(model.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                } else {
                    Text(policy.scope)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }
}
