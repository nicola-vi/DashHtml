#Requires -Version 7.0
<#
.SYNOPSIS
    Every chart / visualisation type DashHtml can draw, in one dashboard.

.DESCRIPTION
    A side-by-side reference of all nine visual block types, plus the three
    in-table cell visualisations. Use it to pick the right widget: each panel
    says what the chart is FOR, not just that it exists.

      Nav 'Trend'        Add-DhLineChart    line, area, multi-series, target line
      Nav 'Proportion'   Add-DhPieChart     donut (from table) + pie (explicit)
      Nav 'Ranking'      Add-DhBarChart     plain + stacked
      Nav 'Range'        Add-DhRangeBar     min/avg/max, per-row + fixed ceiling
      Nav 'Target'       Add-DhBullet       actual vs target with RAG bands
      Nav 'Matrix'       Add-DhStatusGrid   categorical RAG matrix
                         Add-DhHeatmap      numeric, sequential + diverging
      Nav 'Hierarchy'    Add-DhTopologyMap  parent-child tree
      Nav 'Timeline'     Add-DhEventFeed    chronological severity log
      Nav 'KPI'          Add-DhSummary      tile / bignumber / gauge + sparkline
      Nav 'In-table'     Add-DhTable        progressbar / badge / sparkline cells

    Output: Demo-Feature-AllChartTypes.html beside this script.

    Run from a clone of the DashHtml repo. Loads the local module so you can
    iterate without re-installing.
#>

[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Demo-Feature-AllChartTypes.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Default',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\DashHtml\DashHtml.psd1') -Force

$report = New-DhDashboard `
    -Title    'DashHtml - every chart type' `
    -Subtitle 'One panel per visualisation, with what each one is for' `
    -Theme    $Theme `
    -GeneratedBy $env:USERNAME

# Reusable RAG bands - the modern shape, accepted by tiles, bullets and columns.
$latencyRag = @{
    Green = @{ Max = 50 }
    Amber = @{ Min = 50; Max = 80 }
    Red   = @{ Min = 80 }
}

# ===========================================================================
# KPI - Add-DhSummary. All three tile styles plus sparkline and delta.
# ===========================================================================
Add-DhSummary -Report $report -NavPath 'KPI' -Items @(
    @{ Label = 'Requests today'; Value = 128400; Style = 'bignumber'
       Caption = 'across all sites'; Previous = 119800; TrendIsGood = 'up' }
    @{ Label = 'Availability'; Value = 99.2; Unit = '%'; Style = 'gauge'
       Min = 95; Max = 100; Rag = @{ Green = @{ Min = 99.5 }; Amber = @{ Min = 99; Max = 99.5 }; Red = @{ Max = 99 } } }
    @{ Label = 'p95 latency'; Value = 68; Unit = 'ms'; Style = 'gauge'
       Min = 0; Max = 120; Rag = $latencyRag }
    @{ Label = 'Error rate'; Value = 0.42; Unit = '%'; Previous = 0.61; TrendIsGood = 'down'
       Sparkline = @(0.61,0.58,0.55,0.60,0.49,0.44,0.42) }
    @{ Label = 'Open incidents'; Value = 7; Previous = 4; TrendIsGood = 'down' }
)

