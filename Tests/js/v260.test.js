/* 2.6.0 runtime tests: link columns, table state in the address, tree-table windowing and CSV. */
'use strict';
const test   = require('node:test');
const assert = require('node:assert/strict');
const { load, loadWith } = require('./dh-extract');

const links = load('Get-DhJsCore.ps1', ['dhLinkUrl', 'dhLinkFill', 'dhLinkNewTab']);

test('dhLinkUrl: http, https, mailto and tel pass; dangerous schemes never do', () => {
  const { dhLinkUrl } = links;
  for (const u of ['https://x.example/a', 'http://x', 'mailto:a@b.c', 'tel:+3902123', ' HTTPS://X ']) {
    assert.equal(dhLinkUrl(u, false), u.trim(), u);
  }
  for (const u of ['javascript:alert(1)', 'JaVaScRiPt:alert(1)', 'java\tscript:alert(1)', 'java\nscript:x',
                   ' \u0001javascript:x', 'data:text/html,<b>', 'vbscript:x', 'file:///c:/x', 'blob:x']) {
    assert.equal(dhLinkUrl(u, true), '', JSON.stringify(u));
  }
  assert.equal(dhLinkUrl(null, true), '');
  assert.equal(dhLinkUrl('   ', true), '');
});

test('dhLinkUrl: a value without a scheme is a link only when relative links are allowed', () => {
  const { dhLinkUrl } = links;
  for (const u of ['AppDetails.html?id=123', '../vm/srv01.html', '#nav', '/root/x', 'N/A']) {
    assert.equal(dhLinkUrl(u, false), '', u);
    assert.equal(dhLinkUrl(u, true), u, u);
  }
  assert.equal(dhLinkUrl('C:\\temp\\x', true), '', 'a drive letter reads as a scheme');
});

test('dhLinkFill: values are URL-encoded, braces escape, an empty value gives no link', () => {
  const { dhLinkFill } = links;
  assert.equal(dhLinkFill('https://p/#view/appId/{Id}', { Id: 'a b/1' }), 'https://p/#view/appId/a%20b%2F1');
  assert.equal(dhLinkFill('x.html?id={Id}&n={Name}', { Id: 7, Name: 'é&' }), 'x.html?id=7&n=%C3%A9%26');
  assert.equal(dhLinkFill('a{{b}}{Id}', { Id: 1 }), 'a{b}1');
  assert.equal(dhLinkFill('x.html?id={Id}', { Id: '' }), '');
  assert.equal(dhLinkFill('x.html?id={Id}', {}), '');
  assert.equal(dhLinkFill('{Url}', { Url: 'javascript:alert(1)' }), 'javascript%3Aalert(1)', 'the colon is encoded: no scheme can be injected');
});

test('dhLinkNewTab: other sites open a new tab, relative links the same tab, LinkTarget overrides', () => {
  const { dhLinkNewTab } = links;
  assert.equal(dhLinkNewTab('https://x', ''), true);
  assert.equal(dhLinkNewTab('//cdn.example/x', ''), true);
  assert.equal(dhLinkNewTab('page.html', ''), false);
  assert.equal(dhLinkNewTab('#nav', ''), false);
  assert.equal(dhLinkNewTab('https://x', 'same'), false);
  assert.equal(dhLinkNewTab('page.html', 'new'), true);
  assert.equal(dhLinkNewTab('mailto:a@b', 'new'), false, 'mail and phone links never get a target');
  assert.equal(dhLinkNewTab('tel:1', ''), false);
});

const ls = loadWith('Get-DhJsTable.ps1', { vars: ['DH_LS_CAP', 'DH_PAGE_SIZES'], fns: ['dhTableStateGet', 'dhTableStateSet', 'dhTableStateAll', 'dhTableStateFinish'] });
function eng(over) {
  return Object.assign({ id: 't', linkState: true, sortFields: [], currentPage: 1, pageable: true, pageSize: 15, _pageSize0: 15,
    changeFilter: '', base: null, _pendingPage: 0,
    columns: [{ field: 'Name' }, { field: 'Cpu' }, { field: 'Notes', sortable: false }] }, over || {});
}

test('table state: only what differs from the default is written', () => {
  assert.equal(ls.dhTableStateGet(eng()), null);
  assert.deepEqual(ls.dhTableStateGet(eng({ sortFields: [{ field: 'Cpu', dir: 'desc' }], currentPage: 3, pageSize: 50, changeFilter: 'n' })),
    { s: [['Cpu', 'desc']], p: 3, z: 50, c: 'n' });
  assert.equal(ls.dhTableStateGet(eng({ pageable: false, currentPage: 4 })), null, 'no page for an unpaged table');
});

test('table state: reading ignores unknown and unsortable columns, odd sizes, and a Change chip without a baseline', () => {
  const e = eng();
  ls.dhTableStateSet(e, { s: [['Cpu', 'desc'], ['Bogus', 'asc'], ['Notes', 'asc'], ['Cpu', 'asc'], ['Name', 'sideways'], 'x'], z: 7, p: 4, c: 'n' });
  assert.deepEqual(e.sortFields, [{ field: 'Cpu', dir: 'desc' }]);
  assert.equal(e.pageSize, 15);
  assert.equal(e._pendingPage, 4, 'the page waits until every filter is restored');
  assert.equal(e.changeFilter, '');
  const b = eng({ base: {} });
  ls.dhTableStateSet(b, { z: 50, c: 'c' });
  assert.equal(b.pageSize, 50); assert.equal(b.changeFilter, 'c');
  ls.dhTableStateSet(b, null); ls.dhTableStateSet(b, 'junk');   /* no throw */
  const proto = eng();
  ls.dhTableStateSet(proto, { s: [['__proto__', 'asc'], ['constructor', 'asc']] });
  assert.deepEqual(proto.sortFields, []);
});

