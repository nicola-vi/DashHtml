function Add-DhFindings {
    <#
    .SYNOPSIS
        Add a list of assessment findings - severity, description, recommendation,
        affected objects and references - as one expandable block.

    .DESCRIPTION
        v2.2.0. The block an audit or assessment report is built around. Each
        finding is one row (severity badge, title, area, affected count) that
        expands to show what is wrong, what to do about it, which objects are
        affected, a "Show in table" jump to the detail table, and reference
        links (for example Microsoft Learn).

        Above the list: severity counters that double as filters (click to
        show only that severity, click more to combine), and a text filter
        over every field of every finding.

        Findings are sorted critical -> warning -> info -> ok, then by affected
        count, largest first (-SortBy None keeps your order). When printed,
        every finding is shown expanded.

        All text is HTML-encoded. There is no -AllowHtml: finding text usually
        comes from collected data.

    .PARAMETER Report    Dashboard object from New-DhDashboard.
    .PARAMETER Id        Unique block identifier (alphanumeric, - or _).
    .PARAMETER Title     Block heading.

    .PARAMETER Findings
        Array of hashtables:
          @{
              Severity        = 'critical'   # REQUIRED critical|warning|info|ok
                                             #   (aliases: high, medium, low)
              Title           = 'AS-REP roastable accounts'   # REQUIRED
              Area            = 'Accounts'                    # optional grouping / filter text
              Description     = 'Accounts with DoesNotRequirePreAuth ...'
              Recommendation  = 'Clear DONT_REQ_PREAUTH on every listed account.'
              Affected        = @('svc_old','test1')          # optional names
              AffectedCount   = 2            # optional; defaults to Affected.Count
              AffectedTableId = 'risky-accounts'   # optional: "Show in table" target
              AffectedFilter  = 'AS-REP'           # optional text filter for that table
              References      = @(@{ Label='MS Learn'; Url='https://learn.microsoft.com/...' })
              Id              = 'asrep'      # optional stable id (default f1, f2, ...)
          }
        Reference URLs must be http(s), mailto, tel or an in-page #anchor - the
        same rule as alert and tile actions. Anything else throws.

    .PARAMETER GroupBy           None (default) | Area | Severity - group header rows.
    .PARAMETER ShowCounters      Severity counter chips that filter the list (default $true).
    .PARAMETER Filterable        Text filter box (default $true).
    .PARAMETER ExpandSeverity    Severities whose findings start expanded, e.g. 'critical'.
    .PARAMETER MaxAffectedShown  Affected names listed per finding before "+N more" (default 20).
    .PARAMETER HideOk            Drop findings with Severity ok.
    .PARAMETER SortBy            Severity (default) | None.

    .EXAMPLE
        Add-DhFindings -Report $r -Id 'sec' -Title 'Security findings' -NavPath 'Security' `
            -GroupBy Area -ExpandSeverity critical -Findings @(
              @{ Severity='critical'; Title='AS-REP roastable accounts'; Area='Accounts'
                 Description='Accounts with DoesNotRequirePreAuth expose crackable hashes.'
                 Recommendation='Clear DONT_REQ_PREAUTH on every listed account.'
                 Affected=@('svc_old','test1'); AffectedTableId='accounts'; AffectedFilter='AS-REP'
                 References=@(@{ Label='MS Learn'; Url='https://learn.microsoft.com/' }) }
              @{ Severity='medium'; Title='Stale computer objects'; Area='Hygiene'; AffectedCount=148 }
            )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string]   $Id,
        [string]   $Title = 'Findings',
        [Parameter(Mandatory)] [object[]] $Findings,
        [ValidateSet('None','Area','Severity')]
        [string]   $GroupBy = 'None',
        [bool]     $ShowCounters = $true,
        [bool]     $Filterable = $true,
        [string[]] $ExpandSeverity = @(),
        [ValidateRange(0, 10000)]
        [int]      $MaxAffectedShown = 20,
        [switch]   $HideOk,
        [ValidateSet('Severity','None')]
        [string]   $SortBy = 'Severity',
        [bool]     $Collapsible = $true,    # wrap the block in a collapsible header
        [bool]     $DefaultOpen = $true,    # collapsible body starts expanded
        [ValidateRange(0,12)]
        [int]      $GridSpan    = 0,        # columns (1-12) in the -GridSpan grid layout; 0 = default flow
        [string]   $NavGroup    = '',
        [string]   $NavSubGroup = '',
        # ---- v2.0.0 navigation (see readme-dev.md section 5) ----
        [string]   $NavPath     = '',   # 'A/B/C' - where this item lives. '//' escapes a literal '/'
        [ValidateSet('','Exact','Subtree','Global')]
        [string]   $NavScope    = '',   # Exact (default) | Subtree (this node and below) | Global (everywhere)
        [string]   $NavLabel    = '',   # display text for this node, decoupled from the path key
        [int]      $NavOrder    = 0     # explicit sibling ordering; 0 = declaration order
    )

    $navDecl = Resolve-DhNavDeclaration -NavPath $NavPath -NavScope $NavScope `
                    -NavGroup $NavGroup -NavSubGroup $NavSubGroup `
                    -ItemKind 'Block' -Context 'Add-DhFindings'
    if (-not $Report.Contains('_DhNavSeq')) { $Report['_DhNavSeq'] = 0 }
    $navSeqNo = [int]$Report['_DhNavSeq']; $Report['_DhNavSeq'] = $navSeqNo + 1

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhFindings: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }

    $expand = @(foreach ($s in $ExpandSeverity) { ConvertTo-DhSeverity -Severity $s -Context "Add-DhFindings '$Id' -ExpandSeverity" })

    $seenIds = @{}
    $n = 0
    $norm = foreach ($f in $Findings) {
        $n++
        if ($f -isnot [System.Collections.IDictionary]) {
            throw "Add-DhFindings '$Id': finding #$n must be a hashtable. Got: $($f.GetType().Name)"
        }
        if (-not $f.Contains('Title') -or [string]::IsNullOrWhiteSpace([string]$f['Title'])) {
            throw "Add-DhFindings '$Id': finding #$n has no Title."
        }
        $ctx = "Add-DhFindings '$Id' finding '$($f['Title'])'"
        $sev = ConvertTo-DhSeverity -Severity ([string]$f['Severity']) -Context $ctx
        if ($HideOk -and $sev -eq 'ok') { continue }

        $fid = if ($f.Contains('Id') -and -not [string]::IsNullOrWhiteSpace([string]$f['Id'])) { [string]$f['Id'] } else { "f$n" }
        if ($fid -notmatch '^[A-Za-z0-9_-]+$') { throw "${ctx}: Id must be alphanumeric, - or _. Got: '$fid'" }
        if ($seenIds.ContainsKey($fid)) { throw "${ctx}: duplicate finding Id '$fid'." }
        $seenIds[$fid] = $true

        $affected = @(if ($f.Contains('Affected') -and $null -ne $f['Affected']) { @($f['Affected']) | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ } })
        $count = if ($f.Contains('AffectedCount') -and $null -ne $f['AffectedCount']) {
            $c = 0
            if (-not [int]::TryParse([string]$f['AffectedCount'], [ref]$c) -or $c -lt 0) { throw "${ctx}: AffectedCount must be a whole number >= 0. Got: $($f['AffectedCount'])" }
            $c
        } else { $affected.Count }

        $tableId = if ($f.Contains('AffectedTableId')) { [string]$f['AffectedTableId'] } else { '' }
        $filter  = if ($f.Contains('AffectedFilter'))  { [string]$f['AffectedFilter'] }  else { '' }
        if ($filter -and -not $tableId) { throw "${ctx}: AffectedFilter requires AffectedTableId." }

        $refs = @(foreach ($ref in @($f['References'])) {
            if ($null -eq $ref) { continue }
            if ($ref -isnot [System.Collections.IDictionary]) { throw "${ctx}: each References entry must be @{ Label; Url }." }
            $url = Test-DhSafeActionUrl -Url ([string]$ref['Url']) -Context "$ctx reference"
            if (-not $url) { throw "${ctx}: a References entry has no Url." }
            @{ Label = if ($ref['Label']) { [string]$ref['Label'] } else { $url }; Url = $url }
        })

        [ordered]@{
            Id              = $fid
            Seq             = $n
            Severity        = $sev
            Title           = [string]$f['Title']
            Area            = if ($f.Contains('Area')) { [string]$f['Area'] } else { '' }
            Description     = if ($f.Contains('Description')) { [string]$f['Description'] } else { '' }
            Recommendation  = if ($f.Contains('Recommendation')) { [string]$f['Recommendation'] } else { '' }
            Affected        = $affected
            AffectedCount   = $count
            AffectedTableId = $tableId
            AffectedFilter  = $filter
            References      = $refs
        }
    }
    $norm = @($norm)

    if ($SortBy -eq 'Severity') {
        $rank = @{ critical = 0; warning = 1; info = 2; ok = 3 }
        # Seq as the last key keeps the sort stable for equal severity and count
        $norm = @($norm | Sort-Object { $rank[$_.Severity] }, @{ Expression = { $_.AffectedCount }; Descending = $true }, { $_.Seq })
    }

    $Report.Blocks.Add([ordered]@{
        BlockType        = 'findings'
        Id               = $Id
        Title            = $Title
        Findings         = $norm
        GroupBy          = $GroupBy.ToLowerInvariant()
        ShowCounters     = $ShowCounters
        Filterable       = $Filterable
        ExpandSeverity   = $expand
        MaxAffectedShown = $MaxAffectedShown
        NavGroup         = $NavGroup
        NavSubGroup      = $NavSubGroup
        NavPath          = $NavPath
        NavSegments      = $navDecl.Path
        NavSeqNo         = $navSeqNo
        NavScope         = $navDecl.Scope
        NavLabel         = $NavLabel
        NavOrder         = $NavOrder
        GridSpan         = $GridSpan
        Collapsible      = $Collapsible
        DefaultOpen      = $DefaultOpen
    })
    Write-Verbose "Add-DhFindings: '$Id' ($($norm.Count) finding(s), groupBy=$GroupBy)."
}
