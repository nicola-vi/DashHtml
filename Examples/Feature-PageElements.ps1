#Requires -Version 7.0
<#
.SYNOPSIS
    The building blocks of a page: header, banners, notes, collapsibles, tabs, events, grid layout, print.

.DESCRIPTION
    MENU
        Header and banners           info fields, banners of every severity, collapsible banners
        Text blocks                  five styles of note, collapsible cards and free content
        Tabs                         several views of one block (not the same as the menu)
        Events                       a chronological log, grouped by severity
        Grid layout                  place blocks side by side on a 12-column grid
        Print                        what the Print button produces

    A banner with a menu path follows the menu: this page has one global banner (on every view),
    one scoped to the Tabs view, and one for the whole Events branch.

    TABS vs MENU: the menu is page navigation and is part of the URL; tabs switch the content of
    ONE block and are local to it. Use the menu for sections, tabs for alternative views of the
    same thing.

.PARAMETER OutputPath
    Where to write the HTML.

.PARAMETER Theme
    Default, Azure, VMware, Grey, Company or Rag.

.PARAMETER OpenInBrowser
    Open the dashboard once generated.

.EXAMPLE
    PS> ./Examples/Feature-PageElements.ps1 -OpenInBrowser
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Feature-PageElements.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Default',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force

$note = { param([string] $Id, [string] $Path, [string] $Text) Add-DhHtmlBlock -Report $report -Id $Id -Title 'In this view' -Style info -NavPath $Path -Content $Text -AllowHtml:$false }
$report = New-DhDashboard -Title 'Page elements' -Subtitle 'Header, banners, notes, tabs, events, grid and print' -Theme $Theme -NavTitle 'Page' -NavMaxDepth 2 `
    -GeneratedBy 'Feature-PageElements.ps1' -PrintCover -InfoFields @(
        @{ Label = 'Organisation'; Value = 'Contoso' }, @{ Label = 'Environment'; Value = 'Production' }
        @{ Label = 'Owner'; Value = 'Platform team' }, @{ Label = 'Generated'; Value = (Get-Date -Format 'yyyy-MM-dd HH:mm') } )

# GLOBAL banner
Add-DhAlertBanner -Report $report -Id 'global-info' -Severity info -Icon 'i' -Dismissible -Message 'This banner has no path, so it is on every view. Dismiss it with the cross; the choice survives a reload.'

# ============================================================== HEADER AND BANNERS
& $note 'n-banners' 'Header and banners' 'The header shows the title, subtitle and the info fields given to New-DhDashboard. Banners carry a severity, an optional action button (it jumps to a table and filters it) and can be dismissible or collapsible.'
Add-DhAlertBanner -Report $report -Id 'b-ok' -Severity ok -Icon 'OK' -NavPath 'Header and banners' -Message 'Backups completed for all 247 machines.'
Add-DhAlertBanner -Report $report -Id 'b-warn' -Severity warning -Icon '!' -NavPath 'Header and banners' -Dismissible -Message 'Three certificates expire within 30 days.' -Action @{ Label = 'Show them'; TableId = 'certs'; Filter = 'Expiring' }
Add-DhAlertBanner -Report $report -Id 'b-crit' -Severity critical -Icon '!' -NavPath 'Header and banners' -Message 'The payment gateway has been down for ten minutes.'
Add-DhAlertBanner -Report $report -Id 'b-coll' -Severity info -Icon 'i' -NavPath 'Header and banners' -Collapsible $true -DefaultOpen $false -Title 'Collapsed banner (click to open)' -Message 'Longer explanations can sit inside a collapsed banner.'
Add-DhTable -Report $report -TableId 'certs' -Title 'Certificates' -NavPath 'Header and banners' -Data @(
    [pscustomobject]@{ Name = 'vpn.contoso.com'; State = 'Expiring'; Days = 12 }, [pscustomobject]@{ Name = 'mail.contoso.com'; State = 'Expiring'; Days = 21 }
    [pscustomobject]@{ Name = 'www.contoso.com'; State = 'OK'; Days = 211 }, [pscustomobject]@{ Name = 'api.contoso.com'; State = 'Expiring'; Days = 28 } ) -Columns @(
        @{ Field = 'Name'; Label = 'Certificate' }, @{ Field = 'State'; Label = 'State'; CellType = 'badge'; Thresholds = @(@{ Value = 'OK'; Class = 'cell-ok' }, @{ Value = 'Expiring'; Class = 'cell-warn' }) }
        @{ Field = 'Days'; Label = 'Days left'; Align = 'right' } )

# ============================================================== TEXT BLOCKS
& $note 'n-text' 'Text blocks' 'Add-DhHtmlBlock has five styles: info, ok, warn, danger and neutral. Text is encoded unless you pass -AllowHtml and trust the source. Add-DhCollapsible folds cards or free content.'
Add-DhHtmlBlock -Report $report -Id 't-ok' -Style ok -NavPath 'Text blocks' -Title 'ok' -Content 'Everything is working as expected.'
Add-DhHtmlBlock -Report $report -Id 't-warn' -Style warn -NavPath 'Text blocks' -Title 'warn' -Content 'Something needs attention soon.'
Add-DhHtmlBlock -Report $report -Id 't-danger' -Style danger -NavPath 'Text blocks' -Title 'danger' -Content 'Act now.'
Add-DhHtmlBlock -Report $report -Id 't-neutral' -Style neutral -NavPath 'Text blocks' -Title 'neutral' -Content 'A plain remark with no colour.'
Add-DhCollapsible -Report $report -Id 'c-cards' -Title 'Teams at a glance' -NavPath 'Text blocks' -DefaultOpen $true -Cards @(
    foreach ($t in @(@('Platform', 12, 'ok'), @('Security', 7, 'warn'), @('Data', 9, 'ok'))) {
        @{ Title = $t[0]; Badge = "$($t[1]) people"; Fields = @(@{ Label = 'On call'; Value = 'Yes' }, @{ Label = 'Status'; Value = $t[2]; Class = "cell-$($t[2])" }) }
    } )
Add-DhCollapsible -Report $report -Id 'c-free' -Title 'Free content (folded by default)' -NavPath 'Text blocks' -DefaultOpen $false -Content 'Any explanation, runbook link or legend can sit here, out of the way until someone opens it.'

# ============================================================== TABS
Add-DhAlertBanner -Report $report -Id 'tabs-banner' -Severity warning -Icon '!' -NavPath 'Tabs' -Message 'This banner is bound to the Tabs view only (-NavPath Tabs).'
& $note 'n-tabs' 'Tabs' 'Tabs switch the content of one block. The menu navigates the page; tabs do not change the address.'
Add-DhTabs -Report $report -Id 'tabs' -Title 'One service, three views' -NavPath 'Tabs' -AllowHtml:$false -Tabs @(
    @{ Title = 'Overview'; Active = $true; Content = 'The service has run for 214 days without an unplanned outage. Last release: 2026-10-02.' }
    @{ Title = 'Dependencies'; Content = 'Depends on the identity provider, the message bus and the primary database.' }
    @{ Title = 'Runbook'; Content = '1. Check the health endpoint. 2. Check the queue depth. 3. Restart the worker pool.' } )

# ============================================================== EVENTS
Add-DhAlertBanner -Report $report -Id 'events-banner' -Severity info -Icon 'i' -NavPath 'Events' -NavScope Subtree -Message 'Subtree banner: shown on Events and every view below it.'
$events = @(
    @{ Timestamp = '2026-10-17 14:32'; Severity = 'critical'; Source = 'Payments'; Message = 'Gateway timeouts above 5%' }
    @{ Timestamp = '2026-10-17 14:18'; Severity = 'warning'; Source = 'Search'; Message = 'Index lag above 60 seconds' }
    @{ Timestamp = '2026-10-17 12:42'; Severity = 'ok'; Source = 'Backup'; Message = 'Nightly backup completed in 38 minutes' }
    @{ Timestamp = '2026-10-17 10:05'; Severity = 'info'; Source = 'Deploy'; Message = 'Release 4.12 rolled out to 3 regions' }
    @{ Timestamp = '2026-10-17 09:30'; Severity = 'warning'; Source = 'Auth'; Message = 'Failed sign-ins rose to 1,200 per minute' } )
& $note 'n-events' 'Events' 'A chronological, severity-tagged log. -GroupBy Severity (or Source) groups it; the default is newest first. Events are plain text: nothing in them is interpreted as HTML.'
Add-DhEventFeed -Report $report -Id 'feed-grouped' -Title 'Events, grouped by severity' -NavPath 'Events' -GroupBy Severity -Events $events
Add-DhEventFeed -Report $report -Id 'feed-time' -Title 'Events, newest first' -NavPath 'Events' -Events $events

# ============================================================== GRID LAYOUT
& $note 'n-grid' 'Grid layout' 'By default blocks stack. Give any block or table -GridSpan (1 to 12 columns) and the page becomes a 12-column grid: here three charts share a row (4 + 4 + 4) and a table spans the full width. On a phone the columns stack again.'
$rows = foreach ($i in 1..30) { [pscustomobject]@{ Name = 's{0:00}' -f $i; Tier = @('Gold', 'Silver', 'Bronze')[$i % 3]; Region = @('EU', 'US')[$i % 2]; State = @('Up', 'Up', 'Down')[$i % 3] } }
Add-DhTable -Report $report -TableId 'grid-src' -Title 'Servers' -NavPath 'Grid layout' -GridSpan 12 -PageSize 6 -Data $rows -Columns @(
    @{ Field = 'Name'; Label = 'Server' }, @{ Field = 'Tier'; Label = 'Tier' }, @{ Field = 'Region'; Label = 'Region' }, @{ Field = 'State'; Label = 'State' } )
Add-DhBarChart -Report $report -Id 'g1' -Title 'By tier' -NavPath 'Grid layout' -GridSpan 4 -TableId 'grid-src' -Field 'Tier'
Add-DhPieChart -Report $report -Id 'g2' -Title 'By region' -NavPath 'Grid layout' -GridSpan 4 -TableId 'grid-src' -Field 'Region' -Style donut
Add-DhPieChart -Report $report -Id 'g3' -Title 'By state' -NavPath 'Grid layout' -GridSpan 4 -TableId 'grid-src' -Field 'State' -Style pie

# ============================================================== PRINT
& $note 'n-print' 'Print' 'Press the Print button (or Ctrl+P). Printed output shows every section in menu order, every finding and record open, tables unpaged (up to a limit), banners and tabs flattened, and a cover page with the title, info fields and the first verdict because this report was created with -PrintCover. The menu, search, side panel and buttons do not print.'
Add-DhSummary -Report $report -NavPath 'Print' -Items @(
    @{ Style = 'verdict'; Label = 'Overall'; Value = 'Healthy'; Caption = 'The first verdict tile is copied onto the cover page.'; Counts = @{ warning = 1; info = 2 } } )

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
