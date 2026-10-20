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

/* v1.7.0 — a11y: honour the OS "reduce motion" preference. Neutralises every
   transition + animation (collapsible expand, hover lifts, sort-icon spins,
   topology pan easing) while preserving the final rendered state, and disables
   smooth-scroll. Users with vestibular sensitivity get a still, instant UI. */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}

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

/* v1.10.0 — opt-in 12-column grid layout. Active only when a block or table
   declares -GridSpan (Export adds .report-grid). Each spanned section carries
   an inline  grid-column: span N ; sections without a span default to full
   width. Page chrome (alerts, filter bar, summary) is always full width. */
.report-body.report-grid {
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  gap: var(--space-lg);
  align-items: start;
}
.report-grid > .block-section,
.report-grid > .table-section { grid-column: 1 / -1; }   /* default: full row unless an inline span overrides */
.report-grid > #report-alerts,
.report-grid > #global-filter-bar,
.report-grid > #report-summary { grid-column: 1 / -1; }
@media (max-width: 900px) {
  /* v2.2.0 - minmax(0, 1fr), not 1fr: a bare 1fr track can never shrink below
     its content, so a wide table stretched the whole page sideways on a phone
     instead of scrolling inside its own .table-wrapper. */
  .report-body.report-grid { grid-template-columns: minmax(0, 1fr); }
  .report-body.report-grid > * { grid-column: 1 / -1 !important; min-width: 0; }
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
  transition: max-height var(--trans-normal);
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

/* v1.7.0 — virtualised (non-pageable, large) tables scroll inside a bounded
   viewport with a sticky header; the JS only renders the visible row window. */
.table-wrapper.table-virtual {
  max-height: 70vh;
  overflow-y: auto;
}
.table-wrapper.table-virtual thead th {
  position: sticky;
  top: 0;
  z-index: 3;
  background: var(--bg-thead);
}
.data-table tbody tr.virt-spacer:hover { background: transparent !important; box-shadow: none !important; }
.data-table tbody tr.virt-spacer td { padding: 0 !important; border: 0 !important; }

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
  position: relative;   /* anchors .col-resizer */
  /* 2.1.2 - the table is table-layout:auto, where width is only a suggestion
     and a nowrap header that cannot clip sets the column's hard minimum. With
     overflow hidden (plus the max-width the renderer puts on the th) the header
     truncates like the body cells do, so a column can be dragged narrow. */
  overflow: hidden;
}
/* The label clips itself; the th clips whatever follows it (sort icon, grip).
   max-width is 100%, not 100% minus an icon reservation - reserving space made
   a short header like "ID" measure as clipped in a narrow column and pick up a
   pointless tooltip. */
.data-table thead th .col-label {
  display: inline-block;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  vertical-align: middle;
}
/* Header whose own label is clipped - full text is on the th as title= */
.data-table thead th.th-clipped .col-label { cursor: help; }

/* Drag-to-resize grip on a column's right edge. Sits inside the th, so it must
   not inherit the header's pointer/sort affordance. */
.col-resizer {
  position: absolute;
  top: 0;
  right: 0;        /* inside the th: 2.1.2 made the header overflow:hidden */
  width: 8px;
  height: 100%;
  cursor: col-resize;
  z-index: 2;
  touch-action: none;   /* let the pointer drag work on touch devices */
}
.col-resizer::after {
  content: '';
  position: absolute;
  top: 20%;
  bottom: 20%;
  left: 3px;
  width: 1px;
  background: var(--border-medium);
  opacity: 0;
  transition: opacity var(--trans-fast);
}
.data-table thead th:hover .col-resizer::after,
.col-resizer:focus-visible::after,
.col-resizer.resizing::after {
  opacity: 1;
  background: var(--accent-primary);
}
.col-resizer.resizing::after { top: 0; bottom: 0; width: 2px; }
.col-resizer:focus-visible {
  outline: 2px solid var(--accent-primary);
  outline-offset: -1px;
}

/* A cell whose text is clipped carries title= with the full value (set by
   _markTruncated). The dotted edge is the affordance that says "there is more
   here" - an ellipsis alone reads as part of the data. */
.data-table tbody td.cell-clipped {
  border-right: 1px dotted var(--border-medium);
  cursor: help;
}

.data-table thead th.sortable {
  cursor: pointer;
  transition: color var(--trans-fast), background var(--trans-fast);
}

