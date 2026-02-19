import SwiftUI
import Shared

struct ModelSelectorView: View {
    @EnvironmentObject var store: PolicyStore
    @State private var gatewayStatus: GatewayRestartStatus = .idle
    @State private var cleanSlateStatus: CleanSlateStatus = .idle
    @State private var showCleanSlateConfirm = false
    @State private var showRestoreSheet = false
    @State private var cleanSlateError: String?

    private enum GatewayRestartStatus: Equatable {
        case idle, restarting, success, failed
    }

    private enum CleanSlateStatus: Equatable {
        case idle, working, success(String), failed
    }

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

                // Gateway restart
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.title3)
                            .foregroundStyle(gatewayStatusColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gateway Reload")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(gatewayStatusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            gatewayStatus = .restarting
                            DispatchQueue.global(qos: .utility).async {
                                let ok = OpenClawConfig.restartGateway()
                                DispatchQueue.main.async {
                                    gatewayStatus = ok ? .success : .failed
                                    // Reset after 3 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        gatewayStatus = .idle
                                    }
                                }
                            }
                        } label: {
                            if gatewayStatus == .restarting {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 80)
                            } else {
                                Text("Restart")
                                    .frame(width: 80)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(gatewayStatus == .success ? .green : gatewayStatus == .failed ? .red : .blue)
                        .controlSize(.small)
                        .disabled(gatewayStatus == .restarting || !OpenClawConfig.isInstalled)
                    }
                } footer: {
                    Text("Sends a reload signal to the OpenClaw gateway. Use this if the gateway needs to pick up config changes.")
                }

                // Clean Slate
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "eraser.line.dashed.fill")
                            .font(.title3)
                            .foregroundStyle(cleanSlateIconColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clean Slate")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(cleanSlateStatusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            showRestoreSheet = true
                        } label: {
                            Text("Restore")
                                .frame(width: 64)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!OpenClawConfig.isInstalled || OpenClawConfig.listBackups().isEmpty)

                        Button {
                            showCleanSlateConfirm = true
                        } label: {
                            if case .working = cleanSlateStatus {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 80)
                            } else {
                                Text("Clean Slate")
                                    .frame(width: 80)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                        .disabled(!OpenClawConfig.isInstalled || enabledProviders.isEmpty || cleanSlateStatus == .working)
                    }

                    if let error = cleanSlateError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } footer: {
                    Text("Removes all fallback models and extra provider credentials from OpenClaw. Only the #1 primary model and its API key remain. Creates a backup you can restore.")
                }
                .alert("Clean Slate", isPresented: $showCleanSlateConfirm) {
                    Button("Clean Slate", role: .destructive) {
                        performCleanSlate()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    if let top = enabledProviders.first {
                        let model = top.selectedModel ?? top.scope
                        Text("This will remove all fallback models and other provider credentials from OpenClaw.\n\nOnly \(top.serviceName) (\(model)) will remain.\n\nA backup is created automatically so you can restore later.")
                    }
                }
                .sheet(isPresented: $showRestoreSheet) {
                    RestoreBackupSheet()
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

    private var gatewayStatusColor: Color {
        switch gatewayStatus {
        case .idle: .blue
        case .restarting: .orange
        case .success: .green
        case .failed: .red
        }
    }

    private var gatewayStatusText: String {
        switch gatewayStatus {
        case .idle: "Reload the OpenClaw gateway to apply config changes"
        case .restarting: "Sending reload signal..."
        case .success: "Gateway reloaded successfully"
        case .failed: "Gateway reload failed — is OpenClaw running?"
        }
    }

    // MARK: - Clean Slate helpers

    private var cleanSlateIconColor: Color {
        switch cleanSlateStatus {
        case .idle: .orange
        case .working: .orange
        case .success: .green
        case .failed: .red
        }
    }

    private var cleanSlateStatusText: String {
        switch cleanSlateStatus {
        case .idle: "Remove all fallbacks — use only one provider"
        case .working: "Creating backup and cleaning config..."
        case .success(let backup): "Done — backup saved as \(backup)"
        case .failed: "Clean Slate failed"
        }
    }

    private func performCleanSlate() {
        cleanSlateStatus = .working
        cleanSlateError = nil
        Task {
            do {
                guard await KeychainService.authenticateWithBiometrics(
                    reason: "Authenticate to perform Clean Slate"
                ) else {
                    await MainActor.run {
                        cleanSlateStatus = .idle
                    }
                    return
                }
                store.keychain.preloadAll()
                let backupName = try OpenClawConfig.cleanSlate(
                    policies: store.policies,
                    keychain: store.keychain
                )
                await MainActor.run {
                    cleanSlateStatus = .success(backupName)
                    cleanSlateError = nil
                }
                // Reset status after 5 seconds
                try? await Task.sleep(for: .seconds(5))
                await MainActor.run {
                    if case .success = cleanSlateStatus {
                        cleanSlateStatus = .idle
                    }
                }
            } catch {
                await MainActor.run {
                    cleanSlateStatus = .failed
                    cleanSlateError = error.localizedDescription
                }
                try? await Task.sleep(for: .seconds(10))
                await MainActor.run {
                    if cleanSlateStatus == .failed {
                        cleanSlateStatus = .idle
                        cleanSlateError = nil
                    }
                }
            }
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

// MARK: - Restore Backup Sheet

private struct RestoreBackupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var backups: [(name: String, date: Date)] = []
    @State private var restoreError: String?
    @State private var showDeleteConfirm = false
    @State private var backupToDelete: String?

    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Restore Backup")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding()

            Divider()

            if backups.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No backups available")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Backups are created automatically when you use Clean Slate.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else {
                List {
                    ForEach(backups, id: \.name) { backup in
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.blue)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(dateFmt.string(from: backup.date))
                                    .font(.subheadline)
                                Text(backup.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fontDesign(.monospaced)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                backupToDelete = backup.name
                                showDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)

                            Button("Restore") {
                                restoreBackup(backup.name)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }

            if let error = restoreError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 480, height: 320)
        .onAppear { backups = OpenClawConfig.listBackups() }
        .alert("Delete Backup", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let name = backupToDelete {
                    OpenClawConfig.deleteBackup(name: name)
                    backups = OpenClawConfig.listBackups()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete this backup permanently?")
        }
    }

    private func restoreBackup(_ name: String) {
        restoreError = nil
        do {
            try OpenClawConfig.restoreBackup(name: name)
            dismiss()
        } catch {
            restoreError = error.localizedDescription
        }
    }
}
