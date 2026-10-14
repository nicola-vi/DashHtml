# DashHtml cheat sheet — cmdlets, widget choice, the `-Rag` shape

## 1 — The 22 public cmdlets

| Group | Cmdlet | Use when |
|---|---|---|
| **Foundation** | `New-DhDashboard` | Always first. Title, theme, info-field header. `-AutoRefresh '30s'/'5m'/'1h'` for wall displays. `-ThemeMode Light|Dark|Auto` (2.2) opening theme; `-PrintCover` (2.2) printed cover page. |
| | `Export-DhDashboard` | Always last. Writes the single HTML file. `-ExportLibraries Cdn` (default: XLSX/PDF libs load on first click) / `Embed` (inlined, works offline, +1.3 MB) / `None` (CSV only). `-PrintMaxRows` (default 200). Warns about dangling table references. |
| | `Get-DhTheme` | List themes / fetch raw CSS. Rarely needed in report scripts. |
| **Tables** | `Add-DhTable` | Tabular data — sortable, filterable, pageable, exportable. Cell types `text` / `progressbar` / `badge` / `sparkline` / `link` (2.2: `UrlField`, `LinkText`). `-Charts` `Type` = `donut` (default) / `pie` / `bar` (2.2, with `ValueField`/`Aggregate`/`TopN`). Cells never wrap; clipped values get a hover tooltip, and columns are drag-resizable (2.1.1+, min 40px since 2.1.2). |
| | `Set-DhTableLink` | Master-detail: clicking a row in table A filters table B. |
| **KPI strip** | `Add-DhSummary` | KPI tiles. Styles `tile` (default) / `bignumber` (hero) / `gauge` (semicircle SVG) / `verdict` (2.2: full-width overall assessment + severity chips from `Counts`). Per-tile `Action` makes a tile clickable. |
| **Charts** | `Add-DhBarChart` | Horizontal bars. `-Stacked -SeriesField 'X'` for the stacked variant. 2.2: `-ValueField F -Aggregate sum|avg|min|max [-Unit] [-Decimals]` to measure a value instead of counting rows. |
| | `Add-DhPieChart` | Pie / donut. Mode A (`-TableId` + `-Field`) or Mode B (`-Slices`) — never both. |
| | `Add-DhLineChart` | Time-series with axes. Multi-series, `-Filled` for area, `-TargetLine` for thresholds. |
| | `Add-DhBullet` | Actual vs target with RAG performance bands. The canonical SLA / headroom visual. |
| | `Add-DhRangeBar` | min–avg–max spread per category on a shared 0–100 axis; each row normalised against its own `High`. Colour encodes **position**, not category. |
| **2-D grids** | `Add-DhStatusGrid` | Rows × columns **categorical** RAG matrix (services × regions, hosts × probes). |
| | `Add-DhHeatmap` | Rows × columns **numeric** matrix with a sequential or diverging colour scale. |
| **Trees** | `Add-DhTopologyMap` | Parent-child tree (AD Forest→Domain→DC, vCenter→Cluster→Host). Cycle detection, pan/zoom. |
| **Assessment** | `Add-DhFindings` | (2.2) Audit findings: severity, description, recommendation, affected objects, "Show in table", reference links. Severity chips + text filter, `-GroupBy Area`, printed expanded. |
| **Events** | `Add-DhEventFeed` | Chronological severity-tagged log. |
| | `Add-DhAlertBanner` | Top-of-page strip for *current* conditions. Dismissible, optional Action button. |
| **Layout** | `Add-DhTabs` | Inline tabbed content **within one block**. Not page navigation. |
| | `Add-DhCollapsible` | Collapsible card grid or free-form content. |
| | `Add-DhHtmlBlock` | Free-form HTML in one of 6 RAG-coloured styles. |
| **Filtering** | `Add-DhGlobalFilter` | Page-level facet dropdown or date range. Re-filters **every** table carrying the field; AND-combined; persists in the URL. |
| | `Add-DhFilterCard` | Clickable filter-card grid; single or multi-select; filters one target table. |

## 2 — Decision tree

