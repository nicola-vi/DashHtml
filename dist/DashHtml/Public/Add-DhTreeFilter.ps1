function Add-DhTreeFilter {
    <#
    .SYNOPSIS
        Add a collapsible tree that filters a table by path (an OU / folder navigator).

    .DESCRIPTION
        v2.4.0. Shows a hierarchy (organisational units, folders, sites) as an
        expandable tree with a find box and a count per node. Choosing a node
        filters the linked table to the rows whose path field is that node or
        below it. Choosing it again, or using the table's clear button, removes
        the filter. The filter composes (AND) with the table's text filter, card
        filters and global filters.

        The tree is a filter, not a second copy of the data: the objects stay in
        the table. A node can carry a Detail (any section spec, see
        Add-DhKeyValue) that opens in the side panel.

        Matching is case-insensitive and respects the separator, so 'HQ' never
        matches 'HQ2':
          -Match Prefix   paths read root-first, 'contoso.com/HQ/Users'   (separator '/')
          -Match Suffix   distinguished names, 'OU=Users,OU=HQ,DC=contoso' (separator ',')

    .PARAMETER Report      Dashboard object from New-DhDashboard.
    .PARAMETER Id          Unique block identifier (alphanumeric, - or _).
    .PARAMETER Title       Heading shown above the tree.
    .PARAMETER TableId     The table to filter. It must already be added.
    .PARAMETER PathField   The row property that holds the path / distinguished name.
    .PARAMETER Nodes
        Array of hashtables:
          @{ Id='hq'; Parent='root'; Label='HQ'; Path='contoso.com/HQ'
             Count=42; Status='ok'; Flags=@('empty'); Detail=@{...} }
        Id, Label and Path are required; Parent is empty for a root. Count is
        optional (see -CountFromTable). Status is ok | warn | danger | info | nodata.
        Flags are short labels shown as chips. Detail is a section spec.
    .PARAMETER Match       Prefix (default) or Suffix.
    .PARAMETER Separator   Path separator. Default '/' for Prefix, ',' for Suffix.
    .PARAMETER CountFromTable
        Count the table's rows under each node in the browser (rows at the node
        plus everything below it) instead of using each node's Count. Counts
        ignore the table's other filters.
    .PARAMETER MaxNodes    Warn above this many nodes (default 5000); throw above 20000.
    .PARAMETER Height      Tree viewport height in px (default 420).
    .PARAMETER DefaultOpenDepth
        Levels that start expanded (default 1: the roots are open, so their children show;
        0: only the roots are shown; 99: everything is open).

    .EXAMPLE
        Add-DhTreeFilter -Report $r -Id 'ou-tree' -Title 'Organisational units' `
            -TableId 'ous' -PathField 'CanonicalName' -CountFromTable -Nodes @(
                @{ Id='root'; Label='contoso.com'; Path='contoso.com' }
                @{ Id='hq';   Parent='root'; Label='HQ';      Path='contoso.com/HQ' }
                @{ Id='srv';  Parent='hq';   Label='Servers'; Path='contoso.com/HQ/Servers'; Flags=@('empty') }
            )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string]   $Id,
        [Parameter(Mandatory)] [string]   $Title,
        [Parameter(Mandatory)] [string]   $TableId,
        [Parameter(Mandatory)] [string]   $PathField,
        [Parameter(Mandatory)] [object[]] $Nodes,

        [ValidateSet('Prefix','Suffix')]
        [string]   $Match = 'Prefix',
        [string]   $Separator = '',
        [switch]   $CountFromTable,

        [ValidateRange(1, 100000)]
        [int]      $MaxNodes = 5000,
        [ValidateRange(120, 1200)]
        [int]      $Height = 420,
        [ValidateRange(0, 99)]
        [int]      $DefaultOpenDepth = 1,

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
                    -ItemKind 'Block' -Context 'Add-DhTreeFilter'
    if (-not $Report.Contains('_DhNavSeq')) { $Report['_DhNavSeq'] = 0 }
    $navSeqNo = [int]$Report['_DhNavSeq']; $Report['_DhNavSeq'] = $navSeqNo + 1

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhTreeFilter: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }

    $srcTable = @($Report.Tables | Where-Object { $_.Id -eq $TableId } | Select-Object -First 1)
    if ($srcTable.Count -eq 0) {
        throw "Add-DhTreeFilter '$Id': table '$TableId' not found. Add the table before the tree filter."
    }
    $fieldNames = Get-DhTableFieldNames -Table $srcTable[0]
    if ($PathField -cnotin $fieldNames) {
        throw "Add-DhTreeFilter '$Id': PathField '$PathField' is not a field of table '$TableId'. Fields: $($fieldNames -join ', ')."
    }

    if (@($Nodes).Count -lt 1) { throw "Add-DhTreeFilter '$Id': -Nodes must contain at least one node." }
    if (@($Nodes).Count -gt 20000) {
        throw "Add-DhTreeFilter '$Id': $(@($Nodes).Count) nodes is over the hard limit of 20000. Send the top levels only."
    }
    if (@($Nodes).Count -gt $MaxNodes) {
        Write-Warning "Add-DhTreeFilter '$Id': $(@($Nodes).Count) nodes exceeds -MaxNodes ($MaxNodes). The tree is embedded in the page; consider the top levels only."
    }

    $sep = if ($Separator) { $Separator } elseif ($Match -eq 'Suffix') { ',' } else { '/' }
    $allowedStatus = @('ok','warn','danger','info','nodata','')

    $ids = @{}; $paths = @{}
    $norm = foreach ($n in $Nodes) {
        if ($n -isnot [System.Collections.IDictionary]) {
            throw "Add-DhTreeFilter '$Id': each node must be a hashtable. Got: $($n.GetType().Name)"
        }
        foreach ($req in 'Id','Label','Path') {
            if (-not $n.Contains($req) -or [string]::IsNullOrWhiteSpace([string]$n[$req])) {
                throw "Add-DhTreeFilter '$Id': each node must have a non-empty '$req' key."
            }
        }
        $nid = [string]$n['Id']
        if ($ids.ContainsKey($nid)) { throw "Add-DhTreeFilter '$Id': duplicate node Id '$nid'." }
        $ids[$nid] = $true
        $path = [string]$n['Path']
        $pk = $path.ToLowerInvariant()
        if ($paths.ContainsKey($pk)) { throw "Add-DhTreeFilter '$Id': node '$nid' repeats Path '$path' (already used by '$($paths[$pk])')." }
        $paths[$pk] = $nid
        $status = if ($n.Contains('Status') -and $n['Status']) { ConvertTo-DhStatusName $n['Status'] } else { '' }
        $status = switch ($status) { 'warning' { 'warn' } 'critical' { 'danger' } 'error' { 'danger' } default { $status } }
        if ($status -notin $allowedStatus) {
            throw "Add-DhTreeFilter '$Id': node '$nid' Status must be ok, warn, danger, info or nodata. Got: $($n['Status'])"
        }
        $count = $null
        if ($n.Contains('Count') -and $null -ne $n['Count'] -and "$($n['Count'])" -ne '') {
            $c = 0L
            if (-not [long]::TryParse([string]$n['Count'], [System.Globalization.NumberStyles]::Integer, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$c) -or $c -lt 0) {
                throw "Add-DhTreeFilter '$Id': node '$nid' Count must be a whole number >= 0. Got: $($n['Count'])"
            }
            $count = $c
        }
        $flags = @(if ($n.Contains('Flags') -and $null -ne $n['Flags']) { @($n['Flags']) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ } })
        [ordered]@{
            Id     = $nid
            Parent = if ($n.Contains('Parent') -and -not [string]::IsNullOrWhiteSpace([string]$n['Parent'])) { [string]$n['Parent'] } else { '' }
            Label  = [string]$n['Label']
            Path   = $path
            Count  = $count
            Status = $status
            Flags  = $flags
            Detail = if ($n.Contains('Detail')) { ConvertTo-DhDetailSpec -Detail $n['Detail'] -Context "Add-DhTreeFilter '$Id' node '$nid'" } else { $null }
        }
    }
    $norm = @($norm)

    # Parents exist; walk up with a hashtable (no pipeline per step) to find cycles.
    $byId = @{}
    foreach ($n in $norm) { $byId[$n.Id] = $n }
    foreach ($n in $norm) {
        if ($n.Parent -and -not $byId.ContainsKey($n.Parent)) {
            throw "Add-DhTreeFilter '$Id': node '$($n.Id)' references unknown Parent '$($n.Parent)'."
        }
        if ($n.Id -eq $n.Parent) { throw "Add-DhTreeFilter '$Id': node '$($n.Id)' cannot be its own Parent." }
    }
    foreach ($n in $norm) {
        $seen = @{ ($n.Id) = $true }
        $cur = $n.Parent; $depth = 0
        while ($cur -and $depth -lt 100000) {
            if ($seen.ContainsKey($cur)) { throw "Add-DhTreeFilter '$Id': cycle detected at node '$cur' (in chain starting from '$($n.Id)')." }
            $seen[$cur] = $true
            $cur = $byId[$cur].Parent
            $depth++
        }
    }

    $Report.Blocks.Add([ordered]@{
        BlockType        = 'treefilter'
        Id               = $Id
        Title            = $Title
        TableId          = $TableId
        PathField        = $PathField
        Nodes            = $norm
        Match            = $Match
        Separator        = $sep
        CountFromTable   = [bool]$CountFromTable.IsPresent
        Height           = $Height
        DefaultOpenDepth = $DefaultOpenDepth
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
    Write-Verbose "Add-DhTreeFilter: '$Id' ($($norm.Count) node(s)) filters table '$TableId' on '$PathField' ($Match)."
}
