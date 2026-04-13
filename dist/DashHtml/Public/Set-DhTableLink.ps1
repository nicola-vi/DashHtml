function Set-DhTableLink {
    <#
    .SYNOPSIS
        Link a master table to a detail table so that row selection auto-filters
        the detail table.

    .DESCRIPTION
        When the user clicks a row in the master table the detail table is
        immediately filtered to rows whose DetailField value matches the
        selected row's MasterField value.
        Clicking the same row again (or pressing "Clear") removes the filter.

        Links can be chained:  A -> B -> C
        (Set-DhTableLink A->B, then Set-DhTableLink B->C)

        Multiple detail tables can be linked to the same master:
        (Set-DhTableLink A->B, then Set-DhTableLink A->C)

    .PARAMETER Report
        Dashboard object returned by New-DhDashboard.

    .PARAMETER MasterTableId
        TableId of the driving (master / parent) table.

    .PARAMETER DetailTableId
        TableId of the dependent (detail / child) table.

    .PARAMETER MasterField
        Property name in the master table that carries the join key.

    .PARAMETER DetailField
        Property name in the detail table to match against the master key.

    .EXAMPLE
        # Two-level: selecting a parent row filters the child table
        Set-DhTableLink -Report $report -MasterTableId 'parents' -DetailTableId 'children' `
                        -MasterField 'ParentId' -DetailField 'ParentId'

    .EXAMPLE
        # Three-level chain: A -> B -> C
        Set-DhTableLink -Report $report -MasterTableId 'categories' -DetailTableId 'groups' `
                        -MasterField 'Category' -DetailField 'Category'

        Set-DhTableLink -Report $report -MasterTableId 'groups' -DetailTableId 'items' `
                        -MasterField 'GroupId' -DetailField 'GroupId'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)] [string]    $MasterTableId,
        [Parameter(Mandatory)] [string]    $DetailTableId,
        [Parameter(Mandatory)] [string]    $MasterField,
        [Parameter(Mandatory)] [string]    $DetailField
    )

    # Validate both table IDs exist
    foreach ($id in @($MasterTableId, $DetailTableId)) {
        if (-not ($Report.Tables | Where-Object { $_.Id -eq $id })) {
            throw "Set-DhTableLink: No table with Id '$id' found in the report. Add tables before linking."
        }
    }

    if ($MasterTableId -eq $DetailTableId) {
        throw "Set-DhTableLink: MasterTableId and DetailTableId must be different."
    }

    # Warn if duplicate link already exists
    $dupLink = $Report.Links | Where-Object {
        $_.MasterTableId -eq $MasterTableId -and
        $_.DetailTableId -eq $DetailTableId -and
        $_.MasterField   -eq $MasterField   -and
        $_.DetailField   -eq $DetailField
    }
    if ($dupLink) {
        Write-Warning "Set-DhTableLink: A link from '$MasterTableId'.$MasterField to '$DetailTableId'.$DetailField already exists."
    }

    # Warn if field names are not found in the respective table column definitions
    $masterTable = $Report.Tables | Where-Object { $_.Id -eq $MasterTableId }
    $detailTable = $Report.Tables | Where-Object { $_.Id -eq $DetailTableId }
    if ($masterTable -and -not ($masterTable.Columns | Where-Object { $_.Field -eq $MasterField })) {
        Write-Warning "Set-DhTableLink: Field '$MasterField' not found in master table '$MasterTableId' columns. Link may not filter correctly."
    }
    if ($detailTable -and -not ($detailTable.Columns | Where-Object { $_.Field -eq $DetailField })) {
        Write-Warning "Set-DhTableLink: Field '$DetailField' not found in detail table '$DetailTableId' columns. Link may not filter correctly."
    }

    $Report.Links.Add([ordered]@{
        MasterTableId = $MasterTableId
        DetailTableId = $DetailTableId
        MasterField   = $MasterField
        DetailField   = $DetailField
    })

    Write-Verbose "Set-DhTableLink: '$MasterTableId'.$MasterField -> '$DetailTableId'.$DetailField"
}
