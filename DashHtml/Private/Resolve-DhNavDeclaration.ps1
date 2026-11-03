<#
    Nav declaration resolver — turns the nav parameters a caller supplied
    into the canonical (Path, Scope) pair the exporter and runtime consume.

    Every nav-aware cmdlet calls this exactly once. Keeping the mapping here
    rather than repeating it across the cmdlets is deliberate: the 1.x bug the
    2.0.0 nav model fixed (readme-dev gotcha #26) was caused by the same concept
    being implemented slightly differently in several places.

    API: -NavPath 'A/B/C' + -NavScope Exact|Subtree|Global. The 1.x
    -NavGroup / -NavSubGroup compat parameters were removed in 3.0.0
    (Update-DhScript -Apply rewrites them).
#>

function Resolve-DhNavDeclaration {
    <#
    .SYNOPSIS
        Resolve nav parameters to a canonical path + scope.

    .PARAMETER NavPath
        Menu path, '/'-separated. '//' escapes a literal '/'.

    .PARAMETER NavScope
        Exact / Subtree / Global. When omitted, a sensible default is chosen
        from ItemKind (see below).

    .PARAMETER ItemKind
        'Block' or 'Table'. Drives the default when nothing is declared:
          Block : visible everywhere                     -> Global
          Table : its own menu node, keyed on TableId    -> Exact

    .PARAMETER TableId
        Required when ItemKind is 'Table'.

    .OUTPUTS
        [hashtable] @{ Path = [string[]]; Scope = [string] }
    #>
    [CmdletBinding()]
    param(
        [string] $NavPath     = '',
        [string] $NavScope    = '',
        [ValidateSet('Block','Table')]
        [string] $ItemKind    = 'Block',
        [string] $TableId     = '',
        [string] $Context     = ''
    )

    # ── Path supplied ───────────────────────────────────────────────────────
    if (-not [string]::IsNullOrWhiteSpace($NavPath)) {
        $segments = ConvertFrom-DhNavPath $NavPath
        $scope    = if ($NavScope) { $NavScope } else { 'Exact' }
        return @{ Path = @($segments); Scope = $scope }
    }

    # ── Nothing supplied ────────────────────────────────────────────────────
    if ($NavScope) { return @{ Path = @(); Scope = $NavScope } }

    if ($ItemKind -eq 'Table') {
        # An ungrouped table gets its own link in the primary bar and only one
        # shows at a time: a single-segment path keyed on TableId (the only
        # value Add-DhTable enforces as unique). Without this a plain report
        # would render every table stacked at once.
        if ([string]::IsNullOrWhiteSpace($TableId)) {
            throw 'Resolve-DhNavDeclaration: ItemKind Table requires -TableId.'
        }
        return @{ Path = @($TableId); Scope = 'Exact' }
    }

    # An ungrouped BLOCK is visible on every panel.
    return @{ Path = @(); Scope = 'Global' }
}
