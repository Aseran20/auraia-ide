# Harness backlog — Arclen IDE (project-specific)

Tooling/automation to make Arclen dev faster & less error-prone. Cross-project method items live in
`~/.claude/skills/retro/backlog.md`. The `retro` skill re-reads this at session-retro start.

Format: `- [ ] <fix> — <why / incident> — mechanism — effort: <S/M/L>`

## Open
- [ ] **Rebrand the MSI `.wxs` (VSCODIUM.EXE → Arclen) so `SHOULD_BUILD_MSI` can be re-enabled** — `build/windows/msi/vscodium.wxs` hardcodes `TargetFile="VSCODIUM.EXE"` in ~18 file-type-association `<Verb>` elements, and `apply_branding.sh` doesn't touch the `.wxs`, so WiX `light.exe` fails `LGHT0094: Unresolved reference to symbol 'File:VSCODIUM.EXE'` for the Arclen binary. Surfaced 2026-05-31 by the GitHub `build (x64)` job at *Prepare assets* (only reachable once the woff2 compile fix landed; arm64 doesn't build MSI so it passed). Currently worked around by `SHOULD_BUILD_MSI: 'no'` in ci-build-windows.yml (portable ZIP + Inno Setup.exe still produced — enough for smoke-tests). Proper fix: rebrand the `.wxs` EXE symbol via apply_branding (or a patch) so the MSI installer builds. Needed only if Arclen ships an `.msi`. — mechanism: apply_branding sed + branding.sh value — effort: M
- [ ] **`dev/promote.sh` (turnkey promote helper)** — `gen-user-patch.sh` already does the hard part
  (baseline reconstruction + validation), but you still have to name the modified files by hand. A wrapper
  that runs `git -C vscode status` (or reads `.claude/.live-edits`) to LIST candidate files and prints a
  ready-to-paste `gen-user-patch.sh` command would remove the last manual step. Marginal value — naming the
  patch + "user-patch vs disable-base" is still a judgment call. — mechanism: script — effort: S

## Dropped
- **PostToolUse orphan-import hook (was Tier 3)** — dropped 2026-05-28: redundant with `check-ts.sh`,
  which catches the same noUnusedLocals/orphan-import class authoritatively (and `verify-patches.sh`
  now runs it as a gate). A grep heuristic would only add false positives for no extra coverage.
- **`dev/sync-and-check.sh` destructive reset variant (was Tier 2)** — dropped 2026-05-28 in favor of
  the non-destructive `verify-patches.sh` below. A `git reset --hard` on `vscode/` would wipe un-promoted
  live edits (everything in `vscode/` is an uncommitted mod vs the pristine baseline), and `check-ts.sh`
  already TS-checks the live tree — which is what actually catches the incident. Not worth the footgun.

