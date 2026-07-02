#!/usr/bin/env bash
# e2e_one_liner.sh — proves the curl|bash (no-clone) install path actually works
# end-to-end, against the LOCAL install.sh (not the published one), before push.
#
# It simulates "no clone": copies install.sh into a dir with no ./bin beside it,
# so install_script() is forced into its remote-fetch branch (downloads the
# wrappers from raw.githubusercontent.com). Runs fully isolated under a tmp HOME
# with GLM_CLI_NO_VERIFY=1 so it never spends the Z.ai key/quota. Asserts the
# wrappers land in ~/.local/bin, the PATH line is added exactly once, and the
# REAL ~/.bashrc is left untouched.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REAL_HOME="$HOME"
REAL_BASHRC_LINES="$(grep -cE '(^|[[:space:]])(export[[:space:]]+)?PATH=.*\.local/bin' "$REAL_HOME/.bashrc" 2>/dev/null || printf 0)"

tmp="$(mktemp -d)"
# Snapshot of the real .bashrc mtime to detect any accidental write.
real_bashrc="$REAL_HOME/.bashrc"
before="$(stat -c '%Y' "$real_bashrc" 2>/dev/null || stat -f '%m' "$real_bashrc" 2>/dev/null || printf 0)"

echo "e2e_one_liner (local install.sh, no ./bin beside it → remote fetch):"
echo "  tmp HOME: $tmp"

# Simulate curl|bash: install.sh alone, no bin/ next to it.
cp "$SCRIPT_DIR/install.sh" "$tmp/install.sh"

# 32-hex + suffix mock key so the format check passes silently (no real key used).
mock_key="$(printf 'a%.0s' $(seq 1 32)).test"

# Simulate the REAL curl|bash: feed install.sh through a PIPE (so the script's
# stdin is the pipe that delivered it, not a tty/file — the one-liner's actual
# runtime) and run from a dir with no ./bin beside it (forces the remote-fetch
# branch). cwd=$tmp ⇒ SCRIPT_DIR=$tmp. A prior version ran install.sh from a
# file, which hid the stdin-pipe caveat that breaks interactive reads.
cat "$SCRIPT_DIR/install.sh" | ( cd "$tmp" && HOME="$tmp" SHELL="/bin/bash" \
  GLM_CLI_NO_VERIFY=1 ZAI_API_KEY="$mock_key" \
  bash ) >"$tmp/install.log" 2>&1
rc=$?

PASS=0; FAIL=0
ok()  { printf "  \033[32m✓\033[0m %s\n" "$1"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✗\033[0m %s\n" "$1"; FAIL=$((FAIL+1)); }

[ "$rc" = 0 ] && ok "install.sh exited 0" || { bad "install.sh exited $rc"; echo "---- install.log ----"; cat "$tmp/install.log"; }

[ -x "$tmp/.local/bin/glm" ]  && ok "glm wrapper installed + executable"  || bad "glm wrapper missing/not-exec"
[ -x "$tmp/.local/bin/glmf" ] && ok "glmf wrapper installed + executable" || bad "glmf wrapper missing/not-exec"

n="$(grep -cE '(^|[[:space:]])(export[[:space:]]+)?PATH=.*\.local/bin' "$tmp/.bashrc" 2>/dev/null || printf 0)"
[ "$n" = 1 ] && ok "PATH line added exactly once in tmp .bashrc ($n)" || bad "PATH lines: want 1, got $n"

[ -f "$tmp/.zai_api_key" ] && ok "key file written (chmod $(stat -c '%a' "$tmp/.zai_api_key" 2>/dev/null || stat -f '%Lp' "$tmp/.zai_api_key"))" || bad "key file missing"

after="$(stat -c '%Y' "$real_bashrc" 2>/dev/null || stat -f '%m' "$real_bashrc" 2>/dev/null || printf 0)"
[ "$before" = "$after" ] && ok "REAL ~/.bashrc untouched (mtime unchanged)" || bad "REAL ~/.bashrc was modified — isolation leak"

rm -rf "$tmp"
echo
printf "  %s passed, %s failed\n" "$PASS" "$FAIL"
[ "$FAIL" = 0 ] && exit 0 || exit 1