.data-table thead th.sortable:hover {
  color: var(--text-accent);
  background: var(--bg-row-hover);
}
/* v1.7.0 — a11y: keyboard focus ring on sortable headers (they are tabindex=0) */
.data-table thead th.sortable:focus-visible {
  outline: 2px solid var(--accent-primary);
  outline-offset: -2px;
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
/* ── v2.0.0 sidebar rail ─────────────────────────────────────────────
   Used automatically at nav depth 4+, where three or four stacked sticky
   strips would eat a quarter of a 1080p viewport. Shows the whole tree at
   once; only the branch in use is expanded. */
.nav-sidebar {
  position: fixed;
  top: calc(var(--header-height) + var(--nav-height));
  left: 0;
  bottom: 0;
  width: 240px;
  overflow-y: auto;
  background: var(--bg-surface);
  border-right: 1px solid var(--nav-border);
  padding: var(--space-sm) 0;
  z-index: 40;
}
.nav-rail-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 6px;
  padding: 5px 10px;
  font-size: 12.5px;
  color: var(--nav-link-fg);
  text-decoration: none;
  border-left: 2px solid transparent;
  cursor: pointer;
}
.nav-rail-item:hover { background: var(--nav-link-hover-bg); color: var(--nav-link-hover-fg); }
.nav-rail-onpath     { border-left-color: var(--nav-border); }
.nav-rail-active {
  background: var(--accent-primary);
  color: var(--accent-primary-fg, #fff);
  border-left-color: var(--accent-primary);
  font-weight: var(--weight-medium);
}
.nav-rail-d0 { font-weight: var(--weight-medium); }
.nav-rail-item:focus-visible { outline: 2px solid var(--accent-primary); outline-offset: -2px; }

/* Body shifts to make room for the rail. */
body.has-nav-sidebar .report-body,
body.has-nav-sidebar .report-alerts,
body.has-nav-sidebar .global-filter-bar { margin-left: 240px; }

/* Below 900px the rail would leave no room for content: fall back to the
   strips flow rather than a cramped two-column layout. */
@media (max-width: 900px) {
  .nav-sidebar { display: none !important; }
  body.has-nav-sidebar .report-body,
  body.has-nav-sidebar .report-alerts,
  body.has-nav-sidebar .global-filter-bar { margin-left: 0; }
}

/* ── v2.0.0 nav strips ───────────────────────────────────────────────
   N strips rendered from a loop; depth is a class suffix, never a level name.
   Depth 0 reads as the old group-tab row, deeper strips get progressively
   lighter so the hierarchy is legible without three bespoke stylesheets. */
.nav-strips { display: block; }

/* Top-level chips live inside .nav-inner, sharing the line with the Top /
   density / theme buttons. flex:1 pushes those buttons to the right edge.
   v2.5.3 - a zero basis keeps the strip on that line however many chips it
   holds (with 'auto' a long menu dropped onto a line of its own, so the bar
   took two rows and the "More" menu never engaged); the min-width lets it
   wrap below the title only on a narrow screen. -NavOverflow Wrap still
   wraps the chips inside the strip. */
.nav-strip-top {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 4px;
  flex: 1 1 0;
  min-width: min(260px, 100%);
}
/* -NavOverflow Wrap keeps the earlier layout: a long menu takes a line of its own and wraps there */
.report-nav[data-navoverflow="wrap"] .nav-strip-top { flex: 1 1 auto; min-width: 0; }

.nav-strip {
  background: var(--bg-surface);
  border-top: 1px solid var(--nav-border);
}
.nav-strip-0 { background: var(--bg-surface); border-bottom: 2px solid var(--accent-primary); }
.nav-strip-1 { background: var(--bg-page); }
.nav-strip-2,
.nav-strip-3,
.nav-strip-4 { background: var(--bg-page); }

.nav-strip-inner {
  max-width: 2400px;
  margin: 0 auto;
  padding: var(--space-xs) var(--space-md);
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
  min-height: 32px;
}
.nav-strip-0 .nav-strip-inner { min-height: 38px; gap: 2px; }

.nav-chip {
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
.nav-strip-0 .nav-chip { border-radius: 4px; font-size: 13px; padding: 4px 12px; }
.nav-chip:hover {
  background: var(--nav-link-hover-bg);
  color: var(--nav-link-hover-fg);
}
.nav-chip-active {
  background: var(--accent-primary);
  color: var(--accent-primary-fg, #fff);
  border-color: var(--accent-primary);
}
.nav-chip:focus-visible { outline: 2px solid var(--accent-primary); outline-offset: 2px; }

/* Breadcrumb - only rendered at depth 4+, where strips alone stop answering
   "where am I" (plan-v2.md WP3.2). */
.nav-crumb {
  max-width: 2400px;
  margin: 0 auto;
  padding: 4px var(--space-md);
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11px;
  color: var(--text-muted);
}
.nav-crumb-item { color: var(--text-muted); text-decoration: none; }
.nav-crumb-item:hover { color: var(--accent-primary); text-decoration: underline; }
.nav-crumb-sep { color: var(--text-muted); opacity: 0.6; }

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
  background: var(--bg-page);
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
  color: var(--accent-primary-fg, #fff);   /* fallback kept for safety; all themes define it since 1.10.2 */
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

/* v1.9.0 — global filter bar (page-level facet / date-range controls) */
.global-filter-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-md);
  margin-top: var(--space-lg);
  padding: var(--space-sm) var(--space-md);
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
}
.gf-control { display: inline-flex; align-items: center; gap: var(--space-xs); }
.gf-label {
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  text-transform: uppercase;
  letter-spacing: 0.02em;
  color: var(--text-secondary);
}
.gf-select, .gf-date {
  font: inherit;
  font-size: var(--size-sm);
  color: var(--text-primary);
  background: var(--bg-page);
  border: 1px solid var(--border-medium);
  border-radius: var(--radius-sm);
  padding: 4px 8px;
}
.gf-select:focus-visible, .gf-date:focus-visible {
  outline: 2px solid var(--accent-primary);
  outline-offset: 1px;
}
.gf-date-sep { color: var(--text-muted); padding: 0 2px; }
.gf-clear {
  margin-left: auto;
  font: inherit;
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  background: transparent;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  padding: 4px 10px;
  cursor: pointer;
  transition: background var(--trans-fast), color var(--trans-fast);
}
.gf-clear:hover { background: var(--bg-row-hover); color: var(--text-primary); }
.gf-clear:focus-visible { outline: 2px solid var(--accent-primary); outline-offset: 1px; }

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
.alert-banner[data-navgroup]:not(.panel-active),
.alert-banner[data-navpath]:not(.panel-active) { display: none; }

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
  transition: max-height var(--trans-normal);
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
  color: var(--text-primary);
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
  text-shadow: none;   /* the text colour is picked per cell (dhTextOn), so no halo is needed */
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

/* v1.7.0 — interactive topology (pan / zoom / collapse) --------------------- */
.topology-map-inner.topo-interactive {
  overflow: hidden;                 /* content is panned inside a fixed viewport */
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  background:
    radial-gradient(circle, var(--border-subtle) 1px, transparent 1px) 0 0 / 22px 22px;
  cursor: grab;
}
.topology-map-inner.topo-interactive.topo-panning { cursor: grabbing; }
.topology-map-inner.topo-interactive .topology-map-svg { height: 100%; }

.topology-map-toolbar {
  display: flex;
  gap: 4px;
  justify-content: flex-end;
  margin-bottom: 6px;
}
.topo-btn {
  width: 28px;
  height: 28px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 1rem;
  line-height: 1;
  color: var(--text-primary);
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: background var(--trans-fast), border-color var(--trans-fast);
}
.topo-btn:hover        { background: var(--bg-row-hover); border-color: var(--border-strong); }
.topo-btn:focus-visible { outline: 2px solid var(--accent-primary); outline-offset: 1px; }

/* Collapse/expand toggle badge on parent nodes */
.topo-toggle { cursor: pointer; }
.topo-toggle-bg {
  fill: var(--bg-surface);
  stroke: var(--border-strong);
  stroke-width: 1.25;
  transition: fill var(--trans-fast), stroke var(--trans-fast);
}
.topo-toggle:hover .topo-toggle-bg { fill: var(--bg-row-hover); stroke: var(--accent-primary); }
.topo-toggle:focus-visible { outline: none; }
.topo-toggle:focus-visible .topo-toggle-bg { stroke: var(--accent-primary); stroke-width: 2; }
.topo-toggle-sign {
  fill: var(--text-secondary);
  font-family: var(--font-ui);
  font-size: 13px;
  font-weight: var(--weight-bold);
  pointer-events: none;
  user-select: none;
}
.topo-toggle-collapsed .topo-toggle-bg { fill: var(--accent-primary); }
.topo-toggle-collapsed .topo-toggle-sign { fill: var(--accent-primary-fg, #fff); }

/* Node rectangle — base look */
.topo-node-rect {
  fill: var(--bg-elevated, var(--bg-surface));
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
  background: var(--bg-elevated, var(--bg-surface));
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
/* v2.3.0: a cell that is "itself" (SelfDiagonal) is hatched; a glyph is centred in the cell */
.sg-cell.sg-self {
  background: repeating-linear-gradient(135deg, transparent 0 5px, var(--border-subtle) 5px 6px);
  border-style: solid; border-color: var(--border-subtle);
}
.sg-cell { display: flex; align-items: center; justify-content: center; }
.sg-glyph { font-weight: var(--weight-bold); line-height: 1; color: var(--cell-ok-fg); }
.sg-status-warn .sg-glyph   { color: var(--cell-warn-fg); }
.sg-status-danger .sg-glyph { color: var(--cell-danger-fg); }
.sg-status-nodata .sg-glyph, .sg-status-info .sg-glyph { color: var(--text-muted); }
.sg-cell.sg-clickable:focus-visible { outline: 2px solid var(--accent-primary); outline-offset: 1px; }

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
/* v2.1.3 - clickable bars are keyboard-reachable (role=button, tabindex=0),
   so they need a visible focus ring. */
.bar-item.bar-clickable:focus-visible {
  outline: 2px solid var(--accent-primary);
  outline-offset: 2px;
  border-radius: var(--radius-sm);
}

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
/* v2.3.0 - bars coloured by value (-Rag) or category (-KeyClass) */
.bar-fill.bar-fill-ok     { background: var(--cell-ok-fg); }
.bar-fill.bar-fill-warn   { background: var(--cell-warn-fg); }
.bar-fill.bar-fill-danger { background: var(--cell-danger-fg); }
.bar-fill.bar-fill-nodata { background: var(--cell-nodata-fg); }

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

/* ── Range-gradient bar chart (v2.1.0 — Add-DhRangeBar) ──
   min → max floating bars on a shared 0-100 axis, coloured by position on
   that axis. The gradient stops are theme tokens (--range-grad-0/50/100),
   so the ramp follows whichever theme is active. All placement is
   percentage-based against the track's own box, so it reflows at any width.

   Geometry follows the spec: 56px rows, a 24px bar vertically centred, and
   an avg tick that overshoots the bar by 5px top and bottom. */
.rangebar-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-sm) var(--space-lg);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-xs);
}
.rangebar-title {
  font-size: var(--size-md);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  margin-bottom: var(--space-xs);
}
.rangebar-empty {
  color: var(--text-muted);
  font-style: italic;
  padding: var(--space-md);
  text-align: center;
}

/* Data-dense: horizontal scroll beats illegibly compressed tracks. */
.rangebar-scroller { width: 100%; overflow-x: auto; }
.rangebar-plot {
  min-width: 640px;
  display: grid;
  grid-template-columns: 152px 1fr 214px;
  column-gap: 16px;
  align-items: stretch;
  position: relative;
}

.rb-axis-title {
  grid-column: 2;
  grid-row: 1;
  text-align: right;
  font-size: var(--size-xs);
  color: var(--text-muted);
  padding-bottom: 6px;
}
.rb-axis-cell { grid-column: 2; grid-row: 2; height: 26px; position: relative; }
.rb-axis-tick {
  position: absolute;
  top: 0;
  transform: translateX(-50%);
  font-family: var(--font-mono);
  font-size: var(--size-xs);
  color: var(--text-muted);
  font-variant-numeric: tabular-nums;
}
.rb-axis-tick:first-child { transform: translateX(0); }
.rb-axis-tick:last-child  { transform: translateX(-100%); }

/* Gridlines share column 2 with the tracks and span every data row. The row
   span is computed from the item count — never hard-coded. */
.rb-gridlines { grid-column: 2; position: relative; }
.rb-gridline {
  position: absolute;
  top: 0; bottom: 0;
  width: 1px;
  background: var(--border-subtle);
}
.rb-gridline.rb-edge { background: var(--border-medium); }

.rb-label {
  grid-column: 1;
  display: flex;
  align-items: center;
  font-size: var(--size-sm);
  font-weight: var(--weight-medium);
  color: var(--text-primary);
  padding: 15px 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.rb-track {
  grid-column: 2;
  position: relative;
  display: flex;
  align-items: center;
  height: 56px;
}
/* No top/bottom offsets: the static position of an out-of-flow child in a
   centred flex container lands it vertically centred, at its own height. */
.rb-base {
  position: absolute;
  left: 0; right: 0;
  height: 24px;
  border-radius: var(--radius-sm);
  background: var(--progress-track-bg);
}
.rb-bar {
  position: absolute;
  left: 0; right: 0;
  height: 24px;
  border-radius: var(--radius-sm);
  background: linear-gradient(to right,
              var(--range-grad-0)   0%,
              var(--range-grad-50)  50%,
              var(--range-grad-100) 100%);
  cursor: pointer;
}
.rb-bar:focus-visible {
  outline: 2px solid var(--accent-primary);
  outline-offset: 2px;
}
/* Avg tick — independently positioned and deliberately NOT clamped into
   [min, max]; an avg outside the bar is a real data signal, not a glitch. */
.rb-avg {
  position: absolute;
  top: 50%;
  height: 34px;
  width: 2px;
  background: var(--text-primary);
  border-radius: 1px;
  transform: translate(-1px, -50%);
  pointer-events: none;
}
/* Degenerate row (High <= Low): normalisation is undefined, so show the row
   as striped rather than dividing by zero or faking a position. */
.rb-track-bad .rb-base {
  background: repeating-linear-gradient(
      45deg,
      var(--progress-track-bg) 0 6px,
      transparent 6px 12px);
  border: 1px dashed var(--border-medium);
}

.rb-values {
  grid-column: 3;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 15px 0;
  font-family: var(--font-mono);
  font-size: var(--size-xs);
  color: var(--text-secondary);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
.rb-v-range { color: var(--text-primary); font-weight: var(--weight-medium); }
.rb-v-avg b { color: var(--text-primary); font-weight: var(--weight-bold); }

/* Colour encodes position on a shared axis, not category identity — so the
   legend explains the scale once, instead of one swatch per row. */
.rangebar-legend {
  display: flex;
  align-items: center;
  gap: 18px;
  margin-top: var(--space-sm);
  padding-top: var(--space-xs);
  border-top: 1px solid var(--border-subtle);
  flex-wrap: wrap;
  font-size: var(--size-xs);
  color: var(--text-muted);
}
.rb-legend-scale, .rb-legend-avg { display: flex; align-items: center; gap: 8px; }
.rb-legend-scale { font-family: var(--font-mono); }
.rb-legend-swatch {
  width: 120px;
  height: 10px;
  border-radius: 3px;
  background: linear-gradient(to right,
              var(--range-grad-0)   0%,
              var(--range-grad-50)  50%,
              var(--range-grad-100) 100%);
}
.rb-legend-note { color: var(--text-secondary); font-family: var(--font-ui); }
.rb-legend-tick {
  width: 2px;
  height: 14px;
  background: var(--text-primary);
  border-radius: 1px;
}

.rb-table-toggle {
  margin-top: var(--space-sm);
  font-family: var(--font-ui);
  font-size: var(--size-xs);
  font-weight: var(--weight-medium);
  color: var(--text-secondary);
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  padding: 7px 12px;
  cursor: pointer;
}
.rb-table-toggle:hover { color: var(--text-primary); }
.rb-table-toggle:focus-visible {
  outline: 2px solid var(--accent-primary);
  outline-offset: 2px;
}
.rb-data-table { overflow-x: auto; }
.rb-data-table table {
  border-collapse: collapse;
  width: 100%;
  min-width: 520px;
  margin-top: var(--space-xs);
  font-family: var(--font-mono);
  font-size: var(--size-xs);
}
.rb-data-table table[hidden] { display: none; }
.rb-data-table th, .rb-data-table td {
  text-align: right;
  padding: 8px 10px;
  border-bottom: 1px solid var(--border-subtle);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
.rb-data-table th:first-child, .rb-data-table td:first-child {
  text-align: left;
  font-family: var(--font-ui);
  font-weight: var(--weight-medium);
}
.rb-data-table th {
  color: var(--text-muted);
  font-weight: var(--weight-medium);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

/* ===========================================================================
   v2.2.0 ADDITIONS — findings, verdict tile, table bar charts, link cells,
   export-library states, print.
   Colours come only from tokens every theme already defines (cell-* and
   accent-*), so all 12 theme files work unchanged. Severity mapping, shared
   with Add-DhAlertBanner: critical = danger, warning = warn, info = accent,
   ok = ok.
   =========================================================================== */

/* ── Findings ─────────────────────────────────────────────────────────── */
.findings-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-sm) var(--space-lg) var(--space-md);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-xs);
}
.findings-title {
  font-size: var(--size-md);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  margin-bottom: var(--space-sm);
}
.findings-toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-sm);
  margin-bottom: var(--space-sm);
}
.findings-counters { display: flex; flex-wrap: wrap; gap: 6px; }
.findings-chip {
  font: inherit;
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  border: 1px solid var(--border-medium);
  background: var(--bg-surface);
  color: var(--text-secondary);
  border-radius: 99px;
  padding: 3px 10px;
  cursor: pointer;
}
.findings-chip-count { font-family: var(--font-mono); }
.findings-chip-critical { color: var(--cell-danger-fg); border-color: var(--cell-danger-fg); }
.findings-chip-warning  { color: var(--cell-warn-fg);   border-color: var(--cell-warn-fg);   }
.findings-chip-info     { color: var(--accent-primary); border-color: var(--accent-primary); }
.findings-chip-ok       { color: var(--cell-ok-fg);     border-color: var(--cell-ok-fg);     }
.findings-chip[aria-pressed="true"] { color: var(--bg-surface); }
.findings-chip-critical[aria-pressed="true"] { background: var(--cell-danger-fg); }
.findings-chip-warning[aria-pressed="true"]  { background: var(--cell-warn-fg); }
.findings-chip-info[aria-pressed="true"]     { background: var(--accent-primary); }
.findings-chip-ok[aria-pressed="true"]       { background: var(--cell-ok-fg); }
.findings-chip:focus-visible { outline: 2px solid var(--accent-primary); outline-offset: 2px; }
.findings-filter {
  flex: 1 1 200px;
  max-width: 320px;
  margin-left: auto;
  font: inherit;
  font-size: var(--size-sm);
  padding: 5px 10px;
  border: 1px solid var(--border-medium);
  border-radius: var(--radius-md);
  background: var(--bg-input, var(--bg-surface));
  color: var(--text-primary);
}
.findings-list { display: flex; flex-direction: column; gap: 6px; }
.findings-group { display: flex; flex-direction: column; gap: 6px; margin-top: var(--space-xs); }
.findings-group-header {
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-muted);
  border-bottom: 1px solid var(--border-subtle);
  padding: 4px 0;
}
.findings-group-count { font-family: var(--font-mono); margin-left: 4px; }
.finding {
  border: 1px solid var(--border-subtle);
  border-left: 4px solid var(--border-medium);
  border-radius: var(--radius-md);
  background: var(--bg-surface);
}
.finding-critical { border-left-color: var(--cell-danger-fg); }
.finding-warning  { border-left-color: var(--cell-warn-fg); }
.finding-info     { border-left-color: var(--accent-primary); }
.finding-ok       { border-left-color: var(--cell-ok-fg); }
.finding-head {
  display: flex;
  align-items: center;
  gap: var(--space-sm);
  width: 100%;
  font: inherit;
  text-align: left;
  color: inherit;
  background: transparent;
  border: 0;
  padding: 8px var(--space-md);
  cursor: pointer;
}
.finding-head:hover { background: var(--bg-hover, rgba(127,127,127,0.06)); }
.finding-head:focus-visible { outline: 2px solid var(--accent-primary); outline-offset: -2px; }
.finding-badge {
  flex-shrink: 0;
  min-width: 64px;
  text-align: center;
  font-size: 0.68rem;
  font-weight: var(--weight-bold);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  padding: 2px 8px;
  border-radius: 99px;
  border: 1px solid currentColor;
}
.finding-badge-critical { color: var(--cell-danger-fg); background: var(--cell-danger-bg); }
.finding-badge-warning  { color: var(--cell-warn-fg);   background: var(--cell-warn-bg); }
.finding-badge-info     { color: var(--accent-primary); background: color-mix(in srgb, var(--accent-primary) 10%, transparent); }
.finding-badge-ok       { color: var(--cell-ok-fg);     background: var(--cell-ok-bg); }
.finding-title { flex: 1; min-width: 0; font-weight: var(--weight-medium); color: var(--text-primary); }
.finding-area  { flex-shrink: 0; font-size: var(--size-xs); color: var(--text-muted); }
.finding-count {
  flex-shrink: 0;
  font-family: var(--font-mono);
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  color: var(--text-secondary);
  background: var(--progress-track-bg);
  border-radius: 99px;
  padding: 1px 8px;
}
.finding-chevron { flex-shrink: 0; color: var(--text-muted); font-size: 0.85rem; }
.finding-body {
  padding: 4px var(--space-md) var(--space-md) calc(var(--space-md) + 72px);
  font-size: var(--size-sm);
  color: var(--text-secondary);
}
.finding-section { margin-top: var(--space-sm); }
.finding-section p { margin: 2px 0 0; line-height: 1.5; white-space: pre-line; }
.finding-label {
  font-size: 0.68rem;
  font-weight: var(--weight-bold);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-muted);
}
.finding-affected {
  margin: 4px 0 0;
  padding: 0;
  list-style: none;
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}
.finding-affected li {
  font-family: var(--font-mono);
  font-size: var(--size-xs);
  background: var(--progress-track-bg);
  border-radius: var(--radius-sm);
  padding: 1px 6px;
}
.finding-affected li.finding-more { font-family: inherit; font-style: italic; background: transparent; }
.finding-links { display: flex; flex-wrap: wrap; gap: var(--space-sm); margin-top: var(--space-sm); }
.finding-jump {
  font: inherit;
  font-size: var(--size-xs);
  font-weight: var(--weight-bold);
  color: var(--accent-primary-fg, #fff);
  background: var(--accent-primary);
  border: 0;
  border-radius: var(--radius-md);
  padding: 4px 10px;
  cursor: pointer;
}
.finding-ref { font-size: var(--size-xs); color: var(--accent-primary); }
.finding-ref-blocked { color: var(--text-muted); }
.finding-empty, .findings-none { color: var(--text-muted); font-size: var(--size-sm); margin: var(--space-sm) 0 0; }

@media (max-width: 700px) {
  .finding-head { flex-wrap: wrap; }
  .finding-area { order: 5; width: 100%; padding-left: 72px; }
  .finding-body { padding-left: var(--space-md); }
  .findings-filter { max-width: none; margin-left: 0; }
}

/* ── Verdict tile ─────────────────────────────────────────────────────── */
.summary-tile.tile-verdict {
  flex: 1 0 100%;
  max-width: none;
  flex-direction: row;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-md);
  padding: var(--space-md) var(--space-lg);
}
.summary-tile.tile-verdict.cell-danger { background: var(--cell-danger-bg); }
.summary-tile.tile-verdict.cell-warn   { background: var(--cell-warn-bg); }
.summary-tile.tile-verdict.cell-ok     { background: var(--cell-ok-bg); }
.verdict-main { display: flex; align-items: center; gap: var(--space-md); }
.verdict-icon { font-size: 2rem; }
.verdict-text { display: flex; flex-direction: column; gap: 2px; }
.verdict-value {
  font-family: var(--font-display);
  font-size: clamp(1.6rem, 3.5vw, 2.4rem);
  font-weight: var(--weight-bold);
  line-height: 1.1;
  color: var(--text-primary);
}
.summary-tile.tile-verdict.cell-danger .verdict-value { color: var(--cell-danger-fg); }
.summary-tile.tile-verdict.cell-warn   .verdict-value { color: var(--cell-warn-fg); }
.summary-tile.tile-verdict.cell-ok     .verdict-value { color: var(--cell-ok-fg); }
.verdict-caption { font-size: var(--size-sm); color: var(--text-muted); }
.verdict-chips { display: flex; flex-wrap: wrap; gap: 6px; }
.verdict-chip {
  font-size: var(--size-xs);
  border: 1px solid currentColor;
  border-radius: 99px;
  padding: 3px 10px;
  background: var(--bg-surface);
}
.verdict-chip b { font-family: var(--font-mono); }
.verdict-chip-critical { color: var(--cell-danger-fg); }
.verdict-chip-warning  { color: var(--cell-warn-fg); }
.verdict-chip-info     { color: var(--accent-primary); }
.verdict-chip-ok       { color: var(--cell-ok-fg); }

