# DashHtml

A PowerShell 7 module for generating **interactive, self-contained HTML dashboards** from any structured data — sortable/filterable tables, KPI tiles, bar charts, collapsible sections, and clickable filter cards. The output is a single HTML file with all data and styles embedded — no external dependencies at viewing time.

---

## Features

- **Self-contained output** — one HTML file, no companion CSS or JS files
- **Sortable, filterable, pageable tables** — multi-column sort (Shift+Click), text filter, configurable page size
- **KPI summary tiles** — icons, formatted values, threshold colouring; optional sparklines, trend/delta arrows, big-number hero style, semicircle gauge style, click-to-jump actions
- **Charts** — bar (horizontal, stacked), pie / donut, line / area with target-line annotation, bullet (actual-vs-target), inline sparklines in tables and tiles
- **Specialised widgets** — alert banners (dismissible, page-global or per-panel), status grid (RAG matrix), event feed (chronological audit trail), heatmap (sequential / diverging 2-D colour scale), topology map (parent-child trees), inline tabbed content blocks
- **Clickable filter cards** — single or multi-select, instant table filtering
- **Collapsible sections** — key-value card grids or free-form HTML
- **Master-detail table linking** — clicking a row filters a child table
- **Two-tier (or three-tier) navigation** — flat nav, grouped primary-tabs + subnav strip, optional subgroup pills
- **Per-NavGroup summary strips and alert banners** — each panel gets its own KPI hero row and banner set
- **Auto-refresh** — `New-DhDashboard -AutoRefresh '30s' / '5m' / '1h'` for wall-display ops dashboards
- **Client-side export** — CSV (no CDN), XLSX and PDF (cdnjs, requires internet)
- **Light/dark theme toggle** — both variants embedded, switchable at runtime
- **Six theme families** — Default, Azure, VMware, Grey, Company, Rag (the v1.4 family using the Office/Excel-compatible RAG palette)
- **Column features** — progress bars, badges, threshold colouring (unified `-Rag` parameter), row highlighting, pinned first column, footer aggregates, number/currency/bytes/percent/datetime/duration formatting, sparkline cells

---

## Requirements

- PowerShell 7.0 or later

---

## Installation

### From source

```powershell
# Clone the repository, then:
.\Install.ps1                    # CurrentUser scope (no admin required)
.\Install.ps1 -Scope AllUsers    # AllUsers scope (requires admin)
.\Install.ps1 -Force             # Overwrite an existing installation
```

`Install.ps1` installs **both** the core `DashHtml` module and the optional
[`DashHtml.Design`](DashHtml.Design/README.md) companion when the companion is
present (each into its own versioned folder). The core is always installed
first — the companion reads its cmdlet metadata at runtime.

```powershell
.\Install.ps1 -SkipDesign        # core module only
.\Install.ps1 -DesignOnly        # companion only
.\Install.ps1 -Uninstall         # remove all versions of both (per scope)
.\Install.ps1 -Uninstall -DesignOnly   # remove just the companion
```

It prefers a built `dist\<Module>\` when present and falls back to the in-repo
source; override either with `-Source` / `-DesignSource`. `-WhatIf` shows exactly
what would be copied without touching anything.

### Manual

Copy each module folder to a directory in `$env:PSModulePath`, under a versioned
subfolder:
```
<modules-root>\DashHtml\2.0.0\
<modules-root>\DashHtml.Design\1.0.0\      (optional companion)
```

---

## Quick start

```powershell
Import-Module DashHtml

# 1. Create the dashboard object
$report = New-DhDashboard -Title 'Server Inventory' -Theme Default

# 2. Add data
$servers = @(
    [PSCustomObject]@{ Name='srv-001'; OS='Windows Server 2022'; CPU=42; Status='OK'   }
    [PSCustomObject]@{ Name='srv-002'; OS='Windows Server 2019'; CPU=78; Status='Warn' }
    [PSCustomObject]@{ Name='srv-003'; OS='Ubuntu 22.04';        CPU=15; Status='OK'   }
)
Add-DhTable -Report $report -TableId 'servers' -Title 'Servers' -Data $servers

# 3. Export
Export-DhDashboard -Report $report -OutputPath '.\dashboard.html' -Force -OpenInBrowser
```

---

## Declaration order (important)

**Always declare a table _before_ any object that references it.** This is the single most common source of "filter does nothing" / "chart is empty" / "link broken" issues.

The cmdlets below depend on a previously declared table identified by its `-TableId` / `-TargetTableId` / `-MasterTableId` / `-DetailTableId`. If the referenced table has not been added yet when the dependent cmdlet runs, the binding silently fails (the referenced data simply isn't available to bind against):

| Dependent cmdlet | Depends on |
|------------------|------------|
| `Add-DhFilterCard` | `-TargetTableId` must already exist |
| `Add-DhBarChart` | `-TableId` must already exist |
| `Set-DhTableLink` | both `-MasterTableId` and `-DetailTableId` must already exist |

### Correct order

```powershell
# 1. Tables first
Add-DhTable -Report $report -TableId 'items' -Title 'Items' -Data $items
Add-DhTable -Report $report -TableId 'groups' -Title 'Groups' -Data $groups

# 2. Then anything that references them
Add-DhFilterCard -Report $report -Id 'region-fc' -TargetTableId 'items' -FilterField 'Region' -Cards $cards
Add-DhBarChart   -Report $report -Id 'status-bc' -TableId 'items' -Field 'Status'
Set-DhTableLink  -Report $report -MasterTableId 'groups' -DetailTableId 'items' -MasterField 'GroupId' -DetailField 'GroupId'
```

### Wrong order (filter / chart / link will not work)

```powershell
# ❌ FilterCard declared before its target table
Add-DhFilterCard -Report $report -Id 'region-fc' -TargetTableId 'items' -FilterField 'Region' -Cards $cards
Add-DhTable      -Report $report -TableId 'items' -Title 'Items' -Data $items
```

### Tip: visual position vs. declaration order

When using `-NavGroup`, a filter card or bar chart will still render **above** its table in the UI even if the table was declared first — the layout engine groups related blocks visually. So you can keep the safe declaration order (tables first) without sacrificing the desired on-screen layout.

---

## Cmdlet reference

| Cmdlet | Purpose |
|--------|---------|
| `New-DhDashboard` | Create the root dashboard object |
| `Add-DhTable` | Add a sortable/filterable data table |
| `Add-DhSummary` | Add KPI metric tiles |
| `Add-DhBarChart` | Add a horizontal bar chart |
| `Add-DhFilterCard` | Add a clickable card filter grid |
| `Add-DhHtmlBlock` | Add a free-form HTML block |
| `Add-DhCollapsible` | Add a collapsible card/content section |
| `Add-DhAlertBanner` | Add a top-of-page alert banner (severity, dismiss, action) |
| `Add-DhPieChart` | Add a standalone pie / donut chart (from table or explicit slices) |
| `Add-DhBullet` | Add a bullet-chart block (actual vs target with performance bands) |
| `Add-DhLineChart` | Add a line / area chart with axes, multi-series, and optional target line |
| `Add-DhEventFeed` | Add a chronological severity-tagged event list (audit trail) |
| `Add-DhStatusGrid` | Add a rows × columns RAG status matrix (health grid) |
| `Add-DhHeatmap` *(v1.5)* | Add a rows × columns numeric heatmap (sequential / diverging colour scale) |
| `Add-DhTopologyMap` *(v1.5)* | Add a parent-child topology tree (AD forest, vCenter cluster, etc.) |
| `Add-DhTabs` *(v1.5)* | Add an inline tabbed content block (local pivot within one section) |
| `Set-DhTableLink` | Link a master table to a detail table |
| `Export-DhDashboard` | Write the self-contained HTML file |
| `Get-DhTheme` | List or inspect built-in theme families |

Use `Get-Help <cmdlet> -Full` for complete parameter documentation.

---

## Themes

Six built-in families — each includes a light and a dark variant, both always embedded in the output HTML. The toggle button in the nav bar switches at runtime.

| Family | Light | Dark | Font |
|--------|-------|------|------|
| `Default` | Light grey + blue | Near-black + cyan | System UI |
| `Azure` | Warm grey + Azure blue | Office dark + Azure | Segoe UI |
| `VMware` | White/navy + VMware green | Navy + VMware green | Inter |
| `Grey` | Warm grey + steel | Dark neutral + muted grey | System UI |
| `Company` | White + Crimson | Near-black + Crimson | Montserrat |
| `Rag` *(v1.4+)* | Spec-exact Office/Excel RAG palette on white | Office dark-mode RAG companions on near-black | System UI |

```powershell
# List all families
Get-DhTheme

# Inspect CSS for a specific family
$css = Get-DhTheme -Name Azure
$css.LightCss
$css.DarkCss

# Save CSS files to disk
Get-DhTheme -Name Company -SaveTo 'C:\Reports\css'
```

### The `Rag` theme (v1.4+)

Use this family when **strict Office/Excel parity** matters for your audience — auditors, compliance reviewers, finance reports. It uses the exact RGB values from the IT-infrastructure KPI dashboard specification (§7.2):

| Band | Foreground | Background |
|---|---|---|
| GREEN (`cell-ok`) | `#375623` | `#E2EFDA` |
| AMBER (`cell-warn`) | `#7F4B00` | `#FFF2CC` |
| RED (`cell-danger`) | `#9C0006` | `#FFDCE1` |
| GREY (`cell-nodata`) | `#595959` | `#F2F2F2` |

The other five families keep their brand-aligned RAG colours unchanged — switching to `Rag` is an explicit opt-in.

### Unified `-Rag` parameter (v1.4+)

Threshold rules were historically spelled out as an array of `Min`/`Max`/`Class` hashtables (per column on `Add-DhTable`, per item on `Add-DhSummary`). v1.4 adds a more readable **`Rag`** alternative that maps directly to the spec's GREEN / AMBER / RED / GREY bands. Both shapes are accepted; when both are supplied on the same item or column, `Rag` wins.

