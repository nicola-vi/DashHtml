#Requires -Version 7.0
<#
.SYNOPSIS
    DashHtml v1.4 — VMware vSphere ops dashboard example.

.DESCRIPTION
    Mirrors the IT-infrastructure KPI dashboard specification §4.2 layout:

        Row 1 — Summary KPI Cards (Hosts OK, VMs Running, CPU %, Mem %,
                Datastore %, Alarms)
        Row 2 — Cluster Trends (CPU Usage area, Mem Usage area, Datastore I/O area)
        Row 3 — Entity Breakdown (Top 10 VMs by CPU, Top 10 VMs by Mem,
                ESXi Host Health status matrix)
        Row 4 — Capacity & VM Health (CPU Headroom per Host bullet, VM State
                Distribution donut, Datastore Capacity + Old Snapshots table)
        Row 5 — Events (vCenter alarms / HA-DRS events / version compliance)

    All data is SYNTHETIC. Replace with output from Get-VM / Get-VMHost /
    Get-Datastore / Get-VIEvent when adapting to a real environment.

.PARAMETER OutputPath
    Where to write the generated HTML. Defaults to vSphere-Dashboard.html
    beside this script.

.PARAMETER OpenInBrowser
    Open the dashboard in the default browser once generated.

.EXAMPLE
    PS> .\Examples\vSphere-Dashboard.ps1 -OpenInBrowser
    Generates the dashboard and opens it in the default browser.

.EXAMPLE
    PS> .\Examples\vSphere-Dashboard.ps1 -OutputPath C:\Temp\vsphere.html
    Generates the dashboard without opening a browser.
#>
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'vSphere-Dashboard.html'),
    [switch] $OpenInBrowser
)

Import-Module "$PSScriptRoot\..\DashHtml\DashHtml.psd1" -Force

# Reusable RAG bands matching the vSphere thresholds in the spec --------------
$cpuRag = @{
    Green = @{ Max = 70 }
    Amber = @{ Min = 70; Max = 90 }
    Red   = @{ Min = 90 }
    NoData = $true
}
$memRag = @{
    Green = @{ Max = 80 }
    Amber = @{ Min = 80; Max = 95 }
    Red   = @{ Min = 95 }
    NoData = $true
}
$dsRag = @{
    Green = @{ Max = 80 }
    Amber = @{ Min = 80; Max = 90 }
    Red   = @{ Min = 90 }
    NoData = $true
}

$report = New-DhDashboard -Title 'vSphere Operations' `
    -Subtitle 'vCenter vc01.contoso.com — Cluster prod-east' `
    -Theme Rag `
    -InfoFields @(
        @{ Label='vCenter';   Value='vc01.contoso.com' }
        @{ Label='Cluster';   Value='prod-east' }
        @{ Label='ESXi build';Value='8.0 U3 (24022510)' }
        @{ Label='Generated'; Value=(Get-Date -Format 'yyyy-MM-dd HH:mm') }
    )

# ============================================================================
# Row 1 — Summary tiles (6 cards) — Hosts / VMs / CPU / Mem / DS / Alarms
#
# Mix of styles to show the visual hierarchy: bignumber headline up top, then
# compact standard tiles, then three gauges with RAG bands. The Icon field is
# decorative — pass emoji / unicode glyphs or HTML; leave unset for clean
# typography (the choice in this example).
# ============================================================================
Add-DhSummary -Report $report -Title 'Cluster health at a glance' -Items @(
    @{ Style='bignumber'; Label='Cluster availability'; Value='99.98%'
       Caption='30-day SLA — target 99.9% met'; Class='cell-ok' }

    @{ Label='Hosts up';      Value='8/8';   Class='cell-ok' }
    @{ Label='VMs running';   Value=247;     Previous=242; TrendIsGood=$true
       Format='number'; Sparkline=@(240,241,242,243,242,244,247); SparklineStyle='line' }
    @{ Style='gauge'; Label='Cluster CPU'; Value=68;  Max=100; Unit='%'; Rag=$cpuRag }
    @{ Style='gauge'; Label='Cluster Mem'; Value=82;  Max=100; Unit='%'; Rag=$memRag }
    @{ Style='gauge'; Label='Datastore';   Value=74;  Max=100; Unit='%'; Rag=$dsRag }
    @{ Label='Active alarms'; Value=3;      Previous=1; TrendIsGood=$false
       Class='cell-warn' }
)

# Top alert
Add-DhAlertBanner -Report $report -Id 'top-alarm' `
    -Severity 'warning' -Icon '!' -Dismissible `
    -Message '3 vCenter alarms active — esxi-04 memory pressure, datastore-prod-02 latency, VM-DB-01 snapshot > 30 days.' `
    -Action @{ Label='View hosts'; TableId='vms-by-cpu'; Filter='esxi-04' }

