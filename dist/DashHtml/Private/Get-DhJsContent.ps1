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
  var ALERTS_CONFIG  = /*%%ALERTS_CONFIG%%*/[];

  /* =========================================================================
     GLOBAL STATE
     ========================================================================= */
  var engines         = {};        /* tableId -> TableEngine */
  var cardFilters     = {};        /* filterId -> { field, values[] } */
  var currentTheme    = 'default'; /* 'default' or 'light' */
  var tableDensity    = 'normal';  /* 'compact' | 'normal' | 'comfortable' */
  var currentGroup    = '';        /* active nav group in two-tier mode */
  var currentSubGroup = '';        /* active nav sub-group in three-tier mode */
  var dismissedAlerts = {};        /* alertId -> true; persisted in URL hash */

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
        /* dismissed alert banners — array of ids */
        var dismissed = Object.keys(dismissedAlerts);
        if (dismissed.length) state.alerts = dismissed;
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
      banner.innerHTML =
        '<div class="alert-body">'
        + iconHtml
        + '<span class="alert-message">' + alert.message + '</span>'
        + '</div>'
        + '<div class="alert-actions">' + actionHtml + dismissHtml + '</div>';

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
          if (alert.action.tableId && window._showPanel) {
            window._showPanel(alert.action.tableId);
            /* Apply filter text if requested */
            if (alert.action.filter && engines[alert.action.tableId]) {
              var eng = engines[alert.action.tableId];
              var inp = document.getElementById('filter-' + alert.action.tableId);
              eng.filterText = alert.action.filter;
              if (inp) inp.value = alert.action.filter;
              eng.currentPage = 1;
              eng.render();
              URLState.save();
            }
          }
        });
      }

      container.appendChild(banner);
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

  function buildTile(item) {
    var tile;
    switch ((item.style || 'tile').toLowerCase()) {
      case 'bignumber': tile = buildBignumberTile(item); break;
      case 'gauge':     tile = buildGaugeTile(item);     break;
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
        if (item.action.tableId && window._showPanel) {
          window._showPanel(item.action.tableId);
          if (item.action.filter && engines[item.action.tableId]) {
            var eng = engines[item.action.tableId];
            var inp = document.getElementById('filter-' + item.action.tableId);
            eng.filterText = item.action.filter;
            if (inp) inp.value = item.action.filter;
            eng.currentPage = 1;
            eng.render();
            URLState.save();
          }
        }
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

  /* =========================================================================
     BLOCKS ENGINE — HTML, Collapsible, FilterCardGrid, BarChart, PieChart
     ========================================================================= */
  function renderBlocks() {
    BLOCKS_CONFIG.forEach(function (block) {
      var container = document.getElementById('block-'+block.id);
      if (!container) return;
      switch (block.blockType) {
        case 'html':           renderHtmlBlock(container, block); break;
        case 'collapsible':    renderCollapsible(container, block); break;
        case 'filtercardgrid': renderFilterCardGrid(container, block); break;
        case 'barchart':       renderBarChart(container, block); break;
        case 'piechart':       renderPieChart(container, block); break;
        case 'bullet':         renderBullet(container, block); break;
        case 'linechart':      renderLineChart(container, block); break;
        case 'eventfeed':      renderEventFeed(container, block); break;
        case 'statusgrid':     renderStatusGrid(container, block); break;
        case 'summarystrip':   renderSummaryStrip(container, block); break;
        case 'tabs':           renderTabs(container, block); break;
        case 'heatmap':        renderHeatmap(container, block); break;
        case 'topologymap':    renderTopologyMap(container, block); break;
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
      panel.innerHTML = '<div class="chart-title">'+esc(opts.title || '')+'</div>'+
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

    panel.innerHTML = '<div class="chart-title">'+esc(opts.title || '')+'</div>'+
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
      opts.onSliceClick = function (entry) {
        var eng = engines[block.tableId];
        if (!eng) return;
        eng.filterText = entry.label;
        var inp = document.getElementById('filter-'+block.tableId);
        if (inp) inp.value = entry.label;
        eng.currentPage = 1;
        eng.render();
        URLState.save();
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
    var direction = (block.direction || 'vertical').toLowerCase();
    var horizontal = (direction === 'horizontal');
    /* Slot = node + outer gap; depth gap = vertical spacing between levels */
    var hGap    = horizontal ? 40 : 24;
    var vGap    = horizontal ? 32 : 56;
    var slotW   = NW + hGap;
    var slotH   = NH + vGap;
    var marginX = 16, marginY = 16;

    /* leafCount(n) — total leaves in subtree rooted at n.
       Used to size each parent's horizontal footprint. */
    function leafCount(n) {
      var kids = childrenOf[n.id];
      if (!kids.length) return 1;
      var sum = 0;
      for (var i = 0; i < kids.length; i++) sum += leafCount(kids[i]);
      return sum;
    }

    /* Layout pass — assigns x/y to each node.
       Vertical mode: width = leafCount × slot, parent centred above kids.
       Horizontal mode: same maths with axes swapped. */
    var positioned = {};
    var maxX = 0, maxY = 0;

    function layoutVertical(n, xOffset, depth) {
      var kids = childrenOf[n.id];
      var width = leafCount(n) * slotW;
      var x;
      if (!kids.length) {
        x = xOffset + (slotW - NW) / 2;
      } else {
        var cursor = xOffset;
        kids.forEach(function (k) {
          var kw = leafCount(k) * slotW;
          layoutVertical(k, cursor, depth + 1);
          cursor += kw;
        });
        /* Centre parent over its children's span */
        var firstX = positioned[kids[0].id].x;
        var lastX  = positioned[kids[kids.length-1].id].x;
        x = (firstX + lastX) / 2;
      }
      var y = marginY + depth * slotH;
      positioned[n.id] = { x: x, y: y };
      if (x + NW > maxX) maxX = x + NW;
      if (y + NH > maxY) maxY = y + NH;
      return width;
    }

    function layoutHorizontal(n, yOffset, depth) {
      var kids = childrenOf[n.id];
      var height = leafCount(n) * slotH;
      var y;
      if (!kids.length) {
        y = yOffset + (slotH - NH) / 2;
      } else {
        var cursor = yOffset;
        kids.forEach(function (k) {
          var kh = leafCount(k) * slotH;
          layoutHorizontal(k, cursor, depth + 1);
          cursor += kh;
        });
        var firstY = positioned[kids[0].id].y;
        var lastY  = positioned[kids[kids.length-1].id].y;
        y = (firstY + lastY) / 2;
      }
      var x = marginX + depth * (NW + vGap);
      positioned[n.id] = { x: x, y: y };
      if (x + NW > maxX) maxX = x + NW;
      if (y + NH > maxY) maxY = y + NH;
      return height;
    }

    /* Walk each root, side-by-side ("forest" layout when multiple roots) */
    if (horizontal) {
      var yCursor = marginY;
      roots.forEach(function (r) {
        var h = leafCount(r) * slotH;
        layoutHorizontal(r, yCursor, 0);
        yCursor += h;
      });
    } else {
      var xCursor = marginX;
      roots.forEach(function (r) {
        var w = leafCount(r) * slotW;
        layoutVertical(r, xCursor, 0);
        xCursor += w;
      });
    }

    var svgW = Math.max(maxX + marginX, 200);
    var svgH = Math.max(maxY + marginY, 100);

    /* Build connector paths first so node rects draw on top. */
    var connectors = '';
    nodes.forEach(function (n) {
      if (!n.parent || !byId[n.parent]) return;
      var p = positioned[n.parent];
      var c = positioned[n.id];
      if (!p || !c) return;
      var px, py, cx, cy, mid;
      if (horizontal) {
        px = p.x + NW;             py = p.y + NH / 2;
        cx = c.x;                  cy = c.y + NH / 2;
        mid = (px + cx) / 2;
        connectors += '<path class="topo-link" d="M '+px.toFixed(1)+' '+py.toFixed(1)+
                      ' C '+mid.toFixed(1)+' '+py.toFixed(1)+', '+mid.toFixed(1)+' '+cy.toFixed(1)+', '+
                      cx.toFixed(1)+' '+cy.toFixed(1)+'" fill="none" stroke="var(--border-strong)" stroke-width="1.5"/>';
      } else {
        px = p.x + NW / 2;         py = p.y + NH;
        cx = c.x + NW / 2;         cy = c.y;
        mid = (py + cy) / 2;
        connectors += '<path class="topo-link" d="M '+px.toFixed(1)+' '+py.toFixed(1)+
                      ' C '+px.toFixed(1)+' '+mid.toFixed(1)+', '+cx.toFixed(1)+' '+mid.toFixed(1)+', '+
                      cx.toFixed(1)+' '+cy.toFixed(1)+'" fill="none" stroke="var(--border-strong)" stroke-width="1.5"/>';
      }
    });

    /* Nodes */
    var nodeMarkup = '';
    nodes.forEach(function (n) {
      var p = positioned[n.id]; if (!p) return;
      var statusClass = n.status ? ' topo-status-'+n.status : '';
      var clickable   = n.linkTableId ? ' topo-clickable' : '';
      var tipAttr     = n.tooltip
        ? ' data-tooltip="' + esc(n.tooltip) + '"'
        : '';
      var dataAttrs = '';
      if (n.linkTableId) {
        dataAttrs += ' data-link-table="' + esc(n.linkTableId) + '"';
        if (n.linkFilter) dataAttrs += ' data-link-filter="' + esc(n.linkFilter) + '"';
      }
      var iconHtml  = n.icon  ? '<span class="topo-node-icon">'+esc(n.icon)+'</span>' : '';
      var badgeHtml = n.badge ? '<span class="topo-node-badge">'+esc(n.badge)+'</span>' : '';
      /* Use foreignObject so we get HTML text layout (truncation, flex) inside SVG */
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

    var svg =
      '<svg class="topology-map-svg" viewBox="0 0 '+svgW+' '+svgH+'" width="100%" height="'+svgH+'" preserveAspectRatio="xMidYMid meet">'+
        connectors +
        nodeMarkup +
      '</svg>';

    container.innerHTML = titleHtml +
      '<div class="topology-map-inner" style="overflow:auto">' + svg + '</div>';

    /* Wire clickable nodes — same machinery as StatusGrid */
    container.querySelectorAll('.topo-clickable').forEach(function (el) {
      el.addEventListener('click', function () {
        var tableId = el.getAttribute('data-link-table');
        var filter  = el.getAttribute('data-link-filter');
        if (!tableId || !window._showPanel) return;
        window._showPanel(tableId);
        if (filter && engines[tableId]) {
          var eng = engines[tableId];
          var inp = document.getElementById('filter-' + tableId);
          eng.filterText = filter;
          if (inp) inp.value = filter;
          eng.currentPage = 1;
          eng.render();
          URLState.save();
        }
      });
    });
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
        if (!tableId || !window._showPanel) return;
        window._showPanel(tableId);
        if (filter && engines[tableId]) {
          var eng = engines[tableId];
          var inp = document.getElementById('filter-' + tableId);
          eng.filterText = filter;
          if (inp) inp.value = filter;
          eng.currentPage = 1;
          eng.render();
          URLState.save();
        }
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
      /* v1.4.2 — native hover tooltip with label / count / percentage */
      var tip = e.label + ': ' + e.count + ' (' + pctTotal + '%)';
      return '<div class="bar-item'+(block.clickFilters?' bar-clickable':'')+'"'+clickAttr+' title="'+esc(tip)+'">'+
        '<div class="bar-label">'+
          '<span class="bar-label-text">'+esc(e.label)+'</span>'+
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

  /* Stacked variant — each primary bar is segmented by block.seriesField.
     Series values are coloured from chartPalette() in alphabetical order so
     the legend stays stable across renders. clickFilters is intentionally
     ignored in stacked mode (the bar has no single Field value to filter by). */
  function renderBarChartStacked(container, block, engine) {
    /* Two-level aggregation: primary[field][series] = count */
    var primary = {};
    var seriesSet = {};
    engine._getFiltered().forEach(function (row) {
      var pv = (row[block.field]      != null) ? String(row[block.field])      : '(empty)';
      var sv = (row[block.seriesField] != null) ? String(row[block.seriesField]) : '(empty)';
      if (!primary[pv]) primary[pv] = { total: 0, byS: {} };
      primary[pv].total += 1;
      primary[pv].byS[sv] = (primary[pv].byS[sv] || 0) + 1;
      seriesSet[sv] = true;
    });
    var seriesValues = Object.keys(seriesSet).sort();
    var primaryEntries = Object.keys(primary).map(function (k) {
      return { label: k, total: primary[k].total, byS: primary[k].byS };
    }).sort(function (a, b) { return b.total - a.total; }).slice(0, block.topN || 10);

    /* Largest total drives the bar width scale */
    var maxTotal = primaryEntries[0] ? primaryEntries[0].total : 1;
    var grandTotal = engine._getFiltered().length;

    /* Colour map: deterministic alphabetic series → palette index */
    var palette = chartPalette();
    var colorOf = {};
    seriesValues.forEach(function (sv, i) { colorOf[sv] = palette[i % palette.length]; });

    var barsHtml = primaryEntries.map(function (p) {
      var widthPct = (p.total / maxTotal * 100).toFixed(2);
      var pctTotal = (p.total / grandTotal * 100).toFixed(0);
      /* Segments — each is sized in proportion to its share of THIS bar's total */
      var segHtml = seriesValues.map(function (sv) {
        var c = p.byS[sv] || 0;
        if (c === 0) return '';
        var segPct = (c / p.total * 100).toFixed(2);
        var tip = sv + ': ' + c;
        return '<div class="bar-segment" style="width:'+segPct+'%;background:'+esc(colorOf[sv])+'" title="'+esc(tip)+'"></div>';
      }).join('');
      return '<div class="bar-item bar-item-stacked">'+
        '<div class="bar-label">'+
          '<span class="bar-label-text" title="'+esc(p.label)+'">'+esc(p.label)+'</span>'+
          (block.showCount  !== false ? '<span class="bar-label-count">'+esc(p.total)+'</span>' : '')+
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
      '<h3 class="bar-chart-title">'+esc(block.title)+'</h3>'+
      '<div class="bar-chart bar-chart-stacked">'+barsHtml+'</div>'+
      legendHtml;
  }

  /* =========================================================================
     NAVIGATION — PANEL MODE  with row-count badges + URL restore
     Two modes:
       flat     — single nav bar, one panel visible at a time (legacy)
       two-tier — primary group tabs + secondary subnav links
     ========================================================================= */
  /* ── Sync nav sticky top to actual header height ────────────────── */
  function syncNavTop() {
    var hdr = document.querySelector('.report-header');
    var nav = document.getElementById('report-nav');
    if (hdr && nav) { nav.style.top = hdr.offsetHeight + 'px'; }
  }

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
      /* Show all block-sections + alert banners bound to this group */
      document.querySelectorAll(
        '.block-section[data-navgroup="'+groupName+'"], .alert-banner[data-navgroup="'+groupName+'"]'
      ).forEach(function (s) {
        s.classList.add('panel-active');
      });
      /* Show/hide subnav strip — hide it when this group has no table sub-links */
      var subnavEl = document.getElementById('nav-subnav');
      if (subnavEl) {
        var hasGroupLinks = !!document.querySelector('#nav-subnav .nav-link[data-group="'+groupName+'"]');
        subnavEl.style.display = hasGroupLinks ? '' : 'none';
      }
      /* Three-tier: show subgroup pill strip if this group has any subgroups */
      var sgEl = document.getElementById('nav-subgroup');
      if (sgEl) {
        var pills = sgEl.querySelectorAll('.subgroup-pill');
        var anyForGroup = false;
        pills.forEach(function (p) {
          var match = (p.dataset.group === groupName);
          p.style.display = match ? '' : 'none';
          p.classList.remove('subgroup-active');
          if (match) anyForGroup = true;
        });
        sgEl.style.display = anyForGroup ? '' : 'none';
        /* Reset subgroup filter — show all items in group */
        currentSubGroup = '';
        document.querySelectorAll('[data-navgroup="'+groupName+'"][data-navsubgroup]').forEach(function (s) {
          s.style.removeProperty('display');
        });
        document.querySelectorAll('#nav-subnav .nav-link[data-group="'+groupName+'"]').forEach(function (l) {
          l.style.removeProperty('display');
        });
        syncNavTop();
      }
      currentGroup = groupName;
      /* Activate first subnav link */
      var firstLink = document.querySelector('#nav-subnav .nav-link[data-group="'+groupName+'"]');
      if (firstLink) {
        showSubPanel(firstLink.dataset.table || firstLink.dataset.panel, groupName);
      } else {
        URLState.save();
      }
      /* Three-tier: auto-select first subgroup pill so that items tagged
         with -NavSubGroup are bound to a single subgroup (visible only when
         their pill is active). Items in the group without -NavSubGroup remain
         visible regardless. */
      var firstPill = sgEl ? sgEl.querySelector('.subgroup-pill[data-group="'+groupName+'"]') : null;
      if (firstPill) {
        showSubGroup(groupName, firstPill.dataset.subgroup);
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

    /* Three-tier: subgroup pill handling */
    var pills = document.querySelectorAll('.subgroup-pill');

    function showSubGroup(groupName, subGroupName) {
      /* Toggle pill active state */
      pills.forEach(function (p) {
        if (p.dataset.group !== groupName) return;
        p.classList.toggle('subgroup-active',
          subGroupName !== '' && p.dataset.subgroup === subGroupName);
      });
      currentSubGroup = subGroupName;

      /* Filter sections in this group by subgroup.
         Sections WITHOUT data-navsubgroup remain visible regardless. */
      document.querySelectorAll('[data-navgroup="'+groupName+'"][data-navsubgroup]').forEach(function (s) {
        var match = (subGroupName === '' || s.dataset.navsubgroup === subGroupName);
        if (match) { s.style.removeProperty('display'); }
        else       { s.style.display = 'none'; s.classList.remove('panel-active'); }
      });

      /* Filter subnav links in this group by subgroup too */
      var firstVisibleLink = null;
      document.querySelectorAll('#nav-subnav .nav-link[data-group="'+groupName+'"]').forEach(function (l) {
        var lsg   = l.dataset.subgroup || '';
        var match = (subGroupName === '' || lsg === '' || lsg === subGroupName);
        if (match) {
          l.style.removeProperty('display');
          if (!firstVisibleLink) firstVisibleLink = l;
        } else {
          l.style.display = 'none';
          l.classList.remove('nav-active');
        }
      });

      /* If the currently active table is now hidden, switch to first visible */
      var activeSub = document.querySelector('#nav-subnav .nav-link.nav-active[data-group="'+groupName+'"]');
      if ((!activeSub || activeSub.style.display === 'none') && firstVisibleLink) {
        showSubPanel(firstVisibleLink.dataset.table || firstVisibleLink.dataset.panel, groupName);
      }

      URLState.save();
    }

    /* Wire subgroup pill clicks — toggle off when clicking the active pill */
    pills.forEach(function (pill) {
      pill.addEventListener('click', function (e) {
        e.preventDefault();
        var isActive = pill.classList.contains('subgroup-active');
        showSubGroup(pill.dataset.group, isActive ? '' : pill.dataset.subgroup);
      });
    });

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

    window._showPanel    = showSubPanel;
    window._showGroup    = showGroup;
    window._showSubGroup = showSubGroup;
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

  /* Re-render any bar charts and Mode-A pie charts that reference this table */
  TableEngine.prototype._refreshLinkedBarCharts = function () {
    var id = this.id;
    BLOCKS_CONFIG.forEach(function (block) {
      if (block.blockType === 'barchart' && block.tableId === id) {
        var container = document.getElementById('block-' + block.id);
        if (container) renderBarChart(container, block);
      } else if (block.blockType === 'piechart' && block.mode === 'fromtable' && block.tableId === id) {
        var container = document.getElementById('block-' + block.id);
        if (container) renderPieChart(container, block);
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
      /* Pre-build a field → column map so we can spot sparkline columns
         without scanning self.columns inside the hot comparator loop. */
      var colMap = {};
      (self.columns||[]).forEach(function(c){ colMap[c.field] = c; });
      data=data.slice().sort(function(a,b){
        for (var i=0;i<self.sortFields.length;i++) {
          var sf=self.sortFields[i].field,sd=self.sortFields[i].dir;
          var col=colMap[sf];
          var av=(a[sf]!=null)?a[sf]:'',bv=(b[sf]!=null)?b[sf]:'';
          /* v1.4 F8 — sparkline columns reduce arrays to a comparable scalar */
          if (col && col.cellType === 'sparkline') {
            av = sparkReduce(av, col.sortBy);
            bv = sparkReduce(bv, col.sortBy);
          }
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
      td.innerHTML='<div class="progress-wrap"><span class="progress-label">'+dispVal+'</span>'+
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

    /* Bar charts and Mode-A pie charts need engines ready */
    BLOCKS_CONFIG.forEach(function (block) {
      if (block.blockType === 'barchart') {
        var container = document.getElementById('block-'+block.id);
        if (container) renderBarChart(container, block);
      } else if (block.blockType === 'piechart' && block.mode === 'fromtable') {
        var container = document.getElementById('block-'+block.id);
        if (container) renderPieChart(container, block);
      }
    });

    /* Alert banners — render AFTER engines exist so action filters work,
       and AFTER initNav() exposes window._showPanel. Moved below. */

    initNav();
    syncNavTop();
    window.addEventListener('resize', syncNavTop);
    initThemeToggle();
    initDensityToggle();

    /* Alert banners — initNav() has now exposed window._showPanel,
       and engines[] exists, so action buttons can navigate + filter. */
    renderAlerts();

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
