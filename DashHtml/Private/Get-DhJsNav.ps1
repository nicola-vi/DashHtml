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

  /* ── Collapsible table chrome (unchanged from 1.x) ──────────────── */
  function initTableCollapsibles() {
    document.querySelectorAll('.table-section-collapsible .table-collapse-toggle').forEach(function (btn) {
      if (btn._dhWired) return;
      btn._dhWired = true;
      btn.addEventListener('click', function () {
        var sec = btn.closest('.table-section');
        if (!sec) return;
        var open = sec.classList.toggle('table-collapsed');
        btn.setAttribute('aria-expanded', open ? 'false' : 'true');
      });
    });
  }

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
  function buildNavTree() {
    var root = { seg: '', path: [], label: '', children: {}, order: [], hasContent: false };
    navSections().forEach(function (sec) {
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
        var ord = parseInt(sec.dataset.navorder || '0', 10);
        if (ord !== 0 && node.navOrder === 0) node.navOrder = ord;
      }
      if (scope === 'exact') node.hasContent = true;
      if (sec.dataset.navlabel) node.label = sec.dataset.navlabel;
      /* A table section sitting exactly here lets its chip carry a row-count
         badge, replacing the 1.x .nav-badge that lived in the flat nav link. */
      if (scope === 'exact' && sec.id && sec.id.indexOf('section-') === 0) {
        node.tableId = sec.id.slice('section-'.length);
      }
    });
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
      var next = node.order[0];
      out.push(next);
      node = node.children[next];
    }
    return out;
  }

  /* ── THE ONE RULE ────────────────────────────────────────────────── */
  function applyNav(path) {
    currentNavPath = (path || []).slice();
    navSections().forEach(function (sec) {
      sec.classList.toggle('panel-active', navMatches(sec, currentNavPath));
    });
    renderNavMenu(currentNavPath);
    if (typeof URLState !== 'undefined' && URLState.save) URLState.save();
    if (typeof updateNavBadges === 'function') updateNavBadges();
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
    path.forEach(function (seg, i) {
      var node = navNodeAt(tree, path.slice(0, i + 1));
      var a = document.createElement('a');
      a.className = 'nav-crumb-item';
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
  function updateNavBadge(id) {
    var badge = document.querySelector('.nav-badge[data-table="'+id+'"]');
    if (!badge || !engines[id]) return;
    var filtered = engines[id]._getFiltered().length;
    var total    = engines[id].allData.length;
    badge.textContent = (filtered < total) ? filtered+'/'+total : total;
  }

  function updateNavBadges() {
    Object.keys(engines).forEach(function (id) { updateNavBadge(id); });
  }

'@
}








