function ConvertTo-DhSeverity {
    <#
    .SYNOPSIS  Normalise a severity to critical | warning | info | ok (v2.2.0).
    .DESCRIPTION
        The four canonical values match Add-DhAlertBanner -Severity and the
        alert / event-feed colours. For pasting in assessment output from other
        tools, three aliases are accepted (case-insensitive):
            high -> critical    medium -> warning    low -> info
        Anything else throws, naming the context.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()] [AllowEmptyString()] [string] $Severity,
        [Parameter(Mandatory)] [string] $Context
    )
    $s = if ($null -eq $Severity) { '' } else { $Severity.Trim().ToLowerInvariant() }
    switch ($s) {
        { $_ -in 'critical', 'warning', 'info', 'ok' } { return $s }
        'high'   { return 'critical' }
        'medium' { return 'warning' }
        'low'    { return 'info' }
    }
    throw "${Context}: Severity must be critical, warning, info or ok (aliases: high, medium, low). Got: '$Severity'"
}
