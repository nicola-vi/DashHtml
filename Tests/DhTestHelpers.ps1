# Shared helpers for the DashHtml Pester suites (v2.1.4).
# Dot-source inside a BeforeAll:   . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
#
# Older Describes inline the export-to-temp pattern; new ones use this so each
# test states only what it asserts.

function Export-DhTestHtml {
    <#
    .SYNOPSIS  Export a report to a temp file, return the HTML, delete the file.
    .PARAMETER WithWarnings
        Return [pscustomobject]@{ Html; Warnings } instead of the HTML string,
        with every warning the export wrote (as strings).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [switch] $WithWarnings
    )
    $dir  = Join-Path ([IO.Path]::GetTempPath()) ('DH_T_' + [guid]::NewGuid().ToString('N'))
    $path = Join-Path $dir 'report.html'
    New-Item -ItemType Directory -Path $dir | Out-Null
    try {
        Export-DhDashboard -Report $Report -OutputPath $path -Force -WarningVariable exportWarnings -WarningAction SilentlyContinue
        $html = Get-Content -LiteralPath $path -Raw
        if ($WithWarnings) {
            [pscustomobject]@{ Html = $html; Warnings = @($exportWarnings | ForEach-Object { [string]$_ }) }
        } else { $html }
    } finally {
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-DhTestJsFunction {
    <#
    .SYNOPSIS  Return the source of one runtime JS function from exported HTML.
    .DESCRIPTION
        Matches 'function <Name>(' (or 'X.prototype.<Name> = function (') up to
        the first line that closes it at the same two-space indent the runtime
        uses for top-level functions. Returns '' when not found.
    #>
    param([Parameter(Mandatory)] [string] $Html, [Parameter(Mandatory)] [string] $Name)
    $rx = '(?ms)^  (?:function ' + [regex]::Escape($Name) + '\s*\(|\w+\.prototype\.' + [regex]::Escape($Name) + '\s*=\s*function\s*\().*?^  \};?\s*$'
    $m = [regex]::Match($Html, $rx)
    if ($m.Success) { $m.Value } else { '' }
}