```powershell
# Defined once, reused on a gauge and on two table columns
$cpuRag = @{
    Green  = @{ Max = 70 }
    Amber  = @{ Min = 70; Max = 90 }
    Red    = @{ Min = 90 }
    NoData = $true    # ← paint null / missing cells with cell-nodata
}

Add-DhSummary -Report $report -Items @(
    @{ Style='gauge'; Label='CPU';  Value=42;    Max=100; Unit='%'; Rag=$cpuRag }
    @{ Style='gauge'; Label='Disk'; Value=95;    Max=100; Unit='%'; Rag=$cpuRag }
    @{ Style='gauge'; Label='Net';  Value=$null; Max=100; Unit='%'; Rag=$cpuRag }   # → cell-nodata
)

Add-DhTable -Report $report -TableId 'srv' -Title 'Servers' -Data $rows -Columns @(
    @{ Field='Host'; Label='Host' }
    @{ Field='Cpu';  Label='CPU %'; Align='right'; Rag=$cpuRag }
    @{ Field='Mem';  Label='Mem %'; Align='right'
       Rag=@{ Green=@{Max=80}; Amber=@{Min=80;Max=95}; Red=@{Min=95}; NoData=$true } }
)
```

Allowed keys on the `Rag` hashtable:
- `Green` — maps to `cell-ok`. Hashtable with optional `Min` and/or `Max`.
- `Amber` — maps to `cell-warn`. Same shape.
- `Red`   — maps to `cell-danger`. Same shape.
- `NoData` — boolean. When `$true`, null / empty / non-numeric cell values render with `cell-nodata` instead of being left blank. Also lets a gauge accept `Value=$null` and paint itself grey.

Bounds are interpreted as `Min ≤ value < Max` (either bound may be omitted). Unknown keys throw — typos surface as errors instead of silently doing nothing. The legacy `Thresholds=@(@{Min=...;Max=...;Class='cell-...'})` shape on columns and `Thresholds=` on tile items keeps working unchanged for backward compatibility.

### `cell-nodata` — fourth RAG state across all themes (v1.4+)

Every theme now defines `--cell-nodata-fg` / `--cell-nodata-bg` so missing / unmeasured / collection-failed values can be marked visually distinct from `0` or `OK`. Available as `cell-nodata` everywhere `cell-ok` / `cell-warn` / `cell-danger` worked previously: table cell thresholds, summary tile `Class`, html-block `-Style 'nodata'`, collapsible card `BadgeClass`, and the `badge-nodata` / `fill-nodata` / `row-hl-nodata` modifiers. Non-`Rag` themes pick a brand-appropriate neutral grey for the foreground.

```powershell
# Column threshold for a status that may be "NoData"
@{ Field='Status'; Label='Status'
   Thresholds=@(
       @{ Value='OK';     Class='cell-ok'     }
       @{ Value='Warn';   Class='cell-warn'   }
       @{ Value='Error';  Class='cell-danger' }
       @{ Value='NoData'; Class='cell-nodata' }   # ← v1.4
   )
}
```

---

## Tables

### Basic table

```powershell
$data = @(
    [PSCustomObject]@{ Name='alpha'; Region='us-east';  Count=10; Status='Active'   }
    [PSCustomObject]@{ Name='beta';  Region='eu-west';  Count=5;  Status='Inactive' }
    [PSCustomObject]@{ Name='gamma'; Region='ap-south'; Count=22; Status='Active'   }
)

Add-DhTable -Report $report -TableId 'items' -Title 'Item List' -Data $data
```

### Custom columns

```powershell
$cols = @(
    @{ Field='Name';   Label='Item Name'; Width='180px'; PinFirst=$true }
    @{ Field='Region'; Label='Region';    Width='120px' }
    @{ Field='Count';  Label='Count';     Align='right'; Aggregate='sum' }
    @{ Field='Status'; Label='Status';
       Thresholds=@(
           @{ Value='Active';   Class='cell-ok'     }
           @{ Value='Inactive'; Class='cell-warn'   }
           @{ Value='Error';    Class='cell-danger' }
       )
       RowHighlight=$true
    }
)

Add-DhTable -Report $report -TableId 'items' -Title 'Items' -Data $data -Columns $cols -PageSize 25
```

### Column formatting

```powershell
$cols = @(
    @{ Field='Name';     Label='Name' }
    @{ Field='Cost';     Label='Cost';    Format='currency'; Locale='en-US'; Currency='USD'; Decimals=2 }
    @{ Field='Size';     Label='Size';    Format='bytes'   }
    @{ Field='Uptime';   Label='Uptime';  Format='percent'; Decimals=1 }
    @{ Field='Duration'; Label='Runtime'; Format='duration' }
    @{ Field='Updated';  Label='Updated'; Format='datetime'; DatePattern='yyyy-MM-dd' }
)
```

### Long values: tooltip and resizable columns

Table cells never wrap — a value wider than its column is cut with an ellipsis, which keeps rows scannable but can hide the tail of a long string (a nested group chain, a DN, a stack frame). Two things make the full value reachable:

- **Hover a clipped cell** and its complete text appears as a tooltip. The tooltip is added only to cells that are *actually* clipped, measured after render — short cells stay tooltip-free, so hovering means something. Clipped cells also carry a dotted right edge as the visual cue.
- **Drag the right edge of any column header** to widen it. Double-click the grip (or press `Home` with it focused) to reset to the declared width; `←` / `→` nudge it 16px at a time. The width is per-viewer and per-session — it does not change the report for anyone else.

Headers truncate the same way, and a clipped header carries its full text as a tooltip too — worth knowing because a truncated header is the only thing naming the column.

Set a sensible starting width with the column's `Width` key. As of 2.1.1 a declared width is authoritative: previously a column declared wider than the stylesheet's cap was clipped at the cap anyway.

**Minimum width is 40px.** Before 2.1.2 the real floor was the header's own text — the table is `table-layout: auto`, where `width` is only a suggestion, and a header that could not clip pinned the column at roughly *label + 32px padding + sort icon*. A header like `Livello di autorizzazione` floored its column at 239px whatever you did.

```powershell
Add-DhTable -Report $report -TableId 'accessi' -Title 'Access by user' -Data $rows -Columns @(
    @{ Field='User';   Label='User';        Width='200px' }
    @{ Field='Path';   Label='Granted via'; Width='420px' }   # long nested group chains
)
```

Nothing needs enabling — this applies to every text column in every table.

### Sparkline cells (v1.4+)

Set `CellType='sparkline'` and feed the column **arrays** of numbers — each row renders an inline mini-chart. Same SVG helper as the tile sparkline (`SPARK.build`), so the look stays consistent between summary tiles and table cells.

```powershell
$rows = @(
    [PSCustomObject]@{ Host='srv-01'; Cpu24h=@(30,42,38,55,67,71,68,52); Mem24h=@(40,42,45,48,50,52,55,58) }
    [PSCustomObject]@{ Host='srv-02'; Cpu24h=@(80,85,90,95,92,88,84,82); Mem24h=@(70,72,75,80,82,85,88,90) }
    [PSCustomObject]@{ Host='srv-03'; Cpu24h=@(10,12,15,11,13,9,8,7);    Mem24h=@(20,18,22,25,20,18,15,12) }
    [PSCustomObject]@{ Host='srv-04'; Cpu24h=$null; Mem24h=@(60,65,70,75,80,85,90,95) }   # renders an em-dash
)

Add-DhTable -Report $report -TableId 'srv' -Title 'Server fleet' -Data $rows -Columns @(
    @{ Field='Host';   Label='Host' }
    @{ Field='Cpu24h'; Label='CPU 24h'; Align='right'
       CellType='sparkline'; SortBy='max';  SparklineStyle='line' }
    @{ Field='Mem24h'; Label='Mem 24h'; Align='right'
       CellType='sparkline'; SortBy='last'; SparklineStyle='area' }
)
```

Sparkline-cell column keys:
- `CellType` — `'sparkline'` activates this renderer.
- `SortBy` — array-to-scalar reduction for sorting: `'last'` (default) / `'avg'` / `'max'` / `'min'` / `'sum'`. Clicking the column header sorts rows by the reduction.
- `SparklineStyle` — `'line'` (default) / `'area'` / `'bars'`. Same options as the tile sparkline.

Threshold colouring and per-cell `Format` are skipped for sparkline columns (the value is an array, not a scalar). Null / missing values render as a muted em-dash.

---

## KPI summary tiles

Since **1.3.2** the tile strip is wrapped in a collapsible header bar by default (same chrome as `Add-DhCollapsible`), with a badge showing the tile count. Existing scripts get the new look automatically — no parameter changes required.

```powershell
Add-DhSummary -Report $report -Items @(
    # Icon is decorative — pass an emoji ('🖥', '⚠', '🔒'), a unicode glyph,
    # or HTML if you use a font-icon library. Omit for clean iconless tiles.
    @{ Label='Total';    Value=247 }
    @{ Label='Active';   Value=231; Class='cell-ok'     }
    @{ Label='Warnings'; Value=12;  Class='cell-warn'   }
    @{ Label='Critical'; Value=4;   Class='cell-danger' }
    @{ Label='Storage';  Value=1610612736; Format='bytes' }
)
```

### Customising the collapsible header

```powershell
Add-DhSummary -Report $report `
    -Title 'Key metrics' -Icon 'K' -DefaultOpen $false `
    -Items @(
        @{ Label='Total';    Value=247 }
        @{ Label='Active';   Value=231; Class='cell-ok'     }
        @{ Label='Warnings'; Value=12;  Class='cell-warn'   }
        @{ Label='Critical'; Value=4;   Class='cell-danger' }
    )
```

Collapsible-related parameters:
- `-Collapsible` — wrap in a collapsible container (default `$true`). Pass `-Collapsible:$false` to render a flat tile strip with no header (the pre-1.3.2 behaviour).
- `-Title` — header text (default `'Summary'`)
- `-Icon` — optional emoji / unicode glyph shown before the title
- `-DefaultOpen` — start expanded (default `$true`)

### Collapsible chrome on every block cmdlet (1.5.1+)

Since **1.5.1**, every block cmdlet supports the same `-Collapsible` / `-DefaultOpen` pair (defaults `$true`, matching `Add-DhSummary`). When enabled, the cmdlet's `-Title` (and optional `-Icon`) becomes the clickable collapsible header bar. The block content itself is unchanged — just folded behind a chevron.

