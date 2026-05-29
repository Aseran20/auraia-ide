# Harness backlog — Arclen IDE (project-specific)

Tooling/automation to make Arclen dev faster & less error-prone. Cross-project method items live in
`~/.claude/skills/retro/backlog.md`. The `retro` skill re-reads this at session-retro start.

Format: `- [ ] <fix> — <why / incident> — mechanism — effort: <S/M/L>`

## Open
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
