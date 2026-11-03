/* 3.1.0 runtime tests: Add-DhGantt helpers (ticks, durations, time text, packing, layout, text placement). */
'use strict';
const test   = require('node:test');
const assert = require('node:assert/strict');
const { load } = require('./dh-extract');

const G = load('Get-DhJsBlocks.ps1',
  ['dhGanttFmtDur', 'dhGanttParts', 'dhGanttFmtAt', 'dhGanttTicks', 'dhGanttPack', 'dhGanttLayout', 'dhGanttTextPos']);
const wall = (y, mo, d, h, mi, s) => Date.UTC(y, mo - 1, d, h || 0, mi || 0, s || 0) / 1000;

test('durations read from seconds to years', () => {
  assert.equal(G.dhGanttFmtDur(45), '45s');
  assert.equal(G.dhGanttFmtDur(2.5), '2.5s');
  assert.equal(G.dhGanttFmtDur(446), '7m 26s');
  assert.equal(G.dhGanttFmtDur(600), '10m');
  assert.equal(G.dhGanttFmtDur(4426), '1h 14m');
  assert.equal(G.dhGanttFmtDur(3599.6), '1h');               /* rounding carries into the next unit */
  assert.equal(G.dhGanttFmtDur(3 * 86400 + 4 * 3600), '3d 4h');
  assert.equal(G.dhGanttFmtDur(5 * 604800), '5w');
  assert.equal(G.dhGanttFmtDur(200 * 86400), '7mo');
  assert.equal(G.dhGanttFmtDur(430 * 86400), '1y 2mo');
  assert.equal(G.dhGanttFmtDur(-90), '-1m 30s');
  assert.equal(G.dhGanttFmtDur(null), '');
});

test('a point in time is the wall clock it carries, in every axis form', () => {
  const o = wall(2026, 6, 13, 6, 10, 0);
  assert.equal(G.dhGanttFmtAt(0, null, 'elapsed', 100), '0s');
  assert.equal(G.dhGanttFmtAt(446, null, 'elapsed', 1000), '+7m 26s');
  assert.equal(G.dhGanttFmtAt(269, o, 'clock', 4500), '06:14:29');
  assert.equal(G.dhGanttFmtAt(86400 + 60, o, 'clock', 3 * 86400), '14 Jun 06:11');
  assert.equal(G.dhGanttFmtAt(0, wall(2026, 11, 3), 'date', 1e8), '2026-11-03');
  assert.equal(G.dhGanttFmtAt(3600, wall(2026, 11, 3), 'date', 1e8), '2026-11-03 01:00');
});

test('elapsed ticks: nice steps, zero is major, at most maxTicks', () => {
  const t = G.dhGanttTicks(0, 1051, null, 'elapsed', 8);
  assert.deepEqual(t.map(k => k.label), ['0', '+5m', '+10m', '+15m']);
  assert.equal(t[0].major, true);
  assert.ok(G.dhGanttTicks(0, 10, null, 'elapsed', 6).length <= 7);
  const years = G.dhGanttTicks(0, 20 * 31536000, null, 'elapsed', 6);
  assert.ok(years.length <= 7 && years.length >= 2);
});

test('clock ticks cross midnight with a date label', () => {
  const o = wall(2026, 6, 12, 22, 0, 0);
  const t = G.dhGanttTicks(0, 8.5 * 3600, o, 'clock', 6);
  assert.deepEqual(t.map(k => k.label), ['22:00', '13 Jun', '02:00', '04:00', '06:00']);
  assert.deepEqual(t.filter(k => k.major).map(k => k.label), ['13 Jun']);
  const sec = G.dhGanttTicks(0, 40, wall(2026, 1, 1, 8, 0, 0), 'clock', 6);
  assert.match(sec[1].label, /^08:00:\d\d$/);                 /* sub-minute steps show seconds */
});

test('week ticks start on Monday', () => {
  const o = wall(2026, 11, 4);                                  /* a Wednesday */
  const t = G.dhGanttTicks(0, 60 * 86400, o, 'date', 10);
  const first = new Date((o + t[0].t) * 1000);
  assert.equal(first.getUTCDay(), 1);
  assert.equal(t[0].label, '9 Nov');
});

