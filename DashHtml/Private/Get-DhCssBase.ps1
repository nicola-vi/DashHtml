function Get-DhCssBase {
    <#
    .SYNOPSIS  Returns the shared structural CSS used by all themes.
               The :root {} token block is NOT included - themes supply that.
    #>
    return @'
/* ---------------------------------------------------------------------------
   2. RESET & BASE
   --------------------------------------------------------------------------- */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

html {
  font-size: 16px;
  -webkit-font-smoothing: antialiased;
  scroll-behavior: smooth;
}

body {
  background-color: var(--bg-page);
  color: var(--text-primary);
  font-family: var(--font-ui);
  font-size: var(--size-base);
  font-weight: var(--weight-normal);
  line-height: 1.5;
  min-height: 100vh;
}

/* ---------------------------------------------------------------------------
   3. REPORT HEADER
   --------------------------------------------------------------------------- */
.report-header {
  background: var(--bg-header);
  border-bottom: 1px solid var(--border-subtle);
  min-height: var(--header-height);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-sm) var(--space-xl) var(--space-md);
  position: sticky;
  top: 0;
  z-index: 100;
  box-shadow: var(--shadow-md);
  margin-bottom: 8px;
}

.report-header::after {
  content: '';
  position: absolute;
  bottom: 0; left: 0; right: 0;
  height: 2px;
  background: linear-gradient(90deg, transparent, var(--accent-primary), transparent);
}

.header-brand {
  display: flex;
  align-items: center;
  gap: var(--space-md);
  min-width: 0;
}

.report-logo {
  height: 44px;
  width: auto;
  max-width: 160px;
  object-fit: contain;
  flex-shrink: 0;
  border-radius: var(--radius-sm);
  filter: brightness(0.95);
}

.report-logo-placeholder {
  width: 44px;
  height: 44px;
  background: var(--bg-surface);
  border: 1px solid var(--border-medium);
  border-radius: var(--radius-sm);
  flex-shrink: 0;
}

.header-titles { min-width: 0; }

