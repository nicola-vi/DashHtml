#Requires -Version 7.0
<#
.SYNOPSIS
    v1.5 widget showcase: Add-DhTabs + Add-DhHeatmap + Add-DhTopologyMap.

.DESCRIPTION
    Focused demonstration of the three Tier A widgets introduced in v1.5:

      * Add-DhTabs         - inline tabbed content block
      * Add-DhHeatmap      - sequential / diverging 2-D colour matrix
      * Add-DhTopologyMap  - parent-child tree (AD Forest / vCenter style)

    Run from a clone of the DashHtml repo. Loads the local module so you can
    iterate without re-installing.
#>

[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Demo-Feature-TabsHeatmapTopology.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Default',
    [switch] $OpenInBrowser
)

# Load the local module (so this script runs straight from the repo)
$modulePath = Join-Path $PSScriptRoot '..\DashHtml\DashHtml.psd1'
Import-Module $modulePath -Force

$report = New-DhDashboard `
    -Title    'DashHtml v1.5 — Tier A Widgets' `
    -Subtitle 'Inline Tabs · 2-D Heatmaps · Topology Trees' `
    -Theme    $Theme `
    -GeneratedBy $env:USERNAME

# ---------------------------------------------------------------------------
# 1) TOPOLOGY MAP — AD Forest → Domain → DC tree
# ---------------------------------------------------------------------------
Add-DhTopologyMap -Report $report -Id 'ad-forest' `
    -Title 'AD Forest — Topology' `
    -Direction 'vertical' `
    -Nodes @(
        @{ Id='forest'; Label='contoso.com';        Parent=$null;    Status='ok';     Icon='F';  Badge='AD';    Tooltip='Forest functional level 2016' }
        @{ Id='dom-hq'; Label='hq.contoso.com';     Parent='forest'; Status='ok';     Icon='D';  Badge='Dom' }
        @{ Id='dom-eu'; Label='eu.contoso.com';     Parent='forest'; Status='warn';   Icon='D';  Badge='Dom';   Tooltip='Replication lag detected' }
        @{ Id='dom-ap'; Label='ap.contoso.com';     Parent='forest'; Status='ok';     Icon='D';  Badge='Dom' }
        @{ Id='dc-hq1'; Label='DC-HQ01';            Parent='dom-hq'; Status='ok';     Icon='S' }
        @{ Id='dc-hq2'; Label='DC-HQ02';            Parent='dom-hq'; Status='ok';     Icon='S' }
        @{ Id='dc-eu1'; Label='DC-EU01';            Parent='dom-eu'; Status='ok';     Icon='S' }
        @{ Id='dc-eu2'; Label='DC-EU02';            Parent='dom-eu'; Status='warn';   Icon='S';  Tooltip='Replication lag 4m' }
        @{ Id='dc-eu3'; Label='DC-EU03';            Parent='dom-eu'; Status='danger'; Icon='S';  Tooltip='Offline 12m' }
        @{ Id='dc-ap1'; Label='DC-AP01';            Parent='dom-ap'; Status='ok';     Icon='S' }
    )

# ---------------------------------------------------------------------------
# 2) HEATMAP — load by hour/day (sequential)
# ---------------------------------------------------------------------------
$days  = @('Mon','Tue','Wed','Thu','Fri','Sat','Sun')
$hours = @('00','03','06','09','12','15','18','21')

# Generate realistic synthetic load: peaks at 12-15h on weekdays, quiet weekends
$cells = foreach ($d in $days) {
    foreach ($h in $hours) {
        $hourN = [int]$h
        $base = if ($d -in 'Sat','Sun') { 18 } else { 35 }
        $peak = if ($hourN -ge 9 -and $hourN -le 18) {
            45 + [math]::Floor((Get-Random -Minimum -8 -Maximum 12))
        } else { Get-Random -Minimum -5 -Maximum 8 }
        $val  = [math]::Max(0, $base + $peak)
        @{ Row=$d; Column=$h; Value=$val; Tooltip="$d $h:00 — load ${val}%" }
    }
}

Add-DhHeatmap -Report $report -Id 'load-heatmap' `
    -Title 'Cluster Load — Last Week' `
    -Rows $days -Columns $hours -Cells $cells `
    -RowLabel 'Day' -ColumnLabel 'Hour (UTC)' `
    -ColorScale 'sequential' -Unit '%' -ShowValues `
    -CellSize 'normal'

# ---------------------------------------------------------------------------
# 3) TABS — three views in one block (overview / per-server / raw JSON)
# ---------------------------------------------------------------------------
$overviewHtml = @'
<p>The fleet runs <strong>10 servers across 3 sites</strong>. All metrics nominal except <em>srv-eu-03</em> (high CPU).</p>
<ul>
  <li>Uptime SLA: 99.95% (target 99.9%)</li>
  <li>Avg CPU: 38% — within green band</li>
  <li>Storage headroom: 42% — healthy</li>
</ul>
'@

$detailHtml = @'
<table style="width:100%; border-collapse:collapse;">
  <thead><tr style="text-align:left;border-bottom:1px solid var(--border-subtle)"><th>Host</th><th>Site</th><th>CPU</th><th>Status</th></tr></thead>
  <tbody>
    <tr><td>srv-hq-01</td><td>HQ</td><td>22%</td><td>OK</td></tr>
    <tr><td>srv-hq-02</td><td>HQ</td><td>34%</td><td>OK</td></tr>
    <tr><td>srv-eu-01</td><td>EU</td><td>41%</td><td>OK</td></tr>
    <tr><td>srv-eu-02</td><td>EU</td><td>48%</td><td>OK</td></tr>
    <tr><td>srv-eu-03</td><td>EU</td><td>87%</td><td>Warn</td></tr>
    <tr><td>srv-ap-01</td><td>AP</td><td>28%</td><td>OK</td></tr>
  </tbody>
</table>
'@

$rawHtml = @'
<pre style="background:var(--bg-elevated);padding:12px;border-radius:6px;font-size:11px;line-height:1.4;">{
  "fleet": "production",
  "as_of": "2026-05-25T14:00:00Z",
  "servers": 10,
  "alerts": [
    { "host": "srv-eu-03", "type": "cpu", "value": 87 }
  ]
}</pre>
'@

Add-DhTabs -Report $report -Id 'fleet-views' -Title 'Fleet — Views' -AllowHtml:$true -Tabs @(
    @{ Title='Overview';     Icon='O'; Content=$overviewHtml; Active=$true }
    @{ Title='Per-host';     Icon='H'; Content=$detailHtml }
    @{ Title='Raw payload';  Icon='R'; Content=$rawHtml }
)

# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------
Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser

Write-Host "Wrote: $OutputPath" -ForegroundColor Green
