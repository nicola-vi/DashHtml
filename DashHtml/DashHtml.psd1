@{
    # Module identity
    RootModule        = 'DashHtml.psm1'
    ModuleVersion     = '1.5.3'
    GUID              = '3f8e9a2c-1d4b-47f5-8c6e-0a5d2b9f3e71'
    Author            = 'DashHtml Contributors'
    CompanyName       = 'DashHtml Contributors'
    Copyright         = '(c) 2026 DashHtml Contributors. MIT License.'
    Description       = 'Generate interactive self-contained HTML dashboards. Includes sortable / filterable / pageable tables, linked drill-down, client-side CSV / Excel / PDF export, KPI summary tiles (with optional sparklines, trend deltas, big-number and gauge styles), pie / donut / line / area / bar / stacked-bar / bullet charts, RAG status matrix, sequential / diverging 2-D heatmaps, parent-child topology trees, inline tabbed content blocks, chronological event feeds, dismissible alert banners, threshold cell colouring with a unified -Rag parameter, and a sticky nav bar. Six built-in theme families (Default, Azure, VMware, Grey, Company, Rag — the v1.4 family using the Office/Excel-compatible RAG palette) each with embedded light / dark variants and a runtime toggle button.'
    PowerShellVersion = '7.0'

    # Exports
    FunctionsToExport = @(
        'New-DhDashboard'
        'Add-DhTable'
        'Set-DhTableLink'
        'Export-DhDashboard'
        'Get-DhTheme'
        'Add-DhSummary'
        'Add-DhHtmlBlock'
        'Add-DhCollapsible'
        'Add-DhFilterCard'
        'Add-DhBarChart'
        'Add-DhAlertBanner'
        'Add-DhPieChart'
        'Add-DhBullet'
        'Add-DhLineChart'
        'Add-DhEventFeed'
        'Add-DhStatusGrid'
        'Add-DhTabs'
        'Add-DhHeatmap'
        'Add-DhTopologyMap'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Gallery metadata
    PrivateData = @{
        PSData = @{
            Tags         = @('HTML','Dashboard','Table','Export','CSV','Excel','PDF','Report','Infrastructure')
            LicenseUri   = 'https://github.com/nicola-vi/DashHtml/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/nicola-vi/DashHtml'
            ReleaseNotes = @'
1.5.3 — Security hardening. Closes three concrete vectors flagged in the v1.5.2 audit, no script changes required for any caller passing well-formed colours and URLs. Add-DhPieChart slice Color and Add-DhLineChart series Color are now validated against an allowlist of CSS colour shapes (#hex, rgb/rgba/hsl/hsla, var(--token), CSS named colours) before being interpolated into inline style="background: ...", closing the CSS-injection vector reachable when a caller piped untrusted data into a colour field. Add-DhAlertBanner -Action and Add-DhSummary tile Action validate the Url scheme (http/https/mailto/tel/#) so a javascript: URL can no longer reach window.open() and execute in the dashboard origin. The three cdnjs <script> tags now carry SRI integrity="sha384-..." attributes pinned to the bundled library versions, so a compromised CDN cannot inject arbitrary script. ConvertTo-DhJsonString also escapes U+2028 / U+2029 as their explicit \u JSON sequence. Help text on Add-DhTabs, Add-DhAlertBanner, and Add-DhCollapsible spells out the raw-HTML / never-pass-untrusted-data contract previously only documented on Add-DhHtmlBlock. 14 new Pester tests cover each new validator (322 total).

1.5.2 — Topology map usability: Add-DhTopologyMap now accepts -AutoFitWidth (and -AutoFitMaxWidth, default 360 px). When set, the JS renderer measures the widest label / icon / badge combination across all nodes via a hidden canvas and grows NodeWidth so FQDN labels no longer truncate. Topology nodes also get a real styled tooltip on hover — the explicit Tooltip value when supplied, otherwise the full Label — replacing the OS-default title attribute. The tooltip is a single body-level overlay positioned via JS, so it works on SVG nodes (CSS pseudo-elements do not render on SVG elements). No script changes required; pass -AutoFitWidth to opt in.

1.5.1 — Collapsible chrome across every cmdlet. New -Collapsible / -DefaultOpen parameters (default $true, matching Add-DhSummary) on Add-DhBarChart, Add-DhBullet, Add-DhEventFeed, Add-DhFilterCard, Add-DhHeatmap, Add-DhHtmlBlock, Add-DhLineChart, Add-DhPieChart, Add-DhStatusGrid, Add-DhTabs, Add-DhTopologyMap, Add-DhAlertBanner, and Add-DhTable. Add-DhTable additionally accepts -Icon for the new clickable header. Existing dashboards immediately get folding headers; pass -Collapsible:$false per call to restore the flat 1.5.0 look. Implementation centralises the wrap in a single JS dispatcher (wrapCollapsibleBlock) so renderers stay untouched; tables and alert banners get tailored wraps because of their distinct pipelines.

1.5.0 — Tier A widgets: inline tabs, 2-D heatmaps, topology trees.

New cmdlets:
  * Add-DhTabs         - Inline tabbed content block. Local pivot within one
                         section of the dashboard flow (distinct from NavGroup
                         which partitions the whole page). Full W3C tabs
                         accessibility pattern (role=tablist / tab / tabpanel,
                         arrow-key navigation, focus-visible outline).
  * Add-DhHeatmap      - Rows × Columns matrix with a sequential or diverging
                         numeric colour scale. Distinct from Add-DhStatusGrid
                         (categorical RAG). -ColorScale 'sequential' | 'diverging',
                         -Min / -Max auto-fit, -Unit suffix on values, -ShowValues
                         to render the number inside each cell. Defaults to a
                         5000-cell ceiling with a soft 1000-cell warning.
  * Add-DhTopologyMap  - Parent-child tree visualisation (AD Forest → Domain → DC,
                         vCenter → Cluster → Host, network device hierarchies, etc.).
                         Recursive subtree-width layout — simple tidy tree, no
                         force-directed graph. Cycles rejected; missing parents
                         throw. Per-node Status / Icon / Badge / Tooltip /
                         LinkTableId / LinkFilter for click-to-jump navigation.
                         -Direction 'vertical' (default) or 'horizontal'.

Behaviour unchanged for everything else; fully backward compatible at the
API level. 308 Pester tests pass (up from 282 at 1.4.2).

------------------------------------------------------------------------------
1.4.2 — Small UX wins.

Added:
  * Add-DhAlertBanner -NavGroup / -NavSubGroup — per-panel banners.
    Without the params, banners remain page-global as in 1.4.x.
  * Add-DhSummary per-tile Action=@{TableId?;Filter?;Url?;Label?} — the whole
    tile becomes clickable, navigating to a registered table (with optional
    pre-filter) or opening an external URL. Same shape as the AlertBanner
    -Action. Adds .tile-clickable styling + keyboard activation (Enter/Space).
  * New-DhDashboard -AutoRefresh '30s' / '5m' / '1h' / '300' — emits a
    <meta http-equiv="refresh"> in <head>. Useful for wall-display ops
    dashboards. Omit / pass '' to disable (default).
  * Native hover tooltips (title="...") on pie slices and bar chart bars —
    label / count / percentage shown on hover. No JS library, browser-native.

282 Pester tests pass (up from 266 at 1.4.1).

------------------------------------------------------------------------------
1.4.1 — Per-NavGroup summary strips + JS hoist fix.

Added:
  * Add-DhSummary now accepts -NavGroup / -NavSubGroup / -Id, so each panel
    in a two-tier nav can have its own KPI strip. Without -NavGroup, the
    legacy top-of-page singleton behaviour is preserved. Multiple per-group
    strips can coexist alongside one global strip.
  * New example: Examples/Multi-Panel-Dashboard.ps1 — focused showcase of the
    multi-summary feature.
  * Invoke-Demo-DashHtml.ps1 moved to Examples/ and refreshed to exercise the
    full v1.4 widget set (banner, gauge, bignumber, bullet, line, pie, status
    grid, event feed, sparkline cells, per-group summary).

Fixed:
  * JS hoist: pickThresholdClass / classToAccent / classToAccentBg and the
    tile-builder helpers (buildTile, buildStandardTile, buildBignumberTile,
    buildGaugeTile, tileFormatValue, tileDeltaHtml, tileSparklineHtml) were
    nested inside renderSummary() and therefore unreachable from the bullet
    and line-chart renderers at runtime. The latent ReferenceError didn't
    surface in the Pester tests (which match emitted HTML text rather than
    executing the JS), but a browser would have thrown when rendering those
    blocks. All helpers are now at module scope and reused everywhere.

266 Pester tests pass (up from 257 at 1.4.0).

------------------------------------------------------------------------------
1.4.0 — KPI & Dashboard Primitives. Major widget expansion driven by the
IT-infrastructure KPI dashboard specification.

New cmdlets:
  * Add-DhStatusGrid   - rows x columns RAG matrix (services x regions etc.)
  * Add-DhAlertBanner  - top-of-page dismissible alert strip
  * Add-DhEventFeed    - chronological severity-tagged audit trail
  * Add-DhPieChart     - standalone pie / donut block
  * Add-DhBullet       - actual-vs-target with performance bands
  * Add-DhLineChart    - line / area chart with axes, multi-series, optional
                         dashed target / threshold annotation line

Add-DhSummary tile upgrades:
  * Inline sparklines (line / area / bars) below the value
  * Trend & delta indicators (Previous baseline, auto direction, TrendIsGood
    inversion for "lower is better" metrics, percent / absolute / both)
  * Style="bignumber"  hero metric, full-width, large typography, optional Caption
  * Style="gauge"      semicircle SVG with threshold-coloured arc + central readout

Cross-cutting:
  * Unified -Rag parameter (@{ Green; Amber; Red; NoData }) accepted on summary
    items, gauge tiles, bullet items, and table columns; replaces or supplements
    the legacy Thresholds=@(...) array shape.
  * New Rag theme family using the Office/Excel-compatible RAG palette
    (#375623 / #7F4B00 / #9C0006 / #595959) for strict-parity reports.
  * Fourth cell-nodata state added across all six themes.

Other:
  * Add-DhBarChart gains -Stacked + -SeriesField for multi-series breakdowns.
  * Add-DhTable column CellType="sparkline" with SortBy reduction (last / avg /
    max / min / sum) and SparklineStyle.
  * Two example scripts (Examples/AD-Dashboard.ps1, Examples/vSphere-Dashboard.ps1)
    mirror the spec's reference layouts.
  * Bug fix: locale-sensitive [double]::TryParse calls in v1.4 normalisers now
    use InvariantCulture; protects decimal values on locales like it-IT where
    the period is a thousands separator.

Fully backward compatible at the API level. 257 Pester tests pass (up from 116
at the start of v1.4 work).
'@
        }
    }
}

