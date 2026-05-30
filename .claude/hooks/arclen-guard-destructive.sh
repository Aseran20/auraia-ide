#!/usr/bin/env bash
# PreToolUse hook (Bash): block a destructive vscode/ reset when un-promoted live edits exist.
#
# Enforces the CLAUDE.md "Risky actions" rule that was previously advisory-only:
#   `-s` builds run `git add . && git reset -q --hard HEAD` on vscode/ (dev/build.sh:113-114),
#   which wipes any live edit not yet captured in a patch. Documented ≠ prevented — this hook
#   is the enforcement (per the harness "enforce, don't remember" principle).
#
# Fires ONLY when the session ledger (.claude/.live-edits, written by arclen-track-edits.sh)
# lists files — i.e. Claude edited vscode/ source this session and hasn't promoted it. That
# avoids crying wolf on the always-modified tree. gen-user-patch.sh clears promoted files.
#
# Escape hatches printed in the deny message: promote, or (if discarding is intended) rm ledger.

set -euo pipefail

INPUT="$(cat)"
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LEDGER="$PROJECT_DIR/.claude/.live-edits"

[ "$TOOL_NAME" = "Bash" ] || exit 0

# Strip a `-m`/`-F` message body (everything from the first " -m "/" -F " to end of
# command) BEFORE pattern-matching, so commit prose can't trip the match below.
SCAN="$CMD"
case "$CMD" in
  *" -m "*) SCAN="${CMD%% -m *}" ;;
  *" -F "*) SCAN="${CMD%% -F *}" ;;
esac

# Match the destructive operations that reset vscode/ to pristine:
#   • a source build: invokes build.sh / build-checked.sh AND passes a standalone -s/--source flag
#   • an explicit hard reset
#
# WHY token-anchored, not `*build*.sh*-s*` (retro 2026-05-30, 2nd recurrence): the loose
# glob matched ANY command whose substrings happened to align — a commit message, or even
# `node build/next/index.ts && ./dev/relaunch.sh dev/oe-simplified.png` ("build"…".sh"…"-s"
# in "oe-simplified"). The -m strip only fixed the commit case. Anchor the build-script name
# to a path/word boundary + require -s to be a standalone flag token (space/edge on both sides)
# so paths like "oe-simplified" or "relaunch.sh" no longer false-positive.
is_destructive=0
if printf '%s' "$SCAN" | grep -qE '(^|[[:space:]/])build(-checked)?\.sh([[:space:]]|$)' \
   && printf '%s' "$SCAN" | grep -qE '(^|[[:space:]])(-s|--source)([[:space:]]|$)' ; then
  is_destructive=1
fi
case "$SCAN" in
  *"git reset --hard"*|*"reset -q --hard"*) is_destructive=1 ;;
esac
[ "$is_destructive" -eq 1 ] || exit 0

# No ledger or empty ledger → nothing un-promoted → allow.
[ -s "$LEDGER" ] || exit 0
FILES=$(grep -vE '^\s*$' "$LEDGER" 2>/dev/null || true)
[ -z "$FILES" ] && exit 0

LIST=$(echo "$FILES" | sed 's/^/  • /')
REASON="⛔ This command resets vscode/ to the pristine upstream commit — it will WIPE these
live edits that have NOT been promoted to a patch:

${LIST}

Un-promoted edits cannot be recovered after the reset. Choose one:
  1) Promote them first:  dev/gen-user-patch.sh patches/user/arclen-NAME.patch <file...>
     (gen-user-patch.sh clears each file from the ledger once promoted)
  2) Intentionally discarding them? Clear the ledger, then re-run:
     rm .claude/.live-edits

Then retry the build."

jq -n --arg r "$REASON" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": $r
  }
}'
exit 0