# ============================================================================
# Row 2 — Cluster trends (3 area charts)
# ============================================================================
$hrs = @('00:00','02:00','04:00','06:00','08:00','10:00','12:00','14:00','16:00','18:00','20:00','22:00','24:00')

Add-DhLineChart -Report $report -Id 'cluster-cpu-trend' -Title 'Cluster CPU usage (24h)' `
    -Filled -XAxis $hrs `
    -Series @(
        @{ Label='Average';  Values=@(48,42,40,44,52,62,68,72,74,72,66,58,50); Class='cell-ok'   }
        @{ Label='Peak';     Values=@(62,58,56,60,72,82,88,92,94,90,84,76,68); Class='cell-warn' }
    ) `
    -TargetLine 90 -TargetLabel 'Capacity ceiling' `
    -YAxisMin 0 -YAxisMax 100 -YAxisUnit '%'

Add-DhLineChart -Report $report -Id 'cluster-mem-trend' -Title 'Cluster Memory usage (24h)' `
    -Filled -XAxis $hrs `
    -Series @(
        @{ Label='Allocated';  Values=@(72,72,72,72,76,80,82,82,84,84,82,80,78); Class='cell-warn' }
        @{ Label='Active';     Values=@(48,46,44,46,52,58,62,66,68,66,60,54,50); Class='cell-ok'   }
        @{ Label='Ballooned';  Values=@( 0, 0, 0, 0, 2, 4, 6, 6, 8, 8, 4, 2, 0); Color='#9C0006'   }
    ) `
    -TargetLine 95 -TargetLabel 'Swap risk' `
    -YAxisMin 0 -YAxisMax 100 -YAxisUnit '%'

Add-DhLineChart -Report $report -Id 'datastore-io' -Title 'Datastore I/O latency (ms)' `
    -XAxis $hrs `
    -Series @(
        @{ Label='datastore-prod-01'; Values=@(4,4,5,5,6,8,10,12,12,11,8,6,5); Class='cell-ok'   }
        @{ Label='datastore-prod-02'; Values=@(6,7,8,9,12,18,28,42,38,32,24,16,10); Class='cell-warn' }
        @{ Label='datastore-dev';     Values=@(2,2,3,3,4,5,6,7,8,7,5,4,3);     Color='#666666'   }
    ) `
    -TargetLine 20 -TargetLabel 'SLA 20 ms' `
    -YAxisMin 0 -YAxisUnit ' ms'