Add-DhHtmlBlock -Report $report -Id 'kpi-note' -NavPath 'KPI' -Style 'info' -AllowHtml:$true `
    -Content '<b>Add-DhSummary</b> - the top-of-page answer to "is anything wrong?". Use <code>bignumber</code> for the single headline figure, <code>gauge</code> for a percentage against a ceiling, and a plain tile with <code>Previous</code> for "vs last period".'

# ===========================================================================
# TREND - Add-DhLineChart. Time on x, always paired with a target line.
# ===========================================================================
$hours = 0..23 | ForEach-Object { '{0:00}:00' -f $_ }

Add-DhLineChart -Report $report -Id 'trend-latency' -NavPath 'Trend' `
    -Title 'p95 latency over 24h (multi-series + SLA line)' `
    -XAxis $hours `
    -Series @(
        @{ Label = 'milan-dc1';  Values = @(21,20,19,18,18,19,24,38,52,58,61,63,59,55,57,62,66,61,48,37,30,26,23,22) }
        @{ Label = 'rome-dc2';   Values = @(30,28,27,26,27,29,35,49,66,74,79,81,77,71,73,80,86,79,63,50,42,37,34,32) }
        @{ Label = 'dublin-az';  Values = @(44,42,41,40,41,44,52,70,89,97,101,104,99,92,95,102,108,100,82,67,57,51,48,46) }
    ) `
    -TargetLine 80 -TargetLabel 'SLA 80 ms' -YAxisUnit 'ms' -ShowLegend $true

Add-DhLineChart -Report $report -Id 'trend-volume' -NavPath 'Trend' `
    -Title 'Request volume (filled area)' `
    -XAxis $hours `
    -Series @(
        @{ Label = 'requests'; Values = @(120,90,70,60,55,70,180,420,760,910,980,1010,940,880,900,970,1020,880,640,470,360,280,210,160) }
    ) `
    -Filled -YAxisUnit 'req/min'

Add-DhHtmlBlock -Report $report -Id 'trend-note' -NavPath 'Trend' -Style 'info' -AllowHtml:$true `
    -Content '<b>Add-DhLineChart</b> - anything measured repeatedly over time. Always pair it with <code>-TargetLine</code>: a trend without its threshold makes the reader guess where "bad" starts. Add <code>-Filled</code> for volume, leave it off for rates.'

# ===========================================================================
# RANKING - Add-DhBarChart. Counts per category, from a table.
# ===========================================================================
$incidents = @(
    foreach ($i in 1..90) {
        $sev  = @('Critical','High','Medium','Low')[(Get-Random -Max 4)]
        $team = @('Network','Storage','Platform','Database','Security')[(Get-Random -Max 5)]
        $site = @('Milan','Rome','Dublin')[(Get-Random -Max 3)]
        [pscustomobject]@{
            Ticket   = 'INC{0:D5}' -f (10000 + $i)
            Team     = $team
            Severity = $sev
            Site     = $site
            AgeHours = Get-Random -Minimum 1 -Maximum 300
            SlaUsed  = Get-Random -Minimum 5 -Maximum 130
        }
    }
)

Add-DhTable -Report $report -TableId 'incidents' -NavPath 'Ranking' `
    -Title 'Incidents (source table for the charts below)' -PageSize 10 `
    -Data $incidents -Columns @(
        @{ Field = 'Ticket';   Label = 'Ticket';   Width = '120px' }
        @{ Field = 'Team';     Label = 'Team';     Width = '130px' }
        @{ Field = 'Severity'; Label = 'Severity'; Width = '120px'; CellType = 'badge'
           Thresholds = @(
               @{ Value = 'Critical'; Class = 'cell-danger' }
               @{ Value = 'High';     Class = 'cell-warn'   }
               @{ Value = 'Medium';   Class = 'cell-nodata' }
               @{ Value = 'Low';      Class = 'cell-ok'     }
           ) }
        @{ Field = 'Site';     Label = 'Site';     Width = '110px' }
        @{ Field = 'AgeHours'; Label = 'Age (h)';  Width = '110px'; Align = 'right' }
        @{ Field = 'SlaUsed';  Label = 'SLA used'; Width = '160px'; CellType = 'progressbar'
           ProgressMax = 100; Rag = @{ Green = @{ Max = 70 }; Amber = @{ Min = 70; Max = 100 }; Red = @{ Min = 100 } } }
    )

Add-DhBarChart -Report $report -Id 'rank-team' -NavPath 'Ranking' `
    -Title 'Incidents per team' -TableId 'incidents' -Field 'Team' `
    -ShowCount $true -ShowPercent -ClickFilters

Add-DhBarChart -Report $report -Id 'rank-stacked' -NavPath 'Ranking' `
    -Title 'Incidents per team, split by severity' `
    -TableId 'incidents' -Field 'Team' -SeriesField 'Severity' -Stacked

