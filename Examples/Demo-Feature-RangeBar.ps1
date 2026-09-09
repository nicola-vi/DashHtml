#Requires -Version 7.0
<#
.SYNOPSIS
    v2.1 widget showcase: Add-DhRangeBar — min / avg / max range bars.

.DESCRIPTION
    Demonstrates every mode of the range-gradient bar chart introduced in v2.1:

      * explicit -Items, each row scaled against its own High (capacity)
      * -TableId aggregation, recomputed live when the table is filtered
      * -High as one fixed ceiling shared by every row
      * the edge cases the spec calls out: an average outside [Min, Max],
        values beyond the row's own scale, and an undefined (High == Low) scale

    Run from a clone of the DashHtml repo. Loads the local module so you can
    iterate without re-installing.
#>

[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Demo-Feature-RangeBar.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Default',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Load the local module (so this script runs straight from the repo)
$modulePath = Join-Path $PSScriptRoot '..\DashHtml\DashHtml.psd1'
Import-Module $modulePath -Force

$report = New-DhDashboard `
    -Title    'DashHtml v2.1 - Range Bars' `
    -Subtitle 'min / avg / max per entity on a shared 0-100 axis' `
    -Theme    $Theme `
    -GeneratedBy $env:USERNAME

# ---------------------------------------------------------------------------
# 1) EXPLICIT ITEMS - each cluster scaled against its own capacity.
#    cluster01 is allocated 315 units and cluster05 only 30, yet both are
#    readable on one axis because each is normalised against its own High.
# ---------------------------------------------------------------------------
Add-DhRangeBar -Report $report -Id 'cluster-load' `
    -Title 'Cluster load range' `
    -NavPath 'Capacity/Clusters' -NavLabel 'Cluster load' `
    -Unit 'req/s' -ShowDataTable `
    -Items @(
        @{ Name='cluster01-users';    Low=0; High=315; Min=60; Avg=97; Max=120 }
        @{ Name='cluster02-bigdata';  Low=0; High=104; Min=1;  Avg=2;  Max=10  }
        @{ Name='cluster03-cdm';      Low=0; High=97;  Min=1;  Avg=3;  Max=10  }
        @{ Name='cluster04-nsx';      Low=0; High=123; Min=10; Avg=15; Max=30  }
        @{ Name='cluster05-delivery'; Low=0; High=30;  Min=1;  Avg=2;  Max=3   }
    )

# ---------------------------------------------------------------------------
# 2) ONE FIXED CEILING - the axis reads as "% of the 250 ms SLA" for every
#    row, so the bars are directly comparable in real units too.
# ---------------------------------------------------------------------------
Add-DhRangeBar -Report $report -Id 'probe-latency' `
    -Title 'Probe latency vs SLA' `
    -NavPath 'Capacity/Latency' -NavLabel 'Latency vs SLA' `
    -Unit 'ms' -AxisLabel '% of the 250 ms SLA' `
    -Items @(
        @{ Name='milan-dc1';    Low=0; High=250; Min=8;   Avg=14;  Max=31  }
        @{ Name='rome-dc2';     Low=0; High=250; Min=22;  Avg=48;  Max=96  }
        @{ Name='frankfurt-az'; Low=0; High=250; Min=61;  Avg=140; Max=205 }
        @{ Name='dublin-az';    Low=0; High=250; Min=110; Avg=196; Max=248 }
    )

# ---------------------------------------------------------------------------
# 3) FROM A TABLE - min / avg / max are aggregated in the browser from the
#    table's FILTERED rows, so typing in the table's filter box recomputes
#    every bar. Note the table must be declared BEFORE the chart.
# ---------------------------------------------------------------------------
$hosts = @(
    @{ Cluster='cluster01-users'; Hostname='esx01'; LoadReqSec=60;  CapacityReqSec=315 }
    @{ Cluster='cluster01-users'; Hostname='esx02'; LoadReqSec=120; CapacityReqSec=315 }
    @{ Cluster='cluster01-users'; Hostname='esx03'; LoadReqSec=111; CapacityReqSec=315 }
    @{ Cluster='cluster02-bigdata'; Hostname='esx04'; LoadReqSec=1;  CapacityReqSec=104 }
    @{ Cluster='cluster02-bigdata'; Hostname='esx05'; LoadReqSec=10; CapacityReqSec=104 }
    @{ Cluster='cluster04-nsx'; Hostname='esx06'; LoadReqSec=10; CapacityReqSec=123 }
    @{ Cluster='cluster04-nsx'; Hostname='esx07'; LoadReqSec=30; CapacityReqSec=123 }
    @{ Cluster='cluster04-nsx'; Hostname='esx08'; LoadReqSec=22; CapacityReqSec=123 }
)
Add-DhTable -Report $report -TableId 'esxi-hosts' -Title 'ESXi hosts' `
    -NavPath 'Capacity/Hosts' -NavLabel 'ESXi hosts' `
    -Data $hosts -Columns @(
        @{ Field='Cluster';        Label='Cluster' }
        @{ Field='Hostname';       Label='Host' }
        @{ Field='LoadReqSec';     Label='Load (req/s)' }
        @{ Field='CapacityReqSec'; Label='Capacity (req/s)' }
    )

Add-DhRangeBar -Report $report -Id 'cluster-load-live' `
    -Title 'Cluster load range (aggregated from the host table)' `
    -NavPath 'Capacity/Hosts' -NavLabel 'ESXi hosts' `
    -TableId 'esxi-hosts' -CategoryField 'Cluster' `
    -ValueField 'LoadReqSec' -HighField 'CapacityReqSec' `
    -Unit 'req/s' -ShowDataTable

# ---------------------------------------------------------------------------
# 4) EDGE CASES the spec is explicit about. These emit warnings on purpose -
#    they are what a real data problem looks like, not a rendering bug.
# ---------------------------------------------------------------------------
Add-DhRangeBar -Report $report -Id 'edge-cases' `
    -Title 'Edge cases (these warn at generation time, deliberately)' `
    -NavPath 'Capacity/Edge cases' -NavLabel 'Edge cases' `
    -Unit 'ms' `
    -Items @(
        # An avg computed over a longer window than the observed min/max can
        # legitimately fall outside the bar. The tick is NOT clamped.
        @{ Name='avg-left-of-bar';  Low=0; High=100; Min=40; Avg=12; Max=70 }
        @{ Name='avg-right-of-bar'; Low=0; High=100; Min=10; Avg=95; Max=40 }
        # Values beyond the row's own scale: the bar clips at the axis edge,
        # the real numbers survive in the label and tooltip.
        @{ Name='over-its-scale';   Low=0; High=50;  Min=10; Avg=60; Max=80 }
        # High == Low: normalisation is undefined, so the row renders striped
        # rather than dividing by zero or faking a position.
        @{ Name='undefined-scale';  Low=10; High=10; Min=1;  Avg=2;  Max=3  }
    ) -WarningAction SilentlyContinue

# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------
Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser

Write-Host "Wrote: $OutputPath" -ForegroundColor Green
