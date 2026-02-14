import SwiftUI
import Shared

/// Renders each page of the app to PNG files for marketing.
/// Usage: Launch the app with environment variable SCREENSHOT_MODE=1
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

    // Keep windows alive until all screenshots are done to prevent early deallocation crashes
    private static var keepAlive: [NSWindow] = []

    // MARK: - Render a SwiftUI view to a high-res PNG

    static func render<V: View>(_ view: V, width: CGFloat, height: CGFloat, to filename: String) {
        let scale: CGFloat = 2.0

        // Wrap the view with explicit size and dark background
        let wrappedView = view
            .frame(width: width, height: height)
            .clipped()
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .dark)

        // Create NSHostingView with the exact size
        let hostingView = NSHostingView(rootView: wrappedView)
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)

        // Create an off-screen borderless window (required for proper SwiftUI layout)
        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.backgroundColor = .windowBackgroundColor
        window.orderFrontRegardless()
        keepAlive.append(window)

        // Give SwiftUI multiple run-loop passes to fully lay out
        for _ in 0..<5 {
            hostingView.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }

        let pixelWidth = Int(width * scale)
        let pixelHeight = Int(height * scale)

        // Use bitmapImageRepForCachingDisplay for correct coordinate handling
        guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            print("  ✗ Failed to create bitmap for \(filename)")
            return
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

        // The native bitmap is 1x; scale it up to @2x
        let nativeWidth = bitmapRep.pixelsWide
        let nativeHeight = bitmapRep.pixelsHigh
        print("    native: \(nativeWidth)×\(nativeHeight)")

        // Create a @2x version by drawing into a scaled bitmap
        guard let scaledRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: pixelWidth * 4,
            bitsPerPixel: 32
        ) else {
            print("  ✗ Failed to create scaled bitmap for \(filename)")
            return
        }
        scaledRep.size = NSSize(width: width, height: height)

        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: scaledRep)!
        ctx.imageInterpolation = .high
        NSGraphicsContext.current = ctx

        // Draw the native bitmap scaled up to fill the @2x canvas
        let nativeImage = NSImage(size: NSSize(width: nativeWidth, height: nativeHeight))
        nativeImage.addRepresentation(bitmapRep)
        nativeImage.draw(
            in: NSRect(x: 0, y: 0, width: width, height: height),
            from: NSRect(x: 0, y: 0, width: nativeWidth, height: nativeHeight),
            operation: .copy,
            fraction: 1.0
        )

        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = scaledRep.representation(using: .png, properties: [:]) else {
            print("  ✗ Failed to create PNG for \(filename)")
            return
        }

        let path = outputDir.appendingPathComponent("\(filename).png")
        do {
            try pngData.write(to: path)
            print("  ✓ \(filename).png (\(pixelWidth)×\(pixelHeight) @2x)")
        } catch {
            print("  ✗ Write error: \(error)")
        }
    }

    // MARK: - Run all screenshots

    static func runAll(store: PolicyStore) {
        store.policies = MockData.policies
        store.auditEntries = MockData.auditEntries
        store.pendingRequests = MockData.pendingRequests

        print("\n=== ClawAPI Screenshot Mode ===")
        print("Output: \(outputDir.path)")
        print("Store: \(store.policies.count) policies, \(store.auditEntries.count) audit entries, \(store.pendingRequests.count) pending\n")

        // 1. Welcome Page 1 (Start) — tall enough for all features + hero
        print("1/11: Welcome — Start")
        render(
            WelcomePage1Wrapper()
                .padding(.horizontal, 40)
                .padding(.vertical, 20),
            width: 700, height: 880,
            to: "01-welcome-start"
        )

        // 2. Welcome Page 2 (How It Works)
        print("2/11: Welcome — How It Works")
        render(
            WelcomePage2Wrapper()
                .padding(.horizontal, 40)
                .padding(.vertical, 10),
            width: 700, height: 830,
            to: "02-how-it-works"
        )

        // 3. Providers tab
        print("3/11: Providers")
        render(
            ProvidersScreenshot(store: store),
            width: 1100, height: 700,
            to: "03-providers"
        )

        // 4. Sync tab
        print("4/11: Sync")
        render(
            SyncScreenshot(store: store),
            width: 1100, height: 700,
            to: "04-sync"
        )

        // 5. Activity tab
        print("5/11: Activity")
        render(
            ActivityScreenshot(store: store),
            width: 1100, height: 700,
            to: "05-activity"
        )

        // 6. Logs tab
        print("6/11: Logs")
        render(
            LogsScreenshot(store: store),
            width: 1100, height: 700,
            to: "06-logs"
        )

        // 7. Usage tab
        print("7/11: Usage")
        render(
            UsageScreenshot(store: store),
            width: 1100, height: 700,
            to: "07-usage"
        )

        // 8. Quick Guide popover
        print("8/11: Quick Guide")
        render(
            HelpPopoverView()
                .padding(20),
            width: 460, height: 500,
            to: "08-quick-guide"
        )

        // 9. FAQ
        print("9/11: FAQ")
        render(
            FAQView()
                .padding(10),
            width: 680, height: 760,
            to: "09-faq"
        )

        // 10. Get Started — provider picker
        print("10/11: Get Started")
        render(
            GetStartedScreenshot(store: store)
                .padding(20),
            width: 700, height: 820,
            to: "10-get-started"
        )

        // 11. Add Provider — form
        print("11/11: Add Provider — Form")
        render(
            AddScopeSheet()
                .environmentObject(store)
                .padding(10),
            width: 620, height: 700,
            to: "11-add-provider"
        )

        print("\n✓ All screenshots saved to \(outputDir.path)")
        print("Exiting screenshot mode.\n")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }
}

