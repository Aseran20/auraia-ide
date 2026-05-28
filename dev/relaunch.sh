#!/usr/bin/env bash
# dev/relaunch.sh — full relaunch of the Arclen dev build, with a readiness GATE.
#
# WHY THIS EXISTS (retro 2026-05-28):
#   • CSS / theme / product.json changes do NOT hot-reload on Ctrl+R — the injected
#     <style> and document.fonts persist across the soft reload, so you see stale
#     values. Those changes need a FULL relaunch (kill the exe + run code.bat).
#   • The dev extension host is ~5 min slow here, and the workbench paints in stages.
#     Screenshotting right after launch catches a blank / half-painted window, which
#     made past sessions take 5 blind screenshots chasing a theme that hadn't applied.
#   This script kills the running dev exe, relaunches it with CDP + VSCODE_SKIP_PRELAUNCH,
#   then BLOCKS until the workbench is actually painted (theme variables resolved) before
#   returning — so the next screenshot/assert is never blind. The readiness signal is
#   `--vscode-editor-background` resolving on `.monaco-workbench` (set the moment the
#   theme applies, well before the slow ext host finishes).
#
# Usage:
#   dev/relaunch.sh                                  # kill + relaunch + wait until ready
#   dev/relaunch.sh --shot dev/check.png             # ... then screenshot once ready
#   dev/relaunch.sh --assert '--vscode-editor-background=#09090b'   # ... assert a theme value
#   dev/relaunch.sh --probe-only                     # DON'T kill/launch; just gate an existing window
#   dev/relaunch.sh --no-kill                        # launch without killing first
# Options:
#   --port N        CDP port (default 9222)
#   --timeout SEC   max wait for readiness (default 150 — workbench paints in ~15-40s)
#
# Exit codes: 0 ready (and assert passed) | 2 not ready before timeout | 3 assert failed

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXE_IMAGE="Arclen.exe"          # = <nameShort>.exe that code.bat derives from product.json
PORT=9222
TIMEOUT=150
SHOT=""
ASSERT=""
DO_KILL=1
DO_LAUNCH=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --probe-only) DO_KILL=0; DO_LAUNCH=0 ;;
    --no-kill)    DO_KILL=0 ;;
    --shot)       SHOT="$2"; shift ;;
    --assert)     ASSERT="$2"; shift ;;
    --port)       PORT="$2"; shift ;;
    --timeout)    TIMEOUT="$2"; shift ;;
    --shot=*)     SHOT="${1#*=}" ;;
    --assert=*)   ASSERT="${1#*=}" ;;
    --port=*)     PORT="${1#*=}" ;;
    --timeout=*)  TIMEOUT="${1#*=}" ;;
    *) echo "unknown arg: $1" >&2; exit 64 ;;
  esac
  shift
done

step() { printf '\n\033[1;36m[relaunch]\033[0m %s\n' "$1"; }
ok()   { printf '\033[0;32m  ✓ %s\033[0m\n' "$1"; }
die()  { printf '\033[0;31m  ✗ %s\033[0m\n' "$1" >&2; exit "${2:-1}"; }

# ─── 1. Kill the running dev exe ──────────────────────────────────────────────
if [[ "$DO_KILL" -eq 1 ]]; then
  step "Killing ${EXE_IMAGE}"
  MSYS_NO_PATHCONV=1 taskkill /F /IM "${EXE_IMAGE}" >/dev/null 2>&1 \
    && ok "killed" || ok "not running (nothing to kill)"
  # Give the OS a moment to release the CDP port before relaunch.
  sleep 1
fi

# ─── 2. Relaunch via code.bat (detached), CDP + skip-prelaunch ────────────────
if [[ "$DO_LAUNCH" -eq 1 ]]; then
  step "Launching scripts/code.bat (port ${PORT}, VSCODE_SKIP_PRELAUNCH=1)"
  WIN_VSCODE="$(cygpath -w "${REPO_ROOT}/vscode")"
  # Generating a tiny .bat and `start`-ing it avoids the nested-quote hell of
  # `cmd /c start ... cmd /c "set X=1&& code.bat"` (the `&&` gets parsed by the wrong
  # cmd when Git Bash reconstructs the command line → app never launches).
  LAUNCHER="${REPO_ROOT}/dev/.relaunch-launcher.bat"
  {
    printf '@echo off\r\n'
    printf 'set VSCODE_SKIP_PRELAUNCH=1\r\n'
    printf 'cd /d "%s"\r\n' "${WIN_VSCODE}"
    printf 'call scripts\\code.bat --remote-debugging-port=%s\r\n' "${PORT}"
  } > "${LAUNCHER}"
  # start "" <bat> opens a detached console so the app survives after this script exits.
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
    cmd.exe /c start "" "$(cygpath -w "${LAUNCHER}")" >/dev/null 2>&1
  ok "launch issued"
fi

# ─── 3. Readiness gate — block until the workbench paints (theme resolved) ─────
step "Waiting for workbench (theme applied) on CDP ${PORT}, up to ${TIMEOUT}s"
PROBE_JS='(()=>{const wb=document.querySelector(".monaco-workbench");if(!wb)return "NO_WORKBENCH";const bg=getComputedStyle(wb).getPropertyValue("--vscode-editor-background").trim();return bg?("READY "+bg):"NO_THEME";})()'

deadline=$(( SECONDS + TIMEOUT ))
state="(no connection)"
bg=""
while (( SECONDS < deadline )); do
  if agent-browser connect "${PORT}" >/dev/null 2>&1; then
    out="$(agent-browser eval "${PROBE_JS}" 2>/dev/null | tr -d '"')"
    state="${out:-（empty）}"
    if [[ "${out}" == READY* ]]; then
      bg="${out#READY }"
      ok "ready — --vscode-editor-background = ${bg}"
      break
    fi
  fi
  printf '  … %-14s (%ds elapsed)\r' "${state}" "$(( SECONDS - (deadline - TIMEOUT) ))"
  sleep 2
done

if [[ -z "${bg}" ]]; then
  die "workbench not ready after ${TIMEOUT}s (last state: ${state})" 2
fi

# ─── 4. Optional assert on a computed theme/font variable ─────────────────────
if [[ -n "${ASSERT}" ]]; then
  var="${ASSERT%%=*}"
  want="${ASSERT#*=}"
  got="$(agent-browser eval "getComputedStyle(document.querySelector('.monaco-workbench')).getPropertyValue('${var}').trim()" 2>/dev/null | tr -d '"')"
  if [[ "${got}" == *"${want}"* ]]; then
    ok "assert OK: ${var} = ${got}"
  else
    die "assert FAIL: ${var} = '${got}' (wanted to contain '${want}')" 3
  fi
fi

# ─── 5. Optional screenshot (now that it's genuinely painted) ─────────────────
if [[ -n "${SHOT}" ]]; then
  step "Screenshot → ${SHOT}"
  agent-browser screenshot "${SHOT}" >/dev/null 2>&1 && ok "saved ${SHOT}" || die "screenshot failed"
fi

printf '\n\033[1;32m✓ relaunch ready\033[0m\n'
