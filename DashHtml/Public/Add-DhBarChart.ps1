function Add-DhBarChart {
    <#
    .SYNOPSIS
        Add a horizontal bar chart aggregating values from a table field.

    .DESCRIPTION
        Counts occurrences of each distinct value in the specified field across
        all rows of the source table, then renders the top-N results as horizontal
        proportional bars, sorted highest to lowest.

        The chart renders as a standalone block in the dashboard flow and is
        re-calculated at page load from the table's full dataset.

    .PARAMETER Report       Dashboard object from New-DhDashboard.
    .PARAMETER Id           Unique identifier (alphanumeric, - or _).
    .PARAMETER Title        Chart heading.
    .PARAMETER TableId      Source table to aggregate (must already be added).
    .PARAMETER Field        Field name to aggregate by counting distinct values.
    .PARAMETER TopN         Maximum bars to display (default 10).
    .PARAMETER ShowCount    Show the count number beside each bar (default $true).
    .PARAMETER ShowPercent  Show the percentage of total beside each bar (default $false).
    .PARAMETER ClickFilters When $true, clicking a bar sets the source table's text filter.

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
        [string] $NavGroup       = '',   # primary nav group label (enables two-tier nav)
        [string] $NavSubGroup    = ''    # optional second-level group under NavGroup (enables three-tier nav)
    )

    if ($Report.Tables -and -not ($Report.Tables | Where-Object { $_.Id -eq $TableId })) {
        throw "Add-DhBarChart: Source table '$TableId' not found. Add the table before the bar chart."
    }

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
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
        NavGroup     = $NavGroup
        NavSubGroup  = $NavSubGroup
    })
    Write-Verbose "Add-DhBarChart: '$Id' from table '$TableId' field '$Field' (top $TopN)."
}
