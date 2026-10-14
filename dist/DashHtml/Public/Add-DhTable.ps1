function Add-DhTable {
    <#
    .SYNOPSIS
        Add a sortable, filterable, pageable data table to a dashboard definition.

    .PARAMETER Report       Dashboard object from New-DhDashboard.
    .PARAMETER TableId      Unique identifier (alphanumeric, - or _).
    .PARAMETER Title        Display heading.
    .PARAMETER Data         Array of PSObjects or hashtables.

    .PARAMETER Columns
        Array of column definition hashtables. Auto-detected when omitted.
        Full column property reference:

          # Identity
          Field       = 'PropertyName'    # REQUIRED
          Label       = 'Header Text'     # REQUIRED
          Width       = '120px'           # optional fixed width
          Sortable    = $false            # default $true

          # Alignment
          Align       = 'right'           # 'left'(default) | 'center' | 'right'

          # Cell type
          CellType    = 'progressbar'     # 'text'(default) | 'progressbar' | 'badge' | 'sparkline' | 'link'
          ProgressMax = 100               # denominator for progressbar

          # Link cells (v2.2.0, CellType='link')
          UrlField    = 'DocUrl'          # property holding the URL (default: this column's value);
                                          #   may be a property that is not a visible column
          LinkText    = 'MS Learn'        # fixed link text (default: the cell value)
                                          # only http(s) and mailto URLs become links

          # Number / value formatting  (displayed in cell and exported)
          Format      = 'number'          # see Format values below
          Locale      = 'en-US'           # BCP-47 locale (default: browser locale)
          Decimals    = 2                 # decimal places
          Currency    = 'USD'             # for Format='currency'
          DatePattern = 'MM/dd/yyyy'      # for Format='datetime'

          # Format values:
          #   'number'   - locale number  e.g. 12342.2 + en-US -> "12,342.20"
          #   'currency' - locale currency e.g. 1234.5 + en-US + USD -> "$1,234.50"
          #   'bytes'    - auto KB/MB/GB/TB e.g. 1536000000 -> "1.43 GB"
          #   'percent'  - appends %  e.g. 0.856 -> "85.60 %"
          #   'datetime' - custom pattern e.g. "2026-03-19T14:00" -> "03/19/2026 14:00"
          #   'duration' - seconds -> "2h 14m 05s"

          # Text formatting
          Bold        = $true

          # --- PINNED FIRST COLUMN ---
          PinFirst    = $true           # stick column during horizontal scroll

          # --- COLUMN FOOTER AGGREGATE ---
          Aggregate   = 'sum'           # 'sum'|'avg'|'min'|'max'|'count' — adds footer row
          Italic      = $true
          Font        = 'mono'            # 'mono' | 'ui' | 'display'

          # Threshold colour rules - evaluated in order, first match wins
          # Numeric match: use Min / Max
          # String match:  use Value (exact, case-insensitive)
          Thresholds  = @(
              @{ Max   = 70;             Class = 'cell-ok'     }   # numeric: value < 70
              @{ Min   = 70; Max = 85;   Class = 'cell-warn'   }   # numeric: 70 <= value < 85
              @{                         Class = 'cell-danger' }   # catch-all
              # --- OR string matching ---
              @{ Value = 'Connected';    Class = 'cell-ok'     }
              @{ Value = 'Maintenance';  Class = 'cell-warn'   }
              @{ Value = 'NotResponding';Class = 'cell-danger' }
          )

          # Row highlighting
          # When $true, the matching threshold class is applied to the ENTIRE ROW
          # (not just this cell). Useful for "if status=critical, highlight whole row"
          RowHighlight = $true

    .PARAMETER Charts
        Array of chart definitions: @{ Title='X'; Field='Y'; Type='donut' }
        Type is 'donut' (the default when omitted), 'pie' (solid, from 2.1.4)
        or 'bar' (from 2.2.0). Any other Type is skipped with a warning.
        A bar chart takes the optional keys of Add-DhBarChart:
          @{ Field='Site'; Type='bar'; ValueField='DiskGB'; Aggregate='sum'; TopN=5; Unit='GB'; Decimals=0 }
        Aggregate is count (default) | sum | avg | min | max; ValueField alone
        means sum.

    .PARAMETER ExportFileName
        Custom base filename for downloaded exports (without extension).
        Default is the TableId. E.g. -ExportFileName 'servers-2026-03'
        produces servers-2026-03.csv, servers-2026-03.xlsx, servers-2026-03.pdf

    .PARAMETER PageSize     Rows per page (default 15).
    .PARAMETER Sortable     Enable column sort globally (default $true).
    .PARAMETER Filterable   Show filter input (default $true).
    .PARAMETER Pageable     Show pagination (default $true).
    .PARAMETER MultiSelect  Checkbox multi-select (default $false).
    .PARAMETER Description  Paragraph below the table title.

    .EXAMPLE
        # Basic table — columns auto-detected from object properties
        $servers = @(
            [PSCustomObject]@{ Name='srv-001'; OS='Windows Server 2022'; CPU=42; Status='OK'   }
            [PSCustomObject]@{ Name='srv-002'; OS='Windows Server 2019'; CPU=78; Status='Warn' }
        )
        Add-DhTable -Report $report -TableId 'servers' -Title 'Server Inventory' -Data $servers

    .EXAMPLE
        # Custom columns with formatting, thresholds and row highlighting
        $cols = @(
            @{ Field='Name';   Label='Server';  Width='160px'; PinFirst=$true }
            @{ Field='CPU';    Label='CPU %';   Align='right'; Format='number'; Decimals=0
               Thresholds=@(
                   @{ Max=70;          Class='cell-ok'     }
                   @{ Min=70; Max=85;  Class='cell-warn'   }
                   @{                  Class='cell-danger' }
               )
               RowHighlight=$true
            }
            @{ Field='Status'; Label='Status'
               Thresholds=@(
                   @{ Value='OK';   Class='cell-ok'     }
                   @{ Value='Warn'; Class='cell-warn'   }
                   @{ Value='Crit'; Class='cell-danger' }
               )
            }
            @{ Field='Cost'; Label='Monthly Cost'; Format='currency'; Locale='en-US'; Currency='USD'; Decimals=2 }
        )
        Add-DhTable -Report $report -TableId 'servers' -Title 'Servers' -Data $servers `
            -Columns $cols -PageSize 25 -Description 'Live CPU and cost data.'

    .EXAMPLE
        # Table in a two-tier navigation group with a pie chart
        Add-DhTable -Report $report -TableId 'vms' -Title 'Virtual Machines' -Data $vms `
            -NavGroup 'Azure' `
            -Charts @( @{ Title='VMs by Status'; Field='Status'; Type='pie' } )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string]      $TableId,
        [Parameter(Mandatory)] [string]      $Title,
        [Parameter(Mandatory)] [object[]]    $Data,
        [object[]]  $Columns     = @(),
        [object[]]  $Charts      = @(),
        [int]       $PageSize    = 15,
        [bool]      $Sortable    = $true,
        [bool]      $Filterable  = $true,
        [bool]      $Pageable    = $true,
        [switch]    $MultiSelect,
        [string]    $Description    = '',
        [string]    $ExportFileName = '',   # custom filename for CSV/XLSX/PDF download
        [bool]      $Collapsible    = $true,    # v1.5.1 — wrap the section in a collapsible header (chevron + click-to-toggle)
        [bool]      $DefaultOpen    = $true,    # v1.5.1 — whether the table body starts expanded (only used when -Collapsible is $true)
        [string]    $Icon           = '',       # v1.5.1 — optional emoji / unicode glyph shown in the collapsible header
        [ValidateRange(0,12)]
        [int]       $GridSpan       = 0,        # v1.10.0 — columns (1-12) to span in a -report-grid layout; 0 = default flow
        [string]    $NavGroup       = '',   # primary nav group label (enables two-tier nav)
        [string]    $NavSubGroup    = '',    # optional second-level group under NavGroup (enables three-tier nav)
        # ---- v2.0.0 navigation (see readme-dev.md section 15) ----
        [string] $NavPath      = '',   # 'A/B/C' - where this item lives. '//' escapes a literal '/'
        [ValidateSet('','Exact','Subtree','Global')]
        [string] $NavScope     = '',   # Exact (default) | Subtree (this node and below) | Global (everywhere)
        [string] $NavLabel     = '',   # display text for this node, decoupled from the path key
        [int]    $NavOrder     = 0     # explicit sibling ordering; 0 = declaration order
    )

    # v2.0.0 - resolve nav declaration once, in one place. Throws if -NavPath is
    # combined with -NavGroup/-NavSubGroup rather than silently preferring one.
    $navDecl = Resolve-DhNavDeclaration -NavPath $NavPath -NavScope $NavScope `
                    -NavGroup $NavGroup -NavSubGroup $NavSubGroup `
                    -ItemKind 'Table' -TableId $TableId -Context 'Add-DhTable'
    # Monotonic declaration number, shared by tables and blocks. The exporter
    # emits ALL blocks before ALL tables, so without this the menu would order
    # nodes by section type instead of by the order the author wrote them.
    if (-not $Report.Contains('_DhNavSeq')) { $Report['_DhNavSeq'] = 0 }
    $navSeqNo = [int]$Report['_DhNavSeq']; $Report['_DhNavSeq'] = $navSeqNo + 1

    if ($Report.Tables | Where-Object { $_.Id -eq $TableId }) {
        throw "Add-DhTable: A table with Id '$TableId' already exists."
    }

    if ($Data.Count -eq 0) {
        Write-Warning "Add-DhTable: '$TableId' — Data array is empty. An empty table will be rendered."
    }

    # Auto-detect columns
    if ($Columns.Count -eq 0 -and $Data.Count -gt 0) {
        $first = $Data[0]
        $Columns = if ($first -is [hashtable] -or $first -is [System.Collections.Specialized.OrderedDictionary]) {
            $first.Keys | ForEach-Object { @{ Field = $_; Label = $_ } }
        } else {
            $first.PSObject.Properties | ForEach-Object { @{ Field = $_.Name; Label = $_.Name } }
        }
    }

    # Normalise columns - apply defaults for all recognised properties
    $normCols = foreach ($col in $Columns) {
        $c = @{} + $col
        if (-not $c.Contains('Sortable'))     { $c['Sortable']     = $Sortable  }
        if (-not $c.Contains('CellType'))     { $c['CellType']     = 'text'     }
        # v1.4 F8 — explicit validation now that the set is widened to include 'sparkline'
        $ctNorm = ([string]$c['CellType']).ToLowerInvariant()
        if ($ctNorm -notin @('text','progressbar','badge','sparkline','link')) {
            throw "Add-DhTable: column '$($c.Field)' — CellType must be 'text', 'progressbar', 'badge', 'sparkline' or 'link'. Got: $($c['CellType'])"
        }
        $c['CellType'] = $ctNorm

        # v2.2.0 — link cells. UrlField names the property holding the URL
        # (default: this column's own value); LinkText is fixed link text
        # (default: the cell value). Only http(s) and mailto URLs become links,
        # checked in the browser; anything else renders as plain text.
        if ($ctNorm -eq 'link') {
            $c['UrlField'] = if ($c.Contains('UrlField') -and -not [string]::IsNullOrWhiteSpace([string]$c['UrlField'])) { [string]$c['UrlField'] } else { [string]$c.Field }
            $c['LinkText'] = if ($c.Contains('LinkText')) { [string]$c['LinkText'] } else { '' }
        }

        # v1.4 F8 — sparkline-specific column keys
        # SortBy: how to reduce an array of values to a comparable scalar
        if (-not $c.Contains('SortBy') -or [string]::IsNullOrWhiteSpace([string]$c['SortBy'])) {
            $c['SortBy'] = 'last'
        } else {
            $sb = ([string]$c['SortBy']).ToLowerInvariant()
            if ($sb -notin @('last','avg','max','min','sum')) {
                throw "Add-DhTable: column '$($c.Field)' — SortBy must be 'last', 'avg', 'max', 'min', or 'sum'. Got: $($c['SortBy'])"
            }
            $c['SortBy'] = $sb
        }
        # SparklineStyle: same options as the tile sparkline
        if (-not $c.Contains('SparklineStyle') -or [string]::IsNullOrWhiteSpace([string]$c['SparklineStyle'])) {
            $c['SparklineStyle'] = 'line'
        } else {
            $sps = ([string]$c['SparklineStyle']).ToLowerInvariant()
            if ($sps -notin @('line','area','bars')) {
                throw "Add-DhTable: column '$($c.Field)' — SparklineStyle must be 'line', 'area', or 'bars'. Got: $($c['SparklineStyle'])"
            }
            $c['SparklineStyle'] = $sps
        }

        if (-not $c.Contains('ProgressMax'))  { $c['ProgressMax']  = 100        }
        if (-not $c.Contains('Bold'))         { $c['Bold']         = $false     }
        if (-not $c.Contains('Italic'))       { $c['Italic']       = $false     }
        if (-not $c.Contains('Font'))         { $c['Font']         = ''         }
        if (-not $c.Contains('Align'))        { $c['Align']        = 'left'     }
        if (-not $c.Contains('Format'))       { $c['Format']       = ''         }
        if (-not $c.Contains('Locale'))       { $c['Locale']       = ''         }
        if (-not $c.Contains('Decimals'))     { $c['Decimals']     = -1         }  # -1 = not set
        if (-not $c.Contains('Currency'))     { $c['Currency']     = ''         }
        if (-not $c.Contains('DatePattern'))  { $c['DatePattern']  = ''         }
        if (-not $c.Contains('RowHighlight')) { $c['RowHighlight'] = $false     }
        if (-not $c.Contains('PinFirst'))     { $c['PinFirst']     = $false     }
        if (-not $c.Contains('Aggregate'))    { $c['Aggregate']    = ''         }  # sum|avg|min|max|count

        # ---- Unified Rag → Thresholds (v1.4 F13) ----
        # Same semantics as Add-DhSummary: -Rag wins over a legacy Thresholds=
        # array on the column. Converts to the existing Min/Max/Class shape so
        # downstream JSON + JS matcher stay unchanged. RagNoData flag tells the
        # renderer to colour null/missing cells with cell-nodata.
        $c['RagNoData'] = $false
        if ($c.Contains('Rag') -and $null -ne $c['Rag']) {
            $rag = ConvertTo-DhRagThresholds -Rag $c['Rag'] -Context "Add-DhTable column '$($c.Field)'"
            $c['Thresholds'] = $rag.Thresholds
            $c['RagNoData']  = $rag.NoData
            $c.Remove('Rag')
        }

        if (-not $c.Contains('Thresholds'))   { $c['Thresholds']   = @()       }
        $c
    }

    # Normalise data rows
    $normData = foreach ($row in $Data) {
        $h = [ordered]@{}
        if ($row -is [hashtable] -or $row -is [System.Collections.Specialized.OrderedDictionary]) {
            foreach ($k in $row.Keys) { $h[$k] = $row[$k] }
        } else {
            foreach ($p in $row.PSObject.Properties) { $h[$p.Name] = $p.Value }
        }
        $h
    }

    # v2.2.0 — a link column's UrlField must exist in the data (case-sensitive,
    # as the browser reads it). Checked only when there is data to check.
    if (@($normData).Count -gt 0) {
        $dataFields = Get-DhTableFieldNames -Table @{ Id = $TableId; Columns = @($normCols); Data = @($normData) }
        foreach ($c in @($normCols)) {
            if ($c.CellType -eq 'link' -and $c.UrlField -cnotin $dataFields) {
                throw "Add-DhTable: column '$($c.Field)' — UrlField '$($c.UrlField)' is not a property of the data. Fields: $($dataFields -join ', ')"
            }
        }
    }

    # Normalise charts.
    # v2.1.4 - Type is validated. Before 2.1.4 the runtime rendered only 'pie'
    # (always drawn as a donut) and silently dropped anything else. A missing
    # Type still draws a donut, so existing reports look the same; an explicit
    # 'pie' now draws a solid pie. Unknown types warn and are dropped rather
    # than throwing, so a script that runs today keeps running.
    # v2.2.0 - 'bar' renders, with optional ValueField / Aggregate / TopN /
    # Unit / Decimals (same rules as Add-DhBarChart).
    $thisTable = @{ Id = $TableId; Columns = @($normCols); Data = @($normData) }
    $normCharts = foreach ($ch in $Charts) {
        $c = @{} + $ch
        $type = if ($c.Contains('Type') -and -not [string]::IsNullOrWhiteSpace([string]$c['Type'])) {
            ([string]$c['Type']).Trim().ToLowerInvariant()
        } else { 'donut' }
        if ($type -eq 'bar') {
            $aggDecl = Assert-DhBarAggregate -ValueField ([string]$c['ValueField']) -Aggregate ([string]$c['Aggregate']) `
                           -Table $thisTable -Context "Add-DhTable '$TableId' chart '$($c['Field'])'"
            $c['ValueField'] = $aggDecl.ValueField
            $c['Aggregate']  = $aggDecl.Aggregate
            $c['TopN']       = if ($c.Contains('TopN') -and [int]$c['TopN'] -ge 1) { [int]$c['TopN'] } else { 10 }
            $c['Unit']       = if ($c.Contains('Unit')) { [string]$c['Unit'] } else { '' }
            $c['Decimals']   = if ($c.Contains('Decimals') -and $null -ne $c['Decimals']) { [int]$c['Decimals'] } else { -1 }
        }
        if ($type -notin @('pie','donut','bar')) {
            Write-Warning "Add-DhTable: '$TableId' chart '$($c['Field'])' has unknown Type '$($c['Type'])' (expected pie, donut or bar). The chart is skipped."
            continue
        }
        $c['Type'] = $type
        if (-not $c.Contains('Title')) { $c['Title'] = $c['Field'] }
        $c
    }

    $Report.Tables.Add([ordered]@{
        Id          = $TableId
        Title       = $Title
        Description = $Description
        Columns     = @($normCols)
        Data        = @($normData)
        Charts      = @($normCharts)
        PageSize    = $PageSize
        Sortable    = $Sortable
        Filterable  = $Filterable
        Pageable    = $Pageable
        MultiSelect    = $MultiSelect
        ExportFileName = $ExportFileName
        NavGroup       = $NavGroup
        NavSubGroup    = $NavSubGroup
        NavPath     = $NavPath
        NavSegments     = $navDecl.Path
        NavSeqNo     = $navSeqNo
        NavScope    = $navDecl.Scope
        NavLabel    = $NavLabel
        NavOrder    = $NavOrder
        GridSpan       = $GridSpan
        Collapsible    = $Collapsible
        DefaultOpen    = $DefaultOpen
        Icon           = $Icon
    })

    Write-Verbose "Add-DhTable: '$TableId' — $(@($normData).Count) rows, $(@($normCols).Count) cols, $(@($normCharts).Count) charts."
}


