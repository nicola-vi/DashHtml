@{
    # Module identity
    RootModule        = 'DashHtml.psm1'
    ModuleVersion     = '3.1.0'
    GUID              = '3f8e9a2c-1d4b-47f5-8c6e-0a5d2b9f3e71'
    Author            = 'Nicola Viganò'
    CompanyName       = 'Nicola Viganò'
    Copyright         = '(c) 2026 Nicola Viganò. MIT License.'
    Description       = 'Generate interactive self-contained HTML dashboards. Includes sortable / filterable / pageable tables, linked drill-down, client-side CSV / Excel / PDF export, KPI summary tiles (with optional sparklines, trend deltas, big-number, gauge, verdict, score-ring and maturity-ladder styles), assessment findings with severity, remediation, evidence and references (list or split layout), a detail side panel for table rows, grid cells and findings, property tiles, expandable record lists, pie / donut / line / area / bar / stacked-bar / bullet charts with value aggregation (sum / avg / min / max), min-avg-max range-gradient bars, RAG status matrix, sequential / diverging 2-D heatmaps, parent-child topology trees, network and dependency maps (grouped or in tier lanes, with path tracing), OU / folder tree filters, a report-wide search, menu severity badges, columns that fit their text, inline tabbed content blocks, chronological event feeds, dismissible alert banners, threshold cell colouring with a unified -Rag parameter, a sticky nav bar, print / PDF layout with an optional cover page, and offline-capable XLSX / PDF export. Six built-in theme families (Default, Azure, VMware, Grey, Company, Rag — the v1.4 family using the Office/Excel-compatible RAG palette) each with embedded light / dark variants and a runtime toggle button.'
    PowerShellVersion = '7.4'

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
        'Add-DhGantt'
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
3.1.0 - Gantt timelines. New Add-DhGantt: start/end bars on a time axis from seconds to years (clock, dates, months, quarters, years, or elapsed time), lanes, rows shared by several bars with overlaps packed into sub-lines, status or category colours, milestones, critical path, marker lines (a target, today) and shaded windows (a backup window, a change freeze), the detail side panel, and a data table for print and screen readers. From a list of items, or one bar per row of a table that follows the table filter. Times become seconds from an origin in PowerShell, so the browser never parses a date and the reader's time zone cannot move a bar. New example: Feature-Gantt.ps1 (a recovery test, nightly backups, certificate validity). No change to existing reports apart from the runtime.
3.0.0 - MAJOR. Breaking: (1) -NavGroup / -NavSubGroup are removed from every cmdlet (the 1.x compat shim): run Update-DhScript -Apply (DashHtml.Design), which rewrites them to -NavPath / -NavScope with the same menu, and lists any value that is not a literal for a human. (2) PowerShell 7.4 or later. (3) The 2.0 "content looks like HTML and is being encoded" warning is gone (the -AllowHtml $false default stays). (4) Add-DhBullet no longer accepts the 1.x 'Bands' key: use Thresholds (same shape) or Rag. (5) Tools\Test-DhV2Upgrade.ps1 is removed (Test-DhReport and Update-DhScript replace it). New: New-DhDashboard -PrimaryColor / -SecondaryColor / -AccentColor / -FontFamily / -FontFile brand any theme in light and dark (contrast-safe shades for text, warnings below WCAG, status colours never change, the font embedded for offline use); Add-DhTable -RememberViews saves named views (columns, sort, page size, filter) per reader; Tools\Test-DhPrint.ps1 -Png renders every printed page with a vendored pdf.js and writes review.html. Look: the header is a 120-degree gradient in every theme (text at 4.5:1 on both ends); Azure follows the Microsoft roles (Azure Blue accent, Dark Blue header, Light Blue line) and VMware follows VMware by Broadcom (teal-blue #015C89 instead of green, Broadcom Red only as the header line, never a status colour); brand reports get the gradient too; no empty box without -LogoPath; the Generated timestamp uses the header font and New-DhDashboard -HideGeneratedAt removes it. Better: every report is about 150 KB smaller (the structural CSS is embedded once), large tree tables build and export about twice as fast (byte-identical output), a network map prints at its own proportions, line-chart y labels are no longer clipped, status text in badge cells clears 4.5:1 on striped rows in every dark theme (seven tokens lightened), and the browser audits no longer leave headless Edge processes running.
2.7.0 - Readability and the header band. A presentation-layer release: no cmdlet behaviour or data changes, but every report looks different - regenerate to pick it up. (1) Every theme now has a coloured header band in light AND dark mode, using the theme's own accent-secondary (Default #005F8A, Azure #106EBE, Grey #37474F, VMware #007D63, Company #8C0031, Rag #404040); dark mode uses a deep tint of the same hue. Before 2.7.0 three families had a white band, and in dark mode all six were near-black within 1.1 contrast of the page - in Grey and Azure, exactly the page colour, so the band was invisible. (2) --text-muted failed WCAG AA in all twelve theme variants (2.38:1 to 4.41:1 against a 4.5 requirement) while carrying the smallest text in the report; every variant now clears 4.5:1 against every background it can land on, including row stripes, table heads and the 8% overlay behind key-value items. --nav-title-fg failed in 11 of 12 and is fixed too. (3) The type floor was 9.6px: 30 hardcoded sizes bypassed the scale. Nothing in the HTML is below 11.5px now (--size-2xs). Network-map SVG labels are the documented exception - their geometry is computed from hardcoded character widths. (4) Block titles are sentence case: text-transform uppercase went from 38 rules to 8, and 10 ad-hoc letter-spacing values became three tokens. (5) New-DhDashboard -Density Normal|Compact|Comfortable sets the opening density; it now scales the whole type scale, not only table rows. Compact is closest to the old look. (6) No report fetches a font any more - Company and VMware pulled Montserrat and Inter from Google Fonts with an @import, which broke the single-file promise and failed silently offline. Both still name their font first, so readers who have it installed see it.

2.6.0 - Checks, size and links. (1) Test-DhReport (DashHtml.Design): one command for the lints - links, menu, size, baseline sanity for a report object; the upgrade audit for a script; the schema (naming the failing table or key) for a layout; for an HTML file, the fixes an older runtime misses. -Strict for CI. (2) Export-DhDashboard -CompressData stores the data gzip + base64 (a 50,000-row table: 9.2 MB to 1.3 MB) and -SizeBudgetMB (default 15) warns about a big file. (3) New-DhDashboard -LinkState keeps each table's sort, page, page size and Change chip in the address. (4) Add-DhTable -BaselinePath reads the previous rows from .clixml, .csv or .json. (5) Link columns: UrlTemplate ('page.html?id={Id}'), RelativeLinks, LinkTarget new | same, tel: links, links in the detail drawer. (6) Tree tables: windowed above 2,000 rows (50,000 objects stay quick), CSV of the visible rows and of member lists; -MaxRows warns at 20,000 and throws at 100,000. All new behaviour is opt-in; regenerate reports to pick up the runtime.

2.5.x - Baseline markers (-Baseline -KeyField), accessibility and contrast fixes in all themes, CSV formula guard, Tools\Test-DhContrast and Test-DhA11y, Export-DhYamlSchema, Add-DhTreeTable, -NavAllLabel / -NavTree / -StrictNav / -NavOverflow (More after one row), column picker memory, print fixes, data fields named Keys / Values / Count kept.
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


