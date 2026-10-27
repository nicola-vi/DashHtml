function Get-DhJsNav {
    # Auto-split fragment of the dashboard runtime JS (see Get-DhJsContent).
    return @'
  /* =========================================================================
     NAVIGATION (v2.0.0) — one depth-agnostic menu tree

     A section is visible IFF it carries panel-active. NOTHING else ever touches
     style.display on a section. State is RECOMPUTED WHOLE from the selected
     path, never patched incrementally.

     This replaces the 1.x showGroup / showSubPanel / showSubGroup /
     _showFlatPanel quartet, which mutated overlapping subsets of the state
     using two competing mechanisms (an inline style.display AND the
     panel-active class). That is what made a block declared with
     -NavGroup + -NavSubGroup permanently unreachable (readme-dev gotcha #26):
     the hide branch cleared both, the show branch restored only one.

     There are no show/hide branches left to keep symmetrical. Re-applying the
     same path is a no-op, and the result depends only on the final path, never
     on the route taken to reach it.

     Nothing below mentions a number of levels. Depth is data.
     ========================================================================= */

  /* ── Sync nav sticky top to actual header height ────────────────── */
  function syncNavTop() {
    var header = document.querySelector('.report-header');
    var nav    = document.getElementById('report-nav');
    if (!header || !nav) return;
    document.documentElement.style.setProperty('--header-height', header.offsetHeight + 'px');
  }

  /* ── Collapsible table chrome ──────────────────────────────────────
     Build-DhTableSections emits button#tsect-toggle-<id> and
     div#tsect-body-<id>; .open on the body is what the CSS unfolds.
     2.0.0 bound a class that was never emitted (.table-collapse-toggle),
     so a -DefaultOpen:$false table could never be opened. Fixed in 2.1.4;
     this is the 1.5.1 binding again. */
  /* ==== DH-TABLE-COLLAPSE-START ==== (driven by Tests/js/nav.test.js) */
  function initTableCollapsibles() {
    document.querySelectorAll('.table-section-toggle').forEach(function (btn) {
      if (btn._dhWired) return;
      var body = document.getElementById(btn.id.replace(/^tsect-toggle-/, 'tsect-body-'));
      if (!body) return;
      btn._dhWired = true;
      var chev = btn.querySelector('.table-section-chevron');
      btn.addEventListener('click', function () {
        var open = body.classList.toggle('open');
        btn.classList.toggle('open', open);
        btn.setAttribute('aria-expanded', open ? 'true' : 'false');
        if (chev) chev.innerHTML = open ? '&#9662;' : '&#9656;';
        /* a table first laid out while folded measured nothing — re-render */
        var eng = engines[btn.id.replace(/^tsect-toggle-/, '')];
        if (open && eng) eng.render();
      });
    });
  }
  /* ==== DH-TABLE-COLLAPSE-END ==== */

  /* ─────────────────────────────────────────────────────────────────
     THE MATCHER — mirrors Test-DhNavMatch in PowerShell exactly.
     Extracted verbatim by Tests/js/nav.test.js via these sentinels, so the
     two copies cannot drift apart unnoticed. Keep them.
     ───────────────────────────────────────────────────────────────── */
  /* ==== DH-NAV-MATCHER-START ==== */
  function navPathOf(sec) {
    try { return JSON.parse(sec.dataset.navpath || '[]'); } catch (e) { return []; }
  }
  function navMatches(sec, path) {
    var scope = (sec.dataset.navscope || 'exact').toLowerCase();
    if (scope === 'global') return true;
    var p = navPathOf(sec);
    /* the reserved last segment '*' selects an 'All' view: everything at or below the parent,
       whatever its scope, plus Subtree items declared above it (mirrors Test-DhNavMatch) */
    if (path.length && path[path.length - 1] === '*') {
      var base = path.slice(0, -1), n = Math.min(p.length, base.length);
      for (var k = 0; k < n; k++) { if (p[k] !== base[k]) return false; }
      return p.length >= base.length ? true : scope === 'subtree';
    }
    if (p.length > path.length) return false;                 /* declared deeper than selected */
    for (var i = 0; i < p.length; i++) { if (p[i] !== path[i]) return false; }
    return scope === 'subtree' || p.length === path.length;
  }
  /* ==== DH-NAV-MATCHER-END ==== */

  var currentNavPath = [];

  function navSections() { return document.querySelectorAll('[data-navpath]'); }

  /* ── Tree, derived from the DOM ──────────────────────────────────
     Built from the same data-navpath attributes the matcher reads, so a menu
     strip can never describe a view the content does not have, nor miss one it
     does. That drift was defect #2 in the proposal.                        */
  /* Removes dead-end nodes from the menu tree (mutates it). `hasOwn(path)` says whether a view at that
     path would show anything. A node stays when it is declared, has own content, or keeps a child.
     Returns whether `node` itself stays; the root is never removed. */
  function dhNavPrune(node, hasOwn) {
    var keepKids = [];
    node.order.forEach(function (k) {
      var child = node.children[k];
      if (dhNavPrune(child, hasOwn)) keepKids.push(k); else delete node.children[k];
    });
    node.order = keepKids;
    if (!node.path.length) return true;
    return !!node.declared || keepKids.length > 0 || !!hasOwn(node.path);
  }

  function buildNavTree() {
    var root = { seg: '', path: [], label: '', children: {}, order: [], hasContent: false };
    navSections().forEach(function (sec) {
      if (sec.classList.contains('alert-banner')) return;      /* a banner follows the menu, it never adds to it */
      var p = navPathOf(sec);
      if (!p.length) return;                                   /* global: no menu node */
      var scope = (sec.dataset.navscope || 'exact').toLowerCase();
      var node  = root;
      for (var i = 0; i < p.length; i++) {
        if (!node.children[p[i]]) {
          node.children[p[i]] = { seg: p[i], path: p.slice(0, i + 1), label: p[i],
                                  children: {}, order: [], hasContent: false, tableId: null,
                                  seq: Infinity, navOrder: 0 };
          node.order.push(p[i]);
        }
        node = node.children[p[i]];
        /* A node inherits the EARLIEST declaration that passes through it, so an
           ancestor created late by a deep path still sorts by its first mention. */
        var seq = parseInt(sec.dataset.navseq || '0', 10);
        if (seq < node.seq) node.seq = seq;
        /* -NavOrder orders the item's OWN node among its siblings, not its ancestors
           (Get-DhNavTree does the same). It used to be applied at every level, so an
           ordered leaf also moved its parent ahead of unordered siblings. */
        var ord = parseInt(sec.dataset.navorder || '0', 10);
        if (i === p.length - 1 && ord !== 0 && node.navOrder === 0) node.navOrder = ord;
      }
      if (scope === 'exact') node.hasContent = true;
      if (sec.dataset.navlabel) node.label = sec.dataset.navlabel;
      /* A table section sitting exactly here lets its chip carry a row-count
         badge, replacing the 1.x .nav-badge that lived in the flat nav link. */
      if (scope === 'exact' && sec.id && sec.id.indexOf('section-') === 0) {
        node.tableId = sec.id.slice('section-'.length);
      }
    });
    /* New-DhDashboard -NavTree: the menu skeleton. It creates nodes before anything sits on them (an
       empty one shows a "no content" note), puts its own order ahead of declaration order, and supplies
       a label and -NavOrder only where an item gave none (an item's own values win). */
    var navElT = document.getElementById('report-nav');
    if (navElT && navElT.dataset.navtree) {
      var skel = [];
      try { skel = JSON.parse(navElT.dataset.navtree); } catch (e) { skel = []; }
      skel.forEach(function (s, si) {
        var nd = root;
        for (var q = 0; q < s.path.length; q++) {
          if (!nd.children[s.path[q]]) {
            nd.children[s.path[q]] = { seg: s.path[q], path: s.path.slice(0, q + 1), label: s.path[q],
                                       children: {}, order: [], hasContent: false, tableId: null, seq: Infinity, navOrder: 0 };
            nd.order.push(s.path[q]);
          }
          nd = nd.children[s.path[q]];
          if (-100000 + si < nd.seq) nd.seq = -100000 + si;
        }
        if (s.label && nd.label === nd.seg) nd.label = s.label;
        if (s.order && nd.navOrder === 0) nd.navOrder = s.order;
        nd.declared = true;                                  /* an author-declared node is never pruned */
      });
    }
    /* Dead ends: a node with no view content of its own and nothing below it (a Global item that carries a
       path, a lone deleted branch) leads to a blank page, so it is left out of the menu. A node declared in
       -NavTree is the author's intent and stays. */
    dhNavPrune(root, function (path) {
      var secs = navSections();
      for (var i = 0; i < secs.length; i++) {
        var sec = secs[i];
        if (sec.classList.contains('alert-banner') || (sec.dataset.navscope || 'exact').toLowerCase() === 'global' || !navPathOf(sec).length) continue;
        if (navMatches(sec, path)) return true;
      }
      return false;
    });
    /* New-DhDashboard -NavAllLabel: an addressable 'All' child ('*') on a group node. It lists the parent's
       own content and everything below it, and sorts first among its siblings. */
    var navEl = document.getElementById('report-nav');
    if (navEl && (navEl.dataset.navall || navEl.dataset.navallall)) {
      var allMap = {}, allDefault = navEl.dataset.navallall || '';
      try { (JSON.parse(navEl.dataset.navall || '[]')).forEach(function (a) { allMap[JSON.stringify(a.path)] = a.label; }); } catch (e) {}
      (function addAll(node) {
        Object.keys(node.children).forEach(function (k) { addAll(node.children[k]); });
        if (node === root || !node.order.length) return;
        var lab = allMap[JSON.stringify(node.path)] || allDefault;
        if (lab && !node.children['*']) {
          node.children['*'] = { seg: '*', path: node.path.concat('*'), label: lab, children: {}, order: [], hasContent: true,
                                 tableId: null, seq: -Infinity, navOrder: -1 };
          node.order.push('*');
        }
      })(root);
    }
    /* Sort every level: explicit -NavOrder first, then declaration order.
       Mirrors Get-DhNavChildOrder in PowerShell. */
    (function sortTree(node) {
      node.order.sort(function (a, b) {
        var A = node.children[a], B = node.children[b];
        var ao = A.navOrder !== 0 ? 0 : 1, bo = B.navOrder !== 0 ? 0 : 1;
        if (ao !== bo) return ao - bo;
        if (A.navOrder !== B.navOrder) return A.navOrder - B.navOrder;
        return A.seq - B.seq;
      });
      node.order.forEach(function (k) { sortTree(node.children[k]); });
    })(root);
    return root;
  }

  function navNodeAt(tree, path) {
    var node = tree;
    for (var i = 0; i < path.length; i++) {
      if (!node.children[path[i]]) return null;
      node = node.children[path[i]];
    }
    return node;
  }

  /* Descend to the first node that holds content of its own, then STOP.
     At depth <= 3 this is identical to descend-to-first-leaf; deeper, it stops
     one click teleporting the reader several levels down. */
  function navAutoDescend(tree, path) {
    var out  = path.slice();
    var node = navNodeAt(tree, out);
    if (!node) return out;
    while (!node.hasContent && node.order.length) {
      var next = node.order.filter(function (k) { return k !== '*'; })[0];   /* the All view is never the default */
      if (next === undefined) break;
      out.push(next);
      node = node.children[next];
    }
    return out;
  }

  /* ── THE ONE RULE ────────────────────────────────────────────────── */
  function applyNav(path) {
    currentNavPath = (path || []).slice();
    /* v2.3.0: the detail drawer lives on <body>, so it would otherwise keep showing
       a record from a view that is no longer visible. */
    if (typeof dhDrawerClose === 'function') dhDrawerClose(true);
    navSections().forEach(function (sec) {
      sec.classList.toggle('panel-active', navMatches(sec, currentNavPath));
    });
    /* the menu is rebuilt on every change: put keyboard focus back on the same item */
    var fa = document.activeElement, focusKey = null;
    if (fa && fa.dataset && fa.dataset.navto && fa.closest && fa.closest('#report-nav, #nav-sidebar')) focusKey = fa.dataset.navto;
    renderNavMenu(currentNavPath);
    if (focusKey) {
      var again = document.querySelectorAll('[data-navto]');
      for (var fi = 0; fi < again.length; fi++) if (again[fi].dataset.navto === focusKey) { try { again[fi].focus({ preventScroll: true }); } catch (e) {} break; }
    }
    updateEmptyView();
    if (typeof URLState !== 'undefined' && URLState.save) URLState.save();
    if (typeof updateNavBadges === 'function') updateNavBadges();
  }

  /* v2.5.0 - a selected view with nothing of its own (an empty -NavTree node, a deep link to a
     renamed node) says so instead of showing a blank page. Banners, global and path-less items do
     not count as content. */
  function updateEmptyView() {
    var el = document.getElementById('nav-empty');
    var own = false;
    navSections().forEach(function (sec) {
      if (own || sec.classList.contains('alert-banner') || !sec.classList.contains('panel-active')) return;
      if ((sec.dataset.navscope || 'exact').toLowerCase() === 'global' || !navPathOf(sec).length) return;
      own = true;
    });
    if (own || !currentNavPath.length) { if (el) el.hidden = true; return; }
    if (!el) {
      el = document.createElement('div');
      el.id = 'nav-empty'; el.className = 'nav-empty'; el.setAttribute('role', 'status');
      var host = document.querySelector('main') || document.body;
      host.appendChild(el);
    }
    var nav = document.getElementById('report-nav');
    var parent = currentNavPath.length > 1 ? currentNavPath.slice(0, -1) : null;
    el.innerHTML = '<strong>No content in this view.</strong>' +
      (nav && nav.dataset.navstrict === 'true' ? ' Nothing is declared at <code>' + esc(currentNavPath.join(' / ')) + '</code>: check the -NavPath of the items that should be here.' : '') +
      (parent ? ' <button type="button" class="nav-empty-back">Back to ' + esc(parent[parent.length - 1] === '*' ? 'the group' : parent.join(' / ')) + '</button>' : '');
    el.hidden = false;
    var back = el.querySelector('.nav-empty-back');
    if (back) back.addEventListener('click', function () { applyNav(parent); });
  }
  /* ── Menu rendering: one tree, two presentations ─────────────────
     Both read the SAME tree and emit the SAME chip semantics; only the
     arrangement differs. Nothing below is aware of a level count. */
  function navLayout() {
    var nav = document.getElementById('report-nav');
    return (nav && nav.dataset.navlayout) ? nav.dataset.navlayout : 'strips';
  }

  function renderNavMenu(path) {
    if (navLayout() === 'sidebar') { renderNavSidebar(path); renderNavStrips(path, true); }
    else                          { renderNavSidebar(path, true); renderNavStrips(path); }
    renderNavCrumb(path);
  }

  /* Sidebar rail — the whole tree at once, recovering the ~190px of sticky
     vertical chrome the strips consume. Required at depth 4+ (plan-v2.md D6). */
  function renderNavSidebar(path, hide) {
    var host = document.getElementById('nav-sidebar');
    if (!host) return;
    if (hide) { host.style.display = 'none'; host.innerHTML = ''; return; }
    host.style.display = '';
    host.innerHTML = '';
    document.body.classList.add('has-nav-sidebar');

    var tree = buildNavTree();
    (function walk(node, depth, container) {
      node.order.forEach(function (seg) {
        var child    = node.children[seg];
        var onPath   = path[depth] === seg;
        var selected = onPath && path.length === child.path.length;

        var a = document.createElement('a');
        a.className = 'nav-rail-item nav-rail-d' + depth +
                      (selected ? ' nav-rail-active' : '') +
                      (onPath ? ' nav-rail-onpath' : '');
        a.href = '#';
        a.style.paddingLeft = (10 + depth * 14) + 'px';
        a.textContent = child.label;
        a.setAttribute('role', 'treeitem');
        a.setAttribute('aria-selected', selected ? 'true' : 'false');
        a.setAttribute('aria-level', String(depth + 1));
        if (child.order.length) a.setAttribute('aria-expanded', onPath ? 'true' : 'false');
        if (selected) a.setAttribute('aria-current', 'page');
        a.tabIndex = selected || (!path.length && depth === 0 && !container.querySelector('[tabindex="0"]')) ? 0 : -1;
        a.dataset.navto = JSON.stringify(child.path);       /* v2.4.0: NavBadge and search address items by path */
        if (child.tableId) {
          var b = document.createElement('span');
          b.className = 'nav-badge';
          b.dataset.table = child.tableId;
          a.appendChild(b);
        }
        a.addEventListener('click', function (e) {
          e.preventDefault();
          applyNav(navAutoDescend(buildNavTree(), child.path));
        });
        container.appendChild(a);

        /* Only expand the branch the reader is actually on - a fully expanded
           deep tree is as unreadable as four stacked strips. */
        if (onPath && child.order.length) { walk(child, depth + 1, container); }
      });
    })(tree, 0, host);
  }

  /* ── Strips, rendered from a loop ────────────────────────────────
     N strips, no fixed element ids and no L1/L2/L3 naming anywhere. This is
     what makes a 4th level a config change rather than a rewrite. */
  function renderNavStrips(path, hide) {
    var host = document.getElementById('nav-strips');
    if (!host) return;
    var topHostEl = document.getElementById('nav-strips-top');
    if (hide) {
      host.style.display = 'none'; host.innerHTML = '';
      if (topHostEl) { topHostEl.style.display = 'none'; topHostEl.innerHTML = ''; }
      return;
    }
    host.style.display = '';
    if (topHostEl) topHostEl.style.display = '';
    document.body.classList.remove('has-nav-sidebar');
    var tree = buildNavTree();
    host.innerHTML = '';

    /* Depth 0 renders INSIDE .nav-inner, on the same line as the Top / density /
       theme buttons - that is where the 1.x group tabs lived, and moving them to
       their own row cost a whole line of vertical chrome for no benefit.
       Levels 1+ get their own strips below. */
    var topHost = document.getElementById('nav-strips-top');
    if (topHost) topHost.innerHTML = '';

    var node  = tree;
    var depth = 0;
    while (node && node.order.length) {
      var strip = null, inner;
      if (depth === 0 && topHost) {
        inner = topHost;                       /* chips go straight into nav-inner */
      } else {
        strip = document.createElement('div');
        strip.className = 'nav-strip nav-strip-' + depth;   /* depth, not a level name */
        strip.setAttribute('role', 'tablist');
        strip.setAttribute('aria-label', 'Subsections');
        inner = document.createElement('div');
        inner.className = 'nav-strip-inner';
      }

      (function (currentNode, currentDepth) {
        currentNode.order.forEach(function (seg) {
          var child    = currentNode.children[seg];
          var selected = path[currentDepth] === seg;
          var a = document.createElement('a');
          a.className = 'nav-chip' + (selected ? ' nav-chip-active' : '');
          a.href = '#';
          a.textContent = child.label;
          a.setAttribute('role', 'tab');
          a.setAttribute('aria-selected', selected ? 'true' : 'false');
          a.tabIndex = selected ? 0 : -1;                    /* roving tabindex: one tab stop per strip */
          if (selected && path.length === child.path.length) a.setAttribute('aria-current', 'page');
          a.dataset.navto = JSON.stringify(child.path);
          if (child.tableId) {
            var badge = document.createElement('span');
            badge.className = 'nav-badge';
            badge.dataset.table = child.tableId;
            a.appendChild(badge);
          }
          a.addEventListener('click', function (e) {
            e.preventDefault();
            applyNav(navAutoDescend(buildNavTree(), child.path));
          });
          inner.appendChild(a);
        });
      })(node, depth);

      if (strip) { strip.appendChild(inner); host.appendChild(strip); }
      dhNavDecorate(inner);                                  /* badges first: the fit must measure final widths */
      dhNavFitStrip(inner);                                  /* "More" menu when the chips would wrap to a second row */
      dhNavTabStop(inner);

      if (path[depth] === undefined || !node.children[path[depth]]) break;
      node = node.children[path[depth]];
      depth++;
    }
  }

  /* Breadcrumb — mandatory once a tree is 4+ deep, harmless shallower. */
  function renderNavCrumb(path) {
    var host = document.getElementById('nav-crumb');
    if (!host) return;
    if (path.length < 4) { host.innerHTML = ''; host.style.display = 'none'; return; }
    host.style.display = '';
    host.innerHTML = '';
    var tree = buildNavTree();
    host.setAttribute('role', 'navigation');
    path.forEach(function (seg, i) {
      var node = navNodeAt(tree, path.slice(0, i + 1));
      var a = document.createElement('a');
      a.className = 'nav-crumb-item';
      if (i === path.length - 1) a.setAttribute('aria-current', 'page');
      a.href = '#';
      a.textContent = node ? node.label : seg;
      a.addEventListener('click', function (e) {
        e.preventDefault();
        applyNav(path.slice(0, i + 1));
      });
      host.appendChild(a);
      if (i < path.length - 1) {
        var sep = document.createElement('span');
        sep.className = 'nav-crumb-sep';
        sep.textContent = '›';
        host.appendChild(sep);
      }
    });
  }

  /* ── Overflow and keyboard (v2.5.0) ──────────────────────────────────────
     dhNavFit is pure: widths in, which chips stay visible out. dhNavFitStrip
     measures a rendered strip and, when its chips would wrap to a second row,
     moves the ones that do not fit into a "More" menu at the end of the row (the
     selected chip always stays visible). v2.5.3: one row, was two. -NavOverflow
     Wrap turns it off. */
  function dhNavFit(widths, avail, gap, maxRows, moreW, active) {
    var n = widths.length, all = [], i;
    for (i = 0; i < n; i++) all.push(i);
    function rowsFor(idx, extra) {
      var ws = idx.map(function (k) { return widths[k]; }), rows = 1, x = 0;
      if (extra) ws.push(extra);
      ws.forEach(function (w) {
        if (x > 0 && x + gap + w > avail) { rows++; x = w; } else { x += (x > 0 ? gap : 0) + w; }
      });
      return rows;
    }
    if (rowsFor(all, 0) <= maxRows) return { visible: all, overflow: [] };
    var k = n;
    while (k > 1) {
      var vis = all.slice(0, k);
      if (active >= k) vis[k - 1] = active;
      if (rowsFor(vis, moreW) <= maxRows) break;
      k--;
    }
    var visible = all.slice(0, Math.max(1, k));
    if (active >= 0 && visible.indexOf(active) === -1) visible[visible.length - 1] = active;
    visible.sort(function (a, b) { return a - b; });
    return { visible: visible, overflow: all.filter(function (x) { return visible.indexOf(x) === -1; }) };
  }

  var DH_NAV_MAX_ROWS = 1;
  /* Rows a strip takes. A chip starts a new row only when it sits below the previous row by more than
     half its height: chips on one line can differ by a pixel or two (a badge, a bold active chip). */
  function dhNavRows(inner) {
    var rows = 0, lastTop = -Infinity;
    Array.prototype.forEach.call(inner.children, function (c) {
      if (!c.offsetWidth) return;
      if (c.offsetTop > lastTop + c.offsetHeight / 2) { rows++; lastTop = c.offsetTop; }
    });
    return rows;
  }
  /* Fills the row-count badges and -NavBadge pills of one strip, so dhNavFitStrip measures the chips at
     their final width (they used to be filled after the fit, and a full strip then grew a row). */
  function dhNavDecorate(inner) {
    inner.querySelectorAll('.nav-badge[data-table]').forEach(function (b) { dhNavFillBadge(b); });
    var nav = document.getElementById('report-nav');
    if (!nav || nav.dataset.navbadge !== 'true') return;
    inner.querySelectorAll('[data-navto]').forEach(function (el) { dhNavSevPill(el); });
  }
  /* After a badge changes (a filter), a strip that now wraps is fitted again. */
  function dhNavRefitIfWrapped() {
    var nav = document.getElementById('report-nav');
    if (!nav || nav.dataset.navoverflow === 'wrap' || navLayout() === 'sidebar') return;
    var inners = [document.getElementById('nav-strips-top')].concat(Array.prototype.slice.call(document.querySelectorAll('#nav-strips .nav-strip-inner')));
    var wrapped = inners.some(function (inr) {
      if (!inr || !inr.isConnected || inr.clientWidth < 80) return false;
      return dhNavRows(inr) > DH_NAV_MAX_ROWS && inr.querySelectorAll('.nav-chip').length >= 4;   /* dhNavFitStrip leaves shorter strips alone */
    });
    if (wrapped) renderNavMenu(currentNavPath);
  }

  function dhNavFitStrip(inner) {
    var nav = document.getElementById('report-nav');
    if (!nav || nav.dataset.navoverflow === 'wrap' || !inner.isConnected) return;
    var chips = Array.prototype.slice.call(inner.children).filter(function (c) { return c.classList.contains('nav-chip'); });
    if (chips.length < 4 || inner.clientWidth < 80) return;
    if (dhNavRows(inner) <= DH_NAV_MAX_ROWS) return;                  /* fits in one row: leave it */
    var cs = getComputedStyle(inner);
    var gap = parseFloat(cs.columnGap) || 4;
    /* clientWidth includes the padding (a sub-strip has some); widths are fractional, so round up and keep 1px spare */
    var avail = inner.clientWidth - (parseFloat(cs.paddingLeft) || 0) - (parseFloat(cs.paddingRight) || 0) - 1;
    var active = -1;
    chips.forEach(function (c, i) { if (c.classList.contains('nav-chip-active')) active = i; });
    var wrap = document.createElement('div'), btn = document.createElement('button'), menu = document.createElement('div');
    wrap.className = 'nav-more';
    btn.type = 'button'; btn.className = 'nav-more-btn';
    btn.setAttribute('aria-haspopup', 'menu'); btn.setAttribute('aria-expanded', 'false');
    btn.tabIndex = -1;
    menu.className = 'nav-more-menu'; menu.setAttribute('role', 'menu'); menu.hidden = true;
    /* measure the real button (widest count) instead of guessing its width */
    btn.textContent = 'More (' + chips.length + ') \u25BE';
    wrap.appendChild(btn); inner.appendChild(wrap);
    var moreW = Math.ceil(wrap.getBoundingClientRect().width) || 84;
    inner.removeChild(wrap); wrap.removeChild(btn);
    var fit = dhNavFit(chips.map(function (c) { return Math.ceil(c.getBoundingClientRect().width); }), avail, gap, DH_NAV_MAX_ROWS, moreW, active);
    if (!fit.overflow.length) return;
    btn.textContent = 'More (' + fit.overflow.length + ') \u25BE';
    fit.overflow.forEach(function (i) {
      chips[i].setAttribute('role', 'menuitem');
      chips[i].tabIndex = -1;
      menu.appendChild(chips[i]);
    });
    btn.addEventListener('click', function () { dhNavMoreToggle(btn, menu); });
    wrap.appendChild(btn); wrap.appendChild(menu);
    inner.appendChild(wrap);
    dhNavSettle(inner, chips, wrap, btn, menu);
  }
  /* v2.5.3 - the estimate can be one chip off: the strip is a few pixels narrower while it still wraps,
     and the More label shrinks once the count is known. Settle against the real layout: move chips into
     the menu while the strip takes more than one row, then bring them back, in order, while it still fits. */
  function dhNavSettle(inner, chips, wrap, btn, menu) {
    var idx = function (c) { return chips.indexOf(c); };
    var count = function () { btn.textContent = 'More (' + menu.children.length + ') ▾'; };
    var shown = function () { return Array.prototype.filter.call(inner.children, function (c) { return c.classList.contains('nav-chip'); }); };
    var toMenu = function (c) {
      var after = Array.prototype.filter.call(menu.children, function (m) { return idx(m) > idx(c); })[0];
      c.setAttribute('role', 'menuitem'); c.tabIndex = -1;
      menu.insertBefore(c, after || null); count();
    };
    var toStrip = function (c) {
      var after = shown().filter(function (s) { return idx(s) > idx(c); })[0];
      c.setAttribute('role', 'tab'); c.tabIndex = -1;
      inner.insertBefore(c, after || wrap); count();
    };
    var guard = chips.length;
    while (guard-- > 0 && dhNavRows(inner) > DH_NAV_MAX_ROWS) {
      var out = shown().filter(function (c) { return !c.classList.contains('nav-chip-active'); }).pop();
      if (!out) break;
      toMenu(out);
    }
    guard = chips.length;
    while (guard-- > 0 && menu.children.length) {
      var back = menu.children[0];
      toStrip(back);
      if (dhNavRows(inner) > DH_NAV_MAX_ROWS) { toMenu(back); break; }
    }
    if (!menu.children.length) inner.removeChild(wrap);
  }
  function dhNavMoreToggle(btn, menu, forceOpen) {
    var open = forceOpen === undefined ? menu.hidden : forceOpen;
    menu.hidden = !open;
    btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    if (open) { var first = menu.querySelector('[data-navto]'); if (first) first.focus(); }
  }
  /* The keyboard items of one strip, in order: its visible chips, then the More button. The button sits
     inside its .nav-more wrapper, so a scan of the strip's direct children never found it (2.5.0 to 2.5.2:
     the arrow keys could not reach More, and with one tab stop per strip the menu was mouse-only). */
  function dhNavStripItems(inner) {
    var items = Array.prototype.filter.call(inner.children, function (c) { return c.classList.contains('nav-chip'); });
    var more = inner.querySelector(':scope > .nav-more > .nav-more-btn');
    if (more) items.push(more);
    return items;
  }
  /* one tab stop per strip: the selected chip, else the first */
  function dhNavTabStop(inner) {
    var chips = dhNavStripItems(inner);
    if (!chips.length || chips.some(function (c) { return c.tabIndex === 0; })) return;
    chips[0].tabIndex = 0;
  }

  function dhNavKeydown(e) {
    var t = e.target, key = e.key, el, items, i;
    if (!t || !t.closest) return;
    if (key === 'Escape') {
      var menuOpen = document.querySelector('.nav-more-menu:not([hidden])');
      if (menuOpen) { var b = menuOpen.parentNode.querySelector('.nav-more-btn'); dhNavMoreToggle(b, menuOpen, false); b.focus(); e.preventDefault(); }
      return;
    }
    /* inside the More menu */
    el = t.closest('.nav-more-menu [data-navto]');
    if (el) {
      items = Array.prototype.slice.call(el.parentNode.querySelectorAll('[data-navto]')); i = items.indexOf(el);
      if (key === 'ArrowDown') { items[(i + 1) % items.length].focus(); e.preventDefault(); }
      else if (key === 'ArrowUp') { items[(i - 1 + items.length) % items.length].focus(); e.preventDefault(); }
      else if (key === 'Home') { items[0].focus(); e.preventDefault(); }
      else if (key === 'End') { items[items.length - 1].focus(); e.preventDefault(); }
      else if (key === ' ') { el.click(); e.preventDefault(); }
      return;
    }
    /* a strip chip or the More button */
    el = t.closest('.nav-chip, .nav-more-btn');
    var stripEl = el && el.closest('#nav-strips-top, .nav-strip-inner');
    if (el && stripEl) {
      items = dhNavStripItems(stripEl);
      i = items.indexOf(el);
      var to = null;
      if (key === 'ArrowRight') to = items[(i + 1) % items.length];
      else if (key === 'ArrowLeft') to = items[(i - 1 + items.length) % items.length];
      else if (key === 'Home') to = items[0];
      else if (key === 'End') to = items[items.length - 1];
      if (to) { items.forEach(function (c) { c.tabIndex = -1; }); to.tabIndex = 0; to.focus(); e.preventDefault(); return; }
      if (el.classList.contains('nav-more-btn') && (key === 'ArrowDown' || key === 'Enter' || key === ' ')) {
        dhNavMoreToggle(el, el.parentNode.querySelector('.nav-more-menu'), true); e.preventDefault(); return;
      }
      if (key === ' ' && el.classList.contains('nav-chip')) { el.click(); e.preventDefault(); }
      return;
    }
    /* the sidebar rail */
    el = t.closest('.nav-rail-item');
    if (el) {
      items = Array.prototype.slice.call(document.querySelectorAll('#nav-sidebar .nav-rail-item')); i = items.indexOf(el);
      var go = null, pth = [];
      try { pth = JSON.parse(el.dataset.navto || '[]'); } catch (x) {}
      if (key === 'ArrowDown') go = items[Math.min(i + 1, items.length - 1)];
      else if (key === 'ArrowUp') go = items[Math.max(i - 1, 0)];
      else if (key === 'Home') go = items[0];
      else if (key === 'End') go = items[items.length - 1];
      else if (key === 'ArrowRight' && el.getAttribute('aria-expanded') === 'false') { el.click(); e.preventDefault(); return; }
      else if (key === 'ArrowRight' && el.getAttribute('aria-expanded') === 'true') go = items[i + 1];
      else if (key === 'ArrowLeft' && pth.length > 1) {
        var want = JSON.stringify(pth.slice(0, -1));
        go = items.filter(function (x) { return x.dataset.navto === want; })[0];
      }
      else if (key === ' ') { el.click(); e.preventDefault(); return; }
      if (go) { items.forEach(function (x) { x.tabIndex = -1; }); go.tabIndex = 0; go.focus(); e.preventDefault(); }
    }
  }
  /* ── Init ────────────────────────────────────────────────────────── */
  function initNav() {
    var tree = buildNavTree();

    /* Restore from the URL, validating segment by segment and truncating at the
       first miss, so a renamed node degrades to its parent instead of a blank
       page. Old 1.x {group,panel} hashes are shimmed to a path. */
    var saved   = (typeof URLState !== 'undefined' && URLState.load) ? URLState.load() : {};
    var wanted  = [];
    if (saved && saved.nav && saved.nav.length) {
      wanted = saved.nav;
    } else if (saved && saved.group) {
      wanted = [saved.group];                                  /* 1.x hash shim */
      if (saved.panel) wanted.push(saved.panel);
    }

    var valid = [];
    var node  = tree;
    for (var i = 0; i < wanted.length; i++) {
      if (!node.children[wanted[i]]) break;
      node = node.children[wanted[i]];
      valid.push(wanted[i]);
    }

    applyNav(navAutoDescend(tree, valid));
    initTableCollapsibles();

    /* keyboard: arrows, Home, End, Space in the menu; the More menu closes on an outside click */
    document.addEventListener('keydown', dhNavKeydown);
    document.addEventListener('click', function (e) {
      if (e.target.closest && e.target.closest('.nav-more')) return;
      document.querySelectorAll('.nav-more-menu:not([hidden])').forEach(function (m) { dhNavMoreToggle(m.parentNode.querySelector('.nav-more-btn'), m, false); });
    });
    /* re-fit the strips when the width changes (debounced; only the width matters) */
    var navLastW = window.innerWidth, navFitTimer = null;
    function navRefitSoon() {
      clearTimeout(navFitTimer);
      navFitTimer = setTimeout(function () { renderNavMenu(currentNavPath); updateNavBadges(); }, 150);
    }
    window.addEventListener('resize', function () {
      if (window.innerWidth === navLastW) return;
      navLastW = window.innerWidth;
      navRefitSoon();
    });
    /* v2.5.3 - the top strip shares its line with the title, search and buttons: it also changes width
       when those do (the theme and density labels are set after this runs, a web font loads late).
       Its width never depends on its own chips (flex basis 0), so re-fitting cannot feed back. */
    var topFitEl = document.getElementById('nav-strips-top');
    if (topFitEl && typeof ResizeObserver === 'function') {
      var navLastTopW = topFitEl.clientWidth;
      new ResizeObserver(function () {
        var w = topFitEl.clientWidth;
        if (!w || w === navLastTopW) return;
        navLastTopW = w;
        navRefitSoon();
      }).observe(topFitEl);
    }

    /* Compat surface for anything that called into the 1.x internals. */
    window._applyNav     = applyNav;
    window._navPath      = function () { return currentNavPath.slice(); };
    window._showPanel    = function (id) {
      var sec = document.getElementById('section-' + id) || document.getElementById('bsection-' + id);
      if (sec) applyNav(navPathOf(sec));
    };
    window._showGroup    = function (g) { applyNav(navAutoDescend(buildNavTree(), [g])); };
    window._showSubGroup = function (g, sg) { applyNav(navAutoDescend(buildNavTree(), sg ? [g, sg] : [g])); };
  }

  /* Update nav row-count badge — shows filtered/total e.g. "12/47" when filtered */
  function dhNavFillBadge(badge) {
    var id = badge.dataset.table;
    if (!id || typeof engines === 'undefined' || !engines[id]) return;
    var filtered = engines[id]._getFiltered().length;
    var total    = engines[id].allData.length;
    badge.textContent = (filtered < total) ? filtered+'/'+total : total;
  }
  function updateNavBadge(id) {
    document.querySelectorAll('.nav-badge[data-table]').forEach(function (b) { if (b.dataset.table === id) dhNavFillBadge(b); });
  }

  /* v2.4.0 - New-DhDashboard -NavBadge: a pill per menu item with the worst finding
     severity at or below it. The index is built once (findings are static) from the
     findings blocks that have a menu path: counts roll up to every ancestor. */
  var navSevIndex = null;
  function buildNavSevIndex() {
    var idx = {};
    (typeof BLOCKS_CONFIG !== 'undefined' ? BLOCKS_CONFIG : []).forEach(function (b) {
      if (b.blockType !== 'findings') return;
      var el = document.getElementById('block-' + b.id);
      var sec = el && el.closest('[data-navpath]');
      if (!sec) return;
      var p = navPathOf(sec);
      if (!p.length) return;
      var c = { critical: 0, warning: 0, info: 0 };
      (b.findings || []).forEach(function (f) { if (c[f.severity] !== undefined) c[f.severity]++; });
      if (!c.critical && !c.warning && !c.info) return;
      for (var i = 1; i <= p.length; i++) {
        var key = JSON.stringify(p.slice(0, i));
        var e = idx[key] || (idx[key] = { critical: 0, warning: 0, info: 0 });
        e.critical += c.critical; e.warning += c.warning; e.info += c.info;
      }
    });
    return idx;
  }
  function updateNavSeverity() {
    var nav = document.getElementById('report-nav');
    if (!nav || nav.dataset.navbadge !== 'true') return;
    document.querySelectorAll('[data-navto]').forEach(dhNavSevPill);
  }
  function dhNavSevPill(el) {
    if (!navSevIndex) navSevIndex = buildNavSevIndex();
    var old = el.querySelector('.nav-sev');
    if (old) old.remove();
    var e = navSevIndex[el.dataset.navto];
    if (!e) return;
    var worst = e.critical ? 'critical' : (e.warning ? 'warning' : 'info');
    var parts = [];
    if (e.critical) parts.push(e.critical + ' critical');
    if (e.warning)  parts.push(e.warning + (e.warning === 1 ? ' warning' : ' warnings'));
    if (e.info)     parts.push(e.info + ' info');
    var pill = document.createElement('span');
    pill.className = 'nav-sev nav-sev-' + worst;
    pill.title = parts.join(', ');
    pill.textContent = String(e[worst]);
    var sr = document.createElement('span');
    sr.className = 'nav-sev-sr';
    sr.textContent = ' (' + parts.join(', ') + ')';
    pill.appendChild(sr);
    el.appendChild(pill);
  }

  function updateNavBadges() {
    Object.keys(engines).forEach(function (id) { updateNavBadge(id); });
    updateNavSeverity();
    dhNavRefitIfWrapped();                                   /* a wider badge can push a full strip onto a second row */
  }

'@
}








