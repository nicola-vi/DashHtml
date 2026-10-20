#Requires -Version 7.0
<#
.SYNOPSIS
    VMware vSphere operations dashboard (synthetic data).

.DESCRIPTION
    A realistic vSphere report with two clusters, laid out as a menu.

    MENU (what opens where)
        Overview                 headline KPIs, cluster trends
        Compute
            Hosts                host health grid, CPU headroom, host table
            Virtual machines     top consumers, power states, VM table
        Storage
            Datastores           latency, capacity, datastore table
            Snapshots            old snapshots, what they cost
        Network                  hosts, switches and datastores as a map
        Alarms                   events, plus what to do about them

    WHAT IS GLOBAL AND WHAT IS NOT
        * One banner and one global "Cluster" filter (a dropdown above everything). The filter
          narrows EVERY table that has a Cluster column, on every view.
        * "Compute" and "Storage" each have a KPI strip declared with -NavScope Subtree: it sits
          on top of every view under that menu item.
        * Everything else is bound to exactly one view.
        * Page order inside a view: banners, global filters, global KPI tiles, blocks in
          declaration order, tables in declaration order (tables always come last).

    Run Tools/Show-DhNavMap.ps1 on the result to print the menu and each view's content.

    All data is synthetic and deterministic. Replace the data section with PowerCLI output
    (Get-VM, Get-VMHost, Get-Datastore, Get-VIEvent) when adapting.

.PARAMETER OutputPath
    Where to write the HTML. Defaults to Demo-VMware.html beside this script.

.PARAMETER Theme
    Default, Azure, VMware, Grey, Company or Rag.

.PARAMETER OpenInBrowser
    Open the dashboard once generated.

.EXAMPLE
    PS> ./Examples/Demo-VMware.ps1 -OpenInBrowser
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Demo-VMware.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'VMware',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force

# ============================================================================
# Data (synthetic, deterministic)
# ============================================================================
$rng = [System.Random]::new(7)

$cpuRag  = @{ Green = @{ Max = 70 }; Amber = @{ Min = 70; Max = 90 }; Red = @{ Min = 90 }; NoData = $true }
$memRag  = @{ Green = @{ Max = 80 }; Amber = @{ Min = 80; Max = 95 }; Red = @{ Min = 95 }; NoData = $true }
$headRag = @{ Green = @{ Min = 30 }; Amber = @{ Min = 15; Max = 30 }; Red = @{ Max = 15 }; NoData = $true }

# Hosts: 8 in prod-east, 4 in dev-east
$hostRows = foreach ($i in 1..12) {
    $cluster = if ($i -le 8) { 'prod-east' } else { 'dev-east' }
    $cpu = switch ($i) { 4 { 88 } 6 { 76 } 12 { $null } default { 30 + $rng.Next(0, 40) } }
    [pscustomobject]@{
        Host = 'esxi-{0:00}' -f $i; Cluster = $cluster
        Version = '8.0 U3'; Cores = 48; RamGB = 768
        CpuPct = $cpu
        MemPct = $(if ($i -eq 4) { 94 } elseif ($i -eq 12) { $null } else { 45 + $rng.Next(0, 40) })
        Vms = $(if ($i -eq 12) { 0 } else { 14 + $rng.Next(0, 14) })
        Uptime = (30 + $rng.Next(0, 200))
        State = $(if ($i -eq 12) { 'Maintenance' } else { 'Connected' })
    }
}

$vmRows = foreach ($i in 1..60) {
    $cluster = if ($i % 5 -eq 0) { 'dev-east' } else { 'prod-east' }
    [pscustomobject]@{
        Name = 'vm-{0:000}' -f $i
        Cluster = $cluster
        Role = @('app', 'db', 'web', 'infra', 'test')[$i % 5]
        Host = 'esxi-{0:00}' -f (1 + ($i % $(if ($cluster -eq 'prod-east') { 8 } else { 3 })) + $(if ($cluster -eq 'dev-east') { 8 } else { 0 }))
        CpuPct = 5 + $rng.Next(0, 90)
        MemPct = 30 + $rng.Next(0, 66)
        Power = @('PoweredOn', 'PoweredOn', 'PoweredOn', 'PoweredOn', 'PoweredOff', 'Suspended')[$rng.Next(0, 6)]
    }
}

