#Requires -Version 7.0
<#
.SYNOPSIS
    Measures WCAG text contrast of DashHtml classes in every theme (light and dark) with headless Edge/Chrome.
.DESCRIPTION
    Exports Demo-ActiveDirectory, Feature-MapsAndGrids and Feature-Navigation in each theme family (or uses -Path),
    injects Tools/contrast-measure.js into a temporary COPY of each page, opens it in a headless Chromium browser and
    receives the result on a local loopback listener (current Edge prints nothing for --dump-dom). Selectors and accepted exceptions live in Tools/contrast-selectors.json.
    Text over a gradient or image is counted as skipped, never as a pass. Skips with a message when no browser is found.
.PARAMETER Path
    Exported report HTML files to measure (the theme is whatever each file was built with). Default: build the
    example reports in every family.
.PARAMETER Theme
    Families to build when -Path is not given. Default: all six.
.PARAMETER MinRatio
    Minimum ratio for normal text (default 4.5). Large text needs 3.0.
.PARAMETER PassThru
    Return the failing rows as objects (Theme, File, Mode, Selector, Ratio, Min, Text).
.EXAMPLE
    PS> ./Tools/Test-DhContrast.ps1
#>
[CmdletBinding()]
param(
    [string[]] $Path,
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string[]] $Theme = @('Default','Azure','VMware','Grey','Company','Rag'),
    [double] $MinRatio = 4.5,
    [switch] $PassThru
)
$ErrorActionPreference = 'Stop'
$browser = & (Join-Path $PSScriptRoot 'Find-DhBrowser.ps1')
if (-not $browser) { Write-Warning 'No Edge or Chrome found; contrast check skipped.'; return }

$config  = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'contrast-selectors.json') -Raw | ConvertFrom-Json
$script  = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'contrast-measure.js') -Raw).Replace('/*%%SELECTORS%%*/[]', ($config.selectors | ConvertTo-Json -Compress))
. (Join-Path $PSScriptRoot 'BrowserProbe.ps1')
$session = New-DhProbeSession -Browser $browser
$work = $session.Work
try {
    $targets = [System.Collections.Generic.List[object]]::new()
    if ($Path) {
        foreach ($f in @(Get-ChildItem -Path $Path -File)) { $targets.Add([pscustomobject]@{ Theme = '(as built)'; File = $f.FullName }) }
    } else {
        $examples = Join-Path $PSScriptRoot '../Examples'
        foreach ($th in $Theme) {
            foreach ($ex in 'Demo-ActiveDirectory', 'Feature-MapsAndGrids', 'Feature-Navigation') {
                $out = Join-Path $work "$ex-$th.html"
                & (Join-Path $examples "$ex.ps1") -Theme $th -OutputPath $out 6>$null | Out-Null
                $targets.Add([pscustomobject]@{ Theme = $th; File = $out })
            }
        }
    }
    $failures = [System.Collections.Generic.List[object]]::new(); $checked = 0; $skipped = 0; $i = 0
    foreach ($t in $targets) {
        $i++
        $body = Invoke-DhProbe -Session $session -HtmlFile $t.File -Script $script
        if (-not $body) { Write-Warning "$(Split-Path $t.File -Leaf): no measurement came back"; continue }
        $res = $body | ConvertFrom-Json
        $skipped += [int]$res.skipped
        foreach ($r in $res.rows) {
            $checked++
            $min = if ($r.large) { 3.0 } else { $MinRatio }
            $acc = $config.accept | Where-Object { $_.selector -eq $r.selector } | Select-Object -First 1
            if ($acc) { $min = [math]::Min($min, [double]$acc.min) }
            if ($r.ratio -lt $min) {
                $failures.Add([pscustomobject]@{ Theme = $t.Theme; File = Split-Path $t.File -Leaf; Mode = $r.mode; Selector = $r.selector; Ratio = $r.ratio; Min = $min; Text = $r.text })
            }
        }
    }
} finally { Remove-DhProbeSession -Session $session }

$unique = $failures | Sort-Object Theme, Mode, Selector, Ratio -Unique
Write-Host ("Contrast: {0} measurements, {1} skipped (image or gradient background), {2} below the minimum." -f $checked, $skipped, @($unique).Count)
if ($unique) { $unique | Sort-Object Ratio | Format-Table Ratio, Min, Theme, Mode, Selector, Text, File -AutoSize | Out-String | Write-Host }
if ($PassThru) { $unique }
if ($unique) { exit 1 }   # a CI step (pwsh -File) fails on findings