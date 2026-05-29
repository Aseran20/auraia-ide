# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is (and isn't)

**Arclen IDE** is a rebranded VSCodium fork targeting **M&A / finance / consulting analysts — not coders**. The product goal is a Claude Code orchestration cockpit; "scary developer stuff" gets removed or hidden, agent-direction and deliverable management are elevated. The sibling repo (separate) automates PowerPoint/Excel via COM.

The upstream `README.md` is unmodified VSCodium boilerplate — **not** an Arclen description. Ignore it for context; the authoritative project knowledge is in the two skills (below).

## Where the real knowledge lives — read the skills first

Two project skills auto-trigger and are the source of truth:

- **`.claude/skills/arclen-ide/SKILL.md`** — **WHAT / WHERE**: repo structure, branding pipeline (`branding.sh` → `apply_branding.sh`), icon generation, Windows build prerequisites (VS 2022 + Spectre v143 — **not** VS 2026), M&A-tuned defaults, what can be modified *without* a rebuild vs what needs a patch, the patch health check.
- **`.claude/skills/arclen-dev/SKILL.md`** — **HOW**: the validated dev iteration loop, generating clean user patches (plain `git diff` does NOT work — explained below), the cascade-delete pattern, the CRLF/Edit gotcha, QA scripts, monitor patterns for builds, theming & fonts, resuming a broken build.

Also: **`.claude/harness-backlog.md`** — project-level harness backlog (open / done / dropped, with rationale). Check it before proposing a new gate; the wrong version may already be dropped.

## Build pipeline — the macro architecture

This is a VSCodium-style **script-driven build**, not an in-repo source tree:

1. `branding.sh` holds every brand value (name, IDs, URLs). `apply_branding.sh` propagates them into `dev/build.sh`, `prepare_vscode.sh`, CI workflow. **Never hand-edit those targets** — edit `branding.sh` and rerun the propagator.
2. `dev/build.sh` clones Microsoft `vscode` at the commit pinned by `upstream/stable.json` into `./vscode/` (gitignored), then calls `prepare_vscode.sh`.
3. `prepare_vscode.sh` writes product fields, then applies patches in **strict order**:
   `patches/*.patch` (base) → `patches/<os>/*.patch` (windows here) → `patches/user/*.patch` (Arclen). It copies `src/stable/*` overlays before compile.
4. `utils.sh::apply_patch` substitutes placeholders (`!!APP_NAME!!`, `!!BINARY_NAME!!`, etc.) into each patch *before* `git apply`. So patch context lines should use placeholders, not literal `Arclen`.
5. `build.sh` (root) drives the gulp build: `vscode-min-prepack` → `vscode-win32-x64-min-packing`. Output lands in `VSCode-win32-x64/`.

**Consequence — the trap that bites everyone:** because patches are applied as **uncommitted modifications** on top of the pristine upstream baseline in `vscode/`, a plain `cd vscode && git diff` returns *base + windows + prior user patches + your live edits, mixed together*. **It does NOT produce a clean user patch.** Use `dev/gen-user-patch.sh` (the runbook explains why and how it reconstructs the correct pre-state).

**Two artifacts, different purposes**: `vscode/` is for **iteration** (transpile → Ctrl+R). `VSCode-win32-x64/Arclen.exe` is for **distribution smoke-tests**. You almost never need the `.exe` during dev.

## Local-only philosophy

CI is **only** for producing a distributable `.exe`. Never push to master to test a build. The lightweight `.github/workflows/check-patches.yml` (push on `patches/`) is fine — it's a ~1 min guard.

## Validation gates — what to run, in what order

Cheap, deterministic gates exist precisely because the full build is ~10–16 min:

