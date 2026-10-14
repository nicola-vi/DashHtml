@{
    # Module identity
    RootModule        = 'DashHtml.psm1'
    ModuleVersion     = '2.2.0'
    GUID              = '3f8e9a2c-1d4b-47f5-8c6e-0a5d2b9f3e71'
    Author            = 'Nicola Viganò'
    CompanyName       = 'Nicola Viganò'
    Copyright         = '(c) 2026 Nicola Viganò. MIT License.'
    Description       = 'Generate interactive self-contained HTML dashboards. Includes sortable / filterable / pageable tables, linked drill-down, client-side CSV / Excel / PDF export, KPI summary tiles (with optional sparklines, trend deltas, big-number, gauge and verdict styles), assessment findings with severity, remediation and references, pie / donut / line / area / bar / stacked-bar / bullet charts with value aggregation (sum / avg / min / max), min-avg-max range-gradient bars, RAG status matrix, sequential / diverging 2-D heatmaps, parent-child topology trees, inline tabbed content blocks, chronological event feeds, dismissible alert banners, threshold cell colouring with a unified -Rag parameter, a sticky nav bar, print / PDF layout with an optional cover page, and offline-capable XLSX / PDF export. Six built-in theme families (Default, Azure, VMware, Grey, Company, Rag — the v1.4 family using the Office/Excel-compatible RAG palette) each with embedded light / dark variants and a runtime toggle button.'
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
        'Add-DhFindings'
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
2.2.0 - Assessment features. No breaking changes. (1) New Add-DhFindings: one expandable row per finding with severity, description, recommendation, affected objects, a 'Show in table' jump to the evidence and reference links; severity chips and a text box filter the list. Severities critical/warning/info/ok, with high/medium/low accepted as aliases. (2) Add-DhSummary Style='verdict': a full-width overall assessment with severity chips. (3) Add-DhBarChart -ValueField -Aggregate sum|avg|min|max -Unit -Decimals: bars that measure a value instead of counting rows; table -Charts render Type='bar' with the same options. (4) CellType='link' with UrlField / LinkText; only http(s) and mailto become links. (5) New-DhDashboard -ThemeMode Light|Dark|Auto. (6) Export-DhDashboard -ExportLibraries Cdn|Embed|None: the XLSX/PDF libraries no longer block page load. Cdn loads them on first click (SRI-pinned, buttons grey out offline instead of an alert); Embed inlines verified vendored copies for air-gapped readers; None hides the buttons. (7) Print button and print layout: every view in menu order, everything expanded, tables unpaged up to -PrintMaxRows, optional -PrintCover; headless --print-to-pdf gets the same layout. Fixed: grid reports widened the page on phones. Requires regeneration of existing reports to pick up the runtime changes.
2.1.4 - Fixes only, no new parameters. Regenerate existing dashboards: the runtime is baked into each HTML file. (1) Collapsible tables can be opened again: since 2.0.0 the runtime bound a CSS class the table markup never emits, so -DefaultOpen:$false tables stayed closed for good. (2) Table -Charts: a chart with no Type still draws a donut, but Type='pie' now draws a solid pie (it drew a donut before); 'bar' (rendered from 2.2.0) and unknown types warn and are skipped instead of vanishing silently. (3) Alert actions, tile actions, status-grid cells and topology nodes now jump to their table through one function that filters via applyTextFilter, so the clear button appears and linked charts refresh; a folded table is unfolded. (4) The theme choice persists (URL hash, then localStorage) and is applied before first paint; the toggle reads Dark/Light instead of the internal theme name. (5) Density toggle stays in sync after a reload. (6) CSV export honours -ExportFileName; copy-to-clipboard falls back when navigator.clipboard is unavailable. (7) Export-DhDashboard warns about every TableId / LinkTableId / Action.TableId that names a missing table and every unknown block type - each was a silent no-op in the browser. (8) esc() also encodes the single quote; row rendering no longer does a linear indexOf per row. Node test now drives the shipped nav matcher and table toggle.

2.1.3 - Add-DhBarChart -ClickFilters never worked (an inline onclick could not see the runtime's engines); a bar label containing a double quote could inject HTML attributes; pie-slice clicks left the clear button hidden and linked charts stale; the table toolbar markup was malformed on every report. All text filtering now goes through one TableEngine.applyTextFilter. Clickable bars are keyboard-operable.

2.1.2 - A column could not be dragged narrower than its own header; headers now clip with an ellipsis and carry the full text as a tooltip.

2.1.1 - Clipped table cells carry their full value as a tooltip; columns are resizable by dragging the header edge; a declared column Width beats the stylesheet cap. -Collapsible / -DefaultOpen now work on bar and pie charts. Example scripts renamed to Demo-<Domain> / Demo-Feature-<X>; new Demo-Feature-AllChartTypes.ps1.

2.1.0 - New Add-DhRangeBar: min-avg-max range bars normalised onto a shared 0-100 axis, with a theme-following gradient, from explicit -Items or derived live from a table. New companion module DashHtml.Design (YAML layout round-trip, Update-DhScript). Build.ps1 and Install.ps1 handle both modules.

2.0.0 - MAJOR RELEASE. See MIGRATION-v2.md. (1) BREAKING: -AllowHtml defaults to $false on Add-DhHtmlBlock, Add-DhCollapsible, Add-DhAlertBanner and Add-DhTabs; a warning names any call whose content looks like markup. (2) Navigation rebuilt as one depth-agnostic tree: -NavPath 'A/B/C' with -NavScope Exact|Subtree|Global, -NavLabel and -NavOrder; -NavGroup / -NavSubGroup kept and mapped onto it. (3) Fixes blocks declared with -NavGroup + -NavSubGroup that were unreachable in 1.x. (4) Layout engine: -NavLayout Auto|Strips|Sidebar and -NavMaxDepth 1-5, breadcrumb at depth 4+.

Full version history: https://github.com/nicola-vi/DashHtml/blob/main/CHANGELOG.md
'@
        }
    }
}


