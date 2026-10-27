function Get-DhJsSearch {
    # Fragment of the dashboard runtime JS (see Get-DhJsContent). v2.4.0.
    return @'
  /* =========================================================================
     REPORT SEARCH (v2.4.0) - New-DhDashboard -Search
     One box in the menu bar. It finds menu pages, block and table titles,
     findings, and table rows (a hit count per table). Table rows are scanned in
     time slices so a large table never freezes typing, with the same matcher the
     table's own filter uses (TableEngine._matchText). A result opens its page;
     a table hit goes through jumpToTable, so the filter, URL state and clear
     button behave exactly as for a click on a chart. All text goes through esc();
     the query is never written into innerHTML or the URL.
     ========================================================================= */

  /* Every searchable thing that is not a table row; built once, the page is static. */
  function dhSearchIndex() {
    var tree = buildNavTree(), out = { pages: [], findings: [] };
    (function walk(node) {
      node.order.forEach(function (seg) {
        var c = node.children[seg];
        out.pages.push({ kind: 'page', text: c.label, sub: c.path.join(' › '), path: c.path });
        walk(c);
      });
    })(tree);
    function pathOfEl(id) {
      var el = document.getElementById(id), sec = el && el.closest('[data-navpath]');
      return sec ? navPathOf(sec) : [];
    }
    (typeof BLOCKS_CONFIG !== 'undefined' ? BLOCKS_CONFIG : []).forEach(function (b) {
      var p = pathOfEl('block-' + b.id);
      if (b.title) out.pages.push({ kind: 'block', text: b.title, sub: p.join(' › '), path: p, elId: 'block-' + b.id });
      if (b.blockType === 'findings') {
        (b.findings || []).forEach(function (f) {
          out.findings.push({ kind: 'finding', text: f.title, sub: [f.area, p.join(' › ')].filter(Boolean).join(' · '),
            path: p, blockId: b.id, findingId: f.id,
            hay: [f.id, f.title, f.area, f.description, f.recommendation].join(' ').toLowerCase() });
        });
      }
    });
    TABLES_CONFIG.forEach(function (t) {
      out.pages.push({ kind: 'block', text: t.title || t.id, sub: pathOfEl('section-' + t.id).join(' › '), path: pathOfEl('section-' + t.id), elId: 'section-' + t.id });
    });
    return out;
  }

  function initSearch() {
    var input = document.getElementById('nav-search-input'), list = document.getElementById('nav-search-list');
    if (!input || !list) return;
    var index = null, timer = null, token = 0, flat = [], active = -1, current = '';

    function closeList() {
      list.hidden = true; list.innerHTML = '';
      input.setAttribute('aria-expanded', 'false'); input.removeAttribute('aria-activedescendant');
      flat = []; active = -1;
    }

    function render(groups, busy) {
      flat = []; var h = '';
      groups.forEach(function (g) {
        if (!g.items.length) return;
        h += '<div class="ns-group" role="presentation">' + esc(g.title) + '</div>';
        g.items.forEach(function (r) {
          var i = flat.push(r) - 1;
          h += '<button type="button" class="ns-item" role="option" id="ns-opt-' + i + '" data-i="' + i + '" aria-selected="false">' +
               (r.count !== undefined ? '<span class="ns-count">' + esc(r.count.toLocaleString()) + (r.partial ? '+' : '') + '</span>' : '') +
               esc(r.text) + (r.sub ? '<span class="ns-sub">' + esc(r.sub) + '</span>' : '') + '</button>';
        });
      });
      if (!flat.length) h = '<div class="ns-empty" role="presentation">' + (busy ? 'Searching…' : 'No results.') + '</div>';
      list.innerHTML = h; list.hidden = false;
      input.setAttribute('aria-expanded', 'true');
      active = -1;
    }

    function rank(text, term) {
      var t = String(text || '').toLowerCase(), i = t.indexOf(term);
      return i === -1 ? -1 : (i === 0 ? 0 : 1);
    }
    function pick(items, term, hayOf) {
      return items.map(function (r) { return { r: r, k: rank(hayOf ? hayOf(r) : r.text, term) }; })
        .filter(function (x) { return x.k >= 0; })
        .sort(function (a, b) { return a.k - b.k; })
        .slice(0, 8).map(function (x) { return x.r; });
    }

    function run(q) {
      var my = ++token, term = q.toLowerCase();
      if (!index) index = dhSearchIndex();
      var seenBlock = {};
      var pages = pick(index.pages, term).filter(function (r) {            /* a menu page and a block of the same name: show one */
        var k = r.kind + '|' + r.text + '|' + r.sub;
        if (seenBlock[k]) return false; seenBlock[k] = true; return true;
      });
      var findings = pick(index.findings, term, function (r) { return r.hay; });
      var tables = [];
      var groups = [{ title: 'Pages', items: pages }, { title: 'Findings', items: findings }, { title: 'Tables', items: tables }];
      render(groups, true);

      /* table rows: engine by engine, time-sliced, cancelled by newer input */
      var ids = Object.keys(engines), ei = 0, deadline = Date.now() + 1500, partial = false;
      function nextEngine() {
        if (my !== token) return;
        if (ei >= ids.length) { render(groups, false); return; }
        var id = ids[ei++], eng = engines[id], rows = eng.allData, cols = eng._visibleCols(), n = 0, ri = 0;
        function slice() {
          if (my !== token) return;
          var stop = Date.now() + 30;
          while (ri < rows.length && Date.now() < stop) {
            var lim = Math.min(rows.length, ri + 500);
            for (; ri < lim; ri++) if (eng._matchText(rows[ri], term, cols)) n++;
          }
          if (ri < rows.length) {
            if (Date.now() > deadline) { partial = true; finish(true); return; }
            setTimeout(slice, 0); return;
          }
          finish(false);
        }
        function finish(cut) {
          if (n > 0 && tables.length < 12) {
            var sec = document.getElementById('section-' + id);
            tables.push({ kind: 'table', text: eng.title || id, sub: (sec ? navPathOf(sec).join(' › ') : ''), id: id, count: n, partial: cut });
            tables.sort(function (a, b) { return b.count - a.count; });
            render(groups, true);
          }
          if (cut) { render(groups, false); return; }
          setTimeout(nextEngine, 0);
        }
        slice();
      }
      nextEngine();
    }

    function focusFinding(r) {
      var host = document.getElementById('block-' + r.blockId); if (!host) return;
      var els = host.querySelectorAll('[data-finding-id]'), el = null;
      for (var i = 0; i < els.length; i++) if (els[i].getAttribute('data-finding-id') === String(r.findingId)) { el = els[i]; break; }
      if (!el) return;
      if (el.hasAttribute('aria-selected')) { if (el.getAttribute('aria-selected') !== 'true') el.click(); }
      else {
        var btn = el.querySelector('button[aria-expanded="false"]');
        if (btn) btn.click();
      }
      if (el.scrollIntoView) el.scrollIntoView({ block: 'center' });
      el.classList.remove('dh-flash'); void el.offsetWidth; el.classList.add('dh-flash');
    }

    function go(r) {
      closeList();
      if (r.kind === 'page') applyNav(navAutoDescend(buildNavTree(), r.path));
      else if (r.kind === 'table') jumpToTable(r.id, current);
      else {
        if (r.path && r.path.length) applyNav(r.path);
        if (r.kind === 'finding') focusFinding(r);
        else { var el = document.getElementById(r.elId); if (el && el.scrollIntoView) { el.scrollIntoView({ block: 'start' }); el.classList.remove('dh-flash'); void el.offsetWidth; el.classList.add('dh-flash'); } }
      }
    }

    function setActive(i) {
      var opts = list.querySelectorAll('.ns-item');
      if (!opts.length) return;
      active = (i + opts.length) % opts.length;
      for (var k = 0; k < opts.length; k++) opts[k].setAttribute('aria-selected', k === active ? 'true' : 'false');
      input.setAttribute('aria-activedescendant', opts[active].id);
      if (opts[active].scrollIntoView) opts[active].scrollIntoView({ block: 'nearest' });
    }

    input.addEventListener('input', function () {
      clearTimeout(timer);
      current = input.value.trim();
      if (current.length < 2) { token++; closeList(); return; }
      timer = setTimeout(function () { run(current); }, 200);
    });
    input.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowDown') { e.preventDefault(); setActive(active + 1); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); setActive(active < 0 ? -1 : active - 1); }
      else if (e.key === 'Enter') { if (flat.length) { e.preventDefault(); go(flat[active >= 0 ? active : 0]); } }
      else if (e.key === 'Escape') { token++; if (!list.hidden) closeList(); else { input.value = ''; current = ''; input.blur(); } }
    });
    list.addEventListener('click', function (e) {
      var b = e.target.closest('.ns-item'); if (!b) return;
      var r = flat[parseInt(b.getAttribute('data-i'), 10)]; if (r) go(r);
    });
    document.addEventListener('click', function (e) {
      if (!list.hidden && !e.target.closest('#nav-search')) { token++; closeList(); }
    });
    document.addEventListener('keydown', function (e) {
      if (e.key !== '/' || e.ctrlKey || e.metaKey || e.altKey) return;
      var t = e.target, tag = t && t.tagName;
      if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || (t && t.isContentEditable)) return;
      e.preventDefault(); input.focus(); input.select();
    });
  }
'@
}