/* ── Score ring and maturity ladder tiles (v2.3.0) ────────────────────── */
.summary-tile.tile-score, .summary-tile.tile-maturity {
  flex: 1 0 100%;
  max-width: none;
  flex-direction: row;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-lg);
  padding: var(--space-md) var(--space-lg);
  text-align: left;
}
.score-ring { position: relative; width: 120px; height: 120px; flex-shrink: 0; }
.score-svg { display: block; }
.score-value {
  position: absolute; inset: 0;
  display: flex; align-items: center; justify-content: center;
  font-family: var(--font-display); font-size: 2rem; font-weight: var(--weight-bold);
  color: var(--text-primary);
}
.score-unit { margin-left: 2px; font-size: 0.9rem; font-weight: var(--weight-medium); color: var(--text-secondary); }
.score-detail { display: flex; flex-direction: column; gap: 2px; min-width: 0; flex: 1; }
.score-caption {
  font-family: var(--font-display);
  font-size: clamp(1.3rem, 3vw, 1.9rem); font-weight: var(--weight-bold); line-height: 1.15;
  color: var(--text-primary);
}
.summary-tile.tile-score.cell-ok     .score-caption { color: var(--cell-ok-fg); }
.summary-tile.tile-score.cell-warn   .score-caption { color: var(--cell-warn-fg); }
.summary-tile.tile-score.cell-danger .score-caption { color: var(--cell-danger-fg); }
.score-facts { font-size: var(--size-sm); color: var(--text-muted); }
.score-delta { display: flex; align-items: center; flex-wrap: wrap; gap: var(--space-sm); margin-top: 4px; }
.score-delta .summary-delta { margin: 0; }
.score-na { font-size: var(--size-xs); font-style: italic; color: var(--cell-warn-fg); }
.maturity-head { display: flex; align-items: center; gap: var(--space-md); min-width: 180px; }
.maturity-value {
  font-family: var(--font-display); font-size: clamp(1.4rem, 3vw, 2rem);
  font-weight: var(--weight-bold); line-height: 1.1; color: var(--text-primary);
}
.maturity-sub { font-size: var(--size-sm); color: var(--text-muted); }
.maturity-steps {
  display: flex; flex-wrap: wrap; gap: var(--space-sm);
  list-style: none; margin: 0; padding: 0; flex: 2 1 320px;
}
.maturity-step {
  flex: 1 1 90px; min-width: 80px;
  display: flex; flex-direction: column; align-items: center; gap: 4px;
  text-align: center; font-size: var(--size-xs); color: var(--text-muted);
  position: relative;
}
.maturity-dot {
  width: 28px; height: 28px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-weight: var(--weight-bold); font-size: var(--size-sm);
  border: 2px solid var(--border-medium); background: var(--bg-surface); color: var(--text-muted);
}
.maturity-step.is-done .maturity-dot { background: var(--accent-primary); border-color: var(--accent-primary); color: var(--accent-primary-fg, #fff); }
.maturity-step.is-current .maturity-dot { box-shadow: 0 0 0 4px color-mix(in srgb, var(--accent-primary) 25%, transparent); }
.maturity-step.is-current .maturity-name { color: var(--text-primary); font-weight: var(--weight-bold); }
.maturity-step.is-next .maturity-dot { border-style: dashed; border-color: var(--accent-primary); color: var(--accent-primary); }
.maturity-desc { flex: 1 0 100%; font-size: var(--size-sm); color: var(--text-secondary); }
.maturity-criteria { flex: 1 0 100%; font-size: var(--size-sm); }
.maturity-crit-title { font-size: 0.68rem; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.08em; color: var(--text-muted); margin-bottom: 2px; }
.maturity-criteria ul { list-style: none; margin: 0; padding: 0; }
.maturity-criteria li { display: flex; gap: 6px; padding: 1px 0; color: var(--text-secondary); }
.maturity-criteria li.is-met { color: var(--text-muted); }
.maturity-criteria li.is-met .maturity-crit-ico { color: var(--cell-ok-fg); }
.maturity-criteria li.is-unmet .maturity-crit-ico { color: var(--cell-warn-fg); }
.maturity-more { font-style: italic; color: var(--text-muted); }

/* ── Bar chart inside a table's chart strip (-Charts Type='bar') ────────── */
.chart-panel.chart-panel-bar { min-width: 260px; max-width: 420px; }
.chart-panel-bar .bar-chart { gap: 6px; }

/* ── Positive empty state (-AllClearText, v2.3.0) ──────────────────────── */
.dh-allclear {
  display: flex; flex-direction: column; align-items: center; gap: var(--space-sm);
  padding: var(--space-xl) var(--space-lg); text-align: center;
  color: var(--text-secondary);
}
.dh-allclear-ico {
  width: 48px; height: 48px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.6rem; font-weight: var(--weight-bold);
  color: var(--text-invert, #fff); background: var(--cell-ok-fg);
}
.dh-allclear-text { font-size: var(--size-md); }
.table-allclear .table-toolbar,
.table-allclear .table-wrapper,
.table-allclear .table-pagination { display: none; }

/* ── Chips and path cells (CellType='chips' / 'path', v2.3.0) ──────────── */
.td-chips, .td-path { white-space: nowrap; }
.cell-chip {
  display: inline-block; margin-right: 4px; padding: 0 7px;
  font-size: var(--size-xs); font-weight: var(--weight-bold); line-height: 1.5;
  color: var(--accent-primary);
  background: color-mix(in srgb, var(--accent-primary) 12%, transparent);
  border-radius: 99px;
}
.cell-path-node { font-size: var(--size-sm); }
.cell-path-sep { margin: 0 5px; color: var(--text-muted); }

/* ── Link cells (CellType='link') ─────────────────────────────────────── */
.cell-link { color: var(--accent-primary); text-decoration: none; }
.cell-link:hover, .cell-link:focus-visible { text-decoration: underline; }

/* ── Export buttons: loading on demand / unavailable offline ────────────── */
.btn-export.btn-export-busy { opacity: 0.6; cursor: progress; }
.btn-export.btn-export-unavailable,
.btn-export.btn-export-unavailable:hover {
  opacity: 0.45;
  cursor: not-allowed;
  text-decoration: line-through;
}

/* ── Print ────────────────────────────────────────────────────────────────
   The JS print module (Get-DhJsPrint) reorders views and unpages tables;
   everything below is pure CSS, so folded content also prints for a printer
   that never runs those handlers. */
.dh-print-cover, .dh-print-path, .dh-print-note { display: none; }

@media print {
  @page { size: A4; margin: 14mm 12mm; }
  html, body {
    background: #fff !important;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }

  /* chrome that only makes sense on screen */
  .report-nav, .nav-sidebar, .nav-crumb, #global-filter-bar, .global-filter-bar,
  .table-toolbar, .table-pagination, .findings-toolbar, .alert-dismiss-btn,
  .collapsible-chevron, .table-section-chevron, .finding-chevron, .finding-jump,
  .topo-toolbar, .ctx-menu, .nav-top-btn { display: none !important; }
  .report-header { position: static !important; box-shadow: none !important; }
  /* the table header gradient starts from a hard-coded dark colour; flat on paper */
  .table-section-header, .table-section-toggle { background: none !important; }

  /* every folded thing open */
  .table-section-body, .collapsible-body, .alert-collapsible-body {
    max-height: none !important;
    overflow: visible !important;
  }
  .finding[hidden], .finding-body[hidden], .findings-group[hidden] { display: block !important; }
  .findings-none { display: none !important; }
  .tabs-panel { display: block !important; }
  .tabs-panel + .tabs-panel { margin-top: 10pt; }

  /* tables: repeat the header row on every page, never split a row */
  thead { display: table-header-group; }
  tfoot { display: table-footer-group; }
  tr, td, th { break-inside: avoid; }
  .table-wrapper { overflow: visible !important; max-height: none !important; }

  /* keep small things whole */
  .summary-tile, .finding, .chart-panel, .bar-item, .verdict-chips,
  .sg-cell, .event-row { break-inside: avoid; }
  .summary-tile, .block-section, .table-section { box-shadow: none !important; }

  /* print-only elements added by the print module */
  .dh-print-path {
    display: block;
    font-size: 14pt;
    margin: 14pt 0 6pt;
    padding-bottom: 3pt;
    border-bottom: 1px solid #999;
    break-after: avoid;
  }
  .dh-print-note { display: block; font-size: 8pt; font-style: italic; color: #555; margin: 4pt 0 0; }
  .dh-print-cover {
    display: flex;
    flex-direction: column;
    gap: 12pt;
    min-height: 240mm;
    justify-content: center;
    break-after: page;
  }
  .dh-print-cover h1 { font-size: 28pt; margin: 0; }
  .dh-print-cover .report-logo { max-height: 60pt; width: auto; align-self: flex-start; }
  .dh-print-cover .summary-tile { max-width: none; }
  /* v2.3.0: the zoom toolbar's real class (the selector above is a stale name) */
  .topology-map-toolbar { display: none !important; }
}

/* ── Findings: split layout, change markers, evidence (v2.3.0) ────────── */
.finding-change {
  flex-shrink: 0; font-size: 0.68rem; font-weight: var(--weight-bold);
  text-transform: uppercase; letter-spacing: 0.05em;
  padding: 1px 7px; border-radius: 99px; border: 1px solid currentColor;
  background: var(--bg-surface);
}
.finding-change-new      { color: var(--accent-primary); }
.finding-change-worse    { color: var(--cell-danger-fg); }
.finding-change-better   { color: var(--cell-ok-fg); }
.finding-change-resolved { color: var(--text-muted); }
.findings-chip-change { color: var(--text-secondary); }
.findings-chip-change-new[aria-pressed="true"]      { background: var(--accent-primary); }
.findings-chip-change-worse[aria-pressed="true"]    { background: var(--cell-danger-fg); }
.findings-chip-change-better[aria-pressed="true"]   { background: var(--cell-ok-fg); }
.findings-chip-change-resolved[aria-pressed="true"] { background: var(--text-muted); }
.findings-changes { padding-left: var(--space-sm); border-left: 1px solid var(--border-subtle); }
.finding-more-detail {
  font: inherit; font-size: var(--size-xs); font-weight: var(--weight-bold);
  color: var(--accent-primary); background: transparent;
  border: 1px solid var(--accent-primary); border-radius: var(--radius-md);
  padding: 3px 10px; cursor: pointer;
}
.finding-section .dh-sec { margin: 4px 0 0; }

.findings-split {
  display: grid;
  grid-template-columns: minmax(220px, 34%) minmax(0, 1fr);
  gap: var(--space-md);
  align-items: start;
}
.findings-split[hidden] { display: none; }
.findings-split-list { max-height: 72vh; overflow-y: auto; padding-right: 2px; }
.finding-item {
  display: flex; align-items: center; gap: var(--space-sm);
  width: 100%; text-align: left;
  font: inherit; color: inherit; cursor: pointer;
  padding: 8px var(--space-sm);
}
.finding-item[hidden] { display: none; }
.finding-item:hover { background: var(--bg-row-hover, var(--progress-track-bg)); }
.finding-item.selected {
  background: color-mix(in srgb, var(--accent-primary) 10%, var(--bg-surface));
  outline: 1px solid var(--accent-primary);
}
.finding-item:focus-visible { outline: 2px solid var(--accent-primary); outline-offset: 1px; }
.finding-item-text { display: flex; flex-direction: column; min-width: 0; flex: 1; }
.finding-item-text .finding-title { white-space: normal; }
.finding-item-sub { font-size: var(--size-xs); color: var(--text-muted); }
.findings-split-detail {
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  background: var(--bg-surface);
  min-width: 0;
}
.finding-pane { padding: var(--space-md) var(--space-lg); border-left: 4px solid var(--border-medium); border-radius: var(--radius-md); }
.finding-pane[hidden] { display: none; }
.finding-pane.finding-critical { border-left-color: var(--cell-danger-fg); }
.finding-pane.finding-warning  { border-left-color: var(--cell-warn-fg); }
.finding-pane.finding-info     { border-left-color: var(--accent-primary); }
.finding-pane.finding-ok       { border-left-color: var(--cell-ok-fg); }
.finding-pane-head { display: flex; align-items: center; flex-wrap: wrap; gap: var(--space-sm); margin-bottom: var(--space-sm); }
.finding-pane-title { margin: 0; font-size: var(--size-md); color: var(--text-primary); flex: 1; min-width: 0; }
.finding-pane .finding-section:first-child { margin-top: 0; }
@media (max-width: 700px) {
  .findings-split { grid-template-columns: minmax(0, 1fr); }
  .findings-split-list { max-height: 40vh; }
}
@media print {
  .findings-split { display: block; }
  .findings-split-list { display: none !important; }
  .findings-split-detail { border: 0; }
  .finding-pane[hidden] { display: block !important; }
  .finding-pane { break-inside: auto; margin-bottom: 8pt; }
  .finding-pane-head { break-after: avoid; }
  .finding-more-detail, .findings-changes { display: none !important; }
}

/* ── Sections and detail drawer (v2.3.0) ──────────────────────────────────
   renderSections() output is shared by the drawer, Add-DhKeyValue,
   Add-DhRecordList and the findings split layout. Colours only through the
   theme tokens so all 12 themes apply. */
.dh-st-ok     { --dh-st: var(--cell-ok-fg); }
.dh-st-warn   { --dh-st: var(--cell-warn-fg); }
.dh-st-danger { --dh-st: var(--cell-danger-fg); }
.dh-st-info   { --dh-st: var(--accent-primary); }
.dh-st-nodata { --dh-st: var(--cell-nodata-fg); }
.dh-sec { margin: 0 0 var(--space-md); }
.dh-sec-title {
  margin: 0 0 var(--space-sm);
  font-size: 0.68rem;
  font-weight: var(--weight-bold);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-muted);
}
.dh-kv { display: grid; gap: var(--space-sm); margin: 0; grid-template-columns: repeat(2, minmax(0, 1fr)); }
.dh-kv-cols-1 { grid-template-columns: minmax(0, 1fr); }
.dh-kv-cols-3 { grid-template-columns: repeat(3, minmax(0, 1fr)); }
.dh-kv-cols-4 { grid-template-columns: repeat(4, minmax(0, 1fr)); }
.dh-kv-cols-5 { grid-template-columns: repeat(5, minmax(0, 1fr)); }
.dh-kv-cols-6 { grid-template-columns: repeat(6, minmax(0, 1fr)); }
.dh-kv-item {
  min-width: 0;
  padding: var(--space-sm) var(--space-md);
  background: var(--progress-track-bg);
  border-radius: var(--radius-md);
  border-left: 3px solid transparent;
}
.dh-kv-item[class*="dh-st-"] { border-left-color: var(--dh-st); }
.dh-kv-label {
  font-size: 0.68rem;
  font-weight: var(--weight-bold);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-muted);
}
.dh-kv-value {
  margin: 2px 0 0;
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  overflow-wrap: anywhere;
}
.dh-kv-item[class*="dh-st-"] .dh-kv-value { color: var(--dh-st); }
.dh-bars { display: flex; flex-direction: column; gap: 6px; }
.dh-bar-row { display: grid; grid-template-columns: minmax(80px, 30%) 1fr auto; align-items: center; gap: var(--space-sm); font-size: var(--size-sm); }
.dh-bar-label { color: var(--text-secondary); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.dh-bar-track { height: 8px; background: var(--progress-track-bg); border-radius: 99px; overflow: hidden; }
.dh-bar-fill { display: block; height: 100%; background: var(--dh-st, var(--accent-primary)); border-radius: 99px; }
.dh-bar-val { font-family: var(--font-mono); font-size: var(--size-xs); color: var(--text-secondary); }
.dh-statuslist, .dh-checks, .dh-links { list-style: none; margin: 0; padding: 0; }
.dh-statusrow { display: flex; justify-content: space-between; gap: var(--space-md); padding: 4px 0; border-bottom: 1px solid var(--border-subtle); font-size: var(--size-sm); }
.dh-statuslabel { color: var(--text-primary); }
.dh-statusval { display: inline-flex; align-items: center; gap: 6px; color: var(--dh-st, var(--text-secondary)); }
.dh-dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: var(--dh-st, var(--text-muted)); }
.dh-check { display: flex; align-items: baseline; gap: var(--space-sm); padding: 3px 0; font-size: var(--size-sm); }
.dh-check-ico { width: 1.2em; text-align: center; font-weight: var(--weight-bold); color: var(--dh-st); }
.dh-check-label { color: var(--text-primary); }
.dh-check-note { margin-left: auto; color: var(--text-muted); font-size: var(--size-xs); }
.dh-tbl-wrap { overflow-x: auto; }
.dh-tbl { width: 100%; border-collapse: collapse; font-size: var(--size-sm); }
.dh-tbl th {
  text-align: left; padding: 4px var(--space-sm);
  font-size: 0.68rem; text-transform: uppercase; letter-spacing: 0.06em; color: var(--text-muted);
  border-bottom: 1px solid var(--border-medium);
}
.dh-tbl td { padding: 4px var(--space-sm); border-bottom: 1px solid var(--border-subtle); color: var(--text-primary); overflow-wrap: anywhere; }
.dh-pill {
  display: inline-block; padding: 0 8px; border-radius: 99px;
  font-size: var(--size-xs); font-weight: var(--weight-bold);
  color: var(--dh-st);
  background: color-mix(in srgb, var(--dh-st) 14%, transparent);
}
.dh-more { margin: 4px 0 0; font-size: var(--size-xs); font-style: italic; color: var(--text-muted); }
.dh-text { margin: 0; line-height: 1.5; white-space: pre-line; color: var(--text-secondary); font-size: var(--size-sm); }
.dh-links li { padding: 2px 0; font-size: var(--size-sm); }
.dh-links a { color: var(--accent-primary); }
.dh-link-blocked { color: var(--text-muted); }

/* Add-DhRecordList block */
.recordlist-section .recordlist-title { margin: 0 0 var(--space-sm); font-size: var(--size-md); color: var(--text-primary); }
.recordlist-toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-sm); margin-bottom: var(--space-sm); }
.recordlist-filter {
  flex: 1 1 200px; max-width: 320px;
  font: inherit; font-size: var(--size-sm); padding: 5px 10px;
  border: 1px solid var(--border-medium); border-radius: var(--radius-md);
  background: var(--bg-input, var(--bg-surface)); color: var(--text-primary);
}
.recordlist-btn {
  font: inherit; font-size: var(--size-xs); font-weight: var(--weight-bold);
  color: var(--text-secondary); background: var(--bg-surface);
  border: 1px solid var(--border-medium); border-radius: var(--radius-md);
  padding: 4px 10px; cursor: pointer;
}
.recordlist-btn:hover { color: var(--text-primary); }
.recordlist { display: flex; flex-direction: column; gap: var(--space-sm); }
.record {
  background: var(--bg-surface); border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg); box-shadow: var(--shadow-md);
}
.record[hidden] { display: none; }
.record-head {
  display: flex; align-items: center; gap: var(--space-md);
  width: 100%; text-align: left; font: inherit; color: inherit;
  background: transparent; border: 0; cursor: pointer;
  padding: var(--space-md) var(--space-lg);
}
.record-head:focus-visible { outline: 2px solid var(--accent-primary); outline-offset: -2px; border-radius: var(--radius-lg); }
.record-dot { flex-shrink: 0; width: 10px; height: 10px; border-radius: 50%; background: var(--dh-st, var(--text-muted)); }
.record-text { display: flex; flex-direction: column; min-width: 0; flex: 1; }
.record-title { font-family: var(--font-mono); font-weight: var(--weight-bold); color: var(--text-primary); overflow-wrap: anywhere; }
.record-sub { font-size: var(--size-xs); color: var(--text-muted); overflow-wrap: anywhere; }
.record-metrics { display: flex; gap: var(--space-lg); flex-shrink: 0; }
.record-metric { display: flex; flex-direction: column; align-items: center; min-width: 44px; }
.record-metric-value { font-weight: var(--weight-bold); color: var(--text-primary); }
.record-metric[class*="dh-st-"] .record-metric-value { color: var(--dh-st); }
.record-metric-label { font-size: 0.62rem; text-transform: uppercase; letter-spacing: 0.06em; color: var(--text-muted); }
.record-chevron { flex-shrink: 0; color: var(--text-muted); }
.record-body { padding: var(--space-md) var(--space-lg) var(--space-lg); border-top: 1px solid var(--border-subtle); }
.record-body .dh-sec:last-child { margin-bottom: 0; }
.recordlist-none { color: var(--text-muted); font-size: var(--size-sm); }
@media (max-width: 700px) {
  .record-head { flex-wrap: wrap; }
  .record-metrics { order: 3; width: 100%; justify-content: flex-start; padding-left: 22px; }
}
@media print {
  .record[hidden] { display: block !important; }
  .record-body[hidden] { display: block !important; }
  .record { break-inside: auto; box-shadow: none; }
  .record-head { break-after: avoid; }
  .record-chevron, .recordlist-toolbar { display: none !important; }
}