```
A single number that summarises everything        -> Add-DhSummary Style='bignumber'
Several numbers as a compact strip                -> Add-DhSummary (default 'tile')
A % towards a max (CPU, disk, SLA)                -> Add-DhSummary Style='gauge'  OR  Add-DhBullet
A KPI with "vs last period"                       -> Add-DhSummary item + Previous=X, TrendIsGood
A tiny per-tile trend visual                      -> Add-DhSummary item + Sparkline=@(...)
Different KPIs per panel                          -> Add-DhSummary -NavPath 'X' -NavScope Subtree

Categorical counts                                -> Add-DhBarChart
A value per category (avg lag, total GB, worst ms) -> Add-DhBarChart -ValueField X -Aggregate avg|sum|max
Counts split by another field                     -> Add-DhBarChart -Stacked -SeriesField 'Y'
Categorical proportions                           -> Add-DhPieChart ('donut' default, 'pie' solid)
Trend over time                                   -> Add-DhLineChart
Filled area trend                                 -> Add-DhLineChart -Filled
Always pair a time-series with a target line      -> Add-DhLineChart -TargetLine N -TargetLabel '...'

Actual vs target per entity                       -> Add-DhBullet
Spread of a metric per entity (min/avg/max)       -> Add-DhRangeBar
Entities of different scale, as % of own ceiling  -> Add-DhRangeBar -HighField 'Capacity'
Health matrix (categorical state)                 -> Add-DhStatusGrid
Numeric matrix with gradient encoding             -> Add-DhHeatmap
Parent-child hierarchy                            -> Add-DhTopologyMap
Chronological event log                           -> Add-DhEventFeed
"3 incidents open" top-of-page condition          -> Add-DhAlertBanner
Audit / assessment findings with remediation      -> Add-DhFindings  (+ Add-DhSummary Style='verdict')
Link to documentation per row                     -> Add-DhTable column CellType='link'; UrlField='DocUrl'
Readers without internet need XLSX/PDF            -> Export-DhDashboard -ExportLibraries Embed
Printable / PDF assessment                        -> New-DhDashboard -PrintCover; the Print button
Overview / Detail / Raw views of one scope        -> Add-DhTabs
Wall display that auto-reloads                    -> New-DhDashboard -AutoRefresh '5m'

Tabular data, sortable                            -> Add-DhTable
Drill-down (row click filters another table)      -> Add-DhTable + Set-DhTableLink
Per-row mini-chart inside a table                 -> Add-DhTable column CellType='sparkline'
Clickable KPI tile -> filtered table              -> Add-DhSummary item + Action=@{TableId=..;Filter=..}
```

### The two 2-D widgets

- Cells are one of a small set of **states** (`ok`/`warn`/`danger`/`info`/`nodata`)
  → `Add-DhStatusGrid` (discrete RAG palette).
- Cells are **numeric** values with a meaningful range → `Add-DhHeatmap`
  (`-ColorScale 'sequential'` low→high, or `'diverging'` for deviation from a
  centre).

**If your cells have a _range_, use Heatmap. If they have a _state_, use
StatusGrid.**

### The three per-entity bar widgets

- `Add-DhBullet` — one value against one target, RAG bands, bar anchored at the
  axis origin.
- `Add-DhRangeBar` — a min–max **spread** plus its average, all rows on one
  0–100 scale. The only one whose bar does not start at the origin, and the only
  one whose colour encodes **position** rather than category or state.
- `Add-DhBarChart` — a single proportional count per category.

## 3 — The `-Rag` shape

The modern way to declare threshold bands. Accepted on `Add-DhSummary` items
(especially gauge tiles), `Add-DhBullet` items, and `Add-DhTable` columns.

```powershell
$myRag = @{
    Green  = @{ Max = 70 }              # cell-ok      - value < 70
    Amber  = @{ Min = 70; Max = 90 }    # cell-warn    - 70 <= value < 90
    Red    = @{ Min = 90 }              # cell-danger  - value >= 90
    NoData = $true                      # OPT-IN: null/missing -> cell-nodata
}
```

- `Green`→`cell-ok`, `Amber`→`cell-warn`, `Red`→`cell-danger`. Hardcoded mapping.
- `Min`/`Max` are numeric; either may be omitted (open-ended).
- A band matches when `Min <= value < Max`. When several match, **the highest
  `Min` wins** — which makes the Min-only pattern intuitive.
