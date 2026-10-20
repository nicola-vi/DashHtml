#Requires -Version 7.0
<#
.SYNOPSIS
    Print the menu of an exported DashHtml dashboard and what each view shows, in page order.

.DESCRIPTION
    Reads the HTML file, not the report object, so it shows what a reader gets: the menu
    tree, the view the page opens on, and for every selectable view the sections that are
    visible there in the order they appear on the page.

    Page order inside a view is fixed by the exporter: alert banners, the global filter bar,
    the global KPI strip, then every block in the order it was declared, then every table in
    the order it was declared. A table can therefore never sit between two blocks.

    It also warns about the things that usually mean a mistake:
      * a block with no menu path (it appears on EVERY view);
      * a menu view that shows nothing of its own;
      * a table or block bound deeper than any menu node can reach.

.PARAMETER Path
    One or more exported .html files (wildcards allowed).

.PARAMETER Quiet
    Print only the warnings (and a one-line summary per file).

.PARAMETER PassThru
    Return one object per file ({ File, Opens, Views, Global, Warnings }) instead of only printing.

.EXAMPLE
    ./Tools/Show-DhNavMap.ps1 -Path ./Examples/Demo-ActiveDirectory.html

.EXAMPLE
    ./Tools/Show-DhNavMap.ps1 -Path ./Examples/*.html -Quiet
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string[]] $Path,
    [switch] $Quiet,
    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Config {
    param([string] $Html, [string] $Name)
    $m = [regex]::Match($Html, "var $Name\s*=\s*(.*?);\r?\n")
    if (-not $m.Success) { return @() }
    try { return @($m.Groups[1].Value | ConvertFrom-Json -Depth 30) } catch { return @() }
}

# Same rule as Test-DhNavMatch / navMatches
function Test-Match {
    param([string[]] $Declared, [string] $Scope, [string[]] $Selected)
    if ($Scope -eq 'global') { return $true }
    if ($Selected.Count -gt 0 -and $Selected[-1] -ceq '*') {          # an 'All' view: everything at or below the parent
        $base = @(); if ($Selected.Count -gt 1) { $base = @($Selected[0..($Selected.Count - 2)]) }
        for ($i = 0; $i -lt [math]::Min($Declared.Count, $base.Count); $i++) { if ($Declared[$i] -cne $base[$i]) { return $false } }
        return ($Declared.Count -ge $base.Count) -or ($Scope -eq 'subtree')
    }
    if ($Declared.Count -gt $Selected.Count) { return $false }
    for ($i = 0; $i -lt $Declared.Count; $i++) { if ($Declared[$i] -cne $Selected[$i]) { return $false } }
    return ($Scope -eq 'subtree') -or ($Declared.Count -eq $Selected.Count)
}

$results = foreach ($file in (Get-ChildItem -Path $Path -File)) {
    $html = [IO.File]::ReadAllText($file.FullName)
    $warnings = [System.Collections.Generic.List[string]]::new()

    $tables = Get-Config $html 'TABLES_CONFIG'
    $blocks = Get-Config $html 'BLOCKS_CONFIG'
    $alerts = Get-Config $html 'ALERTS_CONFIG'
    $summary = Get-Config $html 'SUMMARY_CONFIG'
    $gfilters = Get-Config $html 'GLOBALFILTER_CONFIG'
    $title = @{}
    foreach ($t in $tables) { $title["section-$($t.id)"] = "$($t.title)" }
    $btype = @{}
    foreach ($b in $blocks) { $title["bsection-$($b.id)"] = "$($b.title)"; $btype["bsection-$($b.id)"] = "$($b.blockType)" }

    # Sections, in page order
    $items = [System.Collections.Generic.List[object]]::new()
    $rx = '<(?:div|section) class="(?<cls>(?:block|table)-section)[^"]*" id="(?<id>(?:bsection|section)-[^"]+)"[^>]*?data-navpath="(?<path>[^"]*)" data-navscope="(?<scope>[^"]*)"(?<rest>[^>]*)'
    foreach ($m in [regex]::Matches($html, $rx)) {
        $segs = @([System.Net.WebUtility]::HtmlDecode($m.Groups['path'].Value) | ConvertFrom-Json)
        $id = $m.Groups['id'].Value
        $items.Add([pscustomobject]@{
            Kind  = if ($m.Groups['cls'].Value -eq 'block-section') { 'block' } else { 'table' }
            Id    = ($id -replace '^(bsection|section)-', '')
            Key   = $id
            Type  = if ($btype.ContainsKey($id)) { $btype[$id] } else { 'table' }
            Title = if ($title.ContainsKey($id)) { $title[$id] } else { '' }
            Path  = [string[]]$segs
            Scope = $m.Groups['scope'].Value
            Seq   = $(if ($m.Groups['rest'].Value -match 'data-navseq="(\d+)"') { [int]$Matches[1] } else { 0 })
            Order = $(if ($m.Groups['rest'].Value -match 'data-navorder="(-?\d+)"') { [int]$Matches[1] } else { 0 })
            Label = $(if ($m.Groups['rest'].Value -match 'data-navlabel="([^"]*)"') { [System.Net.WebUtility]::HtmlDecode($Matches[1]) } else { '' })
        })
    }
    $bi = 0
    foreach ($a in $alerts) {
        [string[]] $p = @()
        if ($a.PSObject.Properties.Name -contains 'navPath') { $p = [string[]]@($a.navPath) }
        $sc = if ($a.PSObject.Properties.Name -contains 'navScope') { "$($a.navScope)" } elseif ($p.Count) { 'exact' } else { 'global' }
        $items.Insert($bi++, [pscustomobject]@{ Kind = 'banner'; Id = "$($a.id)"; Key = "alert-$($a.id)"; Type = "$($a.severity)"; Title = ("$($a.message)" -replace '<[^>]+>', ''); Path = $p; Scope = $sc; Seq = 0; Order = 0; Label = '' })
    }

    # Menu nodes: every prefix of every exact item's path; a node is a view when an exact item sits on it
    $views = [System.Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal)
    foreach ($it in $items) {
        if ($it.Kind -eq 'banner' -or $it.Path.Count -eq 0) { continue }
        if ($it.Scope -eq 'exact') { $views[($it.Path -join "`u{1}")] = $it.Path }
    }
    # A subtree/global-less node that has only descendants is not a view but still a menu node
    $unsorted = [hashtable]::new([StringComparer]::Ordinal); $nodeSeq = [hashtable]::new([StringComparer]::Ordinal); $nodeOrd = [hashtable]::new([StringComparer]::Ordinal); $nodeLabel = [hashtable]::new([StringComparer]::Ordinal)
    foreach ($it in $items) {
        # a Global item shows everywhere; its path would only add an empty node, which the page leaves out of the menu (2.5.2)
        if ($it.Kind -eq 'banner' -or $it.Path.Count -eq 0 -or $it.Scope -eq 'global') { continue }
        for ($d = 1; $d -le $it.Path.Count; $d++) {
            $k = ($it.Path[0..($d - 1)]) -join "`u{1}"
            $unsorted[$k] = [string[]]$it.Path[0..($d - 1)]
            if (-not $nodeSeq.ContainsKey($k) -or $it.Seq -lt $nodeSeq[$k]) { $nodeSeq[$k] = $it.Seq }
            if ($d -eq $it.Path.Count -and $it.Label -and (-not $nodeLabel.ContainsKey($k))) { $nodeLabel[$k] = $it.Label }
            if ($d -eq $it.Path.Count -and $it.Order -ne 0 -and (-not $nodeOrd.ContainsKey($k))) { $nodeOrd[$k] = $it.Order }
        }
    }
    # -NavTree skeleton and -NavAllLabel, read from the menu bar's attributes
    $navTag = [regex]::Match($html, '<nav [^>]*id="report-nav"[^>]*>').Value
    $attr = { param($n) $m = [regex]::Match($navTag, "$n=`"([^`"]*)`""); if ($m.Success) { [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value) } else { '' } }
    $skeleton = @(); $allMap = [hashtable]::new([StringComparer]::Ordinal); $allDefault = ''
    $tj = & $attr 'data-navtree'; if ($tj) { $skeleton = @($tj | ConvertFrom-Json) }
    $aj = & $attr 'data-navall';  if ($aj) { foreach ($a in @($aj | ConvertFrom-Json)) { $allMap[(@($a.path) -join "`u{1}")] = "$($a.label)" } }
    $allDefault = & $attr 'data-navallall'
    for ($si = 0; $si -lt $skeleton.Count; $si++) {
        $sp = [string[]]@($skeleton[$si].path)
        for ($d = 1; $d -le $sp.Count; $d++) {
            $k = ($sp[0..($d - 1)]) -join "`u{1}"
            $unsorted[$k] = [string[]]$sp[0..($d - 1)]
            if (-not $nodeSeq.ContainsKey($k) -or (-100000 + $si) -lt $nodeSeq[$k]) { $nodeSeq[$k] = -100000 + $si }
        }
        $lk = $sp -join "`u{1}"
        if ($skeleton[$si].label -and -not $nodeLabel.ContainsKey($lk)) { $nodeLabel[$lk] = "$($skeleton[$si].label)" }
        if ([int]$skeleton[$si].order -ne 0 -and -not $nodeOrd.ContainsKey($lk)) { $nodeOrd[$lk] = [int]$skeleton[$si].order }
    }
    # The menu orders siblings by explicit -NavOrder, then by the first declaration under the node (what the page does)
    $menuNodes = [System.Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal)
    function Add-Children {
        param([string[]] $Parent)
        $kids = @($unsorted.Keys | Where-Object { $unsorted[$_].Count -eq $Parent.Count + 1 -and ($Parent.Count -eq 0 -or (($unsorted[$_][0..($Parent.Count - 1)] -join "`u{1}") -eq ($Parent -join "`u{1}"))) })
        $sorted = $kids | Sort-Object { if ($nodeOrd.ContainsKey($_)) { 0 } else { 1 } }, { if ($nodeOrd.ContainsKey($_)) { $nodeOrd[$_] } else { 0 } }, { $nodeSeq[$_] }
        foreach ($k in $sorted) { $menuNodes[$k] = $unsorted[$k]; Add-Children -Parent $unsorted[$k] }
    }
    Add-Children -Parent @()
    # 'All' views: a group node (one with children) gets an addressable child whose last segment is '*'
    $allFor = [hashtable]::new([StringComparer]::Ordinal)
    foreach ($mk in @($menuNodes.Keys)) {
        $hasKids = @($menuNodes.Keys | Where-Object { $menuNodes[$_].Count -eq $menuNodes[$mk].Count + 1 -and (($menuNodes[$_][0..($menuNodes[$mk].Count - 1)] -join "`u{1}") -eq $mk) }).Count -gt 0
        $lab = if ($allMap.ContainsKey($mk)) { $allMap[$mk] } else { $allDefault }
        if ($hasKids -and $lab) { $allFor[$mk] = $lab }
    }
    foreach ($ak in $allFor.Keys) { $views[$ak + "`u{1}*"] = [string[]]@($menuNodes[$ak] + '*') }

    # Where does the page open? first menu node, descending to the first node with own content
    $opens = @()
    $cur = @()
    while ($true) {
        $kids = @($menuNodes.Values | Where-Object { $_.Count -eq $cur.Count + 1 -and ($cur.Count -eq 0 -or (($_[0..($cur.Count - 1)] -join "`u{1}") -eq ($cur -join "`u{1}"))) })
        if ($kids.Count -eq 0) { break }
        $cur = $kids[0]
        if ($views.Contains(($cur -join "`u{1}"))) { break }
    }
    $opens = $cur

    $globalItems = @($items | Where-Object { $_.Path.Count -eq 0 -or $_.Scope -eq 'global' })
    foreach ($g in $globalItems | Where-Object { $_.Kind -ne 'banner' }) {
        $warnings.Add("$($g.Kind) '$($g.Id)' has no menu path or is global: it appears on EVERY view.")
    }

    $viewList = foreach ($k in $views.Keys) {
        $sel = [string[]]$views[$k]
        $visible = @($items | Where-Object { Test-Match -Declared $_.Path -Scope $_.Scope -Selected $sel })
        # exporter order: banners, then blocks, then tables (each in declaration order, which is file order)
        $ordered = @($visible | Where-Object Kind -eq 'banner') + @($visible | Where-Object Kind -eq 'block') + @($visible | Where-Object Kind -eq 'table')
        $own = @($ordered | Where-Object { $_.Kind -ne 'banner' -and $_.Path.Count -gt 0 -and $_.Scope -ne 'global' })
        if ($own.Count -eq 0) { $warnings.Add("View '$($sel -join ' / ')' shows nothing of its own.") }
        [pscustomobject]@{ Path = $sel; Items = $ordered }
    }

    $res = [pscustomobject]@{
        File = $file.Name; Opens = $opens; Views = @($viewList)
        Global = [pscustomobject]@{ Summary = @($summary).Count; Filters = @($gfilters).Count; Banners = @($globalItems | Where-Object Kind -eq 'banner').Count }
        Warnings = @($warnings)
    }

    Write-Host ''
    Write-Host ("{0}" -f $file.Name) -ForegroundColor Cyan
    if (-not $Quiet) {
        Write-Host ("  opens on : {0}" -f ($opens -join ' / '))
        Write-Host ("  global   : {0} KPI tile(s), {1} global filter(s), {2} banner(s) shown on every view" -f $res.Global.Summary, $res.Global.Filters, $res.Global.Banners)
        Write-Host '  menu     :'
        foreach ($n in $menuNodes.Values) {
            $indent = '    ' + ('  ' * ($n.Count - 1))
            $tag = if ($views.Contains(($n -join "`u{1}"))) { '' } else { '  (group)' }
            $lab = $nodeLabel[($n -join "`u{1}")]; $shown = if ($lab -and $lab -cne $n[-1]) { "$lab   [key: $($n[-1])]" } else { $n[-1] }
            Write-Host ("{0}{1}{2}" -f $indent, $shown, $tag)
            $nk = ($n -join "`u{1}")
            if ($allFor.ContainsKey($nk)) { Write-Host ("{0}  {1}   [All view: shows this group and everything below]" -f $indent, $allFor[$nk]) }
        }
        foreach ($v in $viewList) {
            Write-Host ''
            Write-Host ("  view: {0}" -f ($v.Path -join ' / ')) -ForegroundColor Yellow
            $i = 0
            foreach ($it in $v.Items) {
                $i++
                $reach = if ($it.Path.Count -eq 0 -or $it.Scope -eq 'global') { 'everywhere' } elseif ($it.Scope -eq 'subtree') { "subtree of $($it.Path -join '/')" } else { 'this view' }
                $t = if ($it.Title.Length -gt 46) { $it.Title.Substring(0, 45) + '…' } else { $it.Title }
                Write-Host ("    {0,2}. {1,-6} {2,-14} {3,-26} {4,-18} {5}" -f $i, $it.Kind, $it.Type, $it.Id, $reach, $t)
            }
        }
    } else {
        Write-Host ("  {0} view(s); opens on {1}" -f $viewList.Count, ($opens -join ' / '))
    }
    foreach ($w in $warnings) { Write-Host ("  WARNING: {0}" -f $w) -ForegroundColor Yellow }
    $res
}

if ($PassThru) { $results }