test('month, quarter and year ticks follow the calendar', () => {
  const o = wall(2026, 1, 15);
  const months = G.dhGanttTicks(0, wall(2026, 7, 1) - o, o, 'date', 8);
  assert.deepEqual(months.map(k => k.label), ['Feb 2026', 'Mar 2026', 'Apr 2026', 'May 2026', 'Jun 2026', 'Jul 2026']);
  for (const k of months) assert.equal(new Date((o + k.t) * 1000).getUTCDate(), 1);  /* month lengths respected */
  const q = G.dhGanttTicks(0, wall(2028, 1, 1) - o, o, 'date', 8);
  assert.ok(q.every(k => /^Q[1-4] \d{4}$/.test(k.label)), q.map(k => k.label).join());
  assert.equal(q[0].label, 'Q2 2026');
  const y = G.dhGanttTicks(0, wall(2031, 6, 1) - o, o, 'date', 8);
  assert.deepEqual(y.map(k => k.label), ['2027', '2028', '2029', '2030', '2031']);
  assert.ok(y.every(k => k.major));
});

test('packing: overlaps go to sub-lines, touching bars share a line, deterministic', () => {
  const bars = [{ s: 0, e: 10 }, { s: 5, e: 8 }, { s: 10, e: 20 }, { s: 6, e: 7 }, { s: 12, e: null }];
  assert.equal(G.dhGanttPack(bars), 3);
  assert.deepEqual(bars.map(b => b.line), [0, 1, 0, 2, 1]);
  const again = [{ s: 0, e: 10 }, { s: 5, e: 8 }, { s: 10, e: 20 }, { s: 6, e: 7 }, { s: 12, e: null }];
  G.dhGanttPack(again);
  assert.deepEqual(again.map(b => b.line), bars.map(b => b.line));
  const ties = [{ s: 0, e: 5 }, { s: 0, e: 5 }];
  G.dhGanttPack(ties);
  assert.deepEqual(ties.map(b => b.line), [0, 1]);              /* equal starts keep declaration order */
});

test('layout: lanes by first appearance, shared rows, sort inside a lane', () => {
  const items = [
    { label: 'a', s: 30, e: 40, group: 'G1' },
    { label: 'b', s: 0,  e: 50, group: 'G2' },
    { label: 'c', s: 10, e: 20, group: 'G1' },
    { label: 'x', s: 0,  e: 5,  group: 'G1', row: 'R' },
    { label: 'y', s: 3,  e: 9,  group: 'G1', row: 'R' }
  ];
  const lanes = G.dhGanttLayout(items, 'start');
  assert.deepEqual(lanes.map(l => l.name), ['G1', 'G2']);
  assert.deepEqual(lanes[0].rows.map(r => r.label), ['R', 'c', 'a']);
  assert.equal(lanes[0].rows[0].bars.length, 2);
  assert.equal(lanes[0].rows[0].lines, 2);
  const byDur = G.dhGanttLayout(items.map(i => Object.assign({}, i)), 'duration');
  assert.deepEqual(byDur[0].rows.map(r => r.label), ['a', 'c', 'R']);  /* 10, 10, 9: ties keep order */
  const none = G.dhGanttLayout(items.map(i => Object.assign({}, i)), 'none');
  assert.deepEqual(none[0].rows.map(r => r.label), ['a', 'c', 'R']);
  const odd = G.dhGanttLayout([{ label: 'p', s: 0, e: 1, group: 'constructor' }], 'label');
  assert.equal(odd[0].name, 'constructor');                     /* no prototype keys leak in */
});

test('text goes inside when it fits, beside a lone bar when there is room, else nowhere', () => {
  assert.equal(G.dhGanttTextPos(10, 50, '7m 26s', 800, true), 'in');
  assert.equal(G.dhGanttTextPos(10, 2, '7m 26s', 800, true), 'right');
  assert.equal(G.dhGanttTextPos(95, 4, '7m 26s', 800, true), 'left');
  assert.equal(G.dhGanttTextPos(10, 2, '7m 26s', 800, false), 'none');
  assert.equal(G.dhGanttTextPos(10, 50, '', 800, true), 'none');
});
