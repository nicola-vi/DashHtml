function Get-DhJsBlocks {
    # Auto-split fragment of the dashboard runtime JS (see Get-DhJsContent).
    return @'
  /* =========================================================================
     BLOCKS ENGINE — HTML, Collapsible, FilterCardGrid, BarChart, PieChart
     ========================================================================= */

  /* Block types whose renderer already implements its own collapsible chrome
     and therefore must NOT be re-wrapped by the central dispatcher. */
  var _SELF_COLLAPSIBLE = { 'collapsible': true, 'summarystrip': true };

  /* wrapCollapsibleBlock — if block.collapsible is true (and the block type
     does not implement its own chrome), transform the outer block container
     into a collapsible-section, build the toggle / body / inner-content
     structure, and return the inner element + a cloned block with title/icon
     cleared so the inner renderer does not double-render the heading. */
  function wrapCollapsibleBlock(outer, block) {
    if (_SELF_COLLAPSIBLE[block.blockType]) return { container: outer, block: block };
    if (!block.collapsible) return { container: outer, block: block };

    var isOpen = block.defaultOpen !== false;
    var title  = block.title || '';
    var icon   = block.icon  || '';
    var uid    = block.id;

    outer.className = 'collapsible-section block-collapsible';
    var iconHtml = icon ? '<span class="collapsible-icon">'+esc(icon)+'</span> ' : '';
    outer.innerHTML =
      '<div class="collapsible-toggle'+(isOpen?' open':'')+'" id="ctoggle-'+uid+'">'+
        '<div class="collapsible-toggle-left">'+
          '<span class="collapsible-title">'+iconHtml+esc(title)+'</span>'+
        '</div>'+
        '<span class="collapsible-chevron">'+(isOpen?'▾':'▸')+'</span>'+
      '</div>'+
      '<div class="collapsible-body'+(isOpen?' open':'')+'" id="cbody-'+uid+'">'+
        '<div class="collapsible-inner block-collapsible-inner" id="cinner-'+uid+'"></div>'+
      '</div>';

    var toggle = outer.querySelector('#ctoggle-'+uid);
    var body   = outer.querySelector('#cbody-'+uid);
    var chev   = outer.querySelector('.collapsible-chevron');
    toggle.addEventListener('click', function () {
      var open = body.classList.toggle('open');
      toggle.classList.toggle('open', open);
      chev.textContent = open ? '▾' : '▸';
    });

    /* Clone block, strip title + icon so the inner renderer doesn't repeat them */
    var innerBlock = {};
    for (var k in block) { if (Object.prototype.hasOwnProperty.call(block, k)) innerBlock[k] = block[k]; }
    innerBlock.title = '';
    innerBlock.icon  = '';
    return { container: outer.querySelector('#cinner-'+uid), block: innerBlock };
  }

  function renderBlocks() {
    BLOCKS_CONFIG.forEach(function (block) {
      var outer = document.getElementById('block-'+block.id);
      if (!outer) return;
      var w         = wrapCollapsibleBlock(outer, block);
      var container = w.container;
      var b         = w.block;
      switch (b.blockType) {
        case 'html':           renderHtmlBlock(container, b); break;
        case 'collapsible':    renderCollapsible(container, b); break;
        case 'filtercardgrid': renderFilterCardGrid(container, b); break;
        case 'barchart':       renderBarChart(container, b); break;
        case 'piechart':       renderPieChart(container, b); break;
        case 'bullet':         renderBullet(container, b); break;
        case 'linechart':      renderLineChart(container, b); break;
        case 'eventfeed':      renderEventFeed(container, b); break;
        case 'statusgrid':     renderStatusGrid(container, b); break;
        case 'summarystrip':   renderSummaryStrip(container, b); break;
        case 'tabs':           renderTabs(container, b); break;
        case 'heatmap':        renderHeatmap(container, b); break;
        case 'topologymap':    renderTopologyMap(container, b); break;
        case 'rangebar':       renderRangeBar(container, b); break;
        case 'findings':       renderFindings(container, b); break;   /* v2.2.0 */
      }
    });
  }

  /* ── Shared chart helpers (used by standalone PieChart block AND
        the per-table chart attached via Add-DhTable -Charts) ── */
  function chartPalette() {
    var fallbacks = ['#00c8ff','#00e676','#ffc107','#ff4d6a','#a855f7','#f97316','#06b6d4','#84cc16'];
    return ['--chart-1','--chart-2','--chart-3','--chart-4','--chart-5','--chart-6','--chart-7','--chart-8']
      .map(function (v, i) { return cssVar(v, fallbacks[i]); });
  }

  /* buildPieSvg — pure renderer.
       entries : [{label, count, color}], already sorted highest-first
       opts.style       'donut' (default) | 'pie'
       opts.title       chart title shown above the svg
       opts.showTotal   show total in donut hole (default true; ignored when style='pie')
       opts.showLegend  show legend rows below (default true)
       opts.onSliceClick(entry)  optional click handler — slices become clickable
       opts.totalLabel  text above the total (default 'Total')
     Returns a DOM element (.chart-panel). */
  function buildPieSvg(entries, opts) {
    opts = opts || {};
    var panel = document.createElement('div');
    panel.className = 'chart-panel';
    var total = entries.reduce(function (s, e) { return s + (Number(e.count) || 0); }, 0);
    if (!total) {
      panel.innerHTML = (opts.title ? '<div class="chart-title">'+esc(opts.title)+'</div>' : '')+
                        '<div class="chart-body chart-empty">No data</div>';
      return panel;
    }
    var size = 130, cx = 65, cy = 65, r = 56;
    var isPie = (opts.style === 'pie');
    var inner = isPie ? 0 : 30;
    var svgParts = ['<svg width="'+size+'" height="'+size+'" viewBox="0 0 '+size+' '+size+'" aria-hidden="true">'];
    var angle = -Math.PI / 2;
    entries.forEach(function (e, idx) {
      var slice = (e.count / total) * 2 * Math.PI;
      if (slice < 0.001) return;
      var clickAttr = opts.onSliceClick ? ' class="pie-clickable" data-slice-idx="'+idx+'"' : '';
      /* v1.4.2 — native hover tooltip with label / count / percentage */
      var pctTxt = ((e.count / total) * 100).toFixed(1) + '%';
      var titleSvg = '<title>' + esc(e.label) + ': ' + esc(e.count) + ' (' + pctTxt + ')</title>';
      if (e.count === total) {
        svgParts.push('<circle'+clickAttr+' cx="'+cx+'" cy="'+cy+'" r="'+r+'" fill="'+esc(e.color)+'">'+titleSvg+'</circle>');
      } else {
        var x1 = (cx + r*Math.cos(angle)).toFixed(2), y1 = (cy + r*Math.sin(angle)).toFixed(2);
        angle += slice;
        var x2 = (cx + r*Math.cos(angle)).toFixed(2), y2 = (cy + r*Math.sin(angle)).toFixed(2);
        svgParts.push('<path'+clickAttr+' d="M'+cx+','+cy+' L'+x1+','+y1+' A'+r+','+r+' 0 '+(slice>Math.PI?1:0)+',1 '+x2+','+y2+' Z" fill="'+esc(e.color)+'" stroke="var(--bg-surface)" stroke-width="2">'+titleSvg+'</path>');
      }
    });
    if (!isPie) {
      svgParts.push('<circle cx="'+cx+'" cy="'+cy+'" r="'+inner+'" fill="var(--bg-surface)"/>');
      if (opts.showTotal !== false) {
        var totalLabel = opts.totalLabel || 'Total';
        svgParts.push('<text x="'+cx+'" y="'+(cy-5)+'" text-anchor="middle" font-size="11" fill="var(--text-muted)" font-family="var(--font-ui)">'+esc(totalLabel)+'</text>');
        svgParts.push('<text x="'+cx+'" y="'+(cy+11)+'" text-anchor="middle" font-size="15" font-weight="700" fill="var(--text-primary)" font-family="var(--font-ui)">'+total+'</text>');
      }
    }
    svgParts.push('</svg>');

    var legendHtml = '';
    if (opts.showLegend !== false) {
      var rows = entries.map(function (e) {
        var pct = ((e.count / total) * 100).toFixed(0);
        return '<div class="legend-row"><span class="legend-dot" style="background:'+esc(e.color)+'"></span>'+
               '<span class="legend-label">'+esc(e.label)+'</span>'+
               '<span class="legend-count">'+esc(e.count)+' <span class="legend-pct">('+esc(pct)+'%)</span></span></div>';
      }).join('');
      legendHtml = '<div class="chart-legend">'+rows+'</div>';
    }

    panel.innerHTML = (opts.title ? '<div class="chart-title">'+esc(opts.title)+'</div>' : '')+
                      '<div class="chart-body">'+svgParts.join('')+legendHtml+'</div>';

    if (opts.onSliceClick) {
      panel.querySelectorAll('.pie-clickable').forEach(function (el) {
        el.style.cursor = 'pointer';
        el.addEventListener('click', function () {
          var idx = parseInt(el.getAttribute('data-slice-idx'), 10);
          if (entries[idx]) opts.onSliceClick(entries[idx]);
        });
      });
    }
    return panel;
  }

  /* ── Standalone Pie / Donut chart block ───────────────────────────── */
  function renderPieChart(container, block) {
    container.className = 'pie-chart-section';
    var palette = chartPalette();
    var entries = [];

    if (block.mode === 'fromtable') {
      var eng = engines[block.tableId];
      if (!eng) { return; }  /* engine not ready yet; post-engine pass handles this */
      var counts = {};
      eng._getFiltered().forEach(function (row) {
        var v = (row[block.field] != null) ? String(row[block.field]) : '(empty)';
        counts[v] = (counts[v] || 0) + 1;
      });
      entries = Object.keys(counts).map(function (k, i) {
        return { label: k, count: counts[k], color: palette[i % palette.length] };
      }).sort(function (a, b) { return b.count - a.count; });
      if (block.topN > 0 && entries.length > block.topN) {
        entries = entries.slice(0, block.topN);
      }
    } else {
      /* explicit slices */
      entries = (block.slices || []).map(function (s, i) {
        return {
          label: s.label,
          count: Number(s.value) || 0,
          color: s.color || palette[i % palette.length]
        };
      });
    }

    var opts = {
      style:       block.style || 'donut',
      title:       block.title,
      showTotal:   block.showTotal !== false,
      showLegend:  block.showLegend !== false
    };

    if (block.mode === 'fromtable' && block.clickFilters) {
      /* v2.1.3 — routed through the shared helper. The copy that used to live
         here left the clear button hidden and never refreshed linked charts. */
      opts.onSliceClick = function (entry) {
        var eng = engines[block.tableId];
        if (eng) eng.applyTextFilter(entry.label);
      };
    }

    container.innerHTML = '';
    container.appendChild(buildPieSvg(entries, opts));
  }

  /* ── Bullet chart (v1.4 F10) — actual vs target with performance bands ──
        Renders one horizontal row per item: track, RAG-tinted bands, solid
        value bar, optional vertical target marker, and a readout on the right.
        Pure SVG; no library dependency. Re-uses pickThresholdClass + the
        classToAccent / classToAccentBg helpers. */
  function renderBullet(container, block) {
    container.className = 'bullet-chart-section';
    var titleHtml = block.title
      ? '<h3 class="bullet-chart-title">' + esc(block.title) + '</h3>'
      : '';
    var rowsHtml = (block.items || []).map(buildBulletRow).join('');
    container.innerHTML = titleHtml + '<div class="bullet-rows">' + rowsHtml + '</div>';
  }

  function buildBulletRow(item) {
    var v   = Number(item.value);
    var min = (item.min != null) ? Number(item.min) : 0;
    var max = (item.max != null) ? Number(item.max) : 100;
    if (max <= min) max = min + 1;
    var target = (item.target != null && isFinite(Number(item.target))) ? Number(item.target) : null;
    var isMissing = (item.value === null || item.value === undefined || item.value === '' || !isFinite(v));

    /* viewBox: 600 wide × 24 tall. preserveAspectRatio=none lets it stretch
       horizontally with the container while the height stays fixed via CSS. */
    var W = 600, H = 24;
    function scale(x) { return Math.max(0, Math.min(1, (x - min) / (max - min))) * W; }

    /* Performance bands (qualitative ranges) — tinted background segments */
    var bandHtml = '';
    if (item.thresholds && item.thresholds.length) {
      item.thresholds.forEach(function (th) {
        var bMin = (th.min != null) ? th.min : min;
        var bMax = (th.max != null) ? th.max : max;
        var x1 = scale(bMin), x2 = scale(bMax);
        if (x2 - x1 < 0.1) return;
        bandHtml += '<rect x="' + x1.toFixed(2) + '" y="2" width="' + (x2 - x1).toFixed(2) +
                    '" height="' + (H - 4) + '" fill="' + classToAccentBg(th['class'] || '') + '"/>';
      });
    }

    /* Pick the value-bar colour: explicit Class wins; otherwise auto-match
       against the bands; otherwise fall back to a neutral accent. The bullet
       NoData semantics: missing value + ragNoData → cell-nodata fill, 0% width. */
    var matchClass;
    if (isMissing && item.ragNoData) {
      matchClass = 'cell-nodata';
    } else if (item['class']) {
      matchClass = item['class'];
    } else {
      matchClass = pickThresholdClass(v, item.thresholds);
    }
    var fillColor = classToAccent(matchClass);

    var valX = isMissing ? 0 : scale(v);
    var barY = H * 0.30, barH = H * 0.40;
    var valHtml = '<rect x="0" y="' + barY + '" width="' + valX.toFixed(2) +
                  '" height="' + barH + '" fill="' + fillColor + '" rx="2"/>';

    /* Target marker — vertical tick, full row height, drawn over the value bar */
    var tgtHtml = '';
    if (target != null) {
      var tx = scale(target);
      tgtHtml = '<line x1="' + tx.toFixed(2) + '" y1="1" x2="' + tx.toFixed(2) +
                '" y2="' + (H - 1) + '" stroke="var(--text-primary)" stroke-width="2.5"/>';
    }

    /* Track background — keeps the bar visible when there are no bands defined */
    var trackHtml = '<rect x="0" y="2" width="' + W + '" height="' + (H - 4) +
                    '" fill="var(--progress-track-bg)" rx="2"/>';

    var svg = '<svg class="bullet-svg" viewBox="0 0 ' + W + ' ' + H +
              '" preserveAspectRatio="none" aria-hidden="true">' +
              trackHtml + bandHtml + valHtml + tgtHtml + '</svg>';

    /* Right-side readout: value + unit + (target N) */
    var displayVal = isMissing ? '—' : String(item.value);
    var unitHtml = item.unit ? '<span class="bullet-unit">' + esc(item.unit) + '</span>' : '';
    var targetHtml = (target != null)
      ? '<span class="bullet-target-readout">target ' + esc(target) + (item.unit ? ' ' + esc(item.unit) : '') + '</span>'
      : '';

    return '<div class="bullet-row' + (isMissing && item.ragNoData ? ' bullet-nodata' : '') + '">' +
             '<div class="bullet-label">' + esc(item.label) + '</div>' +
             '<div class="bullet-svg-wrap">' + svg + '</div>' +
             '<div class="bullet-readout">' +
               '<span class="bullet-value">' + esc(displayVal) + '</span>' +
               unitHtml + targetHtml +
             '</div>' +
           '</div>';
  }

  /* ── Range-gradient bar chart (v2.1.0) ──
        One floating bar per category spanning min → max, an independently
        positioned avg tick, and a shared 0-100 axis. Every row is normalised
        against its own `high`, so categories of very different magnitude become
        comparable. The fill is a fixed slice of ONE gradient that spans the
        whole track — a bar's colour says WHERE ON THE AXIS it sits, not which
        category it is. Implemented with clip-path against the full-track box so
        all placement is percentage-based and reflows at any width. */

  var RB_TICKS = [0, 20, 40, 60, 80, 100];

  /* Round to at most 2 decimals and drop trailing zeros — these are real,
     un-normalised units and must stay readable. */
  function _rbFmt(v) {
    if (v === null || v === undefined || !isFinite(v)) return '—';
    return String(Math.round(v * 100) / 100);
  }
  function _rbPct(v, low, high) {
    var span = high - low;
    if (!isFinite(span) || span <= 0) return 0;
    return (v - low) / span * 100;
  }
  function _rbClamp(p) { return Math.max(0, Math.min(100, p)); }

  /* Where to re-render a block that is refreshed AFTER renderBlocks() ran - the
     boot pass, and every table filter change. renderBlocks() hands collapsible
     blocks an INNER container and a title-stripped clone; a naive re-render into
     'block-<id>' targets the OUTER element with the original block, which wipes
     the collapsible chrome and prints the title a second time. Resolve the same
     target the first render used.

     Used by every table-derived block that re-renders on filter changes:
     rangebar, barchart, and Mode-A piechart. */
  function blockRenderTarget(block) {
    var inner = document.getElementById('cinner-' + block.id);
    if (!inner) return { container: document.getElementById('block-' + block.id), block: block };
    var b = {};
    for (var k in block) { if (Object.prototype.hasOwnProperty.call(block, k)) b[k] = block[k]; }
    b.title = '';
    b.icon  = '';
    return { container: inner, block: b };
  }

  /* Rows for a block, from either mode. Returns null when the block reads a
     table whose engine is not ready yet. */
  function computeRangeRows(block) {
    if (block.mode !== 'fromtable') return (block.items || []).slice();

    var engine = engines[block.tableId];
    if (!engine) return null;

    var groups = {}, order = [];
    engine._getFiltered().forEach(function (row) {
      var raw = row[block.categoryField];
      var key = (raw !== null && raw !== undefined && String(raw) !== '') ? String(raw) : '(empty)';
      var v = Number(row[block.valueField]);
      if (!isFinite(v)) return;            /* non-numeric rows are skipped, never coerced to 0 */
      if (!groups[key]) {
        groups[key] = { name: key, min: v, max: v, sum: 0, n: 0, high: null, low: null };
        order.push(key);
      }
      var g = groups[key];
      if (v < g.min) g.min = v;
      if (v > g.max) g.max = v;
      g.sum += v; g.n++;
      if (block.highField) {
        var hv = Number(row[block.highField]);
        /* max wins, so an inconsistent capacity column cannot under-scale a bar */
        if (isFinite(hv) && (g.high === null || hv > g.high)) g.high = hv;
      }
      if (block.lowField) {
        var lv = Number(row[block.lowField]);
        if (isFinite(lv) && (g.low === null || lv < g.low)) g.low = lv;
      }
    });

    var globalMax = 0;
    order.forEach(function (k) { if (groups[k].max > globalMax) globalMax = groups[k].max; });

    return order.map(function (k) {
      var g = groups[k], high;
      if (block.highField)                                      high = (g.high !== null) ? g.high : g.max;
      else if (block.high !== null && block.high !== undefined)  high = block.high;
      else                                                      high = globalMax;
      var low = (block.lowField && g.low !== null) ? g.low : (block.low || 0);
      return { name: g.name, low: low, high: high, min: g.min, avg: g.sum / g.n, max: g.max };
    });
  }

  function renderRangeBar(container, block) {
    container.className = 'rangebar-section';
    var titleHtml = block.title ? '<h3 class="rangebar-title">' + esc(block.title) + '</h3>' : '';

    var rows = computeRangeRows(block);
    if (rows === null) { container.innerHTML = titleHtml + '<p class="no-data">Table not ready.</p>'; return; }
    if (!rows.length)  { container.innerHTML = titleHtml + '<div class="rangebar-empty">No data.</div>'; return; }

    var unit     = block.unit || '';
    var unitSfx  = unit ? ' ' + unit : '';
    var firstRow = 3;                                  /* row 1 axis caption, row 2 ticks */
    var nRows    = rows.length;

    var tickHtml = RB_TICKS.map(function (t) {
      return '<span class="rb-axis-tick" style="left:' + t + '%">' + t + '</span>';
    }).join('');
    var gridHtml = RB_TICKS.map(function (t) {
      var edge = (t === 0 || t === 100) ? ' rb-edge' : '';
      return '<i class="' + ('rb-gridline' + edge) + '" style="left:' + t + '%"></i>';
    }).join('');

    var rowsHtml = rows.map(function (d, i) {
      var gr    = firstRow + i;
      var span  = d.high - d.low;
      var bad   = !isFinite(span) || span <= 0;        /* spec §3.2 — undefined normalisation */
      var minP  = bad ? 0 : _rbPct(d.min, d.low, d.high);
      var avgP  = bad ? 0 : _rbPct(d.avg, d.low, d.high);
      var maxP  = bad ? 0 : _rbPct(d.max, d.low, d.high);

      /* Geometry is clamped to the axis so an out-of-scale row clips at the
         edge; the labels and tooltip keep the real numbers (spec §3.2). */
      var cMin = _rbClamp(minP), cMax = _rbClamp(maxP), cAvg = _rbClamp(avgP);

      var barHtml = '';
      if (!bad) {
        /* clip-path percentages resolve against the bar's own box, which IS the
           full track — so this reads off the same percentages as the logical
           position, with no pixel maths. */
        var clip = 'inset(0 ' + (100 - cMax) + '% 0 ' + cMin + '% round 4px)';
        var aria = d.name + ': ' + _rbFmt(d.min) + ' to ' + _rbFmt(d.max) + unitSfx +
                   ', average ' + _rbFmt(d.avg) + unitSfx + ', of ' + _rbFmt(d.high) + unitSfx;
        barHtml = '<div class="rb-bar" tabindex="0" role="img"' +
                  ' aria-label="' + esc(aria) + '"' +
                  ' data-rb="' + i + '" style="clip-path:' + clip + ';-webkit-clip-path:' + clip + '"></div>' +
                  '<div class="rb-avg" style="left:' + cAvg + '%"></div>';
      }

      return '<div class="rb-label" style="grid-row:' + gr + '">' + esc(d.name) + '</div>' +
             '<div class="rb-track' + (bad ? ' rb-track-bad' : '') + '" style="grid-row:' + gr + '">' +
               '<div class="rb-base"></div>' + barHtml +
             '</div>' +
             '<div class="rb-values" style="grid-row:' + gr + '">' +
               '<span class="rb-v-range">' + esc(_rbFmt(d.min)) + '–' + esc(_rbFmt(d.max)) + '</span>' +
               '<span class="rb-v-avg">avg <b>' + esc(_rbFmt(d.avg)) + '</b></span>' +
             '</div>';
    }).join('');

    var tableHtml = '';
    if (block.showDataTable) {
      var body = rows.map(function (d) {
        return '<tr><td>' + esc(d.name) + '</td><td>' + esc(_rbFmt(d.low)) + '</td><td>' + esc(_rbFmt(d.high)) +
               '</td><td>' + esc(_rbFmt(d.min)) + '</td><td>' + esc(_rbFmt(d.avg)) + '</td><td>' +
               esc(_rbFmt(d.max)) + '</td></tr>';
      }).join('');
      tableHtml =
        '<button type="button" class="rb-table-toggle" aria-expanded="false">Show data table</button>' +
        '<div class="rb-data-table"><table hidden>' +
          '<thead><tr><th>Name</th><th>Low</th><th>High</th><th>Min</th><th>Avg</th><th>Max</th></tr></thead>' +
          '<tbody>' + body + '</tbody>' +
        '</table></div>';
    }

    container.innerHTML =
      titleHtml +
      '<div class="rangebar-scroller"><div class="rangebar-plot" style="grid-template-rows:repeat(' + (nRows + 2) + ', auto)">' +
        '<div class="rb-axis-title">' + esc(block.axisLabel || '') + '</div>' +
        '<div class="rb-axis-cell">' + tickHtml + '</div>' +
        '<div class="rb-gridlines" style="grid-row:' + firstRow + ' / span ' + nRows + '">' + gridHtml + '</div>' +
        rowsHtml +
      '</div></div>' +
      '<div class="rangebar-legend">' +
        '<span class="rb-legend-scale"><span>0</span><span class="rb-legend-swatch"></span><span>100</span>' +
          '<span class="rb-legend-note">' + esc(block.axisLabel || '') + '</span></span>' +
        '<span class="rb-legend-avg"><span class="rb-legend-tick"></span>average</span>' +
      '</div>' +
      tableHtml;

    /* Tooltip — reuses the shared body-level overlay (pre-wrap, viewport-clamped) */
    container.querySelectorAll('.rb-bar').forEach(function (bar) {
      var d = rows[parseInt(bar.getAttribute('data-rb'), 10)];
      if (!d) return;
      var minP = _rbPct(d.min, d.low, d.high),
          avgP = _rbPct(d.avg, d.low, d.high),
          maxP = _rbPct(d.max, d.low, d.high);
      var text = d.name + '\n' +
                 'min  ' + _rbFmt(d.min) + unitSfx + '  (' + _rbFmt(minP) + '%)\n' +
                 'avg  ' + _rbFmt(d.avg) + unitSfx + '  (' + _rbFmt(avgP) + '%)\n' +
                 'max  ' + _rbFmt(d.max) + unitSfx + '  (' + _rbFmt(maxP) + '%)\n' +
                 'high ' + _rbFmt(d.high) + unitSfx;
      bar.addEventListener('pointerenter', function (e) { _topoShowTooltip(text, e); });
      bar.addEventListener('pointermove',  function (e) { _topoShowTooltip(text, e); });
      bar.addEventListener('pointerleave', _topoHideTooltip);
      bar.addEventListener('blur',         _topoHideTooltip);
      bar.addEventListener('focus', function () {
        /* getBoundingClientRect returns the UNCLIPPED box, so aim at the middle
           of the visible span instead of the middle of the whole track. */
        var r = bar.getBoundingClientRect();
        var midPct = (_rbClamp(minP) + _rbClamp(maxP)) / 2;
        _topoShowTooltip(text, { clientX: r.left + r.width * midPct / 100, clientY: r.top });
      });
    });

    var toggle = container.querySelector('.rb-table-toggle');
    if (toggle) {
      toggle.addEventListener('click', function () {
        var tbl = container.querySelector('.rb-data-table table');
        if (!tbl) return;
        var hidden = tbl.hasAttribute('hidden');
        if (hidden) { tbl.removeAttribute('hidden'); } else { tbl.setAttribute('hidden', ''); }
        toggle.textContent = hidden ? 'Hide data table' : 'Show data table';
        toggle.setAttribute('aria-expanded', hidden ? 'true' : 'false');
      });
    }
  }

  /* ── Line / Area chart (v1.4 F9) ──
        Pure SVG with axes, multi-series support, optional filled-area variant,
        and an optional dashed target / threshold annotation. Per spec §7.4:
        "Always pair a time-series chart with a threshold annotation line." */
  function renderLineChart(container, block) {
    container.className = 'line-chart-section';
    var title = block.title ? '<h3 class="line-chart-title">'+esc(block.title)+'</h3>' : '';
    var H = (block.height && block.height > 0) ? block.height : 240;
    var W = 800;   /* viewBox width; preserveAspectRatio=none lets it stretch */
    var padL = 46, padR = 14, padT = 14, padB = 28;
    var plotW = W - padL - padR;
    var plotH = H - padT - padB;

    var xLabels = block.xAxis || [];
    var series  = block.series || [];
    var n = xLabels.length;
    if (n < 2 || !series.length) {
      container.innerHTML = title + '<div class="line-chart-empty">No data</div>';
      return;
    }

    /* Y-axis bounds: auto-fit from data, then apply user overrides + a small
       padding above the max so the line never hugs the top edge. */
    var dataMin = Infinity, dataMax = -Infinity;
    series.forEach(function (s) {
      (s.values || []).forEach(function (v) {
        if (v === null || v === undefined) return;
        var num = Number(v);
        if (!isFinite(num)) return;
        if (num < dataMin) dataMin = num;
        if (num > dataMax) dataMax = num;
      });
    });
    if (!isFinite(dataMin) || !isFinite(dataMax)) { dataMin = 0; dataMax = 1; }
    /* Include the target line in the visible range so the annotation isn't clipped */
    if (block.targetLine !== null && block.targetLine !== undefined && isFinite(Number(block.targetLine))) {
      var tl = Number(block.targetLine);
      if (tl < dataMin) dataMin = tl;
      if (tl > dataMax) dataMax = tl;
    }
    var yMin = (block.yAxisMin !== null && block.yAxisMin !== undefined) ? Number(block.yAxisMin) : dataMin;
    var yMax = (block.yAxisMax !== null && block.yAxisMax !== undefined) ? Number(block.yAxisMax) : dataMax;
    /* Pad the auto bounds 5% on each side so the line never touches the frame */
    if (block.yAxisMin === null || block.yAxisMin === undefined) {
      var headroom = (yMax - yMin) * 0.05;
      yMin -= headroom;
    }
    if (block.yAxisMax === null || block.yAxisMax === undefined) {
      var headroom2 = (yMax - yMin) * 0.05;
      yMax += headroom2;
    }
    if (yMax <= yMin) yMax = yMin + 1;   /* defensive */

    function xAt(i) { return padL + (i / (n - 1)) * plotW; }
    function yAt(v) { return padT + (1 - (v - yMin) / (yMax - yMin)) * plotH; }

    /* Y-axis ticks — 5 levels at 0/25/50/75/100% of range */
    var tickCount = 5;
    var unit = block.yAxisUnit || '';
    var gridHtml = '', yTickHtml = '';
    for (var i = 0; i <= tickCount; i++) {
      var t = i / tickCount;
      var yVal = yMin + (1 - t) * (yMax - yMin);
      var yPx = yAt(yVal);
      if (block.showGrid !== false) {
        gridHtml += '<line class="lc-grid" x1="'+padL+'" y1="'+yPx.toFixed(1)+'" x2="'+(W - padR)+'" y2="'+yPx.toFixed(1)+'" stroke="var(--border-subtle)" stroke-width="1"/>';
      }
      var lbl = (Math.abs(yVal) >= 100) ? yVal.toFixed(0) : yVal.toFixed(1).replace(/\.0$/, '');
      yTickHtml += '<text class="lc-y-tick" x="'+(padL - 6)+'" y="'+(yPx + 4).toFixed(1)+'" text-anchor="end" font-size="10" fill="var(--text-muted)">'+esc(lbl + unit)+'</text>';
    }

    /* X-axis tick labels — thin to roughly every Nth so labels never collide */
    var maxXTicks = 10;
    var step = Math.max(1, Math.ceil(n / maxXTicks));
    var xTickHtml = '';
    for (var j = 0; j < n; j++) {
      if (j !== 0 && j !== n - 1 && j % step !== 0) continue;
      var xPx = xAt(j);
      xTickHtml += '<text class="lc-x-tick" x="'+xPx.toFixed(1)+'" y="'+(H - padB + 14)+'" text-anchor="middle" font-size="10" fill="var(--text-muted)">'+esc(String(xLabels[j]))+'</text>';
    }

    /* Series polylines / filled areas */
    var palette = chartPalette();
    var seriesHtml = '';
    var legendRows = [];
    series.forEach(function (s, idx) {
      var color = s.color || (s['class'] ? classToAccent(s['class']) : palette[idx % palette.length]);
      /* Build polyline points; null/NaN entries break the line */
      var segments = [], current = [];
      (s.values || []).forEach(function (v, i) {
        if (v === null || v === undefined || !isFinite(Number(v))) {
          if (current.length > 1) segments.push(current);
          current = [];
        } else {
          current.push(xAt(i).toFixed(1) + ',' + yAt(Number(v)).toFixed(1));
        }
      });
      if (current.length > 1) segments.push(current);
      if (current.length === 1) {
        /* single isolated point — draw a dot */
        var dotXY = current[0].split(',');
        seriesHtml += '<circle cx="'+dotXY[0]+'" cy="'+dotXY[1]+'" r="3" fill="'+esc(color)+'"/>';
      }

      if (block.filled) {
        segments.forEach(function (seg) {
          if (seg.length < 2) return;
          var firstX = seg[0].split(',')[0];
          var lastX  = seg[seg.length - 1].split(',')[0];
          var baseY  = (padT + plotH).toFixed(1);
          var pathD = 'M ' + firstX + ',' + baseY + ' L ' + seg.join(' L ') + ' L ' + lastX + ',' + baseY + ' Z';
          seriesHtml += '<path d="'+pathD+'" fill="'+esc(color)+'" fill-opacity="0.20" stroke="none"/>';
          seriesHtml += '<polyline points="'+seg.join(' ')+'" fill="none" stroke="'+esc(color)+'" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>';
        });
      } else {
        segments.forEach(function (seg) {
          if (seg.length < 2) return;
          seriesHtml += '<polyline points="'+seg.join(' ')+'" fill="none" stroke="'+esc(color)+'" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>';
        });
      }
      legendRows.push('<div class="lc-legend-row"><span class="lc-legend-dot" style="background:'+esc(color)+'"></span><span class="lc-legend-label">'+esc(s.label || '')+'</span></div>');
    });

    /* Target / threshold annotation line (dashed) */
    var targetHtml = '';
    if (block.targetLine !== null && block.targetLine !== undefined && isFinite(Number(block.targetLine))) {
      var tlY = yAt(Number(block.targetLine));
      targetHtml += '<line class="lc-target" x1="'+padL+'" y1="'+tlY.toFixed(1)+'" x2="'+(W - padR)+'" y2="'+tlY.toFixed(1)+'" stroke="var(--cell-warn-fg)" stroke-width="1.5" stroke-dasharray="6 4"/>';
      if (block.targetLabel) {
        targetHtml += '<text class="lc-target-label" x="'+(W - padR - 6)+'" y="'+(tlY - 4).toFixed(1)+'" text-anchor="end" font-size="10" fill="var(--cell-warn-fg)" font-weight="700">'+esc(block.targetLabel)+'</text>';
      }
    }

    /* Plot frame (left + bottom axis lines) */
    var frameHtml =
      '<line x1="'+padL+'" y1="'+padT+'" x2="'+padL+'" y2="'+(H - padB)+'" stroke="var(--border-medium)" stroke-width="1"/>' +
      '<line x1="'+padL+'" y1="'+(H - padB)+'" x2="'+(W - padR)+'" y2="'+(H - padB)+'" stroke="var(--border-medium)" stroke-width="1"/>';

    var svg =
      '<svg class="lc-svg" viewBox="0 0 '+W+' '+H+'" preserveAspectRatio="none" width="100%" height="'+H+'" aria-hidden="true">'+
        gridHtml + frameHtml + seriesHtml + targetHtml + yTickHtml + xTickHtml +
      '</svg>';

    var legendHtml = '';
    if (block.showLegend !== false && legendRows.length) {
      legendHtml = '<div class="lc-legend">' + legendRows.join('') + '</div>';
    }

    container.innerHTML = title + '<div class="lc-body">' + svg + '</div>' + legendHtml;
  }

  /* ── Event Feed (v1.4 F11) — chronological severity-tagged audit trail ──
        Distinct from AlertBanner (which carries a single current condition).
        Sorts events by Timestamp string (descending by default — newest first),
        slices to MaxItems, and optionally groups by Severity or Source. */
  function renderEventFeed(container, block) {
    container.className = 'event-feed-section';
    var titleHtml = block.title ? '<h3 class="event-feed-title">'+esc(block.title)+'</h3>' : '';
    var events = (block.events || []).slice();
    var sortDesc = (block.sortDescending !== false);

    /* Lexicographic sort works for ISO-ish timestamps; for free-form values it
       at least gives a stable order. */
    events.sort(function (a, b) {
      var av = String(a.timestamp||''), bv = String(b.timestamp||'');
      return sortDesc ? bv.localeCompare(av) : av.localeCompare(bv);
    });
    if (block.maxItems > 0 && events.length > block.maxItems) {
      events = events.slice(0, block.maxItems);
    }
    if (!events.length) {
      container.innerHTML = titleHtml + '<div class="event-feed-empty">No events.</div>';
      return;
    }

    /* Default glyph per severity (overridden by event.icon when supplied) */
    var defaultIcon = {
      info:     '·',
      ok:       '✓',
      warning:  '!',
      critical: '✕'
    };
    function rowHtml(ev) {
      var sev = (ev.severity || 'info').toLowerCase();
      var icon = ev.icon ? ev.icon : (defaultIcon[sev] || '·');
      var src  = ev.source ? '<span class="event-source">['+esc(ev.source)+']</span>' : '';
      return '<li class="event-row event-'+sev+'">' +
               '<span class="event-icon">'+esc(icon)+'</span>' +
               '<time class="event-timestamp">'+esc(ev.timestamp)+'</time>' +
               src +
               '<span class="event-message">'+esc(ev.message)+'</span>' +
             '</li>';
    }

    var listHtml = '';
    if (block.groupBy === 'severity' || block.groupBy === 'source') {
      /* Group events; emit one group header + sublist per group */
      var key = block.groupBy;
      var sevOrder = ['critical','warning','ok','info'];
      var groups = {};
      events.forEach(function (ev) {
        var g = ev[key] || '(none)';
        if (!groups[g]) groups[g] = [];
        groups[g].push(ev);
      });
      var orderedKeys;
      if (key === 'severity') {
        /* Pin severities to a fixed priority order so critical floats up */
        orderedKeys = sevOrder.filter(function (k) { return groups[k]; });
        Object.keys(groups).forEach(function (k) {
          if (orderedKeys.indexOf(k) === -1) orderedKeys.push(k);
        });
      } else {
        orderedKeys = Object.keys(groups).sort();
      }
      listHtml = orderedKeys.map(function (k) {
        var rows = groups[k].map(rowHtml).join('');
        return '<div class="event-feed-group event-group-'+esc(k)+'">'+
                 '<div class="event-group-header">'+esc(k)+' <span class="event-group-count">('+groups[k].length+')</span></div>'+
                 '<ul class="event-feed-list">'+rows+'</ul>'+
               '</div>';
      }).join('');
    } else {
      listHtml = '<ul class="event-feed-list">' + events.map(rowHtml).join('') + '</ul>';
    }

    container.innerHTML = titleHtml + listHtml;
  }

  /* ── Heatmap (v1.5) — rows × columns × numeric value with colour scale ──
        Distinct from Status Grid: this is a CONTINUOUS scale (sequential or
        diverging) rather than categorical RAG states. Per spec §2. */

  /* Resolve a CSS variable to an [r,g,b] array by painting an off-screen
     element and reading back the computed colour. Works for any colour
     format the browser understands (named, hex, rgb(), oklch(), etc.). */
  function _resolveCssColor(cssExpr) {
    var probe = document.createElement('div');
    probe.style.color = cssExpr;
    probe.style.display = 'none';
    document.body.appendChild(probe);
    var rgb = getComputedStyle(probe).color;
    document.body.removeChild(probe);
    var m = rgb.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/);
    if (!m) return [128, 128, 128];
    return [+m[1], +m[2], +m[3]];
  }
  function _lerp3(a, b, t) {
    return [
      Math.round(a[0] + (b[0] - a[0]) * t),
      Math.round(a[1] + (b[1] - a[1]) * t),
      Math.round(a[2] + (b[2] - a[2]) * t)
    ];
  }
  function _rgbStr(arr) { return 'rgb(' + arr[0] + ',' + arr[1] + ',' + arr[2] + ')'; }

  function renderHeatmap(container, block) {
    container.className = 'heatmap-section heatmap-size-' + (block.cellSize || 'normal');
    var rows = block.rows || [];
    var cols = block.columns || [];
    var cells = block.cells || [];

    var titleHtml = block.title ? '<h3 class="heatmap-title">'+esc(block.title)+'</h3>' : '';
    if (!rows.length || !cols.length || !cells.length) {
      container.innerHTML = titleHtml + '<div class="heatmap-empty">No data.</div>';
      return;
    }

    /* Sparse lookup */
    var cellMap = {};
    var values  = [];
    cells.forEach(function (c) {
      cellMap[c.row + '\0' + c.column] = c;
      values.push(c.value);
    });

    /* Auto-fit Min/Max from data when user didn't override */
    var lo = (block.min !== null && block.min !== undefined) ? Number(block.min) : Math.min.apply(null, values);
    var hi = (block.max !== null && block.max !== undefined) ? Number(block.max) : Math.max.apply(null, values);
    if (hi <= lo) hi = lo + 1;

    /* Resolve gradient endpoints from theme tokens */
    var scale = (block.colorScale || 'sequential').toLowerCase();
    var loColor, midColor, hiColor;
    if (scale === 'diverging') {
      /* Red → neutral → green; the centre is the midpoint of the data range */
      loColor  = _resolveCssColor('var(--cell-danger-fg)');
      midColor = _resolveCssColor('var(--text-muted)');
      hiColor  = _resolveCssColor('var(--cell-ok-fg)');
    } else {
      /* Sequential single-hue: --bg-row-alt → --accent-primary */
      loColor = _resolveCssColor('var(--bg-row-alt)');
      hiColor = _resolveCssColor('var(--accent-primary)');
    }

    function colourFor(v) {
      if (v === null || v === undefined || !isFinite(v)) return null;
      var t = (v - lo) / (hi - lo);
      if (t < 0) t = 0; else if (t > 1) t = 1;
      if (scale === 'diverging') {
        if (t < 0.5) return _rgbStr(_lerp3(loColor, midColor, t * 2));
        return _rgbStr(_lerp3(midColor, hiColor, (t - 0.5) * 2));
      }
      return _rgbStr(_lerp3(loColor, hiColor, t));
    }

    /* Header row */
    var header = '<div class="hm-corner">' +
      (block.rowLabel    ? '<span class="hm-row-label">'+esc(block.rowLabel)+'</span>'    : '') +
      (block.columnLabel ? '<span class="hm-col-label">'+esc(block.columnLabel)+'</span>' : '') +
      '</div>';
    cols.forEach(function (cn) {
      header += '<div class="hm-col-header" title="'+esc(cn)+'">'+esc(cn)+'</div>';
    });

    /* Body */
    var body = '';
    rows.forEach(function (rn) {
      body += '<div class="hm-row-header" title="'+esc(rn)+'">'+esc(rn)+'</div>';
      cols.forEach(function (cn) {
        var def = cellMap[rn + '\0' + cn];
        if (!def) {
          body += '<div class="hm-cell hm-cell-empty" aria-label="'+esc(rn)+' × '+esc(cn)+': no data"></div>';
          return;
        }
        var col = colourFor(def.value);
        var tipParts = [esc(rn), '×', esc(cn), '—', esc(def.value) + esc(block.unit || '')];
        if (def.tooltip) tipParts.push('('+esc(def.tooltip)+')');
        var styleAttr = col ? ' style="background:'+col+'"' : '';
        var inner = block.showValues ? '<span class="hm-value">'+esc(def.value)+'</span>' : '';
        body += '<div class="hm-cell"'+styleAttr+' title="'+tipParts.join(' ')+'" aria-label="'+esc(rn)+' × '+esc(cn)+': '+esc(def.value)+esc(block.unit||'')+'">'+inner+'</div>';
      });
    });

    /* Inline legend strip */
    var legendStops = [];
    var stops = 5;
    for (var i = 0; i <= stops; i++) {
      var t = i / stops;
      var v = lo + t * (hi - lo);
      var col;
      if (scale === 'diverging') {
        col = (t < 0.5) ? _rgbStr(_lerp3(loColor, midColor, t * 2))
                        : _rgbStr(_lerp3(midColor, hiColor, (t - 0.5) * 2));
      } else {
        col = _rgbStr(_lerp3(loColor, hiColor, t));
      }
      legendStops.push('<div class="hm-legend-stop" style="background:'+col+'" title="'+esc(v.toFixed(1))+esc(block.unit||'')+'"></div>');
    }
    var legend =
      '<div class="heatmap-legend">' +
        '<span class="hm-legend-label">'+esc(lo.toFixed(1))+esc(block.unit||'')+'</span>' +
        '<div class="hm-legend-strip">' + legendStops.join('') + '</div>' +
        '<span class="hm-legend-label">'+esc(hi.toFixed(1))+esc(block.unit||'')+'</span>' +
      '</div>';

    container.innerHTML = titleHtml +
      '<div class="heatmap-inner">' +
        '<div class="heatmap-grid" style="grid-template-columns: auto repeat('+cols.length+', minmax(0, 1fr));">' +
          header + body +
        '</div>' +
      '</div>' +
      legend;
  }

  /* ── Tabs (v1.5) — inline tabbed content block ──
        Local pivot within one block of the dashboard flow. Distinct from
        NavGroup (which partitions the whole page). The tab strip uses ARIA
        role="tablist" + role="tab" + role="tabpanel" for accessibility. */
  function renderTabs(container, block) {
    container.className = 'tabs-section';
    var tabs = block.tabs || [];
    if (!tabs.length) { container.innerHTML = ''; return; }

    var titleHtml = block.title ? '<h3 class="tabs-title">'+esc(block.title)+'</h3>' : '';
    var tabId = function (i) { return 'tab-'+block.id+'-'+i; };
    var panelId = function (i) { return 'tabp-'+block.id+'-'+i; };

    var stripHtml = '<div class="tabs-strip" role="tablist">' +
      tabs.map(function (t, i) {
        var icon = t.icon ? '<span class="tabs-tab-icon">'+esc(t.icon)+'</span>' : '';
        return '<button id="'+tabId(i)+'" type="button" class="tabs-tab'+(t.active?' tab-active':'')+
               '" role="tab" aria-selected="'+(t.active?'true':'false')+
               '" aria-controls="'+panelId(i)+'" data-tabs-idx="'+i+'">' +
               icon + '<span class="tabs-tab-label">'+esc(t.title)+'</span></button>';
      }).join('') +
      '</div>';

    var panelsHtml = tabs.map(function (t, i) {
      return '<div id="'+panelId(i)+'" class="tabs-panel'+(t.active?' panel-active':'')+
             '" role="tabpanel" aria-labelledby="'+tabId(i)+'">' + t.content + '</div>';
    }).join('');

    container.innerHTML = titleHtml + stripHtml + panelsHtml;

    /* Wire click + keyboard activation */
    var tabBtns = container.querySelectorAll('.tabs-tab');
    var panels  = container.querySelectorAll('.tabs-panel');
    function activate(idx) {
      tabBtns.forEach(function (b, j) {
        var on = (j === idx);
        b.classList.toggle('tab-active', on);
        b.setAttribute('aria-selected', on ? 'true' : 'false');
      });
      panels.forEach(function (p, j) {
        p.classList.toggle('panel-active', j === idx);
      });
    }
    tabBtns.forEach(function (b, idx) {
      b.addEventListener('click', function () { activate(idx); });
      b.addEventListener('keydown', function (e) {
        /* Left/Right arrow keys move focus between tabs (W3C tabs pattern) */
        var next = null;
        if (e.key === 'ArrowRight') next = (idx + 1) % tabBtns.length;
        else if (e.key === 'ArrowLeft') next = (idx - 1 + tabBtns.length) % tabBtns.length;
        if (next !== null) {
          e.preventDefault();
          tabBtns[next].focus();
          activate(next);
        }
      });
    });
  }

  /* ── Topology Map (v1.5) — parent/child tree visualisation ──
        Recursive subtree-width counting: each leaf claims one slot of
        (nodeWidth + hGap); each parent occupies the centre of its children's
        combined width. No force-directed layout; no Reingold-Tilford. Good
        enough for the spec's "≲ 50 nodes" target (AD Forest→Domain→DC,
        vCenter→Cluster→Host, etc.). */
  /* v1.5.2 — shared canvas for text measurement (created lazily) */
  var _topoMeasureCanvas = null;
  function _topoMeasureText(txt, fontCss) {
    if (!_topoMeasureCanvas) _topoMeasureCanvas = document.createElement('canvas');
    var ctx = _topoMeasureCanvas.getContext('2d');
    ctx.font = fontCss;
    return ctx.measureText(txt || '').width;
  }

  /* v1.5.2 — shared HTML tooltip overlay for topology nodes. Lives outside the
     SVG (browsers don't honour ::after / ::before on SVG elements) and is
     created on first use. */
  var _topoTooltipEl = null;
  function _topoEnsureTooltip() {
    if (_topoTooltipEl) return _topoTooltipEl;
    _topoTooltipEl = document.createElement('div');
    _topoTooltipEl.className = 'topo-tooltip';
    _topoTooltipEl.setAttribute('role', 'tooltip');
    _topoTooltipEl.style.display = 'none';
    document.body.appendChild(_topoTooltipEl);
    return _topoTooltipEl;
  }
  function _topoShowTooltip(text, evt) {
    if (!text) return;
    var tip = _topoEnsureTooltip();
    tip.textContent = text;
    tip.style.display = 'block';
    /* Position above the cursor, snap inside the viewport */
    var x = evt.clientX + 12;
    var y = evt.clientY + 16;
    var rect = tip.getBoundingClientRect();
    if (x + rect.width  > window.innerWidth)  x = window.innerWidth  - rect.width  - 6;
    if (y + rect.height > window.innerHeight) y = evt.clientY - rect.height - 8;
    tip.style.left = x + 'px';
    tip.style.top  = y + 'px';
  }
  function _topoHideTooltip() {
    if (_topoTooltipEl) _topoTooltipEl.style.display = 'none';
  }

  function renderTopologyMap(container, block) {
    container.className = 'topology-map-section';
    var nodes = block.nodes || [];
    var titleHtml = block.title ? '<h3 class="topology-map-title">'+esc(block.title)+'</h3>' : '';
    if (!nodes.length) {
      container.innerHTML = titleHtml + '<div class="topology-map-empty">No nodes.</div>';
      return;
    }

    /* Build id → node + id → children index */
    var byId = {};
    var childrenOf = {};
    nodes.forEach(function (n) {
      byId[n.id] = n;
      childrenOf[n.id] = [];
    });
    var roots = [];
    nodes.forEach(function (n) {
      if (n.parent && byId[n.parent]) {
        childrenOf[n.parent].push(n);
      } else {
        roots.push(n);
      }
    });

    var NW = block.nodeWidth  || 140;
    var NH = block.nodeHeight || 44;

    /* v1.5.2 — Auto-fit NodeWidth to the widest label across all nodes. */
    if (block.autoFitWidth) {
      var probe = document.createElement('span');
      probe.style.visibility = 'hidden';
      probe.style.position   = 'absolute';
      probe.className        = 'topo-node-body';
      container.appendChild(probe);
      var sampleFont = window.getComputedStyle(probe).font || '600 13px sans-serif';
      container.removeChild(probe);

      var maxFit = block.autoFitMaxWidth || 360;
      var widest = NW;
      nodes.forEach(function (n) {
        var labelW = _topoMeasureText(n.label || '', sampleFont);
        var badgeW = n.badge ? _topoMeasureText(n.badge, sampleFont) + 18 : 0;
        var iconW  = n.icon  ? 22 : 0;
        var gaps   = (iconW ? 6 : 0) + (badgeW ? 6 : 0);
        var needed = 16 + iconW + labelW + badgeW + gaps + 8;
        if (needed > widest) widest = needed;
      });
      NW = Math.min(Math.ceil(widest), maxFit);
    }

    var direction  = (block.direction || 'vertical').toLowerCase();
    var horizontal = (direction === 'horizontal');
    var hGap    = horizontal ? 40 : 24;
    var vGap    = horizontal ? 32 : 56;
    var slotW   = NW + hGap;
    var slotH   = NH + vGap;
    var marginX = 16, marginY = 16;

    /* v1.7.0 — interactive pan/zoom + collapsible subtrees. Default on; pass
       -Interactive:$false to Add-DhTopologyMap for the static scale-to-fit view. */
    var interactive = block.interactive !== false;

    /* Collapse state + child accessors. kidsOf() returns no children for a
       collapsed node, so the layout treats it as a leaf and its descendants
       are neither positioned nor drawn. */
    var collapsed = {};
    var dragMoved = false;   /* set by the pan handler; suppresses the drill click */
    function kidsOf(n)   { return collapsed[n.id] ? [] : childrenOf[n.id]; }
    function isParent(n) { return childrenOf[n.id].length > 0; }

    /* ---- Layout (re-runnable; reads the current collapse state) ---------- */
    function computeLayout() {
      var positioned = {}, maxX = 0, maxY = 0;
      function leafCount(n) {
        var kids = kidsOf(n);
        if (!kids.length) return 1;
        var s = 0; for (var i = 0; i < kids.length; i++) s += leafCount(kids[i]);
        return s;
      }
      function layoutV(n, xOffset, depth) {
        var kids = kidsOf(n), x;
        if (!kids.length) { x = xOffset + (slotW - NW) / 2; }
        else {
          var cursor = xOffset;
          kids.forEach(function (k) { layoutV(k, cursor, depth + 1); cursor += leafCount(k) * slotW; });
          x = (positioned[kids[0].id].x + positioned[kids[kids.length-1].id].x) / 2;
        }
        var y = marginY + depth * slotH;
        positioned[n.id] = { x: x, y: y };
        if (x + NW > maxX) maxX = x + NW;
        if (y + NH > maxY) maxY = y + NH;
      }
      function layoutH(n, yOffset, depth) {
        var kids = kidsOf(n), y;
        if (!kids.length) { y = yOffset + (slotH - NH) / 2; }
        else {
          var cursor = yOffset;
          kids.forEach(function (k) { layoutH(k, cursor, depth + 1); cursor += leafCount(k) * slotH; });
          y = (positioned[kids[0].id].y + positioned[kids[kids.length-1].id].y) / 2;
        }
        var x = marginX + depth * (NW + vGap);
        positioned[n.id] = { x: x, y: y };
        if (x + NW > maxX) maxX = x + NW;
        if (y + NH > maxY) maxY = y + NH;
      }
      if (horizontal) { var yc = marginY; roots.forEach(function (r) { layoutH(r, yc, 0); yc += leafCount(r) * slotH; }); }
      else            { var xc = marginX; roots.forEach(function (r) { layoutV(r, xc, 0); xc += leafCount(r) * slotW; }); }
      return { positioned: positioned, contentW: Math.max(maxX + marginX, 200), contentH: Math.max(maxY + marginY, 100) };
    }

    /* ---- SVG content builder (connectors + nodes + optional toggles) ----- */
    function buildInner(positioned, withToggles) {
      var connectors = '', nodeMarkup = '', toggles = '';

      nodes.forEach(function (n) {
        if (!n.parent || !positioned[n.parent] || !positioned[n.id]) return;
        var p = positioned[n.parent], c = positioned[n.id], px, py, cx, cy, mid;
        if (horizontal) {
          px = p.x + NW; py = p.y + NH / 2; cx = c.x; cy = c.y + NH / 2; mid = (px + cx) / 2;
          connectors += '<path class="topo-link" d="M '+px.toFixed(1)+' '+py.toFixed(1)+
                        ' C '+mid.toFixed(1)+' '+py.toFixed(1)+', '+mid.toFixed(1)+' '+cy.toFixed(1)+', '+
                        cx.toFixed(1)+' '+cy.toFixed(1)+'" fill="none" stroke="var(--border-strong)" stroke-width="1.5"/>';
        } else {
          px = p.x + NW / 2; py = p.y + NH; cx = c.x + NW / 2; cy = c.y; mid = (py + cy) / 2;
          connectors += '<path class="topo-link" d="M '+px.toFixed(1)+' '+py.toFixed(1)+
                        ' C '+px.toFixed(1)+' '+mid.toFixed(1)+', '+cx.toFixed(1)+' '+mid.toFixed(1)+', '+
                        cx.toFixed(1)+' '+cy.toFixed(1)+'" fill="none" stroke="var(--border-strong)" stroke-width="1.5"/>';
        }
      });

      nodes.forEach(function (n) {
        var p = positioned[n.id]; if (!p) return;
        var statusClass = n.status ? ' topo-status-'+n.status : '';
        var clickable   = n.linkTableId ? ' topo-clickable' : '';
        var tipAttr     = n.tooltip ? ' data-tooltip="' + esc(n.tooltip) + '"' : '';
        var dataAttrs = '';
        if (n.linkTableId) {
          dataAttrs += ' data-link-table="' + esc(n.linkTableId) + '"';
          if (n.linkFilter) dataAttrs += ' data-link-filter="' + esc(n.linkFilter) + '"';
        }
        var iconHtml  = n.icon  ? '<span class="topo-node-icon">'+esc(n.icon)+'</span>' : '';
        var badgeHtml = n.badge ? '<span class="topo-node-badge">'+esc(n.badge)+'</span>' : '';
        nodeMarkup +=
          '<g class="topo-node'+statusClass+clickable+'" data-node-id="'+esc(n.id)+'" transform="translate('+p.x.toFixed(1)+','+p.y.toFixed(1)+')"'+dataAttrs+(n.tooltip?' role="img" aria-label="'+esc(n.label)+': '+esc(n.tooltip)+'"':' role="img" aria-label="'+esc(n.label)+'"')+'>'+
            '<rect class="topo-node-rect" x="0" y="0" width="'+NW+'" height="'+NH+'" rx="6" ry="6"'+tipAttr+'/>'+
            '<foreignObject x="0" y="0" width="'+NW+'" height="'+NH+'">'+
              '<div xmlns="http://www.w3.org/1999/xhtml" class="topo-node-body" style="width:'+NW+'px;height:'+NH+'px;">'+
                iconHtml +
                '<span class="topo-node-label" title="'+esc(n.label)+'">'+esc(n.label)+'</span>' +
                badgeHtml +
              '</div>'+
            '</foreignObject>'+
          '</g>';
      });

      if (withToggles) {
        nodes.forEach(function (n) {
          var p = positioned[n.id]; if (!p || !isParent(n)) return;
          var tx = horizontal ? (p.x + NW)     : (p.x + NW / 2);
          var ty = horizontal ? (p.y + NH / 2) : (p.y + NH);
          var isColl = !!collapsed[n.id];
          var sign   = isColl ? '+' : '−';
          toggles += '<g class="topo-toggle'+(isColl?' topo-toggle-collapsed':'')+'" data-toggle-id="'+esc(n.id)+'" '+
                     'transform="translate('+tx.toFixed(1)+','+ty.toFixed(1)+')" role="button" tabindex="0" '+
                     'aria-label="'+(isColl?'Expand':'Collapse')+' '+esc(n.label)+'">'+
                     '<circle class="topo-toggle-bg" r="9"></circle>'+
                     '<text class="topo-toggle-sign" text-anchor="middle" dy="0.32em">'+sign+'</text>'+
                     '</g>';
        });
      }

      return connectors + nodeMarkup + toggles;   /* connectors under, toggles over */
    }

    /* ---- Drill-down + tooltip wiring (re-applied after every redraw) ------ */
    function wireNodes(root) {
      root.querySelectorAll('.topo-clickable').forEach(function (el) {
        el.addEventListener('click', function () {
          if (dragMoved) return;   /* the mousedown→up was a pan, not a click */
          var tableId = el.getAttribute('data-link-table');
          var filter  = el.getAttribute('data-link-filter');
          if (tableId) jumpToTable(tableId, filter);
        });
      });
      root.querySelectorAll('.topo-node').forEach(function (el) {
        var rect = el.querySelector('.topo-node-rect');
        var customTip = rect ? rect.getAttribute('data-tooltip') : '';
        var nid       = el.getAttribute('data-node-id');
        var nodeObj   = nid ? byId[nid] : null;
        var tipText   = customTip || (nodeObj ? (nodeObj.label || '') : '');
        if (!tipText) return;
        el.addEventListener('mouseenter', function (e) { _topoShowTooltip(tipText, e); });
        el.addEventListener('mousemove',  function (e) { _topoShowTooltip(tipText, e); });
        el.addEventListener('mouseleave', _topoHideTooltip);
        el.addEventListener('focusin',    function (e) { _topoShowTooltip(tipText, e); });
        el.addEventListener('focusout',   _topoHideTooltip);
      });
    }

    /* ================= Static mode (pre-1.7.0 behaviour) ================== */
    if (!interactive) {
      var L0    = computeLayout();
      var inner = buildInner(L0.positioned, false);
      var svg   = '<svg class="topology-map-svg" viewBox="0 0 '+L0.contentW+' '+L0.contentH+'" width="100%" height="'+L0.contentH+'" preserveAspectRatio="xMidYMid meet">'+inner+'</svg>';
      container.innerHTML = titleHtml + '<div class="topology-map-inner" style="overflow:auto">' + svg + '</div>';
      wireNodes(container);
      return;
    }

    /* ===================== Interactive mode ============================== */
    var initH = Math.min(Math.max(computeLayout().contentH, 240), 600);
    container.innerHTML = titleHtml +
      '<div class="topology-map-toolbar" role="toolbar" aria-label="Topology view controls">'+
        '<button type="button" class="topo-btn" data-topo-act="zoom-in"  title="Zoom in"    aria-label="Zoom in">+</button>'+
        '<button type="button" class="topo-btn" data-topo-act="zoom-out" title="Zoom out"   aria-label="Zoom out">−</button>'+
        '<button type="button" class="topo-btn" data-topo-act="reset"    title="Reset view" aria-label="Reset view">⤢</button>'+
      '</div>'+
      '<div class="topology-map-inner topo-interactive" style="height:'+initH+'px">'+
        '<svg class="topology-map-svg" width="100%" height="100%">'+
          '<g class="topo-viewport"></g>'+
        '</svg>'+
      '</div>';

    var innerDiv = container.querySelector('.topology-map-inner');
    var svgEl    = container.querySelector('.topology-map-svg');
    var vp       = container.querySelector('.topo-viewport');
    var view     = { scale: 1, tx: 0, ty: 0 };
    var lastLayout = null;

    function viewportSize() {
      var r = innerDiv.getBoundingClientRect();
      return { w: r.width || 600, h: r.height || initH };
    }
    function applyTransform() {
      vp.setAttribute('transform', 'translate('+view.tx.toFixed(2)+','+view.ty.toFixed(2)+') scale('+view.scale.toFixed(4)+')');
    }
    var userInteracted = false;   /* true once the user pans / wheel-zooms; stops auto-fit */
    function fitView() {
      var vs = viewportSize();
      /* Never fit against a not-yet-laid-out container — a ~0 width would latch a
         microscopic scale. Bail; onResize will call again once it has real size. */
      if (vs.w < 40 || vs.h < 40 || !lastLayout) return;
      var s = Math.min(vs.w / lastLayout.contentW, vs.h / lastLayout.contentH, 1);
      if (!isFinite(s) || s <= 0) s = 1;
      view.scale = s;
      view.tx = (vs.w - lastLayout.contentW * s) / 2;
      view.ty = (vs.h - lastLayout.contentH * s) / 2;
      userInteracted = false;     /* a fresh fit hands auto-fit back to the container */
      applyTransform();
    }
    function syncViewBox() {
      var vs = viewportSize();
      svgEl.setAttribute('viewBox', '0 0 '+vs.w+' '+vs.h);
    }
    function zoomAround(cx, cy, factor) {
      var ns = Math.max(0.15, Math.min(4, view.scale * factor));
      view.tx = cx - (cx - view.tx) * (ns / view.scale);
      view.ty = cy - (cy - view.ty) * (ns / view.scale);
      view.scale = ns;
      userInteracted = true;      /* user has taken manual control of the view */
      applyTransform();
    }
    function redraw(refit) {
      lastLayout = computeLayout();
      syncViewBox();
      vp.innerHTML = buildInner(lastLayout.positioned, true);
      wireNodes(vp);
      wireToggles();
      if (refit) fitView(); else applyTransform();
    }
    function wireToggles() {
      vp.querySelectorAll('.topo-toggle').forEach(function (g) {
        function toggle(e) {
          e.stopPropagation();
          e.preventDefault();
          var id = g.getAttribute('data-toggle-id');
          collapsed[id] = !collapsed[id];
          _topoHideTooltip();
          redraw(false);   /* keep the user's current pan / zoom */
        }
        g.addEventListener('click', toggle);
        g.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { toggle(e); } });
      });
    }

    /* Toolbar */
    container.querySelector('.topology-map-toolbar').addEventListener('click', function (e) {
      var btn = e.target.closest('[data-topo-act]'); if (!btn) return;
      var act = btn.getAttribute('data-topo-act');
      if (act === 'reset') { fitView(); return; }
      var vs = viewportSize();
      zoomAround(vs.w / 2, vs.h / 2, act === 'zoom-in' ? 1.25 : 1 / 1.25);
    });

    /* Wheel zoom around the cursor */
    svgEl.addEventListener('wheel', function (e) {
      e.preventDefault();
      var rect = svgEl.getBoundingClientRect();
      zoomAround(e.clientX - rect.left, e.clientY - rect.top, e.deltaY < 0 ? 1.15 : 1 / 1.15);
    }, { passive: false });

    /* Drag to pan. dragMoved gates the node drill click (see wireNodes). */
    var panning = false, sx = 0, sy = 0, otx = 0, oty = 0;
    svgEl.addEventListener('mousedown', function (e) {
      if (e.button !== 0) return;
      panning = true; dragMoved = false;
      sx = e.clientX; sy = e.clientY; otx = view.tx; oty = view.ty;
      innerDiv.classList.add('topo-panning');
    });
    window.addEventListener('mousemove', function (e) {
      if (!panning) return;
      var dx = e.clientX - sx, dy = e.clientY - sy;
      if (Math.abs(dx) > 3 || Math.abs(dy) > 3) { dragMoved = true; userInteracted = true; }
      view.tx = otx + dx; view.ty = oty + dy;
      applyTransform();
    });
    window.addEventListener('mouseup', function () {
      if (!panning) return;
      panning = false;
      innerDiv.classList.remove('topo-panning');
    });

    /* Fit-to-view timing. The container may have zero width when this runs —
       it is often inside a nav panel that is display:none until its tab is
       selected, or simply not laid out yet at DOMContentLoaded. Measuring then
       yields a ~0 width and a microscopic fit scale.

       Rather than fitting exactly once (which would latch onto an early bad
       measurement), we re-fit on every size change UNTIL the user takes manual
       control by panning or zooming. This self-corrects when the container
       finally reaches its real size (hidden panel shown, layout settled) and
       stops interfering the moment the user grabs the view. */
    function onResize() {
      var vs = viewportSize();
      /* < 40px means "not laid out yet" (hidden panel, pre-layout) rather than a
         legitimately narrow column — fitting then yields a microscopic scale. */
      if (vs.w < 40) return;
      syncViewBox();
      if (!userInteracted) fitView();
    }
    if (typeof ResizeObserver !== 'undefined') {
      new ResizeObserver(onResize).observe(innerDiv);
    }
    window.addEventListener('resize', onResize);

    redraw(false);   /* build content now; onResize performs the fit once sized */
    onResize();      /* attempt an immediate fit when the size is already known */
  }

  /* ── Status Grid (v1.4 F5) — rows × columns RAG matrix ──
        2-D grid where every cell carries a Status that maps to the existing
        cell-ok / cell-warn / cell-danger / cell-nodata / cell-info palette.
        Per the IT-infrastructure KPI dashboard specification §2: the canonical
        "Status Matrix / Health Grid" widget.

        Layout:
          ┌──────────┬───────┬───────┬───────┐
          │ rowLabel │ col1  │ col2  │ col3  │   ← header row
          ├──────────┼───────┼───────┼───────┤
          │ rowA     │ ●     │ ●     │ ●     │
          │ rowB     │ ●     │ ●     │ ●     │
          └──────────┴───────┴───────┴───────┘

        Missing cells render as a faint neutral state. Cells with linkTableId
        become clickable, mirroring Add-DhAlertBanner's Action handler. */
  function renderStatusGrid(container, block) {
    container.className = 'status-grid-section status-grid-size-' + (block.cellSize || 'normal');

    var rows = block.rows || [];
    var cols = block.columns || [];
    if (!rows.length || !cols.length) {
      container.innerHTML = (block.title ? '<h3 class="status-grid-title">'+esc(block.title)+'</h3>' : '') +
                            '<div class="status-grid-empty">No axes defined.</div>';
      return;
    }

    /* Build sparse cell lookup: cellMap[row + '\0' + column] = cell-def.
       The NUL separator is chosen because it can't appear in JS object keys
       coming from PS string data. */
    var cellMap = {};
    (block.cells || []).forEach(function (c) {
      cellMap[c.row + '\0' + c.column] = c;
    });

    /* Header row: top-left axis caption, then one column header per column */
    var headerCells = '<div class="sg-corner">' +
      (block.rowLabel ? '<span class="sg-row-label">'+esc(block.rowLabel)+'</span>' : '') +
      (block.columnLabel ? '<span class="sg-col-label">'+esc(block.columnLabel)+'</span>' : '') +
      '</div>';
    cols.forEach(function (cn) {
      headerCells += '<div class="sg-col-header" title="'+esc(cn)+'">'+esc(cn)+'</div>';
    });

    /* Body rows */
    var bodyHtml = '';
    rows.forEach(function (rn) {
      bodyHtml += '<div class="sg-row-header" title="'+esc(rn)+'">'+esc(rn)+'</div>';
      cols.forEach(function (cn) {
        var def = cellMap[rn + '\0' + cn];
        if (!def) {
          bodyHtml += '<div class="sg-cell sg-cell-empty" aria-label="'+esc(rn)+' × '+esc(cn)+': no data"></div>';
        } else {
          var statusClass = 'sg-status-' + (def.status || 'info');
          var clickable   = def.linkTableId ? ' sg-clickable' : '';
          var tipAttr     = def.tooltip
            ? ' title="' + esc(def.tooltip) + '"'
            : ' title="' + esc(rn) + ' × ' + esc(cn) + ': ' + esc(def.status) + '"';
          var dataAttrs   = '';
          if (def.linkTableId) {
            dataAttrs += ' data-link-table="' + esc(def.linkTableId) + '"';
            if (def.linkFilter) dataAttrs += ' data-link-filter="' + esc(def.linkFilter) + '"';
          }
          bodyHtml += '<div class="sg-cell '+statusClass+clickable+'"'+tipAttr+dataAttrs+' role="img" aria-label="'+esc(rn)+' × '+esc(cn)+': '+esc(def.status)+(def.tooltip?'. '+esc(def.tooltip):'')+'"></div>';
        }
      });
    });

    /* CSS Grid template: row-header column + N data columns.
       Width per data column comes from the cellSize variant. */
    var gridHtml =
      '<div class="status-grid-inner">' +
        '<div class="status-grid" style="grid-template-columns: auto repeat('+cols.length+', minmax(0, 1fr));">' +
          headerCells +
          bodyHtml +
        '</div>' +
      '</div>';

    /* Legend strip — auto-generated from the statuses actually present */
    var statusSet = {};
    (block.cells || []).forEach(function (c) { statusSet[c.status || 'info'] = true; });
    var legendOrder = ['ok','warn','danger','nodata','info'];
    var legendItems = legendOrder.filter(function (s) { return statusSet[s]; }).map(function (s) {
      return '<div class="sg-legend-row"><span class="sg-legend-swatch sg-status-'+s+'"></span><span class="sg-legend-label">'+esc(s)+'</span></div>';
    }).join('');
    var legendHtml = legendItems
      ? '<div class="status-grid-legend">'+legendItems+'</div>'
      : '';

    container.innerHTML =
      (block.title ? '<h3 class="status-grid-title">'+esc(block.title)+'</h3>' : '') +
      gridHtml +
      legendHtml;

    /* Wire clickable cells — navigate to a registered table and optionally
       apply a text filter (same machinery as Add-DhAlertBanner Action). */
    container.querySelectorAll('.sg-clickable').forEach(function (el) {
      el.addEventListener('click', function () {
        var tableId = el.getAttribute('data-link-table');
        var filter  = el.getAttribute('data-link-filter');
        if (tableId) jumpToTable(tableId, filter);
      });
    });
  }

  /* ── HTML block ─────────────────────────────────────────────────── */
  function renderHtmlBlock(container, block) {
    container.className = 'html-block html-block-'+block.style;
    var titleHtml = block.title
      ? '<div class="html-block-title">'+(block.icon?'<span class="html-block-icon">'+esc(block.icon)+'</span> ':'')+esc(block.title)+'</div>'
      : '';
    container.innerHTML = titleHtml + '<div class="html-block-content">'+block.content+'</div>';
  }

  /* ── Collapsible section ────────────────────────────────────────── */
  function renderCollapsible(container, block) {
    var isOpen = block.defaultOpen !== false;
    container.className = 'collapsible-section';

    var badge = block.badge ? '<span class="collapsible-badge">'+esc(block.badge)+'</span>' : '';
    var iconHtml = block.icon ? '<span class="collapsible-icon">'+esc(block.icon)+'</span> ' : '';

    container.innerHTML =
      '<div class="collapsible-toggle'+(isOpen?' open':'') +'" id="ctoggle-'+esc(block.id)+'">'+
        '<div class="collapsible-toggle-left">'+
          '<span class="collapsible-title">'+iconHtml+esc(block.title)+'</span>'+badge+
        '</div>'+
        '<span class="collapsible-chevron">'+(isOpen?'▾':'▸')+'</span>'+
      '</div>'+
      '<div class="collapsible-body'+(isOpen?' open':'')+'" id="cbody-'+block.id+'">' +
        '<div class="collapsible-inner" id="cinner-'+block.id+'"></div>'+
      '</div>';

    /* Wire toggle */
    var toggle = container.querySelector('#ctoggle-'+block.id);
    var body   = container.querySelector('#cbody-'+block.id);
    var chevron= container.querySelector('.collapsible-chevron');
    toggle.addEventListener('click', function () {
      var open = body.classList.toggle('open');
      toggle.classList.toggle('open', open);
      chevron.textContent = open ? '▾' : '▸';
    });

    /* Render cards or free content */
    var inner = container.querySelector('#cinner-'+block.id);
    if (block.cards && block.cards.length) {
      var grid = document.createElement('div');
      var widthClass = block.cardWidth && block.cardWidth !== 'normal'
        ? ' coll-width-' + esc(block.cardWidth) : '';
      grid.className = 'collapsible-card-grid' + widthClass;
      block.cards.forEach(function (card) {
        var el = document.createElement('div');
        el.className = 'coll-card';
        var fieldsHtml = (card.fields||[]).map(function(f){
          return '<div class="coll-card-field">'+
            '<span class="coll-card-label">'+esc(f.label)+'</span>'+
            '<span class="coll-card-value'+(f['class']?' '+esc(f['class']):'')+'">'+esc(f.value)+'</span>'+
          '</div>';
        }).join('');
        var badgeHtml = card.badge
          ? '<span class="coll-card-badge'+(card.badgeClass?' '+esc(card.badgeClass):'')+'">'+esc(card.badge)+'</span>'
          : '';
        el.innerHTML = '<div class="coll-card-title">'+esc(card.title)+badgeHtml+'</div>'+fieldsHtml;
        grid.appendChild(el);
      });
      inner.appendChild(grid);
    } else if (block.content) {
      inner.innerHTML = block.content;
    }
  }

  /* ── Filter Card Grid ───────────────────────────────────────────── */
  function renderFilterCardGrid(container, block) {
    container.className = 'filter-card-section';
    container.innerHTML =
      '<h3 class="filter-card-title">'+esc(block.title)+'</h3>'+
      '<div class="filter-card-grid" id="fcgrid-'+block.id+'"></div>'+
      '<div class="filter-status" id="fstatus-'+block.id+'" style="display:none">'+
        '<span class="filter-status-text" id="fstattext-'+block.id+'"></span>'+
        '<button class="clear-filter-btn" id="fclr-'+block.id+'">✕ Clear Filter</button>'+
      '</div>';

    var grid = container.querySelector('#fcgrid-'+block.id);
    var activeValues = [];

    function applyCardFilter() {
      var engine = engines[block.targetTableId];
      if (!engine) return;
      if (activeValues.length === 0) {
        delete cardFilters[block.id];
      } else {
        cardFilters[block.id] = { field: block.filterField, values: activeValues.slice() };
      }
      engine._applyCardFilters();
      var status = container.querySelector('#fstatus-'+block.id);
      var statText = container.querySelector('#fstattext-'+block.id);
      if (activeValues.length) {
        status.style.display = 'flex';
        statText.innerHTML = 'Filtering by <strong>'+esc(block.filterField)+'</strong>: '
          + activeValues.map(function(v){return '<em>'+esc(v)+'</em>';}).join(', ');
      } else {
        status.style.display = 'none';
      }
      URLState.save();
    }

    block.cards.forEach(function (card) {
      var el = document.createElement('div');
      el.className = 'filter-card';
      var countHtml = (block.showCount !== false && card.count !== null && card.count !== undefined)
        ? '<span class="filter-card-count">'+card.count+'</span>' : '';
      el.innerHTML = (card.icon?'<span class="filter-card-icon">'+esc(card.icon)+'</span>':'')+
        '<span class="filter-card-name">'+esc(card.label)+'</span>'+
        (card.subLabel?'<span class="filter-card-sub">'+esc(card.subLabel)+'</span>':'')+
        countHtml;

      el.addEventListener('click', function () {
        var val = card.value;
        var idx = activeValues.indexOf(val);
        if (idx === -1) {
          if (!block.multiFilter) { activeValues = []; grid.querySelectorAll('.filter-card').forEach(function(c){c.classList.remove('active');}); }
          activeValues.push(val);
          el.classList.add('active');
        } else {
          activeValues.splice(idx,1);
          el.classList.remove('active');
        }
        applyCardFilter();
      });
      grid.appendChild(el);
    });

    /* Clear button */
    var clrBtn = container.querySelector('#fclr-'+block.id);
    clrBtn.addEventListener('click', function () {
      activeValues = [];
      grid.querySelectorAll('.filter-card').forEach(function(c){c.classList.remove('active');});
      applyCardFilter();
    });
  }

  /* ── Bar Chart ──────────────────────────────────────────────────── */

  /* v2.2.0 — value aggregation. A bar chart used to COUNT rows per category
     only, so a chart titled "replication lag (min)" drew row counts. With
     block.valueField + block.aggregate it now sums / averages / takes the
     min or max of a numeric column instead. 'count' (the default) is the
     old behaviour, byte for byte. Same semantics as the table footer
     aggregates (_renderFoot): parseFloat, non-numeric values ignored.

     aggregateBars(rows, field, opts) -> { entries, total }
       opts.valueField  numeric column to aggregate ('' = count rows)
       opts.aggregate   'count' (default) | 'sum' | 'avg' | 'min' | 'max'
       opts.topN        keep the N largest (default 10)
       entries : [{label, value, count}] sorted by value, largest first
       total   : what a percentage is a share of — the row count for
                 'count', the sum of every value for 'sum', null otherwise
                 ("percent of total" means nothing for avg / min / max) */
  function aggregateBars(rows, field, opts) {
    opts = opts || {};
    var agg = (opts.aggregate || 'count').toLowerCase();
    var vf  = (agg === 'count') ? '' : (opts.valueField || '');
    var groups = {};
    var grandSum = 0;
    rows.forEach(function (row) {
      var k = (row[field] != null) ? String(row[field]) : '(empty)';
      var g = groups[k];
      if (!g) { g = groups[k] = { count: 0, n: 0, sum: 0, min: Infinity, max: -Infinity }; }
      g.count += 1;
      if (vf) {
        var raw = row[vf];
        var v = (raw === null || raw === undefined || raw === '') ? NaN : parseFloat(raw);
        if (!isNaN(v)) {
          g.n += 1; g.sum += v; grandSum += v;
          if (v < g.min) g.min = v;
          if (v > g.max) g.max = v;
        }
      }
    });
    var entries = [];
    /* Object.keys order, as before 2.2.0: integer-like labels first */
    Object.keys(groups).forEach(function (k) {
      var g = groups[k], val;
      switch (agg) {
        case 'sum': val = g.sum; break;
        case 'avg': val = g.n ? g.sum / g.n : null; break;
        case 'min': val = g.n ? g.min : null; break;
        case 'max': val = g.n ? g.max : null; break;
        default:    val = g.count;
      }
      if (vf && agg !== 'sum' && val === null) return;   /* no numeric value at all in this group */
      entries.push({ label: k, value: val, count: g.count });
    });
    /* stable sort, so equal values keep first-seen order (as before 2.2.0) */
    entries.sort(function (a, b) { return b.value - a.value; });
    entries = entries.slice(0, opts.topN || 10);
    var total = (agg === 'count') ? rows.length : (agg === 'sum' ? grandSum : null);
    return { entries: entries, total: total };
  }

  /* Format an aggregated value for display. Counts print as before. */
  function formatBarValue(v, opts) {
    var agg = (opts.aggregate || 'count').toLowerCase();
    if (agg === 'count') return String(v);
    var d = (opts.decimals !== undefined && opts.decimals >= 0) ? opts.decimals : null;
    var nf = (d !== null)
      ? { minimumFractionDigits: d, maximumFractionDigits: d }
      : { maximumFractionDigits: (agg === 'avg' ? 2 : 3) };
    var txt;
    try { txt = new Intl.NumberFormat(undefined, nf).format(v); } catch (e) { txt = String(v); }
    return opts.unit ? txt + ' ' + opts.unit : txt;
  }

  /* buildBarHtml — pure renderer, the bar counterpart of buildPieSvg.
       entries : from aggregateBars
       opts    : { total, aggregate, unit, decimals, showCount, showPercent, clickable }
     Returns the .bar-item markup (no wrapper, no title). Listeners are the
     caller's job, bound after the markup is written. */
  function buildBarHtml(entries, opts) {
    opts = opts || {};
    var maxVal = 0;
    entries.forEach(function (e) { if (e.value > maxVal) maxVal = e.value; });
    if (!maxVal) maxVal = 1;
    /* v2.1.3 — the click affordance is a fixed pair of attributes; the label
       never reaches an event-handler attribute (see renderBarChart). */
    var clickAttr = opts.clickable ? ' role="button" tabindex="0"' : '';
    var hasPct = (opts.total !== null && opts.total !== undefined);
    return entries.map(function (e) {
      var pct = (Math.max(e.value, 0) / maxVal * 100).toFixed(1);
      var shown = formatBarValue(e.value, opts);
      var pctTotal = hasPct ? (opts.total ? (e.value / opts.total * 100) : 0).toFixed(0) : null;
      /* v1.4.2 — native hover tooltip with label / value / percentage */
      var tip = e.label + ': ' + shown + (pctTotal !== null ? ' (' + pctTotal + '%)' : '');
      return '<div class="bar-item'+(opts.clickable?' bar-clickable':'')+'"'+clickAttr+' title="'+esc(tip)+'">'+
        '<div class="bar-label">'+
          '<span class="bar-label-text">'+esc(e.label)+'</span>'+
          (opts.showCount!==false?'<span class="bar-label-count">'+esc(shown)+'</span>':'')+
          (opts.showPercent && pctTotal !== null?'<span class="bar-label-pct">'+esc(pctTotal)+'%</span>':'')+
        '</div>'+
        '<div class="bar-track"><div class="bar-fill" style="width:'+pct+'%"></div></div>'+
      '</div>';
    }).join('');
  }

  /* Bind click + Enter/Space on rendered bars. */
  function bindBarClicks(container, entries, onPick) {
    var barEls = container.querySelectorAll('.bar-item');
    for (var bi = 0; bi < barEls.length && bi < entries.length; bi++) {
      (function (el, label) {
        function applyBar() { onPick(label); }
        el.addEventListener('click', applyBar);
        el.addEventListener('keydown', function (ev) {
          if (ev.key === 'Enter' || ev.key === ' ') { ev.preventDefault(); applyBar(); }
        });
      })(barEls[bi], entries[bi].label);
    }
  }

  function renderBarChart(container, block) {
    container.className = 'bar-chart-section';
    /* Aggregate from engine data */
    var engine = engines[block.tableId];
    if (!engine) { container.innerHTML = '<p class="no-data">Table not ready.</p>'; return; }

    /* v1.4 F12 — stacked branch */
    if (block.stacked && block.seriesField) {
      renderBarChartStacked(container, block, engine);
      return;
    }

    var opts = { valueField: block.valueField, aggregate: block.aggregate, topN: block.topN,
                 unit: block.unit, decimals: block.decimals,
                 showCount: block.showCount, showPercent: block.showPercent, clickable: !!block.clickFilters };
    var agg = aggregateBars(engine._getFiltered(), block.field, opts);
    opts.total = agg.total;

    container.innerHTML =
      (block.title ? '<h3 class="bar-chart-title">'+esc(block.title)+'</h3>' : '')+
      '<div class="bar-chart">'+buildBarHtml(agg.entries, opts)+'</div>';

    /* Bind AFTER the innerHTML assignment — the elements do not exist before
       it. renderBarChart is re-entered by _refreshLinkedBarCharts on every
       filter change, which replaces these nodes wholesale, so no listener
       accumulates across renders. v2.1.3: never an inline onclick — it ran in
       global scope where `engines` is invisible, and splicing the label into
       an attribute was an injection sink. Closing over the value fixes both. */
    if (block.clickFilters) {
      bindBarClicks(container, agg.entries, function (label) { engine.applyTextFilter(label); });
    }
  }

  /* Stacked variant — each primary bar is segmented by block.seriesField.
     Series values are coloured from chartPalette() in alphabetical order so
     the legend stays stable across renders. clickFilters is intentionally
     ignored in stacked mode (the bar has no single Field value to filter by).
     v2.2.0 — with valueField + aggregate 'sum' the segments add up values
     instead of rows (Add-DhBarChart allows only count / sum when stacked). */
  function renderBarChartStacked(container, block, engine) {
    var useSum = (String(block.aggregate || 'count').toLowerCase() === 'sum') && !!block.valueField;
    var fmtOpts = { aggregate: useSum ? 'sum' : 'count', unit: block.unit, decimals: block.decimals };
    /* Two-level aggregation: primary[field][series] = count (or sum) */
    var primary = {};
    var seriesSet = {};
    var grandTotal = 0;
    engine._getFiltered().forEach(function (row) {
      var pv = (row[block.field]      != null) ? String(row[block.field])      : '(empty)';
      var sv = (row[block.seriesField] != null) ? String(row[block.seriesField]) : '(empty)';
      var w = 1;
      if (useSum) {
        var raw = row[block.valueField];
        w = (raw === null || raw === undefined || raw === '') ? NaN : parseFloat(raw);
        if (isNaN(w)) return;
      }
      if (!primary[pv]) primary[pv] = { total: 0, byS: {} };
      primary[pv].total += w;
      primary[pv].byS[sv] = (primary[pv].byS[sv] || 0) + w;
      seriesSet[sv] = true;
      grandTotal += w;
    });
    var seriesValues = Object.keys(seriesSet).sort();
    var primaryEntries = Object.keys(primary).map(function (k) {
      return { label: k, total: primary[k].total, byS: primary[k].byS };
    }).sort(function (a, b) { return b.total - a.total; }).slice(0, block.topN || 10);

    /* Largest total drives the bar width scale */
    var maxTotal = primaryEntries[0] ? primaryEntries[0].total : 1;
    if (!maxTotal) maxTotal = 1;

    /* Colour map: deterministic alphabetic series → palette index */
    var palette = chartPalette();
    var colorOf = {};
    seriesValues.forEach(function (sv, i) { colorOf[sv] = palette[i % palette.length]; });

    var barsHtml = primaryEntries.map(function (p) {
      var widthPct = (Math.max(p.total, 0) / maxTotal * 100).toFixed(2);
      var pctTotal = (grandTotal ? (p.total / grandTotal * 100) : 0).toFixed(0);
      /* Segments — each is sized in proportion to its share of THIS bar's total */
      var segHtml = seriesValues.map(function (sv) {
        var c = p.byS[sv] || 0;
        if (c === 0) return '';
        var segPct = (p.total ? (c / p.total * 100) : 0).toFixed(2);
        var tip = sv + ': ' + formatBarValue(c, fmtOpts);
        return '<div class="bar-segment" style="width:'+segPct+'%;background:'+esc(colorOf[sv])+'" title="'+esc(tip)+'"></div>';
      }).join('');
      return '<div class="bar-item bar-item-stacked">'+
        '<div class="bar-label">'+
          '<span class="bar-label-text" title="'+esc(p.label)+'">'+esc(p.label)+'</span>'+
          (block.showCount  !== false ? '<span class="bar-label-count">'+esc(formatBarValue(p.total, fmtOpts))+'</span>' : '')+
          (block.showPercent          ? '<span class="bar-label-pct">'+esc(pctTotal)+'%</span>' : '')+
        '</div>'+
        '<div class="bar-track bar-track-stacked" style="width:'+widthPct+'%">'+segHtml+'</div>'+
      '</div>';
    }).join('');

    var legendHtml = '<div class="bar-chart-legend">' +
      seriesValues.map(function (sv) {
        return '<div class="bar-legend-row">'+
                 '<span class="bar-legend-dot" style="background:'+esc(colorOf[sv])+'"></span>'+
                 '<span class="bar-legend-label">'+esc(sv)+'</span>'+
               '</div>';
      }).join('') + '</div>';

    container.innerHTML =
      (block.title ? '<h3 class="bar-chart-title">'+esc(block.title)+'</h3>' : '')+
      '<div class="bar-chart bar-chart-stacked">'+barsHtml+'</div>'+
      legendHtml;
  }

  /* ── Findings (v2.2.0, Add-DhFindings) ──────────────────────────────
     A severity counter strip that filters, a text filter, optional group
     headers, and one expandable row per finding. Every string goes through
     esc(); reference URLs were validated in PowerShell and are checked
     again here, so a hand-edited BLOCKS_CONFIG cannot inject a javascript:
     link. "Show in table" goes through jumpToTable. */
  var FINDING_SEV = {
    critical: { label: 'Critical', rank: 0 },
    warning:  { label: 'Warning',  rank: 1 },
    info:     { label: 'Info',     rank: 2 },
    ok:       { label: 'OK',       rank: 3 }
  };
  var FINDING_URL_OK = /^(https?:|mailto:|tel:|#)/i;

  function renderFindings(container, block) {
    container.className = 'findings-section';
    var list = block.findings || [];
    var expand = {};
    (block.expandSeverity || []).forEach(function (s) { expand[s] = true; });
    var maxShown = (block.maxAffectedShown >= 0) ? block.maxAffectedShown : 20;
    var uid = 'fnd-' + block.id;

    /* counters */
    var counts = { critical: 0, warning: 0, info: 0, ok: 0 };
    list.forEach(function (f) { if (counts[f.severity] !== undefined) counts[f.severity]++; });

    function bodyHtml(f, i) {
      var h = '';
      if (f.description)    h += '<div class="finding-section"><div class="finding-label">Description</div><p>'+esc(f.description)+'</p></div>';
      if (f.recommendation) h += '<div class="finding-section"><div class="finding-label">Recommendation</div><p>'+esc(f.recommendation)+'</p></div>';
      var aff = f.affected || [];
      if (aff.length || f.affectedCount) {
        var shown = aff.slice(0, maxShown);
        var more  = Math.max((f.affectedCount || aff.length) - shown.length, 0);
        h += '<div class="finding-section"><div class="finding-label">Affected ('+esc(f.affectedCount || aff.length)+')</div>';
        if (shown.length) {
          h += '<ul class="finding-affected">'+shown.map(function (a) { return '<li>'+esc(a)+'</li>'; }).join('')+
               (more ? '<li class="finding-more">+'+esc(more)+' more</li>' : '')+'</ul>';
        }
        h += '</div>';
      }
      var links = '';
      if (f.affectedTableId) {
        links += '<button type="button" class="finding-jump" data-fi="'+i+'">Show in table &#8594;</button>';
      }
      (f.references || []).forEach(function (r) {
        if (FINDING_URL_OK.test(String(r.url || ''))) {
          links += '<a class="finding-ref" href="'+esc(r.url)+'" target="_blank" rel="noopener noreferrer">'+esc(r.label || r.url)+'</a>';
        } else {
          links += '<span class="finding-ref finding-ref-blocked">'+esc(r.label || r.url)+'</span>';
        }
      });
      if (links) h += '<div class="finding-links">'+links+'</div>';
      return h || '<p class="finding-empty">No further detail.</p>';
    }

    function rowHtml(f, i) {
      var sev = FINDING_SEV[f.severity] ? f.severity : 'info';
      var open = !!expand[sev];
      var fid = uid + '-' + i;
      return '<div class="finding finding-'+sev+(open?' open':'')+'" data-fi="'+i+'" data-sev="'+sev+'" id="'+esc(fid)+'" data-finding-id="'+esc(f.id)+'">'+
        '<button type="button" class="finding-head" aria-expanded="'+(open?'true':'false')+'" aria-controls="'+esc(fid)+'-body">'+
          '<span class="finding-badge finding-badge-'+sev+'">'+esc(FINDING_SEV[sev].label)+'</span>'+
          '<span class="finding-title">'+esc(f.title)+'</span>'+
          (f.area ? '<span class="finding-area">'+esc(f.area)+'</span>' : '')+
          ((f.affectedCount || (f.affected||[]).length) ? '<span class="finding-count" title="Affected objects">'+esc(f.affectedCount || f.affected.length)+'</span>' : '')+
          '<span class="finding-chevron" aria-hidden="true">'+(open?'&#9662;':'&#9656;')+'</span>'+
        '</button>'+
        '<div class="finding-body" id="'+esc(fid)+'-body"'+(open?'':' hidden')+'>'+bodyHtml(f, i)+'</div>'+
      '</div>';
    }

    /* list markup, with optional group headers */
    var groupBy = block.groupBy || 'none';
    var rows = '';
    if (groupBy === 'area' || groupBy === 'severity') {
      var groups = {}, order = [];
      list.forEach(function (f, i) {
        var k = groupBy === 'area' ? (f.area || 'Other') : (FINDING_SEV[f.severity] ? FINDING_SEV[f.severity].label : f.severity);
        if (!groups[k]) { groups[k] = []; order.push(k); }
        groups[k].push(i);
      });
      order.forEach(function (k) {
        rows += '<div class="findings-group" data-group="'+esc(k)+'"><div class="findings-group-header">'+esc(k)+
                ' <span class="findings-group-count">'+groups[k].length+'</span></div>'+
                groups[k].map(function (i) { return rowHtml(list[i], i); }).join('')+'</div>';
      });
    } else {
      rows = list.map(rowHtml).join('');
    }

    var counters = '';
    if (block.showCounters !== false) {
      counters = '<div class="findings-counters" role="group" aria-label="Show severity">'+
        ['critical','warning','info','ok'].filter(function (s) { return counts[s] > 0; }).map(function (s) {
          return '<button type="button" class="findings-chip findings-chip-'+s+'" data-sev="'+s+'" aria-pressed="false">'+
                 '<span class="findings-chip-count">'+counts[s]+'</span> '+esc(FINDING_SEV[s].label)+'</button>';
        }).join('')+'</div>';
    }
    var filterBox = (block.filterable !== false)
      ? '<input type="search" class="findings-filter" placeholder="Filter findings&#8230;" aria-label="Filter findings">'
      : '';

    container.innerHTML =
      (block.title ? '<h3 class="findings-title">'+esc(block.title)+'</h3>' : '')+
      ((counters || filterBox) ? '<div class="findings-toolbar">'+counters+filterBox+'</div>' : '')+
      (list.length
        ? '<div class="findings-list">'+rows+'</div><p class="findings-none" hidden>No findings match the filter.</p>'
        : '<p class="findings-none">No findings.</p>');

    /* expand / collapse */
    function setOpen(el, open) {
      el.classList.toggle('open', open);
      var head = el.querySelector('.finding-head'), body = el.querySelector('.finding-body');
      if (head) head.setAttribute('aria-expanded', open ? 'true' : 'false');
      if (body) { if (open) body.removeAttribute('hidden'); else body.setAttribute('hidden', ''); }
      var chev = el.querySelector('.finding-chevron');
      if (chev) chev.innerHTML = open ? '&#9662;' : '&#9656;';
    }
    container.querySelectorAll('.finding-head').forEach(function (head) {
      head.addEventListener('click', function () {
        var el = head.parentNode;
        setOpen(el, !el.classList.contains('open'));
      });
    });
    container.querySelectorAll('.finding-jump').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var f = list[parseInt(btn.getAttribute('data-fi'), 10)];
        if (f) jumpToTable(f.affectedTableId, f.affectedFilter);
      });
    });

    /* filtering: severity chips (none pressed = all) AND text */
    var activeSev = {};
    var input = container.querySelector('.findings-filter');
    function haystack(f) {
      return [f.title, f.area, f.description, f.recommendation, (f.affected || []).join(' '), f.severity]
        .join('\n').toLowerCase();
    }
    var hay = list.map(haystack);
    function applyFilter() {
      var term = input ? input.value.trim().toLowerCase() : '';
      var anySev = Object.keys(activeSev).length > 0;
      var visible = 0;
      container.querySelectorAll('.finding').forEach(function (el) {
        var i = parseInt(el.getAttribute('data-fi'), 10);
        var ok = (!anySev || activeSev[el.getAttribute('data-sev')]) && (!term || hay[i].indexOf(term) !== -1);
        el.hidden = !ok;
        if (ok) visible++;
      });
      container.querySelectorAll('.findings-group').forEach(function (g) {
        g.hidden = !g.querySelector('.finding:not([hidden])');
      });
      var none = container.querySelector('.findings-none');
      if (none && list.length) none.hidden = visible > 0;
    }
    container.querySelectorAll('.findings-chip').forEach(function (chip) {
      chip.addEventListener('click', function () {
        var s = chip.getAttribute('data-sev');
        if (activeSev[s]) delete activeSev[s]; else activeSev[s] = true;
        chip.setAttribute('aria-pressed', activeSev[s] ? 'true' : 'false');
        applyFilter();
      });
    });
    if (input) input.addEventListener('input', applyFilter);

    /* for print and search: open one finding by its stable id */
    container._dhOpenFinding = function (findingId) {
      var el = container.querySelector('.finding[data-finding-id="'+String(findingId).replace(/["\\]/g, '')+'"]');
      if (el) { setOpen(el, true); if (el.scrollIntoView) el.scrollIntoView({ block: 'center' }); }
      return !!el;
    };
  }

'@
}
