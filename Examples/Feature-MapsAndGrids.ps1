#Requires -Version 7.0
<#
.SYNOPSIS
    Grids, heatmaps and maps: status matrices, colour matrices, trees and networks.

.DESCRIPTION
    MENU
        Grids
            Status grid              rows by columns, one colour per cell, detail behind each cell
            Heatmap                  rows by columns, a number per cell on a colour scale
        Maps
            Tree                     one parent per node (forest, domain, controller)
            Network, grouped         nodes in boxes, any number of links
            Network, tiers           lanes by tier, and a shortest-path trace to a target

    Choosing: a status grid answers "is it OK, per pair"; a heatmap answers "how much, per pair";
    a tree is for strict hierarchies; a network map is for everything with links that is not a
    tree. The network layouts are deterministic: the same data always draws the same picture.

.PARAMETER OutputPath
    Where to write the HTML.

.PARAMETER Theme
    Default, Azure, VMware, Grey, Company or Rag.

.PARAMETER OpenInBrowser
    Open the dashboard once generated.

.EXAMPLE
    PS> ./Examples/Feature-MapsAndGrids.ps1 -OpenInBrowser
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Feature-MapsAndGrids.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Default',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force

$rng = [System.Random]::new(9)
$note = { param([string] $Id, [string] $Path, [string] $Text) Add-DhHtmlBlock -Report $report -Id $Id -Title 'In this view' -Style info -NavPath $Path -Content $Text }
$report = New-DhDashboard -Title 'Grids and maps' -Subtitle 'Status grids, heatmaps, trees and networks' -Theme $Theme -NavTitle 'Maps' -NavMaxDepth 2 -GeneratedBy 'Feature-MapsAndGrids.ps1'

# A table the map nodes can open (a node with LinkTableId jumps to its row)
$dcTable = foreach ($d in 'DC01', 'DC02', 'DC03', 'DC04') { [pscustomobject]@{ DC = $d; Site = @{ DC01 = 'HQ'; DC02 = 'HQ'; DC03 = 'EU'; DC04 = 'EU' }[$d]; Status = $(if ($d -eq 'DC03') { 'Failing' } else { 'OK' }) } }

# ============================================================== GRIDS
$dcs = 'DC01', 'DC02', 'DC03', 'DC04'
& $note 'n-grid' 'Grids/Status grid' 'One colour per cell: ok, warn, danger or no data. -SelfDiagonal hatches the cells where row and column are the same thing. A cell can carry a Glyph, a Tooltip, a Detail (opens the side panel) and a link to a table.'
$cells = foreach ($to in $dcs) {
    foreach ($from in $dcs) {
        if ($to -eq $from) { continue }
        $bad = ($to -eq 'DC03' -and $from -eq 'DC01')
        $st = if ($bad) { 'danger' } elseif ($to -eq 'DC04' -and $from -eq 'DC02') { 'warn' } else { 'ok' }
        @{ Row = $to; Column = $from; Status = $st; Glyph = $(if ($st -eq 'ok') { [string][char]0x2713 } elseif ($st -eq 'danger') { [string][char]0x2717 } else { '!' })
           Tooltip = "$to from $from"; LinkTableId = 'dctable'; LinkFilter = $to
           Detail = @{ Title = "$to from $from"; Sections = @(
               @{ Kind = 'kv'; Items = @(@{ Label = 'Last success'; Value = $(if ($bad) { '3 days ago' } else { '4 minutes ago' }); Status = $st }, @{ Label = 'Failures'; Value = $(if ($bad) { '812' } else { '0' }) }) }
               @{ Kind = 'statusList'; Title = 'Naming contexts'; Items = @('Domain', 'Configuration', 'Schema' | ForEach-Object { @{ Label = $_; Status = $(if ($bad -and $_ -eq 'Configuration') { 'danger' } else { 'ok' }); Text = $(if ($bad -and $_ -eq 'Configuration') { 'Failing' } else { 'In sync' }) } }) }) } }
    }
}
Add-DhStatusGrid -Report $report -Id 'status-grid' -Title 'Replication matrix' -NavPath 'Grids/Status grid' -NavLabel 'Status grid' `
    -RowLabel 'Destination' -ColumnLabel 'Source' -Rows $dcs -Columns $dcs -SelfDiagonal -Cells @($cells)
Add-DhTable -Report $report -TableId 'dctable' -Title 'Domain controllers' -NavPath 'Grids/Status grid' -Data $dcTable -Columns @(
    @{ Field = 'DC'; Label = 'DC' }, @{ Field = 'Site'; Label = 'Site' }
    @{ Field = 'Status'; Label = 'Status'; CellType = 'badge'; Thresholds = @(@{ Value = 'OK'; Class = 'cell-ok' }, @{ Value = 'Failing'; Class = 'cell-danger' }) } )

$days = 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
$hrs = '00', '04', '08', '12', '16', '20'
& $note 'n-heat' 'Grids/Heatmap' 'A number per cell on a colour scale. Sequential for "how much" (low to high); diverging for "above or below a midpoint". -ShowValues prints the numbers; -Unit adds a suffix.'
Add-DhHeatmap -Report $report -Id 'heat-seq' -Title 'Cluster load by weekday and hour (%)' -NavPath 'Grids/Heatmap' -NavLabel 'Heatmap' `
    -Rows $days -Columns $hrs -RowLabel 'Day' -ColumnLabel 'Hour' -ColorScale sequential -Unit '%' -ShowValues -Cells @(
        foreach ($d in $days) { foreach ($h in $hrs) { @{ Row = $d; Column = $h; Value = [int](20 + 60 * [math]::Sin(([int]$h) / 24 * [math]::PI) + $rng.Next(0, 15)) } } } )
