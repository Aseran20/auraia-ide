#!/usr/bin/env bash
# check-patches.sh — verify user patches apply against upstream VS Code
# No vscode/ dir needed: downloads only the specific files each patch touches.
# Usage: bash check-patches.sh [patch-file ...]  (defaults to all patches/user/*.patch)

set -euo pipefail

green='\033[0;32m'
red='\033[0;31m'
reset='\033[0m'

COMMIT=$(jq -r '.commit' upstream/stable.json)
TAG=$(jq -r '.tag' upstream/stable.json)
GITHUB_BASE="https://raw.githubusercontent.com/microsoft/vscode/${COMMIT}"

echo "Checking patches against VS Code ${TAG} (${COMMIT:0:10})..."
echo ""

PASS=0
FAIL=0

WORKDIR=$(mktemp -d)
trap "rm -rf ${WORKDIR}" EXIT

check_patch() {
  local patch="$1"
  local name
  name=$(basename "${patch}")

  local pdir="${WORKDIR}/${name}"
  mkdir -p "${pdir}"
  pushd "${pdir}" >/dev/null

  git init -q
  git config user.email "check@local"
  git config user.name "check"

  local files
  files=$(grep '^+++ b/' "${patch}" | sed 's|^+++ b/||')

  if [[ -z "${files}" ]]; then
    echo -e "  ? ${name} — no target files found"
    popd >/dev/null
    return 0
  fi

  local fetch_failed=0
  while IFS= read -r f; do
    mkdir -p "$(dirname "${f}")"
    if ! curl -sf "${GITHUB_BASE}/${f}" -o "${f}"; then
      echo -e "  ${red}✗${reset} ${name} — cannot fetch ${f} from upstream (file moved or deleted)"
      fetch_failed=1
      break
    fi
    git add "${f}"
  done <<< "${files}"

  if [[ "${fetch_failed}" -eq 1 ]]; then
    popd >/dev/null
    return 1
  fi

  git commit -q -m "base"

  if git apply --check --ignore-whitespace "${patch}" 2>/dev/null; then
    echo -e "  ${green}✓${reset} ${name}"
    popd >/dev/null
    return 0
  else
    echo -e "  ${red}✗${reset} ${name} — does not apply:"
    git apply --ignore-whitespace "${patch}" 2>&1 \
      | grep -E '^error:|^patch failed' \
      | head -5 \
      | sed 's/^/    /'
    popd >/dev/null
    return 1
  fi
}

# Collect patches: args or all patches/user/*.patch
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

for patch in "${PATCHES[@]}"; do
  if check_patch "${patch}"; then
    ((PASS++)) || true
  else
    ((FAIL++)) || true
  fi
done

echo ""
echo "Result: ${PASS} passed, ${FAIL} failed"

[[ "${FAIL}" -eq 0 ]]
