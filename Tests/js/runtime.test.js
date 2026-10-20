/* Runtime unit tests (node --test Tests/js). Pure functions only; the DOM-heavy parts are
 * covered by the Pester suites against exported HTML. */
'use strict';
const test   = require('node:test');
const assert = require('node:assert/strict');
const { load, loadWith, loadMethods } = require('./dh-extract');

test('dhNavFit: everything fits when rows allow', () => {
  const { dhNavFit } = load('Get-DhJsNav.ps1', ['dhNavFit']);
  const r = dhNavFit([50, 50, 50], 400, 4, 2, 80, -1);
  assert.deepEqual(r, { visible: [0, 1, 2], overflow: [] });
});

test('dhNavFit: overflow goes to More and the active item stays visible', () => {
  const { dhNavFit } = load('Get-DhJsNav.ps1', ['dhNavFit']);
  const w = Array(30).fill(100);
  const none = dhNavFit(w, 450, 4, 2, 80, -1);
  assert.ok(none.overflow.length > 0 && none.visible.length + none.overflow.length === 30);
  const act = dhNavFit(w, 450, 4, 2, 80, 17);
  assert.ok(act.visible.includes(17), 'active chip is never hidden');
  assert.deepEqual(act.visible, [...act.visible].sort((a, b) => a - b), 'visible stays in order');
});

test('dhNavFit: always keeps at least one chip visible', () => {
  const { dhNavFit } = load('Get-DhJsNav.ps1', ['dhNavFit']);
  const r = dhNavFit([100, 100, 100], 50, 4, 1, 80, 1);
  assert.ok(r.visible.length >= 1 && r.visible.includes(1));
});

test('dhNavFit: one row (2.5.3) leaves room for the More button on that row', () => {
  const { dhNavFit } = load('Get-DhJsNav.ps1', ['dhNavFit']);
  // 13 chips of 100px in a 450px strip, gap 4: 4 fit alone, 3 fit next to an 80px More button
  const r = dhNavFit(Array(13).fill(100), 450, 4, 1, 80, -1);
  assert.deepEqual(r.visible, [0, 1, 2]);
  assert.equal(r.overflow.length, 10);
  const a = dhNavFit(Array(13).fill(100), 450, 4, 1, 80, 9);
  assert.deepEqual(a.visible, [0, 1, 9], 'the selected chip takes the last visible slot');
  assert.deepEqual(dhNavFit(Array(4).fill(100), 450, 4, 1, 80, -1).overflow, [], 'a row that fits is left alone');
});

test('dhNavRows: a pixel of misalignment is not a new row', () => {
  const { dhNavRows } = load('Get-DhJsNav.ps1', ['dhNavRows']);
  const chip = (top, h, w) => ({ offsetTop: top, offsetHeight: h || 24, offsetWidth: w === undefined ? 90 : w });
  assert.equal(dhNavRows({ children: [chip(4), chip(5), chip(3, 26), chip(4)] }), 1);
  assert.equal(dhNavRows({ children: [chip(4), chip(4), chip(32), chip(33)] }), 2);
  assert.equal(dhNavRows({ children: [chip(4), chip(60, 24, 0)] }), 1, 'a hidden child does not count');
  assert.equal(dhNavRows({ children: [] }), 0);
});

test('dhTtPaths: walks up to the top group and stops at a loop', () => {
  const { dhTtPaths } = load('Get-DhJsTreeTable.ps1', ['dhTtPaths']);
  const up = { u: ['g1'], g1: ['g2'], g2: [] };
  assert.deepEqual(dhTtPaths(up, 'u', 50).paths, [['u', 'g1', 'g2']]);
  const loop = { u: ['a'], a: ['b'], b: ['a'] };
  const r = dhTtPaths(loop, 'u', 50);
  assert.equal(r.circular, true);
  assert.ok(r.paths.length >= 1);
});

test('dhTtPaths: caps the number of paths and counts the rest', () => {
  const { dhTtPaths } = load('Get-DhJsTreeTable.ps1', ['dhTtPaths']);
  const up = { u: ['a', 'b', 'c'], a: [], b: [], c: [] };
  const r = dhTtPaths(up, 'u', 2);
  assert.equal(r.paths.length, 2);
  assert.equal(r.more, 1);
});

