function Export-DhDashboard {
    <#
    .SYNOPSIS
        Write the self-contained HTML dashboard to disk.

    .DESCRIPTION
        Generates a single self-contained HTML file. Both the light and dark CSS
        themes are embedded directly inside the HTML — no external CSS file is
        ever written. A toggle button in the nav bar lets viewers switch themes
        at runtime.

        The HTML also embeds:
          - All table data as JSON (no server round-trips)
          - The full JavaScript table engine (sort / filter / page / link / export)
          - The logo as a Base64 data URI (if supplied to New-DhDashboard)

        External JS libraries referenced from cdnjs (internet required for export):
          - SheetJS  xlsx  v0.18.5  - XLSX export
          - jsPDF         v2.5.1   - PDF export
          - jsPDF-AutoTable v3.8.2 - PDF table formatting

        If the machine opening the report has no internet access, CSV export
        (pure JS, no CDN dependency) continues to work; XLSX and PDF buttons
        will show an alert.

    .PARAMETER Report
        Dashboard object built with New-DhDashboard / Add-DhTable / Set-DhTableLink.

    .PARAMETER OutputPath
        Full path for the HTML file (e.g. C:\Reports\dashboard.html).

    .PARAMETER Force
        Overwrite an existing file without prompting.

    .PARAMETER OpenInBrowser
        Attempt to open the dashboard in the default browser after writing.

    .EXAMPLE
        Export-DhDashboard -Report $report -OutputPath 'C:\Reports\dashboard.html' -Force
        Export-DhDashboard -Report $report -OutputPath '.\report.html' -Force -OpenInBrowser
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)] [string]    $OutputPath,
        [switch] $Force,
        [switch] $OpenInBrowser
    )

    # Resolve module version dynamically so the HTML footer stays accurate after bumps
    $moduleVersion = if ($MyInvocation.MyCommand.Module) {
        $MyInvocation.MyCommand.Module.Version.ToString()
    } else { '1.0.0' }

    # Resolve paths
    $OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    $outDir     = Split-Path $OutputPath -Parent

    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        Write-Verbose "Export-DhDashboard: Created directory '$outDir'."
    }

    # ---- Resolve themes (light = primary, dark = alternate, always embedded) ----
    $theme          = if ($Report.Contains('Theme'))          { $Report.Theme          } else { 'DefaultLight' }
    $alternateTheme = if ($Report.Contains('AlternateTheme')) { $Report.AlternateTheme } else { 'DefaultDark'  }
    $themeFamily    = if ($Report.Contains('ThemeFamily'))    { $Report.ThemeFamily    } else { 'Default'      }
    Write-Verbose "Export-DhDashboard: [CSS ] Themes embedded: $theme (light) + $alternateTheme (dark)"

    # ---- Build table JSON ---------------------------------------------------------
    $jsConfigBlocks = foreach ($t in $Report.Tables) {

        # Columns -> JSON
        $colsJson = ($t.Columns | ForEach-Object {
            $col = $_
            $w   = if ($col.Contains('Width') -and $col.Width)      { ",`"width`":$(ConvertTo-DhJsonString $col.Width)"                                  } else { '' }
            $s   = if ($col.Contains('Sortable'))                    { ",`"sortable`":$(([bool]$col.Sortable).ToString().ToLower())"                    } else { '' }
            $ct  = if ($col.Contains('CellType') -and $col.CellType){ ",`"cellType`":$(ConvertTo-DhJsonString $col.CellType)"                            } else { '' }
            $pm  = if ($col.Contains('ProgressMax'))                 { ",`"progressMax`":$($col.ProgressMax)"                                          } else { '' }
            $bl  = if ($col.Contains('Bold'))                        { ",`"bold`":$(([bool]$col.Bold).ToString().ToLower())"                            } else { '' }
            $it  = if ($col.Contains('Italic'))                      { ",`"italic`":$(([bool]$col.Italic).ToString().ToLower())"                        } else { '' }
            $fn  = if ($col.Contains('Font') -and $col.Font)         { ",`"font`":$(ConvertTo-DhJsonString $col.Font)"                                   } else { '' }
            $al  = if ($col.Contains('Align') -and $col.Align)       { ",`"align`":$(ConvertTo-DhJsonString $col.Align)"                                 } else { '' }
            $fo  = if ($col.Contains('Format') -and $col.Format)     { ",`"format`":$(ConvertTo-DhJsonString $col.Format)"                               } else { '' }
            $lc  = if ($col.Contains('Locale') -and $col.Locale)     { ",`"locale`":$(ConvertTo-DhJsonString $col.Locale)"                               } else { '' }
            $dc  = if ($col.Contains('Decimals') -and $col.Decimals -ge 0) { ",`"decimals`":$($col.Decimals)"                                          } else { '' }
            $cu  = if ($col.Contains('Currency') -and $col.Currency) { ",`"currency`":$(ConvertTo-DhJsonString $col.Currency)"                           } else { '' }
            $dp  = if ($col.Contains('DatePattern') -and $col.DatePattern) { ",`"datePattern`":$(ConvertTo-DhJsonString $col.DatePattern)"               } else { '' }
            $rh  = if ($col.Contains('RowHighlight'))                { ",`"rowHighlight`":$(([bool]$col.RowHighlight).ToString().ToLower())"            } else { '' }
            $pf  = if ($col.Contains('PinFirst') -and $col.PinFirst) { ',"pinFirst":true'                                                               } else { '' }
            $agg = if ($col.Contains('Aggregate') -and $col.Aggregate) { ",`"aggregate`":$(ConvertTo-DhJsonString $col.Aggregate)"                       } else { '' }
            # ragNoData flag (v1.4 F13) — tells the JS matcher to paint null/missing
            # cells with cell-nodata when the column was declared with -Rag NoData=$true
            $rnd = if ($col.Contains('RagNoData') -and $col.RagNoData) { ',"ragNoData":true' } else { '' }
            # v1.4 F8 — sparkline cell column extras (sortBy + sparklineStyle)
            $sb  = if ($col.Contains('SortBy') -and $col.SortBy)         { ",`"sortBy`":$(ConvertTo-DhJsonString $col.SortBy)"                       } else { '' }
            $sps = if ($col.Contains('SparklineStyle') -and $col.SparklineStyle) { ",`"sparklineStyle`":$(ConvertTo-DhJsonString $col.SparklineStyle)" } else { '' }

            # Thresholds — supports both numeric (Min/Max) and string (Value) rules
            $thJson = ''
            if ($col.Contains('Thresholds') -and $col.Thresholds -and $col.Thresholds.Count -gt 0) {
                $thEntries = ($col.Thresholds | ForEach-Object {
                    $th   = $_
                    # String threshold: Value key (exact match in JS)
                    if ($th.Contains('Value') -and $null -ne $th.Value) {
                        $tCls = ConvertTo-DhJsonString ([string]$th.Class)
                        $tVal = ConvertTo-DhJsonString ([string]$th.Value)
                        "{`"value`":$tVal,`"class`":$tCls}"
                    } else {
                        # Numeric threshold: Min/Max
                        $tMin = if ($th.Contains('Min') -and $null -ne $th.Min) { "`"min`":$($th.Min)," } else { '' }
                        $tMax = if ($th.Contains('Max') -and $null -ne $th.Max) { "`"max`":$($th.Max)," } else { '' }
                        $tCls = ConvertTo-DhJsonString ([string]$th.Class)
                        "{$tMin$tMax`"class`":$tCls}"
                    }
                }) -join ','
                $thJson = ",`"thresholds`":[$thEntries]"
            }
            "{`"field`":$(ConvertTo-DhJsonString $col.Field),`"label`":$(ConvertTo-DhJsonString $col.Label)$w$s$ct$pm$bl$it$fn$al$fo$lc$dc$cu$dp$rh$pf$agg$rnd$sb$sps$thJson}"
        }) -join ','

        # Rows -> JSON
        $dataJson = ($t.Data | ForEach-Object {
            $row   = $_
            $props = ($row.Keys | ForEach-Object {
                $k = $_
                $v = $row[$k]
                $vs = if ($null -eq $v) {
                    'null'
                } elseif ($v -is [bool]) {
                    $v.ToString().ToLower()
                } elseif ($v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [float] -or $v -is [decimal]) {
                    [string]$v
                } elseif ($v -is [string]) {
                    ConvertTo-DhJsonString $v
                } elseif ($v -is [System.Collections.IEnumerable]) {
                    # v1.4 F8 — arrays preserve their structure so 'sparkline' cell
                    # types can render an inline mini-chart. Each element is either
                    # a number (emitted bare) or null (for line breaks); anything
                    # else collapses to its string form for fidelity.
                    $items = foreach ($el in $v) {
                        if ($null -eq $el) {
                            'null'
                        } elseif ($el -is [bool]) {
                            $el.ToString().ToLower()
                        } elseif ($el -is [int] -or $el -is [long] -or $el -is [double] -or $el -is [float] -or $el -is [decimal]) {
                            [string]$el
                        } else {
                            $nNum = 0.0
                            if ([double]::TryParse(
                                [string]$el,
                                [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands,
                                [System.Globalization.CultureInfo]::InvariantCulture,
                                [ref]$nNum)) { [string]$nNum } else { ConvertTo-DhJsonString ([string]$el) }
                        }
                    }
                    "[$($items -join ',')]"
                } else {
                    ConvertTo-DhJsonString ([string]$v)
                }
                "$(ConvertTo-DhJsonString $k):$vs"
            }) -join ','
            "{$props}"
        }) -join ','

        # outLinks for this master table
        $outLinks = ($Report.Links | Where-Object { $_.MasterTableId -eq $t.Id } | ForEach-Object {
            "{`"detailTableId`":$(ConvertTo-DhJsonString $_.DetailTableId),`"masterField`":$(ConvertTo-DhJsonString $_.MasterField),`"detailField`":$(ConvertTo-DhJsonString $_.DetailField)}"
        }) -join ','

        # Charts -> JSON
        $chartsJson = ''
        if ($t.Contains('Charts') -and $t.Charts.Count -gt 0) {
            $chartsJson = ($t.Charts | ForEach-Object {
                $ch     = $_
                $chType = if ($ch.Contains('Type') -and $ch.Type) { $ch.Type } else { 'pie' }
                "{`"title`":$(ConvertTo-DhJsonString $ch.Title),`"field`":$(ConvertTo-DhJsonString $ch.Field),`"type`":$(ConvertTo-DhJsonString $chType)}"
            }) -join ','
        }

        # Full table config object
        $expFn = if ($t.Contains('ExportFileName') -and $t.ExportFileName) { ConvertTo-DhJsonString $t.ExportFileName } else { ConvertTo-DhJsonString $t.Id }
        [string]::Format(
            '{{"id":{0},"title":{1},"description":{2},"pageSize":{3},"multiSelect":{4},"filterable":{5},"pageable":{6},"exportFileName":{7},"columns":[{8}],"data":[{9}],"outLinks":[{10}],"charts":[{11}]}}',
            (ConvertTo-DhJsonString $t.Id),
            (ConvertTo-DhJsonString $t.Title),
            (ConvertTo-DhJsonString $t.Description),
            $t.PageSize,
            $t.MultiSelect.ToString().ToLower(),
            $t.Filterable.ToString().ToLower(),
            $t.Pageable.ToString().ToLower(),
            $expFn,
            $colsJson,
            $dataJson,
            $outLinks,
            $chartsJson
        )
    }

    $tablesConfigJson = "[$( $jsConfigBlocks -join ',' )]"

    # ---- Build summary JSON --------------------------------------------------------
    $summaryConfigJson = '[]'
    if ($Report.Contains('Summary') -and $Report.Summary.Count -gt 0) {
        $summaryItems = ($Report.Summary | ForEach-Object {
            $s = $_
            $val = if ($null -eq $s.Value) { 'null' } `
                   elseif ($s.Value -is [bool])    { $s.Value.ToString().ToLower() } `
                   elseif ($s.Value -is [int] -or $s.Value -is [long] -or $s.Value -is [double] -or $s.Value -is [float] -or $s.Value -is [decimal]) { [string]$s.Value } `
                   else { ConvertTo-DhJsonString ([string]$s.Value) }
            $dec = if ($s.Contains('Decimals') -and $s.Decimals -ge 0) { $s.Decimals } else { -1 }

            # Trend / delta (v1.4 F1) — emit only when Previous or an explicit Trend is supplied
            $deltaJson = ''
            $hasPrev   = $s.Contains('Previous')   -and $null -ne $s.Previous
            $hasTrend  = $s.Contains('Trend')      -and $s.Trend -ne 'auto'
            if ($hasPrev -or $hasTrend) {
                $prevJson = if ($hasPrev) { [string]$s.Previous } else { 'null' }
                $trendStr = if ($s.Contains('Trend') -and $s.Trend) { [string]$s.Trend } else { 'auto' }
                $tigJson  = if ($null -ne $s.TrendIsGood) { ([bool]$s.TrendIsGood).ToString().ToLower() } else { 'null' }
                $dfStr    = if ($s.Contains('DeltaFormat') -and $s.DeltaFormat) { [string]$s.DeltaFormat } else { 'both' }
                $deltaJson = ",`"previous`":$prevJson,`"trend`":$(ConvertTo-DhJsonString $trendStr),`"trendIsGood`":$tigJson,`"deltaFormat`":$(ConvertTo-DhJsonString $dfStr)"
            }

            # Sparkline (v1.4 F2) — emit only when the series is non-empty
            $sparkJson = ''
            if ($s.Contains('Sparkline') -and $s.Sparkline -and @($s.Sparkline).Count -gt 0) {
                $sparkValues  = ((@($s.Sparkline) | ForEach-Object { [string]$_ }) -join ',')
                $sparkMinJson = if ($null -ne $s.SparklineMin) { [string]$s.SparklineMin } else { 'null' }
                $sparkMaxJson = if ($null -ne $s.SparklineMax) { [string]$s.SparklineMax } else { 'null' }
                $sparkStyle   = if ($s.Contains('SparklineStyle') -and $s.SparklineStyle) { [string]$s.SparklineStyle } else { 'line' }
                $sparkJson = ",`"sparkline`":[$sparkValues],`"sparklineMin`":$sparkMinJson,`"sparklineMax`":$sparkMaxJson,`"sparklineStyle`":$(ConvertTo-DhJsonString $sparkStyle)"
            }

            # Tile style (v1.4 F3 + F4) — always emit; default 'tile' preserves the existing renderer
            $styleStr = if ($s.Contains('Style') -and $s.Style) { [string]$s.Style } else { 'tile' }
            $styleJson = ",`"style`":$(ConvertTo-DhJsonString $styleStr)"

            # Bignumber caption (only when style is bignumber and caption is set)
            $captionJson = ''
            if ($styleStr -eq 'bignumber' -and $s.Contains('Caption') -and -not [string]::IsNullOrWhiteSpace([string]$s.Caption)) {
                $captionJson = ",`"caption`":$(ConvertTo-DhJsonString $s.Caption)"
            }

            # Gauge fields (only when style is gauge)
            $gaugeJson = ''
            if ($styleStr -eq 'gauge') {
                $minJson  = if ($null -ne $s.Min)  { [string]$s.Min }  else { '0' }
                $maxJson  = if ($null -ne $s.Max)  { [string]$s.Max }  else { '100' }
                $unitStr  = if ($s.Contains('Unit') -and $s.Unit) { [string]$s.Unit } else { '' }
                $thJson   = ''
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
                # ragNoData (v1.4 F13) — when true the gauge paints itself cell-nodata
                # if the value is null/NaN or outside [min,max]
                $rndJson = if ($s.Contains('RagNoData') -and $s.RagNoData) { ',"ragNoData":true' } else { '' }
                $gaugeJson = ",`"min`":$minJson,`"max`":$maxJson,`"unit`":$(ConvertTo-DhJsonString $unitStr)$thJson$rndJson"
            }

            # Per-tile Action (v1.4.2 — click-to-jump) — emit only when set
            $actionJson = ''
            if ($s.Contains('Action') -and $null -ne $s.Action) {
                $a = $s.Action
                $actionJson = ",`"action`":{`"label`":$(ConvertTo-DhJsonString $a.Label),`"tableId`":$(ConvertTo-DhJsonString $a.TableId),`"filter`":$(ConvertTo-DhJsonString $a.Filter),`"url`":$(ConvertTo-DhJsonString $a.Url)}"
            }

            "{`"label`":$(ConvertTo-DhJsonString $s.Label),`"value`":$val,`"icon`":$(ConvertTo-DhJsonString $s.Icon),`"subLabel`":$(ConvertTo-DhJsonString $s.SubLabel),`"class`":$(ConvertTo-DhJsonString $s.Class),`"format`":$(ConvertTo-DhJsonString $s.Format),`"locale`":$(ConvertTo-DhJsonString $s.Locale),`"decimals`":$dec,`"currency`":$(ConvertTo-DhJsonString $s.Currency)$styleJson$captionJson$gaugeJson$deltaJson$sparkJson$actionJson}"
        }) -join ','
        $summaryConfigJson = "[$summaryItems]"
    }

    # ---- Build blocks JSON ---------------------------------------------------------
    $blocksConfigJson = '[]'
    if ($Report.Contains('Blocks') -and $Report.Blocks.Count -gt 0) {
        $blockItems = ($Report.Blocks | ForEach-Object {
            $b = $_
            $bt = ConvertTo-DhJsonString $b.BlockType
            # v1.5.1 — central Collapsible / DefaultOpen flags shared by every block emit
            $bCollStr = if ($b.Contains('Collapsible')) { ([bool]$b.Collapsible).ToString().ToLower() } else { 'false' }
            $bDoStr   = if ($b.Contains('DefaultOpen')) { ([bool]$b.DefaultOpen).ToString().ToLower() } else { 'true'  }
            switch ($b.BlockType) {
                'html' {
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"icon`":$(ConvertTo-DhJsonString $b.Icon),`"content`":$(ConvertTo-DhJsonString $b.Content),`"style`":$(ConvertTo-DhJsonString $b.Style),`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                'collapsible' {
                    $cardsJson = ($b.Cards | ForEach-Object {
                        $card = $_
                        $fieldsJson = ($card.Fields | ForEach-Object {
                            "{`"label`":$(ConvertTo-DhJsonString $_.Label),`"value`":$(ConvertTo-DhJsonString $_.Value),`"class`":$(ConvertTo-DhJsonString $_.Class)}"
                        }) -join ','
                        "{`"title`":$(ConvertTo-DhJsonString $card.Title),`"badge`":$(ConvertTo-DhJsonString $card.Badge),`"badgeClass`":$(ConvertTo-DhJsonString $card.BadgeClass),`"fields`":[$fieldsJson]}"
                    }) -join ','
                    $openStr = $b.DefaultOpen.ToString().ToLower()
                    $cwStr   = if ($b.Contains('CardWidth') -and $b.CardWidth) { ConvertTo-DhJsonString $b.CardWidth } else { '"normal"' }
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"icon`":$(ConvertTo-DhJsonString $b.Icon),`"defaultOpen`":$openStr,`"badge`":$($b.Badge),`"cards`":[$cardsJson],`"content`":$(ConvertTo-DhJsonString $b.Content),`"cardWidth`":$cwStr}"
                }
                'filtercardgrid' {
                    $fcJson = ($b.Cards | ForEach-Object {
                        $c = $_
                        $cnt = if ($null -eq $c.Count) { 'null' } else { [string]$c.Count }
                        "{`"label`":$(ConvertTo-DhJsonString $c.Label),`"value`":$(ConvertTo-DhJsonString $c.Value),`"subLabel`":$(ConvertTo-DhJsonString $c.SubLabel),`"count`":$cnt,`"icon`":$(ConvertTo-DhJsonString $c.Icon)}"
                    }) -join ','
                    $mf  = $b.MultiFilter.ToString().ToLower()
                    $sc  = $b.ShowCount.ToString().ToLower()
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"targetTableId`":$(ConvertTo-DhJsonString $b.TargetTableId),`"filterField`":$(ConvertTo-DhJsonString $b.FilterField),`"multiFilter`":$mf,`"showCount`":$sc,`"cards`":[$fcJson],`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                'barchart' {
                    $spStr = $b.ShowPercent.ToString().ToLower()
                    $scStr = $b.ShowCount.ToString().ToLower()
                    $cfStr = $b.ClickFilters.ToString().ToLower()
                    # v1.4 F12 — stacked mode adds seriesField + stacked flag
                    $stStr   = if ($b.Contains('Stacked'))     { ([bool]$b.Stacked).ToString().ToLower() } else { 'false' }
                    $sfStr   = if ($b.Contains('SeriesField') -and $b.SeriesField) { [string]$b.SeriesField } else { '' }
                    $stacked = ",`"stacked`":$stStr,`"seriesField`":$(ConvertTo-DhJsonString $sfStr)"
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"tableId`":$(ConvertTo-DhJsonString $b.TableId),`"field`":$(ConvertTo-DhJsonString $b.Field),`"topN`":$($b.TopN),`"showCount`":$scStr,`"showPercent`":$spStr,`"clickFilters`":$cfStr$stacked,`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                'heatmap' {
                    # v1.5 — rows × columns matrix with sequential / diverging colour scale.
                    $rowsJ    = (@($b.Rows)    | ForEach-Object { ConvertTo-DhJsonString ([string]$_) }) -join ','
                    $columnsJ = (@($b.Columns) | ForEach-Object { ConvertTo-DhJsonString ([string]$_) }) -join ','
                    $cellsJ = ''
                    if ($b.Cells -and @($b.Cells).Count -gt 0) {
                        $cellsJ = (@($b.Cells) | ForEach-Object {
                            $hc = $_
                            "{`"row`":$(ConvertTo-DhJsonString $hc.Row),`"column`":$(ConvertTo-DhJsonString $hc.Column),`"value`":$([string]$hc.Value),`"tooltip`":$(ConvertTo-DhJsonString $hc.Tooltip)}"
                        }) -join ','
                    }
                    $minJ  = if ($null -ne $b.Min) { [string]$b.Min } else { 'null' }
                    $maxJ  = if ($null -ne $b.Max) { [string]$b.Max } else { 'null' }
                    $svStr = ([bool]$b.ShowValues).ToString().ToLower()
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"rows`":[$rowsJ],`"columns`":[$columnsJ],`"cells`":[$cellsJ],`"rowLabel`":$(ConvertTo-DhJsonString $b.RowLabel),`"columnLabel`":$(ConvertTo-DhJsonString $b.ColumnLabel),`"colorScale`":$(ConvertTo-DhJsonString $b.ColorScale),`"min`":$minJ,`"max`":$maxJ,`"unit`":$(ConvertTo-DhJsonString $b.Unit),`"cellSize`":$(ConvertTo-DhJsonString $b.CellSize),`"showValues`":$svStr,`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                'tabs' {
                    # v1.5 — inline tabbed content block.
                    $tabsJson = ''
                    if ($b.Tabs -and @($b.Tabs).Count -gt 0) {
                        $tabsJson = (@($b.Tabs) | ForEach-Object {
                            $tb = $_
                            $actStr = ([bool]$tb.Active).ToString().ToLower()
                            "{`"title`":$(ConvertTo-DhJsonString $tb.Title),`"content`":$(ConvertTo-DhJsonString $tb.Content),`"icon`":$(ConvertTo-DhJsonString $tb.Icon),`"active`":$actStr}"
                        }) -join ','
                    }
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"tabs`":[$tabsJson],`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                'topologymap' {
                    # v1.5 — parent/child tree visualisation. Each node carries its
                    # id, label, parent id (or '' for root), optional status / icon /
                    # badge / tooltip, plus optional LinkTableId / LinkFilter for
                    # click-to-jump navigation.
                    $nodesJson = ''
                    if ($b.Nodes -and @($b.Nodes).Count -gt 0) {
                        $nodesJson = (@($b.Nodes) | ForEach-Object {
                            $tn = $_
                            "{`"id`":$(ConvertTo-DhJsonString $tn.Id),`"label`":$(ConvertTo-DhJsonString $tn.Label),`"parent`":$(ConvertTo-DhJsonString $tn.Parent),`"status`":$(ConvertTo-DhJsonString $tn.Status),`"icon`":$(ConvertTo-DhJsonString $tn.Icon),`"badge`":$(ConvertTo-DhJsonString $tn.Badge),`"tooltip`":$(ConvertTo-DhJsonString $tn.Tooltip),`"linkTableId`":$(ConvertTo-DhJsonString $tn.LinkTableId),`"linkFilter`":$(ConvertTo-DhJsonString $tn.LinkFilter)}"
                        }) -join ','
                    }
                    $afStr  = if ($b.Contains('AutoFitWidth')) { ([bool]$b.AutoFitWidth).ToString().ToLower() } else { 'false' }
                    $afMaxV = if ($b.Contains('AutoFitMaxWidth') -and $b.AutoFitMaxWidth) { [string]$b.AutoFitMaxWidth } else { '360' }
                    $intStr = if ($b.Contains('Interactive')) { ([bool]$b.Interactive).ToString().ToLower() } else { 'true' }
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"nodes`":[$nodesJson],`"direction`":$(ConvertTo-DhJsonString $b.Direction),`"nodeWidth`":$($b.NodeWidth),`"nodeHeight`":$($b.NodeHeight),`"autoFitWidth`":$afStr,`"autoFitMaxWidth`":$afMaxV,`"interactive`":$intStr,`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                'statusgrid' {
                    # v1.4 F5 — rows × columns RAG matrix.
                    $rowsJson    = (@($b.Rows)    | ForEach-Object { ConvertTo-DhJsonString ([string]$_) }) -join ','
                    $columnsJson = (@($b.Columns) | ForEach-Object { ConvertTo-DhJsonString ([string]$_) }) -join ','
                    $cellsJson = ''
                    if ($b.Cells -and @($b.Cells).Count -gt 0) {
                        $cellsJson = (@($b.Cells) | ForEach-Object {
                            $cell = $_
                            "{`"row`":$(ConvertTo-DhJsonString $cell.Row),`"column`":$(ConvertTo-DhJsonString $cell.Column),`"status`":$(ConvertTo-DhJsonString $cell.Status),`"tooltip`":$(ConvertTo-DhJsonString $cell.Tooltip),`"linkTableId`":$(ConvertTo-DhJsonString $cell.LinkTableId),`"linkFilter`":$(ConvertTo-DhJsonString $cell.LinkFilter)}"
                        }) -join ','
                    }
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"rows`":[$rowsJson],`"columns`":[$columnsJson],`"cells`":[$cellsJson],`"rowLabel`":$(ConvertTo-DhJsonString $b.RowLabel),`"columnLabel`":$(ConvertTo-DhJsonString $b.ColumnLabel),`"cellSize`":$(ConvertTo-DhJsonString $b.CellSize),`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                'summarystrip' {
                    # v1.4.1 F-multi-summary — per-NavGroup KPI strip emitted as
                    # a regular block. The JS renderer reuses the same tile
                    # helpers as the top-of-page strip; only the host container
                    # differs (per-block instead of #report-summary).
                    $stItems = ''
                    if ($b.Items -and @($b.Items).Count -gt 0) {
                        $stItems = (@($b.Items) | ForEach-Object {
                            $it = $_

                            # Mirrors the summary-tile JSON in $summaryItems above —
                            # delta + sparkline + style + gauge fields all included.
                            $val = if ($null -eq $it.Value) { 'null' } `
                                   elseif ($it.Value -is [bool])    { $it.Value.ToString().ToLower() } `
                                   elseif ($it.Value -is [int] -or $it.Value -is [long] -or $it.Value -is [double] -or $it.Value -is [float] -or $it.Value -is [decimal]) { [string]$it.Value } `
                                   else { ConvertTo-DhJsonString ([string]$it.Value) }
                            $dec = if ($it.Contains('Decimals') -and $it.Decimals -ge 0) { $it.Decimals } else { -1 }

                            # Trend / delta
                            $deltaJson2 = ''
                            $hasPrev2   = $it.Contains('Previous')   -and $null -ne $it.Previous
                            $hasTrend2  = $it.Contains('Trend')      -and $it.Trend -ne 'auto'
                            if ($hasPrev2 -or $hasTrend2) {
                                $prevJson2 = if ($hasPrev2) { [string]$it.Previous } else { 'null' }
                                $trendStr2 = if ($it.Contains('Trend') -and $it.Trend) { [string]$it.Trend } else { 'auto' }
                                $tigJson2  = if ($null -ne $it.TrendIsGood) { ([bool]$it.TrendIsGood).ToString().ToLower() } else { 'null' }
                                $dfStr2    = if ($it.Contains('DeltaFormat') -and $it.DeltaFormat) { [string]$it.DeltaFormat } else { 'both' }
                                $deltaJson2 = ",`"previous`":$prevJson2,`"trend`":$(ConvertTo-DhJsonString $trendStr2),`"trendIsGood`":$tigJson2,`"deltaFormat`":$(ConvertTo-DhJsonString $dfStr2)"
                            }

                            # Sparkline
                            $sparkJson2 = ''
                            if ($it.Contains('Sparkline') -and $it.Sparkline -and @($it.Sparkline).Count -gt 0) {
                                $sparkValues2 = ((@($it.Sparkline) | ForEach-Object { [string]$_ }) -join ',')
                                $sparkMinJson2 = if ($null -ne $it.SparklineMin) { [string]$it.SparklineMin } else { 'null' }
                                $sparkMaxJson2 = if ($null -ne $it.SparklineMax) { [string]$it.SparklineMax } else { 'null' }
                                $sparkStyle2   = if ($it.Contains('SparklineStyle') -and $it.SparklineStyle) { [string]$it.SparklineStyle } else { 'line' }
                                $sparkJson2 = ",`"sparkline`":[$sparkValues2],`"sparklineMin`":$sparkMinJson2,`"sparklineMax`":$sparkMaxJson2,`"sparklineStyle`":$(ConvertTo-DhJsonString $sparkStyle2)"
                            }

                            # Style + style-specific fields (bignumber caption, gauge fields)
                            $styleStr2  = if ($it.Contains('Style') -and $it.Style) { [string]$it.Style } else { 'tile' }
                            $styleJson2 = ",`"style`":$(ConvertTo-DhJsonString $styleStr2)"
                            $captionJson2 = ''
                            if ($styleStr2 -eq 'bignumber' -and $it.Contains('Caption') -and -not [string]::IsNullOrWhiteSpace([string]$it.Caption)) {
                                $captionJson2 = ",`"caption`":$(ConvertTo-DhJsonString $it.Caption)"
                            }
                            $gaugeJson2 = ''
                            if ($styleStr2 -eq 'gauge') {
                                $minJson2 = if ($null -ne $it.Min) { [string]$it.Min } else { '0' }
                                $maxJson2 = if ($null -ne $it.Max) { [string]$it.Max } else { '100' }
                                $unitStr2 = if ($it.Contains('Unit') -and $it.Unit) { [string]$it.Unit } else { '' }
                                $thJson2  = ''
                                if ($it.Contains('Thresholds') -and @($it.Thresholds).Count -gt 0) {
                                    $thItems2 = (@($it.Thresholds) | ForEach-Object {
                                        $th = $_
                                        $minPart = if ($th.Contains('Min')) { "`"min`":$([string]$th.Min)," } else { '' }
                                        $maxPart = if ($th.Contains('Max')) { "`"max`":$([string]$th.Max)," } else { '' }
                                        "{$minPart$maxPart`"class`":$(ConvertTo-DhJsonString $th.Class)}"
                                    }) -join ','
                                    $thJson2 = ",`"thresholds`":[$thItems2]"
                                } else {
                                    $thJson2 = ',"thresholds":[]'
                                }
                                $rndJson2 = if ($it.Contains('RagNoData') -and $it.RagNoData) { ',"ragNoData":true' } else { '' }
                                $gaugeJson2 = ",`"min`":$minJson2,`"max`":$maxJson2,`"unit`":$(ConvertTo-DhJsonString $unitStr2)$thJson2$rndJson2"
                            }

                            # Per-tile Action (v1.4.2) — same shape as the top-of-page strip
                            $actionJson2 = ''
                            if ($it.Contains('Action') -and $null -ne $it.Action) {
                                $a2 = $it.Action
                                $actionJson2 = ",`"action`":{`"label`":$(ConvertTo-DhJsonString $a2.Label),`"tableId`":$(ConvertTo-DhJsonString $a2.TableId),`"filter`":$(ConvertTo-DhJsonString $a2.Filter),`"url`":$(ConvertTo-DhJsonString $a2.Url)}"
                            }

                            "{`"label`":$(ConvertTo-DhJsonString $it.Label),`"value`":$val,`"icon`":$(ConvertTo-DhJsonString $it.Icon),`"subLabel`":$(ConvertTo-DhJsonString $it.SubLabel),`"class`":$(ConvertTo-DhJsonString $it.Class),`"format`":$(ConvertTo-DhJsonString $it.Format),`"locale`":$(ConvertTo-DhJsonString $it.Locale),`"decimals`":$dec,`"currency`":$(ConvertTo-DhJsonString $it.Currency)$styleJson2$captionJson2$gaugeJson2$deltaJson2$sparkJson2$actionJson2}"
                        }) -join ','
                    }
                    $collStr = ([bool]$b.Collapsible).ToString().ToLower()
                    $doStr   = ([bool]$b.DefaultOpen).ToString().ToLower()
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"icon`":$(ConvertTo-DhJsonString $b.Icon),`"collapsible`":$collStr,`"defaultOpen`":$doStr,`"items`":[$stItems]}"
                }
                'eventfeed' {
                    # v1.4 F11 — chronological severity-tagged audit trail.
                    $eventsJson = ''
                    if ($b.Events -and @($b.Events).Count -gt 0) {
                        $eventsJson = (@($b.Events) | ForEach-Object {
                            $ev = $_
                            "{`"timestamp`":$(ConvertTo-DhJsonString $ev.Timestamp),`"severity`":$(ConvertTo-DhJsonString $ev.Severity),`"message`":$(ConvertTo-DhJsonString $ev.Message),`"source`":$(ConvertTo-DhJsonString $ev.Source),`"icon`":$(ConvertTo-DhJsonString $ev.Icon)}"
                        }) -join ','
                    }
                    $sdStr = $b.SortDescending.ToString().ToLower()
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"events`":[$eventsJson],`"maxItems`":$($b.MaxItems),`"groupBy`":$(ConvertTo-DhJsonString $b.GroupBy),`"sortDescending`":$sdStr,`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                'linechart' {
                    # v1.4 F9 — pure-SVG line / area chart with optional target line.
                    # xAxis is a string array; series is an array of {label, values[], class, color}.
                    $xAxisJson = ''
                    if ($b.XAxis -and @($b.XAxis).Count -gt 0) {
                        $xAxisJson = (@($b.XAxis) | ForEach-Object { ConvertTo-DhJsonString ([string]$_) }) -join ','
                    }
                    $seriesJson = ''
                    if ($b.Series -and @($b.Series).Count -gt 0) {
                        $seriesJson = (@($b.Series) | ForEach-Object {
                            $sr = $_
                            # NaN doubles serialise as 'NaN' which is not valid JSON — emit null instead
                            $valsJoin = (@($sr.Values) | ForEach-Object {
                                if ([double]::IsNaN([double]$_)) { 'null' } else { [string]$_ }
                            }) -join ','
                            "{`"label`":$(ConvertTo-DhJsonString $sr.Label),`"values`":[$valsJoin],`"class`":$(ConvertTo-DhJsonString $sr.Class),`"color`":$(ConvertTo-DhJsonString $sr.Color)}"
                        }) -join ','
                    }
                    $filledStr = $b.Filled.ToString().ToLower()
                    $tlStr     = if ($null -ne $b.TargetLine) { [string]$b.TargetLine } else { 'null' }
                    $tlLabel   = ConvertTo-DhJsonString ([string]$b.TargetLabel)
                    $yMinStr   = if ($null -ne $b.YAxisMin) { [string]$b.YAxisMin } else { 'null' }
                    $yMaxStr   = if ($null -ne $b.YAxisMax) { [string]$b.YAxisMax } else { 'null' }
                    $yUnitStr  = ConvertTo-DhJsonString ([string]$b.YAxisUnit)
                    $slStr     = $b.ShowLegend.ToString().ToLower()
                    $sgStr     = $b.ShowGrid.ToString().ToLower()
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"xAxis`":[$xAxisJson],`"series`":[$seriesJson],`"filled`":$filledStr,`"targetLine`":$tlStr,`"targetLabel`":$tlLabel,`"yAxisMin`":$yMinStr,`"yAxisMax`":$yMaxStr,`"yAxisUnit`":$yUnitStr,`"showLegend`":$slStr,`"showGrid`":$sgStr,`"height`":$($b.Height),`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                'bullet' {
                    # v1.4 F10 — each item carries Value/Target/Min/Max/Unit/Class
                    # + a thresholds[] array + an optional ragNoData flag.
                    $itemsJson = ''
                    if ($b.Items -and @($b.Items).Count -gt 0) {
                        $itemsJson = (@($b.Items) | ForEach-Object {
                            $bi = $_
                            $targetJson = if ($null -ne $bi.Target) { [string]$bi.Target } else { 'null' }
                            $thArr = ''
                            if ($bi.Thresholds -and @($bi.Thresholds).Count -gt 0) {
                                $thArr = (@($bi.Thresholds) | ForEach-Object {
                                    $th = $_
                                    $mn = if ($th.Contains('Min')) { "`"min`":$([string]$th.Min)," } else { '' }
                                    $mx = if ($th.Contains('Max')) { "`"max`":$([string]$th.Max)," } else { '' }
                                    "{$mn$mx`"class`":$(ConvertTo-DhJsonString $th.Class)}"
                                }) -join ','
                            }
                            $rndPart = if ($bi.RagNoData) { ',"ragNoData":true' } else { '' }
                            $valueJson = if ($null -eq $bi.Value) { 'null' } else { [string]$bi.Value }
                            "{`"label`":$(ConvertTo-DhJsonString $bi.Label),`"value`":$valueJson,`"target`":$targetJson,`"min`":$([string]$bi.Min),`"max`":$([string]$bi.Max),`"unit`":$(ConvertTo-DhJsonString $bi.Unit),`"class`":$(ConvertTo-DhJsonString $bi.Class),`"thresholds`":[$thArr]$rndPart}"
                        }) -join ','
                    }
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"items`":[$itemsJson],`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                'piechart' {
                    $cfStr = $b.ClickFilters.ToString().ToLower()
                    $stStr = $b.ShowTotal.ToString().ToLower()
                    $slStr = $b.ShowLegend.ToString().ToLower()
                    $slicesJson = ''
                    if ($b.Slices -and $b.Slices.Count -gt 0) {
                        $slicesJson = ($b.Slices | ForEach-Object {
                            $s = $_
                            "{`"label`":$(ConvertTo-DhJsonString $s.Label),`"value`":$($s.Value),`"color`":$(ConvertTo-DhJsonString $s.Color)}"
                        }) -join ','
                    }
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"style`":$(ConvertTo-DhJsonString $b.Style),`"mode`":$(ConvertTo-DhJsonString $b.Mode),`"tableId`":$(ConvertTo-DhJsonString $b.TableId),`"field`":$(ConvertTo-DhJsonString $b.Field),`"topN`":$($b.TopN),`"clickFilters`":$cfStr,`"slices`":[$slicesJson],`"showTotal`":$stStr,`"showLegend`":$slStr,`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
            }
        }) -join ','
        $blocksConfigJson = "[$blockItems]"
    }

    # ---- Build alert banners JSON --------------------------------------------------
    $alertsConfigJson = '[]'
    if ($Report.Contains('AlertBanners') -and $Report.AlertBanners.Count -gt 0) {
        $alertItems = ($Report.AlertBanners | ForEach-Object {
            $a = $_
            $dismissStr = $a.Dismissible.ToString().ToLower()
            $actionJson = 'null'
            if ($a.Action) {
                $actionJson = "{`"label`":$(ConvertTo-DhJsonString $a.Action.Label),`"tableId`":$(ConvertTo-DhJsonString $a.Action.TableId),`"filter`":$(ConvertTo-DhJsonString $a.Action.Filter),`"url`":$(ConvertTo-DhJsonString $a.Action.Url)}"
            }
            # v1.4.2+ — optional NavGroup / NavSubGroup so the banner can bind
            # to a single panel rather than staying page-global.
            $ngStr = if ($a.Contains('NavGroup')    -and $a.NavGroup)    { [string]$a.NavGroup }    else { '' }
            $sgStr = if ($a.Contains('NavSubGroup') -and $a.NavSubGroup) { [string]$a.NavSubGroup } else { '' }
            # v1.5.1 — collapsible banner chrome
            $aCollStr  = if ($a.Contains('Collapsible')) { ([bool]$a.Collapsible).ToString().ToLower() } else { 'false' }
            $aDoStr    = if ($a.Contains('DefaultOpen')) { ([bool]$a.DefaultOpen).ToString().ToLower() } else { 'true'  }
            $aTitleStr = if ($a.Contains('Title') -and $a.Title) { [string]$a.Title } else { '' }
            "{`"id`":$(ConvertTo-DhJsonString $a.Id),`"severity`":$(ConvertTo-DhJsonString $a.Severity),`"message`":$(ConvertTo-DhJsonString $a.Message),`"icon`":$(ConvertTo-DhJsonString $a.Icon),`"dismissible`":$dismissStr,`"action`":$actionJson,`"navGroup`":$(ConvertTo-DhJsonString $ngStr),`"navSubGroup`":$(ConvertTo-DhJsonString $sgStr),`"collapsible`":$aCollStr,`"defaultOpen`":$aDoStr,`"title`":$(ConvertTo-DhJsonString $aTitleStr)}"
        }) -join ','
        $alertsConfigJson = "[$alertItems]"
    }

    # ---- Inject config into JS engine --------------------------------------------
    # NB: PowerShell -replace uses .NET regex substitution syntax, where the
    # REPLACEMENT string treats $&, $', $`, $1.., $+, $_ as backreferences. When
    # injected JSON happens to contain those sequences (e.g. an event message
    # containing a SAM account name like "PV04$'..." produces a literal $'),
    # the substitution silently expands and bloats the file by repeating large
    # chunks of the template. Use [regex]::Replace with a MatchEvaluator so the
    # JSON is inserted verbatim.
    # ---- Build global-filter JSON (v1.9.0) ----------------------------------------
    $globalFilterJson = '[]'
    if ($Report.Contains('GlobalFilters') -and $Report.GlobalFilters.Count -gt 0) {
        $gfItems = ($Report.GlobalFilters | ForEach-Object {
            $g = $_
            $valsJson = if ($g.Values -and @($g.Values).Count -gt 0) {
                '[' + ((@($g.Values) | ForEach-Object { ConvertTo-DhJsonString ([string]$_) }) -join ',') + ']'
            } else { '[]' }
            "{`"field`":$(ConvertTo-DhJsonString $g.Field),`"label`":$(ConvertTo-DhJsonString $g.Label),`"type`":$(ConvertTo-DhJsonString $g.Type),`"values`":$valsJson,`"placeholder`":$(ConvertTo-DhJsonString $g.Placeholder)}"
        }) -join ','
        $globalFilterJson = "[$gfItems]"
    }

    $jsTpl = Get-DhJsContent
    $js = [regex]::Replace($jsTpl, '/\*%%TABLES_CONFIG%%\*/\[\]',  { param($m) $tablesConfigJson  })
    $js = [regex]::Replace($js,    '/\*%%SUMMARY_CONFIG%%\*/\[\]', { param($m) $summaryConfigJson })
    $js = [regex]::Replace($js,    '/\*%%BLOCKS_CONFIG%%\*/\[\]',  { param($m) $blocksConfigJson  })
    $js = [regex]::Replace($js,    '/\*%%ALERTS_CONFIG%%\*/\[\]',  { param($m) $alertsConfigJson  })
    $js = [regex]::Replace($js,    '/\*%%GLOBALFILTER_CONFIG%%\*/\[\]', { param($m) $globalFilterJson })

    # ---- Build theme style tag (light primary, dark alternate, always embedded) --
    $primaryCss    = Get-DhThemeCss -Theme $theme
    $alternateCss  = Get-DhThemeCss -Theme $alternateTheme
    $themeStyleTag = @"
  <style id="theme-primary"   data-theme="$theme">$primaryCss</style>
  <style id="theme-alternate" data-theme="$alternateTheme" media="none">$alternateCss</style>
"@

    # ---- Logo HTML ---------------------------------------------------------------
    $logoMime = if ($Report.LogoMime) { $Report.LogoMime } else { 'image/jpeg' }
    $logoHtml = if ($Report.LogoBase64) {
        "<img src=`"data:$logoMime;base64,$($Report.LogoBase64)`" class=`"report-logo`" alt=`"Logo`">"
    } else {
        '<div class="report-logo-placeholder" title="No logo supplied"></div>'
    }

    # Nav logo suppressed by design
    $navLogoHtml = ''

    # ---- Detect two-tier nav (any table or block has a NavGroup) --
    $hasTwoTier = ($Report.Tables | Where-Object { $_.NavGroup }) -or
                  ($Report.Contains('Blocks') -and ($Report.Blocks | Where-Object { $_.NavGroup }))

    if ($hasTwoTier) {
        # Collect ordered unique groups — tables first (preserve order), then any block-only groups
        $groupOrder = [System.Collections.Generic.List[string]]::new()
        foreach ($t in $Report.Tables) {
            if ($t.NavGroup -and -not $groupOrder.Contains($t.NavGroup)) {
                $groupOrder.Add($t.NavGroup)
            }
        }
        # Blocks may introduce groups that have no matching table (e.g. a filter-card-only group)
        if ($Report.Contains('Blocks')) {
            foreach ($b in $Report.Blocks) {
                if ($b.NavGroup -and -not $groupOrder.Contains($b.NavGroup)) {
                    $groupOrder.Add($b.NavGroup)
                }
            }
        }

        # Ungrouped tables get flat links in the primary bar
        $flatLinks = ($Report.Tables | Where-Object { -not $_.NavGroup } | ForEach-Object {
            $tid = $_.Id
            $tn  = [System.Web.HttpUtility]::HtmlEncode($_.Title)
            "<a class=`"nav-link`" href=`"#`" data-table=`"$tid`">$tn<span class=`"nav-badge`" data-table=`"$tid`"></span></a>"
        }) -join "`n        "

        # Group tabs for primary nav
        $groupTabsHtml = ($groupOrder | ForEach-Object {
            $g = [System.Web.HttpUtility]::HtmlEncode($_)
            "<a class=`"nav-group-tab`" href=`"#`" data-group=`"$g`">$g</a>"
        }) -join "`n        "

        # All grouped table links go in subnav (include data-subgroup when defined)
        $subnavLinks = ($Report.Tables | Where-Object { $_.NavGroup } | ForEach-Object {
            $tid = $_.Id
            $tn  = [System.Web.HttpUtility]::HtmlEncode($_.Title)
            $g   = [System.Web.HttpUtility]::HtmlEncode($_.NavGroup)
            $sg  = if ($_.Contains('NavSubGroup') -and $_.NavSubGroup) { $_.NavSubGroup } else { '' }
            $sgAttr = if ($sg) { " data-subgroup=`"$([System.Web.HttpUtility]::HtmlEncode($sg))`"" } else { '' }
            "<a class=`"nav-link`" href=`"#`" data-table=`"$tid`" data-group=`"$g`"$sgAttr>$tn<span class=`"nav-badge`" data-table=`"$tid`"></span></a>"
        }) -join "`n        "

        # ---- Three-tier nav: build subgroup pills ----
        # Collect (group, subgroup) pairs from tables first, then block-only subgroups
        $subGroupPairs = [System.Collections.Generic.List[object]]::new()
        $seenPairs = @{}
        foreach ($t in $Report.Tables) {
            if ($t.NavGroup -and $t.Contains('NavSubGroup') -and $t.NavSubGroup) {
                $key = "$($t.NavGroup)`0$($t.NavSubGroup)"
                if (-not $seenPairs.ContainsKey($key)) {
                    $seenPairs[$key] = $true
                    $subGroupPairs.Add(@{ Group = $t.NavGroup; SubGroup = $t.NavSubGroup })
                }
            }
        }
        if ($Report.Contains('Blocks')) {
            foreach ($b in $Report.Blocks) {
                if ($b.NavGroup -and $b.Contains('NavSubGroup') -and $b.NavSubGroup) {
                    $key = "$($b.NavGroup)`0$($b.NavSubGroup)"
                    if (-not $seenPairs.ContainsKey($key)) {
                        $seenPairs[$key] = $true
                        $subGroupPairs.Add(@{ Group = $b.NavGroup; SubGroup = $b.NavSubGroup })
                    }
                }
            }
        }

        $subgroupHtml = ''
        if ($subGroupPairs.Count -gt 0) {
            $subgroupPillsHtml = ($subGroupPairs | ForEach-Object {
                $g  = [System.Web.HttpUtility]::HtmlEncode($_.Group)
                $sg = [System.Web.HttpUtility]::HtmlEncode($_.SubGroup)
                "<a class=`"subgroup-pill`" href=`"#`" data-group=`"$g`" data-subgroup=`"$sg`">$sg</a>"
            }) -join "`n        "
            $subgroupHtml = "<div class=`"nav-subgroup`" id=`"nav-subgroup`" style=`"display:none`"><div class=`"subgroup-inner`">$subgroupPillsHtml</div></div>"
        }

        $navLinksHtml  = $flatLinks
        $groupTabsHtml = if ($groupTabsHtml) { "<div class=`"nav-group-tabs`" id=`"nav-group-tabs`">$groupTabsHtml</div>" } else { '' }
        $subnavHtml    = "<div class=`"nav-subnav`" id=`"nav-subnav`"><div class=`"subnav-inner`">$subnavLinks</div></div>"
    } else {
        $navLinksHtml  = ($Report.Tables | ForEach-Object {
            $tid   = $_.Id
            $tname = [System.Web.HttpUtility]::HtmlEncode($_.Title)
            "<a class=`"nav-link`" href=`"#`" data-table=`"$tid`">$tname<span class=`"nav-badge`" data-table=`"$tid`"></span></a>"
        }) -join "`n        "
        $groupTabsHtml = ''
        $subnavHtml    = ''
        $subgroupHtml  = ''
    }

    $subtitleHtml = if ($Report.Subtitle) {
        "<p class=`"report-subtitle`">$([System.Web.HttpUtility]::HtmlEncode($Report.Subtitle))</p>"
    } else { '' }

    # Info fields grid (key-value pairs displayed in the report header)
    $infoFieldsHtml = ''
    if ($Report.Contains('InfoFields') -and $Report.InfoFields.Count -gt 0) {
        $fieldItems = ($Report.InfoFields | ForEach-Object {
            $f = $_
            "<div class=`"info-field-item`"><span class=`"info-field-label`">$([System.Web.HttpUtility]::HtmlEncode($f.Label))</span><span class=`"info-field-value`">$([System.Web.HttpUtility]::HtmlEncode($f.Value))</span></div>"
        }) -join "`n            "
        $infoFieldsHtml = "<div class=`"info-fields-grid`">`n            $fieldItems`n          </div>"
    }

    # ---- Summary container shell ------------------------------------------------
    # When -Collapsible was passed to Add-DhSummary, emit data-* attributes that
    # the JS engine reads to wrap the tile strip in a collapsible header.
    $summaryOpts = if ($Report.Contains('SummaryOptions')) { $Report.SummaryOptions } else { $null }
    if ($summaryOpts -and $summaryOpts.Collapsible) {
        $sTitleAttr = [System.Web.HttpUtility]::HtmlEncode([string]$summaryOpts.Title)
        $sIconAttr  = if ($summaryOpts.Icon) { [System.Web.HttpUtility]::HtmlEncode([string]$summaryOpts.Icon) } else { '' }
        $sOpenAttr  = if ($summaryOpts.DefaultOpen) { 'true' } else { 'false' }
        $summaryContainerHtml = "<div class=`"report-summary`" id=`"report-summary`" data-collapsible=`"true`" data-title=`"$sTitleAttr`" data-icon=`"$sIconAttr`" data-default-open=`"$sOpenAttr`"></div>"
    } else {
        $summaryContainerHtml = '<div class="report-summary" id="report-summary"></div>'
    }

    # ---- Table section shells ---------------------------------------------------
    $tableSections = if ($Report.Tables.Count -gt 0) {
        Build-DhTableSections -Tables $Report.Tables
    } else { '' }

    # Build block section HTML shells
    $blockSectionsHtml = ''
    if ($Report.Contains('Blocks') -and $Report.Blocks.Count -gt 0) {
        $blockSectionsHtml = ($Report.Blocks | ForEach-Object {
            $b          = $_
            $bNg        = if ($b.NavGroup) { $b.NavGroup } else { '' }
            $bNgAttr    = if ($bNg) { " data-navgroup=`"$([System.Web.HttpUtility]::HtmlEncode($bNg))`"" } else { '' }
            $bSg        = if ($b.Contains('NavSubGroup') -and $b.NavSubGroup) { $b.NavSubGroup } else { '' }
            $bSgAttr    = if ($bSg) { " data-navsubgroup=`"$([System.Web.HttpUtility]::HtmlEncode($bSg))`"" } else { '' }
            $bActive    = if (-not $bNg) { ' panel-active' } else { '' }
            $bSpanAttr  = if ($b.Contains('GridSpan') -and $b.GridSpan -ge 1 -and $b.GridSpan -le 12) { " style=`"grid-column:span $($b.GridSpan)`"" } else { '' }
            "<div class=`"block-section$bActive`" id=`"bsection-$($b.Id)`"$bNgAttr$bSgAttr$bSpanAttr><div id=`"block-$($b.Id)`"></div></div>"
        }) -join "`n"
    }

    # ---- 12-column grid layout (v1.10.0) ----------------------------------------
    # Opt-in: the report body becomes a 12-column CSS grid only when at least one
    # block or table declares -GridSpan. Otherwise the sequential flow is unchanged.
    $useGrid = $false
    if ($Report.Contains('Blocks')) {
        foreach ($b in $Report.Blocks) { if ($b.Contains('GridSpan') -and $b.GridSpan -ge 1 -and $b.GridSpan -le 12) { $useGrid = $true; break } }
    }
    if (-not $useGrid -and $Report.Tables) {
        foreach ($t in $Report.Tables) { if ($t.Contains('GridSpan') -and $t.GridSpan -ge 1 -and $t.GridSpan -le 12) { $useGrid = $true; break } }
    }
    $bodyClass = if ($useGrid) { 'report-body report-grid' } else { 'report-body' }

    # ---- Auto-refresh meta tag (v1.4.2 — -AutoRefresh on New-DhDashboard) ----
    $autoRefreshTag = ''
    if ($Report.Contains('AutoRefreshSec') -and [int]$Report.AutoRefreshSec -ge 1) {
        $autoRefreshTag = "  <meta http-equiv=`"refresh`" content=`"$([int]$Report.AutoRefreshSec)`">"
    }

    # ---- Assemble HTML ----------------------------------------------------------
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="generator" content="DashHtml PowerShell Module v$moduleVersion">
  <meta name="report-theme" content="$themeFamily">
$autoRefreshTag
  <title>$([System.Web.HttpUtility]::HtmlEncode($Report.Title))</title>
$themeStyleTag
  <!-- Export libraries (cdnjs - internet required for XLSX/PDF export).
       v1.5.3: SRI integrity= attributes pinned so a compromised CDN cannot inject
       arbitrary script. Hashes are tied to the exact versions below; bumping a
       library version requires regenerating the matching sha384 base64 digest. -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js" integrity="sha384-vtjasyidUo0kW94K5MXDXntzOJpQgBKXmE7e2Ga4LG0skTTLeBi97eFAXsqewJjw" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js" integrity="sha384-JcnsjUPPylna1s1fvi1u12X5qjY5OL56iySh75FdtrwhO/SWXgMjoVqcKyIIWOLk" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
  <!-- Bridge: jsPDF 2.x UMD exposes window.jspdf.jsPDF but AutoTable looks for window.jsPDF -->
  <script>if(window.jspdf&&window.jspdf.jsPDF&&!window.jsPDF){window.jsPDF=window.jspdf.jsPDF;}</script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf-autotable/3.8.2/jspdf.plugin.autotable.min.js" integrity="sha384-fCAW/rDWORTbQXSiB7mOg0QtQ5c+r0f544y6XoKjuVva0nMBlCpNUjiFeG5iMdS3" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
</head>
<body>

  <header class="report-header">
    <div class="header-brand">
      $logoHtml
      <div class="header-titles">
        <h1 class="report-title">$([System.Web.HttpUtility]::HtmlEncode($Report.Title))</h1>
        $subtitleHtml
        $infoFieldsHtml
      </div>
    </div>
    <div class="header-meta">
      <span class="meta-label">Generated</span>
      <span class="meta-value">$($Report.GeneratedAt)</span>
    </div>
  </header>

  <nav class="report-nav" id="report-nav" role="navigation" aria-label="Report sections">
    <div class="nav-inner">
      $navLogoHtml
      $(if ($Report.Contains('NavTitle') -and $Report.NavTitle) { "<span class=`"nav-title`">$([System.Web.HttpUtility]::HtmlEncode($Report.NavTitle))</span>" })
      <div class="nav-divider"></div>
      $(if ($navLinksHtml) { "<div class=`"nav-links`">$navLinksHtml</div>" })
      $groupTabsHtml
      <button class="nav-top-btn" onclick="window.scrollTo({top:0,behavior:'smooth'})" title="Back to top">&#8679; Top</button>
      <button class="nav-utility-btn" id="btn-density-toggle" title="Toggle table row density">&#8862; Normal</button>
      <button class="nav-utility-btn" id="btn-theme-toggle" data-primary="$theme" data-alternate="$alternateTheme" title="Toggle theme">&#9790; Dark</button>
    </div>
    $subgroupHtml
    $subnavHtml
  </nav>

  <main class="$bodyClass">
    <div class="report-alerts" id="report-alerts"></div>
    <div class="global-filter-bar" id="global-filter-bar" role="region" aria-label="Global filters" style="display:none"></div>
    $summaryContainerHtml
$blockSectionsHtml
$tableSections
  </main>

  <footer class="report-footer">
    Generated by <strong>DashHtml</strong> v$moduleVersion &mdash; $($Report.GeneratedAt)$(if ($Report.Contains('GeneratedBy') -and $Report.GeneratedBy) { " &mdash; $([System.Web.HttpUtility]::HtmlEncode($Report.GeneratedBy))" })
  </footer>

  <script>
$js
  </script>
</body>
</html>
"@

    # ---- Write HTML -------------------------------------------------------------
    if ($PSCmdlet.ShouldProcess($OutputPath, 'Write HTML dashboard')) {
        if ((Test-Path $OutputPath) -and -not $Force) {
            Write-Warning "HTML already exists: $OutputPath  (use -Force to overwrite)"
            return
        }
        Set-Content -Path $OutputPath -Value $html -Encoding UTF8
        $size = [math]::Round((Get-Item $OutputPath).Length / 1KB, 1)
        Write-Verbose "Export-DhDashboard: [HTML] $OutputPath  ($size KB)"
        Write-Verbose "Export-DhDashboard: Themes: $theme (light) <-> $alternateTheme (dark) — embedded, toggle button in nav"
        Write-Verbose "Export-DhDashboard: Tables=$($Report.Tables.Count)  Links=$($Report.Links.Count)"
    }

    # ---- Open in browser --------------------------------------------------------
    if ($OpenInBrowser -and (Test-Path $OutputPath)) {
        try {
            Start-Process $OutputPath
        } catch {
            Write-Warning "Export-DhDashboard: Could not open dashboard in browser: $_"
        }
    }
}
