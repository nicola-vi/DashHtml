<#
.SYNOPSIS
    Sync and package the 'dashhtml' Claude skill from this repository.

.DESCRIPTION
    The skill at ~\.claude\skills\dashhtml teaches an AI assistant how to use
    DashHtml. Most of it is hand-written narrative distilled from readme-dev.md
    and from lessons learned across the ProjectPS scripts - this build does NOT
    try to regenerate that prose. What it does do:

      1. Reads the hard facts from the module source (version, public cmdlet
         list, which cmdlets are nav-aware) and stamps them into SKILL.md.
      2. Regenerates references\cmdlet-index.md in full - a mechanical index of
         every public cmdlet and its nav support.
      3. Checks the hand-written files for drift: any Dh cmdlet they mention
         that no longer exists in the module, and any public cmdlet the skill
         never mentions at all.
      4. Checks every DashHtml call inside the skill's ```powershell examples
         against the real cmdlet: a parameter that does not exist (for example
         Export-DhDashboard -Path, which is -OutputPath) is reported.
      5. Checks the house-chassis names the skill relies on (Write-Log,
         Add-DhTableIfData, ...) against the ProjectPS skeleton AND the shared
         core _Common\PsReport.Core.ps1, where they live since core 1.0.0, and
         stamps the core's path and version into script-contract.md.
      6. Optionally packages the skill as a .zip for upload to claude.ai.

    Run it after adding, renaming or removing a public cmdlet, and after a
    version bump.

.PARAMETER SkillPath
    Skill directory. Defaults to skills\dashhtml in this repository (the source
    of truth), or ~\.claude\skills\dashhtml when the repo has no skills folder.

.PARAMETER SkeletonPath
    The ProjectPS report-script skeleton. references\script-contract.md names a
    few of its functions as a contract, so the build checks they still exist.
    Skipped with a warning if the file is not present (it lives outside this
    repo, so it is absent on a machine that only has DashHtml).

.PARAMETER CorePath
    The ProjectPS shared core, _Common\PsReport.Core.ps1. The skeleton loads it
    and most chassis helpers the skill names (Write-Log, Invoke-SafeSection,
    Add-DhTableIfData, ...) are defined there, not in the skeleton. Skipped with
    a warning if absent.

.PARAMETER Check
    Report only - make no changes. Exits 1 if anything is out of sync or drifted.
    Suitable for wiring into Build.ps1.

.PARAMETER Zip
    Also produce dist\dashhtml-skill-<version>.zip for claude.ai upload.

.EXAMPLE
    .\Build-DhSkill.ps1

.EXAMPLE
    .\Build-DhSkill.ps1 -Check

.EXAMPLE
    .\Build-DhSkill.ps1 -Zip
#>
[CmdletBinding()]
param(
    [string] $SkillPath = $(if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'skills\dashhtml')) {
                              Join-Path $PSScriptRoot 'skills\dashhtml'
                          } else { Join-Path $HOME '.claude\skills\dashhtml' }),
    [string] $SkeletonPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Documentation\Invoke-ProcedureName.ps1'),
    [string] $CorePath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Documentation\_Common\PsReport.Core.ps1'),
    [switch] $Check,
    [switch] $Zip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot   = $PSScriptRoot
$modulePath = Join-Path $repoRoot 'DashHtml'
$publicPath = Join-Path $modulePath 'Public'
$issues     = [System.Collections.Generic.List[string]]::new()

# Functions the skill names as belonging to the ProjectPS report-script chassis
# (the skeleton plus the shared core it loads). Listed here rather than
# discovered, so a machine without ProjectPS (a colleague who only has DashHtml)
# does not report them as unknown.
$skeletonContract = @('Write-Log', 'Invoke-SafeSection',
                      'Add-DhTableIfData', 'Get-DataCount', 'Test-DhTableRegistered',
                      'Get-DhTableFirstField', 'Join-DhNavPath')