$datastores = @(
    [pscustomobject]@{ Datastore = 'ds-prod-01'; Cluster = 'prod-east'; Type = 'VMFS'; CapacityTB = 40; UsedPct = 64; LatencyMs = 5 }
    [pscustomobject]@{ Datastore = 'ds-prod-02'; Cluster = 'prod-east'; Type = 'VMFS'; CapacityTB = 40; UsedPct = 86; LatencyMs = 28 }
    [pscustomobject]@{ Datastore = 'vsan-prod';  Cluster = 'prod-east'; Type = 'vSAN'; CapacityTB = 120; UsedPct = 71; LatencyMs = 4 }
    [pscustomobject]@{ Datastore = 'ds-dev-01';  Cluster = 'dev-east';  Type = 'NFS';  CapacityTB = 20; UsedPct = 52; LatencyMs = 7 }
    [pscustomobject]@{ Datastore = 'ds-dev-02';  Cluster = 'dev-east';  Type = 'NFS';  CapacityTB = 20; UsedPct = 93; LatencyMs = 11 }
)

$snapshots = @(
    [pscustomobject]@{ VM = 'vm-010'; Cluster = 'prod-east'; Snapshot = 'before-upgrade';  AgeDays = 42; SizeGB = 124 }
    [pscustomobject]@{ VM = 'vm-022'; Cluster = 'prod-east'; Snapshot = 'pre-deploy';      AgeDays = 18; SizeGB = 8 }
    [pscustomobject]@{ VM = 'vm-033'; Cluster = 'prod-east'; Snapshot = 'maintenance';     AgeDays = 92; SizeGB = 42 }
    [pscustomobject]@{ VM = 'vm-045'; Cluster = 'dev-east';  Snapshot = 'test-rollback';   AgeDays = 5;  SizeGB = 12 }
    [pscustomobject]@{ VM = 'vm-050'; Cluster = 'dev-east';  Snapshot = 'golden';          AgeDays = 160; SizeGB = 88 }
)

$hrs = @('00:00','02:00','04:00','06:00','08:00','10:00','12:00','14:00','16:00','18:00','20:00','22:00','24:00')

$report = New-DhDashboard -Title 'vSphere Operations' -Subtitle 'vCenter vc01.contoso.com, clusters prod-east and dev-east' `
    -Theme $Theme -NavTitle 'vSphere' -NavMaxDepth 2 -GeneratedBy 'Demo-VMware.ps1' -InfoFields @(
        @{ Label = 'vCenter';    Value = 'vc01.contoso.com' }
        @{ Label = 'Clusters';   Value = 'prod-east, dev-east' }
        @{ Label = 'ESXi build'; Value = '8.0 U3 (24022510)' }
        @{ Label = 'Generated';  Value = (Get-Date -Format 'yyyy-MM-dd HH:mm') } )

# ============================================================================
# GLOBAL: a banner and a cluster filter, both visible on every view
# ============================================================================
Add-DhAlertBanner -Report $report -Id 'alarms' -Severity warning -Icon '!' -Dismissible `
    -Message '3 vCenter alarms active: esxi-04 memory pressure, ds-prod-02 latency, vm-033 snapshot older than 90 days.' `
    -Action @{ Label = 'Show esxi-04'; TableId = 'hosts'; Filter = 'esxi-04' }

Add-DhGlobalFilter -Report $report -Field 'Cluster' -Label 'Cluster'

# ============================================================================
# OVERVIEW
# ============================================================================
Add-DhSummary -Report $report -NavPath 'Overview' -NavLabel 'Overview' -Items @(
    @{ Style = 'bignumber'; Label = 'Availability (30 days)'; Value = '99.98%'; Caption = 'Target 99.9%, met'; Class = 'cell-ok' }
    @{ Label = 'Hosts up'; Value = '11/12'; Class = 'cell-warn'; SubLabel = '1 in maintenance' }
    @{ Label = 'VMs'; Value = 60; Previous = 57; TrendIsGood = $true; Sparkline = @(54, 55, 56, 57, 57, 58, 60); SparklineStyle = 'line' }
    @{ Style = 'gauge'; Label = 'CPU';       Value = 68; Max = 100; Unit = '%'; Rag = $cpuRag }
    @{ Style = 'gauge'; Label = 'Memory';    Value = 82; Max = 100; Unit = '%'; Rag = $memRag }
    @{ Style = 'gauge'; Label = 'Datastore'; Value = 74; Max = 100; Unit = '%'; Rag = @{ Green = @{ Max = 80 }; Amber = @{ Min = 80; Max = 90 }; Red = @{ Min = 90 } } }
    @{ Label = 'Active alarms'; Value = 3; Previous = 1; TrendIsGood = $false; Class = 'cell-warn' }
)

Add-DhLineChart -Report $report -Id 'cpu-trend' -Title 'Cluster CPU usage (24h)' -NavPath 'Overview' -Filled -XAxis $hrs `
    -YAxisMin 0 -YAxisMax 100 -YAxisUnit '%' -TargetLine 90 -TargetLabel 'Capacity ceiling' -Series @(
        @{ Label = 'Average'; Values = @(48,42,40,44,52,62,68,72,74,72,66,58,50); Class = 'cell-ok' }
        @{ Label = 'Peak';    Values = @(62,58,56,60,72,82,88,92,94,90,84,76,68); Class = 'cell-warn' } )

