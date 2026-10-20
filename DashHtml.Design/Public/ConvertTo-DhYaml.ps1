function ConvertTo-DhYaml {
    <#
    .SYNOPSIS
        Serialise a DashHtml report object into a readable YAML layout spec.

    .DESCRIPTION
        Takes the report object produced by New-DhDashboard (and mutated by the
        Add-Dh* cmdlets) and emits a YAML document describing the dashboard's
        structure — foundation settings, the global summary, tables, blocks,
        global filters, alert banners, and table links.

        This is the reliable "reverse" of the design round-trip: it serialises
        the ALREADY-BUILT object, so loops, computed values, and dynamic data
        are all captured faithfully — no PowerShell parsing involved.

        By default the table row data is summarised as a `dataRows: <count>` line
        to keep the output a layout view. Use -IncludeData to embed the rows.

    .PARAMETER Report
        The dashboard object from New-DhDashboard.

    .PARAMETER OutFile
        Optional path to write the YAML to. When omitted, the YAML string is
        returned.

    .PARAMETER IncludeData
        Embed each table's full row data instead of a `dataRows` count.

    .EXAMPLE
        $r = New-DhDashboard -Title 'Infra' -Theme Azure
        Add-DhTable -Report $r -TableId 'srv' -Title 'Servers' -Data $rows
        $r | ConvertTo-DhYaml -OutFile infra.yaml

    .EXAMPLE
        ConvertTo-DhYaml -Report $r        # returns the YAML as a string
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Collections.Specialized.OrderedDictionary] $Report,
        [string] $OutFile,
        [switch] $IncludeData
    )

    process {
        $model = [ordered]@{}
        $model['title'] = $Report.Title
        if ($Report.Subtitle)    { $model['subtitle'] = $Report.Subtitle }
        if ($Report.ThemeFamily) { $model['theme']    = $Report.ThemeFamily }
        if ($Report.Contains('NavTitle')       -and $Report.NavTitle)       { $model['navTitle']    = $Report.NavTitle }
        if ($Report.Contains('AutoRefreshSec') -and [int]$Report.AutoRefreshSec -gt 0) { $model['autoRefresh'] = [int]$Report.AutoRefreshSec }
        if ($Report.Contains('GeneratedBy')    -and $Report.GeneratedBy)    { $model['generatedBy'] = $Report.GeneratedBy }
        # Options added after 1.0: written only when they differ from the default, so older YAML is unchanged
        if ($Report.Contains('ThemeMode')  -and $Report.ThemeMode -and $Report.ThemeMode -ne 'light') { $model['themeMode'] = $Report.ThemeMode }
        if ($Report.Contains('PrintCover') -and $Report.PrintCover) { $model['printCover'] = $true }
        if ($Report.Contains('NavBadge')   -and $Report.NavBadge)   { $model['navBadge']   = $true }   # DashHtml 2.4.0
        if ($Report.Contains('Search')     -and $Report.Search)     { $model['search']     = $true }   # DashHtml 2.4.0
        # DashHtml 2.5.0 menu options (and NavLayout / NavMaxDepth, which were never written)
        if ($Report.Contains('NavLayout')   -and $Report.NavLayout -and $Report.NavLayout -ne 'Auto') { $model['navLayout'] = $Report.NavLayout }
        if ($Report.Contains('NavMaxDepth') -and [int]$Report.NavMaxDepth -ne 3) { $model['navMaxDepth'] = [int]$Report.NavMaxDepth }
        if ($Report.Contains('NavAllLabel') -and $null -ne $Report.NavAllLabel -and "$($Report.NavAllLabel)" -ne '') {
            $model['navAllLabel'] = if ($Report.NavAllLabel -is [System.Collections.IDictionary]) { Copy-DhSpec $Report.NavAllLabel } else { $Report.NavAllLabel }
        }
        if ($Report.Contains('NavTree') -and @($Report.NavTree).Count -gt 0) { $model['navTree'] = @($Report.NavTree | ForEach-Object { Copy-DhSpec $_ }) }
        if ($Report.Contains('StrictNav') -and $Report.StrictNav) { $model['strictNav'] = $true }
        if ($Report.Contains('NavOverflow') -and $Report.NavOverflow -and $Report.NavOverflow -ne 'More') { $model['navOverflow'] = $Report.NavOverflow }        if ($Report.Contains('InfoFields') -and @($Report.InfoFields).Count -gt 0) {
            $model['infoFields'] = @($Report.InfoFields | ForEach-Object { [ordered]@{ label = $_.Label; value = $_.Value } })
        }

        # Global summary (stored separately from Blocks)
        if ($Report.Contains('Summary') -and @($Report.Summary).Count -gt 0) {
            $sum = [ordered]@{ items = @($Report.Summary | ForEach-Object { Copy-DhSpec $_ }) }
            if ($Report.Contains('SummaryOptions') -and $Report.SummaryOptions) {
                foreach ($k in $Report.SummaryOptions.Keys) { $sum[$k.ToString().ToLower()] = $Report.SummaryOptions[$k] }
            }
            $model['summary'] = $sum
        }

        # Tables
        if (@($Report.Tables).Count -gt 0) {
            $model['tables'] = @($Report.Tables | ForEach-Object {
                $t = Copy-DhSpec $_ -Drop @('Data', 'Baseline')
                if ($IncludeData) { $t['data'] = @($_.Data) }
                else              { $t['dataRows'] = @($_.Data).Count }
                $t
            })
        }

        # Blocks (BlockType -> type, moved to front)
        if ($Report.Contains('Blocks') -and @($Report.Blocks).Count -gt 0) {
            $model['blocks'] = @($Report.Blocks | ForEach-Object {
                $b = Copy-DhSpec $_ -Drop @('BlockType')
                $ordered = [ordered]@{ type = $_.BlockType }
                foreach ($k in $b.Keys) { $ordered[$k] = $b[$k] }
                $ordered
            })
        }

        # Global filters / alert banners / links
        if ($Report.Contains('GlobalFilters') -and @($Report.GlobalFilters).Count -gt 0) {
            $model['globalFilters'] = @($Report.GlobalFilters | ForEach-Object { Copy-DhSpec $_ })
        }
        if ($Report.Contains('AlertBanners') -and @($Report.AlertBanners).Count -gt 0) {
            $model['alertBanners'] = @($Report.AlertBanners | ForEach-Object { Copy-DhSpec $_ })
        }
        if ($Report.Contains('Links') -and @($Report.Links).Count -gt 0) {
            $model['links'] = @($Report.Links | ForEach-Object { Copy-DhSpec $_ })
        }

        $yaml = "# DashHtml layout — generated by ConvertTo-DhYaml`n" + (ConvertTo-DhYamlText $model)

        if ($OutFile) {
            Set-Content -Path $OutFile -Value $yaml -Encoding UTF8
            Write-Verbose "ConvertTo-DhYaml: wrote $OutFile"
        } else {
            $yaml
        }
    }
}

function Copy-DhSpec {
    <# Shallow-clone a spec hashtable, dropping named keys and empty values. #>
    param([object] $Source, [string[]] $Drop = @())
    $out = [ordered]@{}
    foreach ($k in $Source.Keys) {
        if ($k -in $Drop) { continue }
        $v = $Source[$k]
        # Trim obvious noise: empty strings and empty arrays keep the view clean.
        if ($v -is [string] -and $v -eq '') { continue }
        if (($v -is [System.Collections.IEnumerable]) -and ($v -isnot [string]) -and (@($v).Count -eq 0)) { continue }
        $out[$k] = $v
    }
    return $out
}
