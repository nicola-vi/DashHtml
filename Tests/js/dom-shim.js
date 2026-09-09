/* Minimal DOM shim for testing the DashHtml nav matcher under Node.
 *
 * Implements only what applyNav touches: querySelectorAll for attribute
 * selectors, element.dataset, and classList (add/remove/contains/toggle).
 * No browser, no Playwright, deterministic, runs in well under a second.
 *
 * Deliberately tiny: if applyNav ever needs more of the DOM than this, that is
 * a signal the runtime is drifting back towards imperative show/hide instead of
 * deriving state from one rule.
 */
'use strict';

class ClassList {
  constructor() { this._s = new Set(); }
  add(c)      { this._s.add(c); }
  remove(c)   { this._s.delete(c); }
  contains(c) { return this._s.has(c); }
  toggle(c, force) {
    if (force === undefined) { this._s.has(c) ? this._s.delete(c) : this._s.add(c); return this._s.has(c); }
    if (force) this._s.add(c); else this._s.delete(c);
    return force;
  }
  get value() { return [...this._s].join(' '); }
}

class FakeElement {
  /** @param {object} dataset e.g. { navpath: '["Storage"]', navscope: 'subtree' } */
  constructor(dataset = {}, id = null) {
    this.dataset   = { ...dataset };
    this.id        = id;
    this.classList = new ClassList();
    this.style      = {};
  }
  get active() { return this.classList.contains('panel-active'); }
}

class FakeDocument {
  constructor(elements = []) { this._els = elements; }
  add(el) { this._els.push(el); return el; }

  /* Supports only the attribute-presence form applyNav uses: '[data-navpath]'.
     Anything else throws loudly rather than silently matching nothing — a
     silent empty match is exactly the failure mode we are testing against. */
  querySelectorAll(selector) {
    const m = /^\[data-([a-z-]+)\]$/.exec(selector.trim());
    if (!m) throw new Error(`dom-shim: unsupported selector ${JSON.stringify(selector)}`);
    const key = m[1].replace(/-([a-z])/g, (_, c) => c.toUpperCase());
    return this._els.filter(e => e.dataset[key] !== undefined);
  }
}

module.exports = { ClassList, FakeElement, FakeDocument };
