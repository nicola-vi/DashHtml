#Requires -Version 7.0
<#
.SYNOPSIS
    Build.ps1 - Build and package the DashHtml PowerShell module.

.DESCRIPTION
    1. Validates the module manifest and source structure.
    2. Runs Pester tests (if Pester >= 5 is available).
    3. Produces a clean distributable in .\dist\DashHtml\.
    4. Optionally bumps the patch version in the manifest.
    5. Creates a .zip archive suitable for a GitHub Release asset.

.PARAMETER BumpVersion
    Increment the patch segment of the module version before building
    (e.g. 1.0.0 -> 1.0.1).

.PARAMETER SkipTests
    Skip the Pester test run (useful for rapid local iteration).

.PARAMETER NuGet
    Also pack the module as a .nupkg for publishing to PSGallery / private feed.

.EXAMPLE
    .\Build.ps1
    .\Build.ps1 -BumpVersion
    .\Build.ps1 -SkipTests -NuGet
#>
[CmdletBinding()]
param(
    [switch] $BumpVersion,
    [switch] $SkipTests,
    [switch] $NuGet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot   = $PSScriptRoot
$srcDir     = Join-Path $repoRoot 'DashHtml'
$distRoot   = Join-Path $repoRoot 'dist'
$distModule = Join-Path $distRoot 'DashHtml'
$psdFile    = Join-Path $srcDir   'DashHtml.psd1'

Write-Host ''
Write-Host '╔══════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║   DashHtml  BUILD                    ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''

# ── Step 1: Read manifest ────────────────────────────────────────────────────
$manifest = Import-PowerShellDataFile $psdFile
$version  = [version]$manifest.ModuleVersion
$totalSteps = if ($NuGet) { 6 } else { 5 }
Write-Host "[1/$totalSteps] Current version: $version" -ForegroundColor White

# ── Step 2: Bump version (optional) ─────────────────────────────────────────
if ($BumpVersion) {
    $newVersion = [version]::new($version.Major, $version.Minor, $version.Build + 1)
    (Get-Content $psdFile -Raw) -replace "ModuleVersion\s*=\s*'[^']+'"  ,
        "ModuleVersion     = '$newVersion'" |
        Set-Content $psdFile -Encoding UTF8
    Write-Host "     Version bumped: $version -> $newVersion" -ForegroundColor Yellow
    $version = $newVersion
}

# ── Step 3: Validate manifest ────────────────────────────────────────────────
Write-Host "[2/$totalSteps] Validating manifest..." -ForegroundColor White
try {
    Test-ModuleManifest $psdFile | Out-Null
    Write-Host "     Manifest OK" -ForegroundColor Green
} catch {
    Write-Error "Manifest validation failed: $_"
}

# ── Step 4: Pester tests ─────────────────────────────────────────────────────
Write-Host "[3/$totalSteps] Running tests..." -ForegroundColor White
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

# ── Step 5: Stage dist\ ──────────────────────────────────────────────────────
Write-Host "[4/$totalSteps] Staging dist..." -ForegroundColor White
if (Test-Path $distModule) { Remove-Item $distModule -Recurse -Force }
New-Item -ItemType Directory -Path $distModule -Force | Out-Null

$include = @('*.psd1','*.psm1')
# Copy root module files  (Get-ChildItem -Include requires -Recurse or path\* to work;
# use a wildcard path instead to avoid silently skipping the manifest and root module)
foreach ($pattern in $include) {
    Get-ChildItem -Path (Join-Path $srcDir $pattern) -ErrorAction SilentlyContinue |
        Copy-Item -Destination $distModule
}

# Copy sub-folders (Public, Private, etc.)
foreach ($subDir in (Get-ChildItem -Path $srcDir -Directory)) {
    $dest = Join-Path $distModule $subDir.Name
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Get-ChildItem -Path $subDir.FullName -Filter '*.ps1' |
        Copy-Item -Destination $dest
}

# Update version in dist copy if bumped
if ($BumpVersion) {
    $distPsd = Join-Path $distModule 'DashHtml.psd1'
    (Get-Content $distPsd -Raw) -replace "ModuleVersion\s*=\s*'[^']+'",
        "ModuleVersion     = '$version'" |
        Set-Content $distPsd -Encoding UTF8
}

Write-Host "     Staged to: $distModule" -ForegroundColor Green

# ── Step 6: Zip archive ───────────────────────────────────────────────────────
Write-Host "[5/$totalSteps] Creating zip archive..." -ForegroundColor White
$zipName = "DashHtml-v$version.zip"
$zipPath = Join-Path $distRoot $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $distModule -DestinationPath $zipPath
$zipKB = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
Write-Host "     $zipPath  ($zipKB KB)" -ForegroundColor Green

# ── Optional: NuGet ───────────────────────────────────────────────────────────
if ($NuGet) {
    Write-Host "[6/$totalSteps] Packing NuGet..." -ForegroundColor White
    $nugetDest = $distRoot
    Register-PSRepository -Name 'LocalBuild' -SourceLocation $nugetDest `
        -PublishLocation $nugetDest -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    Publish-Module -Path $distModule -Repository 'LocalBuild' -Force
    $nupkg = Get-ChildItem $nugetDest -Filter '*.nupkg' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Host "     $($nupkg.FullName)" -ForegroundColor Green
    Unregister-PSRepository -Name 'LocalBuild' -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "Build complete: DashHtml v$version" -ForegroundColor Cyan
Write-Host ''
