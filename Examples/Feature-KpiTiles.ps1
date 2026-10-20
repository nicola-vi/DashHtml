#Requires -Version 7.0
<#
.SYNOPSIS
    KPI tiles: every style, trends, clicks, and where a strip appears.

.DESCRIPTION
    MENU
        Styles                       compact, big number, gauge, verdict, score ring, maturity ladder
        Trends                       change since last time, sparklines, number formats
        Clicks                       a tile that jumps to a filtered table
        Where strips appear          global strip, branch strip, view strip

    WHERE A STRIP APPEARS (the part people get wrong)
        * Add-DhSummary with no path is the GLOBAL strip: one per report, shown on every view.
        * Add-DhSummary -NavPath X -NavScope Subtree is a BRANCH strip: shown on X and every view
          below it. It is declared before the other blocks of the branch so it sits on top.
        * Add-DhSummary -NavPath X/Y (scope Exact) is a VIEW strip: shown on that view only.
        Open the three views under "Where strips appear" and watch the strips stack: global tiles
        first, then the branch strip, then the view strip, then the rest of the view.

.PARAMETER OutputPath
    Where to write the HTML.

.PARAMETER Theme
    Default, Azure, VMware, Grey, Company or Rag.

.PARAMETER OpenInBrowser
    Open the dashboard once generated.

.EXAMPLE
    PS> ./Examples/Feature-KpiTiles.ps1 -OpenInBrowser
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Feature-KpiTiles.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Default',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force

$note = { param([string] $Id, [string] $Path, [string] $Text) Add-DhHtmlBlock -Report $report -Id $Id -Title 'In this view' -Style info -NavPath $Path -Content $Text }
$utilRag = @{ Green = @{ Max = 70 }; Amber = @{ Min = 70; Max = 90 }; Red = @{ Min = 90 }; NoData = $true }
$report = New-DhDashboard -Title 'KPI tiles' -Subtitle 'Styles, trends, clicks and strips' -Theme $Theme -NavTitle 'KPI' -NavMaxDepth 2 -GeneratedBy 'Feature-KpiTiles.ps1'

# GLOBAL strip: on every view
Add-DhSummary -Report $report -Items @(
    @{ Label = 'Global tile A'; Value = 42 }
    @{ Label = 'Global tile B'; Value = '99.9%'; Class = 'cell-ok' } )

# ============================================================== STYLES
& $note 'n-styles' 'Styles' 'Pick the style by the question. Compact tile: a number. Big number: the one headline. Gauge: a value against a maximum with bands. Verdict: the overall answer and how many findings of each severity. Score: a ring out of a maximum with facts and a change. Maturity: which level, and what the next one needs.'
Add-DhSummary -Report $report -NavPath 'Styles' -Items @(
    @{ Label = 'Compact tile'; Value = 128; SubLabel = 'servers' }
    @{ Label = 'With a colour'; Value = 7; Class = 'cell-warn' }
    @{ Style = 'bignumber'; Label = 'Big number'; Value = '99.94%'; Caption = 'Target 99.9%, met'; Class = 'cell-ok' }
    @{ Style = 'gauge'; Label = 'CPU'; Value = 68; Max = 100; Unit = '%'; Rag = $utilRag }
    @{ Style = 'gauge'; Label = 'Disk'; Value = 93; Max = 100; Unit = '%'; Rag = $utilRag }
    @{ Style = 'verdict'; Label = 'Overall'; Value = 'Attention needed'; Caption = 'One critical finding and three warnings.'; Counts = @{ critical = 1; warning = 3; info = 2 } }
    @{ Style = 'score'; Label = 'Score'; Value = 78; Caption = 'Fair'; Previous = 74; Facts = @('64 checks', '9 failed'); NotAssessed = 6
       Rag = @{ Red = @{ Max = 50 }; Amber = @{ Min = 50; Max = 80 }; Green = @{ Min = 80 } } }
    @{ Style = 'score'; Label = 'Open exposures'; Value = 12; Max = 40; Caption = 'Down from 15'; Previous = 15; LowerIsBetter = $true
       Rag = @{ Green = @{ Max = 10 }; Amber = @{ Min = 10; Max = 25 }; Red = @{ Min = 25 } } }
    @{ Style = 'maturity'; Label = 'Maturity'; Value = 'Managed'; Current = 2; Caption = 'Monitoring is in place.'
       Levels = @(@{ Name = 'Initial'; Description = 'Ad hoc.' }, @{ Name = 'Managed'; Description = 'Monitored.' }, @{ Name = 'Defined'; Description = 'Documented.' }, @{ Name = 'Measured'; Description = 'Trended.' }, @{ Name = 'Optimised'; Description = 'Improving.' })
       Criteria = @(@{ Level = 3; Text = 'Write the build standard'; Met = $false }, @{ Level = 3; Text = 'Alert on every failure'; Met = $true }) } )

