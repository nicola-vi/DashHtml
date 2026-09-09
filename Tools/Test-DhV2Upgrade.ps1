#Requires -Version 7.0
<#
.SYNOPSIS
    Audits DashHtml scripts for work required by the 2.0.0 upgrade.

.DESCRIPTION
    Parses each .ps1 with the PowerShell AST (it never executes them) and reports
    every call affected by a 2.0.0 breaking change:

      15.1  Add-DhTable -NavGroup ...   — ADVISORY ONLY. The v2 compat shim maps
                                          this to 'Group/TableId', so the table
                                          keeps its own menu node and the script
                                          needs no edit. Flagged so you can
                                          migrate to -NavPath for clarity.
      15.2  Add-DhHtmlBlock / -Collapsible / -AlertBanner / -Tabs without an
            explicit -AllowHtml         — the default flips $true -> $false.
      15.3  A block cmdlet with -NavSubGroup — currently invisible (gotcha #26);
                                          it will start rendering in 2.0.0.

    AST parsing is used rather than grep on purpose: these calls routinely span
    several lines with backtick continuation, so a line-oriented pattern silently
    under-reports. On Examples/ the naive greps find 0 issues; this finds 13.

    Read-only. It never modifies anything. The 2.0.0 cmdlet `Update-DhScript`
    will apply the same rules and offer a rewrite mode.

.PARAMETER Path
    Files or directories to scan. Recurses into directories. Default: current dir.

.PARAMETER Detailed
    Also print the source line of each hit.

.EXAMPLE
    .\Tools\Test-DhV2Upgrade.ps1 -Path .\Examples

.EXAMPLE
    .\Tools\Test-DhV2Upgrade.ps1 -Path 'C:\Scripts' -Detailed
#>
[CmdletBinding()]
param(
    [string[]] $Path = @('.'),
    [switch]   $Detailed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$htmlCmds = @('Add-DhHtmlBlock','Add-DhCollapsible','Add-DhAlertBanner','Add-DhTabs')
$blockCmds = @(
    'Add-DhBarChart','Add-DhPieChart','Add-DhLineChart','Add-DhBullet','Add-DhSummary',
    'Add-DhHtmlBlock','Add-DhCollapsible','Add-DhStatusGrid','Add-DhHeatmap',
    'Add-DhTopologyMap','Add-DhEventFeed','Add-DhTabs','Add-DhFilterCard','Add-DhAlertBanner'
)

$files = foreach ($p in $Path) {
    if (Test-Path -LiteralPath $p -PathType Container) { Get-ChildItem -LiteralPath $p -Filter *.ps1 -Recurse -File }
    elseif (Test-Path -LiteralPath $p)                 { Get-Item -LiteralPath $p }
    else { Write-Warning "Not found: $p" }
}

$hits = foreach ($f in $files) {
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errors)
    if ($errors) { Write-Warning "$($f.Name): $($errors.Count) parse error(s) - skipped."; continue }

    $lines = Get-Content -LiteralPath $f.FullName
    foreach ($c in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)) {
        $name = $c.GetCommandName()
        if (-not $name) { continue }
        $params = @($c.CommandElements |
            Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] } |
            ForEach-Object { $_.ParameterName })

        $issue = $null
        $sev = 'ACTION'
        if     ($name -eq 'Add-DhTable' -and $params -contains 'NavGroup')     { $issue = '15.1 table uses the v1 -NavGroup compat API'; $sev = 'advisory' }
        elseif ($name -in $blockCmds    -and $params -contains 'NavSubGroup')  { $issue = '15.3 block in a subgroup (invisible in 1.x, will appear)'; $sev = 'info' }
        elseif ($name -in $htmlCmds     -and $params -notcontains 'AllowHtml') { $issue = '15.2 -AllowHtml default flips to $false'; $sev = 'ACTION' }
        if (-not $issue) { continue }

        [pscustomobject]@{
            File     = $f.Name
            Line     = $c.Extent.StartLineNumber
            Cmdlet   = $name
            Severity = $sev
            Issue    = $issue
            Source   = $lines[$c.Extent.StartLineNumber - 1].Trim()
        }
    }
}

$hits = @($hits)
if (-not $hits.Count) {
    Write-Host "No 2.0.0 upgrade work required in the scanned path." -ForegroundColor Green
    return
}

if ($Detailed) { $hits | Sort-Object Severity, File, Line | Format-List File, Line, Cmdlet, Severity, Issue, Source }
else           { $hits | Sort-Object Severity, File, Line | Format-Table File, Line, Cmdlet, Severity, Issue -AutoSize }

$action = @($hits | Where-Object Severity -eq 'ACTION')
Write-Host ''
if ($action.Count) {
    Write-Host "ACTION REQUIRED: $($action.Count) call(s)" -ForegroundColor Yellow
} else {
    Write-Host "ACTION REQUIRED: none - this script upgrades as-is." -ForegroundColor Green
}
$hits | Group-Object Issue | Sort-Object Name | ForEach-Object {
    Write-Host ("  {0,3}  {1}" -f $_.Count, $_.Name) -ForegroundColor DarkGray
}
Write-Host ''
Write-Host "See readme-dev.md section 15 for how to convert each pattern." -ForegroundColor DarkGray