# Reads a top-level frontmatter value, including a YAML block scalar (description: >-
# followed by indented lines, folded with spaces).
function Get-FrontmatterValue([string]$Front, [string]$Key) {
    $m = [regex]::Match($Front, "(?m)^${Key}:[ \t]*(.*)$")
    if (-not $m.Success) { return '' }
    $v = $m.Groups[1].Value.Trim()
    if ($v -notmatch '^[>|][+-]?$') { return $v.Trim('"', "'") }
    $rest  = $Front.Substring($m.Index + $m.Length).TrimStart("`r", "`n") -split "`r?`n"
    $lines = foreach ($l in $rest) { if ($l -match '^\s+\S') { $l.Trim() } else { break } }
    return (@($lines) -join ' ')
}
function Write-Step { param([string]$Text) Write-Host "  $Text" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Text) Write-Host "  $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "  $Text" -ForegroundColor Yellow }

Write-Host "`nBuild-DhSkill" -ForegroundColor White
Write-Host ("-" * 60)

# ── 1. Facts from the module source ─────────────────────────────────────────

if (-not (Test-Path -LiteralPath $publicPath)) {
    throw "Public cmdlet folder not found: $publicPath"
}

$manifest = Import-PowerShellDataFile (Join-Path $modulePath 'DashHtml.psd1')
$version  = $manifest.ModuleVersion

# One .ps1 per public cmdlet; the file name is the cmdlet name.
$cmdletFiles = Get-ChildItem -LiteralPath $publicPath -Filter '*.ps1' -File | Sort-Object Name
$cmdlets = foreach ($f in $cmdletFiles) {
    $src = Get-Content -LiteralPath $f.FullName -Raw
    [pscustomobject]@{
        Name    = $f.BaseName
        NavAware = $src -match '\$NavPath'
        # -NavGroup/-NavSubGroup without -NavPath would mean a cmdlet missed the
        # v2 nav migration; worth surfacing.
        LegacyOnly = ($src -match '\$NavGroup') -and ($src -notmatch '\$NavPath')
    }
}

$navAware   = @($cmdlets | Where-Object NavAware)
$legacyOnly = @($cmdlets | Where-Object LegacyOnly)

Write-Step "Module version : $version"
Write-Step "Public cmdlets : $($cmdlets.Count) ($($navAware.Count) nav-aware)"

if ($legacyOnly.Count -gt 0) {
    $issues.Add("Cmdlets accept -NavGroup but not -NavPath: $($legacyOnly.Name -join ', ')")
}

if (-not (Test-Path -LiteralPath $SkillPath)) {
    throw "Skill folder not found: $SkillPath`nCreate it first, or pass -SkillPath."
}

$skillMd  = Join-Path $SkillPath 'SKILL.md'
$refsPath = Join-Path $SkillPath 'references'
if (-not (Test-Path -LiteralPath $skillMd))  { throw "SKILL.md not found: $skillMd" }
if (-not (Test-Path -LiteralPath $refsPath)) { throw "references\ not found: $refsPath" }

# ── 2. Stamp the generated values into SKILL.md ─────────────────────────────

# Absolute paths are stamped from wherever this build runs, so the skill is
# correct on any machine that has a copy - that is what makes it shareable.
$skeletonStamp = if (Test-Path -LiteralPath $SkeletonPath) {
                     (Resolve-Path -LiteralPath $SkeletonPath).Path
                 } else {
                     '(not present on this machine)'
                 }
$coreStamp = '(not present on this machine)'; $coreVersion = '?'
if (Test-Path -LiteralPath $CorePath) {
    $coreStamp = (Resolve-Path -LiteralPath $CorePath).Path
    $vm = [regex]::Match((Get-Content -LiteralPath $CorePath -Raw), "PsReportCoreVersion\s*=\s*\[version\]'([\d.]+)'")
    if ($vm.Success) { $coreVersion = $vm.Groups[1].Value }
}

$targets = @(
    @{ Path   = $skillMd
       Label  = 'SKILL.md'
       Stamps = [ordered]@{
           'DH_VERSION'      = $version
           'DH_CMDLET_COUNT' = "$($cmdlets.Count)"
           # v2.1.4 - was hand-typed in SKILL.md and drifted between releases
           'DH_NAVAWARE_COUNT' = "$($navAware.Count)"
           'DH_REPO_PATH'    = $repoRoot
       } },
    @{ Path   = (Join-Path $refsPath 'script-contract.md')
       Label  = 'script-contract.md'
       Stamps = [ordered]@{
           'DH_SKELETON_PATH' = $skeletonStamp
           'DH_CORE_PATH'     = $coreStamp
           'DH_CORE_VERSION'  = $coreVersion
       } }
)

