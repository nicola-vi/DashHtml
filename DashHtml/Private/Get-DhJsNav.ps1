function Get-DhJsNav {
    # Auto-split fragment of the dashboard runtime JS (see Get-DhJsContent).
    return @'
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

  /* v1.5.1 — Wire the per-table collapsible toggle. Each Add-DhTable
     section that opted into -Collapsible emits a header button and a
     wrapped .table-section-body; this binds the click handler. */
  function initTableCollapsibles() {
    var toggles = document.querySelectorAll('.table-section-toggle');
    toggles.forEach(function (btn) {
      var bodyId = btn.id.replace(/^tsect-toggle-/, 'tsect-body-');
      var body   = document.getElementById(bodyId);
      var chev   = btn.querySelector('.table-section-chevron');
      if (!body) return;
      btn.addEventListener('click', function () {
        var open = body.classList.toggle('open');
        btn.classList.toggle('open', open);
        btn.setAttribute('aria-expanded', open ? 'true' : 'false');
        if (chev) chev.innerHTML = open ? '&#9662;' : '&#9656;';
      });
    });
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

'@
}
