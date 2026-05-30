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
yellow='\033[0;33m'
reset='\033[0m'

# We cd into a scratch clone later; capture the invocation dir now so patch paths
# (which are relative to it) survive that cd. Without this, git apply runs from the
# clone and reports "can't open patch 'patches/user/X.patch'" when run from repo root.
START_DIR="$(pwd)"
abspath() { case "$1" in /*) printf '%s\n' "$1" ;; *) printf '%s/%s\n' "${START_DIR}" "$1" ;; esac; }

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

# -h: never prefix matches with the filename. Without it, a SINGLE patch arg yields
# unprefixed lines that the old `s|^.*:+++ b/||` (needs a colon) failed to strip.
USER_FILES=$(grep -h '^+++ b/' "${USER_PATCHES[@]}" | sed 's|^+++ b/||' | sort -u)

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

# ─── Absolutize patch paths (we cd into the clone below) ──────────────────────
for i in "${!USER_PATCHES[@]}";   do USER_PATCHES[$i]="$(abspath "${USER_PATCHES[$i]}")"; done
for i in "${!PREREQ_PATCHES[@]}"; do PREREQ_PATCHES[$i]="$(abspath "${PREREQ_PATCHES[$i]}")"; done

# ─── Conditional-label support (avoid crying wolf on user-patch dependencies) ──
# This script applies BASE patches as prereqs, but NOT prior USER patches. So a user
# patch whose context depends on an earlier user patch (e.g. a comment that patch added)
# legitimately fails --check here even though the real build applies it fine. That's a
# false alarm — dev/gen-user-patch.sh validates such patches authoritatively (it replays
# the full base+windows+prior-user order). We detect the dependency and label it ⚠ rather
# than ✗, and exclude it from the hard-fail exit. (Brand-context mismatches are NOT in this
# bucket — gen-user-patch.sh now placeholder-izes those so they apply here too.)
ALL_USER_SORTED=()
while IFS= read -r -d '' f; do ALL_USER_SORTED+=("$(abspath "$f")"); done \
  < <(find patches/user -name '*.patch' -print0 2>/dev/null | sort -z)

prior_user_dep() {  # $1 = abs patch path → echoes a prior user patch sharing a file, else nothing
  local target="$1" tname tfiles u uname uf
  tname="$(basename "$target")"
  tfiles="$(grep -h '^+++ b/' "$target" | sed 's|^+++ b/||' | sort -u)"
  for u in "${ALL_USER_SORTED[@]}"; do
    uname="$(basename "$u")"
    [[ "$uname" < "$tname" ]] || continue          # only patches that sort BEFORE ours
    while IFS= read -r uf; do
      printf '%s\n' "${tfiles}" | grep -qxF "$uf" && { echo "$uname"; return 0; }
    done < <(grep -h '^+++ b/' "$u" | sed 's|^+++ b/||' | sort -u)
  done
  return 1
}

# ─── Collect all files to sparse-checkout ────────────────────────────────────

ALL_FILES=$(
  {
    grep -h '^+++ b/' "${USER_PATCHES[@]}"
    [[ ${#PREREQ_PATCHES[@]} -gt 0 ]] && grep -h '^+++ b/' "${PREREQ_PATCHES[@]}"
    true   # keep the group's exit 0: an empty PREREQ makes the [[ ]] && grep return 1,
           # which (under pipefail) would poison the pipe and abort via set -e before any
           # check runs — a single patch overlapping no base patch then crashed silently.
  } | sed 's|^+++ b/||' | sort -u
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
COND=0

for patch in "${USER_PATCHES[@]}"; do
  name=$(basename "${patch}")
  if git apply --check --ignore-whitespace "${patch}" 2>/dev/null; then
    echo -e "  ${green}✓${reset} ${name}"
    ((PASS++)) || true
  else
    dep="$(prior_user_dep "${patch}" || true)"
    if [[ -n "${dep}" ]]; then
      echo -e "  ${yellow}⚠${reset} ${name}  (conditional: depends on prior user patch ${dep} — not checkable here; dev/gen-user-patch.sh is authoritative)"
      ((COND++)) || true
    else
      echo -e "  ${red}✗${reset} ${name}:"
      # `|| true`: git apply exits 128 on a corrupt patch / 1 on a clean miss; under
      # set -e + pipefail that aborts the whole script mid-loop (skipping the tally and
      # remaining patches). Keep it non-fatal so we report every failure and exit 1 cleanly.
      git apply --ignore-whitespace "${patch}" 2>&1 \
        | grep -E '^error:|^patch failed' \
        | head -5 \
        | sed 's/^/    /' || true
      ((FAIL++)) || true
    fi
  fi
done

echo ""
if [[ "${COND}" -gt 0 ]]; then
  echo "Result: ${PASS} passed, ${FAIL} failed, ${COND} conditional (user-patch deps — validate with dev/gen-user-patch.sh)"
else
  echo "Result: ${PASS} passed, ${FAIL} failed"
fi
[[ "${FAIL}" -eq 0 ]]
