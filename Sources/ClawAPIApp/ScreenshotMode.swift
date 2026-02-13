import SwiftUI
import Shared

/// Renders each page of the app to PNG files for marketing.
/// Usage: Launch the app with environment variable SCREENSHOT_MODE=1
/// and mock data pre-loaded.
@MainActor
enum ScreenshotMode {

    static let outputDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/ClawAPI/Support/screenshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["SCREENSHOT_MODE"] == "1"
    }

    // MARK: - Render a SwiftUI view to a @2x PNG using an off-screen NSWindow

    static func render<V: View>(_ view: V, width: CGFloat, height: CGFloat, to filename: String) {
        // Create an off-screen window — this gives full AppKit backing (Lists, etc. render correctly)
        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: width, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: view.frame(width: width, height: height))
        window.orderFrontRegardless()

        // Force multiple layout passes
        window.contentView?.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        window.contentView?.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        guard let contentView = window.contentView else {
            print("  ✗ No contentView for \(filename)")
            window.close()
            return
        }

        let frame = contentView.bounds
        guard let bitmapRep = contentView.bitmapImageRepForCachingDisplay(in: frame) else {
            print("  ✗ Failed to create bitmap for \(filename)")
            window.close()
            return
        }

        contentView.cacheDisplay(in: frame, to: bitmapRep)
        window.close()

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("  ✗ Failed to create PNG for \(filename)")
            return
        }

        let path = outputDir.appendingPathComponent("\(filename).png")
        do {
            try pngData.write(to: path)
            print("  ✓ \(filename).png (\(Int(width))×\(Int(height)))")
        } catch {
            print("  ✗ Write error: \(error)")
        }
    }

    // MARK: - Run all screenshots

    static func runAll(store: PolicyStore) {
        // Load mock data directly into the store
        store.policies = MockData.policies
        store.auditEntries = MockData.auditEntries
        store.pendingRequests = MockData.pendingRequests

        print("\n=== ClawAPI Screenshot Mode ===")
        print("Output: \(outputDir.path)")
        print("Store: \(store.policies.count) policies, \(store.auditEntries.count) audit entries, \(store.pendingRequests.count) pending\n")

        // Render at 1200×840 for higher resolution screenshots
        let appWidth: CGFloat = 1200
        let appHeight: CGFloat = 840

        // Tighter size for content-driven pages (Welcome, How It Works, Get Started)
        let contentWidth: CGFloat = 900
        let contentHeight: CGFloat = 700

        // 1. Welcome Page 1 (Start)
        print("1/9: Welcome — Start")
        render(
            WelcomePage1Wrapper()
                .background(.background),
            width: contentWidth, height: contentHeight,
            to: "01-welcome-start"
        )

        // 2. Welcome Page 2 (How It Works)
        print("2/9: Welcome — How It Works")
        render(
            WelcomePage2Wrapper()
                .background(.background),
            width: contentWidth, height: contentHeight,
            to: "02-how-it-works"
        )

        // 3. Providers tab
        print("3/9: Providers")
        render(
            ProvidersScreenshot(store: store)
                .background(.background),
            width: appWidth, height: appHeight,
            to: "03-providers"
        )

        // 4. Activity tab
        print("4/9: Activity")
        render(
            ActivityScreenshot(store: store)
                .background(.background),
            width: appWidth, height: appHeight,
            to: "04-activity"
        )

        // 5. Logs tab
        print("5/9: Logs")
        render(
            LogsScreenshot(store: store)
                .background(.background),
            width: appWidth, height: appHeight,
            to: "05-logs"
        )

        // 6. Quick Guide popover
        print("6/9: Quick Guide")
        render(
            HelpPopoverView()
                .padding()
                .background(.background),
            width: 480, height: 500,
            to: "06-quick-guide"
        )

        // 7. FAQ
        print("7/9: FAQ")
        render(
            FAQView()
                .background(.background),
            width: 720, height: 790,
            to: "07-faq"
        )

        // 8. Get Started — provider picker
        print("8/9: Get Started")
        render(
            GetStartedScreenshot(store: store)
                .background(.background),
            width: contentWidth, height: contentHeight,
            to: "08-get-started"
        )

        // 9. Add Provider — form
        print("9/9: Add Provider — Form")
        render(
            AddScopeSheet()
                .environmentObject(store)
                .background(.background),
            width: 650, height: 740,
            to: "09-add-provider"
        )

        print("\n✓ All screenshots saved to \(outputDir.path)")
        print("Exiting screenshot mode.\n")

        // Exit after screenshots
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }
}

// MARK: - Wrapper views for screenshot mode
// These wrap the private views from WelcomeView.swift into standalone views

