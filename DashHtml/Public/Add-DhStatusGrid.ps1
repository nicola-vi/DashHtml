function Add-DhStatusGrid {
    <#
    .SYNOPSIS
        Add a status-matrix / health-grid block — rows × columns of RAG cells.

    .DESCRIPTION
        Renders a 2-D grid where each cell carries a status (ok / warn / danger /
        nodata / info), per the IT-infrastructure KPI dashboard specification
        (§2 Widget Types — "Status Matrix / Health Grid"). Use it as a
        compact at-a-glance overview of binary or low-cardinality health state
        across many entities — services × regions, DCs × replication links,
        hosts × probes.

        Distinct from Add-DhTable: a status grid is a colour-first matrix where
        the individual cell labels don't matter; a table is text-first with rich
        sorting, filtering, and per-cell content.

        Cells are sparse — declare only the (Row, Column) pairs that exist;
        missing cells render as a faint neutral state.

    .PARAMETER Report       Dashboard object from New-DhDashboard.
    .PARAMETER Id           Unique identifier (alphanumeric, dash, underscore).
    .PARAMETER Title        Block heading shown above the grid.

    .PARAMETER Rows
        Array of row labels (Y-axis). Each cell's Row must match one of these.

    .PARAMETER Columns
        Array of column labels (X-axis). Each cell's Column must match one of these.

    .PARAMETER Cells
        Array of cell hashtables:
          @{
              Row       = 'Auth'              # REQUIRED — must appear in -Rows
              Column    = 'us-east'           # REQUIRED — must appear in -Columns
              Status    = 'ok'                # REQUIRED — ok | warn | danger | nodata | info
              Tooltip   = '99.98% / 24h'      # optional — native hover tooltip
              LinkTableId = 'incidents'       # optional — click jumps to a registered table
              LinkFilter  = 'auth-eu'         # optional — text filter applied on jump
          }

    .PARAMETER RowLabel       Optional caption for the Y-axis (top-left corner).
    .PARAMETER ColumnLabel    Optional caption for the X-axis (above column headers).

    .PARAMETER CellSize
        Cell side length preset: 'small' (32 px) | 'normal' (48 px, default) | 'large' (64 px).
        On a narrow viewport (< 600 px) the grid collapses to a stacked list
        regardless of this setting.

    .PARAMETER MaxCells
        Hard ceiling on Rows × Columns. Default 2000. Above this the cmdlet
        throws to protect against accidental 10k-cell matrices from broad
        `Get-AzResource`-style queries. A soft warning fires at 200 cells.

    .PARAMETER NavGroup       Primary nav group label (enables two-tier nav).
    .PARAMETER NavSubGroup    Optional second-level group under NavGroup.

    .EXAMPLE
        Add-DhStatusGrid -Report $report -Id 'service-health' -Title 'Service Health' `
            -RowLabel 'Service' -ColumnLabel 'Region' `
            -Rows    @('Auth','Billing','Search','Mail') `
            -Columns @('us-east','us-west','eu-west','ap-south') `
            -Cells   @(
                @{ Row='Auth';    Column='us-east'; Status='ok';     Tooltip='99.98% / 24h' }
                @{ Row='Auth';    Column='eu-west'; Status='warn';   Tooltip='latency spike';
                   LinkTableId='incidents'; LinkFilter='auth-eu' }
                @{ Row='Billing'; Column='us-east'; Status='danger'; Tooltip='down 12m' }
            )
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

        [ValidateSet('small','normal','large')]
        [string] $CellSize = 'normal',

        [ValidateRange(1, 100000)]
        [int]    $MaxCells = 2000,

        [string] $NavGroup    = '',
        [string] $NavSubGroup = ''
    )

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhStatusGrid: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }
    if ($Rows.Count -lt 1)    { throw "Add-DhStatusGrid: -Rows must contain at least one label."    }
    if ($Columns.Count -lt 1) { throw "Add-DhStatusGrid: -Columns must contain at least one label." }

    # Size guard — per docs/v1.4-plan.md §3 Q3
    $totalCells = $Rows.Count * $Columns.Count
    if ($totalCells -gt $MaxCells) {
        throw "Add-DhStatusGrid: Rows × Columns = $totalCells exceeds -MaxCells ($MaxCells). Reduce the axes or raise -MaxCells deliberately."
    }
    if ($totalCells -gt 200) {
        Write-Warning "Add-DhStatusGrid: $totalCells cells is dense — consider splitting into smaller grouped grids for legibility (Rows × Columns = $($Rows.Count) × $($Columns.Count))."
    }

    # Normalise axes to strings; build lookup sets for membership checks
    $rowList = @($Rows    | ForEach-Object { [string]$_ })
    $colList = @($Columns | ForEach-Object { [string]$_ })
    $rowSet  = @{}
    $colSet  = @{}
    foreach ($r in $rowList) { $rowSet[$r] = $true }
    foreach ($c in $colList) { $colSet[$c] = $true }

    $allowedStatus = @('ok','warn','danger','nodata','info')

    $normCells = foreach ($cell in $Cells) {
        if ($cell -isnot [hashtable] -and $cell -isnot [System.Collections.Specialized.OrderedDictionary]) {
            throw "Add-DhStatusGrid: each cell must be a hashtable. Got: $($cell.GetType().Name)"
        }
        foreach ($req in 'Row','Column','Status') {
            if (-not $cell.Contains($req) -or [string]::IsNullOrWhiteSpace([string]$cell[$req])) {
                throw "Add-DhStatusGrid: each cell must have a non-empty '$req' key."
            }
        }
        $r = [string]$cell['Row']
        $c = [string]$cell['Column']
        if (-not $rowSet.ContainsKey($r)) {
            throw "Add-DhStatusGrid: cell Row '$r' is not in -Rows. Add it to the axis or fix the typo."
        }
        if (-not $colSet.ContainsKey($c)) {
            throw "Add-DhStatusGrid: cell Column '$c' is not in -Columns. Add it to the axis or fix the typo."
        }
        $st = ([string]$cell['Status']).ToLowerInvariant()
        if ($st -notin $allowedStatus) {
            throw "Add-DhStatusGrid: cell ($r, $c) — Status must be 'ok', 'warn', 'danger', 'nodata', or 'info'. Got: $($cell['Status'])"
        }
        # Action validation — matches Add-DhAlertBanner semantics
        $linkTableId = if ($cell.Contains('LinkTableId') -and -not [string]::IsNullOrWhiteSpace([string]$cell['LinkTableId'])) { [string]$cell['LinkTableId'] } else { '' }
        $linkFilter  = if ($cell.Contains('LinkFilter')  -and -not [string]::IsNullOrWhiteSpace([string]$cell['LinkFilter']))  { [string]$cell['LinkFilter']  } else { '' }
        if ($linkFilter -and -not $linkTableId) {
            throw "Add-DhStatusGrid: cell ($r, $c) — LinkFilter requires LinkTableId."
        }
        @{
            Row         = $r
            Column      = $c
            Status      = $st
            Tooltip     = if ($cell.Contains('Tooltip') -and $null -ne $cell['Tooltip']) { [string]$cell['Tooltip'] } else { '' }
            LinkTableId = $linkTableId
            LinkFilter  = $linkFilter
        }
    }

    $Report.Blocks.Add([ordered]@{
        BlockType   = 'statusgrid'
        Id          = $Id
        Title       = $Title
        Rows        = $rowList
        Columns     = $colList
        Cells       = @($normCells)
        RowLabel    = $RowLabel
        ColumnLabel = $ColumnLabel
        CellSize    = $CellSize
        NavGroup    = $NavGroup
        NavSubGroup = $NavSubGroup
    })
    Write-Verbose "Add-DhStatusGrid: '$Id' ($($rowList.Count) rows × $($colList.Count) cols, $(@($normCells).Count) cells)."
}
