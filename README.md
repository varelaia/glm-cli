# glm-cli

> Run **Claude Code** on **Z.ai GLM-5.2** — a 1M-context coding model — without touching your default `claude` setup.

`glm` and `glmf` are two thin wrappers that launch the real Claude Code binary with environment variables scoped to that single invocation, pointing it at the Z.ai Anthropic-compatible endpoint. Your default `claude` command (Anthropic API / Max plan) is **never modified** — no global `settings.json` is touched, so the two worlds coexist cleanly in the same shell.

| Command | Model | When |
|---------|-------|------|
| `glm`   | `glm-5.2[1m]` (1M ctx, thinking ON) | Heavy work — debugging, multi-step tasks, long context |
| `glmf`  | `glm-5-turbo` (thinking OFF) | Quick tasks — edits, lookups, one-shot prompts |
| `claude`| *(unchanged)* | Still your default — Anthropic / Max |

## Requirements

- macOS or Linux (the Claude Code native installer covers both)
- `curl`
- A Z.ai API key (see below)

## Quick start

```bash
git clone https://github.com/varelaia/glm-cli
cd glm-cli
bash install.sh
```

The installer is **idempotent** and does five things:

1. Installs Claude Code via the official native installer (skipped if already present).
2. Ensures `~/.local/bin` is on your `PATH`.
3. Copies `glm` and `glmf` into `~/.local/bin` (executable).
4. Asks for your Z.ai API key and stores it at `~/.zai_api_key` (`chmod 600`). It accepts the key from an interactive prompt, or non-interactively from the `ZAI_API_KEY` environment variable.
5. Verifies end-to-end against `https://api.z.ai/api/anthropic` (a real `glm-5.2` call expecting HTTP 200).

Then start a fresh shell and run `glm`. On first launch Claude Code asks *"Use this API key?"* → **Yes** (once). Confirm the model with `/model`.

### Get a Z.ai API key

1. Create an account at **https://z.ai**.
2. Go to **https://z.ai/manage-apikey** → *API Keys* → *Create*.
3. Subscribe to a coding plan (e.g. **GLM Coding Pro**, monthly) at **https://z.ai/payment**.
4. Copy the full key. It has the shape `<32 hex chars>.<suffix>` — if it doesn't, it got truncated and auth will fail.

## How your default `claude` stays safe

Each wrapper is a plain script:

```bash
ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic" \
ANTHROPIC_AUTH_TOKEN="$ZAI_KEY" \
ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.2[1m]" \
...
exec claude "$@"
```

The `ANTHROPIC_*` variables are set **inline before `claude`**, so they apply only to that process — they never leak into your shell or your config. Nothing writes to `~/.claude/settings.json`. Contrast with `npx @z_ai/coding-helper`, which edits global settings and would make Z.ai your default; this project deliberately avoids that.

## Models

Verified available on the Z.ai Anthropic-compatible endpoint:

| Model id | Notes |
|----------|-------|
| `glm-5.2[1m]` | 1M-token context; reasoning by default (`glm` uses this) |
| `glm-5-turbo` | Fast GLM-5 variant (~1.3s/turn); `glmf` uses this |
| `glm-4.7` | Mid-tier |
| `glm-4.6` | Mid-tier |
| `glm-4.5-air` | Light; used as the haiku tier by `glm` |

## Troubleshooting

- **`Authentication Failed` (type 1000)** — Z.ai requires `Authorization: Bearer <key>` (the `ANTHROPIC_AUTH_TOKEN` var), **not** an `x-api-key`. The wrappers already do this; if you see it, the key is missing or truncated. Re-check at https://z.ai/manage-apikey.
- **`API error · Retrying in Ns`** mid-session — this is the plan's **per-minute rate limit** (HTTP 429), not a config bug. Claude Code backs off and retries automatically. Pace rapid turns, switch to `glmf` for light work, or upgrade the plan.
- **`glm: command not found` after install** — `~/.local/bin` isn't on `PATH` in the current shell. Run `source ~/.bashrc` (or start a new terminal).
- **Key format warning** — Z.ai keys are `32 hex chars` + `.` + `suffix`. If the installer warns the key looks wrong, you likely copied only part of it.

## Rollback

```bash
rm -f ~/.zai_api_key ~/.local/bin/glm ~/.local/bin/glmf
```

That's it — there is no global state to undo.

## Why

Two reasons people reach for this:

1. **Model diversity / cost.** GLM-5.2 is a strong coding model with a 1M context window at a flat monthly rate, complementing a Claude Max subscription.
2. **Sovereignty over routing.** You decide per-invocation which backend runs, from the same familiar Claude Code UX (skills, slash commands, agents, MCP all carry over unchanged — they are harness plumbing, model-agnostic).

## License

MIT — see [LICENSE](LICENSE).