foreach ($t in $targets) {
    if (-not (Test-Path -LiteralPath $t.Path)) {
        $issues.Add("$($t.Label) not found at $($t.Path).")
        continue
    }

    $text     = Get-Content -LiteralPath $t.Path -Raw
    $original = $text

    foreach ($key in $t.Stamps.Keys) {
        $pattern = "(?s)(<!--$key-->).*?(<!--/$key-->)"
        if ($text -notmatch $pattern) {
            $issues.Add("$($t.Label) is missing the <!--$key--> marker pair.")
            continue
        }
        # MatchEvaluator rather than a replacement string: a stamped value can
        # legitimately contain '$', which would otherwise be read as a backreference.
        $value = $t.Stamps[$key]
        $text  = [regex]::Replace($text, $pattern, {
            param($m) $m.Groups[1].Value + $value + $m.Groups[2].Value })
    }

    if ($text -ne $original) {
        if ($Check) {
            $issues.Add("$($t.Label) stamped values are stale.")
        }
        else {
            Set-Content -LiteralPath $t.Path -Value $text -Encoding utf8BOM -NoNewline
            Write-Ok "$($t.Label) - stamped values updated"
        }
    }
    else {
        Write-Ok "$($t.Label) - stamped values already current"
    }
}

# ── 2b. Frontmatter ─────────────────────────────────────────────────────────
# claude.ai rejects a skill without name / description, or with a description
# longer than 1024 characters.
$front = [regex]::Match((Get-Content -LiteralPath $skillMd -Raw), '(?s)\A\s*---\s*\n(.*?)\n---')
if (-not $front.Success) { $issues.Add('SKILL.md has no YAML frontmatter.') }
else {
    $fmName = Get-FrontmatterValue $front.Groups[1].Value 'name'
    $fmDesc = Get-FrontmatterValue $front.Groups[1].Value 'description'
    if (-not $fmName) { $issues.Add('SKILL.md frontmatter has no name.') }
    if (-not $fmDesc) { $issues.Add('SKILL.md frontmatter has no description.') }
    elseif ($fmDesc.Length -gt 1024) { $issues.Add("SKILL.md description is $($fmDesc.Length) characters; claude.ai allows 1024.") }
    else { Write-Ok "frontmatter - ok (description $($fmDesc.Length) / 1024 characters)" }
}
# ── 3. Regenerate the mechanical cmdlet index ───────────────────────────────

$indexPath = Join-Path $refsPath 'cmdlet-index.md'
$sb = [System.Text.StringBuilder]::new()

[void]$sb.AppendLine('# DashHtml cmdlet index')
[void]$sb.AppendLine()
[void]$sb.AppendLine('<!-- GENERATED BY Build-DhSkill.ps1 - DO NOT EDIT BY HAND -->')
[void]$sb.AppendLine()
[void]$sb.AppendLine("Module version **$version** - $($cmdlets.Count) public cmdlets, $($navAware.Count) nav-aware.")
[void]$sb.AppendLine()
[void]$sb.AppendLine('Nav-aware cmdlets accept `-NavPath`, `-NavScope`, `-NavLabel` and `-NavOrder`')
[void]$sb.AppendLine('(plus the `-NavGroup` / `-NavSubGroup` compat shim). See `navigation.md`.')
[void]$sb.AppendLine()
[void]$sb.AppendLine('| Cmdlet | Nav-aware |')
[void]$sb.AppendLine('|---|---|')
foreach ($c in $cmdlets) {
    $mark = if ($c.NavAware) { 'yes' } else { 'no' }
    [void]$sb.AppendLine("| ``$($c.Name)`` | $mark |")
}
[void]$sb.AppendLine()
[void]$sb.AppendLine('Full parameter signatures: `DashHtml-Reference.html` in the repo, or')
[void]$sb.AppendLine('`Get-Help <cmdlet> -Full` with the module imported.')

$newIndex = $sb.ToString()
$oldIndex = if (Test-Path -LiteralPath $indexPath) { Get-Content -LiteralPath $indexPath -Raw } else { '' }

