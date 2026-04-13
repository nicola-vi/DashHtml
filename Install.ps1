#Requires -Version 7.0
<#
.SYNOPSIS
    Install.ps1 — installs DashHtml into the PowerShell module path.

.DESCRIPTION
    Copies the module into a properly versioned directory:
        <ModulesRoot>\DashHtml\<Version>\

    Scope behaviour mirrors Install-Module:
      • Default when running non-elevated : CurrentUser  (no admin required)
      • Default when running elevated     : AllUsers
      • -Scope parameter always wins

    Scope paths:
      CurrentUser : $HOME\Documents\PowerShell\Modules          (Windows PS 7)
                    $HOME/.local/share/powershell/Modules        (Linux/macOS)
      AllUsers    : $env:ProgramFiles\PowerShell\Modules         (Windows PS 7)
                    /usr/local/share/powershell/Modules          (Linux/macOS)

.PARAMETER Scope
    CurrentUser (default for non-elevated) or AllUsers (default when elevated).

.PARAMETER Source
    Path to the module directory to install.
    Defaults to .\dist\DashHtml if built, otherwise .\DashHtml.

.PARAMETER Force
    Overwrite an existing installation of the same version.

.PARAMETER Uninstall
    Remove all installed versions of DashHtml for the chosen scope.

.EXAMPLE
    .\Install.ps1
    .\Install.ps1 -Scope AllUsers -Force
    .\Install.ps1 -Scope CurrentUser
    .\Install.ps1 -Uninstall
    .\Install.ps1 -Source '.\DashHtml' -Force
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string] $Scope    = '',        # empty = auto-detect from elevation

    [string] $Source   = '',
    [switch] $Force,
    [switch] $Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Banner ──────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '╔══════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║   DashHtml  INSTALL                  ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''

# ── Detect elevation ────────────────────────────────────────────────────────
function Test-Elevated {
    if ($IsWindows) {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        return ([Security.Principal.WindowsPrincipal]$id).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator)
    } else {
        return (id -u) -eq 0
    }
}

$elevated = Test-Elevated

# ── Resolve scope ───────────────────────────────────────────────────────────
if (-not $Scope) {
    $Scope = if ($elevated) { 'AllUsers' } else { 'CurrentUser' }
    Write-Host "  Scope   : $Scope (auto-detected, elevation=$(($elevated).ToString().ToLower()))" -ForegroundColor DarkGray
} else {
    Write-Host "  Scope   : $Scope (explicit)" -ForegroundColor DarkGray
    if ($Scope -eq 'AllUsers' -and -not $elevated) {
        Write-Warning "Scope 'AllUsers' requires an elevated (Administrator) session."
        Write-Warning "Re-run as Administrator or use -Scope CurrentUser."
        throw "Scope 'AllUsers' requires an elevated (Administrator) session."
    }
}

# ── Determine module root for chosen scope ───────────────────────────────────
function Get-ModuleRoot {
    param([string] $ScopeArg)

    # Try to find the matching path directly from PSModulePath first
    $paths = $env:PSModulePath -split [IO.Path]::PathSeparator

    if ($ScopeArg -eq 'CurrentUser') {
        # Look for a path inside the user's home
        $homeNorm = $HOME -replace '\\','/'
        $match = $paths | Where-Object {
            $n = $_ -replace '\\','/'
            $n.StartsWith($homeNorm, [StringComparison]::OrdinalIgnoreCase)
        } | Select-Object -First 1
        if ($match) { return $match }

        # Fallback: construct the standard path
        if ($IsWindows) {
            return Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules'
        } else {
            return Join-Path $HOME '.local/share/powershell/Modules'
        }
    } else {
        # AllUsers — look for path under ProgramFiles or /usr/local
        $match = $paths | Where-Object {
            $n = $_ -replace '\\','/'
            $n -notlike "*$($HOME -replace '\\','/')*"
        } | Where-Object {
            ($IsWindows -and ($_ -like '*Program*')) -or
            (-not $IsWindows -and ($_ -like '*/usr/local/*' -or $_ -like '*/usr/share/*'))
        } | Select-Object -First 1
        if ($match) { return $match }

        # Fallback: construct standard AllUsers path
        if ($IsWindows) {
            return Join-Path $env:ProgramFiles 'PowerShell\Modules'
        } else {
            return '/usr/local/share/powershell/Modules'
        }
    }
}

$moduleRoot = Get-ModuleRoot -ScopeArg $Scope

