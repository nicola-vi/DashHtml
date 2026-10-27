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
        Defaults to no label (the header already shows the Title); pass a
        short form to show one.
          -NavTitle 'My Dashboard' # short form

    .PARAMETER InfoFields
        Optional array of @{ Label='X'; Value='Y' } hashtables rendered as a
        key-value grid in the report header alongside the title and logo.
        Example: -InfoFields @(@{Label='Environment';Value='Production'},@{Label='Region';Value='West'})

    .PARAMETER GeneratedBy
        Optional script/tool name shown in the report footer.

    .PARAMETER ThemeMode
        v2.2.0. The theme the report opens in when the reader has not chosen
        one: Light (default) | Dark | Auto (follow the system's light/dark
        setting). A choice made with the toggle button always wins.

    .PARAMETER Density
        v2.7.0. The reading density the report opens at: Normal (default),
        Compact (tighter rows and a smaller label layer - closest to the
        pre-2.7.0 look) or Comfortable (taller rows, larger type). The reader
        can still cycle it with the density button; their choice is kept in
        the URL, so a shared link carries it.

    .PARAMETER PrintCover
        v2.2.0. When the report is printed (or saved as PDF from the browser),
        start with a cover page: title, subtitle, logo, info fields and the
        first verdict tile, if the report has one.

    .PARAMETER NavBadge
        v2.4.0. Puts a small pill on each menu item showing the worst severity among the
        non-OK findings (Add-DhFindings) on that page and below, with the count of that
        severity; the tooltip gives the full breakdown. Blocks with no menu path are not
        counted. Off by default.

    .PARAMETER Search
        v2.4.0. Adds a search box to the menu bar (press / to focus it). It finds menu
        pages, block and table titles, findings, and table rows (with a hit count per
        table). Choosing a result opens its page; a table hit also filters that table.
        Off by default.

    .PARAMETER NavAllLabel
        v2.5.0. Adds an addressable "All" child to group nodes of the menu (a node that has children).
        The All view shows the group's own content and everything below it, and has its own link
        (the path ends in the reserved segment '*'). It is never the default view. A string adds it to
        every group node ('All'); a hashtable names the groups: @{ 'Storage' = 'All storage' }.

    .PARAMETER NavTree
        v2.5.0. The menu declared once: an array of @{ Path; Label; Order }. It supplies labels and
        sibling order, and creates nodes before anything is placed on them (an empty node shows a
        "no content" note). An item's own -NavLabel / -NavOrder wins over the skeleton; the skeleton
        wins over declaration order.

    .PARAMETER NavOverflow
        v2.5.0. More (default): when a menu strip would wrap to a second row (v2.5.3; was: past two rows), the chips that do not fit
        move into a "More" menu and the selected chip always stays visible. Wrap: let them wrap as in
        earlier versions. A short menu looks the same either way.

    .PARAMETER LinkState
        v2.6.0. Keep each table's sort, page, page size and Change chip in the page address (next to the
        menu path and the text filters, which are always kept), so a copied link opens the same view.
        Off by default: without it the address holds what it held before. Unknown or vanished columns in
        a link are ignored and a page past the end shows the last page.

    .PARAMETER StrictNav
        v2.5.0. At export, warn (never throw) about likely menu mistakes: sibling labels that clash,
        names that differ only in case or by one letter, a path that is not in -NavTree, a Subtree
        item with nothing below it, a -NavAllLabel that names no group.
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

        [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
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
        [string]   $GeneratedBy = '',

        # v1.4.2+ — auto-refresh interval. Accepts seconds as an int or a duration
        # string like '30s', '5m', '1h'. When set, the exported HTML carries a
        # <meta http-equiv="refresh"> tag so wall-display dashboards re-fetch
        # the file automatically. Omit / pass '' / pass 0 to disable.
        [string]   $AutoRefresh = '',

        # ---- v2.0.0 navigation layout ------------------------------------
        # Auto    - strips up to 3 levels, sidebar rail at 4+ (default).
        # Strips  - always the horizontal strips (the 1.x look).
        # Sidebar - always the left tree rail.
        # The three sticky strips cost ~190px of vertical chrome at depth 3 and
        # ~225px at depth 4 (21% of a 1080p viewport), which is why deep trees
        # switch automatically.
        [ValidateSet('Auto','Strips','Sidebar')]
        [string]   $NavLayout = 'Auto',

        # Deepest nav path the report will accept. Depth is a POLICY, not an
        # architectural limit: the matcher, URL state and renderer are all
        # depth-agnostic, so raising this costs nothing but layout.
        [ValidateRange(1,5)]
        [int]      $NavMaxDepth = 3,

        # ---- v2.2.0 ----
        # Theme the report opens in when the reader has not picked one.
        # Light (default, as before) | Dark | Auto (follow the OS / browser
        # prefers-color-scheme until the reader toggles). A choice the reader
        # made with the toggle button always wins (URL hash, then localStorage).
        [ValidateSet('Light','Dark','Auto')]
        [string]   $ThemeMode = 'Light',

        # ---- v2.7.0 ----
        # Reading density the report opens at. The density button still cycles
        # Normal -> Compact -> Comfortable at runtime; this only sets the
        # starting point, and a reader's choice (URL hash) wins over it.
        [ValidateSet('Normal','Compact','Comfortable')]
        [string]   $Density = 'Normal',

        # Print a cover page first: title, subtitle, logo, info fields, and the
        # first verdict tile (Add-DhSummary Style='verdict') when there is one.
        [switch]   $PrintCover,

        # ---- v2.4.0 ----
        # Show, on every menu item, a small pill with the worst finding severity
        # and its count (from Add-DhFindings blocks at or below that item).
        [switch]   $NavBadge,

        # Add a search box to the menu bar: pages, findings and table rows.
        [switch]   $Search,

        # ---- v2.5.0 ----
        # An addressable 'All' child on group nodes of the menu. A string ('All') adds it to EVERY group
        # node; a hashtable adds it to the named groups only: @{ 'Storage' = 'All storage' }.
        [object]   $NavAllLabel = $null,

        # The menu skeleton, declared once: @( @{ Path='Identity'; Label='Identity and access'; Order=1 }, @{ Path='Identity/Users' } ).
        # Gives labels and order, and nodes that exist even when nothing sits on them yet.
        [AllowEmptyCollection()] [object[]] $NavTree = @(),

        # Warn at export about menu mistakes: clashing or case-only sibling names, likely typos, paths
        # outside -NavTree, a Subtree item with nothing below it.
        [switch]   $StrictNav,

        # When a menu strip would wrap to a second row: More (default) moves the chips that do not fit into
        # a 'More' menu (the selected one always stays visible); Wrap lets them wrap as before.
        [ValidateSet('More','Wrap')]
        [string]   $NavOverflow = 'More',

        # ---- v2.6.0 ----
        # Keep each table's sort, page, page size and Change chip in the page address (a link opens the same view).
        [switch]   $LinkState
    )

    # Map theme family to internal light/dark CSS names
    # -NavAllLabel: a string, or a hashtable of path = label. Checked here so a typo fails at build time.
    $navAll = $null
    if ($null -ne $NavAllLabel -and "$NavAllLabel" -ne '') {
        if ($NavAllLabel -is [string]) { $navAll = $NavAllLabel }
        elseif ($NavAllLabel -is [System.Collections.IDictionary]) {
            $navAll = [ordered]@{}
            foreach ($k in $NavAllLabel.Keys) {
                $segs = ConvertFrom-DhNavPath ([string]$k)
                if (@($segs).Count -eq 0) { throw "New-DhDashboard: -NavAllLabel has an empty path key." }
                if ([string]::IsNullOrWhiteSpace([string]$NavAllLabel[$k])) { throw "New-DhDashboard: -NavAllLabel '$k' needs a non-empty label." }
                $navAll[[string]$k] = [string]$NavAllLabel[$k]
            }
        }
        else { throw "New-DhDashboard: -NavAllLabel must be a string or a hashtable of path = label." }
    }
    # -NavTree: the menu skeleton. Normalised to Path / Label / Order, in the order given.
    $navTreeOut = @()
    if (@($NavTree).Count) {
        $seenPaths = @{}
        $navTreeOut = @(foreach ($e in $NavTree) {
            if ($e -isnot [System.Collections.IDictionary] -or -not $e.Contains('Path') -or [string]::IsNullOrWhiteSpace([string]$e['Path'])) {
                throw "New-DhDashboard: each -NavTree entry must be a hashtable with a Path, e.g. @{ Path='Identity/Users'; Label='Users'; Order=2 }."
            }
            $segs = ConvertFrom-DhNavPath ([string]$e['Path'])
            $key = ($segs -join [char]0x1F)
            if ($seenPaths.ContainsKey($key)) { throw "New-DhDashboard: -NavTree lists the path '$($e['Path'])' twice." }
            $seenPaths[$key] = $true
            $ord = 0
            if ($e.Contains('Order') -and $null -ne $e['Order'] -and "$($e['Order'])" -ne '') {
                if (-not [int]::TryParse([string]$e['Order'], [ref]$ord)) { throw "New-DhDashboard: -NavTree '$($e['Path'])' Order must be a whole number. Got: $($e['Order'])" }
            }
            [ordered]@{ Path = [string]$e['Path']; Label = $(if ($e.Contains('Label') -and $null -ne $e['Label']) { [string]$e['Label'] } else { '' }); Order = $ord }
        })
    }
    $themeMap = @{
        'Default' = @{ Light = 'DefaultLight'; Dark = 'DefaultDark'  }
        'Azure'   = @{ Light = 'AzureLight';   Dark = 'AzureDark'    }
        'VMware'  = @{ Light = 'VMwareLight';  Dark = 'VMwareDark'   }
        'Grey'    = @{ Light = 'GreyLight';    Dark = 'GreyDark'     }
        'Company' = @{ Light = 'CompanyLight'; Dark = 'CompanyDark'  }
        'Rag'     = @{ Light = 'RagLight';     Dark = 'RagDark'      }
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

    # Normalise -AutoRefresh into a seconds count (0 = disabled)
    $autoRefreshSeconds = 0
    if (-not [string]::IsNullOrWhiteSpace($AutoRefresh)) {
        $m = [regex]::Match($AutoRefresh.Trim(), '^(?<n>\d+)\s*(?<u>[smh]?)$', 'IgnoreCase')
        if (-not $m.Success) {
            throw "New-DhDashboard: -AutoRefresh must be seconds as a number or a duration like '30s', '5m', '1h'. Got: '$AutoRefresh'"
        }
        $n = [int]$m.Groups['n'].Value
        switch (([string]$m.Groups['u'].Value).ToLowerInvariant()) {
            'm'     { $autoRefreshSeconds = $n * 60 }
            'h'     { $autoRefreshSeconds = $n * 3600 }
            default { $autoRefreshSeconds = $n }       # 's' or no unit → seconds
        }
        if ($autoRefreshSeconds -lt 1) {
            $autoRefreshSeconds = 0   # treat 0 / negative as disabled
        }
    }

    Write-Verbose "New-DhDashboard: Theme='$Theme'  (light: $lightInternal / dark: $darkInternal)$(if ($autoRefreshSeconds) { ", AutoRefresh=${autoRefreshSeconds}s" })"

    return [ordered]@{
        Title          = $Title
        Subtitle       = $Subtitle
        LogoBase64     = $logoBase64
        LogoMime       = $logoMime
        ThemeFamily    = $Theme           # user-facing family name (Default | Azure | VMware | Grey | Company | Rag)
        Theme          = $lightInternal   # internal primary CSS name (always light variant)
        AlternateTheme = $darkInternal    # internal alternate CSS name (always dark variant)
        CssFileName    = ''               # always empty — both themes are embedded in the HTML
        InfoFields     = @($InfoFields)
        Tables         = [System.Collections.Generic.List[hashtable]]::new()
        Links          = [System.Collections.Generic.List[hashtable]]::new()
        GeneratedAt    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')
        NavTitle       = if ($null -eq $NavTitle) { '' } else { $NavTitle }
        GeneratedBy    = $GeneratedBy
        AutoRefreshSec = $autoRefreshSeconds   # 0 = disabled
        NavLayout      = $NavLayout            # v2.0.0 Auto | Strips | Sidebar
        NavMaxDepth    = $NavMaxDepth          # v2.0.0 policy cap (1-5)
        ThemeMode      = $ThemeMode.ToLowerInvariant()   # v2.2.0 light | dark | auto
        Density        = $Density.ToLowerInvariant()     # v2.7.0 normal | compact | comfortable
        PrintCover     = [bool]$PrintCover               # v2.2.0
        NavBadge       = [bool]$NavBadge                 # v2.4.0
        Search         = [bool]$Search                   # v2.4.0
        NavAllLabel    = $navAll                         # v2.5.0
        NavTree        = @($navTreeOut)                  # v2.5.0
        StrictNav      = [bool]$StrictNav                # v2.5.0
        NavOverflow    = $NavOverflow                    # v2.5.0
        LinkState      = [bool]$LinkState                # v2.6.0
    }
}