/* Add-DhKeyValue block */
.keyvalue-section .keyvalue-title { margin: 0 0 var(--space-sm); font-size: var(--size-md); color: var(--text-primary); }

/* The drawer: one element on <body>, above the sticky header, below the topology tooltip */
.dh-drawer-backdrop { position: fixed; inset: 0; z-index: 1000; background: rgba(0, 0, 0, 0.32); }
.dh-drawer {
  position: fixed; top: 0; right: 0; bottom: 0; z-index: 1001;
  width: min(460px, 100vw);
  display: flex; flex-direction: column;
  background: var(--bg-surface);
  color: var(--text-primary);
  border-left: 1px solid var(--border-medium);
  box-shadow: var(--shadow-md);
}
.dh-drawer[hidden], .dh-drawer-backdrop[hidden] { display: none; }
.dh-drawer-head {
  display: flex; align-items: flex-start; justify-content: space-between; gap: var(--space-md);
  padding: var(--space-md) var(--space-lg);
  border-bottom: 1px solid var(--border-subtle);
}
.dh-drawer-title { font-size: var(--size-md); font-weight: var(--weight-bold); overflow-wrap: anywhere; }
.dh-drawer-sub { margin-top: 2px; font-size: var(--size-xs); color: var(--text-muted); overflow-wrap: anywhere; }
.dh-drawer-close {
  flex-shrink: 0; width: 28px; height: 28px; line-height: 1;
  font-size: 1.3rem; color: var(--text-secondary);
  background: transparent; border: 0; border-radius: var(--radius-md); cursor: pointer;
}
.dh-drawer-close:hover, .dh-drawer-close:focus-visible { background: var(--progress-track-bg); color: var(--text-primary); }
.dh-drawer-body { flex: 1; overflow-y: auto; padding: var(--space-md) var(--space-lg) var(--space-xl); }
.dh-drawer-actions { margin-top: var(--space-md); }
.dh-drawer-jump {
  font: inherit; font-size: var(--size-xs); font-weight: var(--weight-bold);
  color: var(--accent-primary-fg, #fff); background: var(--accent-primary);
  border: 0; border-radius: var(--radius-md); padding: 5px 12px; cursor: pointer;
}
/* clickable rows that open the drawer */
tr.dh-drawer-row { cursor: pointer; }
@media (max-width: 700px) {
  .dh-kv, .dh-kv-cols-3, .dh-kv-cols-4, .dh-kv-cols-5, .dh-kv-cols-6 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .dh-bar-row { grid-template-columns: minmax(60px, 35%) 1fr auto; }
}
@media print {
  .dh-drawer, .dh-drawer-backdrop { display: none !important; }
  .dh-kv-item, .dh-sec, .dh-tbl tr { break-inside: avoid; }
  .tile-score, .tile-maturity, .maturity-step, .maturity-criteria { break-inside: avoid; }
}

/* ── New-DhDashboard -NavBadge and -Search (v2.4.0) ───────────────────────── */
.nav-sev {
  display: inline-block; margin-left: 6px; padding: 0 6px; min-width: 1.5em; text-align: center;
  border-radius: 99px; font-size: 0.68rem; font-weight: var(--weight-bold); line-height: 1.5;
}
.nav-sev-critical { color: var(--cell-danger-fg); background: var(--cell-danger-bg); border: 1px solid var(--cell-danger-fg); }
.nav-sev-warning  { color: var(--cell-warn-fg);   background: var(--cell-warn-bg);   border: 1px solid var(--cell-warn-fg); }
.nav-sev-info     { color: var(--accent-primary); background: var(--bg-surface);     border: 1px solid var(--accent-primary); }
.nav-sev-sr { position: absolute; width: 1px; height: 1px; margin: -1px; overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap; }
.nav-search { position: relative; flex: 0 1 220px; min-width: 120px; }
.nav-search-input {
  width: 100%; font: inherit; font-size: var(--size-sm); padding: 4px 10px;
  border: 1px solid var(--border-medium); border-radius: var(--radius-md);
  background: var(--bg-input, var(--bg-surface)); color: var(--text-primary);
}
.nav-search-list {
  position: absolute; z-index: 120; top: calc(100% + 4px); right: 0; width: min(460px, 92vw);
  max-height: 60vh; overflow-y: auto; padding: 4px 0;
  background: var(--bg-surface); border: 1px solid var(--border-medium);
  border-radius: var(--radius-md); box-shadow: var(--shadow-md);
}
.nav-search-list[hidden] { display: none; }
.ns-group { padding: 6px 12px 2px; font-size: 0.68rem; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.08em; color: var(--text-muted); }
.ns-item { display: block; width: 100%; text-align: left; padding: 5px 12px; font: inherit; font-size: var(--size-sm); color: var(--text-primary); background: transparent; border: 0; cursor: pointer; }
.ns-item:hover, .ns-item[aria-selected="true"] { background: var(--bg-row-hover); }
.ns-sub { display: block; font-size: var(--size-xs); color: var(--text-muted); }
.ns-count { float: right; font-family: var(--font-mono); font-size: var(--size-xs); color: var(--text-secondary); }
.ns-empty { padding: 8px 12px; font-size: var(--size-sm); color: var(--text-muted); }
@keyframes dh-flash { from { box-shadow: 0 0 0 3px var(--accent-primary); } to { box-shadow: 0 0 0 3px transparent; } }
.dh-flash { animation: dh-flash 1.6s ease-out 1; }
@media print { .nav-search, .nav-sev { display: none !important; } }

/* footer totals computed over the selected rows */
.tfoot-row.tfoot-selected .tfoot-cell { color: var(--accent-primary); font-weight: var(--weight-bold); }

/* ── Add-DhTreeFilter (v2.4.0) ──────────────────────────────────────────── */
.treefilter-section .treefilter-title { margin: 0 0 var(--space-sm); font-size: var(--size-md); color: var(--text-primary); }
.treefilter-toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-sm); margin-bottom: var(--space-sm); }
.treefilter-find {
  flex: 1 1 180px; max-width: 280px;
  font: inherit; font-size: var(--size-sm); padding: 5px 10px;
  border: 1px solid var(--border-medium); border-radius: var(--radius-md);
  background: var(--bg-input, var(--bg-surface)); color: var(--text-primary);
}
.treefilter-btn {
  font: inherit; font-size: var(--size-xs); padding: 4px 10px; cursor: pointer;
  color: var(--text-secondary); background: transparent;
  border: 1px solid var(--border-medium); border-radius: var(--radius-md);
}
.treefilter-btn:hover, .treefilter-btn:focus-visible { color: var(--text-primary); background: var(--progress-track-bg); }
.treefilter-btn[hidden] { display: none; }
.treefilter-scroll { overflow: auto; border: 1px solid var(--border-subtle); border-radius: var(--radius-md); background: var(--bg-surface); }
.treefilter-empty { padding: var(--space-md); font-size: var(--size-sm); color: var(--text-muted); }
.dh-tree { padding: 4px 0; min-width: max-content; }
.dh-tree-row {
  display: flex; align-items: center; gap: 6px;
  padding: 3px 10px 3px 6px; font-size: var(--size-sm); cursor: pointer;
  color: var(--text-primary); border-left: 3px solid transparent;
}
.dh-tree-row:hover { background: var(--progress-track-bg); }
.dh-tree-row:focus-visible { outline: 2px solid var(--accent-primary); outline-offset: -2px; }
.dh-tree-row.dh-tree-sel { background: color-mix(in srgb, var(--accent-primary) 14%, transparent); border-left-color: var(--accent-primary); font-weight: var(--weight-bold); }
.dh-tree-chev { width: 1.1em; flex-shrink: 0; text-align: center; color: var(--text-muted); }
.dh-tree-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; background: var(--dh-st, var(--text-muted)); }
.dh-tree-dot-none { background: transparent; }
.dh-tree-label { white-space: nowrap; }
.dh-tree-flag {
  padding: 0 6px; border-radius: 99px; font-size: 0.68rem; font-weight: var(--weight-bold);
  color: var(--text-primary); background: var(--progress-track-bg); white-space: nowrap;
}
.dh-tree-count { margin-left: auto; padding-left: var(--space-md); font-family: var(--font-mono); font-size: var(--size-xs); color: var(--text-secondary); }
.dh-tree-info {
  flex-shrink: 0; width: 20px; height: 20px; line-height: 1; padding: 0; cursor: pointer;
  font: italic 0.75rem serif; color: var(--accent-primary);
  background: transparent; border: 1px solid var(--border-medium); border-radius: 50%;
}
.dh-tree-info:hover, .dh-tree-info:focus-visible { background: var(--progress-track-bg); }
@media print {
  .treefilter-toolbar, .dh-tree-info, .treefilter-empty { display: none !important; }
  .treefilter-scroll { max-height: none !important; overflow: visible; border: 0; }
  .dh-tree { min-width: 0; }
  .dh-tree-row { break-inside: avoid; }
}

