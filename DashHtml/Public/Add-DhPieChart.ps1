function Add-DhPieChart {
    <#
    .SYNOPSIS
        Add a standalone pie or donut chart block to the dashboard.

    .DESCRIPTION
        Renders a pie / donut chart as a top-level block in the dashboard flow.
        Two data modes:

          Mode A — derive from a registered table:
            -TableId / -Field [ -TopN ] [ -ClickFilters ]
            Counts distinct values of the field across the table's rows.
            With -ClickFilters, clicking a slice applies the slice label as a
            text filter on the source table.

          Mode B — explicit slices:
            -Slices @( @{ Label='...'; Value=...; Color='...' } ... )
            Values are taken as-is. Use this for non-tabular data such as
            cost breakdowns or weighted distributions.

        The 'donut' style (default) leaves a hole in the centre and prints
        the total value there. 'pie' renders a solid disc.

        Per the IT-infrastructure KPI dashboard specification:
        "Avoid Pie Charts for more than 5 segments — use a horizontal bar
        chart instead." Use -TopN to cap segments or switch to Add-DhBarChart.

    .PARAMETER Report
        Dashboard object from New-DhDashboard.

    .PARAMETER Id
        Unique identifier (alphanumeric, dash, underscore).

    .PARAMETER Title
        Chart heading shown above the SVG.

    .PARAMETER Style
        'donut' (default) leaves a hole in the centre for the total.
        'pie' renders a solid disc with no hole.

    .PARAMETER TableId
        (Mode A) Id of a registered table to aggregate from. Must already be
        added via Add-DhTable before this cmdlet is called.

    .PARAMETER Field
        (Mode A) Field name on the source table. The chart counts distinct
        values of this field.

    .PARAMETER TopN
        (Mode A) Maximum number of segments to show. Slices beyond TopN are
        discarded (no 'Other' bucket — keep the chart honest). Default 10.

    .PARAMETER ClickFilters
        (Mode A) When set, clicking a slice applies the slice label as a text
        filter on the source table.

    .PARAMETER Slices
        (Mode B) Array of slice definitions:
          @{
              Label = 'us-east'    # REQUIRED
              Value = 12500        # REQUIRED — numeric
              Color = '#0088BB'    # optional — defaults to the chart palette
          }

    .PARAMETER ShowTotal
        Show the total value in the donut hole. Default $true.
        Ignored when -Style is 'pie'.

    .PARAMETER ShowLegend
        Show the legend with label / count / percentage rows. Default $true.

    .PARAMETER NavGroup
        Primary nav group label (enables two-tier nav).

    .PARAMETER NavSubGroup
        Optional second-level group under NavGroup (enables three-tier nav).

    .EXAMPLE
        # Mode A — derive from a table column
        Add-DhPieChart -Report $report -Id 'status-pie' -Title 'Items by status' `
            -TableId 'items' -Field 'Status' -ClickFilters

    .EXAMPLE
        # Mode B — explicit slices (e.g. cost by region)
        Add-DhPieChart -Report $report -Id 'cost-pie' -Title 'Monthly cost by region' `
            -Style 'donut' `
            -Slices @(
                @{ Label='us-east'; Value=12500 }
                @{ Label='eu-west'; Value=8200  }
                @{ Label='ap-south'; Value=3400 }
            )

    .EXAMPLE
        # Pie style, no donut hole, custom colours
        Add-DhPieChart -Report $report -Id 'license-pie' -Title 'License usage' `
            -Style 'pie' -ShowLegend $false `
            -Slices @(
                @{ Label='Used';      Value=820; Color='#1B6B35' }
                @{ Label='Available'; Value=180; Color='#8B5200' }
            )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string] $Id,
        [Parameter(Mandatory)] [string] $Title,

        [ValidateSet('pie','donut')]
        [string] $Style = 'donut',

        # Mode A — derive from a registered table
        [string]   $TableId,
        [string]   $Field,
        [ValidateRange(1, [int]::MaxValue)]
        [int]      $TopN         = 10,
        [switch]   $ClickFilters,

        # Mode B — explicit slices
        [object[]] $Slices       = @(),

        # Display
        [bool]     $ShowTotal    = $true,
        [bool]     $ShowLegend   = $true,

        # Nav
        [string]   $NavGroup     = '',
        [string]   $NavSubGroup  = ''
    )

    # ---- Mode resolution --------------------------------------------------------
    $hasTable    = -not [string]::IsNullOrWhiteSpace($TableId)
    $hasSlices   = $Slices -and $Slices.Count -gt 0

    if (-not $hasTable -and -not $hasSlices) {
        throw "Add-DhPieChart: must specify either -TableId (with -Field) to derive from a table, or -Slices for explicit data."
    }
    if ($hasTable -and $hasSlices) {
        throw "Add-DhPieChart: cannot specify both -TableId and -Slices. Choose one data mode."
    }

    # Mode A validation
    if ($hasTable) {
        if ([string]::IsNullOrWhiteSpace($Field)) {
            throw "Add-DhPieChart: -Field is required when -TableId is used."
        }
        if ($Report.Tables -and -not ($Report.Tables | Where-Object { $_.Id -eq $TableId })) {
            throw "Add-DhPieChart: Source table '$TableId' not found. Add the table before the pie chart."
        }
    }

    # Mode B normalisation
    $normSlices = @()
    if ($hasSlices) {
        foreach ($s in $Slices) {
            if ($s -isnot [hashtable] -and $s -isnot [System.Collections.Specialized.OrderedDictionary]) {
                throw "Add-DhPieChart: Each slice must be a hashtable. Got: $($s.GetType().Name)"
            }
            if (-not $s.Contains('Label') -or $null -eq $s['Label']) {
                throw "Add-DhPieChart: Each slice must have a 'Label' key."
            }
            if (-not $s.Contains('Value') -or $null -eq $s['Value']) {
                throw "Add-DhPieChart: Each slice must have a 'Value' key."
            }
            $val = 0.0
            # InvariantCulture: PowerShell [string] on a double uses period decimal,
            # so the parse must too — otherwise locales like it-IT misinterpret it.
            $okV = [double]::TryParse(
                [string]$s['Value'],
                [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [ref]$val)
            if (-not $okV) {
                throw "Add-DhPieChart: Slice '$($s.Label)' has a non-numeric Value: '$($s.Value)'."
            }
            if ($val -lt 0) {
                throw "Add-DhPieChart: Slice '$($s.Label)' has a negative Value ($val). Pie segments must be non-negative."
            }
            $normSlices += @{
                Label = [string]$s.Label
                Value = $val
                Color = if ($s.Contains('Color')) { [string]$s.Color } else { '' }
            }
        }
    }

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }

    $Report.Blocks.Add([ordered]@{
        BlockType    = 'piechart'
        Id           = $Id
        Title        = $Title
        Style        = $Style
        Mode         = if ($hasTable) { 'fromtable' } else { 'explicit' }
        TableId      = if ($hasTable) { $TableId } else { '' }
        Field        = if ($hasTable) { $Field }   else { '' }
        TopN         = $TopN
        ClickFilters = [bool]$ClickFilters
        Slices       = @($normSlices)
        ShowTotal    = $ShowTotal
        ShowLegend   = $ShowLegend
        NavGroup     = $NavGroup
        NavSubGroup  = $NavSubGroup
    })

    Write-Verbose ("Add-DhPieChart: '$Id' (style=$Style, mode=" +
        $(if ($hasTable) { "fromtable '$TableId/$Field'" } else { "$($normSlices.Count) slice(s)" }) + ').')
}
