#Requires -Version 7.0
<#
.SYNOPSIS
    Finding things: global filters, filter cards, click filters, report search and menu badges.

.DESCRIPTION
    MENU
        Global filters               a dropdown and a date range above the page; every table follows
        Filter cards                 click a card to filter one table (single and multi-select)
        Click to filter              bars and pies that filter the table below them
        Search and badges            press / to search the whole report; menu items show findings

    WHAT THE FILTERS TOUCH
        * A global filter (Add-DhGlobalFilter) is not tied to a view: it always sits above the page
          and narrows EVERY table that has that field (and the charts that read those tables), on
          every view. Open two different views and watch the same selection apply to both.
        * A filter card, a bar, a pie or a linked table touches ONE table. Put it on the same view
          as that table, or the click filters something you cannot see.
        * Search (New-DhDashboard -Search) looks at menu pages, titles, findings and table rows,
          with a hit count per table. Opening a table hit filters that table.
        * -NavBadge puts the worst finding severity on each menu item.

.PARAMETER OutputPath
    Where to write the HTML.

.PARAMETER Theme
    Default, Azure, VMware, Grey, Company or Rag.

.PARAMETER OpenInBrowser
    Open the dashboard once generated.

.EXAMPLE
    PS> ./Examples/Feature-FiltersAndSearch.ps1 -OpenInBrowser
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Feature-FiltersAndSearch.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Default',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force

$rng = [System.Random]::new(33)
$note = { param([string] $Id, [string] $Path, [string] $Text) Add-DhHtmlBlock -Report $report -Id $Id -Title 'In this view' -Style info -NavPath $Path -Content $Text }

$regions = 'North', 'South', 'East', 'West'
$tickets = foreach ($i in 1..80) {
    [pscustomobject]@{
        Id = 'T-{0:0000}' -f (1000 + $i); Region = $regions[$i % 4]; Team = @('Network', 'Identity', 'Cloud')[$i % 3]
        Priority = @('P1', 'P2', 'P3', 'P3', 'P4')[$i % 5]; Status = @('Open', 'Open', 'In progress', 'Closed')[$i % 4]
        Opened = (Get-Date '2026-10-17').AddDays(-1 * $rng.Next(0, 60)).ToString('yyyy-MM-dd')
        Title = @('VPN drops', 'Account locked', 'Slow VM', 'Certificate expiring', 'Backup failed', 'Password reset')[$i % 6]
    }
}
$assets = foreach ($i in 1..40) {
    [pscustomobject]@{ Asset = 'asset-{0:000}' -f $i; Region = $regions[$i % 4]; Type = @('Server', 'Switch', 'Firewall')[$i % 3]; Age = 1 + $i % 7 }
}

