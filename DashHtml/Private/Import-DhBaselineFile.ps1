function Import-DhBaselineFile {
    <#
    .SYNOPSIS
        v2.6.0 - read the previous run's rows for Add-DhTable -BaselinePath.
    .DESCRIPTION
        Read-only: the module never writes a baseline. The format follows the extension:
        .clixml / .xml (Import-Clixml, keeps types), .csv (Import-Csv, every value is text),
        .json (an array of objects, or a single object). A missing file returns $null with a
        warning (the first run of a schedule); an unreadable or unsupported file throws.
        The rows are returned wrapped in a one-element array so an empty file stays an
        empty array instead of unrolling to $null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [string] $TableId = ''
    )
    $ctx = "Add-DhTable '$TableId'"
    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($ext -notin @('.clixml', '.xml', '.csv', '.json')) {
        throw "${ctx}: -BaselinePath must end in .clixml, .xml, .csv or .json. Got: $Path"
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Warning "${ctx}: no baseline file at '$Path' yet (first run?). The table is built without change markers."
        return $null
    }
    try {
        $rows = switch ($ext) {
            '.csv'  { @(Import-Csv -LiteralPath $Path -ErrorAction Stop) }
            '.json' {
                $text = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
                if ([string]::IsNullOrWhiteSpace($text)) { @() } else { @($text | ConvertFrom-Json -ErrorAction Stop) }
            }
            default { @(Import-Clixml -LiteralPath $Path -ErrorAction Stop) }
        }
    } catch {
        throw "${ctx}: could not read the baseline file '$Path': $($_.Exception.Message)"
    }
    # ConvertFrom-Json of a top-level array is already enumerated by @(); Import-Clixml of a
    # single object gives one row. Drop nulls (an Export-Clixml of $null).
    return , @($rows | Where-Object { $null -ne $_ })
}
