#!/usr/bin/env bash
# Arclen QA iteration loop.
# Chains the full cycle after editing files in vscode/src/:
#   1. tsgo --noEmit  (catches noUnusedLocals/imports/types early)
#   2. node build/next/index.ts transpile  (emits to vscode/out/)
#   3. agent-browser Ctrl+R + reconnect    (reloads the dev app)
#   4. screenshot                          (dev/qa-<label>-<HHMMSS>.png)
#   5. brand-leak scan                     (HIGH-confidence only)
#
# Usage:
#   dev/qa-loop.sh                          # full loop with label "iter"
#   dev/qa-loop.sh announcements            # label = "announcements"
#   dev/qa-loop.sh --skip-tscheck issue2    # skip the type check (faster)
#   dev/qa-loop.sh --no-shot issue3         # skip the screenshot

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKIP_TSCHECK=0
SKIP_SHOT=0
LABEL="iter"
CDP_PORT=9222

for arg in "$@"; do
  case "$arg" in
    --skip-tscheck) SKIP_TSCHECK=1 ;;
    --no-shot)      SKIP_SHOT=1 ;;
    --port=*)       CDP_PORT="${arg#--port=}" ;;
    *)              LABEL="$arg" ;;
  esac
done

TS=$(date +%H%M%S)
SHOT_PATH="$REPO_ROOT/dev/qa-${LABEL}-${TS}.png"

step() { printf '\n\033[1;36m[step %s]\033[0m %s\n' "$1" "$2"; }
ok()   { printf '\033[0;32m  ✓ %s\033[0m\n' "$1"; }
fail() { printf '\033[0;31m  ✗ %s\033[0m\n' "$1"; exit 1; }

cd "$REPO_ROOT/vscode"

if [ "$SKIP_TSCHECK" -eq 0 ]; then
  step 1/5 "Type check (tsgo --noEmit, ~25s)"
  if npm run compile-check-ts-native --silent 2>&1 | tail -5 | grep -qE "error TS|noEmit failed"; then
    npm run compile-check-ts-native --silent 2>&1 | grep -E "error TS|noEmit failed" | head -10
    fail "TS errors — fix before transpile"
  fi
  ok "no TS errors"
else
  step 1/5 "Type check — SKIPPED"
fi

step 2/5 "Transpile src/ → out/ (~10s)"
if ! node build/next/index.ts transpile 2>&1 | tail -3 | grep -q "Done in"; then
  fail "Transpile failed — see output above"
fi
ok "out/ refreshed"

step 3/5 "Reload dev window (Ctrl+R via agent-browser)"
agent-browser --cdp "$CDP_PORT" press "Ctrl+R" >/dev/null 2>&1 || true
sleep 4   # window needs ~3s to fully reload and re-expose CDP targets
if ! agent-browser connect "$CDP_PORT" >/dev/null 2>&1; then
  fail "Could not reconnect to CDP $CDP_PORT — is code.bat running with --remote-debugging-port=$CDP_PORT ?"
fi
ok "reloaded + reconnected"

if [ "$SKIP_SHOT" -eq 0 ]; then
  step 4/5 "Screenshot → dev/qa-${LABEL}-${TS}.png"
  # Retry up to 3x — workbench takes ~5-8s post-reload to be screenshot-able
  for attempt in 1 2 3; do
    shot_out=$(agent-browser --cdp "$CDP_PORT" screenshot "$SHOT_PATH" 2>&1)
    if echo "$shot_out" | grep -q "Screenshot saved"; then
      ok "saved $SHOT_PATH (attempt $attempt)"
      break
    fi
    if [ "$attempt" -eq 3 ]; then
      echo "$shot_out"
      fail "Screenshot failed after 3 attempts"
    fi
    sleep 3
  done
else
  step 4/5 "Screenshot — SKIPPED"
fi

step 5/5 "Brand-leak scan (HIGH-confidence)"
if "$REPO_ROOT/dev/check-brand-leaks.sh" >/tmp/arclen-leaks.log 2>&1; then
  ok "no HIGH leaks"
else
  cat /tmp/arclen-leaks.log
  fail "HIGH brand leaks detected"
fi

printf '\n\033[1;32m✓ QA loop clean for label "%s"\033[0m\n' "$LABEL"
[ "$SKIP_SHOT" -eq 0 ] && printf 'Screenshot: %s\n' "$SHOT_PATH"