.report-title {
  font-family: var(--font-display);
  font-size: var(--size-xl);
  font-weight: var(--weight-bold);
  color: var(--header-fg);
  letter-spacing: -0.02em;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.report-subtitle {
  font-size: var(--size-sm);
  color: var(--header-fg-muted);
  margin-top: 2px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.header-meta {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  flex-shrink: 0;
  gap: 2px;
}

.meta-label {
  font-size: var(--size-xs);
  color: var(--header-fg-muted);
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.meta-value {
  font-family: var(--font-mono);
  font-size: var(--size-sm);
  color: var(--header-fg-muted);
}

/* ---------------------------------------------------------------------------
   4. REPORT BODY
   --------------------------------------------------------------------------- */
.report-body {
  max-width: 2400px;
  margin: 0 auto;
  padding: var(--space-xl) var(--space-md);
  display: flex;
  flex-direction: column;
  gap: var(--space-xl);
}

/* ---------------------------------------------------------------------------
   5. TABLE SECTION
   --------------------------------------------------------------------------- */
.table-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  overflow: clip;
  box-shadow: var(--shadow-md);
  transition: box-shadow var(--trans-normal);
}

.table-section:hover {
  box-shadow: var(--shadow-md), var(--shadow-glow);
}

.table-section-header {
  padding: var(--space-md) var(--space-lg);
  border-bottom: 1px solid var(--border-subtle);
  background: linear-gradient(180deg, #151e2b 0%, var(--bg-surface) 100%);
}

/* v1.5.1 — Per-table collapsible chrome. The clickable toggle replaces the
   plain header row when -Collapsible $true; the body wrapper folds the
   toolbar / table / paging when closed. */
.table-section-toggle {
  display: flex;
  align-items: center;
  width: 100%;
  background: linear-gradient(180deg, #151e2b 0%, var(--bg-surface) 100%);
  border: none;
  border-bottom: 1px solid var(--border-subtle);
  padding: 0;
  cursor: pointer;
  color: inherit;
  font: inherit;
  text-align: left;
}
.table-section-toggle .table-section-header-clickable {
  flex: 1;
  border-bottom: none;
  background: transparent;
}
.table-section-toggle .table-section-chevron {
  padding: 0 var(--space-lg);
  color: var(--text-muted);
  font-size: 0.9rem;
  transition: color var(--trans-fast);
}
.table-section-toggle:hover .table-section-chevron { color: var(--text-primary); }
.table-section-toggle .table-section-icon { margin-right: 6px; }
.table-section-body {
  max-height: 0;
  overflow: hidden;
  transition: max-height var(--trans-med);
}
.table-section-body.open {
  max-height: none;
  overflow: visible;
}
/* When collapsed, hide its border + box-shadow halo since there's nothing to surround */
.table-section-collapsible .table-section-body:not(.open) { border-bottom: none; }

.table-title {
  font-family: var(--font-display);
  font-size: var(--size-lg);
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  letter-spacing: -0.01em;
}

.table-description {
  font-size: var(--size-sm);
  color: var(--text-secondary);
  margin-top: var(--space-xs);
  line-height: 1.4;
}

/* ---------------------------------------------------------------------------
   6. TOOLBAR
   --------------------------------------------------------------------------- */
.table-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-sm) var(--space-lg);
  background: var(--bg-surface);
  border-bottom: 1px solid var(--border-subtle);
  gap: var(--space-sm);
  flex-wrap: wrap;
}

.toolbar-left,
.toolbar-right {
  display: flex;
  align-items: center;
  gap: var(--space-sm);
  flex-wrap: wrap;
}

/* Filter */
.filter-wrap {
  display: flex;
  align-items: center;
  background: var(--bg-table);
  border: 1px solid var(--border-medium);
  border-radius: var(--radius-md);
  overflow: hidden;
  transition: border-color var(--trans-fast), box-shadow var(--trans-fast);
}

.filter-wrap:focus-within {
  border-color: var(--accent-primary);
  box-shadow: 0 0 0 2px #00c8ff33;
}

.filter-icon {
  padding: 0 var(--space-sm);
  color: var(--text-muted);
  font-size: var(--size-md);
  user-select: none;
  pointer-events: none;
}

.filter-input {
  background: transparent;
  border: none;
  outline: none;
  color: var(--text-primary);
  font-family: var(--font-ui);
  font-size: var(--size-sm);
  padding: 6px var(--space-sm) 6px 0;
  width: 220px;
  min-width: 120px;
}

.filter-input::placeholder { color: var(--text-muted); }

.filter-clear {
  background: none;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  padding: 0 var(--space-sm);
  font-size: var(--size-md);
  line-height: 1;
  display: none;
  align-items: center;
  transition: color var(--trans-fast);
}

.filter-clear:hover { color: var(--accent-danger); }

/* Info + page size */
.table-info {
  font-family: var(--font-mono);
  font-size: var(--size-xs);
  color: var(--text-muted);
  white-space: nowrap;
}

.pagesize-label {
  display: flex;
  align-items: center;
  gap: var(--space-xs);
  font-size: var(--size-xs);
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

.pagesize-select {
  background: var(--bg-table);
  border: 1px solid var(--border-medium);
  border-radius: var(--radius-sm);
  color: var(--text-primary);
  font-size: var(--size-sm);
  padding: 4px var(--space-sm);
  outline: none;
  cursor: pointer;
  transition: border-color var(--trans-fast);
}

.pagesize-select:focus { border-color: var(--accent-primary); }

/* Clear selection */
.btn-clear-sel {
  display: inline-flex;
  align-items: center;
  gap: var(--space-xs);
  background: none;
  border: 1px solid var(--border-medium);
  border-radius: var(--radius-sm);
  color: var(--text-secondary);
  font-size: var(--size-xs);
  padding: 4px var(--space-sm);
  cursor: pointer;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  transition: border-color var(--trans-fast), color var(--trans-fast);
}

.btn-clear-sel:hover {
  border-color: var(--accent-danger);
  color: var(--accent-danger);
}

/* ---------------------------------------------------------------------------
   7. EXPORT BUTTONS
   --------------------------------------------------------------------------- */
.export-group {
  display: flex;
  align-items: center;
  gap: 4px;
  border-left: 1px solid var(--border-subtle);
  padding-left: var(--space-sm);
  margin-left: 2px;
}

.btn-export {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  border-radius: var(--radius-sm);
  font-family: var(--font-mono);
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  letter-spacing: 0.05em;
  padding: 4px 9px;
  cursor: pointer;
  transition: filter var(--trans-fast), transform var(--trans-fast);
  white-space: nowrap;
  border-width: 1px;
  border-style: solid;
}

.btn-export:hover  { filter: brightness(1.25); transform: translateY(-1px); }
.btn-export:active { transform: translateY(0); filter: brightness(0.9); }

.btn-csv {
  background: var(--export-csv-bg);
  color: var(--export-csv-fg);
  border-color: var(--export-csv-bdr);
}

.btn-xlsx {
  background: var(--export-xlsx-bg);
  color: var(--export-xlsx-fg);
  border-color: var(--export-xlsx-bdr);
}

.btn-pdf {
  background: var(--export-pdf-bg);
  color: var(--export-pdf-fg);
  border-color: var(--export-pdf-bdr);
}

/* ---------------------------------------------------------------------------
   8. TABLE
   --------------------------------------------------------------------------- */
.table-wrapper {
  overflow-x: auto;
}

.data-table {
  width: 100%;
  border-collapse: collapse;
  font-size: var(--size-base);
  table-layout: auto;
}

/* Head */
.data-table thead {
  background: var(--bg-thead);
  position: static;
  z-index: auto;
}

.data-table thead th {
  padding: 10px var(--space-md);
  text-align: left;
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-secondary);
  border-bottom: 2px solid var(--border-medium);
  white-space: nowrap;
  user-select: none;
}

.data-table thead th.sortable {
  cursor: pointer;
  transition: color var(--trans-fast), background var(--trans-fast);
}

.data-table thead th.sortable:hover {
  color: var(--text-accent);
  background: var(--bg-row-hover);
}

.data-table thead th.sorted { color: var(--accent-primary); }

.col-label { vertical-align: middle; }

/* Sort icons */
.sort-icon {
  display: inline-block;
  margin-left: 5px;
  width: 10px;
  vertical-align: middle;
  opacity: 0.35;
  font-size: 10px;
  transition: opacity var(--trans-fast);
}

.sort-icon::before         { content: '\2195'; }
.sort-icon.sort-asc::before  { content: '\2191'; }
.sort-icon.sort-desc::before { content: '\2193'; }

th.sorted .sort-icon { opacity: 1; }

/* Selection column */
.col-select {
  width: 36px;
  text-align: center;
  padding: 0 var(--space-sm) !important;
}

.col-select input[type="checkbox"] {
  accent-color: var(--accent-primary);
  width: 15px;
  height: 15px;
  cursor: pointer;
}

/* Body rows */
.data-table tbody tr {
  height: var(--row-height);
  border-bottom: 1px solid var(--border-subtle);
  background: var(--bg-table);
  cursor: pointer;
  transition: background var(--trans-fast);
}

.data-table tbody tr:nth-child(even) { background: var(--bg-row-alt); }
.data-table tbody tr:hover           {
  background: var(--bg-row-hover) !important;
  box-shadow: inset 3px 0 0 var(--accent-primary);
}

.data-table tbody tr.row-selected {
  background: var(--bg-row-sel) !important;
  border-left: 3px solid var(--accent-primary);
}

.data-table tbody tr.row-selected td:first-child {
  padding-left: calc(var(--space-md) - 3px);
}

.data-table tbody td {
  padding: 0 var(--space-md);
  font-family: var(--font-mono);
  font-size: var(--size-sm);
  color: var(--text-primary);
  white-space: nowrap;
  max-width: 340px;
  overflow: hidden;
  text-overflow: ellipsis;
  vertical-align: middle;
}

td.no-data {
  text-align: center;
  color: var(--text-muted);
  font-family: var(--font-ui);
  font-style: italic;
  padding: var(--space-xl) !important;
  cursor: default;
  white-space: normal;
}

/* ---------------------------------------------------------------------------
   9. PAGINATION
   --------------------------------------------------------------------------- */
.table-pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 3px;
  padding: var(--space-sm) var(--space-lg);
  border-top: 1px solid var(--border-subtle);
  flex-wrap: wrap;
  min-height: 44px;
}

.page-btn {
  background: var(--bg-table);
  border: 1px solid var(--border-medium);
  border-radius: var(--radius-sm);
  color: var(--text-secondary);
  font-family: var(--font-mono);
  font-size: var(--size-xs);
  min-width: 30px;
  height: 28px;
  padding: 0 6px;
  cursor: pointer;
  transition: all var(--trans-fast);
}

.page-btn:hover:not(:disabled) {
  background: var(--bg-row-hover);
  border-color: var(--accent-secondary);
  color: var(--text-primary);
}

.page-btn.page-active {
  background: var(--accent-secondary);
  border-color: var(--accent-primary);
  color: #fff;
  font-weight: var(--weight-bold);
}

.page-btn:disabled {
  opacity: 0.3;
  cursor: not-allowed;
}

.page-ellipsis {
  color: var(--text-muted);
  font-size: var(--size-sm);
  padding: 0 3px;
  user-select: none;
}

/* ---------------------------------------------------------------------------
   10. LINK BADGE
   --------------------------------------------------------------------------- */
.link-badge {
  display: flex;
  align-items: center;
  gap: var(--space-sm);
  padding: 6px var(--space-lg);
  background: #00284488;
  border-top: 1px solid #00c8ff44;
  font-size: var(--size-xs);
  color: var(--text-accent);
}

.link-icon { font-size: var(--size-md); opacity: 0.7; }

.link-text {
  flex: 1;
  font-family: var(--font-mono);
  letter-spacing: 0.02em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.link-clear {
  background: none;
  border: none;
  color: var(--text-muted);
  font-size: var(--size-md);
  cursor: pointer;
  padding: 0 var(--space-xs);
  transition: color var(--trans-fast);
  flex-shrink: 0;
}

.link-clear:hover { color: var(--accent-danger); }

/* ---------------------------------------------------------------------------
   11. FOOTER
   --------------------------------------------------------------------------- */
.report-footer {
  text-align: center;
  padding: var(--space-lg);
  font-size: var(--size-xs);
  color: var(--text-muted);
  border-top: 1px solid var(--border-subtle);
  margin-top: var(--space-xl);
}

/* ---------------------------------------------------------------------------
   12. UTILITY
   --------------------------------------------------------------------------- */
.text-ok     { color: var(--accent-ok);     }
.text-warn   { color: var(--accent-warn);   }
.text-danger { color: var(--accent-danger); }
.text-accent { color: var(--accent-primary);}
.text-muted  { color: var(--text-muted);    }

/* ---------------------------------------------------------------------------
   13. SCROLLBARS (Chromium / Safari)
   --------------------------------------------------------------------------- */
::-webkit-scrollbar              { width: 8px; height: 8px; }
::-webkit-scrollbar-track        { background: var(--bg-page); }
::-webkit-scrollbar-thumb        { background: var(--border-medium); border-radius: 4px; }
::-webkit-scrollbar-thumb:hover  { background: var(--accent-secondary); }

/* ---------------------------------------------------------------------------
   14. RESPONSIVE
   --------------------------------------------------------------------------- */
@media (max-width: 900px) {
  .report-header  { height: auto; flex-direction: column; align-items: flex-start;
                    padding: var(--space-md); gap: var(--space-sm); }
  .header-meta    { align-items: flex-start; }
  .report-body    { padding: var(--space-md) var(--space-sm); }
  .filter-input   { width: 130px; }
  .report-title   { font-size: var(--size-lg); }
  .export-group   { border-left: none; padding-left: 0; }
}

@media print {
  .report-header { position: static; }
  .table-toolbar { display: none; }
  .table-pagination { display: none; }
  body { background: #fff; color: #000; }
}

/* ===========================================================================
   EXTENSIONS v1.3.0 - nav bar, cell states, progressbars, charts
   All colours use CSS variables defined in :root so every theme gets
   the correct appearance automatically.
   =========================================================================== */

/* ---------------------------------------------------------------------------
   NAV BAR
   --------------------------------------------------------------------------- */
.report-nav {
  background: var(--nav-bg);
  border-bottom: 1px solid var(--nav-border);
  position: sticky;
  top: calc(var(--header-height) + 8px);   /* stick just below the sticky header + gap */
  z-index: 90;
  box-shadow: 0 2px 8px rgba(0,0,0,0.10);
}

.nav-inner {
  max-width: 2400px;
  margin: 0 auto;
  padding: var(--space-xs) var(--space-md);
  min-height: var(--nav-height);  /* allow growth when links wrap */
  display: flex;
  align-items: center;
  flex-wrap: wrap;               /* <-- key: let nav links wrap to next line */
  gap: var(--space-xs) var(--space-sm);
}

.nav-logo {
  height: 26px;
  width: auto;
  max-width: 80px;
  object-fit: contain;
  flex-shrink: 0;
  opacity: 0.9;
}

.nav-title {
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  color: var(--nav-title-fg);
  text-transform: uppercase;
  letter-spacing: 0.09em;
  white-space: nowrap;
  flex-shrink: 0;
}

.nav-divider {
  width: 1px;
  height: 18px;
  background: var(--nav-border);
  flex-shrink: 0;
  margin: 0 var(--space-xs);
}

.nav-links {
  display: flex;
  align-items: center;
  flex-wrap: wrap;               /* <-- wrap links instead of clipping */
  gap: 2px;
  flex: 1;
  min-width: 0;
}

.nav-link {
  display: inline-flex;
  align-items: center;
  padding: 4px 10px;
  border-radius: var(--radius-sm);
  font-size: var(--size-xs);
  font-weight: var(--weight-medium);
  color: var(--nav-link-fg);
  text-decoration: none;
  white-space: nowrap;
  transition: background var(--trans-fast), color var(--trans-fast);
  border: 1px solid transparent;
}

.nav-link:hover {
  background: var(--nav-link-hover-bg);
  color: var(--nav-link-hover-fg);
}

.nav-link.nav-active {
  background: var(--nav-active-bg);
  color: var(--nav-active-fg);
  border-color: var(--nav-active-border);
  font-weight: var(--weight-bold);
}

.nav-top-btn {
  background: none;
  border: 1px solid var(--nav-border);
  border-radius: var(--radius-sm);
  color: var(--nav-link-fg);
  font-size: var(--size-xs);
  font-family: var(--font-ui);
  font-weight: var(--weight-medium);
  padding: 4px 10px;
  cursor: pointer;
  flex-shrink: 0;
  margin-left: auto;
  transition: all var(--trans-fast);
  white-space: nowrap;
}

.nav-top-btn:hover {
  border-color: var(--accent-primary);
  color: var(--accent-primary);
}

/* Adjust main body top offset when nav is present */
.report-body { padding-top: var(--space-lg); }
/* Panel mode: sections hidden by default, JS controls visibility */
.table-section { display: none; }
.table-section.panel-active { display: block; }
.block-section { display: none; }
.block-section.panel-active { display: block; }

/* ---------------------------------------------------------------------------
   TWO-TIER NAV — group tabs (level 1) + subnav strip (level 2)
   --------------------------------------------------------------------------- */
.nav-group-tabs {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 3px;
  flex: 1;
  min-width: 0;
}

.nav-group-tab {
  display: inline-flex;
  align-items: center;
  padding: 5px 14px;
  border-radius: var(--radius-sm);
  font-size: var(--size-sm);
  font-weight: var(--weight-medium);
  color: var(--nav-link-fg);
  text-decoration: none;
  white-space: nowrap;
  cursor: pointer;
  border: 1px solid var(--nav-border);
  background: none;
  transition: background var(--trans-fast), color var(--trans-fast), border-color var(--trans-fast);
  line-height: 1;
}

.nav-group-tab:hover {
  background: var(--nav-link-hover-bg);
  color: var(--nav-link-hover-fg);
  border-color: var(--accent-primary);
}

.nav-group-tab.group-active {
  background: var(--accent-primary);
  color: #fff;
  border-color: var(--accent-primary);
  font-weight: var(--weight-bold);
  box-shadow: 0 1px 4px rgba(0,0,0,0.18);
}

/* Subnav strip */
.nav-subnav {
  background: var(--bg-surface);
  border-top: 1px solid var(--nav-border);
  border-bottom: 2px solid var(--accent-primary);
}

.subnav-inner {
  max-width: 2400px;
  margin: 0 auto;
  padding: var(--space-xs) var(--space-md);
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 2px;
  min-height: 38px;
}

/* subnav links use the same .nav-link class, already styled */

/* Subgroup pill strip (3rd nav tier) */
.nav-subgroup {
  background: var(--bg-base);
  border-top: 1px solid var(--nav-border);
}
.subgroup-inner {
  max-width: 2400px;
  margin: 0 auto;
  padding: var(--space-xs) var(--space-md);
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
  min-height: 32px;
}
.subgroup-pill {
  display: inline-flex;
  align-items: center;
  padding: 2px 10px;
  font-size: 12px;
  font-weight: var(--weight-medium);
  color: var(--nav-link-fg);
  background: var(--bg-surface);
  border: 1px solid var(--nav-border);
  border-radius: 999px;
  text-decoration: none;
  cursor: pointer;
  transition: background 0.15s, color 0.15s, border-color 0.15s;
}
.subgroup-pill:hover {
  background: var(--nav-link-hover-bg);
  color: var(--nav-link-hover-fg);
}
.subgroup-pill.subgroup-active {
  background: var(--accent-primary);
  color: var(--accent-primary-fg);
  border-color: var(--accent-primary);
}



/* ---------------------------------------------------------------------------
   CELL STATES  (threshold colouring)
   --------------------------------------------------------------------------- */
.data-table tbody td.cell-ok {
  color: var(--cell-ok-fg) !important;
  background: var(--cell-ok-bg) !important;
  font-weight: var(--weight-medium);
}

.data-table tbody tr:hover td.cell-ok,
.data-table tbody tr.row-selected td.cell-ok {
  color: var(--cell-ok-fg) !important;
}

.data-table tbody td.cell-warn {
  color: var(--cell-warn-fg) !important;
  background: var(--cell-warn-bg) !important;
  font-weight: var(--weight-medium);
}

.data-table tbody tr:hover td.cell-warn,
.data-table tbody tr.row-selected td.cell-warn {
  color: var(--cell-warn-fg) !important;
}

.data-table tbody td.cell-danger {
  color: var(--cell-danger-fg) !important;
  background: var(--cell-danger-bg) !important;
  font-weight: var(--weight-bold);
}

.data-table tbody tr:hover td.cell-danger,
.data-table tbody tr.row-selected td.cell-danger {
  color: var(--cell-danger-fg) !important;
}

/* No-data state (v1.4 — spec §7.2 GREY: "no data / not applicable").
   Use for cells where the metric is unmeasured, intentionally absent, or
   blocked by data-collection failure — visually distinct from "0" or "OK". */
.data-table tbody td.cell-nodata {
  color: var(--cell-nodata-fg) !important;
  background: var(--cell-nodata-bg) !important;
  font-style: italic;
}

.data-table tbody tr:hover td.cell-nodata,
.data-table tbody tr.row-selected td.cell-nodata {
  color: var(--cell-nodata-fg) !important;
}

/* ---------------------------------------------------------------------------
   CELL TEXT FORMATTING
   --------------------------------------------------------------------------- */
td.cell-bold    { font-weight: 700 !important; }
td.cell-italic  { font-style: italic !important; }
td.cell-mono    { font-family: var(--font-mono) !important; }
td.cell-ui      { font-family: var(--font-ui) !important; }
td.cell-display { font-family: var(--font-display) !important; }

/* ---------------------------------------------------------------------------
   BADGE CELL TYPE
   --------------------------------------------------------------------------- */
td.td-badge { padding: 0 var(--space-md); vertical-align: middle; }

/* v1.4 F8 — inline sparkline cell. The SVG sizes itself via SPARK.build
   (default 100×22); the cell centres it vertically and pads sideways so the
   chart doesn't crowd the column neighbours. */
td.td-sparkline {
  padding: 0 var(--space-md);
  vertical-align: middle;
  line-height: 0;          /* avoid extra baseline space around the SVG */
  white-space: nowrap;
}
td.td-sparkline .spark-svg { display: inline-block; }
td.td-sparkline .td-sparkline-empty {
  color: var(--text-muted);
  font-style: italic;
  font-size: var(--size-sm);
  line-height: 1;
}

.cell-badge {
  display: inline-block;
  padding: 2px 9px;
  border-radius: 99px;
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  letter-spacing: 0.05em;
  text-transform: uppercase;
  background: var(--border-medium);
  color: var(--text-secondary);
  white-space: nowrap;
}

.cell-badge.badge-ok     { background: var(--cell-ok-bg);     color: var(--cell-ok-fg); }
.cell-badge.badge-warn   { background: var(--cell-warn-bg);   color: var(--cell-warn-fg); }
.cell-badge.badge-danger { background: var(--cell-danger-bg); color: var(--cell-danger-fg); }
.cell-badge.badge-nodata { background: var(--cell-nodata-bg); color: var(--cell-nodata-fg); }

/* ---------------------------------------------------------------------------
   PROGRESS BAR CELL TYPE
   --------------------------------------------------------------------------- */
td.td-progress {
  padding: 0 var(--space-md);
  vertical-align: middle;
  min-width: 120px;
}

.progress-wrap {
  display: flex;
  align-items: center;
  gap: 8px;
}

.progress-label {
  font-family: var(--font-mono);
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  min-width: 32px;
  text-align: right;
  flex-shrink: 0;
}

.progress-track {
  flex: 1;
  height: 8px;
  background: var(--progress-track-bg);
  border-radius: 99px;
  overflow: hidden;
  min-width: 60px;
}

.progress-fill {
  height: 100%;
  border-radius: 99px;
  transition: width var(--trans-normal);
}

.progress-fill.fill-default { background: var(--accent-primary); }
.progress-fill.fill-ok      { background: var(--cell-ok-fg); }
.progress-fill.fill-warn    { background: var(--cell-warn-fg); }
.progress-fill.fill-danger  { background: var(--cell-danger-fg); }
.progress-fill.fill-nodata  { background: var(--cell-nodata-fg); }

/* ---------------------------------------------------------------------------
   PIE / DONUT CHARTS
   --------------------------------------------------------------------------- */
.charts-container {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-md);
  padding: var(--space-md) var(--space-lg);
  background: var(--chart-container-bg);
  border-bottom: 1px solid var(--border-subtle);
}

.chart-panel {
  background: var(--bg-table);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  padding: var(--space-sm) var(--space-md);
  display: flex;
  flex-direction: column;
  gap: var(--space-xs);
  min-width: 220px;
  max-width: 320px;
  flex: 1;
}

.chart-title {
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  border-bottom: 1px solid var(--border-subtle);
  padding-bottom: var(--space-xs);
  margin-bottom: var(--space-xs);
}

.chart-body {
  display: flex;
  align-items: center;
  gap: var(--space-md);
}

.chart-body svg {
  flex-shrink: 0;
}

.chart-legend {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
  overflow: hidden;
}

.legend-row {
  display: flex;
  align-items: center;
  gap: 6px;
  min-width: 0;
}

.legend-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  flex-shrink: 0;
}

.legend-label {
  font-size: var(--size-xs);
  color: var(--text-primary);
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
}

.legend-count {
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  white-space: nowrap;
  flex-shrink: 0;
}

.legend-pct {
  font-weight: var(--weight-normal);
  color: var(--text-muted);
}

/* ---------------------------------------------------------------------------
   RESPONSIVE  (extend existing breakpoint)
   --------------------------------------------------------------------------- */
@media (max-width: 900px) {
  .nav-title    { display: none; }
  .nav-divider  { display: none; }
  .nav-inner    { padding: 0 var(--space-md); gap: var(--space-xs); }
  .charts-container { padding: var(--space-sm); }
  .chart-panel  { min-width: 180px; }
  .progress-track { min-width: 40px; }
}


/* ===========================================================================
   v1.5.0 ADDITIONS - alignment, row highlight, col toggle, summary tiles
   =========================================================================== */

/* ── Cell alignment ── */
td.cell-right  { text-align: right  !important; }
td.cell-center { text-align: center !important; }
th.th-right    { text-align: right  !important; }
th.th-center   { text-align: center !important; }

/* ── Row highlighting (applied to <tr> based on RowHighlight column) ── */
.data-table tbody tr.row-hl-ok {
  background: var(--cell-ok-bg)     !important;
  border-left: 3px solid var(--cell-ok-fg);
}
.data-table tbody tr.row-hl-warn {
  background: var(--cell-warn-bg)   !important;
  border-left: 3px solid var(--cell-warn-fg);
}
.data-table tbody tr.row-hl-danger {
  background: var(--cell-danger-bg) !important;
  border-left: 3px solid var(--cell-danger-fg);
}
.data-table tbody tr.row-hl-nodata {
  background: var(--cell-nodata-bg) !important;
  border-left: 3px solid var(--cell-nodata-fg);
}
/* Keep selected style dominant */
.data-table tbody tr.row-selected.row-hl-ok,
.data-table tbody tr.row-selected.row-hl-warn,
.data-table tbody tr.row-selected.row-hl-danger,
.data-table tbody tr.row-selected.row-hl-nodata {
  background: var(--bg-row-sel) !important;
  border-left: 3px solid var(--accent-primary);
}

/* ── Column visibility toggle ── */
.col-toggle-wrap {
  position: relative;
}

.btn-col-toggle {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  background: none;
  border: 1px solid var(--border-medium);
  border-radius: var(--radius-sm);
  color: var(--text-secondary);
  font-family: var(--font-ui);
  font-size: var(--size-xs);
  font-weight: var(--weight-medium);
  padding: 5px 10px;
  cursor: pointer;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  white-space: nowrap;
  transition: border-color var(--trans-fast), color var(--trans-fast);
}
.btn-col-toggle:hover {
  border-color: var(--accent-primary);
  color: var(--accent-primary);
}

.col-toggle-dropdown {
  position: absolute;
  top: calc(100% + 4px);
  right: 0;
  z-index: 200;
  background: var(--bg-surface);
  border: 1px solid var(--border-medium);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-md);
  padding: var(--space-sm);
  min-width: 160px;
  max-height: 280px;
  overflow-y: auto;
}

