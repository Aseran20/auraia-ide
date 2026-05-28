#!/usr/bin/env bash
# SessionStart hook for Arclen IDE repo.
# Injects critical context so Claude doesn't repeat past mistakes.
# Triggered automatically by CC when a session starts in this project.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
VSCODE_EXISTS="no"
EXE_EXISTS="no"
[ -d "${PROJECT_DIR}/vscode" ] && VSCODE_EXISTS="yes"
[ -f "${PROJECT_DIR}/VSCode-win32-x64/Arclen.exe" ] && EXE_EXISTS="yes"

OUT_HAS_MAIN="no"
[ -f "${PROJECT_DIR}/vscode/out/main.js" ] && OUT_HAS_MAIN="yes"

if [ "$VSCODE_EXISTS" = "yes" ]; then
  if [ "$OUT_HAS_MAIN" = "yes" ]; then
    NEXT_STEP='vscode/ exists AND out/main.js present -> ITERATION LOOP: edit vscode/src/... -> cd vscode && node build/next/index.ts transpile (~10s) -> agent-browser press Ctrl+R -> agent-browser connect 9222 (reconnect, Ctrl+R drops CDP briefly) -> agent-browser screenshot. NPM RUN WATCH IS A NO-OP HERE for emit (useEsbuildTranspile=false in this build); it only type-checks. Do not rely on it to refresh out/. Do NOT run dev/build.sh just to test a change.'
  else
    NEXT_STEP='vscode/ exists BUT out/main.js is MISSING -> dev/build.sh only produced out-vscode-min/ (distrib bundle), not out/ (dev sources). Before launching scripts/code.bat: cd vscode && node build/next/index.ts transpile (~10s, populates out/). Then iteration loop = edit + transpile + Ctrl+R via agent-browser. npm run watch is NOT needed for emit (useEsbuildTranspile=false).'
  fi
else
  NEXT_STEP='vscode/ does NOT exist -> first build required: ./dev/build.sh (~30-40 min). Launch via PowerShell run_in_background:true with tee build.log. Never via Bash tool for Windows paths.'
fi

MESSAGE=$(cat <<EOF
ARCLEN IDE - Auto-Orientation (SessionStart hook)

Repo: VSCodium fork rebranded for M&A analysts. VS Code 1.121.0 upstream.

VALIDATED WINDOWS TOOLCHAIN (do NOT deviate):
- VS 2022 Community + MSVC v143 + Spectre v143 x64. NOT VS 2026 (node-gyp can't detect it; we documented why).
- Stock npm-bundled node-gyp 11.5. If %ProgramFiles%\nodejs\...\node-gyp_11.5.0_bak exists, restore it before building.
- Use your user-level Git Bash (e.g. C:\Users\<you>\AppData\Local\Programs\Git\bin\bash.exe). Run 'which bash' to confirm the path on this machine.
- Python 3.13 works fine (node-gyp 10+).

BUILD STATE:
- vscode/ present: ${VSCODE_EXISTS}
- VSCode-win32-x64/Arclen.exe present: ${EXE_EXISTS}

NEXT STEP: ${NEXT_STEP}

GOLDEN RULES:
1. LOCAL ONLY. CI (ci-build-windows.yml) is 60 min - only for distribution, never for iteration.
2. SKIP_CLI=yes is set in dev/build.sh - the Rust CLI (code-tunnels, Remote-SSH) is irrelevant for Arclen. Do not install rustup.
3. After a compile error, DO NOT re-run dev/build.sh. Edit the file in vscode/ AND the corresponding patches/user/*.patch, then resume with: cd vscode && npm run gulp vscode-min-prepack.
4. When a user patch removes the only usage of an imported symbol, the import must be removed in the same patch (VS Code tsconfig has noUnusedLocals: true). check-patches.sh does NOT catch this - only a full compile does.
5. dev/ vs distrib: scripts/code.bat = dev runner. Arclen.exe = packaged distributable. Daily dev = .bat with --remote-debugging-port=9222 + agent-browser, 99% of the time.
6. Generating user patches: vscode/ git baseline is pristine upstream, so cd vscode && git diff returns BASE PATCHES + USER PATCHES + YOUR EDITS combined - NOT a clean user patch. Prefer renaming base patches to .disabled when killing a community feature; only hand-write user patches when keeping the base patch but tweaking it.
7. CRLF gotcha: some vscode/src files have mixed line endings. If Edit returns "String not found" on a string visible in Read, diagnose with: sed -n Np file | cat -A. Fallback = Python regex via Bash with rb'...' patterns.

REFERENCE (WHAT/WHERE): .claude/skills/arclen-ide/SKILL.md  (repo structure, branding, icons, build prerequisites, modifying packaged output).
RUNBOOK (HOW to iterate): .claude/skills/arclen-dev/SKILL.md  (the real edit->transpile->reload loop, patch generation, cascade-delete, CRLF gotcha, QA scripts).
EOF
)

jq -n --arg msg "$MESSAGE" '{"systemMessage": $msg, "suppressOutput": true}'
