function Get-DhEditDistance {
    <# Levenshtein distance between two strings (small inputs: menu segment names). #>
    param([string] $A, [string] $B)
    $m = $A.Length; $n = $B.Length
    if ($m -eq 0) { return $n }
    if ($n -eq 0) { return $m }
    $prev = 0..$n
    for ($i = 1; $i -le $m; $i++) {
        $cur = @($i) + @(0) * $n
        for ($j = 1; $j -le $n; $j++) {
            $cost = if ($A[$i - 1] -ceq $B[$j - 1]) { 0 } else { 1 }
            $cur[$j] = [math]::Min([math]::Min($cur[$j - 1] + 1, $prev[$j] + 1), $prev[$j - 1] + $cost)
        }
        $prev = $cur
    }
    return $prev[$n]
}

function Test-DhNavLint {
    <#
    .SYNOPSIS
        Likely menu mistakes in a report, as warning strings (New-DhDashboard -StrictNav).
    .DESCRIPTION
        Never throws. Returns nothing for a clean menu. Rules:
          * a path deeper than 3 levels (the strips stop fitting; -NavLayout Sidebar handles it);
          * sibling nodes whose labels are the same (case-insensitive);
          * sibling names that differ only in case ('Sub A' / 'Sub a': nav matching is case-sensitive);
          * sibling names one letter apart (probably a typo: 'Storage' / 'Storag');
          * a path that is not listed in -NavTree, when a -NavTree is given;
          * a -NavTree node with nothing on it or below it;
          * a Subtree item whose node has nothing below it (it behaves like Exact);
          * a -NavAllLabel that names no group node;
          * a Global item that also has a -NavPath (the path only adds an empty node, which the menu leaves out).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param([Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report)

    $out = [System.Collections.Generic.List[string]]::new()
    $items = @(Get-DhNavItem -Report $Report | Where-Object { @($_.Path).Count -gt 0 })
    $tree = Get-DhNavTree -Report $Report

    foreach ($it in $items) {
        if ("$($it.Scope)" -eq 'Global') { $out.Add("Nav lint: '$($it.Id)' has -NavPath '$(@($it.Path) -join '/')' with -NavScope Global: it shows on every view, and the path only adds an empty menu node, which the menu leaves out. Drop the -NavPath, or use -NavScope Subtree.") }
    }
    foreach ($it in $items) {
        if (@($it.Path).Count -gt 3) { $out.Add("Nav lint: '$($it.Id)' sits at '$(@($it.Path) -join '/')', $(@($it.Path).Count) levels deep; more than 3 levels needs -NavLayout Sidebar and a longer reading path.") }
    }

    # the explicit -NavLabel of the first item on a node (else the menu shows the segment)
    $explicit = @{}
    foreach ($kind in 'Tables', 'Blocks') {
        if (-not $Report.Contains($kind)) { continue }
        foreach ($x in @($Report[$kind])) {
            if (-not $x -or -not $x.Contains('NavLabel') -or -not $x.NavLabel -or -not $x.Contains('NavSegments')) { continue }
            $k = (@($x.NavSegments) -join [char]0x1F)
            if ($k -and -not $explicit.ContainsKey($k)) { $explicit[$k] = [string]$x.NavLabel }
        }
    }

    # Siblings, compared case-sensitively (nav matching is). The PowerShell tree keys are case-insensitive,
    # so two names that differ only in case would be one node there; collect them from the raw paths.
    $siblings = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]::new([StringComparer]::Ordinal)
    $addPath = {
        param([string[]] $segs)
        for ($d = 0; $d -lt $segs.Count; $d++) {
            $parent = if ($d -eq 0) { '' } else { ($segs[0..($d - 1)] -join [char]0x1F) }
            if (-not $siblings.ContainsKey($parent)) { $siblings[$parent] = [System.Collections.Generic.List[string]]::new() }
            if (-not $siblings[$parent].Contains($segs[$d])) { $siblings[$parent].Add($segs[$d]) }
        }
    }
    foreach ($it in $items) { & $addPath @($it.Path) }
    foreach ($e in @(if ($Report.Contains('NavTree') -and $Report.NavTree) { $Report.NavTree })) { & $addPath @(ConvertFrom-DhNavPath ([string]$e.Path)) }

    foreach ($parent in $siblings.Keys) {
        $names = $siblings[$parent]
        $trail = @(if ($parent) { $parent -split [char]0x1F })
        $where = if ($trail.Count) { "under '$($trail -join '/')'" } else { 'at the top level' }
        for ($a2 = 0; $a2 -lt $names.Count; $a2++) {
            for ($b2 = $a2 + 1; $b2 -lt $names.Count; $b2++) {
                $sa = $names[$a2]; $sb = $names[$b2]
                if ($sa -ieq $sb) {
                    $out.Add("Nav lint: '$sa' and '$sb' $where differ only in case; nav matching is case-sensitive, so they are two menu items.")
                    continue
                }
                if ($sa.Length -ge 4 -and $sb.Length -ge 4 -and (Get-DhEditDistance $sa.ToLowerInvariant() $sb.ToLowerInvariant()) -eq 1) {
                    $out.Add("Nav lint: '$sa' and '$sb' $where are one letter apart; is one of them a typo?")
                }
                $ka = (@($trail) + $sa) -join [char]0x1F; $kb = (@($trail) + $sb) -join [char]0x1F
                $la = if ($explicit.ContainsKey($ka)) { $explicit[$ka] } else { $sa }
                $lb = if ($explicit.ContainsKey($kb)) { $explicit[$kb] } else { $sb }
                if ($la -ieq $lb) { $out.Add("Nav lint: '$sa' and '$sb' $where both show as '$la' in the menu.") }
            }
        }
    }
    # Subtree item with nothing below it
    foreach ($it in $items) {
        if ($it.Scope -ne 'Subtree') { continue }
        $n = $tree
        foreach ($s in @($it.Path)) { $n = $n.Children[$s] }
        if ($n -and $n.Children.Count -eq 0) {
            $out.Add("Nav lint: '$($it.Id)' is -NavScope Subtree at '$(@($it.Path) -join '/')', which has no views below it, so it behaves like Exact.")
        }
    }

    # -NavTree checks
    $skeleton = @(if ($Report.Contains('NavTree') -and $Report.NavTree) { $Report.NavTree })
    if ($skeleton.Count) {
        $declared = @{}
        foreach ($e in $skeleton) { $declared[((ConvertFrom-DhNavPath ([string]$e.Path)) -join [char]0x1F)] = $true }
        $seenMissing = @{}
        foreach ($it in $items) {
            $segs = @($it.Path)
            $k = ($segs -join [char]0x1F)
            if (-not $declared.ContainsKey($k) -and -not $seenMissing.ContainsKey($k)) {
                $seenMissing[$k] = $true
                $out.Add("Nav lint: '$($segs -join '/')' (used by '$($it.Id)') is not listed in -NavTree.")
            }
        }
        $used = @{}
        foreach ($it in $items) { $segs = @($it.Path); for ($d = 1; $d -le $segs.Count; $d++) { $used[(@($segs[0..($d - 1)]) -join [char]0x1F)] = $true } }
        foreach ($e in $skeleton) {
            $k = ((ConvertFrom-DhNavPath ([string]$e.Path)) -join [char]0x1F)
            if (-not $used.ContainsKey($k)) { $out.Add("Nav lint: -NavTree node '$($e.Path)' has no content on it or below it; the view will show a 'no content' note.") }
        }
    }

    # -NavAllLabel keys that name no group
    if ($Report.Contains('NavAllLabel') -and $Report.NavAllLabel -is [System.Collections.IDictionary]) {
        foreach ($k in $Report.NavAllLabel.Keys) {
            $n = $tree
            foreach ($s in (ConvertFrom-DhNavPath ([string]$k))) { if ($n) { $n = $n.Children[$s] } }
            if (-not $n -or $n.Children.Count -eq 0) { $out.Add("Nav lint: -NavAllLabel '$k' names no group (a menu node with views below it).") }
        }
    }
    return @($out)
}
