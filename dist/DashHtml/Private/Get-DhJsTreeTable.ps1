function Get-DhJsTreeTable {
    # Fragment of the dashboard runtime JS (see Get-DhJsContent). v2.5.0.
    return @'
  /* =========================================================================
     TREE TABLE (v2.5.0) - Add-DhTreeTable
     A directory explorer: tree on the left, the selected object on the right
     with Properties / Members / Member of / Nesting tabs. The membership
     functions below are pure (data in, data out) so they can be tested in node.
     Rows are drawn flat, only when their parent is open.
     ========================================================================= */

  /* links = [[groupId, memberId], ...] -> { membersOf:{group:[member...]}, memberOf:{member:[group...]} } */
  function dhTtLinks(links) {
    var membersOf = {}, memberOf = {};
    (links || []).forEach(function (l) {
      (membersOf[l[0]] = membersOf[l[0]] || []).push(l[1]);
      (memberOf[l[1]] = memberOf[l[1]] || []).push(l[0]);
    });
    return { membersOf: membersOf, memberOf: memberOf };
  }

  /* Every path from `id` up to a group that is in no other group: [[id, g1, g2, ...], ...].
     A group that appears twice on one path is a circular nesting: that branch stops and
     `circular` is set. At most `cap` paths are returned (`more` counts the rest). */
  function dhTtPaths(memberOf, id, cap) {
    var paths = [], circular = false, more = 0;
    (function walk(path) {
      var ups = memberOf[path[path.length - 1]] || [], loops = false;
      ups.forEach(function (g) {
        if (path.indexOf(g) !== -1) { circular = true; loops = true; return; }
        path.push(g); walk(path); path.pop();
      });
      /* a path ends at a group that is in no other group, or where a loop was cut */
      if ((!ups.length || loops) && path.length > 1) { if (paths.length < cap) paths.push(path.slice()); else more++; }
    })([id]);
    return { paths: paths, circular: circular, more: more };
  }

  /* Groups nested below group `gid`, depth first: [{ id, depth, circular }] (cycle-safe, depth-capped). */
  function dhTtNested(membersOf, typeOf, gid, maxDepth) {
    var out = [];
    (function walk(id, depth, trail) {
      (membersOf[id] || []).forEach(function (m) {
        if (typeOf[m] !== 'group') return;
        var circ = trail.indexOf(m) !== -1;
        out.push({ id: m, depth: depth, circular: circ });
        if (!circ && depth < maxDepth) walk(m, depth + 1, trail.concat([m]));
      });
    })(gid, 1, [gid]);
    return out;
  }

  /* v2.6.0 - which rows a find text and type chips keep: match = the rows that pass, force = their
     ancestors (shown, and open, so the match is visible). null when nothing filters. */
  function dhTtMatch(rows, byId, q, typeSel) {
    q = (q || '').toLowerCase();
    var anyType = Object.keys(typeSel || {}).length;
    if (!q && !anyType) return null;
    var match = {}, force = {};
    rows.forEach(function (r) {
      if (anyType && !typeSel[r.type]) return;
      if (q && (r.label + ' ' + r.type).toLowerCase().indexOf(q) === -1) return;
      match[r.id] = true;
      var p = r.parent;
      while (p && byId[p] && !force[p]) { force[p] = true; p = byId[p].parent; }   /* a forced parent's ancestors are forced already */
    });
    return { match: match, force: force };
  }

  /* v2.6.0 - the rows the tree shows, in order: [{ r, pos, size }] (pos / size among the visible siblings,
     for aria-posinset / aria-setsize). One flat list feeds drawing, keyboard, windowing and print. */
  function dhTtFlatten(roots, kids, expanded, m) {
    var out = [];
    (function walk(list) {
      var vis = m ? list.filter(function (r) { return m.match[r.id] || m.force[r.id]; }) : list;
      for (var i = 0; i < vis.length; i++) {
        var r = vis[i];
        out.push({ r: r, pos: i + 1, size: vis.length });
        var open = m ? !!m.force[r.id] : !!expanded[r.id];
        if (kids[r.id].length && open) walk(kids[r.id]);
      }
    })(roots);
    return out;
  }

  /* v2.6.0 - the slice of a fixed-height list to draw: rows in view plus `overscan` on each side, and the
     spacer heights above and below it. */
  function dhTtWindow(scrollTop, viewH, rowH, total, overscan) {
    var start = Math.max(0, Math.floor(scrollTop / rowH) - overscan);
    var end = Math.min(total, Math.ceil((scrollTop + viewH) / rowH) + overscan);
    if (start > end) start = end;
    return { start: start, end: end, top: start * rowH, bottom: (total - end) * rowH };
  }

  /* v2.6.0 - CSV text with the table export's rules: BOM, quoted cells, CRLF, formula guard (dhCsvSafe). */
  function dhCsvText(header, rows) {
    function cell(v) { return '"' + dhCsvSafe(v).replace(/"/g, '""') + '"'; }
    var lines = [header.map(cell).join(',')];
    rows.forEach(function (r) { lines.push(r.map(cell).join(',')); });
    return '﻿' + lines.join('\r\n');
  }
  function dhCsvDownload(text, name) {
    var url = URL.createObjectURL(new Blob([text], { type: 'text/csv;charset=utf-8;' }));
    var a = document.createElement('a'); a.href = url; a.download = name;
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    setTimeout(function () { URL.revokeObjectURL(url); }, 2000);
  }

  /* Tree tables register what they need to do around printing (the windowed ones draw their open rows). */
  var dhTtPrintHooks = [];
  var DH_TT_WIN_MIN = 2000, DH_TT_PRINT_MAX = 2000;

  var DH_TT_GLYPH = { ou: 'OU', group: 'G', user: 'U', computer: 'PC', container: 'C', other: '•' };
  var DH_TT_TYPE  = { ou: 'OU', group: 'Group', user: 'User', computer: 'Computer', container: 'Container', other: 'Other' };

  function renderTreeTable(container, block) {
    container.className = 'treetable-section';
    var rows = block.rows || [], byId = {}, kids = {}, roots = [], depth = {}, order = [], typeOf = {};
    rows.forEach(function (r) { byId[r.id] = r; kids[r.id] = []; typeOf[r.id] = r.type; });
    rows.forEach(function (r) { if (r.parent && byId[r.parent]) kids[r.parent].push(r); else roots.push(r); });
    (function walk(list, d) { list.forEach(function (r) { depth[r.id] = d; order.push(r); walk(kids[r.id], d + 1); }); })(roots, 0);
    var lk = dhTtLinks(block.links), membersOf = lk.membersOf, memberOf = lk.memberOf;
    var maxPaths = block.maxPaths || 50;

    var typesPresent = [];
    rows.forEach(function (r) { if (typesPresent.indexOf(r.type) === -1) typesPresent.push(r.type); });
    var expanded = {}, selectedId = null, focusId = null, findText = '', typeSel = {}, tab = 'props';
    order.forEach(function (r) { if (kids[r.id].length && depth[r.id] < (block.openDepth || 0)) expanded[r.id] = true; });

    container.innerHTML =
      (block.title ? '<h3 class="treetable-title">' + esc(block.title) + '</h3>' : '') +
      '<div class="tt" style="height:' + (parseInt(block.height, 10) || 520) + 'px">' +
        '<div class="tt-left">' +
          '<div class="tt-toolbar">' +
            '<input type="search" class="treefilter-find tt-find" placeholder="Find…" aria-label="Find in ' + esc(block.title || 'directory') + '" autocomplete="off">' +
            '<button type="button" class="treefilter-btn" data-tt="expand">Expand all</button>' +
            '<button type="button" class="treefilter-btn" data-tt="collapse">Collapse all</button>' +
            '<button type="button" class="treefilter-btn" data-tt="csv" title="Save the rows shown in the tree as CSV">CSV</button>' +
            '<span class="tt-chips" role="group" aria-label="Show types">' + typesPresent.map(function (t) {
              return '<button type="button" class="nm-chip tt-chip" data-tt-type="' + esc(t) + '" aria-pressed="false">' + esc(DH_TT_TYPE[t] || t) + '</button>';
            }).join('') + '</span>' +
          '</div>' +
          '<div class="tt-tree dh-tree" role="tree" aria-label="' + esc(block.title || 'Directory') + '"></div>' +
          '<div class="treefilter-empty" hidden>No match.</div>' +
        '</div>' +
        '<div class="tt-right">' +
          '<div class="tt-head"></div>' +
          '<div class="tt-tabs" role="tablist" aria-label="Object details"></div>' +
          '<div class="tt-body" role="tabpanel"></div>' +
        '</div>' +
      '</div>';

    var tree = container.querySelector('.tt-tree'), find = container.querySelector('.tt-find');
    var empty = container.querySelector('.treefilter-empty'), head = container.querySelector('.tt-head');
    var tabsEl = container.querySelector('.tt-tabs'), body = container.querySelector('.tt-body');

    function childCount(r) {
      if (r.type === 'group') return (membersOf[r.id] || []).length;
      return kids[r.id].length;
    }
    /* v2.6.0 - one flat list of the visible rows (dhTtFlatten), rebuilt on expand, collapse and filter, never on
       scroll. Above DH_TT_WIN_MIN rows the tree is windowed: fixed row height, only the rows in view (plus 20 on
       each side) are in the DOM, spacers keep the scrollbar honest. */
    var WIN = rows.length > DH_TT_WIN_MIN, rowH = 28, flat = [], flatIdx = {};
    if (WIN) {
      tree.classList.add('tt-win');
      tree.setAttribute('tabindex', '-1');
      var cssH = parseInt(getComputedStyle(container).getPropertyValue('--tt-row-h'), 10);
      if (cssH > 0) rowH = cssH;
    }
    function rebuild() {
      flat = dhTtFlatten(roots, kids, expanded, dhTtMatch(rows, byId, findText, typeSel));
      flatIdx = {};
      for (var i = 0; i < flat.length; i++) flatIdx[flat[i].r.id] = i;
    }
    function tabTarget() { return (focusId && flatIdx[focusId] !== undefined) ? focusId : (flat[0] && flat[0].r.id); }
    function paint(keepFocus) {
      var tabId = tabTarget(), html;
      if (!WIN) html = flat.map(function (x) { return rowHtml(x, tabId); }).join('');
      else {
        /* the list may have shrunk (a filter) below the current scroll position: clamp before measuring */
        var vh = tree.clientHeight || 400, maxTop = Math.max(0, flat.length * rowH - vh);
        if (tree.scrollTop > maxTop) tree.scrollTop = maxTop;
        var w = dhTtWindow(Math.min(tree.scrollTop, maxTop), vh, rowH, flat.length, 20);
        html = '<div class="tt-spacer" role="presentation" style="height:' + w.top + 'px"></div>' +
               flat.slice(w.start, w.end).map(function (x) { return rowHtml(x, tabId); }).join('') +
               '<div class="tt-spacer" role="presentation" style="height:' + w.bottom + 'px"></div>';
      }
      var had = keepFocus && document.activeElement && tree.contains(document.activeElement) ? (document.activeElement.getAttribute('data-id') || '') : null;
      tree.innerHTML = html;
      if (had !== null) {                                 /* windowed scroll: keep the keyboard in the tree */
        var fe = had ? rowEl(had) : null;
        (fe || tree).focus({ preventScroll: true });
      }
    }
    function scrollToIdx(i) {
      if (!WIN || i === undefined) return;
      var top = i * rowH, vh = tree.clientHeight || 400;
      if (top < tree.scrollTop) tree.scrollTop = top;
      else if (top + rowH > tree.scrollTop + vh) tree.scrollTop = top + rowH - vh;
    }
    if (WIN) {
      /* one repaint per frame; the timer covers a frame that never comes (a hidden or throttled page) */
      var pending = false;
      tree.addEventListener('scroll', function () {
        if (pending) return;
        pending = true;
        var go = function () { if (!pending) return; pending = false; paint(true); };
        if (window.requestAnimationFrame) requestAnimationFrame(go);
        setTimeout(go, 100);
      });
      dhTtPrintHooks.push({
        before: function () {                             /* paper has no scrollbar: the open rows, up to DH_TT_PRINT_MAX */
          var n = Math.min(flat.length, DH_TT_PRINT_MAX), tabId = tabTarget();
          tree.innerHTML = flat.slice(0, n).map(function (x) { return rowHtml(x, tabId); }).join('') +
            (flat.length > n ? '<p class="dh-more tt-print-note">Printed the first ' + n + ' of ' + flat.length + ' open rows.</p>' : '');
        },
        after: function () { paint(false); }
      });
    }

    function rowHtml(x, tabId) {
      var r = x.r;
      var has = kids[r.id].length > 0, filtering = !!(findText || Object.keys(typeSel).length);
      var open = filtering ? true : !!expanded[r.id], st = secStatus(r.status), n = childCount(r);
      return '<div class="dh-tree-row' + (selectedId === r.id ? ' dh-tree-sel' : '') + '" role="treeitem" aria-level="' + (depth[r.id] + 1) + '"' +
        ' aria-posinset="' + x.pos + '" aria-setsize="' + x.size + '"' +
        ' aria-selected="' + (selectedId === r.id ? 'true' : 'false') + '"' + (has ? ' aria-expanded="' + (open ? 'true' : 'false') + '"' : '') +
        ' data-id="' + esc(r.id) + '" tabindex="' + (r.id === tabId ? '0' : '-1') + '" style="padding-left:' + (6 + depth[r.id] * 16) + 'px">' +
        '<span class="dh-tree-chev"' + (has ? ' data-act="toggle"' : '') + '>' + (has ? (open ? '&#9662;' : '&#9656;') : '') + '</span>' +
        '<span class="tt-type tt-type-' + esc(r.type) + '" title="' + esc(DH_TT_TYPE[r.type] || r.type) + '">' + esc(DH_TT_GLYPH[r.type] || '') + '</span>' +
        (st ? '<span class="dh-tree-dot dh-st-' + st + '" title="' + esc(SEC_LABEL[st] || '') + '"></span>' : '') +
        '<span class="dh-tree-label">' + esc(r.label) + '</span>' +
        (r.flags || []).map(function (f) { return '<span class="dh-tree-flag">' + esc(f) + '</span>'; }).join('') +
        (n ? '<span class="dh-tree-count">' + esc(String(n)) + '</span>' : '') + '</div>';
    }

    function renderTree(refocus) {
      rebuild();
      empty.hidden = flat.length > 0;
      if (refocus) scrollToIdx(flatIdx[refocus]);
      paint(false);
      if (refocus) { var el = rowEl(refocus); if (el) el.focus(); }
    }
    function rowEl(id) {
      var els = tree.querySelectorAll('.dh-tree-row');
      for (var i = 0; i < els.length; i++) if (els[i].getAttribute('data-id') === id) return els[i];
      return null;
    }

    function pathLabel(r) {
      var parts = [], p = r;
      while (p) { parts.unshift(p.label); p = p.parent ? byId[p.parent] : null; }
      return parts.join(' / ');
    }
    function chip(id) {
      var r = byId[id], st = secStatus(r.status);
      return '<button type="button" class="tt-link" data-goto="' + esc(id) + '"><span class="tt-type tt-type-' + esc(r.type) + '">' + esc(DH_TT_GLYPH[r.type] || '') + '</span>' +
             (st ? '<span class="dh-tree-dot dh-st-' + st + '"></span>' : '') + esc(r.label) + '</button>';
    }
    function tabsFor(r) {
      var t = [{ k: 'props', l: 'Properties' }];
      if (r.type === 'group') t.push({ k: 'members', l: 'Members (' + (membersOf[r.id] || []).length + ')' });
      if ((memberOf[r.id] || []).length) t.push({ k: 'memberof', l: 'Member of (' + memberOf[r.id].length + ')' });
      var nested = r.type === 'group' && dhTtNested(membersOf, typeOf, r.id, 6).length;
      if (nested || (memberOf[r.id] || []).length) t.push({ k: 'nesting', l: 'Nesting' });
      return t;
    }
    /* v2.6.0 - CSV: Id, ParentId, Type, Label, Path, Status, Flags, then every property name in the list */
    function csvOf(list) {
      var keys = [], seen = {};
      list.forEach(function (r) { (r.props || []).forEach(function (p) { if (!seen[p.label]) { seen[p.label] = 1; keys.push(p.label); } }); });
      var out = list.map(function (r) {
        var pv = {};
        (r.props || []).forEach(function (p) { pv[p.label] = p.value; });
        return [r.id, r.parent || '', DH_TT_TYPE[r.type] || r.type, r.label, pathLabel(r), r.status || '', (r.flags || []).join('; ')]
          .concat(keys.map(function (k) { return pv[k] == null ? '' : pv[k]; }));
      });
      return dhCsvText(['Id', 'ParentId', 'Type', 'Label', 'Path', 'Status', 'Flags'].concat(keys), out);
    }
    function csvName(suffix) {
      return (String(block.id || 'tree') + '-' + suffix).replace(/[^\w.\-]+/g, '_').slice(0, 80) + '.csv';
    }
    function csvButton(kind) {
      return '<button type="button" class="treefilter-btn tt-csv" data-tt-csv="' + kind + '" title="Save this list as CSV">CSV</button>';
    }

    function list(ids, cap) {
      if (!ids.length) return '<p class="dh-text">None.</p>';
      var shown = ids.slice(0, cap || 500);
      return '<div class="tt-list">' + shown.map(chip).join('') + '</div>' +
             (ids.length > shown.length ? '<p class="dh-more">+' + (ids.length - shown.length) + ' more</p>' : '');
    }

    function tabHtml(r) {
      if (tab === 'members') {
        var ms = membersOf[r.id] || [], c = { user: 0, computer: 0, group: 0 };
        ms.forEach(function (m) { if (c[typeOf[m]] !== undefined) c[typeOf[m]]++; });
        return '<p class="dh-text">' + ms.length + ' member' + (ms.length === 1 ? '' : 's') + ': ' + c.user + ' users, ' + c.computer + ' computers, ' + c.group + ' groups.' +
               (ms.length ? ' ' + csvButton('members') : '') + '</p>' + list(ms);
      }
      if (tab === 'memberof') return ((memberOf[r.id] || []).length ? '<p class="dh-text">' + csvButton('memberof') + '</p>' : '') + list(memberOf[r.id] || []);
      if (tab === 'nesting') {
        var h = '';
        if (r.type === 'group') {
          var nest = dhTtNested(membersOf, typeOf, r.id, 6);
          h += '<h4 class="dh-sec-title">Groups nested below</h4>';
          h += nest.length ? '<div class="tt-nest">' + nest.map(function (n) {
            return '<div style="padding-left:' + ((n.depth - 1) * 18) + 'px">' + chip(n.id) + (n.circular ? ' <span class="tt-circ">circular nesting</span>' : '') + '</div>';
          }).join('') + '</div>' : '<p class="dh-text">No groups are nested in this group.</p>';
        }
        var eff = dhTtPaths(memberOf, r.id, maxPaths);
        h += '<h4 class="dh-sec-title">Effective membership: every path up</h4>';
        if (!eff.paths.length) h += '<p class="dh-text">Not a member of any group.</p>';
        else {
          h += '<div class="tt-nest">' + eff.paths.map(function (p) {
            return '<div class="tt-path">' + p.map(function (id, i) { return (i ? '<span class="tt-arrow">→</span>' : '') + chip(id); }).join('') + '</div>';
          }).join('') + '</div>';
          if (eff.more) h += '<p class="dh-more">+' + eff.more + ' more paths</p>';
        }
        if (eff.circular) h += '<p class="tt-circ-note">A group is (directly or indirectly) a member of itself; the loop was not followed.</p>';
        return h;
      }
      var items = [{ label: 'Type', value: DH_TT_TYPE[r.type] || r.type }, { label: 'Location', value: pathLabel(r) }];
      (r.props || []).forEach(function (p) { items.push({ label: p.label, value: p.value }); });
      var secs = [{ kind: 'kv', title: '', columns: 2, items: items }];
      if (r.detail && r.detail.sections) secs = secs.concat(r.detail.sections);
      return renderSections(secs);
    }

    function renderDetail() {
      var r = selectedId && byId[selectedId];
      if (!r) { head.innerHTML = ''; tabsEl.innerHTML = ''; body.innerHTML = '<p class="dh-text">Select an object on the left.</p>'; return; }
      var st = secStatus(r.status);
      head.innerHTML = '<span class="tt-type tt-type-' + esc(r.type) + '">' + esc(DH_TT_GLYPH[r.type] || '') + '</span>' +
        '<span class="tt-head-label">' + esc(r.label) + '</span>' + (st ? '<span class="dh-pill dh-st-' + st + '">' + esc(SEC_LABEL[st]) + '</span>' : '') +
        (r.flags || []).map(function (f) { return '<span class="dh-tree-flag">' + esc(f) + '</span>'; }).join('');
      var ts = tabsFor(r);
      if (!ts.some(function (x) { return x.k === tab; })) tab = 'props';
      tabsEl.innerHTML = ts.map(function (x) {
        return '<button type="button" class="tt-tab" role="tab" data-tab="' + x.k + '" aria-selected="' + (x.k === tab ? 'true' : 'false') + '" tabindex="' + (x.k === tab ? '0' : '-1') + '">' + esc(x.l) + '</button>';
      }).join('');
      body.innerHTML = tabHtml(r);
    }

    function select(id, keepTab) {
      if (!byId[id]) return;
      selectedId = id; focusId = id;
      if (!keepTab) tab = 'props';
      renderTree(); renderDetail();
    }
    function goTo(id) {                                  /* a link in a tab: make the row visible, then select it */
      var p = byId[id] && byId[id].parent;
      while (p && byId[p]) { expanded[p] = true; p = byId[p].parent; }
      rebuild();
      if (flatIdx[id] === undefined) { findText = ''; find.value = ''; typeSel = {}; container.querySelectorAll('.tt-chip').forEach(function (c) { c.setAttribute('aria-pressed', 'false'); }); }
      select(id);
      if (WIN) { scrollToIdx(flatIdx[id]); paint(false); }
      var el = rowEl(id); if (el && el.scrollIntoView) el.scrollIntoView({ block: 'nearest' });
    }

    tree.addEventListener('click', function (e) {
      var rowNode = e.target.closest('.dh-tree-row'); if (!rowNode) return;
      var id = rowNode.getAttribute('data-id'), act = e.target.closest('[data-act]');
      if (act && act.getAttribute('data-act') === 'toggle') { expanded[id] = !expanded[id]; focusId = id; renderTree(id); return; }
      select(id);
    });
    tree.addEventListener('keydown', function (e) {
      var rowNode = e.target.closest && e.target.closest('.dh-tree-row'), id;
      if (rowNode && e.target === rowNode) id = rowNode.getAttribute('data-id');
      else if (e.target === tree && focusId && flatIdx[focusId] !== undefined) id = focusId;   /* windowed: the focused row scrolled away */
      else return;
      var r = byId[id], i = flatIdx[id], key = e.key, to = null;
      if (i === undefined) return;
      var filtering = !!(findText || Object.keys(typeSel).length);
      if (key === 'ArrowDown') to = flat[Math.min(i + 1, flat.length - 1)].r;
      else if (key === 'ArrowUp') to = flat[Math.max(i - 1, 0)].r;
      else if (key === 'Home') to = flat[0].r;
      else if (key === 'End') to = flat[flat.length - 1].r;
      else if (key === 'ArrowRight') {
        if (kids[id].length && !expanded[id] && !filtering) { expanded[id] = true; focusId = id; e.preventDefault(); renderTree(id); return; }
        if (kids[id].length) to = kids[id][0];
      } else if (key === 'ArrowLeft') {
        if (kids[id].length && expanded[id] && !filtering) { expanded[id] = false; focusId = id; e.preventDefault(); renderTree(id); return; }
        to = r.parent ? byId[r.parent] : null;
      } else if (key === 'Enter' || key === ' ') { e.preventDefault(); select(id); var el0 = rowEl(id); if (el0) el0.focus(); return; }
      else return;
      e.preventDefault();
      if (to) { focusId = to.id; renderTree(to.id); }
    });
    /* the row with focus is the keyboard's starting point, however it got focus (Tab, click, script) */
    tree.addEventListener('focusin', function (e) {
      var fr = e.target.closest && e.target.closest('.dh-tree-row');
      if (fr) focusId = fr.getAttribute('data-id');
    });
    var findTimer = 0;
    find.addEventListener('input', function () {
      findText = find.value;
      if (!WIN) { renderTree(); return; }
      clearTimeout(findTimer);
      findTimer = setTimeout(function () { tree.scrollTop = 0; renderTree(); }, 150);   /* 50,000 rows: wait for a pause in typing */
    });
    container.querySelector('.tt-toolbar').addEventListener('click', function (e) {
      var tb = e.target.closest('[data-tt]');
      if (tb && tb.getAttribute('data-tt') === 'csv') {
        dhCsvDownload(csvOf(flat.map(function (x) { return x.r; })), csvName('visible'));
        return;
      }
      if (tb) {
        if (tb.getAttribute('data-tt') === 'expand') order.forEach(function (r) { if (kids[r.id].length) expanded[r.id] = true; });
        else expanded = {};
        renderTree(); return;
      }
      var ch = e.target.closest('[data-tt-type]');
      if (ch) {
        var t = ch.getAttribute('data-tt-type');
        if (typeSel[t]) delete typeSel[t]; else typeSel[t] = true;
        ch.setAttribute('aria-pressed', typeSel[t] ? 'true' : 'false');
        renderTree();
      }
    });
    tabsEl.addEventListener('click', function (e) {
      var b = e.target.closest('[data-tab]'); if (!b) return;
      tab = b.getAttribute('data-tab'); renderDetail();
    });
    tabsEl.addEventListener('keydown', function (e) {
      if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight' && e.key !== 'Home' && e.key !== 'End') return;
      var bs = Array.prototype.slice.call(tabsEl.querySelectorAll('[data-tab]')), i = bs.indexOf(document.activeElement);
      if (i < 0) return;
      e.preventDefault();
      var n = e.key === 'Home' ? 0 : e.key === 'End' ? bs.length - 1 : (i + (e.key === 'ArrowRight' ? 1 : -1) + bs.length) % bs.length;
      tab = bs[n].getAttribute('data-tab'); renderDetail();
      var nb = tabsEl.querySelector('[data-tab="' + tab + '"]'); if (nb) nb.focus();
    });
    body.addEventListener('click', function (e) {
      var cb = e.target.closest('[data-tt-csv]');
      if (cb && selectedId && byId[selectedId]) {
        var kind = cb.getAttribute('data-tt-csv'), sr = byId[selectedId];
        var ids = (kind === 'members' ? membersOf[sr.id] : memberOf[sr.id]) || [];
        dhCsvDownload(csvOf(ids.map(function (x) { return byId[x]; }).filter(Boolean)), csvName(sr.label + '-' + (kind === 'members' ? 'members' : 'member-of')));
        return;
      }
      var g = e.target.closest('[data-goto]'); if (g) goTo(g.getAttribute('data-goto'));
    });

    if (roots.length) select(roots[0].id); else { renderTree(); renderDetail(); }
  }
'@
}
