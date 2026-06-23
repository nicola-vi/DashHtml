function Add-DhEventFeed {
    <#
    .SYNOPSIS
        Add a chronological event-feed block — severity-tagged audit trail.

    .DESCRIPTION
        Renders a list of timestamped events with severity colour-coding. Per
        the IT-infrastructure KPI dashboard specification (§4.1 and §4.2), the
        event feed is the canonical "Row 5" of an ops dashboard — the
        evidence trail that pairs with the at-a-glance KPI tiles above.

        Distinct from Add-DhAlertBanner: a banner surfaces a single CURRENT
        condition (visible at the top of the page until dismissed); an event
        feed lists a chronological history (typically the last N events from
        a log query).

    .PARAMETER Report       Dashboard object from New-DhDashboard.
    .PARAMETER Id           Unique identifier (alphanumeric, dash, underscore).
    .PARAMETER Title        Block heading shown above the list.

    .PARAMETER Events
        Array of event hashtables. Per event:
          @{
              Timestamp = '2026-05-22 14:32'          # REQUIRED — free-form string
              Severity  = 'critical'                  # REQUIRED — info | ok | warning | critical
              Message   = 'Replication failure to DC03' # REQUIRED — the event text
              Source    = 'DC01'                      # optional — origin tag, shown in brackets
              Icon      = '!'                         # optional — overrides default severity glyph
          }

    .PARAMETER MaxItems
        Cap on the number of events shown. Defaults to 50. Older events are
        dropped after the sort+slice. Range 1..1000.

    .PARAMETER GroupBy
        Optional grouping: 'None' (default), 'Severity', or 'Source'. When
        grouped, the events within each group are still ordered by Timestamp;
        groups themselves appear in a fixed priority order
        (Severity: critical > warning > ok > info; Source: alphabetical).

    .PARAMETER SortDescending
        Newest-first by Timestamp. Default $true. Set $false to show oldest
        events at the top (chronological reading order).

    .PARAMETER NavGroup       Primary nav group label (enables two-tier nav).
    .PARAMETER NavSubGroup    Optional second-level group under NavGroup.

    .EXAMPLE
        Add-DhEventFeed -Report $report -Id 'recent-events' `
            -Title 'Recent events (24h)' -MaxItems 50 `
            -Events @(
                @{ Timestamp='2026-05-22 14:32'; Severity='critical'; Source='DC01';
                   Message='Replication failure to DC03' }
                @{ Timestamp='2026-05-22 14:18'; Severity='warning';  Source='DC02';
                   Message='LDAP bind time > 80 ms (avg)' }
                @{ Timestamp='2026-05-22 13:55'; Severity='info';     Source='vSphere';
                   Message='vMotion: VM-027 → ESXi-04' }
            )

    .EXAMPLE
        # Group by severity so critical entries float to the top
        Add-DhEventFeed -Report $report -Id 'incidents-by-sev' `
            -Title 'Open incidents' -GroupBy 'Severity' `
            -Events $incidents
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string] $Id,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [object[]] $Events,

        [ValidateRange(1, 1000)]
        [int]    $MaxItems = 50,

        [ValidateSet('None','Severity','Source')]
        [string] $GroupBy = 'None',

        [bool]   $SortDescending = $true,

        [bool]   $Collapsible = $true,    # wrap the block in a collapsible header (chevron + click-to-toggle)

        [bool]   $DefaultOpen = $true,    # whether the collapsible body starts expanded (only used when -Collapsible is $true)

        [string] $NavGroup    = '',
        [string] $NavSubGroup = ''
    )

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhEventFeed: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }
    if (-not $Events -or $Events.Count -lt 1) {
        throw "Add-DhEventFeed: -Events must contain at least one event."
    }

    $allowedSeverities = @('info','ok','warning','critical')

    $normEvents = foreach ($e in $Events) {
        if ($e -isnot [hashtable] -and $e -isnot [System.Collections.Specialized.OrderedDictionary]) {
            throw "Add-DhEventFeed: each event must be a hashtable. Got: $($e.GetType().Name)"
        }
        foreach ($req in 'Timestamp','Severity','Message') {
            if (-not $e.Contains($req) -or [string]::IsNullOrWhiteSpace([string]$e[$req])) {
                throw "Add-DhEventFeed: each event must have a non-empty '$req' key."
            }
        }
        $sev = ([string]$e['Severity']).ToLowerInvariant()
        if ($sev -notin $allowedSeverities) {
            throw "Add-DhEventFeed: event Severity must be 'info', 'ok', 'warning', or 'critical'. Got: $($e['Severity'])"
        }
        @{
            Timestamp = [string]$e['Timestamp']
            Severity  = $sev
            Message   = [string]$e['Message']
            Source    = if ($e.Contains('Source') -and $null -ne $e['Source']) { [string]$e['Source'] } else { '' }
            Icon      = if ($e.Contains('Icon')   -and $null -ne $e['Icon'])   { [string]$e['Icon'] }   else { '' }
        }
    }

    $Report.Blocks.Add([ordered]@{
        BlockType      = 'eventfeed'
        Id             = $Id
        Title          = $Title
        Events         = @($normEvents)
        MaxItems       = $MaxItems
        GroupBy        = $GroupBy.ToLowerInvariant()
        SortDescending = [bool]$SortDescending
        NavGroup       = $NavGroup
        NavSubGroup = $NavSubGroup
        Collapsible = $Collapsible
        DefaultOpen = $DefaultOpen
    })
    Write-Verbose "Add-DhEventFeed: '$Id' ($($normEvents.Count) event(s), max=$MaxItems, groupBy=$GroupBy)."
}
