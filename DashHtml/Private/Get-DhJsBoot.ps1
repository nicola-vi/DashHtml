function Get-DhJsBoot {
    # Auto-split fragment of the dashboard runtime JS (see Get-DhJsContent).
    return @'
  /* =========================================================================
     BOOT
     ========================================================================= */

  /* v2.1.4 — restore a saved theme NOW, while the script is parsed, so the
     page does not paint in the default theme first and then flash. The two
     theme <style> tags are already in <head>. */
  (function () {
    var m = savedThemeMode();
    if (m) { themeChosen = true; applyThemeMode(m); return; }
    /* v2.2.0 — no saved choice: New-DhDashboard -ThemeMode decides. 'auto'
       follows the system setting, live, until the reader toggles. */
    var def = document.documentElement.getAttribute('data-theme-mode') || 'light';
    if (def === 'auto' && window.matchMedia) {
      var mq = window.matchMedia('(prefers-color-scheme: dark)');
      applyThemeMode(mq.matches ? 'dark' : 'light');
      var follow = function (e) { if (!themeChosen) applyThemeMode(e.matches ? 'dark' : 'light'); };
      if (mq.addEventListener) mq.addEventListener('change', follow);
      else if (mq.addListener) mq.addListener(follow);
    } else if (def === 'dark') {
      applyThemeMode('dark');
    }
  })();

  document.addEventListener('DOMContentLoaded', function () {
    renderSummary();
    renderBlocks();

    TABLES_CONFIG.forEach(function (cfg) {
      engines[cfg.id] = new TableEngine(cfg);
    });
    /* v2.4.0 - column widths are measured with the cell font; measure again once web fonts have loaded */
    if (document.fonts && document.fonts.ready && document.fonts.ready.then) {
      document.fonts.ready.then(function () {
        Object.keys(engines).forEach(function (id) { engines[id]._refit(); });
      });
    }

    /* Bar charts, Mode-A pie charts and table-fed range bars need engines ready.
       v2.1.1 - all three go through blockRenderTarget so a collapsible block is
       re-rendered into its INNER container. Targeting 'block-<id>' directly (as
       barchart and piechart did before 2.1.1) overwrites the collapsible header
       renderBlocks() just built, which is why -Collapsible / -DefaultOpen had no
       visible effect on these block types. */
    BLOCKS_CONFIG.forEach(function (block) {
      if (block.blockType === 'barchart') {
        var bcT = blockRenderTarget(block);
        if (bcT.container) renderBarChart(bcT.container, bcT.block);
      } else if (block.blockType === 'piechart' && block.mode === 'fromtable') {
        var pcT = blockRenderTarget(block);
        if (pcT.container) renderPieChart(pcT.container, pcT.block);
      } else if (block.blockType === 'rangebar' && block.mode === 'fromtable') {
        var rbT = blockRenderTarget(block);
        if (rbT.container) renderRangeBar(rbT.container, rbT.block);
      } else if (block.blockType === 'treefilter') {
        /* v2.4.0 - needs the engine of the table it filters */
        var tfT = blockRenderTarget(block);
        if (tfT.container) renderTreeFilter(tfT.container, tfT.block);
      }
    });

    /* Alert banners — render AFTER engines exist so action filters work,
       and AFTER initNav() exposes window._showPanel. Moved below. */

    /* Global filter bar (v1.9.0) — restore any saved selection, render the
       controls, then subscribe every table (and its derived charts) so a
       change re-filters the whole page at once. */
    var _gfSaved = URLState.load().gf;
    if (_gfSaved) {
      if (_gfSaved.facets) Object.keys(_gfSaved.facets).forEach(function (f) { GlobalFilter.facets[f] = _gfSaved.facets[f]; });
      if (_gfSaved.ranges) Object.keys(_gfSaved.ranges).forEach(function (f) { GlobalFilter.ranges[f] = _gfSaved.ranges[f]; });
    }
    renderGlobalFilters();
    GlobalFilter.subscribe(function () {
      Object.keys(engines).forEach(function (id) {
        var e = engines[id];
        e.currentPage = 1;
        e.render();
        e._refreshLinkedBarCharts();
        e._renderCharts();
      });
      updateNavBadges();
    });
    /* Tables already rendered above without the restored filter — apply it now. */
    if (GlobalFilter.active()) {
      Object.keys(engines).forEach(function (id) {
        var e = engines[id]; e.currentPage = 1; e.render(); e._refreshLinkedBarCharts(); e._renderCharts();
      });
    }

    initNav();
    initSearch();          /* v2.4.0 */
    syncNavTop();
    window.addEventListener('resize', syncNavTop);
    initThemeToggle();
    initDensityToggle();
    initPrint();           /* v2.2.0 */
    initTableCollapsibles();
    /* v2.5.3 - bound here: the runtime is one IIFE, so the page uses no inline on* handlers */
    var topBtn = document.getElementById('btn-nav-top');
    if (topBtn) topBtn.addEventListener('click', function () { window.scrollTo({ top: 0, behavior: 'smooth' }); });

    /* Alert banners — initNav() has now exposed window._showPanel,
       and engines[] exists, so action buttons can navigate + filter. */
    renderAlerts();

    /* ── Restore URL state: density + card filters ── */
    var _saved = URLState.load();
    if (_saved.density) {
      /* v2.1.4 — DENSITY.set moves the toggle's position too */
      DENSITY.set(_saved.density);
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