# ============================================================================
# Row 3 — Entity breakdown
# ============================================================================
# Synthesize 30 VMs with CPU + Mem usage so the bar charts have something to top-10
$vms = 1..30 | ForEach-Object {
    [PSCustomObject]@{
        Name      = "vm-{0:000}" -f $_
        Role      = (Get-Random -InputObject @('app','db','web','dev','test','infra'))
        Cluster   = 'prod-east'
        CpuPct    = (Get-Random -Min 5 -Max 95)
        MemPct    = (Get-Random -Min 30 -Max 96)
        State     = (Get-Random -InputObject @('PoweredOn','PoweredOn','PoweredOn','PoweredOn','PoweredOff','Suspended'))
    }
}
Add-DhTable -Report $report -TableId 'vms-by-cpu' -Title 'All VMs (sortable)' -Data $vms -Columns @(
    @{ Field='Name';    Label='VM'; PinFirst=$true }
    @{ Field='Role';    Label='Role' }
    @{ Field='Cluster'; Label='Cluster' }
    @{ Field='CpuPct';  Label='CPU %';    Align='right'; CellType='progressbar'; ProgressMax=100; Rag=$cpuRag }
    @{ Field='MemPct';  Label='Mem %';    Align='right'; CellType='progressbar'; ProgressMax=100; Rag=$memRag }
    @{ Field='State';   Label='Power';    CellType='badge'
       Thresholds=@(
           @{ Value='PoweredOn';  Class='cell-ok'     }
           @{ Value='Suspended';  Class='cell-warn'   }
           @{ Value='PoweredOff'; Class='cell-nodata' }
       )
    }
) -PageSize 10

Add-DhBarChart -Report $report -Id 'top-vm-cpu' -Title 'Top VMs by CPU' `
    -TableId 'vms-by-cpu' -Field 'Name' -TopN 10

Add-DhBarChart -Report $report -Id 'role-stacked' -Title 'VMs per role (stacked by power state)' `
    -TableId 'vms-by-cpu' -Field 'Role' -SeriesField 'State' -Stacked

