#!/usr/bin/env bash
# PostToolUse hook: record live edits to vscode/ source into a session ledger so the
# destructive-build guard (arclen-guard-destructive.sh) can warn before `build -s`
# (= git reset --hard HEAD) silently wipes un-promoted work.
#
# WHY: vscode/ is ALWAYS in a modified state (every patch is an uncommitted mod vs the
# pristine baseline), so `git status` can't distinguish "modified by a patch" (safe to
# reset — the patch reapplies) from "modified by an un-promoted live edit" (LOST on reset).
# This ledger tracks only the files Claude actually edited this session, so the guard fires
# precisely — no crying wolf on the always-modified tree.
#
# dev/gen-user-patch.sh removes a file from this ledger when it promotes it to a patch.
# Non-blocking — informational bookkeeping only.

set -euo pipefail

INPUT="$(cat)"
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
# On Windows, CC sends file_path with BACKSLASHES (C:\...\vscode\src\...). The globs
# below are forward-slash, so without this the case never matches and the hook silently
# no-ops — the guard's ledger would stay empty and fail to protect. Normalize to forward.
FILE_PATH=$(printf '%s' "$FILE_PATH" | tr '\\' '/')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LEDGER="$PROJECT_DIR/.claude/.live-edits"

case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) : ;;
  *) exit 0 ;;
esac

[ -z "$FILE_PATH" ] && exit 0

# Only track real dev-edit surfaces inside vscode/ that a reset would wipe.
# Exclude generated/transient trees (out*, node_modules, .build).
case "$FILE_PATH" in
  */vscode/out*|*/vscode/node_modules/*|*/vscode/.build/*) exit 0 ;;
  */vscode/src/*|*/vscode/extensions/*|*/vscode/product.json|*/vscode/package.json) : ;;
  *) exit 0 ;;
esac

# Compute the vscode-relative path (everything after the last "/vscode/").
REL="${FILE_PATH##*/vscode/}"
[ "$REL" = "$FILE_PATH" ] && exit 0   # defensive: no /vscode/ segment

# Append to the ledger, deduped. (Plain text, one path per line.)
touch "$LEDGER"
if ! grep -qxF "$REL" "$LEDGER" 2>/dev/null; then
  echo "$REL" >> "$LEDGER"
fi
exit 0
