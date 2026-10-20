#Requires -Version 7.0
<#
.SYNOPSIS
    How the menu works: paths, scopes, labels, order, and where each element lands on the page.

.DESCRIPTION
    Open the page and click through it. Every view starts with a note saying what you are looking
    at and why each element is there. The rules, in one place:

    PATH      -NavPath 'Storage/Capacity' puts an item at a node of the menu. Any depth. The menu is
              built from the paths; you never declare it separately. A table with no path gets one
              named after its TableId, so always give tables a path.
    SCOPE     Exact (default)  the item shows on that node only
              Subtree          the item shows on that node and everything below it
              Global           the item shows everywhere (this is also what an item with no path is)
    LABEL     -NavLabel is the text on the menu. The path stays the key, so renaming a label never
              breaks a saved link. Label a group by putting -NavLabel on an item at the group's own
              path (the strip below does that).
    ORDER     Siblings follow declaration order. -NavOrder 1, 2, ... overrides it for that item's own
              node, without touching its parent.
    ALL VIEW  -NavAllLabel on New-DhDashboard adds an "All" child to a group (here Storage): one more
              view that shows the group's own content and everything below it. It is never the
              default view.
    SKELETON  -NavTree declares the menu once: labels, order, and nodes that exist before anything
              is placed on them. "Later" below has nothing on it, so it shows a "No content" note.
    BANNERS   A banner follows the same rules: no path = every view, a path = that view,
              -NavScope Subtree = that node and below.
    FILTERS   A global filter always sits above everything and narrows every table that has the field.

    PAGE ORDER INSIDE A VIEW (fixed by the exporter, not by where you write the call):
        banners, global filters, global KPI tiles, then blocks in declaration order, then tables in
        declaration order. A table is always the last thing on its view.

    LINKED TABLES  Two tables joined by Set-DhTableLink share one path, so they stack on one view:
                   click a row in the first and the second follows.

    Run Tools/Show-DhNavMap.ps1 on the result to print the menu and what each view contains.

.PARAMETER OutputPath
    Where to write the HTML.

.PARAMETER Theme
    Default, Azure, VMware, Grey, Company or Rag.

.PARAMETER OpenInBrowser
    Open the dashboard once generated.

.EXAMPLE
    PS> ./Examples/Feature-Navigation.ps1 -OpenInBrowser
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Feature-Navigation.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Default',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force

# ---------------------------------------------------------------- data
$volumes = foreach ($i in 1..24) {
    [pscustomobject]@{ Volume = 'vol-{0:000}' -f $i; Tier = @('Gold', 'Silver', 'Bronze')[$i % 3]; SizeGB = 100 * (1 + $i % 8)
                       UsedPct = 20 + ($i * 3) % 75; Tagged = $(if ($i % 4) { 'Yes' } else { 'No' }) }
}
$snapshots = foreach ($i in 1..14) {
    [pscustomobject]@{ Snapshot = 'snap-{0:000}' -f $i; Volume = 'vol-{0:000}' -f (($i * 2) % 24 + 1); AgeDays = ($i * 7) % 60; SizeGB = 5 * (1 + $i % 6) }
}
$hosts = foreach ($i in 1..8) {
    [pscustomobject]@{ Host = 'esxi-{0:00}' -f $i; Cluster = @('prod', 'dev')[$i % 2]; CpuPct = 30 + ($i * 7) % 60 }
}
$vms = foreach ($i in 1..24) {
    [pscustomobject]@{ VM = 'vm-{0:000}' -f $i; Host = 'esxi-{0:00}' -f (1 + $i % 8); Role = @('app', 'db', 'web')[$i % 3]; MemGB = 4 * (1 + $i % 6) }
}
$note = { param([string] $Id, [string] $Path, [string] $Text) Add-DhHtmlBlock -Report $report -Id $Id -Title 'What you are looking at' -Style info -NavPath $Path -Content $Text }

$report = New-DhDashboard -Title 'Navigation guide' -Subtitle 'Click through the menu; each view explains itself' `
    -Theme $Theme -NavTitle 'Guide' -GeneratedBy 'Feature-Navigation.ps1' `
    -NavAllLabel @{ 'Storage' = 'All storage' } `
    -NavTree @(
        @{ Path = 'Home' }
        @{ Path = 'Storage' }
        @{ Path = 'Compute' }
        @{ Path = 'Later'; Label = 'Later (nothing here yet)' }
    )

# ------------------------------------------------------------ GLOBAL
Add-DhAlertBanner -Report $report -Id 'maintenance' -Severity warning -Icon '!' -Dismissible `
    -Message 'GLOBAL banner (no -NavPath): it is on every view. Maintenance window Saturday 02:00-04:00 UTC.'

Add-DhSummary -Report $report -Items @(
    @{ Label = 'Volumes';   Value = $volumes.Count }
    @{ Label = 'Snapshots'; Value = $snapshots.Count }
    @{ Label = 'Hosts';     Value = $hosts.Count }
)

# ------------------------------------------------------------ HOME
& $note 'note-home' 'Home' ('The banner above and the three KPI tiles under it are GLOBAL: declared with no path, so they stay on screen on every view. ' +
    'This note, and everything else below the tiles, is bound to the exact path Home.')

