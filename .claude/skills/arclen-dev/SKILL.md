---
name: arclen-dev
description: Arclen IDE dev iteration runbook — the validated HOW-TO for editing the VS Code source and seeing changes. Covers the real edit→transpile→reload loop (npm run watch is a no-op here), generating user patches correctly (plain git diff does NOT work), cascade-delete dependency walks, the CRLF/Edit gotcha, QA scripts, and resuming a broken build. This is the source of truth for HOW to iterate; the sibling arclen-ide skill covers WHAT/WHERE (repo structure, branding, icons, build prerequisites). Use at the start of any Arclen dev session or when the user says "let's work on Arclen", "start dev session", "where were we", "iterate on a patch", "my change isn't showing up", or "the build won't apply".
---

# Arclen IDE — Dev Iteration Runbook

> **Scope:** this is the HOW (iterate, patch, debug the loop). For the WHAT/WHERE — repo structure, branding, icon generation, build prerequisites, modifying the packaged output — see the `arclen-ide` skill. The two are siblings; this one is authoritative on the iteration loop and patch generation.

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
- `vscode/src/**/*.ts` → loop complet ci-dessous (transpile required, hot-reloads on Ctrl+R)
- `vscode/src/**/*.css` → **transpile copies it, but Ctrl+R does NOT re-read CSS** — injected `<style>`/`document.fonts` persist across the soft reload. **You must fully relaunch** — use **`dev/relaunch.sh`** (kills + relaunches + waits until the workbench actually paints, so the screenshot isn't blind), not a bare `scripts/code.bat`. `document.fonts.check(...)` returns stale `true`, so don't trust it after a soft reload. (See "Theming & fonts" below.)
- `vscode/extensions/*/package.json` ou `*.nls.json` → **skip transpile** (extension manifests are loaded directly, not compiled); just Ctrl+R via agent-browser
- `vscode/extensions/*/src/*.ts` → run `npm run gulp compile-extension:<extName>` (heavier, ~30s) THEN Ctrl+R
- `vscode/extensions/theme-*/themes/*.json` → theme data; reload via theme re-pick or relaunch
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

## Theming & fonts — single source of truth + 2 gotchas (validated 2026-05-28)

The **Arclen Dark** theme + IBM Plex fonts are the IDE defaults. **All colour/font values live in ONE file: `branding/arclen-tokens.json`.** Never hand-edit the theme JSON or the splash colours — they're generated.

**To change a colour or a font default:**
```bash
# 1. edit the palette / fonts in branding/arclen-tokens.json   (e.g. palette.accent)
# 2. regenerate the theme + splash + product.json font defaults:
node dev/gen-arclen-theme.mjs
# 3. mirror into the live tree + relaunch to verify (CSS/theme need a FULL relaunch, not Ctrl+R)
cp src/stable/extensions/theme-arclen/themes/arclen-dark.json vscode/extensions/theme-arclen/themes/
cp src/stable/src/vs/workbench/services/themes/common/arclenInitialColors.ts vscode/src/vs/workbench/services/themes/common/
cd vscode && node build/next/index.ts transpile   # only needed if the .ts splash changed
```
The generator (`dev/gen-arclen-theme.mjs`) expands token refs (`$accent`, `$accent/26` = token+alpha) into hex and writes: the theme JSON, `arclenInitialColors.ts` (the startup "splash", a strict subset of the theme → can't drift), and the font-family values in `product.json`. Theme structure (which workbench key → which token) also lives in `arclen-tokens.json` under `theme.workbench`.

**Files:** source = `branding/arclen-tokens.json` + `dev/gen-arclen-theme.mjs`. Generated/shipped = `src/stable/extensions/theme-arclen/` (the theme, dir-scanned into builds), `src/stable/src/vs/.../arclenInitialColors.ts`, `patches/user/arclen-theme-default.patch` (sets default + re-exports the splash — **stable, doesn't change when colours change**), `patches/user/arclen-fonts.patch` (style.css `@font-face`/`--monaco-font`/`--monaco-monospace-font` + fonts.ts `DEFAULT_FONT_FAMILY`), `src/stable/src/vs/.../arclen-fonts/*.woff2` (bundled fonts). Swapping the whole font *family* (not just fallbacks) means editing `arclen-fonts.patch` + replacing the woff2.

**Gotcha 1 — the default theme is NOT `configurationDefaults.workbench.colorTheme`.** That setting does not make a theme the default on a fresh profile (the theme service resolves its own default before extensions register, then doesn't switch). The real default is `ThemeSettingDefaults.COLOR_THEME_DARK` in `src/vs/workbench/services/themes/common/workbenchThemeService.ts` (patched to `'Arclen Dark'`). The neighbouring `COLOR_THEME_DARK_INITIAL_COLORS` is the pre-extension-load splash — leaving it un-themed flashes the old colours at launch.

**Gotcha 2 — CSS changes need a FULL relaunch, not Ctrl+R** (see the file-type list above). TS hot-reloads; CSS/fonts do not.

**Dev extension host is pathologically slow here** (~5 min, "Extension host did not start in 10 seconds") because built-in extensions' `out/` isn't compiled in this dev tree — unrelated to theming, the source-default theme applies regardless. `set VSCODE_SKIP_PRELAUNCH=1` speeds relaunch.

### ⛔ STOP — the red "Activating extension 'vscode.X' failed: Cannot find module …/out/extension.js" toasts are EXPECTED dev noise. DO NOT chase them.

Same root cause as the slow ext host: built-ins aren't compiled in this dev tree, so EVERY built-in with a `main` throws this on launch (git, github, merge-conflict, debug-auto-launch, emmet, git-base…). The notification stack only shows ~3 at a time, so it looks like "3 specific broken extensions" — it isn't. **They do NOT ship** — `gulp` compiles all built-ins at packaging, so the `.exe` has none of these. Treat them as cosmetic dev-only and move on.

Two traps verified the hard way (2026-05-29, ~20 min lost) — don't repeat:
- **`rm -rf extensions/<x>` to "remove" a built-in BREAKS THE BUILD.** Built-ins use **TypeScript project references** between each other; deleting a referenced target → `TS5058: specified path does not exist` in the dependent's compile. Verified: emmet AND github-authentication are both referenced. Clean removal = untangle the reference graph (remove dependents / drop `references`), NOT just delete the dir. The commented `# rm -rf extensions/copilot` in `prepare_vscode.sh` only works because nothing references copilot.
- **`npm run gulp compile-extensions` to silence the toasts in dev also fails** (`TS2688: cannot find type definition 'mocha'/'node'` — dev tree lacks the @types). `compile-extension:<name>` works case-by-case if you genuinely need one extension's `out/` (e.g. git-base), but there is **no clean way to get a 0-error dev window** — accept it.

## Cold start (first time after `dev/build.sh`)

The full build produces `vscode/out-vscode-min/` (minified bundle) but **NOT** `vscode/out/` (dev sources). `scripts/code.bat` will pop `Cannot find module ...vscode/out/main.js`. Fix once:
```bash
cd vscode && node build/next/index.ts transpile   # 10s cold transpile, populates out/
```

After this, the loop above works.

## Build commands

```bash
# Verify patches are healthy (30s) — note: check-patches.sh has a known cwd bug, see below
"C:\Users\<you>\AppData\Local\Programs\Git\bin\bash.exe" ./check-patches.sh

# If vscode/ does NOT exist — full build (30-60 min, one-time)
"C:\Users\<you>\AppData\Local\Programs\Git\bin\bash.exe" ./dev/build.sh

# Reuse vscode/ with -s flag (~10-15 min, rebuilds binaries from current sources)
# Only needed to verify the .exe — daily dev does NOT need this.
"C:\Users\<you>\AppData\Local\Programs\Git\bin\bash.exe" ./dev/build.sh -s
```

## When making a patch change

1. Edit the file directly in `vscode/src/...` (NOT the patch file)
2. Transpile + reload via the loop above
3. Once validated visually, **promote to a patch** (see "Generating user patches" below)
4. `dev/build.sh -s` only when you want to verify the packaged `.exe` — not for normal dev
5. CI only when distributing

## Generating user patches — the tricky part

**`vscode/` git baseline = pristine upstream commit (e.g. 987c959751 for VS Code 1.121.0).** All patches are applied as **uncommitted modifications**. So `cd vscode && git diff` shows base patches + windows patches + user patches + your live edits **all combined** — NOT a clean user patch.

### Preferred: `dev/gen-user-patch.sh` (automates the whole reconstruction)

```bash
# After editing file(s) in vscode/, generate a clean, validated user patch in one shot:
dev/gen-user-patch.sh <patches/user/NAME.patch> <vscode-relative-file> [more files...]
# e.g.
dev/gen-user-patch.sh arclen-fonts src/vs/base/browser/fonts.ts src/vs/workbench/browser/media/style.css
```
It rebuilds the exact pre-state for those files in the REAL apply order — pristine upstream (`git show HEAD:`) + every base patch + every windows patch + every existing **user** patch that sorts *before* `NAME` (all with `!!APP_NAME!!→Arclen` substitution) — then diffs your live edits against it, producing a minimal correctly-anchored patch, and validates by re-applying it onto that baseline. The target NAME's sort position decides which user patches count as "already applied", so name it the way the build will sort it (`arclen-*`). Generated context uses literal `Arclen` (fine — the build substitutes placeholders to the same value); hand-swap to `!!APP_NAME!!` only if you need portability. **It normalizes scratch files to LF** because the working tree has mixed CRLF+LF (see the encoding gotcha below) — a plain diff against pristine would otherwise report a full-file rewrite. Use this instead of the manual approaches below unless it can't handle your case.

### Manual fallbacks (when the script doesn't fit)

**You cannot just `git diff` to get a user patch.** Three workable approaches:

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

**Canonical entry = `dev/build-checked.sh` (NOT `dev/build.sh` directly).** It runs a 25s TS gate
first (aborts before wasting ~16 min on a broken patch), tees to `build.log` itself, and exits with
the REAL code (no `tee` masking). Run via PowerShell tool with `run_in_background: true` — and arm
the Monitor (below) at the same time:

```powershell
$bash = "C:\Program Files\Git\bin\bash.exe"   # <-- the REAL Git Bash. See trap below.
& $bash -c "cd '/c/path/to/repo' && ./dev/build-checked.sh -s"   # tees + truthful exit internally
```

**Fast standalone TS gate: `dev/check-ts.sh` (~25-70s).** Runs `tsgo --noEmit` on the patched tree.
Catches noUnusedLocals (TS6133) / missing imports / type errors — the class that silently fails
`vscode-min-prepack` at minute 16. Run it after editing source or a patch, before any full build.
(Validated 2026-05-28: it catches an injected unused local in one pass.) `build-checked.sh` calls it
automatically; `dev/sync-and-check.sh` (Tier 2, when built) chains reset→reapply-patches→transpile→check-ts
for the post-pull case where the live tree is out of sync with the patch set.

⚠️ **Git Bash path trap:** the exe location differs per machine and bare `bash` may be WSL.
Resolve it first with PowerShell, not `which bash`:
`(Test-Path "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"), (Test-Path "C:\Program Files\Git\bin\bash.exe")`.
On the current PC it's the **system** install `C:\Program Files\Git\bin\bash.exe`; `bash` on PATH
resolves to `C:\WINDOWS\system32\bash.exe` = WSL, which cannot run the Windows build.

**Never use `Start-Process`** (detaches, no log). **Never use the Bash tool to call Windows `.exe` paths** (Bash tool runs under WSL).

⚠️ **`| tee build.log` MASKS the real exit code.** The pipeline's exit status is `tee`'s (always 0),
so a **failed** `dev/build.sh` reports **"completed exit 0"** to the background task. **Never trust the
exit code** — confirm success by reading `build.log`: success = `Finished '...-min-packing'`; failure =
`errored after` / `Finished compilation with [1-9] errors` / `Found N errors`. (Real incident 2026-05-28:
build reported exit 0 but `vscode-min-prepack` had errored with 5 `noUnusedLocals` errors.) If you want
the exit code to be truthful, launch with `set -o pipefail` or check `${PIPESTATUS[0]}`.

### Attach a Monitor while it builds (do this every build)

A 10-15 min build shouldn't be babysat by manual `Read`s. The moment you launch it,
arm a `Monitor` on `build.log` so you get a predictable heartbeat AND an instant scream on
failure (don't discover a TS error at minute 8). The build's own background-task notification
covers final completion; the monitor adds progress + early-failure detection and self-exits on
the gulp packing marker.

```bash
log=/c/path/to/repo/build.log
# Catch the gulp compile-error SUMMARY, not "error TS" — VS Code prints noUnusedLocals/type
# errors as "Error: path.ts(L,C): 'X' is declared but its value is never read." (NO "error TS" prefix).
fail_re='Finished compilation with [1-9]|errored after|Found [0-9]+ error|JavaScript heap out of memory'
done_re='Finished .*min-packing'          # build.sh ends with: npm run gulp vscode-win32-x64-min-packing
while true; do
  if grep -qaE "$done_re" "$log" 2>/dev/null; then echo "BUILD DONE - next: cold transpile to populate out/"; exit 0; fi
  if grep -qaE "$fail_re" "$log" 2>/dev/null; then echo "BUILD FATAL (gulp compile / OOM):"; grep -haoE "$fail_re" "$log" | sort -u | tail -5; exit 1; fi
  last=$(grep -avE '^\+|jsonTmp|setpath|applying patch:|sed -i|^MS_' "$log" 2>/dev/null | tail -1)
  echo "[$(date +%H:%M:%S)] building... ${last:0:140}"
  sleep 90
done
```

Monitor settings: `persistent: false`, `timeout_ms: 1500000` (~25 min headroom). Heartbeat is
90s so it stays well under the auto-stop volume cap.

⚠️ **Hard-won lesson — keep `fail_re` NARROW.** During the native-module rebuild phase (npm ci /
electron-rebuild of `@vscode/spdlog`, `node-addon-api`, etc.) the log emits **`gyp ERR! not ok`,
`npm error gyp`, and `error MSB3491: ... being used by another process`** — and then **npm
retries and the build continues fine.** A `fail_re` that matches `gyp ERR|npm ERR|MSB[0-9]` will
**false-positive and exit while the build is still healthy.** `MSB3491` specifically is a transient
.tlog file-lock (parallel msbuild race / AV), not a toolchain failure — do not kill the build on it.
So the monitor matches only **gulp TypeScript errors and OOM**, which are never retried. For every
other failure mode, trust the **background-task exit notification** (it fires when `dev/build.sh`
exits non-zero) and THEN read `build.log` to diagnose — don't try to interpret mid-build errors live.
If completion fires via the background task before the monitor's `done_re`, `TaskStop` the monitor.

## Key facts to remember

- **Git Bash path:** `C:\Users\<you>\AppData\Local\Programs\Git\bin\bash.exe` (user-level install)
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

**This also applies to unused PRIVATE class members, not just imports/locals.** The `tsgo` checker here flags `TS6133: 'X' is declared but its value is never read.` for an unused `private` field / getter / setter too (verified 2026-05-29: removing the Accounts code orphaned `private accountAction` + the `accountsVisibilityPreference` getter/setter → 2× TS6133). So when a patch deletes the last use of a private member, delete the member's declaration in the same patch — don't assume "private members are exempt from noUnusedLocals." Run `dev/check-ts.sh` after the edit; it catches this in ~25s instead of at minute ~16 of a build.

`check-patches.sh` does NOT catch this (it only checks `git apply` cleanness, not TS semantics). Only a full compile catches it.

## Where Arclen's product defaults live + how UI surfaces are actually hidden

**M&A `configurationDefaults` + product fields live in the REPO-ROOT `./product.json`**, NOT `vscode/product.json` (which is regenerated). `prepare_vscode.sh:~141` deep-merges root over upstream via `jq -s '.[0] * .[1]' product.json ../product.json` (root wins). So: to change a default (workspace trust, telemetry, minimap, fonts, theme, `update.mode`, extension recs…), edit **root `./product.json` `configurationDefaults`**.

> 🩹 **`product.json` `configurationDefaults` is WEB-only upstream — it was DEAD in the Arclen desktop build until the `arclen-product-config-defaults` patch (2026-05-29).** Root cause (confirmed in source): upstream registers configurationDefaults ONLY from `environmentService.options.configurationDefaults` (`configuration.ts:48`), and `options` = the **web** workbench construction options — `undefined` in the Electron/native env service. So the ENTIRE product.json configurationDefaults block was silently ignored in dev AND the packaged `.exe` (that's why `showTabs` originally had to be patched at the source default). **The fix** (`patches/user/arclen-product-config-defaults.patch`) registers `product.configurationDefaults` in the `DefaultConfiguration` constructor at the same early timing as the web path — `product` (= raw `_VSCODE_PRODUCT_JSON`) carries the field even though `IProductConfiguration` doesn't type it. **Verified on a clean fresh profile:** commandCenter:false, layoutControl→0 icons, showTabs:none all apply purely from product.json. **Consequence: a setting added to root `configurationDefaults` now applies in dev (after transpile + `dev/relaunch.sh --fresh`) AND in packaging** — no per-setting source patch needed anymore. (Verify on a FRESH profile; an existing profile's stored UI state can still mask a default — see the `hideByDefault` caveat below.) NOTE: the Arclen Dark startup bg is still the baked-in `arclenInitialColors.ts` splash; the active *theme* comes from `workbench.colorTheme` in configurationDefaults (now delivered).

**Hiding a UI surface is NOT always a setting — know which lever:**
- **Settings-controllable** (just add to root `configurationDefaults`): minimap, breadcrumbs, line numbers, workspace trust (`security.workspace.trust.enabled/banner/startupPrompt`), update/extension notifs (`update.mode:"none"`, `extensions.autoUpdate/autoCheckUpdates:false`, `extensions.ignoreRecommendations:true`), Command Center (`window.commandCenter:false`), layout control (`workbench.layoutControl.enabled:false`), tabs (`workbench.editor.showTabs:"none"`), terminal-in-center (`terminal.integrated.defaultLocation:"editor"`).
  - **⚠️ ENUM VALUES MUST BE EXACT — a wrong value silently breaks the surface (cost ~15 min, 2026-05-30).** Since `arclen-product-config-defaults` revived `configurationDefaults`, every value is now actually applied — so a *stale/invalid enum string* that used to be ignored now bites. The activity-bar rail vanished entirely because `workbench.activityBar.location` was `"side"` — **not a valid value**; the enum is `default`/`top`/`bottom`/`hidden` (`layoutService.ts` `ActivityBarPosition`). "Show it on the side" = `"default"`, NOT `"side"`. Lesson: when adding/auditing a `configurationDefaults` enum setting, **verify the exact enum in source** (`grep` the `enum`/`"enum": [...]` in `workbench.contribution.ts` or the relevant `*.contribution.ts`) — don't trust the conceptual word. Booleans/free-strings (fonts) are safe; enums are the trap. Unknown *keys* (e.g. a typo'd setting id) are harmlessly ignored — it's invalid *values on valid keys* that break.
  - **Header split button + « … » overflow = `workbench.editor.editorActionsLocation:"hidden"`** (NOT a patch). Non-obvious: with `showTabs:"none"`, the editor-actions toolbar (split + overflow + contributed buttons) migrates from the tab strip into the **title bar** (`titlebarPart.ts editorActionsEnabled` = `location===TITLEBAR || (DEFAULT && showTabs===NONE)`). `"hidden"` disables that whole toolbar → split AND « … » disappear together. Caveat: it also hides future title-bar cockpit buttons (Phase 3) — flip back to `"default"`/`"titleBar"` then. (We started removing the split button at the source in `editor.contribution.ts` → reverted as redundant once the setting was found.)
- **NO setting → needs a patch:**
  - **Activity-bar AND bottom-panel containers**: `PaneCompositeBar` is the SAME class for both the sidebar and the panel — filter by id in `paneCompositeBar.ts` `getViewContainers()` **AND** the `cachedViewContainers` getter (it restores pinned icons from storage, so filtering only the live list leaves a previously-pinned tab/icon visible). The `arclen-clean-activity-bar.patch` `arclenHiddenContainers` set hides Run&Debug + Extensions (`workbench.view.debug/.extensions`, sidebar) AND Problems/Output/Debug-Console/Ports (`workbench.panel.markers/.output/.repl` + `~remote.forwardedPortsContainer`, panel). Terminal is deliberately NOT filtered — it's the Assistant; `terminal.integrated.defaultLocation:editor` moves it to the editor area so the panel ends up empty (hideIfEmpty) anyway.
  - **Explorer views** (Outline, Timeline): set `hideByDefault: true` on the view descriptor (`outline.contribution.ts`, `timeline.contribution.ts`). See `arclen-hide-explorer-views.patch`.
  - **Accounts/global activity:** `globalCompositeBar.ts` (skip the push + neutralize `toggleAccountsActivity` + empty the context-menu toggle, else it re-shows).
- **⚠️ `hideByDefault` and stored view-state are FRESH-PROFILE-only.** An already-used dev profile keeps the stored visibility, so the change won't show on your daily profile. Verify `hideByDefault` on a **fresh profile** (`dev/relaunch.sh --fresh <dir>`), or in the packaged `.exe`. (The composite-bar filter also strips the cache, so it's clean even on an existing profile — views via `hideByDefault` are not.) Since the `arclen-product-config-defaults` patch, `configurationDefaults` ALSO verify on a fresh dev profile (see the 🩹 box above) — both levers now work in dev, both need a fresh profile.

## Marketplace lock (no extensions gallery)

Locking the marketplace = remove `extensionsGallery` from product.json. Done durably by commenting the `setpath_json "product" "extensionsGallery" …` line in `prepare_vscode.sh` (not propagated by `apply_branding.sh`, which only rewrites single-value `setpath` lines). Verify: Extensions view search returns 0 results. Bundled built-ins still load (they don't need a gallery).

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
| `dev/qa-loop.sh [--skip-tscheck] [--no-shot] [label]` | Full iteration chain: tscheck → transpile → Ctrl+R+reconnect → screenshot → brand-leaks. Screenshot saved to `dev/qa-<label>-<HHMMSS>.png`. **For CSS/theme/font changes use `dev/relaunch.sh` instead** (Ctrl+R doesn't re-read CSS). | ~40s (15s without tscheck) |
| `dev/relaunch.sh [--probe-only\|--no-kill] [--fresh [DIR]] [--shot P] [--assert 'var=substr'] [--port N] [--timeout S]` | **Full relaunch for CSS/theme/product.json changes.** Kills the dev exe, relaunches with CDP + `VSCODE_SKIP_PRELAUNCH=1`, then BLOCKS until the workbench actually paints (theme vars resolved) before returning — so the screenshot/assert is never blind. `--probe-only` just gates an already-running window. **`--fresh [DIR]`** launches in a throwaway `--user-data-dir` (default `C:\arclen-fresh`) — the **canonical way to verify `configurationDefaults` / `hideByDefault`**, which an existing profile hides behind stored view-state. | ~30-45s to ready |
| `dev/cdp.sh [--shot P] [--eval JS] [--snapshot] [--port N]` | Connect agent-browser to the **real workbench page** (app already up & painted). `connect <port>` alone can land on `about:blank` → blank/black screenshot or `NO_WORKBENCH`; cdp.sh then selects the workbench target before acting. Use for ad-hoc shots/evals; use `relaunch.sh` for a cold start + paint gate. | ~2s |
| `dev/gen-user-patch.sh <patches/user/NAME.patch> <file...>` | Generate a clean, validated user patch from working-tree edits (see "Generating user patches"). | ~5s |
| `dev/ui-inventory.sh [--shot P] [--port N] [--expect-absent ID] [--expect-present ID]` | **Deterministic inventory of the workbench chrome** (menubar · activity bar · sidebar title · panel tabs · status-bar L/R) as JSON — for the dé-scaring work, prefer this over eyeballing a screenshot ("is the Problems counter / Run menu / remote `><` gone?"). `--expect-absent/-present <status-id>` asserts a status-bar id's visibility (exit 3 on mismatch) → use it as a regression gate after a trim patch. **Boundary:** reads the MAIN frame only — webview interiors (Claude panel, Welcome page) are cross-origin iframes it CANNOT see; those stay screenshot-only. Also: extension-contributed chrome (e.g. the Claude ✳ rail icon) may be ABSENT if run before the slow dev ext-host activates. Needs the dev build running (CDP 9222). | ~2s |

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

## `check-patches.sh` — fixed + one limitation

- **Relative-path/cwd bug — FIXED (2026-05-29).** Patch paths are now absolutized before the `cd` into the scratch clone, so it works from repo root (and a `grep -h` fix makes the single-patch-arg form parse correctly). Validated 7/7 and single-patch.
- **Limitation — base-only baseline → now LABELLED, not a false ✗ (2026-05-30).** It replays only `patches/*.patch` (base) before `--check`, NOT prior **user** patches, so it cannot validate a user patch that depends on another user patch (e.g. `arclen-trim-view-menu` after `arclen-hide-menus` on `menubar.contribution.ts`). It used to report a hard **✗** for these (cry-wolf — the FAIL=1 you learned to ignore). It now detects the dependency and prints **`⚠ conditional: depends on prior user patch <name>`**, excluded from the hard-fail exit (so `verify-patches.sh` goes green). A real ✗ is still a real ✗ — only *dependent* failures are downgraded. For the conditional ones, `dev/gen-user-patch.sh`'s own baseline check (replays prior user patches too) is authoritative.
  - **✅ Brand-context placeholder trap — now AUTO-FIXED by `gen-user-patch.sh` (2026-05-30; was a ~15 min manual trap).** If a hunk's **context/removed** line is one the base `00-brand-remove-branding.patch` rewrote to `!!APP_NAME!!` (e.g. `'…get you started in !!APP_NAME!!.'`), the old behaviour emitted it as literal `Arclen` (gen's baseline substitutes) while `check-patches.sh` (no-subst) had `!!APP_NAME!!` → **false ✗**, and the tempting "fix" (editing the live brand string) was a real brand regression. **`gen-user-patch.sh` now reads the resolved→placeholder mapping straight from the prior patches' own `+` placeholder lines and rewrites brand context/removed lines back to `!!PLACEHOLDER!!` automatically** (added `+` lines are left verbatim), then proves it loss-less by **round-trip** (`substitute(placeholder form) == validated literal form`). So a freshly-generated patch passes BOTH paths with no hand-`sed`. If gen ever prints `! placeholder round-trip mismatch — kept the literal-Arclen patch`, that's the safe fallback — investigate, don't ship blind. (Old manual recipe, no longer needed: `sed -i "s|started in Arclen\.|started in !!APP_NAME!!.|" patch`.)
  - **⚠️ Hunk-merge trap (cost ~10 min, 2026-05-30):** when you add edits to a file *near* another patch's hunk region, `gen-user-patch` may **merge** your small hunks with the existing patch's hunk into one big hunk that spans a region a *prior* user patch modifies → that patch now depends on the prior one → `check-patches.sh`/`verify-patches.sh` flips it to a **persistent false ✗** (cry-wolf, kills the gate's value). Example: folding the Welcome Start FR-vocab edits into `arclen-welcome-cleanup` merged the `startEntries` edits (lines 109-164) with its line-167 walkthroughs-trim hunk, spanning the region `arclen-disable-walkthroughs` empties first. **Fix that keeps the gate green:** put the new edits in their **own** patch scoped to a region **no other user patch touches** (verify with `grep '^@@' other-patches` — Welcome `startEntries` 109-164 is clear; base/`disable-walkthroughs`/`welcome-cleanup` all hit ≥167/≥201). Pure string-swaps don't shift line numbers, so a sibling patch in an untouched region applies independently and both stay ✓. That's why Welcome vocab shipped as a separate `arclen-welcome-vocab` instead of folding into `arclen-welcome-cleanup`.

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
