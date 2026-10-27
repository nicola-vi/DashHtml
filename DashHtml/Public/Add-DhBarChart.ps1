function Add-DhBarChart {
    <#
    .SYNOPSIS
        Add a horizontal bar chart aggregating values from a table field.

    .DESCRIPTION
        Groups the source table's rows by -Field and draws one horizontal bar per
        group, top-N, largest first. By default each bar is the number of rows in
        the group. From 2.2.0, -ValueField with -Aggregate sum|avg|min|max draws
        the sum / average / minimum / maximum of a numeric column instead.
        Aggregation runs in the browser over the table's FILTERED rows, so the
        chart follows every filter.

        The chart renders as a standalone block in the dashboard flow and is
        re-calculated at page load from the table's full dataset.

    .PARAMETER Report       Dashboard object from New-DhDashboard.
    .PARAMETER Id           Unique identifier (alphanumeric, - or _).
    .PARAMETER Title        Chart heading.
    .PARAMETER TableId      Source table to aggregate (must already be added).
    .PARAMETER Field        Primary aggregation field — defines the bars.
    .PARAMETER TopN         Maximum bars to display (default 10).
    .PARAMETER ShowCount    Show the count number beside each bar (default $true).
    .PARAMETER ShowPercent  Show the percentage of total beside each bar (default $false).
    .PARAMETER ClickFilters When $true, clicking a bar sets the source table's text filter.
                            (Single-series mode only — ignored when -Stacked.)

    .PARAMETER ValueField   v2.2.0. Numeric column to aggregate per bar instead of
                            counting rows. Must be a field of the table (hidden
                            properties count). Non-numeric values are ignored.
    .PARAMETER Aggregate    v2.2.0. count (default) | sum | avg | min | max.
                            Anything but count needs -ValueField; -ValueField on
                            its own means sum. With -Stacked only count and sum
                            are allowed. Percentages (-ShowPercent) are a share
                            of the row count for count, of the grand total for
                            sum, and are not shown for avg / min / max.
    .PARAMETER Unit         v2.2.0. Suffix for aggregated values, e.g. 'ms', 'GB'.
    .PARAMETER Decimals     v2.2.0. Fixed decimal places for aggregated values
                            (default: up to 2 for avg, 3 otherwise).

    .PARAMETER Stacked      v1.4+ switch. When set, each primary bar is split
                            into colour-coded segments by -SeriesField. Useful
                            for resource breakdowns (e.g. items per Region
                            stacked by Status). A legend appears below the chart.

    .PARAMETER SeriesField  v1.4+ required when -Stacked is set. The categorical
                            field that subdivides each primary bar.

    .EXAMPLE
        # Show distribution of a categorical field
        Add-DhBarChart -Report $report -Id 'type-chart' `
            -Title 'Top 10 Item Types' `
            -TableId 'inventory' -Field 'Type' -TopN 10 `
            -ShowCount $true -ShowPercent $true

    .EXAMPLE
        # Clicking a bar filters the source table
        Add-DhBarChart -Report $report -Id 'status-chart' `
            -Title 'Items by Status' `
            -TableId 'items' -Field 'Status' -TopN 5 `
            -ClickFilters $true

    .EXAMPLE
        # v2.2.0 - average replication lag per DC, in minutes
        Add-DhBarChart -Report $report -Id 'repl-lag' -Title 'Replication lag by DC' `
            -TableId 'repl' -Field 'DC' -ValueField 'LagMinutes' -Aggregate avg -Unit 'min' -Decimals 1

    .PARAMETER Rag
        v2.3.0. Colour each bar by its value, with the same Green / Amber / Red bands as
        a gauge or a table column. Use it with -ValueField (average lag, size) or for
        counts. Ignored on a stacked chart.
    .PARAMETER KeyClass
        v2.3.0. Colour each bar by its category: @{ Critical='cell-danger'; Medium='cell-warn' }.
        Classes: cell-ok, cell-warn, cell-danger, cell-nodata. Wins over -Rag. Categories
        that are not listed keep the default colour. Ignored on a stacked chart.

    .EXAMPLE
        # v2.3.0 - bars coloured by severity, so the critical row stands out
        Add-DhBarChart -Report $report -Id 'by-sev' -Title 'Findings by severity' `
            -TableId 'findings' -Field 'Severity' `
            -KeyClass @{ Critical='cell-danger'; High='cell-danger'; Medium='cell-warn'; Low='cell-ok' }

    .EXAMPLE
        # v1.4 — stacked: items per Region, segments coloured by Status
        Add-DhBarChart -Report $report -Id 'by-region-stacked' `
            -Title 'Items by Region (stacked by Status)' `
            -TableId 'items' -Field 'Region' -SeriesField 'Status' -Stacked
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string] $Id,
        [Parameter(Mandatory)] [string]    $Title,
        [Parameter(Mandatory)] [string]    $TableId,
        [Parameter(Mandatory)] [string]    $Field,
        [ValidateRange(1, [int]::MaxValue)]
        [int]    $TopN         = 10,
        [bool]   $ShowCount    = $true,
        [switch] $ShowPercent,
        [switch] $ClickFilters,
        [switch] $Stacked,
        [string] $SeriesField    = '',
        # ---- v2.2.0 value aggregation ----
        [string] $ValueField     = '',
        [ValidateSet('','count','sum','avg','min','max')]
        [string] $Aggregate      = '',
        [string] $Unit           = '',
        [ValidateRange(-1, 10)]
        [int]    $Decimals       = -1,
        # ---- v2.3.0 bar colours (single-series bars only) ----
        [System.Collections.IDictionary] $Rag      = $null,   # value bands: @{ Green=@{Max=10}; Amber=@{Min=10;Max=25}; Red=@{Min=25} }
        [System.Collections.IDictionary] $KeyClass = $null,   # category -> class: @{ Critical='cell-danger'; Low='cell-ok' }
        [bool]   $Collapsible = $true,    # wrap the block in a collapsible header (chevron + click-to-toggle)
        [bool]   $DefaultOpen = $true,    # whether the collapsible body starts expanded (only used when -Collapsible is $true)
        [ValidateRange(0,12)]
        [int]    $GridSpan    = 0,   # v1.10.0 - columns (1-12) to span in -report-grid layout; 0 = default flow
        [string] $NavGroup       = '',   # primary nav group label (enables two-tier nav)
        [string] $NavSubGroup    = '',    # optional second-level group under NavGroup (enables three-tier nav)
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
                    -ItemKind 'Block' -Context 'Add-DhBarChart'
    # Monotonic declaration number, shared by tables and blocks. The exporter
    # emits ALL blocks before ALL tables, so without this the menu would order
    # nodes by section type instead of by the order the author wrote them.
    if (-not $Report.Contains('_DhNavSeq')) { $Report['_DhNavSeq'] = 0 }
    $navSeqNo = [int]$Report['_DhNavSeq']; $Report['_DhNavSeq'] = $navSeqNo + 1

    # With no table declared yet the check is skipped: declaring the chart
    # first works (the runtime renders it after every table engine exists).
    # A TableId that never gets a table is reported by Export-DhDashboard's
    # link lint (v2.1.4), whatever the declaration order.
    if ($Report.Tables -and -not ($Report.Tables | Where-Object { $_.Id -eq $TableId })) {
        throw "Add-DhBarChart: Source table '$TableId' not found. Add the table before the bar chart."
    }

    # v1.4 — stacked mode requires SeriesField; if user passed SeriesField without
    # -Stacked we silently turn stacking on for them (least-surprising default).
    if ($Stacked -and [string]::IsNullOrWhiteSpace($SeriesField)) {
        throw "Add-DhBarChart: -Stacked requires -SeriesField (the field that subdivides each primary bar)."
    }
    $isStacked = $Stacked.IsPresent -or -not [string]::IsNullOrWhiteSpace($SeriesField)
    if ($isStacked -and -not [string]::IsNullOrWhiteSpace($SeriesField) -and $SeriesField -eq $Field) {
        throw "Add-DhBarChart: -SeriesField ('$SeriesField') must be different from -Field ('$Field')."
    }

    # v2.2.0 - value aggregation (same rules as Add-DhTable -Charts Type='bar')
    $srcTable = @($Report.Tables | Where-Object { $_.Id -eq $TableId } | Select-Object -First 1)
    $aggDecl  = Assert-DhBarAggregate -ValueField $ValueField -Aggregate $Aggregate `
                    -Table $(if ($srcTable.Count) { $srcTable[0] } else { $null }) -Context "Add-DhBarChart '$Id'"
    if ($isStacked -and $aggDecl.Aggregate -notin 'count', 'sum') {
        throw "Add-DhBarChart '$Id': a stacked chart adds its segments up, so -Aggregate must be count or sum. Got: $($aggDecl.Aggregate)"
    }

    # v2.3.0 - bar colours. -Rag colours a bar by its value, -KeyClass by its
    # category (KeyClass wins). Stacked segments use the series palette, so
    # both are ignored there, with a warning rather than an error.
    $ragThresholds = @()
    if ($PSBoundParameters.ContainsKey('Rag') -and $null -ne $Rag) {
        $ragThresholds = @((ConvertTo-DhRagThresholds -Rag $Rag -Context "Add-DhBarChart '$Id'").Thresholds)
    }
    $keyClassNorm = [ordered]@{}
    if ($PSBoundParameters.ContainsKey('KeyClass') -and $null -ne $KeyClass) {
        # sorted, so the same input always exports the same bytes (a plain @{} has no order)
        foreach ($k in @($KeyClass.PSBase.Keys | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)) {
            $cls = ([string]$KeyClass[$k]).Trim().ToLowerInvariant() -replace '^cell-', ''
            if ($cls -notin 'ok', 'warn', 'danger', 'nodata') {
                throw "Add-DhBarChart '$Id': -KeyClass['$k'] must be cell-ok, cell-warn, cell-danger or cell-nodata. Got: '$($KeyClass[$k])'"
            }
            $keyClassNorm[[string]$k] = "cell-$cls"
        }
    }
    if ($isStacked -and ($ragThresholds.Count -or $keyClassNorm.Count)) {
        Write-Warning "Add-DhBarChart '$Id': -Rag / -KeyClass are ignored on a stacked chart (segments use the series colours)."
        $ragThresholds = @(); $keyClassNorm = [ordered]@{}
    }

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }

    # Duplicate-Id guard (same rule applied by other block cmdlets)
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhBarChart: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }

    $Report.Blocks.Add([ordered]@{
        BlockType    = 'barchart'
        Id           = $Id
        Title        = $Title
        TableId      = $TableId
        Field        = $Field
        TopN         = $TopN
        ShowCount    = $ShowCount
        ShowPercent  = $ShowPercent
        ClickFilters = $ClickFilters
        Stacked      = [bool]$isStacked
        SeriesField  = $SeriesField
        ValueField   = $aggDecl.ValueField
        Aggregate    = $aggDecl.Aggregate
        Unit         = $Unit
        Decimals     = $Decimals
        Thresholds   = $ragThresholds
        KeyClass     = $keyClassNorm
        NavGroup     = $NavGroup
        NavSubGroup = $NavSubGroup
        NavPath     = $NavPath
        NavSegments     = $navDecl.Path
        NavSeqNo     = $navSeqNo
        NavScope    = $navDecl.Scope
        NavLabel    = $NavLabel
        NavOrder    = $NavOrder
        GridSpan    = $GridSpan
        Collapsible = $Collapsible
        DefaultOpen = $DefaultOpen
    })
    Write-Verbose "Add-DhBarChart: '$Id' from table '$TableId' field '$Field' (top $TopN, $($aggDecl.Aggregate)$(if ($aggDecl.ValueField) { " of $($aggDecl.ValueField)" }))$(if ($isStacked) { " stacked by '$SeriesField'" })."
}


