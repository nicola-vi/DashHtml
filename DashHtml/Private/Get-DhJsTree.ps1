function Get-DhJsTree {
    # Fragment of the dashboard runtime JS (see Get-DhJsContent). v2.4.0.
    return @'
  /* =========================================================================
     TREE FILTER (v2.4.0) - Add-DhTreeFilter
     A tree of nodes (OUs, folders, sites) that filters one table by path.
     The filter itself lives in TableEngine (setPathFilter / pathFilter), so the
     table's own clear button, the URL state and the filter badge all work; this
     file only draws the tree and tells the engine what was chosen. Rows are
     drawn flat (aria-level) so an expanded 5,000-node tree is one pass.
     ========================================================================= */

  /* Lower-case, trim, and drop blanks around the separator ("OU=a, OU=b"). */
  function dhPathNorm(s, sep) {
    s = String(s).toLowerCase().trim();
    if (sep && s.indexOf(' ') !== -1) s = s.split(sep).map(function (x) { return x.trim(); }).join(sep);
    return s;
  }

  /* Does a row's path value sit at or below node path p? Prefix: root-first paths
     ('a/b/c'); Suffix: distinguished names ('ou=c,ou=b,dc=a'). The separator is
     part of the test, so 'HQ' never matches 'HQ2'. */
  function dhPathMatch(value, p, sep, mode) {
    if (value === null || value === undefined) return false;
    sep = sep || '/';
    var v = dhPathNorm(value, sep), q = dhPathNorm(p, sep);
    if (v === q) return true;
    if (String(mode || 'prefix').toLowerCase() === 'suffix') {
      return v.length > q.length && v.slice(v.length - q.length - sep.length) === sep + q;
    }
    return v.indexOf(q + sep) === 0;
  }

  var TreeFilter = {
    trees: {},
    /* The engine changed its path filter (or cleared it): redraw every tree on that table. */
    sync: function (tableId) {
      var self = this;
      Object.keys(this.trees).forEach(function (k) {
        if (self.trees[k].block.tableId === tableId) self.trees[k].syncSelection();
      });
    }
  };

  /* Rows at or below each node, from the table: every row is credited to the
     DEEPEST node its path reaches, then counts roll up to the parents. */
  function dhTreeCounts(block, nodes, byId, order) {
    var eng = engines[block.tableId], sep = block.sep || '/';
    var suffix = String(block.match || '').toLowerCase() === 'suffix';
    var total = {}, pathMap = {};
    nodes.forEach(function (n) { total[n.id] = 0; pathMap[dhPathNorm(n.path, sep)] = n.id; });
    if (!eng) return total;
    eng.allData.forEach(function (row) {
      var raw = row[block.pathField];
      if (raw === null || raw === undefined || raw === '') return;
      var parts = dhPathNorm(raw, sep).split(sep), acc = '', hit = null, i;
      if (suffix) {
        for (i = parts.length - 1; i >= 0; i--) {
          acc = acc ? parts[i] + sep + acc : parts[i];
          if (pathMap[acc] !== undefined) hit = pathMap[acc];
        }
      } else {
        for (i = 0; i < parts.length; i++) {
          acc = i ? acc + sep + parts[i] : parts[i];
          if (pathMap[acc] !== undefined) hit = pathMap[acc];
        }
      }
      if (hit !== null) total[hit]++;
    });
    for (var k = order.length - 1; k >= 0; k--) {
      var n = order[k];
      if (n.parent && byId[n.parent]) total[n.parent] += total[n.id];
    }
    return total;
  }

  function renderTreeFilter(container, block) {
    container.className = 'treefilter-section';
    var nodes = block.nodes || [], byId = {}, kids = {}, roots = [], depth = {}, order = [];
    nodes.forEach(function (n) { byId[n.id] = n; kids[n.id] = []; });
    nodes.forEach(function (n) {
      if (n.parent && byId[n.parent]) kids[n.parent].push(n); else roots.push(n);
    });
    (function walk(list, d) {
      list.forEach(function (n) { depth[n.id] = d; order.push(n); walk(kids[n.id], d + 1); });
    })(roots, 0);

    var counts = {};
    if (block.countFromTable) counts = dhTreeCounts(block, nodes, byId, order);
    else nodes.forEach(function (n) { if (n.count !== undefined && n.count !== null) counts[n.id] = n.count; });

    var expanded = {}, selectedId = null, focusId = null, findText = '';
    order.forEach(function (n) { if (kids[n.id].length && depth[n.id] < (block.openDepth || 0)) expanded[n.id] = true; });

    var uid = 'tf-' + block.id;
    container.innerHTML =
      (block.title ? '<h3 class="treefilter-title">' + esc(block.title) + '</h3>' : '') +
      '<div class="treefilter-toolbar">' +
        '<input type="search" class="treefilter-find" id="' + uid + '-find" placeholder="Find…" aria-label="Find in ' + esc(block.title || 'tree') + '" autocomplete="off">' +
        '<button type="button" class="treefilter-btn" data-tf="expand">Expand all</button>' +
        '<button type="button" class="treefilter-btn" data-tf="collapse">Collapse all</button>' +
        '<button type="button" class="treefilter-btn" data-tf="clear" hidden>Clear filter</button>' +
      '</div>' +
      '<div class="treefilter-scroll" style="max-height:' + (parseInt(block.height, 10) || 420) + 'px">' +
        '<div class="dh-tree" role="tree" aria-label="' + esc(block.title || 'Tree') + '"></div></div>' +
      '<div class="treefilter-empty" hidden>No match.</div>';

    var tree  = container.querySelector('.dh-tree');
    var find  = container.querySelector('.treefilter-find');
    var clear = container.querySelector('[data-tf="clear"]');
    var empty = container.querySelector('.treefilter-empty');

    function visibleRows() {
      var q = findText.toLowerCase(), match = null, force = {};
      if (q) {
        match = {};
        nodes.forEach(function (n) {
          if ((n.label + ' ' + n.path).toLowerCase().indexOf(q) === -1) return;
          match[n.id] = true;
          var p = n.parent;
          while (p && byId[p]) { force[p] = true; p = byId[p].parent; }
        });
      }
      var out = [];
      (function walk(list) {
        list.forEach(function (n) {
          if (q && !match[n.id] && !force[n.id]) return;
          out.push(n);
          var open = q ? !!force[n.id] : !!expanded[n.id];
          if (kids[n.id].length && open) walk(kids[n.id]);
        });
      })(roots);
      return out;
    }

    function rowHtml(n, rows, tabId) {
      var has = kids[n.id].length > 0;
      var open = findText ? true : !!expanded[n.id];
      var st = secStatus(n.status);
      var cnt = counts[n.id];
      return '<div class="dh-tree-row' + (selectedId === n.id ? ' dh-tree-sel' : '') + '" role="treeitem"' +
        ' aria-level="' + (depth[n.id] + 1) + '" aria-selected="' + (selectedId === n.id ? 'true' : 'false') + '"' +
        (has ? ' aria-expanded="' + (open ? 'true' : 'false') + '"' : '') +
        ' data-id="' + esc(n.id) + '" tabindex="' + (n.id === tabId ? '0' : '-1') + '"' +
        ' style="padding-left:' + (6 + depth[n.id] * 16) + 'px">' +
        '<span class="dh-tree-chev"' + (has ? ' data-act="toggle"' : '') + '>' + (has ? (open ? '&#9662;' : '&#9656;') : '') + '</span>' +
        (st ? '<span class="dh-tree-dot dh-st-' + st + '" title="' + esc(SEC_LABEL[st] || '') + '"></span>' : '<span class="dh-tree-dot dh-tree-dot-none"></span>') +
        '<span class="dh-tree-label" title="' + esc(n.path) + '">' + esc(n.label) + '</span>' +
        (n.flags || []).map(function (f) { return '<span class="dh-tree-flag">' + esc(f) + '</span>'; }).join('') +
        (cnt !== undefined ? '<span class="dh-tree-count">' + esc(Number(cnt).toLocaleString()) + '</span>' : '') +
        (n.detail ? '<button type="button" class="dh-tree-info" data-act="info" aria-label="Details for ' + esc(n.label) + '">i</button>' : '') +
        '</div>';
    }

    function render(refocus) {
      var rows = visibleRows();
      var tabId = (focusId && rows.some(function (r) { return r.id === focusId; })) ? focusId : (rows[0] && rows[0].id);
      tree.innerHTML = rows.map(function (n) { return rowHtml(n, rows, tabId); }).join('');
      empty.hidden = rows.length > 0;
      clear.hidden = !selectedId;
      if (refocus) rowEl(refocus) && rowEl(refocus).focus();
    }
    function rowEl(id) {
      var els = tree.querySelectorAll('.dh-tree-row');
      for (var i = 0; i < els.length; i++) if (els[i].getAttribute('data-id') === id) return els[i];
      return null;
    }

    function select(n) {
      var eng = engines[block.tableId];
      if (!eng) return;
      if (selectedId === n.id) { eng.setPathFilter(null); return; }
      eng.setPathFilter({ field: block.pathField, value: n.path, sep: block.sep, mode: block.match,
                          treeId: block.id, nodeId: n.id, label: n.label, title: block.title });
    }
    function openDetail(n, opener) {
      var d = n.detail; if (!d) return;
      dhDrawerOpen({ title: d.title || n.label, subtitle: d.subtitle || n.path, sections: d.sections }, { opener: opener });
    }

    function syncSelection() {
      var eng = engines[block.tableId], pf = eng && eng.pathFilter;
      selectedId = (pf && pf.treeId === block.id && byId[pf.nodeId]) ? pf.nodeId : null;
      if (selectedId) {                                   /* make the chosen node visible */
        var p = byId[selectedId].parent;
        while (p && byId[p]) { expanded[p] = true; p = byId[p].parent; }
      }
      render();
    }

    tree.addEventListener('click', function (e) {
      var rowNode = e.target.closest('.dh-tree-row'); if (!rowNode) return;
      var n = byId[rowNode.getAttribute('data-id')]; if (!n) return;
      var act = e.target.closest('[data-act]');
      focusId = n.id;
      if (act && act.getAttribute('data-act') === 'toggle') { expanded[n.id] = !expanded[n.id]; render(n.id); return; }
      if (act && act.getAttribute('data-act') === 'info') { openDetail(n, act); return; }
      select(n);
    });
    tree.addEventListener('keydown', function (e) {
      var rowNode = e.target.closest && e.target.closest('.dh-tree-row'); if (!rowNode || e.target !== rowNode) return;
      var n = byId[rowNode.getAttribute('data-id')], rows = visibleRows(), i = rows.indexOf(n), key = e.key, to = null;
      if (key === 'ArrowDown') to = rows[Math.min(i + 1, rows.length - 1)];
      else if (key === 'ArrowUp') to = rows[Math.max(i - 1, 0)];
      else if (key === 'Home') to = rows[0];
      else if (key === 'End') to = rows[rows.length - 1];
      else if (key === 'ArrowRight') {
        if (kids[n.id].length && !expanded[n.id] && !findText) { expanded[n.id] = true; focusId = n.id; e.preventDefault(); render(n.id); return; }
        if (kids[n.id].length) to = kids[n.id][0];
      } else if (key === 'ArrowLeft') {
        if (kids[n.id].length && expanded[n.id] && !findText) { expanded[n.id] = false; focusId = n.id; e.preventDefault(); render(n.id); return; }
        to = n.parent ? byId[n.parent] : null;
      } else if (key === 'Enter' || key === ' ') { e.preventDefault(); select(n); return; }
      else return;
      e.preventDefault();
      if (to) { focusId = to.id; render(to.id); }
    });
    find.addEventListener('input', function () { findText = find.value; render(); });
    container.querySelector('.treefilter-toolbar').addEventListener('click', function (e) {
      var b = e.target.closest('[data-tf]'); if (!b) return;
      var a = b.getAttribute('data-tf');
      if (a === 'expand')   { order.forEach(function (n) { if (kids[n.id].length) expanded[n.id] = true; }); render(); }
      if (a === 'collapse') { expanded = {}; render(); }
      if (a === 'clear')    { var eng = engines[block.tableId]; if (eng) eng.setPathFilter(null); }
    });

    var inst = { block: block, syncSelection: syncSelection };
    TreeFilter.trees[block.id] = inst;

    /* Restore a selection saved in the URL hash: { tableId: [treeId, nodeId] }. */
    var saved = (URLState.load().pathFilters || {})[block.tableId];
    if (saved && saved[0] === block.id && byId[saved[1]]) select(byId[saved[1]]);
    else render();
    if (!tree.firstChild && roots.length) render();   /* select() returns early when the table is missing */
  }
'@
}
