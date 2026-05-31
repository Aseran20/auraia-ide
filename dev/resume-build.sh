#!/usr/bin/env bash
# dev/resume-build.sh — finish a build that died in the COMPILE/PACK phase WITHOUT redoing the
# expensive clone + npm ci + patch-apply. Reuses the already-prepared vscode/ tree + node_modules
# and re-runs only the gulp compile + Windows packaging (mirrors build.sh's windows branch).
#
# WHY (2026-05-31): our builds failed at late stages (network reset, PC crash); each forced a full
# cold restart (~25-30 min). If prepare already completed (patches applied, node_modules present),
# only compile + packaging remain — that's minutes, not a restart.
#
# WHEN TO USE: after a failure where the tree was already prepared (you saw patches apply + the
# gulp/compile phase start in build.log). If unsure or it errors, fall back to the warm full path:
#   dev/build-safe.sh -s     # reset → re-apply patches → SKIP npm ci (guard) → compile → pack
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$REPO_ROOT"
die(){ printf '\033[0;31m✗ %s\033[0m\n' "$1" >&2; exit 1; }
ok(){  printf '\033[0;32m✓ %s\033[0m\n' "$1"; }

[[ -d vscode ]]              || die "no vscode/ — nothing to resume. Run: dev/build-safe.sh -s"
[[ -d vscode/node_modules ]]|| die "vscode/node_modules missing — tree not installed. Run: dev/build-safe.sh -s"
[[ -f dev/build.env ]]      || die "dev/build.env missing — run a full build first (it writes the version vars)."

# brand + arch env (mirror dev/build.sh) + saved version vars (mirror build.sh)
export APP_NAME="Arclen" ORG_NAME="Arclen" BINARY_NAME="arclen"
export OS_NAME="windows" VSCODE_ARCH="x64" VSCODE_QUALITY="stable" CI_BUILD="no" SKIP_CLI="yes"
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=8192}" VSCODE_PUBLISH_COUNTER=1
# shellcheck disable=SC1091
. dev/build.env   # MS_TAG, MS_COMMIT, RELEASE_VERSION, BUILD_SOURCEVERSION

printf '\033[1;36m[resume]\033[0m RELEASE_VERSION=%s  NODE_OPTIONS=%s\n' "${RELEASE_VERSION:-?}" "${NODE_OPTIONS}"
echo  "[resume] reusing prepared vscode/ — running gulp compile + Windows packaging only."
echo  "[resume] (if this errors on stale partial state, run: dev/build-safe.sh -s)"

cd vscode || die "cd vscode failed"
rm -rf "../VSCode-win32-${VSCODE_ARCH}" 2>/dev/null || true   # start packaging output clean

npm run gulp vscode-min-prepack || die "vscode-min-prepack failed — fall back to: dev/build-safe.sh -s"
# shellcheck disable=SC1091
. ../build/windows/rtf/make.sh
npm run copy-policy-dto --prefix build
node build/lib/policies/policyGenerator.ts build/lib/policies/policyData.jsonc win32
npm run gulp "vscode-win32-${VSCODE_ARCH}-min-packing" || die "packing failed — fall back to: dev/build-safe.sh -s"
cd ..

ok "resume complete — check VSCode-win32-${VSCODE_ARCH}/${APP_NAME}.exe"