test('dhTtNested: nested groups with depth, cycle marked and not followed', () => {
  const { dhTtNested } = load('Get-DhJsTreeTable.ps1', ['dhTtNested']);
  const membersOf = { g1: ['g2', 'u1'], g2: ['g1'] };
  const typeOf = { g1: 'group', g2: 'group', u1: 'user' };
  const out = dhTtNested(membersOf, typeOf, 'g1', 5);
  assert.deepEqual(out.map(x => [x.id, x.depth, x.circular]), [['g2', 1, false], ['g1', 2, true]]);
});

test('column picker: choice is saved and restored by field name, blocked storage is tolerated', () => {
  const m = loadMethods('Get-DhJsTable.ps1', ['_colsKey', '_restoreCols', '_saveCols']);
  const store = new Map();
  global.window = { localStorage: { getItem: k => store.has(k) ? store.get(k) : null, setItem: (k, v) => store.set(k, v), removeItem: k => store.delete(k) } };
  const mk = key => ({ rememberKey: key, columns: [{ field: 'a' }, { field: 'b', hidden: true }, { field: 'c' }],
                       colVisible: { 0: true, 1: false, 2: true }, _colsKey: m._colsKey });
  const e1 = mk('k'); e1.colVisible[0] = false; e1.colVisible[1] = true; m._saveCols.call(e1);
  assert.deepEqual(JSON.parse(store.get('dh:cols:k')), { a: false, b: true, c: true });
  const e2 = mk('k'); m._restoreCols.call(e2);
  assert.deepEqual(e2.colVisible, { 0: false, 1: true, 2: true });
  const e3 = mk(''); e3.colVisible[0] = false; m._saveCols.call(e3);
  assert.equal(store.size, 1, 'no key means nothing stored');
  global.window.localStorage.getItem = () => { throw new Error('blocked'); };
  global.window.localStorage.setItem = () => { throw new Error('blocked'); };
  assert.doesNotThrow(() => { m._saveCols.call(mk('k')); m._restoreCols.call(mk('k')); });
  delete global.window;
});
test('dhTextOn: picks the text colour that reads better on a heatmap cell', () => {
  const { dhTextOn } = load('Get-DhJsBlocks.ps1', ['dhTextOn']);
  assert.equal(dhTextOn('rgb(247,250,254)'), '#1a2332', 'pale cell gets dark text');
  assert.equal(dhTextOn('rgb(8,60,120)'),    '#ffffff', 'deep blue gets white text');
  assert.equal(dhTextOn('rgb(255,255,255)'), '#1a2332');
  assert.equal(dhTextOn('rgb(0,0,0)'),       '#ffffff');
  assert.equal(dhTextOn('nonsense'), '');
});
/* ---- formats --------------------------------------------------------------------------- */
const CORE = 'Get-DhJsCore.ps1';

test('FMT.apply: number, currency, bytes, percent, duration', () => {
  const { FMT } = loadWith(CORE, { vars: ['FMT'] });
  assert.equal(FMT.apply({ format: 'number', locale: 'en-US', decimals: 1 }, 1234.5), '1,234.5');
  assert.equal(FMT.apply({ format: 'currency', locale: 'en-US', currency: 'USD', decimals: 2 }, 1234.5), '$1,234.50');
  assert.equal(FMT.apply({ format: 'bytes', locale: 'en-US' }, 1500), '1.50 KB');
  assert.equal(FMT.apply({ format: 'bytes', locale: 'en-US' }, 999), '999 B');
  assert.equal(FMT.apply({ format: 'percent', locale: 'en-US' }, 45), '45.00\u00A0%');
  assert.equal(FMT.apply({ format: 'percent', locale: 'en-US' }, 0.256), '25.60\u00A0%');
  assert.equal(FMT.apply({ format: 'duration' }, 3725), '1h 02m 05s');
  assert.equal(FMT.apply({ format: 'duration' }, 59), '59s');
});

