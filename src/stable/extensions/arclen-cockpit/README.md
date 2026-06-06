# arclen-cockpit

Built-in extension. Hosts the per-deal **cockpit** (the M&A control tower) in a VS Code webview and
implements the **host side of the comment write bridge** (the humain→Claude channel).

## What it does

- Command **`Arclen: Open Deal Cockpit`** (`arclen-cockpit.open`) finds `…/_view/index.html` in the
  open workspace (the page built by `build_cockpit_view.py` in the sibling auraia repo), opens it in
  an editor-area `WebviewPanel`, and binds the deal's `comments.json` (sibling of the page's `_view/`).
- The page is built **self-contained** (scripts/styles/fonts inlined, themed with `var(--vscode-*)`),
  so we read it and set `webview.html` directly — no `asWebviewUri`. We inject a CSP (the build ships
  none) with `'unsafe-inline'` (the page's inline scripts carry no nonce; content is trusted local
  deal data in a sandboxed webview).
- **Comment bridge** — the page (`cockpit.js`) posts
  `{ type:'cockpit:comment', op, reqId, payload }` (`op ∈ create|resolve|edit|delete`); we answer
  `{ type:'cockpit:comment:result', reqId, ok, data|error }`, read-modify-writing `comments.json`.

## Parity contract (do not drift)

`comments.js::applyCommentOp` is the **faithful mirror** of `apply_post()` in the auraia repo
(`.claude/skills/auraia-global-deal-workspace/scripts/cockpit_serve.py`). The standalone HTTP
transport and this webview-bridge transport must stay behaviourally identical (same ids, same
fail-loud 400/404, same comment shape). `comments.test.js` mirrors `test_cockpit_serve.py`.
**Change one side → change the other, and run both test suites.**

## Verify

```bash
# pure parity test (no vscode, no socket)
node comments.test.js          # exit 0 = green
node --check extension.js       # syntax

# in-Arclen (dev loop): plain JS → no compile step needed
cp -r src/stable/extensions/arclen-cockpit vscode/extensions/
# Ctrl+R via agent-browser (CDP 9222), then Command Palette → "Arclen: Open Deal Cockpit"
```

Plain JS on purpose: built-in extensions are **not** compiled in the Arclen dev tree, so a
`main → out/extension.js` would throw "Cannot find module" on reload. `extension.js` loads directly.

## Deferred (not in this MVP)

- **Auto-open** the cockpit as the Arclen home/welcome surface (today: command-launched panel).
- **Phase C** as-built thumbnails — once a deal slide is `build:"built"` and exports a PNG, the
  cockpit will render `<img>`; `localResourceRoots` is already scoped to the cockpit dir for that.