# ------------------------------------------------------------ STORAGE
Add-DhSummary -Report $report -NavPath 'Storage' -NavLabel 'Storage' -NavScope Subtree -Items @(
    @{ Label = 'Used (average)'; Value = [int](($volumes | Measure-Object UsedPct -Average).Average); Unit = '%' }
    @{ Label = 'Untagged'; Value = @($volumes | Where-Object Tagged -eq 'No').Count; Class = 'cell-warn' }
)
Add-DhAlertBanner -Report $report -Id 'cap-banner' -Severity critical -Icon '!' -NavPath 'Storage/Capacity' `
    -Message 'EXACT banner (-NavPath Storage/Capacity): it shows on this view only.'
Add-DhAlertBanner -Report $report -Id 'storage-banner' -Severity info -Icon 'i' -NavPath 'Storage' -NavScope Subtree `
    -Message 'SUBTREE banner (-NavPath Storage -NavScope Subtree): it shows on every Storage view.'

& $note 'note-capacity' 'Storage/Capacity' ('The KPI strip above this note was declared once, at the path Storage with -NavScope Subtree, so it appears on every Storage view. ' +
    'The red banner is EXACT to this view. The chart and the table below belong to Storage/Capacity only. The table is last because tables always come after blocks.')
Add-DhTable -Report $report -TableId 'volumes' -Title 'Volumes' -NavPath 'Storage/Capacity' -NavLabel 'Capacity' -Data $volumes -PageSize 8 -Columns @(
    @{ Field = 'Volume'; Label = 'Volume' }, @{ Field = 'Tier'; Label = 'Tier'; CellType = 'badge' }
    @{ Field = 'SizeGB'; Label = 'Size (GB)'; Format = 'number'; Align = 'right' }
    @{ Field = 'UsedPct'; Label = 'Used'; CellType = 'progressbar'; ProgressMax = 100; Rag = @{ Green = @{ Max = 70 }; Amber = @{ Min = 70; Max = 90 }; Red = @{ Min = 90 } } } )
Add-DhBarChart -Report $report -Id 'tier-mix' -Title 'Volumes by tier' -NavPath 'Storage/Capacity' -TableId 'volumes' -Field 'Tier'

& $note 'note-tagging' 'Storage/Tagging' 'A block bound to a second-level node. Its own menu entry exists because an item sits exactly on this path.'
Add-DhPieChart -Report $report -Id 'tag-state' -Title 'Tagged and untagged' -NavPath 'Storage/Tagging' -NavLabel 'Tagging' -TableId 'volumes' -Field 'Tagged' -Style donut

# This one is declared LAST but ordered FIRST among its siblings (-NavOrder), without moving its parent.
& $note 'note-snap' 'Storage/Snapshots' 'This view is declared after Capacity and Tagging but appears first in the Storage group: -NavOrder 1 orders this node among its siblings and leaves the parent Storage where it is.'
Add-DhTable -Report $report -TableId 'snaps' -Title 'Snapshots' -NavPath 'Storage/Snapshots' -NavOrder 1 -Data $snapshots -PageSize 8 -Columns @(
    @{ Field = 'Snapshot'; Label = 'Snapshot' }, @{ Field = 'Volume'; Label = 'Volume' }
    @{ Field = 'AgeDays'; Label = 'Age (days)'; Align = 'right'; Rag = @{ Green = @{ Max = 14 }; Amber = @{ Min = 14; Max = 45 }; Red = @{ Min = 45 } } }
    @{ Field = 'SizeGB'; Label = 'Size (GB)'; Align = 'right' } )

& $note 'note-all' 'Storage' 'Storage has its own content (this note) and, because of -NavAllLabel, a view called "All storage" next to Capacity, Tagging and Snapshots. Open it: it shows this note, the KPI strip, and everything under Storage at once.'

# ------------------------------------------------------------ COMPUTE
Add-DhAlertBanner -Report $report -Id 'compute-banner' -Severity warning -Icon '!' -NavPath 'Compute' -NavScope Subtree `
    -Message 'SUBTREE banner on Compute: it shows on Compute and everything below it.'

& $note 'note-hosts' 'Compute/Hosts' ('Two tables share the path Compute/Hosts and are joined with Set-DhTableLink: click a host and the VM table below filters to it. ' +
    'Joined tables belong on ONE path so they stack on one view.')
Add-DhTable -Report $report -TableId 'hosts' -Title 'Hosts (click a row)' -NavPath 'Compute/Hosts' -NavLabel 'Hosts' -Data $hosts -Columns @(
    @{ Field = 'Host'; Label = 'Host' }, @{ Field = 'Cluster'; Label = 'Cluster' }
    @{ Field = 'CpuPct'; Label = 'CPU %'; CellType = 'progressbar'; ProgressMax = 100; Rag = @{ Green = @{ Max = 70 }; Amber = @{ Min = 70; Max = 90 }; Red = @{ Min = 90 } } } )
Add-DhTable -Report $report -TableId 'hostvms' -Title 'Virtual machines on the selected host' -NavPath 'Compute/Hosts' -Data $vms -PageSize 8 -Columns @(
    @{ Field = 'VM'; Label = 'VM' }, @{ Field = 'Host'; Label = 'Host' }, @{ Field = 'Role'; Label = 'Role' }, @{ Field = 'MemGB'; Label = 'Memory (GB)'; Align = 'right' } )
Set-DhTableLink -Report $report -MasterTableId 'hosts' -DetailTableId 'hostvms' -MasterField 'Host' -DetailField 'Host'

& $note 'note-vms' 'Compute/Virtual machines' 'A GLOBAL-scope item would appear here too; this chart is Exact, so it does not leave this view.'
Add-DhBarChart -Report $report -Id 'role-mix' -Title 'VMs by role' -NavPath 'Compute/Virtual machines' -NavLabel 'Virtual machines' -TableId 'hostvms' -Field 'Role' -ClickFilters

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
