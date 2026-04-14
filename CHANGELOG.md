# Changelog

All notable changes to DashHtml are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
