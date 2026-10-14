#Requires -Version 7.0
<#
.SYNOPSIS
    Build.ps1 - Build and package the DashHtml PowerShell modules.

.DESCRIPTION
    Builds two INDEPENDENTLY PUBLISHABLE modules from this repo:

      DashHtml          the core dashboard module
      DashHtml.Design   the optional YAML design / round-trip companion

    Each gets its own manifest validation, its own dist\<Module>\ staging
    folder, its own versioned .zip, and its own .nupkg (-NuGet). They are
    versioned separately: -BumpVersion bumps the core, -BumpDesignVersion
    bumps the companion.

    Steps:
    1. Reads both module manifests.
    2. Optionally bumps either patch version.
    3. Validates both manifests (+ the PSGallery ReleaseNotes length cap).
    4. Runs PSScriptAnalyzer over both module sources.
    5. Runs the Pester suite (covers both modules).
    6. Stages clean distributables into .\dist\.
    7. Creates a .zip per module, suitable for a GitHub Release asset.
    8. Optionally packs a .nupkg per module for PSGallery / a private feed.

.PARAMETER BumpVersion
    Increment the patch segment of the CORE module version (e.g. 1.10.2 -> 1.10.3).

.PARAMETER BumpDesignVersion
    Increment the patch segment of the DashHtml.Design version.

.PARAMETER SkipTests
    Skip the Pester test run (useful for rapid local iteration).

.PARAMETER SkipLint
    Skip the PSScriptAnalyzer run (useful for rapid local iteration).

.PARAMETER SkipDesign
    Build only the core module; ignore DashHtml.Design entirely.

.PARAMETER NuGet
    Also pack each module as a .nupkg for publishing.

.EXAMPLE
    .\Build.ps1
    .\Build.ps1 -BumpVersion
    .\Build.ps1 -BumpDesignVersion -NuGet
    .\Build.ps1 -SkipDesign -SkipTests
