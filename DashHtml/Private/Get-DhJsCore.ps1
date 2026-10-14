function Get-DhJsCore {
    # Auto-split fragment of the dashboard runtime JS (see Get-DhJsContent).
    return @'
(function () {
  'use strict';

  /* =========================================================================
     INJECTED CONFIG
     ========================================================================= */
  var TABLES_CONFIG  = /*%%TABLES_CONFIG%%*/[];
  var SUMMARY_CONFIG = /*%%SUMMARY_CONFIG%%*/[];
  var BLOCKS_CONFIG  = /*%%BLOCKS_CONFIG%%*/[];
  var ALERTS_CONFIG  = /*%%ALERTS_CONFIG%%*/[];
  var GLOBALFILTER_CONFIG = /*%%GLOBALFILTER_CONFIG%%*/[];
  /* v2.2.0 — { mode: 'cdn'|'embed'|'none', libs: { key: { url, sri } } } */
  var EXPORT_LIBS    = /*%%EXPORT_LIBS%%*/{"mode":"none","libs":{}};
  /* v2.2.0 — { maxRows, cover } for the print view */
  var PRINT_CONFIG   = /*%%PRINT_CONFIG%%*/{"maxRows":200,"cover":false};

  /* =========================================================================
     GLOBAL STATE
     ========================================================================= */
  var engines         = {};        /* tableId -> TableEngine */
  var cardFilters     = {};        /* filterId -> { field, values[] } */
  var themeMode       = 'light';   /* 'light' (primary style) | 'dark' (alternate) */
  var themeChosen     = false;     /* true once the reader picked or restored a theme */
  var tableDensity    = 'normal';  /* 'compact' | 'normal' | 'comfortable' */
  var currentGroup    = '';        /* active nav group in two-tier mode */
  var currentSubGroup = '';        /* active nav sub-group in three-tier mode */
  var dismissedAlerts = {};        /* alertId -> true; persisted in URL hash */

  /* esc() — HTML-encode a value before inserting into innerHTML.
     Prevents XSS when data originates from external sources (Azure tags, resource names, etc.)
     v2.1.4 — also encodes ' so the result is safe inside a single-quoted
     attribute too. Every attribute today is double-quoted; this is defence
     in depth, not a fix for a live sink. */
  function esc(s) {
    if (s == null) return '';
    return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
  }

  /* =========================================================================
     GLOBAL FILTER BUS (v1.9.0) — page-level facet / date-range filters. Every
     table subscribes; a table only honours a filter whose field it actually
     has (tables lacking the field are unaffected). Charts derived from tables
     re-aggregate automatically because their source table re-renders.
     ========================================================================= */
  var GlobalFilter = {
    _subs:  [],
    facets: {},   /* field -> selected value ('' = all) */
    ranges: {},   /* field -> { from, to } as ISO date strings */
    subscribe: function (fn) { this._subs.push(fn); },
    _notify: function () {
      this._subs.forEach(function (fn) { try { fn(); } catch (e) {} });
      if (typeof URLState !== 'undefined') URLState.save();
    },
    setFacet: function (field, value) { this.facets[field] = value || ''; this._notify(); },
    setRange: function (field, from, to) { this.ranges[field] = { from: from || '', to: to || '' }; this._notify(); },
    clear: function () {
      var self = this;
      Object.keys(this.facets).forEach(function (f) { self.facets[f] = ''; });
      Object.keys(this.ranges).forEach(function (f) { self.ranges[f] = { from: '', to: '' }; });
      this._notify();
      renderGlobalFilters();   /* reset the controls to their empty state */
    },
    active: function () {
      var any = false, self = this;
      Object.keys(this.facets).forEach(function (f) { if (self.facets[f]) any = true; });
      Object.keys(this.ranges).forEach(function (f) { var r = self.ranges[f]; if (r && (r.from || r.to)) any = true; });
      return any;
    },
    /* true if the row passes every active filter that applies to it */
    matchRow: function (row) {
      var self = this, ok = true;
      Object.keys(this.facets).forEach(function (f) {
        var v = self.facets[f];
        if (!v || !(f in row)) return;
        if (String(row[f]) !== v) ok = false;
      });
      Object.keys(this.ranges).forEach(function (f) {
        var r = self.ranges[f];
        if (!r || (!r.from && !r.to) || !(f in row)) return;
        var t = Date.parse(row[f]);
        if (isNaN(t)) return;                       /* unparseable → don't exclude */
        if (r.from) { var tf = Date.parse(r.from); if (!isNaN(tf) && t < tf) ok = false; }
        if (r.to)   { var tt = Date.parse(r.to);   if (!isNaN(tt) && t > tt + 86399999) ok = false; }  /* inclusive end-of-day */
      });
      return ok;
    }
  };

  /* Distinct non-empty values of a field across every table's data. */
  function _gfDistinct(field) {
    var seen = {}, out = [];
    TABLES_CONFIG.forEach(function (t) {
      (t.data || []).forEach(function (row) {
        if (!(field in row)) return;
        var v = row[field];
        if (v === null || v === undefined || v === '') return;
        var s = String(v);
        if (!seen[s]) { seen[s] = true; out.push(s); }
      });
    });
    out.sort(function (a, b) { var an = parseFloat(a), bn = parseFloat(b); return (!isNaN(an) && !isNaN(bn)) ? (an - bn) : a.localeCompare(b); });
    return out;
  }

  function renderGlobalFilters() {
    var bar = document.getElementById('global-filter-bar');
    if (!bar) return;
    if (!GLOBALFILTER_CONFIG || !GLOBALFILTER_CONFIG.length) { bar.style.display = 'none'; return; }
    bar.innerHTML = '';

    GLOBALFILTER_CONFIG.forEach(function (gf) {
      var wrap = document.createElement('div'); wrap.className = 'gf-control';
      var ctrlId = 'gf-' + String(gf.field).replace(/[^A-Za-z0-9_-]/g, '-');
      var lbl = document.createElement('label'); lbl.className = 'gf-label';
      lbl.textContent = gf.label || gf.field; lbl.setAttribute('for', ctrlId);
      wrap.appendChild(lbl);

      if (gf.type === 'daterange') {
        var from = document.createElement('input'); from.type = 'date'; from.className = 'gf-date'; from.id = ctrlId + '-from';
        var to   = document.createElement('input'); to.type   = 'date'; to.className   = 'gf-date'; to.id   = ctrlId + '-to';
        var cur = GlobalFilter.ranges[gf.field] || { from: '', to: '' };
        from.value = cur.from; to.value = cur.to;
        var upd = function () { GlobalFilter.setRange(gf.field, from.value, to.value); };
        from.addEventListener('change', upd); to.addEventListener('change', upd);
        from.setAttribute('aria-label', (gf.label || gf.field) + ' from');
        to.setAttribute('aria-label',   (gf.label || gf.field) + ' to');
        var sep = document.createElement('span'); sep.className = 'gf-date-sep'; sep.textContent = '→';
        wrap.appendChild(from); wrap.appendChild(sep); wrap.appendChild(to);
      } else {
        var sel = document.createElement('select'); sel.className = 'gf-select'; sel.id = ctrlId;
        var values = (gf.values && gf.values.length) ? gf.values.map(String) : _gfDistinct(gf.field);
        var optAll = document.createElement('option'); optAll.value = '';
        optAll.textContent = gf.placeholder || ('All ' + (gf.label || gf.field));
        sel.appendChild(optAll);
        values.forEach(function (v) { var o = document.createElement('option'); o.value = v; o.textContent = v; sel.appendChild(o); });
        sel.value = GlobalFilter.facets[gf.field] || '';
        sel.addEventListener('change', function () { GlobalFilter.setFacet(gf.field, sel.value); });
        wrap.appendChild(sel);
      }
      bar.appendChild(wrap);
    });

    var clr = document.createElement('button');
    clr.type = 'button'; clr.className = 'gf-clear'; clr.textContent = 'Clear filters';
    clr.addEventListener('click', function () { GlobalFilter.clear(); });
    bar.appendChild(clr);
    bar.style.display = GlobalFilter.active() || GLOBALFILTER_CONFIG.length ? '' : 'none';
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
        /* v2.0.0 - the selected nav path, at any depth. Replaces the 1.x
           {group,panel} pair, which could not express a third level at all
           (proposal defect #6). Old hashes are still READ, in initNav. */
        if (typeof window._navPath === 'function') {
          var np = window._navPath();
          if (np && np.length) state.nav = np;
        }
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
        /* theme (v2.1.4) — only once chosen, so a report's default still applies */
        if (themeChosen) state.theme = themeMode;
        /* dismissed alert banners — array of ids */
        var dismissed = Object.keys(dismissedAlerts);
        if (dismissed.length) state.alerts = dismissed;
        /* global filters (v1.9.0) */
        if (typeof GlobalFilter !== 'undefined' && GlobalFilter.active()) {
          var gf = {};
          Object.keys(GlobalFilter.facets).forEach(function (f) { if (GlobalFilter.facets[f]) { gf.facets = gf.facets || {}; gf.facets[f] = GlobalFilter.facets[f]; } });
          Object.keys(GlobalFilter.ranges).forEach(function (f) { var r = GlobalFilter.ranges[f]; if (r && (r.from || r.to)) { gf.ranges = gf.ranges || {}; gf.ranges[f] = r; } });
          state.gf = gf;
        }
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
          while (n>=1000&&i<u.length-1){n/=1000;i++;}
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
    var isMissing = (rawVal===null||rawVal===undefined||rawVal==='');
    /* v1.4 F13 — when the column was declared with -Rag NoData=$true, paint
       missing/null cells with cell-nodata. Wins over any numeric thresholds
       that would otherwise return ''. */
    if (isMissing && col.ragNoData) return 'cell-nodata';
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
  /* v2.1.4 — the theme choice persists. Before 2.1.4 the toggle called
     URLState.save() but _write had no theme key, so a reload always came back
     in the primary theme. Precedence on load: the URL hash (a shared link)
     beats localStorage (this browser's last choice) beats the report default.
     'light' means the primary <style> (New-DhDashboard always makes the
     primary the light variant), 'dark' the alternate. */
  var THEME_STORE_KEY = 'dh-theme';

  function themeLabel(name) {
    if (/dark$/i.test(name))  return '☾ Dark';
    if (/light$/i.test(name)) return '☀ Light';
    return '⇄ ' + name;
  }

  function themeStoreGet() {
    try { return window.localStorage ? window.localStorage.getItem(THEME_STORE_KEY) : null; } catch (e) { return null; }
  }
  function themeStoreSet(mode) {
    try { if (window.localStorage) window.localStorage.setItem(THEME_STORE_KEY, mode); } catch (e) {}
  }

  /* Apply 'light' | 'dark'. Safe to call before DOMContentLoaded: the two
     <style> tags live in <head>, and the button is labelled only if present. */
  function applyThemeMode(mode) {
    var p   = document.getElementById('theme-primary');
    var a   = document.getElementById('theme-alternate');
    var btn = document.getElementById('btn-theme-toggle');
    themeMode = (mode === 'dark') ? 'dark' : 'light';
    if (p && a) {
      var useAlt = (themeMode === 'dark');
      p.media = useAlt ? 'none' : '';
      a.media = useAlt ? '' : 'none';
      var next = useAlt ? (p.dataset.theme || 'Light') : (a.dataset.theme || 'Dark');
      if (btn) { btn.textContent = themeLabel(next); btn.title = 'Switch to ' + next; }
    } else if (document.body) {
      /* Single-CSS fallback (no alternate <style>): body-class overrides. */
      document.body.classList.toggle('theme-forced-dark',  themeMode === 'dark');
      document.body.classList.toggle('theme-forced-light', themeMode === 'light');
      if (btn) {
        btn.textContent = themeMode === 'dark' ? '☀ Light' : '☾ Dark';
        btn.title       = themeMode === 'dark' ? 'Switch to light mode' : 'Switch to dark mode';
      }
    }
  }

  /* The saved choice, or '' when there is none. */
  function savedThemeMode() {
    var s = URLState.load();
    if (s.theme === 'light' || s.theme === 'dark') return s.theme;
    var ls = themeStoreGet();
    return (ls === 'light' || ls === 'dark') ? ls : '';
  }

  function initThemeToggle() {
    var btn = document.getElementById('btn-theme-toggle');
    if (!btn) return;
    applyThemeMode(themeMode);              /* label the button for the current state */
    btn.addEventListener('click', function () {
      applyThemeMode(themeMode === 'dark' ? 'light' : 'dark');
      themeChosen = true;
      themeStoreSet(themeMode);
      URLState.save();
    });
  }

  /* =========================================================================
     DENSITY TOGGLE
     ========================================================================= */
  /* v2.1.4 — one table of modes and labels, and the cycle position lives here
     rather than in a closure. Before 2.1.4 the URL restore in Boot applied a
     saved density without moving the toggle's private counter (and used a
     different glyph for Spacious), so the first click after a reload either
     did nothing visible or left two density classes on <body>. */
  var DENSITY = {
    modes:  ['normal', 'compact', 'comfortable'],
    labels: { normal: '⊞ Normal', compact: '⊟ Compact', comfortable: '⊠ Spacious' },
    index:  0,
    set: function (mode) {
      var i = this.modes.indexOf(mode);
      if (i === -1) return false;
      var self = this;
      this.modes.forEach(function (m) { document.body.classList.remove('density-' + m); });
      this.index   = i;
      tableDensity = mode;
      if (mode !== 'normal') document.body.classList.add('density-' + mode);
      var btn = document.getElementById('btn-density-toggle');
      if (btn) btn.textContent = self.labels[mode];
      return true;
    }
  };

  function initDensityToggle() {
    var btn = document.getElementById('btn-density-toggle');
    if (!btn) return;
    btn.textContent = DENSITY.labels[DENSITY.modes[DENSITY.index]];
    btn.addEventListener('click', function () {
      DENSITY.set(DENSITY.modes[(DENSITY.index + 1) % DENSITY.modes.length]);
      URLState.save();
    });
  }

  /* =========================================================================
     SPARK — pure-SVG mini-chart helper.
     Used by Add-DhSummary (tile sparkline, F2) and the v1.4 sparkline table
     cell type (F8). No external library; renders a single inline SVG string.

     SPARK.build(series, opts) -> '<svg>...</svg>' string (use innerHTML).
       series    numeric array (non-numeric items should already be filtered out)
       opts.style    'line' (default) | 'area' | 'bars'
       opts.width    default 80
       opts.height   default 24
       opts.min      explicit Y-min (else series min)
       opts.max      explicit Y-max (else series max)
       opts.color    explicit colour (else var(--chart-1) fallback)
     Returns '' for empty series so callers can do a truthy check.
     ========================================================================= */
  /* v1.4 F8 — reduce an array of values to a comparable scalar for sort.
     SortBy: 'last' (default) | 'avg' | 'max' | 'min' | 'sum'. Non-array
     values pass through unchanged so legacy data still sorts correctly. */
  function sparkReduce(arr, mode) {
    if (!Array.isArray(arr)) return arr;
    var nums = [];
    for (var i = 0; i < arr.length; i++) {
      var n = Number(arr[i]);
      if (isFinite(n)) nums.push(n);
    }
    if (!nums.length) return 0;
    switch ((mode || 'last').toLowerCase()) {
      case 'avg': return nums.reduce(function(s,v){return s+v;}, 0) / nums.length;
      case 'max': return Math.max.apply(null, nums);
      case 'min': return Math.min.apply(null, nums);
      case 'sum': return nums.reduce(function(s,v){return s+v;}, 0);
      case 'last':
      default:    return nums[nums.length - 1];
    }
  }

  var SPARK = {
    build: function (series, opts) {
      opts = opts || {};
      if (!series || !series.length) return '';
      var n = series.length;
      var nums = [];
      for (var i = 0; i < n; i++) {
        var v = Number(series[i]);
        nums.push(isFinite(v) ? v : 0);
      }
      var W = opts.width  || 80;
      var H = opts.height || 24;
      var style = (opts.style || 'line').toLowerCase();
      var color = opts.color || cssVar('--chart-1', '#00c8ff');
      var min = (opts.min != null) ? Number(opts.min) : Math.min.apply(null, nums);
      var max = (opts.max != null) ? Number(opts.max) : Math.max.apply(null, nums);
      if (min === max) { min -= 0.5; max += 0.5; }  /* flat series: still draw at mid */
      var pad = 1;
      var xAt = function (i) {
        if (n === 1) return W / 2;
        return pad + (i / (n - 1)) * (W - 2 * pad);
      };
      var yAt = function (v) {
        return (H - pad) - ((v - min) / (max - min)) * (H - 2 * pad);
      };
      var inner = '';
      if (style === 'bars') {
        var bw = Math.max(1, (W / n) - 1);
        var baseline = H - pad;
        for (var i = 0; i < n; i++) {
          var x = (i / n) * W + 0.5;
          var y = yAt(nums[i]);
          var h = baseline - y;
          if (h < 0.5) h = 0.5;  /* visible "zero" bar */
          inner += '<rect x="' + x.toFixed(2) + '" y="' + y.toFixed(2) +
                   '" width="' + bw.toFixed(2) + '" height="' + h.toFixed(2) +
                   '" fill="' + color + '"/>';
        }
      } else {
        var pts = [];
        for (var i = 0; i < n; i++) pts.push(xAt(i).toFixed(2) + ',' + yAt(nums[i]).toFixed(2));
        var ptsStr = pts.join(' ');
        if (style === 'area') {
          var firstX = xAt(0).toFixed(2);
          var lastX  = xAt(n - 1).toFixed(2);
          var areaPts = pts.map(function (p) { return 'L' + p; }).join(' ');
          var areaPath = 'M' + firstX + ',' + (H - pad) + ' ' + areaPts + ' L' + lastX + ',' + (H - pad) + ' Z';
          inner = '<path d="' + areaPath + '" fill="' + color + '" fill-opacity="0.22" stroke="none"/>' +
                  '<polyline points="' + ptsStr + '" fill="none" stroke="' + color +
                  '" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>';
        } else {
          /* default: line */
          inner = '<polyline points="' + ptsStr + '" fill="none" stroke="' + color +
                  '" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>';
        }
      }
      return '<svg class="spark-svg" width="' + W + '" height="' + H +
             '" viewBox="0 0 ' + W + ' ' + H + '" aria-hidden="true">' + inner + '</svg>';
    }
  };

  /* =========================================================================
     DELTA — trend & delta indicator helper (Add-DhSummary tile F1)
     Returns either '' (no indicator wanted) or an object
       { dir: 'up'|'down'|'flat', className: 'delta-good'|'delta-bad'|'delta-flat', html: '<arrow> +12 (+5.5%)' }
     Caller wraps the html in <div class="summary-delta delta-<dir> <className>">
     ========================================================================= */
  var DELTA = {
    build: function (item) {
      var curr = Number(item.value);
      var prev = (item.previous != null) ? Number(item.previous) : null;
      var hasPrev = (prev !== null) && isFinite(prev) && isFinite(curr);

      /* Direction: explicit Trend wins; otherwise derive from Previous vs Value */
      var dir = (item.trend && item.trend !== 'auto') ? item.trend : null;
      if (!dir) {
        if (!hasPrev) return '';   /* no signal at all */
        var d0 = curr - prev;
        dir = (d0 > 0) ? 'up' : (d0 < 0 ? 'down' : 'flat');
      }

      /* Compute delta numbers when Previous is supplied */
      var deltaAbs = hasPrev ? (curr - prev) : null;
      var deltaPct = (hasPrev && prev !== 0) ? (deltaAbs / Math.abs(prev)) * 100 : null;

      /* Colour: explicit TrendIsGood overrides; otherwise semantic (up=good, down=bad, flat=neutral) */
      var className;
      if (item.trendIsGood === true)  className = 'delta-good';
      else if (item.trendIsGood === false) className = 'delta-bad';
      else {
        className = (dir === 'up') ? 'delta-good' : (dir === 'down' ? 'delta-bad' : 'delta-flat');
      }

      /* Arrow glyph */
      var arrow = (dir === 'up') ? '▲' : (dir === 'down' ? '▼' : '▶');

      /* Format the textual portion per item.deltaFormat */
      var fmt = item.deltaFormat || 'both';
      function fmtAbs(n) {
        if (n === 0) return '±0';                 /* ±0 */
        var sign = n > 0 ? '+' : '';                    /* '-' is part of the number itself */
        /* Preserve original precision: integer in / integer out; floats use toFixed(decimals||2) */
        var dec = (item.decimals != null && item.decimals >= 0) ? item.decimals : null;
        var body = (dec !== null) ? n.toFixed(dec) : String(n);
        return sign + body;
      }
      function fmtPct(p) {
        var sign = p > 0 ? '+' : '';
        return sign + p.toFixed(1) + '%';
      }

      var parts = [];
      if (deltaAbs !== null && (fmt === 'absolute' || fmt === 'both')) {
        parts.push(fmtAbs(deltaAbs));
      }
      if (deltaPct !== null && (fmt === 'percent' || fmt === 'both')) {
        parts.push(fmt === 'both' ? '(' + fmtPct(deltaPct) + ')' : fmtPct(deltaPct));
      }
      var labelTxt = parts.join(' ');

      return {
        dir: dir,
        className: className,
        html: '<span class="delta-arrow">' + arrow + '</span>' +
              (labelTxt ? ' <span class="delta-text">' + esc(labelTxt) + '</span>' : '')
      };
    }
  };

  /* =========================================================================
     ALERT BANNERS — top-of-page strips above the summary
     ========================================================================= */
  function renderAlerts() {
    if (!ALERTS_CONFIG || !ALERTS_CONFIG.length) return;
    var container = document.getElementById('report-alerts');
    if (!container) return;
    container.innerHTML = '';

    /* Restore dismissed-state from URL hash so reloads keep banners hidden */
    var saved = URLState.load();
    if (saved.alerts && saved.alerts.length) {
      saved.alerts.forEach(function (id) { dismissedAlerts[id] = true; });
    }

    ALERTS_CONFIG.forEach(function (alert) {
      if (dismissedAlerts[alert.id]) return;  /* user dismissed earlier, keep hidden */

      var severityClass = 'alert-' + (alert.severity || 'info');
      var banner = document.createElement('div');
      banner.className = 'alert-banner ' + severityClass;
      banner.setAttribute('data-alert-id', alert.id);
      banner.setAttribute('role', 'alert');
      /* v1.4.2+ — NavGroup binding. The general nav-routing show/hide pass
         picks up [data-navgroup] elements anywhere in the body. */
      if (alert.navGroup)    banner.setAttribute('data-navgroup',    alert.navGroup);
      if (alert.navSubGroup) banner.setAttribute('data-navsubgroup', alert.navSubGroup);

      var iconHtml = alert.icon
        ? '<span class="alert-icon">' + esc(alert.icon) + '</span>'
        : '';
      var actionHtml = '';
      if (alert.action && alert.action.label) {
        actionHtml = '<button class="alert-action-btn" type="button">'
                   + esc(alert.action.label) + '</button>';
      }
      var dismissHtml = alert.dismissible
        ? '<button class="alert-dismiss-btn" type="button" aria-label="Dismiss alert" title="Dismiss">&times;</button>'
        : '';

      /* alert.message may contain inline HTML by design (matches Add-DhHtmlBlock policy) */
      var bodyHtml =
        '<div class="alert-body">'
        + iconHtml
        + '<span class="alert-message">' + alert.message + '</span>'
        + '</div>';
      var actionsHtml = '<div class="alert-actions">' + actionHtml + dismissHtml + '</div>';

      if (alert.collapsible) {
        /* v1.5.1 — wrap the message body in a collapsible header bar.
           The action + dismiss buttons stay outside the collapse so they
           remain reachable when the body is folded away. */
        var isOpen   = alert.defaultOpen !== false;
        var headTxt  = alert.title || '';
        var uidA     = alert.id;
        banner.classList.add('alert-banner-collapsible');
        banner.innerHTML =
          '<div class="alert-collapsible-head">'
          + '<button class="alert-toggle' + (isOpen?' open':'') + '" type="button" '
          +   'id="atoggle-' + uidA + '" aria-expanded="' + (isOpen?'true':'false') + '">'
          +   iconHtml
          +   '<span class="alert-title">' + esc(headTxt) + '</span>'
          +   '<span class="alert-chevron">' + (isOpen?'▾':'▸') + '</span>'
          + '</button>'
          + actionsHtml
          + '</div>'
          + '<div class="alert-collapsible-body' + (isOpen?' open':'') + '" id="abody-' + uidA + '">'
          +   bodyHtml
          + '</div>';
        var aToggle = banner.querySelector('#atoggle-' + uidA);
        var aBody   = banner.querySelector('#abody-' + uidA);
        var aChev   = banner.querySelector('.alert-chevron');
        aToggle.addEventListener('click', function () {
          var open = aBody.classList.toggle('open');
          aToggle.classList.toggle('open', open);
          aToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
          if (aChev) aChev.textContent = open ? '▾' : '▸';
        });
      } else {
        banner.innerHTML = bodyHtml + actionsHtml;
      }

      /* Wire dismiss */
      if (alert.dismissible) {
        var dismissBtn = banner.querySelector('.alert-dismiss-btn');
        dismissBtn.addEventListener('click', function () {
          dismissedAlerts[alert.id] = true;
          banner.classList.add('alert-dismissed');
          /* Match CSS transition before removal */
          setTimeout(function () { banner.remove(); }, 200);
          URLState.save();
        });
      }

      /* Wire action button */
      if (alert.action && alert.action.label) {
        var actionBtn = banner.querySelector('.alert-action-btn');
        actionBtn.addEventListener('click', function () {
          if (alert.action.url) {
            window.open(alert.action.url, '_blank', 'noopener');
            return;
          }
          if (alert.action.tableId) jumpToTable(alert.action.tableId, alert.action.filter);
        });
      }

      container.appendChild(banner);
    });
  }

  /* =========================================================================
     JUMP TO TABLE (v2.1.4) — the ONE path for "show this table, filtered".
     Alert actions, tile actions, status-grid cells and topology nodes all
     call this. Before 2.1.4 each carried its own copy that set filterText
     directly, so the clear (x) button stayed hidden and linked charts went
     stale. Filtering goes through applyTextFilter; add a step there or here,
     never in a caller. Exposed as window._dhJumpToTable.
     ========================================================================= */
  function jumpToTable(tableId, filterText) {
    if (!tableId) return;
    if (window._showPanel) window._showPanel(tableId);
    /* a folded collapsible table would hide the result — unfold it */
    var tgl = document.getElementById('tsect-toggle-' + tableId);
    var bdy = document.getElementById('tsect-body-' + tableId);
    if (tgl && bdy && !bdy.classList.contains('open')) tgl.click();
    var eng = engines[tableId];
    if (eng && filterText !== undefined && filterText !== null && String(filterText) !== '') {
      eng.applyTextFilter(String(filterText));
    }
    var sec = document.getElementById('section-' + tableId);
    if (sec && sec.getBoundingClientRect && sec.scrollIntoView) {
      var r = sec.getBoundingClientRect();
      if (r.top < 0 || r.top > (window.innerHeight || 0) * 0.8) sec.scrollIntoView({ block: 'start' });
    }
  }
  window._dhJumpToTable = jumpToTable;

  /* =========================================================================
     EXPORT LIBRARIES (v2.2.0) — SheetJS / jsPDF / AutoTable on demand.
     Before 2.2.0 they were blocking <script> tags in <head>: an offline
     reader stared at a blank page until cdnjs timed out, then got an
     alert() on click. Now:
       cdn   — injected on the FIRST XLSX/PDF click, with the pinned SRI hash
               and crossorigin=anonymous; the page never waits for them.
       embed — already inlined at the end of <body>; nothing to fetch.
       none  — the buttons are not emitted at all.
     A failed load disables every button that needs that library, with a
     tooltip pointing at CSV, instead of an alert().
     ========================================================================= */
  var _libLoads = {};
  var LIB_PRESENT = {
    xlsx:      function () { return typeof window.XLSX !== 'undefined'; },
    jspdf:     function () { return !!(window.jspdf && window.jspdf.jsPDF) || typeof window.jsPDF === 'function'; },
    autotable: function () {
      var J = window.jsPDF || (window.jspdf && window.jspdf.jsPDF);
      try { return !!J && typeof (new J()).autoTable === 'function'; } catch (e) { return false; }
    }
  };
  function _bridgeJsPdf() {
    if (window.jspdf && window.jspdf.jsPDF && !window.jsPDF) window.jsPDF = window.jspdf.jsPDF;
  }
  function loadExportLib(key) {
    if (_libLoads[key]) return _libLoads[key];
    _libLoads[key] = new Promise(function (resolve, reject) {
      if (LIB_PRESENT[key] && LIB_PRESENT[key]()) { resolve(); return; }
      var lib = EXPORT_LIBS.libs && EXPORT_LIBS.libs[key];
      if (EXPORT_LIBS.mode !== 'cdn' || !lib) { reject(new Error('library ' + key + ' not available')); return; }
      var s = document.createElement('script');
      s.src = lib.url;
      s.integrity = lib.sri;
      s.crossOrigin = 'anonymous';
      s.referrerPolicy = 'no-referrer';
      s.async = true;
      s.onload  = function () { _bridgeJsPdf(); (LIB_PRESENT[key] && !LIB_PRESENT[key]()) ? reject(new Error(key + ' loaded but not usable')) : resolve(); };
      s.onerror = function () { reject(new Error('could not load ' + lib.url)); };
      document.head.appendChild(s);
    });
    /* a failure is final for this page view: retrying would just wait again */
    return _libLoads[key];
  }
  /* jsPDF first: AutoTable patches it when it loads */
  function loadPdfLibs() {
    return loadExportLib('jspdf').then(function () { _bridgeJsPdf(); return loadExportLib('autotable'); });
  }
  function markExportUnavailable(kind) {
    var sel = (kind === 'xlsx') ? '.btn-export.btn-xlsx' : '.btn-export.btn-pdf';
    document.querySelectorAll(sel).forEach(function (b) {
      b.disabled = true;
      b.classList.add('btn-export-unavailable');
      b.title = 'Needs internet: the ' + (kind === 'xlsx' ? 'Excel' : 'PDF') + ' library could not load. Use CSV.';
    });
  }
  function setExportBusy(kind, busy) {
    var sel = (kind === 'xlsx') ? '.btn-export.btn-xlsx' : '.btn-export.btn-pdf';
    document.querySelectorAll(sel).forEach(function (b) {
      b.classList.toggle('btn-export-busy', busy);
      if (busy) b.setAttribute('aria-busy', 'true'); else b.removeAttribute('aria-busy');
    });
  }

  /* =========================================================================
     SUMMARY / TILE HELPERS (module-scope so the bullet, line-chart, and
     summarystrip renderers can all reuse them).
     ========================================================================= */

  /* Threshold matcher (v1.4 F4) — column-style Min/Max bands. Highest
     matching Min wins, supporting the spec-friendly Min-only pattern. */
  function pickThresholdClass(value, thresholds) {
    if (!thresholds || !thresholds.length) return '';
    var best = null, bestMin = -Infinity;
    for (var i = 0; i < thresholds.length; i++) {
      var th = thresholds[i];
      var hasMin = (th.min !== undefined && th.min !== null);
      var hasMax = (th.max !== undefined && th.max !== null);
      if (hasMin && value < th.min) continue;
      if (hasMax && value >= th.max) continue;
      var mv = hasMin ? th.min : -Infinity;
      if (best === null || mv > bestMin) { best = th; bestMin = mv; }
    }
    return best ? (best['class'] || '') : '';
  }

  /* Map a cell-* class to its accent CSS var so SVG strokes can read it. */
  function classToAccent(cls) {
    switch (cls) {
      case 'cell-ok':     return 'var(--cell-ok-fg)';
      case 'cell-warn':   return 'var(--cell-warn-fg)';
      case 'cell-danger': return 'var(--cell-danger-fg)';
      case 'cell-nodata': return 'var(--cell-nodata-fg)';
      default:            return 'var(--accent-primary)';
    }
  }

  /* Background-tint variant — used by the bullet chart for performance bands. */
  function classToAccentBg(cls) {
    switch (cls) {
      case 'cell-ok':     return 'var(--cell-ok-bg)';
      case 'cell-warn':   return 'var(--cell-warn-bg)';
      case 'cell-danger': return 'var(--cell-danger-bg)';
      case 'cell-nodata': return 'var(--cell-nodata-bg)';
      default:            return 'rgba(0,0,0,0.04)';
    }
  }

  /* Tile sub-renderers (delta, sparkline, formatted value).
     These power the standard / bignumber / gauge tiles and run identically
     from the global top-of-page strip AND from each per-NavGroup strip. */
  function tileFormatValue(item) {
    return FMT.apply(
      {format:item.format||'',locale:item.locale||'',decimals:item.decimals,currency:item.currency||''},
      item.value
    ) || String(item.value!==null&&item.value!==undefined?item.value:'');
  }
  function tileDeltaHtml(item) {
    if ((item.previous != null) || (item.trend && item.trend !== 'auto')) {
      var d = DELTA.build(item);
      if (d) return '<div class="summary-delta delta-'+d.dir+' '+d.className+'">'+d.html+'</div>';
    }
    return '';
  }
  function tileSparklineHtml(item) {
    if (item.sparkline && item.sparkline.length) {
      return '<div class="summary-sparkline">' +
             SPARK.build(item.sparkline, {
               style: item.sparklineStyle || 'line',
               min:   item.sparklineMin,
               max:   item.sparklineMax
             }) +
             '</div>';
    }
    return '';
  }

  /* Standard tile (default since 1.3.x) */
  function buildStandardTile(item) {
    var tile = document.createElement('div');
    tile.className = 'summary-tile'+(item['class']?' '+item['class']:'');
    tile.innerHTML = (item.icon?'<span class="summary-icon">'+esc(item.icon)+'</span>':'')+
      '<span class="summary-value">'+esc(tileFormatValue(item))+'</span>'+
      tileDeltaHtml(item)+
      '<span class="summary-label">'+esc(item.label)+'</span>'+
      (item.subLabel?'<span class="summary-sublabel">'+esc(item.subLabel)+'</span>':'')+
      tileSparklineHtml(item);
    return tile;
  }

  /* Big-number hero tile (v1.4 F3) — full-width, very large value typography. */
  function buildBignumberTile(item) {
    var tile = document.createElement('div');
    tile.className = 'summary-tile tile-bignumber'+(item['class']?' '+item['class']:'');
    tile.innerHTML =
      '<div class="bignumber-head">'+
        (item.icon?'<span class="summary-icon">'+esc(item.icon)+'</span>':'')+
        '<span class="summary-label">'+esc(item.label)+'</span>'+
      '</div>'+
      '<div class="bignumber-value">'+esc(tileFormatValue(item))+'</div>'+
      (item.caption?'<div class="bignumber-caption">'+esc(item.caption)+'</div>':'')+
      tileDeltaHtml(item)+
      tileSparklineHtml(item);
    return tile;
  }

  /* Semicircle gauge tile (v1.4 F4). */
  function buildGaugeTile(item) {
    var tile = document.createElement('div');
    tile.className = 'summary-tile tile-gauge'+(item['class']?' '+item['class']:'');

    var rawVal = Number(item.value);
    var min = (item.min != null) ? Number(item.min) : 0;
    var max = (item.max != null) ? Number(item.max) : 100;
    if (max <= min) max = min + 1;
    var isMissing = (item.value === null || item.value === undefined || item.value === '' || !isFinite(rawVal));
    var ratio = isMissing ? 0 : Math.max(0, Math.min(1, (rawVal - min) / (max - min)));

    var matchClass;
    if (isMissing && item.ragNoData) {
      matchClass = 'cell-nodata';
    } else {
      matchClass = pickThresholdClass(rawVal, item.thresholds);
      if (!matchClass) matchClass = item['class'] || '';
    }
    var fillColor = classToAccent(matchClass);

    var cx = 70, cy = 70, r = 56;
    var angle = -Math.PI + ratio * Math.PI;
    var ex = cx + r * Math.cos(angle);
    var ey = cy + r * Math.sin(angle);
    var bgPath   = 'M '+(cx-r)+' '+cy+' A '+r+' '+r+' 0 0 1 '+(cx+r)+' '+cy;
    var fillPath = (ratio > 0)
      ? 'M '+(cx-r)+' '+cy+' A '+r+' '+r+' 0 0 1 '+ex.toFixed(2)+' '+ey.toFixed(2)
      : null;

    var readout = tileFormatValue(item);
    var unitTxt = item.unit ? esc(item.unit) : '';

    var svg =
      '<svg class="gauge-svg" viewBox="0 0 140 80" width="140" height="80" aria-hidden="true">'+
        '<path class="gauge-bg" d="'+bgPath+'" stroke="var(--border-subtle)" stroke-width="10" fill="none" stroke-linecap="round"/>'+
        (fillPath ? '<path class="gauge-fill" d="'+fillPath+'" stroke="'+fillColor+'" stroke-width="10" fill="none" stroke-linecap="round"/>' : '')+
        '<text class="gauge-readout" x="70" y="66" text-anchor="middle" font-family="var(--font-display)" font-size="20" font-weight="700" fill="var(--text-primary)">'+esc(readout)+(unitTxt?'<tspan font-size="12" font-weight="600" fill="var(--text-secondary)">'+unitTxt+'</tspan>':'')+'</text>'+
      '</svg>';

    tile.innerHTML =
      (item.icon?'<span class="summary-icon gauge-icon">'+esc(item.icon)+'</span>':'')+
      svg+
      '<span class="summary-label">'+esc(item.label)+'</span>'+
      (item.subLabel?'<span class="summary-sublabel">'+esc(item.subLabel)+'</span>':'')+
      tileDeltaHtml(item);
    return tile;
  }

  /* Verdict tile (v2.2.0) — full-width overall assessment ("Action required")
     with one chip per severity count. Colour comes from item.class, which
     Add-DhSummary derives from the counts when the author gives none. */
  function buildVerdictTile(item) {
    var tile = document.createElement('div');
    tile.className = 'summary-tile tile-verdict'+(item['class']?' '+item['class']:'');
    var labels = { critical: 'Critical', warning: 'Warning', info: 'Info', ok: 'OK' };
    var chips = '';
    if (item.counts) {
      ['critical','warning','info','ok'].forEach(function (s) {
        if (item.counts[s] > 0) {
          chips += '<span class="verdict-chip verdict-chip-'+s+'"><b>'+esc(item.counts[s])+'</b> '+esc(labels[s])+'</span>';
        }
      });
    }
    tile.innerHTML =
      '<div class="verdict-main">'+
        (item.icon?'<span class="summary-icon verdict-icon">'+esc(item.icon)+'</span>':'')+
        '<div class="verdict-text">'+
          '<span class="summary-label">'+esc(item.label)+'</span>'+
          '<div class="verdict-value">'+esc(tileFormatValue(item))+'</div>'+
          (item.caption?'<div class="verdict-caption">'+esc(item.caption)+'</div>':'')+
        '</div>'+
      '</div>'+
      (chips?'<div class="verdict-chips">'+chips+'</div>':'');
    return tile;
  }

  function buildTile(item) {
    var tile;
    switch ((item.style || 'tile').toLowerCase()) {
      case 'bignumber': tile = buildBignumberTile(item); break;
      case 'gauge':     tile = buildGaugeTile(item);     break;
      case 'verdict':   tile = buildVerdictTile(item);   break;   /* v2.2.0 */
      default:          tile = buildStandardTile(item);  break;
    }
    /* v1.4.2 — per-tile Action makes the whole tile clickable.
       Reuses the same nav-and-filter wiring used by Add-DhAlertBanner. */
    if (item.action && (item.action.tableId || item.action.url)) {
      tile.classList.add('tile-clickable');
      if (item.action.label) tile.setAttribute('title', item.action.label);
      tile.setAttribute('role', 'button');
      tile.setAttribute('tabindex', '0');
      var fire = function () {
        if (item.action.url) {
          window.open(item.action.url, '_blank', 'noopener');
          return;
        }
        if (item.action.tableId) jumpToTable(item.action.tableId, item.action.filter);
      };
      tile.addEventListener('click', fire);
      tile.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); fire(); }
      });
    }
    return tile;
  }

  /* fillStrip — common workhorse used by both renderSummary (top-of-page)
     and the v1.4.1 summarystrip block (per-NavGroup). Optionally wraps the
     tile flow in the collapsible chrome shared with Add-DhCollapsible. */
  function fillStrip(container, items, opts) {
    opts = opts || {};
    container.innerHTML = '';
    if (!items || !items.length) return;

    if (opts.collapsible) {
      var title  = opts.title || 'Summary';
      var icon   = opts.icon  || '';
      var isOpen = opts.defaultOpen !== false;
      var uid    = opts.idSuffix || 'summary';
      container.classList.add('summary-collapsible','collapsible-section');

      var iconHtml = icon ? '<span class="collapsible-icon">'+esc(icon)+'</span> ' : '';
      container.innerHTML =
        '<div class="collapsible-toggle'+(isOpen?' open':'')+'" id="ctoggle-'+uid+'">'+
          '<div class="collapsible-toggle-left">'+
            '<span class="collapsible-title">'+iconHtml+esc(title)+'</span>'+
            '<span class="collapsible-badge">'+items.length+'</span>'+
          '</div>'+
          '<span class="collapsible-chevron">'+(isOpen?'▾':'▸')+'</span>'+
        '</div>'+
        '<div class="collapsible-body'+(isOpen?' open':'')+'" id="cbody-'+uid+'">'+
          '<div class="summary-tile-strip" id="cinner-'+uid+'"></div>'+
        '</div>';

      var toggle = container.querySelector('#ctoggle-'+uid);
      var body   = container.querySelector('#cbody-'+uid);
      var chev   = container.querySelector('.collapsible-chevron');
      toggle.addEventListener('click', function () {
        var open = body.classList.toggle('open');
        toggle.classList.toggle('open', open);
        chev.textContent = open ? '▾' : '▸';
      });

      var inner = container.querySelector('#cinner-'+uid);
      items.forEach(function (item) { inner.appendChild(buildTile(item)); });
      return;
    }

    /* Flat strip */
    items.forEach(function (item) { container.appendChild(buildTile(item)); });
  }

  /* =========================================================================
     SUMMARY TILES — top-of-page strip (no NavGroup; the global summary).
     ========================================================================= */
  function renderSummary() {
    if (!SUMMARY_CONFIG||!SUMMARY_CONFIG.length) return;
    var container = document.getElementById('report-summary');
    if (!container) return;

    fillStrip(container, SUMMARY_CONFIG, {
      collapsible: container.getAttribute('data-collapsible') === 'true',
      title:       container.getAttribute('data-title')   || 'Summary',
      icon:        container.getAttribute('data-icon')    || '',
      defaultOpen: container.getAttribute('data-default-open') !== 'false',
      idSuffix:    'summary'
    });
  }

  /* Per-NavGroup summarystrip block (v1.4.1) — same look as the top strip
     but lives inside the block flow so the nav system can hide/show it. */
  function renderSummaryStrip(container, block) {
    container.className = 'report-summary';
    fillStrip(container, block.items || [], {
      collapsible: !!block.collapsible,
      title:       block.title || 'Summary',
      icon:        block.icon  || '',
      defaultOpen: block.defaultOpen !== false,
      idSuffix:    'summary-' + (block.id || 'group')
    });
  }

'@
}