Add-DhHeatmap -Report $report -Id 'heat-div' -Title 'Deviation from the weekly baseline (%)' -NavPath 'Grids/Heatmap' `
    -Rows $days -Columns $hrs -RowLabel 'Day' -ColumnLabel 'Hour' -ColorScale diverging -Min -30 -Max 30 -Unit '%' -ShowValues -Cells @(
        foreach ($d in $days) { foreach ($h in $hrs) { @{ Row = $d; Column = $h; Value = $rng.Next(-30, 31) } } } )

# ============================================================== MAPS
& $note 'n-tree' 'Maps/Tree' 'A tree has exactly one parent per node: forest, domain, controller. Pan and zoom with the buttons, the wheel or a drag; the + and - on a node fold its subtree. A node can link to a table.'
Add-DhTopologyMap -Report $report -Id 'tree' -Title 'Forest' -NavPath 'Maps/Tree' -NavLabel 'Tree' -Nodes @(
    @{ Id = 'forest'; Label = 'contoso.com'; Parent = $null; Status = 'ok'; Badge = 'Forest' }
    @{ Id = 'hq'; Label = 'hq.contoso.com'; Parent = 'forest'; Status = 'ok'; Badge = 'Domain' }
    @{ Id = 'eu'; Label = 'eu.contoso.com'; Parent = 'forest'; Status = 'warn'; Badge = 'Domain'; Tooltip = 'Replication lag detected' }
    @{ Id = 'DC01'; Label = 'DC01'; Parent = 'hq'; Status = 'ok'; LinkTableId = 'dctable'; LinkFilter = 'DC01' }
    @{ Id = 'DC02'; Label = 'DC02'; Parent = 'hq'; Status = 'ok'; LinkTableId = 'dctable'; LinkFilter = 'DC02' }
    @{ Id = 'DC03'; Label = 'DC03'; Parent = 'eu'; Status = 'danger'; LinkTableId = 'dctable'; LinkFilter = 'DC03' }
    @{ Id = 'DC04'; Label = 'DC04'; Parent = 'eu'; Status = 'ok'; LinkTableId = 'dctable'; LinkFilter = 'DC04' } )

& $note 'n-net' 'Maps/Network, grouped' 'Not a tree: any number of links, parallel links between the same pair, a direction (arrowheads), a label, a colour and a dashed style. Groups draw boxes (they can nest). Use the chips to filter by status or badge, the box to find a node, and click a node to highlight its links and open its detail.'
Add-DhNetworkMap -Report $report -Id 'net-grouped' -Title 'Replication links' -NavPath 'Maps/Network, grouped' -NavLabel 'Network, grouped' -Legend `
    -Groups @(@{ Id = 'hq'; Label = 'HQ site' }, @{ Id = 'eu'; Label = 'EU site'; Status = 'warn' }) `
    -Nodes @(
        @{ Id = 'DC01'; Label = 'DC01'; Group = 'hq'; Badge = @('PDC', 'GC'); Status = 'ok'; Detail = @{ Title = 'DC01'; Sections = @(@{ Kind = 'kv'; Items = @(@{ Label = 'OS'; Value = 'Windows Server 2022' }) }) } }
        @{ Id = 'DC02'; Label = 'DC02'; Group = 'hq'; Badge = @('GC'); Status = 'ok' }
        @{ Id = 'DC03'; Label = 'DC03'; Group = 'eu'; Badge = @('GC'); Status = 'danger'; LinkTableId = 'dctable'; LinkFilter = 'DC03' }
        @{ Id = 'DC04'; Label = 'DC04'; Group = 'eu'; Status = 'ok' } ) `
    -Edges @(
        @{ From = 'DC01'; To = 'DC02'; Label = '15 s'; Direction = 'both'; Status = 'ok' }
        @{ From = 'DC01'; To = 'DC03'; Label = '15 min'; Direction = 'forward'; Status = 'danger'; Style = 'dashed'; Tooltip = 'Failing: error 1722' }
        @{ From = 'DC03'; To = 'DC01'; Label = '15 min'; Direction = 'forward'; Status = 'ok' }
        @{ From = 'DC03'; To = 'DC04'; Direction = 'none'; Status = 'ok' }
        @{ From = 'DC04'; To = 'DC04'; Label = 'self'; Direction = 'forward'; Status = 'ok' } )

