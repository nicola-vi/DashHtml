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
          CellType    = 'progressbar'     # 'text'(default) | 'progressbar' | 'badge'
          ProgressMax = 100               # denominator for progressbar

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
        Array of chart definitions: @{ Title='X'; Field='Y'; Type='pie' }

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
        [string]    $NavGroup       = ''    # primary nav group label (enables two-tier nav)
    )

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

    # Normalise charts
    $normCharts = foreach ($ch in $Charts) {
        $c = @{} + $ch
        if (-not $c.Contains('Type'))  { $c['Type']  = 'pie' }
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
    })

    Write-Verbose "Add-DhTable: '$TableId' — $(@($normData).Count) rows, $(@($normCols).Count) cols, $(@($normCharts).Count) charts."
}