Add-DhLineChart -Report $report -Id 'mem-trend' -Title 'Cluster memory usage (24h)' -NavPath 'Overview' -Filled -XAxis $hrs `
    -YAxisMin 0 -YAxisMax 100 -YAxisUnit '%' -TargetLine 95 -TargetLabel 'Swap risk' -Series @(
        @{ Label = 'Allocated'; Values = @(72,72,72,72,76,80,82,82,84,84,82,80,78); Class = 'cell-warn' }
        @{ Label = 'Active';    Values = @(48,46,44,46,52,58,62,66,68,66,60,54,50); Class = 'cell-ok' }
        @{ Label = 'Ballooned'; Values = @(0,0,0,0,2,4,6,6,8,8,4,2,0); Color = '#9C0006' } )

# ============================================================================
# COMPUTE  (strip for the whole branch, then Hosts and Virtual machines)
# ============================================================================
Add-DhSummary -Report $report -NavPath 'Compute' -NavScope Subtree -Items @(
    @{ Label = 'Hosts connected'; Value = 11; Class = 'cell-ok' }
    @{ Label = 'VMs powered on';  Value = 47; Previous = 45; TrendIsGood = $true }
    @{ Label = 'vCPU : pCPU';     Value = '3.1 : 1' }
    @{ Label = 'Hosts over 85% memory'; Value = 1; Class = 'cell-warn' }
)

$cells = foreach ($h in $hostRows) {
    foreach ($probe in 'Power', 'vSAN', 'Network', 'Storage', 'HA', 'DRS') {
        $st = 'ok'; $tip = ''
        if ($h.Host -eq 'esxi-04' -and $probe -eq 'Storage') { $st = 'warn'; $tip = 'memory pressure, swapping' }
        if ($h.Host -eq 'esxi-04' -and $probe -eq 'vSAN')    { $st = 'warn'; $tip = 'resync 12%' }
        if ($h.Host -eq 'esxi-06' -and $probe -eq 'Network') { $st = 'warn'; $tip = 'packet drops on vmnic1' }
        if ($h.Host -eq 'esxi-12' -and $probe -in 'vSAN', 'Network', 'Storage') { $st = 'nodata'; $tip = 'in maintenance' }
        @{ Row = $h.Host; Column = $probe; Status = $st; Tooltip = $tip }
    }
}
Add-DhStatusGrid -Report $report -Id 'host-health' -Title 'Host health' -NavPath 'Compute/Hosts' -NavLabel 'Hosts' `
    -RowLabel 'Host' -ColumnLabel 'Probe' -CellSize small -Rows $hostRows.Host -Columns @('Power', 'vSAN', 'Network', 'Storage', 'HA', 'DRS') -Cells @($cells)

Add-DhBullet -Report $report -Id 'cpu-headroom' -Title 'CPU headroom per host' -NavPath 'Compute/Hosts' -Items @(
    foreach ($h in $hostRows) {
        @{ Label = $h.Host; Value = $(if ($null -eq $h.CpuPct) { $null } else { 100 - $h.CpuPct }); Target = 30; Min = 0; Max = 100; Unit = '%'; Rag = $headRag }
    } )