Covered cmdlets:
- `Add-DhBarChart`, `Add-DhBullet`, `Add-DhEventFeed`, `Add-DhFilterCard`, `Add-DhHeatmap`, `Add-DhHtmlBlock`, `Add-DhLineChart`, `Add-DhPieChart`, `Add-DhStatusGrid`, `Add-DhTabs`, `Add-DhTopologyMap`
- `Add-DhTable` — wraps the toolbar, table, and pagination under the section header. New `-Icon` parameter accompanies the existing `-Title`.
- `Add-DhAlertBanner` — folds the message body behind a severity-derived header (`'Alert'` / `'Notice'` / `'Warning'` / `'Critical'`, override with `-Title`). Action + dismiss buttons stay outside the collapse so they remain reachable when folded.

Pass `-Collapsible:$false` per call to restore the flat pre-1.5.1 rendering for any individual element.

```powershell
# Folded charts and tables; tile strip and intro block stay open
Add-DhBarChart -Report $report -Id 'sev'    -Title 'By severity'  -TableId 'incidents' -Field 'Severity' -DefaultOpen $false
Add-DhTable    -Report $report -TableId 'incidents' -Title 'Incidents (last 24h)' -Icon '!' -Data $rows -DefaultOpen $false

# Keep a banner uncollapsable so the message is always visible
Add-DhAlertBanner -Report $report -Id 'maint' -Severity 'info' `
    -Message 'Maintenance window tonight 22:00 UTC' -Collapsible:$false
```

### Flat tile strip (pre-1.3.2 behaviour)

```powershell
Add-DhSummary -Report $report -Collapsible:$false -Items @(
    @{ Label='Total';   Value=247 }
    @{ Label='Active';  Value=231; Class='cell-ok' }
)
```

### Per-NavGroup summary strips (v1.4.1+)

Pass `-NavGroup` (and optionally `-NavSubGroup`) to scope a summary to a single nav panel. Each panel in a two-tier nav can have its own KPI hero row, and these coexist with the unscoped global summary at the top of the page.

```powershell
# Global summary — no NavGroup, visible on every panel
Add-DhSummary -Report $report -Title 'Overall health' -Items @(
    @{ Style='bignumber'; Label='SLA (30d)'; Value='99.96%'; Class='cell-ok' }
    @{ Label='Open incidents'; Value=4; Previous=7; TrendIsGood=$true }
)

# Identity-panel summary — visible only when the 'Identity' tab is active
Add-DhSummary -Report $report -NavGroup 'Identity' -Title 'Identity KPIs' -Items @(
    @{ Label='Active users';  Value=231 }
    @{ Label='Failed logons'; Value=842; Previous=920; TrendIsGood=$true }
)

# Infrastructure-panel summary — different metrics for a different panel
Add-DhSummary -Report $report -NavGroup 'Infrastructure' -Title 'Cluster KPIs' -Items @(
    @{ Style='gauge'; Label='Cluster CPU'; Value=68; Max=100; Unit='%'
       Rag=@{ Green=@{Max=70}; Amber=@{Min=70;Max=90}; Red=@{Min=90} } }
    @{ Label='Active alarms'; Value=3; Previous=1; TrendIsGood=$false }
)

# Add the rest of each panel's content with -NavGroup matching the strip
Add-DhTable      -Report $report -TableId 'users'      ... -NavGroup 'Identity'
Add-DhStatusGrid -Report $report -Id      'svc-health' ... -NavGroup 'Infrastructure'
```

Full runnable example: [`Examples/Demo-Feature-NavMultiPanel.ps1`](Examples/Demo-Feature-NavMultiPanel.ps1).

NavGroup-specific keys:
- `-Id` — explicit block Id; auto-derived by slugifying `NavGroup` (+ optional `NavSubGroup`) when omitted, e.g. `My Group` → `summary-my-group`. Duplicate Ids throw.

### Tile styles (v1.4+)

By default each item renders as the compact tile that has shipped since 1.3.x. Pass `Style='bignumber'` or `Style='gauge'` to switch to one of the new variants for hero metrics or threshold visualisations.

```powershell
Add-DhSummary -Report $report -Items @(

    # Hero metric — full-width tile, very large value typography
    @{ Style='bignumber'; Label='Current SLA'; Value='99.97%'
       Caption='Target 99.9% — met' }

    # Semicircle gauge with RAG bands driven by Thresholds
    @{ Style='gauge'; Label='Cluster CPU'; Value=42; Max=100; Unit='%'
       Thresholds=@(
           @{ Min=0;  Class='cell-ok'     }
           @{ Min=70; Class='cell-warn'   }
           @{ Min=90; Class='cell-danger' }
       )
    }
    @{ Style='gauge'; Label='Disk used'; Value=92; Max=100; Unit='%'
       Thresholds=@(
           @{ Min=0;  Class='cell-ok'     }
           @{ Min=70; Class='cell-warn'   }
           @{ Min=90; Class='cell-danger' }
       )
    }

    # Default compact tile — unchanged
    @{ Label='Active sessions'; Value=287; Icon='S' }
)
```

**Style values:**
- `'tile'` (default) — the compact strip tile.
- `'bignumber'` — full-width tile, 2.4–3.6rem value typography, optional `Caption` line.
- `'gauge'` — 140×80 semicircle SVG, background arc + filled arc coloured by the matching threshold. Defaults `Min=0`, `Max=100`. `Unit` is appended after the centre readout. `Value` must be numeric.

**Threshold matching:** mirrors `Add-DhTable` column thresholds. A band matches when `Min ≤ value < Max` (either bound may be omitted). When multiple bands match, the one with the highest `Min` wins — so the spec-friendly "Min-only" pattern in the example above does the intuitive thing.

All three styles still honour `Class`, `Format`/`Locale`/`Decimals`/`Currency`, and (where it makes visual sense) the v1.4 delta and sparkline keys.

### Trend and delta indicators on tiles (v1.4+)

Each tile can show how its current `Value` compares to a previous baseline. Supply `Previous`, and an arrow + delta line appears between the value and the label:

- `▲ +12 (+5.5%)` (green) — `Active users 231` vs previous `219`
- `▼ -8 (-3.2%)` (red)   — regression
- `▶ ±0`        (grey)  — no change

```powershell
Add-DhSummary -Report $report -Items @(
    # Auto-derived delta: up = good by default
    @{ Label='Active users';  Value=231;      Previous=219 }
    @{ Label='Revenue';       Value=99450.75; Previous=92330.25; Format='currency'; Locale='en-US'; Currency='USD'; Decimals=2 }

    # Inverted semantics — fewer errors is GOOD news, paint green when down
    @{ Label='Errors (24h)';  Value=4;  Previous=12; TrendIsGood=$true; Class='cell-warn' }
    @{ Label='Latency p95';   Value=82; Previous=88; TrendIsGood=$true; DeltaFormat='absolute' }

    # Explicit trend with no baseline number
    @{ Label='Pipeline';      Value=12; Trend='up' }
)
```

Per-item keys (all optional):
- `Previous` — baseline value. When supplied, the arrow direction and delta numbers are computed automatically.
- `Trend` — `'auto'` (default — derived from Previous), `'up'`, `'down'`, or `'flat'`. Pass an explicit value to override the auto direction, or to show a direction without a numeric baseline.
- `TrendIsGood` — flip the colour semantics for "lower is better" metrics. By default `up` is green (good) and `down` is red (bad). Pass `$true` to paint **this direction** as good regardless (e.g. errors trending down), or `$false` to mark it as bad.
- `DeltaFormat` — `'both'` (default, `+12 (+5.5%)`), `'percent'` (just `+5.5%`), or `'absolute'` (just `+12`).

When `Previous` is `0` only the absolute delta is shown (percent is undefined). The arrow alone is rendered when only `Trend` is supplied without `Previous`.

### Inline sparklines on tiles (v1.4+)

Each tile can carry an inline mini-chart below the label. Pure SVG, ~120 × 24 px, no library required. Choose between three styles:

- `'line'` (default) — polyline through the points
- `'area'` — line plus filled area to the baseline
- `'bars'` — small vertical bar at each point

```powershell
Add-DhSummary -Report $report -Items @(
    @{ Label='CPU avg (24h)'; Value=42; Format='percent'
       Sparkline      = @(30,42,38,55,67,71,68,52)
       SparklineStyle = 'line'
       SparklineMin   = 0       # optional fixed axis
       SparklineMax   = 100
    }
    @{ Label='Requests/s'; Value=1240; Format='number'; Class='cell-ok'
       Sparkline      = @(800,950,1100,1240,1200,1180)
       SparklineStyle = 'area'
    }
    @{ Label='Errors (7d)'; Value=4; Class='cell-warn'
       Sparkline      = @(12,8,3,2,5,1,4)
       SparklineStyle = 'bars'
    }
    @{ Label='SLA'; Value=99.97; Format='percent'; Decimals=2 }   # no sparkline
)
```

Per-item keys (all optional):
- `Sparkline` — numeric array. Non-numeric values are dropped with a warning.
- `SparklineStyle` — `'line'` (default) / `'area'` / `'bars'`
- `SparklineMin` / `SparklineMax` — fix the Y-axis. Defaults to the series min/max so flat-looking series still render dramatically.

Sparklines work in both the flat and collapsible variants of the summary strip, and use the accent colour `--chart-1` from the active theme.

### Click-to-jump tile Actions (v1.4.2+)

Any tile (any style — `tile` / `bignumber` / `gauge`) can carry an `Action` hashtable that makes the **whole tile clickable**. Same shape as `Add-DhAlertBanner -Action`: provide either `TableId` (jump to a registered table, with optional `Filter` pre-applied) or `Url` (open in a new tab). Keyboard accessible (Enter / Space).

```powershell
Add-DhSummary -Report $report -Items @(
    # Click jumps to the 'incidents' table, pre-filtered on 'critical'
    @{ Label='Open incidents'; Value=4; Class='cell-warn'
       Action=@{ Label='View incidents'; TableId='incidents'; Filter='critical' } }

    # Click opens an external URL
    @{ Style='bignumber'; Label='Service status'; Value='Degraded'
       Action=@{ Label='Open status page'; Url='https://status.example.com' } }
)
```

The `Label` is used as the native `title=""` hover tooltip. Provide exactly one of `TableId` or `Url`.

---

## Auto-refresh (v1.4.2+)

For wall-display ops dashboards, set `-AutoRefresh` on `New-DhDashboard` to emit a `<meta http-equiv="refresh">` tag in `<head>`. Accepts a friendly duration string (`'30s'`, `'5m'`, `'1h'`) or plain seconds (`'300'`). Omit / pass `''` to disable.

```powershell
$report = New-DhDashboard -Title 'NOC Wall' -Theme Default -AutoRefresh '5m'
```

The browser reloads the file at the configured interval. Pair this with a scheduled task that regenerates the HTML at a slightly shorter cadence so the displayed report stays current.

---

## Alert banners

Top-of-page strips for current conditions — open incidents, recent failures, maintenance notices, compliance breaches. Banners stack vertically *above* the KPI summary tiles in the order they were declared. Each banner carries a severity (`info` / `ok` / `warning` / `critical`) that drives the colour via the standard RAG palette.

```powershell
# Simplest banner — just a message
Add-DhAlertBanner -Report $report -Id 'maintenance' `
    -Severity 'info' -Message 'Maintenance window tonight 22:00–02:00 UTC'

# Critical alert with action button — clicking jumps to a filtered table
Add-DhAlertBanner -Report $report -Id 'open-incidents' `
    -Severity 'critical' -Icon '!' `
    -Message '3 critical incidents open in the last 24h' `
    -Dismissible `
    -Action @{ Label='View incidents'; TableId='incidents'; Filter='critical' }

# External link
Add-DhAlertBanner -Report $report -Id 'release-notes' `
    -Severity 'ok' -Message 'Patch level KB5044277 applied to 98% of hosts' `
    -Action @{ Label='Open KB'; Url='https://support.microsoft.com/kb/5044277' }
```

