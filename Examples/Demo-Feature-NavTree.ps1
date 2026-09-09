#Requires -Version 7.0
<#
.SYNOPSIS
    DashHtml v2.0.0 — the -NavPath navigation model.

.DESCRIPTION
    Shows the three things the v2 nav model gives you that v1 could not express:

      1. A path of ANY depth, declared in one parameter.
             -NavPath 'Storage/Tagging/Key usage'
      2. A scope saying how far up an item stays visible.
             Exact   - only on that exact view (the default)
             Subtree - that node and everything beneath it
             Global  - everywhere, regardless of the selected path
      3. Labels decoupled from the path key, so renaming what the reader sees
         never breaks a saved deep link.

    It also demonstrates the case that was BROKEN in 1.x: a block bound to a
    second-level node. In 1.x a chart declared with -NavGroup + -NavSubGroup was
    unreachable - selecting its own subgroup failed to reveal it (readme-dev
    gotcha #26). Here the same intent is expressed with -NavPath and works.

.EXAMPLE
    .\Demo-Feature-NavTree.ps1
#>
[CmdletBinding()]
param([string] $OutputPath = "$PSScriptRoot\Demo-Feature-NavTree.html")

Import-Module (Join-Path $PSScriptRoot '..\DashHtml\DashHtml.psd1') -Force

# ---------------------------------------------------------------- sample data
$volumes = 1..24 | ForEach-Object {
    [pscustomobject]@{
        Volume    = 'vol-{0:D3}' -f $_
        Tier      = @('Gold','Silver','Bronze')[$_ % 3]
        UsedPct   = 20 + ($_ * 3) % 75
        SizeGB    = 100 * (1 + $_ % 8)
        Tagged    = if ($_ % 4) { 'Yes' } else { 'No' }
    }
}
$snapshots = 1..14 | ForEach-Object {
    [pscustomobject]@{
        Snapshot = 'snap-{0:D3}' -f $_
        Volume   = 'vol-{0:D3}' -f (($_ * 2) % 24 + 1)
        AgeDays  = ($_ * 7) % 60
        SizeGB   = 5 * (1 + $_ % 6)
    }
}
$hosts = 1..10 | ForEach-Object {
    [pscustomobject]@{
        Host    = 'esxi-{0:D2}' -f $_
        Cluster = @('prod','dev')[$_ % 2]
        CpuPct  = 30 + ($_ * 7) % 60
        MemPct  = 40 + ($_ * 5) % 50
    }
}

$report = New-DhDashboard -Title 'Infrastructure' -Theme Azure `
    -Subtitle 'v2.0.0 navigation: one tree, any depth' `
    -NavTitle 'Infra' -GeneratedBy 'Demo-Feature-NavTree.ps1'

# ── Global: visible on every view, whatever is selected ─────────────────────
Add-DhAlertBanner -Report $report -Id 'maint' -Severity 'warning' -Icon '!' -Dismissible `
    -Message 'Maintenance window Saturday 02:00-04:00 UTC.'

Add-DhSummary -Report $report -Items @(
    @{ Label = 'Volumes';   Value = $volumes.Count }
    @{ Label = 'Snapshots'; Value = $snapshots.Count }
    @{ Label = 'Hosts';     Value = $hosts.Count }
)

# ── Storage branch ──────────────────────────────────────────────────────────
# Subtree: this chart stays visible anywhere under Storage, at any depth.
Add-DhBarChart -Report $report -Id 'tier-mix' -TableId 'vols' -Field 'Tier' `
    -Title 'Volumes by tier (visible across all of Storage)' `
    -NavPath 'Storage' -NavScope Subtree

# Level 3 leaf. -NavLabel is what the reader sees; the path key stays stable,
# so renaming the label never breaks a bookmarked link.
Add-DhTable -Report $report -TableId 'vols' -Title 'Volumes' -Data $volumes `
    -NavPath 'Storage/Capacity/vols' -NavLabel 'All volumes' -PageSize 10 `
    -Columns @(
        @{ Field = 'Volume';  Label = 'Volume' }
        @{ Field = 'Tier';    Label = 'Tier'; CellType = 'badge' }
        @{ Field = 'SizeGB';  Label = 'Size (GB)'; Format = 'number' }
        @{ Field = 'UsedPct'; Label = 'Used'; CellType = 'progressbar'
           Rag = @{ Green = @{ Max = 70 }; Amber = @{ Min = 70; Max = 90 }; Red = @{ Min = 90 } } }
    )

# THE 1.x BUG, expressed in v2: a block bound to a second-level node.
# In 1.x this chart was unreachable. Here it appears with its own node.
Add-DhPieChart -Report $report -Id 'tag-state' -TableId 'vols' -Field 'Tagged' `
    -Title 'Tagged vs untagged' -NavPath 'Storage/Tagging' -NavScope Subtree

Add-DhTable -Report $report -TableId 'untagged' -Title 'Untagged volumes' `
    -Data ($volumes | Where-Object Tagged -eq 'No') `
    -NavPath 'Storage/Tagging/untagged' -NavLabel 'Needs a tag'

# -NavOrder overrides declaration order among siblings. Snapshots is declared
# last under Storage but renders first, without moving the code.
Add-DhTable -Report $report -TableId 'snaps' -Title 'Snapshots' -Data $snapshots `
    -NavPath 'Storage/Snapshots/snaps' -NavLabel 'All snapshots' -NavOrder 1 -PageSize 10

# ── Compute branch — no -NavOrder, so it follows declaration order ──────────
Add-DhTable -Report $report -TableId 'hosts' -Title 'Hosts' -Data $hosts `
    -NavPath 'Compute/hosts' -NavLabel 'ESXi hosts'

Add-DhBarChart -Report $report -Id 'cluster-mix' -TableId 'hosts' -Field 'Cluster' `
    -Title 'Hosts per cluster' -NavPath 'Compute' -NavScope Subtree

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force
Write-Host "Wrote $OutputPath" -ForegroundColor Green

