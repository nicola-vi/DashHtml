function Get-DhTableFieldNames {
    <#
    .SYNOPSIS  Every field name a stored table can be aggregated or linked on (v2.2.0).
    .DESCRIPTION
        The declared column fields plus every property of the data rows.
        Export-DhDashboard serialises ALL row properties, not only the visible
        columns, so a hidden property is a valid -ValueField / UrlField too.
        Looks at the first 50 rows, which is enough for heterogeneous data
        without scanning a large table.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param([Parameter(Mandatory)] [System.Collections.IDictionary] $Table)

    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($c in @($Table.Columns)) { if ($c -and $c.Field) { [void]$names.Add([string]$c.Field) } }
    foreach ($row in @($Table.Data | Select-Object -First 50)) {
        if ($row -is [System.Collections.IDictionary]) { foreach ($k in $row.Keys) { [void]$names.Add([string]$k) } }
    }
    , @($names)
}

function Assert-DhBarAggregate {
    <#
    .SYNOPSIS  Validate and normalise a bar-chart value aggregation (v2.2.0).
    .DESCRIPTION
        Shared by Add-DhBarChart and Add-DhTable -Charts Type='bar'.
        Rules:
          - Aggregate is count | sum | avg | min | max (case-insensitive).
          - Anything but count needs a ValueField.
          - A ValueField with no Aggregate means 'sum' (the reason to name a
            value column is to add it up).
          - When the table is known, ValueField must be one of its fields.
        Returns @{ ValueField; Aggregate }.
    #>
    [CmdletBinding()]
    param(
        [string] $ValueField = '',
        [string] $Aggregate  = '',
        [System.Collections.IDictionary] $Table = $null,
        [Parameter(Mandatory)] [string] $Context
    )
    $agg = if ([string]::IsNullOrWhiteSpace($Aggregate)) {
        if ([string]::IsNullOrWhiteSpace($ValueField)) { 'count' } else { 'sum' }
    } else { $Aggregate.Trim().ToLowerInvariant() }
    if ($agg -notin 'count', 'sum', 'avg', 'min', 'max') {
        throw "${Context}: Aggregate must be count, sum, avg, min or max. Got: $Aggregate"
    }
    if ($agg -ne 'count' -and [string]::IsNullOrWhiteSpace($ValueField)) {
        throw "${Context}: Aggregate '$agg' needs a ValueField - the numeric column to $agg."
    }
    if ($agg -eq 'count') { $ValueField = '' }
    if ($ValueField -and $Table) {
        $fields = Get-DhTableFieldNames -Table $Table
        # case-sensitive: the browser reads row[ValueField] verbatim
        if ($ValueField -cnotin $fields) {
            throw "${Context}: ValueField '$ValueField' is not a field of table '$($Table.Id)'. Fields: $($fields -join ', ')"
        }
    }
    @{ ValueField = $ValueField; Aggregate = $agg }
}
