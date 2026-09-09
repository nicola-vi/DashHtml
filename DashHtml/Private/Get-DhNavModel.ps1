<#
    Nav model — builds the menu tree from the declared items, decides the initial
    view, and emits the per-section attributes the runtime matches on.

    Everything here is depth-agnostic: no function mentions a number of levels.
    The tree is built from the paths the items declare, so adding a 4th or 5th
    level is data, not code (plan-v2.md D6).
#>

function New-DhNavNode {
    param([string[]] $Path = @(), [string] $Segment = '')
    return [ordered]@{
        Segment    = $Segment
        Path       = @($Path)
        Label      = $Segment      # overridden by the first -NavLabel seen
        Order      = 0             # from -NavOrder; 0 = declaration order
        Seq        = 0             # declaration order tiebreak
        HasContent = $false        # an item sits exactly here
        Children   = [ordered]@{}
    }
}

function Get-DhNavItem {
    <# Flatten every nav-declaring item in the report into a uniform shape. #>
    param([System.Collections.Specialized.OrderedDictionary] $Report)

    $items = [System.Collections.Generic.List[hashtable]]::new()
    $seq = 0

    foreach ($t in @($Report.Tables)) {
        if (-not $t) { continue }
        $items.Add(@{
            Kind  = 'Table'; Id = $t.Id
            Path  = @(if ($t.Contains('NavSegments')) { $t.NavSegments } else { @() })
            Scope = if ($t.Contains('NavScope') -and $t.NavScope) { $t.NavScope } else { 'Global' }
            Label = if ($t.Contains('NavLabel') -and $t.NavLabel) { $t.NavLabel } else { $t.Title }
            Order = if ($t.Contains('NavOrder')) { [int]$t.NavOrder } else { 0 }
            Seq   = if ($t.Contains('NavSeqNo')) { [int]$t.NavSeqNo } else { $seq }
        })
        $seq++
    }
    if ($Report.Contains('Blocks')) {
        foreach ($b in @($Report.Blocks)) {
            if (-not $b) { continue }
            $items.Add(@{
                Kind  = 'Block'; Id = $b.Id
                Path  = @(if ($b.Contains('NavSegments')) { $b.NavSegments } else { @() })
                Scope = if ($b.Contains('NavScope') -and $b.NavScope) { $b.NavScope } else { 'Global' }
                Label = if ($b.Contains('NavLabel') -and $b.NavLabel) { $b.NavLabel } else { $b.Id }
                Order = if ($b.Contains('NavOrder')) { [int]$b.NavOrder } else { 0 }
                Seq   = if ($b.Contains('NavSeqNo')) { [int]$b.NavSeqNo } else { $seq }
            })
            $seq++
        }
    }
    return $items
}

function Get-DhNavTree {
    <#
    .SYNOPSIS  Build the menu tree from every declared item.
    .OUTPUTS   The root node; children keyed by segment, in render order.
    #>
    param([System.Collections.Specialized.OrderedDictionary] $Report)

    $root  = New-DhNavNode
    $items = Get-DhNavItem -Report $Report

    foreach ($it in $items) {
        $path = @($it.Path)
        if ($path.Count -eq 0) { continue }   # page-global: no menu node

        $node = $root
        for ($i = 0; $i -lt $path.Count; $i++) {
            $seg = $path[$i]
            if (-not $node.Children.Contains($seg)) {
                $node.Children[$seg] = New-DhNavNode -Path @($path[0..$i]) -Segment $seg
                $node.Children[$seg].Seq = $it.Seq
            }
            $node = $node.Children[$seg]
        }
        # The leaf of an Exact item is a view that holds content of its own.
        if ($it.Scope -eq 'Exact') { $node.HasContent = $true }
        if ($it.Label -and $node.Label -eq $node.Segment) { $node.Label = $it.Label }
        if ($it.Order -ne 0 -and $node.Order -eq 0)       { $node.Order = $it.Order }
    }
    return $root
}

function Get-DhNavChildOrder {
    <# Children in render order: explicit -NavOrder first, then declaration order. #>
    param($Node)
    return @($Node.Children.Values |
        Sort-Object @{ Expression = { if ($_.Order -ne 0) { 0 } else { 1 } } },
                    @{ Expression = { $_.Order } },
                    @{ Expression = { $_.Seq } })
}

function Get-DhNavInitialPath {
    <#
    .SYNOPSIS
        The view the report opens on.
    .DESCRIPTION
        Descends from the root to the first node that holds content of its own,
        then STOPS. At depth <= 3 this is identical to 1.x descend-to-first-leaf;
        at depth 4+ it stops a single click teleporting the reader four levels
        down (plan-v2.md WP3.3).
        Returns an empty array when the report declares no nav at all.
    #>
    param($Tree)

    $path = [System.Collections.Generic.List[string]]::new()
    $node = $Tree
    while ($true) {
        # @(...) is load-bearing: a single-child node makes Get-DhNavChildOrder
        # return one object, PowerShell unrolls it on return, and $children[0]
        # would then index the OrderedDictionary by the KEY 0 and yield $null.
        $children = @(Get-DhNavChildOrder -Node $node)
        if ($children.Count -eq 0) { break }
        $node = $children[0]
        [void]$path.Add([string]$node.Segment)
        if ($node.HasContent) { break }
    }
    return @($path)
}

function Get-DhNavDepth {
    <# Deepest declared path in the tree. #>
    param($Node, [int] $Depth = 0)
    $max = $Depth
    foreach ($c in $Node.Children.Values) {
        $d = Get-DhNavDepth -Node $c -Depth ($Depth + 1)
        if ($d -gt $max) { $max = $d }
    }
    return $max
}

function ConvertTo-DhNavAttr {
    <#
    .SYNOPSIS
        The data-navpath / data-navscope attributes plus the initial panel-active
        class for one section.
    .DESCRIPTION
        data-navpath carries the path as a JSON array, so there is no separator
        to escape at runtime. The initial active state is stamped server-side
        using the same predicate the runtime uses (Test-DhNavMatch), which is
        what keeps the first paint and the first applyNav call in agreement.
    .OUTPUTS
        [hashtable] @{ Attr = ' data-navpath="..." data-navscope="..."'; Active = ' panel-active' | '' }
    #>
    param(
        [string[]] $Path        = @(),
        [string]   $Scope       = 'Global',
        [string[]] $InitialPath = @(),
        # Declaration order. The DOM emits ALL blocks before ALL tables, so without
        # this the menu would order nodes by section type rather than by the order
        # the author wrote them - which is not what anyone means.
        [int]      $Seq         = 0,
        [int]      $Order       = 0,
        [string]   $Label       = ''
    )

    # -InputObject, not a pipe: piping an EMPTY array sends nothing down the
    # pipeline, so ConvertTo-Json would emit nothing and the attribute would be
    # blank rather than '[]'.
    $json = ConvertTo-Json -InputObject @($Path) -Compress
    $attr = " data-navpath=`"$([System.Web.HttpUtility]::HtmlEncode($json))`"" +
            " data-navscope=`"$([System.Web.HttpUtility]::HtmlEncode($Scope.ToLowerInvariant()))`"" +
            " data-navseq=`"$Seq`""
    if ($Order -ne 0) { $attr += " data-navorder=`"$Order`"" }
    if ($Label)       { $attr += " data-navlabel=`"$([System.Web.HttpUtility]::HtmlEncode($Label))`"" }

    $active = if (Test-DhNavMatch -DeclaredPath $Path -SelectedPath $InitialPath -Scope $Scope) { ' panel-active' } else { '' }
    return @{ Attr = $attr; Active = $active }
}





