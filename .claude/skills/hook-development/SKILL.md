---
name: hook-development
description: Orient a new Claude session for Arclen IDE development. Run at the start of any dev session to load the right mental model and avoid wasted CI builds. Triggers on "/hook-development" or when user says "let's work on Arclen", "start dev session", "where were we".
---

# Arclen IDE — Dev Session Orientation

Run this at the start of any dev session. It loads the key constraints so you don't repeat past mistakes.

## The golden rule

**Local only. No CI until we need an installeur.**

CI takes 60 min and costs money. Every feature, patch, UI tweak, and setting change is developed and tested locally. CI is triggered once, manually, when we're ready to distribute.

## The iteration loop (the REAL one, validated 2026-05-28)

**Critical: `npm run watch` does NOT emit JS in this config.** `useEsbuildTranspile=false` is set, so the `watch-client-transpile` task becomes a no-op (`[watch] esbuild transpile disabled. Keeping process alive as no-op`). `watch-client` only does `tsgo --noEmit` (type check). So watch alone never refreshes `out/`.

**The real emit step is a one-shot:**
```bash
cd vscode && node build/next/index.ts transpile   # ~10s, full src/ → out/
```

**Quel fichier édites-tu ?**
- `vscode/src/...` → loop complet ci-dessous (transpile required)
- `vscode/extensions/*/package.json` ou `*.nls.json` → **skip transpile** (extension manifests are loaded directly, not compiled); just Ctrl+R via agent-browser
- `vscode/extensions/*/src/*.ts` → run `npm run gulp compile-extension:<extName>` (heavier, ~30s) THEN Ctrl+R
- `vscode/product.json` → quit + relaunch `code.bat` (not picked up by reload)

**Optimal loop per change** (~15s per iteration):
```
1. Edit         → Edit tool on vscode/src/...                          (instant)
2. Transpile    → cd vscode && node build/next/index.ts transpile      (~10s)
3. Reload       → agent-browser press "Ctrl+R"                          (1s)
4. Reconnect    → agent-browser connect 9222   (Ctrl+R briefly drops CDP socket — error 10060 otherwise)
5. Verify       → agent-browser screenshot dev/check-N.png  +  Read the PNG
```

**When to also run `npm run watch` (optional):** for continuous type-check while you edit. Catches TS errors at save time instead of after the 10s transpile. **Known crash**: `watch-extensions` sometimes dies with `ERR_CHILD_PROCESS_STDIO_MAXBUFFER` on `watch-extension-media`. Non-fatal for workbench iteration — just run `watch-client` alone if it bothers you: `npm run gulp watch-client`.

## Cold start (first time after `dev/build.sh`)

The full build produces `vscode/out-vscode-min/` (minified bundle) but **NOT** `vscode/out/` (dev sources). `scripts/code.bat` will pop `Cannot find module ...vscode/out/main.js`. Fix once:
```bash
cd vscode && node build/next/index.ts transpile   # 10s cold transpile, populates out/
```

After this, the loop above works.

## Build commands

```bash
# Verify patches are healthy (30s) — note: check-patches.sh has a known cwd bug, see below
"C:\Users\AdrianTurion\AppData\Local\Programs\Git\bin\bash.exe" ./check-patches.sh

# If vscode/ does NOT exist — full build (30-60 min, one-time)
"C:\Users\AdrianTurion\AppData\Local\Programs\Git\bin\bash.exe" ./dev/build.sh

# Reuse vscode/ with -s flag (~10-15 min, rebuilds binaries from current sources)
# Only needed to verify the .exe — daily dev does NOT need this.
"C:\Users\AdrianTurion\AppData\Local\Programs\Git\bin\bash.exe" ./dev/build.sh -s
```

## When making a patch change

1. Edit the file directly in `vscode/src/...` (NOT the patch file)
2. Transpile + reload via the loop above
3. Once validated visually, **promote to a patch** (see "Generating user patches" below)
4. `dev/build.sh -s` only when you want to verify the packaged `.exe` — not for normal dev
5. CI only when distributing

## Generating user patches — the tricky part

