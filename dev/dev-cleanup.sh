#!/usr/bin/env bash
# dev/dev-cleanup.sh — panic button: kill stray Arclen dev helpers that leak and lag the PC.
#
# WHY THIS EXISTS (retro 2026-05-30):
#   The dev loop spawns helpers that ORPHAN if a run is interrupted or a background task
#   is force-killed. They then linger in the background and lag the whole machine:
#     • tsgo (native type-checker) — the worst offender; 3 strays once held >800 MB and
#       pegged the CPU. Spawned by check-ts.sh / qa-loop.sh.
#     • esbuild                    — transpile helper.
#     • agent-browser chromium     — when agent-browser launches its OWN headless Chrome
#       (temp profile under %TEMP%\agent-browser-chrome-*), the whole tree can survive.
#     • "VSCode Dev" consoles      — code.bat's console; one can survive per relaunch.
#   check-ts.sh and relaunch.sh now self-sweep tsgo, but run THIS anytime the PC feels
#   laggy for a full sweep. It ONLY touches dev junk — never your real Chrome, your
#   editors (Code), or the Claude session.
#
# Usage:
#   dev/dev-cleanup.sh            # sweep helpers, leave the dev app running
#   dev/dev-cleanup.sh --all      # also kill the Arclen dev app itself (Arclen.exe)
set -uo pipefail

KILL_APP=0
[[ "${1:-}" == "--all" ]] && KILL_APP=1
ok()   { printf '\033[0;32m  ✓ %s\033[0m\n' "$1"; }
info() { printf '  %s\n' "$1"; }

echo "[dev-cleanup] sweeping stray dev processes…"

# 1. tsgo + esbuild (Windows images) — MSYS_NO_PATHCONV stops Git Bash mangling /F /IM
for img in tsgo.exe esbuild.exe; do
  MSYS_NO_PATHCONV=1 taskkill /F /IM "$img" >/dev/null 2>&1 && ok "killed stray $img" || true
done

# 2. Leftover "VSCode Dev" consoles (+ child trees)
MSYS_NO_PATHCONV=1 taskkill /F /T /FI "WINDOWTITLE eq VSCode Dev*" >/dev/null 2>&1 \
  && ok "closed leftover dev console(s)" || true

# 3. agent-browser's OWN headless chromium — matched by COMMAND LINE so we never touch
#    the real Chrome. (bash double-quotes keep the PS single-quotes literal; \$ → literal $.)
MSYS2_ARG_CONV_EXCL='*' powershell.exe -NoProfile -Command \
  "\$p = Get-CimInstance Win32_Process | Where-Object { \$_.Name -eq 'chrome.exe' -and \$_.CommandLine -match 'agent-browser-chrome' }; \$n = (\$p | Measure-Object).Count; \$p | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue }; if (\$n) { Write-Host \"  ✓ killed \$n agent-browser chromium proc(s)\" }" 2>/dev/null || true
# their temp profiles
rm -rf "${LOCALAPPDATA:-$HOME/AppData/Local}"/Temp/agent-browser-chrome-* 2>/dev/null \
  && info "removed agent-browser temp profile(s)" || true

# 4. Optional: the dev app itself
if [[ "$KILL_APP" -eq 1 ]]; then
  MSYS_NO_PATHCONV=1 taskkill /F /IM Arclen.exe >/dev/null 2>&1 && ok "killed Arclen.exe (dev app)" || true
fi

echo "[dev-cleanup] done."
