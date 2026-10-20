#Requires -Version 7.0
<#
.SYNOPSIS
    Prints dashboards to PDF with headless Edge/Chrome and reports page count and size.
.DESCRIPTION
    A helper for the manual print check, not a CI gate. Skips with a message when no
    Chromium browser is installed. PDFs go to -OutDir (default: a temp folder).
.PARAMETER Path
    HTML files (default: Examples/*.html).
.PARAMETER OutDir
    Where the PDFs are written.
#>
[CmdletBinding()]
param(
    [string[]] $Path = (Join-Path $PSScriptRoot '../Examples/*.html'),
    [string] $OutDir = (Join-Path ([IO.Path]::GetTempPath()) 'dh-print')
)
$ErrorActionPreference = 'Stop'
$browser = & (Join-Path $PSScriptRoot 'Find-DhBrowser.ps1')
if (-not $browser) { Write-Warning 'No Edge or Chrome found; print check skipped.'; return }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
foreach ($f in @(Get-ChildItem -Path $Path -File)) {
    $pdf = Join-Path $OutDir ($f.BaseName + '.pdf')
    Remove-Item -LiteralPath $pdf -ErrorAction SilentlyContinue
    $uri = ([Uri] $f.FullName).AbsoluteUri
    $prof = Join-Path $OutDir ('profile-' + [guid]::NewGuid().ToString('N'))
    & $browser --headless=new --disable-gpu --no-pdf-header-footer "--user-data-dir=$prof" "--print-to-pdf=$pdf" --virtual-time-budget=8000 $uri 2>$null | Out-Null
    Remove-Item -LiteralPath $prof -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $pdf) {
        $bytes = [IO.File]::ReadAllBytes($pdf)
        $pages = ([regex]::Matches([Text.Encoding]::Latin1.GetString($bytes), '/Type\s*/Page[^s]')).Count
        [pscustomobject]@{ File = $f.Name; Pages = $pages; KB = [int]($bytes.Length / 1KB); Pdf = $pdf }
    } else { [pscustomobject]@{ File = $f.Name; Pages = 0; KB = 0; Pdf = '(failed)' } }
}