## Done
- [x] **Local-build opti: warm `-s` (guarded npm ci) + `dev/build-safe.sh` (anti-crash throttle) + `dev/resume-build.sh`** (2026-05-31) — a full local build OOM-crashed the PC during the gulp compile phase; root cause = `prepare_vscode.sh`'s `npm ci` runs UNGUARDED on every build (clean reinstall + native rebuilds = a 40-proc storm) and the gulp compile gets an 8 GB heap × parallel workers, exceeding 16 GB RAM alongside the MCP swarm/editors. **(a)** Guarded `npm ci`: skip when `node_modules` matches `package-lock.json` (sha stamp in `node_modules/.arclen-npm-ci.sha`); our patches never touch the lock, so `-s` is now genuinely WARM (reset→reapply→skip-npm→compile→pack, ~8-12 min vs ~25-30 cold). `FORCE_NPM_CI=1` overrides. Safe to edit prepare_vscode (apply_branding only seds its `setpath product` lines — verified). **(b)** `dev/build.sh`+`build.sh` now honor a caller-set `NODE_OPTIONS`; `dev/build-safe.sh` caps heap to ~40% RAM (≤6 GB) + JOBS to ¼ cores (≤4). **(c)** `dev/resume-build.sh` re-runs only gulp compile + Windows pack (mirrors build.sh) after a late failure. All syntax-validated + RAM detection confirmed (15.7 GB/16-core → heap 6144, JOBS 4); **first real build validates the npm-ci skip end-to-end.** Decision: keep building local (PC crashes are rare; CI round-trips too slow on errors). — mechanism: script edit×3 + 2 new scripts + skill doc — effort: M
- [x] **`dev/check-patch-collisions.sh` (duplicated-hunk collision lint) + wired into `verify-patches.sh` (gate 1/3)** (2026-05-31) — a from-scratch build died at the patch phase (~3 min in): `arclen-rebrand-preferences.patch` was generated carrying two hunks BYTE-IDENTICAL to `arclen-trim-gear-menu.patch`'s (gen-user-patch swallowed another patch's hunks), so whichever applied second hit "patch does not apply". `check-patches.sh` is structurally blind to this — it tests each patch vs PRISTINE upstream in ISOLATION, so a sequence-only clash is invisible (it's COMPLEMENTARY to the 2026-05-30 ⚠ conditional *dependency* detection: collision ≠ dependency). New <1s static lint hashes each hunk's BODY (context+`-`/`+` lines, dropping the shiftable `@@` header) per file; same body in ≥2 patches = collision. **Precision lesson (caught by the GREEN test):** a first cut matched line *content* and cried wolf on two patches removing a generic line (`title: {`, `content: {`, `when: '!isWeb'`) at DIFFERENT locations — switched to whole-hunk-body matching → 0 false positives by construction. Validated red (committed buggy rebrand → flags both 840/855 dups, exit 1) + green (24 patches clean, exit 0; restored fix byte-identical). — mechanism: script + script edit — effort: M
- [x] **`arclen-dev` skill: reconciled the "arm a Monitor on build.log" guidance with WSL/drvfs blindness** (2026-05-31) — the Monitor/Bash tools run under WSL; `/mnt/c` drvfs negative-dentry caches a `build.log` the Windows `tee` CREATES after the Monitor starts, so a fresh-file Monitor sits in its `[ ! -f ]` wait-loop and self-exits with a false "never appeared" (PowerShell sees it fine). Added the caveat + two fixes (`touch "$log"` from WSL pre-launch so the dentry exists, OR watch via a PowerShell `run_in_background` loop). — mechanism: skill edit — effort: S
- [x] **`dev/ui-inventory.sh` (deterministic workbench-chrome inventory)** (2026-05-30) — the dé-scaring verification ("is the Run menu / Problems counter / remote `><` gone?") was being done by eyeballing screenshots, easy to miss a 14px status-bar item. agent-browser can read the live workbench DOM, so the visible chrome is now ENUMERATED → JSON (menubar · activity bar · sidebar title · panel tabs · status-bar L/R), with `--expect-absent/-present <status-id>` assertions (exit 3 on mismatch) usable as a regression gate after a trim patch. Dogfooded on the footer trim that motivated it: `--expect-absent status.host --expect-present status.notifications` → exit 0, proving `><` gone + bell kept without a screenshot. **Boundary (documented in arclen-dev skill):** reads the MAIN frame only — webview interiors (Claude panel, Welcome page) are cross-origin iframes it can't see (screenshot-only); and extension-contributed chrome (Claude ✳ rail icon) may be absent if run before the slow dev ext-host activates. — mechanism: script + arclen-dev skill row — effort: S
- [x] **`gen-user-patch.sh` auto-placeholder-izes brand context + `check-patches.sh` labels conditional patches** (2026-05-30) — kills the two cry-wolf false-✗ classes that made the apply-check gate untrustworthy (you'd learned to ignore its FAIL count). **(#1)** When a generated patch's CONTEXT/REMOVED line was one a base patch brand-substituted (`!!APP_NAME!!`→`Arclen`), gen used to emit literal `Arclen` while `check-patches` (no-subst) had the placeholder → false ✗, and the tempting "fix" was a brand regression (cost ~15 min once). gen now reads the resolved→placeholder map straight from the prior patches' own `+` placeholder lines (NOT by rebuilding a non-subst baseline — first attempt did that and got a FALSE map when a prior patch's raw replay partially failed, mapping `Arclen`→pristine `VS Code`), rewrites only context/removed lines, and proves it loss-less by round-trip (`substitute(placeholder)==validated literal`). **(#2)** `check-patches` now detects user-patch→user-patch dependencies and prints `⚠ conditional` (excluded from hard-fail exit) instead of a bare ✗. Validated red+green: trim-help auto-reproduces the hand-fixed patch byte-identical & passes a real upstream `check-patches` (✓, was the canonical ✗); brand-free trim-edit untouched; full run = 20 passed/0 failed/1 conditional exit 0; broken *independent* patch still ✗ (not masked) with clean patch ✓, tally correct, exit 1. — mechanism: script + script edit — effort: M
- [x] **`check-patches.sh` two latent `set -e`/`pipefail` aborts — FIXED (2026-05-30)** — surfaced by the #1/#2 validation pass (red+green RED test). (a) `ALL_FILES=$( { grep…; [[ ${#PREREQ[@]} -gt 0 ]] && grep…; } | … )` — when PREREQ is empty the `[[ ]] && grep` returns 1, poisoning the pipe under `pipefail` → script aborted **before any check ran** (a single patch overlapping no base patch crashed silently with only the header printed). Fixed by a trailing `true` in the group. (b) The ✗-branch diagnostic pipe `git apply | grep | head | sed` inherited git's 128/1 under `set -e` and aborted mid-loop (skipping the tally, stopping at the first failure, exiting 128 not 1). Fixed with `|| true`. Now any real failure reports every ✗ and exits 1 cleanly. General bash reflex captured cross-project. — mechanism: script edit — effort: S
- [x] **Hidden dev console + leftover-sweep in `relaunch.sh`** (2026-05-30) — `relaunch.sh` launched
  `code.bat` via `start ""`, opening a VISIBLE console that `code.bat` held open all session (electron
  runs foreground with logging on); the kill step only targeted `Arclen.exe`, so stray dev consoles
  piled up one-per-relaunch on screen (user-reported). Fix: launch the console HIDDEN via
  `Start-Process -WindowStyle Hidden` (IDE GUI still shows; electron logs → `dev/.arclen-dev.log`),
  and on each relaunch also `taskkill /FI "WINDOWTITLE eq VSCode Dev*"` to sweep survivors. Validated
  across two consecutive relaunches: stays at 1 launcher proc / 1 app instance, no visible window,
  theme paints (`#09090b`). Artifacts gitignored. — mechanism: script edit — effort: S
- [x] **Guard-hook false-positives — token-anchored match (2 recurrences, final fix 2026-05-30)** — the
  destructive-build guard (`arclen-guard-destructive.sh`, built 2026-05-29) matched the WHOLE Bash command
  with the loose glob `*build*.sh*-s*`, so any command whose substrings aligned in order false-positived
  and was blocked. **1st recurrence:** a `git commit` whose `-m` message mentioned "build"…".sh"…"-s" (or
  quoted "git reset --hard") — fixed by stripping the `-m`/`-F` body into a `SCAN` var. **2nd recurrence
  (same day):** the `-m` strip was insufficient — `node build/next/index.ts && ./dev/relaunch.sh
  dev/oe-simplified.png` matched too ("build"…"relaunch.sh"…"oe-**s**implified"). **Final fix:** replaced
  the glob with **token-anchored grep** — require an actual `build(-checked)?.sh` at a path/word boundary
  AND a standalone `-s`/`--source` flag (space/edge both sides); kept the `-m` strip. Re-validated red+green
  (6 fixtures incl. the exact misfire → ALLOW; `build-checked.sh -s`, `bash dev/build.sh -s`, `git reset
  --hard` → BLOCK). Lesson = the cross-project reflex already in the user backlog ("match intent, anchor to
  the executable at a word boundary") — this incident is proof to apply it the *first* time. — mechanism: hook edit — effort: S
- [x] **Path-agnostic hook launcher `run.sh` + Windows `file_path` normalization** (2026-05-29) — all
  hooks were silently broken on Windows: CC runs `settings.json` hook commands via **`bash -c`**, where bare
  `bash` = `System32\bash.exe` (**WSL**) — which has **no `jq`** (every hook needs it) and **strips
  backslashes** (`.claude\hooks\x` → "No such file or directory"). First attempt (a `cmd.exe` wrapper) was
  wrong — CC never uses cmd; the `bash:` error prefix was the tell, missed on the first pass. Fix:
  `.claude/hooks/run.sh`, a forward-slash launcher that re-execs the target under **Git Bash** when `jq` is
  absent (probes `/c/...` + `/mnt/c/...`, system + user installs via glob → path-agnostic across both PCs).
  All 4 commands → `bash .claude/hooks/run.sh .claude/hooks/<script>.sh`. **Second bug found while fixing:**
  the scripts matched `tool_input.file_path` with forward-slash globs, but CC sends **backslash** paths on
  Windows → `check-brand`/`track-edits` never fired on real edits (so the guard's ledger stayed empty and
  did NOT protect). Added `tr '\\' '/'` normalization to both. Validated red+green (WSL re-exec emits JSON;
  guard denies on `-s`; backslash vscode path now writes ledger; non-vscode path doesn't; no error on
  clean file). See memory `cc-hooks-run-via-wsl-bash`. — mechanism: script + script edits + settings — effort: M
- [x] **`dev/cdp.sh` (connect to the REAL workbench page) + `relaunch.sh --fresh`** (2026-05-29) —
  kills the blank-screenshot trap: `agent-browser connect <port>` can land on `about:blank`, so
  screenshot/eval returned a black frame and past sessions burned blind shots. `cdp.sh` connects then
  selects the workbench target (lists `tab list --json`, picks the tab whose url matches `workbench`,
  switches by id) before any eval/`--shot`/`--snapshot`. **Gotcha hit & fixed:** the electron skill
  documents `tab --url "*workbench*"`, but installed agent-browser **0.27.0 has no `--url` filter**
  (tabs select by id/label only) — exit-3 first try; rewrote to jq-parse the JSON list. Also added
  `relaunch.sh --fresh [DIR]` (throwaway `--user-data-dir`, default `C:\arclen-fresh`) — the canonical
  way to verify `configurationDefaults`/`hideByDefault` (an existing profile hides them behind stored
  state), and threaded the same workbench-tab select into relaunch's readiness probe. Validated red
  (cdp.sh exit 2 when app down, exit 64 on bad flag) + green (relaunch --fresh → painted Arclen Dark
  fresh profile, `--vscode-editor-background=#09090b`; cdp.sh → on `t1`, `document.title="Welcome -
  Arclen Dev"`, real workbench screenshot). — mechanism: script + script edit — effort: S
- [x] **Destructive-build guard — anti-edit-loss hook** (2026-05-29) — enforces the CLAUDE.md "Risky
  actions" rule that was advisory-only: `-s` builds run `git add . && git reset -q --hard HEAD` on vscode/
  (dev/build.sh:113-114), silently wiping un-promoted live edits. 3 pieces: (1) PostToolUse
  `arclen-track-edits.sh` records vscode/ source edits to a session ledger `.claude/.live-edits`
  (gitignored); (2) PreToolUse `arclen-guard-destructive.sh` (matcher Bash) DENIES `build*.sh*-s` /
  `git reset --hard` when the ledger is non-empty, with promote + escape-hatch instructions;
  (3) `gen-user-patch.sh` clears promoted files from the ledger. **Key design — avoids crying wolf:** the
  tree is ALWAYS modified (every patch is an uncommitted mod), so `git status` can't tell promoted from
  un-promoted; the ledger tracks only files Claude edited this session → fires precisely. Validated red+green
  (8 tests: tracker records/ignores/dedups, guard denies on -s & reset, ALLOWS on empty ledger & non-destructive
  cmd, ledger clears on promote). The live hook even blocked its own test command — strongest enforcement proof.
  — mechanism: hook×2 + script edit — effort: M
- [x] **`dev/relaunch.sh` (full-relaunch + readiness gate)** (2026-05-29) — kills the dev exe, relaunches
  via a generated `.bat` + `start` (CDP + `VSCODE_SKIP_PRELAUNCH=1`), then BLOCKS until the workbench
  paints (`--vscode-editor-background` resolves on `.monaco-workbench`) before returning. Kills the
  blind-screenshot class (CSS needs a full relaunch, ext host is ~5 min slow). `--probe-only` / `--no-kill`
  / `--shot` / `--assert 'var=substr'` / `--port` / `--timeout`. Validated: probe-only + assert exit 0;
  full kill→launch→gate→assert→shot exit 0 (~35s to ready). First launch impl (nested `cmd /c "...&&..."`)
  failed silently — the `.bat`+`start` form fixed it. — mechanism: script — effort: M
- [x] **`dev/gen-user-patch.sh` (clean user-patch generator)** (2026-05-29) — reconstructs the true
  base+windows+prior-user baseline (pristine via `git show HEAD:` + substituted patch replay scoped with
  `git apply --include`), diffs live edits → a minimal, correctly-anchored patch, validates by re-applying
  onto that baseline. Replaces the by-hand reconstruction done 3× last session. **Gotcha hit & fixed:** the
  working tree has mixed CRLF+LF, so the scratch files must be normalized to LF (`sed 's/\r$//'`) before
  diffing or git reports a full-file rewrite. Validated: dependent-on-arclen-fonts case → +3/-1 minimal
  patch, exit 0. — mechanism: script — effort: M
- [x] **`dev/verify-patches.sh` (Tier 2, safe version)** (2026-05-28) — one pre-commit/pre-promote gate:
  `check-ts.sh` (compile the live tree) + `check-patches.sh` (apply-check vs fresh upstream). Non-destructive.
  `--no-apply` (offline/fast, TS only) / `--no-ts` flags. Validated: TS path green on live tree.
- [x] **Fix `check-patches.sh` cwd bug** (2026-05-28) — absolutize patch paths before the `cd` into the
  scratch clone (was "can't open patch …" from repo root). Also fixed a `grep -h` bug (single-patch-arg
  path stripping). Validated from repo root: 7/7 patches checked.
- [x] **Repaired `arclen-hide-menus.patch` corruption** (2026-05-28) — `verify-patches`/`check-patches`
  caught zero-length context lines (editor stripped trailing space → "corrupt patch at line 8", would
  break the next full build). Restored the space markers; re-verified 7 passed / 0 failed.
- [x] **`dev/check-ts.sh` + `dev/build-checked.sh` (Tier 1)** (2026-05-28) — 25s TS gate before any full
  build + truthful exit (no `tee` masking) + log backstop. Validated red (catches injected TS6133) & green.
- [x] **`arclen-disable-walkthroughs.patch` orphan-import fix** (2026-05-28) — added 3 hunks removing
  registerIcon/NotebookSetting/CONTEXT_ACCESSIBILITY/setupIcon/beginnerIcon/Button; validated via git apply on post-base state.
- [x] **Monitor pattern + tee-masking lessons** documented in `.claude/skills/arclen-dev/SKILL.md`.