.col-toggle-item {
  display: flex;
  align-items: center;
  gap: var(--space-sm);
  padding: 5px var(--space-sm);
  font-size: var(--size-sm);
  color: var(--text-primary);
  cursor: pointer;
  border-radius: var(--radius-sm);
  white-space: nowrap;
  user-select: none;
  transition: background var(--trans-fast);
}
.col-toggle-item:hover { background: var(--bg-row-hover); }
.col-toggle-item input[type="checkbox"] {
  accent-color: var(--accent-primary);
  width: 14px;
  height: 14px;
  cursor: pointer;
  flex-shrink: 0;
}

/* ── Alert banners strip (above summary) ──
   Stacks top-of-page banners; each one severity-coloured via cell-* tokens.
   Container collapses when there are no visible banners (or all were dismissed). */
.report-alerts {
  display: flex;
  flex-direction: column;
  gap: var(--space-sm);
  padding: var(--space-lg) 0 0 0;
}
.report-alerts:empty { display: none; padding: 0; }

.alert-banner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-md);
  padding: var(--space-sm) var(--space-md);
  border-radius: var(--radius-md);
  border: 1px solid var(--border-subtle);
  border-left-width: 4px;
  background: var(--bg-surface);
  box-shadow: var(--shadow-md);
  transition: opacity 0.2s ease, transform 0.2s ease;
}
.alert-banner.alert-dismissed { opacity: 0; transform: translateY(-4px); }

