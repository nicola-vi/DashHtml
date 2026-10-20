#Requires -Version 7.0
<#
.SYNOPSIS
    Audits exported DashHtml reports for common accessibility defects with headless Edge/Chrome.
.DESCRIPTION
    Injects Tools\a11y-probe.js into a temporary COPY of each page and reads the findings back (see BrowserProbe.ps1).
    Rules: duplicate ids, controls without a name, sortable headers without aria-sort or keyboard access, tabs and
    expandables without their state, dialogs without a role or name, tables without a name, selection that is not
    announced, missing lang / main landmark, images without alt, no focus-visible style, no reduced-motion rule.
    Severity 'error' fails the check; 'warning' fails it only with -Strict. Skips with a message when no browser is found.
.PARAMETER Path
    Exported report HTML files. Default: Examples/*.html (regenerate them first).
.PARAMETER Strict
    Treat warnings as failures too.
.PARAMETER PassThru
    Return one object per finding (File, Rule, Severity, Count, Sample).
.EXAMPLE
    PS> ./Tools/Test-DhA11y.ps1
#>
[CmdletBinding()]
param(
    [string[]] $Path = (Join-Path $PSScriptRoot '../Examples/*.html'),
    [switch] $Strict,
    [switch] $PassThru
)
$ErrorActionPreference = 'Stop'
$browser = & (Join-Path $PSScriptRoot 'Find-DhBrowser.ps1')
if (-not $browser) { Write-Warning 'No Edge or Chrome found; accessibility check skipped.'; return }
. (Join-Path $PSScriptRoot 'BrowserProbe.ps1')

$probe  = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'a11y-probe.js') -Raw
$script = "window.addEventListener('load', function () { setTimeout(function () {`n var r = $probe`n" +
          " try { fetch('http://127.0.0.1:' + /*%%PORT%%*/0 + '/result', { method: 'POST', mode: 'no-cors', body: JSON.stringify(r) }); } catch (e) {}`n }, 900); });"
$session = New-DhProbeSession -Browser $browser
$findings = [System.Collections.Generic.List[object]]::new(); $files = 0
try {
    foreach ($f in @(Get-ChildItem -Path $Path -File)) {
        $files++
        $body = Invoke-DhProbe -Session $session -HtmlFile $f.FullName -Script $script
        if (-not $body) { Write-Warning "$($f.Name): no result came back"; continue }
        foreach ($r in ($body | ConvertFrom-Json).rules) {
            $findings.Add([pscustomobject]@{ File = $f.Name; Rule = $r.rule; Severity = $r.severity; Count = $r.count; Sample = ($r.samples | Select-Object -First 1) })
        }
    }
} finally { Remove-DhProbeSession -Session $session }

$errors   = @($findings | Where-Object Severity -eq 'error')
$warnings = @($findings | Where-Object Severity -eq 'warning')
Write-Host ("Accessibility: {0} file(s), {1} error rule hit(s), {2} warning rule hit(s)." -f $files, $errors.Count, $warnings.Count)
if ($findings.Count) { $findings | Sort-Object Severity, Rule, File | Format-Table File, Severity, Rule, Count, Sample -AutoSize | Out-String | Write-Host }
if ($PassThru) { $findings }
if ($errors.Count -or ($Strict -and $warnings.Count)) { exit 1 }   # a CI step (pwsh -File) fails on findings