import SwiftUI
import Shared

struct FAQView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("FAQ", systemImage: "book.fill")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // ── Walkthrough ──
                    FAQSection(icon: "sparkles", color: .purple, title: "Quick Start") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Add a provider, pick a model, and you're done.")
                                .font(.body)
                                .foregroundStyle(.secondary)

                            FAQSubsection(title: "1. Add a provider") {
                                Text("Click + in the toolbar. Pick a provider and paste your API key.")
                            }

                            FAQSubsection(title: "2. Pick a model") {
                                Text("Use the dropdown next to the provider name to choose a sub-model (e.g. GPT-4.1, Claude Sonnet 4.5, Grok 4).")
                            }

                            FAQSubsection(title: "3. That's it") {
                                Text("ClawAPI syncs your choice to OpenClaw automatically. Your key is in the Keychain, your model is set.")
                            }
                        }
                    }

                    Divider()

                    // ── Tabs ──
                    FAQSection(icon: "rectangle.on.rectangle", color: .blue, title: "What the Tabs Do") {
                        VStack(alignment: .leading, spacing: 12) {
                            FAQSubsection(title: "Providers") {
                                Text("Your API providers. Pick sub-models, enable/disable providers, drag to reorder priority. The #1 provider is what OpenClaw uses first.")
                            }
                            FAQSubsection(title: "Sync") {
                                Text("Shows what's synced to OpenClaw right now — active model, fallbacks, and provider config.")
                            }
                            FAQSubsection(title: "Activity") {
                                Text("Request counts and recent activity. Click any card to jump to details.")
                            }
                            FAQSubsection(title: "Logs") {
                                Text("Full history of every API request. Filter by result or search by provider.")
                            }
                            FAQSubsection(title: "Usage") {
                                Text("Check your credit balance and spending for providers that support it.")
                            }
                        }
                    }

                    Divider()

                    // ── Model Selection ──
                    FAQSection(icon: "cpu.fill", color: .green, title: "How do I switch models?") {
                        Text("Each provider row has a dropdown showing the current model. Click it to pick a different one. Your choice syncs to OpenClaw instantly — no config editing needed.")
                    }

                    // ── Save Money ──
                    FAQSection(icon: "dollarsign.circle.fill", color: .orange, title: "How do I save money?") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Switch to a cheaper model for everyday tasks — you don't always need the most expensive one. Use the model dropdown to pick a smaller, faster model.")
                            Text("Disable providers you're not using — click the ENABLED button to toggle them off. No more surprise charges.")
                        }
                    }

                    // ── Priority ──
                    FAQSection(icon: "list.number", color: .blue, title: "What does provider priority do?") {
                        Text("Drag rows to reorder. The #1 provider is what OpenClaw prefers. Put your cheapest or fastest provider at the top, keep premium ones as fallbacks.")
                    }

                    Divider()

                    // ── Keys ──
                    FAQSection(icon: "key.fill", color: .green, title: "Where are my API keys stored?") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your primary copy is in the macOS Keychain, encrypted by macOS and protected by your login password. You can't lose them — even if you delete ClawAPI's data files, the Keychain keeps your keys safe.")
                            Text("When you enable a provider, ClawAPI also writes the key into OpenClaw's auth-profiles.json so OpenClaw can use it. If you disable or delete a provider, the key is removed from that file.")
                        }
                    }

                    FAQSection(icon: "arrow.triangle.2.circlepath", color: .orange, title: "How do I change or rotate a key?") {
                        Text("Delete the provider (right-click the row) and re-add it with the new key. The old key is removed from both the Keychain and OpenClaw's config.")
                    }

                    // ── Local Providers ──
                    FAQSection(icon: "desktopcomputer", color: .teal, title: "Can I use Ollama or other local models?") {
                        Text("Yes. Add Ollama from the provider list — no API key needed. ClawAPI detects your locally running models automatically.")
                    }

                    // ── How Sync Works ──
                    FAQSection(icon: "puzzlepiece.extension", color: .cyan, title: "How does ClawAPI talk to OpenClaw?") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ClawAPI writes your API keys into OpenClaw's auth-profiles.json and sets the active model in openclaw.json. OpenClaw reads these files directly — it uses your keys natively.")
                            Text("ClawAPI also registers itself via MCP so OpenClaw can launch it on demand.")
                        }
                    }

                    FAQSection(icon: "pause.circle", color: .purple, title: "How do I stop OpenClaw from using a provider?") {
                        Text("Click the ENABLED button on the provider row to disable it. One click. Re-enable anytime — your key and settings are kept.")
                    }

                    FAQSection(icon: "terminal", color: .indigo, title: "Do I need to start anything manually?") {
                        Text("No. OpenClaw launches ClawAPI automatically when needed. Just keep it installed.")
                    }

                    FAQSection(icon: "doc.text", color: .brown, title: "Where is data stored?") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("All config is in ~/Library/Application Support/ClawAPI/:")
                            CodeBlock("policies.json  — your providers\naudit.json     — access log\npending.json   — pending requests")
                            Text("API keys are in the macOS Keychain. Enabled providers also have their key in OpenClaw's auth-profiles.json for direct access.")
                        }
                    }

                    Divider()

                    // ── Support Development ──
                    FAQSection(icon: "heart.fill", color: .red, title: "Support Development") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ClawAPI is free and open. If you'd like to support its development:")
                            HStack(spacing: 12) {
                                BitcoinLogo(size: 32)
                                CodeBlock("bc1qzu287ld4rskeqwcng7t3ql8mw0z73kw7trcmes")
                            }
                        }
                    }

                    Divider()

                    // ── Disclaimer ──
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Disclaimer", systemImage: "exclamationmark.triangle")
                            .font(.headline)
                            .foregroundStyle(.gray)
                        Text("ClawAPI is provided as-is, without warranty of any kind, express or implied. The authors assume no liability for damages arising from its use. You are solely responsible for the credentials you store, the providers you connect, and any actions taken through ClawAPI. By using ClawAPI, you acknowledge that you do so entirely at your own risk.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    // ── Version ──
                    Text("ClawAPI version \(AppVersion.current) (build \(AppVersion.build))")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                        .frame(maxWidth: .infinity, alignment: .center)

                }
                .padding(24)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 600, height: 700)
    }
}

// MARK: - FAQ Section

private struct FAQSection<Content: View>: View {
    let icon: String
    let color: Color
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            content
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - FAQ Subsection

private struct FAQSubsection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            content
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 4)
    }
}

// MARK: - Code Block

private struct CodeBlock: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(.callout, design: .monospaced))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Bitcoin Logo

struct BitcoinLogo: View {
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.96, green: 0.66, blue: 0.10))
            Text("₿")
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
