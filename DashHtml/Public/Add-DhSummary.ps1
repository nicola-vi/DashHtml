function Add-DhSummary {
    <#
    .SYNOPSIS
        Add a row of KPI metric tiles at the top of the dashboard body.

    .DESCRIPTION
        Renders a horizontal strip of summary cards. Each tile shows an optional
        icon, a formatted value, a label, and an optional sub-label. Tiles can
        be coloured with the same threshold classes used on table cells.

    .PARAMETER Report   Dashboard object from New-DhDashboard.

    .PARAMETER Items
        Array of tile definition hashtables:
          @{
              Label    = 'Caption text'    # REQUIRED
              Value    = 42               # REQUIRED — the main metric
              Icon     = 'X'              # optional emoji / unicode
              SubLabel = 'of 100 total'   # optional small text below label
              Class    = 'cell-danger'    # optional: cell-ok | cell-warn | cell-danger
              Format   = 'number'         # optional: same as column Format values
              Locale   = 'en-US'          # optional BCP-47 locale
              Decimals = 0                # optional decimal places
              Currency = 'USD'            # optional: for Format='currency'
          }

    .EXAMPLE
        Add-DhSummary -Report $report -Items @(
            @{ Label='Total Items';   Value=247;         Icon='X' }
            @{ Label='Active';        Value=231;         Icon='Y'; Class='cell-ok'     }
            @{ Label='Warnings';      Value=12;          Icon='W'; Class='cell-warn'   }
            @{ Label='Critical';      Value=4;           Icon='E'; Class='cell-danger' }
            @{ Label='Monthly Cost';  Value=12450.75;
               Format='currency'; Locale='en-US'; Currency='USD'; Decimals=2 }
            @{ Label='Total Storage'; Value=1610612736;  Format='bytes' }
            @{ Label='Avg Uptime';    Value=99.87;
               Format='percent'; Locale='en-US'; Decimals=2 }
        )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)] [object[]]  $Items
    )

    $replacing = $Report.Contains('Summary')

    $normItems = foreach ($item in $Items) {
        if ($item -isnot [hashtable] -and $item -isnot [System.Collections.Specialized.OrderedDictionary]) {
            throw "Add-DhSummary: Each item must be a hashtable. Got: $($item.GetType().Name)"
        }
        if (-not $item.Contains('Label') -or $null -eq $item['Label']) {
            throw "Add-DhSummary: Each item must have a 'Label' key."
        }
        if (-not $item.Contains('Value')) {
            throw "Add-DhSummary: Each item must have a 'Value' key."
        }
        $t = @{} + $item
        if (-not $t.Contains('Icon'))     { $t['Icon']     = '' }
        if (-not $t.Contains('SubLabel')) { $t['SubLabel'] = '' }
        if (-not $t.Contains('Class'))    { $t['Class']    = '' }
        if (-not $t.Contains('Format'))   { $t['Format']   = '' }
        if (-not $t.Contains('Locale'))   { $t['Locale']   = '' }
        if (-not $t.Contains('Decimals')) { $t['Decimals'] = -1 }
        if (-not $t.Contains('Currency')) { $t['Currency'] = '' }
        $t
    }

    $Report['Summary'] = @($normItems)
    if ($replacing) {
        Write-Warning "Add-DhSummary: Report already has a Summary - replacing the existing tiles."
    }
    Write-Verbose "Add-DhSummary: $(@($normItems).Count) tile(s) added."
}