test('FMT.apply: text, empty, non-numeric, date pattern and list cells', () => {
  const { FMT } = loadWith(CORE, { vars: ['FMT'] });
  assert.equal(FMT.apply({}, 'abc'), 'abc');
  assert.equal(FMT.apply({ format: 'number' }, ''), '');
  assert.equal(FMT.apply({ format: 'number' }, null), '');
  assert.equal(FMT.apply({ format: 'number' }, 'n/a'), 'n/a');
  assert.equal(FMT.apply({ format: 'datetime', datePattern: 'dd/MM/yyyy HH:mm' }, '2026-03-04T09:05:00'), '04/03/2026 09:05');
  assert.equal(FMT.apply({ cellType: 'chips' }, ['a', 'b']), 'a, b');
  assert.equal(FMT.apply({ cellType: 'path' }, ['a', 'b']), 'a \u2192 b');
});

test('FMT.forExport: text stays raw, formats are applied', () => {
  const { FMT } = loadWith(CORE, { vars: ['FMT'] });
  assert.equal(FMT.forExport({}, 12.3456), 12.3456);
  assert.equal(FMT.forExport({ format: 'number', locale: 'en-US', decimals: 0 }, 1234.4), '1,234');
  assert.equal(FMT.forExport({}, null), '');
});

test('esc: escapes the five HTML characters and tolerates null', () => {
  const { esc } = load(CORE, ['esc']);
  assert.equal(esc('<a href="x">&\''), '&lt;a href=&quot;x&quot;&gt;&amp;&#39;');
  assert.equal(esc(null), '');
  assert.equal(esc(5), '5');
});

/* ---- thresholds and spark --------------------------------------------------------------- */
test('getThresholdClass: numeric ranges, string values, missing data', () => {
  const { getThresholdClass } = load(CORE, ['getThresholdClass']);
  const col = { thresholds: [{ min: 0, max: 50, class: 'cell-ok' }, { min: 50, class: 'cell-bad' }] };
  assert.equal(getThresholdClass(col, 49), 'cell-ok');
  assert.equal(getThresholdClass(col, 50), 'cell-bad');
  assert.equal(getThresholdClass(col, 'x'), '');
  assert.equal(getThresholdClass({ thresholds: [{ value: 'Failed', class: 'cell-bad' }] }, 'failed'), 'cell-bad');
  assert.equal(getThresholdClass({ ragNoData: true }, null), 'cell-nodata');
  assert.equal(getThresholdClass({}, 5), '');
});

test('pickThresholdClass: the band with the highest min wins', () => {
  const { pickThresholdClass } = load(CORE, ['pickThresholdClass']);
  const th = [{ min: 0, max: 100, class: 'a' }, { min: 50, class: 'b' }];
  assert.equal(pickThresholdClass(60, th), 'b');
  assert.equal(pickThresholdClass(10, th), 'a');
  assert.equal(pickThresholdClass(-5, th), '');
  assert.equal(pickThresholdClass(5, []), '');
});

test('sparkReduce: reduces a series, ignores non-numbers, empty is 0', () => {
  const { sparkReduce } = load(CORE, ['sparkReduce']);
  assert.equal(sparkReduce([1, 2, 'x', 3], 'avg'), 2);
  assert.equal(sparkReduce([1, 2, 3]), 3);
  assert.equal(sparkReduce([4, 9, 1], 'max'), 9);
  assert.equal(sparkReduce([4, 9, 1], 'min'), 1);
  assert.equal(sparkReduce([4, 9, 1], 'sum'), 14);
  assert.equal(sparkReduce([], 'avg'), 0);
  assert.equal(sparkReduce(7), 7);
});

/* ---- table: aggregates, text match, visible columns ------------------------------------- */
const TABLE = 'Get-DhJsTable.ps1';

