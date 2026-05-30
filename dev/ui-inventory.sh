#!/usr/bin/env bash
# dev/ui-inventory.sh — deterministic inventory of the Arclen workbench chrome.
#
# WHY THIS EXISTS (retro 2026-05-30):
#   The dé-scaring work ("is the Run menu gone? is the Problems counter hidden? did the
#   activity-bar trim survive?") was being verified by eyeballing screenshots — slow, and
#   easy to miss a 14px status-bar item. agent-browser can read the live workbench DOM, so
#   the visible chrome can be ENUMERATED instead of guessed. This dumps the always-visible
#   surfaces (menubar · activity bar · sidebar title · panel tabs · status bar) as JSON, so
#   "what's visible now" becomes a deterministic, diffable artifact.
#
#   BOUNDARY (honest): agent-browser evals the MAIN workbench frame. Webview interiors
#   (the Claude Code panel, the Welcome page) live in cross-origin iframes — this CANNOT see
#   inside them. Webview content stays screenshot-only. Everything else (the bulk of the
#   trim work) is covered here.
#
# Usage:
#   dev/ui-inventory.sh                 # print JSON inventory of the running dev build
#   dev/ui-inventory.sh --shot out.png  # also screenshot
#   dev/ui-inventory.sh --port 9222     # CDP port (default 9222)
#   dev/ui-inventory.sh --expect-absent status.host        # exit 3 if that status id is visible
#   dev/ui-inventory.sh --expect-present status.notifications  # exit 3 if that status id is missing
#
# Requires the dev build already running with CDP (dev/relaunch.sh launches it on 9222).
# Exit: 0 ok | 2 no workbench/connection | 3 an --expect assertion failed
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

PORT=9222
SHOT=""
EXPECT_ABSENT=()
EXPECT_PRESENT=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --shot)           SHOT="$2"; shift ;;
    --port)           PORT="$2"; shift ;;
    --expect-absent)  EXPECT_ABSENT+=("$2"); shift ;;
    --expect-present) EXPECT_PRESENT+=("$2"); shift ;;
    *) echo "unknown arg: $1" >&2; exit 64 ;;
  esac
  shift
done

agent-browser connect "${PORT}" >/dev/null 2>&1 || { echo "no CDP on ${PORT} — is the dev build running?" >&2; exit 2; }
# connect can land on about:blank; switch to the workbench target (same trick as relaunch.sh).
_wbid="$(agent-browser tab list --json 2>/dev/null | jq -r '(.data.tabs // []) | ((map(select((.url // .title // "") | test("workbench";"i")))[0]) // (map(select(.active))[0]) // .[0]) | (.tabId // empty)' 2>/dev/null)"
[[ -n "${_wbid}" ]] && agent-browser tab "${_wbid}" >/dev/null 2>&1 || true

# One eval returns the whole inventory as JSON. Keep selectors resilient: only report items
# that are actually visible (offsetParent + width), strip VS Code's structural classes.
read -r -d '' PROBE <<'JS' || true
(()=>{
  const vis = el => el && el.offsetParent !== null && el.offsetWidth > 0;
  const txt = el => (el.textContent||"").trim().replace(/\s+/g," ");
  const labelList = sel => [...document.querySelectorAll(sel)]
    .filter(vis).map(el => el.getAttribute("aria-label") || txt(el) || el.title || "?");
  const statusItems = sel => [...document.querySelectorAll(sel)].filter(vis).map(el => ({
    id: el.getAttribute("id") || "",
    label: el.getAttribute("aria-label") || "",
    text: txt(el)
  }));
  const sidebar = document.querySelector(".part.sidebar");
  const sidebarTitle = sidebar && vis(sidebar)
    ? (sidebar.querySelector(".composite.title .title-label")?.textContent || "").trim() : null;
  return JSON.stringify({
    menubar:      labelList(".menubar .menubar-menu-button"),
    activityBar:  labelList(".activitybar .action-item .action-label"),
    sidebarTitle,
    panelTabs:    labelList(".part.panel .panel-switcher-container .action-item .action-label"),
    statusLeft:   statusItems(".statusbar .left-items .statusbar-item"),
    statusRight:  statusItems(".statusbar .right-items .statusbar-item")
  });
})()
JS

RAW="$(agent-browser eval "${PROBE}" 2>/dev/null)"
# agent-browser wraps the string result in quotes and escapes inner quotes — unwrap to real JSON.
JSON="$(printf '%s' "${RAW}" | jq -r '. // empty' 2>/dev/null)"
[[ -z "${JSON}" ]] && { echo "no workbench DOM (NO_WORKBENCH) — workbench not painted yet?" >&2; exit 2; }

echo "${JSON}" | jq .

[[ -n "${SHOT}" ]] && agent-browser screenshot "${SHOT}" >/dev/null 2>&1 && echo "shot → ${SHOT}" >&2

# ─── Optional assertions on status-bar ids (deterministic regression checks) ───
rc=0
visible_ids="$(echo "${JSON}" | jq -r '(.statusLeft + .statusRight)[].id')"
for id in "${EXPECT_ABSENT[@]:-}"; do
  [[ -z "${id}" ]] && continue
  if printf '%s\n' "${visible_ids}" | grep -qxF "${id}"; then
    printf '  ✗ expected ABSENT but visible: %s\n' "${id}" >&2; rc=3
  else
    printf '  ✓ absent: %s\n' "${id}" >&2
  fi
done
for id in "${EXPECT_PRESENT[@]:-}"; do
  [[ -z "${id}" ]] && continue
  if printf '%s\n' "${visible_ids}" | grep -qxF "${id}"; then
    printf '  ✓ present: %s\n' "${id}" >&2
  else
    printf '  ✗ expected PRESENT but missing: %s\n' "${id}" >&2; rc=3
  fi
done
exit "${rc}"
