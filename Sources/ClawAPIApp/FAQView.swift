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
                            FAQSubsection(title: "Agents") {
                                Text("Manage your OpenClaw agents. Assign models, bind channels, and configure per-agent settings like workspace and sandbox.")
                            }
                            FAQSubsection(title: "Activity") {
                                Text("Provider changes, health checks, and proxy requests. Search and filter the full history. Appears once there is activity to show.")
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
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Drag rows to reorder. The #1 provider is what OpenClaw prefers. Put your cheapest or fastest provider at the top, keep premium ones as fallbacks.")
                            Text("The order is also the **fallback chain** — when the primary can't handle something (vision, image analysis, embeddings), OpenClaw tries the next provider. Make sure a vision-capable provider with API credits is high in the list.")
                        }
                    }

                    // ── OAuth ──
                    FAQSection(icon: "person.badge.key", color: .green, title: "What is OpenAI Codex (OAuth)?") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("The cheapest way to code with AI. Uses your ChatGPT Plus subscription ($20/mo) instead of per-token API billing.")
                            Text("OAuth covers chat and coding, but **not** vision, image analysis, or embeddings. Put a funded API key provider (like Anthropic) at #2 so OpenClaw can fall back to it for those features.")
                        }
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

                    // ── VPS / Remote ──
                    FAQSection(icon: "server.rack", color: .blue, title: "Can I manage OpenClaw on a remote VPS?") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Yes. Click the gear icon in the toolbar to open Settings. Switch to Remote (SSH), enter your VPS host, user, and SSH key path, then click Test Connection.")
                            Text("ClawAPI connects via SSH to read and write OpenClaw's config on your server. Your API keys are still stored safely in the macOS Keychain on your Mac — they're pushed to the VPS config during sync.")
                            Text("Switch back to Local anytime with one click.")
                        }
                    }

                    // ── How Sync Works ──
                    FAQSection(icon: "puzzlepiece.extension", color: .cyan, title: "How does ClawAPI talk to OpenClaw?") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ClawAPI writes your API keys into OpenClaw's auth-profiles.json and sets the active model in openclaw.json. In local mode, this is direct file I/O. In remote mode, it happens over SSH.")
                            Text("ClawAPI also registers itself via MCP so OpenClaw can launch it on demand.")
                        }
                    }

                    FAQSection(icon: "magnifyingglass", color: .mint, title: "How do I verify which model OpenClaw is using?") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Open Terminal and run:")
                            CodeBlock("openclaw status")
                            Text("Look at the Sessions line — it shows the default model and each session's active model. This is the authoritative source. Don't rely on the AI's self-report — models can't reliably identify themselves.")
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

                    FAQSection(icon: "heart.text.clipboard", color: .green, title: "What do the colored dots mean?") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The dot next to each provider name shows its key status:")
                            HStack(spacing: 6) {
                                Circle().fill(.green).frame(width: 8, height: 8)
                                Text("**Green** — API key is valid.")
                            }
                            HStack(spacing: 6) {
                                Circle().fill(.yellow).frame(width: 8, height: 8)
                                Text("**Yellow** — Unreachable. Network error or timeout.")
                            }
                            HStack(spacing: 6) {
                                Circle().fill(.red).frame(width: 8, height: 8)
                                Text("**Red** — Dead. Invalid key, expired, or quota exhausted.")
                            }
                            HStack(spacing: 6) {
                                Circle().fill(.blue).frame(width: 8, height: 8)
                                Text("**Blue** — OAuth token present (managed by OpenClaw).")
                            }
                            Text("Keys are checked automatically on launch using free endpoints (no tokens consumed). Click **Check All** to re-check anytime.")
                        }
                    }

                    Divider()

                    FAQSection(icon: "folder.badge.questionmark", color: .yellow, title: "Why does macOS ask for folder access?") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("macOS may prompt for folder access (e.g. Documents) when ClawAPI reads OpenClaw's config files. ClawAPI does **not** read, write, or modify anything outside of ~/.openclaw/ and ~/Library/Application Support/ClawAPI/.")
                            Text("You can safely allow or deny — ClawAPI works either way. The prompt only appears once per location.")
                        }
                    }

                    Divider()

                    // ── Agents ──
                    FAQSection(icon: "person.crop.rectangle.stack", color: .purple, title: "Agents \u{2014} How They Work") {
                        VStack(alignment: .leading, spacing: 12) {
                            FAQSubsection(title: "What is an agent?") {
                                Text("An agent is an independent AI worker in OpenClaw with its own model, workspace, and channel bindings. The \u{201C}main\u{201D} agent is created automatically when you first set up OpenClaw. You can create additional agents for different tasks or channels.")
                            }
                            FAQSubsection(title: "How do I create an agent?") {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Click the **+** button in the Agents tab toolbar. A two-step wizard guides you:")
                                    Text("**Step 1 \u{2014} Configure:** Enter a name, pick an emoji, and optionally set a workspace path. The Agent ID is auto-generated from the name (kebab-case) but you can edit it. The ID becomes the directory name under ~/.openclaw/agents/ and cannot be changed later.")
                                    Text("**Step 2 \u{2014} Choose Model:** Toggle \u{201C}Use default model\u{201D} to inherit Provider #1\u{2019}s model, or turn it off to pick a specific model. You can type any model ID or pick from the popular models list.")
                                    Text("The agent\u{2019}s identity name is automatically synced to OpenClaw so it appears correctly in the dashboard and logs.")
                                }
                            }
                            FAQSubsection(title: "Custom model \u{2014} agent vs global default") {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Each agent can use its own model \u{2014} that\u{2019}s intentional. A research agent might use a reasoning model while a chat agent uses a fast one. When an agent has a custom model, a blue \u{24D8} info icon appears on its row.")
                                    Text("If \u{201C}Use default model\u{201D} is ON, the agent inherits Provider #1\u{2019}s model from the Providers tab. If OFF, the model you pick for that agent takes priority.")
                                }
                            }
                            FAQSubsection(title: "Agents vs Providers") {
                                Text("Providers are your API credentials (keys, OAuth tokens). Agents are the AI workers that use those credentials. Multiple agents can share the same provider \u{2014} for example, three agents can all use your OpenAI key but with different models.")
                            }
                            FAQSubsection(title: "How do agents receive messages?") {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("There are two paths:")
                                    Text("**1. Channel bindings** \u{2014} rules that route messages from a specific channel (Telegram, Slack, Discord, etc.) to a specific agent. The **default agent** catches everything that doesn\u{2019}t match a binding.")
                                    Text("**2. Sub-agent spawning** \u{2014} the main agent (or any agent) can spawn another agent as a background worker using /subagents spawn or the sessions_spawn tool. The sub-agent works independently and announces its result back when done.")
                                    Text("An agent without channel bindings and not set as default can still be used as a sub-agent \u{2014} it just won\u{2019}t receive direct messages from any chat channel.")
                                }
                            }
                            FAQSubsection(title: "Can I address a specific agent from chat?") {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Not by @mentioning its name. OpenClaw routes incoming messages by **channel and account**, not by agent name.")
                                    Text("But you can tell your main agent to **delegate work** to another agent. Either use the slash command:")
                                    Text("/subagents spawn research-bot \u{201C}Summarize competitor pricing\u{201D}")
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 4))
                                    Text("Or just ask in natural language: \u{201C}Use the research bot to look up pricing.\u{201D} If tools.agentToAgent is enabled, your main agent can spawn it automatically.")
                                }
                            }
                            FAQSubsection(title: "Sub-agents and agent teams") {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Sub-agents are background workers spawned from a running agent. They get their own session, model, and workspace. When finished, they **announce** their result back to the agent that spawned them.")
                                    Text("With maxSpawnDepth: 2, you can build a **team pattern**: main agent \u{2192} orchestrator sub-agent \u{2192} multiple worker sub-sub-agents running in parallel. Results flow back up the chain.")
                                    Text("To enable, set **tools.agentToAgent.enabled: true** and list allowed agent IDs in **tools.agentToAgent.allow** in your openclaw.json. Configure concurrency via **agents.defaults.subagents**.")
                                }
                            }
                            FAQSubsection(title: "What are channel bindings?") {
                                Text("Channel bindings route messages from specific platforms (Telegram, Slack, Discord, etc.) to a specific agent. Without bindings, all messages go to the default agent. Use Account ID when you have multiple bot accounts on one platform.")
                            }
                            FAQSubsection(title: "What happens when I delete an agent?") {
                                Text("The agent is removed from the config and won\u{2019}t receive messages. Its session history and files on disk are preserved under ~/.openclaw/agents/<id>/.")
                            }
                        }
                    }

                    Divider()

                    // ── Agent Settings Reference ──
                    FAQSection(icon: "gearshape.2", color: .indigo, title: "Agent Settings Reference") {
                        VStack(alignment: .leading, spacing: 12) {
                            FAQSubsection(title: "Name") {
                                Text("The display name for this agent. Shown in the agent list and logs. Does not affect how OpenClaw routes messages.")
                            }
                            FAQSubsection(title: "Emoji") {
                                Text("The avatar icon shown next to the agent name in ClawAPI.")
                            }
                            FAQSubsection(title: "Agent ID") {
                                Text("The internal identifier and directory name under ~/.openclaw/agents/. Cannot be changed after creation. Used by OpenClaw for routing and session storage.")
                            }
                            FAQSubsection(title: "Default Agent") {
                                Text("The default agent receives all messages that don't match a specific channel binding. Only one agent can be the default at a time.")
                            }
                            FAQSubsection(title: "Model Configuration") {
                                Text("Pick which AI model this agent uses. If \"Use default model\" is ON, the agent inherits Provider #1's model from the Providers tab. If OFF, the model you pick here takes priority over Provider #1.")
                            }
                            FAQSubsection(title: "Custom Model") {
                                Text("Type any model ID manually (e.g. provider/model-name) for models not in the catalog. Useful for newly released or custom-deployed models.")
                            }
                            FAQSubsection(title: "Channel Bindings") {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Route direct messages from specific channels (Telegram, Slack, Discord, etc.) to this agent. Each binding needs its own channel account (e.g. a separate Telegram bot token).")
                                    Text("An agent without bindings and not set as default won\u{2019}t receive direct channel messages, but can still be spawned as a **sub-agent** by other agents.")
                                    Text("Account ID is optional \u{2014} use it when you have multiple bot accounts on one channel.")
                                }
                            }
                            FAQSubsection(title: "Workspace Path") {
                                Text("The working directory where this agent runs commands and edits files. Each agent can have its own project folder. Defaults to ~/.openclaw/workspace.")
                            }
                            FAQSubsection(title: "Max Concurrent Sessions") {
                                Text("How many conversations this agent handles simultaneously. Extra messages queue up. Default is 4. Increase for high-traffic channels, decrease to limit resource usage.")
                            }
                            FAQSubsection(title: "Sandbox Mode") {
                                Text("Isolates the agent's file system access in a Docker container. Off = full access. Non-Main = sandbox only on non-main git branches. All = always sandboxed. Requires Docker to be installed and running.")
                            }
                            FAQSubsection(title: "Tools Allow / Deny") {
                                Text("Allow is a whitelist — if set, the agent can ONLY use these tools. Deny is a blacklist that overrides Allow. Use Deny to block specific dangerous capabilities (e.g. browser, admin). Leave both empty to allow all tools.")
                            }
                            FAQSubsection(title: "Require @mention / Mention Patterns") {
                                Text("When Require @mention is ON, the agent only responds in group chats when someone uses one of the mention patterns (e.g. @bot, hey bot). When OFF, the agent responds to every message in the group.")
                            }
                        }
                    }

                    Divider()

                    // ── Website & Contact ──
                    FAQSection(icon: "globe", color: .blue, title: "Website & Contact") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text("Website:")
                                Link("clawapi.app", destination: URL(string: "https://clawapi.app/")!)
                                    .foregroundStyle(.blue)
                                    .underline()
                            }
                            HStack(spacing: 6) {
                                Text("Need help?")
                                Link("Contact Us", destination: URL(string: "https://clawapi.app/contact")!)
                                    .foregroundStyle(.blue)
                                    .underline()
                            }
                        }
                    }

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
