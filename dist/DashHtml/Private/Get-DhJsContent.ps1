function Get-DhJsContent {
    <#
    .SYNOPSIS  Returns the complete dashboard runtime JavaScript.
    .DESCRIPTION
        The runtime is authored across several Get-DhJs*.ps1 fragment files
        (Core / Blocks / Nav / Table / Print / Boot) purely for maintainability; they
        are concatenated here into a single script injected into one <script>
        block by Export-DhDashboard. The split points are top-level function
        boundaries, so the assembled output is a single shared scope exactly as
        before — the fragments are NOT independent modules.
        Placeholders (/*%%TABLES_CONFIG%%*/ etc.) are still substituted by
        Export-DhDashboard after assembly.
    #>
    return @(
        Get-DhJsCore
        Get-DhJsBlocks
        Get-DhJsDrawer     # v2.3.0
        Get-DhJsNav
        Get-DhJsTable
        Get-DhJsTree       # v2.4.0
        Get-DhJsTreeTable  # v2.5.0
        Get-DhJsNetwork    # v2.4.0
        Get-DhJsSearch     # v2.4.0
        Get-DhJsPrint      # v2.2.0
        Get-DhJsBoot
    ) -join "`n"
}