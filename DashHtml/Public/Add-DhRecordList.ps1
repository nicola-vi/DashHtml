function Add-DhRecordList {
    <#
    .SYNOPSIS
        Add a list of records, one row each, that expand to show their details.

    .DESCRIPTION
        v2.3.0. For "one thing per row, with a lot to say about each": the hardware of
        every domain controller, the settings of every GPO, the state of every backup
        job. A row shows a status dot, a title, a sub line and up to four headline
        metrics; clicking it opens the body, which is made of sections: label/value
        tiles, small tables, bars, status lists, check lists, text and links (the same
        sections as the detail drawer and Add-DhKeyValue).

        A filter box searches every row (title, sub line, metrics and the text in the
        sections). Expand all / Collapse all are above the list. Printed, every record
        is shown expanded.

        All text is HTML-encoded (there is no -AllowHtml).

    .PARAMETER Report   Dashboard object from New-DhDashboard.
    .PARAMETER Id       Unique block identifier (alphanumeric, - or _).
    .PARAMETER Title    Block heading.

    .PARAMETER Items
        Array of hashtables:
          @{
              Title    = 'vit00-dc01'                      # REQUIRED
              Subtitle = 'corp.example - FIT00'            # optional
              Status   = 'ok'                              # optional: ok | warn | danger | info | nodata
              Metrics  = @(@{ Label='RAM'; Value='8 GB' }, @{ Label='CPU'; Value='2%'; Status='ok' })  # max 4
              Sections = @(                                # optional; see ConvertTo-DhSections
                  @{ Kind='kv'; Title='System'; Items=@(@{ Label='Model'; Value='VMware20,1' }) }
                  @{ Kind='table'; Title='Volumes'; Columns=@('Drive','Free'); Rows=@(,@('C:','73 GB')) }
              )
              Id       = 'dc01'                            # optional stable id (default r1, r2, ...)
          }
        Section kinds: kv, bars, statusList, checks, table, text, links.

    .PARAMETER Filterable  Text filter box (default $true).
    .PARAMETER OpenAll     Start with every record expanded.
    .PARAMETER MaxItems    Upper limit on the number of records (default 500). More is a
                           warning, not an error: the page works but grows with every record.

    .EXAMPLE
        Add-DhRecordList -Report $r -Id 'dcs' -Title 'Hardware and performance' -NavPath 'Hardware' -Items @(
            @{ Title='vit00-dc01'; Subtitle='corp.example - FIT00'; Status='ok'
               Metrics=@(@{ Label='RAM'; Value='8 GB' }, @{ Label='Cores'; Value='4' }, @{ Label='CPU'; Value='2%' })
               Sections=@(
                   @{ Kind='kv'; Title='System'; Items=@(@{ Label='Manufacturer'; Value='VMware, Inc.' }) }
                   @{ Kind='table'; Title='Logical volumes'; Columns=@('Drive','Size','Free'); Rows=@(,@('C:','99 GB','73 GB')) }) }
        )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string]   $Id,
        [string]   $Title = 'Records',
        [Parameter(Mandatory)] [object[]] $Items,
        [bool]     $Filterable = $true,
        [switch]   $OpenAll,
        [ValidateRange(1, 100000)]
        [int]      $MaxItems = 500,
        [bool]     $Collapsible = $true,
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
                    -ItemKind 'Block' -Context 'Add-DhRecordList'
    if (-not $Report.Contains('_DhNavSeq')) { $Report['_DhNavSeq'] = 0 }
    $navSeqNo = [int]$Report['_DhNavSeq']; $Report['_DhNavSeq'] = $navSeqNo + 1

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhRecordList: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }
    if (@($Items).Count -eq 0) { throw "Add-DhRecordList '$Id': -Items is empty." }
    if (@($Items).Count -gt $MaxItems) {
        Write-Warning "Add-DhRecordList '$Id': $(@($Items).Count) records exceeds -MaxItems ($MaxItems). Every record is built into the page, so it grows with each one; consider a table with -DetailDrawer instead."
    }

    $seenIds = @{}
    $n = 0
    $norm = foreach ($it in $Items) {
        $n++
        if ($it -isnot [System.Collections.IDictionary]) {
            throw "Add-DhRecordList '$Id': record #$n must be a hashtable. Got: $($it.GetType().Name)"
        }
        if (-not $it.Contains('Title') -or [string]::IsNullOrWhiteSpace([string]$it['Title'])) {
            throw "Add-DhRecordList '$Id': record #$n has no Title."
        }
        $ctx = "Add-DhRecordList '$Id' record '$($it['Title'])'"
        $rid = if ($it.Contains('Id') -and -not [string]::IsNullOrWhiteSpace([string]$it['Id'])) { [string]$it['Id'] } else { "r$n" }
        if ($rid -notmatch '^[A-Za-z0-9_-]+$') { throw "${ctx}: Id must be alphanumeric, - or _. Got: '$rid'" }
        if ($seenIds.ContainsKey($rid)) { throw "${ctx}: duplicate record Id '$rid'." }
        $seenIds[$rid] = $true

        $metrics = @(foreach ($m in @($(if ($it.Contains('Metrics')) { $it['Metrics'] } else { $null }))) {
            if ($null -eq $m) { continue }
            if ($m -isnot [System.Collections.IDictionary] -or -not $m.Contains('Label')) { throw "${ctx}: each Metrics entry must be @{ Label; Value; Status }." }
            [ordered]@{
                Label  = [string]$m['Label']
                Value  = if ($m.Contains('Value') -and $null -ne $m['Value']) { [string]$m['Value'] } else { '' }
                Status = ConvertTo-DhStatusName $(if ($m.Contains('Status')) { $m['Status'] } else { $null })
            }
        })
        if ($metrics.Count -gt 4) { throw "${ctx}: at most 4 Metrics are shown in the row. Got $($metrics.Count); put the rest in a kv section." }

        $sections = ConvertTo-DhSections -Context $ctx -Sections @($(if ($it.Contains('Sections')) { $it['Sections'] } else { $null }))

        [ordered]@{
            Id       = $rid
            Title    = [string]$it['Title']
            Subtitle = if ($it.Contains('Subtitle') -and $null -ne $it['Subtitle']) { [string]$it['Subtitle'] } else { '' }
            Status   = ConvertTo-DhStatusName $(if ($it.Contains('Status')) { $it['Status'] } else { $null })
            Metrics  = $metrics
            Sections = $sections
        }
    }

    $Report.Blocks.Add([ordered]@{
        BlockType   = 'recordlist'
        Id          = $Id
        Title       = $Title
        Items       = @($norm)
        Filterable  = $Filterable
        OpenAll     = [bool]$OpenAll
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
    Write-Verbose "Add-DhRecordList: '$Id' ($(@($norm).Count) record(s))."
}
