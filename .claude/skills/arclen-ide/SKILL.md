---
name: arclen-ide
description: Build, customize, and audit Arclen IDE — a rebranded VS Code fork for M&A analysts. Use this skill whenever working on Arclen IDE branding, icons, settings, patches, building the app, or verifying changes visually. Triggers on "build Arclen", "rebuild", "change the logo", "update branding", "check the UI", "screenshot Arclen", "modify settings", "add a patch", "customize the welcome page", "hide a menu", or any task involving the Arclen IDE build pipeline, branding, or visual audit. Also use proactively after making any change to the build source to verify the result visually.
---

# Arclen IDE — Build, Customize & Audit

Arclen IDE is a rebranded VSCodium fork targeting M&A analysts. This skill covers the full lifecycle: branding, building, patching the VS Code source, modifying the build output without recompiling, and auditing changes visually.

## Repo Structure

```
arclen-ide/
├── branding.sh              # Single source of truth for all brand values
├── apply_branding.sh        # Reads branding.sh, patches all build files
├── product.json             # Deep-merged into VS Code's product.json (includes configurationDefaults)
├── prepare_vscode.sh        # Sets product fields, applies patches, runs build
├── dev/build.sh             # Entry point for local builds
├── logos/                   # SVG source files (favicon + full logo, black/white variants)
├── patches/user/            # User patches applied LAST during build (our customizations)
├── src/stable/              # Icon overrides (ICO, PNG) copied into VS Code before compile
├── vscode/                  # Cloned VS Code source (created during build, gitignored)
├── VSCode-win32-x64/        # Build output (the runnable app)
│   ├── arclen.exe
│   └── resources/app/
│       ├── product.json     # The LIVE product.json (editable without rebuild)
│       └── out/nls.messages.json  # UI strings (editable without rebuild)
└── .claude/skills/          # Skills for Claude Code
```

## Branding — How to Change Names, URLs, IDs

All branding is centralized in `branding.sh`. Never edit build files directly.

1. Edit `branding.sh` (name, binary name, URLs, etc.)
2. Run `bash apply_branding.sh` — propagates to dev/build.sh, prepare_vscode.sh, CI workflow
3. Build (or modify the build output directly for quick iteration)

The Windows installer GUIDs in branding.sh were generated once and must never change — they identify Arclen to Windows.

## Icons — Generating with Proper Transparency

The source SVG is `logos/arclen-favicon-white-180x180.svg` (black circle, white triangle, transparent background outside the circle).

The critical flag when converting SVG to ICO/PNG is `-background none`. Without it, ImageMagick fills the transparent area with white, causing the ugly white square in the taskbar.

```bash
# Correct way to generate icons
magick -background none -density 384 logos/arclen-favicon-white-180x180.svg \
  -define icon:auto-resize=256,128,64,48,32,24,16 src/stable/resources/win32/code.ico

# Tile PNGs (also need -background none)
magick -background none -density 384 logos/arclen-favicon-white-180x180.svg \
  -resize 70x70 "PNG32:src/stable/resources/win32/code_70x70.png"

# Server icons
magick -background none -density 384 logos/arclen-favicon-white-180x180.svg \
  -resize 192x192 "PNG32:src/stable/resources/server/code-192.png"
```

After generating, update the .exe icon with rcedit (only needed if skipping a full rebuild):
```bash
rcedit "VSCode-win32-x64/arclen.exe" --set-icon src/stable/resources/win32/code.ico
```

## Building

### Prerequisites (Windows)

| Tool | Version | Why |
|------|---------|-----|
| Git Bash | Latest | Build scripts are POSIX bash |
| Node.js | 22.x | Must match VS Code's .nvmrc |
| npm | < 11.2.0 | VS Code requires this; `npm install -g npm@11.1.0` |
| Python | 3.11 | node-gyp needs it; 3.12+ may break |
| Rust/Cargo | Latest stable | Native modules |
| VS Build Tools 2022 | With C++ workload | node-gyp compilation |
| Spectre-mitigated libs | v143 x64 | Required by VS Code's .vcxproj (install via VS Installer GUI → Individual Components → search "Spectre") |
| ImageMagick | 7.x | Icon generation |
| jq | Latest | JSON manipulation in build scripts |

### Build Commands

```bash
# Full build (first time, ~30-60 min)
cd arclen-ide
"C:\Program Files\Git\bin\bash.exe" ./dev/build.sh

# Rebuild reusing existing source (~10-15 min)
"C:\Program Files\Git\bin\bash.exe" ./dev/build.sh -s

# The -s flag skips cloning VS Code — reuses the existing vscode/ folder.
# Use it after branding/patch/icon changes. Only do a full build when
# updating to a new VS Code upstream version.
```

### CI Build (GitHub Actions)

The CI workflow at `.github/workflows/ci-build-windows.yml` does the same thing on GitHub's runners. Push to master → CI builds → download the artifact. Useful when you don't want to build locally.

```bash
# Trigger CI manually
gh workflow run "CI - Build - Windows" --repo Aseran20/auraia-ide --ref master

# Check status
gh run list --repo Aseran20/auraia-ide --limit 3

# Download artifact when done
gh run download <run-id> --repo Aseran20/auraia-ide
```