# ── Resolve source ───────────────────────────────────────────────────────────
if (-not $Source) {
    $dist    = Join-Path $PSScriptRoot 'dist\DashHtml'
    $src     = Join-Path $PSScriptRoot 'DashHtml'
    $distPsd = Join-Path $dist 'DashHtml.psd1'
    $srcPsd  = Join-Path $src  'DashHtml.psd1'

    if ((Test-Path $dist) -and (Test-Path $distPsd)) {
        $Source = $dist
    } elseif (Test-Path $srcPsd) {
        $Source = $src
        if (Test-Path $dist) {
            Write-Warning "dist\DashHtml exists but has no manifest - falling back to .\DashHtml"
        }
    } else {
        throw "Cannot find DashHtml.psd1 in '$dist' or '$src'. Run .\Build.ps1 first."
    }
}

if (-not (Test-Path $Source)) {
    throw "Source directory not found: '$Source'"
}

$psdFile = Join-Path $Source 'DashHtml.psd1'
if (-not (Test-Path $psdFile)) {
    throw "No DashHtml.psd1 found in '$Source'."
}

$manifest = Import-PowerShellDataFile $psdFile
$version  = $manifest.ModuleVersion
$modName  = 'DashHtml'

# Install target: <root>\DashHtml\<version>\
$installBase = Join-Path $moduleRoot $modName
$installDest = Join-Path $installBase $version

Write-Host "  Module  : $modName  v$version" -ForegroundColor Cyan
Write-Host "  Source  : $Source"              -ForegroundColor DarkGray
Write-Host "  Target  : $installDest"         -ForegroundColor DarkGray
Write-Host ''

# ── Uninstall ────────────────────────────────────────────────────────────────
if ($Uninstall) {
    if (Test-Path $installBase) {
        if ($PSCmdlet.ShouldProcess($installBase, 'Remove module directory tree')) {
            Remove-Item $installBase -Recurse -Force
            Write-Host "  Uninstalled: $installBase" -ForegroundColor Yellow

            # Also remove from current session
            Remove-Module $modName -ErrorAction SilentlyContinue
        }
    } else {
        Write-Warning "Module not found at '$installBase' for scope '$Scope' - nothing to uninstall."
    }
    Write-Host ''
    return
}

# ── Check for existing install ───────────────────────────────────────────────
if (Test-Path $installDest) {
    if ($Force) {
        Remove-Item $installDest -Recurse -Force
        Write-Host "  Removed existing v$version installation." -ForegroundColor DarkGray
    } else {
        Write-Warning "v$version is already installed at '$installDest'."
        Write-Warning "Use -Force to reinstall, or -Uninstall to remove all versions."
        Write-Host ''
        return
    }
}

# ── Copy files ───────────────────────────────────────────────────────────────
if ($PSCmdlet.ShouldProcess($installDest, 'Copy module files')) {
    New-Item -ItemType Directory -Path $installDest -Force | Out-Null
    Copy-Item -Path (Join-Path $Source '*') -Destination $installDest -Recurse -Force

    # Count copied files for confirmation
    $copied = (Get-ChildItem $installDest -Recurse -File).Count
    Write-Host "  Copied $copied files to: $installDest" -ForegroundColor Green
}

# ── Verify ───────────────────────────────────────────────────────────────────
Write-Host "  Verifying import..." -ForegroundColor DarkGray
Remove-Module $modName -ErrorAction SilentlyContinue

try {
    $importedMod = Import-Module $modName -RequiredVersion $version -PassThru -ErrorAction Stop
    $cmdCount    = $importedMod.ExportedFunctions.Count
    $cmdNames    = ($importedMod.ExportedFunctions.Keys | Sort-Object) -join ', '
    Write-Host "  Import OK — $cmdCount cmdlets: $cmdNames" -ForegroundColor Green
}
catch {
    Write-Warning "Import verification failed: $_"
    Write-Warning "Files are installed but the module may not load correctly."
    Write-Host ''
    return
}

Write-Host ''
Write-Host "  DashHtml v$version installed ($Scope)." -ForegroundColor Cyan
Write-Host ''
Write-Host '  Usage:' -ForegroundColor White
Write-Host "    Import-Module DashHtml" -ForegroundColor DarkGray
Write-Host "    Get-Command -Module DashHtml" -ForegroundColor DarkGray
Write-Host "    Get-Help New-DhDashboard -Full" -ForegroundColor DarkGray
Write-Host ''
