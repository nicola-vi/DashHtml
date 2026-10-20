function Get-DhJsPrint {
    # Fragment of the dashboard runtime JS (see Get-DhJsContent). v2.2.0.
    return @'
  /* =========================================================================
     PRINT (v2.2.0)

     The interactive page shows one nav view at a time, folds things away and
     pages its tables. A printout needs the opposite, so between beforeprint
     and afterprint the page is temporarily rearranged:

       - light theme (dark backgrounds waste toner and print badly);
       - every nav view, in menu order, each under a heading with its path;
       - every table shows its filtered rows up to PRINT_CONFIG.maxRows, with
         "Showing N of M rows" when some were left out;
       - an optional cover page (New-DhDashboard -PrintCover).

     Expanding folded content (collapsibles, findings, tab panels, table
     sections) is done in CSS (@media print), so it also works for a printer
     that never runs these handlers. Everything here is undone on afterprint.

     Headless browsers printing to PDF (Edge/Chrome --print-to-pdf, used by
     report pipelines) fire beforeprint too, so they get the same layout.
     ========================================================================= */
  var _printState = null;

  function _navLabelPath(tree, path) {
    var labels = [], node = tree;
    for (var i = 0; i < path.length; i++) {
      node = node && node.children ? node.children[path[i]] : null;
      labels.push(node && node.label ? node.label : path[i]);
    }
    return labels;
  }

  /* Menu order: depth-first over the nav tree, children in the order the
     menu shows them. Returns pathKey -> rank. */
  function _navOrderIndex(tree) {
    var rank = {}, n = 0;
    (function walk(node) {
      rank[JSON.stringify(node.path || [])] = n++;
      (node.order || Object.keys(node.children || {})).forEach(function (k) {
        if (node.children[k]) walk(node.children[k]);
      });
    })(tree);
    return rank;
  }

  function _cssString(s) {
    return '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/[\r\n]+/g, ' ') + '"';
  }

  function dhBeforePrint() {
    if (_printState) return;                         /* already arranged */
    if (typeof dhDrawerClose === 'function') dhDrawerClose(true);   /* v2.3.0: no drawer on paper */
    var st = _printState = { theme: themeMode, moved: [], added: [], engines: {}, reopened: [] };
    /* v2.5.2: the group of removed rows (baseline markers) prints open */
    document.querySelectorAll('details.tbl-removed').forEach(function (d) {
      if (!d.open) { d.open = true; st.reopened.push(d); }
      /* 2.5.3: rows are drawn on open, and the toggle event fires too late for print: draw them now */
      var eng = engines[d.id.replace(/^chg-removed-/, '')];
      if (eng && eng._renderRemoved) eng._renderRemoved();
    });

    /* 1. light theme, without recording it as the reader's choice */
    if (themeMode !== 'light') applyThemeMode('light');
    document.documentElement.classList.add('dh-printing');

    /* 2. page header/footer text: title + page numbers (CSS @page boxes) */
    var pageCss = document.createElement('style');
    pageCss.setAttribute('data-dh-print', '');
    pageCss.textContent = '@page { @top-left { content: ' + _cssString(PRINT_CONFIG.title || document.title) +
      '; font-size: 8pt; color: #666; } @bottom-right { content: "Page " counter(page) " of " counter(pages); font-size: 8pt; color: #666; } }';
    document.head.appendChild(pageCss);
    st.added.push(pageCss);

    /* 3. every nav view, in menu order, each under its path */
    var main = document.querySelector('main.report-body');
    var tree = (typeof buildNavTree === 'function') ? buildNavTree() : null;
    if (main && tree) {
      var rank = _navOrderIndex(tree);
      var secs = Array.prototype.slice.call(main.querySelectorAll(':scope > [data-navpath]'));
      var withPath = secs.map(function (s, i) {
        var p = navPathOf(s);
        var scope = (s.dataset.navscope || 'exact').toLowerCase();
        return { el: s, path: p, global: scope === 'global' || !p.length, r: rank[JSON.stringify(p)], seq: parseInt(s.dataset.navseq || i, 10), i: i };
      }).filter(function (x) { return !x.global; });
      withPath.sort(function (a, b) {
        var ra = (a.r === undefined ? 1e9 : a.r), rb = (b.r === undefined ? 1e9 : b.r);
        return (ra - rb) || (a.seq - b.seq) || (a.i - b.i);
      });
      var lastKey = null;
      withPath.forEach(function (x) {
        st.moved.push({ el: x.el, parent: x.el.parentNode, next: x.el.nextSibling });
        var key = JSON.stringify(x.path);
        if (key !== lastKey) {
          var h = document.createElement('h2');
          h.className = 'dh-print-path';
          h.textContent = _navLabelPath(tree, x.path).join(' \u203A ');
          main.appendChild(h);
          st.added.push(h);
          lastKey = key;
        }
        main.appendChild(x.el);                       /* move, in menu order */
      });
    }

    /* 4. tables: all filtered rows up to maxRows */
    var maxRows = PRINT_CONFIG.maxRows || 200;
    Object.keys(engines).forEach(function (id) {
      var eng = engines[id];
      var total = eng._getFiltered().length;
      st.engines[id] = true;
      eng._printRows = Math.max(1, maxRows);
      eng.render();
      if (total > maxRows) {
        var sec = document.getElementById('section-' + id);
        var wrap = sec && sec.querySelector('.table-wrapper');
        if (wrap) {
          var note = document.createElement('p');
          note.className = 'dh-print-note';
          note.textContent = 'Showing ' + maxRows + ' of ' + total + ' rows. Full data in the interactive report.';
          wrap.parentNode.insertBefore(note, wrap.nextSibling);
          st.added.push(note);
        }
      }
    });

    /* 5. cover page */
    if (PRINT_CONFIG.cover) {
      var cover = document.createElement('section');
      cover.className = 'dh-print-cover';
      var hdr = document.querySelector('.report-header');
      if (hdr) {
        var logo = hdr.querySelector('.report-logo');
        if (logo) cover.appendChild(logo.cloneNode(true));
        var t = hdr.querySelector('.report-title');
        if (t) { var h1 = document.createElement('h1'); h1.textContent = t.textContent; cover.appendChild(h1); }
        var sub = hdr.querySelector('.report-subtitle');
        if (sub) cover.appendChild(sub.cloneNode(true));
        var info = hdr.querySelector('.info-fields-grid');
        if (info) cover.appendChild(info.cloneNode(true));
        var gen = hdr.querySelector('.header-meta');
        if (gen) cover.appendChild(gen.cloneNode(true));
      }
      /* the overall assessment (verdict) and, from 2.3.0, the score ring */
      ['.tile-verdict', '.tile-score'].forEach(function (sel) {
        var tileEl = document.querySelector(sel);
        if (tileEl) {
          var vwrap = document.createElement('div');
          vwrap.className = 'dh-print-cover-verdict';
          vwrap.appendChild(tileEl.cloneNode(true));
          cover.appendChild(vwrap);
        }
      });
      document.body.insertBefore(cover, document.body.firstChild);
      st.added.push(cover);
    }
  }

  function dhAfterPrint() {
    var st = _printState;
    if (!st) return;
    _printState = null;
    /* put sections back exactly where they were, last-moved first */
    for (var i = st.moved.length - 1; i >= 0; i--) {
      var m = st.moved[i];
      m.parent.insertBefore(m.el, m.next && m.next.parentNode === m.parent ? m.next : null);
    }
    st.added.forEach(function (el) { if (el.parentNode) el.parentNode.removeChild(el); });
    Object.keys(st.engines).forEach(function (id) {
      if (engines[id]) { engines[id]._printRows = 0; engines[id].render(); }
    });
    (st.reopened || []).forEach(function (d) { d.open = false; });
    document.documentElement.classList.remove('dh-printing');
    if (st.theme !== themeMode) applyThemeMode(st.theme);
  }

  function initPrint() {
    window.addEventListener('beforeprint', dhBeforePrint);
    window.addEventListener('afterprint', dhAfterPrint);
    var btn = document.getElementById('btn-print');
    if (btn) btn.addEventListener('click', function () { window.print(); });
  }
  window._dhBeforePrint = dhBeforePrint;   /* for pipelines that print without events */
  window._dhAfterPrint  = dhAfterPrint;

'@
}
