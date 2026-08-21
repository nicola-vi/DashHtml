#Requires -Version 7.0
<#
.SYNOPSIS
    Install.ps1 — installs DashHtml (and the optional DashHtml.Design companion)
    into the PowerShell module path.

.DESCRIPTION
    Copies each module into a properly versioned directory:
        <ModulesRoot>\DashHtml\<Version>\
        <ModulesRoot>\DashHtml.Design\<Version>\

    The two modules are versioned and installed independently. By default BOTH
    are installed when the companion is present in the repo (or in dist\ after a
    build); use -SkipDesign for the core only, or -DesignOnly for the companion
    only. The core is always installed first — DashHtml.Design reads the core
    module's cmdlet metadata at runtime.

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
    Path to the CORE module directory to install.
    Defaults to .\dist\DashHtml if built, otherwise .\DashHtml.

.PARAMETER DesignSource
    Path to the DashHtml.Design module directory.
    Defaults to .\dist\DashHtml.Design if built, otherwise .\DashHtml.Design.

.PARAMETER SkipDesign
    Install the core module only; ignore DashHtml.Design.

.PARAMETER DesignOnly
    Install DashHtml.Design only; leave the core module untouched.

.PARAMETER Force
    Overwrite an existing installation of the same version.

.PARAMETER Uninstall
    Remove all installed versions for the chosen scope (both modules by default;
    honours -SkipDesign / -DesignOnly).

.EXAMPLE
    .\Install.ps1
    .\Install.ps1 -Scope AllUsers -Force
    .\Install.ps1 -SkipDesign
    .\Install.ps1 -DesignOnly -Force
    .\Install.ps1 -Uninstall
    .\Install.ps1 -Source '.\DashHtml' -Force
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string] $Scope        = '',        # empty = auto-detect from elevation

    [string] $Source       = '',
    [string] $DesignSource = '',
    [switch] $SkipDesign,
    [switch] $DesignOnly,
    [switch] $Force,
    [switch] $Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($SkipDesign -and $DesignOnly) {
    throw "-SkipDesign and -DesignOnly are mutually exclusive."
}

$CoreName   = 'DashHtml'
$DesignName = 'DashHtml.Design'

$doCore   = -not $DesignOnly
$doDesign = -not $SkipDesign

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

# ── Resolve a module's source directory ──────────────────────────────────────
function Resolve-DhSource {
    <#
        Explicit path wins (and must contain the manifest). Otherwise prefer a
        built dist\<Module>\, then the in-repo .\<Module>\. Returns $null when
        the module isn't present anywhere — the caller decides whether that is
        fatal (core) or just a skip (companion).
    #>
    param([string] $ModuleName, [string] $Explicit)

    if ($Explicit) {
        if (-not (Test-Path $Explicit)) { throw "Source directory not found: '$Explicit'" }
        if (-not (Test-Path (Join-Path $Explicit "$ModuleName.psd1"))) {
            throw "No $ModuleName.psd1 found in '$Explicit'."
        }
        return (Resolve-Path $Explicit).Path
    }

    $dist = Join-Path (Join-Path $PSScriptRoot 'dist') $ModuleName
    $src  = Join-Path $PSScriptRoot $ModuleName

    if ((Test-Path $dist) -and (Test-Path (Join-Path $dist "$ModuleName.psd1"))) { return $dist }
    if (Test-Path (Join-Path $src "$ModuleName.psd1")) {
        if (Test-Path $dist) {
            Write-Warning "dist\$ModuleName exists but has no manifest - falling back to .\$ModuleName"
        }
        return $src
    }
    return $null
}

# ── Install one module ───────────────────────────────────────────────────────
function Install-DhModule {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $ModuleName,
        [string] $SourceDir,
        [string] $ModulesRoot,
        [switch] $ForceOverwrite
    )

    $psdFile  = Join-Path $SourceDir "$ModuleName.psd1"
    $manifest = Import-PowerShellDataFile $psdFile
    $version  = $manifest.ModuleVersion

    $installBase = Join-Path $ModulesRoot $ModuleName
    $installDest = Join-Path $installBase $version

    Write-Host "  Module  : $ModuleName  v$version" -ForegroundColor Cyan
    Write-Host "  Source  : $SourceDir"             -ForegroundColor DarkGray
    Write-Host "  Target  : $installDest"           -ForegroundColor DarkGray

    if (Test-Path $installDest) {
        if ($ForceOverwrite) {
            Remove-Item $installDest -Recurse -Force
            Write-Host "  Removed existing v$version installation." -ForegroundColor DarkGray
        } else {
            Write-Warning "$ModuleName v$version is already installed at '$installDest'."
            Write-Warning "Use -Force to reinstall, or -Uninstall to remove all versions."
            Write-Host ''
            return $false
        }
    }

    if ($PSCmdlet.ShouldProcess($installDest, 'Copy module files')) {
        New-Item -ItemType Directory -Path $installDest -Force | Out-Null
        Copy-Item -Path (Join-Path $SourceDir '*') -Destination $installDest -Recurse -Force
        $copied = (Get-ChildItem $installDest -Recurse -File).Count
        Write-Host "  Copied $copied files to: $installDest" -ForegroundColor Green
    } else {
        Write-Host ''
        return $false
    }

    # ── Verify ──
    Write-Host "  Verifying import..." -ForegroundColor DarkGray
    Remove-Module $ModuleName -ErrorAction SilentlyContinue
    try {
        $imported = Import-Module $ModuleName -RequiredVersion $version -PassThru -ErrorAction Stop
        $cmdNames = ($imported.ExportedFunctions.Keys | Sort-Object) -join ', '
        Write-Host "  Import OK - $($imported.ExportedFunctions.Count) cmdlets: $cmdNames" -ForegroundColor Green
    }
    catch {
        Write-Warning "Import verification failed: $_"
        Write-Warning "Files are installed but the module may not load correctly."
        Write-Host ''
        return $false
    }

    Write-Host "  $ModuleName v$version installed ($Scope)." -ForegroundColor Cyan
    Write-Host ''
    return $true
}