# ESXi host health matrix — hosts × probes
Add-DhStatusGrid -Report $report -Id 'esxi-health' -Title 'ESXi host health' `
    -RowLabel 'Host' -ColumnLabel 'Probe' `
    -Rows    @('esxi-01','esxi-02','esxi-03','esxi-04','esxi-05','esxi-06','esxi-07','esxi-08') `
    -Columns @('Power','vSAN','Network','Storage','HA','DRS','vSwitch') `
    -CellSize 'small' `
    -Cells @(
        # esxi-01..03 healthy
        @{ Row='esxi-01'; Column='Power';   Status='ok' }
        @{ Row='esxi-01'; Column='vSAN';    Status='ok' }
        @{ Row='esxi-01'; Column='Network'; Status='ok' }
        @{ Row='esxi-01'; Column='Storage'; Status='ok' }
        @{ Row='esxi-01'; Column='HA';      Status='ok' }
        @{ Row='esxi-01'; Column='DRS';     Status='ok' }
        @{ Row='esxi-01'; Column='vSwitch'; Status='ok' }
        @{ Row='esxi-02'; Column='Power';   Status='ok' }
        @{ Row='esxi-02'; Column='vSAN';    Status='ok' }
        @{ Row='esxi-02'; Column='Network'; Status='ok' }
        @{ Row='esxi-02'; Column='Storage'; Status='ok' }
        @{ Row='esxi-02'; Column='HA';      Status='ok' }
        @{ Row='esxi-02'; Column='DRS';     Status='ok' }
        @{ Row='esxi-02'; Column='vSwitch'; Status='ok' }
        @{ Row='esxi-03'; Column='Power';   Status='ok' }
        @{ Row='esxi-03'; Column='vSAN';    Status='ok' }
        @{ Row='esxi-03'; Column='Network'; Status='ok' }
        @{ Row='esxi-03'; Column='Storage'; Status='ok' }
        @{ Row='esxi-03'; Column='HA';      Status='ok' }
        @{ Row='esxi-03'; Column='DRS';     Status='ok' }
        @{ Row='esxi-03'; Column='vSwitch'; Status='ok' }
        # esxi-04 — memory pressure flagged
        @{ Row='esxi-04'; Column='Power';   Status='ok' }
        @{ Row='esxi-04'; Column='vSAN';    Status='warn'; Tooltip='resync 12%' }
        @{ Row='esxi-04'; Column='Network'; Status='ok' }
        @{ Row='esxi-04'; Column='Storage'; Status='warn'; Tooltip='memory pressure -> swap' }
        @{ Row='esxi-04'; Column='HA';      Status='ok' }
        @{ Row='esxi-04'; Column='DRS';     Status='ok' }
        @{ Row='esxi-04'; Column='vSwitch'; Status='ok' }
        # esxi-05..07
        @{ Row='esxi-05'; Column='Power';   Status='ok' }
        @{ Row='esxi-05'; Column='vSAN';    Status='ok' }
        @{ Row='esxi-05'; Column='Network'; Status='ok' }
        @{ Row='esxi-05'; Column='Storage'; Status='ok' }
        @{ Row='esxi-05'; Column='HA';      Status='ok' }
        @{ Row='esxi-05'; Column='DRS';     Status='ok' }
        @{ Row='esxi-05'; Column='vSwitch'; Status='ok' }
        @{ Row='esxi-06'; Column='Power';   Status='ok' }
        @{ Row='esxi-06'; Column='vSAN';    Status='ok' }
        @{ Row='esxi-06'; Column='Network'; Status='warn'; Tooltip='packet drops on vmnic1' }
        @{ Row='esxi-06'; Column='Storage'; Status='ok' }
        @{ Row='esxi-06'; Column='HA';      Status='ok' }
        @{ Row='esxi-06'; Column='DRS';     Status='ok' }
        @{ Row='esxi-06'; Column='vSwitch'; Status='ok' }
        @{ Row='esxi-07'; Column='Power';   Status='ok' }
        @{ Row='esxi-07'; Column='vSAN';    Status='ok' }
        @{ Row='esxi-07'; Column='Network'; Status='ok' }
        @{ Row='esxi-07'; Column='Storage'; Status='ok' }
        @{ Row='esxi-07'; Column='HA';      Status='ok' }
        @{ Row='esxi-07'; Column='DRS';     Status='ok' }
        @{ Row='esxi-07'; Column='vSwitch'; Status='ok' }
        # esxi-08 — newly added host, monitoring not yet collecting
        @{ Row='esxi-08'; Column='Power';   Status='ok' }
        @{ Row='esxi-08'; Column='vSAN';    Status='nodata' }
        @{ Row='esxi-08'; Column='Network'; Status='nodata' }
        @{ Row='esxi-08'; Column='Storage'; Status='nodata' }
        @{ Row='esxi-08'; Column='HA';      Status='ok' }
        @{ Row='esxi-08'; Column='DRS';     Status='ok' }
        @{ Row='esxi-08'; Column='vSwitch'; Status='ok' }
    )

# ============================================================================
# Row 4 — Capacity & VM Health
# ============================================================================
# CPU headroom per host — bullet chart with reversed RAG (higher headroom = better)
Add-DhBullet -Report $report -Id 'cpu-headroom' -Title 'CPU headroom per ESXi host' -Items @(
    @{ Label='esxi-01'; Value=58; Target=30; Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{ Min=30 }; Amber=@{ Min=15; Max=30 }; Red=@{ Max=15 } } }
    @{ Label='esxi-02'; Value=42; Target=30; Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{ Min=30 }; Amber=@{ Min=15; Max=30 }; Red=@{ Max=15 } } }
    @{ Label='esxi-03'; Value=48; Target=30; Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{ Min=30 }; Amber=@{ Min=15; Max=30 }; Red=@{ Max=15 } } }
    @{ Label='esxi-04'; Value=12; Target=30; Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{ Min=30 }; Amber=@{ Min=15; Max=30 }; Red=@{ Max=15 } } }
    @{ Label='esxi-05'; Value=62; Target=30; Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{ Min=30 }; Amber=@{ Min=15; Max=30 }; Red=@{ Max=15 } } }
    @{ Label='esxi-06'; Value=24; Target=30; Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{ Min=30 }; Amber=@{ Min=15; Max=30 }; Red=@{ Max=15 } } }
    @{ Label='esxi-07'; Value=52; Target=30; Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{ Min=30 }; Amber=@{ Min=15; Max=30 }; Red=@{ Max=15 } } }
    @{ Label='esxi-08'; Value=$null; Target=30; Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{ Min=30 }; Amber=@{ Min=15; Max=30 }; Red=@{ Max=15 }; NoData=$true } }
)

# VM state distribution
$stateCounts = $vms | Group-Object State | ForEach-Object {
    @{ Label=$_.Name; Value=$_.Count }
}
Add-DhPieChart -Report $report -Id 'vm-states' -Title 'VM state distribution' `
    -Style 'donut' -Slices $stateCounts

