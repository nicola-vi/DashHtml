function Add-DhFilterCard {
    <#
    .SYNOPSIS
        Add a clickable card grid that filters a target table.

    .DESCRIPTION
        Renders a row of clickable cards — each card represents a distinct value
        from a field in the target table. Clicking a card instantly filters the
        table to show only matching rows. An active filter banner appears below
        the grid with a Clear Filter button.

        The cards are independent of the table data: you supply them explicitly
        so they can include display labels, counts, icons, and sub-labels that
        differ from the raw field values.

        Use -MultiFilter to allow more than one card to be active simultaneously.

    .PARAMETER Report           Dashboard object from New-DhDashboard.
    .PARAMETER Id               Unique identifier (alphanumeric, - or _).
    .PARAMETER Title            Section heading shown above the cards.
    .PARAMETER TargetTableId    TableId of the table to filter.
    .PARAMETER FilterField      Field name in the target table to match against.
    .PARAMETER Cards
        Array of card hashtables:
          @{
              Label    = 'Card display name'   # REQUIRED
              Value    = 'match-value'         # REQUIRED — matched against FilterField
              SubLabel = 'Secondary label'     # optional
              Count    = 42                    # optional — badge top-right of card
              Icon     = 'X'                   # optional
          }

    .PARAMETER MultiFilter      Allow multiple cards active simultaneously ($false).
    .PARAMETER ShowCount        Show count badge on cards (default $true).

    .EXAMPLE
        # Filter a table by a grouping field
        $locationCards = $servers | Group-Object Location | ForEach-Object {
            @{ Label = $_.Name; Value = $_.Name; Count = $_.Count }
        }
        Add-DhFilterCard -Report $report -Id 'loc-filter' `
            -Title 'Filter by Location' `
            -TargetTableId 'servers' -FilterField 'Location' `
            -Cards $locationCards

    .EXAMPLE
        # Multi-select filter (multiple cards can be active at once)
        Add-DhFilterCard -Report $report -Id 'env-filter' `
            -Title 'Filter by Environment' `
            -TargetTableId 'resources' -FilterField 'Environment' `
            -MultiFilter $true `
            -Cards @(
                @{ Label = 'Production';  Value = 'prod'; Count = 45 }
                @{ Label = 'Staging';     Value = 'stg';  Count = 12 }
                @{ Label = 'Development'; Value = 'dev';  Count = 30 }
            )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string]   $Id,
        [Parameter(Mandatory)] [string]    $Title,
        [Parameter(Mandatory)] [string]    $TargetTableId,
        [Parameter(Mandatory)] [string]    $FilterField,
        [Parameter(Mandatory)] [object[]]  $Cards,
        [switch]   $MultiFilter,
        [bool]     $ShowCount   = $true,
        [string]   $NavGroup    = '',   # primary nav group label (enables two-tier nav)
        [string]   $NavSubGroup = ''    # optional second-level group under NavGroup (enables three-tier nav)
    )

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }

    if ($Report.Tables -and -not ($Report.Tables | Where-Object { $_.Id -eq $TargetTableId })) {
        throw "Add-DhFilterCard: Target table '$TargetTableId' not found. Add the table before the filter grid."
    }

    $normCards = foreach ($card in $Cards) {
        $c = @{} + $card
        if (-not $c.Contains('SubLabel')) { $c['SubLabel'] = '' }
        if (-not $c.Contains('Count'))    { $c['Count']    = $null }
        if (-not $c.Contains('Icon'))     { $c['Icon']     = '' }
        $c
    }

    $Report.Blocks.Add([ordered]@{
        BlockType     = 'filtercardgrid'
        Id            = $Id
        Title         = $Title
        TargetTableId = $TargetTableId
        FilterField   = $FilterField
        Cards         = @($normCards)
        MultiFilter   = $MultiFilter
        ShowCount     = $ShowCount
        NavGroup      = $NavGroup
        NavSubGroup   = $NavSubGroup
    })
    Write-Verbose "Add-DhFilterCard: '$Id' -> table '$TargetTableId' on field '$FilterField' ($(@($normCards).Count) cards)."
}