Add-DhTable -Report $report -TableId 'hosts' -Title 'ESXi hosts' -NavPath 'Compute/Hosts' -Data $hostRows `
    -DetailDrawer -DetailTitleField 'Host' -Columns @(
        @{ Field = 'Host';    Label = 'Host'; PinFirst = $true }
        @{ Field = 'Cluster'; Label = 'Cluster' }
        @{ Field = 'State';   Label = 'State'; CellType = 'badge'
           Thresholds = @(@{ Value = 'Connected'; Class = 'cell-ok' }, @{ Value = 'Maintenance'; Class = 'cell-nodata' }) }
        @{ Field = 'Version'; Label = 'Version' }
        @{ Field = 'Cores';   Label = 'Cores'; Align = 'right' }
        @{ Field = 'RamGB';   Label = 'RAM (GB)'; Align = 'right'; Format = 'number' }
        @{ Field = 'CpuPct';  Label = 'CPU %'; Align = 'right'; CellType = 'progressbar'; ProgressMax = 100; Rag = $cpuRag }
        @{ Field = 'MemPct';  Label = 'Memory %'; Align = 'right'; CellType = 'progressbar'; ProgressMax = 100; Rag = $memRag }
        @{ Field = 'Vms';     Label = 'VMs'; Align = 'right' }
        @{ Field = 'Uptime';  Label = 'Uptime (days)'; Align = 'right' } )

# The table is declared first (a chart that reads it must come after it); it still renders last on the page.
Add-DhTable -Report $report -TableId 'vms' -Title 'Virtual machines' -NavPath 'Compute/Virtual machines' -NavLabel 'Virtual machines' `
    -Data $vmRows -PageSize 10 -DetailDrawer -DetailTitleField 'Name' -Columns @(
        @{ Field = 'Name';    Label = 'VM'; PinFirst = $true }
        @{ Field = 'Cluster'; Label = 'Cluster' }
        @{ Field = 'Host';    Label = 'Host' }
        @{ Field = 'Role';    Label = 'Role' }
        @{ Field = 'CpuPct';  Label = 'CPU %'; Align = 'right'; CellType = 'progressbar'; ProgressMax = 100; Rag = $cpuRag }
        @{ Field = 'MemPct';  Label = 'Memory %'; Align = 'right'; CellType = 'progressbar'; ProgressMax = 100; Rag = $memRag }
        @{ Field = 'Power';   Label = 'Power'; CellType = 'badge'
           Thresholds = @(@{ Value = 'PoweredOn'; Class = 'cell-ok' }, @{ Value = 'Suspended'; Class = 'cell-warn' }, @{ Value = 'PoweredOff'; Class = 'cell-nodata' }) } )

Add-DhBarChart -Report $report -Id 'top-cpu' -Title 'Busiest VMs (CPU %)' -NavPath 'Compute/Virtual machines' `
    -TableId 'vms' -Field 'Name' -ValueField 'CpuPct' -Aggregate max -Unit '%' -TopN 10 `
    -Rag @{ Green = @{ Max = 70 }; Amber = @{ Min = 70; Max = 90 }; Red = @{ Min = 90 } }

Add-DhBarChart -Report $report -Id 'role-power' -Title 'VMs per role, by power state' -NavPath 'Compute/Virtual machines' `
    -TableId 'vms' -Field 'Role' -SeriesField 'Power' -Stacked

Add-DhPieChart -Report $report -Id 'power-states' -Title 'Power states' -NavPath 'Compute/Virtual machines' `
    -TableId 'vms' -Field 'Power' -Style donut -ClickFilters

# ============================================================================
# STORAGE
# ============================================================================
Add-DhSummary -Report $report -NavPath 'Storage' -NavScope Subtree -Items @(
    @{ Label = 'Capacity'; Value = '240 TB' }
    @{ Style = 'gauge'; Label = 'Used'; Value = 74; Max = 100; Unit = '%'; Rag = @{ Green = @{ Max = 80 }; Amber = @{ Min = 80; Max = 90 }; Red = @{ Min = 90 } } }
    @{ Label = 'Datastores over 85%'; Value = 2; Class = 'cell-warn' }
    @{ Label = 'Snapshots over 30 days'; Value = 3; Previous = 2; TrendIsGood = $false; Class = 'cell-danger' }
)