| Gate | Script | Cost | What it catches |
|---|---|---|---|
| Patch apply check | `check-patches.sh` | ~30–60 s | Patch context drift vs upstream (downloads only the touched files). |
| TS compile gate | `dev/check-ts.sh` | ~25–70 s | `noUnusedLocals` (TS6133), missing imports, type errors — the class that silently kills `vscode-min-prepack` at minute ~16. |
| Combined pre-commit gate | `dev/verify-patches.sh` | ~1–2 min | TS + apply-check together. Non-destructive. `--no-apply` for offline/fast TS-only. |
| Brand-leak scan | `dev/check-brand-leaks.sh [--strict]` | ~5 s | VSCodium/MS branding left in renderer / l10n. Also wired as a PostToolUse hook. |
| Truthful full build | `dev/build-checked.sh [-s]` | ~10–16 min | Runs `check-ts` first (aborts cheap), then build with `pipefail` + log backstop (raw `\| tee` masks exit code). |
| QA chain | `dev/qa-loop.sh [label]` | ~40 s | tscheck → transpile → Ctrl+R → screenshot → brand-leaks. |
| Full relaunch (CSS/theme/product.json) | `dev/relaunch.sh` | ~30–45 s | Ctrl+R does NOT re-read CSS. This kills, relaunches with CDP, blocks until paint, then screenshots — so the verify isn't blind. |

**Always run a cheap gate before the expensive one.** `check-ts.sh` before any `-s` build. `verify-patches.sh` before commit. The skills explain why each step exists.

## Iteration loop — the very short version (full details in `arclen-dev`)

`npm run watch` is a **no-op** here (`useEsbuildTranspile=false`). The real emit is one-shot:

```bash
cd vscode && node build/next/index.ts transpile   # ~10s, src/ → out/
```

Then reload via `agent-browser` on CDP 9222 (`Ctrl+R`). **CSS/theme/font/product.json changes need a full relaunch via `dev/relaunch.sh`**, not Ctrl+R.

## Theming — single source of truth

All theme colours + font defaults live in **`branding/arclen-tokens.json`**. `dev/gen-arclen-theme.mjs` expands token refs and writes the theme JSON, the startup splash colours (`arclenInitialColors.ts`), and the `product.json` font defaults. **Never hand-edit the generated files** — edit tokens, regenerate, mirror into `vscode/`, relaunch.

## Environment specifics (Windows)

- **Git Bash path matters.** Bare `bash` may resolve to WSL (cannot run the Windows build). Resolve with `Test-Path` against `$env:LOCALAPPDATA\Programs\Git\bin\bash.exe` (user install) and `C:\Program Files\Git\bin\bash.exe` (system install) and use whichever exists. The skills assume you've done this.
- **Bash tool ≠ Windows Bash.** The Bash tool runs under WSL — do not use it to invoke `C:\...\bash.exe`. Use the PowerShell tool with `run_in_background: true` to launch builds, and `Read` on `build.log` to follow.
- **Long builds → arm a `Monitor` on `build.log` at launch.** Match the *terminal-state summary* (`Finished compilation with [1-9]`, `errored after`, OOM), **not** mid-run noise (`gyp ERR`, `MSB3491` — those get retried).
- **CRLF/LF mixed in `vscode/src/`.** Some files have stray `\r` mid-line; `Edit` may report "string not found" on a string you can see in `Read`. Diagnose with `sed -n 'Np' file | cat -A`. The skill documents the fallbacks.
- **Python:** 3.13 works (VS Code 1.121.0 uses node-gyp ≥10). No need to downgrade to 3.11 unless build fails.
- **node-gyp + electron-rebuild caches** (`%LOCALAPPDATA%\node-gyp`, `%USERPROFILE%\.electron-gyp`) — **never delete**; they save ~2–3 min per native rebuild.

## What NOT to do

- Do not commit `vscode/`. It is gitignored and regenerable from `patches/` + `src/stable/`. Modules under `vscode/node_modules/` are compiled for this machine and don't transport across PCs.
- Do not produce user patches with `cd vscode && git diff`. Use `dev/gen-user-patch.sh`.
- Do not re-run `dev/build.sh` after a mid-compile failure — resume the gulp step directly (see `arclen-dev`).
- Do not trust the build's exit code under a raw `| tee` pipeline — `tee` masks it. Use `dev/build-checked.sh`, or read `build.log` for the terminal-state line.
- Do not trigger `ci-build-windows.yml` for development. Local-only.
- Do not install VS 2026; node-gyp 11.x can't detect it.

## Risky actions — confirm before doing

`-s` builds run `git reset --hard` on `vscode/`, which **wipes any un-promoted live edits there**. Before any sync/reset operation, check whether unsaved patch work exists in `vscode/` and promote it via `dev/gen-user-patch.sh` first.