# ============================================================== TRENDS
& $note 'n-trends' 'Trends' 'Previous plus TrendIsGood draws an arrow and colours it: more lockouts is bad, more uptime is good. Sparkline adds a small history (line, area or bars). Format controls how the number reads.'
Add-DhSummary -Report $report -NavPath 'Trends' -Items @(
    @{ Label = 'Lockouts (1h)'; Value = 12; Previous = 18; TrendIsGood = $true; Sparkline = @(22, 18, 20, 14, 11, 12); SparklineStyle = 'line' }
    @{ Label = 'Errors'; Value = 3; Previous = 0; TrendIsGood = $false; Class = 'cell-warn'; Sparkline = @(0, 0, 1, 2, 2, 3); SparklineStyle = 'bars' }
    @{ Label = 'Revenue'; Value = 1240500; Previous = 1180000; TrendIsGood = $true; Format = 'currency'; Currency = 'EUR'; Locale = 'en-IE'; Decimals = 0; Sparkline = @(900, 960, 1020, 1100, 1180, 1240); SparklineStyle = 'area' }
    @{ Label = 'Success rate'; Value = 99.94; Previous = 99.92; Format = 'percent'; Decimals = 2; Class = 'cell-ok' }
    @{ Label = 'Transferred'; Value = 48200000000; Format = 'bytes' } )

# ============================================================== CLICKS
& $note 'n-clicks' 'Clicks' 'A tile with an Action is a button: it opens the view that holds the table and filters it. Click "Critical" and the table at the bottom of this view filters to critical alerts (from another view the same click would first open this one).'
Add-DhSummary -Report $report -NavPath 'Clicks' -Items @(
    @{ Label = 'Critical'; Value = 2; Class = 'cell-danger'; Action = @{ TableId = 'alerts'; Filter = 'Critical' } }
    @{ Label = 'Warning'; Value = 3; Class = 'cell-warn'; Action = @{ TableId = 'alerts'; Filter = 'Warning' } }
    @{ Label = 'All alerts'; Value = 6; Action = @{ TableId = 'alerts' } } )
Add-DhTable -Report $report -TableId 'alerts' -Title 'Alerts' -NavPath 'Clicks' -Data @(
    [pscustomobject]@{ Alert = 'Replication failed'; Severity = 'Critical' }, [pscustomobject]@{ Alert = 'Disk full'; Severity = 'Critical' }
    [pscustomobject]@{ Alert = 'High latency'; Severity = 'Warning' }, [pscustomobject]@{ Alert = 'Backup late'; Severity = 'Warning' }, [pscustomobject]@{ Alert = 'Certificate expiring'; Severity = 'Warning' }
    [pscustomobject]@{ Alert = 'Patch pending'; Severity = 'Info' } ) -Columns @(
        @{ Field = 'Alert'; Label = 'Alert' }
        @{ Field = 'Severity'; Label = 'Severity'; CellType = 'badge'; Thresholds = @(@{ Value = 'Critical'; Class = 'cell-danger' }, @{ Value = 'Warning'; Class = 'cell-warn' }, @{ Value = 'Info'; Class = 'cell-ok' }) } )

# ============================================================== WHERE STRIPS APPEAR
Add-DhSummary -Report $report -NavPath 'Strips' -NavLabel 'Where strips appear' -NavScope Subtree -Items @(
    @{ Label = 'Branch tile 1'; Value = 10 }, @{ Label = 'Branch tile 2'; Value = 20 } )

& $note 'n-strips-a' 'Strips/First' 'Top to bottom: the two GLOBAL tiles, then the BRANCH strip (declared at Strips with -NavScope Subtree, so it is on every view under Strips), then this note. This view has no strip of its own.'
Add-DhBarChart -Report $report -Id 'chart-a' -Title 'A chart on the first view' -NavPath 'Strips/First' -NavLabel 'First' -Stacked:$false -TableId 'alerts' -Field 'Severity'

Add-DhSummary -Report $report -NavPath 'Strips/Second' -NavLabel 'Second' -Items @(
    @{ Label = 'View tile 1'; Value = 1 }, @{ Label = 'View tile 2'; Value = 2 } )
& $note 'n-strips-b' 'Strips/Second' 'Here a third strip appears under the branch strip: a VIEW strip declared at Strips/Second with the default (exact) scope. It shows on this view only.'

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
