/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Arclen. All rights reserved.
 *  Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/
// @ts-check
'use strict';

/**
 * Parity guard for the comment bridge. Mirrors the cases of test_cockpit_serve.py in the auraia
 * repo (apply_post) so this host transport and the HTTP transport stay behaviourally identical.
 * Pure (no vscode, no socket): run with `node comments.test.js` — exit 0 = green.
 */

const assert = require('assert');
const { nextId, applyCommentOp } = require('./comments');

const NOW = '2026-06-06T12:00:00';
let n = 0;
const ok = (name, fn) => { fn(); n++; console.log('  ok  ' + name); };

ok('nextId: empty → c1', () => assert.strictEqual(nextId([]), 'c1'));
ok('nextId: max suffix + 1', () =>
	assert.strictEqual(nextId([{ id: 'c1' }, { id: 'c7' }, { id: 'c3' }]), 'c8'));
ok('nextId: ignores non-c ids', () =>
	assert.strictEqual(nextId([{ id: 'x9' }, { id: 'c2' }]), 'c3'));

ok('create: assigns id + shape, returns 200', () => {
	const doc = { comments: [] };
	const { code, data } = applyCommentOp(doc, 'create', { anchor: 'node:portrait', body: 'Vérifier le CA' }, NOW);
	assert.strictEqual(code, 200);
	assert.strictEqual(data.id, 'c1');
	assert.strictEqual(data.anchor, 'node:portrait');
	assert.strictEqual(data.author, 'Adrian');     // défaut
	assert.strictEqual(data.resolved, false);
	assert.strictEqual(data.created, NOW);
	assert.strictEqual(doc.comments.length, 1);
});

ok('create: keeps quote when exact present', () => {
	const doc = { comments: [] };
	const { data } = applyCommentOp(doc, 'create',
		{ anchor: 'slide:x', body: 'b', quote: { exact: 'foo', prefix: 'p', suffix: 's' } }, NOW);
	assert.deepStrictEqual(data.quote, { exact: 'foo', prefix: 'p', suffix: 's' });
});

ok('create: missing anchor → 400', () =>
	assert.strictEqual(applyCommentOp({ comments: [] }, 'create', { body: 'b' }, NOW).code, 400));
ok('create: missing body → 400', () =>
	assert.strictEqual(applyCommentOp({ comments: [] }, 'create', { anchor: 'a' }, NOW).code, 400));

ok('resolve: sets resolved, 200', () => {
	const doc = { comments: [{ id: 'c1', anchor: 'a', body: 'b', resolved: false }] };
	const { code, data } = applyCommentOp(doc, 'resolve', { id: 'c1' }, NOW);
	assert.strictEqual(code, 200);
	assert.strictEqual(data.resolved, true);
});
ok('resolve: unknown id → 404', () =>
	assert.strictEqual(applyCommentOp({ comments: [] }, 'resolve', { id: 'c9' }, NOW).code, 404));

ok('edit: replaces body + stamps edited', () => {
	const doc = { comments: [{ id: 'c1', anchor: 'a', body: 'old', resolved: false }] };
	const { code, data } = applyCommentOp(doc, 'edit', { id: 'c1', body: 'new' }, NOW);
	assert.strictEqual(code, 200);
	assert.strictEqual(data.body, 'new');
	assert.strictEqual(data.edited, NOW);
});
ok('edit: empty body → 400', () => {
	const doc = { comments: [{ id: 'c1', anchor: 'a', body: 'old', resolved: false }] };
	assert.strictEqual(applyCommentOp(doc, 'edit', { id: 'c1', body: '   ' }, NOW).code, 400);
});
ok('edit: unknown id → 404', () =>
	assert.strictEqual(applyCommentOp({ comments: [] }, 'edit', { id: 'c9', body: 'x' }, NOW).code, 404));

ok('delete: removes + returns {id,deleted}, 200', () => {
	const doc = { comments: [{ id: 'c1', anchor: 'a', body: 'b' }, { id: 'c2', anchor: 'a', body: 'b' }] };
	const { code, data } = applyCommentOp(doc, 'delete', { id: 'c1' }, NOW);
	assert.strictEqual(code, 200);
	assert.deepStrictEqual(data, { id: 'c1', deleted: true });
	assert.strictEqual(doc.comments.length, 1);
	assert.strictEqual(doc.comments[0].id, 'c2');
});
ok('delete: unknown id → 404', () =>
	assert.strictEqual(applyCommentOp({ comments: [] }, 'delete', { id: 'c9' }, NOW).code, 404));

ok('unknown op → 400 (fail-loud, no silent no-op)', () =>
	assert.strictEqual(applyCommentOp({ comments: [] }, 'frobnicate', {}, NOW).code, 400));

console.log(`\n${n} passed`);