/* v1.4.2+ — Banners with -NavGroup default to hidden; the nav routing adds
   .panel-active when the matching nav tab is selected. Page-global banners
   (no data-navgroup) stay visible everywhere as before. */
.alert-banner[data-navgroup]:not(.panel-active) { display: none; }

.alert-banner .alert-body {
  display: flex;
  align-items: center;
  gap: var(--space-sm);
  flex: 1 1 auto;
  min-width: 0;
}
.alert-banner .alert-icon {
  font-size: 1.25rem;
  line-height: 1;
  flex-shrink: 0;
}
.alert-banner .alert-message {
  font-size: var(--size-sm);
  color: var(--text-primary);
  line-height: 1.4;
}
.alert-banner .alert-actions {
  display: flex;
  align-items: center;
  gap: var(--space-xs);
  flex-shrink: 0;
}
.alert-banner .alert-action-btn {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  padding: 4px 10px;
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  cursor: pointer;
  transition: background var(--trans-fast);
}
.alert-banner .alert-action-btn:hover { background: var(--bg-row-hover); }
.alert-banner .alert-dismiss-btn {
  background: transparent;
  border: none;
  font-size: 1.25rem;
  line-height: 1;
  color: var(--text-muted);
  cursor: pointer;
  padding: 0 6px;
  transition: color var(--trans-fast);
}
.alert-banner .alert-dismiss-btn:hover { color: var(--text-primary); }

/* v1.5.1 — collapsible alert banner chrome ---------------------------- */
.alert-banner-collapsible {
  flex-direction: column;
  align-items: stretch;
  gap: 0;
}
.alert-banner-collapsible .alert-collapsible-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-sm);
}
.alert-banner-collapsible .alert-toggle {
  display: flex;
  align-items: center;
  gap: var(--space-xs);
  flex: 1;
  min-width: 0;
  background: transparent;
  border: none;
  padding: 0;
  font: inherit;
  color: inherit;
  cursor: pointer;
  text-align: left;
}
.alert-banner-collapsible .alert-title {
  font-weight: var(--weight-bold);
  font-size: var(--size-sm);
}
.alert-banner-collapsible .alert-chevron {
  margin-left: auto;
  color: var(--text-muted);
  font-size: 0.85rem;
  transition: color var(--trans-fast);
}
.alert-banner-collapsible .alert-toggle:hover .alert-chevron { color: var(--text-primary); }
.alert-banner-collapsible .alert-collapsible-body {
  max-height: 0;
  overflow: hidden;
  transition: max-height var(--trans-med);
  padding-top: 0;
}
.alert-banner-collapsible .alert-collapsible-body.open {
  max-height: 600px;
  padding-top: var(--space-xs);
}

/* Severity → RAG colours (reuses cell-* tokens for theme alignment) */
.alert-banner.alert-info     { border-left-color: var(--accent-primary); }
.alert-banner.alert-ok       { border-left-color: var(--cell-ok-fg);     background: var(--cell-ok-bg);     }
.alert-banner.alert-warning  { border-left-color: var(--cell-warn-fg);   background: var(--cell-warn-bg);   }
.alert-banner.alert-critical { border-left-color: var(--cell-danger-fg); background: var(--cell-danger-bg); }
.alert-banner.alert-ok       .alert-icon { color: var(--cell-ok-fg);     }
.alert-banner.alert-warning  .alert-icon { color: var(--cell-warn-fg);   }
.alert-banner.alert-critical .alert-icon { color: var(--cell-danger-fg); }

@media (max-width: 700px) {
  .alert-banner {
    flex-direction: column;
    align-items: flex-start;
  }
  .alert-banner .alert-actions { align-self: flex-end; }
}

/* ── Summary tiles strip ── */
.report-summary {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-md);
  padding: var(--space-lg) 0 0 0;
}

/* Hide the summary div when empty */
.report-summary:empty { display: none; }

.summary-tile {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-md) var(--space-lg);
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 3px;
  min-width: 140px;
  flex: 1;
  max-width: 220px;
  box-shadow: var(--shadow-md);
  transition: box-shadow var(--trans-normal), transform var(--trans-fast);
  position: relative;
  overflow: clip;
}

.summary-tile::before {
  content: '';
  position: absolute;
  left: 0; top: 0; bottom: 0;
  width: 4px;
  background: var(--border-medium);
  border-radius: var(--radius-lg) 0 0 var(--radius-lg);
}

.summary-tile.cell-ok::before     { background: var(--cell-ok-fg);     }
.summary-tile.cell-warn::before   { background: var(--cell-warn-fg);   }
.summary-tile.cell-danger::before { background: var(--cell-danger-fg); }
.summary-tile.cell-nodata::before { background: var(--cell-nodata-fg); }

.summary-tile:hover { box-shadow: var(--shadow-md), var(--shadow-glow); transform: translateY(-1px); }

/* v1.4.2 — clickable tile (per-tile Action). Adds pointer cursor + a
   slightly more prominent hover lift to signal interactivity. */
.summary-tile.tile-clickable { cursor: pointer; }
.summary-tile.tile-clickable:hover {
  box-shadow: var(--shadow-md), var(--shadow-glow);
  transform: translateY(-2px);
}
.summary-tile.tile-clickable:focus-visible {
  outline: 2px solid var(--accent-primary);
  outline-offset: 2px;
}

.summary-icon {
  font-size: 1.5rem;
  line-height: 1;
  margin-bottom: 2px;
}

.summary-value {
  font-family: var(--font-display);
  font-size: 1.6rem;
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  line-height: 1.1;
  letter-spacing: -0.02em;
}

.summary-tile.cell-ok     .summary-value { color: var(--cell-ok-fg);     }
.summary-tile.cell-warn   .summary-value { color: var(--cell-warn-fg);   }
.summary-tile.cell-danger .summary-value { color: var(--cell-danger-fg); }
.summary-tile.cell-nodata .summary-value { color: var(--cell-nodata-fg); }

