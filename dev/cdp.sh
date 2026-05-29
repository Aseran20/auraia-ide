#!/usr/bin/env bash
# dev/cdp.sh — connect agent-browser to the Arclen dev app's REAL workbench page.
#
# WHY THIS EXISTS (retro 2026-05-29):
#   `agent-browser connect <port>` attaches to whatever target the browser hands
#   back first — for an Electron/VS Code app that is often the `about:blank`
#   shared-process page, NOT the workbench. Screenshot/eval against that target
#   then returns a blank black image or `NO_WORKBENCH`, and past sessions burned
#   several blind screenshots chasing a "broken" UI that was actually the wrong
#   page. The fix (per agent-browser's own `electron` skill) is to connect and
#   then `tab --url "*workbench*"` to switch onto the real workbench target.
#   This wraps that two-step into one command so every visual-QA call lands right.
#
# Usage:
#   dev/cdp.sh                              # connect + select workbench (idempotent)
#   dev/cdp.sh --shot dev/check.png         # ... then screenshot the workbench
#   dev/cdp.sh --eval '<js>'                # ... then eval JS on the workbench, print result
#   dev/cdp.sh --snapshot                   # ... then print the accessibility snapshot (-i refs)
# Options:
#   --port N     CDP port (default 9222)
#
# Exit codes: 0 ok | 2 could not connect | 3 no workbench target found
#
# NOTE: this does NOT launch or wait for paint. For a cold relaunch + readiness
# gate use dev/relaunch.sh (which now selects the workbench tab via this same
# mechanism before probing). Use cdp.sh when the app is already up and painted.

set -uo pipefail

PORT=9222
SHOT=""
EVAL=""
DO_SNAPSHOT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --shot)      SHOT="$2"; shift ;;
    --shot=*)    SHOT="${1#*=}" ;;
    --eval)      EVAL="$2"; shift ;;
    --eval=*)    EVAL="${1#*=}" ;;
    --snapshot)  DO_SNAPSHOT=1 ;;
    --port)      PORT="$2"; shift ;;
    --port=*)    PORT="${1#*=}" ;;
    *) echo "unknown arg: $1" >&2; exit 64 ;;
  esac
  shift
done

ok()  { printf '\033[0;32m  ✓ %s\033[0m\n' "$1"; }
die() { printf '\033[0;31m  ✗ %s\033[0m\n' "$1" >&2; exit "${2:-1}"; }

# ─── 1. Connect ───────────────────────────────────────────────────────────────
agent-browser connect "${PORT}" >/dev/null 2>&1 \
  || die "could not connect to CDP ${PORT} — is the dev app running with --remote-debugging-port=${PORT}? (use dev/relaunch.sh)" 2

# ─── 2. Switch onto the workbench target (the whole point) ─────────────────────
# This agent-browser (0.27.0) selects tabs by id/label only — no --url filter — so
# we list as JSON and pick the target whose url is VS Code's renderer
# (.../workbench/workbench*.html). Falls back to the active tab, then the first.
TABS_JSON="$(agent-browser tab list --json 2>/dev/null)"
WB_ID="$(printf '%s' "${TABS_JSON}" | jq -r '
  (.data.tabs // [])
  | ( ( map(select((.url // .title // "") | test("workbench"; "i")))[0] )
      // ( map(select(.active))[0] )
      // .[0] )
  | (.tabId // empty)' 2>/dev/null)"

[[ -n "${WB_ID}" ]] || die "no targets on CDP ${PORT} (window not painted yet?). Try dev/relaunch.sh" 3
agent-browser tab "${WB_ID}" >/dev/null 2>&1 || die "could not switch to tab ${WB_ID}" 3
ok "on workbench target (${WB_ID})"

# ─── 3. Optional actions ───────────────────────────────────────────────────────
if [[ -n "${EVAL}" ]]; then
  agent-browser eval "${EVAL}" || die "eval failed"
fi

if [[ "${DO_SNAPSHOT}" -eq 1 ]]; then
  agent-browser snapshot -i || die "snapshot failed"
fi

if [[ -n "${SHOT}" ]]; then
  agent-browser screenshot "${SHOT}" >/dev/null 2>&1 && ok "saved ${SHOT}" || die "screenshot failed"
fi
