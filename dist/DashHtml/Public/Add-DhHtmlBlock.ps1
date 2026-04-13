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
        [ValidateSet('info','warn','danger','ok','neutral')]
        [string] $Style   = 'info',
        [string] $NavGroup = ''    # primary nav group label (enables two-tier nav)
    )

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }

    $Report.Blocks.Add([ordered]@{
        BlockType = 'html'
        Id        = $Id
        Title     = $Title
        Icon      = $Icon
        Content   = $Content
        Style     = $Style
        NavGroup  = $NavGroup
    })
    Write-Verbose "Add-DhHtmlBlock: Added HTML block '$Id' (style: $Style)."
}
