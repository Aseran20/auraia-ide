---
name: hook-development
description: Orient a new Claude session for Arclen IDE development. Run at the start of any dev session to load the right mental model and avoid wasted CI builds. Triggers on "/hook-development" or when user says "let's work on Arclen", "start dev session", "where were we".
---

# Arclen IDE — Dev Session Orientation

Run this at the start of any dev session. It loads the key constraints so you don't repeat past mistakes.

## The golden rule

**Local only. No CI until we need an installeur.**

CI takes 60 min and costs money. Every feature, patch, UI tweak, and setting change is developed and tested locally. CI is triggered once, manually, when we're ready to distribute.

## Workflow checklist before touching anything

```bash
# 1. Verify patches are healthy (30s)
"C:\Users\AdrianTurion\AppData\Local\Programs\Git\bin\bash.exe" ./check-patches.sh

# 2. If vscode/ exists — use watch mode (5s iteration)
cd vscode && npm run watch       # Terminal 1, keep running
.\scripts\code.bat               # Terminal 2, launches dev app
# Then Ctrl+Shift+P → "Developer: Reload Window" after each change

# 3. If vscode/ doesn't exist — full build first (30-60 min, one-time)
"C:\Users\AdrianTurion\AppData\Local\Programs\Git\bin\bash.exe" ./dev/build.sh

# 4. After first build, always reuse vscode/ with -s flag (~10-15 min)
"C:\Users\AdrianTurion\AppData\Local\Programs\Git\bin\bash.exe" ./dev/build.sh -s
```

## When making a patch change

1. `check-patches.sh` — confirm patch applies before anything
2. Edit the patch in `patches/user/`
3. `check-patches.sh` again — confirm it still applies
4. If `vscode/` exists: test in watch mode
5. If ready to verify end-to-end: `dev/build.sh -s`
6. CI only when distributing

## Key facts to remember

- **Git Bash path:** `C:\Users\AdrianTurion\AppData\Local\Programs\Git\bin\bash.exe` (user-level install)
- **Patch application order:** `patches/*.patch` → `patches/windows/*.patch` → `patches/user/*.patch`. Base patches run first — user patch context must account for what base patches already removed.
- **`00-brand-remove-branding.patch`** removes `topLevelOpenTunnel` and `topLevelNewWorkspaceChat` from `gettingStartedContent.ts`. Our `arclen-welcome-cleanup.patch` runs after this — its after-context is `];` not `topLevelOpenTunnel`.
- **`check-patches.sh`** auto-detects base patches that overlap with user patch files and applies them first — it simulates real build state correctly.
- **Python 3.13** works with VS Code 1.121.0 (node-gyp 10.x). No need to downgrade to 3.11 unless build fails.
- **`vscode/`** is created by the first `dev/build.sh`. Once it exists, always use `-s` flag to skip re-cloning.

## What NOT to do

- Don't push to master just to test a build — use local
- Don't run `dev/build.sh` without `-s` unless updating upstream VS Code version
- Don't edit JS in `VSCode-win32-x64/out/` directly — use patches + rebuild
- Don't trigger `ci-build-windows.yml` manually unless ready to distribute