Add-DhHtmlBlock -Report $report -Id 'rank-note' -NavPath 'Ranking' -Style 'info' -AllowHtml:$true `
    -Content '<b>Add-DhBarChart</b> - "which category has the most?". It counts rows, so it needs no pre-aggregation. <code>-ClickFilters</code> makes a bar filter the source table; <code>-Stacked -SeriesField</code> adds a second dimension. Filtering the table re-aggregates the chart live.'

# ===========================================================================
# PROPORTION - Add-DhPieChart. Both modes.
# ===========================================================================
Add-DhPieChart -Report $report -Id 'prop-sev' -NavPath 'Proportion' `
    -Title 'Severity mix (donut, aggregated from the table)' `
    -TableId 'incidents' -Field 'Severity'

Add-DhPieChart -Report $report -Id 'prop-budget' -NavPath 'Proportion' `
    -Title 'Budget split (pie, explicit slices)' -Style 'pie' `
    -Slices @(
        @{ Label = 'Compute';  Value = 42 }
        @{ Label = 'Storage';  Value = 27 }
        @{ Label = 'Network';  Value = 18 }
        @{ Label = 'Licences'; Value = 13 }
    )

Add-DhHtmlBlock -Report $report -Id 'prop-note' -NavPath 'Proportion' -Style 'warn' -AllowHtml:$true `
    -Content '<b>Add-DhPieChart</b> - parts of one whole, and only when there are few parts. Past about six slices a bar chart reads better. Mode A (<code>-TableId</code> + <code>-Field</code>) counts rows and follows table filters; Mode B (<code>-Slices</code>) takes numbers you already have.'

# ===========================================================================
# RANGE - Add-DhRangeBar. min / avg / max on a shared 0-100 axis.
# ===========================================================================
Add-DhRangeBar -Report $report -Id 'range-capacity' -NavPath 'Range' `
    -Title 'Cluster load range (each row vs its own capacity)' `
    -Unit 'req/s' -ShowDataTable `
    -Items @(
        @{ Name = 'cluster01-users';    Low = 0; High = 315; Min = 60; Avg = 97; Max = 120 }
        @{ Name = 'cluster02-bigdata';  Low = 0; High = 104; Min = 1;  Avg = 2;  Max = 10  }
        @{ Name = 'cluster03-cdm';      Low = 0; High = 97;  Min = 1;  Avg = 3;  Max = 10  }
        @{ Name = 'cluster04-nsx';      Low = 0; High = 123; Min = 10; Avg = 15; Max = 30  }
        @{ Name = 'cluster05-delivery'; Low = 0; High = 30;  Min = 1;  Avg = 2;  Max = 3   }
    )

Add-DhRangeBar -Report $report -Id 'range-sla' -NavPath 'Range' `
    -Title 'SLA consumption per team (one fixed ceiling)' `
    -TableId 'incidents' -CategoryField 'Team' -ValueField 'SlaUsed' -High 130 `
    -Unit '%' -AxisLabel '% of the 130% breach point'

Add-DhHtmlBlock -Report $report -Id 'range-note' -NavPath 'Range' -Style 'info' -AllowHtml:$true `
    -Content '<b>Add-DhRangeBar</b> - the SPREAD of a metric per entity, not a single value. The bar is min-to-max, the tick is the average, and colour follows position on the 0-100 axis. Normalising each row against its own <code>High</code> lets a 315-unit cluster and a 30-unit one share one axis. The average tick is deliberately not clamped inside the bar.'

# ===========================================================================
# TARGET - Add-DhBullet. Actual vs target with qualitative bands.
# ===========================================================================
Add-DhBullet -Report $report -Id 'bullet-latency' -NavPath 'Target' `
    -Title 'LDAP bind time vs 50 ms target' `
    -Items @(
        @{ Label = 'dc01'; Value = 42; Target = 50; Max = 120; Unit = 'ms'; Rag = $latencyRag }
        @{ Label = 'dc02'; Value = 68; Target = 50; Max = 120; Unit = 'ms'; Rag = $latencyRag }
        @{ Label = 'dc03'; Value = 92; Target = 50; Max = 120; Unit = 'ms'; Rag = $latencyRag }
        @{ Label = 'dc04'; Value = $null; Target = 50; Max = 120; Unit = 'ms'; Rag = @{ Green=@{Max=50}; Amber=@{Min=50;Max=80}; Red=@{Min=80}; NoData=$true } }
    )

Add-DhHtmlBlock -Report $report -Id 'bullet-note' -NavPath 'Target' -Style 'info' -AllowHtml:$true `
    -Content '<b>Add-DhBullet</b> - one value against one target, per entity. The bar starts at the axis origin (unlike the range bar) and the tick is the target, not the average. Reach for it when there is an agreed number to hit; reach for the range bar when you care how much the value moves. Row dc04 shows the no-data state.'

