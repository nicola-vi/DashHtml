function Get-DhTheme {
    <#
    .SYNOPSIS
        List available DashHtml theme families or retrieve a family's CSS.

    .DESCRIPTION
        Without parameters, returns a summary of all 5 built-in theme families.

        With -Name, returns a PSCustomObject with LightCss and DarkCss properties
        containing the full CSS strings for both variants of the chosen family.

        With -SaveTo (requires -Name), saves both CSS files to the specified
        directory as  <Family>-light.css  and  <Family>-dark.css.

    .PARAMETER Name
        Theme family to retrieve.
        Valid values: Default | Azure | VMware | Grey | Company

    .PARAMETER SaveTo
        Directory path where the two CSS files will be saved.
        Use with -Name. The directory is created if it does not exist.

    .EXAMPLE
        # List all theme families
        Get-DhTheme

    .EXAMPLE
        # Get the CSS for the Azure family
        $css = Get-DhTheme -Name Azure
        $css.LightCss   # CSS for the light variant
        $css.DarkCss    # CSS for the dark variant

    .EXAMPLE
        # Save both CSS files for the Company family
        Get-DhTheme -Name Company -SaveTo 'C:\Reports'

    .OUTPUTS
        [PSCustomObject[]]  when called without -Name (one entry per family)
        [PSCustomObject]    { LightCss, DarkCss } when called with -Name
    #>
    [CmdletBinding(DefaultParameterSetName='List')]
    param(
        [Parameter(ParameterSetName='Get', Mandatory)]
        [ValidateSet('Default','Azure','VMware','Grey','Company')]
        [string] $Name,

        [Parameter(ParameterSetName='Get')]
        [string] $SaveTo = ''
    )

    # Internal light/dark mapping (mirrors New-DhDashboard)
    $themeMap = @{
        'Default' = @{ Light = 'DefaultLight'; Dark = 'DefaultDark';  LightDesc = 'Light grey (#F0F4F8), blue accent';      DarkDesc = 'Near-black (#0b0f14), cyan accent';    Font = 'System UI / Segoe UI'  }
        'Azure'   = @{ Light = 'AzureLight';   Dark = 'AzureDark';    LightDesc = 'Warm grey (#F3F2F1), Azure blue header'; DarkDesc = 'Office dark (#1B1A19), Azure accent';  Font = 'Segoe UI (system)'     }
        'VMware'  = @{ Light = 'VMwareLight';  Dark = 'VMwareDark';   LightDesc = 'White/navy header, VMware green';        DarkDesc = 'Navy (#1D2437), VMware green accent';  Font = 'Inter (Google Fonts)'  }
        'Grey'    = @{ Light = 'GreyLight';    Dark = 'GreyDark';     LightDesc = 'Warm grey (#EEEEEE), steel accent';      DarkDesc = 'Dark neutral (#1A1A1A), grey accent';  Font = 'System UI / Segoe UI'  }
        'Company' = @{ Light = 'CompanyLight'; Dark = 'CompanyDark';  LightDesc = 'White, Crimson Glory (#BE0036)';         DarkDesc = 'Near-black (#0E0709), Crimson accent'; Font = 'Montserrat (Google Fonts)' }
    }

    if ($PSCmdlet.ParameterSetName -eq 'List') {
        return @(
            foreach ($family in @('Default','Azure','VMware','Grey','Company')) {
                $m = $themeMap[$family]
                [PSCustomObject]@{
                    Family      = $family
                    Font        = $m.Font
                    LightTheme  = $m.Light
                    LightDesc   = $m.LightDesc
                    DarkTheme   = $m.Dark
                    DarkDesc    = $m.DarkDesc
                }
            }
        )
    }

    # Return CSS strings for both variants
    $m        = $themeMap[$Name]
    $lightCss = Get-DhThemeCss -Theme $m.Light
    $darkCss  = Get-DhThemeCss -Theme $m.Dark

    if ($SaveTo) {
        $SaveTo = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SaveTo)
        if (-not (Test-Path $SaveTo)) {
            New-Item -ItemType Directory -Path $SaveTo -Force | Out-Null
        }
        $lightFile = Join-Path $SaveTo "$Name-light.css"
        $darkFile  = Join-Path $SaveTo "$Name-dark.css"
        Set-Content -Path $lightFile -Value $lightCss -Encoding UTF8
        Set-Content -Path $darkFile  -Value $darkCss  -Encoding UTF8
        Write-Verbose "Get-DhTheme: Saved $Name light -> $lightFile"
        Write-Verbose "Get-DhTheme: Saved $Name dark  -> $darkFile"
    }

    return [PSCustomObject]@{
        Family   = $Name
        LightCss = $lightCss
        DarkCss  = $darkCss
    }
}