**Key behaviours:**
- `-Dismissible` adds a close (×) button. The dismissal is remembered in the URL hash so a page reload keeps the banner hidden; opening the report in a new browser session restores it.
- `-Action` adds a button that either navigates to a registered table (with optional `Filter` text pre-applied) or opens an external `Url`. Provide one of `TableId` or `Url`, not both.
- `-NavGroup` / `-NavSubGroup` *(v1.4.2+)* bind the banner to a single nav panel, so it appears only when that panel is active. Without these params, the banner stays page-global (visible on every panel) — the legacy behaviour.
- The `-Message` may contain inline HTML — useful for embedding a short link inside the prose.
- Severity maps to the existing `cell-ok` / `cell-warn` / `cell-danger` palette, so the colours follow the active theme.
- Distinct from `Add-DhCollapsible` or `Add-DhHtmlBlock`: an alert banner sits **above** the summary and is meant for transient, high-visibility conditions.

---

## Bar charts

```powershell
# Basic distribution chart
Add-DhBarChart -Report $report -Id 'status-chart' `
    -Title 'Items by Status' `
    -TableId 'items' -Field 'Status' -TopN 10 `
    -ShowCount $true -ShowPercent $true

# Click a bar to filter the source table
Add-DhBarChart -Report $report -Id 'region-chart' `
    -Title 'Items by Region' `
    -TableId 'items' -Field 'Region' -ClickFilters

# v1.4 — stacked: bars represent Region, segments coloured by Status
Add-DhBarChart -Report $report -Id 'by-region-stacked' `
    -Title 'Items by Region (stacked by Status)' `
    -TableId 'items' -Field 'Region' -SeriesField 'Status' -Stacked
```

**Stacked mode (v1.4+):** pass `-SeriesField` to break each primary bar into colour-coded segments. The legend below the chart maps each series value to its colour. The `-Stacked` switch is optional — supplying `-SeriesField` alone implies it. Click-to-filter (`-ClickFilters`) is single-series only; stacked bars have no single value to filter by. Series colours are pulled from the active theme's chart palette and assigned in alphabetical order, so the legend stays stable across renders.

**`-ClickFilters` (working from 2.1.3):** a bar click applies the bar's label as the source table's **text filter** — exactly as if you had typed it into the search box. The table filters, the `×` clear button appears, the chart re-aggregates against the filtered rows (so it collapses to the clicked bar), linked charts refresh, and the state is written to the URL hash so the view survives a reload and can be shared. Click `×` for the full distribution again. Because it is a text filter rather than an exact-value match, a label that is a substring of another value matches both.

Bars are keyboard-operable: Tab to one, then Enter or Space.

> **This never worked before 2.1.3** — every click threw `ReferenceError: engines is not defined`, and a label containing a `"` could inject HTML attributes. If you have dashboards using `-ClickFilters`, regenerate them: the runtime is baked into each HTML file, so updating the module alone changes nothing already on disk.

---

## Pie / Donut charts

Standalone pie or donut chart as a top-level block. Supports two data modes:

- **Mode A — derive from a registered table.** Counts distinct values of a field across all rows; sorts highest-to-lowest; caps at `TopN` segments.
- **Mode B — explicit slices.** Provide `Label`/`Value` (and optional `Color`) hashtables directly. Use this for non-tabular data (cost breakdowns, weighted distributions).

The `donut` style (default) leaves a hole in the centre with the total; `pie` renders a solid disc.

> **Spec guidance:** the IT-infrastructure KPI dashboard spec recommends avoiding pies with more than 5 segments — switch to `Add-DhBarChart` for higher cardinality.

```powershell
# Mode A — derive from a table column
Add-DhPieChart -Report $report -Id 'status-pie' `
    -Title 'Items by status' `
    -TableId 'items' -Field 'Status' -ClickFilters

# Mode B — explicit slices, donut style
Add-DhPieChart -Report $report -Id 'cost-pie' `
    -Title 'Monthly cost by region' -Style 'donut' `
    -Slices @(
        @{ Label='us-east';  Value=12500 }
        @{ Label='eu-west';  Value=8200  }
        @{ Label='ap-south'; Value=3400  }
    )

# Pie style, custom colours, no legend
Add-DhPieChart -Report $report -Id 'license-pie' `
    -Title 'License usage' -Style 'pie' -ShowLegend $false `
    -Slices @(
        @{ Label='Used';      Value=820; Color='#1B6B35' }
        @{ Label='Available'; Value=180; Color='#8B5200' }
    )
```

**Key parameters:**
- `-Style` — `'donut'` (default) or `'pie'`
- `-TableId` / `-Field` — Mode A only; the source table must already be added
- `-TopN` — Mode A only; cap at N segments (default 10)
- `-ClickFilters` — Mode A only; clicking a slice applies the slice label as a text filter on the source table, the same way a bar-chart click does. Before 2.1.3 a slice click filtered the table but left the `×` clear button hidden and linked charts stale.
- `-Slices` — Mode B only; mutually exclusive with `-TableId`
- `-ShowTotal` — show the total in the donut hole (default `$true`; ignored for `pie` style)
- `-ShowLegend` — show the label / count / percentage rows (default `$true`)

---

## Line / Area charts (v1.4+)

Time-series-style chart as a top-level block. Multiple series share one X-axis of category labels (typically timestamps). Optional `-Filled` switches the lines into filled areas. Optional `-TargetLine` draws a dashed horizontal annotation at a Y value, which the spec (§7.4) calls out as the canonical pairing for any time-series visualisation: *"Always pair a time-series chart with a threshold annotation line."*

```powershell
$hours = @('00:00','04:00','08:00','12:00','16:00','20:00','24:00')

# Single series with a warning-threshold annotation
Add-DhLineChart -Report $report -Id 'cpu-trend' -Title 'Cluster CPU (24h)' `
    -XAxis $hours `
    -Series @(
        @{ Label='Avg'; Values=@(42,38,55,67,71,68,52); Class='cell-ok' }
    ) `
    -TargetLine 70 -TargetLabel 'Warning threshold' `
    -YAxisMin 0 -YAxisMax 100 -YAxisUnit '%'

# Multi-series filled area chart
Add-DhLineChart -Report $report -Id 'net-bw' -Title 'Network throughput (Mbps)' `
    -Filled `
    -XAxis $hours `
    -Series @(
        @{ Label='Ingress'; Values=@(800,950,1100,1240,1200,1180,900); Class='cell-ok'   }
        @{ Label='Egress';  Values=@(600,700,820,910,880,850,720);     Class='cell-warn' }
    )

# Gap handling — $null entries break the line at that index
Add-DhLineChart -Report $report -Id 'replication-lag' -Title 'Replication Lag' `
    -XAxis $hours `
    -Series @(
        @{ Label='DC01→DC02'; Values=@(2,3,$null,$null,5,4,3); Color='#0088BB' }
        @{ Label='DC01→DC03'; Values=@(1,2,2,3,2,2,1);         Color='#E08800' }
    ) `
    -TargetLine 60 -TargetLabel 'SLA 60s' -YAxisUnit 's'
```

**Parameters:**
- `-XAxis` — array of category labels (typically timestamps). Must have ≥ 2 entries.
- `-Series` — array of `@{Label;Values[];Class;Color}`. Each series's `Values` length must match `XAxis`. `Class` maps to the RAG palette (`cell-ok` / `cell-warn` / …); `Color` is an explicit override. `$null` entries in `Values` are allowed and rendered as line breaks.
- `-Filled` — switch; renders each series as a filled area instead of a polyline.
- `-TargetLine` / `-TargetLabel` — optional numeric reference Y and its label. Dashed line drawn in the warning colour.
- `-YAxisMin` / `-YAxisMax` / `-YAxisUnit` — explicit Y-axis bounds (auto-fitted with 5% padding when omitted) and an optional unit suffix on tick labels (`'%'`, `'ms'`, `'GB'` etc.).
- `-ShowLegend` / `-ShowGrid` — defaults `$true`. Disable for compact embeds.
- `-Height` — SVG height in px (80–1000, default 240).

The plot stretches to fit its container horizontally; height is fixed by `-Height`.

---

## Status Grid (v1.4+)