/* column picker: back to the default columns */
.col-toggle-reset { display: block; width: 100%; margin-top: 4px; padding: 5px 8px; font: inherit; font-size: var(--size-xs); text-align: left; cursor: pointer; color: var(--text-secondary); background: transparent; border: 0; border-top: 1px solid var(--border-subtle); }
.col-toggle-reset:hover, .col-toggle-reset:focus-visible { color: var(--text-primary); background: var(--progress-track-bg); }

/* ── Menu overflow (v2.5.0) ────────────────────────────────────────────── */
.nav-more { position: relative; display: inline-block; }
.nav-more-btn {
  font: inherit; font-size: var(--size-sm); padding: 3px 10px; cursor: pointer;
  color: var(--text-secondary); background: transparent; border: 1px solid var(--border-medium); border-radius: 99px;
}
.nav-more-btn:hover, .nav-more-btn:focus-visible { color: var(--text-primary); background: var(--progress-track-bg); }
.nav-more-menu {
  position: absolute; z-index: 130; top: calc(100% + 4px); left: 0; min-width: 180px; max-height: 60vh; overflow-y: auto;
  display: flex; flex-direction: column; padding: 4px; gap: 2px;
  background: var(--bg-surface); border: 1px solid var(--border-medium); border-radius: var(--radius-md); box-shadow: var(--shadow-md);
}
.nav-more-menu[hidden] { display: none; }
.nav-more-menu .nav-chip { display: block; text-align: left; white-space: nowrap; }
@media print { .nav-more { display: none !important; } }
/* ── Empty view (v2.5.0) ───────────────────────────────────────────────── */
.nav-empty { padding: var(--space-lg); margin: var(--space-md) 0; text-align: center; color: var(--text-secondary); background: var(--bg-surface); border: 1px dashed var(--border-medium); border-radius: var(--radius-md); }
.nav-empty[hidden] { display: none; }
.nav-empty code { font-family: var(--font-mono); }
.nav-empty-back { font: inherit; font-size: var(--size-sm); padding: 3px 10px; margin-left: 6px; cursor: pointer; color: var(--text-primary); background: var(--bg-surface); border: 1px solid var(--border-medium); border-radius: var(--radius-md); }
@media print { .nav-empty { display: none !important; } }
/* ── Add-DhTreeTable (v2.5.0) ───────────────────────────────────────────── */
.treetable-section .treetable-title { margin: 0 0 var(--space-sm); font-size: var(--size-md); color: var(--text-primary); }
.tt { display: grid; grid-template-columns: minmax(260px, 38%) minmax(0, 1fr); gap: var(--space-md); }
.tt-left, .tt-right { display: flex; flex-direction: column; min-height: 0; border: 1px solid var(--border-subtle); border-radius: var(--radius-md); background: var(--bg-surface); }
.tt-left { overflow: hidden; }
.tt-toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; padding: var(--space-sm); border-bottom: 1px solid var(--border-subtle); }
.tt-find { flex: 1 1 140px; max-width: none; }
.tt-chips { display: inline-flex; flex-wrap: wrap; gap: 4px; flex-basis: 100%; }
.tt-tree { flex: 1; overflow: auto; min-width: 0; }
.tt-tree.dh-tree { min-width: 0; }
.tt-type {
  display: inline-flex; align-items: center; justify-content: center; flex-shrink: 0;
  min-width: 22px; height: 18px; padding: 0 4px; border-radius: 4px;
  font-size: 0.62rem; font-weight: var(--weight-bold); letter-spacing: 0.03em;
  color: var(--text-secondary); background: var(--progress-track-bg); border: 1px solid var(--border-medium);
}
/* the type is told by the border colour; the letters keep the primary text colour so they stay readable in every theme */
.tt-type { color: var(--text-primary); }
.tt-type-ou, .tt-type-container { border-color: var(--accent-primary); }
.tt-type-group { border-color: var(--cell-warn-fg); }
.tt-type-user { border-color: var(--cell-ok-fg); }
.tt-right { overflow: hidden; }
.tt-head { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; padding: var(--space-sm) var(--space-md); border-bottom: 1px solid var(--border-subtle); min-height: 40px; }
.tt-head-label { font-size: var(--size-md); font-weight: var(--weight-bold); color: var(--text-primary); overflow-wrap: anywhere; }
.tt-tabs { display: flex; flex-wrap: wrap; gap: 2px; padding: 0 var(--space-sm); border-bottom: 1px solid var(--border-subtle); }
.tt-tab {
  font: inherit; font-size: var(--size-sm); padding: 6px 12px; cursor: pointer;
  color: var(--text-secondary); background: transparent; border: 0; border-bottom: 2px solid transparent;
}
.tt-tab:hover, .tt-tab:focus-visible { color: var(--text-primary); }
.tt-tab[aria-selected="true"] { color: var(--text-primary); border-bottom-color: var(--accent-primary); font-weight: var(--weight-bold); }
.tt-body { flex: 1; overflow: auto; padding: var(--space-md); }
.tt-list { display: flex; flex-direction: column; gap: 2px; }
.tt-link {
  display: inline-flex; align-items: center; gap: 6px; width: fit-content; max-width: 100%;
  font: inherit; font-size: var(--size-sm); text-align: left; padding: 2px 6px; cursor: pointer;
  color: var(--text-primary); background: transparent; border: 0; border-radius: var(--radius-sm);
}
.tt-link:hover, .tt-link:focus-visible { background: var(--progress-track-bg); }
.tt-nest > div { padding: 2px 0; }
.tt-path { display: flex; flex-wrap: wrap; align-items: center; gap: 2px; }
.tt-arrow { color: var(--text-muted); padding: 0 2px; }
.tt-circ { font-size: var(--size-xs); font-weight: var(--weight-bold); color: var(--cell-danger-fg); }
.tt-circ-note { margin-top: var(--space-sm); font-size: var(--size-sm); color: var(--cell-danger-fg); }
@media (max-width: 800px) { .tt { grid-template-columns: minmax(0, 1fr); height: auto !important; } .tt-tree { max-height: 320px; } }
@media print {
  .tt { display: block; height: auto !important; }
  .tt-toolbar, .tt-tabs { display: none !important; }
  .tt-tree, .tt-body { max-height: none; overflow: visible; }
  .tt-left, .tt-right { break-inside: avoid; margin-bottom: 8pt; }
}

