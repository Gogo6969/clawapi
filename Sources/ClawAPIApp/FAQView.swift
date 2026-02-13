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
                    FAQSection(icon: "sparkles", color: .purple, title: "Walkthrough: Connect OpenClaw to OpenAI") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("This example shows how to let OpenClaw call the OpenAI API — without OpenClaw ever seeing your API key.")
                                .font(.callout)
                                .foregroundStyle(.secondary)

                            FAQSubsection(title: "1. Select OpenAI and paste your key") {
                                Text("Click + in the toolbar, select OpenAI from the grid, and paste your API key (sk-...). Domains and settings are filled in automatically. That's the only step.")
                            }

                            FAQSubsection(title: "2. OpenClaw can now use OpenAI") {
                                Text("ClawAPI automatically registers itself with OpenClaw. When OpenClaw needs to call OpenAI, it discovers ClawAPI and uses it to inject your API key. OpenClaw never sees the key — only the API response.")
                            }

                            FAQSubsection(title: "3. Check Activity") {
                                Text("Open the Activity tab to see request counts and recent activity. Click any card to jump to the relevant section.")
                            }
                        }
                    }

                    Divider()

                    // ── Enable / Disable — Save Costs ──

                    FAQSection(icon: "power.circle.fill", color: .green, title: "Enable & Disable Providers — Save Costs") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Every provider row has a prominent ENABLED / DISABLED button. Use it to instantly toggle whether OpenClaw can use that provider.")
                            Text("**Why this matters:** Disabling a provider you're not actively using prevents accidental API calls that rack up costs. Re-enabling takes one click — no need to re-enter credentials or reconfigure anything.")
                            Text("**Tip:** Disable expensive providers (like GPT-4, Claude, etc.) when you're not using them, and only enable the ones you need for your current task. This gives you fine-grained cost control without deleting anything.")
                        }
                    }

                    Divider()

                    // ── Provider Priority ──

                    FAQSection(icon: "list.number", color: .blue, title: "Provider Priority — Set Your MAIN Provider") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Drag provider rows to reorder them. The provider at the top is your #1 MAIN provider — it's the one OpenClaw will prefer to use first.")
                            Text("**How it works:** OpenClaw sees the priority order when it calls clawapi_list_scopes. The #1 MAIN provider is listed first, followed by #2, #3, and so on. This lets OpenClaw know which provider you prefer for each task.")
                            Text("**Tip:** Put your fastest or cheapest provider at #1, and keep premium providers lower in the list as fallbacks.")
                        }
                    }

                    Divider()

                    // ── Best For Tags ──

                    FAQSection(icon: "tag.fill", color: .purple, title: "\"Best For\" Tags — Guide OpenClaw to the Right Provider") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Each provider can be tagged with what it's best at: coding, research, chat, analysis, images, audio, or any custom tag you create.")
                            Text("**How it works:** When OpenClaw calls clawapi_list_scopes, it sees each provider's tags. This lets OpenClaw pick the right provider for the task — e.g., use Anthropic for coding, Perplexity for research, ElevenLabs for audio.")
                            Text("**Setting tags:** Click + to add a provider — suggested tags are pre-filled based on the service. Open Advanced Settings to customize them. You can also add custom tags for your own workflows.")
                            Text("**Tip:** Combined with priority ordering, tags give you powerful routing control. Set your #1 MAIN provider for general use, and tag specialized providers for specific tasks.")
                        }
                    }

                    Divider()

                    // ── General FAQs ──

                    FAQSection(icon: "lock.shield", color: .blue, title: "Does OpenClaw ever see my credentials?") {
                        Text("No. ClawAPI is a secure tool that injects your credentials into requests server-side and returns only the API response. OpenClaw sends unauthenticated requests to ClawAPI locally. Your passwords and API keys never leave ClawAPI.")
                    }

                    FAQSection(icon: "key.fill", color: .green, title: "Where are my credentials stored?") {
                        Text("In the macOS Keychain, encrypted at rest by macOS and protected by your login. ClawAPI's data files only store metadata (which providers you've connected) — never your actual passwords or keys. No one with just file access can see or misuse your credentials.")
                    }

                    FAQSection(icon: "arrow.triangle.2.circlepath", color: .orange, title: "How do I change a password or rotate a key?") {
                        Text("In the Providers tab, right-click the provider row and choose \"Delete Provider\". Re-add the provider with the new credentials. The old credentials are removed from Keychain when you delete.")
                    }

                    FAQSection(icon: "globe", color: .teal, title: "Can I restrict which domains are allowed?") {
                        Text("Yes. Each provider has an allowed domains list. If OpenClaw tries to send a request to a domain that isn't listed, the request is denied and logged.")
                    }

                    FAQSection(icon: "puzzlepiece.extension", color: .cyan, title: "How does OpenClaw connect to ClawAPI?") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ClawAPI automatically registers itself with OpenClaw through MCP (Model Context Protocol). No manual setup needed — just open ClawAPI and it handles the rest.")
                            Text("ClawAPI exposes three tools that OpenClaw discovers automatically:")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• **clawapi_proxy** — forward an HTTP request with automatic credential injection")
                                Text("• **clawapi_list_scopes** — list available providers")
                                Text("• **clawapi_health** — check ClawAPI status")
                            }
                            Text("OpenClaw launches ClawAPI on demand whenever it needs to call an API — no need to start anything manually.")
                        }
                    }

                    FAQSection(icon: "person.2", color: .mint, title: "Can other agents besides OpenClaw use ClawAPI?") {
                        Text("Yes. Any MCP-compatible agent can connect via MCPorter, and any agent that can send HTTP requests to localhost can use ClawAPI directly. Each request is logged individually with the scope and target URL.")
                    }

                    FAQSection(icon: "pause.circle", color: .purple, title: "How do I stop OpenClaw from accessing a provider?") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Click the ENABLED button on the provider row to instantly disable it. OpenClaw will no longer be able to use that provider — and you save money on API calls you don't need.")
                            Text("For more granular control, right-click the provider row to change the access mode to \"Require Approval\" (you approve each request manually), or \"Delete Provider\" to remove it entirely.")
                            Text("A disabled provider keeps its credentials and settings. Re-enable it anytime with one click.")
                        }
                    }

                    FAQSection(icon: "terminal", color: .indigo, title: "Do I need to start anything manually?") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No. OpenClaw launches ClawAPI automatically whenever it needs to call an API. Just keep the ClawAPI app installed — everything else is handled for you.")
                            Text("Advanced users can also run a standalone HTTP server:")
                            CodeBlock("clawapi-daemon proxy")
                            Text("This listens on port 9090 with /proxy and /mcp endpoints.")
                        }
                    }

                    FAQSection(icon: "doc.text", color: .brown, title: "Where are log files stored?") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("All data is in ~/Library/Application Support/ClawAPI/:")
                            CodeBlock("policies.json  — your providers\naudit.json     — access log (shown in app)\npending.json   — pending requests\naudit.log      — full log (JSONL format)")
                        }
                    }

                    Divider()

                    // ── Support Development ──
                    FAQSection(icon: "heart.fill", color: .red, title: "Support Development") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ClawAPI is free and open. If you'd like to support its development, contributions of any amount are welcome:")
                            CodeBlock("bc1qzu287ld4rskeqwcng7t3ql8mw0z73kw7trcmes")
                            Text("Thank you for helping keep ClawAPI alive!")
                        }
                    }

                    Divider()

                    // ── Disclaimer ──
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Disclaimer", systemImage: "exclamationmark.triangle")
                            .font(.headline)
                            .foregroundStyle(.gray)
                        Text("ClawAPI is provided as-is, without warranty of any kind, express or implied. The authors assume no liability for damages arising from its use. You are solely responsible for the credentials you store, the providers you connect, and any actions taken through ClawAPI. By using ClawAPI, you acknowledge that you do so entirely at your own risk.")
                            .font(.callout)
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
        .frame(width: 600, height: 660)
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
                .font(.callout)
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
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            content
                .font(.caption)
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
            .font(.system(.caption, design: .monospaced))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }
}