Rows × columns RAG matrix — the IT-infrastructure KPI dashboard specification's "Status Matrix / Health Grid" (§2). Use it for at-a-glance health overviews where many entities share a small set of states: services × regions, DCs × replication links, hosts × probes. A status grid is a colour-first matrix; if your data needs sortable columns or rich cell content, use `Add-DhTable` instead.

```powershell
Add-DhStatusGrid -Report $report -Id 'service-health' -Title 'Service Health' `
    -RowLabel 'Service' -ColumnLabel 'Region' `
    -Rows    @('Auth','Billing','Search','Mail','Payments') `
    -Columns @('us-east','us-west','eu-west','eu-central','ap-south') `
    -CellSize 'normal' `
    -Cells @(
        @{ Row='Auth';    Column='us-east';   Status='ok';     Tooltip='99.98% / 24h' }
        @{ Row='Auth';    Column='eu-west';   Status='warn';   Tooltip='latency spike'
           LinkTableId='incidents'; LinkFilter='auth-eu' }
        @{ Row='Billing'; Column='us-east';   Status='danger'; Tooltip='down 12m' }
        @{ Row='Billing'; Column='ap-south';  Status='nodata' }
        # ... declare only the (Row, Column) pairs that exist
    )
```

**Per-cell keys:**
- `Row` — required string, must appear in `-Rows`. Typo throws (no silent miss).
- `Column` — required string, must appear in `-Columns`.
- `Status` — required. One of `'ok'` / `'warn'` / `'danger'` / `'nodata'` / `'info'`. Drives the cell colour via the existing RAG palette.
- `Tooltip` — optional string. Renders as the native `title=""` hover tooltip; no popover library.
- `LinkTableId` — optional. Clicking the cell jumps to this registered table (reuses the same panel-navigation hook as `Add-DhAlertBanner -Action`).
- `LinkFilter` — optional. When `LinkTableId` is set, the table receives this text filter on jump. Filter without `LinkTableId` throws.

**Cmdlet parameters:**
- `-Rows` / `-Columns` — required string arrays defining the axes.
- `-RowLabel` / `-ColumnLabel` — optional axis captions shown in the top-left corner of the grid.
- `-CellSize` — `'small'` (32 px) / `'normal'` (48 px, default) / `'large'` (64 px). Below a 600 px viewport, the grid collapses to a stacked list regardless of this setting.
- `-MaxCells` — hard ceiling on `Rows × Columns` (default `2000`). A soft warning fires above 200 cells.

Cells you don't declare render as a faint dashed neutral state. A legend strip below the grid auto-generates from the statuses actually present.

---

## Heatmap (v1.5+)

Rows × columns matrix with a **numeric** colour scale — distinct from `Add-DhStatusGrid`, which is categorical. Use it for time-of-day load matrices, weekly seasonal patterns, latency histograms, percentile distributions — anywhere the cell value is a number that benefits from gradient encoding rather than discrete RAG buckets.

```powershell
$days  = @('Mon','Tue','Wed','Thu','Fri','Sat','Sun')
$hours = @('00','03','06','09','12','15','18','21')

$cells = foreach ($d in $days) {
    foreach ($h in $hours) {
        @{ Row=$d; Column=$h; Value=(Get-Random -Min 10 -Max 95); Tooltip="$d $h:00" }
    }
}

# Sequential scale — chart-1 → chart-2 from min to max
Add-DhHeatmap -Report $report -Id 'load-heatmap' -Title 'Cluster Load — Last Week' `
    -RowLabel 'Day' -ColumnLabel 'Hour (UTC)' `
    -Rows $days -Columns $hours -Cells $cells `
    -ColorScale 'sequential' -Unit '%' -ShowValues

# Diverging scale — centred on a midpoint (good for "delta from target")
Add-DhHeatmap -Report $report -Id 'deviation' -Title 'CPU vs SLA target' `
    -Rows $days -Columns $hours -Cells $cells -Min -50 -Max 50 `
    -ColorScale 'diverging' -CellSize 'small'
```

**Per-cell keys:**
- `Row` — required, must appear in `-Rows`.
- `Column` — required, must appear in `-Columns`.
- `Value` — required numeric. The cell's colour is interpolated between the active theme's `--chart-1` and `--chart-2` (sequential) or `--chart-1` → `--border-subtle` → `--chart-3` (diverging), based on where `Value` sits in `[Min, Max]`.
- `Tooltip` — optional native `title=""` hover.

**Cmdlet parameters:**
- `-ColorScale` — `'sequential'` (default) or `'diverging'`.
- `-Min` / `-Max` — explicit value range. Auto-fitted from the cells when omitted.
- `-Unit` — suffix appended to the cell value when `-ShowValues` is set.
- `-ShowValues` — switch; render the numeric value inside each cell.
- `-CellSize` — `'small'` / `'normal'` (default) / `'large'`.
- `-MaxCells` — hard ceiling on `Rows × Columns` (default `5000`). Soft warning above 1000.

When to use which 2-D widget:
- **`Add-DhStatusGrid`** — categorical state (`ok`/`warn`/`danger`/`nodata`). One of a small set of discrete values per cell.
- **`Add-DhHeatmap`** — continuous numeric value per cell. Gradient encoding makes patterns pop.

---

## Topology Map (v1.5+)

Parent-child tree visualisation for hierarchies — AD Forest → Domain → DC, vCenter → Cluster → Host, network device chains, application dependency trees. The renderer is intentionally simple: a recursive subtree-width layout — no force-directed graphs, no Reingold-Tilford. Handles realistic IT hierarchies well (≲ 50 nodes); above that the spec recommends a different visualisation.

```powershell
Add-DhTopologyMap -Report $report -Id 'ad-forest' -Title 'AD Forest' `
    -Direction 'vertical' `
    -Nodes @(
        @{ Id='forest';  Label='contoso.com';     Parent=$null;    Status='ok' }
        @{ Id='dom-hq';  Label='hq.contoso.com';  Parent='forest'; Status='ok'   }
        @{ Id='dom-eu';  Label='eu.contoso.com';  Parent='forest'; Status='warn' }
        @{ Id='dc-hq01'; Label='DC-HQ01';         Parent='dom-hq'; Status='ok' }
        @{ Id='dc-hq02'; Label='DC-HQ02';         Parent='dom-hq'; Status='ok' }
        @{ Id='dc-eu01'; Label='DC-EU01';         Parent='dom-eu'; Status='warn'
           Tooltip='Replication lag 4m'
           LinkTableId='incidents'; LinkFilter='dc-eu01' }
        @{ Id='dc-eu02'; Label='DC-EU02';         Parent='dom-eu'; Status='danger' }
    )
```

**Per-node keys:**
- `Id` — required, unique within this topology.
- `Label` — required string shown inside the node box.
- `Parent` — id of the parent node, or `$null` / `''` for a root. Multiple roots are allowed (the layout renders side-by-side as a forest).
- `Status` — optional `'ok'` / `'warn'` / `'danger'` / `'nodata'` / `'info'` / `''`. Drives the box tint via the existing RAG palette.
- `Icon` — optional emoji / glyph rendered before the label.
- `Badge` — optional short tag (e.g. `'AD'`, `'Dom'`) rendered after the label.
- `Tooltip` — optional. Surfaces in a styled hover overlay (since **1.5.2**) — works on SVG node groups, themed to match the rest of the dashboard. If `Tooltip` is omitted, the renderer falls back to the node's full `Label` so truncated FQDN labels still surface on hover.
- `LinkTableId` — optional. Clicking the node jumps to this registered table (reuses the same drill-down hook as `Add-DhStatusGrid` cells and `Add-DhAlertBanner -Action`).
- `LinkFilter` — optional pre-applied text filter when `LinkTableId` is set. Filter without `LinkTableId` throws.

**Cmdlet parameters:**
- `-Direction` — `'vertical'` (default, parent above children) or `'horizontal'` (parent left of children). Horizontal scales better for wide-fan trees (any level with 5+ children).
- `-NodeWidth` / `-NodeHeight` — per-node pixel dimensions (defaults `140 × 44`).
- `-AutoFitWidth` *(1.5.2+)* — switch. When set, the JS renderer probes the live `.topo-node-body` font and uses a hidden `<canvas>` to measure every node's label + icon + badge combination. `NodeWidth` is then grown to the widest needed value, clamped at `-AutoFitMaxWidth`. Pair with `-Direction 'horizontal'` for the best reading experience on wide-fan trees with long FQDN labels.
- `-AutoFitMaxWidth` *(1.5.2+)* — ceiling (default `360 px`) on the auto-fit growth, so a single outlier label can't push the layout to absurd widths.
- `-MaxNodes` — hard ceiling (default `200`). Trees larger than this usually warrant a different visualisation.

```powershell
# Wide-fan farm topology — auto-fit + horizontal + intermediate category nodes
Add-DhTopologyMap -Report $report -Id 'farm-topology' -Title 'Farm Topology' `
    -Direction 'horizontal' -NodeWidth 220 -AutoFitWidth `
    -Nodes @(
        @{ Id='farm';       Label='CAI-DC';            Parent=$null;       Status='ok'; Icon='F'; Badge='Farm'  }
        @{ Id='site';       Label='EGSI-RAS-BRK01';    Parent='farm';      Status='ok'; Icon='S'; Badge='Site'  }
        # Intermediate categories keep the tree visually balanced when a site has 10+ leaves
        @{ Id='cat-brk';    Label='Brokers';           Parent='site';      Status='ok'; Icon='B'; Badge='2'     }
        @{ Id='cat-gw';     Label='Gateways';          Parent='site';      Status='ok'; Icon='G'; Badge='2'     }
        @{ Id='cat-pool';   Label='RDS Host Pools';    Parent='site';      Status='ok'; Icon='P'; Badge='5'     }
        # Leaves
        @{ Id='brk-1';      Label='EGSI-RAS-BRK01.egsi.local'; Parent='cat-brk';  Status='ok';   Icon='B'; Badge='Primary'
           Tooltip='EGSI-RAS-BRK01.egsi.local — role Primary, agent OK'; LinkTableId='brokers' }
        # … etc.
    )
```

Cycle detection rejects loops (`A → B → A`); references to unknown parents throw at declaration time.

### Interactive pan / zoom / collapse (1.7.0+)

