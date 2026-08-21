function Add-DhGlobalFilter {
    <#
    .SYNOPSIS
        Add a page-level filter control that filters every table at once (v1.9.0).

    .DESCRIPTION
        Renders a control in a filter bar above the report body. When the user
        changes it, EVERY table that has the named field re-filters to matching
        rows, and any chart derived from those tables re-aggregates. Tables that
        do not have the field are unaffected.

        Two control types:
          -Type facet      A dropdown of distinct values (default). Pick one to
                           keep only rows whose Field equals it. Values are
                           auto-derived from the tables' data unless -Values is
                           supplied.
          -Type daterange  Two date inputs (from / to). Keeps rows whose Field
                           parses as a date within the inclusive range.

        Multiple global filters combine with AND. Selections persist in the URL
        hash, so a shared link or reload keeps the filter applied.

    .PARAMETER Report   Dashboard object from New-DhDashboard.
    .PARAMETER Field    Row field/property name to filter on (must match the
                        column Field used in your tables).
    .PARAMETER Label    Display label for the control. Defaults to -Field.
    .PARAMETER Type     'facet' (default) or 'daterange'.
    .PARAMETER Values   Explicit facet values (facet type only). When omitted,
                        distinct values are derived at runtime from all tables.
    .PARAMETER Placeholder
                        Text for the facet's "all / no selection" option.
                        Defaults to "All <Label>".

    .EXAMPLE
        # Environment dropdown — filters every table that has an 'Environment' column
        Add-DhGlobalFilter -Report $report -Field 'Environment' -Label 'Environment'

    .EXAMPLE
        # Explicit ordered values
        Add-DhGlobalFilter -Report $report -Field 'Tier' -Values 'Gold','Silver','Bronze'

    .EXAMPLE
        # Date range over a 'LastSeen' timestamp column
        Add-DhGlobalFilter -Report $report -Field 'LastSeen' -Label 'Last seen' -Type daterange
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)] [string]   $Field,
        [string]   $Label       = '',
        [ValidateSet('facet','daterange')]
        [string]   $Type        = 'facet',
        [string[]] $Values      = @(),
        [string]   $Placeholder = ''
    )

    if (-not $Report.Contains('GlobalFilters')) {
        $Report['GlobalFilters'] = [System.Collections.Generic.List[hashtable]]::new()
    }

    foreach ($existing in $Report['GlobalFilters']) {
        if ($existing.Field -eq $Field) {
            throw "Add-DhGlobalFilter: A global filter for field '$Field' already exists."
        }
    }

    if ($Type -ne 'facet' -and $Values.Count -gt 0) {
        Write-Warning "Add-DhGlobalFilter: -Values is only used with -Type 'facet'; ignored for '$Type'."
    }

    $Report['GlobalFilters'].Add(@{
        Field       = $Field
        Label       = if ($Label) { $Label } else { $Field }
        Type        = $Type
        Values      = @($Values)
        Placeholder = $Placeholder
    })
    Write-Verbose "Add-DhGlobalFilter: '$Field' ($Type)."
}
