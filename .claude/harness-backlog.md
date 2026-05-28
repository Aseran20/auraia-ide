# Harness backlog — Arclen IDE (project-specific)

Tooling/automation to make Arclen dev faster & less error-prone. Cross-project method items live in
`~/.claude/skills/retro/backlog.md`. The `retro` skill re-reads this at session-retro start.

Format: `- [ ] <fix> — <why / incident> — mechanism — effort: <S/M/L>`

## Open

_(none — all triaged 2026-05-28; next harness work returns from the M&A roadmap)_

## Dropped
- **PostToolUse orphan-import hook (was Tier 3)** — dropped 2026-05-28: redundant with `check-ts.sh`,
  which catches the same noUnusedLocals/orphan-import class authoritatively (and `verify-patches.sh`
  now runs it as a gate). A grep heuristic would only add false positives for no extra coverage.
- **`dev/sync-and-check.sh` destructive reset variant (was Tier 2)** — dropped 2026-05-28 in favor of
  the non-destructive `verify-patches.sh` below. A `git reset --hard` on `vscode/` would wipe un-promoted
  live edits (everything in `vscode/` is an uncommitted mod vs the pristine baseline), and `check-ts.sh`
  already TS-checks the live tree — which is what actually catches the incident. Not worth the footgun.

## Done
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