By default (`-Interactive` = `$true`) the tree renders in a fixed-height viewport you can explore:

- **Drag** the background to pan; **mouse-wheel** to zoom around the cursor; the corner toolbar has **zoom-in / zoom-out / reset-to-fit** buttons.
- Every **parent node shows a `+/−` toggle** — click (or focus + Enter/Space) to collapse or expand its subtree. Collapsing a branch reflows the remaining tree.
- The view **auto-fits** to the container on load and re-fits on resize until you pan or zoom, after which it leaves your view alone (the reset button hands control back).

Pass `-Interactive:$false` for the static scale-to-fit rendering (no toolbar, no collapse) — useful for print or when embedding a small fixed tree.

---

## Tabs (v1.5+)

Inline tabbed content block — a **local** pivot within one section of the dashboard flow. Distinct from `-NavGroup` which partitions the **whole page**. Use tabs when several views of the same scope (Overview / Detail / Raw payload) belong together but only one should be visible at a time.

```powershell
Add-DhTabs -Report $report -Id 'fleet-views' -Title 'Fleet — Views' -Tabs @(
    @{ Title='Overview';    Icon='O'; Content='<p>The fleet runs 10 servers …</p>'; Active=$true }
    @{ Title='Per-host';    Icon='H'; Content='<table>…</table>' }
    @{ Title='Raw payload'; Icon='R'; Content='<pre>{ … }</pre>' }
)
```

**Per-tab keys:**
- `Title` — required string shown on the tab button.
- `Content` — required raw HTML (same policy as `Add-DhHtmlBlock` — emitted verbatim).
- `Icon` — optional emoji / glyph rendered before the title.
- `Active` — optional `$true` to mark this tab initially visible. If no tab is marked active, the first one is auto-activated.

Implements the full W3C tab pattern: `role="tablist" / "tab" / "tabpanel"`, `aria-selected`, `aria-controls`, left/right arrow-key navigation, and a `focus-visible` outline.

---

## Event feed (v1.4+)

Chronological severity-tagged audit trail. Per the IT-infrastructure KPI dashboard specification (§4.1 and §4.2), this is the canonical **Row 5** of an ops dashboard — the evidence trail that pairs with the at-a-glance KPI tiles above. Distinct from `Add-DhAlertBanner` (which surfaces a single *current* condition at the top of the page).

```powershell
Add-DhEventFeed -Report $report -Id 'recent-events' `
    -Title 'Recent events (24h)' -MaxItems 50 `
    -Events @(
        @{ Timestamp='2026-05-22 14:32'; Severity='critical'; Source='DC01'
           Message='Replication failure to DC03' }
        @{ Timestamp='2026-05-22 14:18'; Severity='warning';  Source='DC02'
           Message='LDAP bind time > 80 ms (avg)' }
        @{ Timestamp='2026-05-22 13:55'; Severity='info';     Source='vSphere'
           Message='vMotion: VM-027 → ESXi-04' }
        @{ Timestamp='2026-05-22 12:42'; Severity='ok';       Source='Backup'
           Message='Nightly backup completed in 42 minutes' }
    )

# Optional grouping — critical floats to the top
Add-DhEventFeed -Report $report -Id 'incidents-by-sev' `
    -Title 'Open incidents' -GroupBy 'Severity' -Events $incidents
```

**Per-event keys:**
- `Timestamp` — required string. Free-form — sorted lexicographically. ISO-8601 timestamps sort correctly out of the box.
- `Severity` — required. One of `'info'` / `'ok'` / `'warning'` / `'critical'`. Drives the row colour via the existing RAG palette.
- `Message` — required string. Long messages wrap onto a second line.
- `Source` — optional string. Rendered in `[brackets]` between the timestamp and the message.
- `Icon` — optional emoji / glyph. Overrides the default severity icon (`·` / `✓` / `!` / `✕`).

**Cmdlet parameters:**
- `-MaxItems` — cap on visible rows (default 50, range 1..1000). Older events are dropped after sort+slice.
- `-GroupBy` — `'None'` (default) / `'Severity'` / `'Source'`. With grouping, each group is preceded by a header showing the group key and entry count. `'Severity'` groups appear in priority order (critical → warning → ok → info).
- `-SortDescending` — newest-first by default (`$true`). Pass `$false` for chronological top-down reading.

---

## Bullet charts (v1.4+)

The canonical "actual vs target with performance bands" visualisation, per the IT-infrastructure KPI dashboard specification (§2 Widget Types). Each row stacks vertically and shows: a full-width track, RAG-coloured performance bands, a solid value bar from `Min` to `Value`, and an optional vertical target marker on top.

```powershell
# Share one RAG definition across multiple rows
$latencyRag = @{
    Green = @{ Max = 50 }
    Amber = @{ Min = 50; Max = 80 }
    Red   = @{ Min = 80 }
}

Add-DhBullet -Report $report -Id 'auth-latency' -Title 'LDAP Bind Time' -Items @(
    @{ Label='DC01'; Value=42; Target=50; Max=120; Unit='ms'; Rag=$latencyRag }
    @{ Label='DC02'; Value=68; Target=50; Max=120; Unit='ms'; Rag=$latencyRag }
    @{ Label='DC03'; Value=92; Target=50; Max=120; Unit='ms'; Rag=$latencyRag }
)
```

For "bigger is better" metrics (headroom, uptime SLA), flip the RAG semantics:

```powershell
Add-DhBullet -Report $report -Id 'cpu-headroom' -Title 'CPU Headroom per Host' -Items @(
    @{ Label='esxi-01'; Value=42; Target=30; Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{Min=30}; Amber=@{Min=15;Max=30}; Red=@{Max=15} } }
    @{ Label='esxi-02'; Value=12; Target=30; Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{Min=30}; Amber=@{Min=15;Max=30}; Red=@{Max=15} } }
)
```

Per-item keys:
- `Label` — left-side row label (required)
- `Value` — actual numeric value (required)
- `Target` — optional numeric. When set, a vertical tick mark appears on the track.
- `Min` / `Max` — track range. Defaults `0..100`; `Max` must be `> Min`.
- `Unit` — optional suffix in the readout (`'ms'`, `'%'`, …)
- `Class` — optional value-bar colour override (`'cell-ok'` / `'cell-warn'` / `'cell-danger'` / `'cell-nodata'`). Wins over the auto threshold match.
- `Rag` — preferred way to declare the bands (see [Unified `-Rag` parameter](#unified--rag-parameter-v14)).
- `Bands` / `Thresholds` — legacy array shape `@(@{Min;Max;Class})`; `Bands` is an alias for `Thresholds`. `Rag` wins when both are supplied.

---

## Range bars (2.1+)

`Add-DhRangeBar` shows the **spread** of a metric per entity, not a single value. Each row is a floating bar from `Min` to `Max` with a tick at `Avg`, and every row is normalised against its own `High` — so a cluster allocated 315 units and one allocated 30 sit on the same comparable 0–100 axis.

Bar colour follows **position on that axis** (`--accent-ok` → `--accent-warn` → `--accent-danger`), not category identity. Two bars of the same colour mean "same load level", never "same thing".

```powershell
Add-DhRangeBar -Report $report -Id 'cluster-load' -Title 'Cluster load range' `
    -Unit 'req/s' -ShowDataTable `
    -Items @(
        @{ Name='cluster01-users';   Low=0; High=315; Min=60; Avg=97; Max=120 }
        @{ Name='cluster02-bigdata'; Low=0; High=104; Min=1;  Avg=2;  Max=10  }
    )
```

Or derive the rows from a table already in the report. Aggregation runs in the browser against the table's **filtered** rows, so filtering the table live-recomputes every bar:

```powershell
Add-DhTable -Report $report -TableId 'clusters' -Title 'Cluster hosts' -Data $hosts

Add-DhRangeBar -Report $report -Id 'cluster-load' -Title 'Cluster load range' `
    -TableId 'clusters' -CategoryField 'Cluster' `
    -ValueField 'LoadReqSec' -HighField 'CapacityReqSec' -Unit 'req/s'
```

**Where `High` comes from**, in precedence order — it decides what the chart is actually saying:

| Form | The axis reads as | Use when |
|---|---|---|
| `-HighField 'Capacity'` | "% of that row's own capacity" | each table row carries its category's ceiling |
| `-High 250` | "% of a fixed ceiling" | one SLA / limit applies to everything |
| neither | "% of the largest value seen anywhere" | exploratory |

`-High` together with `-HighField` is an error, not a silent preference. The 0–100 caption is derived from whichever you pick, so the chart never ships without saying what the axis means.

Per-item keys (all six required): `Name`, `Low`, `High`, `Min`, `Avg`, `Max`. Values are real, un-normalised units — the percentages are an internal plotting mechanism and are shown only in the tooltip.

Worth knowing:

- **The avg tick is not clamped** into `[Min, Max]`. An average computed over a longer window than the observed min/max legitimately falls outside the bar; hiding that would misrepresent the data.
- **`High <= Low` is not an error.** Normalisation is undefined, so the row renders striped and muted and you get a `Write-Warning`. Fix the source data.
- **Values beyond the row's own scale** clip at the axis edge, but the real numbers survive in the label and the tooltip.
- `-ShowDataTable` adds a toggleable raw-values table — the printable, screen-reader-friendly escape hatch.
- `-MaxRows` (default 60) throws on a runaway `-CategoryField` rather than emitting hundreds of unreadable rows.

### Choosing between the three per-entity bar widgets

| You want to show | Use | Bar starts at |
|---|---|---|
| one value vs one target, with RAG bands | `Add-DhBullet` | the axis origin |
| a min–max spread plus its average | `Add-DhRangeBar` | `Min` (it floats) |
| a count per category | `Add-DhBarChart` | the axis origin |

`Add-DhRangeBar` is the only one whose bar floats, and the only one whose colour encodes position rather than category or state.

Full runnable example: [`Examples/Demo-Feature-RangeBar.ps1`](Examples/Demo-Feature-RangeBar.ps1). Every chart type side by side, with guidance on which to pick: [`Examples/Demo-Feature-AllChartTypes.ps1`](Examples/Demo-Feature-AllChartTypes.ps1).

---

## Global filters (1.9.0+)

`Add-DhGlobalFilter` puts a control in a bar above the whole report. Changing it re-filters **every table that has the named field at once** — and any chart built from those tables re-aggregates. Tables that don't have the field are left untouched. Multiple global filters combine with **AND**, and the selection is saved in the URL so a shared link or reload keeps it applied.

```powershell
$rows = Get-Inventory   # objects with Environment, Tier, LastSeen, …
Add-DhTable -Report $report -TableId 'hosts'  -Title 'Hosts'  -Data $rows
Add-DhTable -Report $report -TableId 'alerts' -Title 'Alerts' -Data $alertRows  # also has 'Environment'