# ===========================================================================
# MATRIX - Add-DhStatusGrid (categorical) and Add-DhHeatmap (numeric).
# ===========================================================================
$sites    = @('Milan','Rome','Dublin','Frankfurt')
$services = @('Auth','API','Database','Storage','Backup')
Add-DhStatusGrid -Report $report -Id 'grid-services' -NavPath 'Matrix' `
    -Title 'Service health by site' -RowLabel 'Service' -ColumnLabel 'Site' `
    -Rows $services -Columns $sites `
    -Cells @(
        foreach ($svc in $services) {
            foreach ($st in $sites) {
                $roll  = Get-Random -Maximum 10
                $state = if ($roll -lt 7) { 'ok' } elseif ($roll -lt 9) { 'warn' } else { 'danger' }
                @{ Row = $svc; Column = $st; Status = $state; Tooltip = "$svc @ $st" }
            }
        }
    )

Add-DhHeatmap -Report $report -Id 'heat-load' -NavPath 'Matrix' `
    -Title 'CPU load by day and hour (sequential)' `
    -RowLabel 'Day' -ColumnLabel 'Hour' -Unit '%' -ShowValues `
    -Rows @('Mon','Tue','Wed','Thu','Fri','Sat','Sun') `
    -Columns @('00','04','08','12','16','20') `
    -Cells @(
        foreach ($d in @('Mon','Tue','Wed','Thu','Fri','Sat','Sun')) {
            foreach ($h in @('00','04','08','12','16','20')) {
                $base = if ($d -in 'Sat','Sun') { 15 } elseif ($h -in '08','12','16') { 70 } else { 30 }
                @{ Row = $d; Column = $h; Value = $base + (Get-Random -Minimum -10 -Maximum 20) }
            }
        }
    )

Add-DhHeatmap -Report $report -Id 'heat-drift' -NavPath 'Matrix' `
    -Title 'Deviation from target (diverging)' -ColorScale 'diverging' `
    -RowLabel 'Service' -ColumnLabel 'Site' -Unit 'ms' -ShowValues `
    -Rows $services -Columns $sites `
    -Cells @(
        foreach ($svc in $services) {
            foreach ($st in $sites) {
                @{ Row = $svc; Column = $st; Value = Get-Random -Minimum -40 -Maximum 41 }
            }
        }
    )

Add-DhHtmlBlock -Report $report -Id 'matrix-note' -NavPath 'Matrix' -Style 'info' -AllowHtml:$true `
    -Content 'Two widgets, one shape. <b>Add-DhStatusGrid</b> when a cell is one of a few STATES (ok / warn / danger); <b>Add-DhHeatmap</b> when a cell is a NUMBER. Use <code>-ColorScale diverging</code> whenever zero is meaningful - deviation from target, growth vs decline - so the midpoint reads as neutral instead of as "medium".'

# ===========================================================================
# HIERARCHY - Add-DhTopologyMap.
# ===========================================================================
Add-DhTopologyMap -Report $report -Id 'topo-estate' -NavPath 'Hierarchy' `
    -Title 'vCenter - cluster - host' -Direction 'vertical' -AutoFitWidth `
    -Nodes @(
        @{ Id = 'vc';   Label = 'vcenter.corp.local'; Parent = $null; Status = 'ok';   Badge = 'VC' }
        @{ Id = 'c1';   Label = 'cluster01-users';    Parent = 'vc';  Status = 'ok';   Badge = 'Cl' }
        @{ Id = 'c2';   Label = 'cluster02-bigdata';  Parent = 'vc';  Status = 'warn'; Badge = 'Cl'; Tooltip = 'Memory pressure' }
        @{ Id = 'h1';   Label = 'esx01.corp.local';   Parent = 'c1';  Status = 'ok' }
        @{ Id = 'h2';   Label = 'esx02.corp.local';   Parent = 'c1';  Status = 'ok' }
        @{ Id = 'h3';   Label = 'esx03.corp.local';   Parent = 'c2';  Status = 'warn' }
        @{ Id = 'h4';   Label = 'esx04.corp.local';   Parent = 'c2';  Status = 'danger'; Tooltip = 'Host not responding' }
    )

Add-DhHtmlBlock -Report $report -Id 'topo-note' -NavPath 'Hierarchy' -Style 'info' -AllowHtml:$true `
    -Content '<b>Add-DhTopologyMap</b> - parent-child structure where the SHAPE matters: AD forest to domain to DC, vCenter to cluster to host. Status colours the node, so one glance shows both where a fault is and what sits under it. <code>-AutoFitWidth</code> stops FQDNs truncating.'

