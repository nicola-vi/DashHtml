/* WP2 SPIKE — does a Node + DOM-shim test actually catch the NavSubGroup bug?
 *
 * proposed.md §4(b) asserts this approach "would have caught the reported bug in
 * a single assertion". That was untested. This spike settles it before any
 * production code is written against the assumption.
 *
 * Run: node Tests/js/nav-spike.test.js
 */
'use strict';
const { FakeElement, FakeDocument } = require('./dom-shim');

let pass = 0, fail = 0;
function check(name, cond, detail) {
  if (cond) { pass++; console.log(`  [+] ${name}`); }
  else      { fail++; console.log(`  [-] ${name}${detail ? '\n        ' + detail : ''}`); }
}

/* ── The 2.0.0 matcher (proposed.md §3.2) ──────────────────────────────── */
function navMatches(sec, path) {
  const scope = sec.dataset.navscope || 'exact';
  if (scope === 'global') return true;
  const p = JSON.parse(sec.dataset.navpath || '[]');
  if (p.length > path.length) return false;
  for (let i = 0; i < p.length; i++) if (p[i] !== path[i]) return false;
  return scope === 'subtree' || p.length === path.length;
}
function applyNav(doc, path) {
  doc.querySelectorAll('[data-navpath]').forEach(s =>
    s.classList.toggle('panel-active', navMatches(s, path)));
}

/* ── The 1.x asymmetry (Get-DhJsNav.ps1:200-204) ──────────────────────────
   Hide clears panel-active AND sets display:none; show clears ONLY the inline
   style. Because .block-section{display:none} / .panel-active{display:block},
   a section that lost panel-active never returns.

   NOTE: this is a SIMPLIFIED model, present only to prove the structural
   assertion discriminates. It treats every depth-2 segment as a subgroup, so it
   also flags tables — whereas real 1.x drives tables through the subnav-link
   path and they work correctly (confirmed in a browser during review). The
   faithful, browser-verified claim is narrower: BLOCKS in a non-first subgroup
   are unreachable. Do not read this function as a 1.x emulator.             */
function applyNavLegacy(doc, subGroupName) {
  doc.querySelectorAll('[data-navpath]').forEach(s => {
    const p = JSON.parse(s.dataset.navpath || '[]');
    const sg = p.length > 1 ? p[1] : undefined;
    if (sg === undefined) return;                       // untagged: left alone
    if (subGroupName === '' || sg === subGroupName) {
      delete s.style.display;                           // show: inline style only
    } else {
      s.style.display = 'none';
      s.classList.remove('panel-active');               // ← the asymmetry
    }
  });
}
const legacyVisible = s => s.classList.contains('panel-active') && s.style.display !== 'none';

/* ── Fixture: the exact shape from the browser repro ─────────────────────── */
function fixture() {
  const mk = (id, path, scope) =>
    new FakeElement({ navpath: JSON.stringify(path), navscope: scope }, id);
  return new FakeDocument([
    mk('chartCap',  ['Storage', 'Capacity'], 'subtree'),
    mk('chartTag',  ['Storage', 'Tagging'],  'subtree'),
    mk('tblA',      ['Storage', 'Capacity', 'tblA'], 'exact'),
    mk('tblB',      ['Storage', 'Tagging',  'tblB'], 'exact'),
    mk('grpOnly',   ['Storage'],             'subtree'),
    mk('globalBan', [],                      'global'),
    mk('netTbl',    ['Network', 'tblC'],     'exact'),
  ]);
}
const byId = (doc, id) => doc._els.find(e => e.id === id);

/* ── Every reachable path in the fixture tree ───────────────────────────── */
function allPaths(doc) {
  const set = new Set();
  doc._els.forEach(e => {
    const p = JSON.parse(e.dataset.navpath || '[]');
    for (let i = 1; i <= p.length; i++) set.add(JSON.stringify(p.slice(0, i)));
  });
  set.add('[]');
  return [...set].map(JSON.parse);
}

console.log('\nWP2 SPIKE — Node DOM shim\n');

/* 1. THE headline claim: one structural assertion catches the bug. */
console.log('1. Structural test: no content unreachable');
{
  const doc = fixture(), paths = allPaths(doc);
  const unreachable = doc._els.filter(sec =>
    !paths.some(p => { applyNav(doc, p); return sec.classList.contains('panel-active'); }));
  check('2.0.0 matcher: every section reachable from some path',
        unreachable.length === 0,
        unreachable.length ? 'unreachable: ' + unreachable.map(e => e.id).join(', ') : '');
}
{
  // Same assertion against the 1.x behaviour must FAIL, or it proves nothing.
  const doc = fixture();
  doc._els.forEach(e => e.classList.add('panel-active'));   // initial render
  const subgroups = ['Capacity', 'Tagging'];
  const everVisible = new Set();
  subgroups.forEach(sg => {
    applyNavLegacy(doc, sg);
    doc._els.forEach(e => { if (legacyVisible(e)) everVisible.add(e.id); });
  });
  const lost = doc._els.filter(e => !everVisible.has(e.id) &&
                                    JSON.parse(e.dataset.navpath || '[]').length > 1);
  check('1.x behaviour: SAME assertion detects unreachable content',
        lost.length > 0,
        'expected the legacy model to lose content; lost = [' + lost.map(e => e.id).join(', ') + ']');
  console.log(`        (legacy loses: ${lost.map(e => e.id).join(', ') || 'nothing'})`);
}

/* 2. The specific reported bug. */
console.log('\n2. Reported bug: block in a non-first subgroup');
{
  const doc = fixture();
  applyNav(doc, ['Storage', 'Tagging']);
  check('chartTag is visible when its own node is selected', byId(doc, 'chartTag').active);
  check('chartCap is hidden there', !byId(doc, 'chartCap').active);
  applyNav(doc, ['Storage', 'Capacity']);
  check('chartCap returns when re-selected (1.x never did)', byId(doc, 'chartCap').active);
}

/* 3. Scope semantics. */
console.log('\n3. Scope semantics');
{
  const doc = fixture();
  applyNav(doc, ['Storage', 'Capacity', 'tblA']);
  check('Subtree parent visible from a descendant path', byId(doc, 'grpOnly').active);
  check('Global visible anywhere',                        byId(doc, 'globalBan').active);
  check('Exact leaf visible at its exact path',           byId(doc, 'tblA').active);
  check('Exact leaf hidden one level up', (applyNav(doc, ['Storage', 'Capacity']), !byId(doc, 'tblA').active));
  applyNav(doc, ['Network']);
  check('Other branch hidden',        !byId(doc, 'chartCap').active);
  check('Global still visible there',  byId(doc, 'globalBan').active);
}

/* 4. Idempotence + order independence — the property 1.x lacked. */
console.log('\n4. Idempotence and order independence');
{
  const doc = fixture();
  const snap = () => doc._els.map(e => e.id + ':' + e.active).join('|');
  applyNav(doc, ['Storage', 'Tagging']); const once = snap();
  applyNav(doc, ['Storage', 'Tagging']); check('re-applying the same path is a no-op', snap() === once);
  applyNav(doc, ['Network']); applyNav(doc, ['Storage', 'Capacity']); applyNav(doc, ['Storage', 'Tagging']);
  check('state depends only on the final path, not the route', snap() === once);
}

console.log(`\n${pass} passed, ${fail} failed\n`);
process.exit(fail === 0 ? 0 : 1);