# One dropdown filters BOTH tables (both have an 'Environment' column)
Add-DhGlobalFilter -Report $report -Field 'Environment' -Label 'Environment'

# Ordered facet with explicit values
Add-DhGlobalFilter -Report $report -Field 'Tier' -Values 'Gold','Silver','Bronze'

# A from/to date range over a timestamp column
Add-DhGlobalFilter -Report $report -Field 'LastSeen' -Label 'Last seen' -Type daterange
```

- **`-Type facet`** (default) — dropdown of distinct values (auto-derived from the data, or pass `-Values`).
- **`-Type daterange`** — from/to date inputs; keeps rows whose field parses as a date in the inclusive range.
- `-Label` sets the visible label (defaults to `-Field`); `-Placeholder` sets the "all" option text.

Distinct from `Add-DhFilterCard` (which filters **one** target table via clickable cards) — a global filter fans out to **all** tables sharing the field.

---

## 12-column grid layout (1.10.0+)

By default blocks and tables stack vertically (one per row). Pass **`-GridSpan <1-12>`** on any block or table to place several side by side: the report body becomes a 12-column grid the moment any element sets a span.

```powershell
# A wide trend chart beside a narrow donut, then a full-width table below
Add-DhLineChart -Report $report -Id 'trend' -Title 'CPU (24h)' -GridSpan 8 -XAxis $hrs -Series $s
Add-DhPieChart  -Report $report -Id 'state' -Title 'By state'  -GridSpan 4 -Slices $slices
Add-DhTable     -Report $report -TableId 'hosts' -Title 'Hosts' -Data $rows   # no span → full width

# A row of three equal thirds
Add-DhStatusGrid -Report $report -Id 'g1' -GridSpan 4 ...
Add-DhStatusGrid -Report $report -Id 'g2' -GridSpan 4 ...
Add-DhStatusGrid -Report $report -Id 'g3' -GridSpan 4 ...
```

- `-GridSpan 6` + `-GridSpan 6` → two half-width elements side by side.
- `-GridSpan 4` ×3 → a row of thirds; `-GridSpan 3` ×4 → quarters.
- Elements **without** a span default to full width, so you can freely mix.
- Alert banners, the global filter bar, and the KPI summary strip are always full width.
- The grid **collapses to a single column below 900 px** for narrow screens.

It's fully opt-in and non-breaking: a dashboard that never sets `-GridSpan` renders exactly as before (sequential flow).

---

## Filter cards

```powershell
$regionCards = $data | Group-Object Region | ForEach-Object {
    @{ Label=$_.Name; Value=$_.Name; Count=$_.Count }
}

Add-DhFilterCard -Report $report -Id 'region-filter' `
    -Title 'Filter by Region' `
    -TargetTableId 'items' -FilterField 'Region' `
    -Cards $regionCards

# Multi-select (multiple cards active at once)
Add-DhFilterCard -Report $report -Id 'status-filter' `
    -Title 'Filter by Status' `
    -TargetTableId 'items' -FilterField 'Status' `
    -MultiFilter $true `
    -Cards @(
        @{ Label='Active';   Value='Active';   Count=231 }
        @{ Label='Inactive'; Value='Inactive'; Count=12  }
        @{ Label='Error';    Value='Error';    Count=4   }
    )
```

---

## Linking tables

```powershell
# Master → Detail: click a parent row to filter the child table
Add-DhTable -Report $report -TableId 'groups'  -Title 'Groups' -Data $groups
Add-DhTable -Report $report -TableId 'members' -Title 'Members' -Data $members
Set-DhTableLink -Report $report -MasterTableId 'groups' -DetailTableId 'members' `
                -MasterField 'GroupId' -DetailField 'GroupId'

# Three-level chain: A → B → C
Set-DhTableLink -Report $report -MasterTableId 'categories' -DetailTableId 'groups' `
                -MasterField 'Category' -DetailField 'Category'
Set-DhTableLink -Report $report -MasterTableId 'groups' -DetailTableId 'items' `
                -MasterField 'GroupId' -DetailField 'GroupId'
```

---

## Navigation (2.0.0)

Every item declares **where it lives** (a path) and **how far up it stays visible** (a scope). One rule, any depth.

```powershell
Add-DhTable    -Report $r -TableId 'vols' -NavPath 'Storage/Capacity/vols' -NavLabel 'All volumes'
Add-DhBarChart -Report $r -Id 'mix' -NavPath 'Storage' -NavScope Subtree   # whole branch
Add-DhAlertBanner -Report $r -Id 'a1' -NavScope Global                     # everywhere
```

| Parameter | Meaning |
|---|---|
| `-NavPath` | where the item lives, e.g. `'A/B/C'`. `'//'` escapes a literal `/` in a segment |
| `-NavScope` | `Exact` (default) · `Subtree` (this node and everything below) · `Global` (everywhere) |
| `-NavLabel` | display text, decoupled from the path key — rename without breaking deep links |
| `-NavOrder` | explicit sibling ordering; ties fall back to declaration order |

Combining `-NavPath` with `-NavGroup`/`-NavSubGroup` on one call is a hard error.

### Layout

```powershell
New-DhDashboard -Title 'Net' -NavLayout Auto -NavMaxDepth 4
```

`Auto` (default) renders horizontal strips up to 3 levels and switches to a left tree rail with a breadcrumb at 4+, where stacked sticky strips would consume about a fifth of the viewport. Force either with `-NavLayout Strips|Sidebar`. Selecting a node descends to the first child that has content of its own, so one click never teleports you several levels down.

### Upgrading from 1.x

`-NavGroup` / `-NavSubGroup` **keep working** and map onto the new model — no edit required. See **[MIGRATION-v2.md](MIGRATION-v2.md)**, and run:

```powershell
Update-DhScript -Path .\YourScripts        # report only
```

> **One behaviour change worth checking.** In 1.x a *block* given both `-NavGroup` and `-NavSubGroup` was unreachable and never rendered. It works now, so content that has been silently missing will reappear.

---

## Two-tier navigation

Use `-NavGroup` on **any** cmdlet (`Add-DhTable`, `Add-DhFilterCard`, `Add-DhBarChart`, `Add-DhHtmlBlock`, `Add-DhCollapsible`) to create a grouped navigation with a primary tab bar and a sub-nav strip:

```powershell
$report = New-DhDashboard -Title 'Operations Dashboard'

# Filter card and bar chart placed at the top of the Identity group
Add-DhFilterCard -Report $report -Id 'status-fc' -NavGroup 'Identity' `
    -Title 'Filter by Status' -TargetTableId 'users' -FilterField 'Status' `
    -Cards @( @{Label='Active'; Value='Active'}, @{Label='Disabled'; Value='Disabled'} )

Add-DhTable -Report $report -TableId 'users'   -Title 'Users'   -Data $users   -NavGroup 'Identity'
Add-DhTable -Report $report -TableId 'groups'  -Title 'Groups'  -Data $groups  -NavGroup 'Identity'
Add-DhTable -Report $report -TableId 'servers' -Title 'Servers' -Data $servers -NavGroup 'Infrastructure'
Add-DhTable -Report $report -TableId 'disks'   -Title 'Disks'   -Data $disks   -NavGroup 'Infrastructure'

Export-DhDashboard -Report $report -OutputPath '.\ops.html' -Force
```

Result: primary nav shows **Identity** and **Infrastructure** group tabs. Clicking a group tab shows the subnav for that group. Blocks with a matching `-NavGroup` appear as persistent content above the sub-nav panel (e.g. filter cards remain visible while switching between tables in the same group). Groups composed entirely of blocks (no tables) are supported — the subnav strip is hidden automatically for those groups.

### Three-tier navigation (optional)

Add an optional `-NavSubGroup` on top of `-NavGroup` to get a third level: a pill strip appears below the sub-nav when the active group has any subgroups. When a group with subgroups is opened, the **first pill is automatically active**, so items tagged with `-NavSubGroup` behave as a true subgroup binding — visible only when their pill is the active one. Clicking another pill switches the subgroup; clicking the active pill clears the filter and shows all items in the group. Items in a group that have **no** `-NavSubGroup` remain visible regardless of pill state, acting as group-wide content.

```powershell
Add-DhTable -Report $report -TableId 'users-prod' -Title 'Users (Prod)' -Data $prodUsers `
    -NavGroup 'Identity' -NavSubGroup 'Production'
Add-DhTable -Report $report -TableId 'users-dev'  -Title 'Users (Dev)'  -Data $devUsers  `
    -NavGroup 'Identity' -NavSubGroup 'Development'
Add-DhTable -Report $report -TableId 'users-all'  -Title 'All Users'    -Data $allUsers  `
    -NavGroup 'Identity'   # no NavSubGroup → always visible in Identity
```

The parameter is available on every block cmdlet (`Add-DhTable`, `Add-DhHtmlBlock`, `Add-DhCollapsible`, `Add-DhFilterCard`, `Add-DhBarChart`) and is fully backward compatible — existing scripts work unchanged.

---

## Collapsible sections

```powershell
Add-DhCollapsible -Report $report -Id 'accounts' -Title 'Accounts' -DefaultOpen $true `
    -Cards @(
        @{
            Title      = 'Production'
            Badge      = 'Active'
            BadgeClass = 'cell-ok'
            Fields     = @(
                @{ Label='Account ID'; Value='acc-001' }
                @{ Label='Region';     Value='us-east-1' }
            )
        }
    )
