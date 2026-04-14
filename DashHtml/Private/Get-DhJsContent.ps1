function Get-DhJsContent {
    <#
    .SYNOPSIS  Full client-side JS engine (version follows module manifest)
    .NOTES     Single-quoted here-string — no PS interpolation.
               Placeholders replaced by Export-DhDashboard before writing.
    #>
    return @'
(function () {
  'use strict';

  /* =========================================================================
     INJECTED CONFIG
     ========================================================================= */
  var TABLES_CONFIG  = /*%%TABLES_CONFIG%%*/[];
  var SUMMARY_CONFIG = /*%%SUMMARY_CONFIG%%*/[];
  var BLOCKS_CONFIG  = /*%%BLOCKS_CONFIG%%*/[];

  /* =========================================================================
     GLOBAL STATE
     ========================================================================= */
  var engines       = {};        /* tableId -> TableEngine */
  var cardFilters   = {};        /* filterId -> { field, values[] } */
  var currentTheme  = 'default'; /* 'default' or 'light' */
  var tableDensity  = 'normal';  /* 'compact' | 'normal' | 'comfortable' */
  var currentGroup  = '';        /* active nav group in two-tier mode */

  /* esc() — HTML-encode a value before inserting into innerHTML.
     Prevents XSS when data originates from external sources (Azure tags, resource names, etc.) */
  function esc(s) {
    if (s == null) return '';
    return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  }

  /* =========================================================================
     URL STATE  — encode active panel + card filters + text filters in hash
     ========================================================================= */
  var URLState = {
    _debounce: null,
    save: function () {
      clearTimeout(this._debounce);
      var self = this;
      this._debounce = setTimeout(function () { self._write(); }, 300);
    },
    _write: function () {
      try {
        var state = {};
        /* active group (two-tier mode) */
        if (currentGroup) state.group = currentGroup;
        /* active panel */
        var activeLink = document.querySelector('.nav-link.nav-active');
        if (activeLink) state.panel = activeLink.dataset.table || activeLink.dataset.panel;
        /* text filters per table */
        var filters = {};
        Object.keys(engines).forEach(function (id) {
          if (engines[id].filterText) filters[id] = engines[id].filterText;
        });
        if (Object.keys(filters).length) state.filters = filters;
        /* card filters */
        if (Object.keys(cardFilters).length) state.cardFilters = cardFilters;
        /* density */
        if (tableDensity !== 'normal') state.density = tableDensity;
        history.replaceState(null, '', '#' + encodeURIComponent(JSON.stringify(state)));
      } catch(e) {}
    },
    load: function () {
      try {
        var raw = decodeURIComponent((location.hash || '').replace('#',''));
        if (!raw || raw[0] !== '{') return {};
        return JSON.parse(raw);
      } catch(e) { return {}; }
    }
  };

  /* =========================================================================
     FORMATTING ENGINE
     ========================================================================= */
  var FMT = {
    apply: function (col, rawVal) {
      if (rawVal === null || rawVal === undefined || rawVal === '') return '';
      var str = String(rawVal);
      var fmt = (col.format || '').toLowerCase();
      if (!fmt || fmt === 'text') return str;
      var locale   = col.locale   || undefined;
      var decimals = (col.decimals !== undefined && col.decimals >= 0) ? col.decimals : undefined;
      switch (fmt) {
        case 'number': {
          var n = parseFloat(str); if (isNaN(n)) return str;
          var o = decimals !== undefined ? {minimumFractionDigits:decimals,maximumFractionDigits:decimals} : {};
          return new Intl.NumberFormat(locale, o).format(n);
        }
        case 'currency': {
          var n = parseFloat(str); if (isNaN(n)) return str;
          return new Intl.NumberFormat(locale, {style:'currency',currency:col.currency||'EUR',
            minimumFractionDigits:decimals!==undefined?decimals:2,maximumFractionDigits:decimals!==undefined?decimals:2}).format(n);
        }
        case 'bytes': {
          var n = parseFloat(str); if (isNaN(n)) return str;
          var u=['B','KB','MB','GB','TB','PB'], i=0;
          while (n>=1024&&i<u.length-1){n/=1024;i++;}
          var dp=decimals!==undefined?decimals:(i===0?0:2);
          return new Intl.NumberFormat(locale,{minimumFractionDigits:dp,maximumFractionDigits:dp}).format(n)+' '+u[i];
        }
        case 'percent': {
          var n = parseFloat(str); if (isNaN(n)) return str;
          var pct = n>1?n:n*100, dp=decimals!==undefined?decimals:2;
          return new Intl.NumberFormat(locale,{minimumFractionDigits:dp,maximumFractionDigits:dp}).format(pct)+'\u00A0%';
        }
        case 'datetime': {
          var d = new Date(str); if (isNaN(d.getTime())) return str;
          var p=col.datePattern||'';
          if (p) {
            var pad=function(v,l){return String(v).padStart(l||2,'0');};
            return p.replace('dd',pad(d.getDate())).replace('MM',pad(d.getMonth()+1))
              .replace('yyyy',d.getFullYear()).replace('yy',String(d.getFullYear()).slice(-2))
              .replace('HH',pad(d.getHours())).replace('mm',pad(d.getMinutes())).replace('ss',pad(d.getSeconds()));
          }
          return new Intl.DateTimeFormat(locale).format(d);
        }
        case 'duration': {
          var s=parseInt(str,10); if(isNaN(s)) return str;
          var h=Math.floor(s/3600),m=Math.floor((s%3600)/60),sec=s%60,parts=[];
          if(h) parts.push(h+'h');
          if(m||h) parts.push(String(m).padStart(2,'0')+'m');
          parts.push(String(sec).padStart(2,'0')+'s');
          return parts.join(' ');
        }
        default: return str;
      }
    },
    forExport: function (col, rawVal) {
      if (rawVal===null||rawVal===undefined) return '';
      var fmt=(col.format||'').toLowerCase();
      if (!fmt||fmt==='text') return rawVal;
      return FMT.apply(col, rawVal);
    }
  };

  /* =========================================================================
     THRESHOLD ENGINE — numeric (Min/Max) + string (Value)
     ========================================================================= */
  function getThresholdClass(col, rawVal) {
    if (!col.thresholds||!col.thresholds.length) return '';
    var str=(rawVal!==null&&rawVal!==undefined)?String(rawVal):'';
    var numVal=parseFloat(str);
    for (var i=0;i<col.thresholds.length;i++) {
      var t=col.thresholds[i];
      if (t.value!==undefined&&t.value!==null) {
        if (str.toLowerCase()===String(t.value).toLowerCase()) return t['class']||'';
        continue;
      }
      if (isNaN(numVal)) continue;
      var ok=(t.min===undefined||t.min===null||numVal>=t.min)&&
             (t.max===undefined||t.max===null||numVal<t.max);
      if (ok) return t['class']||'';
    }
    return '';
  }

  /* =========================================================================
     CSS VARIABLE HELPER
     ========================================================================= */
  function cssVar(name, fallback) {
    var v=getComputedStyle(document.documentElement).getPropertyValue(name).trim();
    return v||fallback;
  }

  /* =========================================================================
     THEME TOGGLE
     Two modes:
       1. Dual-embed: both <style> tags present (data-theme attrs) — swap disabled
       2. Single CSS fallback: toggle CSS variable overrides via body class
     ========================================================================= */
  function initThemeToggle() {
    var btn = document.getElementById('btn-theme-toggle');
    if (!btn) return;

    var primaryStyle   = document.getElementById('theme-primary');
    var alternateStyle = document.getElementById('theme-alternate');
    var isDual         = primaryStyle && alternateStyle;

    /* ── Dual-embed mode ────────────────────────────────────────────── */
    if (isDual) {
      var primaryName   = primaryStyle.dataset.theme   || 'Theme A';
      var alternateName = alternateStyle.dataset.theme || 'Theme B';
      var usingPrimary  = true;

      /* Initial button label */
      btn.textContent   = '⇄ ' + alternateName;
      btn.title         = 'Switch to ' + alternateName;

      btn.addEventListener('click', function () {
        usingPrimary = !usingPrimary;
        if (usingPrimary) {
          primaryStyle.media   = '';       /* activate primary */
          alternateStyle.media = 'none';   /* suppress alternate */
          btn.textContent = '⇄ ' + alternateName;
          btn.title       = 'Switch to ' + alternateName;
        } else {
          alternateStyle.media = '';       /* activate alternate */
          primaryStyle.media   = 'none';   /* suppress primary */
          btn.textContent = '⇄ ' + primaryName;
          btn.title       = 'Switch to ' + primaryName;
        }
        URLState.save();
      });
      return;
    }

    /* ── Single-CSS fallback mode (basic variable overrides) ────────── */
    var lightActive = false;
    btn.textContent = '☀ Light';
    btn.title       = 'Switch to light mode';
    btn.addEventListener('click', function () {
      lightActive = !lightActive;
      if (lightActive) {
        document.body.classList.add('theme-forced-light');
        document.body.classList.remove('theme-forced-dark');
        btn.textContent = '🌙 Dark';
        btn.title       = 'Switch to dark mode';
      } else {
        document.body.classList.add('theme-forced-dark');
        document.body.classList.remove('theme-forced-light');
        btn.textContent = '☀ Light';
        btn.title       = 'Switch to light mode';
      }
    });
  }

  /* =========================================================================
     DENSITY TOGGLE
     ========================================================================= */
  function initDensityToggle() {
    var btn = document.getElementById('btn-density-toggle');
    if (!btn) return;
    var states = ['normal','compact','comfortable'];
    var labels = { normal:'⊞ Normal', compact:'⊟ Compact', comfortable:'⊠ Spacious' };
    var i = 0;
    btn.textContent = labels['normal'];
    btn.addEventListener('click', function () {
      document.body.classList.remove('density-'+states[i]);
      i = (i+1) % states.length;
      tableDensity = states[i];
      document.body.classList.add('density-'+states[i]);
      btn.textContent = labels[states[i]];
      URLState.save();
    });
  }

  /* =========================================================================
     SUMMARY TILES
     ========================================================================= */
  function renderSummary() {
    if (!SUMMARY_CONFIG||!SUMMARY_CONFIG.length) return;
    var container = document.getElementById('report-summary');
    if (!container) return;
    container.innerHTML = '';
    SUMMARY_CONFIG.forEach(function (item) {
      var displayVal = FMT.apply(
        {format:item.format||'',locale:item.locale||'',decimals:item.decimals,currency:item.currency||''},
        item.value
      ) || String(item.value!==null&&item.value!==undefined?item.value:'');
      var tile = document.createElement('div');
      tile.className = 'summary-tile'+(item['class']?' '+item['class']:'');
      tile.innerHTML = (item.icon?'<span class="summary-icon">'+esc(item.icon)+'</span>':'')+
        '<span class="summary-value">'+esc(displayVal)+'</span>'+
        '<span class="summary-label">'+esc(item.label)+'</span>'+
        (item.subLabel?'<span class="summary-sublabel">'+esc(item.subLabel)+'</span>':'');
      container.appendChild(tile);
    });
  }

  /* =========================================================================
     BLOCKS ENGINE — HTML, Collapsible, FilterCardGrid, BarChart
     ========================================================================= */
  function renderBlocks() {
    BLOCKS_CONFIG.forEach(function (block) {
      var container = document.getElementById('block-'+block.id);
      if (!container) return;
      switch (block.blockType) {
        case 'html':         renderHtmlBlock(container, block); break;
        case 'collapsible':  renderCollapsible(container, block); break;
        case 'filtercardgrid': renderFilterCardGrid(container, block); break;
        case 'barchart':     renderBarChart(container, block); break;
      }
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
      grid.className = 'collapsible-card-grid';
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
  function renderBarChart(container, block) {
    container.className = 'bar-chart-section';
    /* Aggregate from engine data */
    var engine = engines[block.tableId];
    if (!engine) { container.innerHTML = '<p class="no-data">Table not ready.</p>'; return; }

    var counts = {};
    engine._getFiltered().forEach(function (row) {
      var v = (row[block.field]!=null)?String(row[block.field]):'(empty)';
      counts[v]=(counts[v]||0)+1;
    });
    var entries = Object.keys(counts).map(function(k){return{label:k,count:counts[k]};})
      .sort(function(a,b){return b.count-a.count;}).slice(0,block.topN||10);
    var maxCount = entries[0]?entries[0].count:1;
    var total = engine._getFiltered().length;

    var barsHtml = entries.map(function (e) {
      var pct = (e.count/maxCount*100).toFixed(1);
      var pctTotal = (e.count/total*100).toFixed(0);
      var clickAttr = block.clickFilters
        ? ' onclick="(function(){var eng=engines[\''+block.tableId+'\'];if(eng){eng.filterText=\''+e.label.replace(/'/g,"\\'")+ '\';document.getElementById(\'filter-'+block.tableId+'\').value=\''+e.label.replace(/'/g,"\\'")+'\';eng.currentPage=1;eng.render();}})();"'
        : '';
      return '<div class="bar-item'+(block.clickFilters?' bar-clickable':'')+'"'+clickAttr+'>'+
        '<div class="bar-label">'+
          '<span class="bar-label-text" title="'+esc(e.label)+'">'+esc(e.label)+'</span>'+
          (block.showCount!==false?'<span class="bar-label-count">'+esc(e.count)+'</span>':'')+
          (block.showPercent?'<span class="bar-label-pct">'+esc(pctTotal)+'%</span>':'')+
        '</div>'+
        '<div class="bar-track"><div class="bar-fill" style="width:'+pct+'%"></div></div>'+
      '</div>';
    }).join('');

    container.innerHTML =
      '<h3 class="bar-chart-title">'+esc(block.title)+'</h3>'+
      '<div class="bar-chart">'+barsHtml+'</div>';
  }

  /* =========================================================================
     NAVIGATION — PANEL MODE  with row-count badges + URL restore
     Two modes:
       flat     — single nav bar, one panel visible at a time (legacy)
       two-tier — primary group tabs + secondary subnav links
     ========================================================================= */
  function initNav() {
    var groupTabsEl = document.getElementById('nav-group-tabs');

    if (groupTabsEl) {
      _initTwoTierNav(groupTabsEl);
    } else {
      _initFlatNav();
    }
  }

  /* ── FLAT NAV (no NavGroup used) ──────────────────────────────────── */
  function _initFlatNav() {
    var links = document.querySelectorAll('.nav-link[data-table], .nav-link[data-panel]');
    if (!links.length) return;

    function showPanel(id) {
      /* Leave ungrouped blocks (no data-navgroup) untouched — they are always visible */
      document.querySelectorAll('.table-section, .block-section[data-navgroup]').forEach(function (sec) {
        sec.classList.remove('panel-active');
      });
      links.forEach(function (l) { l.classList.remove('nav-active'); });
      var sec  = document.getElementById('section-'+id) || document.getElementById('bsection-'+id);
      var link = document.querySelector('.nav-link[data-table="'+id+'"], .nav-link[data-panel="'+id+'"]');
      if (sec)  sec.classList.add('panel-active');
      if (link) link.classList.add('nav-active');
      URLState.save();
    }

    links.forEach(function (link) {
      link.addEventListener('click', function (e) {
        e.preventDefault();
        showPanel(link.dataset.table || link.dataset.panel);
      });
    });

    var saved  = URLState.load();
    var target = saved.panel || '';
    var hasEl  = target && (document.getElementById('section-'+target) || document.getElementById('bsection-'+target));
    if (!hasEl) target = (links[0].dataset.table || links[0].dataset.panel);
    if (target) showPanel(target);

    window._showPanel = showPanel;
  }

  /* ── TWO-TIER NAV ─────────────────────────────────────────────────── */
  function _initTwoTierNav(groupTabsEl) {
    var tabs      = groupTabsEl.querySelectorAll('.nav-group-tab');
    var subLinks  = document.querySelectorAll('#nav-subnav .nav-link');
    var flatLinks = document.querySelectorAll('.nav-inner .nav-link[data-table], .nav-inner .nav-link[data-panel]');

    /* Wire flat links (ungrouped tables in primary bar) */
    flatLinks.forEach(function (link) {
      link.addEventListener('click', function (e) {
        e.preventDefault();
        _showFlatPanel(link.dataset.table || link.dataset.panel);
      });
    });

    function _showFlatPanel(id) {
      /* Hide all grouped sections, show ungrouped target */
      document.querySelectorAll('[data-navgroup]').forEach(function (s) { s.classList.remove('panel-active'); });
      tabs.forEach(function (t) { t.classList.remove('group-active'); });
      subLinks.forEach(function (l) { l.classList.remove('nav-active'); });
      flatLinks.forEach(function (l) { l.classList.remove('nav-active'); });
      currentGroup = '';
      var sec  = document.getElementById('section-'+id) || document.getElementById('bsection-'+id);
      var link = document.querySelector('.nav-inner .nav-link[data-table="'+id+'"]');
      if (sec)  sec.classList.add('panel-active');
      if (link) link.classList.add('nav-active');
      URLState.save();
    }

    function showGroup(groupName) {
      /* Hide all grouped sections */
      document.querySelectorAll('[data-navgroup]').forEach(function (s) { s.classList.remove('panel-active'); });
      /* Deactivate flat links */
      flatLinks.forEach(function (l) { l.classList.remove('nav-active'); });
      /* Activate group tab */
      tabs.forEach(function (t) { t.classList.toggle('group-active', t.dataset.group === groupName); });
      /* Show/hide subnav links */
      subLinks.forEach(function (l) {
        l.style.display = (l.dataset.group === groupName) ? '' : 'none';
        l.classList.remove('nav-active');
      });
      /* Show all block-sections for this group */
      document.querySelectorAll('.block-section[data-navgroup="'+groupName+'"]').forEach(function (s) {
        s.classList.add('panel-active');
      });
      /* Show/hide subnav strip — hide it when this group has no table sub-links */
      var subnavEl = document.getElementById('nav-subnav');
      if (subnavEl) {
        var hasGroupLinks = !!document.querySelector('#nav-subnav .nav-link[data-group="'+groupName+'"]');
        subnavEl.style.display = hasGroupLinks ? '' : 'none';
      }
      currentGroup = groupName;
      /* Activate first subnav link */
      var firstLink = document.querySelector('#nav-subnav .nav-link[data-group="'+groupName+'"]');
      if (firstLink) {
        showSubPanel(firstLink.dataset.table || firstLink.dataset.panel, groupName);
      } else {
        URLState.save();
      }
    }

    function showSubPanel(id, groupName) {
      var grp = groupName || currentGroup;
      /* Hide all table-sections in this group, show the target */
      document.querySelectorAll('.table-section[data-navgroup="'+grp+'"]').forEach(function (s) {
        s.classList.remove('panel-active');
      });
      subLinks.forEach(function (l) { l.classList.remove('nav-active'); });
      var sec  = document.getElementById('section-'+id);
      var link = document.querySelector('#nav-subnav .nav-link[data-table="'+id+'"]');
      if (sec)  sec.classList.add('panel-active');
      if (link) link.classList.add('nav-active');
      URLState.save();
    }

    /* Wire group tab clicks */
    tabs.forEach(function (tab) {
      tab.addEventListener('click', function (e) {
        e.preventDefault();
        showGroup(tab.dataset.group);
      });
    });

    /* Wire subnav link clicks */
    subLinks.forEach(function (link) {
      link.addEventListener('click', function (e) {
        e.preventDefault();
        showSubPanel(link.dataset.table || link.dataset.panel, link.dataset.group);
      });
    });

    /* Restore from URL or show first group + first panel */
    var saved = URLState.load();
    var restoredGroup = saved.group || (tabs[0] ? tabs[0].dataset.group : '');
    if (restoredGroup) {
      showGroup(restoredGroup);
      /* Then restore specific panel within the group */
      if (saved.panel) {
        var restoredLink = document.querySelector('#nav-subnav .nav-link[data-table="'+saved.panel+'"][data-group="'+restoredGroup+'"]');
        if (restoredLink) showSubPanel(saved.panel, restoredGroup);
      }
    } else if (flatLinks.length) {
      _showFlatPanel(flatLinks[0].dataset.table || flatLinks[0].dataset.panel);
    }

    window._showPanel   = showSubPanel;
    window._showGroup   = showGroup;
  }

  /* Update row-count badges in nav after tables render */
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

  /* Re-render any bar charts that reference this table */
  TableEngine.prototype._refreshLinkedBarCharts = function () {
    var id = this.id;
    BLOCKS_CONFIG.forEach(function (block) {
      if (block.blockType === 'barchart' && block.tableId === id) {
        var container = document.getElementById('block-' + block.id);
        if (container) renderBarChart(container, block);
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
  TableEngine.prototype._bindFilter = function () {
    var inp=document.getElementById('filter-'+this.id);
    var clr=document.getElementById('filter-clear-'+this.id);
    if (!inp) return;
    var self=this;
    inp.addEventListener('input',function(){
      self.filterText=inp.value;self.currentPage=1;
      clr.style.display=inp.value?'flex':'none';
      self.render();self._refreshLinkedBarCharts();self._renderCharts();URLState.save();
    });
    clr.addEventListener('click',function(){
      inp.value='';self.filterText='';clr.style.display='none';
      self.currentPage=1;self.render();self._refreshLinkedBarCharts();self._renderCharts();URLState.save();
    });
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
      data=data.slice().sort(function(a,b){
        for (var i=0;i<self.sortFields.length;i++) {
          var sf=self.sortFields[i].field,sd=self.sortFields[i].dir;
          var av=(a[sf]!=null)?a[sf]:'',bv=(b[sf]!=null)?b[sf]:'';
          var an=parseFloat(av),bn=parseFloat(bv);
          var n=(!isNaN(an)&&!isNaN(bn))?(an-bn):String(av).localeCompare(String(bv),undefined,{sensitivity:'base'});
          if(n!==0)return sd==='asc'?n:-n;
        }
        return 0;
      });
    }
    return data;
  };

  /* ── Cell rendering ─────────────────────────────────────────────── */
  TableEngine.prototype._renderCell = function (col,rawVal) {
    var td=document.createElement('td');
    var strRaw=(rawVal!==null&&rawVal!==undefined)?String(rawVal):'';
    var dispVal=FMT.apply(col,rawVal)||strRaw;
    var thClass=getThresholdClass(col,rawVal);

    var align=(col.align||'left').toLowerCase();
    if(align==='right') td.classList.add('cell-right');
    if(align==='center')td.classList.add('cell-center');
    if(thClass)td.classList.add(thClass);
    if(col.bold)  td.classList.add('cell-bold');
    if(col.italic)td.classList.add('cell-italic');
    if(col.font){var fm={mono:'cell-mono',ui:'cell-ui',display:'cell-display'};var fc=fm[col.font.toLowerCase()];if(fc)td.classList.add(fc);}

    var cellType=(col.cellType||'text').toLowerCase();
    if(cellType==='progressbar'){
      var numVal=parseFloat(strRaw),pMax=col.progressMax||100;
      var pct=isNaN(numVal)?0:Math.min(100,Math.max(0,(numVal/pMax)*100));
      var fillCls=thClass?thClass.replace('cell-','fill-'):'fill-default';
      td.classList.add('td-progress');
      td.innerHTML='<div class="progress-wrap"><span class="progress-label">'+dispVal+'</span>'+
        '<div class="progress-track"><div class="progress-fill '+fillCls+'" style="width:'+pct.toFixed(1)+'%"></div></div></div>';
    } else if(cellType==='badge'){
      td.classList.add('td-badge');
      var badge=document.createElement('span');
      badge.className='cell-badge'+(thClass?' badge-'+thClass.replace('cell-',''):'');
      badge.textContent=dispVal;td.appendChild(badge);
    } else {
      td.textContent=dispVal;
    }
    /* Pin first column */
    if(col.pinFirst){td.classList.add('col-pinned');}
    return td;
  };

  /* ── Render ─────────────────────────────────────────────────────── */
  TableEngine.prototype.render = function(){
    this._renderHead();this._renderBody();this._renderFoot();this._renderPaging();
    this._renderInfo();this._renderSelClearBtn();
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
        var start=(self.currentPage-1)*self.pageSize;
        filtered.slice(start,start+self.pageSize).forEach(function(row){
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
      if(col.width)th.style.width=col.width;
      if(col.pinFirst)th.classList.add('col-pinned');

      var align=(col.align||'left').toLowerCase();
      if(align==='right') th.classList.add('th-right');
      if(align==='center')th.classList.add('th-center');

      var lbl=document.createElement('span');lbl.className='col-label';lbl.textContent=col.label;
      th.appendChild(lbl);

      if(col.sortable!==false){
        th.classList.add('sortable');
        var icon=document.createElement('span');icon.className='sort-icon';

        /* Show sort position for multi-sort */
        var sortPos=self.sortFields.findIndex(function(sf){return sf.field===col.field;});
        if(sortPos>-1){
          icon.classList.add('sort-'+self.sortFields[sortPos].dir);
          th.classList.add('sorted');
          if(self.sortFields.length>1){
            var pos=document.createElement('span');
            pos.className='sort-pos';pos.textContent=sortPos+1;
            th.appendChild(pos);
          }
        }
        th.appendChild(icon);

        th.addEventListener('click',function(e){
          var existIdx=self.sortFields.findIndex(function(sf){return sf.field===col.field;});
          if(e.shiftKey&&self.sortFields.length>0){
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
        });
      }
      tr.appendChild(th);
    });
  };

  TableEngine.prototype._renderBody = function(){
    var tbody=document.getElementById('tbody-'+this.id);
    if(!tbody)return;
    var filtered=this._getFiltered();
    var start=(this.currentPage-1)*this.pageSize;
    var page=filtered.slice(start,start+this.pageSize);
    var self=this;var visCols=this._visibleCols();
    tbody.innerHTML='';

    /* Update nav badge */
    var navBadge=document.querySelector('.nav-badge[data-table="'+this.id+'"]');
    if(navBadge) navBadge.textContent=filtered.length;

    /* Update nav badge with current filtered count */
    updateNavBadge(this.id);

    if(page.length===0){
      var tr=document.createElement('tr');var td=document.createElement('td');
      td.colSpan=visCols.length+(this.multiSelect?1:0);td.className='no-data';
      td.textContent='No matching records found.';tr.appendChild(td);tbody.appendChild(tr);return;
    }

    page.forEach(function(row){
      var globalIdx=self.allData.indexOf(row);
      var tr=document.createElement('tr');tr.dataset.idx=globalIdx;

      /* Row highlight */
      self.columns.forEach(function(col){
        if(col.rowHighlight){
          var cls=getThresholdClass(col,row[col.field]);
          if(cls)tr.classList.add('row-hl-'+cls.replace('cell-',''));
        }
      });

      if(self.selected.indexOf(globalIdx)!==-1)tr.classList.add('row-selected');

      tr.addEventListener('click',function(e){
        if(e.target.type==='checkbox')return;
        self._handleRowClick(globalIdx,row,tr);
      });

      if(self.multiSelect){
        var tdChk=document.createElement('td');tdChk.className='col-select';
        var chk=document.createElement('input');chk.type='checkbox';
        chk.checked=self.selected.indexOf(globalIdx)!==-1;
        chk.addEventListener('change',function(){
          if(chk.checked){if(self.selected.indexOf(globalIdx)===-1)self.selected.push(globalIdx);}
          else{self.selected=self.selected.filter(function(i){return i!==globalIdx;});}
          self._syncRowClass(tr,globalIdx);self._renderInfo();self._renderSelClearBtn();
        });
        tdChk.appendChild(chk);tr.appendChild(tdChk);
      }

      visCols.forEach(function(col){tr.appendChild(self._renderCell(col,row[col.field]));});
      tbody.appendChild(tr);
    });
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

  /* ── Pie Charts ─────────────────────────────────────────────────── */
  TableEngine.prototype._chartPalette=function(){
    return['--chart-1','--chart-2','--chart-3','--chart-4','--chart-5','--chart-6','--chart-7','--chart-8']
      .map(function(v,i){return cssVar(v,['#00c8ff','#00e676','#ffc107','#ff4d6a','#a855f7','#f97316','#06b6d4','#84cc16'][i]);});
  };

  TableEngine.prototype._renderCharts=function(){
    if(!this.charts||!this.charts.length)return;
    var container=document.getElementById('charts-'+this.id);
    if(!container)return;container.innerHTML='';var self=this;
    this.charts.forEach(function(chart){
      if((chart.type||'pie').toLowerCase()==='pie')container.appendChild(self._buildPieChart(chart));
    });
  };

  TableEngine.prototype._buildPieChart=function(chart){
    var self=this,palette=this._chartPalette(),counts={};
    this._getFiltered().forEach(function(row){var v=(row[chart.field]!=null)?String(row[chart.field]):'(empty)';counts[v]=(counts[v]||0)+1;});
    var entries=Object.keys(counts).map(function(k,i){return{label:k,count:counts[k],color:palette[i%palette.length]};}).sort(function(a,b){return b.count-a.count;});
    var total=entries.reduce(function(s,e){return s+e.count;},0);if(!total)return document.createElement('div');
    var size=130,cx=65,cy=65,r=56,inner=30;
    var svgParts=['<svg width="'+size+'" height="'+size+'" viewBox="0 0 '+size+' '+size+'" aria-hidden="true">'];
    var angle=-Math.PI/2;
    entries.forEach(function(e){
      var slice=(e.count/total)*2*Math.PI;if(slice<0.001)return;
      if(e.count===total){svgParts.push('<circle cx="'+cx+'" cy="'+cy+'" r="'+r+'" fill="'+e.color+'"/>');}
      else{
        var x1=(cx+r*Math.cos(angle)).toFixed(2),y1=(cy+r*Math.sin(angle)).toFixed(2);
        angle+=slice;
        var x2=(cx+r*Math.cos(angle)).toFixed(2),y2=(cy+r*Math.sin(angle)).toFixed(2);
        svgParts.push('<path d="M'+cx+','+cy+' L'+x1+','+y1+' A'+r+','+r+' 0 '+(slice>Math.PI?1:0)+',1 '+x2+','+y2+' Z" fill="'+e.color+'" stroke="var(--bg-surface)" stroke-width="2"/>');
      }
    });
    svgParts.push('<circle cx="'+cx+'" cy="'+cy+'" r="'+inner+'" fill="var(--bg-surface)"/>','<text x="'+cx+'" y="'+(cy-5)+'" text-anchor="middle" font-size="11" fill="var(--text-muted)" font-family="var(--font-ui)">Total</text>','<text x="'+cx+'" y="'+(cy+11)+'" text-anchor="middle" font-size="15" font-weight="700" fill="var(--text-primary)" font-family="var(--font-ui)">'+total+'</text>','</svg>');
    var legendRows=entries.map(function(e){var pct=((e.count/total)*100).toFixed(0);return'<div class="legend-row"><span class="legend-dot" style="background:'+esc(e.color)+'"></span><span class="legend-label">'+esc(e.label)+'</span><span class="legend-count">'+esc(e.count)+' <span class="legend-pct">('+esc(pct)+'%)</span></span></div>';}).join('');
    var panel=document.createElement('div');panel.className='chart-panel';
    panel.innerHTML='<div class="chart-title">'+esc(chart.title||chart.field)+'</div><div class="chart-body">'+svgParts.join('')+'<div class="chart-legend">'+legendRows+'</div></div>';
    return panel;
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
    var wb=XLSX.utils.book_new();XLSX.utils.book_append_sheet(wb,ws,this.title.substring(0,31));
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

  /* =========================================================================
     BOOT
     ========================================================================= */
  document.addEventListener('DOMContentLoaded', function () {
    renderSummary();
    renderBlocks();

    TABLES_CONFIG.forEach(function (cfg) {
      engines[cfg.id] = new TableEngine(cfg);
    });

    /* Bar charts need engines ready */
    BLOCKS_CONFIG.forEach(function (block) {
      if (block.blockType === 'barchart') {
        var container = document.getElementById('block-'+block.id);
        if (container) renderBarChart(container, block);
      }
    });

    initNav();
    initThemeToggle();
    initDensityToggle();

    /* ── Restore URL state: density + card filters ── */
    var _saved = URLState.load();
    if (_saved.density) {
      /* Apply saved density class */
      var _densityStates = ['normal','compact','comfortable'];
      var _densityLabels = { normal:'⊞ Normal', compact:'⊟ Compact', comfortable:'⊚ Spacious' };
      if (_densityStates.indexOf(_saved.density) !== -1) {
        tableDensity = _saved.density;
        document.body.classList.add('density-' + tableDensity);
        var _db = document.getElementById('btn-density-toggle');
        if (_db) _db.textContent = _densityLabels[tableDensity];
      }
    }
    if (_saved.cardFilters) {
      /* Re-apply saved card filters — mark active cards and update engines */
      Object.keys(_saved.cardFilters).forEach(function (filterId) {
        var cf = _saved.cardFilters[filterId];
        cardFilters[filterId] = cf;
        /* Mark active cards visually */
        var grid = document.getElementById('fcgrid-' + filterId);
        if (grid) {
          grid.querySelectorAll('.filter-card').forEach(function (card) {
            var cardVal = card.querySelector('.filter-card-name');
            if (cardVal && cf.values && cf.values.indexOf(cardVal.textContent) !== -1) {
              card.classList.add('active');
            }
          });
        }
        /* Update engine */
        if (cf.tableId && engines[cf.tableId]) {
          engines[cf.tableId]._applyCardFilters();
        }
      });
    }

    updateNavBadges();
  });

})();
'@
}
