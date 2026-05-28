#!/usr/bin/env bash
# preflight.sh — check all prerequisites before running a build
# Run from repo root: "C:\Program Files\Git\bin\bash.exe" ./preflight.sh
# Exit 0 = all checks passed. Exit 1 = at least one blocker found.

set -euo pipefail

PASS=0
WARN=0
FAIL=0

green='\033[0;32m'
yellow='\033[1;33m'
red='\033[0;31m'
reset='\033[0m'

ok()   { echo -e "  ${green}✓${reset} $1"; ((PASS++)); }
warn() { echo -e "  ${yellow}⚠${reset} $1"; ((WARN++)); }
fail() { echo -e "  ${red}✗${reset} $1"; ((FAIL++)); }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         Arclen IDE — Preflight           ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ─── 1. Node version ────────────────────────────────────────────────────────
echo "── Node / npm / Python ──"

REQUIRED_NODE=$( cat .nvmrc 2>/dev/null | tr -d '[:space:]' )
ACTUAL_NODE=$( node -v 2>/dev/null | tr -d 'v' || echo "NOT_FOUND" )

if [[ "${ACTUAL_NODE}" == "NOT_FOUND" ]]; then
  fail "node not found (required: ${REQUIRED_NODE})"
else
  REQUIRED_MAJOR=$( echo "${REQUIRED_NODE}" | cut -d. -f1 )
  ACTUAL_MAJOR=$( echo "${ACTUAL_NODE}" | cut -d. -f1 )
  if [[ "${ACTUAL_MAJOR}" == "${REQUIRED_MAJOR}" ]]; then
    ok "node ${ACTUAL_NODE} (required major: ${REQUIRED_MAJOR})"
  else
    fail "node ${ACTUAL_NODE} — expected major ${REQUIRED_MAJOR} (from .nvmrc: ${REQUIRED_NODE})"
  fi
fi

# npm must be < 11.2.0
ACTUAL_NPM=$( npm -v 2>/dev/null || echo "NOT_FOUND" )
if [[ "${ACTUAL_NPM}" == "NOT_FOUND" ]]; then
  fail "npm not found"
else
  NPM_MAJOR=$( echo "${ACTUAL_NPM}" | cut -d. -f1 )
  NPM_MINOR=$( echo "${ACTUAL_NPM}" | cut -d. -f2 )
  # fail if >= 11.2
  if [[ "${NPM_MAJOR}" -gt 11 ]] || [[ "${NPM_MAJOR}" -eq 11 && "${NPM_MINOR}" -ge 2 ]]; then
    fail "npm ${ACTUAL_NPM} — VS Code requires npm < 11.2.0 (run: npm install -g npm@11.1.0)"
  else
    ok "npm ${ACTUAL_NPM} (< 11.2.0)"
  fi
fi

# Python must be 3.11.x (node-gyp breaks on 3.12+)
PYTHON_BIN=$( command -v python3 2>/dev/null || command -v python 2>/dev/null || echo "NOT_FOUND" )
if [[ "${PYTHON_BIN}" == "NOT_FOUND" ]]; then
  fail "python not found (node-gyp needs Python 3.11)"
else
  PY_VER=$( "${PYTHON_BIN}" --version 2>&1 | awk '{print $2}' )
  PY_MAJOR=$( echo "${PY_VER}" | cut -d. -f1 )
  PY_MINOR=$( echo "${PY_VER}" | cut -d. -f2 )
  if [[ "${PY_MAJOR}" -eq 3 && "${PY_MINOR}" -eq 11 ]]; then
    ok "python ${PY_VER}"
  elif [[ "${PY_MAJOR}" -eq 3 && "${PY_MINOR}" -ge 12 ]]; then
    fail "python ${PY_VER} — node-gyp may break on 3.12+, use 3.11"
  else
    warn "python ${PY_VER} — expected 3.11.x; may work but untested"
  fi
fi

echo ""

# ─── 2. Required CLI tools ───────────────────────────────────────────────────
echo "── CLI tools ──"

for tool in git jq curl; do
  if command -v "${tool}" &>/dev/null; then
    ok "${tool} $( ${tool} --version 2>&1 | head -1 )"
  else
    fail "${tool} not found"
  fi
done

# Rust/Cargo
if command -v cargo &>/dev/null; then
  ok "cargo $( cargo --version 2>&1 )"
else
  fail "cargo not found (Rust required for native modules)"
fi

# ImageMagick (magick or convert)
if command -v magick &>/dev/null; then
  ok "imagemagick $( magick --version 2>&1 | head -1 )"
elif command -v convert &>/dev/null; then
  ok "imagemagick (convert) $( convert --version 2>&1 | head -1 )"
else
  warn "imagemagick not found — only needed for icon regeneration, not the build"
fi

echo ""

