import SwiftUI
import Shared
import AppKit

/// Handles the OAuth onboarding flow for providers like OpenAI Codex.
///
/// Because OpenClaw's `onboard` command uses a TUI wizard with multiple
/// interactive prompts, we open it in Terminal.app and poll for the
/// resulting OAuth profile in auth-profiles.json.
struct OAuthFlowView: View {
    let template: ServiceTemplate
    let onComplete: (ScopePolicy) -> Void
    let onCancel: () -> Void

    @State private var step: OAuthStep = .instructions
    @State private var isPolling = false
    @State private var errorMessage: String?
    @State private var terminalLaunched = false

    private enum OAuthStep {
        case instructions
        case waiting
        case success
        case error
    }

    /// The OpenClaw `--auth-choice` value for this template.
    private var authChoice: String {
        if case .oauth(let provider) = template.authMethod {
            return provider
        }
        return template.scope
    }

    /// The expected profile key in auth-profiles.json.
    private var expectedProfileKey: String {
        "\(authChoice):default"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                if step == .instructions {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text(step == .success ? "\(template.name) Connected" : "Set Up \(template.name)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer()

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            Group {
                switch step {
                case .instructions:
                    instructionsView
                case .waiting:
                    waitingView
                case .success:
                    successView
                case .error:
                    errorView
                }
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    isPolling = false
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                switch step {
                case .instructions:
                    Button("Open Terminal & Start") {
                        launchTerminal()
                    }
                    .keyboardShortcut(.defaultAction)
                case .waiting:
                    Button("Check Now") {
                        Task { await checkForProfile() }
                    }
                case .success:
                    EmptyView()
                case .error:
                    Button("Try Again") {
                        step = .instructions
                        errorMessage = nil
                    }
                }
            }
            .padding()
        }
        .frame(width: 520, height: step == .success ? 280 : 460)
    }

    // MARK: - Step Views

    private var instructionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Badge
                HStack(spacing: 10) {
                    Image(systemName: "person.badge.key")
                        .font(.title)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("OAuth Authentication")
                            .font(.headline)
                        Text("Sign in with your OpenAI account — no API key needed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    instructionRow(number: 1, text: "Click **\"Open Terminal & Start\"** below")
                    instructionRow(number: 2, text: "In the Terminal, OpenClaw will guide you through the setup wizard")
                    instructionRow(number: 3, text: "When prompted for auth, a browser window will open")
                    instructionRow(number: 4, text: "Sign in with your OpenAI account and authorize access")
                    instructionRow(number: 5, text: "Once complete, return here — ClawAPI will detect the new connection automatically")
                }

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Uses **ChatGPT Plus** quota — no separate API billing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(20)
        }
    }

    private var waitingView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("Waiting for OAuth sign-in...")
                .font(.headline)

            Text("Complete the setup in the Terminal window.\nClawAPI will detect the connection automatically.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if terminalLaunched {
                Button("Re-open Terminal") {
                    launchTerminal()
                }
                .buttonStyle(.link)
                .font(.caption)
            }

            Spacer()
        }
        .padding(20)
        .task {
            await pollForProfile()
        }
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)

            Text("\(template.name) connected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("OAuth credentials are managed by OpenClaw")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("OAuth Setup Failed")
                .font(.title3)
                .fontWeight(.semibold)

            if let msg = errorMessage {
                Text(msg)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Helpers

    private func instructionRow(number: Int, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.blue, in: Circle())
            Text(text)
                .font(.callout)
        }
    }

    // MARK: - Terminal Launch

    private func launchTerminal() {
        // Build the openclaw onboard command
        let cmd = "/opt/homebrew/bin/openclaw onboard --auth-choice \(authChoice) --skip-daemon --skip-channels --skip-skills --skip-health --skip-ui"

        // Open Terminal.app with the command
        let script = """
        tell application "Terminal"
            activate
            do script "\(cmd)"
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                errorMessage = "Failed to open Terminal: \(error)"
                step = .error
                return
            }
        }

        terminalLaunched = true
        withAnimation { step = .waiting }
    }

    // MARK: - Profile Polling

    private func pollForProfile() async {
        isPolling = true
        // Poll every 3 seconds for up to 5 minutes
        for _ in 0..<100 {
            guard isPolling else { return }
            try? await Task.sleep(for: .seconds(3))
            guard isPolling else { return }

            if await checkForProfile() {
                return
            }
        }

        // Timeout
        if isPolling {
            errorMessage = "Timed out waiting for OAuth sign-in. Please try again."
            withAnimation { step = .error }
        }
    }

    @discardableResult
    private func checkForProfile() async -> Bool {
        let profiles = OpenClawConfig.listOAuthProfiles()
        if profiles.contains(where: { $0.profileKey == expectedProfileKey }) {
            isPolling = false

            // Create the policy
            let policy = ScopePolicy(
                serviceName: template.name,
                scope: template.scope,
                allowedDomains: template.domains,
                approvalMode: .auto,
                hasSecret: false,  // OAuth tokens are in auth-profiles.json, not Keychain
                credentialType: template.credentialType,
                preferredFor: template.suggestedTags
            )

            withAnimation { step = .success }

            // Auto-complete after a brief delay
            try? await Task.sleep(for: .seconds(1.5))
            onComplete(policy)
            return true
        }
        return false
    }
}
