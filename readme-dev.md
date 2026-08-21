# DashHtml — Developer / AI-assistant Reference

> **Audience:** An LLM-based coding assistant (or a developer in a hurry) that needs to use DashHtml correctly without reading the full README. Pass this file as context at the start of a session to skip the discovery phase.

> **Module version this file describes:** **1.10.4** (2026-08-07)

---

## 1 — What DashHtml is, in 60 seconds

DashHtml is a **PowerShell 7+ module** that generates **self-contained interactive HTML dashboards**. One module = one HTML file. The HTML has CSS + JS + data all embedded — no companion files, no server, no build step.

**Lifecycle of every dashboard:**

```
                                                                      ┌──────────────┐
                                                                      │  *.html      │
                                                                      │ (self-       │
New-DhDashboard ──▶ Add-DhX … ──▶ Add-DhTable ──▶ Set-DhTableLink ──▶ │  contained;  │
                                                                      │  CSS+JS+data │
                                                  Export-DhDashboard──▶ embedded)   │
                                                                      └──────────────┘
```

**Mental model:**
- `New-DhDashboard` returns an `[ordered]` hashtable — **the report object**. Every other cmdlet mutates it.
- Order matters: **declare tables BEFORE any block that references them** (filter cards, bar charts, pie charts, status-grid link cells, summary tile actions). This is the single most common mistake.
- `Export-DhDashboard` is the **last** call. It serialises everything to HTML.

---

## 2 — Cmdlet cheat sheet (20 cmdlets, grouped by role)