test('table state: tables without -LinkState are left out; past the cap the least recently used go first', () => {
  const engs = { a: eng({ id: 'a', currentPage: 2, _lsTouch: 1 }), b: eng({ id: 'b', currentPage: 3, _lsTouch: 5 }), c: eng({ id: 'c', linkState: false, currentPage: 9 }) };
  assert.deepEqual(ls.dhTableStateAll(engs), { b: { p: 3 }, a: { p: 2 } });
  const many = {};
  for (let i = 0; i < 200; i++) many['table' + i] = eng({ id: 'table' + i, sortFields: [{ field: 'Name', dir: 'asc' }], _lsTouch: i });
  const out = ls.dhTableStateAll(many);
  assert.ok(JSON.stringify(out).length <= 1500);
  assert.ok(out.table199 && !out.table0, 'the most recently used tables are kept');
  assert.equal(ls.dhTableStateAll({}), null);
});

test('table state: a page past the end is clamped to the last page', () => {
  let rendered = 0;
  const e = eng({ _pendingPage: 99, _getFiltered: () => new Array(40), render: () => { rendered++; } });
  ls.dhTableStateFinish({ e });
  assert.equal(e.currentPage, 3); assert.equal(e._pendingPage, 0); assert.equal(rendered, 1);
});

const tt = load('Get-DhJsTreeTable.ps1', ['dhTtMatch', 'dhTtFlatten', 'dhTtWindow']);
function model() {
  const rows = [
    { id: 'd', parent: '', type: 'ou', label: 'contoso' },
    { id: 'o1', parent: 'd', type: 'ou', label: 'Site 1' },
    { id: 'o2', parent: 'd', type: 'ou', label: 'Site 2' },
    { id: 'u1', parent: 'o1', type: 'user', label: 'alice' },
    { id: 'u2', parent: 'o1', type: 'user', label: 'bob' },
    { id: 'g1', parent: 'o2', type: 'group', label: 'admins' }];
  const byId = {}, kids = {}, roots = [];
  rows.forEach(r => { byId[r.id] = r; kids[r.id] = []; });
  rows.forEach(r => { if (r.parent && byId[r.parent]) kids[r.parent].push(r); else roots.push(r); });
  return { rows, byId, kids, roots };
}

test('dhTtFlatten: open rows only, with position and size among visible siblings', () => {
  const m = model();
  const flat = tt.dhTtFlatten(m.roots, m.kids, { d: true, o1: true }, null);
  assert.deepEqual(flat.map(x => x.r.id), ['d', 'o1', 'u1', 'u2', 'o2']);
  assert.deepEqual(flat.map(x => x.pos + '/' + x.size), ['1/1', '1/2', '1/2', '2/2', '2/2']);
  assert.deepEqual(tt.dhTtFlatten(m.roots, m.kids, {}, null).map(x => x.r.id), ['d']);
});

test('dhTtMatch + dhTtFlatten: a match shows its ancestors open, whatever is expanded', () => {
  const m = model();
  const hit = tt.dhTtMatch(m.rows, m.byId, 'BOB', {});
  assert.deepEqual(tt.dhTtFlatten(m.roots, m.kids, {}, hit).map(x => x.r.id + ':' + x.pos + '/' + x.size), ['d:1/1', 'o1:1/1', 'u2:1/1']);
  const groups = tt.dhTtMatch(m.rows, m.byId, '', { group: true });
  assert.deepEqual(tt.dhTtFlatten(m.roots, m.kids, {}, groups).map(x => x.r.id), ['d', 'o2', 'g1']);
  assert.equal(tt.dhTtMatch(m.rows, m.byId, '', {}), null, 'no filter, no match object');
  assert.deepEqual(tt.dhTtFlatten(m.roots, m.kids, {}, tt.dhTtMatch(m.rows, m.byId, 'zzz', {})), []);
});

test('dhTtWindow: rows in view plus overscan, spacers fill the rest', () => {
  assert.deepEqual(tt.dhTtWindow(0, 280, 28, 1000, 20), { start: 0, end: 30, top: 0, bottom: 970 * 28 });
  assert.deepEqual(tt.dhTtWindow(28 * 500, 280, 28, 1000, 20), { start: 480, end: 530, top: 480 * 28, bottom: 470 * 28 });
  const end = tt.dhTtWindow(28 * 995, 280, 28, 1000, 20);
  assert.equal(end.end, 1000); assert.equal(end.bottom, 0);
  assert.deepEqual(tt.dhTtWindow(0, 280, 28, 0, 20), { start: 0, end: 0, top: 0, bottom: 0 });
  const past = tt.dhTtWindow(28 * 5000, 280, 28, 10, 20);
  assert.ok(past.start <= past.end && past.end === 10);
});

test('dhCsvText: BOM, quoted cells, CRLF, and the formula guard on tree exports', () => {
  const { dhCsvSafe } = loadWith('Get-DhJsTable.ps1', { fns: ['dhCsvSafe'] });
  const { dhCsvText } = load('Get-DhJsTreeTable.ps1', ['dhCsvText'], { dhCsvSafe });
  const t = dhCsvText(['Id', 'Label'], [['g1', '=Group "1"'], ['u1', -5]]);
  assert.equal(t, '\uFEFF"Id","Label"\r\n"g1","\'=Group ""1"""\r\n"u1","-5"');
});
