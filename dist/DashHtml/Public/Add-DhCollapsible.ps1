function Add-DhCollapsible {
    <#
    .SYNOPSIS
        Add a collapsible section containing metadata cards or free-form content.

    .DESCRIPTION
        Renders a clickable header bar with a chevron toggle and an optional item
        count badge. The body expands or collapses when the header is clicked.

        Two content modes:
          -Cards    A responsive grid of key-value cards (accounts, environments,
                    locations, servers — any structured metadata)
          -Content  Free-form HTML rendered inside the collapsible body

    .PARAMETER Report       Dashboard object from New-DhDashboard.
    .PARAMETER Id           Unique identifier (alphanumeric, - or _).
    .PARAMETER Title        Header text shown in the toggle bar.
    .PARAMETER Icon         Optional emoji / unicode icon before the title.
    .PARAMETER DefaultOpen  Start expanded (default $true).

    .PARAMETER Cards
        Array of card hashtables. Each card:
          @{
              Title      = 'Card heading'         # REQUIRED
              Fields     = @(                     # REQUIRED — key-value pairs
                  @{ Label = 'ID';     Value = 'abc-123' }
                  @{ Label = 'Status'; Value = 'Active'; Class = 'cell-ok' }
              )
              Badge      = 'Active'               # optional badge text
              BadgeClass = 'cell-ok'              # optional badge colour class
          }

    .PARAMETER Content
        Free-form HTML string (alternative to -Cards).
        SECURITY: Content is injected via innerHTML. Never pass untrusted
        external data (AD attributes, log lines, anything supplied by an
        actor outside your trust boundary) into this parameter without
        HTML-encoding it first with [System.Web.HttpUtility]::HtmlEncode().
        Same rule as Add-DhHtmlBlock, Add-DhAlertBanner -Message, and
        Add-DhTabs per-tab Content.

    .EXAMPLE
        # Card grid — any structured metadata (accounts, locations, teams…)
        Add-DhCollapsible -Report $report -Id 'accounts' `
            -Title 'Accounts' -Icon 'X' -DefaultOpen $true `
            -Cards @(
                @{
                    Title      = 'Production Account'
                    Badge      = 'Active'
                    BadgeClass = 'cell-ok'
                    Fields     = @(
                        @{ Label = 'Account ID'; Value = 'acc-001-prod' }
                        @{ Label = 'Region';     Value = 'us-east-1' }
                        @{ Label = 'Resources';  Value = '147' }
                    )
                }
                @{
                    Title      = 'DR Account'
                    Badge      = 'Standby'
                    BadgeClass = 'cell-warn'
                    Fields     = @(
                        @{ Label = 'Account ID'; Value = 'acc-002-dr' }
                        @{ Label = 'Region';     Value = 'us-west-2' }
                        @{ Label = 'Resources';  Value = '23'; Class = 'cell-warn' }
                    )
                }
            )

    .EXAMPLE
        # Free-form collapsible notes
        Add-DhCollapsible -Report $report -Id 'notes' `
            -Title 'Maintenance Notes' -DefaultOpen $false `
            -Content '<p>Last maintenance window: 2026-03-01. Next: 2026-04-01.</p>'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string]   $Id,
        [Parameter(Mandatory)] [string]    $Title,
        [string]   $Icon        = '',
        [bool]     $DefaultOpen = $true,
        [object[]] $Cards       = @(),
        [string]   $Content     = '',
        # v1.6.0 — when $false, -Content is HTML-encoded instead of injected raw.
        # Only affects free-form -Content (the -Cards path is always structured/safe).
        # Default $true preserves v1.x behaviour; flips to $false in DashHtml 2.0.0.
        [bool]     $AllowHtml   = $true,
        [ValidateSet('small','normal','large','xlarge','auto')]
        [string]   $CardWidth   = 'normal',  # card grid sizing: small=150-220, normal=200-320 (default), large=280-480, xlarge=360-640, auto=grow to fit
        [ValidateRange(0,12)]
        [int]    $GridSpan    = 0,   # v1.10.0 - columns (1-12) to span in -report-grid layout; 0 = default flow
        [string] $NavGroup    = '',   # primary nav group label (enables two-tier nav)
        [string]   $NavSubGroup = ''    # optional second-level group under NavGroup (enables three-tier nav)
    )

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }

    # Duplicate-Id guard (same rule applied by other block cmdlets)
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhCollapsible: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }

    $normCards = foreach ($card in $Cards) {
        if ($card -isnot [hashtable] -and $card -isnot [System.Collections.Specialized.OrderedDictionary]) {
            throw "Add-DhCollapsible: Each card must be a hashtable. Got: $($card.GetType().Name)"
        }
        if (-not $card.Contains('Title') -or $null -eq $card.Title) {
            throw "Add-DhCollapsible: Each card must have a 'Title' key."
        }
        if (-not $card.Contains('Fields')) {
            throw "Add-DhCollapsible: Each card must have a 'Fields' key (array of @{Label;Value} hashtables)."
        }
        # Normalize fields — ensure each field is a hashtable with Label, Value, Class keys
        $normFields = @($card.Fields) | ForEach-Object {
            $f = if ($_ -is [hashtable] -or $_ -is [System.Collections.Specialized.OrderedDictionary]) {
                @{} + $_
            } else {
                @{ Label = [string]$_.Label; Value = [string]$_.Value }
            }
            if (-not $f.Contains('Class')) { $f['Class'] = '' }
            $f
        }
        $c = @{} + $card
        $c['Fields'] = @($normFields)
        if (-not $c.Contains('Badge'))      { $c['Badge']      = '' }
        if (-not $c.Contains('BadgeClass')) { $c['BadgeClass'] = '' }
        $c
    }

    # Free-form Content only reaches innerHTML when there are no cards; encode it
    # per -AllowHtml. Empty content short-circuits (no warning, nothing to encode).
    $safeContent = if ([string]::IsNullOrEmpty($Content)) { $Content } else {
        ConvertTo-DhSafeContent -Content $Content -AllowHtml $AllowHtml `
            -Explicit $PSBoundParameters.ContainsKey('AllowHtml') -Context "Add-DhCollapsible '$Id' -Content"
    }

    $Report.Blocks.Add([ordered]@{
        BlockType   = 'collapsible'
        Id          = $Id
        Title       = $Title
        Icon        = $Icon
        DefaultOpen = $DefaultOpen
        Cards       = @($normCards)
        Content     = $safeContent
        Badge       = @($normCards).Count
        CardWidth   = $CardWidth
        NavGroup    = $NavGroup
        NavSubGroup = $NavSubGroup
        GridSpan    = $GridSpan
    })
    Write-Verbose "Add-DhCollapsible: Added '$Id' ($(@($normCards).Count) cards)."
}
