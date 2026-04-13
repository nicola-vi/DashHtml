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
        [string]   $NavGroup    = ''    # primary nav group label (enables two-tier nav)
    )

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
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

    $Report.Blocks.Add([ordered]@{
        BlockType   = 'collapsible'
        Id          = $Id
        Title       = $Title
        Icon        = $Icon
        DefaultOpen = $DefaultOpen
        Cards       = @($normCards)
        Content     = $Content
        Badge       = @($normCards).Count
        NavGroup    = $NavGroup
    })
    Write-Verbose "Add-DhCollapsible: Added '$Id' ($(@($normCards).Count) cards)."
}
