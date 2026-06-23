function Add-DhAlertBanner {
    <#
    .SYNOPSIS
        Add a top-of-page alert banner to the dashboard.

    .DESCRIPTION
        Renders a strip *above* the KPI summary tiles. Useful for surfacing
        current operational conditions — open incidents, recent failures,
        compliance breaches — so they are visible the moment the report opens.

        Multiple banners can be added; they stack vertically in the order they
        were declared. Each banner carries a severity (info / ok / warning /
        critical) which drives the colour via the existing RAG palette.

        Optionally:
          -Dismissible  — adds a close button; the dismissal is remembered in
                          the URL hash so it survives a page reload.
          -Action       — adds a button that either navigates to a registered
                          table (with an optional pre-filter) or opens an
                          external URL.

        Distinct from Add-DhEventFeed (v1.4+): a banner surfaces a single
        current condition; an event feed lists a chronological audit trail.

    .PARAMETER Report
        Dashboard object from New-DhDashboard.

    .PARAMETER Id
        Unique identifier (alphanumeric, dash, or underscore). Used as the
        DOM id and as the dismissal key in the URL hash.

    .PARAMETER Severity
        Visual treatment: 'info' | 'ok' | 'warning' | 'critical'.
        Default: 'info'.

    .PARAMETER Message
        The text shown in the banner (required). May contain inline HTML —
        use Add-DhHtmlBlock for richer content.

        SECURITY: Message is injected into the DOM via innerHTML. Never pass
        untrusted external data (AD attributes, ticket titles, log lines,
        anything supplied by an actor outside your trust boundary) into this
        parameter without HTML-encoding it first with
        [System.Web.HttpUtility]::HtmlEncode(). The same rule applies to
        Add-DhHtmlBlock, Add-DhTabs (per-tab Content), and Add-DhCollapsible
        (Content).

    .PARAMETER Icon
        Optional emoji / unicode glyph shown before the message.

    .PARAMETER Dismissible
        Adds a close (x) button. Dismissal persists across reloads via the URL
        hash. The banner re-appears in a new browser session.

    .PARAMETER Action
        Optional action button hashtable:
          @{
              Label    = 'View incidents'    # REQUIRED — button text
              TableId  = 'incidents'         # navigate to this registered table
              Filter   = 'severity:critical' # optional pre-filter text
              # ─ OR ─
              Url      = 'https://...'       # external link instead of TableId
          }

    .EXAMPLE
        # Simplest banner — just a message
        Add-DhAlertBanner -Report $report -Id 'maintenance' `
            -Severity 'info' -Message 'Maintenance window tonight 22:00–02:00 UTC'

    .EXAMPLE
        # Critical alert with action button — clicking jumps to a filtered table
        Add-DhAlertBanner -Report $report -Id 'open-incidents' `
            -Severity 'critical' -Icon '!' `
            -Message '3 critical incidents open in the last 24h' `
            -Dismissible `
            -Action @{ Label='View incidents'; TableId='incidents'; Filter='critical' }

    .EXAMPLE
        # External link
        Add-DhAlertBanner -Report $report -Id 'release-notes' `
            -Severity 'ok' -Message 'Patch level KB5044277 applied to 98% of hosts' `
            -Action @{ Label='Open KB'; Url='https://support.microsoft.com/kb/5044277' }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string] $Id,
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('info','ok','warning','critical')]
        [string]    $Severity = 'info',
        [string]    $Icon     = '',
        [switch]    $Dismissible,
        [hashtable] $Action   = $null,

        # v1.5.1 — collapsible banner chrome. Defaults to $true (matches the
        # rest of v1.5.1). The banner's message + icon + action button live
        # inside a clickable header bar. -Title controls the header text;
        # when empty it auto-derives from the severity ('Alert' / 'Notice' /
        # 'Warning' / 'Critical'). Pass -Collapsible:$false to keep the
        # original flat banner strip.
        [bool]      $Collapsible = $true,
        [bool]      $DefaultOpen = $true,
        [string]    $Title       = '',

        # v1.4.2+ — optional NavGroup binding. When set, the banner is visible
        # only while the matching nav group (and optional subgroup) is active.
        # Without these, the banner stays page-global (visible everywhere) as
        # in v1.4.x — full backward compatibility.
        [string]    $NavGroup    = '',
        [string]    $NavSubGroup = ''
    )

    # Init the collection lazily — keeps reports that don't use banners clean
    if (-not $Report.Contains('AlertBanners')) {
        $Report['AlertBanners'] = [System.Collections.Generic.List[hashtable]]::new()
    }

    # Duplicate-Id guard (same rule as Add-DhTable)
    foreach ($existing in $Report['AlertBanners']) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhAlertBanner: A banner with Id '$Id' already exists in this report. Use a unique Id."
        }
    }

    # Validate Action shape when provided
    $normAction = $null
    if ($Action) {
        if (-not $Action.Contains('Label') -or [string]::IsNullOrWhiteSpace([string]$Action.Label)) {
            throw "Add-DhAlertBanner: -Action requires a non-empty 'Label' key."
        }
        $hasTableId = $Action.Contains('TableId') -and -not [string]::IsNullOrWhiteSpace([string]$Action.TableId)
        $hasUrl     = $Action.Contains('Url')     -and -not [string]::IsNullOrWhiteSpace([string]$Action.Url)
        if (-not $hasTableId -and -not $hasUrl) {
            throw "Add-DhAlertBanner: -Action requires either a 'TableId' key (jump to table) or a 'Url' key (external link)."
        }
        if ($hasTableId -and $hasUrl) {
            throw "Add-DhAlertBanner: -Action must specify EITHER 'TableId' OR 'Url', not both."
        }
        # v1.5.3 — the JS renderer passes Url straight to window.open(); restrict the
        # scheme so a 'javascript:' Url cannot reach window.open() and execute in the
        # dashboard's origin. Test-DhSafeActionUrl throws on any unsupported scheme.
        $safeUrl = if ($hasUrl) { Test-DhSafeActionUrl -Url ([string]$Action.Url) -Context "Add-DhAlertBanner '$Id': Action.Url" } else { '' }

        $normAction = @{
            Label   = [string]$Action.Label
            TableId = if ($hasTableId) { [string]$Action.TableId } else { '' }
            Filter  = if ($Action.Contains('Filter')) { [string]$Action.Filter } else { '' }
            Url     = $safeUrl
        }
    }

    # Auto-derive a collapsible-header Title from severity when caller didn't supply one.
    $resolvedTitle = if (-not [string]::IsNullOrWhiteSpace($Title)) { $Title }
                     else { switch ($Severity) {
                         'critical' { 'Critical' }
                         'warning'  { 'Warning'  }
                         'ok'       { 'Notice'   }
                         default    { 'Alert'    }
                     } }

    $banner = [ordered]@{
        Id          = $Id
        Severity    = $Severity
        Message     = $Message
        Icon        = $Icon
        Dismissible = [bool]$Dismissible
        Action      = $normAction
        Collapsible = [bool]$Collapsible
        DefaultOpen = [bool]$DefaultOpen
        Title       = $resolvedTitle
        NavGroup    = $NavGroup
        NavSubGroup = $NavSubGroup
    }

    $Report['AlertBanners'].Add($banner)
    Write-Verbose "Add-DhAlertBanner: Added '$Id' (severity=$Severity, dismissible=$([bool]$Dismissible))."
}
