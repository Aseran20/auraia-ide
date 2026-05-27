---
name: electron
description: Automate Electron desktop apps (Arclen IDE, VS Code, Slack, Discord, Figma, etc.) using agent-browser via Chrome DevTools Protocol. Use when you need to take screenshots, inspect UI, click elements, or verify visual output of Arclen or any Electron app. Triggers on "screenshot Arclen", "check the UI", "verify my changes", "audit the app", "take a screenshot", "inspect the window", or any task requiring visual verification of the desktop app.
allowed-tools: Bash(agent-browser:*), Bash(npx agent-browser:*)
---

# Electron App Automation — Arclen IDE

Automate Arclen IDE (and any Electron app) using `agent-browser` CLI via Chrome DevTools Protocol (CDP).

## Quick Start — Arclen

```bash
# 1. Launch Arclen with CDP
"C:\Users\Adrian\Desktop\devprojects\3-auraia\auraia-ide\VSCode-win32-x64\arclen.exe" --remote-debugging-port=9333

# 2. Verify CDP is up
curl -s http://localhost:9333/json/version

# 3. Screenshot
agent-browser --cdp 9333 screenshot arclen-check.png

# 4. Snapshot (accessibility tree — interactive elements)
agent-browser --cdp 9333 snapshot -i

# 5. Click an element
agent-browser --cdp 9333 click @e5
```

## Core Workflow

1. **Launch** the Electron app with `--remote-debugging-port=9333`
2. **Connect** agent-browser to the CDP port
3. **Snapshot** to discover interactive elements (each gets a ref like @e1, @e2)
4. **Interact** using element refs (click, fill, etc.)
5. **Screenshot** to verify visual state
6. **Re-snapshot** after navigation or state changes

## Commands Reference

```bash
# Connect (persists for subsequent commands)
agent-browser connect 9333

# Snapshot — discover UI elements
agent-browser --cdp 9333 snapshot -i

# Screenshot
agent-browser --cdp 9333 screenshot output.png
agent-browser --cdp 9333 screenshot --annotate annotated.png  # numbered element boxes
agent-browser --cdp 9333 screenshot --full full.png           # full page

# Click
agent-browser --cdp 9333 click @e5

# Fill input
agent-browser --cdp 9333 fill @e3 "search query"

# Press key
agent-browser --cdp 9333 press Enter

# Get text from element
agent-browser --cdp 9333 get text @e5

# Tab management (Electron apps have multiple windows/webviews)
agent-browser --cdp 9333 tab                    # list targets
agent-browser --cdp 9333 tab 2                  # switch to tab 2
agent-browser --cdp 9333 tab --url "*settings*" # switch by URL pattern

# Wait
agent-browser --cdp 9333 wait 1000

# Export snapshot as JSON
agent-browser --cdp 9333 snapshot --json > state.json
```

## Visual Audit Workflow

After making changes to Arclen (icons, settings, branding):

```bash
# Take screenshot
agent-browser --cdp 9333 screenshot check.png

# Read the image (Claude is multimodal)
# Then compare against expected state

# If something is wrong, fix it directly in:
#   VSCode-win32-x64/resources/app/product.json  (settings)
#   VSCode-win32-x64/                            (icons)
# Then restart Arclen and re-screenshot
```

## Multiple Apps Simultaneously

```bash
agent-browser --session arclen connect 9333
agent-browser --session slack connect 9222

agent-browser --session arclen screenshot arclen.png
agent-browser --session slack screenshot slack.png
```

## Troubleshooting

- **"Connection refused"**: App must be launched with `--remote-debugging-port=9333`. If already running, quit and relaunch.
- **Elements not found**: Use `agent-browser tab` to list targets, switch to the right webview.
- **Cannot type**: Try `agent-browser keyboard type "text"` or `agent-browser keyboard inserttext "text"`.
- **Dark mode lost**: Set `AGENT_BROWSER_COLOR_SCHEME=dark` before connecting.