```

Use `-CardWidth` to change the card grid sizing: `small` (150–220 px), `normal` (default, 200–320 px), `large` (280–480 px), `xlarge` (360–640 px), or `auto` (240 px min, no max — cards grow to fill the row).

```powershell
Add-DhCollapsible -Report $report -Id 'accounts' -Title 'Accounts' -CardWidth 'large' -Cards $cards
```

---

## HTML blocks

```powershell
Add-DhHtmlBlock -Report $report -Id 'intro' -Title 'Overview' -Style 'info' -Content @"
<p>This dashboard is generated automatically. Data is refreshed daily.</p>
<ul>
  <li><strong>Section A</strong> — identity and access</li>
  <li><strong>Section B</strong> — infrastructure inventory</li>
</ul>
"@
```

---

## Logo and header fields

The logo (`-LogoPath`) is displayed in the **report header** only — it does not appear in the nav bar.
`-NavTitle` is optional; when omitted the nav bar shows only navigation links.

```powershell
$report = New-DhDashboard -Title 'Infrastructure Dashboard' `
    -Subtitle 'Environment: Production' `
    -LogoPath 'C:\img\logo.png' `
    -Theme Company `
    -NavTitle 'Infra' `
    -InfoFields @(
        @{ Label='Environment'; Value='Production' }
        @{ Label='Region';      Value='us-east-1'  }
        @{ Label='Generated';   Value=(Get-Date -Format 'yyyy-MM-dd') }
    )
```

---

## Declarative layouts (YAML) — `DashHtml.Design`

An **optional** companion module, [DashHtml.Design](DashHtml.Design/README.md),
lets you manage a dashboard's *layout* in a declarative YAML/JSON file and
round-trip between YAML and PowerShell. It is a pure design tool — it makes **no
changes to this module**.

```powershell
Import-Module DashHtml.Design

# YAML layout  ->  runnable build script  ->  HTML
ConvertFrom-DhYaml   -Path layout.yaml -OutFile build.ps1 -OutputPath dash.html

# built report  ->  YAML layout (lossless snapshot)
$report | ConvertTo-DhYaml -OutFile layout.yaml

# existing .ps1  ->  YAML (best-effort static parse)
ConvertFrom-DhScript -Path build-dashboard.ps1
```

See the [module README](DashHtml.Design/README.md) and the
[example](Examples/design/) for the layout schema and full details.

---

## Building and testing

`Build.ps1` produces **two independently publishable modules** — the core
`DashHtml` and the optional `DashHtml.Design` companion. Each gets its own
manifest validation, `dist\<Module>\` staging folder, versioned `.zip`, and
`.nupkg`. They are **versioned separately**.

```powershell
# Run tests (one suite, covers both modules)
Invoke-Pester .\Tests -Output Detailed

# Build both (validate + lint + test + stage dist/ + zip)
.\Build.ps1

# Bump the CORE patch version
.\Build.ps1 -BumpVersion

# Bump the COMPANION patch version (independent of the core)
.\Build.ps1 -BumpDesignVersion

# Pack a .nupkg per module for publishing
.\Build.ps1 -NuGet

# Core module only; skip the companion entirely
.\Build.ps1 -SkipDesign

# Fast local iteration
.\Build.ps1 -SkipTests -SkipLint
```

Artifacts land in `dist\`:

```
dist\DashHtml\                   dist\DashHtml.Design\
dist\DashHtml-v2.0.0.zip        dist\DashHtml.Design-v1.0.0.zip
dist\DashHtml.2.0.0.nupkg       dist\DashHtml.Design.1.0.0.nupkg
```

Each staged module ships its own `README.md` (the companion has a module-local
one, so its PSGallery page describes the companion, not the core) plus `LICENSE`.

---

## Security model

DashHtml emits a **self-contained static HTML file** intended to be opened locally (file:// or an intranet share) by an analyst or operator. There is no server, no auth, no state mutation, no cross-origin context. The realistic threat model is **untrusted data flowing through your PowerShell script into the dashboard**: an attacker plants a malicious string in an external system (an AD attribute, a ticket title, a log line, a hostname), your script reads it without sanitising, and the rendered HTML executes script when the analyst opens the report.

### Hard rules

These four parameters are **raw HTML by design** — they are emitted via `innerHTML` so the caller can embed lists, links, formatted markup, etc.

| Cmdlet | Field | Sink |
|---|---|---|
| `Add-DhHtmlBlock` | `-Content` | `innerHTML` |
| `Add-DhTabs` | per-tab `Content` | `innerHTML` |
| `Add-DhCollapsible` | `-Content` | `innerHTML` |
| `Add-DhAlertBanner` | `-Message` | `innerHTML` |

**Since 1.6.0, each of these takes an `-AllowHtml` switch.** Pass **`-AllowHtml:$false`** whenever the content includes externally-sourced data — the cmdlet HTML-encodes it for you, so it renders as literal text and cannot execute:

```powershell
# Untrusted value interpolated into a message — let the cmdlet encode it
Add-DhAlertBanner -Report $r -Id 'a' -Severity warning `
    -Message "Ticket: $($ticket.Title)" -AllowHtml:$false

# Markup you authored yourself — keep it raw
Add-DhHtmlBlock -Report $r -Id 'intro' -Style info -AllowHtml:$true `
    -Content '<ul><li>Section A</li><li>Section B</li></ul>'
```

`-AllowHtml` defaults to `$true` (raw) in the 1.x line, **but that default flips to `$false` (encode) in 2.0.0.** If you pass HTML without an explicit `-AllowHtml`, you'll get a one-time deprecation warning per call — resolve it by adding `-AllowHtml:$true` (trusted markup) or `-AllowHtml:$false` (untrusted data). If you'd rather encode manually, `[System.Web.HttpUtility]::HtmlEncode()` (or `[System.Net.WebUtility]::HtmlEncode()`) still works.

Everything else (table cells, summary tile labels, topology node labels, status grid cells, KPI captions, etc.) goes through HTML-encoding automatically; passing user-supplied text is safe.

### What the module enforces for you (since 1.5.3)

- **Colour values** on `Add-DhPieChart` slices and `Add-DhLineChart` series are validated against an allowlist (`#hex`, `rgb()/rgba()`, `hsl()/hsla()`, `var(--token)`, CSS named colours). Anything else throws at declaration time. Closes the CSS-injection vector where a `;background:url(http://evil/...)` payload would otherwise reach the inline `style=""` attribute.
- **Action URLs** on `Add-DhAlertBanner -Action` and `Add-DhSummary` tile `Action` must use `http:`, `https:`, `mailto:`, `tel:`, or a leading `#`. `javascript:` and `data:` URLs are rejected before they reach `window.open()`.
- **CDN scripts** (`xlsx`, `jspdf`, `jspdf-autotable`) are loaded with SRI `integrity="sha384-…"` attributes pinned to the bundled versions. A compromised CDN cannot inject arbitrary script.
- **JSON embedding** escapes `</script>` (existing) plus U+2028 / U+2029 line separators (new in 1.5.3).

### What you should still do

- **Treat your dashboard generator like an injection-vulnerable application.** Even if you trust the data sources today, pass `-AllowHtml:$false` (or pre-encode) every external string before it reaches one of the four raw-HTML sinks above.
- **Open dashboards from trusted locations only.** Anyone who can write to the HTML file can put anything in it.
- **Don't open a dashboard from an email attachment** without verifying the sender — same hygiene as any other downloaded `.html` file.

---

## Project structure

```
DashHtml/
  DashHtml.psd1          Module manifest
  DashHtml.psm1          Module loader
  Public/
    New-DhDashboard.ps1
    Add-DhTable.ps1
    Add-DhSummary.ps1
    Add-DhBarChart.ps1
    Add-DhPieChart.ps1
    Add-DhLineChart.ps1
    Add-DhBullet.ps1
    Add-DhFilterCard.ps1
    Add-DhHtmlBlock.ps1
    Add-DhCollapsible.ps1
    Add-DhAlertBanner.ps1
    Add-DhStatusGrid.ps1
    Add-DhEventFeed.ps1
    Add-DhHeatmap.ps1          # v1.5
    Add-DhTopologyMap.ps1      # v1.5
    Add-DhTabs.ps1             # v1.5
    Set-DhTableLink.ps1
    Export-DhDashboard.ps1
    Get-DhTheme.ps1
  Private/
    Get-DhJsContent.ps1
    Get-DhCssBase.ps1
    Get-DhThemeCss.ps1
    Get-DhCssDefaultLight.ps1
    Get-DhCssDefaultDark.ps1
    Get-DhCssAzureLight.ps1
    Get-DhCssAzureDark.ps1
    Get-DhCssVMwareLight.ps1
    Get-DhCssVMwareDark.ps1
    Get-DhCssGreyLight.ps1
    Get-DhCssGreyDark.ps1
    Get-DhCssCompanyLight.ps1
    Get-DhCssCompanyDark.ps1
    Get-DhCssRagLight.ps1            # v1.4
    Get-DhCssRagDark.ps1             # v1.4
    Build-DhTableSections.ps1
    ConvertTo-DhJsonString.ps1
    ConvertTo-DhRagThresholds.ps1    # v1.4 — unified -Rag normaliser
Tests/
  DashHtml.Tests.ps1               # 474 tests at 2.0.0
Examples/                            # Demo-<Domain> = a realistic report
                                     # Demo-Feature-* = one capability, isolated
  Demo-ActiveDirectory.ps1           # AD ops report
  Demo-VMware.ps1                    # vSphere ops report
  Demo-Feature-FullShowcase.ps1      # every cmdlet, realistic data
  Demo-Feature-AllChartTypes.ps1     # every chart type + when to use each
  Demo-Feature-RangeBar.ps1          # Add-DhRangeBar, both data modes
  Demo-Feature-TabsHeatmapTopology.ps1
  Demo-Feature-NavMultiPanel.ps1     # per-NavGroup KPI strips
  Demo-Feature-NavTree.ps1           # v2 -NavPath tree
  Demo-Feature-NavDeepSidebar.ps1    # v2 deep nav sidebar
Build.ps1
Build-DhReference.ps1              # Generates DashHtml-Reference.html
Install.ps1
CHANGELOG.md
README.md
readme-dev.md                      # AI-assistant reference
```

---

## License

MIT













