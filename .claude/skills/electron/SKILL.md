---
name: electron
description: Automate Electron desktop apps (Arclen IDE, VS Code, Slack, Discord, Figma, etc.) using agent-browser via Chrome DevTools Protocol. Use when you need to take screenshots, inspect UI, click elements, or verify visual output of Arclen or any Electron app. Triggers on "screenshot Arclen", "check the UI", "verify my changes", "audit the app", "take a screenshot", "inspect the window", or any task requiring visual verification of the desktop app.
allowed-tools: Bash(agent-browser:*), Bash(npx agent-browser:*)
---

# Electron App Automation — Arclen IDE

Automate Arclen IDE (and any Electron app) using `agent-browser` CLI via Chrome DevTools Protocol (CDP).

## Quick Start — Arclen (validated paths on this machine)

```bash
# OPTION A — QA the packaged distributable (production binary)
"<repo-root>\VSCode-win32-x64\Arclen.exe" --remote-debugging-port=9222

# OPTION B — QA the dev runner (with hot reload via npm run watch)
# In one terminal: cd vscode && npm run watch
# In another:
cmd /c "cd /d <repo-root>\vscode && scripts\code.bat --remote-debugging-port=9222"

# Verify CDP is up
curl -s http://localhost:9222/json/version

# Connect agent-browser (persists for subsequent calls)
agent-browser connect 9222

# Workflow
agent-browser tab                                 # list windows
agent-browser snapshot -i                         # a11y tree with @e refs
agent-browser screenshot dev/arclen-check.png     # visual
agent-browser click @e5                           # interact
```

**Key paths (substitute `<repo-root>` with this machine's actual repo path):**
- Repo root: `<repo-root>\`
- Production exe: `VSCode-win32-x64\Arclen.exe` (capital A)
- Dev runner: `vscode\scripts\code.bat`
- Before launching `code.bat` after a fresh `dev/build.sh`: run `cd vscode && node build/next/index.ts transpile` to populate `vscode/out/` (the dev runner needs `out/main.js` which the production build doesn't create).

## Core Workflow

1. **Launch** the Electron app with `--remote-debugging-port=9222`
2. **Connect** agent-browser to the CDP port
3. **Snapshot** to discover interactive elements (each gets a ref like @e1, @e2)
4. **Interact** using element refs (click, fill, etc.)
5. **Screenshot** to verify visual state
6. **Re-snapshot** after navigation or state changes

## Command reference — load it dynamically

Don't hard-code the command list here; it drifts from the installed CLI. Pull the
always-current Electron workflow from agent-browser itself:

```bash
agent-browser skills get electron     # full command set, templates, troubleshooting
```

The essentials you'll use most (all assume `--cdp 9222`):

```bash
agent-browser connect 9222                     # connect (persists for later calls)
agent-browser --cdp 9222 tab                   # list windows/webviews
agent-browser --cdp 9222 snapshot -i           # a11y tree with @eN refs (text checks)
agent-browser --cdp 9222 screenshot out.png    # visual check
agent-browser --cdp 9222 click @e5             # interact via ref
agent-browser --cdp 9222 press Ctrl+R          # reload (then reconnect — see troubleshooting)
```

## Visual Audit Workflow

After making changes to Arclen (icons, settings, branding):

```bash
# Take screenshot
agent-browser --cdp 9222 screenshot check.png

# Read the image (Claude is multimodal)
# Then compare against expected state

# If something is wrong, fix it directly in:
#   VSCode-win32-x64/resources/app/product.json  (settings)
#   VSCode-win32-x64/                            (icons)
# Then restart Arclen and re-screenshot
```

## Multiple Apps Simultaneously

```bash
agent-browser --session arclen connect 9222
agent-browser --session slack connect 9222

agent-browser --session arclen screenshot arclen.png
agent-browser --session slack screenshot slack.png
```

## Troubleshooting

- **"Connection refused"**: App must be launched with `--remote-debugging-port=9222`. If already running, quit and relaunch.
- **`os error 10060` (timeout) right after `press Ctrl+R`**: the reload drops the CDP socket briefly. Reconnect with `agent-browser connect 9222` before the next call. This is the normal recovery — not a bug. Build it into any reload→screenshot sequence.
- **Elements not found**: Use `agent-browser tab` to list targets, switch to the right webview.
- **Cannot type**: Try `agent-browser keyboard type "text"` or `agent-browser keyboard inserttext "text"`.
- **Dark mode lost**: Set `AGENT_BROWSER_COLOR_SCHEME=dark` before connecting.
