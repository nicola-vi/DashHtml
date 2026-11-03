/* 3.0.0 runtime tests: saved table views (Add-DhTable -RememberViews). */
'use strict';
const test   = require('node:test');
const assert = require('node:assert/strict');
const { loadWith } = require('./dh-extract');

function storage(throws) {
  const m = new Map();
  return {
    getItem(k) { if (throws) throw new Error('blocked'); return m.has(k) ? m.get(k) : null; },
    setItem(k, v) { if (throws) throw new Error('blocked'); m.set(k, String(v)); },
    removeItem(k) { m.delete(k); }
  };
}
function views(win) {
  return loadWith('Get-DhJsTable.ps1', {
    vars: ['DH_LS_CAP', 'DH_PAGE_SIZES', 'DH_VIEWS_MAX'],
    fns: ['dhTableStateGet', 'dhTableStateSet', 'dhViewsLoad', 'dhViewsStore', 'dhViewCapture', 'dhViewApply']
  }, { window: win });
}
function eng(over) {
  const e = Object.assign({ id: 't', sortFields: [], currentPage: 3, pageable: true, pageSize: 15, _pageSize0: 15,
    changeFilter: '', base: { changes: {} }, _pendingPage: 0, filterText: '',
    columns: [{ field: 'Name' }, { field: 'Cpu' }, { field: 'Owner', hidden: true }, { field: 'Notes', sortable: false }] }, over || {});
  e.colVisible = e.colVisible || { 0: true, 1: true, 2: false, 3: true };
  return e;
}

test('a view keeps columns by field name, sort, page size, chip and filter, not the page', () => {
  const v = views({ localStorage: storage(false) });
  const e = eng({ sortFields: [{ field: 'Cpu', dir: 'desc' }], pageSize: 50, changeFilter: 'n', filterText: 'rome', colVisible: { 0: true, 1: false, 2: true, 3: true } });
  const cap = v.dhViewCapture(e);
  assert.deepEqual(cap, { cols: { Name: true, Cpu: false, Owner: true, Notes: true }, q: 'rome', s: [['Cpu', 'desc']], z: 50, c: 'n' });
  assert.equal('p' in cap, false);
});

test('applying a view restores it; unknown or unsortable fields and odd sizes are skipped', () => {
  const v = views({ localStorage: storage(false) });
  const e = eng({ sortFields: [{ field: 'Name', dir: 'asc' }], pageSize: 25, changeFilter: 'c' });
  const q = v.dhViewApply(e, { cols: { Cpu: false, Gone: true }, s: [['Notes', 'asc'], ['Gone', 'asc'], ['Cpu', 'desc']], z: 7, c: 'n', q: 'x' });
  assert.equal(q, 'x');
  assert.deepEqual(e.sortFields, [{ field: 'Cpu', dir: 'desc' }]);
  assert.equal(e.pageSize, 15, 'a page size the menu does not offer falls back to the author default');
  assert.equal(e.changeFilter, 'n');
  assert.equal(e.currentPage, 1);
  assert.deepEqual(e.colVisible, { 0: true, 1: false, 2: false, 3: true }, 'a column the view does not name keeps its default (Owner is Hidden)');
});

test('the empty view is the author default: columns, sort, page size, no chip, no filter', () => {
  const v = views({ localStorage: storage(false) });
  const e = eng({ sortFields: [{ field: 'Name', dir: 'asc' }], pageSize: 100, changeFilter: 'n', colVisible: { 0: false, 1: false, 2: true, 3: false } });
  assert.equal(v.dhViewApply(e, {}), '');
  assert.deepEqual(e.sortFields, []);
  assert.equal(e.pageSize, 15);
  assert.equal(e.changeFilter, '');
  assert.deepEqual(e.colVisible, { 0: true, 1: true, 2: false, 3: true });
});

test('storage: views round-trip, junk is dropped, and blocked storage never throws', () => {
  const ok = views({ localStorage: storage(false) });
  assert.equal(ok.dhViewsStore('k', [{ name: 'A', cols: {} }, { name: '' }, null, 5, { cols: {} }]), true);
  assert.deepEqual(ok.dhViewsLoad('k'), [{ name: 'A', cols: {} }]);
  assert.deepEqual(ok.dhViewsLoad('missing'), []);
  const s = storage(false); s.setItem('bad', '{not json');
  assert.deepEqual(views({ localStorage: s }).dhViewsLoad('bad'), []);
  const blocked = views({ localStorage: storage(true) });
  assert.deepEqual(blocked.dhViewsLoad('k'), []);
  assert.equal(blocked.dhViewsStore('k', [{ name: 'A' }]), false);
  assert.equal(ok.DH_VIEWS_MAX, 20);
});
