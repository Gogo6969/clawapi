import SwiftUI
import Shared

struct SettingsView: View {
    @EnvironmentObject private var store: PolicyStore
    @Environment(\.dismiss) private var dismiss

    @State private var mode: ConnectionMode
    @State private var sshHost: String
    @State private var sshPort: String
    @State private var sshUser: String
    @State private var sshKeyPath: String
    @State private var remoteOpenClawPath: String

    @State private var testStatus: TestStatus = .idle
    @State private var testMessage: String = ""

    enum TestStatus {
        case idle, testing, success, failed
    }

    init() {
        let settings = ConnectionSettings.load()
        _mode = State(initialValue: settings.mode)
        _sshHost = State(initialValue: settings.sshHost)
        _sshPort = State(initialValue: "\(settings.sshPort)")
        _sshUser = State(initialValue: settings.sshUser)
        _sshKeyPath = State(initialValue: settings.sshKeyPath)
        _remoteOpenClawPath = State(initialValue: settings.remoteOpenClawPath)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Settings", systemImage: "gearshape.fill")
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Connection Mode
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connection Mode")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Picker("Mode", selection: $mode) {
                            Label("Local (this Mac)", systemImage: "desktopcomputer")
                                .tag(ConnectionMode.local)
                            Label("Remote (SSH)", systemImage: "server.rack")
                                .tag(ConnectionMode.remote)
                        }
                        .pickerStyle(.segmented)

                        if mode == .local {
                            Text("ClawAPI manages OpenClaw on this Mac. No SSH needed.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("ClawAPI connects to your VPS via SSH to manage OpenClaw remotely.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // SSH fields (only shown in remote mode)
                    if mode == .remote {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("SSH Connection")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Host").font(.caption).foregroundStyle(.secondary)
                                    TextField("server.example.com", text: $sshHost)
                                        .textFieldStyle(.roundedBorder)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Port").font(.caption).foregroundStyle(.secondary)
                                    TextField("22", text: $sshPort)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 70)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("User").font(.caption).foregroundStyle(.secondary)
                                TextField("ubuntu", text: $sshUser)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("SSH Key Path").font(.caption).foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    TextField("~/.ssh/id_ed25519", text: $sshKeyPath)
                                        .textFieldStyle(.roundedBorder)
                                    Button("Browse...") {
                                        browseForSSHKey()
                                    }
                                    .controlSize(.small)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Remote OpenClaw Path").font(.caption).foregroundStyle(.secondary)
                                TextField("~/.openclaw", text: $remoteOpenClawPath)
                                    .textFieldStyle(.roundedBorder)
                            }

                            // Test Connection
                            HStack(spacing: 12) {
                                Button {
                                    testConnection()
                                } label: {
                                    HStack(spacing: 6) {
                                        if testStatus == .testing {
                                            ProgressView()
                                                .controlSize(.small)
                                        }
                                        Text("Test Connection")
                                    }
                                }
                                .disabled(sshHost.isEmpty || sshUser.isEmpty || testStatus == .testing)

                                switch testStatus {
                                case .idle:
                                    EmptyView()
                                case .testing:
                                    Text("Connecting...")
                                        .font(.caption).foregroundStyle(.secondary)
                                case .success:
                                    Label("Connected", systemImage: "checkmark.circle.fill")
                                        .font(.caption).foregroundStyle(.green)
                                case .failed:
                                    Label(testMessage, systemImage: "xmark.circle.fill")
                                        .font(.caption).foregroundStyle(.red)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(16)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveSettings()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 520, height: mode == .remote ? 560 : 280)
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    // MARK: - Actions

    private func browseForSSHKey() {
        let panel = NSOpenPanel()
        panel.title = "Select SSH Key"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSString(string: "~/.ssh").expandingTildeInPath)
        panel.showsHiddenFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            sshKeyPath = url.path
        }
    }

    private func testConnection() {
        testStatus = .testing
        testMessage = ""

        let settings = buildSettings()

        Task.detached {
            let error = RemoteShell.testConnection(settings: settings)
            await MainActor.run {
                if let error {
                    testStatus = .failed
                    testMessage = error
                } else {
                    testStatus = .success
                    testMessage = ""
                }
            }
        }
    }

    private func buildSettings() -> ConnectionSettings {
        ConnectionSettings(
            mode: mode,
            sshHost: sshHost.trimmingCharacters(in: .whitespaces),
            sshUser: sshUser.trimmingCharacters(in: .whitespaces),
            sshKeyPath: sshKeyPath.trimmingCharacters(in: .whitespaces),
            sshPort: Int(sshPort) ?? 22,
            remoteOpenClawPath: remoteOpenClawPath.trimmingCharacters(in: .whitespaces)
        )
    }

    private func saveSettings() {
        let settings = buildSettings()
        settings.save()
        OpenClawConfig.connectionSettings = settings

        // Trigger a full re-sync with the (now potentially remote) OpenClaw
        store.save(fullSync: true)

        dismiss()
    }
}
