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

# Match the destructive operations that reset vscode/ to pristine:
#   • a source build (build.sh / build-checked.sh) with the -s flag
#   • an explicit hard reset
is_destructive=0
case "$CMD" in
  *build*.sh*-s*)        is_destructive=1 ;;
  *"git reset --hard"*)  is_destructive=1 ;;
  *"reset -q --hard"*)   is_destructive=1 ;;
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
