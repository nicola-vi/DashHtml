function Add-DhHeatmap {
    <#
    .SYNOPSIS
        Add a heatmap block — 2D grid with a sequential or diverging colour scale.

    .DESCRIPTION
        Renders a rows × columns matrix where each cell is coloured by its
        numeric value via a continuous colour scale. This is the canonical
        "Heatmap" widget from the IT-infrastructure KPI dashboard specification
        (§2): time-of-day patterns, replication-lag matrices, latency by
        endpoint × hour, request volume by region × day.

        **Distinct from Add-DhStatusGrid**: StatusGrid is CATEGORICAL (cells
        carry a state like ok / warn / danger). Heatmap is CONTINUOUS (cells
        carry a numeric value mapped to a colour gradient).

        Two colour scales:
          'sequential' (default) — single-hue gradient from light to dark.
                                   Use for "more is more": request counts,
                                   latency, error counts.
          'diverging'            — three-stop gradient red → neutral → green.
                                   Use for "deviation from a centre":
                                   actual-vs-target deltas, drift, A/B lift.

        Cells you don't declare render as a faint "no data" state.

    .PARAMETER Report
        Dashboard object from New-DhDashboard.

    .PARAMETER Id
        Unique identifier (alphanumeric, dash, underscore).

    .PARAMETER Title
        Block heading shown above the matrix.

    .PARAMETER Rows
        Array of row labels (Y-axis).

    .PARAMETER Columns
        Array of column labels (X-axis).

    .PARAMETER Cells
        Array of cell hashtables:
          @{
              Row    = 'DC01'           # REQUIRED — must appear in -Rows
              Column = '14:00'          # REQUIRED — must appear in -Columns
              Value  = 42               # REQUIRED — numeric (the heat)
              Tooltip = 'avg over 5m'   # optional — extra text in hover tooltip
          }

    .PARAMETER RowLabel       Optional caption for the Y-axis.
    .PARAMETER ColumnLabel    Optional caption for the X-axis.

    .PARAMETER ColorScale
        'sequential' (default) | 'diverging'.

    .PARAMETER Min
        Lower bound of the colour scale. Auto-fits from data when omitted.

    .PARAMETER Max
        Upper bound of the colour scale. Auto-fits from data when omitted.

    .PARAMETER Unit
        Optional suffix appended to values in hover tooltips ('ms', '%', etc).

    .PARAMETER CellSize
        Cell side length preset: 'small' (24 px) | 'normal' (36 px, default) | 'large' (48 px).

    .PARAMETER ShowValues
        When set, the numeric value is printed inside each cell. Useful for
        small grids where the colour alone isn't precise enough.

    .PARAMETER MaxCells
        Hard ceiling on Rows × Columns. Default 5000 (heatmaps can be larger
        than StatusGrids since cells are smaller). Throws above this.

    .PARAMETER NavGroup       Primary nav group label (enables two-tier nav).
    .PARAMETER NavSubGroup    Optional second-level group under NavGroup.

    .EXAMPLE
        # Replication latency per DC pair × hour (24h)
        $hours = 0..23 | ForEach-Object { '{0:00}:00' -f $_ }
        Add-DhHeatmap -Report $report -Id 'repl-latency-heat' `
            -Title 'Replication latency (ms) — DC pair × hour' `
            -RowLabel 'DC pair' -ColumnLabel 'Hour' `
            -Rows    @('DC01→DC02','DC01→DC03','DC02→DC03') `
            -Columns $hours `
            -Cells   $latencyCells `
            -ColorScale 'sequential' -Unit ' ms' -Min 0 -Max 100
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string] $Id,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [object[]] $Rows,
        [Parameter(Mandatory)] [object[]] $Columns,
        [Parameter(Mandatory)] [object[]] $Cells,

        [string] $RowLabel    = '',
        [string] $ColumnLabel = '',

        [ValidateSet('sequential','diverging')]
        [string] $ColorScale = 'sequential',

        [object] $Min  = $null,
        [object] $Max  = $null,
        [string] $Unit = '',

        [ValidateSet('small','normal','large')]
        [string] $CellSize = 'normal',

        [switch] $ShowValues,

        [ValidateRange(1, 200000)]
        [int]    $MaxCells = 5000,

        [string] $NavGroup    = '',
        [string] $NavSubGroup = ''
    )

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhHeatmap: A block with Id '$Id' already exists in this report."
        }
    }
    if ($Rows.Count -lt 1)    { throw "Add-DhHeatmap: -Rows must contain at least one label."    }
    if ($Columns.Count -lt 1) { throw "Add-DhHeatmap: -Columns must contain at least one label." }

    $totalCells = $Rows.Count * $Columns.Count
    if ($totalCells -gt $MaxCells) {
        throw "Add-DhHeatmap: Rows × Columns = $totalCells exceeds -MaxCells ($MaxCells). Split the matrix or raise -MaxCells deliberately."
    }
    if ($totalCells -gt 1000) {
        Write-Warning "Add-DhHeatmap: $totalCells cells is dense ($($Rows.Count) × $($Columns.Count)) — consider splitting into smaller grouped heatmaps for legibility."
    }

    # Normalise axes and lookup sets
    $rowList = @($Rows    | ForEach-Object { [string]$_ })
    $colList = @($Columns | ForEach-Object { [string]$_ })
    $rowSet  = @{}
    $colSet  = @{}
    foreach ($r in $rowList) { $rowSet[$r] = $true }
    foreach ($c in $colList) { $colSet[$c] = $true }

    # Local InvariantCulture parser
    function _tryNum {
        param([object] $v, [string] $label, [string] $ctx)
        $n = 0.0
        $ok = [double]::TryParse(
            [string]$v,
            [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$n)
        if (-not $ok) {
            throw "Add-DhHeatmap: $ctx — $label must be a number, got: $v"
        }
        return $n
    }

    $normCells = foreach ($cell in $Cells) {
        if ($cell -isnot [hashtable] -and $cell -isnot [System.Collections.Specialized.OrderedDictionary]) {
            throw "Add-DhHeatmap: each cell must be a hashtable. Got: $($cell.GetType().Name)"
        }
        foreach ($req in 'Row','Column','Value') {
            if (-not $cell.Contains($req) -or $null -eq $cell[$req]) {
                throw "Add-DhHeatmap: each cell must have a non-empty '$req' key."
            }
        }
        $r = [string]$cell['Row']
        $c = [string]$cell['Column']
        if (-not $rowSet.ContainsKey($r)) {
            throw "Add-DhHeatmap: cell Row '$r' is not in -Rows."
        }
        if (-not $colSet.ContainsKey($c)) {
            throw "Add-DhHeatmap: cell Column '$c' is not in -Columns."
        }
        $v = _tryNum $cell['Value'] 'Value' "cell ($r, $c)"
        @{
            Row     = $r
            Column  = $c
            Value   = $v
            Tooltip = if ($cell.Contains('Tooltip') -and $null -ne $cell['Tooltip']) { [string]$cell['Tooltip'] } else { '' }
        }
    }

    # Optional Min/Max bounds
    $minNum = if ($null -ne $Min) { _tryNum $Min 'Min' 'Add-DhHeatmap' } else { $null }
    $maxNum = if ($null -ne $Max) { _tryNum $Max 'Max' 'Add-DhHeatmap' } else { $null }
    if (($null -ne $minNum) -and ($null -ne $maxNum) -and ($maxNum -le $minNum)) {
        throw "Add-DhHeatmap: -Max ($maxNum) must be greater than -Min ($minNum)."
    }

    $Report.Blocks.Add([ordered]@{
        BlockType   = 'heatmap'
        Id          = $Id
        Title       = $Title
        Rows        = $rowList
        Columns     = $colList
        Cells       = @($normCells)
        RowLabel    = $RowLabel
        ColumnLabel = $ColumnLabel
        ColorScale  = $ColorScale
        Min         = $minNum
        Max         = $maxNum
        Unit        = $Unit
        CellSize    = $CellSize
        ShowValues  = [bool]$ShowValues
        NavGroup    = $NavGroup
        NavSubGroup = $NavSubGroup
    })
    Write-Verbose "Add-DhHeatmap: '$Id' ($($rowList.Count) × $($colList.Count), $(@($normCells).Count) cells, scale=$ColorScale)."
}