if ($newIndex -ne $oldIndex) {
    if ($Check) {
        $issues.Add('references\cmdlet-index.md is out of date.')
    }
    else {
        Set-Content -LiteralPath $indexPath -Value $newIndex -Encoding utf8BOM -NoNewline
        Write-Ok 'cmdlet-index.md - regenerated'
    }
}
else {
    Write-Ok 'cmdlet-index.md - already current'
}

# ── 4. Drift checks against the hand-written prose ──────────────────────────

$handWritten = Get-ChildItem -LiteralPath $SkillPath -Filter '*.md' -Recurse -File |
               Where-Object { $_.Name -ne 'cmdlet-index.md' }

# A name is "known" if it exists anywhere the skill legitimately refers to:
# DashHtml public cmdlets, DashHtml private helpers (the skill explains a few by
# name), and DashHtml.Design public cmdlets such as Update-DhScript.
$known = [System.Collections.Generic.List[string]]::new()
$cmdlets.Name | ForEach-Object { $known.Add($_) }

foreach ($extra in @(
        (Join-Path $modulePath 'Private'),
        (Join-Path $repoRoot 'DashHtml.Design\Public'),
        (Join-Path $repoRoot 'DashHtml.Design\Private'))) {
    if (Test-Path -LiteralPath $extra) {
        Get-ChildItem -LiteralPath $extra -Filter '*.ps1' -File |
            ForEach-Object { $known.Add($_.BaseName) }
    }
}

# Helpers that live in the ProjectPS report-script skeleton, not in the module.
# The contract names are always known; the rest are discovered when the skeleton
# is actually present. Parsed once here, reused by the check below.
$skeletonContract | ForEach-Object { $known.Add($_) }

# Chassis functions: the skeleton's own plus the shared core's (which the skeleton
# dot-sources). Since core 1.0.0 the guard helpers live in the core.
$skelFuncs = @()
foreach ($src in @($SkeletonPath, $CorePath)) {
    if (Test-Path -LiteralPath $src) {
        $skelFuncs += @([regex]::Matches(
                        (Get-Content -LiteralPath $src -Raw),
                        '(?m)^\s*function\s+([A-Za-z]+-[A-Za-z]+)') |
                       ForEach-Object { $_.Groups[1].Value })
    }
}
$skelFuncs = @($skelFuncs | Sort-Object -Unique)
$skelFuncs | ForEach-Object { $known.Add($_) }

$mentioned = [System.Collections.Generic.HashSet[string]]::new(
                [string[]]@(), [System.StringComparer]::OrdinalIgnoreCase)
$unknown   = [System.Collections.Generic.HashSet[string]]::new(
                [string[]]@(), [System.StringComparer]::OrdinalIgnoreCase)

foreach ($file in $handWritten) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    # Verb-Dh* tokens only; avoids matching prose like "the Dh model".
    foreach ($m in [regex]::Matches($text, '\b[A-Z][a-z]+-Dh[A-Za-z]+\b')) {
        $name = $m.Value
        [void]$mentioned.Add($name)
        # Report each unknown name once, not once per occurrence.
        if (($known -notcontains $name) -and $unknown.Add($name)) {
            $issues.Add("$($file.Name): mentions '$name', which exists nowhere in the repo.")
        }
    }
}

# Coverage is only meaningful for the public surface.
$never = @($cmdlets.Name | Where-Object { -not $mentioned.Contains($_) })
if ($never.Count -gt 0) {
    Write-Warn "Not mentioned anywhere in the skill: $($never -join ', ')"
}

# ── 4a. Parameters used in the examples ─────────────────────────────────────
# Every DashHtml call in a ```powershell block must use parameters the cmdlet
# really has. Prose cannot be checked this way; code can. The module is loaded
# from THIS repo in a child process so the check never depends on (or disturbs)
# whatever DashHtml the session happens to have imported.

