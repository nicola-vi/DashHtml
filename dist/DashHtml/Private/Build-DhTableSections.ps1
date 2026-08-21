function Build-DhTableSections {
    <#
    .SYNOPSIS  Returns the HTML markup for every table section.
               JS populates all data, charts, and column visibility at runtime.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Generic.List[hashtable]] $Tables
    )

    $sb = [System.Text.StringBuilder]::new()

    foreach ($t in $Tables) {
        $id       = $t.Id
        $titleEsc = [System.Web.HttpUtility]::HtmlEncode($t.Title)
        $ngAttr   = if ($t.NavGroup) { " data-navgroup=`"$([System.Web.HttpUtility]::HtmlEncode($t.NavGroup))`"" } else { '' }
        $sgAttr   = if ($t.Contains('NavSubGroup') -and $t.NavSubGroup) { " data-navsubgroup=`"$([System.Web.HttpUtility]::HtmlEncode($t.NavSubGroup))`"" } else { '' }
        $descHtml = if ($t.Description) {
            "        <p class=`"table-description`">$([System.Web.HttpUtility]::HtmlEncode($t.Description))</p>"
        } else { '' }

        $chartsHtml = if ($t.Contains('Charts') -and $t.Charts.Count -gt 0) {
            "      <div class=`"charts-container`" id=`"charts-$id`"></div>"
        } else { '' }

        # v1.5.1 — collapsible chrome for table sections. The outer <section>
        # stays as the nav target (showSubPanel toggles .panel-active on it),
        # but a clickable header bar wraps the table content so the user can
        # fold individual tables away.
        $collapsible = if ($t.Contains('Collapsible')) { [bool]$t.Collapsible } else { $false }
        $defaultOpen = if ($t.Contains('DefaultOpen')) { [bool]$t.DefaultOpen } else { $true }
        $tIcon       = if ($t.Contains('Icon') -and $t.Icon) { [System.Web.HttpUtility]::HtmlEncode($t.Icon) } else { '' }
        $secCls      = if ($collapsible) { ' table-section-collapsible' } else { '' }
        $bodyOpenCls = if ($defaultOpen) { ' open' } else { '' }
        $chev        = if ($defaultOpen) { '&#9662;' } else { '&#9656;' }
        $iconHtml    = if ($tIcon) { "<span class=`"table-section-icon`">$tIcon</span> " } else { '' }
        # v1.10.0 — 12-column grid span (only meaningful when the body is .report-grid)
        $spanAttr    = if ($t.Contains('GridSpan') -and $t.GridSpan -ge 1 -and $t.GridSpan -le 12) { " style=`"grid-column:span $($t.GridSpan)`"" } else { '' }

        if ($collapsible) {
            $headerHtml = @"
      <button class="table-section-toggle$bodyOpenCls" id="tsect-toggle-$id" type="button" aria-expanded="$($defaultOpen.ToString().ToLower())">
        <div class="table-section-header table-section-header-clickable">
          <h2 class="table-title">$iconHtml$titleEsc</h2>
$descHtml
        </div>
        <span class="table-section-chevron">$chev</span>
      </button>
      <div class="table-section-body$bodyOpenCls" id="tsect-body-$id">
"@
            $footerHtml = "      </div>"
        } else {
            $headerHtml = @"
      <div class="table-section-header">
        <h2 class="table-title">$iconHtml$titleEsc</h2>
$descHtml
      </div>
"@
            $footerHtml = ''
        }

        [void]$sb.AppendLine(@"
    <section class="table-section$secCls" id="section-$id"$ngAttr$sgAttr$spanAttr>
$headerHtml
$chartsHtml
      <div class="table-toolbar" id="toolbar-$id"
        <div class="toolbar-left">
          <div class="filter-wrap" id="filter-wrap-$id">
            <span class="filter-icon">&#9906;</span>
            <input type="text" class="filter-input" id="filter-$id" placeholder="Filter table&#8230;" autocomplete="off">
            <button class="filter-clear" id="filter-clear-$id" title="Clear filter">&#215;</button>
          </div>
        </div>
        <div class="toolbar-right">
          <span class="table-info" id="info-$id" role="status" aria-live="polite" aria-atomic="true"></span>
          <label class="pagesize-label">
            Rows
            <select class="pagesize-select" id="pagesize-$id"></select>
          </label>
          <button class="btn-clear-sel" id="clear-sel-$id" title="Clear selection" style="display:none">&#10005; Clear</button>
          <div class="col-toggle-wrap" id="col-toggle-wrap-$id">
            <button class="btn-col-toggle" id="btn-col-toggle-$id" title="Show / hide columns">&#9776; Columns</button>
            <div class="col-toggle-dropdown" id="col-toggle-dd-$id" style="display:none"></div>
          </div>
          <div class="export-group" title="Export currently filtered data">
            <button class="btn-export btn-csv"  id="exp-csv-$id"  title="Download filtered data as CSV">&#8595;&thinsp;CSV</button>
            <button class="btn-export btn-xlsx" id="exp-xlsx-$id" title="Download filtered data as Excel">&#8595;&thinsp;XLSX</button>
            <button class="btn-export btn-pdf"  id="exp-pdf-$id"  title="Download filtered data as PDF">&#8595;&thinsp;PDF</button>
          </div>
        </div>
      </div>
      <div class="table-wrapper">
        <table class="data-table" id="tbl-$id" role="grid" aria-label="$titleEsc">
          <thead><tr id="thead-$id"></tr></thead>
          <tbody id="tbody-$id"></tbody>
        </table>
      </div>
      <div class="table-pagination" id="paging-$id" role="navigation" aria-label="Pagination for $titleEsc"></div>
      <div class="link-badge" id="link-badge-$id" style="display:none" role="status">
        <span class="link-icon">&#9663;</span>
        <span class="link-text" id="link-text-$id"></span>
        <button class="link-clear" id="link-clear-$id" title="Remove link filter">&#215;</button>
      </div>
$footerHtml
    </section>
"@)
    }

    return $sb.ToString()
}
