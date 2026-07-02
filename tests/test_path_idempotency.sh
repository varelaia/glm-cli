#!/usr/bin/env bash
# test_path_idempotency.sh — validates that ensure_path() (from install.sh) is
# idempotent. Covers the regression the v1 had: duplicating the PATH line when
# it already existed in $HOME-form (what the native Claude installer writes) or
# in expanded-form, plus not persisting when PATH was only loaded in the session.
#
# Strategy: source install.sh (which does NOT run main(), thanks to its source
# guard) and exercise ensure_path() against a throwaway HOME with controlled
# .bashrc scenarios. The real HOME/.bashrc is never touched.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/install.sh"
set +e   # install.sh sets -e; we want to run every case and tally at the end.

PASS=0; FAIL=0
ok()  { printf "  \033[32m✓\033[0m %s\n" "$1"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✗\033[0m %s\n" "$1"; FAIL=$((FAIL+1)); }

# Count PATH assignments referencing .local/bin in the given rc file.
count_path_lines() { grep -cE '(^|[[:space:]])(export[[:space:]]+)?PATH=.*\.local/bin' "$1" 2>/dev/null || printf 0; }

# Run ensure_path over a tmp HOME whose .bashrc starts as $1; echo final count.
run() {
  local initial="$1" tmp
  tmp="$(mktemp -d)"
  printf '%s' "$initial" > "$tmp/.bashrc"
  HOME="$tmp" SHELL="/bin/bash" ensure_path >/dev/null 2>&1 || true
  count_path_lines "$tmp/.bashrc"
  rm -rf "$tmp"
}

echo "test_path_idempotency:"

# 1) empty rc → exactly 1 line added.
c="$(run "")";                                       [ "$c" = 1 ] && ok "empty rc → 1 line ($c)"                  || bad "empty rc: want 1, got $c"
# 2) pre-existing $HOME-form → no duplicate (v1 regression).
c="$(run 'export PATH="$HOME/.local/bin:$PATH"
')";                  [ "$c" = 1 ] && ok "\$HOME-form present → no duplicate ($c)"   || bad "\$HOME-form: want 1, got $c"
# 3) pre-existing expanded-form → no duplicate.
c="$(run 'export PATH="/home/jsnow/.local/bin:$PATH"
')";        [ "$c" = 1 ] && ok "expanded-form present → no duplicate ($c)"|| bad "expanded-form: want 1, got $c"
# 4) Ubuntu-style snippet (PATH= without export) → no duplicate.
c="$(run 'if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
')";        [ "$c" = 1 ] && ok "Ubuntu snippet present → no duplicate ($c)"      || bad "ubuntu snippet: want 1, got $c"
# 5) self-idempotency: 2 consecutive runs → still 1 line.
tmp="$(mktemp -d)"; printf '' > "$tmp/.bashrc"
HOME="$tmp" SHELL="/bin/bash" ensure_path >/dev/null 2>&1 || true
HOME="$tmp" SHELL="/bin/bash" ensure_path >/dev/null 2>&1 || true
c="$(count_path_lines "$tmp/.bashrc")";              [ "$c" = 1 ] && ok "2 consecutive runs → 1 line ($c)"        || bad "2 runs: want 1, got $c"
rm -rf "$tmp"
# 6) anti-regression Edge-1: PATH loaded in session + empty rc → MUST still persist.
#    (v1 skipped the write when $PATH had .local/bin; v2 gates only on the rc.)
tmp="$(mktemp -d)"; printf '' > "$tmp/.bashrc"
HOME="$tmp" SHELL="/bin/bash" PATH="/fake/.local/bin:/usr/bin:/bin" ensure_path >/dev/null 2>&1 || true
c="$(count_path_lines "$tmp/.bashrc")";              [ "$c" = 1 ] && ok "PATH-in-session + empty rc → persists ($c)" || bad "edge-1: want 1, got $c"
rm -rf "$tmp"

echo
printf "  %s passed, %s failed\n" "$PASS" "$FAIL"
[ "$FAIL" = 0 ] && exit 0 || exit 1