.summary-label {
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.summary-sublabel {
  font-size: var(--size-xs);
  color: var(--text-muted);
  font-weight: var(--weight-normal);
}

/* ── Big-number hero tile (v1.4 F3) ──
   Full-width tile with very large value typography. Used for headline KPIs
   (current SLA, MTD revenue, etc.) where the value is the centre of attention. */
.summary-tile.tile-bignumber {
  flex: 1 0 100%;
  max-width: none;
  align-items: flex-start;
  padding: var(--space-md) var(--space-lg);
  gap: 4px;
}
.summary-tile.tile-bignumber .bignumber-head {
  display: flex;
  align-items: center;
  gap: var(--space-sm);
}
.summary-tile.tile-bignumber .bignumber-head .summary-label {
  font-size: var(--size-xs);
  margin: 0;
}
.summary-tile.tile-bignumber .bignumber-value {
  font-family: var(--font-display);
  font-size: clamp(2.4rem, 5vw, 3.6rem);
  font-weight: var(--weight-bold);
  line-height: 1.05;
  letter-spacing: -0.03em;
  color: var(--text-primary);
}
.summary-tile.tile-bignumber.cell-ok     .bignumber-value { color: var(--cell-ok-fg);     }
.summary-tile.tile-bignumber.cell-warn   .bignumber-value { color: var(--cell-warn-fg);   }
.summary-tile.tile-bignumber.cell-danger .bignumber-value { color: var(--cell-danger-fg); }
.summary-tile.tile-bignumber.cell-nodata .bignumber-value { color: var(--cell-nodata-fg); }
.summary-tile.tile-bignumber .bignumber-caption {
  font-size: var(--size-sm);
  color: var(--text-muted);
  margin-top: 2px;
}

/* ── Semicircle gauge tile (v1.4 F4) ──
   Background arc + threshold-coloured filled arc + numeric readout at the centre.
   The SVG fixes its own 140×80 viewBox. Tile sizing is controlled here. */
.summary-tile.tile-gauge {
  align-items: center;
  min-width: 160px;
  max-width: 220px;
  padding: var(--space-md) var(--space-sm) var(--space-sm);
  gap: 2px;
}
.summary-tile.tile-gauge .gauge-icon {
  position: absolute;
  top: var(--space-sm);
  left: var(--space-sm);
  font-size: 1.1rem;
}
.summary-tile.tile-gauge .gauge-svg {
  display: block;
  width: 140px;
  height: 80px;
}
.summary-tile.tile-gauge .summary-label {
  text-align: center;
}

/* ── Tile delta / trend indicator (v1.4 F1) ──
   Compact line between the value and the label showing the change vs. Previous.
   Three colour states reuse the existing RAG palette tokens:
     delta-good (cell-ok-fg)    — improvement
     delta-bad  (cell-danger-fg) — regression
     delta-flat (text-muted)    — unchanged */
.summary-delta {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  line-height: 1;
  margin-top: -2px;
  white-space: nowrap;
}
.summary-delta .delta-arrow { font-size: 0.85em; }
.summary-delta .delta-text  { letter-spacing: 0.01em; }

.summary-delta.delta-good { color: var(--cell-ok-fg);     }
.summary-delta.delta-bad  { color: var(--cell-danger-fg); }
.summary-delta.delta-flat { color: var(--text-muted);     }

/* ── Tile sparkline (v1.4 F2) ──
   Inline mini-chart anchored to the bottom of the tile. Sits below the
   label/sublabel; sized intrinsically by the SVG itself (default 80×24). */
.summary-sparkline {
  margin-top: 4px;
  width: 100%;
  display: flex;
  align-items: flex-end;
}
.summary-sparkline .spark-svg {
  width: 100%;
  max-width: 120px;
  height: 24px;
  display: block;
}

@media (max-width: 900px) {
  .report-summary { gap: var(--space-sm); }
  .summary-tile   { min-width: 120px; padding: var(--space-sm) var(--space-md); }
  .summary-value  { font-size: 1.3rem; }
}

/* ── Collapsible summary variant ──
   When Add-DhSummary is called with -Collapsible, the outer container
   reuses the collapsible-section chrome and the tiles live inside a
   nested flex strip. Override the default flex layout on the outer
   container so the header bar + body stack vertically. */
.report-summary.summary-collapsible {
  display: block;
  padding: var(--space-lg) 0 0 0;
}
.summary-tile-strip {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-md);
  padding: var(--space-md);
}
@media (max-width: 900px) {
  .summary-tile-strip { gap: var(--space-sm); padding: var(--space-sm); }
}


/* ===========================================================================
   v1.6.0 ADDITIONS
   =========================================================================== */

/* ── Info fields grid in header ── */
.info-fields-grid {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-md) var(--space-xl);
  margin-top: var(--space-sm);
  padding-top: var(--space-sm);
  border-top: 1px solid var(--border-subtle);
}
.info-field-item {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.info-field-label {
  font-size: var(--size-xs);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--header-fg-muted);
  font-weight: var(--weight-medium);
}
.info-field-value {
  font-size: var(--size-sm);
  font-weight: var(--weight-bold);
  color: var(--header-fg);
}

/* ── Nav utility buttons (density, theme toggle) ── */
.nav-utility-btn {
  background: none;
  border: 1px solid var(--nav-border);
  border-radius: var(--radius-sm);
  color: var(--nav-link-fg);
  font-family: var(--font-ui);
  font-size: var(--size-xs);
  font-weight: var(--weight-medium);
  padding: 4px 9px;
  cursor: pointer;
  flex-shrink: 0;
  white-space: nowrap;
  transition: all var(--trans-fast);
}
.nav-utility-btn:hover { border-color: var(--accent-primary); color: var(--accent-primary); }

/* ── Nav row count badges ── */
.nav-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: var(--border-medium);
  color: var(--text-muted);
  font-size: 0.65rem;
  font-weight: var(--weight-bold);
  border-radius: 99px;
  min-width: 18px;
  height: 16px;
  padding: 0 5px;
  margin-left: 5px;
  vertical-align: middle;
  transition: background var(--trans-fast), color var(--trans-fast);
}
.nav-link.nav-active .nav-badge {
  background: var(--nav-active-bg);
  color: var(--nav-active-fg);
}

/* ── Multi-sort position indicator ── */
.sort-pos {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: var(--accent-primary);
  color: var(--text-invert);
  font-size: 0.60rem;
  font-weight: var(--weight-bold);
  border-radius: 50%;
  width: 13px;
  height: 13px;
  margin-left: 3px;
  vertical-align: middle;
}

/* ── Right-click copy flash ── */
td.cell-copied {
  background: var(--accent-primary) !important;
  color: var(--text-invert) !important;
  transition: background 0.05s, color 0.05s;
}

/* ── First column pin ── */
.col-pinned {
  position: sticky;
  left: 0;
  z-index: 5;
  background: var(--bg-table);
}
tr:nth-child(even) .col-pinned { background: var(--bg-row-alt); }
tr:hover           .col-pinned { background: var(--bg-row-hover) !important; }
tr.row-selected    .col-pinned { background: var(--bg-row-sel) !important; }

/* ── Density modes ── */
.density-compact  .data-table tbody tr { height: 26px; }
.density-compact  .data-table tbody td,
.density-compact  .data-table thead th { padding: 0 var(--space-sm); font-size: var(--size-xs); }
.density-comfortable .data-table tbody tr { height: 54px; }
.density-comfortable .data-table tbody td { padding: 0 var(--space-md); }

/* ── Theme override classes ── */
body.theme-forced-light {
  --bg-page: #F4F5F7; --bg-header: #fff; --bg-surface: #fff;
  --bg-table: #fff; --bg-row-alt: #F7FAFE; --bg-row-hover: #C7E4FF;
  --bg-row-sel: #D0EAFF; --bg-thead: #F0F4F8;
  --text-primary: #1A2332; --text-secondary: #445566; --text-muted: #8899AA;
  --border-subtle: #DDE4EE; --border-medium: #C8D4E0;
}
body.theme-forced-dark {
  --bg-page: #0b0f14; --bg-header: #0d1219; --bg-surface: #111720;
  --bg-table: #0f141b; --bg-row-alt: #131922; --bg-row-hover: #2A3A56;
  --bg-row-sel: #0a2540; --bg-thead: #161e2b;
  --text-primary: #e2eaf4; --text-secondary: #8899aa; --text-muted: #4a5a6a;
  --border-subtle: #1e2b3a; --border-medium: #2a3a4d;
}

/* ── HTML blocks ── */
.block-section { display: none; padding: 0; }
.block-section.panel-active { display: block; }

.html-block {
  border-radius: var(--radius-lg);
  padding: var(--space-md) var(--space-lg);
  margin-bottom: var(--space-md);
  border-left: 4px solid var(--border-medium);
  background: var(--bg-surface);
  box-shadow: var(--shadow-md);
}
.html-block-info    { border-left-color: var(--accent-primary); background: color-mix(in srgb, var(--accent-primary) 6%, var(--bg-surface)); }
.html-block-ok      { border-left-color: var(--cell-ok-fg);     background: var(--cell-ok-bg); }
.html-block-warn    { border-left-color: var(--cell-warn-fg);   background: var(--cell-warn-bg); }
.html-block-danger  { border-left-color: var(--cell-danger-fg); background: var(--cell-danger-bg); }
.html-block-nodata  { border-left-color: var(--cell-nodata-fg); background: var(--cell-nodata-bg); }
.html-block-neutral { border-left-color: var(--border-medium);  background: var(--bg-surface); }

.html-block-title {
  font-size: var(--size-md);
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  margin-bottom: var(--space-sm);
  display: flex;
  align-items: center;
  gap: var(--space-sm);
}
.html-block-icon { font-size: 1.2em; }
.html-block-content {
  font-size: var(--size-sm);
  color: var(--text-secondary);
  line-height: 1.6;
}
.html-block-content ul, .html-block-content ol { padding-left: 1.4em; margin: var(--space-xs) 0; }
.html-block-content li { margin-bottom: 4px; }
.html-block-content strong { color: var(--text-primary); font-weight: var(--weight-bold); }
.html-block-content a { color: var(--accent-primary); text-decoration: none; }
.html-block-content a:hover { text-decoration: underline; }