/* ── Add-DhNetworkMap (v2.4.0) ───────────────────────────────────────────
   Colours only through the theme tokens, so all 12 themes apply. */
.network-map-section {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-sm) var(--space-lg);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-xs);
}
.network-map-title {
  font-size: var(--size-md); font-weight: var(--weight-bold); color: var(--text-secondary);
  text-transform: uppercase; letter-spacing: 0.07em; margin-bottom: var(--space-sm);
}
.network-map-empty { color: var(--text-muted); font-style: italic; padding: var(--space-md); text-align: center; }
.network-map-inner.topo-interactive {
  width: 100%; overflow: hidden; cursor: grab;
  border: 1px solid var(--border-subtle); border-radius: var(--radius-md);
  background: radial-gradient(circle, var(--border-subtle) 1px, transparent 1px) 0 0 / 22px 22px;
}
.network-map-inner.topo-interactive.topo-panning { cursor: grabbing; }
.network-map-svg { display: block; height: 100%; }
.network-map-toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; margin-bottom: 6px; }
.network-map-toolbar .nm-search {
  flex: 0 1 170px; min-width: 110px; margin-left: auto;
  font: inherit; font-size: var(--size-sm); padding: 4px 10px;
  border: 1px solid var(--border-medium); border-radius: var(--radius-md);
  background: var(--bg-input, var(--bg-surface)); color: var(--text-primary);
}
.nm-btn {
  font: inherit; font-size: var(--size-xs); padding: 4px 10px; cursor: pointer;
  color: var(--text-secondary); background: var(--bg-surface);
  border: 1px solid var(--border-subtle); border-radius: var(--radius-sm);
}
.nm-btn:hover, .nm-btn:focus-visible { color: var(--text-primary); background: var(--bg-row-hover); }
.nm-btn[aria-pressed="true"] { color: var(--text-primary); border-color: var(--accent-primary); font-weight: var(--weight-bold); }
.nm-chips { display: inline-flex; flex-wrap: wrap; gap: 4px; flex-basis: 100%; }
.nm-chip {
  display: inline-flex; align-items: center; gap: 5px;
  font: inherit; font-size: var(--size-xs); padding: 2px 9px; cursor: pointer;
  color: var(--text-secondary); background: transparent;
  border: 1px solid var(--border-medium); border-radius: 99px;
}
.nm-chip[aria-pressed="true"] { color: var(--text-primary); background: var(--progress-track-bg); border-color: var(--accent-primary); font-weight: var(--weight-bold); }
.nm-chip-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--nm-c, var(--text-muted)); display: inline-block; }
.nm-legend { display: flex; flex-wrap: wrap; gap: var(--space-md); margin-bottom: 6px; font-size: var(--size-xs); color: var(--text-secondary); }
.nm-legend-item { display: inline-flex; align-items: center; gap: 5px; }
.nm-legend-line { stroke: var(--text-secondary); stroke-width: 2; }
.nm-dashed-line { stroke-dasharray: 6 4; }
.nm-target-sample { color: var(--text-primary); }
.nm-status { min-height: 1.4em; margin-top: 4px; font-size: var(--size-xs); color: var(--text-secondary); }
.nm-sr { position: absolute; width: 1px; height: 1px; margin: -1px; padding: 0; overflow: hidden; clip: rect(0 0 0 0); border: 0; white-space: nowrap; }