#>
[CmdletBinding()]
param(
    [switch] $BumpVersion,
    [switch] $BumpDesignVersion,
    [switch] $SkipTests,
    [switch] $SkipLint,
    [switch] $SkipDesign,
    [switch] $NuGet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot   = $PSScriptRoot
$distRoot   = Join-Path $repoRoot 'dist'
$lintCfg    = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'

$srcDir     = Join-Path $repoRoot 'DashHtml'
$psdFile    = Join-Path $srcDir   'DashHtml.psd1'
$designSrc  = Join-Path $repoRoot 'DashHtml.Design'
$designPsd  = Join-Path $designSrc 'DashHtml.Design.psd1'

# DashHtml.Design is optional — skip cleanly if the folder isn't present.
$buildDesign = (-not $SkipDesign) -and (Test-Path -LiteralPath $designPsd)

# ── Helpers ──────────────────────────────────────────────────────────────────
function Step-DhBumpVersion {
    <# Increment the patch segment in a manifest, return the new [version]. #>
    param([string] $PsdPath, [version] $Current)
    $new = [version]::new($Current.Major, $Current.Minor, $Current.Build + 1)
    (Get-Content $PsdPath -Raw) -replace "ModuleVersion\s*=\s*'[^']+'",
        "ModuleVersion     = '$new'" |
        Set-Content $PsdPath -Encoding UTF8
    return $new
}

function Test-DhManifest {
    <# Validate a manifest and enforce the PSGallery ReleaseNotes length cap. #>
    param([string] $PsdPath, [string] $Label)
    try {
        Test-ModuleManifest $PsdPath | Out-Null
        Write-Host "     $Label manifest OK" -ForegroundColor Green
    } catch {
        Write-Error "$Label manifest validation failed: $_"
    }
    # PSGallery rejects a ReleaseNotes value longer than 10,600 characters. Keep
    # ReleaseNotes to the current release only (point to CHANGELOG.md for
    # history) — this guard fails the build BEFORE a doomed publish attempt.
    $releaseNotes = (Import-PowerShellDataFile $PsdPath).PrivateData.PSData.ReleaseNotes
    if ($releaseNotes -and $releaseNotes.Length -gt 10600) {
        Write-Error ("BUILD FAILED: $Label ReleaseNotes is $($releaseNotes.Length) chars; " +
            "PSGallery caps it at 10600. Trim it to the current release and link CHANGELOG.md for older versions.")
    }
}

function Copy-DhModuleToDist {
    <#
        Stage one module into dist\: manifest + root module, every subfolder's
        *.ps1, plus docs. A module-local README.md wins over the repo-root one,
        so DashHtml.Design ships its own page on PSGallery.
    #>
    param([string] $SourceDir, [string] $DestDir)

    if (Test-Path $DestDir) { Remove-Item $DestDir -Recurse -Force }
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null

    # Root module files. (Get-ChildItem -Include needs -Recurse or a wildcard
    # path to work; use a wildcard path so the manifest isn't silently skipped.)
    foreach ($pattern in @('*.psd1','*.psm1')) {
        Get-ChildItem -Path (Join-Path $SourceDir $pattern) -ErrorAction SilentlyContinue |
            Copy-Item -Destination $DestDir
    }

    # Sub-folders (Public, Private, ...): only *.ps1, so stray backups and
    # scratch files never ship.
    # v2.2.0 - Vendor\ is the exception: it holds the export libraries that
    # Export-DhDashboard -ExportLibraries Embed inlines, plus their licences,
    # and must ship whole. Without this the staged module would silently lose
    # them and Embed would fail on every machine that installed from dist\.
    foreach ($subDir in (Get-ChildItem -Path $SourceDir -Directory)) {
        $dest = Join-Path $DestDir $subDir.Name
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        $filter = if ($subDir.Name -eq 'Vendor') { '*' } else { '*.ps1' }
        Get-ChildItem -Path $subDir.FullName -Filter $filter -File |
            Copy-Item -Destination $dest
    }

    # README: module-local first, else the repo root one. Without a README
    # PSGallery shows the package page with no description and dotnet pack
    # emits the "missing a readme" warning.
    $localReadme = Join-Path $SourceDir 'README.md'
    if (Test-Path -LiteralPath $localReadme) {
        Copy-Item -LiteralPath $localReadme -Destination $DestDir -Force
    } elseif (Test-Path -LiteralPath (Join-Path $repoRoot 'README.md')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot 'README.md') -Destination $DestDir -Force
    }

    # LICENSE alongside for completeness (Publish-Module 2.x still uses
    # LicenseUri from the manifest; Publish-PSResource picks the file up).
    foreach ($docPattern in @('LICENSE','LICENSE.txt')) {
        $src = Join-Path $repoRoot $docPattern
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination $DestDir -Force
        }
    }
}

function New-DhZip {
    param([string] $StagedDir, [string] $ModuleName, [version] $Version)
    $zipPath = Join-Path $distRoot "$ModuleName-v$Version.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path $StagedDir -DestinationPath $zipPath
    $zipKB = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
    Write-Host "     $zipPath  ($zipKB KB)" -ForegroundColor Green
}

Write-Host ''
Write-Host '╔══════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║   DashHtml  BUILD                    ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''

$totalSteps = if ($NuGet) { 7 } else { 6 }

# ── Step 1: Read manifests ───────────────────────────────────────────────────
$version = [version](Import-PowerShellDataFile $psdFile).ModuleVersion
Write-Host "[1/$totalSteps] Current version: DashHtml $version" -ForegroundColor White
if ($buildDesign) {
    $designVersion = [version](Import-PowerShellDataFile $designPsd).ModuleVersion
    Write-Host "     Companion:       DashHtml.Design $designVersion" -ForegroundColor White
} else {
    Write-Host "     Companion:       DashHtml.Design (skipped)" -ForegroundColor DarkGray
}