/* ── Collapsible sections ── */
.collapsible-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  overflow: clip;
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-md);
}

.collapsible-toggle {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-md) var(--space-lg);
  cursor: pointer;
  user-select: none;
  background: var(--bg-thead);
  border-bottom: 1px solid transparent;
  transition: background var(--trans-fast);
}
.collapsible-toggle:hover { background: var(--bg-row-hover); }
.collapsible-toggle.open  { border-bottom-color: var(--border-subtle); }

.collapsible-toggle-left {
  display: flex;
  align-items: center;
  gap: var(--space-sm);
}

.collapsible-icon   { font-size: 1.2em; }
.collapsible-title  { font-size: var(--size-md); font-weight: var(--weight-bold); color: var(--text-primary); }
.collapsible-badge  {
  display: inline-flex; align-items: center; justify-content: center;
  background: var(--accent-primary); color: var(--text-invert);
  font-size: var(--size-xs); font-weight: var(--weight-bold);
  border-radius: 99px; min-width: 22px; height: 20px; padding: 0 6px;
}
.collapsible-chevron { font-size: var(--size-md); color: var(--text-muted); transition: transform var(--trans-fast); }

.collapsible-body { max-height: 0; overflow: hidden; transition: max-height 0.3s ease; }
.collapsible-body.open { max-height: 2000px; }

.collapsible-inner { padding: var(--space-md) var(--space-lg); }

/* Collapsible card grid */
.collapsible-card-grid {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-md);
}

.coll-card {
  background: var(--bg-table);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  padding: var(--space-md);
  min-width: 200px;
  flex: 1;
  max-width: 320px;
}

/* Collapsible card grid — width variants (default: normal = 200/320) */
.collapsible-card-grid.coll-width-small  .coll-card { min-width: 150px; max-width: 220px; }
.collapsible-card-grid.coll-width-large  .coll-card { min-width: 280px; max-width: 480px; }
.collapsible-card-grid.coll-width-xlarge .coll-card { min-width: 360px; max-width: 640px; }
.collapsible-card-grid.coll-width-auto   .coll-card { min-width: 240px; max-width: none; }

.coll-card-title {
  font-size: var(--size-sm);
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  margin-bottom: var(--space-sm);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-sm);
}

.coll-card-badge {
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  padding: 2px 8px;
  border-radius: 99px;
  background: var(--border-medium);
  color: var(--text-secondary);
}
.coll-card-badge.cell-ok     { background: var(--cell-ok-bg);     color: var(--cell-ok-fg); }
.coll-card-badge.cell-warn   { background: var(--cell-warn-bg);   color: var(--cell-warn-fg); }
.coll-card-badge.cell-danger { background: var(--cell-danger-bg); color: var(--cell-danger-fg); }
.coll-card-badge.cell-nodata { background: var(--cell-nodata-bg); color: var(--cell-nodata-fg); }

.coll-card-field {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: var(--space-sm);
  padding: 3px 0;
  border-bottom: 1px solid var(--border-subtle);
  font-size: var(--size-xs);
}
.coll-card-field:last-child { border-bottom: none; }
.coll-card-label { color: var(--text-muted); white-space: nowrap; }
.coll-card-value { font-weight: var(--weight-medium); color: var(--text-primary); font-family: var(--font-mono); word-break: break-all; text-align: right; }

/* ── Filter card grid ── */
.filter-card-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: 6px var(--space-md);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-xs);
}

.filter-card-title {
  font-size: var(--size-sm);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  margin-bottom: var(--space-xs);
}

.filter-card-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
}

.filter-card {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 1px;
  background: var(--bg-table);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  padding: 5px 10px;
  cursor: pointer;
  transition: all var(--trans-fast);
  position: relative;
  min-width: 80px;
}
.filter-card:hover { border-color: var(--accent-primary); background: var(--bg-row-hover); }
.filter-card.active { border-color: var(--accent-primary); background: var(--bg-row-sel); box-shadow: 0 0 0 2px var(--accent-primary); }

.filter-card-icon { font-size: 1em; }
.filter-card-name { font-size: var(--size-xs); font-weight: var(--weight-bold); color: var(--text-primary); }
.filter-card-sub  { font-size: 0.7rem; color: var(--text-muted); }

.filter-card-count {
  position: absolute;
  top: 3px;
  right: 5px;
  background: var(--accent-primary);
  color: var(--text-invert);
  font-size: 0.6rem;
  font-weight: var(--weight-bold);
  border-radius: 99px;
  min-width: 16px;
  height: 14px;
  padding: 0 3px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.filter-status {
  display: flex;
  align-items: center;
  gap: var(--space-sm);
  margin-top: var(--space-md);
  padding: 7px var(--space-md);
  background: color-mix(in srgb, var(--accent-primary) 8%, var(--bg-surface));
  border: 1px solid color-mix(in srgb, var(--accent-primary) 30%, transparent);
  border-radius: var(--radius-md);
  font-size: var(--size-xs);
  color: var(--text-accent);
  flex-wrap: wrap;
}

.filter-status-text { flex: 1; font-weight: var(--weight-medium); }
.filter-status-text strong { color: var(--text-primary); }
.filter-status-text em { font-style: normal; font-weight: var(--weight-bold); }

.clear-filter-btn {
  background: none;
  border: 1px solid var(--border-medium);
  border-radius: var(--radius-sm);
  color: var(--text-secondary);
  font-size: var(--size-xs);
  font-family: var(--font-ui);
  padding: 3px 10px;
  cursor: pointer;
  transition: all var(--trans-fast);
  white-space: nowrap;
}
.clear-filter-btn:hover { border-color: var(--accent-danger); color: var(--accent-danger); }

/* ── Standalone pie / donut chart (Add-DhPieChart) ──
   Wraps the existing .chart-panel renderer (reused from per-table charts)
   in a section-level container with consistent surface/shadow/spacing. */
.pie-chart-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-sm) var(--space-lg);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-xs);
  display: flex;
  justify-content: flex-start;
}
.pie-chart-section .chart-panel {
  /* Free the chart-panel from its per-table grid constraints */
  background: transparent;
  border: none;
  padding: 0;
  max-width: none;
  min-width: 280px;
}
.pie-chart-section .chart-body.chart-empty {
  color: var(--text-muted);
  font-style: italic;
  padding: var(--space-md);
}
.pie-chart-section .pie-clickable {
  transition: opacity var(--trans-fast);
}
.pie-chart-section .pie-clickable:hover {
  opacity: 0.85;
}

/* ── Heatmap (v1.5 — Add-DhHeatmap) ──
   Rows × columns matrix with a continuous colour scale. Distinct from
   StatusGrid (categorical). Three CellSize variants control row height. */
.heatmap-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-sm) var(--space-lg);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-xs);
}
.heatmap-title {
  font-size: var(--size-md);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  margin-bottom: var(--space-xs);
}
.heatmap-empty {
  color: var(--text-muted);
  font-style: italic;
  padding: var(--space-md);
  text-align: center;
}
.heatmap-inner { width: 100%; overflow-x: auto; }
.heatmap-grid {
  display: grid;
  gap: 1px;
  background: var(--border-subtle);
}
.heatmap-size-small  .hm-cell { height: 24px; }
.heatmap-size-normal .hm-cell { height: 36px; }
.heatmap-size-large  .hm-cell { height: 48px; }

.hm-corner {
  background: var(--bg-surface);
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  padding: 0 var(--space-sm) 4px 0;
}
.hm-corner .hm-row-label,
.hm-corner .hm-col-label {
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  line-height: 1.2;
}
.hm-corner .hm-col-label { color: var(--text-secondary); }

.hm-col-header {
  background: var(--bg-surface);
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-align: center;
  padding-bottom: 4px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.hm-row-header {
  background: var(--bg-surface);
  font-size: var(--size-sm);
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  padding: 0 var(--space-md) 0 0;
  display: flex;
  align-items: center;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  min-width: 80px;
  max-width: 240px;
}

/* Data cell — background colour set inline by the JS renderer */
.hm-cell {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  transition: transform var(--trans-fast), z-index 0s;
}
.hm-cell:hover {
  transform: scale(1.06);
  z-index: 1;
  outline: 1px solid var(--text-primary);
  outline-offset: -1px;
}
.hm-cell-empty {
  background: var(--cell-nodata-bg);
  opacity: 0.4;
}
.hm-cell .hm-value {
  text-shadow: 0 0 2px var(--bg-surface);   /* keep numeric readable over any background */
  pointer-events: none;
}

/* Legend strip below the grid */
.heatmap-legend {
  display: flex;
  align-items: center;
  gap: var(--space-sm);
  margin-top: var(--space-sm);
  padding-top: var(--space-xs);
  border-top: 1px solid var(--border-subtle);
}
.hm-legend-label {
  font-family: var(--font-mono);
  font-size: var(--size-xs);
  color: var(--text-muted);
  white-space: nowrap;
}
.hm-legend-strip {
  flex: 1;
  display: flex;
  height: 14px;
  border-radius: var(--radius-sm);
  overflow: hidden;
}
.hm-legend-stop { flex: 1; }

@media (max-width: 600px) {
  /* On narrow viewports, fall back to a horizontally scrollable matrix
     rather than stacking into a list — heatmaps lose their meaning
     when flattened. */
  .heatmap-inner { overflow-x: auto; }
}

/* ── Inline tabbed content (v1.5 — Add-DhTabs) ──
   Distinct from NavGroup (page-level); this is a local pivot inside one
   block of the dashboard flow. */
.tabs-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-sm) var(--space-lg);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-xs);
}
.tabs-title {
  font-size: var(--size-md);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  margin-bottom: var(--space-xs);
}
.tabs-strip {
  display: flex;
  gap: 2px;
  border-bottom: 2px solid var(--border-subtle);
  margin-bottom: var(--space-sm);
  overflow-x: auto;
}
.tabs-tab {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px var(--space-md);
  background: transparent;
  border: 0;
  border-bottom: 2px solid transparent;
  margin-bottom: -2px;     /* overlap the strip's border-bottom */
  font-size: var(--size-sm);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  cursor: pointer;
  white-space: nowrap;
  transition: color var(--trans-fast), border-bottom-color var(--trans-fast);
}
.tabs-tab:hover { color: var(--text-primary); }
.tabs-tab.tab-active {
  color: var(--text-primary);
  border-bottom-color: var(--accent-primary);
}
.tabs-tab:focus-visible {
  outline: 2px solid var(--accent-primary);
  outline-offset: 2px;
  border-radius: var(--radius-sm);
}
.tabs-tab-icon { font-size: 1em; line-height: 1; }
.tabs-tab-label { line-height: 1.2; }