.nm-st-ok     { --nm-c: var(--cell-ok-fg); }
.nm-st-warn   { --nm-c: var(--cell-warn-fg); }
.nm-st-danger { --nm-c: var(--cell-danger-fg); }
.nm-st-info   { --nm-c: var(--accent-primary); }
.nm-st-nodata { --nm-c: var(--cell-nodata-fg); }

.nm-lane-band { fill: transparent; stroke: var(--border-subtle); }
.nm-lane-alt  { fill: var(--progress-track-bg); fill-opacity: 0.5; }
.nm-lane-label { fill: var(--text-muted); font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em; }
.nm-group-box { fill: color-mix(in srgb, var(--accent-primary) 4%, transparent); stroke: var(--nm-c, var(--border-medium)); stroke-width: 1.25; }
.nm-group-label { fill: var(--text-secondary); font-size: 11px; font-weight: 700; }

.nm-edge { cursor: default; }
.nm-edge.nm-clickable { cursor: pointer; }
.nm-edge-hit  { fill: none; stroke: transparent; stroke-width: 12; pointer-events: stroke; }
.nm-edge-line { fill: none; stroke: var(--nm-c, var(--text-muted)); stroke-width: 1.6; }
.nm-e-ok     { --nm-c: var(--cell-ok-fg); }
.nm-e-warn   { --nm-c: var(--cell-warn-fg); }
.nm-e-danger { --nm-c: var(--cell-danger-fg); }
.nm-e-info   { --nm-c: var(--accent-primary); }
.nm-e-nodata { --nm-c: var(--cell-nodata-fg); }
.nm-e-none   { --nm-c: var(--text-muted); }
.nm-dashed .nm-edge-line { stroke-dasharray: 6 4; }
.nm-arrow path { fill: var(--nm-c, var(--text-muted)); }
.nm-edge-label rect { fill: var(--bg-surface); stroke: var(--border-subtle); }
.nm-edge-label text { fill: var(--text-secondary); font-size: 10.5px; }
.nm-hide-labels .nm-edge-label { display: none; }

