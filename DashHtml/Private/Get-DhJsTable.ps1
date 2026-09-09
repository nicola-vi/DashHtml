function Get-DhJsTable {
    # Auto-split fragment of the dashboard runtime JS (see Get-DhJsContent).
    return @'
  /* =========================================================================
     TABLE ENGINE
     ========================================================================= */
  function TableEngine(cfg) {
    this.id          = cfg.id;
    this.title       = cfg.title||cfg.id;
    this.allData     = cfg.data.slice();
    this.columns     = cfg.columns;
    this.pageSize    = cfg.pageSize||15;
    this.multiSelect = cfg.multiSelect||false;
    this.filterable  = cfg.filterable!==false;
    this.pageable    = cfg.pageable!==false;
    this.outLinks    = cfg.outLinks||[];
    this.charts      = cfg.charts||[];

    this.currentPage   = 1;
    this.sortFields    = [];   /* [{field, dir}] — multi-sort */
    this.filterText    = '';
    this.linkedFilter  = null;
    this.selected      = [];
    this.colVisible    = {};
    this.columns.forEach(function(col,i){this.colVisible[i]=true;},this);
    /* Per-field width overrides set by dragging a header edge. Empty until the
       user resizes something; the declared col.width stays the default. */
    this.colWidths     = {};

    this.exportFileName = cfg.exportFileName || cfg.id;
    this._initPageSizes();
    this._bindFilter();
    this._bindClearSel();
    this._bindLinkClear();
    this._bindExport();
    this._buildColToggle();
    this._renderCharts();
    this._bindRightClick();
    this.render();
  }

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
    sel.addEventListener('change',function(){self.pageSize=parseInt(sel.value,10);self.currentPage=1;self.render();});
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

    /* Custom context menu element — created once and reused */
    var ctxMenu = document.createElement('div');
    ctxMenu.className = 'ctx-menu';
    ctxMenu.style.display = 'none';
    ctxMenu.innerHTML =
      '<div class="ctx-item" id="ctx-copy-cell">&#128203; Copy cell value</div>' +
      '<div class="ctx-item" id="ctx-copy-csv">&#128190; Copy table as CSV</div>';
    document.body.appendChild(ctxMenu);

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
    ctxMenu.querySelector('#ctx-copy-cell').addEventListener('click', function() {
      if (!targetTd) return;
      var text = (targetTd.textContent || targetTd.innerText || '').trim();
      if (text && navigator.clipboard) {
        navigator.clipboard.writeText(text).then(function() {
          targetTd.classList.add('cell-copied');
          setTimeout(function(){ targetTd.classList.remove('cell-copied'); }, 600);
        });
      }
      closeMenu();
    });

    /* Copy entire filtered table as CSV */
    ctxMenu.querySelector('#ctx-copy-csv').addEventListener('click', function() {
      var r    = self._exportRows();
      var BOM  = '';
      var lines = [r.cols.map(function(c){ return '"'+c.label.replace(/"/g,'""')+'"'; }).join(',')];
      r.rows.forEach(function(row){
        lines.push(r.cols.map(function(c){
          var v = FMT.forExport(c, row[c.field]);
          v = (v !== null && v !== undefined) ? String(v) : '';
          return '"'+v.replace(/"/g,'""')+'"';
        }).join(','));
      });
      var csv = lines.join('\r\n');
      if (navigator.clipboard) {
        navigator.clipboard.writeText(csv).then(function(){
          /* Brief visual feedback on the table */
          var tbl = document.getElementById('tbl-'+self.id);
          if (tbl) {
            tbl.classList.add('table-copied');
            setTimeout(function(){ tbl.classList.remove('table-copied'); }, 800);
          }
        });
      }
      closeMenu();
    });
  };

  /* ── Column visibility toggle ───────────────────────────────────── */
  TableEngine.prototype._buildColToggle = function () {
    var btn=document.getElementById('btn-col-toggle-'+this.id);
    var dd=document.getElementById('col-toggle-dd-'+this.id);
    if(!btn||!dd) return;
    var self=this;
    this.columns.forEach(function(col,i){
      var row=document.createElement('label');
      row.className='col-toggle-item';
      var chk=document.createElement('input');
      chk.type='checkbox';chk.checked=true;
      chk.addEventListener('change',function(){self.colVisible[i]=chk.checked;self.render();});
      row.appendChild(chk);
      row.appendChild(document.createTextNode(' '+col.label));
      dd.appendChild(row);
    });
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
    } else {badge.style.display='none';}
  };

  /* ── Data pipeline — multi-sort + card filters ──────────────────── */
  TableEngine.prototype._getFiltered = function () {
    var data=this.allData;var self=this;

    if (self.linkedFilter) {
      var lf=self.linkedFilter;
      data=data.filter(function(row){return String(row[lf.field])===lf.value;});
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

    if (self.filterText) {
      var term=self.filterText.toLowerCase();
      data=data.filter(function(row){
        return self._visibleCols().some(function(col){
          var v=row[col.field];if(v===null||v===undefined)return false;
          return String(v).toLowerCase().indexOf(term)!==-1||
                 FMT.apply(col,v).toLowerCase().indexOf(term)!==-1;
        });
      });
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
  TableEngine.prototype._renderCell = function (col,rawVal) {
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
    } else {
      td.textContent=dispVal;
    }

    /* Width: a dragged override wins over the author's declared width. Without
       this the cell falls back to the .data-table td max-width, so a column
       declared wider than that silently clipped anyway. */
    var effW = (this.colWidths && this.colWidths[col.field]) || col.width;
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
    this._markTruncated();
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
      if(td.scrollWidth>td.clientWidth+1){
        td.title=td.dataset.full;
        td.classList.add('cell-clipped');
      } else {
        td.removeAttribute('title');
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

    var filtered = this._getFiltered();
    var tfoot = document.createElement('tfoot');
    var tr    = document.createElement('tr');
    tr.className = 'tfoot-row';

    if (this.multiSelect) {
      var tdBlank = document.createElement('td'); tdBlank.className = 'col-select';
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

      var nums = filtered.map(function(row){
        var v = parseFloat(row[col.field]);
        return isNaN(v) ? null : v;
      }).filter(function(v){ return v !== null; });

      var result = null;
      switch (agg) {
        case 'sum':   result = nums.reduce(function(a,b){return a+b;}, 0); break;
        case 'avg':   result = nums.length ? nums.reduce(function(a,b){return a+b;},0)/nums.length : null; break;
        case 'min':   result = nums.length ? Math.min.apply(null, nums) : null; break;
        case 'max':   result = nums.length ? Math.max.apply(null, nums) : null; break;
        case 'count': result = filtered.length; break;
      }

      if (result !== null) {
        var displayVal = FMT.apply(col, result) || String(result);
        td.textContent = displayVal;
        td.title = agg.charAt(0).toUpperCase()+agg.slice(1)+': '+displayVal;
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
      th.innerHTML='<input type="checkbox" id="chk-all-'+this.id+'">';
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
          var idx=self.allData.indexOf(row);
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
      var effW=self.colWidths[col.field]||col.width;
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
          self.currentPage=1;self.render();
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
      grip.title='Drag to resize · double-click to reset';
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
        delete self.colWidths[col.field];self.render();
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

    tr.addEventListener('click',function(e){
      if(e.target.type==='checkbox')return;
      self._handleRowClick(globalIdx,row,tr);
    });

    if(this.multiSelect){
      var tdChk=document.createElement('td');tdChk.className='col-select';
      var chk=document.createElement('input');chk.type='checkbox';
      chk.checked=this.selected.indexOf(globalIdx)!==-1;
      chk.addEventListener('change',function(){
        if(chk.checked){if(self.selected.indexOf(globalIdx)===-1)self.selected.push(globalIdx);}
        else{self.selected=self.selected.filter(function(i){return i!==globalIdx;});}
        self._syncRowClass(tr,globalIdx);self._renderInfo();self._renderSelClearBtn();
      });
      tdChk.appendChild(chk);tr.appendChild(tdChk);
    }

    visCols.forEach(function(col){tr.appendChild(self._renderCell(col,row[col.field]));});
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

    /* Paginated path (default) — unchanged: render only the current page. */
    if(this.pageable){
      this._teardownVirtual();
      tbody.innerHTML='';
      var start=(this.currentPage-1)*this.pageSize;
      filtered.slice(start,start+this.pageSize).forEach(function(row){
        tbody.appendChild(self._buildRow(row, self.allData.indexOf(row)));
      });
      return;
    }

    /* Non-pageable path — render ALL rows. Small tables render plainly;
       large ones are virtualised so the DOM only holds the visible window.
       (Before v1.7.0 this path incorrectly showed only pageSize rows.) */
    if(filtered.length<=VIRTUALISE_ABOVE){
      this._teardownVirtual();
      tbody.innerHTML='';
      filtered.forEach(function(row){ tbody.appendChild(self._buildRow(row, self.allData.indexOf(row))); });
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
      filtered.forEach(function(row){ tbody.appendChild(self._buildRow(row, self.allData.indexOf(row))); });
      return;
    }
    wrapper.classList.add('table-virtual');

    /* Measure a representative row height once. */
    tbody.innerHTML='';
    var probe=this._buildRow(filtered[0], this.allData.indexOf(filtered[0]));
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
      for(var i=first;i<last;i++){ tbody.appendChild(self._buildRow(filtered[i], self.allData.indexOf(filtered[i]))); }
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
      this._syncRowClass(tr,globalIdx);this._renderInfo();this._renderSelClearBtn();
      this._notifyLinks(this.selected.length>0?this.allData[this.selected[0]]:null);
    } else {
      if(this.selected.length===1&&this.selected[0]===globalIdx){this.selected=[];this._notifyLinks(null);}
      else{this.selected=[globalIdx];this._notifyLinks(row);}
      this.render();
    }
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
    if(this.selected.indexOf(globalIdx)!==-1)tr.classList.add('row-selected');
    else tr.classList.remove('row-selected');
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
      b.addEventListener('click',function(){if(!disabled){self.currentPage=page;self.render();}});
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
    this.charts.forEach(function (chart) {
      if ((chart.type || 'pie').toLowerCase() === 'pie') {
        container.appendChild(self._buildPieChart(chart));
      }
    });
  };

  TableEngine.prototype._buildPieChart = function (chart) {
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
      style:      'donut',
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
  TableEngine.prototype._exportRows=function(){return{cols:this._visibleCols(),rows:this._getFiltered()};};

  TableEngine.prototype.exportCsv=function(){
    var r=this._exportRows(),BOM='\uFEFF';
    var lines=[r.cols.map(function(c){return'"'+c.label.replace(/"/g,'""')+'"';}).join(',')];
    r.rows.forEach(function(row){lines.push(r.cols.map(function(c){var v=FMT.forExport(c,row[c.field]);v=(v!==null&&v!==undefined)?String(v):'';return'"'+v.replace(/"/g,'""')+'"';}).join(','));});
    this._triggerDownload(URL.createObjectURL(new Blob([BOM+lines.join('\r\n')],{type:'text/csv;charset=utf-8;'})),this.id+'.csv');
  };

  TableEngine.prototype.exportExcel=function(){
    if(typeof XLSX==='undefined'){alert('SheetJS did not load. Internet required for XLSX export.');return;}
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
    var JsPDF=(typeof window.jsPDF!=='undefined')?window.jsPDF:(typeof jspdf!=='undefined'&&jspdf.jsPDF)?jspdf.jsPDF:null;
    if(!JsPDF){alert('jsPDF did not load.\nInternet access required (cdnjs.cloudflare.com).');return;}
    var _test=new JsPDF();
    if(typeof _test.autoTable!=='function'){alert('jsPDF-AutoTable did not load.\nInternet access required (cdnjs.cloudflare.com).\nTry reloading the page.');return;}
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