.tabs-panel { display: none; }
.tabs-panel.panel-active { display: block; }

/* ── Topology Map (v1.5 — Add-DhTopologyMap) ──
   Parent/child tree rendered as inline SVG. Connector paths use the
   theme's --border-strong; nodes wear cell-* tints by status. The body
   of each node is HTML (foreignObject) so we get flex layout + ellipsis. */
.topology-map-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-sm) var(--space-lg);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-xs);
}
.topology-map-title {
  font-size: var(--size-md);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  margin-bottom: var(--space-sm);
}
.topology-map-empty {
  color: var(--text-muted);
  font-style: italic;
  padding: var(--space-md);
  text-align: center;
}
.topology-map-inner {
  width: 100%;
  overflow: auto;        /* large topologies scroll rather than overflow the page */
}
.topology-map-svg { display: block; }

/* Node rectangle — base look */
.topo-node-rect {
  fill: var(--bg-elevated);
  stroke: var(--border-strong);
  stroke-width: 1;
  transition: stroke var(--trans-fast), fill var(--trans-fast);
}

/* HTML body inside the foreignObject */
.topo-node-body {
  box-sizing: border-box;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 0 8px;
  font-family: var(--font-ui);
  font-size: var(--size-sm);
  color: var(--text-primary);
  overflow: hidden;
}
.topo-node-icon {
  flex: 0 0 auto;
  font-size: 1.05em;
  line-height: 1;
  color: var(--text-secondary);
}
.topo-node-label {
  flex: 1 1 auto;
  font-weight: var(--weight-bold);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  min-width: 0;
}
.topo-node-badge {
  flex: 0 0 auto;
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  background: var(--bg-surface);
  color: var(--text-secondary);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  padding: 0 6px;
  line-height: 1.4;
  white-space: nowrap;
}

/* Status-driven tint — same palette as cell-* tokens */
/* v1.5.2 — shared topology tooltip overlay (positioned via JS, lives on <body>) */
.topo-tooltip {
  position: fixed;
  z-index: 9999;
  max-width: 360px;
  padding: 6px 10px;
  background: var(--bg-elevated);
  color: var(--text-primary);
  border: 1px solid var(--border-strong);
  border-radius: var(--radius-sm);
  box-shadow: var(--shadow-md);
  font-family: var(--font-ui);
  font-size: var(--size-xs);
  line-height: 1.35;
  pointer-events: none;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}

.topo-status-ok     .topo-node-rect { fill: var(--cell-ok-bg);     stroke: var(--cell-ok-fg); }
.topo-status-warn   .topo-node-rect { fill: var(--cell-warn-bg);   stroke: var(--cell-warn-fg); }
.topo-status-danger .topo-node-rect { fill: var(--cell-danger-bg); stroke: var(--cell-danger-fg); }
.topo-status-nodata .topo-node-rect { fill: var(--cell-nodata-bg); stroke: var(--cell-nodata-fg); }
.topo-status-info   .topo-node-rect { fill: var(--bg-surface);     stroke: var(--accent-primary); }

/* Clickable nodes get a pointer cursor + hover lift */
.topo-clickable { cursor: pointer; }
.topo-clickable:hover .topo-node-rect {
  filter: brightness(1.05);
  stroke-width: 2;
}
.topo-clickable:focus-visible .topo-node-rect {
  stroke: var(--accent-primary);
  stroke-width: 2.5;
}

/* Connector paths between nodes */
.topo-link {
  opacity: 0.7;
}

/* ── Status Grid (v1.4 F5) — rows × columns RAG matrix ──
   Three CellSize variants control the data-cell height (rows are square).
   The grid uses CSS Grid with `auto` left column for row headers + `1fr`
   columns for the data cells so the chart stretches to fill its container.
   Below 600px viewport, the grid collapses to a stacked list view. */
.status-grid-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-sm) var(--space-lg);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-xs);
}
.status-grid-title {
  font-size: var(--size-md);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  margin-bottom: var(--space-xs);
}
.status-grid-empty {
  color: var(--text-muted);
  font-style: italic;
  padding: var(--space-md);
  text-align: center;
}
.status-grid-inner {
  width: 100%;
  overflow-x: auto;
}
.status-grid {
  display: grid;
  gap: 2px;
}
/* Cell-size variants — only the data cells take a fixed height; row/column
   headers borrow it via the implicit grid-row track. */
.status-grid-size-small  .sg-cell { height: 32px; }
.status-grid-size-normal .sg-cell { height: 48px; }
.status-grid-size-large  .sg-cell { height: 64px; }

/* Top-left corner — holds the axis labels */
.sg-corner {
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  padding: 0 var(--space-sm) 4px 0;
}
.sg-corner .sg-row-label,
.sg-corner .sg-col-label {
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  line-height: 1.2;
}
.sg-corner .sg-col-label { color: var(--text-secondary); }

.sg-col-header {
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-align: center;
  padding-bottom: 4px;
  border-bottom: 1px solid var(--border-subtle);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.sg-row-header {
  font-size: var(--size-sm);
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  padding: 0 var(--space-md) 0 0;
  display: flex;
  align-items: center;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  min-width: 80px;
  max-width: 200px;
}

/* Data cells */
.sg-cell {
  border-radius: var(--radius-sm);
  background: var(--cell-nodata-bg);
  border: 1px solid var(--border-subtle);
  transition: transform var(--trans-fast), box-shadow var(--trans-fast);
}
.sg-cell-empty { opacity: 0.35; background: transparent; border-style: dashed; }
.sg-cell.sg-clickable { cursor: pointer; }
.sg-cell.sg-clickable:hover {
  transform: scale(1.04);
  box-shadow: var(--shadow-md);
  z-index: 1;
}
.sg-cell.sg-status-ok      { background: var(--cell-ok-bg);     border-color: var(--cell-ok-fg);     }
.sg-cell.sg-status-warn    { background: var(--cell-warn-bg);   border-color: var(--cell-warn-fg);   }
.sg-cell.sg-status-danger  { background: var(--cell-danger-bg); border-color: var(--cell-danger-fg); }
.sg-cell.sg-status-nodata  { background: var(--cell-nodata-bg); border-color: var(--cell-nodata-fg); border-style: dashed; }
.sg-cell.sg-status-info    { background: rgba(0,0,0,0.04);      border-color: var(--accent-primary); }

/* Legend — auto-generated from statuses present in the grid */
.status-grid-legend {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-md);
  margin-top: var(--space-sm);
  padding-top: var(--space-xs);
  border-top: 1px solid var(--border-subtle);
}
.sg-legend-row {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: var(--size-xs);
  color: var(--text-secondary);
}
.sg-legend-swatch {
  display: inline-block;
  width: 14px;
  height: 14px;
  border-radius: var(--radius-sm);
  flex-shrink: 0;
}
.sg-legend-label { font-weight: var(--weight-medium); text-transform: capitalize; }

/* Responsive collapse: below 600px viewport flatten the grid into a stacked
   list — one row per cell with a coloured stripe on the left, so it stays
   usable on tablets / phones. */
@media (max-width: 600px) {
  .status-grid {
    display: flex !important;
    flex-direction: column;
    gap: 4px;
    grid-template-columns: none !important;
  }
  .status-grid .sg-corner,
  .status-grid .sg-col-header { display: none; }
  .status-grid .sg-row-header {
    grid-column: auto;
    max-width: none;
    background: var(--bg-row-alt);
    padding: var(--space-xs) var(--space-sm);
    border-radius: var(--radius-sm);
  }
  .status-grid .sg-cell {
    height: auto !important;
    min-height: 36px;
    padding: var(--space-xs) var(--space-sm);
    border-left-width: 6px;
  }
  .status-grid .sg-cell-empty { display: none; }   /* skip "no data" rows on mobile */
}

/* ── Event Feed (v1.4 F11) ──
   Chronological severity-tagged list. Each row is a one-line entry with an
   icon, timestamp, optional source tag, and the message. Long messages
   wrap to a second line. Group headers (when -GroupBy is used) bold the
   group key and show the entry count. */