$report = New-DhDashboard -Title 'Filters and search' -Subtitle 'Global filters, cards, click filters, search and badges' `
    -Theme $Theme -NavTitle 'Filters' -NavMaxDepth 2 -Search -NavBadge -GeneratedBy 'Feature-FiltersAndSearch.ps1'

# GLOBAL filters: above everything, on every view
Add-DhGlobalFilter -Report $report -Field 'Region' -Label 'Region'
Add-DhGlobalFilter -Report $report -Field 'Opened' -Label 'Opened' -Type daterange

# Tables first (charts and cards that read them are declared after)
Add-DhTable -Report $report -TableId 'tickets' -Title 'Tickets' -NavPath 'Global filters' -PageSize 8 -Data $tickets -Columns @(
    @{ Field = 'Id'; Label = 'Ticket' }, @{ Field = 'Region'; Label = 'Region' }, @{ Field = 'Team'; Label = 'Team' }
    @{ Field = 'Priority'; Label = 'Priority'; CellType = 'badge'; Thresholds = @(@{ Value = 'P1'; Class = 'cell-danger' }, @{ Value = 'P2'; Class = 'cell-warn' }, @{ Value = 'P3'; Class = 'cell-ok' }, @{ Value = 'P4'; Class = 'cell-nodata' }) }
    @{ Field = 'Status'; Label = 'Status' }, @{ Field = 'Opened'; Label = 'Opened' }, @{ Field = 'Title'; Label = 'Title' } )
Add-DhTable -Report $report -TableId 'assets' -Title 'Assets' -NavPath 'Global filters/Second table' -NavLabel 'Second table' -PageSize 8 -Data $assets -Columns @(
    @{ Field = 'Asset'; Label = 'Asset' }, @{ Field = 'Region'; Label = 'Region' }, @{ Field = 'Type'; Label = 'Type' }, @{ Field = 'Age'; Label = 'Age (years)'; Align = 'right' } )

# ============================================================== GLOBAL FILTERS
& $note 'n-global' 'Global filters' 'The two controls above the page are global: pick a region and both this ticket table and the asset table (next view) narrow, as do the charts that read them. The date range filters the tickets only, because only they have an Opened column.'

& $note 'n-global2' 'Global filters/Second table' 'The same Region selection applies here. Nothing on this view declares the filter; it is global.'

# ============================================================== FILTER CARDS
Add-DhTable -Report $report -TableId 'cards-tickets' -Title 'Tickets' -NavPath 'Filter cards' -PageSize 6 -Data $tickets -Columns @(
    @{ Field = 'Id'; Label = 'Ticket' }, @{ Field = 'Region'; Label = 'Region' }, @{ Field = 'Team'; Label = 'Team' }, @{ Field = 'Priority'; Label = 'Priority' }, @{ Field = 'Status'; Label = 'Status' }, @{ Field = 'Title'; Label = 'Title' } )
& $note 'n-cards' 'Filter cards' 'A card grid filters ONE table (the one named by -TargetTableId, here the table below). Single select by default; -MultiFilter lets you pick several values. Both card grids and the table sit on this one view.'
Add-DhFilterCard -Report $report -Id 'cards-status' -Title 'Status (single select)' -NavPath 'Filter cards' -TargetTableId 'cards-tickets' -FilterField 'Status' -Cards @(
    foreach ($g in ($tickets | Group-Object Status | Sort-Object Count -Descending)) { @{ Label = $g.Name; Value = $g.Name; Count = $g.Count } } )
Add-DhFilterCard -Report $report -Id 'cards-team' -Title 'Team (multi select)' -NavPath 'Filter cards' -TargetTableId 'cards-tickets' -FilterField 'Team' -MultiFilter $true -Cards @(
    foreach ($g in ($tickets | Group-Object Team)) { @{ Label = $g.Name; Value = $g.Name; Count = $g.Count } } )

# ============================================================== CLICK TO FILTER
Add-DhTable -Report $report -TableId 'click-tickets' -Title 'Tickets' -NavPath 'Click to filter' -PageSize 6 -Data $tickets -Columns @(
    @{ Field = 'Id'; Label = 'Ticket' }, @{ Field = 'Region'; Label = 'Region' }, @{ Field = 'Priority'; Label = 'Priority' }, @{ Field = 'Team'; Label = 'Team' }, @{ Field = 'Status'; Label = 'Status' } )
& $note 'n-click' 'Click to filter' 'Click a bar or a slice and the table below filters to it; click again to clear. The chart and the table must be on the same view, as they are here.'
Add-DhBarChart -Report $report -Id 'click-bar' -Title 'Tickets per priority' -NavPath 'Click to filter' -TableId 'click-tickets' -Field 'Priority' -ClickFilters `
    -KeyClass @{ P1 = 'cell-danger'; P2 = 'cell-warn'; P3 = 'cell-ok'; P4 = 'cell-nodata' }
Add-DhPieChart -Report $report -Id 'click-pie' -Title 'Tickets per team' -NavPath 'Click to filter' -TableId 'click-tickets' -Field 'Team' -Style donut -ClickFilters

# ============================================================== SEARCH AND BADGES
& $note 'n-search' 'Search and badges' 'Press / (or click the box in the menu bar) and type two or more letters: try "vpn", "T-1010" or "stale". Results group into Pages, Findings and Tables (with a hit count). The red and amber pills on the menu show the worst finding at or below that item.'
Add-DhFindings -Report $report -Id 'search-findings' -Title 'Findings (they feed the menu badges)' -NavPath 'Search and badges' -Findings @(
    @{ Id = 'F-1'; Severity = 'critical'; Area = 'Network'; Title = 'VPN concentrator has a stale certificate'; Description = 'Expired two days ago.'; Recommendation = 'Renew and deploy.' }
    @{ Id = 'F-2'; Severity = 'warning'; Area = 'Identity'; Title = 'Stale privileged accounts'; Description = 'Three accounts have not signed in for 180 days.'; Recommendation = 'Disable them.' }
    @{ Id = 'F-3'; Severity = 'info'; Area = 'Cloud'; Title = 'Backup retention is 14 days'; Recommendation = 'Consider 30 days.' } )

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