Add-DhLineChart -Report $report -Id 'ds-latency' -Title 'Datastore latency (ms)' -NavPath 'Storage/Datastores' -NavLabel 'Datastores' -XAxis $hrs `
    -YAxisMin 0 -YAxisUnit ' ms' -TargetLine 20 -TargetLabel 'SLA 20 ms' -Series @(
        @{ Label = 'ds-prod-01'; Values = @(4,4,5,5,6,8,10,12,12,11,8,6,5);       Class = 'cell-ok' }
        @{ Label = 'ds-prod-02'; Values = @(6,7,8,9,12,18,28,42,38,32,24,16,10);  Class = 'cell-warn' }
        @{ Label = 'ds-dev-02';  Values = @(2,2,3,3,4,5,6,7,8,7,5,4,3);           Color = '#666666' } )

Add-DhTable -Report $report -TableId 'datastores' -Title 'Datastores' -NavPath 'Storage/Datastores' -Data $datastores -DetailDrawer -DetailTitleField 'Datastore' -Columns @(
    @{ Field = 'Datastore';  Label = 'Datastore'; PinFirst = $true }
    @{ Field = 'Cluster';    Label = 'Cluster' }
    @{ Field = 'Type';       Label = 'Type'; CellType = 'badge' }
    @{ Field = 'CapacityTB'; Label = 'Capacity (TB)'; Align = 'right'; Format = 'number' }
    @{ Field = 'UsedPct';    Label = 'Used %'; Align = 'right'; CellType = 'progressbar'; ProgressMax = 100
       Rag = @{ Green = @{ Max = 80 }; Amber = @{ Min = 80; Max = 90 }; Red = @{ Min = 90 } } }
    @{ Field = 'LatencyMs';  Label = 'Latency (ms)'; Align = 'right'
       Rag = @{ Green = @{ Max = 15 }; Amber = @{ Min = 15; Max = 25 }; Red = @{ Min = 25 } } } )

Add-DhBarChart -Report $report -Id 'used-by-ds' -Title 'Used space by datastore (%)' -NavPath 'Storage/Datastores' `
    -TableId 'datastores' -Field 'Datastore' -ValueField 'UsedPct' -Aggregate max -Unit '%' `
    -Rag @{ Green = @{ Max = 80 }; Amber = @{ Min = 80; Max = 90 }; Red = @{ Min = 90 } }

Add-DhTable -Report $report -TableId 'snapshots' -Title 'Snapshots older than 7 days' -NavPath 'Storage/Snapshots' -NavLabel 'Snapshots' -Data $snapshots -Columns @(
    @{ Field = 'VM';       Label = 'VM' }
    @{ Field = 'Cluster';  Label = 'Cluster' }
    @{ Field = 'Snapshot'; Label = 'Snapshot' }
    @{ Field = 'AgeDays';  Label = 'Age (days)'; Align = 'right'; Rag = @{ Green = @{ Max = 7 }; Amber = @{ Min = 7; Max = 30 }; Red = @{ Min = 30 } } }
    @{ Field = 'SizeGB';   Label = 'Size (GB)'; Align = 'right'; Aggregate = 'sum' } )

Add-DhBarChart -Report $report -Id 'snap-size' -Title 'Snapshot size by VM (GB)' -NavPath 'Storage/Snapshots' `
    -TableId 'snapshots' -Field 'VM' -ValueField 'SizeGB' -Aggregate sum -Unit 'GB'