.nm-node { cursor: pointer; }
.nm-node-box { fill: var(--bg-surface); stroke: var(--nm-c, var(--border-medium)); stroke-width: 1.5; }
.nm-led { fill: var(--nm-c, var(--text-muted)); }
.nm-node-label { fill: var(--text-primary); font-size: 12.5px; font-weight: 600; }
.nm-node-badges { fill: var(--text-muted); font-size: 10.5px; }
.nm-target .nm-node-box { stroke-width: 3; }
.nm-target-mark { fill: var(--text-primary); font-size: 12px; }
.nm-node:hover .nm-node-box { fill: var(--bg-row-hover); }
.nm-node:focus-visible { outline: none; }
.nm-node:focus-visible .nm-node-box { stroke: var(--accent-primary); stroke-width: 3; }
.nm-node.nm-sel .nm-node-box { stroke: var(--accent-primary); stroke-width: 3; fill: color-mix(in srgb, var(--accent-primary) 10%, var(--bg-surface)); }
.nm-dim { opacity: 0.18; }
.nm-edge.nm-onpath .nm-edge-line { stroke-width: 3.5; }
.nm-node.nm-onpath .nm-node-box { stroke: var(--accent-primary); stroke-width: 3; }
@media print {
  .network-map-toolbar, .nm-status { display: none !important; }
  .network-map-section { break-inside: avoid; box-shadow: none; }
  .nm-dim { opacity: 1; }
}

/* ===== v2.5.2 baseline markers (Add-DhTable -Baseline) ===== */
.tbl-change-bar { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 14px; padding: 6px var(--space-md); border-bottom: 1px solid var(--border-subtle); font-size: var(--size-sm); }
.tbl-baseline-note { color: var(--text-secondary); }
.chg-chips { display: inline-flex; flex-wrap: wrap; gap: 4px; }
.chg-chip { font: inherit; font-size: var(--size-xs); padding: 2px 10px; border-radius: 99px; border: 1px solid var(--border-medium); background: var(--bg-surface); color: var(--text-primary); cursor: pointer; }
.chg-chip[aria-pressed="true"] { background: var(--accent-primary); border-color: var(--accent-primary); color: var(--accent-primary-fg, #fff); }
.chg-chip:focus-visible { outline: 2px solid var(--accent-primary); outline-offset: 2px; }
.chg-n { font-family: var(--font-mono); }
.chg-incl { margin-left: auto; color: var(--text-secondary); font-size: var(--size-xs); }
.chg-tag { display: inline-block; margin-right: 6px; padding: 0 6px; border: 1px solid currentColor; border-radius: 99px; font-size: 0.68rem; font-weight: var(--weight-bold); }
.chg-new { color: var(--cell-ok-fg); background: var(--cell-ok-bg); }
.chg-changed { color: var(--cell-warn-fg); background: var(--cell-warn-bg); }
tr.row-new > td:first-child { border-left: 3px solid var(--cell-ok-fg); }
tr.row-changed > td:first-child { border-left: 3px solid var(--cell-warn-fg); }
td.cell-changed { outline: 1px dashed var(--cell-warn-fg); outline-offset: -2px; }
.tbl-removed { margin: var(--space-sm) var(--space-md) var(--space-md); border: 1px solid var(--border-subtle); border-radius: var(--radius-md); background: var(--bg-surface); }
.tbl-removed > summary { cursor: pointer; padding: 6px var(--space-md); font-weight: var(--weight-bold); color: var(--text-primary); }
.tbl-removed > summary:focus-visible { outline: 2px solid var(--accent-primary); outline-offset: -2px; }
.tbl-removed-body { overflow-x: auto; padding: 0 var(--space-md) var(--space-sm); }
.tbl-removed-table { border-collapse: collapse; font-size: var(--size-sm); width: 100%; }
.tbl-removed-table th, .tbl-removed-table td { text-align: left; padding: 3px 8px; border-bottom: 1px solid var(--border-subtle); color: var(--text-primary); white-space: nowrap; }
.tbl-removed-none { color: var(--text-secondary); font-style: italic; }
@media print {
  .chg-chips, .chg-incl { display: none !important; }
  .tbl-removed, .tbl-change-bar { break-inside: avoid; }
  tr.row-new > td:first-child, tr.row-changed > td:first-child { border-left-width: 3px; }
}
/* v2.4.2: a table wider than the page wraps its cells instead of running off the paper (the section clips overflow) */
@media print {
  .table-section { overflow: visible; }
  .data-table { width: 100% !important; table-layout: auto; font-size: 8pt; }
  .data-table th, .data-table td { white-space: normal !important; overflow-wrap: anywhere; max-width: none !important; min-width: 0 !important; }
  .data-table th, .data-table .cell-chip { overflow-wrap: normal; }
  .data-table th, .data-table td { padding: 3px 4px !important; }
  .data-table td svg { max-width: 64px; height: auto; }
  .data-table .progress-wrap { min-width: 0 !important; }
  .data-table .progress-track { min-width: 24px !important; }   /* header words stay whole, so a narrow column is never wider than its label */
  .col-resizer, .sort-icon { display: none !important; }
  /* soft shadows print as blurred images and can hide the content on top of them */
  *, *::before, *::after { box-shadow: none !important; text-shadow: none !important; }
}

'@
}


