function Get-DhJsTable {
    # Auto-split fragment of the dashboard runtime JS (see Get-DhJsContent).
    return @'
  /* =========================================================================
     TABLE ENGINE
     ========================================================================= */
  /* Footer aggregate of the numbers in a column. `rowCount` feeds 'count'. null = nothing to show. */
  function dhAggregate(agg, nums, rowCount) {
    switch (agg) {
      case 'sum':   return nums.reduce(function(a,b){return a+b;}, 0);
      case 'avg':   return nums.length ? nums.reduce(function(a,b){return a+b;},0)/nums.length : null;
      case 'min':   return nums.length ? Math.min.apply(null, nums) : null;
      case 'max':   return nums.length ? Math.max.apply(null, nums) : null;
      case 'count': return rowCount;
    }
    return null;
  }

  /* Footer cell text. An unformatted column would show 37.333333333: round to Decimals (default 2). */
  function dhFootText(col, result) {
    var plain = !col.format || String(col.format).toLowerCase() === 'text';
    return (plain && typeof result === 'number' && isFinite(result) && result % 1 !== 0)
      ? result.toFixed(col.decimals >= 0 ? col.decimals : 2)
      : (FMT.apply(col, result) || String(result));
  }

  /* v2.5.2 baseline markers (Add-DhTable -Baseline): pure helpers */
  function dhBaselineNote(b) {
    return 'vs ' + b.label + ': +' + b['new'] + ' new, ~' + b.changed + ' changed, \u2212' + b.removed + ' removed';
  }
  /* filter: '' (all) | 'n' (new) | 'c' (changed); state is the row's entry in baseline.changes, or undefined */
  function dhChangeKeep(state, filter) { return !filter || (!!state && state.s === filter); }
  /* Text of a cell as the reader sees it, without the New / Changed tag (copy cell). */
  function dhCellText(td) {
    var c = td.cloneNode(true);
    var tags = c.querySelectorAll('.chg-tag');
    for (var i = 0; i < tags.length; i++) tags[i].parentNode.removeChild(tags[i]);
    return (c.textContent || '').trim();
  }
  /* CSV formula guard: a spreadsheet evaluates a cell that starts with = + - @ (or a tab / CR), so such
     text gets a leading apostrophe. Numbers such as -5 or +1.5 are left alone. */
  function dhCsvSafe(v) {
    var s = (v === null || v === undefined) ? '' : String(v);
    if (/^[=+\-@\t\r]/.test(s) && !(s.trim() !== '' && isFinite(Number(s)))) return "'" + s;
    return s;
  }
  function dhWasText(col, was, fmtApply) {
    return 'was: ' + ((was === null || was === undefined || was === '') ? '(empty)' : (fmtApply(col, was) || String(was)));
  }

  function TableEngine(cfg) {
    this.id          = cfg.id;
    this.title       = cfg.title||cfg.id;
    this.allData     = cfg.data.slice();
    /* v2.1.4 — row -> position in allData, built once. Every row render used
       to call allData.indexOf(row), a linear scan per row: O(n^2) per render
       on a large page or virtual window. allData is never reordered. */
    this._rowIdx     = new Map();
    for (var ri = 0; ri < this.allData.length; ri++) this._rowIdx.set(this.allData[ri], ri);
    this.columns     = cfg.columns;
    this.pageSize    = cfg.pageSize||15;
    this.multiSelect = cfg.multiSelect||false;
    this.filterable  = cfg.filterable!==false;
    this.pageable    = cfg.pageable!==false;
    this.outLinks    = cfg.outLinks||[];
    this.charts      = cfg.charts||[];
    this.detail      = cfg.detail||null;    /* v2.3.0 - row detail drawer (Add-DhTable -DetailDrawer) */
    /* v2.5.2 - baseline markers: row object -> {s:'n'|'c', f:[fields], w:{old values}}; changeFilter '' | 'n' | 'c' */
    this.base        = cfg.baseline||null;
    this.changeFilter = '';
    this._includeRemoved = false;
    this._baseState  = new Map();
    if (this.base) {
      for (var bk in this.base.changes) {
        if (Object.prototype.hasOwnProperty.call(this.base.changes, bk) && this.allData[+bk]) this._baseState.set(this.allData[+bk], this.base.changes[bk]);
      }
    }

    this.currentPage   = 1;
    this.sortFields    = [];   /* [{field, dir}] — multi-sort */
    this.filterText    = '';
    this.linkedFilter  = null;
    this.pathFilter    = null;   /* v2.4.0 - set only through setPathFilter (Add-DhTreeFilter) */
    this.selected      = [];
    this.colVisible    = {};
    /* v2.5.0 - a column with Hidden starts unticked in the picker; -RememberColumns restores the reader's own choice */
    this.columns.forEach(function(col,i){this.colVisible[i]=!col.hidden;},this);
    this.rememberKey   = cfg.remember||'';
    this._restoreCols();
    /* Per-field width overrides set by dragging a header edge. Empty until the
       user resizes something; the declared col.width stays the default. */
    this.colWidths     = {};
    /* v2.4.0 - measured column widths (Add-DhTable -ColumnFit Auto, the default).
       Precedence: dragged width, then the author's Width, then this. */
    this.columnFit     = (cfg.columnFit === 'fixed') ? 'fixed' : 'auto';
    this.columnMax     = cfg.columnMax || 800;
    this._fitW         = null;

    this.exportFileName = cfg.exportFileName || cfg.id;
    /* v2.3.0 - AllClearText: an empty check shows a check mark instead of an empty grid */
    if(cfg.allClear && !this.allData.length){
      var acSec=document.getElementById('section-'+cfg.id);
      var acBar=acSec&&acSec.querySelector('.table-toolbar');
      if(acBar){
        acSec.classList.add('table-allclear');
        var acCard=document.createElement('div'); acCard.className='table-allclear-card';
        acCard.innerHTML=allClearHtml(cfg.allClear);
        acBar.parentNode.insertBefore(acCard,acBar);
      }
    }
    /* v2.6.0 - New-DhDashboard -LinkState: sort, page size and Change chip from the address before the first render */
    this.linkState  = !!cfg.linkState;
    this._pageSize0 = this.pageSize;
    this._pendingPage = 0;
    this._restoreLinkState();
    this._initPageSizes();
    this._bindFilter();
    this._bindClearSel();
    this._bindLinkClear();
    this._bindExport();
    this._buildColToggle();
    this._renderCharts();
    this._bindRightClick();
    this._buildChangeBar();
    this.render();
  }

  /* ── Table state in the address (v2.6.0, New-DhDashboard -LinkState) ──
     Only what differs from the default is written: s = [[field, 'asc'|'desc'], ...], p = page (> 1),
     z = page size (when changed), c = Change chip ('n' | 'c'). The text filter is already kept under
     "filters". Reading is defensive: unknown or unsortable columns, odd page sizes and other keys are
     ignored, and a page past the end is clamped once every filter has been restored. */
  var DH_LS_CAP = 1500, dhLsSeq = 0;
  var DH_PAGE_SIZES = [5, 10, 15, 25, 50, 100];
  function dhTableStateGet(eng) {
    var st = {};
    if (eng.sortFields.length) st.s = eng.sortFields.map(function (sf) { return [sf.field, sf.dir]; });
    if (eng.pageable && eng.currentPage > 1) st.p = eng.currentPage;
    if (eng.pageSize !== eng._pageSize0) st.z = eng.pageSize;
    if (eng.changeFilter) st.c = eng.changeFilter;
    return Object.keys(st).length ? st : null;
  }
  function dhTableStateSet(eng, st) {
    if (!st || typeof st !== 'object') return;
    var sortable = Object.create(null);
    eng.columns.forEach(function (c) { if (c.sortable !== false) sortable[c.field] = true; });
    if (Array.isArray(st.s)) {
      var sf = [];
      st.s.forEach(function (x) {
        if (!Array.isArray(x) || typeof x[0] !== 'string' || sortable[x[0]] !== true) return;
        if (x[1] !== 'asc' && x[1] !== 'desc') return;
        if (sf.some(function (y) { return y.field === x[0]; })) return;
        sf.push({ field: x[0], dir: x[1] });
      });
      eng.sortFields = sf;
    }
    var z = parseInt(st.z, 10);
    if (DH_PAGE_SIZES.indexOf(z) !== -1) eng.pageSize = z;
    var p = parseInt(st.p, 10);
    if (eng.pageable && p > 1) eng._pendingPage = p;
    if ((st.c === 'n' || st.c === 'c') && eng.base) eng.changeFilter = st.c;
  }
  /* Every -LinkState table's state; past DH_LS_CAP characters the least recently used tables are dropped. */
  function dhTableStateAll(engs) {
    var list = [];
    Object.keys(engs).forEach(function (id) {
      var e = engs[id];
      if (!e.linkState) return;
      var st = dhTableStateGet(e);
      if (st) list.push({ id: id, st: st, touch: e._lsTouch || 0 });
    });
    if (!list.length) return null;
    list.sort(function (a, b) { return b.touch - a.touch; });
    var out = {}, size = 2, n = 0;
    list.forEach(function (x) {
      var add = JSON.stringify(x.id).length + JSON.stringify(x.st).length + 2;
      if (size + add <= DH_LS_CAP) { out[x.id] = x.st; size += add; n++; }
    });
    return n ? out : null;
  }
  /* The page from the address, applied after every other filter (card, tree, global) was restored. */
  function dhTableStateFinish(engs) {
    Object.keys(engs).forEach(function (id) {
      var e = engs[id], p = e._pendingPage;
      if (!p) return;
      e._pendingPage = 0;
      var tp = Math.max(1, Math.ceil(e._getFiltered().length / e.pageSize));
      e.currentPage = Math.min(p, tp);
      e.render();
    });
  }
  TableEngine.prototype._restoreLinkState = function () {
    if (!this.linkState) return;
    var t = URLState.load().t;
    if (t && typeof t === 'object' && Object.prototype.hasOwnProperty.call(t, this.id)) dhTableStateSet(this, t[this.id]);
  };
  TableEngine.prototype._saveLinkState = function () {
    if (!this.linkState) return;
    this._lsTouch = ++dhLsSeq;
    URLState.save();
  };

  /* ── Baseline markers (v2.5.2) ───────────────────────────────────────
     A line under the toolbar ("vs previous run: +3 new, ~2 changed, -1 removed"), Change chips that filter the table,
     and a collapsed group under the table for the rows that disappeared. */
  TableEngine.prototype._buildChangeBar = function () {
    if (!this.base) return;
    var self = this, b = this.base, tb = document.getElementById('toolbar-' + this.id);
    if (!tb) return;
    var bar = document.createElement('div');
    bar.className = 'tbl-change-bar'; bar.id = 'chg-bar-' + this.id;
    var defs = [['', 'All', this.allData.length], ['n', 'New', b['new']], ['c', 'Changed', b.changed], ['r', 'Removed', b.removed]];
    var html = '<span class="tbl-baseline-note">' + esc(dhBaselineNote(b)) + '</span>' +
               '<span class="chg-chips" role="group" aria-label="Filter by change">';
    defs.forEach(function (d) {
      html += '<button type="button" class="chg-chip" data-chg="' + d[0] + '" aria-pressed="' + (d[0] === self.changeFilter ? 'true' : 'false') + '">' + esc(d[1]) + ' <span class="chg-n">' + d[2] + '</span></button>';
    });
    html += '</span>';
    if (b.removed) html += '<label class="chg-incl"><input type="checkbox" class="chg-incl-box"> Include removed rows in exports</label>';
    bar.innerHTML = html;
    tb.parentNode.insertBefore(bar, tb.nextSibling);
    bar.addEventListener('click', function (e) {
      var chip = e.target.closest ? e.target.closest('.chg-chip') : null;
      if (!chip) return;
      var v = chip.getAttribute('data-chg');
      if (v === 'r') {                                  /* Removed rows are not in the table: reveal their group */
        if (self._remBox) { self._remBox.open = true; self._remBox.scrollIntoView({ block: 'nearest' }); }
        return;
      }
      self.changeFilter = (self.changeFilter === v) ? '' : v;
      bar.querySelectorAll('.chg-chip').forEach(function (c) {
        var cv = c.getAttribute('data-chg');
        if (cv === 'r') return;
        c.setAttribute('aria-pressed', (cv === self.changeFilter) ? 'true' : 'false');
      });
      self.currentPage = 1;
      self.render();
      self._refreshLinkedBarCharts();
      self._renderCharts();
      self._saveLinkState();
    });
    var box = bar.querySelector('.chg-incl-box');
    if (box) box.addEventListener('change', function () { self._includeRemoved = box.checked; });
    if (b.removed) {
      var tbl = document.getElementById('tbl-' + this.id), wrap = tbl && tbl.closest ? tbl.closest('.table-wrapper') : null;
      var det = document.createElement('details');
      det.className = 'tbl-removed'; det.id = 'chg-removed-' + this.id;
      det.innerHTML = '<summary>Removed since ' + esc(b.label) + ' (<span class="tbl-removed-n">' + b.removed + '</span>)</summary><div class="tbl-removed-body"></div>';
      if (wrap && wrap.parentNode) wrap.parentNode.insertBefore(det, wrap.nextSibling); else bar.parentNode.appendChild(det);
      this._remBox = det; this._remBody = det.querySelector('.tbl-removed-body');
      /* 2.5.3: the rows are drawn only while the group is open (it used to be rebuilt on every render) */
      det.addEventListener('toggle', function () { if (det.open) self._renderRemoved(); });
    }
  };

  TableEngine.prototype._renderRemoved = function () {
    if (!this.base || !this._remBody) return;
    var self = this, cols = this._visibleCols(), term = (this.filterText || '').toLowerCase();
    var rows = this.base.removedRows.filter(function (r) { return !term || self._matchText(r, term, cols); });
    var n = this._remBox.querySelector('.tbl-removed-n'); if (n) n.textContent = rows.length;
    if (!this._remBox.open) { this._remBody.innerHTML = ''; return; }   /* the count stays current; the rows wait for the open */
    var h = '<table class="tbl-removed-table"><thead><tr>' + cols.map(function (c) { return '<th scope="col">' + esc(c.label) + '</th>'; }).join('') + '</tr></thead><tbody>';
    rows.forEach(function (r) {
      h += '<tr>' + cols.map(function (c) { var v = r[c.field]; return '<td>' + esc(v === null || v === undefined ? '' : (FMT.apply(c, v) || String(v))) + '</td>'; }).join('') + '</tr>';
    });
    if (!rows.length) h += '<tr><td colspan="' + Math.max(1, cols.length) + '" class="tbl-removed-none">No removed row matches the filter.</td></tr>';
    this._remBody.innerHTML = h + '</tbody></table>';
  };

  /* ── Card filter bridge ─────────────────────────────────────────── */
  TableEngine.prototype._applyCardFilters = function () {
    this.currentPage = 1;
    this.render();
    this._refreshLinkedBarCharts();
    this._renderCharts();
  };

  /* Re-render any bar charts, Mode-A pie charts and range bars that reference
     this table. v2.1.1 - every branch resolves its target through
     blockRenderTarget so the collapsible chrome survives a filter change. */
  TableEngine.prototype._refreshLinkedBarCharts = function () {
    var id = this.id;
    BLOCKS_CONFIG.forEach(function (block) {
      if (block.blockType === 'barchart' && block.tableId === id) {
        var bcT = blockRenderTarget(block);
        if (bcT.container) renderBarChart(bcT.container, bcT.block);
      } else if (block.blockType === 'piechart' && block.mode === 'fromtable' && block.tableId === id) {
        var pcT = blockRenderTarget(block);
        if (pcT.container) renderPieChart(pcT.container, pcT.block);
      } else if (block.blockType === 'rangebar' && block.mode === 'fromtable' && block.tableId === id) {
        /* v2.1.0 - a filtered table live-recomputes its range bars */
        var rbT = blockRenderTarget(block);
        if (rbT.container) renderRangeBar(rbT.container, rbT.block);
      }
    });
  };

  /* Position of a row object in allData (-1 when it is not one of ours). */
  TableEngine.prototype._idxOf = function (row) {
    var i = this._rowIdx.get(row);
    return (i === undefined) ? -1 : i;
  };

  /* ── Visible columns ────────────────────────────────────────────── */
  TableEngine.prototype._visibleCols = function () {
    var self=this;
    return this.columns.filter(function(col,i){return self.colVisible[i]!==false;});
  };

  /* ── Page size ──────────────────────────────────────────────────── */
  TableEngine.prototype._initPageSizes = function () {
    var sel=document.getElementById('pagesize-'+this.id);
    if (!sel) return;
    var self=this;
    [5,10,15,25,50,100].forEach(function(n){
      var o=document.createElement('option');
      o.value=n;o.textContent=n;
      if(n===self.pageSize)o.selected=true;
      sel.appendChild(o);
    });
    sel.addEventListener('change',function(){self.pageSize=parseInt(sel.value,10);self.currentPage=1;self.render();self._saveLinkState();});
    if (!this.filterable){var fw=document.getElementById('filter-wrap-'+this.id);if(fw)fw.style.display='none';}
  };

  /* ── Filter ─────────────────────────────────────────────────────── */

  /* v2.1.3 — the single definition of "apply a text filter to this table".
     The search box, pie-slice clicks and bar-chart clicks all route through
     here. Before 2.1.3 each carried its own partial copy and they had drifted:
     the pie never revealed the clear button and never refreshed linked charts,
     and the bar chart's inline onclick did neither and skipped URLState too.
     Add a step here, never in a caller. */
  TableEngine.prototype.applyTextFilter = function (value) {
    var inp = document.getElementById('filter-'+this.id);
    var clr = document.getElementById('filter-clear-'+this.id);
    this.filterText  = value || '';
    this.currentPage = 1;
    if (inp) inp.value = this.filterText;
    if (clr) clr.style.display = this.filterText ? 'flex' : 'none';
    this.render();
    this._refreshLinkedBarCharts();
    this._renderCharts();
    URLState.save();
  };

  TableEngine.prototype._bindFilter = function () {
    var inp=document.getElementById('filter-'+this.id);
    var clr=document.getElementById('filter-clear-'+this.id);
    if (!inp) return;
    var self=this;
    inp.addEventListener('input',function(){ self.applyTextFilter(inp.value); });
    clr.addEventListener('click',function(){ self.applyTextFilter(''); });
    /* Restore from URL */
    var saved=URLState.load();
    if (saved.filters&&saved.filters[this.id]) {
      inp.value=saved.filters[this.id];
      self.filterText=inp.value;
      clr.style.display='flex';
    }
  };

  /* ── Clear selection ────────────────────────────────────────────── */
  TableEngine.prototype._bindClearSel = function () {
    var btn=document.getElementById('clear-sel-'+this.id);
    if (!btn) return;
    var self=this;
    btn.addEventListener('click',function(){self.selected=[];self._notifyLinks(null);self.render();});
  };

  /* ── Link clear ─────────────────────────────────────────────────── */
  TableEngine.prototype._bindLinkClear = function () {
    var btn=document.getElementById('link-clear-'+this.id);
    if (!btn) return;
    var self=this;
    btn.addEventListener('click',function(){
      self.linkedFilter=null;self.currentPage=1;self.selected=[];
      var badge=document.getElementById('link-badge-'+self.id);
      if(badge)badge.style.display='none';
      if(self.pathFilter){self.setPathFilter(null);return;}
      self.render();
    });
  };

  /* ── Export bindings ────────────────────────────────────────────── */
  TableEngine.prototype._bindExport = function () {
    var self=this;
    var csv=document.getElementById('exp-csv-'+this.id);
    var xlsx=document.getElementById('exp-xlsx-'+this.id);
    var pdf=document.getElementById('exp-pdf-'+this.id);
    if(csv) csv.addEventListener('click',function(){self.exportCsv();});
    if(xlsx)xlsx.addEventListener('click',function(){self.exportExcel();});
    if(pdf) pdf.addEventListener('click',function(){self.exportPdf();});
  };

  /* ── Right-click copy ───────────────────────────────────────────── */
  TableEngine.prototype._bindRightClick = function () {
    var tbody = document.getElementById('tbody-' + this.id);
    if (!tbody) return;
    var self = this;

    /* Custom context menu element — one per table. v2.1.4: the items carry
       classes, not ids; with fixed ids every table after the first put a
       duplicate id into the document. */
    var ctxMenu = document.createElement('div');
    ctxMenu.className = 'ctx-menu';
    ctxMenu.style.display = 'none';
    ctxMenu.innerHTML =
      '<div class="ctx-item ctx-copy-cell">&#128203; Copy cell value</div>' +
      '<div class="ctx-item ctx-copy-csv">&#128190; Copy table as CSV</div>';
    document.body.appendChild(ctxMenu);

    /* Clipboard write with a fallback for file:// pages and browsers where
       navigator.clipboard is missing or refuses (it needs a secure context). */
    function copyText(text, onDone) {
      function legacy() {
        var ta = document.createElement('textarea');
        ta.value = text;
        ta.setAttribute('readonly', '');
        ta.style.cssText = 'position:fixed;top:-1000px;left:-1000px;opacity:0;';
        document.body.appendChild(ta);
        ta.select();
        var ok = false;
        try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
        document.body.removeChild(ta);
        if (ok && onDone) onDone();
      }
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function () { if (onDone) onDone(); }, legacy);
      } else {
        legacy();
      }
    }

    var targetTd = null;

    function closeMenu() { ctxMenu.style.display = 'none'; targetTd = null; }
    document.addEventListener('click', closeMenu);
    document.addEventListener('keydown', function(e){ if(e.key==='Escape') closeMenu(); });

    tbody.addEventListener('contextmenu', function(e) {
      var td = e.target.closest('td');
      if (!td) return;
      targetTd = td;
      ctxMenu.style.cssText = 'display:block;position:fixed;top:'+e.clientY+'px;left:'+e.clientX+'px;z-index:9999;';
      e.preventDefault();
    });

    /* Copy single cell */
    ctxMenu.querySelector('.ctx-copy-cell').addEventListener('click', function() {
      if (!targetTd) return;
      var td   = targetTd;
      var text = dhCellText(td);
      if (text) {
        copyText(text, function() {
          td.classList.add('cell-copied');
          setTimeout(function(){ td.classList.remove('cell-copied'); }, 600);
        });
      }
      closeMenu();
    });

    /* Copy entire filtered table as CSV */
    ctxMenu.querySelector('.ctx-copy-csv').addEventListener('click', function() {
      var r    = self._exportRows();
      var lines = [r.cols.map(function(c){ return '"'+c.label.replace(/"/g,'""')+'"'; }).join(',')];
      r.rows.forEach(function(row){
        lines.push(r.cols.map(function(c){
          var v = dhCsvSafe(FMT.forExport(c, row[c.field]));
          return '"'+v.replace(/"/g,'""')+'"';
        }).join(','));
      });
      copyText(lines.join('\r\n'), function(){
        /* Brief visual feedback on the table */
        var tbl = document.getElementById('tbl-'+self.id);
        if (tbl) {
          tbl.classList.add('table-copied');
          setTimeout(function(){ tbl.classList.remove('table-copied'); }, 800);
        }
      });
      closeMenu();
    });
  };

  /* ── Column visibility toggle ───────────────────────────────────── */
  /* v2.5.0 - the reader's column choice, kept per viewer in localStorage (opt-in: Add-DhTable
     -RememberColumns). Stored by field name, so a column added later keeps its default. Storage can be
     blocked (private windows), so every access is guarded and the table works without it. */
  TableEngine.prototype._colsKey = function () {
    return this.rememberKey ? 'dh:cols:'+this.rememberKey : '';
  };
  TableEngine.prototype._restoreCols = function () {
    var key=this._colsKey(); if(!key) return;
    try{
      var saved=JSON.parse(window.localStorage.getItem(key)||'null');
      if(!saved||typeof saved!=='object') return;
      var self=this;
      this.columns.forEach(function(col,i){ if(Object.prototype.hasOwnProperty.call(saved,col.field)) self.colVisible[i]=!!saved[col.field]; });
    }catch(e){}
  };
  TableEngine.prototype._saveCols = function () {
    var key=this._colsKey(); if(!key) return;
    try{
      var map={}, self=this;
      this.columns.forEach(function(col,i){ map[col.field]=self.colVisible[i]!==false; });
      window.localStorage.setItem(key,JSON.stringify(map));
    }catch(e){}
  };
  TableEngine.prototype._colToggleLabel = function () {
    var btn=document.getElementById('btn-col-toggle-'+this.id); if(!btn) return;
    var self=this, n=0;
    this.columns.forEach(function(col,i){ if(self.colVisible[i]===false) n++; });
    btn.innerHTML='&#9776; Columns'+(n?' ('+n+' hidden)':'');
  };

  TableEngine.prototype._buildColToggle = function () {
    var btn=document.getElementById('btn-col-toggle-'+this.id);
    var dd=document.getElementById('col-toggle-dd-'+this.id);
    if(!btn||!dd) return;
    var self=this, boxes=[];
    this.columns.forEach(function(col,i){
      var row=document.createElement('label');
      row.className='col-toggle-item';
      var chk=document.createElement('input');
      chk.type='checkbox';chk.checked=self.colVisible[i]!==false;
      chk.addEventListener('change',function(){self.colVisible[i]=chk.checked;self._saveCols();self._colToggleLabel();self.render();});
      boxes.push(chk);
      row.appendChild(chk);
      row.appendChild(document.createTextNode(' '+col.label));
      dd.appendChild(row);
    });
    /* back to the author's columns (and forget the saved choice) */
    var reset=document.createElement('button');
    reset.type='button'; reset.className='col-toggle-reset'; reset.textContent='Default columns';
    reset.addEventListener('click',function(e){
      e.stopPropagation();
      self.columns.forEach(function(col,i){ self.colVisible[i]=!col.hidden; boxes[i].checked=!col.hidden; });
      var key=self._colsKey(); if(key){ try{ window.localStorage.removeItem(key); }catch(x){} }
      self._colToggleLabel(); self.render();
    });
    dd.appendChild(reset);
    this._colToggleLabel();
    btn.addEventListener('click',function(e){e.stopPropagation();dd.style.display=dd.style.display==='none'?'block':'none';});
    document.addEventListener('click',function(){dd.style.display='none';});
  };

  /* ── Linked-filter API ──────────────────────────────────────────── */
  TableEngine.prototype.applyLinkedFilter = function (field,value,masterTitle) {
    this.linkedFilter=(value!==null)?{field:field,value:String(value),masterTitle:masterTitle}:null;
    this.currentPage=1;this.selected=[];
    this._updateLinkBadge();this.render();
  };

  TableEngine.prototype._updateLinkBadge = function () {
    var badge=document.getElementById('link-badge-'+this.id);
    var text=document.getElementById('link-text-'+this.id);
    if(!badge)return;
    if(this.linkedFilter){
      badge.style.display='flex';
      text.textContent='Filtered by \u201C'+(this.linkedFilter.masterTitle||'master')+
        '\u201D \u2192 '+this.linkedFilter.field+' = '+this.linkedFilter.value;
    } else if(this.pathFilter){
      badge.style.display='flex';
      text.textContent='Filtered by \u201C'+(this.pathFilter.title||'tree')+
        '\u201D \u2192 '+(this.pathFilter.label||this.pathFilter.value);
    } else {badge.style.display='none';}
  };

  /* v2.4.0 - the single definition of "this row matches this text" (lower-cased
     term). _getFiltered and the report-wide search both call it. */
  TableEngine.prototype._matchText = function (row, term, cols) {
    cols = cols || this._visibleCols();
    for (var i = 0; i < cols.length; i++) {
      var col = cols[i], v = row[col.field];
      if (v === null || v === undefined) continue;
      if (String(v).toLowerCase().indexOf(term) !== -1 ||
          FMT.apply(col, v).toLowerCase().indexOf(term) !== -1) return true;
    }
    return false;
  };

  /* v2.4.0 - path filter (Add-DhTreeFilter). spec = {field, value, sep, mode, nodeId,
     label, title} or null. The one place pathFilter is assigned, like
     applyTextFilter for text: callers never set it directly. */
  TableEngine.prototype.setPathFilter = function (spec) {
    this.pathFilter = spec || null;
    this.currentPage = 1; this.selected = [];
    this._updateLinkBadge();
    this.render();
    this._refreshLinkedBarCharts();
    this._renderCharts();
    if (typeof TreeFilter !== 'undefined') TreeFilter.sync(this.id);
    URLState.save();
  };

  /* ── Data pipeline — multi-sort + card filters ──────────────────── */
  TableEngine.prototype._getFiltered = function () {
    var data=this.allData;var self=this;

    if (self.linkedFilter) {
      var lf=self.linkedFilter;
      data=data.filter(function(row){return String(row[lf.field])===lf.value;});
    }

    if (self.base && self.changeFilter) {
      data=data.filter(function(row){return dhChangeKeep(self._baseState.get(row), self.changeFilter);});
    }

    /* Card filters */
    Object.keys(cardFilters).forEach(function(filterId) {
      var cf=cardFilters[filterId];
      if (cf.values&&cf.values.length) {
        data=data.filter(function(row){
          return cf.values.some(function(v){return String(row[cf.field])===v;});
        });
      }
    });

    /* Global page-level filters (v1.9.0) — only rows matching every active
       facet / date-range whose field this table has. */
    if (typeof GlobalFilter !== 'undefined' && GlobalFilter.active()) {
      data=data.filter(function(row){ return GlobalFilter.matchRow(row); });
    }

    if (self.pathFilter) {
      var pf=self.pathFilter;
      data=data.filter(function(row){return dhPathMatch(row[pf.field],pf.value,pf.sep,pf.mode);});
    }

    if (self.filterText) {
      var term=self.filterText.toLowerCase();
      var mcols=self._visibleCols();
      data=data.filter(function(row){return self._matchText(row,term,mcols);});
    }

    /* Multi-sort: sortFields is [{field,dir},...] */
    if (self.sortFields&&self.sortFields.length) {
      /* Pre-build a field → column map so we can spot sparkline columns
         without scanning self.columns inside the hot comparator loop. */
      var colMap = {};
      (self.columns||[]).forEach(function(c){ colMap[c.field] = c; });
      /* PERF 1.10.4 — decorate/sort/undecorate.
         The previous comparator ran parseFloat twice AND
         String.localeCompare(x, undefined, {sensitivity:'base'}) on every
         comparison (~n log n: ~270,000 calls for a 19,011-row table). Passing
         an options object to localeCompare makes the engine resolve collation
         settings per call, which measured 5.6 s of BLOCKED main thread to sort
         one column. Precomputing each row's keys once (O(n)) and reusing a
         single Intl.Collator is ~32x faster.
         Ordering is byte-for-byte unchanged: the spec defines
         localeCompare(y, loc, opts) as new Intl.Collator(loc, opts).compare(x, y),
         and Array#sort is stable in ES2019+, so ties keep their input order. */
      var _ic = (typeof Intl !== 'undefined' && Intl.Collator)
                ? new Intl.Collator(undefined, {sensitivity:'base'}) : null;
      var cmpStr = _ic
        ? function(x,y){ return _ic.compare(x,y); }
        : function(x,y){ return x.localeCompare(y,undefined,{sensitivity:'base'}); };
      var sfs=self.sortFields, nf=sfs.length;
      var dec=new Array(data.length);
      for (var di=0; di<data.length; di++) {
        var row=data[di], ks=new Array(nf), ns=new Array(nf);
        for (var fi=0; fi<nf; fi++) {
          var f=sfs[fi].field, col=colMap[f];
          var v=(row[f]!=null)?row[f]:'';
          /* v1.4 F8 — sparkline columns reduce arrays to a comparable scalar */
          if (col && col.cellType === 'sparkline') { v = sparkReduce(v, col.sortBy); }
          var num=parseFloat(v);
          ks[fi]=String(v); ns[fi]=isNaN(num)?null:num;
        }
        dec[di]={r:row,k:ks,n:ns};
      }
      dec.sort(function(a,b){
        for (var i=0;i<nf;i++) {
          var an=a.n[i],bn=b.n[i];
          var n=(an!==null&&bn!==null)?(an-bn):cmpStr(a.k[i],b.k[i]);
          if(n!==0)return sfs[i].dir==='asc'?n:-n;
        }
        return 0;
      });
      data=new Array(dec.length);
      for (var ui=0; ui<dec.length; ui++) { data[ui]=dec[ui].r; }
    }
    return data;
  };

  /* ── Cell rendering ─────────────────────────────────────────────── */
  TableEngine.prototype._renderCell = function (col,rawVal,row) {
    var td=document.createElement('td');
    var cellType=(col.cellType||'text').toLowerCase();
    var isSparklineCell = (cellType === 'sparkline');
    var strRaw=(rawVal!==null&&rawVal!==undefined)?String(rawVal):'';
    /* Skip FMT.apply + threshold matching for sparkline cells — the value is
       an array, not a scalar, and those code paths would mis-parse it. */
    var dispVal = isSparklineCell ? '' : (FMT.apply(col,rawVal) || strRaw);
    var thClass = isSparklineCell ? '' : getThresholdClass(col,rawVal);

    var align=(col.align||'left').toLowerCase();
    if(align==='right') td.classList.add('cell-right');
    if(align==='center')td.classList.add('cell-center');
    if(thClass)td.classList.add(thClass);
    if(col.bold)  td.classList.add('cell-bold');
    if(col.italic)td.classList.add('cell-italic');
    if(col.font){var fm={mono:'cell-mono',ui:'cell-ui',display:'cell-display'};var fc=fm[col.font.toLowerCase()];if(fc)td.classList.add(fc);}

    if(cellType==='progressbar'){
      var numVal=parseFloat(strRaw),pMax=col.progressMax||100;
      var pct=isNaN(numVal)?0:Math.min(100,Math.max(0,(numVal/pMax)*100));
      var fillCls=thClass?thClass.replace('cell-','fill-'):'fill-default';
      td.classList.add('td-progress');
      td.innerHTML='<div class="progress-wrap"><span class="progress-label">'+esc(dispVal)+'</span>'+
        '<div class="progress-track"><div class="progress-fill '+fillCls+'" style="width:'+pct.toFixed(1)+'%"></div></div></div>';
    } else if(cellType==='badge'){
      td.classList.add('td-badge');
      var badge=document.createElement('span');
      badge.className='cell-badge'+(thClass?' badge-'+thClass.replace('cell-',''):'');
      badge.textContent=dispVal;td.appendChild(badge);
    } else if(cellType==='sparkline'){
      /* v1.4 F8 — inline mini-chart per row. Cell value must be a numeric array;
         null/non-array values render as an em dash. Reuses the SPARK helper
         shared with Add-DhSummary tile sparklines. */
      td.classList.add('td-sparkline');
      var arr = Array.isArray(rawVal) ? rawVal : null;
      if (arr && arr.length) {
        td.innerHTML = SPARK.build(arr, {
          style:  col.sparklineStyle || 'line',
          width:  100,
          height: 22
        });
      } else {
        td.innerHTML = '<span class="td-sparkline-empty">—</span>';
      }
    } else if(cellType==='chips'||cellType==='path'){
      /* v2.3.0 — a list in one cell. chips: tags (FSMO roles); path: an arrow
         chain (A -> B -> Tier 0). The value is an array, or a string split on
         ';' / ',' (chips) or '>' / the arrow (path). DOM calls only. */
      var items = Array.isArray(rawVal) ? rawVal.map(String)
                : (strRaw ? strRaw.split(cellType==='chips' ? /\s*[;,]\s*/ : /\s*(?:->|>|→)\s*/) : []);
      items = items.filter(function(s){return s!=='';});
      td.classList.add(cellType==='chips'?'td-chips':'td-path');
      if(!items.length){ td.textContent=''; }
      items.forEach(function(it,i){
        if(cellType==='path' && i>0){
          var sep=document.createElement('span'); sep.className='cell-path-sep'; sep.textContent='→'; td.appendChild(sep);
        }
        var chip=document.createElement('span');
        chip.className=cellType==='chips'?'cell-chip':'cell-path-node';
        chip.textContent=it; td.appendChild(chip);
      });
    } else if(cellType==='link'){
      /* v2.2.0 — link cell. The URL comes from col.urlField (default: this
         column's value), possibly a property that is not a visible column.
         Only http(s) and mailto become links; anything else, javascript:
         included, is shown as plain text. Built with DOM calls, never
         innerHTML, so neither the URL nor the text can inject markup. */
      /* v2.6.0 - also tel:, relative / #fragment URLs (col.relativeLinks or a template), URL
         templates (col.urlTemplate) and the link target (col.linkTarget), all in dhLinkUrl / dhLinkFill. */
      var lk = this._linkFor(col, row, rawVal);
      if (lk) {
        var a = document.createElement('a');
        a.href = lk.url;
        a.textContent = col.linkText || dispVal || lk.url;
        a.className = 'cell-link';
        if (lk.newTab) { a.target = '_blank'; a.rel = 'noopener noreferrer'; }
        a.title = lk.url;
        td.appendChild(a);
      } else {
        var rawUrl = row && col.urlField ? row[col.urlField] : rawVal;
        td.textContent = dispVal || (rawUrl !== null && rawUrl !== undefined ? String(rawUrl).trim() : '');
      }
    } else {
      td.textContent=dispVal;
    }

    /* Width: a dragged override wins over the author's declared width. Without
       this the cell falls back to the .data-table td max-width, so a column
       declared wider than that silently clipped anyway. */
    var effW = this._effWidth(col);
    if(effW){ td.style.maxWidth=effW; td.style.width=effW; }

    /* Full text for the truncation tooltip. _markTruncated() promotes this to a
       real title= only on cells that actually overflow, so short cells stay
       tooltip-free. Kept off badge/progress/sparkline cells, whose visible text
       is not the raw value. */
    if(cellType==='text' && dispVal){ td.dataset.full=dispVal; }

    /* Pin first column */
    if(col.pinFirst){td.classList.add('col-pinned');}
    return td;
  };

  /* ── Render ─────────────────────────────────────────────────────── */
  TableEngine.prototype.render = function(){
    this._renderHead();this._renderBody();this._renderFoot();this._renderPaging();
    this._renderInfo();this._renderSelClearBtn();
    this._renderRemoved();
    this._ensureFit();
    this._markTruncated();
  };

  /* ── Column fit (v2.4.0) ────────────────────────────────────────────
     Cells are nowrap with an ellipsis and a 340px CSS cap, so a long value lost
     its tail. Auto fit measures the formatted text of every row (canvas
     measureText, so it needs no layout and works for rows a virtual table has not
     drawn) and gives each column the width of its widest text, header included,
     clamped to [MinWidth, ColumnMaxWidth]. Past the cap the cell still ellipsises
     and shows its tooltip. Fonts and padding are read from a rendered cell, so a
     theme or density change re-measures (_refit). */
  var _fitCanvas = null;

  TableEngine.prototype._effWidth = function(col){
    return (this.colWidths&&this.colWidths[col.field]) || col.width || (this._fitW&&this._fitW[col.field]) || '';
  };

  function dhFitFont(cs){
    return cs.fontStyle+' '+cs.fontWeight+' '+cs.fontSize+' '+cs.fontFamily;
  }
  function dhFitPad(cs){
    return (parseFloat(cs.paddingLeft)||0)+(parseFloat(cs.paddingRight)||0);
  }

  /* Width in px of one column's widest text, or 0 when it cannot be measured yet. */
  TableEngine.prototype._measureCol = function(col, ci, ctx, env){
    var cell = env.row && env.row.cells[ci+env.off];
    var ccs = cell ? getComputedStyle(cell) : null;
    var bodyFont = ccs ? dhFitFont(ccs) : '12px monospace';
    var padB = ccs ? dhFitPad(ccs) : 24;
    var label = String(col.label||'');
    ctx.font = env.headFont;
    var hw = ctx.measureText(label.toUpperCase()).width + env.ls*label.length + 30 + env.padH;   /* + sort icon and grip */

    var ct = (col.cellType||'').toLowerCase();
    var cw = 0, extra = 0;
    if (ct === 'sparkline') { cw = 100; }
    else {
      var seen = new Set(), list = [], r, s;
      for (r = 0; r < this.allData.length; r++) {
        var v = this.allData[r][col.field];
        if (v === null || v === undefined || v === '') continue;
        s = FMT.apply(col, v);
        if (!s || seen.has(s)) continue;
        seen.add(s); list.push(s);
      }
      if (list.length > 3000) {                 /* the widest text is among the longest strings */
        list.sort(function(a,b){return b.length-a.length;});
        list = list.slice(0, 3000);
      }
      ctx.font = bodyFont;
      for (r = 0; r < list.length; r++) {
        var w = ctx.measureText(list[r]).width;
        if (w > cw) { cw = w; if (ct === 'chips') extra = 14 * (list[r].split(', ').length); }
      }
      if (ct === 'badge')       extra = 22;
      if (ct === 'progressbar') cw = Math.max(cw, 90);
      if (this.base && ci === 0) extra += 62;          /* the New / Changed tag sits in the first cell */
    }
    var w2 = Math.ceil(Math.max(hw, cw + padB + extra) + 4);   /* 4px: sub-pixel rounding must never clip the last glyph */
    var min = col.minWidth || 48, max = Math.max(min, this.columnMax);
    return Math.min(max, Math.max(min, w2));
  };

  /* Fonts and padding come from a rendered cell and header; null until one exists. */
  TableEngine.prototype._fitEnv = function(){
    var tbody=document.getElementById('tbody-'+this.id), head=document.getElementById('thead-'+this.id);
    if(!tbody||!head) return null;
    var row=null, i;
    for(i=0;i<tbody.rows.length;i++){
      var rr=tbody.rows[i];
      if(rr.classList.contains('virt-spacer')||rr.querySelector('td.no-data')) continue;
      row=rr; break;
    }
    var th=head.querySelector('th[data-field]');
    if(!row||!th) return null;
    if(!_fitCanvas) _fitCanvas=document.createElement('canvas');
    var ctx=_fitCanvas.getContext&&_fitCanvas.getContext('2d');
    if(!ctx) return null;
    var hcs=getComputedStyle(th);
    return { ctx:ctx, row:row, off:this.multiSelect?1:0, headFont:dhFitFont(hcs), ls:parseFloat(hcs.letterSpacing)||0, padH:dhFitPad(hcs) };
  };

  TableEngine.prototype._measureFit = function(cols){
    var env=this._fitEnv();
    if(!env) return null;
    var out={}, self=this;
    cols.forEach(function(col,ci){
      if(col.width) return;                          /* the author's width wins */
      out[col.field]=self._measureCol(col,ci,env.ctx,env)+'px';
    });
    return out;
  };

  TableEngine.prototype._ensureFit = function(force){
    if(this.columnFit==='fixed'||!this.allData.length) return;
    var cols=this._visibleCols(), self=this;
    var complete=this._fitW&&cols.every(function(c){return c.width||(c.field in self._fitW);});
    if(complete&&!force) return;
    var m=this._measureFit(cols);
    if(!m) return;
    this._fitW=m;
    Object.keys(m).forEach(function(f){ if(!self.colWidths[f]) self._applyColWidthDom(f,m[f]); });
  };

  /* Fonts, density or visible columns changed: measure again. */
  TableEngine.prototype._refit = function(){
    this._fitW=null;
    this._ensureFit(true);
    this._markTruncated();
  };

  /* Width of one column fitted to its content right now (double-click on its grip). */
  TableEngine.prototype._fitOne = function(col){
    var ci=this._visibleCols().indexOf(col), env=this._fitEnv();
    if(ci<0||!env) return 0;
    return this._measureCol(col,ci,env.ctx,env);
  };

  /* Give a title= only to cells whose text is actually clipped, so hovering a
     short cell shows nothing while a clipped one reveals the full value.
     Measured rather than guessed from string length, because the threshold is
     the rendered column width - which the author sets, the theme font affects,
     and the user can now drag. One pass over the rendered rows only: the page
     when paginated, the virtualised window otherwise. */
  TableEngine.prototype._markTruncated = function(){
    /* Headers first. A clipped header is worse than a clipped cell - it is the
       only thing naming the column - so it gets the same measured title=. */
    var head=document.getElementById('thead-'+this.id);
    if(head){
      var ths=head.querySelectorAll('th');
      for(var h=0;h<ths.length;h++){
        var lab=ths[h].querySelector('.col-label');
        if(!lab)continue;
        if(lab.scrollWidth>lab.clientWidth+1){
          ths[h].title=lab.textContent;
          ths[h].classList.add('th-clipped');
        } else {
          ths[h].removeAttribute('title');
          ths[h].classList.remove('th-clipped');
        }
      }
    }
    var tbody=document.getElementById('tbody-'+this.id);
    if(!tbody)return;
    var cells=tbody.querySelectorAll('td[data-full]');
    for(var i=0;i<cells.length;i++){
      var td=cells[i];
      var was=td.dataset.was||'';                         /* v2.5.2: the old value of a changed cell (baseline) */
      if(td.scrollWidth>td.clientWidth+1){
        td.title=td.dataset.full+(was?' \u2014 '+was:'');
        td.classList.add('cell-clipped');
      } else {
        if(was)td.title=was; else td.removeAttribute('title');
        td.classList.remove('cell-clipped');
      }
    }
  };

  /* Aggregate footer row — only rendered when any column has an 'aggregate' property */
  TableEngine.prototype._renderFoot = function() {
    var self = this;
    var visCols = this._visibleCols();
    var hasFoot = visCols.some(function(col){ return col.aggregate; });
    var tbl = document.getElementById('tbl-' + this.id);
    if (!tbl) return;

    /* Remove existing tfoot */
    var oldFoot = tbl.querySelector('tfoot');
    if (oldFoot) oldFoot.remove();
    if (!hasFoot) return;

    /* Totals follow the selection: with rows ticked (and still in the filtered set) the footer
       aggregates just those rows; with none ticked it aggregates every filtered row. */
    var filtered = this._getFiltered();
    var selRows = null;
    if (this.multiSelect && this.selected.length) {
      var inView = new Set(filtered);
      var picked = [];
      this.selected.forEach(function(i){ var r = self.allData[i]; if (r !== undefined && inView.has(r)) picked.push(r); });
      if (picked.length) selRows = picked;
    }
    var aggRows = selRows || filtered;
    var tfoot = document.createElement('tfoot');
    var tr    = document.createElement('tr');
    tr.className = 'tfoot-row' + (selRows ? ' tfoot-selected' : '');

    if (this.multiSelect) {
      var tdBlank = document.createElement('td'); tdBlank.className = 'col-select';
      if (selRows) tdBlank.title = 'Totals for the ' + selRows.length + ' selected row' + (selRows.length === 1 ? '' : 's');
      tr.appendChild(tdBlank);
    }

    visCols.forEach(function(col) {
      var td = document.createElement('td');
      td.className = 'tfoot-cell';
      var align = (col.align || 'left').toLowerCase();
      if (align === 'right')  td.classList.add('cell-right');
      if (align === 'center') td.classList.add('cell-center');
      if (col.pinFirst) td.classList.add('col-pinned');

      var agg = (col.aggregate || '').toLowerCase();
      if (!agg) { tr.appendChild(td); return; }

      var nums = aggRows.map(function(row){
        var v = parseFloat(row[col.field]);
        return isNaN(v) ? null : v;
      }).filter(function(v){ return v !== null; });

      var result = dhAggregate(agg, nums, aggRows.length);

      if (result !== null) {
        var displayVal = dhFootText(col, result);
        td.textContent = displayVal;
        td.title = (selRows ? 'Selected (' + selRows.length + ') - ' : '') + agg.charAt(0).toUpperCase()+agg.slice(1)+': '+displayVal;
      }
      tr.appendChild(td);
    });

    tfoot.appendChild(tr);
    tbl.appendChild(tfoot);
  };

  TableEngine.prototype._renderHead = function(){
    var tr=document.getElementById('thead-'+this.id);
    if(!tr)return;
    var self=this;tr.innerHTML='';
    var visCols=this._visibleCols();

    if(this.multiSelect){
      var th=document.createElement('th');th.className='col-select';
      th.innerHTML='<input type="checkbox" id="chk-all-'+this.id+'" aria-label="Select all rows">';
      th.querySelector('input').addEventListener('change',function(e){
        var checked=e.target.checked,filtered=self._getFiltered();
        /* Select the rows the user can actually see: the current page when
           paginated, or the WHOLE filtered set when -Pageable:$false (which
           renders every row). Slicing by pageSize on a non-pageable table only
           toggled the first 15 rows — the select-all lied. */
        var pageRows=self.pageable
          ?filtered.slice((self.currentPage-1)*self.pageSize,(self.currentPage-1)*self.pageSize+self.pageSize)
          :filtered;
        pageRows.forEach(function(row){
          var idx=self._idxOf(row);
          if(checked){if(self.selected.indexOf(idx)===-1)self.selected.push(idx);}
          else{self.selected=self.selected.filter(function(i){return i!==idx;});}
        });self.render();
      });
      tr.appendChild(th);
    }

    visCols.forEach(function(col,ci){
      var th=document.createElement('th');
      th.dataset.field=col.field;
      th.setAttribute('scope','col');   /* a11y: column-header association */
      var effW=self._effWidth(col);
      /* max-width as well as width: under table-layout:auto the browser treats
         width as a suggestion and will not go below the header's own text. */
      if(effW){th.style.width=effW;th.style.maxWidth=effW;}
      if(col.pinFirst)th.classList.add('col-pinned');

      var align=(col.align||'left').toLowerCase();
      if(align==='right') th.classList.add('th-right');
      if(align==='center')th.classList.add('th-center');

      var lbl=document.createElement('span');lbl.className='col-label';lbl.textContent=col.label;
      th.appendChild(lbl);

      if(col.sortable!==false){
        th.classList.add('sortable');
        /* a11y: keyboard-operable sort control + screen-reader sort state */
        th.tabIndex=0;
        th.setAttribute('role','columnheader');
        var icon=document.createElement('span');icon.className='sort-icon';

        /* Show sort position for multi-sort */
        var sortPos=self.sortFields.findIndex(function(sf){return sf.field===col.field;});
        if(sortPos>-1){
          icon.classList.add('sort-'+self.sortFields[sortPos].dir);
          th.classList.add('sorted');
          th.setAttribute('aria-sort',self.sortFields[sortPos].dir==='asc'?'ascending':'descending');
          if(self.sortFields.length>1){
            var pos=document.createElement('span');
            pos.className='sort-pos';pos.textContent=sortPos+1;
            th.appendChild(pos);
          }
        } else {
          th.setAttribute('aria-sort','none');
        }
        th.appendChild(icon);

        var doSort=function(shift){
          var existIdx=self.sortFields.findIndex(function(sf){return sf.field===col.field;});
          if(shift&&self.sortFields.length>0){
            /* Multi-sort: add or toggle */
            if(existIdx>-1){
              if(self.sortFields[existIdx].dir==='asc') self.sortFields[existIdx].dir='desc';
              else self.sortFields.splice(existIdx,1);
            } else {
              self.sortFields.push({field:col.field,dir:'asc'});
            }
          } else {
            /* Single sort */
            if(existIdx>-1&&self.sortFields.length===1){
              self.sortFields[0].dir=self.sortFields[0].dir==='asc'?'desc':'asc';
            } else {
              self.sortFields=[{field:col.field,dir:'asc'}];
            }
          }
          self.currentPage=1;self.render();self._saveLinkState();
        };
        th.addEventListener('click',function(e){ doSort(e.shiftKey); });
        th.addEventListener('keydown',function(e){
          if(e.key==='Enter'||e.key===' '){ e.preventDefault(); doSort(e.shiftKey); }
        });
      }
      /* Drag-to-resize grip on the column's right edge. Added after the sort
         handlers so its own pointerdown/click can stop propagation - otherwise
         every resize would also toggle the sort. */
      var grip=document.createElement('span');
      grip.className='col-resizer';
      grip.setAttribute('role','separator');
      grip.setAttribute('aria-orientation','vertical');
      grip.setAttribute('aria-label','Resize column '+col.label);
      grip.tabIndex=0;
      grip.title='Drag to resize · double-click to fit the text';
      grip.addEventListener('click',function(e){e.stopPropagation();});
      grip.addEventListener('keydown',function(e){
        /* Keyboard parity: arrows nudge, Home resets. */
        var step=(e.key==='ArrowLeft')?-16:(e.key==='ArrowRight')?16:0;
        if(step){
          e.preventDefault();e.stopPropagation();
          var cur=th.getBoundingClientRect().width;
          self._setColWidth(col.field,Math.max(40,cur+step));
        } else if(e.key==='Home'){
          e.preventDefault();e.stopPropagation();
          delete self.colWidths[col.field];self.render();
        }
      });
      grip.addEventListener('dblclick',function(e){
        e.preventDefault();e.stopPropagation();
        /* v2.4.0: fit this column to its widest text (it used to reset to the CSS default) */
        var fw=self._fitOne(col);
        if(fw){ self._setColWidth(col.field,fw); self._markTruncated(); }
        else { delete self.colWidths[col.field];self.render(); }
      });
      grip.addEventListener('pointerdown',function(e){
        e.preventDefault();e.stopPropagation();
        var startX=e.clientX, startW=th.getBoundingClientRect().width;
        grip.setPointerCapture(e.pointerId);
        grip.classList.add('resizing');
        var onMove=function(ev){
          self._setColWidth(col.field,Math.max(40,startW+(ev.clientX-startX)));
        };
        var onUp=function(ev){
          grip.classList.remove('resizing');
          try{grip.releasePointerCapture(ev.pointerId);}catch(_){}
          grip.removeEventListener('pointermove',onMove);
          grip.removeEventListener('pointerup',onUp);
          grip.removeEventListener('pointercancel',onUp);
          /* Re-evaluate which cells are clipped at the new width */
          self._markTruncated();
        };
        grip.addEventListener('pointermove',onMove);
        grip.addEventListener('pointerup',onUp);
        grip.addEventListener('pointercancel',onUp);
      });
      th.appendChild(grip);

      tr.appendChild(th);
    });
  };

  /* Apply a dragged column width without a full re-render - rebuilding every
     row on each pointermove would make the drag crawl on a large table. */
  TableEngine.prototype._setColWidth = function(field,px){
    var w=Math.round(px)+'px';
    this.colWidths[field]=w;
    this._applyColWidthDom(field,w);
  };

  /* Write a width onto the header and every rendered cell of one column (no re-render). */
  TableEngine.prototype._applyColWidthDom = function(field,w){
    var idx=this._visibleCols().findIndex(function(c){return c.field===field;});
    if(idx<0)return;
    if(this.multiSelect)idx+=1;
    var head=document.getElementById('thead-'+this.id);
    if(head&&head.children[idx]){
      head.children[idx].style.width=w;
      head.children[idx].style.maxWidth=w;
    }
    var tbody=document.getElementById('tbody-'+this.id);
    if(!tbody)return;
    var rows=tbody.rows;
    for(var r=0;r<rows.length;r++){
      var cell=rows[r].cells[idx];
      if(cell){cell.style.width=w;cell.style.maxWidth=w;}
    }
  };

  /* Build one <tr> for a data row. Extracted from _renderBody so both the
     paginated path and the virtualised (non-pageable) path produce identical
     rows. globalIdx is the row's index in allData (used for selection/links). */
  TableEngine.prototype._buildRow = function(row, globalIdx){
    var self=this; var visCols=this._visibleCols();
    var tr=document.createElement('tr'); tr.dataset.idx=globalIdx;

    /* Row highlight */
    this.columns.forEach(function(col){
      if(col.rowHighlight){
        var cls=getThresholdClass(col,row[col.field]);
        if(cls)tr.classList.add('row-hl-'+cls.replace('cell-',''));
      }
    });

    if(this.selected.indexOf(globalIdx)!==-1)tr.classList.add('row-selected');
    if(this.multiSelect)tr.setAttribute('aria-selected',tr.classList.contains('row-selected')?'true':'false');

    tr.addEventListener('click',function(e){
      if(e.target.type==='checkbox')return;
      if(e.target.closest&&e.target.closest('a'))return;   /* a link cell opens its link, not the drawer */
      self._handleRowClick(globalIdx,row,tr);
    });
    if(this.detail){
      /* v2.3.0 - keyboard access to the drawer */
      tr.classList.add('dh-drawer-row');tr.tabIndex=0;
      tr.addEventListener('keydown',function(e){
        if(e.target!==tr)return;
        if(e.key==='Enter'||e.key===' '){e.preventDefault();self._handleRowClick(globalIdx,row,tr);}
      });
    }

    if(this.multiSelect){
      var tdChk=document.createElement('td');tdChk.className='col-select';
      var chk=document.createElement('input');chk.type='checkbox';chk.setAttribute('aria-label','Select row '+(globalIdx+1));
      chk.checked=this.selected.indexOf(globalIdx)!==-1;
      chk.addEventListener('change',function(){
        if(chk.checked){if(self.selected.indexOf(globalIdx)===-1)self.selected.push(globalIdx);}
        else{self.selected=self.selected.filter(function(i){return i!==globalIdx;});}
        self._syncRowClass(tr,globalIdx);self._renderInfo();self._renderSelClearBtn();self._renderFoot();
      });
      tdChk.appendChild(chk);tr.appendChild(tdChk);
    }

    visCols.forEach(function(col){tr.appendChild(self._renderCell(col,row[col.field],row));});
    var bs=this.base&&this._baseState.get(row);
    if(bs){
      tr.classList.add(bs.s==='n'?'row-new':'row-changed');
      var off=this.multiSelect?1:0, first=tr.cells[off];
      if(first){
        var tag=document.createElement('span');
        tag.className='chg-tag '+(bs.s==='n'?'chg-new':'chg-changed');
        tag.textContent=bs.s==='n'?'New':'Changed';
        first.insertBefore(tag,first.firstChild);
      }
      if(bs.s==='c'){
        visCols.forEach(function(col,i){
          if(bs.f.indexOf(col.field)===-1)return;
          var td=tr.cells[off+i]; if(!td)return;
          td.classList.add('cell-changed');
          td.dataset.was=dhWasText(col,bs.w[col.field],FMT.apply);
          td.title=(td.title?td.title+' \u2014 ':'')+td.dataset.was;
        });
      }
    }
    return tr;
  };

  /* v1.7.0 — row virtualisation threshold. Only the non-pageable path (which now
     shows ALL rows) windows the DOM; below this count it renders plainly. */
  var VIRTUALISE_ABOVE = 150;

  TableEngine.prototype._renderBody = function(){
    var tbody=document.getElementById('tbody-'+this.id);
    if(!tbody)return;
    var filtered=this._getFiltered();
    var self=this;var visCols=this._visibleCols();
    var colSpan=visCols.length+(this.multiSelect?1:0);

    /* Update nav badge with current filtered count */
    var navBadge=document.querySelector('.nav-badge[data-table="'+this.id+'"]');
    if(navBadge) navBadge.textContent=filtered.length;
    updateNavBadge(this.id);

    if(filtered.length===0){
      this._teardownVirtual();
      tbody.innerHTML='';
      var tr=document.createElement('tr');var td=document.createElement('td');
      td.colSpan=colSpan;td.className='no-data';
      td.textContent='No matching records found.';tr.appendChild(td);tbody.appendChild(tr);return;
    }

    /* v2.2.0 — print path: the first _printRows filtered rows, plainly, no
       pages and no virtual window (a printout cannot scroll). Set and cleared
       by the beforeprint / afterprint handlers in the print module. */
    if(this._printRows){
      this._teardownVirtual();
      tbody.innerHTML='';
      filtered.slice(0,this._printRows).forEach(function(row){
        tbody.appendChild(self._buildRow(row, self._idxOf(row)));
      });
      return;
    }

    /* Paginated path (default) — unchanged: render only the current page. */
    if(this.pageable){
      this._teardownVirtual();
      tbody.innerHTML='';
      var start=(this.currentPage-1)*this.pageSize;
      filtered.slice(start,start+this.pageSize).forEach(function(row){
        tbody.appendChild(self._buildRow(row, self._idxOf(row)));
      });
      return;
    }

    /* Non-pageable path — render ALL rows. Small tables render plainly;
       large ones are virtualised so the DOM only holds the visible window.
       (Before v1.7.0 this path incorrectly showed only pageSize rows.) */
    if(filtered.length<=VIRTUALISE_ABOVE){
      this._teardownVirtual();
      tbody.innerHTML='';
      filtered.forEach(function(row){ tbody.appendChild(self._buildRow(row, self._idxOf(row))); });
      return;
    }
    this._renderVirtual(filtered, colSpan);
  };

  /* Virtualised body for a large non-pageable table. Renders only the rows near
     the scroll viewport, padded by top/bottom spacer <tr>s sized to preserve the
     scrollbar geometry. Row height is measured once from a real row. */
  TableEngine.prototype._renderVirtual = function(filtered, colSpan){
    var self=this;
    var tbody=document.getElementById('tbody-'+this.id);
    var wrapper=document.getElementById('tbl-'+this.id).closest('.table-wrapper');
    if(!wrapper){ /* no scroll container — fall back to rendering all */
      tbody.innerHTML='';
      filtered.forEach(function(row){ tbody.appendChild(self._buildRow(row, self._idxOf(row))); });
      return;
    }
    wrapper.classList.add('table-virtual');

    /* Measure a representative row height once. */
    tbody.innerHTML='';
    var probe=this._buildRow(filtered[0], this._idxOf(filtered[0]));
    tbody.appendChild(probe);
    var rowH=probe.getBoundingClientRect().height||34;

    function spacer(){
      var tr=document.createElement('tr');tr.className='virt-spacer';
      var td=document.createElement('td');td.colSpan=colSpan;
      tr.appendChild(td);return tr;
    }
    var topSpacer=spacer(), botSpacer=spacer();

    function renderWindow(){
      var scrollTop=wrapper.scrollTop;
      var vpH=wrapper.clientHeight||400;
      var buffer=8;
      var first=Math.max(0, Math.floor(scrollTop/rowH)-buffer);
      var count=Math.ceil(vpH/rowH)+buffer*2;
      var last=Math.min(filtered.length, first+count);
      topSpacer.firstChild.style.height=(first*rowH)+'px';
      botSpacer.firstChild.style.height=((filtered.length-last)*rowH)+'px';
      tbody.innerHTML='';
      tbody.appendChild(topSpacer);
      for(var i=first;i<last;i++){ tbody.appendChild(self._buildRow(filtered[i], self._idxOf(filtered[i]))); }
      tbody.appendChild(botSpacer);
    }

    var ticking=false;
    this._teardownVirtual();   /* clear any previous handler before wiring a new one */
    this._virtScrollHandler=function(){
      if(ticking)return; ticking=true;
      requestAnimationFrame(function(){ renderWindow(); ticking=false; });
    };
    this._virtWrapper=wrapper;
    wrapper.addEventListener('scroll', this._virtScrollHandler);
    renderWindow();
  };

  TableEngine.prototype._teardownVirtual = function(){
    if(this._virtWrapper && this._virtScrollHandler){
      this._virtWrapper.removeEventListener('scroll', this._virtScrollHandler);
      this._virtWrapper.classList.remove('table-virtual');
    }
    this._virtWrapper=null; this._virtScrollHandler=null;
  };

  TableEngine.prototype._handleRowClick=function(globalIdx,row,tr){
    if(this.multiSelect){
      var pos=this.selected.indexOf(globalIdx);
      if(pos===-1)this.selected.push(globalIdx);else this.selected.splice(pos,1);
      this._syncRowClass(tr,globalIdx);this._renderInfo();this._renderSelClearBtn();this._renderFoot();
      this._notifyLinks(this.selected.length>0?this.allData[this.selected[0]]:null);
    } else {
      if(this.selected.length===1&&this.selected[0]===globalIdx){this.selected=[];this._notifyLinks(null);}
      else{this.selected=[globalIdx];this._notifyLinks(row);}
      this.render();
    }
    if(this.detail)this._openDetail(globalIdx,row,tr);
  };

  /* v2.3.0 - the row's properties as label/value tiles in the shared drawer.
     The row <tr> is re-created by render(), so focus goes back to it by selector. */
  TableEngine.prototype._openDetail=function(globalIdx,row,tr){
    var d=this.detail; if(!d||typeof dhDrawerOpen!=='function')return;
    function fmt(v){
      if(v===null||v===undefined)return '';
      if(Array.isArray(v))return v.join(', ');
      if(typeof v==='object'){try{return JSON.stringify(v);}catch(ex){return String(v);}}
      return String(v);
    }
    var title=d.titleField?fmt(row[d.titleField]):'';
    /* v2.6.0 - a link column's value is the same link in the panel */
    var self=this, linkCol={};
    this.columns.forEach(function(c){ if(c.cellType==='link')linkCol[c.field]=c; });
    dhDrawerOpen({
      title:title||this.title,
      subtitle:title?this.title:'',
      sections:[{kind:'kv',columns:2,items:d.fields.map(function(f){
        var it={label:f.label,value:fmt(row[f.field])}, c=linkCol[f.field];
        var lk=c?self._linkFor(c,row,row[f.field]):null;
        if(lk){ it._link=lk.url; it._newTab=lk.newTab; if(c.linkText)it.value=c.linkText; else if(!it.value)it.value=lk.url; }
        return it;
      })}]
    },{opener:tr,restore:'#tbody-'+this.id+' tr[data-idx="'+globalIdx+'"]'});
  };

  /* v2.6.0 - the link of a CellType='link' cell: { url, newTab }, or null when the value must stay text.
     A template is author-written, so a relative template is allowed; a data value is relative only
     with RelativeLinks = $true (a link column holding "N/A" must not become a link to ./N/A). */
  TableEngine.prototype._linkFor=function(col,row,rawVal){
    var url;
    if(col.urlTemplate){ url=dhLinkUrl(dhLinkFill(col.urlTemplate,row),true); }
    else { url=dhLinkUrl(row&&col.urlField?row[col.urlField]:rawVal,!!col.relativeLinks); }
    return url?{url:url,newTab:dhLinkNewTab(url,col.linkTarget||'')}:null;
  };

  TableEngine.prototype._notifyLinks=function(masterRow){
    var self=this;
    this.outLinks.forEach(function(link){
      var det=engines[link.detailTableId];if(!det)return;
      det.applyLinkedFilter(link.detailField,masterRow!==null?masterRow[link.masterField]:null,self.title);
    });
  };

  /* After linked filter is applied, refresh bar charts referencing the detail table */
  TableEngine.prototype.applyLinkedFilter = (function(_orig){
    return function(field, value, masterTitle) {
      _orig.call(this, field, value, masterTitle);
      this._refreshLinkedBarCharts();
    };
  })(TableEngine.prototype.applyLinkedFilter);

  TableEngine.prototype._syncRowClass=function(tr,globalIdx){
    var on=this.selected.indexOf(globalIdx)!==-1;
    tr.classList.toggle('row-selected',on);
    if(this.multiSelect)tr.setAttribute('aria-selected',on?'true':'false');   /* grid rows announce their selection */
  };

  /* ── Pagination ─────────────────────────────────────────────────── */
  TableEngine.prototype._renderPaging=function(){
    var container=document.getElementById('paging-'+this.id);
    if(!container||!this.pageable)return;
    var filtered=this._getFiltered();
    var totalPages=Math.max(1,Math.ceil(filtered.length/this.pageSize));
    var self=this;container.innerHTML='';if(totalPages<=1)return;
    function mkBtn(label,page,disabled,active){
      var b=document.createElement('button');
      b.className='page-btn'+(active?' page-active':'');
      b.textContent=label;b.disabled=disabled;
      b.addEventListener('click',function(){if(!disabled){self.currentPage=page;self.render();self._saveLinkState();}});
      return b;
    }
    container.appendChild(mkBtn('\u00AB',1,self.currentPage===1,false));
    container.appendChild(mkBtn('\u2039',self.currentPage-1,self.currentPage===1,false));
    var start=Math.max(1,self.currentPage-2),end=Math.min(totalPages,start+4);
    start=Math.max(1,end-4);
    if(start>1){container.appendChild(mkBtn('1',1,false,false));if(start>2){var e1=document.createElement('span');e1.className='page-ellipsis';e1.textContent='\u2026';container.appendChild(e1);}}
    for(var p=start;p<=end;p++)container.appendChild(mkBtn(String(p),p,false,p===self.currentPage));
    if(end<totalPages){if(end<totalPages-1){var e2=document.createElement('span');e2.className='page-ellipsis';e2.textContent='\u2026';container.appendChild(e2);}container.appendChild(mkBtn(String(totalPages),totalPages,false,false));}
    container.appendChild(mkBtn('\u203A',self.currentPage+1,self.currentPage===totalPages,false));
    container.appendChild(mkBtn('\u00BB',totalPages,self.currentPage===totalPages,false));
  };

  TableEngine.prototype._renderInfo=function(){
    var el=document.getElementById('info-'+this.id);if(!el)return;
    var filtered=this._getFiltered();
    var total=this.allData.length,shown=filtered.length;
    var start=(this.currentPage-1)*this.pageSize+1;
    var end=Math.min(start+this.pageSize-1,shown);
    var text=shown<total?(start+'\u2013'+end+' of '+shown+' (filtered from '+total+')'):(start+'\u2013'+end+' of '+total);
    if(this.selected.length>0)text+='  \u2014  '+this.selected.length+' selected';
    el.textContent=text;
  };

  TableEngine.prototype._renderSelClearBtn=function(){
    var btn=document.getElementById('clear-sel-'+this.id);
    if(btn)btn.style.display=this.selected.length>0?'inline-flex':'none';
  };

  /* ── Per-table Pie Charts (Add-DhTable -Charts) ─────────────────────
        Delegates SVG generation to the shared chartPalette() / buildPieSvg()
        helpers so the standalone Add-DhPieChart and the per-table chart
        stay visually consistent. */
  TableEngine.prototype._chartPalette = function () { return chartPalette(); };

  TableEngine.prototype._renderCharts = function () {
    if (!this.charts || !this.charts.length) return;
    var container = document.getElementById('charts-' + this.id);
    if (!container) return;
    container.innerHTML = '';
    var self = this;
    /* v2.1.4 - 'pie' draws solid, 'donut' (the default) draws a donut.
       v2.2.0 - 'bar' draws through the shared aggregateBars / buildBarHtml.
       Add-DhTable validates Type and drops anything else with a warning. */
    this.charts.forEach(function (chart) {
      var t = (chart.type || 'donut').toLowerCase();
      if (t === 'pie' || t === 'donut') {
        container.appendChild(self._buildPieChart(chart, t));
      } else if (t === 'bar') {
        container.appendChild(self._buildBarChart(chart));
      }
    });
  };

  /* v2.2.0 — a bar chart inside the table's chart strip. Same aggregation
     as Add-DhBarChart, over this table's filtered rows. */
  TableEngine.prototype._buildBarChart = function (chart) {
    var opts = { valueField: chart.valueField, aggregate: chart.aggregate, topN: chart.topN || 10,
                 unit: chart.unit, decimals: chart.decimals, showCount: true, showPercent: false, clickable: false };
    var agg = aggregateBars(this._getFiltered(), chart.field, opts);
    opts.total = agg.total;
    var panel = document.createElement('div');
    panel.className = 'chart-panel chart-panel-bar';
    var title = chart.title || chart.field;
    panel.innerHTML = (title ? '<div class="chart-title">'+esc(title)+'</div>' : '')+
      (agg.entries.length
        ? '<div class="bar-chart">'+buildBarHtml(agg.entries, opts)+'</div>'
        : '<div class="chart-body chart-empty">No data</div>');
    return panel;
  };

  TableEngine.prototype._buildPieChart = function (chart, style) {
    var palette = chartPalette();
    var counts = {};
    this._getFiltered().forEach(function (row) {
      var v = (row[chart.field] != null) ? String(row[chart.field]) : '(empty)';
      counts[v] = (counts[v] || 0) + 1;
    });
    var entries = Object.keys(counts).map(function (k, i) {
      return { label: k, count: counts[k], color: palette[i % palette.length] };
    }).sort(function (a, b) { return b.count - a.count; });
    return buildPieSvg(entries, {
      style:      style === 'pie' ? 'pie' : 'donut',
      title:      chart.title || chart.field,
      showTotal:  true,
      showLegend: true
    });
  };

  /* ── Export ─────────────────────────────────────────────────────── */
  TableEngine.prototype._triggerDownload=function(url,filename){
    var a=document.createElement('a');a.href=url;a.download=filename;
    document.body.appendChild(a);a.click();document.body.removeChild(a);
    if(url.startsWith('blob:'))setTimeout(function(){URL.revokeObjectURL(url);},2000);
  };
  TableEngine.prototype._exportRows=function(){
    var cols=this._visibleCols(),rows=this._getFiltered();
    if(!this.base)return{cols:cols,rows:rows};
    /* baseline: a Change column; the removed rows only when the reader ticked the box */
    var self=this;
    cols=cols.concat([{field:'__change',label:'Change'}]);
    rows=rows.map(function(row){var s=self._baseState.get(row);return Object.assign({},row,{__change:s?(s.s==='n'?'New':'Changed'):''});});
    if(this._includeRemoved)this.base.removedRows.forEach(function(r){rows.push(Object.assign({},r,{__change:'Removed'}));});
    return{cols:cols,rows:rows};
  };

  TableEngine.prototype.exportCsv=function(){
    var r=this._exportRows(),BOM='\uFEFF';
    var lines=[r.cols.map(function(c){return'"'+c.label.replace(/"/g,'""')+'"';}).join(',')];
    r.rows.forEach(function(row){lines.push(r.cols.map(function(c){var v=dhCsvSafe(FMT.forExport(c,row[c.field]));return'"'+v.replace(/"/g,'""')+'"';}).join(','));});
    this._triggerDownload(URL.createObjectURL(new Blob([BOM+lines.join('\r\n')],{type:'text/csv;charset=utf-8;'})),this.exportFileName+'.csv');
  };

  /* v2.2.0 — the library is loaded on demand (see loadExportLib); a failure
     disables the button with a tooltip instead of raising an alert(). */
  TableEngine.prototype.exportExcel=function(){
    var self=this;
    setExportBusy('xlsx',true);
    loadExportLib('xlsx').then(function(){ setExportBusy('xlsx',false); self._writeExcel(); },
                               function(){ setExportBusy('xlsx',false); markExportUnavailable('xlsx'); });
  };

  TableEngine.prototype._writeExcel=function(){
    var r=this._exportRows();
    var aoa=[r.cols.map(function(c){return c.label;})];
    r.rows.forEach(function(row){aoa.push(r.cols.map(function(c){
      var raw=row[c.field],fmt=(c.format||'').toLowerCase();
      if(fmt==='number'||fmt==='currency'||fmt==='percent'){var n=parseFloat(raw);return isNaN(n)?FMT.apply(c,raw):n;}
      return FMT.forExport(c,raw);
    }));});
    var ws=XLSX.utils.aoa_to_sheet(aoa);
    ws['!cols']=r.cols.map(function(c){var max=c.label.length;r.rows.forEach(function(row){var v=String(FMT.apply(c,row[c.field])||'');if(v.length>max)max=v.length;});return{wch:Math.min(max+2,60)};});
    ws['!freeze']={xSplit:0,ySplit:1};
    /* Excel sheet names: max 31 chars, may not contain  : \ / ? * [ ]  and may
       not be blank — an invalid name makes book_append_sheet throw and the whole
       export silently fails. Sanitise, then fall back to 'Sheet1'. */
    var sheetName=String(this.title||'').replace(/[:\\\/?*\[\]]/g,' ').replace(/\s+/g,' ').trim().substring(0,31);
    if(!sheetName)sheetName='Sheet1';
    var wb=XLSX.utils.book_new();XLSX.utils.book_append_sheet(wb,ws,sheetName);
    XLSX.writeFile(wb,this.exportFileName+'.xlsx');
  };

  TableEngine.prototype.exportPdf=function(){
    var self=this;
    setExportBusy('pdf',true);
    loadPdfLibs().then(function(){ setExportBusy('pdf',false); self._writePdf(); },
                       function(){ setExportBusy('pdf',false); markExportUnavailable('pdf'); });
  };

  TableEngine.prototype._writePdf=function(){
    var JsPDF=window.jsPDF||(window.jspdf&&window.jspdf.jsPDF);
    var r=this._exportRows();
    var orient=(r.cols.length>6||r.rows.length>30)?'landscape':'portrait';
    var doc=new JsPDF({orientation:orient,unit:'mm',format:'a4'});
    doc.setFontSize(15);doc.setTextColor(0,119,204);doc.text(this.title,14,16);
    doc.setFontSize(8);doc.setTextColor(100,110,130);doc.text('Rows: '+r.rows.length+'  |  '+new Date().toLocaleString(),14,22);
    var colStyles={};
    r.cols.forEach(function(col,i){var align=(col.align||'left').toLowerCase();if(align==='right'||align==='center')colStyles[i]={halign:align};});
    doc.autoTable({head:[r.cols.map(function(c){return c.label;})],
      body:r.rows.map(function(row){return r.cols.map(function(c){var v=FMT.apply(c,row[c.field]);return(v!==null&&v!==undefined)?String(v):'';});}),
      startY:27,columnStyles:colStyles,
      styles:{fontSize:8,cellPadding:2,overflow:'ellipsize',font:'helvetica'},
      headStyles:{fillColor:[0,77,153],textColor:255,fontStyle:'bold',halign:'left'},
      alternateRowStyles:{fillColor:[240,245,252]},margin:{left:14,right:14}});
    var pageCount=doc.internal.getNumberOfPages();
    for(var i=1;i<=pageCount;i++){doc.setPage(i);doc.setFontSize(7);doc.setTextColor(160,160,180);doc.text('Page '+i+' of '+pageCount,doc.internal.pageSize.getWidth()-14,doc.internal.pageSize.getHeight()-6,{align:'right'});}
    doc.save(this.exportFileName+'.pdf');
  };

'@
}
