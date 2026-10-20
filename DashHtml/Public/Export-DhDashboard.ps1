function Export-DhDashboard {
    <#
    .SYNOPSIS
        Write the self-contained HTML dashboard to disk.

    .DESCRIPTION
        Generates a single HTML file, self-contained except for the optional
        XLSX/PDF export libraries listed below. Both the light and dark CSS
        themes are embedded directly inside the HTML — no external CSS file is
        ever written. A toggle button in the nav bar lets viewers switch themes
        at runtime.

        The HTML also embeds:
          - All table data as JSON (no server round-trips)
          - The full JavaScript table engine (sort / filter / page / link / export)
          - The logo as a Base64 data URI (if supplied to New-DhDashboard)

        XLSX and PDF export use three JavaScript libraries:
          - SheetJS  xlsx  v0.18.5  - XLSX export
          - jsPDF         v2.5.1   - PDF export
          - jsPDF-AutoTable v3.8.2 - PDF table formatting
        -ExportLibraries decides how they reach the reader (v2.2.0). CSV export
        needs none of them and always works.

        Every TableId / LinkTableId / Action.TableId that names a table not in
        the report, and every unknown block type, is reported as a warning
        (v2.1.4): in the browser each of them would be a silent no-op.

    .PARAMETER Report
        Dashboard object built with New-DhDashboard / Add-DhTable / Set-DhTableLink.

    .PARAMETER OutputPath
        Full path for the HTML file (e.g. C:\Reports\dashboard.html).

    .PARAMETER Force
        Overwrite an existing file without prompting.

    .PARAMETER OpenInBrowser
        Attempt to open the dashboard in the default browser after writing.

    .PARAMETER ExportLibraries
        v2.2.0. How the XLSX / PDF export libraries reach the reader.
          Cdn   (default) Loaded from cdnjs the first time a reader clicks XLSX
                or PDF, checked against a pinned SRI hash. The page itself never
                waits on the network. Offline, the two buttons turn grey and say
                "Needs internet: use CSV".
          Embed The libraries are inlined into the report (about 1.3 MB), so
                XLSX and PDF work with no network at all. For air-gapped readers.
          None  No XLSX or PDF buttons; CSV only.
        Before 2.2.0 the libraries were blocking script tags in the page head,
        so an offline reader waited for them to time out before the page
        appeared.

    .PARAMETER PrintMaxRows
        v2.2.0. When the report is printed, each table prints its filtered rows
        up to this many (default 200), with a note when rows were left out.
        The interactive view is unaffected.

    .EXAMPLE
        Export-DhDashboard -Report $report -OutputPath 'C:\Reports\dashboard.html' -Force
        Export-DhDashboard -Report $report -OutputPath '.\report.html' -Force -OpenInBrowser
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)] [string]    $OutputPath,
        [switch] $Force,
        [switch] $OpenInBrowser,
        [ValidateSet('Cdn','Embed','None')]
        [string] $ExportLibraries = 'Cdn',
        [ValidateRange(1, 100000)]
        [int]    $PrintMaxRows = 200
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
    # v2.2.0 - opening theme when the reader has not chosen one (light | dark | auto)
    $themeMode      = if ($Report.Contains('ThemeMode') -and $Report.ThemeMode -in 'light','dark','auto') { $Report.ThemeMode } else { 'light' }
    Write-Verbose "Export-DhDashboard: [CSS ] Themes embedded: $theme (light) + $alternateTheme (dark)"

    # ---- Build table JSON ---------------------------------------------------------
    $jsConfigBlocks = foreach ($t in $Report.Tables) {

        # Columns -> JSON
        $colsJson = ($t.Columns | ForEach-Object {
            $col = $_
            $w   = if ($col.Contains('Width') -and $col.Width)      { ",`"width`":$(ConvertTo-DhJsonString $col.Width)"                                  } else { '' }
            # v2.4.0 - MinWidth floors the measured width (Add-DhTable -ColumnFit Auto); emitted only when set
            if ($col.Contains('MinWidth') -and $col.MinWidth)        { $w += ",`"minWidth`":$([int]$col.MinWidth)" }
            # v2.5.0 - Hidden: emitted only when set
            if ($col.Contains('Hidden') -and $col.Hidden)            { $w += ',"hidden":true' }
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
            # v2.2.0 — link cell extras (only on CellType='link' columns)
            $sps += if ($col.Contains('UrlField') -and $col.UrlField) { ",`"urlField`":$(ConvertTo-DhJsonString $col.UrlField),`"linkText`":$(ConvertTo-DhJsonString $col.LinkText)" } else { '' }

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

        # v2.3.0 - fields shown as chips / path keep their list elements as strings
        # ("007" must stay "007"); the numeric collapse below is for sparklines.
        $listTextFields = @($t.Columns | Where-Object { $_.Contains('CellType') -and $_.CellType -in 'chips', 'path' } | ForEach-Object { [string]$_.Field })

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
                } elseif ($v -is [System.Collections.IEnumerable] -and $k -in $listTextFields) {
                    '[' + ((@($v) | ForEach-Object { ConvertTo-DhJsonString ([string]$_) }) -join ',') + ']'
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
                # v2.2.0 - bar charts carry their aggregation and size
                $barJson = ''
                if ($chType -eq 'bar') {
                    $barJson = ",`"valueField`":$(ConvertTo-DhJsonString $ch.ValueField),`"aggregate`":$(ConvertTo-DhJsonString $ch.Aggregate),`"topN`":$([int]$ch.TopN),`"unit`":$(ConvertTo-DhJsonString $ch.Unit),`"decimals`":$([int]$ch.Decimals)"
                }
                "{`"title`":$(ConvertTo-DhJsonString $ch.Title),`"field`":$(ConvertTo-DhJsonString $ch.Field),`"type`":$(ConvertTo-DhJsonString $chType)$barJson}"
            }) -join ','
        }

        # Full table config object
        $expFn = if ($t.Contains('ExportFileName') -and $t.ExportFileName) { ConvertTo-DhJsonString $t.ExportFileName } else { ConvertTo-DhJsonString $t.Id }
        # v2.3.0 - detail drawer config, emitted only when -DetailDrawer was used
        $detailJson = ''
        if ($t.Contains('DetailDrawer') -and $t.DetailDrawer) {
            $dFields = (@($t.DetailFields) | ForEach-Object { "{`"field`":$(ConvertTo-DhJsonString $_.Field),`"label`":$(ConvertTo-DhJsonString $_.Label)}" }) -join ','
            $detailJson = ",`"detail`":{`"titleField`":$(ConvertTo-DhJsonString $t.DetailTitleField),`"fields`":[$dFields]}"
        }
        # v2.4.0 - column fit: auto is the default and emits nothing, so old tables export unchanged
        # v2.5.0 - RememberColumns: a stable key (report title, -GeneratedBy and table id) so the choice survives a regenerated report
        if ($t.Contains('RememberColumns') -and $t.RememberColumns) {
            $keySrc = "$($Report.Title)|$(if ($Report.Contains('GeneratedBy')) { $Report.GeneratedBy })|$($t.Id)"
            $sha = [System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($keySrc))
            $detailJson += ",`"remember`":$(ConvertTo-DhJsonString (([BitConverter]::ToString($sha) -replace '-','').Substring(0,16).ToLowerInvariant()))"
        }
        # v2.5.2 - baseline markers (only when -Baseline was given): states by row index, old values of changed cells,
        # and the removed rows (declared columns only)
        if ($t.Contains('Baseline') -and $t.Baseline) {
            $bl = $t.Baseline
            $val = {
                param($v)
                if ($null -eq $v) { 'null' }
                elseif ($v -is [bool]) { $v.ToString().ToLowerInvariant() }
                elseif ($v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [decimal] -or $v -is [single]) { [System.Convert]::ToString($v, [System.Globalization.CultureInfo]::InvariantCulture) }
                elseif ($v -is [datetime]) { ConvertTo-DhJsonString ($v.ToString('yyyy-MM-dd HH:mm:ss')) }
                elseif ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) { ConvertTo-DhJsonString ((@($v | ForEach-Object { [string]$_ })) -join ', ') }
                else { ConvertTo-DhJsonString ([string]$v) }
            }
            $chg = (@($bl.Changes.Keys) | ForEach-Object {
                $c = $bl.Changes[$_]
                $f = '[' + ((@($c.Fields) | ForEach-Object { ConvertTo-DhJsonString $_ }) -join ',') + ']'
                $w = '{' + ((@($c.Was.Keys) | ForEach-Object { "$(ConvertTo-DhJsonString $_):$(& $val $c.Was[$_])" }) -join ',') + '}'
                "`"$_`":{`"s`":$(if ($c.State -eq 'new') { '"n"' } else { '"c"' }),`"f`":$f,`"w`":$w}"
            }) -join ','
            $declared = @($t.Columns | ForEach-Object { $_.Field })
            $rem = (@($bl.Removed) | ForEach-Object {
                $r = $_
                '{' + ((@($declared) | Where-Object { $r.Contains($_) } | ForEach-Object { "$(ConvertTo-DhJsonString $_):$(& $val $r[$_])" }) -join ',') + '}'
            }) -join ','
            $detailJson += ",`"baseline`":{`"label`":$(ConvertTo-DhJsonString $bl.Label),`"key`":$(ConvertTo-DhJsonString $bl.KeyField),`"new`":$([int]$bl.Counts.New),`"changed`":$([int]$bl.Counts.Changed),`"removed`":$([int]$bl.Counts.Removed),`"changes`":{$chg},`"removedRows`":[$rem]}"
        }
        if ($t.Contains('ColumnFit') -and $t.ColumnFit -eq 'Fixed') { $detailJson += ',"columnFit":"fixed"' }
        if ($t.Contains('ColumnMaxWidth') -and [int]$t.ColumnMaxWidth -ne 800) { $detailJson += ",`"columnMax`":$([int]$t.ColumnMaxWidth)" }
        if ($t.Contains('AllClearText') -and $t.AllClearText -and @($t.Data).Count -eq 0) {
            $detailJson += ",`"allClear`":$(ConvertTo-DhJsonString $t.AllClearText)"
        }
        [string]::Format(
            '{{"id":{0},"title":{1},"description":{2},"pageSize":{3},"multiSelect":{4},"filterable":{5},"pageable":{6},"exportFileName":{7},"columns":[{8}],"data":[{9}],"outLinks":[{10}],"charts":[{11}]{12}}}',
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
            $chartsJson,
            $detailJson
        )
    }

    $tablesConfigJson = "[$( $jsConfigBlocks -join ',' )]"

    # ---- Build summary JSON --------------------------------------------------------
    $summaryConfigJson = '[]'
    if ($Report.Contains('Summary') -and $Report.Summary.Count -gt 0) {
        # v2.2.0 - one serialiser for both strips (Private/ConvertTo-DhTileJson.ps1)
        $summaryItems = ($Report.Summary | ForEach-Object { ConvertTo-DhTileJson -Item $_ }) -join ','
        $summaryConfigJson = "[$summaryItems]"
    }

    # ---- Cross-reference lint (v2.1.4) -----------------------------------------
    # A TableId / LinkTableId / Action.TableId naming a table that does not
    # exist, or an unknown BlockType, renders as a silent no-op in the browser.
    # Warn here, against the finished report, whatever the declaration order.
    # Keep this list in sync with the switch below.
    $knownBlockTypes = @('html','collapsible','filtercardgrid','barchart','heatmap','rangebar','tabs',
                         'topologymap','statusgrid','summarystrip','eventfeed','linechart','bullet','piechart',
                         'findings','keyvalue','recordlist','treefilter','networkmap','treetable')
    foreach ($msg in (Test-DhReportLinks -Report $Report -KnownBlockTypes $knownBlockTypes)) {
        Write-Warning "Export-DhDashboard: $msg"
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
                    # v2.2.0 - value aggregation; emitted only when it is not the
                    # default row count, so a counting chart's JSON is unchanged
                    $aggJson = ''
                    if ($b.Contains('Aggregate') -and $b.Aggregate -and $b.Aggregate -ne 'count') {
                        $aggJson = ",`"valueField`":$(ConvertTo-DhJsonString $b.ValueField),`"aggregate`":$(ConvertTo-DhJsonString $b.Aggregate),`"unit`":$(ConvertTo-DhJsonString $b.Unit),`"decimals`":$([int]$b.Decimals)"
                    }
                    # v2.3.0 - bar colours, emitted only when set
                    $colorJson = ''
                    if ($b.Contains('Thresholds') -and @($b.Thresholds).Count -gt 0) {
                        $thItems = (@($b.Thresholds) | ForEach-Object {
                            $th = $_
                            $minPart = if ($th.Contains('Min')) { "`"min`":$(([double]$th.Min).ToString('R', [cultureinfo]::InvariantCulture))," } else { '' }
                            $maxPart = if ($th.Contains('Max')) { "`"max`":$(([double]$th.Max).ToString('R', [cultureinfo]::InvariantCulture))," } else { '' }
                            "{$minPart$maxPart`"class`":$(ConvertTo-DhJsonString $th.Class)}"
                        }) -join ','
                        $colorJson += ",`"thresholds`":[$thItems]"
                    }
                    if ($b.Contains('KeyClass') -and $b.KeyClass.Count -gt 0) {
                        $kcItems = (@($b.KeyClass.Keys) | ForEach-Object { "$(ConvertTo-DhJsonString ([string]$_)):$(ConvertTo-DhJsonString $b.KeyClass[$_])" }) -join ','
                        $colorJson += ",`"keyClass`":{$kcItems}"
                    }
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"tableId`":$(ConvertTo-DhJsonString $b.TableId),`"field`":$(ConvertTo-DhJsonString $b.Field),`"topN`":$($b.TopN),`"showCount`":$scStr,`"showPercent`":$spStr,`"clickFilters`":$cfStr$stacked$aggJson$colorJson,`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
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
                'rangebar' {
                    # v2.1.0 - min / avg / max floating bars on a shared 0-100 axis.
                    # Two modes: 'items' carries the finished rows; 'fromtable'
                    # carries the field names and the browser aggregates the
                    # table's FILTERED rows, so filtering live-recomputes ranges.
                    # Numbers are formatted InvariantCulture - a comma decimal
                    # separator in the host culture would emit invalid JSON.
                    $inv = [System.Globalization.CultureInfo]::InvariantCulture
                    $rbItemsJ = ''
                    if ($b.Items -and @($b.Items).Count -gt 0) {
                        $rbItemsJ = (@($b.Items) | ForEach-Object {
                            $ri = $_
                            "{`"name`":$(ConvertTo-DhJsonString $ri.Name),`"low`":$(([double]$ri.Low).ToString($inv)),`"high`":$(([double]$ri.High).ToString($inv)),`"min`":$(([double]$ri.Min).ToString($inv)),`"avg`":$(([double]$ri.Avg).ToString($inv)),`"max`":$(([double]$ri.Max).ToString($inv))}"
                        }) -join ','
                    }
                    $rbHighJ = if ($null -ne $b.High) { ([double]$b.High).ToString($inv) } else { 'null' }
                    $rbLowJ  = if ($null -ne $b.Low)  { ([double]$b.Low).ToString($inv)  } else { '0' }
                    $rbSdtJ  = ([bool]$b.ShowDataTable).ToString().ToLower()
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"mode`":$(ConvertTo-DhJsonString $b.Mode),`"items`":[$rbItemsJ],`"tableId`":$(ConvertTo-DhJsonString $b.TableId),`"categoryField`":$(ConvertTo-DhJsonString $b.CategoryField),`"valueField`":$(ConvertTo-DhJsonString $b.ValueField),`"highField`":$(ConvertTo-DhJsonString $b.HighField),`"lowField`":$(ConvertTo-DhJsonString $b.LowField),`"high`":$rbHighJ,`"low`":$rbLowJ,`"maxRows`":$($b.MaxRows),`"axisLabel`":$(ConvertTo-DhJsonString $b.AxisLabel),`"unit`":$(ConvertTo-DhJsonString $b.Unit),`"showDataTable`":$rbSdtJ,`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
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
                            # v2.3.0 - glyph / self / detail are emitted only when used, so grids
                            # without them export byte-identically to 2.2.0
                            $cx = ''
                            if ($cell.Contains('Glyph') -and $cell.Glyph)   { $cx += ',"glyph":' + (ConvertTo-DhJsonString $cell.Glyph) }
                            if ($cell.Contains('Self') -and $cell.Self)     { $cx += ',"self":true' }
                            if ($cell.Contains('Detail') -and $cell.Detail) { $cx += ',"detail":' + (ConvertTo-DhDetailJson $cell.Detail) }
                            "{`"row`":$(ConvertTo-DhJsonString $cell.Row),`"column`":$(ConvertTo-DhJsonString $cell.Column),`"status`":$(ConvertTo-DhJsonString $cell.Status),`"tooltip`":$(ConvertTo-DhJsonString $cell.Tooltip),`"linkTableId`":$(ConvertTo-DhJsonString $cell.LinkTableId),`"linkFilter`":$(ConvertTo-DhJsonString $cell.LinkFilter)$cx}"
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
                        # v2.2.0 - same serialiser as the top-of-page strip
                        $stItems = (@($b.Items) | ForEach-Object { ConvertTo-DhTileJson -Item $_ }) -join ','
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
                'findings' {
                    # v2.2.0 - Add-DhFindings
                    $fJson = (@($b.Findings) | ForEach-Object {
                        $f = $_
                        $affJson  = (@($f.Affected) | ForEach-Object { ConvertTo-DhJsonString $_ }) -join ','
                        $refsJson = (@($f.References) | ForEach-Object { "{`"label`":$(ConvertTo-DhJsonString $_.Label),`"url`":$(ConvertTo-DhJsonString $_.Url)}" }) -join ','
                        # v2.3.0 - facts / evidence / change / detail, emitted only when present so
                        # a finding without them exports byte-identically to 2.2.0
                        $fx = ''
                        if ($f.Contains('Facts') -and @($f.Facts).Count -gt 0) {
                            $fx += ',"facts":[' + ((@($f.Facts) | ForEach-Object { "{`"label`":$(ConvertTo-DhJsonString $_.Label),`"value`":$(ConvertTo-DhJsonString $_.Value),`"status`":$(ConvertTo-DhJsonString $_.Status)}" }) -join ',') + ']'
                        }
                        if ($f.Contains('Evidence') -and @($f.Evidence).Count -gt 0) {
                            $fx += ',"evidence":[' + ((@($f.Evidence) | ForEach-Object { "{`"object`":$(ConvertTo-DhJsonString $_.Object),`"value`":$(ConvertTo-DhJsonString $_.Value),`"status`":$(ConvertTo-DhJsonString $_.Status),`"note`":$(ConvertTo-DhJsonString $_.Note)}" }) -join ',') + ']'
                        }
                        if ($f.Contains('Change') -and $f.Change) { $fx += ',"change":' + (ConvertTo-DhJsonString $f.Change) }
                        if ($f.Contains('Detail') -and $f.Detail) { $fx += ',"detail":' + (ConvertTo-DhDetailJson $f.Detail) }
                        "{`"id`":$(ConvertTo-DhJsonString $f.Id),`"severity`":$(ConvertTo-DhJsonString $f.Severity),`"title`":$(ConvertTo-DhJsonString $f.Title),`"area`":$(ConvertTo-DhJsonString $f.Area),`"description`":$(ConvertTo-DhJsonString $f.Description),`"recommendation`":$(ConvertTo-DhJsonString $f.Recommendation),`"affected`":[$affJson],`"affectedCount`":$([int]$f.AffectedCount),`"affectedTableId`":$(ConvertTo-DhJsonString $f.AffectedTableId),`"affectedFilter`":$(ConvertTo-DhJsonString $f.AffectedFilter),`"references`":[$refsJson]$fx}"
                    }) -join ','
                    $expJson = (@($b.ExpandSeverity) | ForEach-Object { ConvertTo-DhJsonString $_ }) -join ','
                    $scJson  = ([bool]$b.ShowCounters).ToString().ToLower()
                    $fiJson  = ([bool]$b.Filterable).ToString().ToLower()
                    $acJson  = if ($b.Contains('AllClearText') -and $b.AllClearText) { ",`"allClear`":$(ConvertTo-DhJsonString $b.AllClearText)" } else { '' }
                    if ($b.Contains('Layout') -and $b.Layout -eq 'split') { $acJson += ",`"layout`":`"split`",`"maxEvidenceShown`":$([int]$b.MaxEvidenceShown)" }
                    elseif ($b.Contains('MaxEvidenceShown') -and [int]$b.MaxEvidenceShown -ne 50) { $acJson += ",`"maxEvidenceShown`":$([int]$b.MaxEvidenceShown)" }
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"groupBy`":$(ConvertTo-DhJsonString $b.GroupBy),`"showCounters`":$scJson,`"filterable`":$fiJson,`"expandSeverity`":[$expJson],`"maxAffectedShown`":$([int]$b.MaxAffectedShown),`"findings`":[$fJson]$acJson,`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                'recordlist' {
                    # v2.3.0 - Add-DhRecordList
                    $riJson = (@($b.Items) | ForEach-Object {
                        $r = $_
                        $mJson = (@($r.Metrics) | ForEach-Object { "{`"label`":$(ConvertTo-DhJsonString $_.Label),`"value`":$(ConvertTo-DhJsonString $_.Value),`"status`":$(ConvertTo-DhJsonString $_.Status)}" }) -join ','
                        "{`"id`":$(ConvertTo-DhJsonString $r.Id),`"title`":$(ConvertTo-DhJsonString $r.Title),`"subtitle`":$(ConvertTo-DhJsonString $r.Subtitle),`"status`":$(ConvertTo-DhJsonString $r.Status),`"metrics`":[$mJson],`"sections`":$(ConvertTo-DhSectionsJson $r.Sections)}"
                    }) -join ','
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"filterable`":$(([bool]$b.Filterable).ToString().ToLower()),`"openAll`":$(([bool]$b.OpenAll).ToString().ToLower()),`"items`":[$riJson],`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                'keyvalue' {
                    # v2.3.0 - Add-DhKeyValue
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"sections`":$(ConvertTo-DhSectionsJson @([ordered]@{ Kind = 'kv'; Title = ''; Columns = [int]$b.Columns; Items = @($b.Items) })),`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                'treetable' {
                    # v2.5.0 - Add-DhTreeTable. Flags, props and detail only when present; links as compact pairs.
                    $ttRows = (@($b.Rows) | ForEach-Object {
                        $tr = $_; $tx = ''
                        if (@($tr.Flags).Count)      { $tx += ',"flags":[' + ((@($tr.Flags) | ForEach-Object { ConvertTo-DhJsonString $_ }) -join ',') + ']' }
                        if ($tr.Properties.Count) { $tx += ',"props":[' + ((@($tr.Properties.Keys) | ForEach-Object { "{`"label`":$(ConvertTo-DhJsonString $_),`"value`":$(ConvertTo-DhJsonString $tr.Properties[$_])}" }) -join ',') + ']' }
                        if ($tr.Detail)              { $tx += ',"detail":' + (ConvertTo-DhDetailJson $tr.Detail) }
                        "{`"id`":$(ConvertTo-DhJsonString $tr.Id),`"parent`":$(ConvertTo-DhJsonString $tr.ParentId),`"type`":$(ConvertTo-DhJsonString $tr.Type),`"label`":$(ConvertTo-DhJsonString $tr.Label),`"status`":$(ConvertTo-DhJsonString $tr.Status)$tx}"
                    }) -join ','
                    $ttLinks = (@($b.Memberships) | ForEach-Object { "[$(ConvertTo-DhJsonString $_.GroupId),$(ConvertTo-DhJsonString $_.MemberId)]" }) -join ','
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"height`":$([int]$b.Height),`"openDepth`":$([int]$b.DefaultOpenDepth),`"maxPaths`":$([int]$b.MaxNestingPaths),`"rows`":[$ttRows],`"links`":[$ttLinks],`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                'networkmap' {
                    # v2.4.0 - Add-DhNetworkMap. Optional keys (tier, target, detail, link*) only when used.
                    $nmNodes = (@($b.Nodes) | ForEach-Object {
                        $nn = $_; $nx = ''
                        if ($null -ne $nn.Tier)   { $nx += ',"tier":' + [string]$nn.Tier }
                        if ($nn.Target)           { $nx += ',"target":true' }
                        if ($nn.Icon)             { $nx += ',"icon":' + (ConvertTo-DhJsonString $nn.Icon) }
                        if ($nn.Tooltip)          { $nx += ',"tooltip":' + (ConvertTo-DhJsonString $nn.Tooltip) }
                        if ($nn.Detail)           { $nx += ',"detail":' + (ConvertTo-DhDetailJson $nn.Detail) }
                        if ($nn.LinkTableId)      { $nx += ',"linkTableId":' + (ConvertTo-DhJsonString $nn.LinkTableId) }
                        if ($nn.LinkFilter)       { $nx += ',"linkFilter":' + (ConvertTo-DhJsonString $nn.LinkFilter) }
                        "{`"id`":$(ConvertTo-DhJsonString $nn.Id),`"label`":$(ConvertTo-DhJsonString $nn.Label),`"group`":$(ConvertTo-DhJsonString $nn.Group),`"status`":$(ConvertTo-DhJsonString $nn.Status),`"badges`":[$((@($nn.Badge) | ForEach-Object { ConvertTo-DhJsonString $_ }) -join ',')]$nx}"
                    }) -join ','
                    $nmEdges = (@($b.Edges) | ForEach-Object {
                        $ee = $_; $ex = ''
                        if ($ee.Label)       { $ex += ',"label":' + (ConvertTo-DhJsonString $ee.Label) }
                        if ($ee.Tooltip)     { $ex += ',"tooltip":' + (ConvertTo-DhJsonString $ee.Tooltip) }
                        if ($ee.LinkTableId) { $ex += ',"linkTableId":' + (ConvertTo-DhJsonString $ee.LinkTableId) }
                        if ($ee.LinkFilter)  { $ex += ',"linkFilter":' + (ConvertTo-DhJsonString $ee.LinkFilter) }
                        "{`"from`":$(ConvertTo-DhJsonString $ee.From),`"to`":$(ConvertTo-DhJsonString $ee.To),`"status`":$(ConvertTo-DhJsonString $ee.Status),`"style`":$(ConvertTo-DhJsonString $ee.Style),`"direction`":$(ConvertTo-DhJsonString $ee.Direction)$ex}"
                    }) -join ','
                    $nmGroups = (@($b.Groups) | ForEach-Object {
                        "{`"id`":$(ConvertTo-DhJsonString $_.Id),`"label`":$(ConvertTo-DhJsonString $_.Label),`"parent`":$(ConvertTo-DhJsonString $_.Parent),`"status`":$(ConvertTo-DhJsonString $_.Status)}"
                    }) -join ','
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"layout`":$(ConvertTo-DhJsonString $b.Layout),`"nodeWidth`":$([int]$b.NodeWidth),`"nodeHeight`":$([int]$b.NodeHeight),`"height`":$([int]$b.Height),`"legend`":$(([bool]$b.Legend).ToString().ToLower()),`"nodes`":[$nmNodes],`"edges`":[$nmEdges],`"groups`":[$nmGroups],`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                'treefilter' {
                    # v2.4.0 - Add-DhTreeFilter. Count is emitted only when given, Detail only when present.
                    $tnJson = (@($b.Nodes) | ForEach-Object {
                        $tn = $_
                        $tx = ''
                        if ($null -ne $tn.Count)  { $tx += ',"count":' + [string]$tn.Count }
                        if (@($tn.Flags).Count)   { $tx += ',"flags":[' + ((@($tn.Flags) | ForEach-Object { ConvertTo-DhJsonString $_ }) -join ',') + ']' }
                        if ($tn.Detail)           { $tx += ',"detail":' + (ConvertTo-DhDetailJson $tn.Detail) }
                        "{`"id`":$(ConvertTo-DhJsonString $tn.Id),`"parent`":$(ConvertTo-DhJsonString $tn.Parent),`"label`":$(ConvertTo-DhJsonString $tn.Label),`"path`":$(ConvertTo-DhJsonString $tn.Path),`"status`":$(ConvertTo-DhJsonString $tn.Status)$tx}"
                    }) -join ','
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"tableId`":$(ConvertTo-DhJsonString $b.TableId),`"pathField`":$(ConvertTo-DhJsonString $b.PathField),`"match`":$(ConvertTo-DhJsonString $b.Match),`"sep`":$(ConvertTo-DhJsonString $b.Separator),`"countFromTable`":$(([bool]$b.CountFromTable).ToString().ToLower()),`"height`":$([int]$b.Height),`"openDepth`":$([int]$b.DefaultOpenDepth),`"nodes`":[$tnJson],`"collapsible`":$bCollStr,`"defaultOpen`":$bDoStr}"
                }
                # An unknown BlockType emits nothing; Test-DhReportLinks above
                # has already warned about it.
                default { }
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
            # The banner's menu path and scope (-NavPath, or -NavGroup/-NavSubGroup resolved to a path).
            # Emitted only when the banner is bound to a path, so a global banner exports as before.
            $aNavJson = ''
            if ($a.Contains('NavSegments') -and @($a.NavSegments).Count -gt 0) {
                $aSegs = (@($a.NavSegments) | ForEach-Object { ConvertTo-DhJsonString ([string]$_) }) -join ','
                $aScope = if ($a.Contains('NavScope') -and $a.NavScope) { ([string]$a.NavScope).ToLowerInvariant() } else { 'exact' }
                $aNavJson = ",`"navPath`":[$aSegs],`"navScope`":$(ConvertTo-DhJsonString $aScope)"
            }
            "{`"id`":$(ConvertTo-DhJsonString $a.Id),`"severity`":$(ConvertTo-DhJsonString $a.Severity),`"message`":$(ConvertTo-DhJsonString $a.Message),`"icon`":$(ConvertTo-DhJsonString $a.Icon),`"dismissible`":$dismissStr,`"action`":$actionJson,`"navGroup`":$(ConvertTo-DhJsonString $ngStr),`"navSubGroup`":$(ConvertTo-DhJsonString $sgStr),`"collapsible`":$aCollStr,`"defaultOpen`":$aDoStr,`"title`":$(ConvertTo-DhJsonString $aTitleStr)$aNavJson}"
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

    # v2.2.0 - export libraries and print settings
    $libMode         = $ExportLibraries.ToLowerInvariant()
    $exportLibsJson  = Get-DhExportLibraryConfigJson -Mode $libMode
    $printCoverJson  = if ($Report.Contains('PrintCover') -and $Report.PrintCover) { 'true' } else { 'false' }
    $printConfigJson = "{`"maxRows`":$PrintMaxRows,`"cover`":$printCoverJson,`"title`":$(ConvertTo-DhJsonString $Report.Title)}"
    $js = [regex]::Replace($js, '/\*%%EXPORT_LIBS%%\*/\{[^\n]*?\}\};', { param($m) "$exportLibsJson;" })
    $js = [regex]::Replace($js, '/\*%%PRINT_CONFIG%%\*/\{[^\n]*?\};',  { param($m) "$printConfigJson;" })
    $embeddedLibs    = if ($libMode -eq 'embed') { Get-DhEmbeddedExportLibraries } else { '' }

    # ---- Build theme style tag (light primary, dark alternate, always embedded) --
    $primaryCss    = Get-DhThemeCss -Theme $theme
    $alternateCss  = Get-DhThemeCss -Theme $alternateTheme
    $themeStyleTag = @"
  <style id="theme-primary"   data-theme="$theme">$primaryCss</style>
  <style id="theme-alternate" data-theme="$alternateTheme" media="none">$alternateCss</style>
  <script>/* v2.1.4 - apply a saved theme before first paint (URL hash, then localStorage, then -ThemeMode). The runtime re-applies it and labels the toggle. */
  (function(){try{var m='',h=decodeURIComponent((location.hash||'').replace('#',''));if(h&&h.charAt(0)==='{'){var s=JSON.parse(h);if(s.theme==='light'||s.theme==='dark')m=s.theme;}if(!m){var l=window.localStorage?localStorage.getItem('dh-theme'):null;if(l==='light'||l==='dark')m=l;}if(!m){var d=document.documentElement.getAttribute('data-theme-mode');if(d==='dark')m='dark';else if(d==='auto'&&window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches)m='dark';}if(m==='dark'){document.getElementById('theme-primary').media='none';document.getElementById('theme-alternate').media='';}}catch(e){}})();</script>
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

    # v2.0.0 - the nav menu is no longer built here. The runtime derives the
    # whole tree from the data-navpath attributes on the sections themselves
    # (see Get-DhJsNav), which is what stops a menu strip describing a view the
    # content does not have. The 1.x code that assembled nav-group-tabs,
    # nav-subgroup pills and nav-subnav links server-side has been deleted.

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

    # ---- Navigation model (v2.0.0) ----------------------------------------------
    # Build the menu tree ONCE from the declared paths, then derive the opening
    # view from it. Both the strips/sidebar renderer and the server-stamped
    # panel-active classes read from this, so the menu can never describe a
    # different set of views than the content it reveals.
    $navSeq     = @{}    # "<kind>:<id>" -> declaration index
    foreach ($it in (Get-DhNavItem -Report $Report)) { $navSeq["$($it.Kind):$($it.Id)"] = $it.Seq }
    $navTree    = Get-DhNavTree -Report $Report
    $navInitial = Get-DhNavInitialPath -Tree $navTree
    $navDepth   = Get-DhNavDepth -Node $navTree

    # Depth policy. Exceeding it is a warning, not an error: the runtime handles
    # any depth, so refusing to export would punish the author for a layout
    # preference rather than a correctness problem.
    $navMaxDepth = if ($Report.Contains('NavMaxDepth') -and $Report.NavMaxDepth) { [int]$Report.NavMaxDepth } else { 3 }
    if ($navDepth -gt $navMaxDepth) {
        Write-Warning ("Export-DhDashboard: nav tree is $navDepth levels deep but -NavMaxDepth is $navMaxDepth. " +
                       "Rendering anyway. Raise -NavMaxDepth on New-DhDashboard to silence this.")
    }

    # Layout resolution (v2.0.0). Auto keeps the 1.x strips look up to 3 levels
    # and switches to the sidebar rail at 4+, where the strips stop fitting.
    # -NavAllLabel: the 'All' child of group nodes, read by the runtime when it builds the menu
    $navAllAttr = ''
    if ($Report.Contains('NavTree') -and @($Report.NavTree).Count) {
        $tree = @(foreach ($te in $Report.NavTree) { [ordered]@{ path = @(ConvertFrom-DhNavPath ([string]$te.Path)); label = [string]$te.Label; order = [int]$te.Order } })
        $navAllAttr += " data-navtree=`"$([System.Web.HttpUtility]::HtmlEncode((ConvertTo-Json -InputObject $tree -Compress -Depth 4)))`""
    }
    if ($Report.Contains('NavOverflow') -and $Report.NavOverflow -eq 'Wrap') { $navAllAttr += ' data-navoverflow="wrap"' }
    if ($Report.Contains('StrictNav') -and $Report.StrictNav) {
        $navAllAttr += ' data-navstrict="true"'
        foreach ($lint in @(Test-DhNavLint -Report $Report)) { Write-Warning "Export-DhDashboard: $lint" }
    }
    if ($Report.Contains('NavAllLabel') -and $null -ne $Report.NavAllLabel) {
        if ($Report.NavAllLabel -is [string]) {
            $navAllAttr += " data-navallall=`"$([System.Web.HttpUtility]::HtmlEncode([string]$Report.NavAllLabel))`""
        } else {
            $pairs = @(foreach ($k in $Report.NavAllLabel.Keys) { [ordered]@{ path = @(ConvertFrom-DhNavPath ([string]$k)); label = [string]$Report.NavAllLabel[$k] } })
            $navAllAttr += " data-navall=`"$([System.Web.HttpUtility]::HtmlEncode((ConvertTo-Json -InputObject $pairs -Compress -Depth 4)))`""
        }
    }
    $navLayoutPref = if ($Report.Contains('NavLayout') -and $Report.NavLayout) { $Report.NavLayout } else { 'Auto' }
    $navLayout = switch ($navLayoutPref) {
        'Strips'  { 'strips' }
        'Sidebar' { 'sidebar' }
        default   { if ($navDepth -ge 4) { 'sidebar' } else { 'strips' } }
    }
    Write-Verbose "Export-DhDashboard: nav depth $navDepth, layout '$navLayout' (pref '$navLayoutPref'), opening view '$($navInitial -join '/')'"

    # ---- Table section shells ---------------------------------------------------
    $tableSections = if ($Report.Tables.Count -gt 0) {
        Build-DhTableSections -Tables $Report.Tables -NavInitialPath $navInitial -NavSeq $navSeq -ExportLibraries $libMode
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
            # v2.0.0 - canonical nav attributes. The initial panel-active class is
            # stamped with the SAME predicate the runtime uses, so first paint and
            # first applyNav agree by construction.
            $bNav       = ConvertTo-DhNavAttr -Path @($b.NavSegments) -Scope $b.NavScope -InitialPath $navInitial `
                              -Seq ([int]$navSeq["Block:$($b.Id)"]) `
                              -Order $(if ($b.Contains('NavOrder')) { [int]$b.NavOrder } else { 0 }) `
                              -Label $(if ($b.Contains('NavLabel')) { [string]$b.NavLabel } else { '' })
            $bActive    = $bNav.Active
            $bSpanAttr  = if ($b.Contains('GridSpan') -and $b.GridSpan -ge 1 -and $b.GridSpan -le 12) { " style=`"grid-column:span $($b.GridSpan)`"" } else { '' }
            "<div class=`"block-section$bActive`" id=`"bsection-$($b.Id)`"$bNgAttr$bSgAttr$($bNav.Attr)$bSpanAttr><div id=`"block-$($b.Id)`"></div></div>"
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
<html lang="en" data-theme-mode="$themeMode">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="generator" content="DashHtml PowerShell Module v$moduleVersion">
  <meta name="report-theme" content="$themeFamily">
$autoRefreshTag
  <title>$([System.Web.HttpUtility]::HtmlEncode($Report.Title))</title>
$themeStyleTag
  <!-- v2.2.0: no blocking export-library tags here any more. -ExportLibraries Cdn
       loads them on first XLSX/PDF click (SRI-pinned); Embed inlines them at the end
       of <body>; None removes the two buttons. -->
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

  <nav class="report-nav" id="report-nav" role="navigation" aria-label="Report sections" data-navlayout="$navLayout" data-navdepth="$navDepth"$(if ($Report.Contains('NavBadge') -and $Report.NavBadge) { ' data-navbadge="true"' })$navAllAttr>
    <div class="nav-inner">
      $navLogoHtml
      $(if ($Report.Contains('NavTitle') -and $Report.NavTitle) { "<span class=`"nav-title`">$([System.Web.HttpUtility]::HtmlEncode($Report.NavTitle))</span>" })
      <div class="nav-divider"></div>
      <div class="nav-strip-top" id="nav-strips-top" role="tablist" aria-label="Sections"></div>
      $(if ($Report.Contains('Search') -and $Report.Search) { '<div class="nav-search" id="nav-search" role="search"><input type="search" id="nav-search-input" class="nav-search-input" placeholder="Search report  ( / )" aria-label="Search the report" role="combobox" aria-autocomplete="list" aria-expanded="false" aria-controls="nav-search-list" autocomplete="off"><div class="nav-search-list" id="nav-search-list" role="listbox" aria-label="Search results" hidden></div></div>' })
      <button class="nav-top-btn" id="btn-nav-top" type="button" title="Back to top">&#8679; Top</button>
      <button class="nav-utility-btn" id="btn-density-toggle" title="Toggle table row density">&#8862; Normal</button>
      <button class="nav-utility-btn" id="btn-theme-toggle" data-primary="$theme" data-alternate="$alternateTheme" title="Toggle theme">&#9790; Dark</button>
      <button class="nav-utility-btn" id="btn-print" type="button" title="Print, or save as PDF from the print dialog">&#128424; Print</button>
    </div>
    <div class="nav-strips" id="nav-strips"></div>
    <div class="nav-crumb" id="nav-crumb" style="display:none" aria-label="Breadcrumb"></div>
  </nav>
  <aside class="nav-sidebar" id="nav-sidebar" role="tree" aria-label="Report sections" style="display:none"></aside>

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
$embeddedLibs</body>
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










