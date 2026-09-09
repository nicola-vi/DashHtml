function Add-DhRangeBar {
    <#
    .SYNOPSIS
        Add a range-gradient bar chart - min / avg / max per category, normalised
        onto a shared 0-100 axis, coloured by position on that axis.

    .DESCRIPTION
        One horizontal floating bar per category:

          * the bar spans Min -> Max (it does NOT start at the axis origin)
          * a vertical tick marks Avg, positioned independently of the bar -
            it is deliberately NOT clamped inside [Min, Max], so an average
            computed over a different window shows up as the anomaly it is
          * every row is normalised against its own High value, so categories
            of wildly different magnitude become visually comparable
          * the fill is a fixed slice of ONE gradient spanning the whole track,
            so a bar's colour says where it sits on the 0-100 axis - not which
            category it is

        The gradient runs --accent-ok -> --accent-warn -> --accent-danger, so it
        follows whichever theme is active.

        Two ways to supply data, mutually exclusive:

          -Items     explicit rows (static)
          -TableId   derive rows from a table already added to the report.
                     Aggregation runs in the browser against the table's
                     FILTERED rows, so filtering the table live-recomputes the
                     ranges (same behaviour as Add-DhBarChart).

    .PARAMETER Report
        Dashboard object from New-DhDashboard.

    .PARAMETER Id
        Unique identifier (alphanumeric, dash, underscore).

    .PARAMETER Title
        Block heading shown above the chart.

    .PARAMETER Items
        Explicit rows. Array of hashtables, each requiring all six keys:

          @{
              Name = 'cluster01-users'   # row label (must be unique)
              Low  = 0                   # axis floor in real units
              High = 315                 # the value that maps to 100 on the axis
              Min  = 60                  # minimum observed
              Avg  = 97                  # average observed
              Max  = 120                 # maximum observed
          }

        Min / Avg / Max are real, un-normalised units. Normalisation to the
        0-100 axis happens at render time.

    .PARAMETER TableId
        Source table to aggregate. Must already be added with Add-DhTable.

    .PARAMETER CategoryField
        Column whose distinct values become the rows.

    .PARAMETER ValueField
        Numeric column aggregated into Min / Avg / Max within each category.

    .PARAMETER HighField
        Column carrying each row's own 100% reference (capacity, quota, ceiling).
        The maximum value seen within the category wins, so an inconsistent
        column cannot silently under-scale a bar. Highest precedence.

    .PARAMETER High
        One constant High for every row - the axis then reads as "% of a fixed
        ceiling". Used when -HighField is not given.

    .PARAMETER Low
        Axis floor in real units. Default 0.

    .PARAMETER LowField
        Per-category axis floor, the mirror of -HighField (minimum within the
        category wins). Overrides -Low.

    .PARAMETER MaxRows
        Guard against a category field with runaway cardinality. Throws when the
        table yields more distinct categories than this. Default 60.

    .PARAMETER AxisLabel
        Small right-aligned caption naming what 0-100 means. Auto-derived from
        the High source when not supplied - the one non-obvious mechanic a new
        reader needs spelled out.

    .PARAMETER Unit
        Suffix for the real-value labels and tooltip (e.g. 'req/s', 'ms', '%').

    .PARAMETER ShowDataTable
        Render a toggleable raw-values table under the chart (Low / High / Min /
        Avg / Max per row), off by default. The accessible / printable escape
        hatch, so every number is reachable without hovering.

    .EXAMPLE
        # Explicit rows
        Add-DhRangeBar -Report $report -Id 'cluster-load' -Title 'Cluster load range' `
            -Unit 'req/s' -ShowDataTable `
            -Items @(
                @{ Name='cluster01-users';   Low=0; High=315; Min=60; Avg=97; Max=120 }
                @{ Name='cluster02-bigdata'; Low=0; High=104; Min=1;  Avg=2;  Max=10  }
            )

    .EXAMPLE
        # Derived from a table, each cluster scaled against its own capacity
        Add-DhRangeBar -Report $report -Id 'cluster-load' -Title 'Cluster load range' `
            -TableId 'clusters' -CategoryField 'Cluster' `
            -ValueField 'LoadReqSec' -HighField 'CapacityReqSec' -Unit 'req/s'

    .EXAMPLE
        # Derived from a table against one fixed ceiling
        Add-DhRangeBar -Report $report -Id 'latency' -Title 'Latency range per site' `
            -TableId 'probes' -CategoryField 'Site' -ValueField 'RttMs' `
            -High 250 -Unit 'ms' -AxisLabel '% of 250 ms SLA'
    #>
    [CmdletBinding(DefaultParameterSetName = 'Items')]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string] $Id,
        [Parameter(Mandatory)] [string] $Title,

        # ---- Mode A: explicit rows ----
        [Parameter(Mandatory, ParameterSetName = 'Items')] [object[]] $Items,

        # ---- Mode B: aggregate from a table ----
        [Parameter(Mandatory, ParameterSetName = 'FromTable')] [string] $TableId,
        [Parameter(Mandatory, ParameterSetName = 'FromTable')] [string] $CategoryField,
        [Parameter(Mandatory, ParameterSetName = 'FromTable')] [string] $ValueField,
        [Parameter(ParameterSetName = 'FromTable')] [string] $HighField = '',
        [Parameter(ParameterSetName = 'FromTable')] [string] $LowField  = '',
        [Parameter(ParameterSetName = 'FromTable')] [Nullable[double]] $High = $null,
        [Parameter(ParameterSetName = 'FromTable')] [double] $Low = 0,
        [Parameter(ParameterSetName = 'FromTable')]
        [ValidateRange(1, 500)]
        [int] $MaxRows = 60,

        # ---- Presentation ----
        [string] $AxisLabel = '',
        [string] $Unit      = '',
        [switch] $ShowDataTable,
        [bool]   $Collapsible = $true,    # wrap the block in a collapsible header (chevron + click-to-toggle)
        [bool]   $DefaultOpen = $true,    # whether the collapsible body starts expanded (only used when -Collapsible is $true)
        [ValidateRange(0,12)]
        [int]    $GridSpan    = 0,   # v1.10.0 - columns (1-12) to span in -report-grid layout; 0 = default flow
        [string] $NavGroup    = '',
        [string] $NavSubGroup = '',
        # ---- v2.0.0 navigation (see readme-dev.md section 15) ----
        [string] $NavPath      = '',   # 'A/B/C' - where this item lives. '//' escapes a literal '/'
        [ValidateSet('','Exact','Subtree','Global')]
        [string] $NavScope     = '',   # Exact (default) | Subtree (this node and below) | Global (everywhere)
        [string] $NavLabel     = '',   # display text for this node, decoupled from the path key
        [int]    $NavOrder     = 0     # explicit sibling ordering; 0 = declaration order
    )

    # v2.0.0 - resolve nav declaration once, in one place. Throws if -NavPath is
    # combined with -NavGroup/-NavSubGroup rather than silently preferring one.
    $navDecl = Resolve-DhNavDeclaration -NavPath $NavPath -NavScope $NavScope `
                    -NavGroup $NavGroup -NavSubGroup $NavSubGroup `
                    -ItemKind 'Block' -Context 'Add-DhRangeBar'
    # Monotonic declaration number, shared by tables and blocks. The exporter
    # emits ALL blocks before ALL tables, so without this the menu would order
    # nodes by section type instead of by the order the author wrote them.
    if (-not $Report.Contains('_DhNavSeq')) { $Report['_DhNavSeq'] = 0 }
    $navSeqNo = [int]$Report['_DhNavSeq']; $Report['_DhNavSeq'] = $navSeqNo + 1

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhRangeBar: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }

    # Local InvariantCulture parser - a comma decimal separator in the host
    # culture must not turn 1.5 into 15.
    function _rbNum {
        param([object] $v, [string] $label, [string] $ctx)
        $n = 0.0
        $ok = [double]::TryParse(
            [string]$v,
            [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$n)
        if (-not $ok) {
            throw "Add-DhRangeBar: $ctx - $label must be a number, got: $v"
        }
        return $n
    }

    $mode      = $PSCmdlet.ParameterSetName
    $normItems = @()

    if ($mode -eq 'Items') {
        if (@($Items).Count -lt 1) {
            throw "Add-DhRangeBar: -Items must contain at least one row."
        }
        $seenNames = @{}
        $normItems = foreach ($item in $Items) {
            if ($item -isnot [hashtable] -and $item -isnot [System.Collections.Specialized.OrderedDictionary]) {
                throw "Add-DhRangeBar: each item must be a hashtable. Got: $($item.GetType().Name)"
            }
            foreach ($req in 'Name','Low','High','Min','Avg','Max') {
                if (-not $item.Contains($req) -or $null -eq $item[$req] -or [string]::IsNullOrWhiteSpace([string]$item[$req])) {
                    throw "Add-DhRangeBar: each item must have a non-empty '$req' key. Offending item: $($item['Name'])"
                }
            }
            $nm = [string]$item['Name']
            if ($seenNames.ContainsKey($nm)) {
                throw "Add-DhRangeBar: duplicate item Name '$nm'. Row names must be unique."
            }
            $seenNames[$nm] = $true

            $lo = _rbNum $item['Low']  'Low'  "item '$nm'"
            $hi = _rbNum $item['High'] 'High' "item '$nm'"
            $mn = _rbNum $item['Min']  'Min'  "item '$nm'"
            $av = _rbNum $item['Avg']  'Avg'  "item '$nm'"
            $mx = _rbNum $item['Max']  'Max'  "item '$nm'"

            # Spec 3.2 - never divide by zero and never silently clamp. Both
            # conditions surface as warnings so a data problem stays visible;
            # the renderer flags the degenerate row visually.
            if ($hi -le $lo) {
                Write-Warning "Add-DhRangeBar '$Id': item '$nm' has High ($hi) <= Low ($lo). The row will render muted at 0% - fix the source data."
            }
            elseif ($mx -gt $hi -or $mn -lt $lo) {
                Write-Warning "Add-DhRangeBar '$Id': item '$nm' has values outside its own scale (Low=$lo High=$hi Min=$mn Max=$mx). The bar clips at the axis edge; real numbers stay in the label and tooltip."
            }
            if ($mn -gt $mx) {
                Write-Warning "Add-DhRangeBar '$Id': item '$nm' has Min ($mn) > Max ($mx)."
            }

            [ordered]@{ Name = $nm; Low = $lo; High = $hi; Min = $mn; Avg = $av; Max = $mx }
        }
        $normItems = @($normItems)
    }
    else {
        # ---- FromTable: validate now, aggregate in the browser ----
        $tbl = $null
        if ($Report.Tables) { $tbl = $Report.Tables | Where-Object { $_.Id -eq $TableId } | Select-Object -First 1 }
        if (-not $tbl) {
            throw "Add-DhRangeBar: Source table '$TableId' not found. Add the table before the range bar."
        }
        if ($null -ne $High -and -not [string]::IsNullOrWhiteSpace($HighField)) {
            throw "Add-DhRangeBar: -High and -HighField are mutually exclusive. -HighField scales each row against its own ceiling; -High applies one ceiling to every row."
        }

        # Field names must exist, or the chart silently renders empty.
        $known = @{}
        foreach ($c in @($tbl.Columns)) { if ($c.Field) { $known[[string]$c.Field] = $true } }
        foreach ($r in @($tbl.Data))    { foreach ($k in $r.Keys) { $known[[string]$k] = $true } }
        foreach ($pair in @(
                @{ N = 'CategoryField'; V = $CategoryField },
                @{ N = 'ValueField';    V = $ValueField },
                @{ N = 'HighField';     V = $HighField },
                @{ N = 'LowField';      V = $LowField })) {
            if (-not [string]::IsNullOrWhiteSpace($pair.V) -and -not $known.ContainsKey($pair.V)) {
                throw "Add-DhRangeBar: -$($pair.N) '$($pair.V)' is not a column of table '$TableId'. Known fields: $(($known.Keys | Sort-Object) -join ', ')"
            }
        }

        # Cardinality + numeric sanity, reported once at generation time rather
        # than as a console.warn nobody will ever read.
        $cats     = @{}
        $badVals  = 0
        $totalRow = 0
        foreach ($r in @($tbl.Data)) {
            $totalRow++
            $cv = if ($null -ne $r[$CategoryField]) { [string]$r[$CategoryField] } else { '(empty)' }
            $cats[$cv] = $true
            $probe = 0.0
            $ok = [double]::TryParse(
                [string]$r[$ValueField],
                [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [ref]$probe)
            if (-not $ok) { $badVals++ }
        }
        if ($cats.Count -gt $MaxRows) {
            throw "Add-DhRangeBar: '$CategoryField' yields $($cats.Count) distinct categories, over -MaxRows ($MaxRows). Filter the table, pick a coarser field, or raise -MaxRows deliberately."
        }
        if ($badVals -gt 0 -and $badVals -lt $totalRow) {
            Write-Warning "Add-DhRangeBar '$Id': $badVals of $totalRow rows have a non-numeric '$ValueField' and will be skipped when aggregating."
        }
        if ($totalRow -gt 0 -and $badVals -eq $totalRow) {
            throw "Add-DhRangeBar: no row of table '$TableId' has a numeric '$ValueField'. The chart would render empty."
        }
        if ([string]::IsNullOrWhiteSpace($HighField) -and $null -eq $High) {
            Write-Verbose "Add-DhRangeBar: '$Id' - neither -HighField nor -High given; the axis will read as % of the largest '$ValueField' seen."
        }
    }

    # Spec section 6 - the caption must say what 0-100 means. Derive one when the
    # caller does not, so the chart is never shipped without it.
    $axisCaption = $AxisLabel
    if ([string]::IsNullOrWhiteSpace($axisCaption)) {
        $axisCaption =
            if ($mode -eq 'Items')                                 { '% of high' }
            elseif (-not [string]::IsNullOrWhiteSpace($HighField)) { "% of $HighField" }
            elseif ($null -ne $High)                               { "% of $High$(if ($Unit) { ' ' + $Unit })" }
            else                                                   { "% of max $ValueField" }
    }

    $Report.Blocks.Add([ordered]@{
        BlockType     = 'rangebar'
        Id            = $Id
        Title         = $Title
        Mode          = $(if ($mode -eq 'Items') { 'items' } else { 'fromtable' })
        Items         = $normItems
        TableId       = $TableId
        CategoryField = $CategoryField
        ValueField    = $ValueField
        HighField     = $HighField
        LowField      = $LowField
        High          = $High
        Low           = $Low
        MaxRows       = $MaxRows
        AxisLabel     = $axisCaption
        Unit          = $Unit
        ShowDataTable = [bool]$ShowDataTable
        NavGroup      = $NavGroup
        NavSubGroup   = $NavSubGroup
        NavPath       = $NavPath
        NavSegments   = $navDecl.Path
        NavSeqNo      = $navSeqNo
        NavScope      = $navDecl.Scope
        NavLabel      = $NavLabel
        NavOrder      = $NavOrder
        GridSpan      = $GridSpan
        Collapsible   = $Collapsible
        DefaultOpen   = $DefaultOpen
    })

    if ($mode -eq 'Items') {
        Write-Verbose "Add-DhRangeBar: '$Id' - $($normItems.Count) explicit rows."
    } else {
        Write-Verbose "Add-DhRangeBar: '$Id' - from table '$TableId' by '$CategoryField' over '$ValueField'."
    }
}