test('dhAggregate and dhFootText: aggregates and the rounding of unformatted averages', () => {
  const FMT = loadWith(CORE, { vars: ['FMT'] }).FMT;
  const f = loadWith(TABLE, { fns: ['dhAggregate', 'dhFootText'] }, { FMT });
  assert.equal(f.dhAggregate('sum', [1, 2, 3], 3), 6);
  assert.equal(f.dhAggregate('avg', [1, 1, 2], 3), 4 / 3);
  assert.equal(f.dhAggregate('min', [4, 2], 2), 2);
  assert.equal(f.dhAggregate('max', [4, 2], 2), 4);
  assert.equal(f.dhAggregate('count', [], 7), 7);
  assert.equal(f.dhAggregate('avg', [], 0), null);
  assert.equal(f.dhAggregate('median', [1], 1), null);
  assert.equal(f.dhFootText({}, 4 / 3), '1.33');
  assert.equal(f.dhFootText({ decimals: 0 }, 4 / 3), '1');
  assert.equal(f.dhFootText({}, 6), '6');
  assert.equal(f.dhFootText({ format: 'number', locale: 'en-US', decimals: 1 }, 1234.56), '1,234.6');
});

test('_matchText and _visibleCols: text matches raw or formatted values of visible columns only', () => {
  const FMT = loadWith(CORE, { vars: ['FMT'] }).FMT;
  const m = loadMethods(TABLE, ['_matchText', '_visibleCols'], { FMT });
  const cols = [{ field: 'a' }, { field: 'b', format: 'number', locale: 'en-US', decimals: 0 }, { field: 'c' }];
  const self = { columns: cols, colVisible: { 0: true, 1: true, 2: false }, _visibleCols: m._visibleCols };
  assert.deepEqual(m._visibleCols.call(self).map(c => c.field), ['a', 'b']);
  assert.equal(m._matchText.call(self, { a: 'Alpha', b: 1234, c: 'secret' }, 'alp'), true);
  assert.equal(m._matchText.call(self, { a: 'Alpha', b: 1234, c: 'secret' }, '1,234'), true, 'formatted value');
  assert.equal(m._matchText.call(self, { a: 'Alpha', b: 1234, c: 'secret' }, 'secret'), false, 'hidden column');
  assert.equal(m._matchText.call(self, { a: null, b: undefined }, 'x'), false);
});

/* ---- network map ------------------------------------------------------------------------- */
const NET = 'Get-DhJsNetwork.ps1';
const netFns = () => loadWith(NET, { vars: ['DH_NET'], fns: ['dhNetFlow', 'dhNetBoundary', 'dhNetLayout', 'dhNetEdgeGeom', 'dhNetPath', 'dhNetTrunc'] });

test('dhNetFlow and dhNetBoundary: wrap at the limit; edge point of a box', () => {
  const { dhNetFlow, dhNetBoundary } = netFns();
  const items = [1, 2, 3].map(() => ({ w: 100, h: 20 }));
  const size = dhNetFlow(items, 250, 10);
  assert.deepEqual(items.map(i => [i.x, i.y]), [[0, 0], [110, 0], [0, 30]]);
  assert.deepEqual(size, { w: 210, h: 50 });
  assert.deepEqual(dhNetBoundary({ x: 0, y: 0, w: 100, h: 50 }, 200, 25), { x: 100, y: 25 });
  assert.deepEqual(dhNetBoundary({ x: 0, y: 0, w: 100, h: 50 }, 50, 25), { x: 50, y: 25 });
});

test('dhNetPath: shortest route to a target, direction respected, null when unreachable', () => {
  const { dhNetPath } = netFns();
  const nodes = [{ id: 'a' }, { id: 'b' }, { id: 'c', target: true }];
  const fwd = { nodes, edges: [{ from: 'a', to: 'b', direction: 'forward' }, { from: 'b', to: 'c', direction: 'forward' }] };
  assert.deepEqual(dhNetPath(fwd, 'a'), { nodes: ['a', 'b', 'c'], edges: [0, 1] });
  assert.deepEqual(dhNetPath(fwd, 'c'), { nodes: ['c'], edges: [] }, 'a target is its own path');
  const both = { nodes, edges: [{ from: 'b', to: 'a', direction: 'both' }, { from: 'b', to: 'c', direction: 'forward' }] };
  assert.deepEqual(dhNetPath(both, 'a'), { nodes: ['a', 'b', 'c'], edges: [0, 1] });
  const wrong = { nodes, edges: [{ from: 'b', to: 'a', direction: 'forward' }, { from: 'b', to: 'c', direction: 'forward' }] };
  assert.equal(dhNetPath(wrong, 'a'), null, 'forward-only edge cannot be walked backwards');
  assert.equal(dhNetPath(fwd, 'zzz'), null);
});

