function Add-DhTabs {
    <#
    .SYNOPSIS
        Add an inline tabbed content block (v1.5+).

    .DESCRIPTION
        Renders a tab strip with one content pane per tab. Distinct from the
        page-level NavGroup mechanism: NavGroup partitions the whole dashboard
        into named panels; Add-DhTabs creates a tabbed pivot inside a single
        block of the dashboard flow.

        Use it for "summary / details / settings" style pivots — when several
        related views share the same surface area and the user toggles between
        them locally without navigating away from the current panel.

        Each tab is a hashtable carrying:
          - Title (required) — the label shown on the tab strip
          - Content — free-form HTML rendered inside the tab pane, OR
          - HtmlBlockId — an Id of an Add-DhHtmlBlock previously declared

        Free-form Content is the simplest path. To embed a richer block
        (sparkline table, status grid, etc.) inside a tab, the easiest pattern
        is still to wrap the block in -NavGroup / -NavSubGroup and use the
        page-level nav; Add-DhTabs is intentionally limited to inline HTML.

        SECURITY: per-tab Content is injected into the DOM via innerHTML.
        Never pass untrusted external data (AD attributes, ticket titles, log
        lines, anything supplied by an actor outside your trust boundary) into
        Content without HTML-encoding it first with
        [System.Web.HttpUtility]::HtmlEncode(). Same policy as
        Add-DhHtmlBlock, Add-DhAlertBanner -Message, and Add-DhCollapsible
        -Content.

    .PARAMETER Report
        Dashboard object from New-DhDashboard.

    .PARAMETER Id
        Unique identifier (alphanumeric, dash, underscore).

    .PARAMETER Title
        Optional block heading shown above the tab strip.

    .PARAMETER Tabs
        Array of tab definition hashtables:
          @{
              Title   = 'Overview'       # REQUIRED — tab label
              Content = '<p>...</p>'     # REQUIRED — inline HTML
              Icon    = 'X'              # optional — glyph shown before the label
              Active  = $true            # optional — selects this tab on load (first by default)
          }

    .PARAMETER NavGroup
        Primary nav group label (enables two-tier nav).

    .PARAMETER NavSubGroup
        Optional second-level group under NavGroup (enables three-tier nav).

    .EXAMPLE
        Add-DhTabs -Report $report -Id 'auth-pivot' -Title 'Authentication detail' `
            -Tabs @(
                @{ Title='Overview';
                   Content='<p>Auth subsystem is operating within SLA.</p>' }
                @{ Title='Errors';
                   Content='<p>3 auth errors in the last hour. <a href="#">View log</a>.</p>' }
                @{ Title='Configuration';
                   Content='<pre>kerberos.maxRetries=3
ntlm.fallback=disabled</pre>' }
            )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string] $Id,
        [string] $Title = '',
        [Parameter(Mandatory)] [object[]] $Tabs,

        # v1.6.0 — when $false, each tab's Content is HTML-encoded (rendered as
        # literal text) instead of injected as raw markup. Applies to every tab
        # in this block. Default $true preserves v1.x behaviour; flips to $false
        # in DashHtml 2.0.0. See ConvertTo-DhSafeContent.
        [bool]   $AllowHtml   = $true,

        [bool]   $Collapsible = $true,    # wrap the block in a collapsible header (chevron + click-to-toggle)

        [bool]   $DefaultOpen = $true,    # whether the collapsible body starts expanded (only used when -Collapsible is $true)

        [ValidateRange(0,12)]

        [int]    $GridSpan    = 0,   # v1.10.0 - columns (1-12) to span in -report-grid layout; 0 = default flow

        [string] $NavGroup    = '',
        [string] $NavSubGroup = ''
    )

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhTabs: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }
    if ($Tabs.Count -lt 1) {
        throw "Add-DhTabs: -Tabs must contain at least one tab."
    }

    $allowHtmlExplicit = $PSBoundParameters.ContainsKey('AllowHtml')
    # @(...) so a single tab still yields an array — otherwise $normTabs[0] below
    # indexes a scalar hashtable and throws (a single-tab block is valid).
    $normTabs = @(foreach ($t in $Tabs) {
        if ($t -isnot [hashtable] -and $t -isnot [System.Collections.Specialized.OrderedDictionary]) {
            throw "Add-DhTabs: each tab must be a hashtable. Got: $($t.GetType().Name)"
        }
        foreach ($req in 'Title','Content') {
            if (-not $t.Contains($req) -or [string]::IsNullOrWhiteSpace([string]$t[$req])) {
                throw "Add-DhTabs: each tab must have a non-empty '$req' key."
            }
        }
        @{
            Title   = [string]$t['Title']
            # v1.6.0 — apply the -AllowHtml policy per tab. Context names the tab
            # so the deprecation warning points at the offending content.
            Content = ConvertTo-DhSafeContent -Content ([string]$t['Content']) -AllowHtml $AllowHtml `
                        -Explicit $allowHtmlExplicit -Context "Add-DhTabs '$Id' tab '$([string]$t['Title'])' Content"
            Icon    = if ($t.Contains('Icon')   -and $null -ne $t['Icon'])   { [string]$t['Icon'] }   else { '' }
            Active  = if ($t.Contains('Active') -and $null -ne $t['Active']) { [bool]$t['Active'] }   else { $false }
        }
    })

    # If no tab is explicitly Active, mark the first one
    $explicit = @($normTabs | Where-Object { $_.Active }).Count
    if ($explicit -eq 0) {
        $normTabs[0].Active = $true
    } elseif ($explicit -gt 1) {
        # Keep only the first explicitly-active tab; reset the rest
        $seen = $false
        foreach ($t in $normTabs) {
            if ($t.Active -and -not $seen) { $seen = $true } else { $t.Active = $false }
        }
    }

    $Report.Blocks.Add([ordered]@{
        BlockType   = 'tabs'
        Id          = $Id
        Title       = $Title
        Tabs        = @($normTabs)
        NavGroup    = $NavGroup
        NavSubGroup = $NavSubGroup
        GridSpan    = $GridSpan
        Collapsible = $Collapsible
        DefaultOpen = $DefaultOpen
    })
    Write-Verbose "Add-DhTabs: '$Id' ($($normTabs.Count) tab(s))."
}
