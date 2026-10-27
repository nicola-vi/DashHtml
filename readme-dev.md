# DashHtml — Developer / AI-assistant Reference

> **Audience:** An LLM-based coding assistant (or a developer in a hurry) that needs to use DashHtml correctly without reading the full README. Pass this file as context at the start of a session to skip the discovery phase.

> **Module version this file describes:** **2.0.0** (2026-08-26)

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

## 2 — Cmdlet cheat sheet (27 cmdlets, grouped by role)

| Group | Cmdlet | Use when… |
|---|---|---|
| **Foundation** | `New-DhDashboard` | Always first. Sets title, theme, info-fields header. **`-AutoRefresh '30s'/'5m'/'1h'`** (v1.4.2) emits a `<meta http-equiv="refresh">` for wall displays. **`-ThemeMode Light|Dark|Auto`** (2.2) sets the opening theme; **`-PrintCover`** (2.2) adds a printed cover page. **`-LinkState`** (2.6) keeps each table's sort, page, page size and Change chip in the address (7.33). |
| | `Export-DhDashboard` | Always last. Writes the HTML file. **`-ExportLibraries Cdn|Embed|None`** (2.2): XLSX/PDF libraries loaded on first click (default), inlined for air-gapped readers, or no XLSX/PDF buttons. **`-CompressData`** (2.6) gzip + base64 data and **`-SizeBudgetMB`** (2.6, default 15) size warning, see 7.33. **`-PrintMaxRows`** (2.2, default 200) caps rows per table in print. Warns about dangling table references (2.1.4). |
| | `Get-DhTheme` | List available themes / fetch raw CSS. Rarely needed in user scripts. |
| **Tables** | `Add-DhTable` | Tabular data. Sortable, filterable, pageable, exportable. Cell types: `text` / `progressbar` / `badge` / `sparkline` / `link` (2.2: `UrlField`, `LinkText`; 2.6: `UrlTemplate`, `RelativeLinks`, `LinkTarget`; http(s)/mailto/tel only, see 7.34). `-Charts` types: `donut` (default) / `pie` / `bar` (2.2, with `ValueField`/`Aggregate`/`TopN`). Cells never wrap: a clipped value gets a hover tooltip with the full text, and any column can be resized by dragging its header edge (2.1.1+). Headers clip and get a tooltip too; minimum column width is 40px (2.1.2+). |
| | `Set-DhTableLink` | Master-detail wiring: clicking a row in table A filters table B. |
| **KPI strip** | `Add-DhSummary` | Top-of-page KPI tiles (and per-NavGroup strips in v1.4.1+). Tile styles: `tile` (default compact) / `bignumber` (hero) / `gauge` (semicircle SVG) / `verdict` (2.2: full-width overall assessment with severity chips from `Counts`). v1.4.2: per-tile `Action` makes any tile clickable. |
| **Charts** | `Add-DhBarChart` | Horizontal bars. Pass `-Stacked -SeriesField 'X'` for stacked variant (v1.4+). **2.2:** `-ValueField F -Aggregate sum|avg|min|max -Unit -Decimals` makes the bars measure a value instead of counting rows. |
| | `Add-DhPieChart` | Pie / donut. Two modes: Mode A (from a table column) or Mode B (explicit `-Slices`). |
| | `Add-DhLineChart` | Time-series with axes. Multi-series + optional `-Filled` (area) + optional `-TargetLine` for thresholds (the spec's mandatory pairing per §7.4). |
| | `Add-DhBullet` | Actual-vs-target with performance bands. Canonical SLA / headroom visualisation. |
| | `Add-DhRangeBar` *(v2.1)* | **min–avg–max range per category** on a shared 0–100 axis. Each row is normalised against its own `High`, so entities of very different magnitude become comparable; bar colour follows position on the axis (`--accent-ok → --accent-warn → --accent-danger`), not category identity. Two modes: explicit `-Items`, or `-TableId` + `-CategoryField`/`-ValueField` (aggregated in the browser, so filtering the table live-recomputes the ranges). |
| **2-D grids** *(v1.5)* | `Add-DhStatusGrid` | Rows × columns **RAG** matrix (categorical). Services × regions, hosts × probes. |
| | `Add-DhHeatmap` *(v1.5)* | Rows × columns **numeric** matrix with sequential / diverging colour scale. Time-of-day load, percentile distributions, deviation from target. |
| **Trees** *(v1.5)* | `Add-DhTopologyMap` *(v1.5)* | Parent-child tree (AD Forest→Domain→DC, vCenter→Cluster→Host). Recursive subtree-width SVG layout; cycle detection. **v1.5.2:** `-AutoFitWidth` measures the widest label and grows `NodeWidth` so FQDN labels stop truncating; every node also gets a styled hover tooltip (falls back to the full `Label`). |
| **Assessment** *(v2.2)* | `Add-DhFindings` | Audit findings: severity (critical/warning/info/ok; high/medium/low aliases), description, recommendation, affected objects, "Show in table", reference links. Severity chips + text filter; `-GroupBy Area`; printed fully expanded. |
| **Events / alerts** | `Add-DhEventFeed` | Chronological severity-tagged log. Pair with KPI tiles as Row-5 audit trail. |
| | `Add-DhAlertBanner` | Top-of-page strip for *current* conditions. Dismissible, with optional Action button. v1.4.2: `-NavGroup` / `-NavSubGroup` bind to a single panel. |
| **Layout** | `Add-DhTabs` *(v1.5)* | Inline tabbed content block. Local pivot inside one block; distinct from `-NavGroup` (page-level). |
| **Global filter** *(v1.9)* | `Add-DhGlobalFilter` | Page-level facet dropdown or from/to date range in a bar above the body. Re-filters EVERY table that has the field at once; charts re-aggregate; AND-combined; persists in URL. Tables lacking the field are unaffected. |
| | `Add-DhFilterCard` | Clickable filter card grid; single or multi-select; filters a target table. |
| | `Add-DhKeyValue` *(2.3)* | A grid of label/value tiles (a property sheet): `-Items @(@{ Label; Value; Status })`, `-Columns 1..6`. |
| | `Add-DhRecordList` *(2.3)* | One row per record (status dot, title, sub line, ≤4 metrics) that expands to sections (kv / bars / statusList / checks / table / text / links). Filter, expand all, printed expanded. |
| **Maps and trees** *(2.4)* | `Add-DhNetworkMap` | A graph, not a tree: nodes + links (replication, site links, trusts, tiers). `-Layout grouped` (boxes) or `layered` (lanes by `Tier`), deterministic. Nodes: `Group, Tier, Status, Badge (list), Target, Detail, LinkTableId`; edges: `Label, Status, Style, Direction`. Filters, node search, shortest-path trace to a `Target`, SVG download. Caps 300 nodes / 1500 edges. |
| | `Add-DhTreeFilter` | An OU / folder tree that filters a table by path: `-TableId -PathField -Nodes @(@{ Id; Parent; Label; Path; Count; Status; Flags; Detail })`, `-Match Prefix` (`a/b/c`) or `Suffix` (distinguished names), `-CountFromTable`. The table must already exist. |
| | `Add-DhTreeTable` *(2.5)* | A directory explorer: `-Rows @(@{ Id; ParentId; Type ou/group/user/computer/container/other; Label; Status; Flags; Properties; Detail })` and `-Memberships @(@{ GroupId; MemberId })`. Tabs Properties / Members / Member of / Nesting (effective membership, circular nesting marked). Browsing tool: warns above 5,000 rows, throws above 20,000. |
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
Spread of a metric per entity (min/avg/max)          → Add-DhRangeBar        (v2.1)
Entities of different scale, compared as % of own    → Add-DhRangeBar -HighField 'Capacity'
   capacity/ceiling
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

### Choosing between the three per-entity bar widgets

```
One value against one target, with RAG bands
  → Add-DhBullet                  (bar anchored at the axis origin, target tick)

A min–max SPREAD plus its average, all rows on one 0-100 scale
  → Add-DhRangeBar                (floating bar, unclamped avg tick, gradient by position)

A single proportional count per category
  → Add-DhBarChart                (bar length = count, colour = one accent)
```

`Add-DhRangeBar` is the only one of the three whose bar does not start at the
axis origin, and the only one whose colour encodes POSITION rather than
category or state.

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

## 5 — Navigation: the `-NavPath` model

> **Write all new code with `-NavPath`.** `-NavGroup` / `-NavSubGroup` are a
> compatibility shim — kept indefinitely, still correct, but they cannot express
> most of what the path model can. Migration guide: §15.1.

Every item — table or block — sits at a **path** in one tree and declares **how
far its visibility reaches** from that path. That is the whole model. The 1.x
asymmetry (tables navigated through a table-only code path, blocks through
another) is gone; it was the cause of defect #26.

### 5.1 — The four parameters

Present on all **17** nav-aware cmdlets, identical on each.

| Parameter | Type | Default | Meaning |
|---|---|---|---|
| `-NavPath` | `string` | `''` | `'A/B/C'` — where this item lives. `''` = page-global. |
| `-NavScope` | `Exact`\|`Subtree`\|`Global` | `Exact` when `-NavPath` is given | How far visibility reaches. |
| `-NavLabel` | `string` | last path segment | Display text, decoupled from the path key. |
| `-NavOrder` | `int` | `0` | Explicit sibling order; `0` = declaration order. |

**Path syntax.** `/` separates segments; **`//` escapes a literal `/`**
(`'Reports/A//B'` → `@('Reports','A/B')`). Segments are trimmed, and an empty
segment **throws** — a trailing `/` or a `//` used as a separator produces an
unaddressable node. Matching is **case-sensitive** (`Ordinal`) — see gotcha #10.

**Scope.** A section is visible for the selected path iff:

| Scope | Visible when |
|---|---|
| `Global` | always |
| `Subtree` | the declared path is a **prefix** of the selection (this node and everything below) |
| `Exact` | the declared path **equals** the selection |

Two consequences worth internalising: an item declared **deeper** than the
selection can never be visible (except `Global`), and `Subtree` on a leaf behaves
exactly like `Exact`.

Single source of truth: `Private/Test-DhNavMatch.ps1`. The runtime JS
(`Get-DhJsNav.ps1`, `navMatches`) mirrors it exactly. Since 2.1.4,
`Tests/js/nav.test.js` extracts the **shipped** matcher from `Get-DhJsNav.ps1`
by its `DH-NAV-MATCHER-START/END` sentinel comments and runs it under Node
against a truth table that the Pester wrapper generates from
`Test-DhNavMatch`, so the two copies cannot drift apart unnoticed. The wrapper is
skipped when `node` is not on PATH. (`Tests/js/nav-spike.test.js` is the 2.0.0
spike that proved the approach on a private copy; keep it as history.)

### 5.2 — Nav-aware cmdlets

**22 accept the nav parameters:** `Add-DhTable`, `Add-DhSummary`, `Add-DhFindings`,
`Add-DhBarChart`, `Add-DhPieChart`, `Add-DhLineChart`, `Add-DhRangeBar`,
`Add-DhBullet`, `Add-DhStatusGrid`, `Add-DhHeatmap`, `Add-DhTopologyMap`,
`Add-DhTabs`, `Add-DhEventFeed`, `Add-DhFilterCard`, `Add-DhHtmlBlock`,
`Add-DhCollapsible`, `Add-DhAlertBanner`, `Add-DhKeyValue`, `Add-DhRecordList`,
`Add-DhNetworkMap`, `Add-DhTreeFilter`, `Add-DhTreeTable`.

**5 do not:** `New-DhDashboard`, `Export-DhDashboard`, `Get-DhTheme`,
`Set-DhTableLink`, `Add-DhGlobalFilter`.

### 5.3 — Defaults when nothing is declared

Tables and blocks differ here, deliberately — it reproduces 1.x flat nav exactly.

| Item | No nav parameters | Why |
|---|---|---|
| **Table** | path `<TableId>`, scope `Exact` | A plain report shows one table at a time, each with its own link. Without this every table would stack on one page. |
| **Block** | path *(empty)*, scope `Global` | An ungrouped block was visible on every panel in 1.x. |

So a three-table report with no nav parameters already has a working three-entry
menu. **You do not have to declare nav to get nav.**

`Add-DhSummary` follows the block rule and is worth calling out: without a path
it is the classic singleton at the top of `<main>`, visible everywhere; with one
it becomes a `summarystrip` block scoped to its panel. Both can coexist — one
global strip plus many per-panel strips.

### 5.4 — Layout policy (`New-DhDashboard`)

| Parameter | Values | Default | Notes |
|---|---|---|---|
| `-NavTitle` | string | the `-Title` | `''` hides the nav-bar label. |
| `-NavLayout` | `Auto`\|`Strips`\|`Sidebar` | `Auto` | Strips to 3 levels, sidebar rail at 4+. `Strips` forces the 1.x look. |
| `-NavMaxDepth` | `1`–`5` | `3` | **Policy, not an architectural limit** — the matcher, URL state and renderer are all depth-agnostic. |

`Auto` switches because three sticky strips cost ~190 px of vertical chrome at
depth 3 and ~225 px at depth 4 — 21% of a 1080p viewport.

### 5.5 — Example

```powershell
# KPI strip across the whole Identity section
Add-DhSummary -Report $r -NavPath 'Identity' -NavScope Subtree -Items $kpis

Add-DhTable -Report $r -TableId 'users'  -Title 'Users'  -Data $users `
            -NavPath 'Identity/users'  -NavLabel 'User accounts'
Add-DhTable -Report $r -TableId 'groups' -Title 'Groups' -Data $groups `
            -NavPath 'Identity/groups' -NavLabel 'Security groups'

# three levels
Add-DhTable -Report $r -TableId 'cpu' -Data $cpu -NavPath 'Compute/Capacity/cpu' -NavLabel 'CPU'
```

Supplying **both** `-NavPath` and `-NavGroup`/`-NavSubGroup` on one call is a
hard error, and `-NavSubGroup` without `-NavGroup` is too. Silent precedence
between two ways of saying the same thing is how the 1.x nav became three
competing mechanisms — see `Private/Resolve-DhNavDeclaration.ps1`.

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
        @{ Id='farm';     Label='FARM-01';                     Parent=$null;     Status='ok'; Icon='🏗️'; Badge='Farm' }
        @{ Id='site';     Label='RAS-SITE-01';             Parent='farm';    Status='ok'; Icon='🌐';  Badge='Site' }
        @{ Id='cat-brk';  Label='Brokers';                    Parent='site';    Status='ok'; Icon='🔀';  Badge='2'    }
        @{ Id='cat-gw';   Label='Gateways';                   Parent='site';    Status='ok'; Icon='🛡️'; Badge='2'    }
        @{ Id='cat-pool'; Label='RDS Host Pools';             Parent='site';    Status='ok'; Icon='📦';  Badge='5'    }
        @{ Id='brk-01';   Label='RAS-BRK01.contoso.local';  Parent='cat-brk'; Status='ok'; Icon='🔀';  Badge='Primary'
           Tooltip='RAS-BRK01.contoso.local — role Primary, agent OK'; LinkTableId='brokers' }
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

### 7.15 — Range bar: min–avg–max per entity (v2.1+)

Explicit rows — each cluster scaled against its own capacity, so a 315-unit
cluster and a 30-unit one sit on one comparable axis:

```powershell
Add-DhRangeBar -Report $report -Id 'cluster-load' -Title 'Cluster load range' `
    -Unit 'req/s' -ShowDataTable `
    -Items @(
        @{ Name='cluster01-users';   Low=0; High=315; Min=60; Avg=97; Max=120 }
        @{ Name='cluster02-bigdata'; Low=0; High=104; Min=1;  Avg=2;  Max=10  }
    )
```

Or derive the rows from a table already in the report. Aggregation runs in the
browser against the table's **filtered** rows, so filtering the table
live-recomputes every bar:

```powershell
Add-DhTable -Report $report -TableId 'clusters' -Title 'Cluster hosts' -Data $hosts

Add-DhRangeBar -Report $report -Id 'cluster-load' -Title 'Cluster load range' `
    -TableId 'clusters' -CategoryField 'Cluster' `
    -ValueField 'LoadReqSec' -HighField 'CapacityReqSec' -Unit 'req/s'
```

**Where `High` comes from**, in precedence order — it is the value that maps to
100 on the axis, and it decides what the chart is actually saying:

| Form | The axis reads as | Use when |
|---|---|---|
| `-HighField 'Capacity'` | "% of that row's own capacity" | each table row carries its category's ceiling |
| `-High 250` | "% of a fixed ceiling" | one SLA / limit applies to everything |
| neither | "% of the largest value seen anywhere" | exploratory |

`-High` and `-HighField` together is an error, not a silent preference.

Gotchas:

- **The avg tick is deliberately not clamped** into `[Min, Max]`. An average
  computed over a longer window than the observed min/max legitimately falls
  outside the bar; clamping would hide a real data question.
- **`High <= Low` is not an error** — normalisation is undefined, so the row
  renders striped and muted and you get a `Write-Warning`. Fix the source data.
- **Colour is not category identity.** All bars share one gradient spanning the
  whole track; a bar is orange because it sits mid-axis, not because of which
  row it is. Never read two bars of the same colour as "the same thing".
- `-MaxRows` (default 60) throws on a runaway `-CategoryField`, rather than
  emitting 400 unreadable rows.

### 7.16 — Assessment report: verdict + findings (v2.2+)

```powershell
# Evidence tables first: findings jump to them.
Add-DhTable -Report $report -TableId 'accounts' -Title 'Accounts with findings' -Data $accounts -NavPath 'Evidence/Accounts'

Add-DhSummary -Report $report -Items @(
    @{ Style='verdict'; Label='Overall'; Value='Action required'
       Caption='Fix the critical findings first.'; Counts=@{ critical=2; warning=3; info=1 } }
)

Add-DhFindings -Report $report -Id 'sec' -Title 'Security findings' -NavPath 'Findings' `
    -GroupBy Area -ExpandSeverity critical -Findings @(
      @{ Severity='critical'; Title='AS-REP roastable accounts'; Area='Accounts'
         Description='...'; Recommendation='Clear DONT_REQ_PREAUTH on every listed account.'
         Affected=$asrep.SamAccountName; AffectedTableId='accounts'; AffectedFilter='AS-REP'
         References=@(@{ Label='MS Learn'; Url='https://learn.microsoft.com/...' }) }
    )
```

- `Affected` takes names. `AffectedCount` defaults to their number; set it explicitly when you list only a sample.
- Severity aliases `high / medium / low` are normalised in the cmdlet, so the browser only ever sees the four canonical values.
- Reference URLs go through `Test-DhSafeActionUrl` (http, https, mailto, tel, #); anything else throws.
- Verdict `Counts` take the same severities and aliases. Without `Class`, the colour follows the worst count.
- Gotcha: findings text is always encoded. To emphasise something, use the structure (Description vs Recommendation), not markup.

### 7.19 — Detail drawer, property tiles, record lists (v2.3+)

```powershell
Add-DhTable -Report $r -TableId 'dcs' -Title 'Domain controllers' -Data $dcs -DetailDrawer -DetailTitleField 'Name' `
    -DetailFields @('Name','Site',@{ Field='RamGB'; Label='RAM (GB)' },'Roles')

Add-DhStatusGrid -Report $r -Id 'repl' -Title 'Replication' -Rows $names -Columns $names -SelfDiagonal -Cells @(
    @{ Row='DC01'; Column='DC02'; Status='danger'; Glyph='x'; LinkTableId='dcs'
       Detail=@{ Title='DC01 to DC02'; Sections=@(@{ Kind='kv'; Items=@(@{ Label='Last success'; Value='3 days ago'; Status='danger' }) }) } })

Add-DhKeyValue   -Report $r -Id 'scope' -Title 'Scope' -Columns 4 -Items @(@{ Label='Forest'; Value='corp.example' })
Add-DhRecordList -Report $r -Id 'hw' -Title 'Hardware' -Items @(
    @{ Title='dc01'; Status='ok'; Metrics=@(@{ Label='RAM'; Value='8 GB' })
       Sections=@(@{ Kind='table'; Title='Volumes'; Columns=@('Drive','Free'); Rows=@(,@('C:','73 GB')) }) })
```

- **One section spec** (`ConvertTo-DhSections` in PowerShell, `renderSections` in JS) feeds the drawer, `Add-DhKeyValue`, `Add-DhRecordList` and the findings split layout. Kinds: `kv`, `bars`, `statusList`, `checks`, `table`, `text`, `links`. A status is `ok|warn|danger|info|nodata`; `cell-danger`, `critical`, `failed` etc. are normalised, an unknown word shows grey (it never throws).
- `ConvertTo-DhSections` returns `, @($out)` on purpose: without the comma a single section unrolls to a bare ordered dictionary and `.Count` / `[0]` then mean keys. Same trap as `Get-DhTableFieldNames`: assign its result directly (`$x = Get-...`), never `@(Get-...)`.
- `ConvertTo-DhDetailSpec` accepts text, one section, an array of sections or `@{ Title; Subtitle; Sections }` and returns one shape (or `$null`). Status-grid cells and findings share it.
- **The drawer** is one element on `<body>` (`dhDrawerOpen(spec, { opener, restore })`, also `window._dhOpenDrawer`). Pass `restore` as a selector when the opener is re-rendered (table rows are). `applyNav` and `dhBeforePrint` close it. Build new consumers on `dhDrawerOpen`; do not add a second popover.
- Table drawer options are stored as `DetailDrawer` / `DetailFields` / `DetailTitleField` (the cmdlet's own parameter names) so `DashHtml.Design` round-trips them. `Add-DhKeyValue` stores `Items` / `Columns` for the same reason. A YAML round trip drops table data and empty lists, so `Add-DhTable -Data` may be empty and `Add-DhFindings -Findings` is not mandatory.

### 7.20 — Score ring and maturity ladder (v2.3+)

```powershell
Add-DhSummary -Report $r -Items @(
    @{ Style='score'; Label='Posture'; Value=69; Caption='Elevated risk'; Facts=@('211 checks'); Previous=66; NotAssessed=20
       Rag=@{ Red=@{ Max=50 }; Amber=@{ Min=50; Max=80 }; Green=@{ Min=80 } } }
    @{ Style='maturity'; Label='Maturity'; Value='Initial'; Current=1; Levels=@('Initial','Managed','Defined')
       Criteria=@(@{ Level=2; Text='Enable the AD Recycle Bin'; Met=$false }) }
)
```

- They are tile **styles**, not cmdlets, so nav-aware strips, the global strip, `Action`, `Previous` and the link lint all work. `score` is validated like a gauge (a missing `Value` needs `Rag NoData`); colours come from `-Rag` / `Class` through theme tokens only.
- `LowerIsBetter` flips only the delta colour. The ring still fills as value / max.
- `Current` is 0..N (0 = nothing reached); the script owns the model, e.g. "the lowest unmet control caps the level".
- The score also appears on the print cover (`Get-DhJsPrint` clones `.tile-verdict` and `.tile-score`).

### 7.21 — Findings: split layout, evidence, change (v2.3+)

```powershell
Add-DhFindings -Report $r -Id 'h' -Title 'Hardening' -Layout Split -MaxEvidenceShown 50 -AllClearText 'Every setting is as recommended.' -Findings @(
    @{ Severity='warning'; Title='NTLM level'; Area='Auth'; Change='new'
       Facts=@(@{ Label='Recommended'; Value='5' }); Evidence=@(@{ Object='DC01'; Value='Level 4'; Status='warn' })
       Detail=@{ Title='How to check'; Sections=@(@{ Kind='text'; Text='...' }) } } )
```

- `List` output of a finding without the new keys is byte-identical to 2.2.0 (tested). The new keys are emitted only when present.
- Split keeps every detail pane in the DOM (hidden) so print can stack them and the filter never rebuilds; the cost is that evidence is built eagerly, which is why `-MaxEvidenceShown` exists.
- `Change` is a marker supplied by the script (it compares with the last run); DashHtml adds a badge and a filter chip.

### 7.22 — Small things (v2.3+)

- `CellType='chips'` (array as tags) and `'path'` (array as `A → B → Tier 0`): the export keeps list elements as strings for these columns ("007" stays "007"); CSV/XLSX get the joined text.
- `Add-DhBarChart -Rag` colours by value, `-KeyClass @{ Critical='cell-danger' }` by category (four classes only; `barFillClass` whitelists them). Ignored with a warning on a stacked chart.
- `-AllClearText` on `Add-DhTable` (empty `-Data`) and `Add-DhFindings` (no findings): a check mark and a sentence instead of nothing.

### 7.23 — Network map (v2.4+)

```powershell
Add-DhNetworkMap -Report $r -Id 'repl' -Title 'Replication' -NavPath 'Network' -Legend `
    -Groups @(@{ Id='hq'; Label='HQ site' }, @{ Id='eu'; Label='EU site' }) `
    -Nodes @(
        @{ Id='dc01'; Label='DC01'; Group='hq'; Badge=@('PDC','GC'); Status='ok' }
        @{ Id='dc02'; Label='DC02'; Group='eu'; Status='danger'; LinkTableId='dcs'; LinkFilter='DC02' } ) `
    -Edges @( @{ From='dc01'; To='dc02'; Label='15 min'; Direction='both'; Status='danger'; Style='dashed' } )

# lanes: -Layout layered, Tier 0 on top; Target=$true marks what "Trace path" aims for
Add-DhNetworkMap -Report $r -Id 'tiers' -Title 'Reaching Tier 0' -Layout layered -Nodes $nodes -Edges $edges
```

- Not a tree: use `Add-DhTopologyMap` when every node has exactly one parent. Edges between the same pair are parallel curves; a self edge is a loop; unknown `From`/`To` throws.
- Layout is computed in the browser by `dhNetLayout` (pure, tested in node): same input, same picture. `grouped` flows boxes left to right and wraps at 1100 px; `layered` orders each lane by declaration, then one barycentre sweep. Do not add randomness or a force simulation (decision D3).
- Path trace is `dhNetPath` (BFS, directed for `forward`, both ways for `both`/`none`, ties by declaration order).
- Edge labels are hidden above 400 links (the **Labels** button turns them on). Clicks are one delegated handler; a drag must not count as a click (`pz.dragged()`).
- SVG download copies the `.nm-*` rules and the CSS variables they use into the file (`dhNetDownload`); if you add a new `.nm-*` rule that uses a variable, it is picked up automatically.

### 7.24 — OU tree filter (v2.4+)

```powershell
Add-DhTable -Report $r -TableId 'ous' -Title 'OUs' -Data $ous                 # declare the table first
Add-DhTreeFilter -Report $r -Id 'ou-tree' -Title 'Browse by OU' -TableId 'ous' -PathField 'CanonicalName' -CountFromTable -Nodes @(
    @{ Id='root'; Label='corp.example'; Path='corp.example' }
    @{ Id='hq';   Parent='root'; Label='HQ'; Path='corp.example/HQ'; Status='ok'; Flags=@('large') } )
```

- `Path` is what table rows are compared with (case-insensitive, separator-aware: `HQ` does not match `HQ2`). Prefix for `a/b/c`, Suffix for distinguished names.
- The filter lives in the table engine: `TableEngine.setPathFilter(spec)` is the only place `pathFilter` is assigned (a test pins it). It ANDs with the text, card and global filters, shows in the link badge, and is saved in the URL as `pathFilters`.
- The tree renders in the Boot loop **after** the engines exist (like table-fed bar charts), not in `renderBlocks`.
- `-CountFromTable` credits each row to the deepest node it reaches, then rolls up: O(rows x depth).
- A runtime marker the older tests pin: the strings `"detail"`, `"layout"`, `"glyph"`, `"self"` must not appear in the runtime as exact quoted words (the tree uses `data-act="info"`), because the 2.3.0 byte-identity tests search the whole HTML for them.

### 7.25 — Search and menu badges (v2.4+)

- `New-DhDashboard -Search` adds `#nav-search-input`; `initSearch` (`Get-DhJsSearch.ps1`) is booted after `initNav`. The index (`dhSearchIndex`) is built once; table rows are scanned in time slices through `TableEngine._matchText`, the same matcher as the table's filter. Results go through `applyNav` / `jumpToTable`; the query never reaches the URL or `innerHTML`.
- `-NavBadge` sets `data-navbadge` on `#report-nav`; `buildNavSevIndex` rolls findings counts up to every ancestor path; `updateNavSeverity` (called from `updateNavBadges`) draws the `.nav-sev` pill on every `[data-navto]` element (strip chips and sidebar items).

### 7.26 — Columns that fit (v2.4+)

- Auto-fit is on by default (`Add-DhTable -ColumnFit Auto`). `TableEngine._measureCol` measures the formatted text with canvas `measureText` (fonts and padding read from a rendered cell), clamps to `[MinWidth, -ColumnMaxWidth]`, and `_effWidth` applies it after a dragged width and the author's `Width`.
- Re-measure on `document.fonts.ready`, on density change (`DENSITY.set`) and when a hidden column is shown. Large tables: unique strings only, the 3,000 longest if there are more.
- `-ColumnFit Fixed` restores the 340 px CSS cap exactly. Emitted JSON has no `columnFit`/`columnMax`/`minWidth` unless used.

### 7.27 — Directory explorer (v2.5+)

```powershell
Add-DhTreeTable -Report $r -Id 'dir' -Title 'Directory' -NavPath 'Identity/Directory' -Rows @(
    @{ Id='ou-hq'; Type='ou'; Label='Headquarters' }
    @{ Id='g-da'; ParentId='ou-hq'; Type='group'; Label='Domain Admins'; Flags=@('privileged') }
    @{ Id='u-rossi'; ParentId='ou-hq'; Type='user'; Label='adm.rossi'; Properties=[ordered]@{ 'Password age'='41 days' } }
) -Memberships @( @{ GroupId='g-da'; MemberId='u-rossi' } )
```

- Two flat lists. `ParentId` is the container (it must not loop: that throws); `-Memberships` is group nesting (it may loop: real directories do, and the browser marks it "circular nesting").
- The membership logic is three pure functions in `Get-DhJsTreeTable.ps1`: `dhTtLinks` (pairs to both directions), `dhTtPaths` (every path up, capped by `-MaxNestingPaths`, a cut loop ends a path and sets `circular`), `dhTtNested` (groups below a group, depth-capped). They are tested in node; keep them pure.
- The tree is drawn flat, only rows whose parent is open (like `Add-DhTreeFilter`); do not render everything and hide it. Cap: warn above `-MaxRows`, throw above 20,000.
- A tab link (`data-goto`) calls `goTo(id)`: it opens the ancestors, clears the find box and type filter if they hide the row, then selects it.
- It does not read or filter a table, so it renders in `renderBlocks` (no engine needed).
### 7.28 — Menu: All view, skeleton, lint, overflow, keyboard (v2.5+)

```powershell
$r = New-DhDashboard -Title 'Estate' -StrictNav `
    -NavAllLabel @{ 'Storage' = 'All storage' } `              # or -NavAllLabel 'All' for every group
    -NavTree @( @{ Path='Overview' }, @{ Path='Storage'; Label='Storage and backup' }, @{ Path='Storage/Capacity' } ) `
    -NavOverflow More                                          # default; Wrap keeps the old wrapping
```

- **All view** = path ending in `*`. Matching (both `Test-DhNavMatch` and JS `navMatches`): visible if the declared path is at or below the parent (any scope), global, or a Subtree item above the parent. `*` is reserved: `ConvertFrom-DhNavPath` rejects it. The JS tree adds the node from `data-navall` / `data-navallall` on `#report-nav`; `navAutoDescend` skips `*`.
- **Skeleton** = `data-navtree` on `#report-nav`; both `Get-DhNavTree` (PowerShell: initial path, depth) and `buildNavTree` (JS: the menu) create its nodes first with a sequence below any declaration. Order and label from the skeleton apply only where the item gave none.
- **Lint** = `Test-DhNavLint` (private, returns strings); it compares siblings case-sensitively from the raw paths because PowerShell ordered-dictionary keys are case-insensitive.
- **Overflow** = pure `dhNavFit(widths, avail, gap, maxRows, moreW, active)` plus `dhNavFitStrip` (measure, then move chips into `.nav-more-menu`). `DH_NAV_MAX_ROWS` is 1 since 2.5.3 (was 2). The selected chip is never moved. Rules that keep the fit honest (2.5.3): `.nav-strip-top` has `flex: 1 1 0` so a long menu stays on the title line instead of dropping onto its own; `dhNavDecorate` fills row-count badges and `-NavBadge` pills **before** the fit; `avail` excludes the strip padding; the More button is measured, not guessed; `updateNavBadges` calls `dhNavRefitIfWrapped` (a filter can widen a badge). A window width change, or a width change of `#nav-strips-top` (ResizeObserver: the theme/density labels and fonts settle after `initNav`), re-renders the menu (debounced).
- **Keyboard** = one delegated `dhNavKeydown`. The menu is rebuilt on every `applyNav`, so `applyNav` remembers the focused `data-navto` and refocuses it.
- **Empty view** = `updateEmptyView` after every `applyNav`: no panel-active section that has a path and a non-global scope means "no content".

### 7.29 — Column picker (v2.5+)

- Column key `Hidden = $true` (bool only; anything else throws) starts the column unticked. Export emits `"hidden":true` only when set; `Add-DhTable` throws when every column is Hidden.
- `Add-DhTable -RememberColumns` adds `"remember":"<16 hex>"` to the table config: the first 16 hex of SHA-256 over `ReportTitle|GeneratedBy|TableId`, so the key is stable across regenerations and different per report. The runtime stores `{ field: bool }` under `dh:cols:<key>` (`_saveCols`) and applies it by field name (`_restoreCols`); every localStorage access is in try/catch. `Default columns` (`.col-toggle-reset`) restores `!col.hidden` and removes the key.
- Picker label: `_colToggleLabel` ("Columns (n hidden)"). Showing a hidden column re-measures its width through the usual `_ensureFit` path.
- Exports use `_visibleCols`, so unticked and hidden columns are not exported (unchanged behaviour).

### 7.31 — Baseline markers (v2.5.2)

- `Add-DhTable -Baseline -KeyField [-BaselineFields] [-BaselineLabel]`. Add-DhTable passes the table's column fields as the compared set unless `-BaselineFields` is given (a hidden timestamp must not mark rows Changed). A field that is a date on one side and text on the other is counted and reported as a warning. Copy cell uses `dhCellText` (drops the tag); CSV and copy-as-CSV go through `dhCsvSafe` (formula guard). The comparison is `Get-DhBaselineDiff` (Private, unit-tested): key = case-insensitive text, values compared as invariant-culture text (null = empty), duplicate keys throw, result `Changes` by DATA ROW INDEX (`'3' = @{State='new|changed'; Fields; Was}`), `Removed` rows, `Counts`. The table object carries `Baseline` (null without the parameter).
- Export emits `"baseline":{label,key,new,changed,removed,changes:{"<idx>":{s:"n|c",f:[..],w:{..}}},removedRows:[..declared columns..]}` only when set, so a plain table's JSON is unchanged.
- Runtime (`Get-DhJsTable.ps1`): `_baseState` maps row object to its entry (rows are never reordered, so the index is stable); `_getFiltered` applies the chip filter (`dhChangeKeep`); `_buildRow` adds the tag, `row-new/row-changed` and `cell-changed` + `data-was` (kept by `_markTruncated`, which rewrites `title`); `_exportRows` adds the `Change` column and, with the checkbox, the removed rows; `_buildChangeBar` / `_renderRemoved` build the line, chips and the `details.tbl-removed` group (opened by `dhBeforePrint`). Column fit adds 62 px to the first column for the tag.
- YAML: `ConvertTo-DhYaml` drops `Baseline` (it is data); the schema lists the four parameters.

### 7.30 — Quality tools: print, contrast, accessibility, schema (v2.5.2)

- **`Tools\Test-DhPrint.ps1`** prints reports to PDF with headless Edge/Chrome (page count, size). Review the pages as images with a pdf.js page if no rasteriser is installed.
- **`Tools\Test-DhContrast.ps1`** builds three examples in all 6 families (or takes `-Path`), injects `contrast-measure.js` into a COPY of each page and measures WCAG ratios for the selectors in `contrast-selectors.json` in light and dark (3.0 for large text; `accept` lists documented exceptions, currently heatmap mid-tones at 3.8). Text over a gradient or image counts as skipped, never as a pass. A fix goes into the theme tokens (`--cell-*-fg`, `--text-secondary`), not into one selector.
- **`Tools\Test-DhA11y.ps1`** runs `a11y-probe.js` the same way: duplicate ids, controls without a name, sortable headers without `aria-sort`/keyboard access, tabs and expandables without state, dialogs, tables without a name, selection that is not announced, lang/main/alt, focus-visible and reduced-motion rules. Errors fail; warnings fail with `-Strict`. Add a rule in the probe and a bad-HTML case in the Pester test.
- Both use **`BrowserProbe.ps1`**: current Edge prints nothing for `--dump-dom`, so the injected script `fetch`es its JSON to a loopback HttpListener (`/*%%PORT%%*/0` is replaced). `Find-DhBrowser.ps1` returns Edge/Chrome/Chromium on Windows, macOS and Linux; the Pester tests skip when none exists. The probe also works when the desktop window is minimised (a hidden page fires no scroll events, so check scrolling behaviour there, not in a hidden preview pane).
- **Collapsible headers** are divs: `dhBindCollapsible(toggle, body, chevron)` in `Get-DhJsCore.ps1` gives them `role=button`, a tab stop, `aria-expanded`/`aria-controls` and Enter/Space. Use it for any new collapsible; never add a bare click handler to a div.
- **Menu pruning:** `dhNavPrune(root, hasOwn)` in `Get-DhJsNav.ps1` drops nodes with no own content and no kept child (a Global item that carries a path); a node declared in `-NavTree` stays.
- **`Export-DhYamlSchema`** (DashHtml.Design) writes `DashHtml.Design\dashhtml.schema.json` from `Get-Command` metadata; property maps must be ordinal (`[ordered]` is case-insensitive and would merge `Id` and `id`). A Pester test fails when the committed file differs from a fresh export: regenerate it after changing a cmdlet parameter.
- **Node tests:** `Tests\js\dh-extract.js` (`load`, `loadWith` for top-level vars like `FMT`, `loadMethods` for `TableEngine.prototype.X`) loads functions from the fragments; run `node --test "Tests/js/*.test.js"`. A missing function throws, so a rename fails the test.

### 7.32 — `Test-DhReport` (v2.6.0)

- DashHtml.Design cmdlet #6, `Public/Test-DhReport.ps1`; the helpers in the same file (`New-DhFinding`, `Test-DhReportObject`, `Test-DhReportScript`, `Test-DhReportLayout`, `Test-DhReportHtml`) are not exported (the psm1 exports by file name).
- The core's private lints are called in module scope: `& (Get-Module DashHtml) { Test-DhReportLinks ... }`, `Test-DhNavLint`. Known block types come from `$script:DhTypeToCmdlet` (DhSchema), so a new block type needs no change here.
- Layout check: `Test-Json` against `Export-DhYamlSchema`. Its messages are poor (the root `anyOf` for title/Title adds a false "Title missing"), so the check (1) drops that noise, (2) re-validates each section item alone with the document's title, and (3) for a failing mapping removes one key at a time to name the culprit. Keep that order when adding checks.
- HTML check: the footer stamp `Generated by <strong>DashHtml</strong> vX.Y.Z` against the loaded module; `$script:DhRuntimeFixes` (newest first) lists what each release fixed. **Add a line there for every release that changes the runtime.**
- Severities: `error`, `ACTION` (from `Update-DhScript`), `warning`, `advisory`, `info`. `-Strict` sets `$global:LASTEXITCODE` (1 on error / ACTION / warning, else 0). `Build.ps1` runs it on `Examples\*.ps1` and fails on ACTION or error.

### 7.33 — Compressed data, size budget, table state in the address (v2.6.0)

- `Export-DhDashboard -CompressData`: `ConvertTo-DhGzipBase64` (Private) gzips `$tablesConfigJson` and `$blocksConfigJson`; they become `[]` and the payload goes into `var DH_ZDATA = /*%%ZDATA%%*/null;` (Core). Boot: the `DOMContentLoaded` handler calls `dhUnzipConfig(DH_ZDATA, dhBoot)` (atob, `DecompressionStream('gzip')`, `JSON.parse`, then reassign `TABLES_CONFIG` / `BLOCKS_CONFIG`) or `dhBoot()` directly. **Nothing may read `TABLES_CONFIG` / `BLOCKS_CONFIG` before `dhBoot`** (they are `[]` until then in a compressed report); no other `DOMContentLoaded` listener exists, keep it that way. The configs must stay valid JSON (they are parsed, not evaluated). Tools that read `TABLES_CONFIG` from the HTML (`Show-DhNavMap`) see `[]` in a compressed report.
- `-SizeBudgetMB` (default 15, 0 = off): measured on the final HTML string; the per-table/block sizes come from the JSON parts (`$jsConfigBlocks`, `$blockList`), matched by their `"id"`.
- `New-DhDashboard -LinkState` adds `"linkState":true` to every table config. Table fragment: `dhTableStateGet/Set/All/Finish`, `_restoreLinkState` (constructor, before `_initPageSizes`, so the select shows the restored size), `_saveLinkState` (sort, page buttons, page size, Change chip; a no-op without the switch, so a plain report never touches the address on sort). `URLState._write` adds `state.t` from `dhTableStateAll`; the page waits in `_pendingPage` and is clamped by `dhTableStateFinish(engines)` at the very end of `dhBoot`, after card, tree and global filters are restored. Hash keys: `s` `[[field,'asc'|'desc']...]`, `p`, `z` (one of 5/10/15/25/50/100), `c` (`n`|`c`). Cap 1,500 characters, least recently used tables dropped (`_lsTouch`).

### 7.34 — Link columns: templates, relative links, target (v2.6.0)

- Column keys `UrlTemplate`, `RelativeLinks` (bool), `LinkTarget` (`new`|`same`), validated in `Add-DhTable` (only on `CellType='link'`; `UrlTemplate` excludes `UrlField`; every `{Field}` must be a data property, `{{`/`}}` literal). Export emits `urlTemplate` (+ `linkText`), `linkTarget`, `relativeLinks` only when set; a template column has no `urlField`.
- Runtime: `dhLinkUrl(raw, allowRelative)`, `dhLinkFill(tpl, row)`, `dhLinkNewTab(url, target)` in Core (node-tested allow/deny list). `TableEngine._linkFor(col,row,rawVal)` is the one place a cell becomes a link; `_renderCell` and `_openDetail` (drawer) use it. The drawer's `kv` items carry `_link` / `_newTab`, re-vetted by `dhLinkUrl(...,true)` in `renderSection`. A template allows relative URLs; a data value only with `RelativeLinks` (a value like "N/A" must stay text).

### 7.35 — Tree tables: windowing and CSV (v2.6.0)

- One flat list: `dhTtMatch(rows, byId, q, typeSel)` (match + forced ancestors) and `dhTtFlatten(roots, kids, expanded, m)` → `[{r,pos,size}]`; `rebuild()` runs on expand, collapse, filter and select, never on scroll. Above `DH_TT_WIN_MIN` (2,000) rows the tree gets `.tt-win`: fixed `--tt-row-h` (28 px), `dhTtWindow(scrollTop, viewH, rowH, total, 20)` picks the slice, two `.tt-spacer` divs keep the scroll height. Scroll repaints once per frame with a 100 ms timer as fallback, and keeps keyboard focus in the tree (the tree itself has `tabindex=-1`; keydown on the tree uses `focusId`, which a `focusin` listener keeps current). `paint()` clamps `scrollTop` when the list shrank.
- Print: `dhTtPrintHooks` (`before` draws the first `DH_TT_PRINT_MAX` open rows with a note, `after` repaints), called from `dhBeforePrint` / `dhAfterPrint`.
- CSV: `dhCsvText(header, rows)` (BOM, quotes, CRLF, `dhCsvSafe`) and `dhCsvDownload`; the toolbar `data-tt="csv"` button saves `flat`, the `data-tt-csv` buttons in Members / Member of save the list. Columns: Id, ParentId, Type, Label, Path, Status, Flags, then every property label in first-seen order.
- `Add-DhTreeTable`: `-MaxRows` default 20,000 (warning), hard limit 100,000. Building 50,000 rows takes about 25 s in `Add-DhTreeTable` and 30 s in the export on a laptop.
### 7.17 — Bars that measure a value (v2.2+)

```powershell
Add-DhBarChart -Report $report -Id 'lag' -Title 'Worst replication lag by DC' `
    -TableId 'repl' -Field 'SourceDC' -ValueField 'LagMinutes' -Aggregate max -Unit 'min'

# inside a table's chart strip
Add-DhTable ... -Charts @(@{ Field='Site'; Type='bar'; ValueField='UsedGB'; Aggregate='sum'; Unit='GB'; TopN=5 })
```

- `-ValueField` alone = `sum`; `avg/min/max` need a `-ValueField`; stacked charts allow `count` or `sum`.
- `ValueField` is checked case-sensitively against the table's fields (hidden properties count), at Add-time if the table exists and again at export.
- `-ShowPercent` is meaningful for `count` and `sum` only; it is not drawn for `avg/min/max`.
- JS: `aggregateBars(rows, field, opts)` + `buildBarHtml(entries, opts)` are the shared pure helpers; `bindBarClicks` binds after the markup is written.

### 7.18 — Print, PDF and offline export (v2.2+)

```powershell
$report = New-DhDashboard -Title 'AD Assessment' -PrintCover -ThemeMode Auto
...
Export-DhDashboard -Report $report -OutputPath $out -ExportLibraries Embed -PrintMaxRows 500
```

- **Print** is arranged by `Get-DhJsPrint` on `beforeprint` and undone on `afterprint`. Folded content is opened in CSS, so it also works without the handlers. Headless `msedge --headless --print-to-pdf` fires the handlers (checked by comparing page counts with and without `-PrintCover`). The hooks are also exposed as `window._dhBeforePrint` / `window._dhAfterPrint` for pipelines that print without events.
- **`-ExportLibraries`:**
  - `Cdn` (default) loads on the first click, via `loadExportLib`, with SRI. A failure greys the buttons out; it never raises an `alert()`.
  - `Embed` inlines `DashHtml/Vendor/*.js` after a hash check; it refuses a file containing `</script` or `<!--` with `<script`.
  - `None` removes the XLSX/PDF buttons.
  - The URLs and hashes live in **one** place: `Private/Get-DhExportLibraries.ps1`.

---

## 8 — Critical gotchas (AI should always check these)

1. **Declaration order.** Declare tables before any block that references them by `TableId` (`Add-DhFilterCard`, `Add-DhBarChart`, `Add-DhPieChart` Mode A, `Set-DhTableLink`, `Add-DhAlertBanner -Action`, `Add-DhStatusGrid` cell `LinkTableId`, summary tile `Action`, `Add-DhRangeBar -TableId`, `Add-DhFindings` `AffectedTableId`). What actually happens otherwise: `Add-DhBarChart` / `PieChart` / `FilterCard` **throw** when another table already exists but this one does not yet, and skip the check when no table exists; `Set-DhTableLink` always throws. The runtime itself is order-independent (table-fed blocks render after every engine exists, verified in 2.1.4). Since 2.1.4 `Export-DhDashboard` **warns** about every reference to a table that never appears, so a typo is no longer a silent no-op.

2. **`Icon` is decorative.** Pass an emoji (`🖥`, `⚠`, `🔒`, `🌐`) or unicode glyph, or omit. **Don't pass bare ASCII letters like `'X'` or `'B'`** — they render as ugly single characters in the corner.

3. **Standard tile size is intentional.** `Style='tile'` (default) value typography is ~1.6 rem. If the user feels tiles are "too small", they probably want `Style='bignumber'` for headlines.

4. **`-Rag` wins over `Thresholds=`.** When both are supplied on the same item / column, the `Rag` shape is used and the legacy `Thresholds` array is discarded. Don't supply both unless you understand this.

5. **`Rag.NoData=$true` is the only way to render null values as `cell-nodata`.** Without it, null cells render blank (table) or throw (`Add-DhSummary` gauge tile, `Add-DhBullet`).

6. **`Add-DhBarChart` click-filter is single-series only.** When `-Stacked` is set, `-ClickFilters` is a no-op (stacked bars have no single value to filter by).

6a. **`-ClickFilters` requires 2.1.3+ to do anything.** In every earlier version the bar rendered as clickable and clicking it threw `ReferenceError: engines is not defined` — the handler was an inline `onclick`, evaluated in global scope where the runtime's `engines` registry is invisible. A label containing `"` could also inject HTML attributes. The runtime is baked into each generated HTML file, so **updating the module is not enough — the dashboard must be regenerated.**

6b. **A click applies a *text* filter, not an exact-value match.** It is the same code path as typing into the search box (`engine.applyTextFilter`), so a bar labelled `X` also matches a row containing `Xenon`. The chart then re-aggregates against the filtered rows and collapses to the clicked bar; the `×` button restores the full distribution. If you need exact-value semantics, use `Add-DhFilterCard` instead.

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

26. **A block given BOTH `-NavGroup` and `-NavSubGroup` is unreachable in 1.x (fixed in 2.0.0).** `showSubGroup` (`Get-DhJsNav.ps1:200-204`) hides with `style.display='none'` **and** `classList.remove('panel-active')`, but shows again by clearing **only** the inline style. Since `.block-section { display:none }` / `.block-section.panel-active { display:block }` (`Get-DhCssBase.ps1:827-828`), a section that lost `panel-active` stays invisible no matter what the inline style says. Reproduced in a browser: a block in the **first** subgroup shows on load but disappears after any pill click (only a full group round-trip restores it); a block in **any other** subgroup is **never visible at all**. **Tables are unaffected** — they use the subnav-link path. Fails **silently**: zero console output, just an empty panel. This is the class of bug no functional test catches, because nothing throws — see [plan-v2.md](plan-v2.md) §WP2 for the structural "no content unreachable" test that will pin it.

---

## 9 — Theme selection

`New-DhDashboard -Theme <name>` selects from six families, each with embedded light + dark variants (toggle at runtime via the nav-bar button):

| Family | Use when… |
|---|---|
| `Default` | General-purpose, blue accents, system UI font. |
| `Azure` | Microsoft Azure / 365 branding (Segoe UI, Azure blue). |
| `VMware` | VMware-ecosystem dashboards (VMware green; Inter if the reader has it). |
| `Grey` | Neutral / muted, no brand colour. |
| `Company` | Crimson + Montserrat if the reader has it. Marketing / executive reports. |
| `Rag` (v1.4) | **Strict Office/Excel RAG palette** (`#375623` / `#7F4B00` / `#9C0006` / `#595959`). Use when audit / compliance / finance audience needs spreadsheet parity. |

All themes define `--cell-ok-fg`, `--cell-warn-fg`, `--cell-danger-fg`, `--cell-nodata-fg` (v1.4) + bg variants. Use these as CSS variables; never hardcode colours.

### 9.1 — The v2.7.0 token contract (read before touching a theme file)

Four rules now hold across all twelve theme files. `Tools/Test-DhContrast.ps1` enforces the
first two over 61 selectors (was 33) and ~5,700 measurements; it must report **0 below the
minimum** before a release.

1. **`--bg-header` is the theme's own `--accent-secondary`** in light mode, with
   `--header-fg: #FFFFFF` and `--header-fg-muted: rgba(255,255,255,0.94)`. The 0.94 is not
   cosmetic: at 0.82 the muted header text measured 3.97 on VMware's band and 4.08 on
   Azure's, the two lightest bands. In dark mode the band is a deep tint of the accent hue
   (saturation taken from the theme's own accent, so `Rag` and `Grey` stay neutral) with at
   least 1.30 contrast against `--bg-page`. Before 2.7.0 `Grey` and `Azure` set it to
   *exactly* `--bg-page`, so the band did not exist.
2. **Every text token clears 4.5:1 against every background it can land on** — not only
   `--bg-surface` and `--bg-page`, but `--bg-row-alt`, `--bg-thead`,
   `--chart-container-bg`, and each of those composited under `--progress-track-bg` (the
   8% overlay behind `.dh-kv-item`) or the element's own `--cell-*-bg` tint. This is what
   a first pass missed: `--text-muted` was corrected against surface and page and still
   failed on `.dh-kv-label` at 3.80.
3. **`--size-2xs` (0.72rem / 11.5px) is the floor**, for badges and chips only. Nothing in
   the HTML goes below it. The exception is the network-map SVG labels
   (`.nm-edge-label text` and `.nm-node-badges` at 10.5px, `.nm-lane-label` /
   `.nm-group-label` at 11px): node and edge geometry is computed from hardcoded character
   widths in `Get-DhJsNetwork.ps1` (`lw = len * 6 + 10`, `maxChars = (nw - 34) / 6.6`, rect
   `height: 16`), so the type cannot move without retuning the layout — and network-map
   layouts must stay deterministic.
4. **Tracking is three tokens** — `--track-tight` (-0.02em, display numerals and the report
   title), `--track-none` (0), `--track-label` (0.04em). `text-transform: uppercase`
   survives on 8 rules only: the three `th` rules, `.summary-label`, `.cell-badge`,
   `.finding-badge`, `.record-metric-label` and the SVG `.nm-lane-label`. Block titles are
   sentence case. Before 2.7.0 there were 38 uppercase rules and 10 tracking values.

Two consequences worth knowing when editing:

- **`body.theme-forced-light` / `-dark` are gone.** They were unreachable (both stylesheets
  are always embedded, and `applyThemeMode` only falls back to them when one is missing)
  and carried no `--accent-*`, `--chart-*`, `--header-fg` or font tokens, so they would
  have stripped every brand colour if they ever had engaged.
- **No theme fetches a font.** A generated report makes zero network requests. `Company`
  and `VMware` name Montserrat and Inter first in their stack, so a reader who has the font
  installed sees it and everyone else gets Segoe UI. The old `@import` from
  `fonts.googleapis.com` broke the single-file promise and failed silently offline.

### 9.2 — `-Density` (2.7.0)

`New-DhDashboard -Density Normal|Compact|Comfortable` sets the opening density; the runtime
button still cycles all three, and a reader's choice in the URL hash wins. It reuses the
existing `DENSITY` controller in `Get-DhJsCore.ps1` — the only new plumbing is
`data-density` on `<html>` (`Export-DhDashboard.ps1`) and the boot branch in
`Get-DhJsBoot.ps1` that applies it when `URLState.load()` carries no density. The classes
land on `<body>`, so `body.density-compact` / `body.density-comfortable` redefine the size
tokens and the whole label layer scales, not just table rows. Compact never goes below
11.2px.

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
│   │   ├── Add-DhNetworkMap.ps1       ← v2.4
│   │   ├── Add-DhTreeFilter.ps1       ← v2.4
│   │   ├── Add-DhTreeTable.ps1        ← v2.5
│   │   ├── Add-DhHtmlBlock.ps1
│   │   ├── Add-DhRangeBar.ps1         ← v2.1
│   │   ├── Add-DhFindings.ps1         ← v2.2
│   │   ├── Add-DhGlobalFilter.ps1     ← v1.9
│   │   └── Add-DhCollapsible.ps1
│   ├── Vendor/                        ← v2.2: SheetJS / jsPDF / AutoTable + licences (-ExportLibraries Embed)
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
│       ├── Test-DhReportLinks.ps1     ← v2.1.4: export-time link lint
│       ├── ConvertTo-DhTileJson.ps1   ← v2.2: the one summary-tile serialiser
│       ├── ConvertTo-DhSeverity.ps1   ← v2.2: critical|warning|info|ok + high/medium/low aliases
│       ├── Get-DhTableFieldNames.ps1  ← v2.2: table fields + bar aggregate validation
│       ├── Get-DhExportLibraries.ps1  ← v2.2: XLSX/PDF library URLs + SRI hashes, Embed
│       ├── Get-DhJsPrint.ps1          ← v2.2: JS print arrangement (beforeprint/afterprint)
│       ├── Get-DhJsDrawer.ps1         ← v2.3: renderSections, the detail drawer, key-value and record-list renderers
│       ├── Get-DhJsTreeTable.ps1      ← v2.5: dhTtLinks / dhTtPaths / dhTtNested (pure), renderTreeTable (Add-DhTreeTable)
│       ├── Get-DhJsTree.ps1           ← v2.4: dhPathMatch, TreeFilter, renderTreeFilter (Add-DhTreeFilter)
│       ├── Get-DhJsNetwork.ps1        ← v2.4: dhNetLayout / dhNetEdgeGeom / dhNetPath (pure), renderNetworkMap
│       ├── Get-DhJsSearch.ps1         ← v2.4: report search (New-DhDashboard -Search)
│       ├── ConvertTo-DhSections.ps1   ← v2.3: section specs, detail specs, status names (PowerShell side)
│       ├── ConvertTo-DhSectionsJson.ps1 ← v2.3: their JSON
│       └── Build-DhTableSections.ps1
├── Tests/
│   ├── DashHtml.Tests.ps1             ← Pester 5; 581 tests at 2.3.0; covers every cmdlet + Examples smoke test
│   ├── DashHtml.Nav.Tests.ps1         ← nav truth table, reachability, layout (47)
│   ├── DashHtml.Design.Tests.ps1      ← companion module (27)
│   ├── DhTestHelpers.ps1              ← Export-DhTestHtml, Get-DhTestJsFunction (v2.1.4)
│   └── js/nav.test.js                 ← Node: drives the shipped matcher + table toggle (v2.1.4)
├── Examples/
│   │  Demo-<Domain>.ps1  = a realistic report for that domain
│   │  Demo-*.ps1 = a realistic report; Feature-*.ps1 = one capability (see Examples\README.md)
│   ├── Demo-ActiveDirectory.ps1
│   ├── Demo-VMware.ps1
│   ├── Demo-AzureInfrastructure.ps1
│   ├── Demo-Microsoft365.ps1
│   ├── Feature-Navigation.ps1 / Feature-NavigationSidebar.ps1
│   ├── Feature-Tables.ps1 / Feature-Charts.ps1 / Feature-KpiTiles.ps1
│   ├── Feature-Assessment.ps1 / Feature-MapsAndGrids.ps1
│   ├── Feature-FiltersAndSearch.ps1 / Feature-PageElements.ps1
│   └── (Tools\Show-DhNavMap.ps1 prints the menu and per-view content of an exported file)
├── Tools/   Show-DhNavMap, Test-DhV2Upgrade, Test-DhPrint (PDF), Test-DhContrast (WCAG ratios, 12 themes), Test-DhA11y (accessibility audit);
│            helpers Find-DhBrowser.ps1, BrowserProbe.ps1 (headless browser + loopback result), contrast-measure.js, a11y-probe.js, contrast-selectors.json
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

   **If the block re-renders after `renderBlocks()`** — i.e. it reads a table and
   must follow filter changes, like `barchart` / `piechart` Mode-A / `rangebar` —
   register it in the boot loop (`Get-DhJsBoot.ps1`) and in
   `TableEngine.prototype._refreshLinkedBarCharts` (`Get-DhJsTable.ps1`), and in
   BOTH resolve the target with `blockRenderTarget(block)`:

   ```js
   var t = blockRenderTarget(block);
   if (t.container) renderX(t.container, t.block);
   ```

   Never `document.getElementById('block-' + block.id)` in those loops. That is
   the OUTER element; for a collapsible block `renderBlocks()` already replaced it
   with a toggle header and rendered into `#cinner-<id>`, so writing to the outer
   element destroys the header, loses the open/closed state on every filter change,
   and prints the title twice. This was a live defect in `barchart` and `piechart`
   until 2.1.1. Also emit your `<h3>` conditionally (`block.title ? … : ''`) —
   `blockRenderTarget` blanks the title so the header does not appear twice.

   **Never emit an inline `onclick` (or any `on*` attribute).** Bind with
   `addEventListener` after the markup is written, from inside the runtime IIFE.
   Two reasons, both of which bit `barchart` until 2.1.3:

   - Inline handlers are evaluated in **global** scope. Everything the runtime
     owns — `engines`, `URLState`, `BLOCKS_CONFIG`, `esc` — is a `var` inside the
     IIFE and invisible there. `-ClickFilters` threw `ReferenceError: engines is
     not defined` on every click for its entire life. Do **not** "fix" that by
     exporting to `window`; bind the listener instead.
   - Building a handler string means hand-escaping data into an HTML attribute.
     The old line escaped single quotes only, so a label containing `"` broke out
     of the attribute and the remaining JS was parsed as attributes — a real
     injection sink fed by table data. A closure captures the value, so there is
     nothing left to escape.

   ```js
   container.innerHTML = '…';                       /* write the markup first */
   var els = container.querySelectorAll('.thing');  /* then bind */
   for (var i = 0; i < els.length; i++) {
     (function (el, value) {
       el.addEventListener('click', function () { doSomething(value); });
     })(els[i], entries[i].value);
   }
   ```

   Bind **after** the `innerHTML` write — the elements do not exist before it. If
   the element is clickable, also give it `role="button"`, `tabindex="0"` and an
   Enter/Space `keydown` handler: a `<div>` with a click listener is not
   keyboard-reachable.
5. **Add CSS** to `Private/Get-DhCssBase.ps1`. Reuse existing tokens: `--cell-ok-fg` / `--cell-warn-fg` / `--cell-danger-fg` / `--cell-nodata-fg` for RAG colouring, `--chart-1`..`--chart-8` for categorical colours, `--accent-primary` for the brand accent.
6. **Add the BlockType to `$knownBlockTypes`** in `Export-DhDashboard.ps1` (next to the switch). Otherwise the export-time lint (`Private/Test-DhReportLinks.ps1`, v2.1.4) warns that the block type is unknown. If the block references a table (`TableId`, `LinkTableId`, `Action.TableId`), add a case to `Test-DhReportLinks` so a dangling id warns too.
7. **Tell the tooling about it** — each list below is hand-maintained, and `Add-DhRangeBar` was missing from three of them from 2.1.0 to 2.1.3:
   - `DashHtml.Design/Private/DhSchema.ps1` → `$script:DhTypeToCmdlet` (block type → cmdlet)
   - `DashHtml.Design/Public/ConvertFrom-DhScript.ps1` → `$reverse` (cmdlet → block type)
   - `DashHtml.Design/Public/Update-DhScript.ps1` and `Tools/Test-DhV2Upgrade.ps1` → `$blockCmds`
   - `Build-DhReference.ps1` → `$cmdMeta` (tag, colour, group in the reference)
   - the skill prose under `skills/dashhtml/` (`Build-DhSkill.ps1` warns about any public cmdlet the skill never mentions)
8. **Write Pester tests** in `Tests/DashHtml.Tests.ps1` — at minimum, validation paths + a smoke test that checks the emitted HTML. Add the cmdlet to the duplicate-Id `-ForEach` in `Describe 'Duplicate-Id guard on all block cmdlets'`. `Tests/DhTestHelpers.ps1` has `Export-DhTestHtml` (export to temp, return the HTML, optionally the warnings) and `Get-DhTestJsFunction` (one runtime function's source).
9. **If it navigates to a table**, call `jumpToTable(tableId, filter)` (v2.1.4). Never set `engine.filterText` yourself.

**Reusable helpers already at module-level JS scope:**
- `esc(s)` — HTML-escape a value
- `cssVar(name, fallback)` — read a CSS custom property
- `chartPalette()` — array of 8 chart colours from `--chart-1..8`
- `classToAccent(cls)` / `classToAccentBg(cls)` — map `cell-ok|warn|danger|nodata` to its CSS var
- `pickThresholdClass(value, thresholds)` — match a value against an array of `{min,max,class}` bands (highest-Min-wins)
- `SPARK.build(series, opts)` — inline SVG sparkline (line/area/bars)
- `DELTA.build(item)` — trend arrow + delta text for tiles
- `buildTile(item)` — tile renderer (dispatches to standard/bignumber/gauge/verdict/score/maturity)
- `renderSections(sections)` / `renderSection(sec)` *(v2.3)* — the one pure renderer for kv / bars / statusList / checks / table / text / links; returns an HTML string, escapes every value
- `dhDrawerOpen(spec, { opener, restore })` / `dhDrawerClose(skipFocus)` *(v2.3, also `window._dhOpenDrawer` / `_dhCloseDrawer`)* — the shared side panel; `spec = { title, subtitle, sections, tableId, filter }`
- `createPanZoom({ innerDiv, svgEl, vp, toolbar, initH, getContent })` *(v2.3)* — pan, wheel/toolbar zoom, fit and resize for an SVG viewport; shared by maps
- `buildPieSvg(entries, opts)` — pie / donut SVG
- `fillStrip(container, items, opts)` — populate a container with tiles, with optional collapsible chrome
- `URLState.save() / load()` — persist active panel / filters / dismissed banners to URL hash
- `engine.applyTextFilter(value)` *(v2.1.3)* — **the** way to apply a text filter to a table. Sets `filterText`, resets the page, syncs the search input, shows/hides the `×`, re-renders the table, refreshes linked bar/pie/range blocks and in-table charts, and saves URL state. The search box, pie-slice clicks and bar clicks all go through it. Add a step here, never in a caller — three partial copies had already drifted apart before it existed.
- `jumpToTable(tableId, filterText)` *(v2.1.4, also `window._dhJumpToTable`)* — **the** way to send the reader to a table: shows its nav panel, unfolds it if collapsed, filters through `applyTextFilter`, scrolls it into view. Alert actions, tile actions, status-grid cells and topology nodes all use it.
- `applyThemeMode('light'|'dark')` / `DENSITY.set(mode)` *(v2.1.4)* — change theme or density and keep the toggle button in sync. Both persist through `URLState`; the theme also goes to `localStorage['dh-theme']`.
- `_resolveCssColor(cssExpr)` *(v1.5)* — resolve any CSS colour expression (`var(--chart-1)`, `#abc`, `rgba(...)`) to an `[r,g,b]` triple. Used by `renderHeatmap` to interpolate colours that follow the active theme.
- `_lerp3(a, b, t)` / `_rgbStr([r,g,b])` *(v1.5)* — linear interpolate two RGB triples / format a triple back to `rgb(r,g,b)`.

**Reusable helpers in PowerShell:**
- `Test-DhReportLinks` *(v2.1.4)* — export-time cross-reference lint; returns one message per dangling table id or unknown block type
- `ConvertTo-DhJsonString` — JSON-string-encode a PowerShell value
- `ConvertTo-DhRagThresholds` — convert a `Rag` hashtable to a `Thresholds` array + `NoData` flag
- `ConvertTo-DhSections` / `ConvertTo-DhDetailSpec` / `ConvertTo-DhStatusName` *(v2.3)* — validate and normalise section and detail specs; `ConvertTo-DhSectionsJson` / `ConvertTo-DhDetailJson` serialise them

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

Tests run quickly (~3 min for 807 tests across the three suites at 2.5.1 (plus 10 node tests: node --test "Tests/js/*.test.js"); the Examples smoke test adds ~20 s of subprocess runs). The full suite must always pass before declaring work complete.

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

## 15 — Upgrading existing scripts to v2.0.0 (audit checklist)

> **Applies to:** DashHtml **2.0.0 and later** (shipped 2026-08-26; current
> release 2.1.3). See [plan-v2.md](plan-v2.md).
> `Update-DhScript` (in the **DashHtml.Design** module) automates every check
> below and has a rewrite mode: `-Apply`.

2.0.0 carries **two breaking changes** and one behaviour fix.

### 15.0 — Run the audit first

```powershell
.\Tools\Test-DhV2Upgrade.ps1 -Path .\Examples      # or any folder of scripts
.\Tools\Test-DhV2Upgrade.ps1 -Path 'C:\Scripts' -Detailed
```

Read-only, AST-based, never executes your scripts. It reports every affected call with file and line.

> **Do not audit with grep.** These calls routinely span several lines with backtick
> continuation, so a line-oriented pattern silently under-reports. On `Examples/` the
> obvious greps find **0** issues; the AST audit finds **13**. Under-reporting is the
> exact failure class this release exists to fix.

Current result for the bundled examples:

```
  9  15.1 table relies on the removed automatic menu entry
  4  15.2 -AllowHtml default flips to $false
  0  15.3 block in a subgroup
```

### 15.1 — ADVISORY: tables now use one uniform path model

**What changed.** In 1.x, `Add-DhTable -NavGroup 'G'` produced its own subnav link through a table-only code path; blocks had no equivalent (that asymmetry was defect #2). In 2.0.0 every item — table or block — sits at the path it declares, under one rule.

**Your scripts keep working — no edit needed.** The compat shim maps `-NavGroup 'G'` on a table to `'G/<TableId>'` with `Exact` scope, reproducing the 1.x menu entry exactly. Verified against a pure 1.x script: each table keeps its own node.

Migrating to `-NavPath` is **optional**, and buys explicit control over the node key, its label, and its depth.

**Convert (optional):**

| 1.x | 2.0.0 |
|---|---|
| `Add-DhTable -TableId 'vols' -NavGroup 'Storage'` | `Add-DhTable -TableId 'vols' -NavPath 'Storage/vols' -NavLabel 'Volumes'` |
| `Add-DhTable -TableId 'vols' -NavGroup 'Storage' -NavSubGroup 'Capacity'` | `Add-DhTable -TableId 'vols' -NavPath 'Storage/Capacity/vols'` |

The path node is keyed on **`TableId`**, not `Title` — `TableId` is the only value the module enforces as unique (`Add-DhTable.ps1:152`). `Title` becomes the `-NavLabel`. Keying on `Title` would silently merge two same-titled tables into one node.

**⚠ Converting a BLOCK? Restate the scope.** `-NavPath` defaults to `Exact`, but
the block compat shim defaults to `Subtree`. The naive rewrite silently hides
content:

```powershell
Add-DhBarChart ... -NavGroup 'Storage'                          # visible across all of Storage
Add-DhBarChart ... -NavPath 'Storage'                           # ❌ only the bare 'Storage' node
Add-DhBarChart ... -NavPath 'Storage' -NavScope Subtree         # ✅ equivalent to the original
```

The full mapping the shim applies (`Private/Resolve-DhNavDeclaration.ps1`):

| Old declaration | Item | Path | Scope |
|---|---|---|---|
| `-NavGroup 'G'` | Table | `G/<TableId>` | `Exact` |
| `-NavGroup 'G' -NavSubGroup 'S'` | Table | `G/S/<TableId>` | `Exact` |
| *(none)* | Table | `<TableId>` | `Exact` |
| `-NavGroup 'G'` | Block | `G` | **`Subtree`** |
| `-NavGroup 'G' -NavSubGroup 'S'` | Block | `G/S` | **`Subtree`** |
| *(none)* | Block | *(empty)* | **`Global`** |

Nav is never rewritten automatically by `Update-DhScript` — it is reported as
`advisory` and left to a human. After any nav migration, regenerate the report
and **click every menu node**: nav bugs fail silently, with no console output.

### 15.2 — BREAKING: `-AllowHtml` defaults to `$false`

**What changed.** The default flips from `$true` (raw markup) to `$false` (HTML-encoded). This has been announced by a runtime warning since 1.5.x. Affects **4 cmdlets**: `Add-DhHtmlBlock`, `Add-DhCollapsible`, `Add-DhAlertBanner`, `Add-DhTabs`.

**Find affected calls:** audit issue **15.2** — it flags exactly those four cmdlets called *without* an explicit `-AllowHtml`. Any of them passing markup in `-Content` will start rendering it as literal text.

**Convert:** add `-AllowHtml:$true` where you genuinely intend raw HTML. Where the content is externally sourced, change nothing — the new default is the safe one, and that is the point of the flip.

The quickest way to spot these today: run the script against **1.10.4** and read the warnings. Every call that will change behaviour already prints one:

> `… content contains HTML and is rendered as raw markup. DashHtml 2.0.0 will change the -AllowHtml default …`

**A clean 1.10.4 run with no such warnings means nothing to do here.**

### 15.3 — Behaviour fix: blocks in a subgroup start appearing

**What changed.** In 1.x a **block** (chart, summary, HTML block …) given both `-NavGroup` and `-NavSubGroup` was unreachable — see gotcha #26 below. In 2.0.0 it renders correctly. Content that has been silently missing will reappear.

**Find affected calls:** audit issue **15.3**.

Not an error to fix — but if a dashboard was rewritten to *dodge* this bug (e.g. flattened to top-level tabs), that workaround is now unnecessary. It stays valid; cleanup is optional.

### 15.4 — Not breaking, no action needed

| Pattern | Status in 2.0.0 |
|---|---|
| Blocks with `-NavGroup` only, no subgroup | ✅ unchanged — visible across the whole group (`-NavScope Subtree`) |
| Cmdlets with no nav parameters | ✅ unchanged — page-global (`-NavScope Global`) |
| `-NavGroup` / `-NavSubGroup` themselves | ✅ **kept forever** as a compatibility shim; they map onto `-NavPath`/`-NavScope` at `Add-Dh*` time |
| Old bookmarked `#{group,panel}` URLs | ✅ still resolve, via a shim in `URLState.load` |

### 15.5 — Triage summary

Run the audit, then:

- **No hits at all** → nothing to do; the upgrade is a drop-in.
- **Only 15.3 hits** → nothing to fix; expect previously invisible content to reappear.
- **15.1 or 15.2 hits** → real edits required. `Update-DhScript` will handle them, or convert by hand using the tables above.

---

## 16 — When in doubt

1. **Look at `Examples/`** — the four `Demo-*.ps1` reports (Active Directory, VMware, Azure, Microsoft 365) show how a menu is laid out with realistic data, and the nine `Feature-*.ps1` scripts show one capability each (`Examples\README.md` lists them and the menu rules; `Tools\Show-DhNavMap.ps1` prints a report's menu).
2. **Look at `DashHtml-Reference.html`** — full Get-Help output for every public cmdlet, with parameter signatures and defaults.
3. **Look at `docs/v1.4-plan.md` and `docs/KPI_Dashboard_Specification.docx`** for the design rationale of the v1.4 widget set.
4. **Look at the tests** — `Tests/DashHtml.Tests.ps1` documents every supported parameter combination, validation rule, and threshold edge case.

---

*End of dev/AI reference. Module version 2.1.3, last revised 2026-09-09.*

*A distilled version of this document ships as the **`dashhtml` Claude skill**
(`~\.claude\skills\dashhtml`), so it is available in every project rather than
only inside this repo. Regenerate its mechanical parts and re-check it for drift
with `.\Build-DhSkill.ps1`; package it for claude.ai with `-Zip`.*