# ── Uninstall one module ─────────────────────────────────────────────────────
function Uninstall-DhModule {
    [CmdletBinding(SupportsShouldProcess)]
    param([string] $ModuleName, [string] $ModulesRoot)

    $installBase = Join-Path $ModulesRoot $ModuleName
    if (-not (Test-Path $installBase)) {
        Write-Warning "$ModuleName not found at '$installBase' for scope '$Scope' - nothing to uninstall."
        return
    }
    if ($PSCmdlet.ShouldProcess($installBase, 'Remove module directory tree')) {
        Remove-Module $ModuleName -ErrorAction SilentlyContinue
        Remove-Item $installBase -Recurse -Force
        Write-Host "  Uninstalled: $installBase" -ForegroundColor Yellow
    }
}

# ── Resolve sources ──────────────────────────────────────────────────────────
$coreSource = $null
if ($doCore) {
    $coreSource = Resolve-DhSource -ModuleName $CoreName -Explicit $Source
    if (-not $coreSource) {
        throw ("Cannot find $CoreName.psd1 in '.\dist\$CoreName' or '.\$CoreName'. Run .\Build.ps1 first.")
    }
}

$designSourceResolved = $null
if ($doDesign) {
    $designSourceResolved = Resolve-DhSource -ModuleName $DesignName -Explicit $DesignSource
    if (-not $designSourceResolved) {
        if ($DesignOnly -or $DesignSource) {
            throw ("Cannot find $DesignName.psd1 in '.\dist\$DesignName' or '.\$DesignName'.")
        }
        # Companion simply isn't in this checkout — carry on with the core.
        Write-Host "  $DesignName not found - installing the core module only." -ForegroundColor DarkGray
        $doDesign = $false
    }
}

Write-Host ''

# ── Uninstall ────────────────────────────────────────────────────────────────
if ($Uninstall) {
    # Companion first: it depends on the core at runtime.
    if ($doDesign -or $DesignOnly) { Uninstall-DhModule -ModuleName $DesignName -ModulesRoot $moduleRoot }
    if ($doCore)                   { Uninstall-DhModule -ModuleName $CoreName   -ModulesRoot $moduleRoot }
    Write-Host ''
    return
}

# ── Install (core first — the companion reads its cmdlet metadata) ───────────
$installedAny = $false
if ($doCore) {
    if (Install-DhModule -ModuleName $CoreName -SourceDir $coreSource `
            -ModulesRoot $moduleRoot -ForceOverwrite:$Force) { $installedAny = $true }
}
if ($doDesign) {
    if (Install-DhModule -ModuleName $DesignName -SourceDir $designSourceResolved `
            -ModulesRoot $moduleRoot -ForceOverwrite:$Force) { $installedAny = $true }
}

if (-not $installedAny) { return }

# ── Usage ────────────────────────────────────────────────────────────────────
Write-Host '  Usage:' -ForegroundColor White
if ($doCore) {
    Write-Host "    Import-Module DashHtml" -ForegroundColor DarkGray
    Write-Host "    Get-Command -Module DashHtml" -ForegroundColor DarkGray
    Write-Host "    Get-Help New-DhDashboard -Full" -ForegroundColor DarkGray
}
if ($doDesign) {
    Write-Host "    Import-Module DashHtml.Design" -ForegroundColor DarkGray
    Write-Host "    ConvertFrom-DhYaml -Path layout.yaml -OutFile build.ps1" -ForegroundColor DarkGray
    Write-Host "    `$report | ConvertTo-DhYaml -OutFile layout.yaml" -ForegroundColor DarkGray
}
Write-Host ''
