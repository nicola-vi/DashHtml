function Add-DhNetworkMap {
    <#
    .SYNOPSIS
        Add a network / dependency map: nodes joined by edges, in groups or in tier lanes.

    .DESCRIPTION
        v2.4.0. Draws a graph that is not a tree: domain controllers and their
        replication links, sites and site links, trusts, or accounts and the tier
        they can reach. Unlike Add-DhTopologyMap (one parent per node) a node can
        have any number of links, several links can join the same two nodes, and
        a link can have a direction, a label, a status colour and a dashed style.

        The layout is computed in the browser and is deterministic: the same data
        always gives the same picture (no force simulation).
          -Layout grouped   nodes sit in boxes (Groups), boxes can nest. For
                            sites > domains > servers.
          -Layout layered   horizontal lanes by Tier (0 on top). For Tier 0/1/2
                            views. A node without Tier takes its depth from the
                            links (From above To).

        The reader can pan and zoom, filter by status or badge, search nodes,
        click a node to highlight its links (and open its Detail in the side
        panel, or jump to a table), trace the shortest path from a node to the
        nearest Target node, and download the map as SVG.

        All text is HTML-encoded.

    .PARAMETER Report   Dashboard object from New-DhDashboard.
    .PARAMETER Id       Unique block identifier (alphanumeric, - or _).
    .PARAMETER Title    Heading shown above the map.
    .PARAMETER Nodes
        Array of hashtables:
          @{ Id='dc01'; Label='DC01'; Group='site-hq'; Tier=0; Status='ok'
             Badge=@('PDC','GC'); Target=$false; Icon=''; Tooltip='...'
             Detail=<text or sections>; LinkTableId='dcs'; LinkFilter='DC01' }
        Id and Label are required. Status is ok | warn | danger | info | nodata.
        Badge is a list of short tags (shown on the node, usable as a filter).
        Target marks the nodes "trace path" aims for (for example Tier 0 assets).
    .PARAMETER Edges
        Array of hashtables:
          @{ From='dc01'; To='dc02'; Label='15 min'; Status='danger'
             Style='dashed'; Direction='both'; Tooltip='Last failure 02:10'
             LinkTableId='repl'; LinkFilter='dc01' }
        From and To must be node Ids. Direction is none | forward (default) | both.
        Style is solid (default) | dashed. Several edges between the same two
        nodes are drawn as parallel curves.
    .PARAMETER Groups
        Array of @{ Id; Label; Parent; Status } boxes for -Layout grouped.
        Parent nests a group inside another.
    .PARAMETER Layout     grouped (default) or layered.
    .PARAMETER MaxNodes   Hard ceiling (default 300).
    .PARAMETER MaxEdges   Hard ceiling (default 1500).
    .PARAMETER NodeWidth  Node box width in px (default 150).
    .PARAMETER NodeHeight Node box height in px (default 46).
    .PARAMETER Height     Viewport height in px (default 520).
    .PARAMETER Legend     Show a legend of the colours and line styles.

    .EXAMPLE
        Add-DhNetworkMap -Report $r -Id 'repl' -Title 'Replication' -Legend `
            -Groups @(@{ Id='hq'; Label='HQ' }, @{ Id='eu'; Label='EU' }) `
            -Nodes @(
                @{ Id='dc01'; Label='DC01'; Group='hq'; Badge=@('PDC') }
                @{ Id='dc02'; Label='DC02'; Group='eu'; Status='warn' }
            ) `
            -Edges @(
                @{ From='dc01'; To='dc02'; Label='15 min'; Direction='both' }
            )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string]   $Id,
        [Parameter(Mandatory)] [string]   $Title,
        [Parameter(Mandatory)] [object[]] $Nodes,
        [AllowEmptyCollection()] [object[]] $Edges  = @(),
        [AllowEmptyCollection()] [object[]] $Groups = @(),

        [ValidateSet('grouped','layered')]
        [string]   $Layout = 'grouped',

        [ValidateRange(1, 2000)]
        [int]      $MaxNodes = 300,
        [ValidateRange(1, 20000)]
        [int]      $MaxEdges = 1500,
        [ValidateRange(60, 400)]
        [int]      $NodeWidth = 150,
        [ValidateRange(24, 200)]
        [int]      $NodeHeight = 46,
        [ValidateRange(200, 1600)]
        [int]      $Height = 520,
        [switch]   $Legend,

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
                    -ItemKind 'Block' -Context 'Add-DhNetworkMap'
    if (-not $Report.Contains('_DhNavSeq')) { $Report['_DhNavSeq'] = 0 }
    $navSeqNo = [int]$Report['_DhNavSeq']; $Report['_DhNavSeq'] = $navSeqNo + 1

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhNetworkMap: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }
    if (@($Nodes).Count -lt 1) { throw "Add-DhNetworkMap '$Id': -Nodes must contain at least one node." }
    if (@($Nodes).Count -gt $MaxNodes) {
        throw "Add-DhNetworkMap '$Id': $(@($Nodes).Count) nodes exceeds -MaxNodes ($MaxNodes). Tighten the scope or raise -MaxNodes deliberately."
    }
    if (@($Edges).Count -gt $MaxEdges) {
        throw "Add-DhNetworkMap '$Id': $(@($Edges).Count) edges exceeds -MaxEdges ($MaxEdges). Tighten the scope or raise -MaxEdges deliberately."
    }

    $allowedStatus = @('ok','warn','danger','info','nodata','')
    $statusOf = {
        param($raw, $where)
        $s = ConvertTo-DhStatusName $raw
        $s = switch ($s) { 'warning' { 'warn' } 'critical' { 'danger' } 'error' { 'danger' } default { $s } }
        if ($s -notin $allowedStatus) { throw "Add-DhNetworkMap '$Id': $where Status must be ok, warn, danger, info or nodata. Got: $raw" }
        $s
    }
    $str = { param($h, $k) if ($h.Contains($k) -and $null -ne $h[$k]) { [string]$h[$k] } else { '' } }

    # ---- groups ------------------------------------------------------------
    $groupIds = @{}
    $normGroups = @(foreach ($g in @($Groups)) {
        if ($null -eq $g) { continue }
        if ($g -isnot [System.Collections.IDictionary]) { throw "Add-DhNetworkMap '$Id': each group must be a hashtable. Got: $($g.GetType().Name)" }
        foreach ($req in 'Id','Label') {
            if (-not $g.Contains($req) -or [string]::IsNullOrWhiteSpace([string]$g[$req])) { throw "Add-DhNetworkMap '$Id': each group must have a non-empty '$req' key." }
        }
        $gid = [string]$g['Id']
        if ($groupIds.ContainsKey($gid)) { throw "Add-DhNetworkMap '$Id': duplicate group Id '$gid'." }
        $groupIds[$gid] = $true
        [ordered]@{
            Id     = $gid
            Label  = [string]$g['Label']
            Parent = (& $str $g 'Parent').Trim()
            Status = & $statusOf $(if ($g.Contains('Status')) { $g['Status'] } else { '' }) "group '$gid'"
        }
    })
    $groupById = @{}
    foreach ($g in $normGroups) { $groupById[$g.Id] = $g }
    foreach ($g in $normGroups) {
        if ($g.Parent -and -not $groupById.ContainsKey($g.Parent)) { throw "Add-DhNetworkMap '$Id': group '$($g.Id)' references unknown Parent '$($g.Parent)'." }
        if ($g.Parent -eq $g.Id) { throw "Add-DhNetworkMap '$Id': group '$($g.Id)' cannot be its own Parent." }
    }
    foreach ($g in $normGroups) {
        $seen = @{ ($g.Id) = $true }; $cur = $g.Parent; $d = 0
        while ($cur -and $d -lt 10000) {
            if ($seen.ContainsKey($cur)) { throw "Add-DhNetworkMap '$Id': group cycle detected at '$cur' (in chain starting from '$($g.Id)')." }
            $seen[$cur] = $true; $cur = $groupById[$cur].Parent; $d++
        }
    }

    # ---- nodes -------------------------------------------------------------
    $nodeIds = @{}
    $normNodes = @(foreach ($n in $Nodes) {
        if ($n -isnot [System.Collections.IDictionary]) { throw "Add-DhNetworkMap '$Id': each node must be a hashtable. Got: $($n.GetType().Name)" }
        foreach ($req in 'Id','Label') {
            if (-not $n.Contains($req) -or [string]::IsNullOrWhiteSpace([string]$n[$req])) { throw "Add-DhNetworkMap '$Id': each node must have a non-empty '$req' key." }
        }
        $nid = [string]$n['Id']
        if ($nodeIds.ContainsKey($nid)) { throw "Add-DhNetworkMap '$Id': duplicate node Id '$nid'." }
        $nodeIds[$nid] = $true
        $grp = (& $str $n 'Group').Trim()
        if ($grp -and -not $groupById.ContainsKey($grp)) { throw "Add-DhNetworkMap '$Id': node '$nid' references unknown Group '$grp'." }
        $tier = $null
        if ($n.Contains('Tier') -and $null -ne $n['Tier'] -and "$($n['Tier'])" -ne '') {
            $t = 0
            if (-not [int]::TryParse([string]$n['Tier'], [ref]$t) -or $t -lt 0) { throw "Add-DhNetworkMap '$Id': node '$nid' Tier must be a whole number >= 0. Got: $($n['Tier'])" }
            $tier = $t
        }
        $lt = (& $str $n 'LinkTableId').Trim(); $lf = (& $str $n 'LinkFilter')
        if ($lf -and -not $lt) { throw "Add-DhNetworkMap '$Id': node '$nid' - LinkFilter requires LinkTableId." }
        $badges = @(if ($n.Contains('Badge') -and $null -ne $n['Badge']) { @($n['Badge']) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ } })
        [ordered]@{
            Id          = $nid
            Label       = [string]$n['Label']
            Group       = $grp
            Tier        = $tier
            Status      = & $statusOf $(if ($n.Contains('Status')) { $n['Status'] } else { '' }) "node '$nid'"
            Icon        = & $str $n 'Icon'
            Badge       = $badges
            Target      = [bool]($n.Contains('Target') -and $n['Target'])
            Tooltip     = & $str $n 'Tooltip'
            Detail      = if ($n.Contains('Detail')) { ConvertTo-DhDetailSpec -Detail $n['Detail'] -Context "Add-DhNetworkMap '$Id' node '$nid'" } else { $null }
            LinkTableId = $lt
            LinkFilter  = $lf
        }
    })

    # ---- edges -------------------------------------------------------------
    $n = 0
    $normEdges = @(foreach ($e in @($Edges)) {
        if ($null -eq $e) { continue }
        $n++
        if ($e -isnot [System.Collections.IDictionary]) { throw "Add-DhNetworkMap '$Id': each edge must be a hashtable. Got: $($e.GetType().Name)" }
        foreach ($req in 'From','To') {
            if (-not $e.Contains($req) -or [string]::IsNullOrWhiteSpace([string]$e[$req])) { throw "Add-DhNetworkMap '$Id': edge #$n needs a non-empty '$req'." }
        }
        $from = [string]$e['From']; $to = [string]$e['To']
        foreach ($end in @(@('From', $from), @('To', $to))) {
            if (-not $nodeIds.ContainsKey($end[1])) { throw "Add-DhNetworkMap '$Id': edge #$n $($end[0]) '$($end[1])' is not a node Id." }
        }
        $dir = if ($e.Contains('Direction') -and $e['Direction']) { ([string]$e['Direction']).ToLowerInvariant() } else { 'forward' }
        if ($dir -notin 'none','forward','both') { throw "Add-DhNetworkMap '$Id': edge #$n Direction must be none, forward or both. Got: $($e['Direction'])" }
        $style = if ($e.Contains('Style') -and $e['Style']) { ([string]$e['Style']).ToLowerInvariant() } else { 'solid' }
        if ($style -notin 'solid','dashed') { throw "Add-DhNetworkMap '$Id': edge #$n Style must be solid or dashed. Got: $($e['Style'])" }
        $lt = (& $str $e 'LinkTableId').Trim(); $lf = (& $str $e 'LinkFilter')
        if ($lf -and -not $lt) { throw "Add-DhNetworkMap '$Id': edge #$n - LinkFilter requires LinkTableId." }
        [ordered]@{
            From        = $from
            To          = $to
            Label       = & $str $e 'Label'
            Status      = & $statusOf $(if ($e.Contains('Status')) { $e['Status'] } else { '' }) "edge #$n"
            Style       = $style
            Direction   = $dir
            Tooltip     = & $str $e 'Tooltip'
            LinkTableId = $lt
            LinkFilter  = $lf
        }
    })

    $Report.Blocks.Add([ordered]@{
        BlockType   = 'networkmap'
        Id          = $Id
        Title       = $Title
        Nodes       = $normNodes
        Edges       = $normEdges
        Groups      = $normGroups
        Layout      = $Layout
        NodeWidth   = $NodeWidth
        NodeHeight  = $NodeHeight
        Height      = $Height
        Legend      = [bool]$Legend.IsPresent
        NavGroup    = $NavGroup
        NavSubGroup = $NavSubGroup
        NavPath     = $NavPath
        NavSegments = $navDecl.Path
        NavSeqNo    = $navSeqNo
        NavScope    = $navDecl.Scope
        NavLabel    = $NavLabel
        NavOrder    = $NavOrder
        GridSpan    = $GridSpan
        Collapsible = $Collapsible
        DefaultOpen = $DefaultOpen
    })
    Write-Verbose "Add-DhNetworkMap: '$Id' ($($normNodes.Count) node(s), $($normEdges.Count) edge(s), $($normGroups.Count) group(s), layout=$Layout)."
}
