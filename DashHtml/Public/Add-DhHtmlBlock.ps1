function Add-DhHtmlBlock {
    <#
    .SYNOPSIS
        Add a free-form HTML block to the dashboard.

    .DESCRIPTION
        Inserts a styled HTML panel into the dashboard flow. Content is rendered as
        raw HTML — use lists, bold text, links, or any valid HTML markup.
        Blocks appear in the order they are added, interleaved with tables and
        other block elements.

    .PARAMETER Report     Dashboard object from New-DhDashboard.
    .PARAMETER Id         Unique identifier (alphanumeric, - or _).
    .PARAMETER Title      Optional panel heading shown above the content.
    .PARAMETER Icon       Optional emoji / unicode icon shown before the title.
    .PARAMETER Content
        Raw HTML string rendered inside the panel.
        SECURITY: Content is injected as-is via innerHTML. Never pass untrusted
        external data directly into this parameter without HTML-encoding it first
        with [System.Web.HttpUtility]::HtmlEncode().
    .PARAMETER Style      Visual style: 'info' | 'warn' | 'danger' | 'ok' | 'neutral'

    .EXAMPLE
        Add-DhHtmlBlock -Report $report -Id 'intro' -Title 'Dashboard Structure' `
            -Icon 'X' -Style 'info' -Content @"
        This dashboard covers all infrastructure components:
        <ul>
          <li><strong>Section A</strong> — overview and statistics</li>
          <li><strong>Section B</strong> — detailed inventory</li>
          <li><strong>Section C</strong> — status and health</li>
        </ul>
        <p><strong>Tip:</strong> Use <em>Shift+Click</em> on column headers for
        multi-column sort. Right-click any cell to copy its value.</p>
        "@

    .EXAMPLE
        Add-DhHtmlBlock -Report $report -Id 'stale-warn' -Style 'warn' -Content `
            '<strong>Note:</strong> Data was collected 6 hours ago. Regenerate to refresh.'

    .EXAMPLE
        Add-DhHtmlBlock -Report $report -Id 'ok-note' -Style 'ok' -Content `
            'All health checks passed at last collection run.'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string] $Id,
        [string] $Title   = '',
        [string] $Icon    = '',
        [Parameter(Mandatory)] [string] $Content,
        [ValidateSet('info','warn','danger','ok','nodata','neutral')]
        [string] $Style   = 'info',
        # v1.6.0 — when $false, -Content is HTML-encoded (rendered as literal text)
        # instead of injected as raw markup. v2.0.0: the default is now $false
        # (encoded). Pass -AllowHtml:$true for intentional raw markup.
        [bool]   $AllowHtml   = $false,
        [bool]   $Collapsible = $true,    # wrap the block in a collapsible header (chevron + click-to-toggle)
        [bool]   $DefaultOpen = $true,    # whether the collapsible body starts expanded (only used when -Collapsible is $true)
        [ValidateRange(0,12)]
        [int]    $GridSpan    = 0,   # v1.10.0 - columns (1-12) to span in -report-grid layout; 0 = default flow
        [string] $NavGroup    = '',   # primary nav group label (enables two-tier nav)
        [string] $NavSubGroup = '',    # optional second-level group under NavGroup (enables three-tier nav)
        # ---- v2.0.0 navigation (see readme-dev.md section 15) ----
        [string] $NavPath      = '',   # 'A/B/C' - where this item lives. '//' escapes a literal '/'
        [ValidateSet('','Exact','Subtree','Global')]
        [string] $NavScope     = '',   # Exact (default) | Subtree (this node and below) | Global (everywhere)
        [string] $NavLabel     = '',   # display text for this node, decoupled from the path key
        [int]    $NavOrder     = 0     # explicit sibling ordering; 0 = declaration order
    )

    # v2.0.0 - resolve nav declaration once, in one place. Throws if -NavPath is
    # combined with -NavGroup/-NavSubGroup rather than silently preferring one.
    $navDecl = Resolve-DhNavDeclaration -NavPath $NavPath -NavScope $NavScope `
                    -NavGroup $NavGroup -NavSubGroup $NavSubGroup `
                    -ItemKind 'Block' -Context 'Add-DhHtmlBlock'
    # Monotonic declaration number, shared by tables and blocks. The exporter
    # emits ALL blocks before ALL tables, so without this the menu would order
    # nodes by section type instead of by the order the author wrote them.
    if (-not $Report.Contains('_DhNavSeq')) { $Report['_DhNavSeq'] = 0 }
    $navSeqNo = [int]$Report['_DhNavSeq']; $Report['_DhNavSeq'] = $navSeqNo + 1

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }

    # Duplicate-Id guard (same rule applied by other block cmdlets)
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhHtmlBlock: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }

    $safeContent = ConvertTo-DhSafeContent -Content $Content -AllowHtml $AllowHtml `
        -Explicit $PSBoundParameters.ContainsKey('AllowHtml') -Context "Add-DhHtmlBlock '$Id' -Content"

    $Report.Blocks.Add([ordered]@{
        BlockType = 'html'
        Id        = $Id
        Title     = $Title
        Icon      = $Icon
        Content   = $safeContent
        Style     = $Style
        NavGroup    = $NavGroup
        NavSubGroup = $NavSubGroup
        NavPath     = $NavPath
        NavSegments     = $navDecl.Path
        NavSeqNo     = $navSeqNo
        NavScope    = $navDecl.Scope
        NavLabel    = $NavLabel
        NavOrder    = $NavOrder
        GridSpan    = $GridSpan
        Collapsible = $Collapsible
        DefaultOpen = $DefaultOpen
    })
    Write-Verbose "Add-DhHtmlBlock: Added HTML block '$Id' (style: $Style)."
}



