#!/usr/bin/env bash
# Fast authoritative TS gate for the patched vscode/ tree (~25s).
#
# Runs `tsgo --noEmit` on src/ — catches noUnusedLocals (TS6133), missing imports,
# and type errors. These are EXACTLY the errors that silently fail `vscode-min-prepack`
# at minute ~16 of a full build. Run this BEFORE committing to a full build.
#
# Exit 0 = clean.  Exit 1 = TS errors (printed).  Exit 2 = tree not ready.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT/vscode" 2>/dev/null || { echo "✗ vscode/ not found — populate it with a build first."; exit 2; }
[ -d node_modules ] || { echo "✗ vscode/node_modules missing — run a build first."; exit 2; }

echo "[check-ts] tsgo --noEmit on src/ (~25s)..."
out="$(npm run --silent compile-check-ts-native 2>&1)"; rc=$?

# tsgo prints, e.g.:  src/.../file.ts(72,7): error TS6133: 'setupIcon' is declared but its value is never read.
errs="$(printf '%s\n' "$out" | grep -E "error TS[0-9]+|is declared but its value is never read|Cannot find name" || true)"

if [ "$rc" -ne 0 ] || [ -n "$errs" ]; then
  if [ -n "$errs" ]; then
    printf '%s\n' "$errs" | sed '/^[[:space:]]*$/d' | head -40
  else
    # rc != 0 but no recognizable TS error line — show raw tail so the cause is visible.
    printf '%s\n' "$out" | tail -20
  fi
  echo "✗ TS check FAILED — fix these now; they WILL fail the full build."
  exit 1
fi

echo "✓ TS check clean (src/ type-checks)."
