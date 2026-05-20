<div align="center">

# 🔧 Jules Action Ollama

**Local AI coding agent for GitHub Actions — powered by Ollama instead of Gemini**

[![Runs with Ollama](https://img.shields.io/badge/Runs%20with-Ollama-blue?logo=ollama)](https://ollama.ai)
[![No API Key Needed](https://img.shields.io/badge/No%20API%20Key-green)](https://github.com/andrefelippeadfarias/jules-action-ollama)
[![100% Local](https://img.shields.io/badge/100%25-Local-orange)](https://github.com/andrefelippeadfarias/jules-action-ollama)
[![Security Audited](https://img.shields.io/badge/Security-Audited-red)](https://github.com/andrefelippeadfarias/jules-action-ollama)

</div>

## What is this?

A **fork of [google-labs-code/jules-action](https://github.com/google-labs-code/jules-action)** modified to use **[Ollama](https://ollama.ai)** (local AI) instead of the Jules Cloud API (Gemini 3 Pro).

Same concept — invoke an AI coding agent from GitHub Actions — but:
- ✅ **No API key needed** (Ollama runs locally)
- ✅ **No cloud dependency** (your code never leaves your machine)
- ✅ **No usage limits** (unlimited tasks, unlike Jules Free tier)
- ✅ **Any model you want** (GLM-5.1, Llama, Mistral, CodeLlama, etc.)
- ✅ **Self-hosted runner** (runs on YOUR hardware)
- 🔒 **Security audited** — Shell injection, JSON injection, and prompt injection mitigated

## ⚠️ Security

This action has been audited for common vulnerabilities:

| Issue | Mitigation |
|-------|------------|
| Shell injection | Shell variables sanitized; `--body-file` used for PR bodies |
| JSON injection | Proper JSON serialization via `python3` |
| Prompt injection | User inputs should be validated before inclusion |
| Auto-commit | **Default: `false`** — requires explicit opt-in |
| Sensitive files | `.env`, `*.key`, `*.pem`, `*secret*`, `*credential*` excluded |
| Workflow auth | All examples include `github.actor` allowlist checks |
| Artifacts | `prompt.txt`, `payload.json` cleaned up after execution |
| Checkout pinned | `actions/checkout@v4` (stable release) |
| Ollama timeout | `--max-time 600 --connect-timeout 30` |

**Always review AI-generated PRs before merging.**

## Quick Start

### 1. Install Ollama

```bash
# macOS/Linux
curl -fsSL https://ollama.ai/install.sh | sh

# Pull a model
ollama pull glm-5.1:cloud
```

### 2. Set up Self-hosted Runner

Follow [GitHub's guide](https://docs.github.com/en/actions/hosting-your-own-runners) to add a self-hosted runner to your repo. Make sure Ollama is running on the same machine.

### 3. Add the Action

Create `.github/workflows/security-agent.yml`:

```yaml
name: Daily Security Scan

on:
  schedule:
    - cron: '0 6 * * 1'  # Every Monday at 6 AM
  workflow_dispatch:

jobs:
  scan:
    # SECURITY: Restrict who can trigger
    if: ${{ contains(fromJSON('["your-username"]'), github.actor) }}
    runs-on: self-hosted
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - name: Security Scan
        uses: andre-farias/jules-action-ollama@v1
        with:
          prompt: |
            Scan this codebase for security vulnerabilities.
            Fix critical issues and create a PR.
          ollama_model: 'glm-5.1:cloud'
          auto_commit: false  # SECURITY: Review before committing
```

## Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `prompt` | **Required.** The task for the agent to perform. | — |
| `ollama_model` | Ollama model to use | `glm-5.1:cloud` |
| `ollama_url` | Ollama API URL | `http://localhost:11434` |
| `starting_branch` | Branch to start from | `main` |
| `include_last_commit` | Include last commit diff | `false` |
| `include_commit_log` | Include commit history | `false` |
| `auto_commit` | Auto commit and create PR | **`false`** |
| `max_files` | Max source files in context | `50` |
| `temperature` | Ollama temperature (0-1) | `0.3` |
| `max_tokens` | Max tokens in response | `8192` |

## Example Workflows

| Workflow | Trigger | Description |
|----------|---------|-------------|
| [security-agent](examples/security-agent.yml) | Cron (Mon 6h) | 🔒 Security vulnerability scan |
| [bug-fixer](examples/bug-fixer.yml) | Issue labeled `bug` | 🐛 Auto-fix bugs |
| [weekly-cleanup](examples/weekly-cleanup.yml) | Cron (Sat 3h) | 🧹 Code cleanup & refactoring |
| [performance](examples/performance-improver.yml) | Cron (Mon 4h) | ⚡ Performance optimization |
| [deps-updater](examples/deps-updater.yml) | Cron (Fri 6h) | 📦 Dependency updates |
| [ci-failure-fix](examples/ci-failure-fix.yml) | CI failure | 🔧 Fix broken builds |

## GLM Thinking Mode

GLM-5.1 uses a "thinking" mode where the model's reasoning goes to a `thinking` field instead of `response`. This action automatically handles both fields — if `response` is empty, it uses `thinking` content.

## Requirements

- **Self-hosted runner** (to access Ollama on localhost)
- **Ollama** running on the runner machine (default port 11434)
- **Python 3** available (for JSON serialization)
- **gh CLI** authenticated (for creating PRs)
- **Git** configured with push access

## vs Original Jules Action

| Feature | Jules Action (Original) | Jules Action Ollama |
|---------|------------------------|---------------------|
| Backend | Gemini 3 Pro (Cloud) | Any Ollama model (Local) |
| API Key | Required | **Not needed** |
| Cost | Free: 15/day, Pro: ~$20/mo | **Free** (local) |
| Limits | 15-300 tasks/day | **Unlimited** |
| Privacy | Code sent to Google | **100% local** |
| Models | Gemini only | **Any Ollama model** |
| Auto-commit default | `true` | **`false`** (safer) |
| JSON serialization | String interpolation | **python3 (safe)** |
| Shell injection | Not mitigated | **Sanitized** |
| Sensitive files | Not excluded | **Excluded** |
| Checkout | `@v5` (doesn't exist) | **`@v4`** (stable) |

## License

MIT (same as original jules-action)

## Credits

Forked from [google-labs-code/jules-action](https://github.com/google-labs-code/jules-action) by Google Labs.
Modified to use Ollama instead of Jules Cloud API.