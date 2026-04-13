@{
    # Module identity
    RootModule        = 'DashHtml.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '3f8e9a2c-1d4b-47f5-8c6e-0a5d2b9f3e71'
    Author            = 'DashHtml Contributors'
    CompanyName       = 'DashHtml Contributors'
    Copyright         = '(c) 2026 DashHtml Contributors. MIT License.'
    Description       = 'Generate interactive self-contained HTML dashboards with sort, filter, paging, linked drill-down, client-side CSV/Excel/PDF export, pie charts, progress bars, threshold cell colouring, and a nav bar. Five built-in theme families (Default, Azure, VMware, Grey, Company) each with embedded light/dark variants and a runtime toggle button.'
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
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Gallery metadata
    PrivateData = @{
        PSData = @{
            Tags         = @('HTML','Dashboard','Table','Export','CSV','Excel','PDF','Report','Infrastructure')
            LicenseUri   = 'https://github.com/DashHtml/DashHtml/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/DashHtml/DashHtml'
            ReleaseNotes = '1.0.0 — Initial release. Sortable/filterable/pageable tables, KPI tiles, bar charts, clickable filter cards, collapsible sections, master-detail table linking, two-tier navigation, pie charts, progress bars, badge cells, threshold colouring, row highlighting, footer aggregates, number/currency/bytes/percent/datetime/duration formatting, client-side CSV/XLSX/PDF export, five theme families (Default/Azure/VMware/Grey/Company) each with embedded light+dark variants and a runtime toggle.'
        }
    }
}
