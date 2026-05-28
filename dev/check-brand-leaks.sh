#!/usr/bin/env bash
# Arclen brand-leak scanner.
# Scans vscode/src/ (or a user-supplied path) for VSCodium / Microsoft / VS Code
# strings that would visibly leak in the running app.
#
# Exit 0 = clean. Exit 1 = leaks found (printed file:line:pattern).
#
# Usage:
#   dev/check-brand-leaks.sh                # scan default paths
#   dev/check-brand-leaks.sh path/to/file   # scan one file
#   dev/check-brand-leaks.sh --strict       # additionally flag low-confidence patterns

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STRICT=0
TARGETS=()

for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    *) TARGETS+=("$arg") ;;
  esac
done

if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=(
    "$REPO_ROOT/vscode/src/vs/workbench"
    "$REPO_ROOT/vscode/src/vs/code"
    "$REPO_ROOT/vscode/src/vs/platform/product"
    "$REPO_ROOT/vscode/product.json"
  )
fi

# HIGH = almost certainly a user-visible leak. Zero tolerance.
HIGH_PATTERNS=(
  'Securing VSCodium'
  'Welcome to VSCodium'
  'raw\.githubusercontent\.com/VSCodium'
  'VSCodium Insider'
  'github\.com/VSCodium'
)

# MEDIUM = often a leak but with legit infra usage (CSP, disabled update endpoints, telemetry shims).
# Flagged separately so high-signal issues don't drown.
MEDIUM_PATTERNS=(
  '\[.*\]\(https://code\.visualstudio\.com'
  'localize\(.*code\.visualstudio\.com'
  '"description".*code\.visualstudio\.com'
  'aka\.ms/[a-zA-Z]'
  'go\.microsoft\.com/fwlink'
  'marketplace\.visualstudio\.com'
)

# STRICT = noisy. Reserve for pre-release audits.
STRICT_PATTERNS=(
  '"VSCodium"'
  "'VSCodium'"
  '"Visual Studio Code"'
  "'Visual Studio Code'"
)

# Lines that legitimately reference these strings — never flag.
WHITELIST_REGEX='Copyright \(c\) Microsoft Corporation|Licensed under the MIT License|vscode-app://|vscode-webview://|vscode-file://|ms-vscode\.|ms-azuretools\.|nls\.localize'

FOUND=0

scan_one() {
  local pattern="$1"
  shift
  for target in "$@"; do
    [ -e "$target" ] || continue
    # rg if available, else grep
    if command -v rg >/dev/null 2>&1; then
      while IFS= read -r line; do
        if ! echo "$line" | grep -qE "$WHITELIST_REGEX"; then
          printf '  %s  [%s]\n' "$line" "$pattern"
          FOUND=1
        fi
      done < <(rg --no-heading -n -e "$pattern" "$target" 2>/dev/null || true)
    else
      while IFS= read -r line; do
        if ! echo "$line" | grep -qE "$WHITELIST_REGEX"; then
          printf '  %s  [%s]\n' "$line" "$pattern"
          FOUND=1
        fi
      done < <(grep -rEn "$pattern" "$target" 2>/dev/null || true)
    fi
  done
}

HIGH_FOUND=0
MEDIUM_FOUND=0

echo "Arclen brand-leak scan (targets: ${#TARGETS[@]})"
echo ""

echo "=== HIGH (must fix) ==="
FOUND=0
for p in "${HIGH_PATTERNS[@]}"; do
  scan_one "$p" "${TARGETS[@]}"
done
HIGH_FOUND=$FOUND

echo ""
echo "=== MEDIUM (review — likely user-visible) ==="
FOUND=0
for p in "${MEDIUM_PATTERNS[@]}"; do
  scan_one "$p" "${TARGETS[@]}"
done
MEDIUM_FOUND=$FOUND

if [ "$STRICT" -eq 1 ]; then
  echo ""
  echo "=== STRICT (pre-release audit) ==="
  for p in "${STRICT_PATTERNS[@]}"; do
    scan_one "$p" "${TARGETS[@]}"
  done
fi

echo ""
if [ "$HIGH_FOUND" -eq 0 ] && [ "$MEDIUM_FOUND" -eq 0 ]; then
  echo "✓ No leaks found."
  exit 0
elif [ "$HIGH_FOUND" -eq 0 ]; then
  echo "⚠ Medium-confidence leaks only. Review and decide."
  exit 0
else
  echo "✗ HIGH-confidence brand leaks detected. Fix before commit."
  exit 1
fi