struct WelcomePage1Wrapper: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 28)
                VStack(spacing: 12) {
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.system(size: 56))
                        .foregroundStyle(Color(red: 0.91, green: 0.22, blue: 0.22))
                        .symbolRenderingMode(.hierarchical)
                    Text("ClawAPI")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("Secure API Tool for OpenClaw")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("OpenClaw needs to call APIs — but it should never see your passwords or API keys. ClawAPI is a secure tool that injects your credentials into requests server-side, so OpenClaw only sees the API response.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 520)
                }
                Spacer().frame(height: 24)
                VStack(alignment: .leading, spacing: 16) {
                    ScreenshotFeatureRow(icon: "lock.shield.fill", color: .blue, title: "Zero Credential Exposure",
                        description: "OpenClaw never sees your passwords or API keys. ClawAPI injects them server-side and returns only the API response.")
                    ScreenshotFeatureRow(icon: "key.fill", color: .green, title: "Encrypted in the Keychain",
                        description: "Your credentials are encrypted in the macOS Keychain. No one with just file access can see or misuse them.")
                    ScreenshotFeatureRow(icon: "list.bullet.rectangle.fill", color: .orange, title: "Full Audit Trail",
                        description: "Every proxied request is logged. See what was accessed, when, and why.")
                    ScreenshotFeatureRow(icon: "pause.circle.fill", color: .purple, title: "Pause or Remove Anytime",
                        description: "Change access mode or delete any provider from the Providers tab. OpenClaw instantly loses access.")
                }
                .frame(maxWidth: 520)
                Spacer().frame(height: 24)
                Button {} label: {
                    HStack(spacing: 6) {
                        Text("How It Works").font(.headline)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Spacer().frame(height: 16)
                Text("ClawAPI is provided as-is, without warranty of any kind. You are solely responsible for the credentials you store and the providers you connect. Use at your own risk.")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
                Spacer().frame(height: 20)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ScreenshotFeatureRow: View {
    let icon: String; let color: Color; let title: String; let description: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Text(description).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct WelcomePage2Wrapper: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)
            Label("How It Works", systemImage: "questionmark.circle.fill")
                .font(.title2).fontWeight(.semibold)
            Text("Example: let OpenClaw call the OpenAI API for you")
                .font(.callout).foregroundStyle(.secondary)
                .padding(.top, 4).padding(.bottom, 20)
            VStack(alignment: .leading, spacing: 20) {
                ScreenshotStep(number: 1, icon: "plus.circle.fill", color: .blue, title: "Add a Provider",
                    example: "Click + and select OpenAI. Paste your API key. That's it.")
                ScreenshotStep(number: 2, icon: "key.fill", color: .green, title: "Credential Stored Securely",
                    example: "Your API key is encrypted in the macOS Keychain — never stored as plain text.")
                ScreenshotStep(number: 3, icon: "puzzlepiece.extension.fill", color: .orange, title: "OpenClaw Finds It Automatically",
                    example: "ClawAPI registers itself with OpenClaw — no setup needed. When OpenClaw needs to call an API, it discovers ClawAPI and uses it to inject your credentials. OpenClaw never sees the key.")
                ScreenshotStep(number: 4, icon: "eye.fill", color: .purple, title: "You Stay in Control",
                    example: "Every proxied request is logged. Change access mode or delete any provider from the Providers tab.")
            }
            .frame(maxWidth: 480)
            Text("Works for any API provider: OpenAI, GitHub, Stripe, and any provider with an API key or token.")
                .font(.caption).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center).padding(.top, 16)
            Spacer()
            HStack(spacing: 16) {
                Button {} label: {
                    HStack(spacing: 6) { Image(systemName: "arrow.left"); Text("Back") }
                        .frame(maxWidth: 120)
                }.buttonStyle(.bordered).controlSize(.large)
                Button {} label: {
                    Text("Get Started").font(.headline).frame(maxWidth: 220)
                }.buttonStyle(.borderedProminent).controlSize(.large)
            }
            Text("Reopen anytime from the house icon, or check the FAQ from the book icon.")
                .font(.caption).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center).padding(.top, 8)
            Spacer().frame(height: 24)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ScreenshotStep: View {
    let number: Int; let icon: String; let color: Color; let title: String; let example: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)").font(.caption2).fontWeight(.bold).foregroundStyle(.white)
                .frame(width: 24, height: 24).background(color, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon).font(.headline).foregroundStyle(color)
                Text(example).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Tab screenshots using the actual views

struct ProvidersScreenshot: View {
    let store: PolicyStore
    var body: some View {
        CredentialsView(
            selectedTab: .constant(.providers),
            showingPendingReview: .constant(false),
            logsFilter: .constant(nil)
        )
        .environmentObject(store)
    }
}

struct ActivityScreenshot: View {
    let store: PolicyStore
    var body: some View {
        ActivityView(
            selectedTab: .constant(.activity),
            showingPendingReview: .constant(false),
            logsFilter: .constant(nil)
        )
        .environmentObject(store)
    }
}

struct LogsScreenshot: View {
    let store: PolicyStore
    var body: some View {
        LogsView(
            selectedTab: .constant(.logs),
            showingPendingReview: .constant(false),
            filterResult: .constant(nil)
        )
        .environmentObject(store)
    }
}

struct GetStartedScreenshot: View {
    let store: PolicyStore
    var body: some View {
        GetStartedView()
            .environmentObject(store)
    }
}