# ── Step 2: Bump versions (optional) ─────────────────────────────────────────
if ($BumpVersion) {
    $newVersion = Step-DhBumpVersion -PsdPath $psdFile -Current $version
    Write-Host "     DashHtml version bumped: $version -> $newVersion" -ForegroundColor Yellow
    $version = $newVersion
}
if ($BumpDesignVersion) {
    if (-not $buildDesign) {
        Write-Warning "-BumpDesignVersion ignored: DashHtml.Design is not being built."
    } else {
        $newDesign = Step-DhBumpVersion -PsdPath $designPsd -Current $designVersion
        Write-Host "     DashHtml.Design version bumped: $designVersion -> $newDesign" -ForegroundColor Yellow
        $designVersion = $newDesign
    }
}

# ── Step 3: Validate manifests ───────────────────────────────────────────────
Write-Host "[2/$totalSteps] Validating manifests..." -ForegroundColor White
Test-DhManifest -PsdPath $psdFile -Label 'DashHtml'
if ($buildDesign) { Test-DhManifest -PsdPath $designPsd -Label 'DashHtml.Design' }

# ── Step 4: PSScriptAnalyzer ─────────────────────────────────────────────────
# Fails the build on Error-severity findings only; Warnings are reported but
# non-fatal. Rule exclusions + rationale live in PSScriptAnalyzerSettings.psd1.
Write-Host "[3/$totalSteps] Running PSScriptAnalyzer..." -ForegroundColor White
if ($SkipLint) {
    Write-Host "     SKIPPED (-SkipLint)" -ForegroundColor DarkGray
} else {
    $pssaModule = Get-Module -Name PSScriptAnalyzer -ListAvailable |
                  Sort-Object Version -Descending |
                  Select-Object -First 1
    if ($pssaModule) {
        Import-Module $pssaModule.Path -Force
        $lintPaths = @($srcDir)
        if ($buildDesign) { $lintPaths += $designSrc }

        $findings = @()
        foreach ($lintPath in $lintPaths) {
            $analyzerArgs = @{ Path = $lintPath; Recurse = $true }
            if (Test-Path $lintCfg) { $analyzerArgs['Settings'] = $lintCfg }
            $findings += @(Invoke-ScriptAnalyzer @analyzerArgs)
        }
        $errors   = @($findings | Where-Object Severity -eq 'Error')
        $warnings = @($findings | Where-Object Severity -eq 'Warning')

        foreach ($f in $errors) {
            Write-Host ("     [Error]   {0}:{1}  {2}  {3}" -f `
                (Split-Path $f.ScriptPath -Leaf), $f.Line, $f.RuleName, $f.Message) -ForegroundColor Red
        }
        foreach ($f in $warnings) {
            Write-Host ("     [Warning] {0}:{1}  {2}  {3}" -f `
                (Split-Path $f.ScriptPath -Leaf), $f.Line, $f.RuleName, $f.Message) -ForegroundColor Yellow
        }

        if ($errors.Count -gt 0) {
            Write-Error "BUILD FAILED: PSScriptAnalyzer reported $($errors.Count) error(s)."
        }
        if ($warnings.Count -gt 0) {
            Write-Host "     Lint: 0 errors, $($warnings.Count) warning(s)" -ForegroundColor Yellow
        } else {
            Write-Host "     Lint clean (0 errors, 0 warnings)" -ForegroundColor Green
        }
    } else {
        Write-Warning "PSScriptAnalyzer not found. Install with: Install-Module PSScriptAnalyzer -Force. Skipping lint."
    }
}

# ── Step 5: Pester tests (one suite, covers both modules) ────────────────────
Write-Host "[4/$totalSteps] Running tests..." -ForegroundColor White
if ($SkipTests) {
    Write-Host "     SKIPPED (-SkipTests)" -ForegroundColor DarkGray
} else {
    $pesterModule = Get-Module -Name Pester -ListAvailable |
                    Where-Object { $_.Version -ge [version]'5.0' } |
                    Sort-Object Version -Descending |
                    Select-Object -First 1
    if ($pesterModule) {
        Import-Module $pesterModule.Path -Force
        $testPath = Join-Path $repoRoot 'Tests'
        if (Test-Path $testPath) {
            $result = Invoke-Pester -Path $testPath -PassThru -Output Minimal
            if ($result.FailedCount -gt 0) {
                Write-Error "BUILD FAILED: $($result.FailedCount) test(s) failed."
            }
            Write-Host "     Tests passed: $($result.PassedCount)  Failed: $($result.FailedCount)" -ForegroundColor Green
        } else {
            Write-Host "     No Tests\ directory found - skipping." -ForegroundColor DarkGray
        }
    } else {
        Write-Warning "Pester 5+ not found. Install with: Install-Module Pester -Force. Skipping tests."
    }
}

