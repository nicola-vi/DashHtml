#Requires -Version 7.0
<#
.SYNOPSIS
    DashHtml.Design — companion tools that convert between a declarative YAML
    layout spec and DashHtml PowerShell.

    ConvertTo-DhYaml     report object -> YAML   (lossless "layout view")
    ConvertFrom-DhYaml   YAML/JSON     -> .ps1   (runnable build script)
    ConvertFrom-DhScript .ps1          -> YAML   (best-effort static parse)
    Export-DhYamlSchema  cmdlets       -> JSON Schema of the layout
    Update-DhScript      .ps1          -> 2.0.0 upgrade audit / rewrite
    Test-DhReport        report, .ps1, .yaml, .html -> findings (2.6.0)

    This module changes NOTHING in the core DashHtml module; it is a pure
    design / round-trip tool. It has no external dependencies (self-contained
    YAML reader/writer). ConvertFrom-DhYaml reads DashHtml cmdlet metadata, so
    the core DashHtml module must be importable.
#>

Set-StrictMode -Version Latest

$Private = Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue
$Public  = Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1"  -ErrorAction Stop

foreach ($file in @($Private) + @($Public)) {
    try { . $file.FullName }
    catch { Write-Error "DashHtml.Design: failed to import '$($file.FullName)': $_" }
}

Export-ModuleMember -Function (@($Public) | Select-Object -ExpandProperty BaseName)
