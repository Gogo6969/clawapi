import SwiftUI
import Shared

@main
struct ClawAPIApp: App {
    @StateObject private var store = PolicyStore()
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("skippedGetStarted") private var skippedGetStarted = false
    @State private var showOpenClawMissing = false

    var body: some Scene {
        Window("ClawAPI", id: "main") {
            Group {
                if !hasSeenWelcome {
                    WelcomeView {
                        withAnimation {
                            hasSeenWelcome = true
                        }
                    }
                    .frame(minWidth: 800, minHeight: 700)
                } else if store.policies.isEmpty && !skippedGetStarted {
                    GetStartedView()
                        .environmentObject(store)
                        .frame(minWidth: 800, minHeight: 700)
                } else {
                    ContentView()
                        .environmentObject(store)
                        .frame(minWidth: 800, minHeight: 600)
                }
            }
            .alert("OpenClaw Not Found", isPresented: $showOpenClawMissing) {
                Button("OK") { }
            } message: {
                Text("ClawAPI only works as intended with OpenClaw installed.\n\nInstall OpenClaw first, then relaunch ClawAPI.")
            }
            .task {
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
                    ScreenshotMode.runAll(store: store)
                }
            }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 700)
    }
}