test('dhNetEdgeGeom: parallel edges fan out, a self link loops, a missing node gives null', () => {
  const { dhNetEdgeGeom } = netFns();
  const pos = { a: { x: 0, y: 0, w: 100, h: 40 }, b: { x: 300, y: 0, w: 100, h: 40 } };
  const g = dhNetEdgeGeom([{ from: 'a', to: 'b' }, { from: 'a', to: 'b' }, { from: 'a', to: 'a' }, { from: 'a', to: 'zz' }], pos);
  assert.notEqual(g[0].d, g[1].d, 'two links between the same pair take different curves');
  assert.equal(g[2].loop, true);
  assert.equal(g[3], null);
  assert.match(g[0].d, /^M[\d.]+,[\d.]+ Q/);
});

test('dhNetTrunc: shortens with an ellipsis, keeps short text, tolerates null', () => {
  const { dhNetTrunc } = netFns();
  assert.equal(dhNetTrunc('abcdef', 4), 'abc\u2026');
  assert.equal(dhNetTrunc('abc', 4), 'abc');
  assert.equal(dhNetTrunc(null, 4), '');
});

test('dhNetLayout: deterministic, every node placed, layered layout adds lanes', () => {
  const { dhNetLayout } = netFns();
  const nodes = ['a', 'b', 'c', 'd'].map((id, i) => ({ id, label: id, tier: i % 2 }));
  const edges = [{ from: 'a', to: 'b' }, { from: 'b', to: 'c' }, { from: 'c', to: 'd' }];
  const grouped = { nodes, edges, groups: [{ id: 'g', label: 'G', members: ['a', 'b'] }] };
  const l1 = dhNetLayout(JSON.parse(JSON.stringify(grouped))), l2 = dhNetLayout(JSON.parse(JSON.stringify(grouped)));
  assert.deepEqual(l1, l2, 'same input, same layout');
  nodes.forEach(n => assert.ok(l1.pos[n.id] && l1.pos[n.id].w > 0, 'node ' + n.id + ' has a box'));
  assert.ok(l1.width > 0 && l1.height > 0);
  const layered = dhNetLayout({ nodes, edges, layout: 'layered' });
  assert.ok(layered.lanes.length >= 2, 'tiers 0 and 1 give two lanes');
  const ys = nodes.map(n => layered.pos[n.id].y);
  assert.ok(layered.pos.a.y < layered.pos.b.y, 'tier 0 sits above tier 1');
  assert.equal(new Set(ys).size >= 2, true);
});

/* ---- nav tree ---------------------------------------------------------------------------- */
test('navNodeAt and navAutoDescend: find a node, descend to the first node with content, skip the All view', () => {
  const { navNodeAt, navAutoDescend } = load('Get-DhJsNav.ps1', ['navNodeAt', 'navAutoDescend']);
  const leaf = { children: {}, order: [], hasContent: true };
  const tree = { children: { A: { children: { '*': { children: {}, order: [], hasContent: true }, B: leaf }, order: ['*', 'B'], hasContent: false } }, order: ['A'], hasContent: false };
  assert.equal(navNodeAt(tree, ['A', 'B']), leaf);
  assert.equal(navNodeAt(tree, ['A', 'nope']), null);
  assert.deepEqual(navAutoDescend(tree, ['A']), ['A', 'B']);
  assert.deepEqual(navAutoDescend(tree, ['Z']), ['Z']);
});
/* ---- menu pruning ------------------------------------------------------------------------- */
test('dhNavPrune: dead ends go, declared nodes, content and their ancestors stay', () => {
  const { dhNavPrune } = load('Get-DhJsNav.ps1', ['dhNavPrune']);
  const mk = (seg, path, extra) => Object.assign({ seg, path, label: seg, children: {}, order: [], hasContent: false }, extra || {});
  const root = mk('', []);
  const add = (parent, node) => { parent.children[node.seg] = node; parent.order.push(node.seg); return node; };
  const a = add(root, mk('A', ['A']));
  add(a, mk('Live', ['A', 'Live']));            /* has content */
  add(a, mk('Dead', ['A', 'Dead']));            /* nothing here */
  const b = add(root, mk('B', ['B']));
  add(b, mk('Gone', ['B', 'Gone']));            /* only dead children: B goes too */
  add(root, mk('Later', ['Later'], { declared: true }));
  const own = new Set(['A/Live']);
  dhNavPrune(root, p => own.has(p.join('/')));
  assert.deepEqual(root.order, ['A', 'Later']);
  assert.deepEqual(a.order, ['Live']);
  assert.equal(root.children.B, undefined);
  assert.equal(a.children.Dead, undefined);
});

