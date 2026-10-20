@{
    # Module identity
    RootModule        = 'DashHtml.psm1'
    ModuleVersion     = '2.5.3'
    GUID              = '3f8e9a2c-1d4b-47f5-8c6e-0a5d2b9f3e71'
    Author            = 'Nicola Viganò'
    CompanyName       = 'Nicola Viganò'
    Copyright         = '(c) 2026 Nicola Viganò. MIT License.'
    Description       = 'Generate interactive self-contained HTML dashboards. Includes sortable / filterable / pageable tables, linked drill-down, client-side CSV / Excel / PDF export, KPI summary tiles (with optional sparklines, trend deltas, big-number, gauge, verdict, score-ring and maturity-ladder styles), assessment findings with severity, remediation, evidence and references (list or split layout), a detail side panel for table rows, grid cells and findings, property tiles, expandable record lists, pie / donut / line / area / bar / stacked-bar / bullet charts with value aggregation (sum / avg / min / max), min-avg-max range-gradient bars, RAG status matrix, sequential / diverging 2-D heatmaps, parent-child topology trees, network and dependency maps (grouped or in tier lanes, with path tracing), OU / folder tree filters, a report-wide search, menu severity badges, columns that fit their text, inline tabbed content blocks, chronological event feeds, dismissible alert banners, threshold cell colouring with a unified -Rag parameter, a sticky nav bar, print / PDF layout with an optional cover page, and offline-capable XLSX / PDF export. Six built-in theme families (Default, Azure, VMware, Grey, Company, Rag — the v1.4 family using the Office/Excel-compatible RAG palette) each with embedded light / dark variants and a runtime toggle button.'
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
        'Add-DhKeyValue'
        'Add-DhRecordList'
        'Add-DhTreeFilter'
        'Add-DhNetworkMap'
        'Add-DhTreeTable'
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
2.5.3 - Menu overflow after one row. A menu strip that does not fit on one row shows the chips that fit plus More (n) at the end of the row (2.5.0 to 2.5.2 waited for a second row), and the top strip stays on the title line instead of dropping onto its own line. -NavOverflow Wrap keeps the old wrapping. Fixes: badges are filled before the chips are measured, the fit settles against the real layout, the arrow keys reach the More button, the Top button no longer uses an inline onclick. Also: Export-DhYamlSchema -OutFile honours the PowerShell location, removed baseline rows are drawn on open, a number-vs-text baseline warning, -NavLayout Auto ignores Global item paths, module sources are LF. Regenerate reports to pick it up.

2.5.2 - Baseline markers, accessibility and quality tooling. (0) Add-DhTable -Baseline -KeyField marks rows New / Changed (on the table's columns) against the previous run (tag, old value on hover, counts, Change chips, collapsed Removed group, Change column in exports). (1) Collapsible headers work from the keyboard (button role, aria-expanded, Enter/Space); table filter, select-all and row checkboxes are named; multi-select rows announce aria-selected. (2) Cell state colours and secondary text meet 4.5:1 on striped and selected rows in every theme (small colour shifts in 10 of the 12 theme files). (3) Menu nodes with nothing to show are pruned (a -NavTree node never is). CSV exports guard against spreadsheet formulas. (4) New Tools\Test-DhContrast.ps1 and Tools\Test-DhA11y.ps1 (headless Edge/Chrome). (5) DashHtml.Design: Export-DhYamlSchema and dashhtml.schema.json, a JSON Schema of the layout YAML that rejects typos. (6) 31 node tests; forward-slash paths; CI matrix with Ubuntu.

2.5.1 - Print and contrast fixes, round-trip fixes, node tests. (1) Print: soft shadows no longer hide heatmap cells and block titles in a PDF, tables wider than the page wrap to fit (8 pt, tighter cells, header words kept whole). (2) Contrast: heatmap values pick dark or white text per cell (they were unreadable in dark mode), nav badges, tree-table type letters and tree flags use the primary text colour in all 12 themes. (3) ConvertTo-DhYaml now writes navLayout, navMaxDepth, navAllLabel, navTree, strictNav and navOverflow, and generated scripts keep ordered hashtables (tree-table Properties keep their order). (4) Footer averages of unformatted columns are rounded (Decimals, default 2). (5) Tests\js: dh-extract.js loads runtime functions for node --test; Build.ps1 reports the node test count.
2.5.0 - Directory explorer, richer menu, column picker. (1) New Add-DhTreeTable: an OU / group / user tree from two flat lists (Rows, Memberships) with a property panel (Properties, Members, Member of, Nesting) and circular-nesting detection. (2) Menu: New-DhDashboard -NavAllLabel adds an addressable All view to a group; -NavTree declares labels, order and empty nodes up front; -StrictNav lints the menu at export (warnings only); -NavOverflow More (default) moves chips that do not fit into a More menu, Wrap keeps the old wrapping; an empty view shows a note; arrow keys, Home/End, Escape and ARIA roles work in the menu. (3) Tables: column key Hidden starts a column unticked, Add-DhTable -RememberColumns keeps the reader's column choice in the browser, Default columns resets it, and the button shows how many are hidden. (4) Fixes: tables wider than the page no longer lose columns when printed; three CSS variables that no theme defined (--bg-base, --text3, --trans-med) now resolve, so nav strips, breadcrumb and global filter selects pick up their intended colours. (5) Tools\Test-DhPrint.ps1 prints dashboards to PDF through Edge/Chrome. Existing reports are unchanged unless they use a new parameter; regenerate them to pick up the fixes.

2.4.1 - Banners follow -NavPath/-NavScope, -NavOrder fix, Tools\Show-DhNavMap.ps1, new example set.
2.4.0 - Add-DhNetworkMap, Add-DhTreeFilter, report search (-Search), nav badges (-NavBadge), columns that fit their content.
2.3.0 - Add-DhKeyValue, Add-DhRecordList, table drawers, score/maturity tiles, split findings.
2.2.0 - Add-DhFindings, cell types chips and path, -AllClearText, coloured bars.
2.1.x - Add-DhRangeBar and a series of table and click-filter fixes.
2.0.0 - MAJOR: -AllowHtml defaults to $false, -NavPath/-NavScope navigation. See MIGRATION-v2.md.

Full version history: https://github.com/nicola-vi/DashHtml/blob/main/CHANGELOG.md
'@
        }
    }
}