# ===========================================================================
# TIMELINE - Add-DhEventFeed.
# ===========================================================================
Add-DhEventFeed -Report $report -Id 'feed-audit' -NavPath 'Timeline' `
    -Title 'Recent operational events' -MaxItems 12 -SortDescending $true `
    -Events @(
        @{ Timestamp = (Get-Date).AddMinutes(-8);  Severity = 'critical'; Source = 'esx04'
           Message = 'Host not responding - HA failed over 12 VMs.' }
        @{ Timestamp = (Get-Date).AddMinutes(-42); Severity = 'warning';  Source = 'ds-prod-01'
           Message = 'Datastore 82% full - crossed the warning threshold.' }
        @{ Timestamp = (Get-Date).AddHours(-3);    Severity = 'ok';       Source = 'veeam01'
           Message = 'Backup completed: 412 VMs, 0 failures.' }
        @{ Timestamp = (Get-Date).AddHours(-9);    Severity = 'info';     Source = 'cluster02'
           Message = 'Patch window opened - entered maintenance mode.' }
        @{ Timestamp = (Get-Date).AddDays(-1);     Severity = 'ok';       Source = 'vcenter'
           Message = 'Certificate renewed, valid 12 months.' }
    )

Add-DhHtmlBlock -Report $report -Id 'feed-note' -NavPath 'Timeline' -Style 'info' -AllowHtml:$true `
    -Content '<b>Add-DhEventFeed</b> - what HAPPENED, in order, with severity. It answers "what changed?" where the charts answer "what is the state?". Pair it with the KPI strip as the bottom-of-page audit trail.'

# ===========================================================================
# IN-TABLE - the three cell visualisations, on one table.
# ===========================================================================
$hostRows = 1..8 | ForEach-Object {
    [pscustomobject]@{
        Hostname  = 'esx{0:D2}.corp.local' -f $_
        State     = @('Connected','Connected','Connected','Maintenance','Disconnected')[(Get-Random -Max 5)]
        CpuPct    = Get-Random -Minimum 12 -Maximum 96
        MemPct    = Get-Random -Minimum 30 -Maximum 99
        Last7Days = @(1..7 | ForEach-Object { Get-Random -Minimum 20 -Maximum 90 })
    }
}

Add-DhTable -Report $report -TableId 'hosts' -NavPath 'In-table' `
    -Title 'Hosts - progressbar, badge and sparkline cells' -PageSize 10 `
    -Data $hostRows -Columns @(
        @{ Field = 'Hostname'; Label = 'Host'; Width = '200px' }
        @{ Field = 'State';    Label = 'State'; Width = '150px'; CellType = 'badge'
           Thresholds = @(
               @{ Value = 'Connected';    Class = 'cell-ok'     }
               @{ Value = 'Maintenance';  Class = 'cell-warn'   }
               @{ Value = 'Disconnected'; Class = 'cell-danger' }
           ) }
        @{ Field = 'CpuPct';   Label = 'CPU';  Width = '170px'; CellType = 'progressbar'; ProgressMax = 100
           Rag = @{ Green = @{ Max = 70 }; Amber = @{ Min = 70; Max = 90 }; Red = @{ Min = 90 } } }
        @{ Field = 'MemPct';   Label = 'Memory'; Width = '170px'; CellType = 'progressbar'; ProgressMax = 100
           Rag = @{ Green = @{ Max = 70 }; Amber = @{ Min = 70; Max = 90 }; Red = @{ Min = 90 } } }
        @{ Field = 'Last7Days'; Label = 'CPU trend'; Width = '150px'; CellType = 'sparkline'; SparklineStyle = 'bars'; SortBy = 'avg' }
    )

Add-DhHtmlBlock -Report $report -Id 'cell-note' -NavPath 'In-table' -Style 'info' -AllowHtml:$true `
    -Content 'A table row can carry its own visuals: <code>CellType=''progressbar''</code> for a value against a max, <code>''badge''</code> for a state, <code>''sparkline''</code> for a per-row trend. These keep the detail next to the identifier instead of splitting it into a separate chart. Long values elsewhere in a table are clipped with an ellipsis - hover to read the full text, or drag the column edge to widen it.'

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser

Write-Host "Wrote: $OutputPath" -ForegroundColor Green
