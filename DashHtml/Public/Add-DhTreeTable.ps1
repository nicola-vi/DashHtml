function Add-DhTreeTable {
    <#
    .SYNOPSIS
        Add a directory explorer: a tree of OUs, groups, users and computers with a property panel,
        group membership and nesting.

    .DESCRIPTION
        One block with two panes. The left pane is a tree (expand and collapse, find box, type
        filter, status dot, flag chips, a count on containers and groups). The right pane shows the
        selected object in tabs:
          Properties   the label/value pairs you supply, plus any extra sections
          Members      (groups) who is in the group; click a member to go to it
          Member of    which groups the object is directly in
          Nesting      (groups) the groups nested below, and for any object every path up to the
                       top-level groups that grant it membership (effective membership). A circular
                       nesting is detected and marked, not followed forever.

        The data is two flat lists, so a collector can emit it without recursion:
          -Rows         one entry per object: Id, ParentId (the OU or container it sits in), Type,
                        Label, plus optional Status, Flags, Properties, Detail
          -Memberships  one entry per membership: GroupId and MemberId (a member can be a user, a
                        computer or another group)

        Rows are drawn only when their parent is open. Above 2,000 rows the tree is windowed (v2.6.0):
        only the rows in view are in the page, so 50,000 objects stay quick. The cmdlet warns above
        -MaxRows (default 20000) and throws above 100000 rows. The toolbar's CSV button saves the
        visible rows; the Members and Member of tabs save their list.

        All text is HTML-encoded.

    .PARAMETER Report   Dashboard object from New-DhDashboard.
    .PARAMETER Id       Unique block identifier (alphanumeric, - or _).
    .PARAMETER Title    Heading shown above the explorer.
    .PARAMETER Rows
        Array of hashtables:
          @{ Id='grp-da'; ParentId='ou-groups'; Type='group'; Label='Domain Admins'
             Status='warn'; Flags=@('privileged')
             Properties=[ordered]@{ 'Distinguished name'='CN=Domain Admins,...'; 'Members'='4' }
             Detail=<text or sections> }
        Id, Type and Label are required. ParentId is empty for a root. Type is one of ou, group,
        user, computer, container, other. Status is ok | warn | danger | info | nodata.
    .PARAMETER Memberships
        Array of @{ GroupId; MemberId }. Both must be row Ids. GroupId should be a group (a warning
        names any that is not).
    .PARAMETER MaxRows        Warn above this many rows (default 20000; 5000 before 2.6.0); throws above 100000.
    .PARAMETER Height         Height of both panes in px (default 520).
    .PARAMETER DefaultOpenDepth
        Levels that start expanded (default 1: roots are open, so their children show).
    .PARAMETER MaxNestingPaths
        Most "path up" lines the Nesting tab lists for one object (default 50).

    .EXAMPLE
        Add-DhTreeTable -Report $r -Id 'dir' -Title 'Directory' -Rows @(
            @{ Id='ou-hq';  ParentId='';      Type='ou';    Label='Headquarters' }
            @{ Id='g-da';   ParentId='ou-hq'; Type='group'; Label='Domain Admins'; Flags=@('privileged') }
            @{ Id='u-rossi';ParentId='ou-hq'; Type='user';  Label='adm.rossi'
               Properties=[ordered]@{ 'Last logon'='2026-10-16'; 'Password age'='41 days' } }
        ) -Memberships @(
            @{ GroupId='g-da'; MemberId='u-rossi' }
        )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string]   $Id,
        [Parameter(Mandatory)] [string]   $Title,
        [Parameter(Mandatory)] [object[]] $Rows,
        [AllowEmptyCollection()] [object[]] $Memberships = @(),

        [ValidateRange(1, 100000)]
        [int]      $MaxRows = 20000,
        [ValidateRange(240, 1600)]
        [int]      $Height = 520,
        [ValidateRange(0, 99)]
        [int]      $DefaultOpenDepth = 1,
        [ValidateRange(1, 1000)]
        [int]      $MaxNestingPaths = 50,

        [bool]     $Collapsible = $false,
        [bool]     $DefaultOpen = $true,
        [ValidateRange(0,12)]
        [int]      $GridSpan    = 0,
        [string]   $NavGroup    = '',
        [string]   $NavSubGroup = '',
        # ---- v2.0.0 navigation (see readme-dev.md section 5) ----
        [string]   $NavPath     = '',
        [ValidateSet('','Exact','Subtree','Global')]
        [string]   $NavScope    = '',
        [string]   $NavLabel    = '',
        [int]      $NavOrder    = 0
    )

    $navDecl = Resolve-DhNavDeclaration -NavPath $NavPath -NavScope $NavScope `
                    -NavGroup $NavGroup -NavSubGroup $NavSubGroup `
                    -ItemKind 'Block' -Context 'Add-DhTreeTable'
    if (-not $Report.Contains('_DhNavSeq')) { $Report['_DhNavSeq'] = 0 }
    $navSeqNo = [int]$Report['_DhNavSeq']; $Report['_DhNavSeq'] = $navSeqNo + 1

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhTreeTable: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }

    if (@($Rows).Count -lt 1) { throw "Add-DhTreeTable '$Id': -Rows must contain at least one row." }
    if (@($Rows).Count -gt 100000) {
        throw "Add-DhTreeTable '$Id': $(@($Rows).Count) rows is over the hard limit of 100000. Send the top levels, or use Add-DhTreeFilter with a table."
    }
    if (@($Rows).Count -gt $MaxRows) {
        Write-Warning "Add-DhTreeTable '$Id': $(@($Rows).Count) rows exceeds -MaxRows ($MaxRows). The data is embedded in the page; consider fewer rows."
    }

    $types = @('ou', 'group', 'user', 'computer', 'container', 'other')
    $allowedStatus = @('ok', 'warn', 'danger', 'info', 'nodata', '')

    $ids = @{}
    $norm = foreach ($r in $Rows) {
        if ($r -isnot [System.Collections.IDictionary]) {
            throw "Add-DhTreeTable '$Id': each row must be a hashtable. Got: $($r.GetType().Name)"
        }
        foreach ($req in 'Id', 'Type', 'Label') {
            if (-not $r.Contains($req) -or [string]::IsNullOrWhiteSpace([string]$r[$req])) {
                throw "Add-DhTreeTable '$Id': each row must have a non-empty '$req' key."
            }
        }
        $rid = [string]$r['Id']
        if ($ids.ContainsKey($rid)) { throw "Add-DhTreeTable '$Id': duplicate row Id '$rid'." }
        $ids[$rid] = $true
        $type = ([string]$r['Type']).Trim().ToLowerInvariant()
        if ($type -notin $types) { throw "Add-DhTreeTable '$Id': row '$rid' Type must be one of $($types -join ', '). Got: $($r['Type'])" }
        $status = if ($r.Contains('Status') -and $r['Status']) { ConvertTo-DhStatusName $r['Status'] } else { '' }
        $status = switch ($status) { 'warning' { 'warn' } 'critical' { 'danger' } 'error' { 'danger' } default { $status } }
        if ($status -notin $allowedStatus) { throw "Add-DhTreeTable '$Id': row '$rid' Status must be ok, warn, danger, info or nodata. Got: $($r['Status'])" }
        $props = [ordered]@{}
        if ($r.Contains('Properties') -and $null -ne $r['Properties']) {
            if ($r['Properties'] -isnot [System.Collections.IDictionary]) { throw "Add-DhTreeTable '$Id': row '$rid' Properties must be a hashtable of label = value." }
            foreach ($k in $r['Properties'].PSBase.Keys) { $props[[string]$k] = $(if ($null -eq $r['Properties'][$k]) { '' } else { [string]$r['Properties'][$k] }) }
        }
        $flags = @(if ($r.Contains('Flags') -and $null -ne $r['Flags']) { @($r['Flags']) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ } })
        [ordered]@{
            Id         = $rid
            ParentId   = if ($r.Contains('ParentId') -and -not [string]::IsNullOrWhiteSpace([string]$r['ParentId'])) { [string]$r['ParentId'] } else { '' }
            Type       = $type
            Label      = [string]$r['Label']
            Status     = $status
            Flags      = $flags
            Properties = $props
            Detail     = if ($r.Contains('Detail')) { ConvertTo-DhDetailSpec -Detail $r['Detail'] -Context "Add-DhTreeTable '$Id' row '$rid'" } else { $null }
        }
    }
    $norm = @($norm)

    # Parents exist; walk up with a hashtable to find cycles
    $byId = @{}
    foreach ($n in $norm) { $byId[$n.Id] = $n }
    foreach ($n in $norm) {
        if ($n.ParentId -and -not $byId.ContainsKey($n.ParentId)) { throw "Add-DhTreeTable '$Id': row '$($n.Id)' references unknown ParentId '$($n.ParentId)'." }
        if ($n.Id -eq $n.ParentId) { throw "Add-DhTreeTable '$Id': row '$($n.Id)' cannot be its own parent." }
    }
    foreach ($n in $norm) {
        $seen = @{ ($n.Id) = $true }; $cur = $n.ParentId; $depth = 0
        while ($cur -and $depth -lt 100000) {
            if ($seen.ContainsKey($cur)) { throw "Add-DhTreeTable '$Id': the ParentId chain loops at row '$cur' (starting from '$($n.Id)'). Containers cannot contain themselves; group nesting belongs in -Memberships." }
            $seen[$cur] = $true; $cur = $byId[$cur].ParentId; $depth++
        }
    }

    # Memberships: both ends must be rows; duplicates dropped; a non-group GroupId is a warning
    $links = [System.Collections.Generic.List[object]]::new()
    $linkSeen = @{}
    $m = 0
    foreach ($ms in @($Memberships)) {
        if ($null -eq $ms) { continue }
        $m++
        if ($ms -isnot [System.Collections.IDictionary] -or -not $ms.Contains('GroupId') -or -not $ms.Contains('MemberId')) {
            throw "Add-DhTreeTable '$Id': membership #$m must be @{ GroupId; MemberId }."
        }
        $g = [string]$ms['GroupId']; $mem = [string]$ms['MemberId']
        if (-not $byId.ContainsKey($g))   { throw "Add-DhTreeTable '$Id': membership #$m GroupId '$g' is not a row Id." }
        if (-not $byId.ContainsKey($mem)) { throw "Add-DhTreeTable '$Id': membership #$m MemberId '$mem' is not a row Id." }
        if ($byId[$g].Type -ne 'group') { Write-Warning "Add-DhTreeTable '$Id': membership #$m GroupId '$g' is a $($byId[$g].Type), not a group." }
        $key = "$g`u{1}$mem"
        if ($linkSeen.ContainsKey($key)) { continue }
        $linkSeen[$key] = $true
        $links.Add([ordered]@{ GroupId = $g; MemberId = $mem })
    }

    $Report.Blocks.Add([ordered]@{
        BlockType        = 'treetable'
        Id               = $Id
        Title            = $Title
        Rows             = $norm
        Memberships      = $links.ToArray()
        Height           = $Height
        DefaultOpenDepth = $DefaultOpenDepth
        MaxNestingPaths  = $MaxNestingPaths
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
    Write-Verbose "Add-DhTreeTable: '$Id' ($($norm.Count) row(s), $($links.Count) membership(s))."
}
