# Changelog

All notable changes to DashHtml are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
