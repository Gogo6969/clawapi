<p align="center">
  <img src="screenshots/03-providers.png" width="600" alt="ClawAPI — Model Switcher & Key Vault for OpenClaw">
</p>

<h1 align="center">ClawAPI</h1>
<p align="center"><strong>Model Switcher & Key Vault for OpenClaw</strong></p>
<p align="center">
A native macOS app that lets you switch AI models and securely manage API keys for <a href="https://openclaw.app">OpenClaw</a>.<br>
Supports OpenAI, Anthropic, Google, xAI, Groq, Mistral, Ollama, and 15+ more providers.<br>
All keys stored in the macOS Keychain — never on disk.
</p>

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Gogo6969/clawapi/main/install.sh | bash
```

Installs `ClawAPI.app` to `/Applications`. Requires macOS 14+.

## Features

- **One-click model switching** — Pick any model from any provider and apply it instantly
- **Secure key vault** — API keys stored in the macOS Keychain with hardware encryption
- **Sub-model picker** — Browse the full model catalog for each provider
- **15+ providers** — OpenAI, Anthropic, xAI, Groq, Mistral, Google, Ollama, and more
- **Auto-sync** — Changes are written directly to OpenClaw's config, no restart needed
- **Auto-update** — Built-in update checker fetches new releases from GitHub
- **Usage dashboard** — Check your credit balance and billing across providers
- **No proxy, no middleware** — ClawAPI talks directly to provider APIs using your keys

## Screenshots

<table>
<tr>
<td align="center"><strong>Providers</strong></td>
<td align="center"><strong>Sync</strong></td>
</tr>
<tr>
<td><img src="screenshots/03-providers.png" width="500" alt="Providers tab"></td>
<td><img src="screenshots/04-sync.png" width="500" alt="Sync tab"></td>
</tr>
<tr>
<td align="center"><strong>Get Started</strong></td>
<td align="center"><strong>Activity</strong></td>
</tr>
<tr>
<td><img src="screenshots/10-get-started.png" width="500" alt="Get Started"></td>
<td><img src="screenshots/05-activity.png" width="500" alt="Activity tab"></td>
</tr>
<tr>
<td align="center"><strong>How It Works</strong></td>
<td align="center"><strong>FAQ</strong></td>
</tr>
<tr>
<td><img src="screenshots/02-how-it-works.png" width="500" alt="How It Works"></td>
<td><img src="screenshots/09-faq.png" width="500" alt="FAQ"></td>
</tr>
</table>

## How It Works

1. **Add a Provider** — Click + in the toolbar, pick a provider, paste your API key
2. **Pick a Model** — Use the dropdown to choose a sub-model (GPT-4.1, Claude Sonnet 4, etc.)
3. **Done** — ClawAPI syncs everything to OpenClaw automatically. No restart needed.

## Requirements

- macOS 14.0 or later (Apple Silicon or Intel)
- [OpenClaw](https://openclaw.app) installed
- API key from at least one supported provider (or Ollama running locally)

## Support Development

ClawAPI is free and open source. If you find it useful, consider supporting development:

**Bitcoin:** `bc1qzu287ld4rskeqwcng7t3ql8mw0z73kw7trcmes`

## License

MIT