test('dhNavPrune: a parent with its own content stays even when every child is gone; the root is never removed', () => {
  const { dhNavPrune } = load('Get-DhJsNav.ps1', ['dhNavPrune']);
  const node = (seg, path) => ({ seg, path, children: {}, order: [] });
  const root = node('', []), p = node('P', ['P']), c = node('C', ['P', 'C']);
  root.children.P = p; root.order = ['P']; p.children.C = c; p.order = ['C'];
  assert.equal(dhNavPrune(root, path => path.join('/') === 'P'), true);
  assert.deepEqual(root.order, ['P']);
  assert.deepEqual(p.order, []);
  const empty = node('', []);
  assert.equal(dhNavPrune(empty, () => false), true);
});
test('dhTtLinks: indexes members and memberships, tolerates no links', () => {
  const { dhTtLinks } = load('Get-DhJsTreeTable.ps1', ['dhTtLinks']);
  const r = dhTtLinks([['g1', 'u1'], ['g1', 'u2'], ['g2', 'g1']]);
  assert.deepEqual(r.membersOf, { g1: ['u1', 'u2'], g2: ['g1'] });
  assert.deepEqual(r.memberOf, { u1: ['g1'], u2: ['g1'], g1: ['g2'] });
  assert.deepEqual(dhTtLinks(undefined), { membersOf: {}, memberOf: {} });
});

test('dhNavFit: an empty list and a very wide chip never loop or hide the active one', () => {
  const { dhNavFit } = load('Get-DhJsNav.ps1', ['dhNavFit']);
  assert.deepEqual(dhNavFit([], 400, 4, 2, 80, -1), { visible: [], overflow: [] });
  const r = dhNavFit([900, 50, 50], 300, 4, 1, 60, 0);
  assert.ok(r.visible.includes(0));
});

test('dh-extract: a function that is not in the runtime fails loudly', () => {
  assert.throws(() => load('Get-DhJsNav.ps1', ['thisFunctionDoesNotExist']), /not found/);
  assert.throws(() => loadWith('Get-DhJsCore.ps1', { vars: ['NoSuchVar'] }), /not found/);
});
/* ---- accessibility helpers ---------------------------------------------------------------- */
function fakeEl(id) {
  const attrs = {}, listeners = {}, classes = new Set();
  return {
    id, textContent: '\u25BE', attrs, listeners,
    classList: { contains: c => classes.has(c), toggle: (c, f) => { const on = f === undefined ? !classes.has(c) : !!f; on ? classes.add(c) : classes.delete(c); return on; }, add: c => classes.add(c) },
    setAttribute: (k, v) => { attrs[k] = String(v); }, getAttribute: k => attrs[k],
    addEventListener: (t, fn) => { (listeners[t] = listeners[t] || []).push(fn); }
  };
}

