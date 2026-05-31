#!/usr/bin/env bash
# shellcheck disable=SC1091,2154

set -e

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  cp -rp src/insider/* vscode/
else
  cp -rp src/stable/* vscode/
fi

cp -f LICENSE vscode/LICENSE.txt

cd vscode || { echo "'vscode' dir not found"; exit 1; }

# rm -rf extensions/copilot

# Arclen — built-in extension trimming is DEFERRED (see TODO/TODO.md "built-ins").
# Built-ins use TypeScript project references between each other, so `rm -rf extensions/<x>`
# breaks any dependent extension's compile (TS5058) — verified: emmet AND github-authentication
# are both referenced. Clean removal needs untangling the reference graph (remove dependents /
# drop the `references` entries), not just deleting dirs. The activation errors these throw in the
# DEV tree do NOT ship (gulp compiles all built-ins at packaging). Leaving all built-ins bundled.

{ set +x; } 2>/dev/null

# {{{ product.json
cp product.json{,.bak}

setpath() {
  local jsonTmp
  { set +x; } 2>/dev/null
  jsonTmp=$( jq --arg 'value' "${3}" "setpath(path(.${2}); \$value)" "${1}.json" )
  echo "${jsonTmp}" > "${1}.json"
  set -x
}

setpath_json() {
  local jsonTmp
  { set +x; } 2>/dev/null
  jsonTmp=$( jq --argjson 'value' "${3}" "setpath(path(.${2}); \$value)" "${1}.json" )
  echo "${jsonTmp}" > "${1}.json"
  set -x
}

setpath "product" "checksumFailMoreInfoUrl" "https://go.microsoft.com/fwlink/?LinkId=828886"
setpath "product" "documentationUrl" "https://go.microsoft.com/fwlink/?LinkID=533484#vscode"
# Arclen: marketplace LOCKED — no extensionsGallery. M&A analysts get a curated, pre-installed
# extension set (incl. Claude Code); they cannot browse/install arbitrary extensions, and the
# Extensions icon is already hidden (patches/user/arclen-clean-activity-bar.patch). Bundled
# extensions still load (they don't need a gallery). To re-enable, restore the setpath_json below.
# NOTE: not touched by apply_branding.sh (it only rewrites single-value `setpath` lines).
# setpath_json "product" "extensionsGallery" '{"serviceUrl": "https://open-vsx.org/vscode/gallery", "itemUrl": "https://open-vsx.org/vscode/item", "latestUrlTemplate": "https://open-vsx.org/vscode/gallery/{publisher}/{name}/latest", "controlUrl": "https://raw.githubusercontent.com/EclipseFdn/publish-extensions/refs/heads/master/extension-control/extensions.json"}'

setpath "product" "introductoryVideosUrl" "https://go.microsoft.com/fwlink/?linkid=832146"
setpath "product" "keyboardShortcutsUrlLinux" "https://go.microsoft.com/fwlink/?linkid=832144"
setpath "product" "keyboardShortcutsUrlMac" "https://go.microsoft.com/fwlink/?linkid=832143"
setpath "product" "keyboardShortcutsUrlWin" "https://go.microsoft.com/fwlink/?linkid=832145"
setpath "product" "licenseUrl" "https://github.com/Aseran20/auraia-ide/blob/master/LICENSE"
setpath_json "product" "linkProtectionTrustedDomains" '["https://open-vsx.org"]'
setpath "product" "releaseNotesUrl" "https://go.microsoft.com/fwlink/?LinkID=533483#vscode"
setpath "product" "reportIssueUrl" "https://github.com/Aseran20/auraia-ide/issues/new"
setpath "product" "requestFeatureUrl" "https://go.microsoft.com/fwlink/?LinkID=533482"
setpath "product" "tipsAndTricksUrl" "https://go.microsoft.com/fwlink/?linkid=852118"
setpath "product" "twitterUrl" "https://go.microsoft.com/fwlink/?LinkID=533687"

if [[ "${DISABLE_UPDATE}" != "yes" ]]; then
  setpath "product" "updateUrl" ""

  if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
    setpath "product" "downloadUrl" "https://github.com/Aseran20/auraia-ide/releases"
  else
    setpath "product" "downloadUrl" "https://github.com/Aseran20/auraia-ide/releases"
  fi

  # if [[ "${OS_NAME}" == "windows" ]]; then
  #   setpath_json "product" "win32VersionedUpdate" "true"
  # fi
fi

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  setpath "product" "nameShort" "Arclen"
  setpath "product" "nameLong" "Arclen"
  setpath "product" "applicationName" "arclen"
  setpath "product" "dataFolderName" ".arclen"
  setpath "product" "linuxIconName" "arclen"
  setpath "product" "quality" "insider"
  setpath "product" "urlProtocol" "arclen"
  setpath "product" "serverApplicationName" "arclen-server"
  setpath "product" "serverDataFolderName" ".arclen-server"
  setpath "product" "darwinBundleIdentifier" "com.arclen"
  setpath "product" "win32AppUserModelId" "Arclen.Arclen"
  setpath "product" "win32DirName" "Arclen"
  setpath "product" "win32MutexName" "arclen"
  setpath "product" "win32NameVersion" "Arclen"
  setpath "product" "win32RegValueName" "Arclen"
  setpath "product" "win32ShellNameShort" "Arclen"
  setpath "product" "win32AppId" "{{EF35BB36-FA7E-4BB9-B7DA-D1E09F2DA9C9}"
  setpath "product" "win32x64AppId" "{{B2E0DDB2-120E-4D34-9F7E-8C688FF839A2}"
  setpath "product" "win32arm64AppId" "{{44721278-64C6-4513-BC45-D48E07830599}"
  setpath "product" "win32UserAppId" "{{ED2E5618-3E7E-4888-BF3C-A6CCC84F586F}"
  setpath "product" "win32x64UserAppId" "{{20F79D0D-A9AC-4220-9A81-CE675FFB6B41}"
  setpath "product" "win32arm64UserAppId" "{{2E362F92-14EA-455A-9ABD-3E656BBBFE71}"
  setpath "product" "tunnelApplicationName" "arclen-tunnel"
  setpath "product" "win32TunnelServiceMutex" "arclen-tunnelservice"
  setpath "product" "win32TunnelMutex" "arclen-tunnel"
  setpath "product" "win32ContextMenu.x64.clsid" "90AAD229-85FD-43A3-B82D-8598A88829CF"
  setpath "product" "win32ContextMenu.arm64.clsid" "7544C31C-BDBF-4DDF-B15E-F73A46D6723D"
else
  setpath "product" "nameShort" "Arclen"
  setpath "product" "nameLong" "Arclen"
  setpath "product" "applicationName" "arclen"
  setpath "product" "dataFolderName" ".arclen"
  setpath "product" "linuxIconName" "arclen"
  setpath "product" "quality" "stable"
  setpath "product" "urlProtocol" "arclen"
  setpath "product" "serverApplicationName" "arclen-server"
  setpath "product" "serverDataFolderName" ".arclen-server"
  setpath "product" "darwinBundleIdentifier" "com.arclen"
  setpath "product" "win32AppUserModelId" "Arclen.Arclen"
  setpath "product" "win32DirName" "Arclen"
  setpath "product" "win32MutexName" "arclen"
  setpath "product" "win32NameVersion" "Arclen"
  setpath "product" "win32RegValueName" "Arclen"
  setpath "product" "win32ShellNameShort" "Arclen"
  setpath "product" "win32AppId" "{{04CF44D6-4864-4A38-AE1F-9D6B713C58BC}"
  setpath "product" "win32x64AppId" "{{C960DD98-6BDF-4B58-9F63-F4F6D89C55D8}"
  setpath "product" "win32arm64AppId" "{{71BA525D-861B-440C-92F3-D569455F4D48}"
  setpath "product" "win32UserAppId" "{{60241EC3-BC44-46CE-B298-D04C1071A4D4}"
  setpath "product" "win32x64UserAppId" "{{619CBB99-7951-40D1-B03D-DA242AB30A20}"
  setpath "product" "win32arm64UserAppId" "{{8CA8E90B-5623-44E8-8B7E-6B9870E51D86}"
  setpath "product" "tunnelApplicationName" "arclen-tunnel"
  setpath "product" "win32TunnelServiceMutex" "arclen-tunnelservice"
  setpath "product" "win32TunnelMutex" "arclen-tunnel"
  setpath "product" "win32ContextMenu.x64.clsid" "D910D5E6-B277-4F4A-BDC5-759A34EEE25D"
  setpath "product" "win32ContextMenu.arm64.clsid" "4852FC55-4A84-4EA1-9C86-D53BE3DF83C0"
fi

setpath_json "product" "tunnelApplicationConfig" '{}'

jsonTmp=$( jq -s '.[0] * .[1]' product.json ../product.json )
echo "${jsonTmp}" > product.json && unset jsonTmp

# ─── Arclen: bundle the official Claude Code extension (cockpit core) ──────────
# `builtInExtensions` supports a LOCAL `vsix` (build/lib/builtInExtensions.ts →
# ext.fromVsix), so we ship the GENUINE, UNMODIFIED Anthropic VSIX with no gallery
# (marketplace is locked) and no network at extension-sync time. Per-user own-account
# auth — see memory `claude-ext-bundling-decision`. fromVsix verifies the sha256, so a
# tampered/wrong download fails the build loudly. We APPEND (jq `+=`) so the MS built-ins
# (js-debug, …) survive — jq's `*` merge above REPLACES arrays, so this must run after it.
# To bump: update version+sha256 (sha256 = `sha256sum` of the win32-x64 .vsix from Open VSX).
ARCLEN_CC_VERSION="2.1.157"
ARCLEN_CC_SHA256="d210b783ca432bb91f7bcd28d9e03c4ec49b0c19c5bcea3fc2d1ced18bdc0e15"
ARCLEN_CC_VSIX="arclen-vendor/claude-code.vsix"   # relative to vscode/ (= build root)
ARCLEN_CC_URL="https://open-vsx.org/api/Anthropic/claude-code/win32-x64/${ARCLEN_CC_VERSION}/file/Anthropic.claude-code-${ARCLEN_CC_VERSION}@win32-x64.vsix"

mkdir -p "$( dirname "${ARCLEN_CC_VSIX}" )"
if [[ ! -f "${ARCLEN_CC_VSIX}" ]] || ! echo "${ARCLEN_CC_SHA256}  ${ARCLEN_CC_VSIX}" | sha256sum -c - >/dev/null 2>&1 ; then
  echo "Arclen: fetching Claude Code ${ARCLEN_CC_VERSION} (win32-x64) from Open VSX..."
  curl -fSL --retry 3 -o "${ARCLEN_CC_VSIX}" "${ARCLEN_CC_URL}"
  echo "${ARCLEN_CC_SHA256}  ${ARCLEN_CC_VSIX}" | sha256sum -c - \
    || { echo "Arclen: Claude Code VSIX sha256 mismatch — aborting"; exit 1; }
fi

jsonTmp=$( jq --arg v "${ARCLEN_CC_VERSION}" --arg s "${ARCLEN_CC_SHA256}" --arg x "${ARCLEN_CC_VSIX}" '
  .builtInExtensions += [{
    name: "anthropic.claude-code",
    version: $v,
    sha256: $s,
    vsix: $x,
    repo: "https://open-vsx.org/extension/Anthropic/claude-code",
    platforms: ["win32"],
    metadata: {
      id: "anthropic.claude-code",
      publisherId: { publisherId: "anthropic", publisherName: "Anthropic", displayName: "Anthropic", flags: "" },
      publisherDisplayName: "Anthropic"
    }
  }]' product.json )
echo "${jsonTmp}" > product.json && unset jsonTmp

cat product.json
# }}}

# include common functions
. ../utils.sh

# {{{ apply patches

echo "APP_NAME=\"${APP_NAME}\""
echo "APP_NAME_LC=\"${APP_NAME_LC}\""
echo "ASSETS_REPOSITORY=\"${ASSETS_REPOSITORY}\""
echo "BINARY_NAME=\"${BINARY_NAME}\""
echo "GH_REPO_PATH=\"${GH_REPO_PATH}\""
echo "GLOBAL_DIRNAME=\"${GLOBAL_DIRNAME}\""
echo "ORG_NAME=\"${ORG_NAME}\""
echo "TUNNEL_APP_NAME=\"${TUNNEL_APP_NAME}\""

if [[ "${DISABLE_UPDATE}" == "yes" ]]; then
  mv ../patches/00-update-disable.patch.yet ../patches/00-update-disable.patch
fi

for file in ../patches/*.json; do
  if [[ -f "${file}" ]]; then
    apply_actions "${file}"
  fi
done

for file in ../patches/*.patch; do
  if [[ -f "${file}" ]]; then
    apply_patch "${file}"
  fi
done

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  for file in ../patches/insider/*.patch; do
    if [[ -f "${file}" ]]; then
      apply_patch "${file}"
    fi
  done
fi

if [[ -d "../patches/${OS_NAME}/" ]]; then
  for file in "../patches/${OS_NAME}/"*.patch; do
    if [[ -f "${file}" ]]; then
      apply_patch "${file}"
    fi
  done
fi

for file in ../patches/user/*.patch; do
  if [[ -f "${file}" ]]; then
    apply_patch "${file}"
  fi
done
# }}}

set -x

# {{{ install dependencies
export ELECTRON_SKIP_BINARY_DOWNLOAD=1
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

if [[ "${OS_NAME}" == "linux" ]]; then
  export VSCODE_SKIP_NODE_VERSION_CHECK=1

   if [[ "${npm_config_arch}" == "arm" ]]; then
    export npm_config_arm_version=7
  fi
elif [[ "${OS_NAME}" == "windows" ]]; then
  if [[ "${npm_config_arch}" == "arm" ]]; then
    export npm_config_arm_version=7
  fi
else
  if [[ "${CI_BUILD}" != "no" ]]; then
    clang++ --version
  fi
fi

node build/npm/preinstall.ts

# ── Arclen warm-build guard: skip the heavy `npm ci` (clean reinstall + native rebuilds —
#    the per-extension storm that can OOM/crash the machine, and the slowest single phase) when
#    node_modules ALREADY matches this package-lock. Our patches never touch package-lock.json,
#    so iterative .exe rebuilds reuse node_modules → compile+pack only. Force a clean reinstall
#    with FORCE_NPM_CI=1 or by deleting vscode/node_modules. The stamp lives INSIDE node_modules
#    so it dies with it (a cold build that rm -rf's vscode/ re-installs + re-stamps).
#    NOTE: apply_branding.sh only seds the `setpath "product"` lines of this file, so this guard
#    block is safe from the brand propagator. ──
ARCLEN_NPM_STAMP="node_modules/.arclen-npm-ci.sha"
ARCLEN_LOCK_SHA="$( sha256sum package-lock.json 2>/dev/null | cut -d' ' -f1 )"
if [[ "${FORCE_NPM_CI:-0}" != "1" && -n "${ARCLEN_LOCK_SHA}" && -d node_modules && -f "${ARCLEN_NPM_STAMP}" && "$( cat "${ARCLEN_NPM_STAMP}" 2>/dev/null )" == "${ARCLEN_LOCK_SHA}" ]]; then
  echo "Arclen: node_modules already matches package-lock — skipping npm ci (warm build). FORCE_NPM_CI=1 to override."
else
  mv .npmrc .npmrc.bak
  cp ../npmrc .npmrc

  for i in {1..5}; do # try 5 times
    if [[ "${CI_BUILD}" != "no" && "${OS_NAME}" == "osx" ]]; then
      CXX=clang++ npm ci && break
    else
      npm ci && break
    fi

    if [[ $i == 5 ]]; then
      echo "Npm install failed too many times" >&2
      exit 1
    fi
    echo "Npm install failed $i, trying again..."

    sleep $(( 15 * (i + 1)))
  done

  mv .npmrc.bak .npmrc
  echo "${ARCLEN_LOCK_SHA}" > "${ARCLEN_NPM_STAMP}"
fi
# }}}

# package.json
cp package.json{,.bak}

setpath "package" "version" "${RELEASE_VERSION%-insider}"

replace 's|Microsoft Corporation|VSCodium|' package.json

cp resources/server/manifest.json{,.bak}

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  setpath "resources/server/manifest" "name" "VSCodium - Insiders"
  setpath "resources/server/manifest" "short_name" "VSCodium - Insiders"
else
  setpath "resources/server/manifest" "name" "VSCodium"
  setpath "resources/server/manifest" "short_name" "VSCodium"
fi

# announcements
replace "s|\\[\\/\\* BUILTIN_ANNOUNCEMENTS \\*\\/\\]|$( tr -d '\n' < ../announcements-builtin.json )|" src/vs/workbench/contrib/welcomeGettingStarted/browser/gettingStarted.ts

../undo_telemetry.sh

replace 's|Microsoft Corporation|VSCodium|' build/lib/electron.ts
replace 's|([0-9]) Microsoft|\1 VSCodium|' build/lib/electron.ts

if [[ "${OS_NAME}" == "linux" ]]; then
  # microsoft adds their apt repo to sources
  # unless the app name is code-oss
  # as we are renaming the application to vscodium
  # we need to edit a line in the post install template
  if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
    sed -i "s/code-oss/codium-insiders/" resources/linux/debian/postinst.template
  else
    sed -i "s/code-oss/codium/" resources/linux/debian/postinst.template
  fi

  # fix the packages metadata
  # code.appdata.xml
  sed -i 's|Visual Studio Code|VSCodium|g' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://github.com/VSCodium/vscodium#download-install|' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com/home/home-screenshot-linux-lg.png|https://vscodium.com/img/vscodium.png|' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com|https://vscodium.com|' resources/linux/code.appdata.xml

  # control.template
  sed -i 's|Microsoft Corporation <vscode-linux@microsoft.com>|VSCodium Team https://github.com/VSCodium/vscodium/graphs/contributors|'  resources/linux/debian/control.template
  sed -i 's|Visual Studio Code|VSCodium|g' resources/linux/debian/control.template
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://github.com/VSCodium/vscodium#download-install|' resources/linux/debian/control.template
  sed -i 's|https://code.visualstudio.com|https://vscodium.com|' resources/linux/debian/control.template

  # code.spec.template
  sed -i 's|Microsoft Corporation|VSCodium Team|' resources/linux/rpm/code.spec.template
  sed -i 's|Visual Studio Code Team <vscode-linux@microsoft.com>|VSCodium Team https://github.com/VSCodium/vscodium/graphs/contributors|' resources/linux/rpm/code.spec.template
  sed -i 's|Visual Studio Code|VSCodium|' resources/linux/rpm/code.spec.template
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://github.com/VSCodium/vscodium#download-install|' resources/linux/rpm/code.spec.template
  sed -i 's|https://code.visualstudio.com|https://vscodium.com|' resources/linux/rpm/code.spec.template

  # snapcraft.yaml
  sed -i 's|Visual Studio Code|VSCodium|' resources/linux/rpm/code.spec.template
elif [[ "${OS_NAME}" == "windows" ]]; then
  # code.iss
  sed -i 's|https://code.visualstudio.com|https://vscodium.com|' build/win32/code.iss
  sed -i 's|Microsoft Corporation|VSCodium|' build/win32/code.iss
fi

cd ..
