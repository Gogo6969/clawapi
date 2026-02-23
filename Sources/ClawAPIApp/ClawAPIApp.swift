import SwiftUI
import Shared

@main
struct ClawAPIApp: App {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("skippedGetStarted") private var skippedGetStarted = false
    @AppStorage("acknowledgedFolderAccess") private var acknowledgedFolderAccess = false
    @State private var showOpenClawMissing = false
    @StateObject private var storeHolder = StoreHolder()

    var body: some Scene {
        Window("ClawAPI", id: "main") {
            Group {
                if !acknowledgedFolderAccess {
                    FolderAccessView {
                        acknowledgedFolderAccess = true
                        storeHolder.initialize()
                    }
                    .frame(minWidth: 800, minHeight: 500)
                } else if !hasSeenWelcome {
                    WelcomeView {
                        withAnimation {
                            hasSeenWelcome = true
                        }
                    }
                    .frame(minWidth: 800, minHeight: 600)
                } else if let store = storeHolder.store,
                          store.policies.isEmpty && !skippedGetStarted {
                    GetStartedView()
                        .environmentObject(store)
                        .frame(minWidth: 800, minHeight: 700)
                } else if let store = storeHolder.store {
                    ContentView()
                        .environmentObject(store)
                        .frame(minWidth: 960, minHeight: 600)
                } else {
                    ProgressView("Loading…")
                        .frame(minWidth: 800, minHeight: 600)
                }
            }
            .alert("OpenClaw Not Found", isPresented: $showOpenClawMissing) {
                Button("OK") { }
            } message: {
                Text("ClawAPI only works as intended with OpenClaw installed.\n\nInstall OpenClaw first, then relaunch ClawAPI.")
            }
            .task {
                // Initialize store on launch if user already acknowledged folder access
                if acknowledgedFolderAccess && storeHolder.store == nil {
                    storeHolder.initialize()
                }
            }
            .task(id: storeHolder.store != nil) {
                guard let store = storeHolder.store else { return }

                // Auto-check API keys on launch (free, no tokens consumed)
                if !store.policies.isEmpty {
                    try? await Task.sleep(for: .seconds(1)) // let UI settle
                    store.checkAllKeys()
                }

                // Register ClawAPI with MCPorter on every launch (silent, idempotent)
                MCPorterRegistration.ensureRegistered()

                // Warn if OpenClaw is not installed
                if !OpenClawDetection.isInstalled {
                    try? await Task.sleep(for: .seconds(0.5))
                    showOpenClawMissing = true
                }

                // Screenshot mode: render all pages to PNG and exit
                if ScreenshotMode.isEnabled {
                    try? await Task.sleep(for: .seconds(1))
                    if let store = storeHolder.store {
                        ScreenshotMode.runAll(store: store)
                    }
                }
            }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1060, height: 720)
    }
}

// MARK: - Deferred PolicyStore holder

/// Holds the PolicyStore and defers its creation until after the user
/// acknowledges the folder access explanation.
@MainActor
final class StoreHolder: ObservableObject {
    @Published var store: PolicyStore?

    func initialize() {
        guard store == nil else { return }
        store = PolicyStore()
    }
}

// MARK: - Folder Access Explanation

struct FolderAccessView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
                .padding(.bottom, 20)

            Text("Folder Access Required")
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 12)

            Text("ClawAPI needs to read OpenClaw's configuration files.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("What it accesses")
                            .fontWeight(.semibold)
                        Text("Only **~/.openclaw/** — OpenClaw's config and auth profiles.")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("What it does NOT access")
                            .fontWeight(.semibold)
                        Text("ClawAPI does **not** read, write, or modify your Documents, Desktop, Downloads, or any other personal folders.")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.orange)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Why macOS asks")
                            .fontWeight(.semibold)
                        Text("macOS treats **~/.openclaw/** as part of your home directory and requires permission to access it. This is a standard macOS security prompt.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.callout)
            .padding(24)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 60)

            Spacer()

            Text("After clicking Continue, macOS may ask you to allow folder access.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            Button("Continue") {
                onContinue()
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)

            Spacer().frame(height: 24)
        }
    }
}
