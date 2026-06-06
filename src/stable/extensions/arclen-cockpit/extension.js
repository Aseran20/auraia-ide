/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Arclen. All rights reserved.
 *  Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/
// @ts-check
'use strict';

/**
 * Arclen Cockpit — hosts the per-deal control tower (an HTML page built by build_cockpit_view.py)
 * in a VS Code webview, and implements the HOST side of the comment write bridge.
 *
 * The page (cockpit.js, already shipped in the auraia repo) calls acquireVsCodeApi() and posts
 *   { type:'cockpit:comment', op, reqId, payload }     op ∈ create|resolve|edit|delete
 * We answer
 *   { type:'cockpit:comment:result', reqId, ok, data|error }
 * The page captures comments identically across all transports (file:// inert, http: fetch,
 * this bridge) — only persistence differs. The write logic mirrors cockpit_serve.apply_post
 * (see comments.js PARITY CONTRACT). The page is built self-contained (scripts/styles/fonts
 * inlined, themed with var(--vscode-*)), so we just read it and set webview.html — no asWebviewUri.
 *
 * Plain JS on purpose: built-in extensions are NOT compiled in the Arclen dev tree, so a
 * main → out/extension.js would throw "Cannot find module" on Ctrl+R. extension.js loads directly.
 */

const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
const { applyCommentOp, loadDoc, saveDoc, nowIso } = require('./comments');

/** @type {vscode.WebviewPanel | undefined} */
let panel;
/** comments.json bound to the panel's current deal (updated on each open). */
let commentsFile;
/** the panel's current cockpit dir — a deal switch needs a fresh panel (localResourceRoots is immutable). */
let currentDir;

/** Find the cockpit page(s) in the open workspace. Cockpit builds land at <cockpit>/_view/index.html. */
async function pickCockpitHtml() {
	const hits = await vscode.workspace.findFiles('**/_view/index.html', '**/node_modules/**', 20);
	if (hits.length === 0) { return undefined; }
	if (hits.length === 1) { return hits[0]; }
	const items = hits.map(u => ({ label: vscode.workspace.asRelativePath(u), uri: u }));
	const pick = await vscode.window.showQuickPick(items, { placeHolder: 'Quel cockpit ouvrir ?' });
	return pick && pick.uri;
}

/** The generated page ships no CSP; the webview wants one. 'unsafe-inline' because the page's
 *  scripts/styles are inlined without nonces (trusted local deal content, sandboxed webview). */
function injectCsp(webview, html) {
	const csp = `<meta http-equiv="Content-Security-Policy" content="default-src 'none'; ` +
		`img-src ${webview.cspSource} https: data:; style-src ${webview.cspSource} 'unsafe-inline'; ` +
		`font-src ${webview.cspSource} data:; script-src ${webview.cspSource} 'unsafe-inline';">`;
	return html.replace('<head>', '<head>' + csp);
}

/** Bridge message handler. Single-threaded event loop → the sync read-modify-write is atomic
 *  w.r.t. other messages (no lock needed, unlike the multi-threaded HTTP server). */
function handleMessage(msg) {
	if (!msg || msg.type !== 'cockpit:comment' || !msg.reqId) { return; }
	const reply = (ok, body) => {
		if (!panel) { return; }
		const m = { type: 'cockpit:comment:result', reqId: msg.reqId, ok };
		if (ok) { m.data = body; } else { m.error = body; }
		panel.webview.postMessage(m);
	};
	try {
		const doc = loadDoc(commentsFile);
		const { code, data } = applyCommentOp(doc, msg.op, msg.payload, nowIso());
		if (code === 200) {
			saveDoc(commentsFile, doc);
			reply(true, data);
		} else {
			reply(false, (data && data.error) || 'erreur');
		}
	} catch (e) {
		reply(false, String((e && e.message) || e));   // jamais un échec silencieux
	}
}

async function openCockpit(context) {
	const htmlUri = await pickCockpitHtml();
	if (!htmlUri) {
		vscode.window.showWarningMessage(
			'Arclen Cockpit : aucun cockpit (…/_view/index.html) dans le workspace — lancer build_cockpit_view.py d\'abord.');
		return;
	}
	const htmlPath = htmlUri.fsPath;
	const cockpitDir = path.dirname(path.dirname(htmlPath));   // _view/ → 0. Cockpit/
	commentsFile = path.join(cockpitDir, 'comments.json');

	if (panel && currentDir !== cockpitDir) {                  // deal switch → fresh panel (resource root)
		panel.dispose();
		panel = undefined;
	}
	currentDir = cockpitDir;

	if (!panel) {
		panel = vscode.window.createWebviewPanel(
			'arclenCockpit', 'Cockpit', vscode.ViewColumn.One,
			{
				enableScripts: true,
				retainContextWhenHidden: true,                 // garde l'état (scroll, commentaires ouverts) au switch d'onglet
				localResourceRoots: [vscode.Uri.file(cockpitDir)]
			});
		panel.onDidDispose(() => { panel = undefined; }, null, context.subscriptions);
		panel.webview.onDidReceiveMessage(handleMessage, null, context.subscriptions);
	} else {
		panel.reveal(vscode.ViewColumn.One);
	}

	const html = fs.readFileSync(htmlPath, 'utf8');
	const titleMatch = html.match(/<title>(.*?)<\/title>/i);   // réutilise le titre du build (porte le nom du deal)
	panel.title = titleMatch ? titleMatch[1] : 'Cockpit';
	panel.webview.html = injectCsp(panel.webview, html);
}

function activate(context) {
	context.subscriptions.push(
		vscode.commands.registerCommand('arclen-cockpit.open', () => openCockpit(context)));
}

function deactivate() { }

module.exports = { activate, deactivate };
