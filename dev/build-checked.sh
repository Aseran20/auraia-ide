#!/usr/bin/env bash
# Gated, TRUTHFUL build wrapper — the canonical way to run a full build.
#
# Fixes the two traps that cost us ~16 min on 2026-05-28:
#   1. A patch broke compile with noUnusedLocals — only surfaced after a full build.
#   2. `dev/build.sh ... | tee build.log` reports exit 0 even when the build FAILED
#      (the pipeline's exit code is tee's, not the build's).
#
# This wrapper:
#   [1] runs a 25s TS gate first and ABORTS before wasting ~16 min if it's red;
#   [2] runs dev/build.sh with `set -o pipefail` so the real exit code propagates;
#   [3] scans build.log for the compile-failure signature as a backstop.
#
# Usage: dev/build-checked.sh [-s|-i|...]   (same flags as dev/build.sh)
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== [1/2] Pre-build TS gate (~25s) ==="
echo "    Note: checks the CURRENT vscode/ tree. If you just pulled NEW patches,"
echo "    run dev/sync-and-check.sh first so the tree reflects them (else this"
echo "    gate is a false-green and the real build below is the safety net)."
if [ -d vscode/node_modules ]; then
  if ! ./dev/check-ts.sh; then
    echo "✗ Aborting build — 25s just saved you ~16 min. Fix the TS errors above."
    exit 1
  fi
else
  echo "    (skipped — vscode/ not populated yet; the first build will create it.)"
fi

echo ""
echo "=== [2/2] Build (truthful exit, no tee masking) ==="
set -o pipefail
./dev/build.sh "$@" 2>&1 | tee build.log
rc=${PIPESTATUS[0]}

# Backstop: the real failure signature, regardless of any exit-code games.
if grep -qaE "errored after|Finished compilation with [1-9]|Found [0-9]+ error" build.log; then
  echo "✗ BUILD FAILED — compile errors (see build.log):"
  grep -aE "errored after|Finished compilation with [1-9]|Found [0-9]+ error|is declared but its value is never read" build.log | tail -12
  exit 1
fi
if [ "$rc" -ne 0 ]; then
  echo "✗ build.sh exited with code $rc (see build.log)."
  exit "$rc"
fi

echo "✓ Build completed cleanly."
