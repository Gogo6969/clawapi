import SwiftUI
import AppKit
import Shared

// MARK: - Title bar branding (shield + "ClawAPI" in the leading title bar area)

enum TitleBarBranding {
    static func install() {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first(where: {
                $0.identifier?.rawValue == "main" || $0.title == "ClawAPI"
            }) ?? NSApplication.shared.mainWindow else { return }

            // Disable fullscreen — ClawAPI is a utility window, not a document editor
            window.collectionBehavior.remove(.fullScreenPrimary)

            // Don't add twice
            let brandingID = NSUserInterfaceItemIdentifier("clawapi-branding")
            if window.titlebarAccessoryViewControllers.contains(where: { $0.view.identifier == brandingID }) { return }

            let hostingView = NSHostingView(rootView:
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.91, green: 0.22, blue: 0.22))
                        .symbolRenderingMode(.hierarchical)
                    Text("ClawAPI")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .padding(.leading, 6)
            )
            hostingView.identifier = brandingID
            hostingView.frame.size = hostingView.fittingSize

            let accessory = NSTitlebarAccessoryViewController()
            accessory.view = hostingView
            accessory.layoutAttribute = .leading
            window.addTitlebarAccessoryViewController(accessory)
        }
    }
}

enum AppTab: Hashable {
    case providers, model, activity, logs, usage
}

struct ContentView: View {
    @EnvironmentObject var store: PolicyStore
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = true
    @State private var selectedTab: AppTab = .providers
    @State private var showingAddScope = false
    @State private var showingPendingReview = false
    @State private var showingHelp = false
    @State private var showingFAQ = false
    @State private var showingUpdate = false
    @StateObject private var updateChecker = UpdateChecker()
    @State private var logsFilter: AuditResult?

    var body: some View {
        TabView(selection: $selectedTab) {
            CredentialsView(selectedTab: $selectedTab, showingPendingReview: $showingPendingReview, logsFilter: $logsFilter)
                .tabItem {
                    Label("Providers", systemImage: "key")
                }
                .tag(AppTab.providers)

            ModelSelectorView()
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(AppTab.model)

            ActivityView(selectedTab: $selectedTab, showingPendingReview: $showingPendingReview, logsFilter: $logsFilter)
                .tabItem {
                    Label("Activity", systemImage: "gauge")
                }
                .tag(AppTab.activity)

            LogsView(selectedTab: $selectedTab, showingPendingReview: $showingPendingReview, filterResult: $logsFilter)
                .tabItem {
                    Label("Logs", systemImage: "list.bullet.rectangle")
                }
                .tag(AppTab.logs)

            UsageView()
                .tabItem {
                    Label("Usage", systemImage: "chart.bar")
                }
                .tag(AppTab.usage)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddScope = true
                } label: {
                    Label("Add Provider", systemImage: "plus")
                }
                .help("Connect a new API provider for OpenClaw to use")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingPendingReview = true
                } label: {
                    Label("Review Pending", systemImage: "bell.badge")
                }
                .badge(store.pendingRequests.count)
                .help("Review pending requests from OpenClaw")
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    showingFAQ = true
                } label: {
                    Label("FAQ", systemImage: "book")
                }
                .help("FAQ and setup guide")
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    showingHelp.toggle()
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
                .help("Quick guide")
                .popover(isPresented: $showingHelp, arrowEdge: .bottom) {
                    HelpPopoverView()
                }
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation {
                        hasSeenWelcome = false
                    }
                } label: {
                    Label("Welcome", systemImage: "house")
                }
                .help("Show the welcome start screen again")
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    showingUpdate = true
                } label: {
                    Label("Updates", systemImage: updateChecker.hasUpdate ? "arrow.down.circle.fill" : "arrow.down.circle")
                }
                .help("Check for ClawAPI updates")
            }
        }
        .onAppear {
            if !ScreenshotMode.isEnabled {
                TitleBarBranding.install()
            }
        }
        .task {
            // Auto-check for updates on launch (silent, non-blocking)
            guard !ScreenshotMode.isEnabled else { return }
            try? await Task.sleep(for: .seconds(2)) // let the UI settle
            await updateChecker.checkForUpdates()
            if case .available = updateChecker.status {
                showingUpdate = true
            }
        }
        .sheet(isPresented: $showingAddScope) {
            AddScopeSheet()
        }
        .sheet(isPresented: $showingPendingReview) {
            PendingReviewSheet()
        }
        .sheet(isPresented: $showingFAQ) {
            FAQView()
        }
        .sheet(isPresented: $showingUpdate) {
            UpdateView(checker: updateChecker)
        }
    }
}
