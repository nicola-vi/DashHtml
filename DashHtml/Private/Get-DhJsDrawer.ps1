function Get-DhJsDrawer {
    # Fragment of the dashboard runtime JS (see Get-DhJsContent). v2.3.0.
    return @'
  /* =========================================================================
     SECTIONS + DETAIL DRAWER (v2.3.0)
     renderSections() is the ONE place that draws the section kinds
        kv | bars | statusList | checks | table | text | links
     for the detail drawer, Add-DhKeyValue, Add-DhRecordList and the findings
     split layout. It is pure (spec in, HTML string out) and escapes every
     value. dhDrawer is a single right-hand panel appended to <body>, outside
     every [data-navpath] section, so it survives view changes (applyNav closes
     it on purpose). No inline on* handlers: bindSectionLinks() binds after the
     markup is written.
     ========================================================================= */

  var SEC_STATUS = {
    ok: 'ok', good: 'ok', pass: 'ok', passed: 'ok', healthy: 'ok',
    warn: 'warn', warning: 'warn', medium: 'warn',
    danger: 'danger', critical: 'danger', error: 'danger', fail: 'danger', failed: 'danger', high: 'danger',
    info: 'info', low: 'info',
    nodata: 'nodata', unknown: 'nodata', skipped: 'nodata'
  };
  /* Status or cell-* class -> one of ok|warn|danger|info|nodata (default nodata). */
  function secStatus(v) {
    var s = String(v == null ? '' : v).toLowerCase().replace(/^cell-/, '');
    return SEC_STATUS[s] || (s ? 'nodata' : '');
  }
  function secCls(v) { var k = secStatus(v); return k ? ' dh-st-' + k : ''; }
  var SEC_LABEL = { ok: 'OK', warn: 'Warning', danger: 'Critical', info: 'Info', nodata: 'Unknown' };
  var SEC_URL_OK =/^(https?:|mailto:|tel:|#)/i;

  function secCell(c) {
    if (c && typeof c === 'object') {
      var k = secStatus(c.status);
      return k ? '<span class="dh-pill dh-st-' + k + '">' + esc(c.text) + '</span>' : esc(c.text);
    }
    return esc(c);
  }

  function renderSection(sec) {
    if (!sec || typeof sec !== 'object') return '';
    var kind = String(sec.kind || 'text').toLowerCase();
    var items = sec.items || [];
    var h = '<section class="dh-sec dh-sec-' + esc(kind) + '">';
    if (sec.title) h += '<h4 class="dh-sec-title">' + esc(sec.title) + '</h4>';

    if (kind === 'kv') {
      var cols = (sec.columns >= 1 && sec.columns <= 6) ? sec.columns : 2;
      h += '<dl class="dh-kv dh-kv-cols-' + cols + '">' + items.map(function (it) {
        var shown = it.value == null || it.value === '' ? '&#8212;' : esc(it.value);
        /* v2.6.0 - a table link column (TableEngine._linkFor sets _link); vetted again here */
        var lu = it._link ? dhLinkUrl(it._link, true) : '';
        if (lu) shown = '<a class="cell-link" href="' + esc(lu) + '"' + (it._newTab ? ' target="_blank" rel="noopener noreferrer"' : '') + '>' + shown + '</a>';
        return '<div class="dh-kv-item' + secCls(it.status || it['class']) + '"><dt class="dh-kv-label">' + esc(it.label) +
               '</dt><dd class="dh-kv-value">' + shown + '</dd></div>';
      }).join('') + '</dl>';
    } else if (kind === 'bars') {
      var mx = sec.max > 0 ? sec.max : items.reduce(function (m, it) { var v = Number(it.value); return v > m ? v : m; }, 0);
      h += '<div class="dh-bars">' + items.map(function (it) {
        var v = Number(it.value), ok = isFinite(v) && it.value !== '' && it.value != null;
        var pct = (ok && mx > 0) ? Math.max(0, Math.min(100, v / mx * 100)) : 0;
        var shown = it.display != null ? it.display : (ok ? v + (sec.unit ? ' ' + sec.unit : '') : '—');
        return '<div class="dh-bar-row"><span class="dh-bar-label">' + esc(it.label) + '</span>' +
               '<span class="dh-bar-track"><span class="dh-bar-fill' + secCls(it.status || it['class']) + '" style="width:' + pct.toFixed(1) + '%"></span></span>' +
               '<span class="dh-bar-val">' + esc(shown) + '</span></div>';
      }).join('') + '</div>';
    } else if (kind === 'statuslist') {
      h += '<ul class="dh-statuslist">' + items.map(function (it) {
        return '<li class="dh-statusrow"><span class="dh-statuslabel">' + esc(it.label) + '</span>' +
               '<span class="dh-statusval' + secCls(it.status) + '"><i class="dh-dot"></i>' + esc(it.text != null ? it.text : it.status) + '</span></li>';
      }).join('') + '</ul>';
    } else if (kind === 'checks') {
      h += '<ul class="dh-checks">' + items.map(function (it) {
        var st = it.status ? secStatus(it.status) : (it.ok === false ? 'danger' : (it.ok === true ? 'ok' : 'nodata'));
        var glyph = st === 'ok' ? '&#10003;' : (st === 'danger' ? '&#10007;' : (st === 'warn' ? '!' : '&middot;'));
        return '<li class="dh-check dh-st-' + st + '"><span class="dh-check-ico" aria-hidden="true">' + glyph + '</span>' +
               '<span class="dh-check-label">' + esc(it.label) + '</span>' +
               (it.note ? '<span class="dh-check-note">' + esc(it.note) + '</span>' : '') + '</li>';
      }).join('') + '</ul>';
    } else if (kind === 'table') {
      var heads = sec.columns || [], rows = sec.rows || [];
      var maxRows = sec.maxRows >= 1 ? sec.maxRows : 50;
      var shownRows = rows.slice(0, maxRows);
      h += '<div class="dh-tbl-wrap"><table class="dh-tbl"><thead><tr>' +
           heads.map(function (c) { return '<th>' + esc(c) + '</th>'; }).join('') + '</tr></thead><tbody>' +
           shownRows.map(function (r) {
             return '<tr>' + (r || []).map(function (c) { return '<td>' + secCell(c) + '</td>'; }).join('') + '</tr>';
           }).join('') + '</tbody></table></div>';
      if (rows.length > shownRows.length) h += '<p class="dh-more">+' + (rows.length - shownRows.length) + ' more</p>';
    } else if (kind === 'links') {
      h += '<ul class="dh-links">' + items.map(function (it) {
        return '<li>' + (SEC_URL_OK.test(String(it.url || ''))
          ? '<a href="' + esc(it.url) + '" target="_blank" rel="noopener noreferrer">' + esc(it.label || it.url) + '</a>'
          : '<span class="dh-link-blocked">' + esc(it.label || it.url) + '</span>') + '</li>';
      }).join('') + '</ul>';
    } else {
      h += '<p class="dh-text">' + esc(sec.text) + '</p>';
    }
    return h + '</section>';
  }

  /* sections: array of section specs. Returns an HTML string. */
  function renderSections(sections) {
    return (sections || []).map(renderSection).join('');
  }

  /* Add-DhKeyValue block */
  function renderKeyValue(container, block) {
    container.className = 'keyvalue-section';
    container.innerHTML =
      (block.title ? '<h3 class="keyvalue-title">' + esc(block.title) + '</h3>' : '') +
      renderSections(block.sections);
  }

  /* Add-DhRecordList block: one row per record (status dot, title, sub line, up to
     four metrics, chevron) that expands to its sections. The bodies are built once,
     hidden; print shows them all through CSS, with no handler needed. */
  function renderRecordList(container, block) {
    container.className = 'recordlist-section';
    var items = block.items || [];
    var uid = 'rec-' + block.id;
    var html = items.map(function (r, i) {
      var open = !!block.openAll;
      var rid = uid + '-' + i;
      var metrics = (r.metrics || []).map(function (m) {
        return '<span class="record-metric' + secCls(m.status) + '"><span class="record-metric-value">' + esc(m.value) +
               '</span><span class="record-metric-label">' + esc(m.label) + '</span></span>';
      }).join('');
      return '<div class="record' + (open ? ' open' : '') + '" data-ri="' + i + '" data-record-id="' + esc(r.id) + '">' +
        '<button type="button" class="record-head" aria-expanded="' + (open ? 'true' : 'false') + '" aria-controls="' + esc(rid) + '-body">' +
          '<span class="record-dot' + secCls(r.status) + '" aria-hidden="true"></span>' +
          '<span class="record-text"><span class="record-title">' + esc(r.title) + '</span>' +
            (r.subtitle ? '<span class="record-sub">' + esc(r.subtitle) + '</span>' : '') + '</span>' +
          '<span class="record-metrics">' + metrics + '</span>' +
          '<span class="record-chevron" aria-hidden="true">' + (open ? '&#9662;' : '&#9656;') + '</span>' +
        '</button>' +
        '<div class="record-body" id="' + esc(rid) + '-body"' + (open ? '' : ' hidden') + '>' + (renderSections(r.sections) || '<p class="dh-text">No further detail.</p>') + '</div>' +
      '</div>';
    }).join('');

    var tools = '';
    if (items.length > 1) {
      tools = '<div class="recordlist-toolbar">' +
        (block.filterable !== false ? '<input type="search" class="recordlist-filter" placeholder="Filter&#8230;" aria-label="Filter records">' : '') +
        '<button type="button" class="recordlist-btn" data-act="open">Expand all</button>' +
        '<button type="button" class="recordlist-btn" data-act="close">Collapse all</button></div>';
    }
    container.innerHTML =
      (block.title ? '<h3 class="recordlist-title">' + esc(block.title) + '</h3>' : '') + tools +
      (items.length ? '<div class="recordlist">' + html + '</div><p class="recordlist-none" hidden>No records match the filter.</p>'
                    : '<p class="recordlist-none">No records.</p>');

    function setOpen(el, open) {
      el.classList.toggle('open', open);
      var head = el.querySelector('.record-head'), body = el.querySelector('.record-body');
      if (head) head.setAttribute('aria-expanded', open ? 'true' : 'false');
      if (body) { if (open) body.removeAttribute('hidden'); else body.setAttribute('hidden', ''); }
      var chev = el.querySelector('.record-chevron');
      if (chev) chev.innerHTML = open ? '&#9662;' : '&#9656;';
    }
    container.querySelectorAll('.record-head').forEach(function (head) {
      head.addEventListener('click', function () {
        var el = head.parentNode;
        setOpen(el, !el.classList.contains('open'));
      });
    });
    container.querySelectorAll('.recordlist-btn').forEach(function (b) {
      b.addEventListener('click', function () {
        var open = b.getAttribute('data-act') === 'open';
        container.querySelectorAll('.record').forEach(function (el) { if (!el.hidden) setOpen(el, open); });
      });
    });

    var hay = items.map(function (r) {
      var parts = [r.title, r.subtitle, r.status];
      (r.metrics || []).forEach(function (m) { parts.push(m.label, m.value); });
      (r.sections || []).forEach(function (s) {
        parts.push(s.title, s.text);
        (s.items || []).forEach(function (it) { parts.push(it.label, it.value, it.text, it.note); });
        (s.rows || []).forEach(function (row) { (row || []).forEach(function (c) { parts.push(c && typeof c === 'object' ? c.text : c); }); });
      });
      return parts.filter(function (p) { return p !== undefined && p !== null; }).join('\n').toLowerCase();
    });
    var input = container.querySelector('.recordlist-filter');
    if (input) input.addEventListener('input', function () {
      var term = input.value.trim().toLowerCase(), visible = 0;
      container.querySelectorAll('.record').forEach(function (el) {
        var ok = !term || hay[parseInt(el.getAttribute('data-ri'), 10)].indexOf(term) !== -1;
        el.hidden = !ok;
        if (ok) visible++;
      });
      var none = container.querySelector('.recordlist-none');
      if (none) none.hidden = visible > 0;
    });
  }

  /* ── The drawer ─────────────────────────────────────────────────────── */
  var _drawer = null;     /* { root, backdrop, body, title, sub, close, opener, restore } */

  function dhDrawerEnsure() {
    if (_drawer) return _drawer;
    var backdrop = document.createElement('div');
    backdrop.className = 'dh-drawer-backdrop';
    backdrop.hidden = true;
    var root = document.createElement('aside');
    root.className = 'dh-drawer';
    root.setAttribute('role', 'dialog');
    root.setAttribute('aria-modal', 'true');
    root.setAttribute('aria-label', 'Details');
    root.hidden = true;
    root.innerHTML =
      '<header class="dh-drawer-head">' +
        '<div class="dh-drawer-heading"><div class="dh-drawer-title"></div><div class="dh-drawer-sub"></div></div>' +
        '<button type="button" class="dh-drawer-close" aria-label="Close details">&#215;</button>' +
      '</header>' +
      '<div class="dh-drawer-body"></div>';
    document.body.appendChild(backdrop);
    document.body.appendChild(root);
    _drawer = {
      root: root, backdrop: backdrop,
      body:  root.querySelector('.dh-drawer-body'),
      title: root.querySelector('.dh-drawer-title'),
      sub:   root.querySelector('.dh-drawer-sub'),
      close: root.querySelector('.dh-drawer-close'),
      opener: null, restore: null
    };
    _drawer.close.addEventListener('click', dhDrawerClose);
    backdrop.addEventListener('click', dhDrawerClose);
    root.addEventListener('keydown', function (e) {
      if (e.key !== 'Tab') return;
      var f = root.querySelectorAll('button, a[href], input, [tabindex="0"]');
      if (!f.length) return;
      var first = f[0], last = f[f.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && _drawer && !_drawer.root.hidden) { e.stopPropagation(); dhDrawerClose(); }
    }, true);
    return _drawer;
  }

  /* spec: { title, subtitle, sections:[...], tableId, filter }
     opts: { opener: element to give focus back to,
             restore: selector used when the opener was re-rendered }
     When spec.tableId is set a "Show in table" button is added. */
  function dhDrawerOpen(spec, opts) {
    var d = dhDrawerEnsure();
    spec = spec || {};
    opts = opts || {};
    d.opener  = opts.opener || document.activeElement || null;
    d.restore = opts.restore || null;
    d.title.textContent = spec.title == null ? '' : String(spec.title);
    d.sub.textContent   = spec.subtitle == null ? '' : String(spec.subtitle);
    d.sub.hidden = !d.sub.textContent;
    d.root.setAttribute('aria-label', d.title.textContent || 'Details');
    var html = renderSections(spec.sections);
    if (spec.tableId) html += '<div class="dh-drawer-actions"><button type="button" class="dh-drawer-jump">Show in table &#8594;</button></div>';
    d.body.innerHTML = html || '<p class="dh-text">No further detail.</p>';
    var jump = d.body.querySelector('.dh-drawer-jump');
    if (jump) jump.addEventListener('click', function () {
      dhDrawerClose(true);
      jumpToTable(spec.tableId, spec.filter);
    });
    d.backdrop.hidden = false;
    d.root.hidden = false;
    d.root.classList.add('open');
    d.body.scrollTop = 0;
    d.close.focus();
  }

  /* skipFocus: the caller is about to move focus elsewhere itself. */
  function dhDrawerClose(skipFocus) {
    if (!_drawer || _drawer.root.hidden) return;
    var d = _drawer;
    d.root.classList.remove('open');
    d.root.hidden = true;
    d.backdrop.hidden = true;
    if (skipFocus === true) return;
    var target = d.opener;
    if ((!target || !document.body.contains(target)) && d.restore) target = document.querySelector(d.restore);
    if (target && target.focus) target.focus();
  }

  window._dhOpenDrawer  = dhDrawerOpen;
  window._dhCloseDrawer = dhDrawerClose;

'@
}
