import SwiftUI
import Shared

@main
struct ClawAPIApp: App {
    @StateObject private var store = PolicyStore()
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("skippedGetStarted") private var skippedGetStarted = false

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
            .task {
                // Register ClawAPI with MCPorter on every launch (silent, idempotent)
                MCPorterRegistration.ensureRegistered()

                // Screenshot mode: render all pages to PNG and exit
                if ScreenshotMode.isEnabled {
                    try? await Task.sleep(for: .seconds(1))
                    ScreenshotMode.runAll(store: store)
                }
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 700)
    }
}
