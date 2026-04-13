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
  max-width: 1600px;
  margin: 0 auto;
  padding: var(--space-xl) var(--space-lg);
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
.data-table tbody tr:hover           { background: var(--bg-row-hover) !important; }

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
  max-width: 1600px;
  margin: 0 auto;
  padding: var(--space-xs) var(--space-lg);
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
  max-width: 1600px;
  margin: 0 auto;
  padding: var(--space-xs) var(--space-lg);
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 2px;
  min-height: 38px;
}

/* subnav links use the same .nav-link class, already styled */



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
/* Keep selected style dominant */
.data-table tbody tr.row-selected.row-hl-ok,
.data-table tbody tr.row-selected.row-hl-warn,
.data-table tbody tr.row-selected.row-hl-danger {
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

.summary-tile:hover { box-shadow: var(--shadow-md), var(--shadow-glow); transform: translateY(-1px); }

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

@media (max-width: 900px) {
  .report-summary { gap: var(--space-sm); }
  .summary-tile   { min-width: 120px; padding: var(--space-sm) var(--space-md); }
  .summary-value  { font-size: 1.3rem; }
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
  --bg-table: #fff; --bg-row-alt: #F7FAFE; --bg-row-hover: #E8F4FF;
  --bg-row-sel: #D0EAFF; --bg-thead: #F0F4F8;
  --text-primary: #1A2332; --text-secondary: #445566; --text-muted: #8899AA;
  --border-subtle: #DDE4EE; --border-medium: #C8D4E0;
}
body.theme-forced-dark {
  --bg-page: #0b0f14; --bg-header: #0d1219; --bg-surface: #111720;
  --bg-table: #0f141b; --bg-row-alt: #131922; --bg-row-hover: #1a2332;
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
  padding: var(--space-md) var(--space-lg);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-md);
}

.filter-card-title {
  font-size: var(--size-md);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  margin-bottom: var(--space-md);
}

.filter-card-grid {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-sm);
}

.filter-card {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 2px;
  background: var(--bg-table);
  border: 2px solid var(--border-subtle);
  border-radius: var(--radius-md);
  padding: var(--space-sm) var(--space-md);
  cursor: pointer;
  transition: all var(--trans-fast);
  position: relative;
  min-width: 110px;
}
.filter-card:hover { border-color: var(--accent-primary); background: var(--bg-row-hover); }
.filter-card.active { border-color: var(--accent-primary); background: var(--bg-row-sel); }

.filter-card-icon { font-size: 1.2em; }
.filter-card-name { font-size: var(--size-sm); font-weight: var(--weight-bold); color: var(--text-primary); }
.filter-card-sub  { font-size: var(--size-xs); color: var(--text-muted); }

.filter-card-count {
  position: absolute;
  top: 4px;
  right: 6px;
  background: var(--accent-primary);
  color: var(--text-invert);
  font-size: 0.65rem;
  font-weight: var(--weight-bold);
  border-radius: 99px;
  min-width: 18px;
  height: 16px;
  padding: 0 4px;
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

/* ── Horizontal bar chart ── */
.bar-chart-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-md) var(--space-lg);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-md);
}

.bar-chart-title {
  font-size: var(--size-md);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  margin-bottom: var(--space-md);
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

@media (max-width: 900px) {
  .info-fields-grid { gap: var(--space-sm); }
  .coll-card { min-width: 150px; }
  .filter-card { min-width: 90px; }
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
