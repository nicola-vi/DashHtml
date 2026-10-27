#Requires -Version 7.0
<#
.SYNOPSIS
    Every chart type, and when to use which.

.DESCRIPTION
    MENU
        Bars
            Count                    how many rows per category (the table is the source)
            Measure a value          sum, average, min or max of a column, per category
            Stacked and coloured     a second dimension, colours by value or by name
        Pies
            Pie and donut            share of a whole; click a slice to filter the table
        Lines
            Trends                   several series, filled areas, a target line
        Targets
            Bullets                  actual against target, with bands
            Ranges                   min, average and max per entity on one axis

    Charts that read a table (bars, pies, ranges) are declared AFTER the table but are drawn
    ABOVE it: blocks come first on a view, tables last. Charts you give explicit numbers (slices,
    series, bullets) need no table.

.PARAMETER OutputPath
    Where to write the HTML.

.PARAMETER Theme
    Default, Azure, VMware, Grey, Company or Rag.

.PARAMETER OpenInBrowser
    Open the dashboard once generated.

.EXAMPLE
    PS> ./Examples/Feature-Charts.ps1 -OpenInBrowser
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Feature-Charts.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Default',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force

$rng = [System.Random]::new(21)
$note = { param([string] $Id, [string] $Path, [string] $Text) Add-DhHtmlBlock -Report $report -Id $Id -Title 'When to use it' -Style info -NavPath $Path -Content $Text -AllowHtml:$false }
$hours = @('00:00', '04:00', '08:00', '12:00', '16:00', '20:00')

$vms = foreach ($i in 1..60) {
    [pscustomobject]@{
        Name = 'vm-{0:000}' -f $i; Cluster = @('prod', 'dev', 'test')[$i % 3]; Role = @('app', 'db', 'web', 'infra')[$i % 4]
        Power = @('On', 'On', 'On', 'Off')[$i % 4]; CpuPct = 5 + $rng.Next(0, 92); MemGB = 4 * (1 + $rng.Next(0, 16))
        Severity = @('Critical', 'High', 'Medium', 'Low')[$i % 4]
    }
}

$report = New-DhDashboard -Title 'Charts' -Subtitle 'Bars, pies, lines, bullets and ranges' -Theme $Theme -NavTitle 'Charts' -NavMaxDepth 2 -GeneratedBy 'Feature-Charts.ps1'

# One table feeds the bars, the pie and the range chart; it is shown on the first view of each group.
Add-DhTable -Report $report -TableId 'vms' -Title 'Virtual machines (the source of the charts above)' -NavPath 'Bars/Count' -PageSize 6 -Data $vms -Columns @(
    @{ Field = 'Name'; Label = 'VM' }, @{ Field = 'Cluster'; Label = 'Cluster' }, @{ Field = 'Role'; Label = 'Role' }, @{ Field = 'Power'; Label = 'Power' }
    @{ Field = 'CpuPct'; Label = 'CPU %'; Align = 'right' }, @{ Field = 'MemGB'; Label = 'Memory (GB)'; Align = 'right' } )

# ============================================================== BARS
& $note 'n-count' 'Bars/Count' 'Count rows per category: how many VMs per cluster. TopN keeps the biggest categories. ShowPercent adds the share. ClickFilters turns a bar into a filter on the table below.'
Add-DhBarChart -Report $report -Id 'bar-count' -Title 'VMs per cluster' -NavPath 'Bars/Count' -NavLabel 'Count' -TableId 'vms' -Field 'Cluster' -ShowPercent -ClickFilters
Add-DhBarChart -Report $report -Id 'bar-top' -Title 'Top 3 roles' -NavPath 'Bars/Count' -TableId 'vms' -Field 'Role' -TopN 3 -ShowCount $true

& $note 'n-measure' 'Bars/Measure a value' 'Give -ValueField and -Aggregate (sum, avg, min or max) to chart a number, not a row count: average CPU per cluster, total memory per role. -Rag colours each bar by its value.'
Add-DhBarChart -Report $report -Id 'bar-avg' -Title 'Average CPU by cluster' -NavPath 'Bars/Measure a value' -NavLabel 'Measure a value' -TableId 'vms' -Field 'Cluster' `
    -ValueField 'CpuPct' -Aggregate avg -Unit '%' -Decimals 0 -Rag @{ Green = @{ Max = 50 }; Amber = @{ Min = 50; Max = 75 }; Red = @{ Min = 75 } }
Add-DhBarChart -Report $report -Id 'bar-sum' -Title 'Total memory by role (GB)' -NavPath 'Bars/Measure a value' -TableId 'vms' -Field 'Role' -ValueField 'MemGB' -Aggregate sum -Unit 'GB'

& $note 'n-stack' 'Bars/Stacked and coloured' 'SeriesField with -Stacked splits each bar by a second column. -KeyClass colours a bar by its name (Critical red, Low green), which a single accent colour cannot do.'
Add-DhBarChart -Report $report -Id 'bar-stack' -Title 'VMs per role, by power state' -NavPath 'Bars/Stacked and coloured' -NavLabel 'Stacked and coloured' -TableId 'vms' -Field 'Role' -SeriesField 'Power' -Stacked
Add-DhBarChart -Report $report -Id 'bar-key' -Title 'VMs by severity' -NavPath 'Bars/Stacked and coloured' -TableId 'vms' -Field 'Severity' `
    -KeyClass @{ Critical = 'cell-danger'; High = 'cell-danger'; Medium = 'cell-warn'; Low = 'cell-ok' }

