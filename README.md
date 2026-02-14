# ClawAPI

**Model Switcher & Key Vault for OpenClaw**

A native macOS menu-bar app that lets you switch AI models and securely manage API keys for [OpenClaw](https://openclaw.app). Supports OpenAI, Anthropic, Google Gemini, Groq, Ollama, and more — all stored in the macOS Keychain, never on disk.

![Welcome](screenshots/01-welcome-start.png)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Gogo6969/clawapi/main/install.sh | bash
```

Installs `ClawAPI.app` to `/Applications`. Requires macOS 14+.

## Features

- **One-click model switching** — Pick any model from OpenAI, Anthropic, Google, Groq, or Ollama and apply it instantly to OpenClaw
- **Secure key vault** — API keys are stored in the macOS Keychain with hardware encryption, never written to disk
- **Sub-model picker** — Browse the full model catalog for each provider and select exactly the model you want
- **Ollama support** — Use local models running on Ollama with no API key required
- **Auto-sync** — Changes are written directly to OpenClaw's config, no restart needed
- **Auto-update** — Built-in update checker fetches new releases from GitHub
- **Usage dashboard** — Check your credit balance and billing across providers
- **No proxy, no middleware** — ClawAPI talks directly to provider APIs using your keys

## Screenshots

| Providers | Sync |
|:-:|:-:|
| ![Providers](screenshots/03-providers.png) | ![Sync](screenshots/04-sync.png) |

| How It Works | FAQ |
|:-:|:-:|
| ![How It Works](screenshots/02-how-it-works.png) | ![FAQ](screenshots/09-faq.png) |

## Requirements

- macOS 14.0 or later (Apple Silicon or Intel)
- [OpenClaw](https://openclaw.app) installed
- API key from at least one supported provider (or Ollama running locally)

## How It Works

1. Add your API keys in the **Providers** tab
2. Pick a model from the **Model Switcher**
3. ClawAPI writes the selection to OpenClaw's config
4. OpenClaw picks it up — no restart needed

## Support Development

ClawAPI is free and open source. If you find it useful, consider supporting development:

**Bitcoin:** `bc1qzu287ld4rskeqwcng7t3ql8mw0z73kw7trcmes`

## License

MIT