# ─── 3. VS Build Tools (Windows only) ───────────────────────────────────────
if [[ "${OSTYPE}" == "msys"* || "${OSTYPE}" == "cygwin"* ]]; then
  echo "── Windows Build Tools ──"

  # Check for cl.exe (MSVC compiler) via vswhere or PATH
  VSWHERE="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
  if [[ -f "${VSWHERE}" ]]; then
    VS_PATH=$( "${VSWHERE}" -latest -property installationPath 2>/dev/null || echo "" )
    if [[ -n "${VS_PATH}" ]]; then
      ok "Visual Studio found at: ${VS_PATH}"
    else
      fail "Visual Studio not found via vswhere — install VS Build Tools 2022 with C++ workload"
    fi

    # Check Spectre-mitigated libs (v143 x64)
    SPECTRE_PATH="${VS_PATH}/VC/Tools/MSVC"
    if [[ -d "${SPECTRE_PATH}" ]]; then
      SPECTRE_CHECK=$( find "${SPECTRE_PATH}" -name "spectre" -type d 2>/dev/null | head -1 )
      if [[ -n "${SPECTRE_CHECK}" ]]; then
        ok "Spectre-mitigated libs found"
      else
        fail "Spectre-mitigated libs NOT found — install via VS Installer → Individual Components → search 'Spectre' → check MSVC v143 x64"
      fi
    fi
  else
    warn "vswhere not found — cannot verify VS Build Tools (may still work if cl.exe is in PATH)"
    if command -v cl &>/dev/null; then
      ok "cl.exe in PATH"
    else
      fail "cl.exe not in PATH — VS Build Tools 2022 with C++ workload required"
    fi
  fi
  echo ""
fi

# ─── 4. vscode/ source dir ───────────────────────────────────────────────────
echo "── Source state ──"

if [[ -d "vscode" ]]; then
  VSCODE_COMMIT=$( cd vscode && git rev-parse HEAD 2>/dev/null || echo "unknown" )
  EXPECTED_COMMIT=$( jq -r '.commit' upstream/stable.json 2>/dev/null || echo "unknown" )
  if [[ "${VSCODE_COMMIT}" == "${EXPECTED_COMMIT}" ]]; then
    ok "vscode/ at correct commit ${VSCODE_COMMIT:0:10}"
  else
    warn "vscode/ at ${VSCODE_COMMIT:0:10} — upstream/stable.json expects ${EXPECTED_COMMIT:0:10} (run without -s to re-fetch)"
  fi
else
  warn "vscode/ not found — first build will clone VS Code source (~5 min download). Use './dev/build.sh' without -s flag."
fi

echo ""

# ─── 5. Patch applicability ──────────────────────────────────────────────────
echo "── Patches ──"

if [[ ! -d "vscode" ]]; then
  warn "Skipping patch checks — vscode/ not present"
else
  cd vscode

  # Save current state
  git stash --quiet 2>/dev/null || true

  PATCH_FAIL=0

  check_patches() {
    local dir="$1"
    local label="$2"
    if [[ -d "${dir}" ]]; then
      for patch in "${dir}"/*.patch; do
        [[ -f "${patch}" ]] || continue
        name=$( basename "${patch}" )
        result=$( git apply --check "${patch}" 2>&1 )
        if [[ $? -eq 0 ]]; then
          ok "${label}/${name}"
        else
          fail "${label}/${name} — WILL NOT APPLY: $( echo "${result}" | head -1 )"
          ((PATCH_FAIL++))
        fi
      done
    fi
  }

  check_patches "../patches" "patches"
  check_patches "../patches/windows" "patches/windows"
  check_patches "../patches/user" "patches/user"

  # Restore
  git stash pop --quiet 2>/dev/null || true

  cd ..

  if [[ "${PATCH_FAIL}" -eq 0 ]]; then
    ok "All patches apply cleanly"
  fi
fi

echo ""

# ─── 6. product.json validity ────────────────────────────────────────────────
echo "── Config ──"

if jq empty product.json 2>/dev/null; then
  ok "product.json is valid JSON"
else
  fail "product.json — invalid JSON (jq parse failed)"
fi

# Check upstream/stable.json matches what build.sh expects
if [[ -f "upstream/stable.json" ]]; then
  TAG=$( jq -r '.tag' upstream/stable.json 2>/dev/null )
  COMMIT=$( jq -r '.commit' upstream/stable.json 2>/dev/null )
  ok "upstream pinned to VS Code ${TAG} @ ${COMMIT:0:10}"
fi

echo ""

# ─── Summary ─────────────────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════╗"
printf  "║  %-7s %-7s %-7s                  ║\n" \
  "${green}✓ ${PASS} ok${reset}" \
  "${yellow}⚠ ${WARN} warn${reset}" \
  "${red}✗ ${FAIL} fail${reset}"
echo "╚══════════════════════════════════════════╝"
echo ""

if [[ "${FAIL}" -gt 0 ]]; then
  echo -e "${red}Build will likely fail. Fix the issues above first.${reset}"
  exit 1
elif [[ "${WARN}" -gt 0 ]]; then
  echo -e "${yellow}Build may work — review warnings above.${reset}"
  exit 0
else
  echo -e "${green}All checks passed. Safe to build.${reset}"
  exit 0
fi
