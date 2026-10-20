function Get-DhJsNetwork {
    # Fragment of the dashboard runtime JS (see Get-DhJsContent). v2.4.0.
    return @'
  /* =========================================================================
     NETWORK MAP (v2.4.0) - Add-DhNetworkMap
     Layout and path finding are PURE functions (data in, numbers out) and
     deterministic: same input, same picture. No force simulation (decision D3).
     Pan/zoom is createPanZoom() shared with the topology map. One delegated
     click handler on the SVG; no per-node listeners.
     ========================================================================= */

  var DH_NET = { GX: 26, GY: 30, PAD: 14, HEAD: 26, TOP: 1100, MARGIN: 20, LANE_LABEL: 96, LANE_PAD: 30 };

  /* Place boxes left to right, wrapping at `limit`. Mutates x/y on each item. */
  function dhNetFlow(items, limit, gap) {
    var x = 0, y = 0, rowH = 0, maxW = 0;
    items.forEach(function (it) {
      if (x > 0 && x + it.w > limit) { x = 0; y += rowH + gap; rowH = 0; }
      it.x = x; it.y = y; x += it.w + gap;
      if (it.h > rowH) rowH = it.h;
      if (x - gap > maxW) maxW = x - gap;
    });
    return { w: maxW, h: items.length ? y + rowH : 0 };
  }

  /* Rect-edge point on the line from the rect centre toward (tx, ty). */
  function dhNetBoundary(r, tx, ty) {
    var cx = r.x + r.w / 2, cy = r.y + r.h / 2, dx = tx - cx, dy = ty - cy;
    if (!dx && !dy) return { x: cx, y: cy };
    var s = Math.min(dx ? (r.w / 2) / Math.abs(dx) : Infinity, dy ? (r.h / 2) / Math.abs(dy) : Infinity);
    return { x: cx + dx * s, y: cy + dy * s };
  }

  /* Layout of a network map. Returns
     { pos:{id:{x,y,w,h}}, groups:[{id,label,status,x,y,w,h,depth}], lanes:[{tier,label,y,h}], width, height } */
  function dhNetLayout(block) {
    var G = DH_NET, nodes = block.nodes || [], edges = block.edges || [], groups = block.groups || [];
    var nw = block.nodeWidth || 150, nh = block.nodeHeight || 46;
    var pos = {}, outGroups = [], lanes = [];

    if (String(block.layout || 'grouped') === 'layered') {
      var byId = {}, out = {}, indeg = {}, depth = {}, order = {};
      nodes.forEach(function (n, i) { byId[n.id] = n; out[n.id] = []; indeg[n.id] = 0; order[n.id] = i; });
      edges.forEach(function (e) {
        if (e.from === e.to || !byId[e.from] || !byId[e.to]) return;
        out[e.from].push(e.to); indeg[e.to]++;
      });
      var seen = {};
      function bfs(startId) {
        var q = [startId]; seen[startId] = true; depth[startId] = 0;
        for (var qi = 0; qi < q.length; qi++) {
          out[q[qi]].forEach(function (t) {
            if (!seen[t]) { seen[t] = true; depth[t] = depth[q[qi]] + 1; q.push(t); }
          });
        }
      }
      nodes.forEach(function (n) { if (!indeg[n.id] && !seen[n.id]) bfs(n.id); });
      nodes.forEach(function (n) { if (!seen[n.id]) bfs(n.id); });      /* what is left sits in a cycle */

      var tierOf = {}, tiers = [];
      nodes.forEach(function (n) {
        var t = (n.tier !== undefined && n.tier !== null) ? n.tier : depth[n.id];
        tierOf[n.id] = t;
        if (tiers.indexOf(t) === -1) tiers.push(t);
      });
      tiers.sort(function (a, b) { return a - b; });
      var lane = tiers.map(function (t) { return nodes.filter(function (n) { return tierOf[n.id] === t; }).map(function (n) { return n.id; }); });

      /* one barycentre sweep, top to bottom; stable, ties by declaration order */
      var rank = {};
      lane[0].forEach(function (id, i) { rank[id] = (i + 0.5) / lane[0].length; });
      var nbr = {};
      nodes.forEach(function (n) { nbr[n.id] = []; });
      edges.forEach(function (e) {
        if (e.from === e.to || !byId[e.from] || !byId[e.to]) return;
        nbr[e.from].push(e.to); nbr[e.to].push(e.from);
      });
      for (var li = 1; li < lane.length; li++) {
        var keyed = lane[li].map(function (id, i) {
          var sum = 0, cnt = 0;
          nbr[id].forEach(function (o) {
            if (tiers.indexOf(tierOf[o]) < li && rank[o] !== undefined) { sum += rank[o]; cnt++; }
          });
          return { id: id, key: cnt ? sum / cnt : (i + 0.5) / lane[li].length, o: order[id] };
        });
        keyed.sort(function (a, b) { return (a.key - b.key) || (a.o - b.o); });
        lane[li] = keyed.map(function (k) { return k.id; });
        lane[li].forEach(function (id, i) { rank[id] = (i + 0.5) / lane[li].length; });
      }
      var maxW = 0;
      lane.forEach(function (ids) { var w = ids.length * nw + (ids.length - 1) * G.GX; if (w > maxW) maxW = w; });
      var laneH = nh + 2 * G.LANE_PAD, y0 = G.MARGIN;
      lane.forEach(function (ids, i) {
        var w = ids.length * nw + (ids.length - 1) * G.GX, x0 = G.MARGIN + G.LANE_LABEL + (maxW - w) / 2;
        ids.forEach(function (id, k) { pos[id] = { x: x0 + k * (nw + G.GX), y: y0 + G.LANE_PAD, w: nw, h: nh }; });
        lanes.push({ tier: tiers[i], label: 'Tier ' + tiers[i], y: y0, h: laneH });
        y0 += laneH;
      });
      return { pos: pos, groups: [], lanes: lanes, width: G.MARGIN * 2 + G.LANE_LABEL + maxW, height: y0 + G.MARGIN };
    }

    /* grouped */
    var gById = {}, kidsOf = {}, nodesOf = { '': [] };
    groups.forEach(function (g) { gById[g.id] = g; kidsOf[g.id] = []; nodesOf[g.id] = []; });
    var rootGroups = [];
    groups.forEach(function (g) { if (g.parent && gById[g.parent]) kidsOf[g.parent].push(g); else rootGroups.push(g); });
    nodes.forEach(function (n) { (nodesOf[(n.group && gById[n.group]) ? n.group : ''] || nodesOf['']).push(n); });

    function nodesBlock(members, inner) {
      var fit = Math.max(1, Math.floor((inner + G.GX) / (nw + G.GX)));
      var cols = Math.max(1, Math.min(Math.ceil(Math.sqrt(members.length)), fit, 5));
      var rows = Math.ceil(members.length / cols);
      return { kind: 'nodes', members: members, cols: cols, w: cols * nw + (cols - 1) * G.GX, h: rows * nh + (rows - 1) * G.GY };
    }
    function groupBox(g, limit) {
      var inner = limit - 2 * G.PAD, items = [];
      if (nodesOf[g.id].length) items.push(nodesBlock(nodesOf[g.id], inner));
      kidsOf[g.id].forEach(function (c) { var b = groupBox(c, inner); b.kind = 'group'; items.push(b); });
      var f = dhNetFlow(items, inner, G.GX);
      var labelW = String(g.label || '').length * 7 + 2 * G.PAD;
      return { g: g, items: items, w: Math.max(f.w + 2 * G.PAD, labelW), h: G.HEAD + f.h + G.PAD };
    }
    function place(box, ox, oy, d) {
      outGroups.push({ id: box.g.id, label: box.g.label, status: box.g.status || '', x: ox, y: oy, w: box.w, h: box.h, depth: d });
      box.items.forEach(function (it) {
        var bx = ox + G.PAD + it.x, by = oy + G.HEAD + it.y;
        if (it.kind === 'nodes') {
          it.members.forEach(function (n, i) {
            pos[n.id] = { x: bx + (i % it.cols) * (nw + G.GX), y: by + Math.floor(i / it.cols) * (nh + G.GY), w: nw, h: nh };
          });
        } else place(it, bx, by, d + 1);
      });
    }
    var top = [];
    if (nodesOf[''].length) top.push(nodesBlock(nodesOf[''], G.TOP));
    rootGroups.forEach(function (g) { var b = groupBox(g, G.TOP); b.kind = 'group'; top.push(b); });
    var tf = dhNetFlow(top, G.TOP, G.GX);
    top.forEach(function (it) {
      var bx = G.MARGIN + it.x, by = G.MARGIN + it.y;
      if (it.kind === 'nodes') {
        it.members.forEach(function (n, i) {
          pos[n.id] = { x: bx + (i % it.cols) * (nw + G.GX), y: by + Math.floor(i / it.cols) * (nh + G.GY), w: nw, h: nh };
        });
      } else place(it, bx, by, 0);
    });
    return { pos: pos, groups: outGroups, lanes: [], width: tf.w + 2 * G.MARGIN, height: tf.h + 2 * G.MARGIN };
  }

  /* Geometry of every edge: parallel edges between a pair fan out; a self edge is a loop.
     Returns [{ d, mx, my, loop }] in the order of `edges`. */
  function dhNetEdgeGeom(edges, pos) {
    var pairs = {}, idx = [];
    edges.forEach(function (e, i) {
      var k = e.from < e.to ? e.from + '\u0001' + e.to : e.to + '\u0001' + e.from;
      (pairs[k] = pairs[k] || []).push(i);
      idx[i] = k;
    });
    return edges.map(function (e, i) {
      var a = pos[e.from], b = pos[e.to];
      if (!a || !b) return null;
      if (e.from === e.to) {
        var tx = a.x + a.w / 2, ty = a.y;
        return { d: 'M' + (tx - 14) + ',' + ty + ' C' + (tx - 34) + ',' + (ty - 40) + ' ' + (tx + 34) + ',' + (ty - 40) + ' ' + (tx + 14) + ',' + ty,
                 mx: tx, my: ty - 30, loop: true };
      }
      var group = pairs[idx[i]], k = group.indexOf(i), n = group.length;
      var lo = e.from < e.to ? a : b, hi = e.from < e.to ? b : a;
      var cax = lo.x + lo.w / 2, cay = lo.y + lo.h / 2, cbx = hi.x + hi.w / 2, cby = hi.y + hi.h / 2;
      var dx = cbx - cax, dy = cby - cay, len = Math.sqrt(dx * dx + dy * dy) || 1;
      var off = (k - (n - 1) / 2) * 30;
      var cx = (cax + cbx) / 2 + (-dy / len) * off * 2, cy = (cay + cby) / 2 + (dx / len) * off * 2;
      var p0 = dhNetBoundary(a, cx, cy), p2 = dhNetBoundary(b, cx, cy);
      return { d: 'M' + p0.x.toFixed(1) + ',' + p0.y.toFixed(1) + ' Q' + cx.toFixed(1) + ',' + cy.toFixed(1) + ' ' + p2.x.toFixed(1) + ',' + p2.y.toFixed(1),
               mx: 0.25 * p0.x + 0.5 * cx + 0.25 * p2.x, my: 0.25 * p0.y + 0.5 * cy + 0.25 * p2.y, loop: false };
    });
  }

  /* Shortest path from startId to the nearest Target node. Directed edges are followed
     forward only; 'both' and 'none' edges either way. BFS in declaration order, so ties
     are broken deterministically. Returns { nodes:[ids], edges:[edge indexes] } or null. */
  function dhNetPath(block, startId) {
    var nodes = block.nodes || [], edges = block.edges || [], byId = {}, adj = {};
    nodes.forEach(function (n) { byId[n.id] = n; adj[n.id] = []; });
    if (!byId[startId]) return null;
    edges.forEach(function (e, i) {
      if (!byId[e.from] || !byId[e.to] || e.from === e.to) return;
      adj[e.from].push({ to: e.to, i: i });
      if (e.direction === 'both' || e.direction === 'none') adj[e.to].push({ to: e.from, i: i });
    });
    if (byId[startId].target) return { nodes: [startId], edges: [] };
    var prev = {}, q = [startId], seen = {};
    seen[startId] = true;
    for (var qi = 0; qi < q.length; qi++) {
      var cur = q[qi];
      for (var k = 0; k < adj[cur].length; k++) {
        var s = adj[cur][k];
        if (seen[s.to]) continue;
        seen[s.to] = true; prev[s.to] = { from: cur, i: s.i }; q.push(s.to);
        if (byId[s.to].target) {
          var pn = [s.to], pe = [], at = s.to;
          while (at !== startId) { pe.unshift(prev[at].i); at = prev[at].from; pn.unshift(at); }
          return { nodes: pn, edges: pe };
        }
      }
    }
    return null;
  }

  function dhNetTrunc(s, max) {
    s = String(s == null ? '' : s);
    return s.length > max ? s.slice(0, Math.max(1, max - 1)) + '…' : s;
  }

  var DH_NET_STATUSES = ['ok', 'warn', 'danger', 'info', 'nodata'];

  function renderNetworkMap(container, block) {
    container.className = 'network-map-section';
    var nodes = block.nodes || [], edges = block.edges || [];
    var titleHtml = block.title ? '<h3 class="network-map-title">' + esc(block.title) + '</h3>' : '';
    if (!nodes.length) { container.innerHTML = titleHtml + '<div class="network-map-empty">No nodes.</div>'; return; }

    var nw = block.nodeWidth || 150, nh = block.nodeHeight || 46;
    var L = dhNetLayout(block), geom = dhNetEdgeGeom(edges, L.pos);
    var byId = {};
    nodes.forEach(function (n) { byId[n.id] = n; });
    var uid = 'nm-' + block.id.replace(/[^A-Za-z0-9_-]/g, '_');

    /* ---- svg body ---------------------------------------------------- */
    var markerDefs = DH_NET_STATUSES.concat(['none']).map(function (s) {
      return '<marker id="' + uid + '-arr-' + s + '" class="nm-arrow nm-e-' + s + '" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="9" markerHeight="9" markerUnits="userSpaceOnUse" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z"/></marker>';
    }).join('');

    var lanesSvg = L.lanes.map(function (ln, i) {
      return '<g class="nm-lane"><rect class="nm-lane-band' + (i % 2 ? ' nm-lane-alt' : '') + '" x="' + DH_NET.MARGIN + '" y="' + ln.y + '" width="' + (L.width - 2 * DH_NET.MARGIN) + '" height="' + ln.h + '"/>' +
             '<text class="nm-lane-label" x="' + (DH_NET.MARGIN + 10) + '" y="' + (ln.y + ln.h / 2 + 4) + '">' + esc(ln.label) + '</text></g>';
    }).join('');

    var groupsSvg = L.groups.map(function (g) {
      var st = g.status ? ' nm-st-' + g.status : '';
      return '<g class="nm-group' + st + '"><rect class="nm-group-box" x="' + g.x + '" y="' + g.y + '" width="' + g.w + '" height="' + g.h + '" rx="8"/>' +
             '<text class="nm-group-label" x="' + (g.x + 10) + '" y="' + (g.y + 17) + '">' + esc(dhNetTrunc(g.label, Math.floor(g.w / 7))) + '</text></g>';
    }).join('');

    var edgesSvg = edges.map(function (e, i) {
      var gm = geom[i]; if (!gm) return '';
      var st = e.status || 'none', dir = e.direction || 'forward';
      var mk = (dir === 'forward' || dir === 'both' ? ' marker-end="url(#' + uid + '-arr-' + st + ')"' : '') +
               (dir === 'both' ? ' marker-start="url(#' + uid + '-arr-' + st + ')"' : '');
      var tipText = e.tooltip || ((byId[e.from] ? byId[e.from].label : e.from) + ' → ' + (byId[e.to] ? byId[e.to].label : e.to) + (e.label ? ': ' + e.label : ''));
      var lbl = '';
      if (e.label) {
        var lw = Math.max(18, String(e.label).length * 6 + 10);
        lbl = '<g class="nm-edge-label"><rect x="' + (gm.mx - lw / 2).toFixed(1) + '" y="' + (gm.my - 8).toFixed(1) + '" width="' + lw + '" height="16" rx="8"/>' +
              '<text x="' + gm.mx.toFixed(1) + '" y="' + (gm.my + 3.5).toFixed(1) + '" text-anchor="middle">' + esc(e.label) + '</text></g>';
      }
      return '<g class="nm-edge nm-e-' + st + (e.style === 'dashed' ? ' nm-dashed' : '') + ((e.linkTableId) ? ' nm-clickable' : '') + '" data-ei="' + i + '" data-tip="' + esc(tipText) + '">' +
             '<path class="nm-edge-hit" d="' + gm.d + '"/><path class="nm-edge-line" d="' + gm.d + '"' + mk + '/>' + lbl + '</g>';
    }).join('');

    var maxChars = Math.max(4, Math.floor((nw - 34) / 6.6));
    var nodesSvg = nodes.map(function (n, i) {
      var p = L.pos[n.id]; if (!p) return '';
      var st = n.status ? ' nm-st-' + n.status : '';
      var badges = n.badges || [];
      var bTxt = badges.slice(0, 3).join(' · ') + (badges.length > 3 ? ' +' + (badges.length - 3) : '');
      var yLabel = bTxt ? p.h * 0.42 : p.h / 2 + 4, yBadge = p.h * 0.78;
      var label = (n.icon ? n.icon + ' ' : '') + n.label;
      var aria = n.label + (n.status ? ', ' + (SEC_LABEL[n.status] || n.status) : '') + (badges.length ? ', ' + badges.join(', ') : '') + (n.target ? ', target' : '');
      var tip = n.tooltip || (n.label + (badges.length ? ' (' + badges.join(', ') + ')' : ''));
      return '<g class="nm-node' + st + (n.target ? ' nm-target' : '') + '" data-id="' + esc(n.id) + '" tabindex="0" role="button" aria-label="' + esc(aria) + '"' +
             ' data-tip="' + esc(tip) + '" transform="translate(' + p.x.toFixed(1) + ',' + p.y.toFixed(1) + ')">' +
             '<rect class="nm-node-box" width="' + p.w + '" height="' + p.h + '" rx="7"/>' +
             '<circle class="nm-led" cx="13" cy="' + (p.h / 2) + '" r="4.5"/>' +
             '<text class="nm-node-label" x="26" y="' + yLabel.toFixed(1) + '">' + esc(dhNetTrunc(label, maxChars)) + '</text>' +
             (bTxt ? '<text class="nm-node-badges" x="26" y="' + yBadge.toFixed(1) + '">' + esc(dhNetTrunc(bTxt, maxChars + 2)) + '</text>' : '') +
             (n.target ? '<text class="nm-target-mark" x="' + (p.w - 14) + '" y="15" text-anchor="middle">◎</text>' : '') +
             '</g>';
    }).join('');

    /* ---- toolbar ------------------------------------------------------ */
    var stSet = [], bdSet = [];
    nodes.forEach(function (n) {
      if (n.status && stSet.indexOf(n.status) === -1) stSet.push(n.status);
      (n.badges || []).forEach(function (b) { if (bdSet.indexOf(b) === -1) bdSet.push(b); });
    });
    stSet.sort(function (a, b) { return DH_NET_STATUSES.indexOf(a) - DH_NET_STATUSES.indexOf(b); });
    var hasTarget = nodes.some(function (n) { return n.target; });
    var chips =
      stSet.map(function (s) { return '<button type="button" class="nm-chip nm-st-' + s + '" data-f="s:' + esc(s) + '" aria-pressed="false"><span class="nm-chip-dot"></span>' + esc(SEC_LABEL[s] || s) + '</button>'; }).join('') +
      bdSet.slice(0, 12).map(function (b) { return '<button type="button" class="nm-chip" data-f="b:' + esc(b) + '" aria-pressed="false">' + esc(b) + '</button>'; }).join('');
    var legendHtml = '';
    if (block.legend) {
      legendHtml = '<div class="nm-legend" aria-label="Legend">' +
        DH_NET_STATUSES.map(function (s) { return '<span class="nm-legend-item nm-st-' + s + '"><span class="nm-chip-dot"></span>' + esc(SEC_LABEL[s]) + '</span>'; }).join('') +
        '<span class="nm-legend-item"><svg width="30" height="8" aria-hidden="true"><line x1="0" y1="4" x2="30" y2="4" class="nm-legend-line"/></svg>link</span>' +
        '<span class="nm-legend-item"><svg width="30" height="8" aria-hidden="true"><line x1="0" y1="4" x2="30" y2="4" class="nm-legend-line nm-dashed-line"/></svg>dashed</span>' +
        (hasTarget ? '<span class="nm-legend-item"><span class="nm-target-sample">◎</span>target</span>' : '') + '</div>';
    }
    var srList = '<ul class="nm-sr">' + edges.map(function (e) {
      var a = byId[e.from], b = byId[e.to];
      return '<li>' + esc((a ? a.label : e.from) + (e.direction === 'both' ? ' ↔ ' : e.direction === 'none' ? ' — ' : ' → ') + (b ? b.label : e.to) +
             (e.label ? ' (' + e.label + ')' : '') + (e.status ? ', ' + (SEC_LABEL[e.status] || e.status) : '')) + '</li>';
    }).join('') + '</ul>';

    var initH = Math.min(Math.max(block.height || 520, 200), 1600);
    container.innerHTML = titleHtml +
      '<div class="network-map-toolbar" role="toolbar" aria-label="Network map controls">' +
        '<button type="button" class="topo-btn" data-topo-act="zoom-in" title="Zoom in" aria-label="Zoom in">+</button>' +
        '<button type="button" class="topo-btn" data-topo-act="zoom-out" title="Zoom out" aria-label="Zoom out">−</button>' +
        '<button type="button" class="topo-btn" data-topo-act="reset" title="Reset view" aria-label="Reset view">⤢</button>' +
        '<input type="search" class="nm-search" placeholder="Find node…" aria-label="Find a node" autocomplete="off">' +
        '<button type="button" class="nm-btn" data-nm="labels" aria-pressed="true" title="Show or hide link labels">Labels</button>' +
        (hasTarget ? '<button type="button" class="nm-btn" data-nm="path" aria-pressed="false" title="Select a node, then trace the shortest path to the nearest target">Trace path</button>' : '') +
        '<button type="button" class="nm-btn" data-nm="svg" title="Download as SVG">SVG</button>' +
        (chips ? '<span class="nm-chips" role="group" aria-label="Filters">' + chips + '</span>' : '') +
      '</div>' + legendHtml +
      '<div class="network-map-inner topo-interactive" style="height:' + initH + 'px">' +
        '<svg class="network-map-svg" width="100%" height="100%" role="group" aria-label="' + esc((block.title || 'Network map') + ': ' + nodes.length + ' nodes, ' + edges.length + ' links') + '">' +
          '<defs>' + markerDefs + '</defs><g class="topo-viewport nm-viewport">' +
          '<g class="nm-lanes">' + lanesSvg + '</g><g class="nm-groups">' + groupsSvg + '</g><g class="nm-edges">' + edgesSvg + '</g><g class="nm-nodes">' + nodesSvg + '</g>' +
        '</g></svg></div>' +
      '<div class="nm-status" role="status" aria-live="polite"></div>' + srList;

    var innerDiv = container.querySelector('.network-map-inner');
    var svgEl = container.querySelector('.network-map-svg');
    var vp = container.querySelector('.nm-viewport');
    var tbar = container.querySelector('.network-map-toolbar');
    var statusEl = container.querySelector('.nm-status');
    var search = container.querySelector('.nm-search');
    var nodeEls = {}, edgeEls = [];
    container.querySelectorAll('.nm-node').forEach(function (el) { nodeEls[el.getAttribute('data-id')] = el; });
    container.querySelectorAll('.nm-edge').forEach(function (el) { edgeEls[parseInt(el.getAttribute('data-ei'), 10)] = el; });
    if (edges.length > 400) container.classList.add('nm-hide-labels');

    var pz = createPanZoom({
      innerDiv: innerDiv, svgEl: svgEl, vp: vp, initH: initH, toolbar: tbar,
      getContent: function () { return { w: L.width, h: L.height }; }
    });
    pz.syncViewBox(); pz.fit();

    /* ---- state + painting -------------------------------------------- */
    var fStatus = {}, fBadge = {}, selected = null, pathMode = false, pathRes = null, q = '';
    function nodeMatches(n) {
      var sK = Object.keys(fStatus), bK = Object.keys(fBadge);
      if (sK.length && !fStatus[n.status || '']) return false;
      if (bK.length && !(n.badges || []).some(function (b) { return fBadge[b]; })) return false;
      if (q) {
        var hay = (n.label + ' ' + n.id + ' ' + (n.badges || []).join(' ')).toLowerCase();
        if (hay.indexOf(q) === -1) return false;
      }
      return true;
    }
    function paint() {
      var anyFilter = Object.keys(fStatus).length || Object.keys(fBadge).length || q;
      var near = null;
      if (selected && !pathRes) {
        near = {}; near[selected] = true;
        edges.forEach(function (e) {
          if (e.from === selected) near[e.to] = true;
          if (e.to === selected) near[e.from] = true;
        });
      }
      var onPathN = {}, onPathE = {};
      if (pathRes) { pathRes.nodes.forEach(function (id) { onPathN[id] = true; }); pathRes.edges.forEach(function (i) { onPathE[i] = true; }); }
      nodes.forEach(function (n) {
        var el = nodeEls[n.id]; if (!el) return;
        var dim = (anyFilter && !nodeMatches(n)) || (near && !near[n.id]) || (pathRes && !onPathN[n.id]);
        el.classList.toggle('nm-dim', !!dim);
        el.classList.toggle('nm-sel', selected === n.id);
        el.classList.toggle('nm-onpath', !!onPathN[n.id] && !!pathRes);
      });
      edges.forEach(function (e, i) {
        var el = edgeEls[i]; if (!el) return;
        var a = byId[e.from], b = byId[e.to];
        var dim = (anyFilter && ((a && !nodeMatches(a)) || (b && !nodeMatches(b)))) ||
                  (selected && !pathRes && e.from !== selected && e.to !== selected) || (pathRes && !onPathE[i]);
        el.classList.toggle('nm-dim', !!dim);
        el.classList.toggle('nm-onpath', !!onPathE[i] && !!pathRes);
      });
    }
    function say(t) { statusEl.textContent = t || ''; }
    function updatePath() {
      pathRes = null;
      if (pathMode && selected) {
        pathRes = dhNetPath(block, selected);
        var s = byId[selected];
        if (!pathRes) say('No path from ' + s.label + ' to a target node.');
        else if (pathRes.nodes.length === 1) say(s.label + ' is itself a target.');
        else say('Path to ' + byId[pathRes.nodes[pathRes.nodes.length - 1]].label + ' (' + (pathRes.nodes.length - 1) + ' hop' + (pathRes.nodes.length === 2 ? '' : 's') + '): ' +
                 pathRes.nodes.map(function (id) { return byId[id].label; }).join(' → '));
      } else if (selected) {
        say(byId[selected].label + ' selected. Click the background to clear.');
      } else say('');
    }
    function select(id, el) {
      selected = (selected === id && !pathMode) ? null : id;
      updatePath(); paint();
      var n = byId[id];
      if (selected !== id) return;
      if (n.detail) {
        dhDrawerOpen({ title: n.detail.title || n.label, subtitle: n.detail.subtitle || '', sections: n.detail.sections,
                       tableId: n.linkTableId || '', filter: n.linkFilter || '' }, { opener: el });
      } else if (n.linkTableId) jumpToTable(n.linkTableId, n.linkFilter);
    }
    function centreOn(id) {
      var p = L.pos[id]; if (!p) return;
      var r = innerDiv.getBoundingClientRect(), sc = pz.view.scale;
      pz.view.tx = (r.width || 600) / 2 - (p.x + p.w / 2) * sc;
      pz.view.ty = (r.height || initH) / 2 - (p.y + p.h / 2) * sc;
      pz.zoomAround((r.width || 600) / 2, (r.height || initH) / 2, 1);
    }

    /* ---- events ------------------------------------------------------- */
    svgEl.addEventListener('click', function (e) {
      if (pz.dragged()) return;
      var nodeEl = e.target.closest('.nm-node');
      if (nodeEl) { select(nodeEl.getAttribute('data-id'), nodeEl); return; }
      var edgeEl = e.target.closest('.nm-edge');
      if (edgeEl) {
        var ed = edges[parseInt(edgeEl.getAttribute('data-ei'), 10)];
        if (ed && ed.linkTableId) jumpToTable(ed.linkTableId, ed.linkFilter);
        return;
      }
      if (selected) { selected = null; updatePath(); paint(); }
    });
    svgEl.addEventListener('keydown', function (e) {
      var nodeEl = e.target.closest && e.target.closest('.nm-node');
      if (nodeEl && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); select(nodeEl.getAttribute('data-id'), nodeEl); }
      else if (e.key === 'Escape' && selected) { selected = null; updatePath(); paint(); }
    });
    svgEl.addEventListener('mousemove', function (e) {
      var t = e.target.closest && e.target.closest('[data-tip]');
      if (t && !pz.dragged()) _topoShowTooltip(t.getAttribute('data-tip'), e); else _topoHideTooltip();
    });
    svgEl.addEventListener('mouseleave', _topoHideTooltip);

    tbar.addEventListener('click', function (e) {
      var chip = e.target.closest('.nm-chip');
      if (chip) {
        var f = chip.getAttribute('data-f'), set = f.charAt(0) === 's' ? fStatus : fBadge, key = f.slice(2);
        if (set[key]) delete set[key]; else set[key] = true;
        chip.setAttribute('aria-pressed', set[key] ? 'true' : 'false');
        paint(); return;
      }
      var btn = e.target.closest('[data-nm]'); if (!btn) return;
      var a = btn.getAttribute('data-nm');
      if (a === 'labels') {
        var on = container.classList.toggle('nm-hide-labels');
        btn.setAttribute('aria-pressed', on ? 'false' : 'true');
      } else if (a === 'path') {
        pathMode = !pathMode;
        btn.setAttribute('aria-pressed', pathMode ? 'true' : 'false');
        if (pathMode && !selected) say('Select a node to trace its path to a target.'); else { updatePath(); paint(); }
      } else if (a === 'svg') dhNetDownload(svgEl, L, block);
    });
    var labelsBtn = tbar.querySelector('[data-nm="labels"]');
    if (labelsBtn && edges.length > 400) labelsBtn.setAttribute('aria-pressed', 'false');
    search.addEventListener('input', function () { q = search.value.trim().toLowerCase(); paint(); });
    search.addEventListener('keydown', function (e) {
      if (e.key !== 'Enter') return;
      var hit = nodes.filter(nodeMatches)[0];
      if (hit) centreOn(hit.id);
    });
    paint();
  }

  /* Download the map as a stand-alone SVG: the .nm-* rules and the theme variables
     they use are copied in, because a saved file has no page stylesheet. */
  function dhNetDownload(svgEl, L, block) {
    try {
      var clone = svgEl.cloneNode(true);
      var vpc = clone.querySelector('.nm-viewport');
      if (vpc) vpc.removeAttribute('transform');
      clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
      clone.setAttribute('viewBox', '0 0 ' + L.width + ' ' + L.height);
      clone.setAttribute('width', L.width); clone.setAttribute('height', L.height);
      var css = '', vars = {};
      Array.prototype.forEach.call(document.styleSheets, function (ss) {
        var rules; try { rules = ss.cssRules; } catch (e) { return; }
        Array.prototype.forEach.call(rules || [], function (r) {
          if (r.type === 1 && /\.nm-|\.topo-/.test(r.selectorText) && !/network-map|\.nm-(chip|btn|search|status|sr|legend)/.test(r.selectorText)) css += r.cssText + '\n';
        });
      });
      var cs = getComputedStyle(svgEl), m, rx = /var\((--[\w-]+)/g;
      while ((m = rx.exec(css))) vars[m[1]] = cs.getPropertyValue(m[1]).trim();
      var decl = Object.keys(vars).map(function (k) { return k + ':' + vars[k]; }).join(';');
      var st = document.createElementNS('http://www.w3.org/2000/svg', 'style');
      st.textContent = 'svg{' + decl + ';font-family:' + (cs.fontFamily || 'sans-serif') + '}\n' + css;
      clone.insertBefore(st, clone.firstChild);
      var bg = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
      bg.setAttribute('width', '100%'); bg.setAttribute('height', '100%');
      bg.setAttribute('fill', getComputedStyle(document.body).backgroundColor || '#fff');
      clone.insertBefore(bg, st.nextSibling);
      var blob = new Blob(['<?xml version="1.0" encoding="UTF-8"?>\n' + new XMLSerializer().serializeToString(clone)], { type: 'image/svg+xml' });
      var a = document.createElement('a');
      a.href = URL.createObjectURL(blob); a.download = (block.id || 'network-map') + '.svg';
      document.body.appendChild(a); a.click(); document.body.removeChild(a);
      setTimeout(function () { URL.revokeObjectURL(a.href); }, 1000);
    } catch (e) { /* download is a convenience; never break the page */ }
  }
'@
}
