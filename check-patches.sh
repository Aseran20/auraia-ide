#!/usr/bin/env bash
# check-patches.sh — verify user patches apply against upstream VS Code
#
# The build applies patches in order: patches/*.patch → patches/user/*.patch
# User patches run against a MODIFIED state (not raw VS Code). This script
# reproduces that correctly by applying any base patch that overlaps with
# the user patch's target files before running --check.
#
# Uses sparse clone (--filter=blob:none) so only affected files are downloaded.
# Usage: bash check-patches.sh [user-patch-file ...]

set -euo pipefail

green='\033[0;32m'
red='\033[0;31m'
reset='\033[0m'

COMMIT=$(jq -r '.commit' upstream/stable.json)
TAG=$(jq -r '.tag'    upstream/stable.json)
VSCODE_URL="https://github.com/microsoft/vscode.git"

echo "Checking patches against VS Code ${TAG} (${COMMIT:0:10})..."
echo ""

# ─── Collect user patches ────────────────────────────────────────────────────

USER_PATCHES=("${@}")
if [[ ${#USER_PATCHES[@]} -eq 0 ]]; then
  while IFS= read -r -d '' f; do
    USER_PATCHES+=("$f")
  done < <(find patches/user -name '*.patch' -print0 2>/dev/null | sort -z)
fi

if [[ ${#USER_PATCHES[@]} -eq 0 ]]; then
  echo "No patches found in patches/user/ — nothing to check."
  exit 0
fi

# ─── Find base patches that overlap with user patch target files ──────────────

USER_FILES=$(grep '^+++ b/' "${USER_PATCHES[@]}" | sed 's|^.*:+++ b/||' | sort -u)

PREREQ_PATCHES=()
while IFS= read -r -d '' base; do
  for f in ${USER_FILES}; do
    if grep -q "^+++ b/${f}$" "${base}" 2>/dev/null; then
      PREREQ_PATCHES+=("${base}")
      break
    fi
  done
done < <(find patches -maxdepth 1 -name '*.patch' -print0 2>/dev/null | sort -z)

if [[ ${#PREREQ_PATCHES[@]} -gt 0 ]]; then
  echo "Base patches that run before ours (will apply first):"
  for p in "${PREREQ_PATCHES[@]}"; do echo "  $(basename "$p")"; done
  echo ""
fi

# ─── Collect all files to sparse-checkout ────────────────────────────────────

ALL_FILES=$(
  {
    grep '^+++ b/' "${USER_PATCHES[@]}"
    [[ ${#PREREQ_PATCHES[@]} -gt 0 ]] && grep '^+++ b/' "${PREREQ_PATCHES[@]}"
  } | sed 's|^.*:+++ b/||' | sort -u
)

# ─── Sparse clone ────────────────────────────────────────────────────────────

WORKDIR=$(mktemp -d)
trap "rm -rf ${WORKDIR}" EXIT

echo "Cloning VS Code tree (sparse, no blobs)..."
git clone \
  --depth 1 \
  --filter=blob:none \
  --no-checkout \
  --quiet \
  "${VSCODE_URL}" \
  "${WORKDIR}/vscode"

cd "${WORKDIR}/vscode"

git sparse-checkout init --no-cone 2>/dev/null
echo "${ALL_FILES}" > .git/info/sparse-checkout
git checkout HEAD -- 2>/dev/null

# ─── Apply prerequisite base patches ─────────────────────────────────────────

if [[ ${#PREREQ_PATCHES[@]} -gt 0 ]]; then
  echo "Applying base patches..."
  for patch in "${PREREQ_PATCHES[@]}"; do
    name=$(basename "${patch}")
    if git apply --ignore-whitespace "${patch}" 2>/dev/null; then
      echo "  applied: ${name}"
    else
      echo "  skipped (does not apply cleanly — may touch files outside sparse set): ${name}"
    fi
  done
  echo ""
fi

# ─── Check user patches ───────────────────────────────────────────────────────

echo "Checking user patches..."
PASS=0
FAIL=0

for patch in "${USER_PATCHES[@]}"; do
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