**`vscode/` git baseline = pristine upstream commit (e.g. 987c959751 for VS Code 1.121.0).** All patches are applied as **uncommitted modifications**. So `cd vscode && git diff` shows base patches + windows patches + user patches + your live edits **all combined** — NOT a clean user patch.

**This means you cannot just `git diff` to get a user patch.** Three workable approaches:

1. **`.disabled` rename** (preferred when base patch adds code Arclen doesn't need): rename `patches/00-foo.patch` → `.disabled`. `prepare_vscode.sh:159` globs `*.patch` so the disabled extension is naturally ignored. Already used for `patches/windows/41-cli-fix-update-url.patch.disabled` and (since 2026-05-28) `patches/00-community-add-announcements.patch.disabled`.

2. **Hand-write the user patch** from before/after snippets of the relevant file. The `before` must reflect the file state AFTER all base patches apply (so your `before` matches what `00-community-add-announcements.patch` produced, not upstream).

3. **Build a clean intermediate state**: in a scratch worktree, clone upstream + apply only `patches/*.patch` + `patches/windows/*.patch` (skip `patches/user/`), commit, then apply your live `vscode/` changes on top → `git diff` gives the right user-patch content. Heavy; reserve for >1 file changes.

4. **Programmatic patch generation for large deletions** (validated 2026-05-28, Issue #4-5):
   ```bash
   # Get pristine upstream
   cd vscode && git show HEAD:path/to/file > /tmp/pg/pristine.ts
   # Extract base patch hunks for that file only
   awk '/^diff --git a\/path\/to\/file/,/^diff --git /' ../patches/00-base.patch > /tmp/pg/base.patch
   # Apply base patch to get post-base-patch state
   cd /tmp/pg && patch --no-backup-if-mismatch -p1 pristine.ts < base.patch
   # Now pristine.ts == post-base-patch state. Use python to compute the hunk:
   python3 -c "
   with open('pristine.ts') as f: lines = f.read().splitlines()
   target = lines[START_LINE-1:END_LINE]  # the section to delete
   # Build hunk: @@ -START,LEN +START,1 @@ then '-line' for each, then '+replacement'
   "
   # Validate: apply your user patch to a copy of post-base-patch state, check it succeeds.
   ```

### Placeholders in patches

`utils.sh:53-61` defines `apply_patch()` which **substitutes `!!APP_NAME!!`, `!!APP_NAME_LC!!`, `!!ASSETS_REPOSITORY!!`, `!!BINARY_NAME!!`, `!!GH_REPO_PATH!!`, `!!GLOBAL_DIRNAME!!`, `!!ORG_NAME!!`, `!!RELEASE_VERSION!!`, `!!TUNNEL_APP_NAME!!`** in the patch text BEFORE calling `git apply`. So:
- User patches can (and should) use `!!APP_NAME!!` in before-context lines, not the literal `Arclen` — keeps them portable if `APP_NAME` changes.
- When generating a user patch via the "post-base-patch state" approach above, the post-state file will have `!!APP_NAME!!` (because we applied the base patch without substitution). Your generated user patch will inherit those placeholders → apply_patch substitutes them again at apply time → matches the live working tree (which has `Arclen` everywhere because base patches were applied via apply_patch with substitution). Round-trip works.

## Killing a base patch vs writing a user patch

| Situation | Choose |
|---|---|
| Base patch adds a VSCodium-community feature Arclen never wants (announcements, telemetry-style ads, etc.) | **`.disabled` rename** — clean, ~50 LOC of dead code avoided, no drift to maintain |
| Base patch is fine but Arclen needs a tweak | **User patch** in `patches/user/arclen-*.patch` |
| Base patch breaks Arclen functionality | Investigate why — maybe a `.disabled`, maybe a user patch that fixes the regression |

**Past examples:**
- `00-community-add-announcements.patch.disabled` (kills the Welcome announcements section + remote fetch to `raw.githubusercontent.com/.../announcements-extra.json`)
- `windows/41-cli-fix-update-url.patch.disabled` (irrelevant URL targeting since updateUrl is disabled in `product.json`)

## How to launch a build (Claude Code)

Run via PowerShell tool with `run_in_background: true`, always pipe to `build.log`:

```powershell
$bash = "C:\Users\AdrianTurion\AppData\Local\Programs\Git\bin\bash.exe"
& $bash -c "cd '/c/Users/AdrianTurion/devprojects/2-auraia/auraia-ide' && ./dev/build.sh -s 2>&1 | tee build.log"
```

Then monitor with `Read` on `build.log` or `Bash tail build.log | head -30`.

**Never use `Start-Process`** (detaches, no log). **Never use the Bash tool to call Windows `.exe` paths** (Bash tool runs under WSL).

## Key facts to remember

- **Git Bash path:** `C:\Users\AdrianTurion\AppData\Local\Programs\Git\bin\bash.exe` (user-level install)
- **Validated Windows toolchain (2026-05):** VS 2022 Community 17.14 + MSVC v143 (v14.44.35207) + Spectre v143 x64. **Do NOT install VS 2026** — node-gyp 11.x can't detect it and the workarounds (node-gyp swap, env override) diverge from CI.
- **node-gyp:** stock npm-bundled 11.5 (no swap needed with VS 2022). If a previous Claude swapped to 12.x for 2026 support, restore from `node-gyp_11.5.0_bak` backup in `%ProgramFiles%\nodejs\node_modules\npm\node_modules\`.
- **Patch application order:** `patches/*.patch` → `patches/windows/*.patch` → `patches/user/*.patch`. Base patches run first — user patch context must account for what base patches already removed.
- **`00-brand-remove-branding.patch`** removes `topLevelOpenTunnel` and `topLevelNewWorkspaceChat` from `gettingStartedContent.ts`. Our `arclen-welcome-cleanup.patch` runs after this — its after-context is `];` not `topLevelOpenTunnel`.
- **`check-patches.sh`** auto-detects base patches that overlap with user patch files and applies them first — it simulates real build state correctly.
- **Python 3.13** works with VS Code 1.121.0 (node-gyp 10+). No need to downgrade to 3.11 unless build fails.
- **`vscode/`** is created by the first `dev/build.sh`. Once it exists, always use `-s` flag to skip re-cloning.
- **node-gyp + electron-rebuild caches** live in `%LOCALAPPDATA%\node-gyp` and `%USERPROFILE%\.electron-gyp`. **Never delete** between builds — they hold node/electron headers (~100 MB) and saves ~2-3 min of re-download per native module rebuild.

## Rust CLI is skipped by design

`dev/build.sh` exports `SKIP_CLI=yes` and `build.sh` honors it to skip `build_cli.sh`. The Rust CLI binary (`code.exe` in upstream, would be `arclen.exe` CLI here) is **not the IDE** — it's a separate static binary used for: code-tunnels (share local IDE via vscode.dev), Remote-SSH server bootstrap, and dev container/WSL/Codespaces server. **None of these are Arclen use cases** (M&A analysts editing files locally). Skipping saves the rustup install + cargo compile (~5-10 min) and removes a Rust toolchain dependency from the machine.

If you ever need the CLI: `winget install Rustlang.Rustup` then unset `SKIP_CLI` and rebuild.

## Disabled / kept-in-mind base patches

- `patches/windows/41-cli-fix-update-url.patch.disabled` — targets `latest.json` URL removed in VS Code 1.121.0. Arclen has `updateUrl` disabled in `product.json` so the patch is irrelevant. **Don't re-enable.** When updating VS Code version, check if upstream VSCodium fixed it.

## Two artifacts, two purposes — don't confuse them

| Artifact | Purpose | When to use |
|---|---|---|
| `vscode/` (source tree, compiled in-place via `npm run watch`) | **Dev iteration**, 5s reload loop | 99% of dev work — patches, UI tweaks, settings |
| `VSCode-win32-x64/Arclen.exe` (packaged binary) | **Distribution** (what a user double-clicks) | Smoke-test the packaged build, hand to a non-dev user |

Watch mode only needs `vscode/` populated. The `.exe` is the result of `npm run gulp vscode-win32-x64-min-packing` after `vscode-min-prepack` — `dev/build.sh` chains both. You do NOT need `.exe` to iterate.

**⚠️ One-time gotcha after the first `dev/build.sh`:** the full build produces `vscode/out-vscode-min/` (minified distrib bundle) but **NOT** `vscode/out/` (non-minified dev sources). `scripts/code.bat` needs `vscode/out/main.js` and will pop a dialog `Cannot find module ...vscode/out/main.js` if it's missing. Fix once:
```bash
cd vscode && node build/next/index.ts transpile   # 10s cold transpile, populates out/
```
After this, `npm run watch` keeps `out/` fresh incrementally. The orientation hook detects this case and tells the next Claude session to run the transpile step first.

## Patches must remove imports of removed usages (VS Code TS strict)

VS Code's `tsconfig` has `noUnusedLocals: true`. If a `patches/user/*.patch` removes the *only* usage of an imported symbol but leaves the import line intact, the compile fails with `'X' is declared but its value is never read.` after ~7 min of compile.

**Concrete past incident:** `arclen-hide-run-menu.patch` removed the menu block using `IsSessionsWindowContext.negate()` but left `import { FocusedViewContext, IsSessionsWindowContext } from '../../../common/contextkeys.js';`. Fix = add a hunk at line ~20 changing the import to drop `IsSessionsWindowContext`.

**When writing/modifying a user patch that removes code:** grep the file for every symbol used in the removed block — if no other usage remains in the post-patch file, the import must also go in the same patch.

`check-patches.sh` does NOT catch this (it only checks `git apply` cleanness, not TS semantics). Only a full compile catches it.

### Cascade-delete dependency tree

When killing a feature, the orphans cascade. List the tree **before editing** rather than discovering each error one at a time (each iteration = 10s transpile + reload + screenshot = wasted minutes).

**Template — for any feature removal, identify in order:**
1. **Type definitions** (`type X = ...`, `interface X { ... }`) — orphaned once no field/var uses them
2. **Module-level consts** that hold instances of those types (`const FOO: X[] = [...]`)
3. **Class fields** that reference the type (`private fooList?: GettingStartedIndexList<X>;`)
4. **Methods** that build/use those fields (`private async buildFoo(): Promise<...>`)
5. **Callsites** of those methods (`await this.buildFoo()`)
6. **Imports** of any symbol whose only usage you just removed

**Past incident — Issue #1 (2026-05-28):** killing `buildAnnouncementList()` orphaned `AnnouncementEntry` type, `BUILTIN_ANNOUNCEMENTS` const, `announcementList` and `announcementData` fields, plus the const binding at the callsite. I discovered each across 3 separate compile passes (~45s wasted). Doing the dependency walk upfront would have been one edit, one transpile.

## File encoding gotcha — CRLF/LF mismatch breaks Edit tool

Some files in `vscode/src/` have **mixed line endings** (CRLF mixed with LF). The `Edit` tool's `old_string` matcher operates on the on-disk bytes, but the `Read` tool normalizes for display — so a string you copy from `Read` output may not match the file's actual bytes.

**Symptom:** `Edit` returns "String to replace not found" on a string you can literally see in `Read` output.

**Diagnose:** `sed -n 'Np' file | cat -A` — look for `^M` between visible chars (not just at line end). Past incident: line `const BUILTIN_ANNOUNCEMENTS: AnnouncementEntry[] = [];` had bytes `[\r]\r;` not `[];`.

**Workarounds (in order of preference):**
1. **Use a longer `old_string` with anchors** that ARE pure ASCII on both sides of the weird bytes.
2. **Fall back to Python via Bash** with a regex that tolerates the weirdness:
   ```bash
   python3 -c "
   import re
   p = 'path/to/file.ts'
   with open(p, 'rb') as f: data = f.read()
   new = re.sub(rb'\nconst BUILTIN_ANNOUNCEMENTS:[^\n]*\n', b'\n', data)
   with open(p, 'wb') as f: f.write(new)
   print('removed', len(data)-len(new), 'bytes')
   "
   ```
3. **Don't** try `dos2unix` / mass line-ending normalization — it will diff against every patch hunk and break everything.

## QA scripts & loops

### Upstream VS Code scripts (always available in `vscode/`)

| Script | Cost | Use case |
|---|---|---|
| `npm run compile-check-ts-native` | ~25s | `tsgo --noEmit` one-shot. Catches `noUnusedLocals` / missing imports / type errors **before** the transpile + reload cycle. Run after any non-trivial edit. |
| `npm run hygiene` | ~1 min | Format, copyright headers, no-debugger, indent. Run before commit. |
| `npm run eslint` | ~30s | ESLint pass on src + extensions. Before commit. |
| `npm run precommit` | ~20s | `build/hygiene.ts` — faster subset of hygiene for git pre-commit hook. |
| `npm run check-cyclic-dependencies` | varies | Cyclic imports in `out/`. After full builds, not iteration. |

### Arclen-specific scripts (in `dev/`)

| Script | Purpose | Cost |
|---|---|---|
| `dev/check-brand-leaks.sh [--strict] [paths...]` | Scans for VSCodium/MS branding in renderer + l10n. HIGH (must fix), MEDIUM (review), STRICT (audit only). Exit 1 if HIGH leaks. | ~5s |
| `dev/qa-loop.sh [--skip-tscheck] [--no-shot] [label]` | Full iteration chain: tscheck → transpile → Ctrl+R+reconnect → screenshot → brand-leaks. Screenshot saved to `dev/qa-<label>-<HHMMSS>.png`. | ~40s (15s without tscheck) |

### Hook: `arclen-check-brand` (PostToolUse)

Wired in `.claude/settings.json` on matcher `Edit|Write|NotebookEdit`. After any edit to `vscode/src/vs/{workbench,code,platform/product}/...`, the hook **invokes `dev/check-brand-leaks.sh` on the changed file** and emits a `systemMessage` if HIGH-confidence leaks are found. Silent otherwise. Non-blocking — informational only.

**Single source of truth = `dev/check-brand-leaks.sh`.** Patterns live in the script only; the hook just parses its output. To add a new HIGH pattern: edit the `HIGH_PATTERNS` array in the script — the hook picks it up automatically.

### Recommended use in the iteration loop

For trivial edits (rename, tweak, single-line): just `transpile + Ctrl+R + screenshot`, skip the tscheck.

For non-trivial edits (delete a feature, refactor a method, touch multiple files):
```bash
dev/qa-loop.sh issueN          # full chain, ~40s
# → red ✗ on TS error    = fix and rerun (cheaper than discovering at reload)
# → red ✗ on HIGH leak   = fix and rerun
# → green ✓ + screenshot = visually validate, then promote to patch
```

For pre-commit batch:
```bash
cd vscode && npm run compile-check-ts-native && npm run eslint && npm run hygiene
cd .. && dev/check-brand-leaks.sh --strict
```

## `check-patches.sh` known bugs

- **Relative path bug**: script can fail with `error: can't open patch 'patches/user/X.patch': No such file or directory` when run from repo root, because it `cd`s into a clone dir mid-script. Doesn't invalidate the patches themselves — just don't rely on it as the final gate before commit. Fix pending.

## How to resume a build that died mid-compile

If `gulp compile-src` fails with a TS error, **do NOT** re-run `./dev/build.sh -s` — that re-clones, re-applies patches, re-runs `npm ci` (~25 min wasted). The vscode/ tree is in a fully-patched state; just:

1. Edit the offending file **both** in `vscode/` (so the resume picks up the fix) AND in the source `patches/user/*.patch` (so the next clean build has it)
2. From repo root in Git Bash:
   ```bash
   cd vscode && npm run gulp vscode-min-prepack
   ```
3. ~10 min later you're past the compile. If you also want the `.exe`, follow up with the packaging steps from `build.sh:38-44` (RTF, policies, `vscode-win32-x64-min-packing`).

## What NOT to do

- Don't push to master just to test a build — use local
- Don't run `dev/build.sh` without `-s` unless updating upstream VS Code version
- Don't re-run `dev/build.sh` after a compile error — resume the gulp step directly (see above)
- Don't edit JS in `VSCode-win32-x64/out/` directly — use patches + rebuild
- Don't trigger `ci-build-windows.yml` manually unless ready to distribute
- Don't install rustup just to make the build "complete" — `SKIP_CLI=yes` is the right answer for Arclen
