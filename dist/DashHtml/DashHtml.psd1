@{
    # Module identity
    RootModule        = 'DashHtml.psm1'
    ModuleVersion     = '2.1.3'
    GUID              = '3f8e9a2c-1d4b-47f5-8c6e-0a5d2b9f3e71'
    Author            = 'DashHtml Contributors'
    CompanyName       = 'DashHtml Contributors'
    Copyright         = '(c) 2026 DashHtml Contributors. MIT License.'
    Description       = 'Generate interactive self-contained HTML dashboards. Includes sortable / filterable / pageable tables, linked drill-down, client-side CSV / Excel / PDF export, KPI summary tiles (with optional sparklines, trend deltas, big-number and gauge styles), pie / donut / line / area / bar / stacked-bar / bullet charts, min-avg-max range-gradient bars, RAG status matrix, sequential / diverging 2-D heatmaps, parent-child topology trees, inline tabbed content blocks, chronological event feeds, dismissible alert banners, threshold cell colouring with a unified -Rag parameter, and a sticky nav bar. Six built-in theme families (Default, Azure, VMware, Grey, Company, Rag — the v1.4 family using the Office/Excel-compatible RAG palette) each with embedded light / dark variants and a runtime toggle button.'
    PowerShellVersion = '7.0'

    # Exports
    FunctionsToExport = @(
        'New-DhDashboard'
        'Add-DhTable'
        'Set-DhTableLink'
        'Export-DhDashboard'
        'Get-DhTheme'
        'Add-DhSummary'
        'Add-DhHtmlBlock'
        'Add-DhCollapsible'
        'Add-DhFilterCard'
        'Add-DhBarChart'
        'Add-DhAlertBanner'
        'Add-DhPieChart'
        'Add-DhBullet'
        'Add-DhLineChart'
        'Add-DhEventFeed'
        'Add-DhStatusGrid'
        'Add-DhTabs'
        'Add-DhHeatmap'
        'Add-DhRangeBar'
        'Add-DhTopologyMap'
        'Add-DhGlobalFilter'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Gallery metadata
    PrivateData = @{
        PSData = @{
            Tags         = @('HTML','Dashboard','Table','Export','CSV','Excel','PDF','Report','Infrastructure')
            LicenseUri   = 'https://github.com/nicola-vi/DashHtml/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/nicola-vi/DashHtml'
            ReleaseNotes = @'
2.0.0 - MAJOR RELEASE. See MIGRATION-v2.md. All five bundled examples upgrade with ZERO edits.

(1) BREAKING: -AllowHtml now defaults to $false on Add-DhHtmlBlock, Add-DhCollapsible, Add-DhAlertBanner and Add-DhTabs. Content is HTML-encoded and renders as literal text unless you pass -AllowHtml:$true. Announced by a runtime warning on every build since 1.5.x. The change is self-diagnosing: when the new default applies AND the content looks like markup, a warning names the exact call site; an explicit -AllowHtml (either value) silences it.

(2) Navigation rebuilt as ONE depth-agnostic tree. New -NavPath 'A/B/C' plus -NavScope Exact|Subtree|Global, -NavLabel and -NavOrder on all 15 nav-aware cmdlets. -NavGroup / -NavSubGroup are KEPT indefinitely and map onto the new model, so existing scripts need no edit. Combining the two APIs on one call is a hard error rather than silent precedence.

(3) FIXES silent content loss. A block declared with -NavGroup + -NavSubGroup was UNREACHABLE in 1.x: the hide path cleared both the inline display and the panel-active class while the show path restored only the style, and .block-section defaults to display:none. Verified in a browser - a chart in a non-first subgroup never appeared under any navigation sequence, with no console output. Dashboards that have quietly lost a chart since 1.9.x will start rendering it, so the page may look different.

(4) The runtime replaces showGroup/showSubPanel/showSubGroup/_showFlatPanel (~110 lines, two competing visibility mechanisms) with applyNav + navMatches. Visibility is derived from one rule, recomputed whole, idempotent and route-independent. The menu is built from the DOM's own data-navpath attributes, so a strip can never describe a view the content lacks.

(5) New layout engine: -NavLayout Auto|Strips|Sidebar and -NavMaxDepth 1-5. Auto keeps the 1.x strips look to 3 levels and switches to a sidebar rail plus breadcrumb at 4+, where stacked sticky strips would eat ~225px of a 1080p viewport. Auto-descend stops at the first node with content of its own. Exceeding -NavMaxDepth warns but still exports.

(6) New Update-DhScript cmdlet in DashHtml.Design: AST-based upgrade audit with an optional rewrite mode, classifying findings as ACTION / advisory / info, backing up before editing, and idempotent.

474 tests.
1.10.4 — Performance. Sorting a large table no longer freezes the browser. The sort comparator called String.localeCompare(x, undefined, {sensitivity:''base''}) on EVERY comparison (~270,000 times for a 19,011-row table); passing an options object makes the engine re-resolve collation settings per call, and parseFloat ran O(n log n) times instead of O(n). Measured on a real 19,011-row x 17-column permission audit: clicking a column header blocked the main thread for 5.6 SECONDS. Now 169 ms — about 33x faster. The fix precomputes each row''s sort keys once and reuses a single Intl.Collator. Sort ORDER is unchanged and proven so: 501 randomised cases (partially-numeric strings, case/accent insensitivity, booleans, nulls, sparkline reduction in all four sortBy modes, multi-field sorts with mixed directions, and an all-ties stability check) produce byte-identical ordering against the previous implementation — the spec defines localeCompare(y, loc, opts) as new Intl.Collator(loc, opts).compare(x, y), and Array#sort is stable. Filtering (~250 ms) is unaffected. 397 tests.

1.10.3 — Performance. Export-DhDashboard is dramatically faster on large tables: ConvertTo-DhJsonString now short-circuits its nine regex passes with a single IndexOfAny pre-check, since real table data is overwhelmingly plain text that needs no escaping. Measured 1.27 ms -> 0.014 ms per call (90x); a 20,400-cell report exports in 5.2 s instead of 79.7 s (15x), and marginal cost falls from ~2.9 ms to ~0.08 ms per cell (~40x) — a 338,000-cell report drops from ~16 min to ~30 s. Escaping behaviour is unchanged and byte-identical: the nine passes are untouched, only skipped when provably unnecessary. Their ORDER is load-bearing (CR is dropped, not escaped, so '<' CR '/script>' collapses into '</script>' mid-pass and is caught by the '</' rule) — this is now documented and pinned by tests so a future single-regex rewrite cannot reintroduce a script breakout. 392 tests. See CHANGELOG.md for older releases.

1.10.1 — Bug-fix patch (from an internal code review). SECURITY: table cells with CellType='progressbar' now HTML-encode their label value — previously a non-numeric value was injected via innerHTML, an XSS sink that contradicted the "table cells are auto-encoded" guarantee. Also: the duplicate-Id guard now covers Add-DhBarChart / Add-DhCollapsible / Add-DhFilterCard / Add-DhHtmlBlock / Add-DhPieChart (the other 11 block cmdlets already had it); and the table header "select all" checkbox now selects every row of a -Pageable:$false table instead of only the first page. No API changes. 379 tests.

1.10.0 — Opt-in 12-column grid layout. Blocks and tables accept -GridSpan (1-12); as soon as one is set, the report body becomes a 12-column CSS grid and each element spans the requested columns (unspanned elements stay full-width). Put two half-width charts side by side with -GridSpan 6, three-across with -GridSpan 4, etc. Collapses to a single column below 900px. Fully non-breaking: a dashboard with no -GridSpan is byte-identical to 1.9.0 (sequential flow). 372 tests.

1.9.0 — Global filters. New Add-DhGlobalFilter cmdlet adds a page-level control (a facet dropdown, or a from/to date range) to a filter bar above the report body. Changing it re-filters EVERY table that has the named field at once, and charts derived from those tables re-aggregate; tables without the field are unaffected. Multiple global filters combine with AND, and selections persist in the URL hash. Non-breaking — dashboards with no global filter are byte-unchanged. 365 tests.

1.8.0 — Internal refactor, no functional change. The ~3,400-line dashboard runtime JavaScript (previously one here-string in Get-DhJsContent.ps1) is now authored across five cohesive fragment files — Get-DhJsCore / Get-DhJsBlocks / Get-DhJsNav / Get-DhJsTable / Get-DhJsBoot — concatenated by Get-DhJsContent. The assembled output is byte-for-byte identical to 1.7.0 (verified); generated dashboards are unchanged. Purely a maintainability improvement. 355 tests.

1.7.0 — UX & performance. (1) Interactive topology maps: Add-DhTopologyMap now renders in a fixed viewport with drag-to-pan, wheel-zoom, a zoom/reset toolbar, and a +/- toggle on every parent node to collapse its subtree. Default on; pass -Interactive:$false for the pre-1.7.0 static view. (2) Accessibility: honours prefers-reduced-motion, adds aria-sort + keyboard operation to sortable table headers, an aria-live result-count region, and a focus ring on sortable headers. (3) Large tables: -Pageable:$false now renders ALL rows (previously it wrongly showed only the first page) and virtualises the DOM above 150 rows so "show all" stays fast. Also fixes Add-DhTabs throwing on a single tab. Non-breaking. 355 tests.

Full version history: https://github.com/nicola-vi/DashHtml/blob/main/CHANGELOG.md
'@
        }
    }
}


