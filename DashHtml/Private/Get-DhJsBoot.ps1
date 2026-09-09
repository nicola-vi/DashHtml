function Get-DhJsBoot {
    # Auto-split fragment of the dashboard runtime JS (see Get-DhJsContent).
    return @'
  /* =========================================================================
     BOOT
     ========================================================================= */
  document.addEventListener('DOMContentLoaded', function () {
    renderSummary();
    renderBlocks();

    TABLES_CONFIG.forEach(function (cfg) {
      engines[cfg.id] = new TableEngine(cfg);
    });

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
    syncNavTop();
    window.addEventListener('resize', syncNavTop);
    initThemeToggle();
    initDensityToggle();
    initTableCollapsibles();

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
