#!/usr/bin/env bash
# dev/verify-patches.sh — one pre-commit / pre-promote gate for patch changes.
#
# Combines the cheap checks that together catch the "patches look fine but the
# build dies at minute 16" class:
#   1. check-patch-collisions.sh — static scan of patches/user/*.patch for two patches carrying
#                          the SAME hunk (<1s, local). Catches a sequence-only clash that #3 below
#                          is blind to (it tests each patch vs pristine in ISOLATION). Built after a
#                          full build died at the patch phase on exactly this (retro 2026-05-31).
#   2. check-ts.sh       — tsgo --noEmit on the live vscode/ tree (~25-70s, local).
#                          Catches noUnusedLocals (TS6133) / orphan imports / type errors —
#                          the exact failure that silently kills vscode-min-prepack mid-build.
#   3. check-patches.sh  — git apply --check of every patches/user/*.patch against a fresh
#                          upstream sparse clone (~30-60s, needs network). Catches patches
#                          that no longer apply cleanly.
#
# This does NOT reset or rebuild vscode/ — it is non-destructive and never touches your
# un-promoted live edits. (A full reset+reapply variant was deliberately NOT built: it would
# wipe un-promoted vscode/ edits, and check-ts already TS-checks the live tree, which is what
# catches the real incident. See .claude/harness-backlog.md.)
#
# Usage:
#   dev/verify-patches.sh                 # both checks
#   dev/verify-patches.sh --no-apply      # TS check only (skip the network clone — fast, offline)
#   dev/verify-patches.sh --no-ts         # apply check only
#   dev/verify-patches.sh patches/user/foo.patch [...]   # apply-check only these (implies running TS too)
#
# Exit 0 = all run checks passed.  Exit 1 = a check failed.  Exit 2 = tree not ready.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

run_ts=1
run_apply=1
patch_args=()
for arg in "$@"; do
  case "$arg" in
    --no-ts)    run_ts=0 ;;
    --no-apply) run_apply=0 ;;
    -h|--help)  sed -n '2,30p' "$0"; exit 0 ;;
    *)          patch_args+=("$arg") ;;  # explicit patch files -> pass through to check-patches.sh
  esac
done

coll_rc=0
ts_rc=0
apply_rc=0

# Gate 1 — collision lint (local, <1s, no network). Catches two user patches carrying the SAME
# hunk (a sequence-only clash that check-patches.sh, testing each patch vs pristine in isolation,
# is structurally blind to — see dev/check-patch-collisions.sh). Always run: it's the cheapest gate.
echo "── 1/3  Patch collision lint (duplicated hunks) ─────────────────────────"
bash "$REPO_ROOT/dev/check-patch-collisions.sh"; coll_rc=$?
echo ""

if [[ "$run_ts" -eq 1 ]]; then
  echo "── 2/3  TS compile gate (live vscode/ tree) ─────────────────────────────"
  bash "$REPO_ROOT/dev/check-ts.sh"; ts_rc=$?
  echo ""
fi

if [[ "$run_apply" -eq 1 ]]; then
  echo "── 3/3  Patch apply check (fresh upstream clone) ────────────────────────"
  bash "$REPO_ROOT/check-patches.sh" "${patch_args[@]}"; apply_rc=$?
  echo ""
fi

echo "──────────────────────────────────────────────────────────────────────────"
{ [[ "$coll_rc" -eq 0 ]] && echo "✓ Patch collision lint: PASS" || echo "✗ Patch collision lint: FAIL ($coll_rc)"; }
[[ "$run_ts"    -eq 1 ]] && { [[ "$ts_rc"    -eq 0 ]] && echo "✓ TS compile gate: PASS"    || echo "✗ TS compile gate: FAIL ($ts_rc)"; }
[[ "$run_apply" -eq 1 ]] && { [[ "$apply_rc" -eq 0 ]] && echo "✓ Patch apply check: PASS"  || echo "✗ Patch apply check: FAIL ($apply_rc)"; }

if [[ "$coll_rc" -ne 0 || "$ts_rc" -ne 0 || "$apply_rc" -ne 0 ]]; then
  echo "→ Fix the above before committing / before any full build."
  exit 1
fi
echo "→ Safe to commit / promote. (A full build is still required to produce the .exe.)"