$paramDump = pwsh -NoProfile -NonInteractive -Command @"
Import-Module '$(Join-Path $modulePath 'DashHtml.psd1')' -Force
Get-Command -Module DashHtml -CommandType Function | ForEach-Object {
    `$c = `$_
    `$names = foreach (`$p in `$c.Parameters.Values) { `$p.Name; `$p.Aliases }
    '{0}={1}' -f `$c.Name, ((`$names | Where-Object { `$_ }) -join ',')
}
"@
$cmdParams = @{}
foreach ($line in $paramDump) {
    $k, $v = $line -split '=', 2
    if ($k) { $cmdParams[$k] = @($v -split ',') }
}
$exampleCalls = 0
foreach ($file in $handWritten) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($block in [regex]::Matches($text, '(?s)```powershell\s*\n(.*?)```')) {
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($block.Groups[1].Value, [ref]$null, [ref]$null)
        foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            $name = $c.GetCommandName()
            if (-not $name -or -not $cmdParams.ContainsKey($name)) { continue }
            $exampleCalls++
            foreach ($e in $c.CommandElements) {
                if ($e -isnot [System.Management.Automation.Language.CommandParameterAst]) { continue }
                # PowerShell accepts any unambiguous prefix of a parameter name.
                $hits = @($cmdParams[$name] | Where-Object { $_ -like "$($e.ParameterName)*" })
                if ($hits.Count -eq 0) {
                    $issues.Add("$($file.Name): example calls $name -$($e.ParameterName), which $name does not have.")
                }
            }
        }
    }
}
Write-Ok "examples  - $exampleCalls DashHtml call(s) in code blocks checked against the real parameters"

# ── 4b. Skeleton contract check ─────────────────────────────────────────────
# script-contract.md points at the skeleton by path (always current) but also
# names a few of its functions as a contract. Those names are the only thing
# that can drift when the skeleton is edited, so verify just those.

$contractMd = Join-Path $refsPath 'script-contract.md'

if (-not (Test-Path -LiteralPath $SkeletonPath)) {
    Write-Warn "skeleton not found - skipped ($SkeletonPath)"
}
elseif (-not (Test-Path -LiteralPath $contractMd)) {
    Write-Warn 'script-contract.md not found - skeleton check skipped'
}
else {
    $contract = Get-Content -LiteralPath $contractMd -Raw
    # $skelFuncs was parsed in step 4.

    $claimed = $skeletonContract

    foreach ($fn in $claimed) {
        if ($contract -match [regex]::Escape($fn)) {
            if ($skelFuncs -notcontains $fn) {
                $issues.Add("script-contract.md claims the chassis supplies '$fn', but neither the skeleton nor PsReport.Core defines it.")
            }
        }
    }
    if (-not (Test-Path -LiteralPath $CorePath)) {
        Write-Warn "PsReport.Core not found - chassis names checked against the skeleton only ($CorePath)"
    }

    # Informational only: the skill deliberately summarises (export, startup and
    # data helpers belong to the ps-report-script skill), so an unmentioned
    # helper is not an error - just worth seeing when it is newly added.
    $unmentioned = @($skelFuncs | Where-Object { $contract -notmatch [regex]::Escape($_) })
    if ($unmentioned.Count -gt 0) {
        Write-Verbose "chassis helpers not mentioned in script-contract.md: $($unmentioned -join ', ')"
    }

    Write-Ok "chassis   - $($skelFuncs.Count) functions (skeleton + PsReport.Core $coreVersion), $($claimed.Count) contract names verified"
}

# ── 5. Package ──────────────────────────────────────────────────────────────

if ($Zip -and -not $Check) {
    $distPath = Join-Path $repoRoot 'dist'
    if (-not (Test-Path -LiteralPath $distPath)) {
        New-Item -ItemType Directory -Path $distPath | Out-Null
    }
    $zipPath = Join-Path $distPath "dashhtml-skill-$version.zip"
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

    # Zip the folder itself, so the archive contains dashhtml\SKILL.md - the
    # layout claude.ai expects on upload.
    Compress-Archive -Path $SkillPath -DestinationPath $zipPath
    $kb = [math]::Round((Get-Item -LiteralPath $zipPath).Length / 1KB, 1)
    Write-Ok "packaged  - $zipPath ($kb KB)"
}

# ── 6. Report ───────────────────────────────────────────────────────────────

Write-Host ("-" * 60)

if ($issues.Count -gt 0) {
    Write-Host "$($issues.Count) issue(s):" -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    if ($Check) { exit 1 }
}
else {
    Write-Host "Skill is in sync with DashHtml $version." -ForegroundColor Green
}

Write-Host ''
