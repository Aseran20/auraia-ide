#!/usr/bin/env bash
# ============================================================
# Reads branding.sh and patches all build files accordingly.
# Run from repo root: bash apply_branding.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/branding.sh"

echo "Applying branding: ${BRAND_APP_NAME} (${BRAND_BINARY_NAME})"

# ---- 1. dev/build.sh ----
sed -i \
  -e "s|^export APP_NAME=.*|export APP_NAME=\"${BRAND_APP_NAME}\"|" \
  -e "s|^export ASSETS_REPOSITORY=.*|export ASSETS_REPOSITORY=\"${BRAND_GH_REPO}\"|" \
  -e "s|^export BINARY_NAME=.*|export BINARY_NAME=\"${BRAND_BINARY_NAME}\"|" \
  -e "s|^export GH_REPO_PATH=.*|export GH_REPO_PATH=\"${BRAND_GH_REPO}\"|" \
  -e "s|^export ORG_NAME=.*|export ORG_NAME=\"${BRAND_ORG_NAME}\"|" \
  dev/build.sh

echo "  [OK] dev/build.sh"

# ---- 2. prepare_vscode.sh (stable block) ----
# We use a targeted sed approach: match the exact setpath lines and replace values

apply_setpath() {
  local field="$1" value="$2"
  sed -i "s|setpath \"product\" \"${field}\" \"[^\"]*\"|setpath \"product\" \"${field}\" \"${value}\"|" prepare_vscode.sh
}

apply_setpath "nameShort"              "${BRAND_APP_NAME}"
apply_setpath "nameLong"               "${BRAND_APP_NAME}"
apply_setpath "applicationName"        "${BRAND_BINARY_NAME}"
apply_setpath "dataFolderName"         "${BRAND_DATA_FOLDER}"
apply_setpath "linuxIconName"          "${BRAND_BINARY_NAME}"
apply_setpath "urlProtocol"            "${BRAND_URL_PROTOCOL}"
apply_setpath "serverApplicationName"  "${BRAND_BINARY_NAME}-server"
apply_setpath "serverDataFolderName"   "${BRAND_DATA_FOLDER}-server"
apply_setpath "darwinBundleIdentifier" "com.${BRAND_BINARY_NAME}"
apply_setpath "win32AppUserModelId"    "${BRAND_APP_NAME}.${BRAND_APP_NAME}"
apply_setpath "win32DirName"           "${BRAND_APP_NAME}"
apply_setpath "win32MutexName"         "${BRAND_BINARY_NAME}"
apply_setpath "win32NameVersion"       "${BRAND_APP_NAME}"
apply_setpath "win32RegValueName"      "${BRAND_APP_NAME}"
apply_setpath "win32ShellNameShort"    "${BRAND_APP_NAME}"
apply_setpath "tunnelApplicationName"  "${BRAND_BINARY_NAME}-tunnel"
apply_setpath "win32TunnelServiceMutex" "${BRAND_BINARY_NAME}-tunnelservice"
apply_setpath "win32TunnelMutex"       "${BRAND_BINARY_NAME}-tunnel"

apply_setpath "licenseUrl"    "${BRAND_LICENSE_URL}"
apply_setpath "reportIssueUrl" "${BRAND_ISSUES_URL}"
apply_setpath "downloadUrl"   "${BRAND_DOWNLOAD_URL}"

echo "  [OK] prepare_vscode.sh"

# ---- 3. CI workflow ----
CI_FILE=".github/workflows/ci-build-windows.yml"
if [[ -f "${CI_FILE}" ]]; then
  sed -i "s|APP_NAME:.*|APP_NAME: ${BRAND_APP_NAME}|" "${CI_FILE}"
  # BINARY_NAME in CI uses a ternary expression — replace both old names
  sed -i "s|codium-insiders|${BRAND_BINARY_NAME}-insiders|g; s|'codium'|'${BRAND_BINARY_NAME}'|g" "${CI_FILE}"
  echo "  [OK] ${CI_FILE}"
fi

echo ""
echo "Done. All branding set to: ${BRAND_APP_NAME}"
echo "Next: commit and build (local or CI)"