# Old snapshots table
$snapshots = @(
    [PSCustomObject]@{ VM='vm-DB-01';  Snapshot='before-upgrade';  AgeDays=42; SizeGB=124 }
    [PSCustomObject]@{ VM='vm-APP-12'; Snapshot='pre-deploy-prod'; AgeDays=18; SizeGB=8    }
    [PSCustomObject]@{ VM='vm-WEB-03'; Snapshot='maintenance';     AgeDays=92; SizeGB=42   }
    [PSCustomObject]@{ VM='vm-INFRA-02';Snapshot='test-rollback';  AgeDays=5;  SizeGB=12   }
)
Add-DhTable -Report $report -TableId 'old-snapshots' -Title 'Snapshots > 7 days' -Data $snapshots -Columns @(
    @{ Field='VM';       Label='VM' }
    @{ Field='Snapshot'; Label='Snapshot name' }
    @{ Field='AgeDays';  Label='Age (days)'; Align='right'
       Rag=@{ Green=@{ Max=7 }; Amber=@{ Min=7; Max=30 }; Red=@{ Min=30 } } }
    @{ Field='SizeGB';   Label='Size (GB)';  Align='right' }
)

# ============================================================================
# Row 5 — Events
# ============================================================================
Add-DhEventFeed -Report $report -Id 'vcenter-events' -Title 'vCenter events (24h)' `
    -GroupBy 'Severity' -Events @(
        @{ Timestamp='2026-05-22 15:18'; Severity='warning';  Source='esxi-04';   Message='Host memory state changed: HARD (esxi-04 memory pressure)' }
        @{ Timestamp='2026-05-22 14:42'; Severity='warning';  Source='datastore'; Message='datastore-prod-02 latency above warning threshold (28 ms p95)' }
        @{ Timestamp='2026-05-22 14:12'; Severity='critical'; Source='vm-DB-01';  Message='Snapshot age > 30 days — performance impact likely' }
        @{ Timestamp='2026-05-22 13:55'; Severity='info';     Source='DRS';       Message='Migrated vm-WEB-08 from esxi-04 to esxi-05 (memory rebalance)' }
        @{ Timestamp='2026-05-22 13:42'; Severity='info';     Source='DRS';       Message='Migrated vm-APP-19 from esxi-04 to esxi-03 (memory rebalance)' }
        @{ Timestamp='2026-05-22 12:38'; Severity='info';     Source='HA';        Message='Cluster HA monitoring state nominal (8/8 hosts responding)' }
        @{ Timestamp='2026-05-22 12:00'; Severity='ok';       Source='Backup';    Message='VBR job "Prod-Daily" completed — 247 VMs, 0 failures' }
        @{ Timestamp='2026-05-22 09:14'; Severity='info';     Source='vCenter';   Message='Patch baseline "ESXi-8.0U3" attached to cluster prod-east' }
        @{ Timestamp='2026-05-22 02:00'; Severity='info';     Source='Cron';      Message='DRS recalculation complete' }
)

# ============================================================================
# Render
# ============================================================================
Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
