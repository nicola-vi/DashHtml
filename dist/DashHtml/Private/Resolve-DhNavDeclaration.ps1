<#
    Nav declaration resolver — turns whatever nav parameters a caller supplied
    into the canonical (Path, Scope) pair the exporter and runtime consume.

    Every nav-aware cmdlet calls this exactly once. Keeping the mapping here
    rather than repeating it across 16 cmdlets is deliberate: the 1.x bug this
    release exists to fix (readme-dev gotcha #26) was caused by the same concept
    being implemented slightly differently in several places.

    v2.0.0 API      : -NavPath 'A/B/C' + -NavScope Exact|Subtree|Global
    v1.x compat API : -NavGroup / -NavSubGroup  (kept indefinitely)
#>

function Resolve-DhNavDeclaration {
    <#
    .SYNOPSIS
        Resolve nav parameters to a canonical path + scope.

    .PARAMETER NavPath
        v2 path, '/'-separated. '//' escapes a literal '/'.

    .PARAMETER NavScope
        Exact / Subtree / Global. When omitted, a sensible default is chosen
        from ItemKind (see below).

    .PARAMETER NavGroup
        v1.x compat: primary group label.

    .PARAMETER NavSubGroup
        v1.x compat: second-level label under NavGroup.

    .PARAMETER ItemKind
        'Block' or 'Table'. Drives the compat defaults, because 1.x meant
        different things by "no subgroup" for the two:
          Block : content shown across the whole group   -> Subtree
          Table : one specific view                      -> Exact
        In 2.0.0 a table is a node like any other, so the compat shim appends
        its TableId as a leaf segment to preserve its own menu entry.

    .PARAMETER TableId
        Required when ItemKind is 'Table' and the compat API is used.

    .OUTPUTS
        [hashtable] @{ Path = [string[]]; Scope = [string] }

    .NOTES
        Supplying BOTH -NavPath and -NavGroup/-NavSubGroup is a hard error.
        Silent precedence between two ways of saying the same thing is exactly
        how the 1.x nav became three competing mechanisms.
    #>
    [CmdletBinding()]
    param(
        [string] $NavPath     = '',
        [string] $NavScope    = '',
        [string] $NavGroup    = '',
        [string] $NavSubGroup = '',
        [ValidateSet('Block','Table')]
        [string] $ItemKind    = 'Block',
        [string] $TableId     = '',
        [string] $Context     = ''
    )

    $hasV2 = -not [string]::IsNullOrWhiteSpace($NavPath)
    $hasV1 = (-not [string]::IsNullOrWhiteSpace($NavGroup)) -or
             (-not [string]::IsNullOrWhiteSpace($NavSubGroup))

    if ($hasV2 -and $hasV1) {
        $where = if ($Context) { "$Context : " } else { '' }
        throw ("${where}-NavPath cannot be combined with -NavGroup / -NavSubGroup. " +
               "Use -NavPath '$NavGroup$(if($NavSubGroup){"/$NavSubGroup"})' on its own, " +
               "or keep the v1 parameters. See readme-dev.md section 15.")
    }

    if ((-not [string]::IsNullOrWhiteSpace($NavSubGroup)) -and [string]::IsNullOrWhiteSpace($NavGroup)) {
        $where = if ($Context) { "$Context : " } else { '' }
        throw "${where}-NavSubGroup requires -NavGroup. A subgroup with no parent has no place in the menu."
    }

    # ── v2 path supplied ────────────────────────────────────────────────────
    if ($hasV2) {
        $segments = ConvertFrom-DhNavPath $NavPath
        $scope    = if ($NavScope) { $NavScope } else { 'Exact' }
        return @{ Path = @($segments); Scope = $scope }
    }

    # ── v1 compat ───────────────────────────────────────────────────────────
    if ($hasV1) {
        $segments = [System.Collections.Generic.List[string]]::new()
        [void]$segments.Add($NavGroup.Trim())
        if (-not [string]::IsNullOrWhiteSpace($NavSubGroup)) { [void]$segments.Add($NavSubGroup.Trim()) }

        if ($ItemKind -eq 'Table') {
            # 1.x gave every grouped table its own subnav link. Preserve that by
            # appending the TableId as a leaf, keyed on TableId (the only value
            # Add-DhTable enforces as unique) rather than the free-form Title.
            if ([string]::IsNullOrWhiteSpace($TableId)) {
                throw 'Resolve-DhNavDeclaration: ItemKind Table requires -TableId.'
            }
            [void]$segments.Add($TableId)
            $scope = if ($NavScope) { $NavScope } else { 'Exact' }
        }
        else {
            # 1.x blocks were visible across their whole group.
            $scope = if ($NavScope) { $NavScope } else { 'Subtree' }
        }
        return @{ Path = @($segments); Scope = $scope }
    }

    # ── Nothing supplied ────────────────────────────────────────────────────
    if ($NavScope) { return @{ Path = @(); Scope = $NavScope } }

    if ($ItemKind -eq 'Table') {
        # 1.x flat nav: an ungrouped table got its own link in the primary bar
        # and only one showed at a time. Giving it a single-segment path keyed on
        # TableId reproduces that exactly under the uniform model. Without this a
        # plain report would render every table stacked at once - a regression in
        # the commonest case of all.
        if ([string]::IsNullOrWhiteSpace($TableId)) {
            throw 'Resolve-DhNavDeclaration: ItemKind Table requires -TableId.'
        }
        return @{ Path = @($TableId); Scope = 'Exact' }
    }

    # 1.x: an ungrouped BLOCK was visible on every panel.
    return @{ Path = @(); Scope = 'Global' }
}
