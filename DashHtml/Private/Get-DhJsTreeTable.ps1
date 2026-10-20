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
    function visibleRows() {
      var q = findText.toLowerCase(), anyType = Object.keys(typeSel).length;
      var match = null, force = {};
      if (q || anyType) {
        match = {};
        rows.forEach(function (r) {
          if (anyType && !typeSel[r.type]) return;
          if (q && (r.label + ' ' + r.type).toLowerCase().indexOf(q) === -1) return;
          match[r.id] = true;
          var p = r.parent;
          while (p && byId[p]) { force[p] = true; p = byId[p].parent; }
        });
      }
      var out = [];
      (function walk(list) {
        list.forEach(function (r) {
          if (match && !match[r.id] && !force[r.id]) return;
          out.push(r);
          var open = match ? !!force[r.id] : !!expanded[r.id];
          if (kids[r.id].length && open) walk(kids[r.id]);
        });
      })(roots);
      return out;
    }

    function rowHtml(r, tabId) {
      var has = kids[r.id].length > 0, filtering = !!(findText || Object.keys(typeSel).length);
      var open = filtering ? true : !!expanded[r.id], st = secStatus(r.status), n = childCount(r);
      return '<div class="dh-tree-row' + (selectedId === r.id ? ' dh-tree-sel' : '') + '" role="treeitem" aria-level="' + (depth[r.id] + 1) + '"' +
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
      var list = visibleRows();
      var tabId = (focusId && list.some(function (r) { return r.id === focusId; })) ? focusId : (list[0] && list[0].id);
      tree.innerHTML = list.map(function (r) { return rowHtml(r, tabId); }).join('');
      empty.hidden = list.length > 0;
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
        return '<p class="dh-text">' + ms.length + ' member' + (ms.length === 1 ? '' : 's') + ': ' + c.user + ' users, ' + c.computer + ' computers, ' + c.group + ' groups.</p>' + list(ms);
      }
      if (tab === 'memberof') return list(memberOf[r.id] || []);
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
      var hidden = !visibleRows().some(function (r) { return r.id === id; });
      if (hidden) { findText = ''; find.value = ''; typeSel = {}; container.querySelectorAll('.tt-chip').forEach(function (c) { c.setAttribute('aria-pressed', 'false'); }); }
      select(id);
      var el = rowEl(id); if (el && el.scrollIntoView) el.scrollIntoView({ block: 'nearest' });
    }

    tree.addEventListener('click', function (e) {
      var rowNode = e.target.closest('.dh-tree-row'); if (!rowNode) return;
      var id = rowNode.getAttribute('data-id'), act = e.target.closest('[data-act]');
      if (act && act.getAttribute('data-act') === 'toggle') { expanded[id] = !expanded[id]; focusId = id; renderTree(id); return; }
      select(id);
    });
    tree.addEventListener('keydown', function (e) {
      var rowNode = e.target.closest && e.target.closest('.dh-tree-row'); if (!rowNode || e.target !== rowNode) return;
      var id = rowNode.getAttribute('data-id'), r = byId[id], list2 = visibleRows(), i = list2.indexOf(r), key = e.key, to = null;
      var filtering = !!(findText || Object.keys(typeSel).length);
      if (key === 'ArrowDown') to = list2[Math.min(i + 1, list2.length - 1)];
      else if (key === 'ArrowUp') to = list2[Math.max(i - 1, 0)];
      else if (key === 'Home') to = list2[0];
      else if (key === 'End') to = list2[list2.length - 1];
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
    find.addEventListener('input', function () { findText = find.value; renderTree(); });
    container.querySelector('.tt-toolbar').addEventListener('click', function (e) {
      var tb = e.target.closest('[data-tt]');
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
      var g = e.target.closest('[data-goto]'); if (g) goTo(g.getAttribute('data-goto'));
    });

    if (roots.length) select(roots[0].id); else { renderTree(); renderDetail(); }
  }
'@
}
