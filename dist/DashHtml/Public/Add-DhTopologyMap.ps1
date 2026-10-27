function Add-DhTopologyMap {
    <#
    .SYNOPSIS
        Add a topology / hierarchy map block (tree visualisation, v1.5+).

    .DESCRIPTION
        Renders a parent-child tree from a flat list of nodes. Per the
        IT-infrastructure KPI dashboard specification §2 ("Topology /
        Hierarchy Map"): used for AD Forest → Domain → DC, vCenter →
        Cluster → Host, network device hierarchies, etc.

        The renderer is intentionally simple: a recursive SVG tree with
        "spread leaves evenly, centre parents above children" layout. No
        force-directed graphs, no Reingold-Tilford — just a clean tidy
        tree that handles realistic IT hierarchies (≲ 50 nodes well).

        Cycles are rejected; missing parents throw.

    .PARAMETER Report
        Dashboard object from New-DhDashboard.

    .PARAMETER Id
        Unique identifier (alphanumeric, dash, underscore).

    .PARAMETER Title
        Block heading shown above the tree.

    .PARAMETER Nodes
        Array of node hashtables:
          @{
              Id      = 'forest'         # REQUIRED — unique within this topology
              Label   = 'contoso.com'    # REQUIRED — displayed inside the node
              Parent  = 'root-id'        # OR $null/'' for a root node
              Status  = 'ok'             # optional — ok | warn | danger | nodata | info
              Icon    = 'F'              # optional — emoji/glyph
              Badge   = 'AD'             # optional — small tag next to the label
              Tooltip = 'Forest functional level 2016'  # optional
              LinkTableId = 'incidents'  # optional — click navigates to a table
              LinkFilter  = 'auth-eu'    # optional — applied filter on jump
          }

        Multiple root nodes (Parent=$null) are allowed and render as forests.

    .PARAMETER Direction
        'vertical' (default — parent above children, tree flows downward) or
        'horizontal' (parent left of children, tree flows rightward).

    .PARAMETER NodeWidth / -NodeHeight
        Pixel dimensions of each node box. Defaults: 140 × 44.

    .PARAMETER MaxNodes
        Hard ceiling. Default 200. Throws above this. Trees larger than this
        usually need a different visualisation anyway.

    .PARAMETER NavGroup       Primary nav group label.
    .PARAMETER NavSubGroup    Optional second-level group.

    .EXAMPLE
        Add-DhTopologyMap -Report $report -Id 'ad-forest' -Title 'AD Forest' `
            -Nodes @(
                @{ Id='forest';  Label='contoso.com';        Status='ok';   Parent=$null }
                @{ Id='dom-hq';  Label='hq.contoso.com';     Status='ok';   Parent='forest' }
                @{ Id='dom-eu';  Label='eu.contoso.com';     Status='warn'; Parent='forest' }
                @{ Id='dc01';    Label='DC01';               Status='ok';   Parent='dom-hq' }
                @{ Id='dc02';    Label='DC02';               Status='ok';   Parent='dom-hq' }
                @{ Id='dc03';    Label='DC03';               Status='warn'; Parent='dom-eu'
                   Tooltip='Replication lag 4m'; LinkTableId='incidents'; LinkFilter='dc03' }
                @{ Id='dc04';    Label='DC04';               Status='danger'; Parent='dom-eu' }
            )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string] $Id,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [object[]] $Nodes,

        [ValidateSet('vertical','horizontal')]
        [string] $Direction = 'vertical',

        [ValidateRange(60, 400)]
        [int]    $NodeWidth  = 140,

        [ValidateRange(24, 200)]
        [int]    $NodeHeight = 44,

        [ValidateRange(1, 1000)]
        [int]    $MaxNodes = 200,

        # v1.5.2 — auto-fit node width: the JS renderer measures the widest
        # label (label + icon + badge + padding) and grows NodeWidth to fit,
        # capped at -AutoFitMaxWidth. Avoids the truncated-FQDN problem on
        # default 140 px boxes.
        [switch] $AutoFitWidth,
        [ValidateRange(140, 600)]
        [int]    $AutoFitMaxWidth = 360,

        # v1.7.0 — interactive pan / zoom / collapse. Default $true: the tree
        # renders in a fixed-height viewport with drag-to-pan, wheel-zoom, a
        # zoom/reset toolbar, and a +/- toggle on every parent node to fold its
        # subtree. Pass -Interactive:$false for the pre-1.7.0 static
        # scale-to-fit rendering (no toolbar, no collapse).
        [bool]   $Interactive = $true,

        [bool]   $Collapsible = $true,    # wrap the block in a collapsible header (chevron + click-to-toggle)

        [bool]   $DefaultOpen = $true,    # whether the collapsible body starts expanded (only used when -Collapsible is $true)

        [ValidateRange(0,12)]

        [int]    $GridSpan    = 0,   # v1.10.0 - columns (1-12) to span in -report-grid layout; 0 = default flow

        [string] $NavGroup    = '',
        [string] $NavSubGroup = '',
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
                    -ItemKind 'Block' -Context 'Add-DhTopologyMap'
    # Monotonic declaration number, shared by tables and blocks. The exporter
    # emits ALL blocks before ALL tables, so without this the menu would order
    # nodes by section type instead of by the order the author wrote them.
    if (-not $Report.Contains('_DhNavSeq')) { $Report['_DhNavSeq'] = 0 }
    $navSeqNo = [int]$Report['_DhNavSeq']; $Report['_DhNavSeq'] = $navSeqNo + 1

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhTopologyMap: A block with Id '$Id' already exists in this report."
        }
    }
    if ($Nodes.Count -lt 1) {
        throw "Add-DhTopologyMap: -Nodes must contain at least one node."
    }
    if ($Nodes.Count -gt $MaxNodes) {
        throw "Add-DhTopologyMap: $($Nodes.Count) nodes exceeds -MaxNodes ($MaxNodes). Tighten the scope or raise -MaxNodes deliberately."
    }

    $allowedStatus = @('ok','warn','danger','nodata','info','')

    # First pass: normalise + collect ids + detect duplicates
    $idSet  = @{}
    $normNodes = foreach ($n in $Nodes) {
        if ($n -isnot [hashtable] -and $n -isnot [System.Collections.Specialized.OrderedDictionary]) {
            throw "Add-DhTopologyMap: each node must be a hashtable. Got: $($n.GetType().Name)"
        }
        foreach ($req in 'Id','Label') {
            if (-not $n.Contains($req) -or [string]::IsNullOrWhiteSpace([string]$n[$req])) {
                throw "Add-DhTopologyMap: each node must have a non-empty '$req' key."
            }
        }
        $nid = [string]$n['Id']
        if ($idSet.ContainsKey($nid)) {
            throw "Add-DhTopologyMap: duplicate node Id '$nid'."
        }
        $idSet[$nid] = $true
        $status = if ($n.Contains('Status') -and $n['Status']) { ([string]$n['Status']).ToLowerInvariant() } else { '' }
        if ($status -notin $allowedStatus) {
            throw "Add-DhTopologyMap: node '$nid' — Status must be 'ok'/'warn'/'danger'/'nodata'/'info' or empty. Got: $($n['Status'])"
        }
        $parent = if ($n.Contains('Parent') -and -not [string]::IsNullOrWhiteSpace([string]$n['Parent'])) { [string]$n['Parent'] } else { '' }
        # Action validation
        $linkTableId = if ($n.Contains('LinkTableId') -and -not [string]::IsNullOrWhiteSpace([string]$n['LinkTableId'])) { [string]$n['LinkTableId'] } else { '' }
        $linkFilter  = if ($n.Contains('LinkFilter')  -and -not [string]::IsNullOrWhiteSpace([string]$n['LinkFilter']))  { [string]$n['LinkFilter']  } else { '' }
        if ($linkFilter -and -not $linkTableId) {
            throw "Add-DhTopologyMap: node '$nid' — LinkFilter requires LinkTableId."
        }
        @{
            Id          = $nid
            Label       = [string]$n['Label']
            Parent      = $parent
            Status      = $status
            Icon        = if ($n.Contains('Icon')   -and $null -ne $n['Icon'])   { [string]$n['Icon'] }   else { '' }
            Badge       = if ($n.Contains('Badge')  -and $null -ne $n['Badge'])  { [string]$n['Badge'] }  else { '' }
            Tooltip     = if ($n.Contains('Tooltip') -and $null -ne $n['Tooltip']) { [string]$n['Tooltip'] } else { '' }
            LinkTableId = $linkTableId
            LinkFilter  = $linkFilter
        }
    }

    # Second pass: verify parents exist and there are no cycles
    foreach ($n in $normNodes) {
        if ($n.Parent -and -not $idSet.ContainsKey($n.Parent)) {
            throw "Add-DhTopologyMap: node '$($n.Id)' references unknown Parent '$($n.Parent)'."
        }
        if ($n.Id -eq $n.Parent) {
            throw "Add-DhTopologyMap: node '$($n.Id)' cannot be its own Parent."
        }
    }
    # Cycle detection: walk up from each node, bail if we revisit. The Id-to-node
    # map keeps this O(n * depth); a pipeline lookup per step was O(n^2).
    $byId = @{}
    foreach ($n in $normNodes) { $byId[$n.Id] = $n }
    foreach ($n in $normNodes) {
        $seen = @{ ($n.Id) = $true }
        $cur = $n.Parent
        $depth = 0
        while ($cur -and $depth -lt 1000) {
            if ($seen.ContainsKey($cur)) {
                throw "Add-DhTopologyMap: cycle detected at node '$cur' (in chain starting from '$($n.Id)')."
            }
            $seen[$cur] = $true
            $cur = $byId[$cur].Parent
            $depth++
        }
    }

    $Report.Blocks.Add([ordered]@{
        BlockType   = 'topologymap'
        Id          = $Id
        Title       = $Title
        Nodes       = @($normNodes)
        Direction   = $Direction
        NodeWidth   = $NodeWidth
        NodeHeight  = $NodeHeight
        AutoFitWidth    = [bool]$AutoFitWidth.IsPresent
        AutoFitMaxWidth = $AutoFitMaxWidth
        Interactive     = $Interactive
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

    $rootCount = @($normNodes | Where-Object { -not $_.Parent }).Count
    Write-Verbose "Add-DhTopologyMap: '$Id' ($($normNodes.Count) nodes, $rootCount root(s), direction=$Direction)."
}