# ============================================================== PIES
& $note 'n-pie' 'Pies/Pie and donut' 'Use a pie for a share of a whole with few slices. From a table (left) it counts a column and a click on a slice filters the table; with explicit slices (right) you give the numbers. Donut shows the total in the middle.'
Add-DhTable -Report $report -TableId 'vms-pie' -Title 'Virtual machines (click a slice to filter)' -NavPath 'Pies/Pie and donut' -PageSize 5 -Data $vms -Columns @(
    @{ Field = 'Name'; Label = 'VM' }, @{ Field = 'Cluster'; Label = 'Cluster' }, @{ Field = 'Power'; Label = 'Power' }, @{ Field = 'CpuPct'; Label = 'CPU %'; Align = 'right' } )
Add-DhPieChart -Report $report -Id 'pie-table' -Title 'Power state (from the table below)' -NavPath 'Pies/Pie and donut' -NavLabel 'Pie and donut' -TableId 'vms-pie' -Field 'Power' -Style donut -ClickFilters
Add-DhPieChart -Report $report -Id 'pie-slices' -Title 'Account states (explicit numbers)' -NavPath 'Pies/Pie and donut' -Style pie -Slices @(
    @{ Label = 'Enabled'; Value = 15420; Color = '#375623' }, @{ Label = 'Disabled'; Value = 820; Color = '#7F4B00' }
    @{ Label = 'Locked'; Value = 42; Color = '#9C0006' }, @{ Label = 'Stale'; Value = 214; Color = '#595959' } )

# ============================================================== LINES
& $note 'n-line' 'Lines/Trends' 'Several series on one axis; -Filled draws areas (keep it to one to three series); -TargetLine draws a threshold. A $null in a series leaves a gap rather than a zero.'
Add-DhLineChart -Report $report -Id 'line-multi' -Title 'Requests per second' -NavPath 'Lines/Trends' -NavLabel 'Trends' -XAxis $hours -YAxisMin 0 -YAxisUnit ' req/s' -Series @(
    @{ Label = 'API';    Values = @(120, 90, 480, 760, 820, 300); Class = 'cell-ok' }
    @{ Label = 'Web';    Values = @(200, 140, 620, 980, 1010, 480); Color = '#4B5B6B' }
    @{ Label = 'Batch';  Values = @(30, 600, 80, 40, 20, 10); Class = 'cell-warn' } )
Add-DhLineChart -Report $report -Id 'line-target' -Title 'Latency against the objective' -NavPath 'Lines/Trends' -Filled -XAxis $hours -YAxisMin 0 -YAxisUnit ' ms' `
    -TargetLine 250 -TargetLabel 'Objective 250 ms' -Series @(
        @{ Label = 'p95'; Values = @(120, 110, 180, 260, 310, $null); Class = 'cell-warn' } )

# ============================================================== TARGETS
& $note 'n-bullet' 'Targets/Bullets' 'A bullet chart answers "how far from the target, and is that good?": the bar is the value, the tick is the target, the bands are green, amber and red. Reverse the bands when higher is better (free space) or lower is better (latency).'
Add-DhBullet -Report $report -Id 'bullets' -Title 'Free disk space against the 30% target' -NavPath 'Targets/Bullets' -NavLabel 'Bullets' -Items @(
    foreach ($d in @(@('dc01', 78), @('dc02', 82), @('dc03', 18), @('fs01', 41), @('sql01', 12))) {
        @{ Label = $d[0]; Value = $d[1]; Target = 30; Min = 0; Max = 100; Unit = '%'; Rag = @{ Green = @{ Min = 30 }; Amber = @{ Min = 15; Max = 30 }; Red = @{ Max = 15 } } }
    } )

& $note 'n-range' 'Targets/Ranges' 'A range bar shows min, average and max of each entity on one shared axis, each scaled against its own capacity (High). It reads a table and recomputes live when the table is filtered, or takes explicit items as here.'
Add-DhRangeBar -Report $report -Id 'ranges' -Title 'CPU range per cluster' -NavPath 'Targets/Ranges' -NavLabel 'Ranges' -Unit '%' -ShowDataTable -Items @(
    @{ Name = 'prod'; Low = 0; High = 100; Min = 12; Avg = 44; Max = 91 }
    @{ Name = 'dev';  Low = 0; High = 100; Min = 2;  Avg = 18; Max = 55 }
    @{ Name = 'test'; Low = 0; High = 100; Min = 1;  Avg = 9;  Max = 40 } )

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