| Group | Cmdlet | Use when… |
|---|---|---|
| **Foundation** | `New-DhDashboard` | Always first. Sets title, theme, info-fields header. **`-AutoRefresh '30s'/'5m'/'1h'`** (v1.4.2) emits a `<meta http-equiv="refresh">` for wall displays. |
| | `Export-DhDashboard` | Always last. Writes the HTML file. |
| | `Get-DhTheme` | List available themes / fetch raw CSS. Rarely needed in user scripts. |
| **Tables** | `Add-DhTable` | Tabular data. Sortable, filterable, pageable, exportable. Cell types: `text` / `progressbar` / `badge` / `sparkline`. |
| | `Set-DhTableLink` | Master-detail wiring: clicking a row in table A filters table B. |
| **KPI strip** | `Add-DhSummary` | Top-of-page KPI tiles (and per-NavGroup strips in v1.4.1+). Tile styles: `tile` (default compact) / `bignumber` (hero) / `gauge` (semicircle SVG). v1.4.2: per-tile `Action` makes any tile clickable. |
| **Charts** | `Add-DhBarChart` | Horizontal bars. Pass `-Stacked -SeriesField 'X'` for stacked variant (v1.4+). |
| | `Add-DhPieChart` | Pie / donut. Two modes: Mode A (from a table column) or Mode B (explicit `-Slices`). |
| | `Add-DhLineChart` | Time-series with axes. Multi-series + optional `-Filled` (area) + optional `-TargetLine` for thresholds (the spec's mandatory pairing per §7.4). |
| | `Add-DhBullet` | Actual-vs-target with performance bands. Canonical SLA / headroom visualisation. |
| **2-D grids** *(v1.5)* | `Add-DhStatusGrid` | Rows × columns **RAG** matrix (categorical). Services × regions, hosts × probes. |
| | `Add-DhHeatmap` *(v1.5)* | Rows × columns **numeric** matrix with sequential / diverging colour scale. Time-of-day load, percentile distributions, deviation from target. |
| **Trees** *(v1.5)* | `Add-DhTopologyMap` *(v1.5)* | Parent-child tree (AD Forest→Domain→DC, vCenter→Cluster→Host). Recursive subtree-width SVG layout; cycle detection. **v1.5.2:** `-AutoFitWidth` measures the widest label and grows `NodeWidth` so FQDN labels stop truncating; every node also gets a styled hover tooltip (falls back to the full `Label`). |
| **Events / alerts** | `Add-DhEventFeed` | Chronological severity-tagged log. Pair with KPI tiles as Row-5 audit trail. |
| | `Add-DhAlertBanner` | Top-of-page strip for *current* conditions. Dismissible, with optional Action button. v1.4.2: `-NavGroup` / `-NavSubGroup` bind to a single panel. |
| **Layout** | `Add-DhTabs` *(v1.5)* | Inline tabbed content block. Local pivot inside one block; distinct from `-NavGroup` (page-level). |
| **Global filter** *(v1.9)* | `Add-DhGlobalFilter` | Page-level facet dropdown or from/to date range in a bar above the body. Re-filters EVERY table that has the field at once; charts re-aggregate; AND-combined; persists in URL. Tables lacking the field are unaffected. |
| | `Add-DhFilterCard` | Clickable filter card grid; single or multi-select; filters a target table. |
| | `Add-DhHtmlBlock` | Free-form HTML in one of 6 RAG-coloured styles. |
| | `Add-DhCollapsible` | Collapsible card grid or free-form content. |

---

## 3 — Decision tree

When a user describes what they want, map onto:

```
A single number that summarises everything           → Add-DhSummary Style='bignumber'
Several numbers as a compact strip                   → Add-DhSummary (default 'tile' style)
A % towards a max (CPU, disk, SLA)                   → Add-DhSummary Style='gauge'  OR  Add-DhBullet
A KPI with "vs last period" change                   → Add-DhSummary item: + Previous=X, TrendIsGood
A tiny per-tile trend visual                         → Add-DhSummary item: + Sparkline=@(...)
Different KPIs per nav-panel                         → Add-DhSummary -NavGroup 'X'    (v1.4.1+)

Categorical counts                                   → Add-DhBarChart
Categorical counts split by another field            → Add-DhBarChart -Stacked -SeriesField 'Y'
Categorical proportions                              → Add-DhPieChart  (style: 'donut' default, 'pie' for solid)
Trend over time                                      → Add-DhLineChart
Filled area trend                                    → Add-DhLineChart -Filled
"Always pair time-series with target line"           → Add-DhLineChart -TargetLine N -TargetLabel '...'

Actual vs target per entity                          → Add-DhBullet
Health matrix (rows × columns, categorical state)    → Add-DhStatusGrid
Numeric matrix with gradient encoding                → Add-DhHeatmap        (v1.5)
Parent-child hierarchy (AD forest, vCenter)          → Add-DhTopologyMap    (v1.5)
Chronological event log                              → Add-DhEventFeed
"3 incidents open" type top-of-page condition        → Add-DhAlertBanner
Several views of the same scope, one visible at a    → Add-DhTabs            (v1.5)
   time (Overview / Detail / Raw)
Wall-display dashboard that auto-reloads             → New-DhDashboard -AutoRefresh '5m'

Tabular data, sortable                               → Add-DhTable
Drill-down (click row → filter another table)        → Add-DhTable + Set-DhTableLink
Per-row mini-chart inside a table                    → Add-DhTable column: CellType='sparkline'
Make a KPI tile clickable (jump to a filtered table) → Add-DhSummary item: + Action=@{TableId='...'; Filter='...'}
```

### Choosing between the two 2-D widgets

```
Cells are one of a small set of states (ok/warn/danger/info/nodata)
  → Add-DhStatusGrid              (categorical, colour palette = RAG)

Cells are numeric values with a meaningful range
  → Add-DhHeatmap                 (gradient, continuous)
    -ColorScale 'sequential'        — single-direction (low → high)
    -ColorScale 'diverging'         — centred (negative ←0→ positive, deviation from target)
```

---

## 4 — The `-Rag` shape (critical to know — used everywhere)

Modern way to declare threshold bands. Accepted on `Add-DhSummary` items (esp. gauge tiles), `Add-DhBullet` items, `Add-DhTable` columns. Wins over the legacy `Thresholds=@(...)` array when both are supplied.

```powershell
$myRag = @{
    Green  = @{ Max = 70 }              # cell-ok      — value < 70
    Amber  = @{ Min = 70; Max = 90 }    # cell-warn    — 70 ≤ value < 90
    Red    = @{ Min = 90 }              # cell-danger  — value ≥ 90
    NoData = $true                      # OPT-IN: null/missing → cell-nodata
}
```

**Semantics:**
- `Green` → `cell-ok`, `Amber` → `cell-warn`, `Red` → `cell-danger`. Hardcoded mapping.
- `Min`/`Max` are numeric bounds; either or both may be omitted (open-ended).
- Matching rule: a band matches when `Min ≤ value < Max`. When multiple bands match, **the highest `Min` wins**. This makes the Min-only pattern (`@{Min=0;...}, @{Min=70;...}, @{Min=90;...}`) intuitive.
- `NoData=$true` opts in to a 4th `cell-nodata` state for null/missing values. **Without** this opt-in, missing values are left blank (or throw for `Add-DhSummary` gauge tiles and `Add-DhBullet`).
- **Reversed metrics** (headroom, uptime — bigger is better): just flip the bounds:
  ```powershell
  @{ Green=@{Min=30}; Amber=@{Min=15;Max=30}; Red=@{Max=15} }
  ```

**Legacy `Thresholds=` shape still works**, both numeric and string:
```powershell
Thresholds = @(
    @{ Max=70;             Class='cell-ok'     }   # numeric: value < 70
    @{ Min=70; Max=90;     Class='cell-warn'   }
    @{ Min=90;             Class='cell-danger' }
    @{ Value='Connected';  Class='cell-ok'     }   # string match (exact, case-insensitive)
    @{ Value='Offline';    Class='cell-danger' }
)
```

---

## 5 — NavGroup binding (two-tier navigation)

DashHtml has a built-in two-tier nav system. Mechanically:

1. Any cmdlet that supports `-NavGroup` puts its block into the named group.
2. Cmdlets WITHOUT `-NavGroup` are "flat" — visible on every panel.
3. The exported HTML has a primary tab bar (one tab per NavGroup) with a sub-nav strip showing the tables in the active group.
4. `-NavSubGroup` adds a third pill level filtering within a group.

| Cmdlet | Supports NavGroup? |
|---|---|
| `Add-DhTable` | ✅ |
| `Add-DhSummary` | ✅ (v1.4.1+ — per-panel KPI strip) |
| `Add-DhBarChart` | ✅ |
| `Add-DhPieChart` | ✅ |
| `Add-DhLineChart` | ✅ |
| `Add-DhBullet` | ✅ |
| `Add-DhStatusGrid` | ✅ |
| `Add-DhHeatmap` *(v1.5)* | ✅ |
| `Add-DhTopologyMap` *(v1.5)* | ✅ |
| `Add-DhTabs` *(v1.5)* | ✅ |
| `Add-DhEventFeed` | ✅ |
| `Add-DhFilterCard` | ✅ |
| `Add-DhHtmlBlock` | ✅ |
| `Add-DhCollapsible` | ✅ |
| `Add-DhAlertBanner` | ✅ (v1.4.2+ — without `-NavGroup`, the banner stays page-global as in 1.4.x) |

**`Add-DhSummary` is a special case** (v1.4.1):
- Without `-NavGroup`: classic singleton at the top of `<main>`, visible on every panel.
- With `-NavGroup`: stored as a `summarystrip` block; visible only when its panel is active.
- Both can coexist: one global strip + many per-panel strips.

---

## 6 — Tile-style decision matrix

`Add-DhSummary -Items @(@{Style='X'; ...})`:

| Style | Visual | Use for | Mandatory keys | Optional keys (most useful) |
|---|---|---|---|---|
| `'tile'` (default) | 220 px wide, 1.6 rem value, compact strip | 4–8 KPIs in a row | `Label`, `Value` | `Icon`, `SubLabel`, `Class`, `Format`/`Locale`/`Decimals`/`Currency`, `Previous`+`TrendIsGood`+`DeltaFormat`, `Sparkline`+`SparklineStyle`+`SparklineMin`+`SparklineMax` |
| `'bignumber'` | Full-width row, 2.4–3.6 rem value, optional `Caption` line | The headline metric ("Current SLA — 99.97%") | `Label`, `Value` | `Caption`, `Class`, plus all the standard-tile keys above |
| `'gauge'` | 140×80 semicircle SVG, threshold-coloured arc, central numeric readout | "What % of capacity?" | `Label`, `Value` (numeric) | `Min` (default 0), `Max` (default 100), `Unit` (`'%'`/`'ms'`/etc), `Rag` (RAG bands drive the arc colour) |

**Important:** `Icon` is **decorative** — it expects an emoji, unicode glyph, or HTML. Don't pass bare ASCII letters as placeholders; they render as ugly single characters.

---

## 7 — Idioms & ready-to-paste recipes

### 7.1 — Minimal one-table dashboard
```powershell
Import-Module DashHtml -Force
$data = @(
    [PSCustomObject]@{ Name='alpha'; Status='OK'   ; CPU=42 }
    [PSCustomObject]@{ Name='beta';  Status='Warn' ; CPU=88 }
)
$report = New-DhDashboard -Title 'Inventory'
Add-DhTable -Report $report -TableId 'items' -Title 'Items' -Data $data
Export-DhDashboard -Report $report -OutputPath '.\out.html' -Force -OpenInBrowser
```

### 7.2 — KPI strip with deltas and sparklines
```powershell
Add-DhSummary -Report $report -Items @(
    @{ Style='bignumber'; Label='Current SLA'; Value='99.97%'
       Caption='Target 99.9% — met'; Class='cell-ok' }

    @{ Label='Active users';  Value=231; Previous=219; TrendIsGood=$true
       Format='number'
       Sparkline=@(180,195,210,219,225,228,231); SparklineStyle='line' }

    @{ Label='Errors (24h)'; Value=4; Previous=12; TrendIsGood=$true   # fewer errors = good
       Class='cell-warn'; Sparkline=@(12,10,8,6,5,4,4); SparklineStyle='bars' }

    @{ Style='gauge'; Label='CPU'; Value=68; Max=100; Unit='%'
       Rag=@{ Green=@{Max=70}; Amber=@{Min=70;Max=90}; Red=@{Min=90} } }
)
```

### 7.3 — Bullet chart (actual vs target with RAG bands)
```powershell
$latencyRag = @{ Green=@{Max=50}; Amber=@{Min=50;Max=80}; Red=@{Min=80} }

Add-DhBullet -Report $report -Id 'auth-latency' -Title 'LDAP Bind Time' -Items @(
    @{ Label='DC01'; Value=42; Target=50; Max=120; Unit='ms'; Rag=$latencyRag }
    @{ Label='DC02'; Value=68; Target=50; Max=120; Unit='ms'; Rag=$latencyRag }
    @{ Label='DC03'; Value=92; Target=50; Max=120; Unit='ms'; Rag=$latencyRag }
)
```

### 7.4 — Time-series with target line (the spec's mandatory pattern)
```powershell
$hours = @('00:00','04:00','08:00','12:00','16:00','20:00','24:00')

Add-DhLineChart -Report $report -Id 'cpu-trend' -Title 'CPU (24h)' `
    -XAxis $hours `
    -Series @(
        @{ Label='Avg'; Values=@(42,38,55,67,71,68,52); Class='cell-ok' }
    ) `
    -TargetLine 70 -TargetLabel 'Warning threshold' `
    -YAxisMin 0 -YAxisMax 100 -YAxisUnit '%'
```

### 7.5 — Status grid (services × regions)
```powershell
Add-DhStatusGrid -Report $report -Id 'service-health' -Title 'Service Health' `
    -RowLabel 'Service' -ColumnLabel 'Region' `
    -Rows    @('Auth','Billing','Search') `
    -Columns @('us-east','us-west','eu-west') `
    -Cells @(
        @{ Row='Auth';    Column='us-east'; Status='ok' }
        @{ Row='Auth';    Column='eu-west'; Status='warn'; Tooltip='latency spike' }
        @{ Row='Billing'; Column='us-east'; Status='danger'
           LinkTableId='incidents'; LinkFilter='billing' }
    )
```
Cells you don't declare render as a neutral dashed state. `LinkTableId`/`LinkFilter` is optional per cell.

### 7.6 — Multi-panel dashboard with per-NavGroup KPI strips
```powershell
# Global summary (visible everywhere)
Add-DhSummary -Report $report -Items @(
    @{ Style='bignumber'; Label='Overall SLA'; Value='99.96%'; Class='cell-ok' }
)

# Identity-panel summary
Add-DhSummary -Report $report -NavGroup 'Identity' -Title 'Identity KPIs' -Items @(
    @{ Label='Active users';  Value=231 }
    @{ Label='Failed logons'; Value=842; Previous=920; TrendIsGood=$true }
)

# Infrastructure-panel summary (different metrics)
Add-DhSummary -Report $report -NavGroup 'Infrastructure' -Title 'Cluster KPIs' -Items @(
    @{ Style='gauge'; Label='Cluster CPU'; Value=68; Max=100; Unit='%' }
)

# Other blocks bind to the same NavGroup
Add-DhTable      -Report $report -TableId 'users'      ... -NavGroup 'Identity'
Add-DhStatusGrid -Report $report -Id      'svc-health' ... -NavGroup 'Infrastructure'
```

### 7.7 — Sparkline cells in a table
```powershell
$rows = @(
    [PSCustomObject]@{ Host='srv-01'; Cpu24h=@(30,42,38,55,67,71,68,52); }
    [PSCustomObject]@{ Host='srv-02'; Cpu24h=@(80,85,90,95,92,88,84,82); }
    [PSCustomObject]@{ Host='srv-03'; Cpu24h=$null; }   # renders em-dash
)
Add-DhTable -Report $report -TableId 'srv' -Title 'Servers' -Data $rows -Columns @(
    @{ Field='Host';   Label='Host' }
    @{ Field='Cpu24h'; Label='CPU 24h'; Align='right'
       CellType='sparkline'; SortBy='max'; SparklineStyle='area' }
)
```
Cell value must be a **numeric array**. `SortBy`: `'last'` (default) / `'avg'` / `'max'` / `'min'` / `'sum'` controls how clicking the header sorts rows.

### 7.8 — Event feed (chronological audit trail)
```powershell
Add-DhEventFeed -Report $report -Id 'recent' -Title 'Recent events (24h)' `
    -MaxItems 50 -GroupBy 'Severity' `
    -Events @(
        @{ Timestamp='2026-05-22 14:32'; Severity='critical'; Source='DC01'
           Message='Replication failure to DC03' }
        @{ Timestamp='2026-05-22 14:18'; Severity='warning';  Source='DC02'
           Message='LDAP bind time > 80 ms' }
        @{ Timestamp='2026-05-22 13:55'; Severity='info';     Source='vSphere'
           Message='vMotion: VM-027 → ESXi-04' }
    )
```

### 7.9 — Top-of-page alert banner
```powershell
Add-DhAlertBanner -Report $report -Id 'top-alert' `
    -Severity 'critical' -Icon '!' -Dismissible `
    -Message '3 critical incidents open in the last 24h' `
    -Action @{ Label='View incidents'; TableId='incidents'; Filter='critical' }

# v1.4.2+ — bind to a single nav panel
Add-DhAlertBanner -Report $report -Id 'eu-alert' `
    -Severity 'warning' -Message 'EU site failover in progress' `
    -NavGroup 'Infrastructure'   # visible only when the Infrastructure tab is active
```
Severity: `info` / `ok` / `warning` / `critical`. The `Action` button either navigates to a registered table (with optional filter text) or opens an external URL.

### 7.10 — Clickable KPI tile (v1.4.2+)
```powershell
Add-DhSummary -Report $report -Items @(
    @{ Label='Open incidents'; Value=4; Class='cell-warn'
       Action=@{ Label='View incidents'; TableId='incidents'; Filter='critical' } }

    @{ Style='bignumber'; Label='Status'; Value='Degraded'
       Action=@{ Label='Open status page'; Url='https://status.example.com' } }
)
```
`Action` keys: `Label` (used as `title=""` tooltip), then exactly one of `TableId` (+ optional `Filter`) or `Url`. Works on all tile styles. Keyboard accessible (Enter / Space).

### 7.11 — Auto-refresh for wall displays (v1.4.2+)
```powershell
$report = New-DhDashboard -Title 'NOC Wall' -Theme Default -AutoRefresh '5m'
```
Emits a `<meta http-equiv="refresh" content="300">`. Accepts `'30s'`, `'5m'`, `'1h'`, or plain seconds. Pair with a scheduled task that regenerates the file slightly more often than the refresh interval.

### 7.12 — Heatmap (v1.5+)
```powershell
$days  = @('Mon','Tue','Wed','Thu','Fri','Sat','Sun')
$hours = @('00','03','06','09','12','15','18','21')
$cells = foreach ($d in $days) {
    foreach ($h in $hours) {
        @{ Row=$d; Column=$h; Value=(Get-Random -Min 10 -Max 95) }
    }
}
Add-DhHeatmap -Report $report -Id 'load' -Title 'Cluster load — last week' `
    -Rows $days -Columns $hours -Cells $cells `
    -RowLabel 'Day' -ColumnLabel 'Hour (UTC)' `
    -ColorScale 'sequential' -Unit '%' -ShowValues
```
Cell value must be **numeric**. `-ColorScale` is `'sequential'` (single hue ramp) or `'diverging'` (centred — good for deviation-from-target views; pair with symmetric `-Min` / `-Max`).

### 7.13 — Topology map (v1.5+)
```powershell
Add-DhTopologyMap -Report $report -Id 'ad-forest' -Title 'AD Forest' `
    -Direction 'vertical' `
    -Nodes @(
        @{ Id='forest';  Label='contoso.com';     Parent=$null;    Status='ok' }
        @{ Id='dom-hq';  Label='hq.contoso.com';  Parent='forest'; Status='ok' }
        @{ Id='dom-eu';  Label='eu.contoso.com';  Parent='forest'; Status='warn' }
        @{ Id='dc-hq01'; Label='DC-HQ01';         Parent='dom-hq'; Status='ok' }
        @{ Id='dc-eu01'; Label='DC-EU01';         Parent='dom-eu'; Status='warn'
           Tooltip='Replication lag 4m'
           LinkTableId='incidents'; LinkFilter='dc-eu01' }   # clickable → jump
    )
```
`Parent=$null` marks a root (multiple roots OK — forest layout). Cycles throw. Each node can carry `Status` (paints the box via RAG palette), `Icon`, `Badge`, `Tooltip`, and `LinkTableId`/`LinkFilter` for drill-down.

**v1.5.2 — wide-fan trees with long labels.** Default `NodeWidth=140` truncates FQDN labels once icon + badge eat into the box. Two combined tools fix it:

- `-AutoFitWidth` measures the widest label / icon / badge combination via a hidden `<canvas>` and grows `NodeWidth` to fit (capped by `-AutoFitMaxWidth`, default `360`).
- `-Direction 'horizontal'` puts depth on the X axis so wide bottom rows stack vertically instead of competing for horizontal space.
- Every node now gets a **styled hover tooltip** (single body-level overlay positioned by JS — CSS pseudo-elements don't render on SVG). When `Tooltip` is omitted, the full `Label` is used as fallback, so truncation never hides identifying info.

**Idiom for wide-fan trees** — introduce intermediate "category" nodes between the parent and its homogeneous leaves so the tree reads as an architecture diagram rather than a row of badges:

```powershell
# 1 farm → 1 site → 4 categories → many leaves
Add-DhTopologyMap -Report $report -Id 'farm-topology' -Title 'Farm Topology' `
    -Direction 'horizontal' -NodeWidth 220 -AutoFitWidth `
    -Nodes @(
        @{ Id='farm';     Label='CAI-DC';                     Parent=$null;     Status='ok'; Icon='🏗️'; Badge='Farm' }
        @{ Id='site';     Label='EGSI-RAS-BRK01';             Parent='farm';    Status='ok'; Icon='🌐';  Badge='Site' }
        @{ Id='cat-brk';  Label='Brokers';                    Parent='site';    Status='ok'; Icon='🔀';  Badge='2'    }
        @{ Id='cat-gw';   Label='Gateways';                   Parent='site';    Status='ok'; Icon='🛡️'; Badge='2'    }
        @{ Id='cat-pool'; Label='RDS Host Pools';             Parent='site';    Status='ok'; Icon='📦';  Badge='5'    }
        @{ Id='brk-01';   Label='EGSI-RAS-BRK01.egsi.local';  Parent='cat-brk'; Status='ok'; Icon='🔀';  Badge='Primary'
           Tooltip='EGSI-RAS-BRK01.egsi.local — role Primary, agent OK'; LinkTableId='brokers' }
        # … etc.
    )
```

### 7.14 — Inline tabs (v1.5+)
```powershell
Add-DhTabs -Report $report -Id 'fleet' -Title 'Fleet views' -Tabs @(
    @{ Title='Overview';    Icon='O'; Content='<p>Summary text...</p>'; Active=$true }
    @{ Title='Per-host';    Icon='H'; Content='<table>...</table>' }
    @{ Title='Raw payload'; Icon='R'; Content='<pre>{ ... }</pre>' }
)
```
`Content` is raw HTML (same policy as `Add-DhHtmlBlock`). Distinct from `-NavGroup`: tabs partition one block's content, NavGroup partitions the whole page. Full W3C tablist pattern with arrow-key nav.

---

## 8 — Critical gotchas (AI should always check these)

1. **Declaration order.** Tables MUST be declared before any block that references them by `TableId` (`Add-DhFilterCard`, `Add-DhBarChart`, `Add-DhPieChart` Mode A, `Set-DhTableLink`, `Add-DhAlertBanner -Action`, `Add-DhStatusGrid` cell `LinkTableId`, summary tile `Action`). Wrong order = silent no-op.

2. **`Icon` is decorative.** Pass an emoji (`🖥`, `⚠`, `🔒`, `🌐`) or unicode glyph, or omit. **Don't pass bare ASCII letters like `'X'` or `'B'`** — they render as ugly single characters in the corner.

3. **Standard tile size is intentional.** `Style='tile'` (default) value typography is ~1.6 rem. If the user feels tiles are "too small", they probably want `Style='bignumber'` for headlines.

4. **`-Rag` wins over `Thresholds=`.** When both are supplied on the same item / column, the `Rag` shape is used and the legacy `Thresholds` array is discarded. Don't supply both unless you understand this.

5. **`Rag.NoData=$true` is the only way to render null values as `cell-nodata`.** Without it, null cells render blank (table) or throw (`Add-DhSummary` gauge tile, `Add-DhBullet`).

6. **`Add-DhBarChart` click-filter is single-series only.** When `-Stacked` is set, `-ClickFilters` is a no-op (stacked bars have no single value to filter by).

7. **Sparkline cells need ARRAYS.** `[PSCustomObject]@{ Cpu24h=@(30,42,38) }` — not strings, not comma-separated text. Anything non-array renders as em-dash.

8. **`Add-DhPieChart` Mode A vs Mode B are mutually exclusive.** Pass either `-TableId`+`-Field` OR `-Slices @(...)`, not both. Validation throws when both are present.

9. **`Add-DhStatusGrid` row/column membership is checked.** Every cell's `Row` and `Column` must appear in the `-Rows` / `-Columns` axis arrays. Typos throw — they don't silently miss.

10. **NavGroup case-sensitive matching at render time.** `-NavGroup 'Identity'` and `-NavGroup 'identity'` are two different groups. Pick one casing and use it consistently.

11. **Locale-safe number parsing.** v1.4 cmdlets all parse via `InvariantCulture` (regression fix from v1.4.0 — `it-IT` was treating `92330.25` as `9233025`). When extending the module, never use `[double]::TryParse([string], [ref])` without explicitly passing `InvariantCulture`.

12. **JS helpers are module-scope (v1.4.1+).** When extending the embedded JS, put new helpers at module scope (not nested inside `renderSummary` or similar) so cross-block renderers can call them. The bullet + line chart renderers used to silently break because of nested helpers — fixed in 1.4.1. **Since 1.8.0** the runtime JS is split across `Get-DhJsCore/Blocks/Nav/Table/Boot.ps1` (concatenated by `Get-DhJsContent`) — it is still ONE shared scope after assembly, so a helper defined in `Get-DhJsCore` is callable from `Get-DhJsBlocks`, etc. Put new block renderers in `Get-DhJsBlocks.ps1`.

13. **Banners can be per-panel since v1.4.2.** `Add-DhAlertBanner -NavGroup '...' [-NavSubGroup '...']` binds the banner to a single panel. Without those params, the banner stays page-global (the legacy default). Bound banners disappear when their group is not active.

14. **Heatmap vs StatusGrid — don't confuse them.** Heatmap cells carry a **numeric** `Value`; the colour is interpolated. StatusGrid cells carry a **categorical** `Status` (`ok`/`warn`/`danger`/`nodata`/`info`); the colour is discrete RAG. If your cells naturally have a *range*, use Heatmap. If they have a *state*, use StatusGrid.

15. **TopologyMap rejects cycles AND missing parents.** Every node's `Parent` must either be `$null`/`''` (root) or match the `Id` of another supplied node. Self-parents (`Id='a'; Parent='a'`) and cycles (`A→B→A`) both throw at declaration time. Forests (multiple `Parent=$null` roots) are allowed.

15a. **TopologyMap — wide-fan + long labels is the classic bad render** (since 1.5.2). If any single node has more than ~5 children and the children carry FQDN labels (host names, AD object DNs), the default 140 px node width truncates every label. Three fixes, applied together:

   1. `-Direction 'horizontal'` — depth on the X axis, leaves stack vertically.
   2. `-AutoFitWidth` — JS measures the widest label and grows `NodeWidth` to fit (cap with `-AutoFitMaxWidth`, default `360`).
   3. **Insert intermediate "category" nodes.** A site with 10 children mixing brokers / gateways / pools / providers reads poorly. Group them under category nodes (`'Brokers'`, `'Gateways'`, `'RDS Host Pools'`, `'VDI Providers'`) — same data, but the tree now looks like a real architecture diagram. Skip a category node when its bucket is empty to avoid dead branches.

   Always set `Tooltip` on leaf nodes to the full identifying string (FQDN + role + status). Even with auto-fit, a hover tooltip is the user's escape hatch when the box can't show everything.

16. **Tabs vs NavGroup — different scopes.** `Add-DhTabs` partitions content **within one block** — the user toggles between local views of the same scope. `-NavGroup` partitions the **whole page** — the user navigates between unrelated dashboards via the top tab bar. Don't try to use Tabs as page-level navigation.

17. **AutoRefresh is a browser `<meta refresh>`, not live data.** `New-DhDashboard -AutoRefresh '5m'` makes the browser reload the same HTML file every 5 minutes. To actually update the data, schedule a job that re-runs your dashboard script slightly more frequently than the refresh interval.

18. **Four cmdlets accept raw HTML — use `-AllowHtml:$false` for untrusted data.** `Add-DhHtmlBlock -Content`, `Add-DhTabs` per-tab `Content`, `Add-DhCollapsible -Content`, and `Add-DhAlertBanner -Message` are injected via `innerHTML` by design (so callers can embed lists, links, formatted markup). Since **1.6.0** each takes an `-AllowHtml` switch:
    - `-AllowHtml:$true` (**current default**) — raw markup, as in v1.x. Use for HTML you authored.
    - `-AllowHtml:$false` — the cmdlet HTML-encodes the content for you (`[System.Net.WebUtility]::HtmlEncode`). Use for any externally-sourced value (AD attribute, ticket title, log line, hostname).

    If you pass HTML-looking content without an explicit `-AllowHtml`, a **deprecation warning** fires: the default flips to `$false` (encode) in **2.0.0**. Silence it by choosing a value explicitly. The encode/warn logic is centralised in the private helper `ConvertTo-DhSafeContent` (+ `Test-DhLooksLikeHtml`) — all four cmdlets route through it. Every other text field in the module — table cells, summary labels, topology labels, status grid cells, KPI captions — is HTML-encoded automatically and is safe to pass user data into. (As of **1.5.3** colour values on `Add-DhPieChart` / `Add-DhLineChart` and `Url` fields on `Action` hashtables are validated for you and throw on hostile input; you do not have to sanitise those.)

19. **`-Pageable:$false` shows ALL rows (since 1.7.0), and virtualises above 150.** Before 1.7.0 a non-pageable table wrongly rendered only the first `pageSize` (15) rows with no way to reach the rest. Now it renders every filtered row. For large data this is windowed: only the rows near the scroll viewport are in the DOM, inside a `max-height:70vh` sticky-header scroll container (`.table-virtual`). The **default paginated path is unchanged** and never virtualises — DOM rows are always capped at `pageSize`. If you relied on `-Pageable:$false` truncating to 15 rows (you shouldn't have — it was a bug), set an explicit small `-PageSize` with paging instead.

20. **Topology is interactive by default (since 1.7.0).** `Add-DhTopologyMap` renders pan/zoom/collapse in a fixed viewport. Pass `-Interactive:$false` for the old static scale-to-fit (e.g. for print). The renderer auto-fits via `ResizeObserver` and stops auto-fitting once the user pans/zooms — important because topology often lives in a `-NavGroup` panel that is `display:none` (zero width) until its tab is shown; the observer fires and fits when it becomes visible.

21. **Global filters do NOT reach summary tiles (since 1.9.0).** `Add-DhGlobalFilter` re-filters tables and table-derived charts (`GlobalFilter.matchRow` runs in each `TableEngine._getFiltered`). It does **not** touch `Add-DhSummary` KPI tiles — those are computed once from the full dataset and never re-aggregate. If a user wants filter-reactive KPIs, drive them from a filtered table or scope them per panel with `Add-DhSummary -NavGroup`. This is a known limitation, documented in the 1.10.1 CHANGELOG.

22. **`CellType='progressbar'` label is HTML-encoded (fixed 1.10.1).** All table cell types now escape user values; before 1.10.1 the progressbar label was an unescaped `innerHTML` XSS sink. Every table cell is safe to pass user data into — you do not need to pre-encode.

23. **CSV / XLSX / PDF export always covers the FULL filtered set**, never just the visible page or the virtualised window. `_exportRows()` returns `_getFiltered()` (all rows matching the active filters, in sort order), so a user looking at page 1 of 20 — or a virtualised window of 40 rows — still downloads every matching row. The PDF header prints `Rows: N` as a cue. This is intentional; if you want a page-limited export, filter the data first. (Since 1.10.2 the XLSX sheet name is sanitised — `: \ / ? * [ ]` stripped, blank → `Sheet1` — so a table title with those characters no longer makes the Excel export silently fail.)

24. **`ConvertTo-DhJsonString`: the order of the escape passes is load-bearing — do NOT fold them into one regex.** Carriage return is *dropped*, not escaped. So `'<' CR '/script>'` only collapses into a literal `</script>` **partway through** escaping, and is then caught by the `</` → `<\/` pass that runs after the CR pass. Verified: ``"a<`r/script>b"`` → `"a<\/script>b"`. A single regex over the *original* string never sees that `</` and would emit it raw — a script breakout. The nine passes look redundant and are the obvious thing to "optimise"; they are not. Since 1.10.3 they are *skipped* (not merged) via an `IndexOfAny` fast path when the string provably needs no escaping — that is the safe way to make this faster, and it already bought ~40× on the marginal cost of `Export-DhDashboard`. Same reasoning rules out `ConvertTo-Json` / `System.Text.Json`, which also drop the `</` and U+2028/29 handling.

25. **Never pass an options object to `localeCompare` inside a comparator (fixed 1.10.4).** `String.localeCompare(x, undefined, {sensitivity:'base'})` makes the engine **re-resolve collation settings on every call**. In the table sort comparator that ran ~270,000 times for a 19,011-row table and blocked the main thread for **5.6 seconds** on a single header click. Build **one** `Intl.Collator` and reuse `collator.compare` — measured ~15× on its own, ~33× combined with precomputing sort keys outside the comparator (`parseFloat` was also running O(n log n) times instead of O(n)). Ordering is safe to preserve across the swap because the spec defines `localeCompare(y, loc, opts)` as `new Intl.Collator(loc, opts).compare(x, y)`, and `Array#sort` is stable. Note this class of bug is **invisible to functional tests** — the slow code sorted perfectly correctly — so it is pinned at source level in the Pester suite instead.

---

## 9 — Theme selection

`New-DhDashboard -Theme <name>` selects from six families, each with embedded light + dark variants (toggle at runtime via the nav-bar button):

| Family | Use when… |
|---|---|
| `Default` | General-purpose, blue accents, system UI font. |
| `Azure` | Microsoft Azure / 365 branding (Segoe UI, Azure blue). |
| `VMware` | VMware-ecosystem dashboards (Inter font, VMware green). |
| `Grey` | Neutral / muted, no brand colour. |
| `Company` | Crimson + Montserrat. Marketing / executive reports. |
| `Rag` (v1.4) | **Strict Office/Excel RAG palette** (`#375623` / `#7F4B00` / `#9C0006` / `#595959`). Use when audit / compliance / finance audience needs spreadsheet parity. |

All themes define `--cell-ok-fg`, `--cell-warn-fg`, `--cell-danger-fg`, `--cell-nodata-fg` (v1.4) + bg variants. Use these as CSS variables; never hardcode colours.

---

## 10 — Module file structure (when reading or editing source)

```
DashHtml/
├── DashHtml/                          ← module root (matches manifest RootModule)
│   ├── DashHtml.psd1                  ← manifest: ModuleVersion, FunctionsToExport
│   ├── DashHtml.psm1                  ← loader: dot-sources Private then Public
│   ├── Public/                        ← every file = one exported cmdlet
│   │   ├── New-DhDashboard.ps1
│   │   ├── Export-DhDashboard.ps1
│   │   ├── Get-DhTheme.ps1
│   │   ├── Add-DhTable.ps1
│   │   ├── Set-DhTableLink.ps1
│   │   ├── Add-DhSummary.ps1
│   │   ├── Add-DhBarChart.ps1
│   │   ├── Add-DhPieChart.ps1
│   │   ├── Add-DhLineChart.ps1
│   │   ├── Add-DhBullet.ps1
│   │   ├── Add-DhStatusGrid.ps1
│   │   ├── Add-DhHeatmap.ps1          ← v1.5
│   │   ├── Add-DhTopologyMap.ps1      ← v1.5
│   │   ├── Add-DhTabs.ps1             ← v1.5
│   │   ├── Add-DhEventFeed.ps1
│   │   ├── Add-DhAlertBanner.ps1
│   │   ├── Add-DhFilterCard.ps1
│   │   ├── Add-DhHtmlBlock.ps1
│   │   └── Add-DhCollapsible.ps1
│   └── Private/                       ← internal helpers
│       ├── Get-DhJsContent.ps1        ← assembler: concatenates the JS fragments below
│       ├── Get-DhJsCore.ps1           ← JS: config/state/URL/format/threshold/theme/tiles/alerts
│       ├── Get-DhJsBlocks.ps1         ← JS: every block renderer (charts, grids, topology, tabs…)
│       ├── Get-DhJsNav.ps1            ← JS: two/three-tier navigation
│       ├── Get-DhJsTable.ps1          ← JS: the TableEngine (sort/filter/page/virtualise/export)
│       ├── Get-DhJsBoot.ps1           ← JS: DOMContentLoaded bootstrap
│       ├── Get-DhCssBase.ps1          ← structural CSS shared by every theme
│       ├── Get-DhCssDefaultLight.ps1  ← per-theme :root variables (light)
│       ├── Get-DhCssDefaultDark.ps1   ← per-theme :root variables (dark)
│       ├── Get-DhCss{Azure,VMware,Grey,Company,Rag}{Light,Dark}.ps1
│       ├── Get-DhThemeCss.ps1         ← combines theme + base CSS
│       ├── ConvertTo-DhRagThresholds.ps1   ← Rag → Min/Max/Class normaliser
│       ├── ConvertTo-DhJsonString.ps1
│       └── Build-DhTableSections.ps1
├── Tests/
│   └── DashHtml.Tests.ps1             ← Pester 5; 397 tests at 1.10.4; covers every cmdlet + Examples smoke test
├── Examples/
│   ├── AD-Dashboard.ps1               ← Active Directory ops, spec §4.1 layout
│   ├── vSphere-Dashboard.ps1          ← vSphere ops, spec §4.2 layout
│   ├── Multi-Panel-Dashboard.ps1      ← Per-NavGroup KPI strips (v1.4.1)
│   ├── Invoke-Demo-DashHtml.ps1       ← Big showcase: every cmdlet
│   └── v1.5-Widgets-Showcase.ps1      ← Tabs / Heatmap / TopologyMap demo (v1.5)
├── docs/
│   ├── KPI_Dashboard_Specification_v2.docx   ← the IT-infra KPI spec that drove v1.4/1.5
│   ├── KPI_Dashboard_Addendum_A_v2.docx      ← HTML-email digest modality (v1.6+ candidate)
│   └── v1.4-plan.md                   ← the v1.4 design plan + rationale
├── Build.ps1                          ← validate manifest + run Pester + zip dist
├── Build-DhReference.ps1              ← regenerate DashHtml-Reference.html
├── DashHtml-Reference.html            ← full API reference (auto-generated)
├── Install.ps1                        ← copy module to $env:PSModulePath
├── README.md                          ← user-facing docs
├── CHANGELOG.md
└── dist/
    ├── DashHtml/                      ← staged for publish
    └── DashHtml-v<version>.zip
```

---

## 11 — Extending the module (when implementing a new cmdlet)

The recurring pattern for a new block-type cmdlet:

1. **Create `Public/Add-DhX.ps1`** with `param`, validation, and a final `$Report.Blocks.Add([ordered]@{ BlockType='xxx'; Id=...; ... })`.
2. **Add the cmdlet name to `FunctionsToExport`** in `DashHtml/DashHtml.psd1`.
3. **In `Export-DhDashboard.ps1`**, find the `switch ($b.BlockType)` and add a new `'xxx'` case that serialises the block hashtable to JSON.
4. **In `Private/Get-DhJsBlocks.ps1`**, add a `case 'xxx': renderX(container, block); break;` in the `switch (block.blockType)` inside `renderBlocks()`, and define the `renderX` function at **module scope** (not nested). (Since 1.8.0 the block renderers live in this fragment; shared helpers are in `Get-DhJsCore.ps1`.)
5. **Add CSS** to `Private/Get-DhCssBase.ps1`. Reuse existing tokens: `--cell-ok-fg` / `--cell-warn-fg` / `--cell-danger-fg` / `--cell-nodata-fg` for RAG colouring, `--chart-1`..`--chart-8` for categorical colours, `--accent-primary` for the brand accent.
6. **Write Pester tests** in `Tests/DashHtml.Tests.ps1` — at minimum, validation paths + a smoke test that checks the emitted HTML.

**Reusable helpers already at module-level JS scope:**
- `esc(s)` — HTML-escape a value
- `cssVar(name, fallback)` — read a CSS custom property
- `chartPalette()` — array of 8 chart colours from `--chart-1..8`
- `classToAccent(cls)` / `classToAccentBg(cls)` — map `cell-ok|warn|danger|nodata` to its CSS var
- `pickThresholdClass(value, thresholds)` — match a value against an array of `{min,max,class}` bands (highest-Min-wins)
- `SPARK.build(series, opts)` — inline SVG sparkline (line/area/bars)
- `DELTA.build(item)` — trend arrow + delta text for tiles
- `buildTile(item)` — tile renderer (dispatches to standard/bignumber/gauge)
- `buildPieSvg(entries, opts)` — pie / donut SVG
- `fillStrip(container, items, opts)` — populate a container with tiles, with optional collapsible chrome
- `URLState.save() / load()` — persist active panel / filters / dismissed banners to URL hash
- `_resolveCssColor(cssExpr)` *(v1.5)* — resolve any CSS colour expression (`var(--chart-1)`, `#abc`, `rgba(...)`) to an `[r,g,b]` triple. Used by `renderHeatmap` to interpolate colours that follow the active theme.
- `_lerp3(a, b, t)` / `_rgbStr([r,g,b])` *(v1.5)* — linear interpolate two RGB triples / format a triple back to `rgb(r,g,b)`.

**Reusable helpers in PowerShell:**
- `ConvertTo-DhJsonString` — JSON-string-encode a PowerShell value
- `ConvertTo-DhRagThresholds` — convert a `Rag` hashtable to a `Thresholds` array + `NoData` flag

---

## 12 — Testing

```powershell
# Full Pester run
Invoke-Pester -Path .\Tests -Output Detailed

# Build (validate manifest + run tests + stage dist + zip)
.\Build.ps1

# Regenerate the API reference HTML
.\Build-DhReference.ps1
```

When writing tests, follow the existing pattern in `Tests/DashHtml.Tests.ps1` — one `Describe` block per cmdlet, with:
- BeforeEach: `$script:report = New-DhDashboard -Title 'T'`
- Storage tests (checks `$report['Blocks'][0].SomeField`)
- Validation tests (`{ Add-DhX ... bad-input ... } | Should -Throw`)
- HTML round-trip test (`Should -Match` on the emitted HTML/JSON text)

Tests run quickly (~30 s for 397 tests at 1.10.4; the Examples smoke test adds ~20 s of subprocess runs). The full suite must always pass before declaring work complete.

---

## 13 — Anti-patterns (don't do these)

| Bad | Why | Do this instead |
|---|---|---|
| `Icon='X'`, `Icon='Y'` | Renders as a bare letter glyph — looks broken | `Icon='🖥'` / `Icon='⚠'` / omit it |
| `Add-DhBarChart` *before* its target `Add-DhTable` | Silent no-op (table doesn't exist yet) | Declare tables first; then everything that references them |
| Hardcoding `#1B6B35` in CSS or markup | Breaks when user switches theme | Use `var(--cell-ok-fg)` |
| `Class='cell-ok'` AND `Rag=@{...}` on the same tile/cell | Rag wins, Class is ignored — confusing | Pick one |
| `Style='gauge'; Value=$null` without `Rag.NoData=$true` | Throws | Add `Rag.NoData=$true` to allow null |
| Mix `-Filled` with very dense lines (>10 series) | Visual mush | Use `-Filled` for 1–3 series; multi-series uses plain lines |
| `Sparkline=@()` (empty array) | No-op — no chart rendered, no error | Just omit the key |
| Mutating `$report` after `Export-DhDashboard` | The cmdlet has already serialised — changes lost | Add everything *before* the export |
| Re-exporting to the same file without `-Force` | `Write-Warning` and returns without writing | Use `-Force` |
| Hand-rolling threshold arrays for the same RAG bands across multiple items | Verbose, error-prone, repetitive | Define `$rag = @{Green=...; Amber=...; Red=...}` once, reuse via `Rag=$rag` |

---

## 14 — One worked example (paste-and-run)

A realistic 100-line dashboard exercising the v1.4 widget set:

```powershell
#Requires -Version 7.0
Import-Module DashHtml -Force

$report = New-DhDashboard -Title 'Service Operations' `
    -Subtitle 'Last 24h' -Theme Rag `
    -InfoFields @(
        @{ Label='Environment'; Value='Production' }
        @{ Label='Generated';   Value=(Get-Date -Format 'yyyy-MM-dd HH:mm') }
    )

# ── Reusable RAG bands ─────────────────────────────────────────────────
$utilRag = @{ Green=@{Max=70}; Amber=@{Min=70;Max=90}; Red=@{Min=90}; NoData=$true }

# ── Row 1: KPI strip (mixes bignumber + gauges + standard tiles) ──────
Add-DhSummary -Report $report -Title 'Service health' -Items @(
    @{ Style='bignumber'; Label='Current SLA'; Value='99.96%'
       Caption='Target 99.9% — met'; Class='cell-ok' }
    @{ Label='Hosts up';     Value='8/8'; Class='cell-ok' }
    @{ Label='VMs running';  Value=247;   Previous=242; TrendIsGood=$true; Format='number' }
    @{ Style='gauge'; Label='Cluster CPU';  Value=68;  Max=100; Unit='%'; Rag=$utilRag }
    @{ Style='gauge'; Label='Cluster Mem';  Value=82;  Max=100; Unit='%'; Rag=$utilRag }
    @{ Label='Active alarms'; Value=3; Previous=1; TrendIsGood=$false; Class='cell-warn' }
)

# ── Row 1.5: Top-of-page alert ────────────────────────────────────────
Add-DhAlertBanner -Report $report -Id 'top' `
    -Severity 'warning' -Icon '!' -Dismissible `
    -Message '3 alarms active — esxi-04 memory pressure, datastore latency, snapshot age > 30d.'

# ── Row 2: Trend chart with target line ───────────────────────────────
$hours = @('00:00','04:00','08:00','12:00','16:00','20:00','24:00')
Add-DhLineChart -Report $report -Id 'cpu-trend' -Title 'Cluster CPU (24h)' `
    -Filled -XAxis $hours `
    -Series @(
        @{ Label='Avg';  Values=@(42,38,55,67,71,68,52); Class='cell-ok' }
        @{ Label='Peak'; Values=@(58,52,72,84,91,86,68); Class='cell-warn' }
    ) `
    -TargetLine 90 -TargetLabel 'Capacity ceiling' `
    -YAxisMin 0 -YAxisMax 100 -YAxisUnit '%'

# ── Row 3: Bullets (actual vs target) ────────────────────────────────
Add-DhBullet -Report $report -Id 'cpu-headroom' -Title 'CPU headroom per host' -Items @(
    @{ Label='esxi-01'; Value=58; Target=30; Max=100; Unit='%'
       Rag=@{ Green=@{Min=30}; Amber=@{Min=15;Max=30}; Red=@{Max=15} } }
    @{ Label='esxi-04'; Value=12; Target=30; Max=100; Unit='%'
       Rag=@{ Green=@{Min=30}; Amber=@{Min=15;Max=30}; Red=@{Max=15} } }
)

# ── Row 4: Status grid ────────────────────────────────────────────────
Add-DhStatusGrid -Report $report -Id 'esxi-health' -Title 'ESXi host health' `
    -RowLabel 'Host' -ColumnLabel 'Probe' `
    -Rows    @('esxi-01','esxi-02','esxi-03','esxi-04') `
    -Columns @('Power','Network','Storage','HA') `
    -Cells @(
        @{ Row='esxi-01'; Column='Power';   Status='ok' }
        @{ Row='esxi-01'; Column='Network'; Status='ok' }
        @{ Row='esxi-01'; Column='Storage'; Status='ok' }
        @{ Row='esxi-01'; Column='HA';      Status='ok' }
        @{ Row='esxi-04'; Column='Power';   Status='ok' }
        @{ Row='esxi-04'; Column='Network'; Status='ok' }
        @{ Row='esxi-04'; Column='Storage'; Status='warn'; Tooltip='memory pressure → swap' }
        @{ Row='esxi-04'; Column='HA';      Status='ok' }
    )

# ── Row 5: Event feed ─────────────────────────────────────────────────
Add-DhEventFeed -Report $report -Id 'recent' -Title 'Recent events' `
    -Events @(
        @{ Timestamp='2026-05-22 15:18'; Severity='warning';  Source='esxi-04';   Message='Memory state changed: HARD' }
        @{ Timestamp='2026-05-22 14:12'; Severity='critical'; Source='vm-DB-01';  Message='Snapshot age > 30 days' }
        @{ Timestamp='2026-05-22 12:00'; Severity='ok';       Source='Backup';    Message='Nightly job completed' }
    )

Export-DhDashboard -Report $report -OutputPath '.\demo.html' -Force -OpenInBrowser
```

---

## 15 — When in doubt

1. **Look at `Examples/`** — `AD-Dashboard.ps1`, `vSphere-Dashboard.ps1`, `Multi-Panel-Dashboard.ps1`, `Invoke-Demo-DashHtml.ps1`, and `v1.5-Widgets-Showcase.ps1` show every feature with realistic data.
2. **Look at `DashHtml-Reference.html`** — full Get-Help output for every public cmdlet, with parameter signatures and defaults.
3. **Look at `docs/v1.4-plan.md` and `docs/KPI_Dashboard_Specification.docx`** for the design rationale of the v1.4 widget set.
4. **Look at the tests** — `Tests/DashHtml.Tests.ps1` documents every supported parameter combination, validation rule, and threshold edge case.

---

*End of dev/AI reference. Module version 1.10.4, generated 2026-08-07.*








