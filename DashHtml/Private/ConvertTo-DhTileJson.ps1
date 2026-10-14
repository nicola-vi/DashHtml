function ConvertTo-DhTileJson {
    <#
    .SYNOPSIS  Serialise one normalised summary tile (from Add-DhSummary) to JSON.

    .DESCRIPTION
        v2.2.0 - single source for the tile JSON. Until 2.2.0 Export-DhDashboard
        carried two hand-synchronised copies of this code: one for the
        top-of-page strip and one for per-panel 'summarystrip' blocks. Add a
        tile key HERE and both paths get it.

        Optional groups (delta, sparkline, caption, gauge fields, verdict,
        action) are emitted only when they apply, so a plain tile stays small.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [System.Collections.IDictionary] $Item)

    $s = $Item
    $val = if ($null -eq $s.Value) { 'null' } `
           elseif ($s.Value -is [bool])    { $s.Value.ToString().ToLower() } `
           elseif ($s.Value -is [int] -or $s.Value -is [long] -or $s.Value -is [double] -or $s.Value -is [float] -or $s.Value -is [decimal]) { [string]$s.Value } `
           else { ConvertTo-DhJsonString ([string]$s.Value) }
    $dec = if ($s.Contains('Decimals') -and $s.Decimals -ge 0) { $s.Decimals } else { -1 }

    # Trend / delta (v1.4 F1) - only when Previous or an explicit Trend is supplied
    $deltaJson = ''
    $hasPrev   = $s.Contains('Previous') -and $null -ne $s.Previous
    $hasTrend  = $s.Contains('Trend')    -and $s.Trend -ne 'auto'
    if ($hasPrev -or $hasTrend) {
        $prevJson = if ($hasPrev) { [string]$s.Previous } else { 'null' }
        $trendStr = if ($s.Contains('Trend') -and $s.Trend) { [string]$s.Trend } else { 'auto' }
        $tigJson  = if ($null -ne $s.TrendIsGood) { ([bool]$s.TrendIsGood).ToString().ToLower() } else { 'null' }
        $dfStr    = if ($s.Contains('DeltaFormat') -and $s.DeltaFormat) { [string]$s.DeltaFormat } else { 'both' }
        $deltaJson = ",`"previous`":$prevJson,`"trend`":$(ConvertTo-DhJsonString $trendStr),`"trendIsGood`":$tigJson,`"deltaFormat`":$(ConvertTo-DhJsonString $dfStr)"
    }

    # Sparkline (v1.4 F2) - only when the series is non-empty
    $sparkJson = ''
    if ($s.Contains('Sparkline') -and $s.Sparkline -and @($s.Sparkline).Count -gt 0) {
        $sparkValues  = ((@($s.Sparkline) | ForEach-Object { [string]$_ }) -join ',')
        $sparkMinJson = if ($null -ne $s.SparklineMin) { [string]$s.SparklineMin } else { 'null' }
        $sparkMaxJson = if ($null -ne $s.SparklineMax) { [string]$s.SparklineMax } else { 'null' }
        $sparkStyle   = if ($s.Contains('SparklineStyle') -and $s.SparklineStyle) { [string]$s.SparklineStyle } else { 'line' }
        $sparkJson = ",`"sparkline`":[$sparkValues],`"sparklineMin`":$sparkMinJson,`"sparklineMax`":$sparkMaxJson,`"sparklineStyle`":$(ConvertTo-DhJsonString $sparkStyle)"
    }

    # Tile style (v1.4 F3 + F4) - always emitted; 'tile' is the standard renderer
    $styleStr  = if ($s.Contains('Style') -and $s.Style) { [string]$s.Style } else { 'tile' }
    $styleJson = ",`"style`":$(ConvertTo-DhJsonString $styleStr)"

    # Caption: bignumber (v1.4) and verdict (v2.2.0)
    $captionJson = ''
    if ($styleStr -in 'bignumber', 'verdict' -and $s.Contains('Caption') -and -not [string]::IsNullOrWhiteSpace([string]$s.Caption)) {
        $captionJson = ",`"caption`":$(ConvertTo-DhJsonString $s.Caption)"
    }

    # Gauge fields
    $gaugeJson = ''
    if ($styleStr -eq 'gauge') {
        $minJson = if ($null -ne $s.Min) { [string]$s.Min } else { '0' }
        $maxJson = if ($null -ne $s.Max) { [string]$s.Max } else { '100' }
        $unitStr = if ($s.Contains('Unit') -and $s.Unit) { [string]$s.Unit } else { '' }
        if ($s.Contains('Thresholds') -and @($s.Thresholds).Count -gt 0) {
            $thItems = (@($s.Thresholds) | ForEach-Object {
                $th = $_
                $minPart = if ($th.Contains('Min')) { "`"min`":$([string]$th.Min)," } else { '' }
                $maxPart = if ($th.Contains('Max')) { "`"max`":$([string]$th.Max)," } else { '' }
                "{$minPart$maxPart`"class`":$(ConvertTo-DhJsonString $th.Class)}"
            }) -join ','
            $thJson = ",`"thresholds`":[$thItems]"
        } else {
            $thJson = ',"thresholds":[]'
        }
        # ragNoData (v1.4 F13) - the gauge paints itself cell-nodata on a missing value
        $rndJson = if ($s.Contains('RagNoData') -and $s.RagNoData) { ',"ragNoData":true' } else { '' }
        $gaugeJson = ",`"min`":$minJson,`"max`":$maxJson,`"unit`":$(ConvertTo-DhJsonString $unitStr)$thJson$rndJson"
    }

    # Verdict severity counts (v2.2.0) - fixed key order, zero counts omitted
    $verdictJson = ''
    if ($styleStr -eq 'verdict' -and $s.Contains('Counts') -and $s.Counts) {
        $parts = foreach ($k in 'critical', 'warning', 'info', 'ok') {
            if ($s.Counts.Contains($k) -and [int]$s.Counts[$k] -gt 0) { "`"$k`":$([int]$s.Counts[$k])" }
        }
        $verdictJson = ",`"counts`":{$(@($parts) -join ',')}"
    }

    # Per-tile Action (v1.4.2 - click-to-jump)
    $actionJson = ''
    if ($s.Contains('Action') -and $null -ne $s.Action) {
        $a = $s.Action
        $actionJson = ",`"action`":{`"label`":$(ConvertTo-DhJsonString $a.Label),`"tableId`":$(ConvertTo-DhJsonString $a.TableId),`"filter`":$(ConvertTo-DhJsonString $a.Filter),`"url`":$(ConvertTo-DhJsonString $a.Url)}"
    }

    "{`"label`":$(ConvertTo-DhJsonString $s.Label),`"value`":$val,`"icon`":$(ConvertTo-DhJsonString $s.Icon),`"subLabel`":$(ConvertTo-DhJsonString $s.SubLabel),`"class`":$(ConvertTo-DhJsonString $s.Class),`"format`":$(ConvertTo-DhJsonString $s.Format),`"locale`":$(ConvertTo-DhJsonString $s.Locale),`"decimals`":$dec,`"currency`":$(ConvertTo-DhJsonString $s.Currency)$styleJson$captionJson$gaugeJson$verdictJson$deltaJson$sparkJson$actionJson}"
}