// MARK: - Wrapper views for screenshot mode
// These mirror the private views from WelcomeView.swift with rebranded content
// IMPORTANT: No ScrollView — must fit in allocated frame

struct WelcomePage1Wrapper: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            // Hero
            VStack(spacing: 14) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 64))
                    .foregroundStyle(Color(red: 0.91, green: 0.22, blue: 0.22))
                    .symbolRenderingMode(.hierarchical)
                Text("ClawAPI")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("Model Switcher & Key Vault for OpenClaw")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("Pick your AI models, save money by switching to cheaper ones when you can, and keep your API keys safe in the macOS Keychain.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }

            Spacer().frame(height: 32)

            // Features
            VStack(alignment: .leading, spacing: 18) {
                ScreenshotFeatureRow(icon: "cpu.fill", color: .blue,
                    title: "Switch Models Instantly",
                    description: "Pick any sub-model from any provider. Your choice syncs to OpenClaw automatically.")
                ScreenshotFeatureRow(icon: "key.fill", color: .green,
                    title: "API Keys in the Keychain",
                    description: "Your keys are stored in the macOS Keychain, encrypted at rest. You can't lose them.")
                ScreenshotFeatureRow(icon: "dollarsign.circle.fill", color: .orange,
                    title: "Save Money",
                    description: "Switch to a cheaper model for everyday tasks. Disable providers you're not using. Only pay for what you need.")
                ScreenshotFeatureRow(icon: "arrow.triangle.2.circlepath", color: .purple,
                    title: "Auto-Sync to OpenClaw",
                    description: "Models, keys, and priorities sync to OpenClaw's config. No manual editing.")
            }
            .frame(maxWidth: 520)

            Spacer().frame(height: 32)

            // CTA button
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
                .frame(maxWidth: 440)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ScreenshotFeatureRow: View {
    let icon: String; let color: Color; let title: String; let description: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body).fontWeight(.semibold)
                Text(description).font(.body).foregroundStyle(.primary.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct WelcomePage2Wrapper: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)

            Label("How It Works", systemImage: "questionmark.circle.fill")
                .font(.title2).fontWeight(.semibold)
            Text("Three steps — that's it")
                .font(.body).foregroundStyle(.secondary)
                .padding(.top, 4).padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 22) {
                ScreenshotStep(number: 1, icon: "plus.circle.fill", color: .blue,
                    title: "Add a Provider",
                    example: "Click + and pick a provider (OpenAI, Claude, Groq, etc.). Paste your API key.")
                ScreenshotStep(number: 2, icon: "cpu.fill", color: .green,
                    title: "Pick Your Model",
                    example: "Use the dropdown next to each provider to choose a sub-model. It becomes your active model instantly.")
                ScreenshotStep(number: 3, icon: "checkmark.circle.fill", color: .orange,
                    title: "Done — OpenClaw Uses It",
                    example: "ClawAPI syncs everything to OpenClaw automatically. Your key is safe in the Keychain, your model is set, and you're ready to go.")
            }
            .frame(maxWidth: 480)

            Text("Supports 15+ providers including OpenAI, Anthropic, xAI, Groq, Mistral, and local models like Ollama.")
                .font(.callout).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center).padding(.top, 16)

            Spacer()

            // Buttons
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
                .font(.callout).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center).padding(.top, 10)

            Spacer().frame(height: 14)

            // Bitcoin donation
            VStack(spacing: 6) {
                BitcoinLogo(size: 44)
                Text("ClawAPI is free — support is much appreciated")
                    .font(.callout).foregroundStyle(.secondary)
                Text("bc1qzu287ld4rskeqwcng7t3ql8mw0z73kw7trcmes")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)

            Spacer().frame(height: 8)

            HStack(spacing: 6) {
                Image(systemName: "eye.slash")
                Text("Never show the Start Screens again")
            }
            .font(.callout).foregroundStyle(.secondary)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(.fill.tertiary, in: Capsule())

            Spacer().frame(height: 16)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ScreenshotStep: View {
    let number: Int; let icon: String; let color: Color; let title: String; let example: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)").font(.caption).fontWeight(.bold).foregroundStyle(.white)
                .frame(width: 26, height: 26).background(color, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon).font(.headline).foregroundStyle(color)
                Text(example).font(.body).foregroundStyle(.secondary)
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

struct SyncScreenshot: View {
    let store: PolicyStore
    var body: some View {
        ModelSelectorView()
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

struct UsageScreenshot: View {
    let store: PolicyStore
    var body: some View {
        UsageView()
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