# ============================================================================
# NETWORK: hosts, switches and datastores as one map
# ============================================================================
Add-DhNetworkMap -Report $report -Id 'fabric' -Title 'Host connectivity' -NavPath 'Network' -NavLabel 'Network' -Legend `
    -Groups @(
        @{ Id = 'hosts';  Label = 'ESXi hosts (prod-east)' }
        @{ Id = 'switch'; Label = 'Switches' }
        @{ Id = 'store';  Label = 'Datastores' } ) `
    -Nodes @(
        foreach ($h in ($hostRows | Where-Object Cluster -eq 'prod-east')) {
            @{ Id = $h.Host; Label = $h.Host; Group = 'hosts'; Status = $(if ($h.Host -eq 'esxi-04') { 'warn' } else { 'ok' }); LinkTableId = 'hosts'; LinkFilter = $h.Host }
        }
        @{ Id = 'sw-a'; Label = 'switch-a'; Group = 'switch'; Status = 'ok' }
        @{ Id = 'sw-b'; Label = 'switch-b'; Group = 'switch'; Status = 'warn'; Tooltip = 'Packet drops on uplink 1' }
        @{ Id = 'ds1'; Label = 'ds-prod-01'; Group = 'store'; Status = 'ok'; Badge = @('VMFS') }
        @{ Id = 'ds2'; Label = 'ds-prod-02'; Group = 'store'; Status = 'warn'; Badge = @('VMFS'); Tooltip = 'Latency 28 ms' }
        @{ Id = 'vsan'; Label = 'vsan-prod'; Group = 'store'; Status = 'ok'; Badge = @('vSAN') } ) `
    -Edges @(
        foreach ($h in ($hostRows | Where-Object Cluster -eq 'prod-east')) {
            @{ From = $h.Host; To = 'sw-a'; Direction = 'both'; Status = 'ok' }
            @{ From = $h.Host; To = 'sw-b'; Direction = 'both'; Status = $(if ($h.Host -eq 'esxi-06') { 'warn' } else { 'ok' }); Style = 'dashed' }
        }
        @{ From = 'sw-a'; To = 'ds1'; Label = '25 Gb'; Direction = 'both'; Status = 'ok' }
        @{ From = 'sw-b'; To = 'ds2'; Label = '25 Gb'; Direction = 'both'; Status = 'warn' }
        @{ From = 'sw-a'; To = 'vsan'; Label = '100 Gb'; Direction = 'both'; Status = 'ok' } )

# ============================================================================
# ALARMS
# ============================================================================
Add-DhEventFeed -Report $report -Id 'events' -Title 'vCenter events (24h)' -NavPath 'Alarms' -NavLabel 'Alarms' -GroupBy Severity -Events @(
    @{ Timestamp = '2026-10-17 15:18'; Severity = 'warning';  Source = 'esxi-04';  Message = 'Host memory state changed to HARD' }
    @{ Timestamp = '2026-10-17 14:42'; Severity = 'warning';  Source = 'datastore'; Message = 'ds-prod-02 latency above the warning threshold (28 ms p95)' }
    @{ Timestamp = '2026-10-17 14:12'; Severity = 'critical'; Source = 'vm-033';   Message = 'Snapshot older than 90 days: performance impact likely' }
    @{ Timestamp = '2026-10-17 13:55'; Severity = 'info';     Source = 'DRS';      Message = 'Migrated vm-008 from esxi-04 to esxi-05 (memory rebalance)' }
    @{ Timestamp = '2026-10-17 12:38'; Severity = 'info';     Source = 'HA';       Message = 'Cluster HA monitoring nominal (11/11 hosts responding)' }
    @{ Timestamp = '2026-10-17 12:00'; Severity = 'ok';       Source = 'Backup';   Message = 'Job "Prod-Daily" completed: 47 VMs, 0 failures' }
    @{ Timestamp = '2026-10-17 02:00'; Severity = 'info';     Source = 'DRS';      Message = 'Recalculation complete' } )

Add-DhFindings -Report $report -Id 'actions' -Title 'What to do' -NavPath 'Alarms' -Findings @(
    @{ Severity = 'warning'; Area = 'Compute'; Title = 'esxi-04 is short of memory'
       Description = '94% memory used, ballooning and swapping.'; Recommendation = 'Let DRS move two more VMs, or add memory.'
       Affected = @('esxi-04'); AffectedTableId = 'hosts' }
    @{ Severity = 'warning'; Area = 'Storage'; Title = 'ds-prod-02 latency is above 25 ms'
       Recommendation = 'Move busy VMs to vsan-prod.'; Affected = @('ds-prod-02'); AffectedTableId = 'datastores' }
    @{ Severity = 'critical'; Area = 'Storage'; Title = 'Snapshots older than 90 days'
       Description = 'Old snapshots slow the VM and grow without limit.'; Recommendation = 'Consolidate or delete them after confirming with the owner.'
       Affected = @('vm-033', 'vm-050'); AffectedTableId = 'snapshots' } )

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