& $note 'n-tier' 'Maps/Network, tiers' 'Layered layout: lanes by Tier (0 on top). A node without a Tier takes its depth from the links. Mark the nodes you care about with Target, switch on "Trace path", click a workstation, and the shortest route to the nearest target is highlighted and spelled out.'
Add-DhNetworkMap -Report $report -Id 'net-tiers' -Title 'How a workstation reaches Tier 0' -NavPath 'Maps/Network, tiers' -NavLabel 'Network, tiers' -Layout layered -Legend `
    -Nodes @(
        @{ Id = 'da'; Label = 'Domain Admins'; Tier = 0; Target = $true; Status = 'danger'; Badge = @('group') }
        @{ Id = 'dc'; Label = 'DC01'; Tier = 0; Target = $true }
        @{ Id = 'bkp'; Label = 'Backup server'; Tier = 1; Status = 'warn' }
        @{ Id = 'sql'; Label = 'SQL-PROD'; Tier = 1 }
        @{ Id = 'app'; Label = 'APP-ERP'; Tier = 1 }
        @{ Id = 'ws1'; Label = 'WS-HELPDESK-07'; Tier = 2 }
        @{ Id = 'ws2'; Label = 'WS-SALES-112'; Tier = 2 }
        @{ Id = 'ws3'; Label = 'WS-LAB-003'; Tier = 2 } ) `
    -Edges @(
        @{ From = 'ws1'; To = 'app'; Label = 'local admin'; Status = 'warn' }
        @{ From = 'ws2'; To = 'app' }
        @{ From = 'ws3'; To = 'sql'; Label = 'SMB signing off'; Status = 'warn' }
        @{ From = 'app'; To = 'sql' }
        @{ From = 'sql'; To = 'bkp'; Label = 'service account' }
        @{ From = 'bkp'; To = 'dc'; Label = 'DCSync'; Status = 'danger' }
        @{ From = 'dc'; To = 'da' } )

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
