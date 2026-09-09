#Requires -Version 7.0
<#
.SYNOPSIS
    DashHtml v2.0.0 — four-level navigation with the sidebar layout.

.DESCRIPTION
    Depth in v2 is a POLICY, not an architectural limit. The matcher, the URL
    state and the menu renderer are all depth-agnostic — no function anywhere
    mentions a level count — so a fourth level costs nothing to express.

    What DOES change at depth 4 is presentation. Three or four stacked sticky
    strips consume roughly 190-225px of vertical chrome, about a fifth of a
    1080p viewport. So -NavLayout Auto (the default) switches to a left tree
    rail at depth 4+, and a breadcrumb appears so "where am I" stays answerable.

    Two further behaviours worth watching here:

      * Auto-descend stops at the first node that has content of its OWN,
        rather than diving to the deepest leaf. Without that rule one click on
        a top-level node would teleport you four levels down.
      * The rail expands only the branch you are on. A fully expanded deep tree
        is as unreadable as four stacked strips.

    Pass -NavLayout Strips to New-DhDashboard to force the 1.x look and see why
    the switch exists.

.EXAMPLE
    .\Demo-Feature-NavDeepSidebar.ps1
#>
[CmdletBinding()]
param([string] $OutputPath = "$PSScriptRoot\Demo-Feature-NavDeepSidebar.html")

Import-Module (Join-Path $PSScriptRoot '..\DashHtml\DashHtml.psd1') -Force

function New-Rows {
    param([string] $Prefix, [int] $Count = 12)
    1..$Count | ForEach-Object {
        [pscustomobject]@{
            Name    = '{0}-{1:D2}' -f $Prefix, $_
            Status  = @('OK','Warning','Critical')[$_ % 3]
            Latency = 5 + ($_ * 11) % 90
            Region  = @('eu-west','us-east')[$_ % 2]
        }
    }
}

# -NavMaxDepth 4 raises the policy cap. Without it the export still works but
# warns that the tree is deeper than the configured maximum.
$report = New-DhDashboard -Title 'Global network' -Theme Azure `
    -Subtitle 'Four-level navigation with the sidebar rail' `
    -NavTitle 'NetOps' -NavMaxDepth 4 -GeneratedBy 'Demo-Feature-NavDeepSidebar.ps1'

# Global chrome — present on every view at any depth.
Add-DhSummary -Report $report -Items @(
    @{ Label = 'Sites';    Value = 4 }
    @{ Label = 'Devices';  Value = 96 }
    @{ Label = 'Incidents'; Value = 3; Rag = @{ Green = @{ Max = 1 }; Red = @{ Min = 3 } } }
)

# ── EMEA / Edge / Firewall — four levels ────────────────────────────────────
Add-DhTable -Report $report -TableId 'emea-fw-rules' -Title 'Firewall rules' `
    -Data (New-Rows 'rule') -NavPath 'EMEA/Edge/Firewall/rules' -NavLabel 'Rules'
Add-DhTable -Report $report -TableId 'emea-fw-logs' -Title 'Firewall logs' `
    -Data (New-Rows 'log') -NavPath 'EMEA/Edge/Firewall/logs' -NavLabel 'Logs'

# A Subtree block: visible anywhere under EMEA/Edge, at any depth below it.
Add-DhBarChart -Report $report -Id 'edge-status' -TableId 'emea-fw-rules' -Field 'Status' `
    -Title 'Edge status mix (visible across the whole Edge branch)' `
    -NavPath 'EMEA/Edge' -NavScope Subtree

Add-DhTable -Report $report -TableId 'emea-lb' -Title 'Load balancers' `
    -Data (New-Rows 'lb') -NavPath 'EMEA/Edge/LoadBalancers/lb' -NavLabel 'Pools'

# Three levels in the same report — depth need not be uniform.
Add-DhTable -Report $report -TableId 'emea-core' -Title 'Core switches' `
    -Data (New-Rows 'sw') -NavPath 'EMEA/Core/switches' -NavLabel 'Switches'

# ── AMER branch ─────────────────────────────────────────────────────────────
Add-DhTable -Report $report -TableId 'amer-fw' -Title 'Firewall rules' `
    -Data (New-Rows 'rule') -NavPath 'AMER/Edge/Firewall/rules' -NavLabel 'Rules'
Add-DhTable -Report $report -TableId 'amer-core' -Title 'Core switches' `
    -Data (New-Rows 'sw') -NavPath 'AMER/Core/switches' -NavLabel 'Switches'

# ── A shallow branch, to show mixed depth in one tree ───────────────────────
Add-DhTable -Report $report -TableId 'incidents' -Title 'Open incidents' `
    -Data (New-Rows 'inc' 6) -NavPath 'Incidents/open' -NavLabel 'Open'

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force
Write-Host "Wrote $OutputPath" -ForegroundColor Green
