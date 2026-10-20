/* DashHtml accessibility probe. Runs inside an exported report and returns
   { rules: [{ rule, severity, count, samples: [] }] }. Used by Tools\Test-DhA11y.ps1 (and by hand in a browser).
   Rules are deliberately small and concrete: names, roles, ids, sort state, dialogs, landmarks. */
(function (root) {
  function samples(list) { return list.slice(0, 4).map(function (e) { return (e.tagName || '?').toLowerCase() + (e.id ? '#' + e.id : '') + (typeof e.className === 'string' && e.className ? '.' + e.className.trim().split(/\s+/)[0] : '') + ' "' + ((e.textContent || '').trim().slice(0, 24)) + '"'; }); }
  function visible(e) { var cs = getComputedStyle(e); return cs.display !== 'none' && cs.visibility !== 'hidden' && !e.closest('[hidden]'); }
  function nameOf(e) {
    if (e.getAttribute('aria-label')) return e.getAttribute('aria-label').trim();
    var lb = e.getAttribute('aria-labelledby');
    if (lb) { var t = lb.split(/\s+/).map(function (id) { var n = document.getElementById(id); return n ? n.textContent : ''; }).join(' ').trim(); if (t) return t; }
    if (e.tagName === 'INPUT' || e.tagName === 'SELECT' || e.tagName === 'TEXTAREA') {
      if (e.id) { var l = document.querySelector('label[for="' + CSS.escape(e.id) + '"]'); if (l && l.textContent.trim()) return l.textContent.trim(); }
      var wrap = e.closest('label'); if (wrap && wrap.textContent.trim()) return wrap.textContent.trim();
    }
    if ((e.textContent || '').trim()) return e.textContent.trim();
    if (e.getAttribute('title')) return e.getAttribute('title').trim();
    var img = e.querySelector('svg[aria-label], img[alt]'); if (img) return (img.getAttribute('aria-label') || img.getAttribute('alt') || '').trim();
    return '';
  }
  var rules = [];
  function add(rule, severity, list) { if (list.length) rules.push({ rule: rule, severity: severity, count: list.length, samples: samples(list) }); }

  /* ids */
  var seen = {}, dups = [];
  document.querySelectorAll('[id]').forEach(function (e) { if (seen[e.id]) dups.push(e); else seen[e.id] = 1; });
  add('duplicate-id', 'error', dups);

  /* names */
  var ctl = [].slice.call(document.querySelectorAll('button, [role=button], input:not([type=hidden]), select, textarea, a[href], [role=tab], [role=treeitem], [role=checkbox], [role=switch], [role=menuitem]')).filter(visible);
  add('control-without-name', 'error', ctl.filter(function (e) { return !nameOf(e); }));

  /* sortable headers */
  var sortable = [].slice.call(document.querySelectorAll('th.sortable')).filter(visible);
  add('sortable-header-without-aria-sort', 'error', sortable.filter(function (e) { return !e.hasAttribute('aria-sort'); }));
  add('sortable-header-not-keyboard-operable', 'error', sortable.filter(function (e) { return !e.hasAttribute('tabindex') && !e.querySelector('button, a[href]'); }));

  /* roles with required state */
  add('tab-without-aria-selected', 'error', [].slice.call(document.querySelectorAll('[role=tab]')).filter(function (e) { return !e.hasAttribute('aria-selected'); }));
  add('treeitem-without-aria-level', 'warning', [].slice.call(document.querySelectorAll('[role=treeitem]')).filter(function (e) { return !e.hasAttribute('aria-level'); }));
  add('expandable-without-aria-expanded', 'error', [].slice.call(document.querySelectorAll('.collapsible-toggle, .table-section-toggle, .finding-head, [data-expands]')).filter(visible).filter(function (e) { return !e.hasAttribute('aria-expanded'); }));
  add('expandable-not-keyboard-operable', 'error', [].slice.call(document.querySelectorAll('.collapsible-toggle')).filter(visible).filter(function (e) { return e.tagName !== 'BUTTON' && !(e.getAttribute('role') === 'button' && e.getAttribute('tabindex') === '0'); }));
  add('positive-tabindex', 'warning', [].slice.call(document.querySelectorAll('[tabindex]')).filter(function (e) { return parseInt(e.getAttribute('tabindex'), 10) > 0; }));

  /* dialogs */
  var drawers = [].slice.call(document.querySelectorAll('.dh-drawer, #dh-drawer, [data-drawer]'));
  add('drawer-without-dialog-role', 'error', drawers.filter(function (e) { return e.getAttribute('role') !== 'dialog' && e.getAttribute('role') !== 'complementary'; }));
  add('dialog-without-name', 'error', [].slice.call(document.querySelectorAll('[role=dialog]')).filter(function (e) { return !e.getAttribute('aria-label') && !e.getAttribute('aria-labelledby'); }));

  /* tables */
  var tbls = [].slice.call(document.querySelectorAll('table.data-table')).filter(visible);
  add('table-without-name', 'warning', tbls.filter(function (t) { return !t.getAttribute('aria-label') && !t.getAttribute('aria-labelledby') && !t.querySelector('caption'); }));
  add('table-selection-not-announced', 'warning', tbls.filter(function (t) { var info = document.getElementById('info-' + String(t.id).replace(/^tbl-/, '')); return t.querySelector('.col-select') && !(info && info.hasAttribute('aria-live')); }));
  add('row-selection-without-aria-selected', 'warning', [].slice.call(document.querySelectorAll('tr.selected, tr.row-selected, tr.sel')).filter(function (e) { return !e.hasAttribute('aria-selected'); }));

  /* page */
  var page = [];
  if (!document.documentElement.getAttribute('lang')) page.push(document.documentElement);
  add('html-without-lang', 'error', page);
  if (!document.querySelector('main, [role=main]')) add('no-main-landmark', 'error', [document.body]);
  add('nav-without-name', 'warning', [].slice.call(document.querySelectorAll('nav, [role=navigation]')).filter(function (e) { return !e.getAttribute('aria-label') && !e.getAttribute('aria-labelledby'); }));
  add('images-without-alt', 'error', [].slice.call(document.querySelectorAll('img')).filter(function (e) { return !e.hasAttribute('alt'); }));
  add('svg-img-without-name', 'warning', [].slice.call(document.querySelectorAll('svg[role=img]')).filter(function (e) { return !e.getAttribute('aria-label') && !e.getAttribute('aria-labelledby') && !e.querySelector('title'); }));
  add('no-focus-visible-style', 'warning', (function () { var css = [].slice.call(document.styleSheets).map(function (s) { try { return [].slice.call(s.cssRules).map(function (r) { return r.cssText; }).join(''); } catch (e) { return ''; } }).join(''); return /:focus-visible/.test(css) ? [] : [document.body]; })());
  add('no-reduced-motion-rule', 'warning', (function () { var css = [].slice.call(document.styleSheets).map(function (s) { try { return [].slice.call(s.cssRules).map(function (r) { return r.cssText; }).join(''); } catch (e) { return ''; } }).join(''); return /prefers-reduced-motion/.test(css) ? [] : [document.body]; })());
  return { rules: rules };
})(document);