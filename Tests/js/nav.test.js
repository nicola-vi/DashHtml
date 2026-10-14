/* Drives the PRODUCTION runtime JS under Node (v2.1.4).
 *
 * nav-spike.test.js proved the approach against its own copy of the matcher.
 * This file extracts the shipped code from DashHtml/Private/Get-DhJsNav.ps1 by
 * its sentinel comments, so a change to the runtime is what gets tested:
 *
 *   DH-NAV-MATCHER-START / END     navPathOf + navMatches
 *   DH-TABLE-COLLAPSE-START / END  initTableCollapsibles (F1 regression)
 *
 * Run:   node Tests/js/nav.test.js [truth-table.json]
 *
 * With a JSON argument, the cases come from the PowerShell predicate
 * Test-DhNavMatch (the Pester wrapper generates the file), which pins the JS
 * mirror to the PowerShell source of truth. Without one, a built-in table runs.
 * Exit code 0 = all passed.
 */
'use strict';
const fs   = require('fs');
const path = require('path');
const { FakeElement } = require('./dom-shim');

let pass = 0, fail = 0;
function check(name, cond, detail) {
  if (cond) { pass++; }
  else      { fail++; console.log(`  [-] ${name}${detail ? '\n        ' + detail : ''}`); }
}

const navPs1 = path.join(__dirname, '..', '..', 'DashHtml', 'Private', 'Get-DhJsNav.ps1');
const src    = fs.readFileSync(navPs1, 'utf8');

function extract(start, end) {
  const a = src.indexOf(`==== ${start} ====`);
  const b = src.indexOf(`==== ${end} ====`);
  if (a < 0 || b < 0 || b < a) throw new Error(`sentinels ${start}/${end} not found in Get-DhJsNav.ps1`);
  /* from the end of the start comment line to the start of the end comment */
  const from = src.indexOf('\n', a) + 1;
  const to   = src.lastIndexOf('\n', b);
  return src.slice(from, to);
}

/* ── 1. The matcher ──────────────────────────────────────────────────── */
const matcher = new Function(extract('DH-NAV-MATCHER-START', 'DH-NAV-MATCHER-END') +
                             '\nreturn { navPathOf: navPathOf, navMatches: navMatches };')();

function section(declared, scope) {
  return new FakeElement({ navpath: JSON.stringify(declared), navscope: scope.toLowerCase() });
}

let cases;
if (process.argv[2]) {
  cases = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
} else {
  /* Built-in table: scope x declared depth x selected depth, plus case-sensitivity. */
  const paths = [[], ['A'], ['A', 'B'], ['A', 'B', 'C'], ['A', 'X'], ['a']];
  cases = [];
  for (const scope of ['Exact', 'Subtree', 'Global'])
    for (const d of paths)
      for (const s of paths) {
        let expected;
        if (scope === 'Global') expected = true;
        else if (d.length > s.length) expected = false;
        else if (d.some((seg, i) => seg !== s[i])) expected = false;
        else expected = scope === 'Subtree' || d.length === s.length;
        cases.push({ declared: d, selected: s, scope: scope, expected: expected });
      }
}

for (const c of cases) {
  const got = matcher.navMatches(section(c.declared || [], c.scope), c.selected || []);
  check(`navMatches ${JSON.stringify(c.declared)} ${c.scope} @ ${JSON.stringify(c.selected)} = ${c.expected}`,
        got === c.expected, `got ${got}`);
}
check('truth table is not empty', cases.length > 0);
check('navPathOf survives a malformed attribute',
      Array.isArray(matcher.navPathOf(new FakeElement({ navpath: '{not json' }))));

/* ── 2. Collapsible tables (F1: 2.0.0-2.1.3 bound a class never emitted) ── */
function makeDom() {
  const els = {};
  function el(id, cls) {
    const e = {
      id: id, _handlers: {}, attrs: {}, innerHTML: '', children: {},
      classList: (function () {
        const s = new Set(cls);
        return {
          add: c => s.add(c), remove: c => s.delete(c), contains: c => s.has(c),
          toggle: (c, f) => { const on = f === undefined ? !s.has(c) : !!f; on ? s.add(c) : s.delete(c); return on; }
        };
      })(),
      setAttribute(k, v) { this.attrs[k] = String(v); },
      getAttribute(k) { return this.attrs[k]; },
      addEventListener(t, fn) { (this._handlers[t] = this._handlers[t] || []).push(fn); },
      click() { (this._handlers.click || []).forEach(fn => fn({})); },
      querySelector(sel) { return this.children[sel] || null; }
    };
    els[id] = e;
    return e;
  }
  /* exactly what Build-DhTableSections emits for -Collapsible -DefaultOpen:$false */
  const btn  = el('tsect-toggle-vms', ['table-section-toggle']);
  const body = el('tsect-body-vms',   ['table-section-body']);
  btn.children['.table-section-chevron'] = { innerHTML: '&#9656;' };
  const document = {
    querySelectorAll(sel) {
      if (sel !== '.table-section-toggle') throw new Error('unexpected selector ' + sel);
      return Object.values(els).filter(e => e.classList.contains('table-section-toggle'));
    },
    getElementById(id) { return els[id] || null; }
  };
  return { document, btn, body };
}

const collapseSrc = extract('DH-TABLE-COLLAPSE-START', 'DH-TABLE-COLLAPSE-END');
const dom = makeDom();
let renders = 0;
const engines = { vms: { render() { renders++; } } };
const init = new Function('document', 'engines', collapseSrc + '\nreturn initTableCollapsibles;')(dom.document, engines);

init();
check('a folded table starts closed', !dom.body.classList.contains('open'));
dom.btn.click();
check('clicking the toggle opens the body (.open on tsect-body-<id>)', dom.body.classList.contains('open'));
check('aria-expanded follows the state', dom.btn.getAttribute('aria-expanded') === 'true');
check('the chevron points down when open', dom.btn.children['.table-section-chevron'].innerHTML === '&#9662;');
check('opening re-renders the table engine', renders === 1);
dom.btn.click();
check('a second click closes it again', !dom.body.classList.contains('open'));
check('aria-expanded is false when closed', dom.btn.getAttribute('aria-expanded') === 'false');
init();
dom.btn.click();
check('calling init twice does not bind twice', dom.body.classList.contains('open') && renders === 2);

console.log(`nav.test.js: ${pass} passed, ${fail} failed (${cases.length} matcher cases)`);
process.exit(fail ? 1 : 0);
