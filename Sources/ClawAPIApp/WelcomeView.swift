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

                    Text("Model Switcher & Key Vault for OpenClaw")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Pick your AI models, save money by switching to cheaper ones when you can, and keep your API keys safe in the macOS Keychain.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560)
                }

                Spacer().frame(height: 40)

                // Feature cards
                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(
                        icon: "cpu.fill",
                        color: .blue,
                        title: "Switch Models Instantly",
                        description: "Pick any sub-model from any provider. Your choice syncs to OpenClaw automatically."
                    )
                    FeatureRow(
                        icon: "key.fill",
                        color: .green,
                        title: "API Keys in the Keychain",
                        description: "Your keys are stored in the macOS Keychain, encrypted at rest. You can't lose them."
                    )
                    FeatureRow(
                        icon: "dollarsign.circle.fill",
                        color: .orange,
                        title: "Save Money",
                        description: "Switch to a cheaper model for everyday tasks. Disable providers you're not using. Only pay for what you need."
                    )
                    FeatureRow(
                        icon: "arrow.triangle.2.circlepath",
                        color: .purple,
                        title: "Auto-Sync to OpenClaw",
                        description: "Models, keys, and priorities sync to OpenClaw's config. No manual editing."
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

            Text("Three steps — that's it")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 24) {
                SimpleStep(
                    number: 1,
                    icon: "plus.circle.fill",
                    color: .blue,
                    title: "Add a Provider",
                    example: "Click + and pick a provider (OpenAI, Claude, Groq, etc.). Paste your API key."
                )

                SimpleStep(
                    number: 2,
                    icon: "cpu.fill",
                    color: .green,
                    title: "Pick Your Model",
                    example: "Use the dropdown next to each provider to choose a sub-model. It becomes your active model instantly."
                )

                SimpleStep(
                    number: 3,
                    icon: "checkmark.circle.fill",
                    color: .orange,
                    title: "Done — OpenClaw Uses It",
                    example: "ClawAPI syncs everything to OpenClaw automatically. Your key is safe in the Keychain, your model is set, and you're ready to go."
                )
            }
            .frame(maxWidth: 480)

            Text("Supports 15+ providers including OpenAI, Anthropic, xAI, Groq, Mistral, and local models like Ollama.")
                .font(.callout)
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
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            Spacer().frame(height: 16)

            // Bitcoin donation
            VStack(spacing: 6) {
                BitcoinLogo(size: 44)
                Text("ClawAPI is free — support is much appreciated")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("bc1qzu287ld4rskeqwcng7t3ql8mw0z73kw7trcmes")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 10)

            Spacer().frame(height: 12)

            Button {
                onGetStarted()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash")
                    Text("Never show the Start Screens again")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.fill.tertiary, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer().frame(height: 24)
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
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(color, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                Text(example)
                    .font(.body)
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

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.body)
                    .foregroundStyle(.primary.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
