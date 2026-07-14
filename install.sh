#!/usr/bin/env bash
# glm-cli installer — Claude Code + Z.ai GLM-5.2 wrappers.
# Idempotent. Does NOT touch Claude's global settings.json, so your default
# `claude` (Anthropic / Max plan) stays untouched. glm/glmf only override env
# vars for the duration of their own invocation.
#
# Two install modes:
#   1. curl|bash (no clone): install.sh fetches the wrappers from this repo.
#   2. clone + bash install.sh: wrappers are read from ./bin locally.
#
# Env knobs:
#   ZAI_API_KEY            non-interactive key (skips the prompt).
#   GLM_CLI_NO_VERIFY=1    skip the final Z.ai endpoint check (for tests/CI).
#
# Sourcing this file does NOT run the installer (guard at the bottom), so the
# tests can exercise ensure_path() in isolation under a fake HOME.
set -euo pipefail

ZAI_BASE_URL="https://api.z.ai/api/anthropic"
KEY_FILE="${HOME}/.zai_api_key"
LOCAL_BIN="${HOME}/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Where to fetch the wrappers from when there is no local clone (curl|bash mode).
WRAPPER_URL="https://raw.githubusercontent.com/varelaia/glm-cli/main/bin"

c_ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
c_info() { printf "  \033[36m→\033[0m %s\n" "$1"; }
c_warn() { printf "  \033[33m!\033[0m %s\n" "$1"; }
c_err()  { printf "  \033[31m✗\033[0m %s\n" "$1"; }

# Idempotently ensure ~/.local/bin is on PATH in the user's shell rc.
# Detects an existing PATH entry by the literal `.local/bin` token — tolerant to
# $HOME-form vs expanded-form, and to an `export ` prefix — so it NEVER duplicates
# a line the native Claude installer (or the user) already wrote. Reads $HOME at
# call time so it is safe to exercise under a fake HOME in tests.
ensure_path() {
  local rc bin="${HOME}/.local/bin"
  case "${SHELL:-}" in
    */zsh)  rc="${ZDOTDIR:-$HOME}/.zshrc" ;;
    */bash) rc="$HOME/.bashrc" ;;
    *)      rc="$HOME/.profile" ;;
  esac
  [ -f "$rc" ] || touch "$rc"
  if grep -qE '(^|[[:space:]])(export[[:space:]]+)?PATH=.*\.local/bin' "$rc"; then
    c_ok "${bin} already on PATH in $(basename "$rc")"
  else
    # Write $HOME-form (portable across users if the rc is copied between machines).
    printf '\n# glm-cli\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
    c_info "added ${bin} to PATH via $(basename "$rc") — run: source $rc"
  fi
}

# Install a wrapper into ~/.local/bin. From the local ./bin if present (clone
# mode), otherwise fetched from the repo (curl|bash mode). curl -f makes a 404
# fail loudly instead of silently writing GitHub's HTML page as the wrapper.
install_script() {
  local name="$1" src dest
  src="${SCRIPT_DIR}/bin/${name}"
  dest="${LOCAL_BIN}/${name}"
  if [ -f "$src" ]; then
    install -m 0755 "$src" "$dest"
  else
    c_info "fetching ${name} from repo (curl|bash mode)…"
    curl -fsSL "${WRAPPER_URL}/${name}" -o "$dest" || { c_err "could not fetch ${name} from ${WRAPPER_URL}"; exit 1; }
    chmod 0755 "$dest"
  fi
  c_ok "installed ${name} → ${dest}"
}

resolve_key() {
  if [ -s "$KEY_FILE" ]; then
    c_ok "Z.ai key present at ${KEY_FILE} (reusing)"
    return 0
  fi
  if [ -n "${ZAI_API_KEY:-}" ]; then
    printf '%s' "$ZAI_API_KEY" > "$KEY_FILE"; chmod 600 "$KEY_FILE"
    c_ok "Z.ai key written from \$ZAI_API_KEY"
    return 0
  fi
  # Read the key from the controlling terminal (/dev/tty), NOT the script's
  # stdin — under `curl|bash` stdin is the pipe that delivered the script, so a
  # plain `read` would hit EOF and silently abort with "no key provided". If
  # there is no controlling tty (CI / non-interactive pipe), read fails and we
  # fall through to ask for ZAI_API_KEY instead.
  c_info "Get a key at https://z.ai/manage-apikey  (API Keys → Create)"
  printf "  Paste your Z.ai API key (input hidden): "
  if ! { read -rs KEY </dev/tty; } 2>/dev/null; then
    KEY=""
  fi
  echo
  [ -n "$KEY" ] || {
    c_err "no key provided (no TTY to prompt). Re-run with:"
    c_err "  curl -fsSL https://raw.githubusercontent.com/varelaia/glm-cli/main/install.sh | ZAI_API_KEY=<key> bash"
    exit 1
  }
  printf '%s' "$KEY" > "$KEY_FILE"; chmod 600 "$KEY_FILE"
  c_ok "Z.ai key saved to ${KEY_FILE} (chmod 600)"
}

