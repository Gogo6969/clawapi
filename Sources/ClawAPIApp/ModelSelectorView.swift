import SwiftUI
import Shared

struct ModelSelectorView: View {
    @EnvironmentObject var store: PolicyStore
    @State private var gatewayStatus: GatewayRestartStatus = .idle
    @State private var cleanSlateStatus: CleanSlateStatus = .idle
    @State private var showCleanSlateConfirm = false
    @State private var showRestoreSheet = false
    @State private var cleanSlateError: String?
    @State private var oauthProfiles: [OpenClawConfig.OAuthProfile] = []
    @State private var showRemoveOAuthConfirm = false
    @State private var oauthToRemove: OpenClawConfig.OAuthProfile?
    @State private var oauthRemoveError: String?
    @State private var showOAuthBackups = false

    private enum GatewayRestartStatus: Equatable {
        case idle, restarting, success, failed
    }

    private enum CleanSlateStatus: Equatable {
        case idle, working, success(String), failed
    }

    private var enabledProviders: [ScopePolicy] {
        store.policies
            .filter { $0.isEnabled && ($0.hasSecret || !(ServiceCatalog.find($0.scope)?.requiresKey ?? true)) && $0.approvalMode == .auto }
            .sorted { $0.priority < $1.priority }
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
                // ── Synced Providers ──
                Section {
                    if enabledProviders.isEmpty {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.orange.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.orange)
                            }
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
                        Text("Provider #1 is the primary model in OpenClaw. If it fails, OpenClaw tries each fallback in order. Drag to reorder in the Providers tab.")
                    }
                }

                // ── Gateway Reload ──
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(gatewayStatusColor.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(gatewayStatusColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gateway Reload")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(gatewayStatusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Button {
                            gatewayStatus = .restarting
                            DispatchQueue.global(qos: .utility).async {
                                let ok = OpenClawConfig.restartGateway()
                                DispatchQueue.main.async {
                                    gatewayStatus = ok ? .success : .failed
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

                // ── Clean Slate ──
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(cleanSlateIconColor.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "eraser.line.dashed.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(cleanSlateIconColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clean Slate")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(cleanSlateStatusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
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

                // ── OAuth Connections ──
                if !oauthProfiles.isEmpty {
                    Section {
                        ForEach(oauthProfiles, id: \.profileKey) { profile in
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.blue.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "person.badge.key.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.blue)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.provider)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    HStack(spacing: 4) {
                                        Text("OAuth")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(.blue.opacity(0.15), in: Capsule())
                                            .foregroundStyle(.blue)
                                        if let acct = profile.accountId {
                                            Text(acct.prefix(8) + "...")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .fontDesign(.monospaced)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                    }
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    oauthToRemove = profile
                                    showRemoveOAuthConfirm = true
                                } label: {
                                    Text("Remove")
                                        .frame(width: 64)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.vertical, 2)
                        }

                        if let error = oauthRemoveError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    } header: {
                        HStack {
                            Text("OAuth Connections")
                            Spacer()
                            Button("Backups") {
                                showOAuthBackups = true
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                            .disabled(OpenClawConfig.listOAuthBackups().isEmpty)
                        }
                    } footer: {
                        Text("OAuth connections are managed by OpenClaw. They use your ChatGPT/account login instead of an API key. Removing an OAuth connection creates a backup so you can restore it later.")
                    }
                    .alert("Remove OAuth Connection", isPresented: $showRemoveOAuthConfirm) {
                        Button("Remove", role: .destructive) {
                            if let profile = oauthToRemove {
                                removeOAuthProfile(profile)
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        if let profile = oauthToRemove {
                            Text("Remove the OAuth connection for \(profile.provider)?\n\nA backup will be created automatically. You can restore it from the OAuth Backups sheet, or re-authenticate by adding the provider again in the Providers tab.")
                        }
                    }
                    .sheet(isPresented: $showOAuthBackups) {
                        OAuthBackupSheet()
                    }
                }

                // ── How It Works ──
                Section("How It Works") {
                    VStack(alignment: .leading, spacing: 10) {
                        InfoRow(icon: "1.circle.fill", color: .blue,
                                text: "Add API keys in the Providers tab")
                        InfoRow(icon: "2.circle.fill", color: .blue,
                                text: "ClawAPI syncs keys into OpenClaw's auth-profiles.json")
                        InfoRow(icon: "3.circle.fill", color: .blue,
                                text: "Provider #1 becomes the primary model")
                        InfoRow(icon: "4.circle.fill", color: .blue,
                                text: "Providers #2+ form the fallback chain")
                        InfoRow(icon: "5.circle.fill", color: .green,
                                text: "OpenClaw talks directly to providers — fast and native")
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .onAppear { oauthProfiles = OpenClawConfig.listOAuthProfiles() }
        }
    }

    // MARK: - OAuth helpers

    private func removeOAuthProfile(_ profile: OpenClawConfig.OAuthProfile) {
        oauthRemoveError = nil
        do {
            _ = try OpenClawConfig.removeOAuthProfile(profileKey: profile.profileKey)
            oauthProfiles = OpenClawConfig.listOAuthProfiles()
        } catch {
            oauthRemoveError = error.localizedDescription
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

    private var roleLabel: String {
        isFirst ? "PRIMARY" : "FALLBACK #\(rank - 1)"
    }

    private var roleColor: Color {
        isFirst ? .green : .secondary
    }

    private var displayModel: String {
        if let selected = policy.selectedModel, !selected.isEmpty {
            return selected
        }
        return policy.scope
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFirst ? .green.opacity(0.15) : Color.secondary.opacity(0.08))
                    .frame(width: 36, height: 36)
                Text("#\(rank)")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(roleColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(policy.serviceName)
                        .font(.subheadline)
                        .fontWeight(isFirst ? .semibold : .regular)
                        .lineLimit(1)
                    Text(roleLabel)
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(0.3)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(roleColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(roleColor)
                }

                Text(displayModel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

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
                .lineLimit(2)
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
                                    .lineLimit(1)
                                    .truncationMode(.middle)
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

// MARK: - OAuth Backup Sheet

private struct OAuthBackupSheet: View {
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("OAuth Backups")
                        .font(.headline)
                    Text("Restore a previously removed OAuth connection")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                    Image(systemName: "person.badge.key")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No OAuth backups")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Backups are created when you remove an OAuth connection.")
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
                            Image(systemName: "person.badge.key")
                                .foregroundStyle(.blue)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(dateFmt.string(from: backup.date))
                                    .font(.subheadline)
                                Text(backup.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fontDesign(.monospaced)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
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
                                restoreOAuthBackup(backup.name)
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
        .onAppear { backups = OpenClawConfig.listOAuthBackups() }
        .alert("Delete Backup", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let name = backupToDelete {
                    OpenClawConfig.deleteBackup(name: name)
                    backups = OpenClawConfig.listOAuthBackups()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete this OAuth backup permanently? You won't be able to restore this OAuth connection from it.")
        }
    }

    private func restoreOAuthBackup(_ name: String) {
        restoreError = nil
        do {
            try OpenClawConfig.restoreBackup(name: name)
            dismiss()
        } catch {
            restoreError = error.localizedDescription
        }
    }
}
