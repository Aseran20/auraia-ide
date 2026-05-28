#!/usr/bin/env node
/**
 * Arclen theme generator — SINGLE SOURCE OF TRUTH workflow.
 *
 * Edit colours/fonts in  branding/arclen-tokens.json  (the palette is the source),
 * then run:   node dev/gen-arclen-theme.mjs
 *
 * It regenerates, from that one file:
 *   1. src/stable/extensions/theme-arclen/themes/arclen-dark.json   (the colour theme)
 *   2. src/stable/src/vs/workbench/services/themes/common/arclenInitialColors.ts
 *        (the pre-extension-load "splash" colours — a subset of the theme, so the two
 *         can never drift; arclen-theme-default.patch wires VS Code to import it)
 *   3. product.json  configurationDefaults font-family values (targeted, in place)
 *
 * Generated files carry a "do not edit" marker. Re-run after any token change.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const TOKENS = JSON.parse(fs.readFileSync(path.join(ROOT, 'branding/arclen-tokens.json'), 'utf8'));
const PALETTE = TOKENS.palette;

const GEN_NOTE = 'Generated from branding/arclen-tokens.json by dev/gen-arclen-theme.mjs — do not edit by hand.';

/** Resolve a token ref ("$accent" or "$accent/26") or pass through a literal "#rrggbb". */
function expand(ref) {
	if (typeof ref !== 'string' || ref[0] !== '$') return ref;
	const [name, alpha] = ref.slice(1).split('/');
	const hex = PALETTE[name];
	if (!hex) throw new Error(`Unknown token "$${name}" — add it to palette in arclen-tokens.json`);
	return alpha ? hex + alpha : hex;
}

function expandColors(obj) {
	const out = {};
	for (const [k, v] of Object.entries(obj)) out[k] = expand(v);
	return out;
}

// ---- 1. theme JSON ----------------------------------------------------------
const t = TOKENS.theme;
const colors = expandColors(t.workbench);
const theme = {
	$schema: 'vscode://schemas/color-theme',
	_generated: GEN_NOTE,
	name: TOKENS.themeName,
	type: t.type,
	semanticHighlighting: t.semanticHighlighting,
	colors,
	tokenColors: t.tokenColors.map(tc => {
		const settings = { ...tc.settings };
		if (settings.foreground) settings.foreground = expand(settings.foreground);
		return { scope: tc.scope, settings };
	}),
	semanticTokenColors: Object.fromEntries(Object.entries(t.semanticTokenColors).map(([k, v]) => {
		if (typeof v === 'string') return [k, expand(v)];
		if (v && typeof v === 'object' && v.foreground) return [k, { ...v, foreground: expand(v.foreground) }];
		return [k, v];
	})),
};
const themePath = path.join(ROOT, 'src/stable/extensions/theme-arclen/themes/arclen-dark.json');
fs.writeFileSync(themePath, JSON.stringify(theme, null, '\t') + '\n');

// ---- 2. splash colours (.ts), a strict subset of the theme ------------------
const initial = {};
for (const key of TOKENS.initialColorKeys) {
	if (!(key in colors)) throw new Error(`initialColorKeys lists "${key}" but it is not in theme.workbench`);
	initial[key] = colors[key];
}
const tsHeader =
`/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

// ${GEN_NOTE}
// Pre-extension-load colours for the default dark theme (Arclen Dark). Kept in sync with the
// theme by construction — both come from branding/arclen-tokens.json.

export const COLOR_THEME_DARK_INITIAL_COLORS = ${JSON.stringify(initial, null, '\t')};
`;
const tsPath = path.join(ROOT, 'src/stable/src/vs/workbench/services/themes/common/arclenInitialColors.ts');
fs.mkdirSync(path.dirname(tsPath), { recursive: true });
fs.writeFileSync(tsPath, tsHeader);

// ---- 3. product.json font defaults (targeted in-place replace) --------------
const productPath = path.join(ROOT, 'product.json');
let product = fs.readFileSync(productPath, 'utf8');
const fontKeys = {
	'editor.fontFamily': TOKENS.fonts.editorFontFamily,
	'terminal.integrated.fontFamily': TOKENS.fonts.terminalFontFamily,
	'markdown.preview.fontFamily': TOKENS.fonts.markdownPreviewFontFamily,
	'chat.editor.fontFamily': TOKENS.fonts.chatEditorFontFamily,
};
let fontUpdates = 0;
for (const [key, val] of Object.entries(fontKeys)) {
	const re = new RegExp(`("${key.replace(/[.]/g, '\\.')}"\\s*:\\s*)"[^"]*"`);
	if (re.test(product)) {
		const next = product.replace(re, `$1${JSON.stringify(val)}`);
		if (next !== product) { product = next; fontUpdates++; }
	}
}
if (fontUpdates) fs.writeFileSync(productPath, product);

console.log(`arclen theme generated:`);
console.log(`  theme   : ${Object.keys(colors).length} colours, ${theme.tokenColors.length} token rules`);
console.log(`  splash  : ${Object.keys(initial).length} colours -> ${path.relative(ROOT, tsPath)}`);
console.log(`  product : ${fontUpdates} font default(s) synced`);
console.log(`Note: font *family* names (IBM Plex Sans/Mono) also live in patches/user/arclen-fonts.patch`);
console.log(`      (style.css + fonts.ts) and the woff2 in src/stable/.../arclen-fonts/. Swapping the`);
console.log(`      whole font family means updating those too.`);
