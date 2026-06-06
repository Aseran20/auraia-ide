/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Arclen. All rights reserved.
 *  Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/
// @ts-check
'use strict';

/**
 * Comment read-modify-write — the host half of the cockpit's humain→Claude channel.
 *
 * PARITY CONTRACT: applyCommentOp() is the faithful mirror of apply_post() in
 *   auraia (claude-fs-plugins-testing) .claude/skills/auraia-global-deal-workspace/scripts/cockpit_serve.py
 * The standalone HTTP transport (cockpit_serve.py) and this webview-bridge transport MUST stay
 * behaviourally identical — same ids, same fail-loud 400/404, same comment shape — so a comment
 * captured in either context looks the same in comments.json. Change one, change the other.
 * cockpit_serve.apply_post is unit-tested (test_cockpit_serve.py); this side is tested by
 * comments.test.js (same cases). The two test suites are the parity guard.
 */

const fs = require('fs');

/** Next id `c<N>` (N = max existing numeric suffix + 1). Deterministic, no uuid/random
 *  (testable + stable for re-anchoring). Mirror of cockpit_serve.next_id. */
function nextId(comments) {
	let n = 0;
	for (const c of comments) {
		const cid = String((c && c.id) || '');
		if (cid[0] === 'c' && /^\d+$/.test(cid.slice(1))) {
			n = Math.max(n, parseInt(cid.slice(1), 10));
		}
	}
	return 'c' + (n + 1);
}

/**
 * PURE: apply one bridge comment op to `doc` (mutated in place). Mirror of apply_post,
 * keyed on (op, payload) instead of an HTTP path — the bridge carries the id INSIDE payload.
 * Returns { code, data }: 200 + the comment (or {id,deleted:true}); fail-loud 400 (missing
 * anchor/body on create, empty body on edit, unknown op) or 404 (unknown id) — never a silent
 * success. `now` is injected (ISO seconds) so the op is testable.
 *
 * @param {{comments?: any[]}} doc
 * @param {string} op  one of create | resolve | edit | delete
 * @param {Record<string, any>} payload
 * @param {string} now
 * @returns {{code: number, data: any}}
 */
function applyCommentOp(doc, op, payload, now) {
	payload = payload || {};
	const comments = doc.comments || (doc.comments = []);

	if (op === 'resolve' || op === 'edit' || op === 'delete') {
		const id = String(payload.id == null ? '' : payload.id);
		const i = comments.findIndex(c => String(c.id) === id);
		if (i === -1) {
			return { code: 404, data: { error: `comment ${id} introuvable` } };
		}
		const c = comments[i];
		if (op === 'resolve') {
			c.resolved = true;
			return { code: 200, data: c };
		}
		if (op === 'delete') {                 // retire le commentaire (destructif, demandé)
			comments.splice(i, 1);
			return { code: 200, data: { id, deleted: true } };
		}
		const nb = String(payload.body || '').trim();   // edit : remplace le corps, horodate
		if (!nb) {
			return { code: 400, data: { error: 'body requis' } };
		}
		c.body = nb;
		c.edited = now;
		return { code: 200, data: c };
	}

	if (op !== 'create') {                     // op inconnue → fail-loud (jamais un no-op silencieux)
		return { code: 400, data: { error: `op inconnue: ${op}` } };
	}

	const anchor = payload.anchor;
	const body = String(payload.body || '').trim();
	if (!anchor || !body) {
		return { code: 400, data: { error: 'anchor et body requis' } };
	}
	const c = {
		id: nextId(comments), anchor, body,
		author: payload.author || 'Adrian', created: now, resolved: false
	};
	const q = payload.quote || {};
	if (q.exact) {
		c.quote = { exact: q.exact || '', prefix: q.prefix || '', suffix: q.suffix || '' };
	}
	comments.push(c);
	return { code: 200, data: c };
}

/** Load comments.json → doc. Missing file → empty doc (first comment of a deal). Invalid JSON
 *  THROWS (fail-loud — never overwrite a corrupt file). Mirror of cockpit_serve._load. */
function loadDoc(file) {
	try {
		return JSON.parse(fs.readFileSync(file, 'utf8'));
	} catch (e) {
		if (e && e.code === 'ENOENT') {
			return { comments: [] };
		}
		throw e;
	}
}

/** Atomic save (tmp + rename on same volume) — never a half-written comments.json.
 *  Mirror of cockpit_serve._save. */
function saveDoc(file, doc) {
	const tmp = file + '.tmp';
	fs.writeFileSync(tmp, JSON.stringify(doc, null, 2), 'utf8');
	fs.renameSync(tmp, file);
}

/** Local-time ISO to seconds — parity with Python datetime.now().isoformat(timespec='seconds'). */
function nowIso() {
	const d = new Date();
	const p = n => String(n).padStart(2, '0');
	return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T` +
		`${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
}

module.exports = { nextId, applyCommentOp, loadDoc, saveDoc, nowIso };