- **`NoData = $true` is the only way to render nulls as `cell-nodata`.** Without
  it, missing values render blank in a table and **throw** on a gauge tile or
  `Add-DhBullet`.
- **Reversed metrics** (headroom, uptime — bigger is better): flip the bounds.
  ```powershell
  @{ Green=@{Min=30}; Amber=@{Min=15;Max=30}; Red=@{Max=15} }
  ```
- **`-Rag` wins over a legacy `Thresholds=` array** when both are supplied on
  the same item or column; the `Thresholds` value is discarded. Don't pass both.

Legacy `Thresholds=` still works and is the only shape that does **string**
matching:

```powershell
Thresholds = @(
    @{ Max=70;            Class='cell-ok'     }   # numeric: value < 70
    @{ Min=70; Max=90;    Class='cell-warn'   }
    @{ Min=90;            Class='cell-danger' }
    @{ Value='Connected'; Class='cell-ok'     }   # string, exact, case-insensitive
    @{ Value='Offline';   Class='cell-danger' }
)
```

## 4 — Tile styles

`Add-DhSummary -Items @(@{ Style='...'; ... })`:

| Style | Visual | Use for | Required | Most useful optional keys |
|---|---|---|---|---|
| `tile` (default) | 220px wide, ~1.6rem value | 4–8 KPIs in a row | `Label`, `Value` | `Icon`, `SubLabel`, `Class`, `Format`/`Locale`/`Decimals`/`Currency`, `Previous`+`TrendIsGood`+`DeltaFormat`, `Sparkline`+`SparklineStyle`/`Min`/`Max` |
| `bignumber` | Full-width, 2.4–3.6rem, optional `Caption` | The one headline metric | `Label`, `Value` | `Caption`, `Class`, plus all standard-tile keys |
| `gauge` | 140×80 semicircle SVG, RAG-coloured arc | "What % of capacity?" | `Label`, numeric `Value` | `Min` (0), `Max` (100), `Unit` (`'%'`, `'ms'`…), `Rag` |
| `verdict` (2.2) | Full-width, large text value + severity chips | The overall assessment ("Action required") | `Label`, `Value` | `Counts=@{critical=2;warning=5}` (high/medium/low aliases), `Caption`, `Icon`; colour follows the worst count unless `Class` is set |

**Tile size is intentional.** If tiles feel "too small", the user probably wants
`Style='bignumber'` for the headline, not a CSS change.

**`Icon` is decorative** — emoji or unicode glyph only. Bare ASCII letters render
as broken single characters.

## 5 — Themes

`New-DhDashboard -Theme <name>` — six families, each with embedded light **and**
dark variants and a runtime toggle in the nav bar: `Default`, `Azure`, `VMware`,
`Company`, `Grey`, `Rag`. Both variants ship in every file; the user's toggle
choice persists.

## 6 — Minimal working example

```powershell
Import-Module DashHtml
$r = New-DhDashboard -Title 'Infrastructure' -Theme 'Azure' -NavMaxDepth 3

Add-DhSummary -Report $r -Items @(
    @{ Label='Hosts';   Value=$hosts.Count;  Icon='🖥' }
    @{ Label='Critical'; Value=$crit.Count;  Icon='⚠'; Class='cell-danger' }
)

if ($vms.Count -gt 0) {
    Add-DhTable -Report $r -TableId 'vms' -Title 'Virtual Machines' -Data $vms `
                -NavPath 'Compute/vms' -NavLabel 'Virtual machines'
}

Export-DhDashboard -Report $r -OutputPath 'C:\Reports\infra.html'
```

Note the order: table **before** anything referencing `vms`, and the `.Count`
guard around it. In a ProjectPS report script the guard is
`$hasVms = Add-DhTableIfData @{ ... }` (PsReport.Core), and the chart goes inside
`if ($hasVms) { ... }`.

`Export-DhDashboard` takes `-OutputPath` (there is no `-Path`), `-Force` to
overwrite, `-OpenInBrowser`, and honours `-WhatIf` on its own.