.event-feed-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-sm) var(--space-lg);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-xs);
}
.event-feed-title {
  font-size: var(--size-md);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  margin-bottom: var(--space-xs);
}
.event-feed-empty {
  color: var(--text-muted);
  font-style: italic;
  padding: var(--space-md);
  text-align: center;
}
.event-feed-list {
  list-style: none;
  margin: 0;
  padding: 0;
}
.event-row {
  display: grid;
  grid-template-columns: 20px 130px auto 1fr;
  gap: var(--space-sm);
  align-items: baseline;
  padding: 6px var(--space-sm);
  border-left: 3px solid transparent;
  border-radius: var(--radius-sm);
  font-size: var(--size-sm);
  line-height: 1.45;
}
.event-row + .event-row { margin-top: 2px; }
.event-row .event-icon {
  font-weight: var(--weight-bold);
  text-align: center;
  font-family: var(--font-mono);
  font-size: var(--size-sm);
  line-height: 1.2;
}
.event-row .event-timestamp {
  font-family: var(--font-mono);
  font-size: var(--size-xs);
  color: var(--text-muted);
  white-space: nowrap;
}
.event-row .event-source {
  font-family: var(--font-mono);
  font-size: var(--size-xs);
  color: var(--text-secondary);
  font-weight: var(--weight-bold);
  white-space: nowrap;
}
.event-row .event-message {
  color: var(--text-primary);
  word-break: break-word;
}

/* Severity colours — left border + icon tint via RAG tokens */
.event-row.event-info     { background: rgba(0,0,0,0.02); border-left-color: var(--accent-primary); }
.event-row.event-info     .event-icon { color: var(--accent-primary); }
.event-row.event-ok       { background: var(--cell-ok-bg);     border-left-color: var(--cell-ok-fg);     }
.event-row.event-ok       .event-icon { color: var(--cell-ok-fg);     }
.event-row.event-warning  { background: var(--cell-warn-bg);   border-left-color: var(--cell-warn-fg);   }
.event-row.event-warning  .event-icon { color: var(--cell-warn-fg);   }
.event-row.event-critical { background: var(--cell-danger-bg); border-left-color: var(--cell-danger-fg); }
.event-row.event-critical .event-icon { color: var(--cell-danger-fg); }

/* Group headers (when -GroupBy is set) */
.event-feed-group { margin-bottom: var(--space-md); }
.event-feed-group:last-child { margin-bottom: 0; }
.event-group-header {
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  margin: var(--space-sm) 0 4px 0;
  padding-bottom: 2px;
  border-bottom: 1px solid var(--border-subtle);
}
.event-group-count {
  color: var(--text-muted);
  font-weight: var(--weight-normal);
  letter-spacing: 0;
  text-transform: none;
}

@media (max-width: 700px) {
  .event-row {
    grid-template-columns: 20px auto 1fr;
  }
  .event-row .event-timestamp {
    grid-column: 1 / -1;
    margin-left: 28px;
    font-size: 0.7rem;
  }
}

/* ── Line / Area chart (v1.4 F9) ──
   Section wrapper, title, SVG plot area (height controlled by -Height param
   on the cmdlet), and an optional legend strip below. */
.line-chart-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-sm) var(--space-lg);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-xs);
}
.line-chart-title {
  font-size: var(--size-md);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  margin-bottom: var(--space-xs);
}
.line-chart-section .lc-body {
  width: 100%;
  overflow: hidden;
}
.line-chart-section .lc-svg {
  width: 100%;
  display: block;
}
.line-chart-section .line-chart-empty {
  color: var(--text-muted);
  font-style: italic;
  padding: var(--space-md);
  text-align: center;
}

/* Legend strip */
.line-chart-section .lc-legend {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-md);
  margin-top: var(--space-xs);
  padding-top: var(--space-xs);
  border-top: 1px solid var(--border-subtle);
}
.line-chart-section .lc-legend-row {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: var(--size-xs);
  color: var(--text-secondary);
}
.line-chart-section .lc-legend-dot {
  display: inline-block;
  width: 12px;
  height: 12px;
  border-radius: 99px;
  flex-shrink: 0;
}
.line-chart-section .lc-legend-label {
  font-weight: var(--weight-medium);
}

/* SVG tick labels — slightly muted so the series stand out */
.line-chart-section .lc-x-tick,
.line-chart-section .lc-y-tick {
  font-family: var(--font-ui);
}

/* ── Bullet chart (v1.4 F10) ──
   Section wrapper hosts a title and a stack of rows. Each row is a 3-column
   grid: label / SVG track / numeric readout. Below 600px viewport the row
   collapses to a stack so the track gets the full width. */
.bullet-chart-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-sm) var(--space-lg);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-xs);
}
.bullet-chart-title {
  font-size: var(--size-md);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  margin-bottom: var(--space-xs);
}
.bullet-rows {
  display: flex;
  flex-direction: column;
  gap: var(--space-sm);
}
.bullet-row {
  display: grid;
  grid-template-columns: minmax(120px, 200px) 1fr minmax(120px, 180px);
  align-items: center;
  gap: var(--space-md);
}
.bullet-row.bullet-nodata .bullet-value { color: var(--cell-nodata-fg); font-style: italic; }

.bullet-label {
  font-size: var(--size-sm);
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.bullet-svg-wrap {
  width: 100%;
  display: flex;
}
.bullet-svg {
  width: 100%;
  height: 24px;
  display: block;
}
.bullet-readout {
  display: flex;
  align-items: baseline;
  gap: 6px;
  justify-content: flex-end;
  font-family: var(--font-display);
}
.bullet-readout .bullet-value {
  font-size: var(--size-md);
  font-weight: var(--weight-bold);
  color: var(--text-primary);
}
.bullet-readout .bullet-unit {
  font-size: var(--size-xs);
  color: var(--text-secondary);
  font-weight: var(--weight-medium);
}
.bullet-readout .bullet-target-readout {
  font-size: var(--size-xs);
  color: var(--text-muted);
  font-style: italic;
  margin-left: var(--space-xs);
}

@media (max-width: 700px) {
  .bullet-row {
    grid-template-columns: 1fr;
    gap: 4px;
  }
  .bullet-readout { justify-content: flex-start; }
}

/* ── Horizontal bar chart ── */
.bar-chart-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-sm) var(--space-lg);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-xs);
}

.bar-chart-title {
  font-size: var(--size-md);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  margin-bottom: var(--space-xs);
}

.bar-chart { display: flex; flex-direction: column; gap: var(--space-xs); }

.bar-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.bar-item.bar-clickable { cursor: pointer; }
.bar-item.bar-clickable:hover .bar-fill { filter: brightness(1.2); }

.bar-label {
  display: flex;
  align-items: baseline;
  gap: var(--space-sm);
  font-size: var(--size-xs);
}
.bar-label-text  { flex: 1; color: var(--text-primary); font-weight: var(--weight-medium); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; min-width: 0; }
.bar-label-count { color: var(--text-muted); font-family: var(--font-mono); flex-shrink: 0; font-weight: var(--weight-bold); }
.bar-label-pct   { color: var(--text-muted); font-size: 0.7rem; flex-shrink: 0; }

.bar-track {
  height: 10px;
  background: var(--progress-track-bg);
  border-radius: 99px;
  overflow: hidden;
}
.bar-fill {
  height: 100%;
  background: var(--accent-primary);
  border-radius: 99px;
  transition: width var(--trans-normal);
}

/* v1.4 F12 — Stacked bar segments */
.bar-track-stacked {
  display: flex;
  flex-direction: row;
  background: transparent;     /* segments paint themselves; no track tint */
}
.bar-segment {
  height: 100%;
  transition: filter var(--trans-fast);
}
.bar-segment:first-child { border-top-left-radius: 99px; border-bottom-left-radius: 99px; }
.bar-segment:last-child  { border-top-right-radius: 99px; border-bottom-right-radius: 99px; }
.bar-segment:hover { filter: brightness(1.1); }

.bar-chart-legend {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-md);
  margin-top: var(--space-sm);
  padding-top: var(--space-xs);
  border-top: 1px solid var(--border-subtle);
}
.bar-legend-row {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: var(--size-xs);
  color: var(--text-secondary);
}
.bar-legend-dot {
  display: inline-block;
  width: 12px;
  height: 12px;
  border-radius: 99px;
  flex-shrink: 0;
}
.bar-legend-label { font-weight: var(--weight-medium); }

@media (max-width: 900px) {
  .info-fields-grid { gap: var(--space-sm); }
  .coll-card { min-width: 150px; }
  .filter-card { min-width: 65px; }
  .collapsible-card-grid { gap: var(--space-sm); }
}

@media print {
  .nav-utility-btn, .btn-col-toggle, .export-group { display: none !important; }
  .collapsible-body { max-height: none !important; }
  .block-section, .table-section { display: block !important; }
}



/* ===========================================================================
   v1.8.0 ADDITIONS — tfoot aggregates, context menu, table-copied flash
   =========================================================================== */

/* ── Column aggregate footer row ── */
.data-table tfoot { border-top: 2px solid var(--border-medium); }

.tfoot-row .tfoot-cell {
  padding: 8px var(--space-md);
  font-size: var(--size-sm);
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  background: var(--bg-thead);
  white-space: nowrap;
  font-family: var(--font-mono);
}

/* ── Right-click context menu ── */
.ctx-menu {
  background: var(--bg-surface);
  border: 1px solid var(--border-medium);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-md);
  padding: var(--space-xs) 0;
  min-width: 200px;
  font-size: var(--size-sm);
  font-family: var(--font-ui);
  user-select: none;
}

.ctx-item {
  padding: 8px var(--space-md);
  color: var(--text-primary);
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: var(--space-sm);
  transition: background var(--trans-fast);
}
.ctx-item:hover {
  background: var(--bg-row-hover);
  color: var(--accent-primary);
}

/* ── Table CSV-copy flash ── */
.data-table.table-copied {
  outline: 2px solid var(--accent-primary);
  outline-offset: -2px;
  transition: outline 0.1s;
}

'@
}
