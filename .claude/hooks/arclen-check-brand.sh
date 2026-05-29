#!/usr/bin/env bash
# PostToolUse hook: after every Edit/Write in vscode/src/, run check-brand-leaks.sh
# on the edited file and emit a systemMessage if HIGH-confidence leaks are found.
# Non-blocking — informational only.

set -euo pipefail

INPUT="$(cat)"
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
# Windows CC sends backslash file_path; the forward-slash globs below would never match
# (hook no-ops). Normalize to forward slashes so brand-leak scanning actually fires.
FILE_PATH=$(printf '%s' "$FILE_PATH" | tr '\\' '/')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LEAK_SCRIPT="$PROJECT_DIR/dev/check-brand-leaks.sh"

case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) : ;;
  *) exit 0 ;;
esac

[ -z "$FILE_PATH" ] && exit 0
[ -f "$FILE_PATH" ] || exit 0
[ -x "$LEAK_SCRIPT" ] || exit 0

# Only scan files inside vscode/src/{workbench,code,platform/product}/
case "$FILE_PATH" in
  */vscode/src/vs/workbench/*|*/vscode/src/vs/code/*|*/vscode/src/vs/platform/product/*) : ;;
  *) exit 0 ;;
esac

# Run the canonical script on just this file. Capture HIGH section only.
OUTPUT=$("$LEAK_SCRIPT" "$FILE_PATH" 2>&1 || true)
HIGH_HITS=$(echo "$OUTPUT" | awk '/=== HIGH/,/=== MEDIUM/' | grep -E '^\s+' || true)

if [ -z "$HIGH_HITS" ]; then
  exit 0
fi

REL_PATH="${FILE_PATH#"$PROJECT_DIR"/}"
MESSAGE="⚠ Arclen brand-leak (HIGH) in ${REL_PATH}:
${HIGH_HITS}

Source of truth: dev/check-brand-leaks.sh (single file). Fix before commit."

jq -n --arg msg "$MESSAGE" '{"systemMessage": $msg, "suppressOutput": true}'
