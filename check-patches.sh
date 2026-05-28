#!/usr/bin/env bash
# check-patches.sh — verify user patches apply against upstream VS Code
#
# Uses git sparse-checkout + --filter=blob:none to fetch only the files
# each patch touches, in a real git context (~10-20s, no vscode/ needed).
#
# Why not curl per-file: curl in an ad-hoc temp repo gives false positives
# on multi-file patches — git apply processes hunks across files as a unit,
# and per-file isolation breaks that. Sparse clone avoids the problem.
#
# Usage: bash check-patches.sh [patch-file ...]  (defaults to patches/user/*.patch)

set -euo pipefail

green='\033[0;32m'
red='\033[0;31m'
reset='\033[0m'

COMMIT=$(jq -r '.commit' upstream/stable.json)
TAG=$(jq -r '.tag'    upstream/stable.json)
VSCODE_URL="https://github.com/microsoft/vscode.git"

echo "Checking patches against VS Code ${TAG} (${COMMIT:0:10})..."
echo ""

# ─── Collect patches ─────────────────────────────────────────────────────────

PATCHES=("${@}")
if [[ ${#PATCHES[@]} -eq 0 ]]; then
  while IFS= read -r -d '' f; do
    PATCHES+=("$f")
  done < <(find patches/user -name '*.patch' -print0 2>/dev/null | sort -z)
fi

if [[ ${#PATCHES[@]} -eq 0 ]]; then
  echo "No patches found in patches/user/ — nothing to check."
  exit 0
fi

# ─── Sparse clone: tree metadata only, no blobs yet ──────────────────────────

WORKDIR=$(mktemp -d)
trap "rm -rf ${WORKDIR}" EXIT

echo "Cloning VS Code tree (no blobs)..."
git clone \
  --depth 1 \
  --filter=blob:none \
  --no-checkout \
  --quiet \
  "${VSCODE_URL}" \
  "${WORKDIR}/vscode"

cd "${WORKDIR}/vscode"

# ─── Sparse checkout: only files the patches touch ───────────────────────────

# Collect all unique file paths across all patches
PATCH_FILES=$(
  grep '^+++ b/' "${PATCHES[@]}" \
    | sed 's|^.*:+++ b/||' \
    | sort -u
)

git sparse-checkout init --no-cone 2>/dev/null
echo "${PATCH_FILES}" > .git/info/sparse-checkout

# Pin to exact commit (depth-1 clone fetches HEAD; verify it matches)
CLONED_COMMIT=$(git rev-parse HEAD)
if [[ "${CLONED_COMMIT}" != "${COMMIT}" ]]; then
  echo "Warning: cloned HEAD is ${CLONED_COMMIT:0:10}, expected ${COMMIT:0:10}"
  echo "upstream/stable.json may be out of sync with the default branch."
fi

git checkout HEAD -- 2>/dev/null

echo "Downloaded ${PATCH_FILES_COUNT:-$(echo "${PATCH_FILES}" | wc -l | tr -d ' ')} file(s). Checking patches..."
echo ""

# ─── Check each patch ────────────────────────────────────────────────────────

PASS=0
FAIL=0

for patch in "${PATCHES[@]}"; do
  name=$(basename "${patch}")

  if git apply --check --ignore-whitespace "${patch}" 2>/dev/null; then
    echo -e "  ${green}✓${reset} ${name}"
    ((PASS++)) || true
  else
    echo -e "  ${red}✗${reset} ${name}:"
    git apply --ignore-whitespace "${patch}" 2>&1 \
      | grep -E '^error:|^patch failed' \
      | head -5 \
      | sed 's/^/    /'
    ((FAIL++)) || true
  fi
done

echo ""
echo "Result: ${PASS} passed, ${FAIL} failed"
[[ "${FAIL}" -eq 0 ]]