## Modifying WITHOUT Rebuild

Many changes can be applied directly to the build output (`VSCode-win32-x64/`). This is instant — no 15-minute rebuild needed.

### What you CAN change without rebuild

| Change | How |
|--------|-----|
| Default settings | Edit `VSCode-win32-x64/resources/app/product.json` → `configurationDefaults` |
| UI strings (tagline, labels) | Edit `VSCode-win32-x64/resources/app/out/nls.messages.json` |
| ICO/PNG icons in resources | Replace files in `VSCode-win32-x64/resources/app/resources/win32/` |
| .exe icon (taskbar) | `rcedit VSCode-win32-x64/arclen.exe --set-icon new.ico` |
| Disable update feed | Set `"updateUrl": ""` in product.json |
| Disable walkthroughs | Set `"workbench.welcomePage.walkthroughs.openOnInstall": false` |

After editing the build output product.json, delete the user data folder so fresh defaults apply:
```powershell
Remove-Item "$env:APPDATA\Arclen" -Recurse -Force
```

### What REQUIRES a rebuild

| Change | Why |
|--------|-----|
| Hide menu items (e.g., Run menu) | Hardcoded in TypeScript source → needs a patch |
| Remove Welcome page entries (Clone Git, Connect to...) | Hardcoded in source |
| Change activity bar default views | View registration is in source |
| Change the tagline permanently | Source has the string; nls.messages.json is regenerated on rebuild |

For these, create patches in `patches/user/` (see below).

## User Patches

Patches in `patches/user/` are applied LAST during the build, after VSCodium's own patches. They modify the VS Code source before compilation.

Current patches:
- `arclen-hide-run-menu.patch` — Removes "Run" from menu bar + adds hideIfEmpty to Debug sidebar
- `arclen-hide-menus.patch` — Removes Selection, View, Go, Help menus (keeps File, Edit, Terminal)
- `arclen-welcome-cleanup.patch` — Removes Clone Git/Connect to.../Open Repository from Welcome page + changes tagline

### Creating a new patch

1. Make sure `vscode/` exists (from a previous build with `-s`)
2. Edit the source file in `vscode/src/...`
3. Generate the patch: `cd vscode && git diff -- path/to/file.ts > ../patches/user/arclen-my-change.patch`
4. Revert: `git checkout -- path/to/file.ts`
5. Test: `git apply --check ../patches/user/arclen-my-change.patch`

Patches must apply cleanly against the current VS Code version pinned in `upstream/stable.json`.

## Visual Audit — Verifying Changes

After any change (rebuild, icon swap, settings edit), verify visually using `agent-browser`. This catches issues that code review can't: wrong icons, broken layouts, missing text.

### The audit loop

```bash
# 1. Kill existing instances and launch with CDP
Get-Process -Name "arclen" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process "VSCode-win32-x64\arclen.exe" -ArgumentList "--remote-debugging-port=9333"
Start-Sleep -Seconds 5

# 2. Read the UI content (more useful than screenshot for checking text/menus)
agent-browser --cdp 9333 snapshot

# 3. Screenshot for visual checks (icons, layout, colors)
agent-browser --cdp 9333 screenshot arclen-check.png
```

### Snapshot vs Screenshot

**Use `snapshot` (accessibility tree) when checking:**
- Menu items present/absent (File, Edit, View, Go, Run...)
- Activity bar items (Explorer, Search, Source Control, Extensions...)
- Welcome page text content (tagline, Start entries, walkthroughs)
- Button labels, status bar content
- Any text-based verification

**Use `screenshot` (image) when checking:**
- Icons (favicon, activity bar icons, logo)
- Colors and theming
- Layout and spacing
- Visual regressions

Always snapshot first — it's faster, more reliable for text checks, and gives you element refs (@e1, @e2...) for interaction.

### Fresh-state testing

To test with clean defaults (as a new user would see it):
```powershell
# Delete user data
Remove-Item "$env:APPDATA\Arclen" -Recurse -Force
# Then relaunch Arclen
```

## M&A-Specific Defaults

The `configurationDefaults` in product.json are tuned for M&A analysts, not developers:
- No minimap, no line numbers, no bracket guides, no code suggestions
- Word wrap on, font size 14
- Debug/testing panels hidden
- Telemetry off, auto-update off
- Git decorations and action buttons hidden (git works via Claude in terminal)
- Walkthroughs disabled

## Common Pitfalls

1. **Icons have white square background** → Regenerate with `-background none` in the magick command
2. **Build fails on Spectre libs** → Install via VS Installer GUI: Individual Components → search "Spectre" → check MSVC v143 x64
3. **Build fails on npm version** → VS Code requires npm < 11.2.0: `npm install -g npm@11.1.0`
4. **Build fails on Python** → node-gyp needs Python 3.11 specifically
5. **Settings don't apply** → Delete `$env:APPDATA\Arclen` to clear cached profile
6. **nls.messages.json changes lost after rebuild** → Put text changes in a patch instead
7. **Patch doesn't apply** → Generate patches with `git diff` from within the `vscode/` dir, not by hand
