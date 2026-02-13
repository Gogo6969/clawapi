import SwiftUI
import Shared

struct UpdateView: View {
    @ObservedObject var checker: UpdateChecker
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Software Update", systemImage: "arrow.down.circle.fill")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content based on status
            Group {
                switch checker.status {
                case .idle, .checking:
                    checkingView
                case .upToDate:
                    upToDateView
                case .available(let manifest):
                    availableView(manifest)
                case .downloading(let progress):
                    downloadingView(progress)
                case .installing:
                    installingView
                case .error(let message):
                    errorView(message)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)

            Divider()

            // Footer
            HStack {
                Text("Current version: \(AppVersion.current) (build \(AppVersion.build))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if case .available = checker.status {
                    // No "Done" when update is available — show the action button instead
                } else if case .downloading = checker.status {
                    // Don't show Done while downloading
                } else if case .installing = checker.status {
                    // Don't show Done while installing
                } else {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
        .frame(width: 460, height: 360)
        .task {
            if checker.status == .idle {
                await checker.checkForUpdates()
            }
        }
    }

    // MARK: - Sub-views

    private var checkingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Checking for updates...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var upToDateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("ClawAPI is up to date")
                .font(.title3)
                .fontWeight(.semibold)
            Text("You're running the latest version (\(AppVersion.current)).")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func availableView(_ manifest: UpdateManifest) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ClawAPI \(manifest.version) is available")
                        .font(.headline)
                    Text("You have version \(AppVersion.current)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Release notes
            GroupBox("What's New") {
                ScrollView {
                    Text(manifest.releaseNotes)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                }
            }
            .frame(maxHeight: 120)

            Button {
                Task {
                    await checker.downloadAndInstall(manifest: manifest)
                }
            } label: {
                Text("Update Now")
                    .font(.headline)
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func downloadingView(_ progress: Double) -> some View {
        VStack(spacing: 16) {
            ProgressView(value: progress) {
                Text("Downloading update...")
                    .font(.headline)
            }
            .progressViewStyle(.linear)
            .frame(maxWidth: 300)

            Text("\(Int(progress * 100))%")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var installingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Installing update...")
                .font(.headline)
            Text("ClawAPI will restart automatically.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text("Update Error")
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button {
                Task {
                    await checker.checkForUpdates()
                }
            } label: {
                Text("Try Again")
                    .frame(maxWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
