function New-DhDashboard {
    <#
    .SYNOPSIS
        Create a new DashHtml dashboard definition object.

    .DESCRIPTION
        Returns an ordered dictionary that acts as the root object for all
        subsequent Add-DhTable, Set-DhTableLink and Export-DhDashboard calls.

        Both the light and dark variants of the chosen theme are always embedded
        directly in the HTML output — no external CSS file is ever written. A
        toggle button in the nav bar lets viewers switch between light and dark
        at runtime without any server round-trip.

    .PARAMETER Title
        Main heading shown in the sticky report header.

    .PARAMETER Subtitle
        Optional sub-heading / description line beneath the title.

    .PARAMETER LogoPath
        Path to an image file. The image is Base64-encoded and embedded directly
        in the HTML so the report is portable with no external image references.
        Accepted formats: .jpg .jpeg .png .gif .webp

    .PARAMETER Theme
        Theme family for the dashboard. The light variant is shown on load; the dark
        variant is the runtime-toggle alternate. Both are always embedded.
        Valid values (default: Default):
          Default  - System UI fonts.  Light: light grey + blue.   Dark: near-black + cyan.
          Azure    - Segoe UI (system). Light: warm grey + Azure blue.  Dark: Office dark + Azure.
          VMware   - Inter (Google).   Light: white/navy + VMware green. Dark: navy + VMware green.
          Grey     - System UI fonts.  Light: warm grey + steel.  Dark: dark neutral + muted grey.
          Company  - Montserrat (Google). Light: white + Crimson. Dark: near-black + Crimson.
        Use  Get-DhTheme  to list families and inspect their CSS.

    .PARAMETER NavTitle
        Text shown in the sticky nav bar alongside the navigation links.
        Defaults to the dashboard Title.
        Set to an empty string to suppress the label entirely (logo + links only).
          -NavTitle ''             # hide entirely
          -NavTitle 'My Dashboard' # short form

    .PARAMETER InfoFields
        Optional array of @{ Label='X'; Value='Y' } hashtables rendered as a
        key-value grid in the report header alongside the title and logo.
        Example: -InfoFields @(@{Label='Environment';Value='Production'},@{Label='Region';Value='West'})

    .PARAMETER GeneratedBy
        Optional script/tool name shown in the report footer.

    .EXAMPLE
        $report = New-DhDashboard -Title 'Infrastructure Dashboard' -Theme Azure

    .EXAMPLE
        $report = New-DhDashboard -Title 'My Dashboard' `
                                  -Subtitle 'Environment: Production' `
                                  -LogoPath 'C:\img\logo.png' `
                                  -Theme Company `
                                  -NavTitle 'Infra'

    .OUTPUTS
        [System.Collections.Specialized.OrderedDictionary]  Dashboard definition object passed to Add-DhTable / Export-DhDashboard.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Title,

        [string] $Subtitle = '',
        [string] $LogoPath = '',

        [ValidateSet('Default','Azure','VMware','Grey','Company')]
        [string] $Theme = 'Default',

        # Nav bar label — defaults to Title ($null); set '' to suppress.
        # Untyped so that $null (default, meaning "use Title") is not coerced to '' by [string].
        # [AllowNull()] + [AllowEmptyString()] still documented here for IDE tooling.
        [AllowNull()][AllowEmptyString()]
        $NavTitle = $null,

        # Multi-field info grid shown in the report header
        # Array of @{ Label='Field Name'; Value='Field Value' } hashtables
        [object[]] $InfoFields  = @(),

        # Optional script/tool name shown in the report footer
        [string]   $GeneratedBy = ''
    )

    # Map theme family to internal light/dark CSS names
    $themeMap = @{
        'Default' = @{ Light = 'DefaultLight'; Dark = 'DefaultDark'  }
        'Azure'   = @{ Light = 'AzureLight';   Dark = 'AzureDark'    }
        'VMware'  = @{ Light = 'VMwareLight';  Dark = 'VMwareDark'   }
        'Grey'    = @{ Light = 'GreyLight';    Dark = 'GreyDark'     }
        'Company' = @{ Light = 'CompanyLight'; Dark = 'CompanyDark'  }
    }
    $lightInternal = $themeMap[$Theme].Light
    $darkInternal  = $themeMap[$Theme].Dark

    # Embed logo
    $logoBase64 = ''
    $logoMime   = 'image/jpeg'   # default, updated below if logo found
    if ($LogoPath) {
        if (-not (Test-Path -LiteralPath $LogoPath)) {
            Write-Warning "New-DhDashboard: Logo file not found at '$LogoPath'. Skipping logo."
        } else {
            $ext = [System.IO.Path]::GetExtension($LogoPath).ToLower()
            $mimeMap = @{
                '.jpg'  = 'image/jpeg'
                '.jpeg' = 'image/jpeg'
                '.png'  = 'image/png'
                '.gif'  = 'image/gif'
                '.webp' = 'image/webp'
            }
            if ($ext -notin $mimeMap.Keys) {
                Write-Warning "New-DhDashboard: Unsupported logo format '$ext'. Supported: .jpg .jpeg .png .gif .webp. Skipping."
            } else {
                $bytes      = [System.IO.File]::ReadAllBytes($LogoPath)
                $logoBase64 = [System.Convert]::ToBase64String($bytes)
                $logoMime   = $mimeMap[$ext]
                Write-Verbose "New-DhDashboard: Logo embedded ($([math]::Round($bytes.Length / 1KB, 1)) KB, $logoMime)."
            }
        }
    }

    Write-Verbose "New-DhDashboard: Theme='$Theme'  (light: $lightInternal / dark: $darkInternal)"

    return [ordered]@{
        Title          = $Title
        Subtitle       = $Subtitle
        LogoBase64     = $logoBase64
        LogoMime       = $logoMime
        ThemeFamily    = $Theme           # user-facing family name (Default | Azure | VMware | Grey | Company)
        Theme          = $lightInternal   # internal primary CSS name (always light variant)
        AlternateTheme = $darkInternal    # internal alternate CSS name (always dark variant)
        CssFileName    = ''               # always empty — both themes are embedded in the HTML
        InfoFields     = @($InfoFields)
        Tables         = [System.Collections.Generic.List[hashtable]]::new()
        Links          = [System.Collections.Generic.List[hashtable]]::new()
        GeneratedAt    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')
        NavTitle       = if ($null -eq $NavTitle) { '' } else { $NavTitle }
        GeneratedBy    = $GeneratedBy
    }
}