# ── Step 6: Stage dist\ ──────────────────────────────────────────────────────
Write-Host "[5/$totalSteps] Staging dist..." -ForegroundColor White
$distModule = Join-Path $distRoot 'DashHtml'
Copy-DhModuleToDist -SourceDir $srcDir -DestDir $distModule
if ($BumpVersion) {
    $distPsd = Join-Path $distModule 'DashHtml.psd1'
    (Get-Content $distPsd -Raw) -replace "ModuleVersion\s*=\s*'[^']+'",
        "ModuleVersion     = '$version'" | Set-Content $distPsd -Encoding UTF8
}
Write-Host "     Staged: $distModule" -ForegroundColor Green

if ($buildDesign) {
    $distDesign = Join-Path $distRoot 'DashHtml.Design'
    Copy-DhModuleToDist -SourceDir $designSrc -DestDir $distDesign
    if ($BumpDesignVersion) {
        $distPsd = Join-Path $distDesign 'DashHtml.Design.psd1'
        (Get-Content $distPsd -Raw) -replace "ModuleVersion\s*=\s*'[^']+'",
            "ModuleVersion     = '$designVersion'" | Set-Content $distPsd -Encoding UTF8
    }
    Write-Host "     Staged: $distDesign" -ForegroundColor Green
}

# ── Step 7: Zip archives (one per module) ────────────────────────────────────
Write-Host "[6/$totalSteps] Creating zip archives..." -ForegroundColor White
New-DhZip -StagedDir $distModule -ModuleName 'DashHtml' -Version $version
if ($buildDesign) {
    New-DhZip -StagedDir $distDesign -ModuleName 'DashHtml.Design' -Version $designVersion
}

# ── Optional: NuGet (one .nupkg per module) ──────────────────────────────────
if ($NuGet) {
    Write-Host "[7/$totalSteps] Packing NuGet..." -ForegroundColor White

    $packTargets = @(
        @{ Dir = $distModule; Name = 'DashHtml'; Version = $version }
    )
    if ($buildDesign) {
        $packTargets += @{ Dir = $distDesign; Name = 'DashHtml.Design'; Version = $designVersion }
    }

    Register-PSRepository -Name 'LocalBuild' -SourceLocation $distRoot `
        -PublishLocation $distRoot -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    try {
        foreach ($t in $packTargets) {
            # dist\ IS the LocalBuild repository's source location, so a .nupkg
            # left from a previous run makes Publish-Module refuse with "version
            # already available". Drop the stale package first so re-packing the
            # same version is idempotent (re-packing is a local build artefact
            # step; it never touches a real feed).
            $existing = Join-Path $distRoot ("{0}.{1}.nupkg" -f $t.Name, $t.Version)
            if (Test-Path -LiteralPath $existing) { Remove-Item -LiteralPath $existing -Force }

            Publish-Module -Path $t.Dir -Repository 'LocalBuild' -Force
            if (Test-Path -LiteralPath $existing) {
                Write-Host "     $existing" -ForegroundColor Green
            } else {
                Write-Warning "Expected package not produced: $existing"
            }
        }
    } finally {
        Unregister-PSRepository -Name 'LocalBuild' -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host "Build complete: DashHtml v$version" -ForegroundColor Cyan
if ($buildDesign) {
    Write-Host "                DashHtml.Design v$designVersion" -ForegroundColor Cyan
}
Write-Host ''
