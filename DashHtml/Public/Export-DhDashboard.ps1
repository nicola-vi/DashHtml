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
            "{`"field`":$(ConvertTo-DhJsonString $col.Field),`"label`":$(ConvertTo-DhJsonString $col.Label)$w$s$ct$pm$bl$it$fn$al$fo$lc$dc$cu$dp$rh$pf$agg$thJson}"
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
            "{`"label`":$(ConvertTo-DhJsonString $s.Label),`"value`":$val,`"icon`":$(ConvertTo-DhJsonString $s.Icon),`"subLabel`":$(ConvertTo-DhJsonString $s.SubLabel),`"class`":$(ConvertTo-DhJsonString $s.Class),`"format`":$(ConvertTo-DhJsonString $s.Format),`"locale`":$(ConvertTo-DhJsonString $s.Locale),`"decimals`":$dec,`"currency`":$(ConvertTo-DhJsonString $s.Currency)}"
        }) -join ','
        $summaryConfigJson = "[$summaryItems]"
    }

    # ---- Build blocks JSON ---------------------------------------------------------
    $blocksConfigJson = '[]'
    if ($Report.Contains('Blocks') -and $Report.Blocks.Count -gt 0) {
        $blockItems = ($Report.Blocks | ForEach-Object {
            $b = $_
            $bt = ConvertTo-DhJsonString $b.BlockType
            switch ($b.BlockType) {
                'html' {
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"icon`":$(ConvertTo-DhJsonString $b.Icon),`"content`":$(ConvertTo-DhJsonString $b.Content),`"style`":$(ConvertTo-DhJsonString $b.Style)}"
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
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"icon`":$(ConvertTo-DhJsonString $b.Icon),`"defaultOpen`":$openStr,`"badge`":$($b.Badge),`"cards`":[$cardsJson],`"content`":$(ConvertTo-DhJsonString $b.Content)}"
                }
                'filtercardgrid' {
                    $fcJson = ($b.Cards | ForEach-Object {
                        $c = $_
                        $cnt = if ($null -eq $c.Count) { 'null' } else { [string]$c.Count }
                        "{`"label`":$(ConvertTo-DhJsonString $c.Label),`"value`":$(ConvertTo-DhJsonString $c.Value),`"subLabel`":$(ConvertTo-DhJsonString $c.SubLabel),`"count`":$cnt,`"icon`":$(ConvertTo-DhJsonString $c.Icon)}"
                    }) -join ','
                    $mf  = $b.MultiFilter.ToString().ToLower()
                    $sc  = $b.ShowCount.ToString().ToLower()
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"targetTableId`":$(ConvertTo-DhJsonString $b.TargetTableId),`"filterField`":$(ConvertTo-DhJsonString $b.FilterField),`"multiFilter`":$mf,`"showCount`":$sc,`"cards`":[$fcJson]}"
                }
                'barchart' {
                    $spStr = $b.ShowPercent.ToString().ToLower()
                    $scStr = $b.ShowCount.ToString().ToLower()
                    $cfStr = $b.ClickFilters.ToString().ToLower()
                    "{`"blockType`":$bt,`"id`":$(ConvertTo-DhJsonString $b.Id),`"title`":$(ConvertTo-DhJsonString $b.Title),`"tableId`":$(ConvertTo-DhJsonString $b.TableId),`"field`":$(ConvertTo-DhJsonString $b.Field),`"topN`":$($b.TopN),`"showCount`":$scStr,`"showPercent`":$spStr,`"clickFilters`":$cfStr}"
                }
            }
        }) -join ','
        $blocksConfigJson = "[$blockItems]"
    }

    # ---- Inject config into JS engine --------------------------------------------
    $js = (Get-DhJsContent) -replace '/\*%%TABLES_CONFIG%%\*/\[\]',  $tablesConfigJson
    $js = $js               -replace '/\*%%SUMMARY_CONFIG%%\*/\[\]', $summaryConfigJson
    $js = $js               -replace '/\*%%BLOCKS_CONFIG%%\*/\[\]',  $blocksConfigJson

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

    # Nav logo (smaller thumbnail) and nav links
    $navLogoHtml = if ($Report.LogoBase64) {
        "<img src=`"data:$logoMime;base64,$($Report.LogoBase64)`" class=`"nav-logo`" alt=`"Logo`">"
    } else { '' }

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

        # All grouped table links go in subnav
        $subnavLinks = ($Report.Tables | Where-Object { $_.NavGroup } | ForEach-Object {
            $tid = $_.Id
            $tn  = [System.Web.HttpUtility]::HtmlEncode($_.Title)
            $g   = [System.Web.HttpUtility]::HtmlEncode($_.NavGroup)
            "<a class=`"nav-link`" href=`"#`" data-table=`"$tid`" data-group=`"$g`">$tn<span class=`"nav-badge`" data-table=`"$tid`"></span></a>"
        }) -join "`n        "

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

    # ---- Table section shells ---------------------------------------------------
    $tableSections = Build-DhTableSections -Tables $Report.Tables

    # Build block section HTML shells
    $blockSectionsHtml = ''
    if ($Report.Contains('Blocks') -and $Report.Blocks.Count -gt 0) {
        $blockSectionsHtml = ($Report.Blocks | ForEach-Object {
            $b          = $_
            $bNg        = if ($b.NavGroup) { $b.NavGroup } else { '' }
            $bNgAttr    = if ($bNg) { " data-navgroup=`"$([System.Web.HttpUtility]::HtmlEncode($bNg))`"" } else { '' }
            $bActive    = if (-not $bNg) { ' panel-active' } else { '' }
            "<div class=`"block-section$bActive`" id=`"bsection-$($b.Id)`"$bNgAttr><div id=`"block-$($b.Id)`"></div></div>"
        }) -join "`n"
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
  <title>$([System.Web.HttpUtility]::HtmlEncode($Report.Title))</title>
$themeStyleTag
  <!-- Export libraries (cdnjs - internet required for XLSX/PDF export) -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js" crossorigin="anonymous"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js" crossorigin="anonymous"></script>
  <!-- Bridge: jsPDF 2.x UMD exposes window.jspdf.jsPDF but AutoTable looks for window.jsPDF -->
  <script>if(window.jspdf&&window.jspdf.jsPDF&&!window.jsPDF){window.jsPDF=window.jspdf.jsPDF;}</script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf-autotable/3.8.2/jspdf.plugin.autotable.min.js" crossorigin="anonymous"></script>
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
    $subnavHtml
  </nav>

  <main class="report-body">
    <div class="report-summary" id="report-summary"></div>
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
