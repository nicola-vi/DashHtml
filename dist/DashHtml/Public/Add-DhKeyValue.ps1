function Add-DhKeyValue {
    <#
    .SYNOPSIS
        Add a grid of label/value tiles (a property sheet) as one block.

    .DESCRIPTION
        v2.3.0. For the facts about one thing: manufacturer, model, BIOS, total
        RAM; the baseline a report was checked against; who ran it and when. Each
        item is a small tile with an upper-case label and a bold value. An
        optional Status colours the left edge and the value (ok, warn, danger,
        info, nodata; 'critical' and 'cell-danger' style names are accepted too).

        The same tiles appear inside the detail drawer, record lists and the
        findings split layout; this cmdlet is the stand-alone form.

        All text is HTML-encoded (there is no -AllowHtml). An empty Value shows
        a dash.

    .PARAMETER Report   Dashboard object from New-DhDashboard.
    .PARAMETER Id       Unique block identifier (alphanumeric, - or _).
    .PARAMETER Title    Optional heading. With -Collapsible it is the header text.
    .PARAMETER Items
        Array of hashtables:  @{ Label='Model'; Value='VMware20,1'; Status='ok' }
        Label is required. Status is optional ('Class' is accepted as a synonym).
    .PARAMETER Columns  Tiles per row, 1 to 6 (default 3). Phones always show 2.
    .PARAMETER Collapsible  Wrap the block in a collapsible header (default $false).
    .PARAMETER DefaultOpen  Collapsible body starts expanded (default $true).

    .EXAMPLE
        Add-DhKeyValue -Report $r -Id 'sys' -Title 'System' -NavPath 'Hardware' -Columns 2 -Items @(
            @{ Label='Manufacturer'; Value='VMware, Inc.' }
            @{ Label='Model';        Value='VMware20,1' }
            @{ Label='CPU usage';    Value='2%'; Status='ok' }
        )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string]   $Id,
        [string]   $Title = '',
        [Parameter(Mandatory)] [object[]] $Items,
        [ValidateRange(1, 6)]
        [int]      $Columns = 3,
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
                    -ItemKind 'Block' -Context 'Add-DhKeyValue'
    if (-not $Report.Contains('_DhNavSeq')) { $Report['_DhNavSeq'] = 0 }
    $navSeqNo = [int]$Report['_DhNavSeq']; $Report['_DhNavSeq'] = $navSeqNo + 1

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhKeyValue: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }
    if (@($Items).Count -eq 0) { throw "Add-DhKeyValue '$Id': -Items is empty." }

    $sections = ConvertTo-DhSections -Context "Add-DhKeyValue '$Id'" -Sections @(
        @{ Kind = 'kv'; Columns = $Columns; Items = $Items }
    )

    $Report.Blocks.Add([ordered]@{
        BlockType   = 'keyvalue'
        Id          = $Id
        Title       = $Title
        # Stored under the cmdlet's own parameter names so DashHtml.Design round-trips it;
        # the exporter rebuilds the section from these.
        Items       = @($sections[0].Items)
        Columns     = $Columns
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
    Write-Verbose "Add-DhKeyValue: '$Id' ($(@($Items).Count) item(s), $Columns column(s))."
}
