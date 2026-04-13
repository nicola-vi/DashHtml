#Requires -Version 7.0
<#
.SYNOPSIS
    DashHtml module loader.
    Auto-imports all Private helpers then all Public cmdlets.
#>

Set-StrictMode -Version Latest

$Private = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue
$Public  = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1"  -ErrorAction Stop

foreach ($file in @($Private) + @($Public)) {
    try {
        . $file.FullName
    }
    catch {
        Write-Error "DashHtml: Failed to import '$($file.FullName)': $_"
    }
}

Export-ModuleMember -Function (@($Public) | Select-Object -ExpandProperty BaseName)