test('dhBindCollapsible: button role, tab stop, aria state, Enter and Space toggle', () => {
  const { dhBindCollapsible } = load('Get-DhJsCore.ps1', ['dhBindCollapsible']);
  const toggle = fakeEl('t'), body = fakeEl('cbody-x'), chev = fakeEl('c');
  body.classList.add('open');
  dhBindCollapsible(toggle, body, chev);
  assert.equal(toggle.attrs.role, 'button');
  assert.equal(toggle.attrs.tabindex, '0');
  assert.equal(toggle.attrs['aria-expanded'], 'true');
  assert.equal(toggle.attrs['aria-controls'], 'cbody-x');
  assert.equal(chev.attrs['aria-hidden'], 'true');
  toggle.listeners.click[0]();
  assert.equal(toggle.attrs['aria-expanded'], 'false');
  assert.equal(chev.textContent, '\u25B8');
  let prevented = 0;
  toggle.listeners.keydown[0]({ key: 'Enter', preventDefault: () => prevented++ });
  assert.equal(toggle.attrs['aria-expanded'], 'true');
  toggle.listeners.keydown[0]({ key: ' ', preventDefault: () => prevented++ });
  assert.equal(toggle.attrs['aria-expanded'], 'false');
  toggle.listeners.keydown[0]({ key: 'a', preventDefault: () => prevented++ });
  assert.equal(prevented, 2, 'other keys are left alone');
});
/* ---- baseline markers ----------------------------------------------------------------------- */
test('baseline helpers: note text, change filter, old-value tooltip', () => {
  const f = loadWith('Get-DhJsTable.ps1', { fns: ['dhBaselineNote', 'dhChangeKeep', 'dhWasText'] });
  assert.equal(f.dhBaselineNote({ label: 'last night', new: 3, changed: 2, removed: 1 }), 'vs last night: +3 new, ~2 changed, \u22121 removed');
  assert.equal(f.dhChangeKeep(undefined, ''), true, 'no filter keeps everything');
  assert.equal(f.dhChangeKeep(undefined, 'n'), false, 'an unchanged row is not New');
  assert.equal(f.dhChangeKeep({ s: 'n' }, 'n'), true);
  assert.equal(f.dhChangeKeep({ s: 'c' }, 'n'), false);
  assert.equal(f.dhChangeKeep({ s: 'c' }, 'c'), true);
  const fmt = (col, v) => col.format === 'number' ? String(Number(v).toFixed(1)) : String(v);
  assert.equal(f.dhWasText({}, 5, fmt), 'was: 5');
  assert.equal(f.dhWasText({ format: 'number' }, 5, fmt), 'was: 5.0');
  assert.equal(f.dhWasText({}, null, fmt), 'was: (empty)');
  assert.equal(f.dhWasText({}, '', fmt), 'was: (empty)');
});
test('dhCsvSafe: formula-looking text gets an apostrophe, numbers and plain text do not', () => {
  const { dhCsvSafe } = loadWith('Get-DhJsTable.ps1', { fns: ['dhCsvSafe'] });
  assert.equal(dhCsvSafe('=HYPERLINK("http://x")'), "'=HYPERLINK(\"http://x\")");
  assert.equal(dhCsvSafe('+33 1 23'), "'+33 1 23");
  assert.equal(dhCsvSafe('@SUM(A1)'), "'@SUM(A1)");
  assert.equal(dhCsvSafe('-cmd|x'), "'-cmd|x");
  assert.equal(dhCsvSafe('\tx'), "'\tx");
  assert.equal(dhCsvSafe('-5'), '-5');
  assert.equal(dhCsvSafe('+1.5'), '+1.5');
  assert.equal(dhCsvSafe('srv-01'), 'srv-01');
  assert.equal(dhCsvSafe(null), '');
  assert.equal(dhCsvSafe(42), '42');
});

test('dhCellText: the copied text leaves out the New / Changed tag', () => {
  const { dhCellText } = loadWith('Get-DhJsTable.ps1', { fns: ['dhCellText'] });
  const mk = (cls, text, kids) => ({ className: cls, text, kids: kids || [], parentNode: null,
    get textContent() { return this.text + this.kids.map(k => k.textContent).join(''); } });
  const tag = mk('chg-tag', 'New'); const val = mk('', 'srv-5');
  const td = mk('', '', [tag, val]);
  td.cloneNode = function () {
    const c = mk('', '', this.kids.slice());
    c.kids.forEach(k => { k.parentNode = { removeChild: x => { c.kids = c.kids.filter(y => y !== x); } }; });
    c.querySelectorAll = sel => sel === '.chg-tag' ? c.kids.filter(k => k.className === 'chg-tag') : [];
    return c;
  };
  assert.equal(dhCellText(td), 'srv-5');
});