function Add-DhLineChart {
    <#
    .SYNOPSIS
        Add a line or area chart with axes, multi-series support, and an
        optional target / threshold annotation.

    .DESCRIPTION
        Renders a time-series style chart as a top-level block. Pure SVG, no
        external library. Single or multiple series share a common X-axis of
        category labels (timestamps, day names, etc.). Optional `-Filled`
        switches each series from a polyline to a filled area.

        Per the IT-infrastructure KPI dashboard specification (§7.4):
        "Always pair a time-series chart with a threshold annotation line."
        Use `-TargetLine` to draw a dashed horizontal reference at a Y value
        (SLA, alert threshold, capacity ceiling) plus an optional
        `-TargetLabel`.

    .PARAMETER Report
        Dashboard object from New-DhDashboard.

    .PARAMETER Id
        Unique identifier (alphanumeric, dash, underscore).

    .PARAMETER Title
        Chart heading shown above the plot.

    .PARAMETER XAxis
        Array of category labels for the X-axis (e.g. timestamps). Each
        series's Values must have the same length.

    .PARAMETER Series
        Array of series-definition hashtables:
          @{
              Label  = 'Avg CPU'                 # REQUIRED
              Values = @(42,38,55,67,71,68,52)   # REQUIRED — numeric, len == XAxis
              Class  = 'cell-ok'                 # optional — RAG class for line colour
              Color  = '#1B6B35'                 # optional — explicit colour override
          }

    .PARAMETER Filled
        Render each series as a filled area chart instead of a line.

    .PARAMETER TargetLine
        Optional numeric Y value — a dashed horizontal annotation line is
        drawn at this position. Use it for SLA / warning thresholds, capacity
        ceilings, alert lines.

    .PARAMETER TargetLabel
        Optional label text shown next to the target line.

    .PARAMETER YAxisMin / -YAxisMax
        Explicit Y-axis bounds. When omitted, the chart auto-fits from the
        series data (with a small padding above the max).

    .PARAMETER YAxisUnit
        Optional suffix appended to Y-axis tick labels (e.g. '%', 'ms', 'GB').

    .PARAMETER ShowLegend
        Show a legend strip below the chart with one swatch per series.
        Defaults to $true.

    .PARAMETER ShowGrid
        Show horizontal gridlines at each Y-axis tick. Defaults to $true.

    .PARAMETER Height
        Pixel height of the SVG. Defaults to 240.

    .EXAMPLE
        # Single series with a warning-threshold line
        Add-DhLineChart -Report $report -Id 'cpu-trend' -Title 'Cluster CPU (24h)' `
            -XAxis @('00:00','04:00','08:00','12:00','16:00','20:00','24:00') `
            -Series @(
                @{ Label='Avg'; Values=@(42,38,55,67,71,68,52); Class='cell-ok' }
            ) `
            -TargetLine 70 -TargetLabel 'Warning threshold' `
            -YAxisMax 100 -YAxisUnit '%'

    .EXAMPLE
        # Multi-series filled area chart
        Add-DhLineChart -Report $report -Id 'net-bw' -Title 'Network throughput' `
            -Filled `
            -XAxis $hours `
            -Series @(
                @{ Label='Ingress'; Values=$ingress; Class='cell-ok'   }
                @{ Label='Egress';  Values=$egress;  Class='cell-warn' }
            )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string] $Id,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [object[]] $XAxis,
        [Parameter(Mandatory)] [object[]] $Series,

        [switch] $Filled,
        [object] $TargetLine = $null,
        [string] $TargetLabel = '',

        [object] $YAxisMin = $null,
        [object] $YAxisMax = $null,
        [string] $YAxisUnit = '',

        [bool]   $ShowLegend = $true,
        [bool]   $ShowGrid   = $true,
        [ValidateRange(80, 1000)]
        [int]    $Height     = 240,

        [string] $NavGroup    = '',
        [string] $NavSubGroup = ''
    )

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }

    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhLineChart: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }

    if ($XAxis.Count -lt 2) {
        throw "Add-DhLineChart: -XAxis must contain at least 2 labels (got $($XAxis.Count))."
    }
    if (-not $Series -or $Series.Count -lt 1) {
        throw "Add-DhLineChart: -Series must contain at least one series."
    }

    # Local InvariantCulture number parser
    function _tryNum {
        param([object] $v, [string] $label, [string] $ctx)
        $n = 0.0
        $ok = [double]::TryParse(
            [string]$v,
            [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$n)
        if (-not $ok) {
            throw "Add-DhLineChart: $ctx — $label must be a number, got: $v"
        }
        return $n
    }

    $normSeries = foreach ($s in $Series) {
        if ($s -isnot [hashtable] -and $s -isnot [System.Collections.Specialized.OrderedDictionary]) {
            throw "Add-DhLineChart: each series entry must be a hashtable. Got: $($s.GetType().Name)"
        }
        if (-not $s.Contains('Label') -or [string]::IsNullOrWhiteSpace([string]$s['Label'])) {
            throw "Add-DhLineChart: each series must have a non-empty 'Label' key."
        }
        if (-not $s.Contains('Values') -or $null -eq $s['Values']) {
            throw "Add-DhLineChart: series '$($s.Label)' must have a 'Values' key."
        }
        $vals = @($s['Values'])
        if ($vals.Count -ne $XAxis.Count) {
            throw "Add-DhLineChart: series '$($s.Label)' has $($vals.Count) Values but XAxis has $($XAxis.Count) labels. Lengths must match."
        }
        $numVals = foreach ($v in $vals) {
            if ($null -eq $v -or [string]::IsNullOrWhiteSpace([string]$v)) {
                # Null entries are allowed — JS plots them as line breaks (NaN)
                [double]::NaN
            } else {
                _tryNum $v "series '$($s.Label)' value" "Add-DhLineChart"
            }
        }
        @{
            Label = [string]$s['Label']
            Values = @($numVals)
            Class  = if ($s.Contains('Class') -and $s['Class']) { [string]$s['Class'] } else { '' }
            Color  = if ($s.Contains('Color') -and $s['Color']) { [string]$s['Color'] } else { '' }
        }
    }

    # Optional numerics
    $tlNum   = if ($null -ne $TargetLine) { _tryNum $TargetLine 'TargetLine' 'Add-DhLineChart' } else { $null }
    $yMinNum = if ($null -ne $YAxisMin)   { _tryNum $YAxisMin   'YAxisMin'   'Add-DhLineChart' } else { $null }
    $yMaxNum = if ($null -ne $YAxisMax)   { _tryNum $YAxisMax   'YAxisMax'   'Add-DhLineChart' } else { $null }
    if (($null -ne $yMinNum) -and ($null -ne $yMaxNum) -and ($yMaxNum -le $yMinNum)) {
        throw "Add-DhLineChart: -YAxisMax ($yMaxNum) must be greater than -YAxisMin ($yMinNum)."
    }

    # Normalise XAxis to strings
    $xAxisOut = @($XAxis | ForEach-Object { [string]$_ })

    $Report.Blocks.Add([ordered]@{
        BlockType   = 'linechart'
        Id          = $Id
        Title       = $Title
        XAxis       = $xAxisOut
        Series      = @($normSeries)
        Filled      = [bool]$Filled
        TargetLine  = $tlNum
        TargetLabel = $TargetLabel
        YAxisMin    = $yMinNum
        YAxisMax    = $yMaxNum
        YAxisUnit   = $YAxisUnit
        ShowLegend  = $ShowLegend
        ShowGrid    = $ShowGrid
        Height      = $Height
        NavGroup    = $NavGroup
        NavSubGroup = $NavSubGroup
    })
    Write-Verbose "Add-DhLineChart: '$Id' ($($normSeries.Count) series, $($xAxisOut.Count) X-points$(if ($Filled) { ', filled' })$(if ($tlNum) { ', target=$tlNum' }))."
}
