import SwiftUI

struct WelcomeView: View {
    var onGetStarted: () -> Void

    @State private var page = 0

    var body: some View {
        Group {
            if page == 0 {
                WelcomePage1 {
                    withAnimation { page = 1 }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            } else {
                WelcomePage2(
                    onBack: { withAnimation { page = 0 } },
                    onGetStarted: onGetStarted
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }
        }
        .background(.background)
    }
}

// MARK: - Page 1: Hero + Features

private struct WelcomePage1: View {
    var onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 48)

                // Hero
                VStack(spacing: 16) {
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.system(size: 72))
                        .foregroundStyle(Color(red: 0.91, green: 0.22, blue: 0.22))
                        .symbolRenderingMode(.hierarchical)

                    Text("ClawAPI")
                        .font(.system(size: 42, weight: .bold, design: .rounded))

                    Text("Secure API Tool for OpenClaw")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("OpenClaw needs to call APIs — but it should never see your passwords or API keys. ClawAPI is a secure tool that injects your credentials into requests server-side, so OpenClaw only sees the API response.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560)
                }

                Spacer().frame(height: 40)

                // Feature cards
                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(
                        icon: "lock.shield.fill",
                        color: .blue,
                        title: "Zero Credential Exposure",
                        description: "OpenClaw never sees your passwords or API keys. ClawAPI injects them server-side and returns only the API response."
                    )
                    FeatureRow(
                        icon: "key.fill",
                        color: .green,
                        title: "Encrypted in the Keychain",
                        description: "Your credentials are encrypted in the macOS Keychain. No one with just file access can see or misuse them."
                    )
                    FeatureRow(
                        icon: "list.bullet.rectangle.fill",
                        color: .orange,
                        title: "Full Audit Trail",
                        description: "Every proxied request is logged. See what was accessed, when, and why."
                    )
                    FeatureRow(
                        icon: "pause.circle.fill",
                        color: .purple,
                        title: "Pause or Remove Anytime",
                        description: "Change access mode or delete any provider from the Providers tab. OpenClaw instantly loses access."
                    )
                }
                .frame(maxWidth: 560)

                Spacer().frame(height: 44)

                // Next button
                Button {
                    onNext()
                } label: {
                    HStack(spacing: 6) {
                        Text("How It Works")
                            .font(.headline)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Spacer().frame(height: 24)

                // Disclaimer
                Text("ClawAPI is provided as-is, without warranty of any kind. You are solely responsible for the credentials you store and the providers you connect. Use at your own risk.")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)

                Spacer().frame(height: 32)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Page 2: How It Works

private struct WelcomePage2: View {
    var onBack: () -> Void
    var onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 36)

            Label("How It Works", systemImage: "questionmark.circle.fill")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Example: let OpenClaw call the OpenAI API for you")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 24) {
                SimpleStep(
                    number: 1,
                    icon: "plus.circle.fill",
                    color: .blue,
                    title: "Add a Provider",
                    example: "Click + and select OpenAI. Paste your API key. That's it."
                )

                SimpleStep(
                    number: 2,
                    icon: "key.fill",
                    color: .green,
                    title: "Credential Stored Securely",
                    example: "Your API key is encrypted in the macOS Keychain — never stored as plain text."
                )

                SimpleStep(
                    number: 3,
                    icon: "puzzlepiece.extension.fill",
                    color: .orange,
                    title: "OpenClaw Finds It Automatically",
                    example: "ClawAPI registers itself with OpenClaw — no setup needed. When OpenClaw needs to call an API, it discovers ClawAPI and uses it to inject your credentials. OpenClaw never sees the key."
                )

                SimpleStep(
                    number: 4,
                    icon: "eye.fill",
                    color: .purple,
                    title: "You Stay in Control",
                    example: "Every proxied request is logged. Change access mode or delete any provider from the Providers tab."
                )
            }
            .frame(maxWidth: 480)

            Text("Works for any API provider: OpenAI, GitHub, Stripe, and any provider with an API key or token.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 16)

            Spacer()

            // Navigation buttons
            HStack(spacing: 16) {
                Button {
                    onBack()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .frame(maxWidth: 120)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    onGetStarted()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Text("Reopen anytime from the house icon, or check the FAQ from the book icon.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            Spacer().frame(height: 36)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Simple Step

private struct SimpleStep: View {
    let number: Int
    let icon: String
    let color: Color
    let title: String
    let example: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                Text(example)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
