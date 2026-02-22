# ClawAPI User Guide

A complete walkthrough of every feature in ClawAPI — the Model Switcher & Key Vault for OpenClaw.

---

## Table of Contents

- [Getting Started](#getting-started)
  - [Installation](#installation)
  - [First Launch](#first-launch)
  - [Adding Your First Provider](#adding-your-first-provider)
- [Providers Tab](#providers-tab)
  - [Adding a Provider](#adding-a-provider)
  - [Switching Models](#switching-models)
  - [Provider Priority](#provider-priority)
  - [Enabling and Disabling](#enabling-and-disabling)
  - [Approval Modes](#approval-modes)
  - [Deleting a Provider](#deleting-a-provider)
- [Sync Tab](#sync-tab)
  - [Active Model](#active-model)
  - [Fallback Chain](#fallback-chain)
  - [Connection Status](#connection-status)
- [Activity Tab](#activity-tab)
- [Logs Tab](#logs-tab)
- [Usage Tab](#usage-tab)
  - [Checking Balances](#checking-balances)
  - [Admin Keys](#admin-keys)
- [Settings](#settings)
  - [Local Mode](#local-mode)
  - [Remote / SSH Mode](#remote--ssh-mode)
- [Model Switching Tips](#model-switching-tips)
- [Keychain & Security](#keychain--security)
- [Ollama (Local Models)](#ollama-local-models)
- [Updating ClawAPI](#updating-clawapi)
- [Data Storage](#data-storage)
- [Troubleshooting](#troubleshooting)

---

## Getting Started

### Installation

Run the installer in Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/Gogo6969/clawapi/main/install.sh | bash
```

This downloads the latest release from GitHub and installs `ClawAPI.app` to `/Applications`. The app is signed with Apple Developer ID and notarized — macOS will not block it.

You can also download the ZIP manually from the [Releases page](https://github.com/Gogo6969/clawapi/releases).

### First Launch

When you first open ClawAPI, you will see:

1. **Connection Mode** — Choose between **Local** (OpenClaw on this Mac) or **Remote (SSH)** (OpenClaw on a VPS). Most users should pick Local. You can change this later in Settings.

2. **Welcome Screen** — A quick tour of what ClawAPI does:
   - Switch AI models with one click
   - Store keys securely in the macOS Keychain
   - Save money by picking the right model for each task
   - Everything syncs to OpenClaw automatically

3. **Get Started** — A grid of all supported providers. Tap one to add it.

### Adding Your First Provider

1. Pick a provider from the Get Started grid (or click `+` in the toolbar anytime)
2. Paste your API key in the text field
3. Click **Save to Keychain**
4. macOS will ask for your login password — click **Always Allow** so ClawAPI can access your key without asking again

That's it. Your provider is now connected, enabled, and synced to OpenClaw.

---

## Providers Tab

The Providers tab is the main screen. It shows all your connected providers as a list.

### Adding a Provider

Click the `+` button in the toolbar to open the Add Provider wizard:

1. **Pick a Service** — Search or scroll through 15+ providers. Select one, or choose "Custom" for unlisted providers.
2. **Enter Your Key** — Paste your API key. The placeholder text shows the expected format (e.g., `sk-...` for OpenAI). You can toggle visibility with the eye icon.
3. **Advanced Settings** (optional):
   - **Connection ID** — Custom scope name (usually auto-filled)
   - **Allowed Domains** — Restrict which domains can use this key
   - **Credential Type** — Bearer Token, Custom Header, Cookie, or Basic Auth
   - **Approval Mode** — Auto, Manual, or Pending
   - **Task Tags** — Tag this provider for specific tasks (research, coding, chat, etc.)
4. **Done** — A success screen confirms your key is stored. The provider is automatically enabled and synced.

### Switching Models

Each provider row has a **model dropdown** (CPU icon). Click it to see all available models for that provider, fetched from OpenClaw's model catalog.

For example, under OpenAI you might see:
- gpt-5.2
- gpt-5.1
- gpt-4.1
- gpt-4.1-mini
- o3
- o4-mini

Select a model and it becomes the active model for that provider. If this is your #1 priority provider, it becomes OpenClaw's primary model.

**Important:** After switching models, you need to start a **new session** in OpenClaw. Existing chat sessions continue using their original model. Type `/new` in the OpenClaw chat to start a fresh session with the new model.

A popup will remind you of this each time you switch. You can check "Don't show this again" if you prefer.

### Provider Priority & Fallback Chain

The order of providers in the list determines the **fallback chain**:

- **#1** is the **primary** provider — its model becomes OpenClaw's default
- **#2, #3, etc.** become **fallbacks** — used when the primary can't handle a request (quota exceeded, feature not supported, etc.)

To reorder, **drag and drop** a provider row to a new position.

**Why this matters:** Some features like **vision/image analysis** and **embeddings** aren't supported by every provider. For example, OpenAI Codex (OAuth) covers chat/coding but not vision. If Codex is #1, put a vision-capable provider with API credits (like Anthropic) at #2 so OpenClaw can fall back to it for image analysis.

### OpenAI Codex (OAuth)

The cheapest way to use AI for coding. Instead of per-token API billing, Codex uses your **ChatGPT Plus subscription** ($20/mo).

1. Click `+` in the toolbar and select **OpenAI Codex (OAuth)**
2. A Terminal window opens to complete the OAuth sign-in with your OpenAI account
3. Once connected, ClawAPI detects it automatically

**Limitations:** OAuth covers chat and coding completions only. For vision, image analysis, and embeddings, OpenClaw falls back to the next provider in your priority list. Make sure you have a funded API key provider as a fallback.

### Enabling and Disabling

Each provider has an **ENABLED / DISABLED** button on the right:

- **Enabled** (green) — The provider is active, its key is synced to OpenClaw
- **Disabled** (red) — The provider is inactive, its key is removed from OpenClaw's config

Disabling a provider does not delete your API key from the Keychain — it just stops OpenClaw from using it.

### Approval Modes

Right-click a provider (or click the `...` menu) to set its approval mode:

- **Auto-Approve** (bolt icon) — Requests are forwarded immediately. Best for normal use.
- **Require Approval** (hand icon) — Every request needs your explicit OK.
- **Queue / Pending** (clock icon) — Requests are queued for batch review.

### Deleting a Provider

Right-click and select **Delete Provider**, or use the `...` menu. This removes:
- The provider from your list
- The API key from the Keychain
- The synced key from OpenClaw's auth-profiles

---

## Sync Tab

The Sync tab shows exactly what is synced to OpenClaw right now.

### Active Model

The top section shows the **currently active model** in OpenClaw (read directly from `openclaw.json`). For example:

```
openai/gpt-4.1-mini
Primary model in OpenClaw
```

### Fallback Chain

Below the active model, you see the **fallback chain** — the ordered list of models OpenClaw will try if the primary is unavailable:

```
1. openai/gpt-4.1
2. anthropic/claude-sonnet-4-5
3. xai/grok-4-fast
```

### Connection Status

The top-right corner shows whether OpenClaw is detected:
- **Connected** (green checkmark) — `~/.openclaw/openclaw.json` exists
- **Not Installed** (orange warning) — OpenClaw config not found

---

## Activity Tab

The Activity tab gives you a real-time overview:

- **Status Cards** — Provider count, pending requests, approved count, denied count
- **Recent Activity** — The last 5 audit log entries
- **Pending Requests** — If any requests are waiting for approval, they appear here with Approve/Deny buttons

Click any status card to jump to the relevant tab or filter.

---

## Logs Tab

The Logs tab shows the full audit history of every API request ClawAPI has processed.

**Features:**
- **Search** — Filter by provider name, domain, or reason
- **Result Filter** — Show All, Approved only, Denied only, or Errors only
- **Details** — Each entry shows the scope, requesting host, reason, timestamp, and result
- **Clickable Cards** — The status cards at the top act as quick filters

---

## Usage Tab

The Usage tab lets you check credit balances and spending for providers that support billing APIs.

### Checking Balances

For supported providers (OpenAI, Anthropic, xAI, OpenRouter), you can see:
- Current credit balance
- Usage this billing period
- A link to the provider's billing dashboard

Click **Refresh** to fetch the latest balance.

### Admin Keys

Some providers require a separate **admin API key** to access billing information (different from the key used for model access). To set one up:

1. Go to the Usage tab
2. Click the key icon next to the provider
3. Enter your admin/billing API key
4. The balance will now show

Not all providers require a separate admin key — some use the same key for both model access and billing.

---

## Settings

Open Settings via the gear icon in the toolbar.

### Local Mode

**Default.** ClawAPI reads and writes OpenClaw's config files directly on your Mac:
- `~/.openclaw/openclaw.json` — Model configuration
- `~/.openclaw/agents/main/agent/auth-profiles.json` — API keys

### Remote / SSH Mode

If OpenClaw runs on a remote server (VPS), ClawAPI can manage it over SSH:

1. Switch to **Remote (SSH)** in Settings
2. Fill in:
   - **Host** — Your server's IP or hostname
   - **Port** — SSH port (default: 22)
   - **User** — SSH username
   - **Key Path** — Path to your SSH private key (e.g., `~/.ssh/id_ed25519`)
   - **Remote OpenClaw Path** — Where OpenClaw lives on the server (default: `~/.openclaw`)
3. Click **Test Connection** to verify

Your API keys remain in the local Keychain. They are synced to the remote server's `auth-profiles.json` via SSH on every change.

---

## Model Switching Tips

1. **Switch models** using the dropdown in the Providers tab
2. **Reorder providers** by dragging rows — the #1 provider becomes primary
3. **Start a new session** after switching: type `/new` in the OpenClaw chat
4. **Verify the active model** in the Sync tab — it reads directly from OpenClaw's config
5. **Existing sessions keep their model** — switching only affects new sessions
6. AI models sometimes claim to be a different model than they are — the Sync tab is the authoritative source

---

## Keychain & Security

ClawAPI uses the macOS Keychain to store all API keys:

- Keys are encrypted at rest by macOS using hardware-backed encryption
- No API key is ever written to disk in plain text
- Keys are only synced to OpenClaw's `auth-profiles.json` when a provider is enabled
- Disabling or deleting a provider removes the key from OpenClaw's config
- On first access, macOS asks for your login password — click **Always Allow** to avoid being asked every time

The Keychain service identifier is `com.worldapi.shared`.

---

## Ollama (Local Models)

Ollama runs AI models locally on your Mac — no API key needed.

1. [Install Ollama](https://ollama.com) and pull a model (e.g., `ollama pull llama3.2:3b`)
2. In ClawAPI, click `+` and select **Ollama**
3. No key is needed — just click Save
4. The model dropdown shows all models available in your local Ollama installation

Ollama providers are marked as **Local** instead of showing "Secret stored."

---

## Updating ClawAPI

ClawAPI checks for updates automatically when you open it. You can also check manually:

1. Click the **download arrow** icon in the toolbar
2. If an update is available, you'll see the new version, release notes, and a download button
3. Click **Download** to get the latest version

Or re-run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/Gogo6969/clawapi/main/install.sh | bash
```

---

## Data Storage

| What | Where |
|------|-------|
| Provider configurations | `~/Library/Application Support/ClawAPI/policies.json` |
| Audit log | `~/Library/Application Support/ClawAPI/audit.json` |
| Pending requests | `~/Library/Application Support/ClawAPI/pending.json` |
| API keys | macOS Keychain (service: `com.worldapi.shared`) |
| OpenClaw model config | `~/.openclaw/openclaw.json` |
| OpenClaw auth profiles | `~/.openclaw/agents/main/agent/auth-profiles.json` |
| App preferences | macOS UserDefaults |

---

## Troubleshooting

### "ClawAPI can't be opened" after install

This shouldn't happen with v1.5.0+ (signed and notarized). If it does:

```bash
xattr -cr /Applications/ClawAPI.app
```

### Model didn't change in OpenClaw

- Make sure you started a **new session** — type `/new` in the chat
- Check the **Sync tab** to verify the correct model is active
- Existing sessions always keep their original model

### Keychain keeps asking for password

When macOS asks for your login password, click **Always Allow** (not just "Allow"). This grants ClawAPI permanent access to the key.

### OpenClaw shows "Not Installed"

ClawAPI looks for `~/.openclaw/openclaw.json`. Make sure OpenClaw is installed and has been run at least once to create its config.

### SSH connection fails

- Verify your SSH key path is correct
- Make sure the SSH key has no passphrase (or use `ssh-add` first)
- Check that the remote user has read/write access to the OpenClaw directory
- Use the **Test Connection** button in Settings to diagnose

### Provider shows "No secret"

The API key wasn't saved to the Keychain. Edit the provider and re-enter your key. Make sure you click **Save to Keychain** and approve the Keychain prompt.

---

## Links

- **Website:** [clawapi.app](https://clawapi.app)
- **GitHub:** [github.com/Gogo6969/clawapi](https://github.com/Gogo6969/clawapi)
- **Contact:** [clawapi.app/contact](https://clawapi.app/contact)
- **OpenClaw:** [openclaw.app](https://openclaw.app)

## Support Development

ClawAPI is free and open source. If you find it useful:

**Bitcoin:** `bc1qzu287ld4rskeqwcng7t3ql8mw0z73kw7trcmes`