main() {
  echo "▸ glm-cli installer — Claude Code + Z.ai GLM-5.2"

  # 1) dependencies
  command -v curl >/dev/null 2>&1 || { c_err "curl is required (install it first)"; exit 1; }

  # 2) Claude Code (official native installer)
  if command -v claude >/dev/null 2>&1; then
    c_ok "Claude Code already installed: $(command -v claude)"
  else
    c_info "Installing Claude Code via official native installer…"
    curl -fsSL https://claude.ai/install.sh | bash
  fi
  command -v claude >/dev/null 2>&1 \
    || c_warn "claude not on PATH in this shell yet — it will be after you restart the shell."

  # 3) ensure ~/.local/bin is on PATH
  mkdir -p "$LOCAL_BIN"
  ensure_path

  # 4) install glm / glmf wrappers
  install_script glm
  install_script glmf

  # 5) Z.ai API key
  resolve_key

  # format sanity check (warn only): Z.ai keys are "<32 hex>.<suffix>"
  local key; key="$(cat "$KEY_FILE")"
  if ! printf '%s' "$key" | grep -qE '^[0-9a-f]{32}\.'; then
    c_warn "key doesn't look like a full Z.ai key (expect 32 hex chars + '.' + suffix) — auth may fail"
  fi

  # 6) Check ~/.claude/settings.json for conflicts that break glm.
  #    Two things there silently break glm:
  #    a) "model": "<something>" — overrides the ANTHROPIC_DEFAULT_*_MODEL vars
  #       that the wrapper sets inline. Z.ai rejects non-GLM model ids with 400.
  #    b) Hooks pointing to nonexistent scripts — UserPromptSubmit hooks run on
  #       every prompt and block it if the script is missing.
  check_claude_settings() {
    local settings="${HOME}/.claude/settings.json"
    [ -f "$settings" ] || return 0  # no settings = no problem

    # Only warn if the user has python3 or jq — we try python3 first (more common
    # alongside Claude Code), then jq, then skip silently if neither is available.
    local has_parser=""
    command -v python3 >/dev/null 2>&1 && has_parser="python3"
    [ -z "$has_parser" ] && command -v jq >/dev/null 2>&1 && has_parser="jq"
    [ -z "$has_parser" ] && return 0

    # a) Model override
    local model=""
    if [ "$has_parser" = "python3" ]; then
      model="$(python3 -c "import json,sys; d=json.load(open('$settings')); print(d.get('model',''))" 2>/dev/null || echo "")"
    else
      model="$(jq -r '.model // ""' "$settings" 2>/dev/null || echo "")"
    fi
    if [ -n "$model" ]; then
      c_warn "\"model\": \"${model}\" in ${settings}"
      c_warn "  This overrides the glm wrapper's ANTHROPIC_DEFAULT_*_MODEL vars."
      c_warn "  glm will fail with 'Unknown Model' (HTTP 400). Fix:"
      c_warn "    Remove the \"model\" line from settings.json (or use /model inside glm)."
    fi

    # b) Hooks referencing missing scripts
    local hook_count broken=0
    if [ "$has_parser" = "python3" ]; then
      hook_count="$(python3 -c "
import json,os,sys
d=json.load(open('$settings'))
hooks=d.get('hooks',{})
broken=0
for event,matchers in hooks.items():
  for m in matchers:
    for h in m.get('hooks',[]):
      cmd=h.get('command','')
      # extract the script path (first arg after python3/bash/etc)
      parts=cmd.split()
      for p in parts:
        if p.startswith('/') and not os.path.exists(p):
          broken+=1
          break
print(broken)
" 2>/dev/null || echo "0")"
    else
      hook_count=0
    fi
    if [ "$hook_count" -gt 0 ] 2>/dev/null; then
      c_warn "${hook_count} hook(s) in settings.json reference scripts that don't exist."
      c_warn "  These hooks run on every prompt and will BLOCK glm (and claude)."
      c_warn "  Fix: remove the broken hooks from ${settings}, or restore the missing files."
    fi
  }
  check_claude_settings

  # 7) end-to-end verify (skippable for tests/CI via GLM_CLI_NO_VERIFY=1)
  if [ "${GLM_CLI_NO_VERIFY:-0}" = "1" ]; then
    c_warn "GLM_CLI_NO_VERIFY=1 — skipping Z.ai endpoint check."
  else
    c_info "Verifying Z.ai endpoint (glm-5.2)…"
    local http
    http=$(curl -s -o /dev/null -w "%{http_code}" "$ZAI_BASE_URL/v1/messages" \
      -H "Authorization: Bearer $key" \
      -H "anthropic-version: 2023-06-01" \
      -d '{"model":"glm-5.2","max_tokens":16,"messages":[{"role":"user","content":"ping"}]}' || true)
    case "$http" in
      200) c_ok "Z.ai GLM-5.2 reachable (HTTP 200) — you're ready." ;;
      401|403) c_err "auth failed (HTTP ${http}). Key may be truncated — check https://z.ai/manage-apikey"; exit 1 ;;
      429) c_warn "rate-limited (HTTP 429) during verify — config is correct; retry in a minute." ;;
      *) c_warn "unexpected HTTP ${http} from Z.ai — config saved; check network/key." ;;
    esac
  fi

  echo
  echo "  ▸ Done. Start a fresh shell (or 'source ~/.bashrc'), then:"
  echo "      glm      # Claude Code on GLM-5.2  (1M ctx, thinking ON) — heavy work"
  echo "      glmf     # Claude Code on GLM-5-turbo (fast, thinking off) — quick tasks"
  echo "      claude   # unchanged — still your default (Anthropic)"
  echo "    On first launch it asks \"Use this API key?\" → Yes (once). Verify with /model."
}

# Run main() when the script is executed (from a file OR piped via curl|bash),
# but NOT when sourced by another script (so the tests can call ensure_path()).
# Under `curl|bash` BASH_SOURCE[0] is empty (no file) — treat empty as "run".
if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
  main "$@"
fi
