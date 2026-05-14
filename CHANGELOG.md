# Changelog

All notable changes to DashHtml are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
