#Requires -Version 7.0
<#
.SYNOPSIS
    A deep menu (four levels) with the sidebar layout and a breadcrumb.

.DESCRIPTION
    Depth is a policy, not a limit: the menu works at any depth. What changes with depth is the
    presentation. Three or four stacked strips cost about a fifth of a laptop screen, so with
    -NavLayout Auto (the default) the menu becomes a left rail at four levels or more, and a
    breadcrumb shows where you are.

    Things to try:
      * Click EMEA: the page opens the first view that has content of its own, not the deepest
        leaf, so one click never drops you four levels down.
      * The rail opens only the branch you are on; a fully expanded deep tree is unreadable.
      * Mixed depth is fine: Incidents is one level deep, Firewall rules is four.
      * A Subtree block (the "Edge status" chart) shows at every level under EMEA / Edge.
      * Pass -Layout Strips to force the horizontal strips and see why the rail exists.

    Page order inside a view is fixed: banners, global filters, global KPI tiles, blocks in
    declaration order, tables in declaration order.

.PARAMETER OutputPath
    Where to write the HTML.

.PARAMETER Layout
    Auto (default), Strips or Sidebar.

.PARAMETER Theme
    Default, Azure, VMware, Grey, Company or Rag.

.PARAMETER OpenInBrowser
    Open the dashboard once generated.

.EXAMPLE
    PS> ./Examples/Feature-NavigationSidebar.ps1 -OpenInBrowser
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Feature-NavigationSidebar.html'),
    [ValidateSet('Auto', 'Strips', 'Sidebar')]
    [string] $Layout = 'Auto',
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Azure',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force

function New-Rows {
    param([string] $Prefix, [int] $Count = 12)
    foreach ($i in 1..$Count) {
        [pscustomobject]@{ Name = '{0}-{1:00}' -f $Prefix, $i; Status = @('OK', 'Warning', 'Critical')[$i % 3]; LatencyMs = 5 + ($i * 11) % 90; Region = @('eu-west', 'us-east')[$i % 2] }
    }
}
$cols = @(
    @{ Field = 'Name'; Label = 'Name' }
    @{ Field = 'Status'; Label = 'Status'; CellType = 'badge'; Thresholds = @(@{ Value = 'OK'; Class = 'cell-ok' }, @{ Value = 'Warning'; Class = 'cell-warn' }, @{ Value = 'Critical'; Class = 'cell-danger' }) }
    @{ Field = 'LatencyMs'; Label = 'Latency (ms)'; Align = 'right'; Rag = @{ Green = @{ Max = 30 }; Amber = @{ Min = 30; Max = 60 }; Red = @{ Min = 60 } } }
    @{ Field = 'Region'; Label = 'Region' } )

# -NavMaxDepth 4 raises the policy cap; without it the export still works but warns.
$report = New-DhDashboard -Title 'Global network' -Subtitle 'Four-level navigation' -Theme $Theme `
    -NavTitle 'NetOps' -NavMaxDepth 4 -NavLayout $Layout -GeneratedBy 'Feature-NavigationSidebar.ps1'

# Global: on every view at any depth
Add-DhSummary -Report $report -Items @(
    @{ Label = 'Sites'; Value = 4 }, @{ Label = 'Devices'; Value = 96 }
    @{ Label = 'Incidents'; Value = 3; Rag = @{ Green = @{ Max = 1 }; Red = @{ Min = 3 } } } )

# EMEA / Edge / Firewall: four levels
Add-DhTable -Report $report -TableId 'emea-rules' -Title 'Firewall rules' -NavPath 'EMEA/Edge/Firewall/Rules' -NavLabel 'Rules' -Data (New-Rows 'rule') -Columns $cols
Add-DhTable -Report $report -TableId 'emea-logs' -Title 'Firewall logs' -NavPath 'EMEA/Edge/Firewall/Logs' -NavLabel 'Logs' -Data (New-Rows 'log') -Columns $cols

# A Subtree block: visible anywhere under EMEA / Edge
Add-DhBarChart -Report $report -Id 'edge-status' -Title 'Edge status mix (every view under EMEA / Edge)' -NavPath 'EMEA/Edge' -NavScope Subtree `
    -TableId 'emea-rules' -Field 'Status' -KeyClass @{ OK = 'cell-ok'; Warning = 'cell-warn'; Critical = 'cell-danger' }

Add-DhTable -Report $report -TableId 'emea-lb' -Title 'Load balancer pools' -NavPath 'EMEA/Edge/Load balancers/Pools' -NavLabel 'Pools' -Data (New-Rows 'lb') -Columns $cols

# Three levels in the same tree: depth need not be uniform
Add-DhTable -Report $report -TableId 'emea-core' -Title 'Core switches' -NavPath 'EMEA/Core/Switches' -NavLabel 'Switches' -Data (New-Rows 'sw') -Columns $cols

# AMER
Add-DhTable -Report $report -TableId 'amer-rules' -Title 'Firewall rules' -NavPath 'AMER/Edge/Firewall/Rules' -NavLabel 'Rules' -Data (New-Rows 'rule') -Columns $cols
Add-DhTable -Report $report -TableId 'amer-core' -Title 'Core switches' -NavPath 'AMER/Core/Switches' -NavLabel 'Switches' -Data (New-Rows 'sw') -Columns $cols

# One level deep
Add-DhTable -Report $report -TableId 'incidents' -Title 'Open incidents' -NavPath 'Incidents' -Data (New-Rows 'inc' 6) -Columns $cols

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
