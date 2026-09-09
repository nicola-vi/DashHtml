<#
    Navigation visibility — the single source of truth.

    A section is visible for a selected path IFF Test-DhNavMatch returns $true.
    The runtime JS (Get-DhJsNav.ps1, navMatches) mirrors this exactly; a Pester
    test pins the two together, and Tests/js/nav.test.js drives the JS copy
    through the same truth table under Node.

    Why a predicate and not show/hide branches: 1.x patched visibility
    incrementally across four functions using two competing mechanisms (an
    inline style.display and the panel-active class), which is what made a
    block declared with -NavGroup + -NavSubGroup permanently unreachable
    (readme-dev gotcha #26). State here is DERIVED — recomputed whole from the
    selected path, idempotent, and independent of the route taken to get there.

    Depth-agnostic on purpose: nothing below mentions a number of levels.
#>

function ConvertFrom-DhNavPath {
    <#
    .SYNOPSIS
        Split a '/'-separated nav path into its segments.
    .DESCRIPTION
        '//' is the escape for a literal '/' inside a segment. Empty and
        whitespace-only segments are rejected — they would produce an
        unaddressable node.
        Returns an empty array for '' or $null (a page-global item).
    .EXAMPLE
        ConvertFrom-DhNavPath 'Storage/Tagging'      -> @('Storage','Tagging')
        ConvertFrom-DhNavPath 'Reports/A//B'         -> @('Reports','A/B')
    #>
    param([string] $Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return @() }

    # Protect the '//' escape, split on the remaining single '/', then restore.
    $sentinel = [char]0x1F      # unit separator: never legal in a nav label
    $guarded  = $Path -replace '//', $sentinel
    $segments = $guarded -split '/'

    $out = foreach ($s in $segments) {
        $seg = ($s -replace $sentinel, '/').Trim()
        if ([string]::IsNullOrEmpty($seg)) {
            throw "Nav path '$Path' contains an empty segment. Use '//' for a literal '/'."
        }
        $seg
    }
    return @($out)
}

function Test-DhNavMatch {
    <#
    .SYNOPSIS
        Is a section visible for the selected nav path?
    .PARAMETER DeclaredPath
        The section's own path segments (empty array = page-global item).
    .PARAMETER SelectedPath
        The path currently selected in the menu.
    .PARAMETER Scope
        Exact   — visible only on this exact view (default).
        Subtree — visible for this node and everything beneath it.
        Global  — visible everywhere, regardless of path.
    .OUTPUTS
        [bool]
    #>
    param(
        [string[]] $DeclaredPath = @(),
        [string[]] $SelectedPath = @(),
        [ValidateSet('Exact','Subtree','Global')]
        [string]   $Scope = 'Exact'
    )

    if ($Scope -eq 'Global') { return $true }

    $declared = @($DeclaredPath)
    $selected = @($SelectedPath)

    # Declared deeper than the selection can never match.
    if ($declared.Count -gt $selected.Count) { return $false }

    # Every declared segment must prefix-match the selection.
    # Case-sensitive by design: nav matching has always been case-sensitive
    # (readme-dev gotcha #10), and -StrictNav will flag case-only collisions.
    for ($i = 0; $i -lt $declared.Count; $i++) {
        if (-not [string]::Equals($declared[$i], $selected[$i], [StringComparison]::Ordinal)) {
            return $false
        }
    }

    # Prefix matched. Exact requires the depths to agree; Subtree does not.
    return ($Scope -eq 'Subtree') -or ($declared.Count -eq $selected.Count)
}
