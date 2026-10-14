# DashHtml gotchas — check these before declaring work done

Every item here has cost real debugging time. The common thread: **most of these
fail silently.** Nothing throws, nothing appears in the console — you just get an
empty panel, a blank cell, or a control that does nothing.

## 1 — The silent-failure short list

Run through this whenever a dashboard "looks wrong" but nothing errored.

1. **Declaration order.** Declare a table before anything referencing its
   `TableId`: `Set-DhTableLink`, `Add-DhBarChart`, `Add-DhPieChart` (Mode A),
   `Add-DhFilterCard`, `Add-DhRangeBar`, `Add-DhAlertBanner -Action`,
   `Add-DhStatusGrid` cell `LinkTableId`, summary tile `Action`, `Add-DhFindings`
   `AffectedTableId`. What happens otherwise (verified in 2.1.4):
   - `Add-DhBarChart` / `PieChart` / `FilterCard` **throw** when *another*
     table already exists but this one does not yet. They skip the check when
     no table exists at all. `Set-DhTableLink` always throws.
   - The browser does not care about order: table-fed blocks render after
     every table engine exists.
   - Since 2.1.4, `Export-DhDashboard` **warns** about every id that never
     gets a table, or an unknown block type. Read export warnings: they are
     the replacement for the old silent no-op.

   In a ProjectPS report script, don't check this by eye — PsReport.Core ships
   `Add-DhTableIfData` (returns `$true` when the table was added; gate dependent
   widgets on it) and `Test-DhTableRegistered -Report $r -TableId '...'`. See
   `script-contract.md` §1.

1a. **A single object passed as `-Data` is enumerated by _property_, not row.**
   A lone `[PSCustomObject]` is not an `[object[]]`, so PowerShell binds it as a
   scalar and you get one row per property instead of one row of data. Always
   wrap: `-Data @($rows)`. `Add-DhTableIfData` does this re-wrap for you, which
   is one of the reasons to prefer it. Use `Get-DataCount` for a null-safe count
   rather than `$x.Count`, which throws under `Set-StrictMode` when `$x` is
   `$null`.
1b. **A pipeline that produces nothing returns `$null`, not an empty array.**
   `$rows = $src | ForEach-Object { [pscustomobject]@{...} }` is `$null` when
   `$src` is empty, and `$rows.Count` then **throws** under `Set-StrictMode
   -Version Latest` — the whole HTML section fails. Always wrap:
   `$rows = @($src | ForEach-Object { ... })`. The same applies to
   `$x = if (...) { @(...) }`: the `if` unrolls the array; write `$x = @(if (...) { ... })`.
1c. **An empty list passed to a widget's list parameter throws** —
   `Add-DhFilterCard -Cards @()`, and the same shape for `-Items`, `-Slices`,
   `-Nodes`, `-Events`: *Cannot bind argument to parameter 'Cards' because it is
   an empty array*. It is loud, but it takes down the **whole** HTML section, and
   it only happens on the empty-data run. Lists built from the data
   (`$rows | Group-Object OS | ForEach-Object { @{ Label=$_.Name ... } }`) are the
   usual culprit — gate the call on the list's count, not only on the table flag.
2. **Nav path typo or wrong scope** — see `navigation.md` §9. Case-sensitive.
3. **`Sparkline=@()`** (empty array) renders nothing and reports nothing. Omit
   the key instead.
4. **Sparkline cells need real arrays.**
   `[PSCustomObject]@{ Cpu24h = @(30,42,38) }` — not strings, not
   comma-separated text. Anything non-array renders as an em-dash.
5. **Mutating `$report` after `Export-DhDashboard`** — already serialised, the
   changes are lost.
6. **Re-exporting to the same path without `-Force`** — warns and returns
   without writing. You end up reading yesterday's file.
7. **Global filters do not reach summary tiles.** `Add-DhGlobalFilter` re-filters
   tables and table-derived charts; KPI tiles are computed once from the full
   dataset and never re-aggregate. For filter-reactive KPIs, drive them from a
   filtered table or scope them per panel.
7a. **A bar chart counts rows unless told otherwise.** A chart titled "lag in
   minutes" or "GB used" without `-ValueField` / `-Aggregate` (2.2+) draws the
   **number of rows** per group. In a table's `-Charts`, `Type='bar'` likewise
   needs `ValueField` + `Aggregate`. `-ValueField` must match the property name
   exactly, case-sensitive.
7b. **Table `-Charts` with no `Type` draws a donut; `Type='pie'` is solid**
   (since 2.1.4; earlier `'pie'` also drew a donut). Unknown types warn and
   are skipped.

## 2 — Values, styles, and thresholds

8. **`Icon` must be an emoji** (`🖥` `⚠` `🔒` `🌐`) or unicode glyph. Bare ASCII
   letters render as broken single characters — and so do **words**: there is no
   named-icon set, `Icon='shield'` / `'server'` / `'OK'` / `'X'` all render as
   letters. The checker catches 1–3 letters (`DASH006`); longer words it misses.
9. **`Add-DhHtmlBlock -Style` is `info|warn|danger|ok|nodata|neutral`.** There is
   **no `warning`** — that value exists only on `Add-DhAlertBanner -Severity`.
   Mixing them up is a frequent error.
10. **`-Rag` beats `Thresholds=`** when both are on the same item or column; the
    `Thresholds` value is silently discarded. Same for `Class='cell-ok'` plus
    `Rag=@{...}` on one tile — `Rag` wins and `Class` is ignored. Pick one.
11. **`Rag.NoData=$true` is the only way to render nulls as `cell-nodata`.**
    Without it, nulls are blank in a table and **throw** on a gauge tile or
    `Add-DhBullet`.
12. **Never hardcode a hex colour** in markup or CSS — it breaks the theme
    toggle. Use the CSS variables (`var(--cell-ok-fg)`, `var(--accent-primary)`).
13. **Standard tile size is intentional.** "Tiles are too small" usually means
    the user wants `Style='bignumber'` for the headline metric.

## 3 — Per-widget traps

14. **`Add-DhPieChart` Mode A and Mode B are mutually exclusive.** Either
    `-TableId` + `-Field`, or `-Slices @(...)`. Passing both throws.
15. **`Add-DhStatusGrid` validates axis membership.** Every cell's `Row` and
    `Column` must appear in `-Rows` / `-Columns`. Typos throw (this one is loud).
16. **Heatmap vs StatusGrid.** Heatmap cells carry a **numeric** `Value`
    (interpolated colour); StatusGrid cells carry a **categorical** `Status`
    (discrete RAG). Range → Heatmap. State → StatusGrid.
17. **`Add-DhTopologyMap` rejects cycles, missing parents and duplicate ids.**
    Every `Parent` must be `$null`/`''` or match another node's `Id`.
    Self-parents, cycles and two nodes with one `Id` throw at declaration time.
    Multiple roots (a forest) are fine. **Build node ids from a counter, never
    from the data** (`"cl-$n"`, name in `Label`): real inventories repeat names —
    two clusters called `Prod` in different datacenters, the same server listed
    as broker twice — and a name hash only moves the collision. Keep a lookup
    (`$clusterIds["$dc|$cluster"] = "cl-$n"`) to wire children to parents.
    `Add-DhStatusGrid` is the quiet version: duplicate `Row` keys collapse and the
    last cell wins.
17a. **The same applies to ids inside hand-written HTML.** A block whose
    `-Content` carries element ids for its own JavaScript (tabs, show/hide
    buttons) must build them from the block's position, not from a name — two
    vaults with the same name in different subscriptions made each other's tabs
    switch.
18. **Topology wide-fan + long labels is the classic bad render.** More than ~5
    children with FQDN labels truncates everything at the default 140px node
    width. Fix all three together: `-Direction 'horizontal'`, `-AutoFitWidth`
    (cap via `-AutoFitMaxWidth`, default 360), and **insert intermediate
    category nodes** so the tree reads like an architecture diagram. Always set
    `Tooltip` on leaves to the full identifying string.
19. **`Add-DhBarChart -ClickFilters` is single-series only.** With `-Stacked` it
    is a no-op — a stacked bar has no single value to filter by.
20. **`-ClickFilters` needs 2.1.3+.** Earlier versions rendered clickable bars
    that threw `ReferenceError: engines is not defined`, and a label containing
    `"` could inject HTML attributes. **The runtime is baked into each generated
    HTML file — updating the module is not enough, the dashboard must be
    regenerated.**
21. **A bar click applies a _text_ filter, not an exact-value match.** Same code
    path as typing in the search box, so a bar labelled `X` also matches
    `Xenon`. For exact-value semantics use `Add-DhFilterCard`.
22. **`Add-DhTabs` is not navigation.** Tabs partition content within one block;
    `-NavPath` partitions the page.
23. **`-Pageable:$false` shows ALL rows** (since 1.7.0) and virtualises above
    150 inside a `max-height:70vh` scroll container. If you want few rows, set a
    small `-PageSize` with paging on.
24. **Exports always cover the full filtered set**, never just the visible page
    or virtualised window. Filter the data first if you want less.
25. **`-AutoRefresh` is a browser `<meta refresh>`, not live data.** Schedule the
    generating job slightly more often than the refresh interval.

## 3a — Export, print and offline (2.2+)

- **"No CDN" is only true with `-ExportLibraries Embed` or `None`.** The default
  `Cdn` loads SheetJS / jsPDF from cdnjs on the first XLSX/PDF click. The page
  no longer waits for them, and offline the buttons grey out instead of raising
  an alert. For air-gapped customers use `Embed` (+1.3 MB per file).
- **Printing rearranges the page** between `beforeprint` and `afterprint`:
  every view in menu order, everything expanded, tables up to
  `-PrintMaxRows`. Headless `--print-to-pdf` runs the same handlers. If a
  pipeline prints without browser events, call `window._dhBeforePrint()`
  first.
- **The theme is remembered per browser** (localStorage) since 2.1.4. All
  `file://` reports share one origin, so a reader who picks dark gets dark in
  every report. `-ThemeMode` (2.2) sets only the default for readers who have
  not chosen.

## 4 — Security and encoding

26. **Four cmdlets accept raw HTML:** `Add-DhHtmlBlock -Content`,
    `Add-DhCollapsible -Content`, `Add-DhAlertBanner -Message`, and `Add-DhTabs`
    per-tab `Content`. Since **2.0.0 the `-AllowHtml` default is `$false`**
    (encode).
    - `-AllowHtml:$true` — only for markup **you** wrote.
    - leave the default — for anything externally sourced (AD attribute, ticket
      title, log line, hostname, API text).
27. **Every other text field is HTML-encoded for you** — including all `Add-DhFindings` text (2.2; there is no `-AllowHtml` there) and `CellType='link'` cells, which link only http(s)/mailto URLs — table cells (including
    the `progressbar` label since 1.10.1), summary labels, topology labels,
    status-grid cells, KPI captions. Do **not** pre-encode; you will get double
    encoding. Colour values and `Action` `Url` fields are validated and throw on
    hostile input.
27a. **State the choice explicitly, also when it is the default.** The house
    checker (`DASH002`) wants `-AllowHtml:$false` written out on data-derived
    text (banner messages built from counts, collapsible cards with AD / Azure
    names), so a reviewer can tell *chosen* from *forgotten*.
28. **Do not "fix" a call that deliberately keeps the encoding default.** In the
    ProjectPS Documentation scripts, four `Add-DhAlertBanner` sites intentionally
    stay encoded (Azure resource counts, Parallels licence/broadcast text from
    the RAS API). The audit flags them because they are *unchosen*, not wrong.
    Adding an explicit `-AllowHtml:$false` is the only acceptable change.

## 5 — When extending the module itself

29. **Locale-safe parsing.** Always pass `InvariantCulture` to
    `[double]::TryParse`. An `it-IT` machine read `92330.25` as `9233025`.
30. **JS helpers live at module scope.** The runtime is split across
    `Get-DhJsCore/Blocks/Nav/Table/Boot.ps1` and concatenated into **one** shared
    scope. Put new block renderers in `Get-DhJsBlocks.ps1`; never nest a helper
    inside another renderer.
31. **`ConvertTo-DhJsonString`: the order of the escape passes is load-bearing.**
    Do not fold them into one regex, and do not swap in `ConvertTo-Json` or
    `System.Text.Json`. CR is *dropped*, so `'<' CR '/script>'` only collapses
    into a literal `</script>` partway through escaping and is caught by the
    later `</` → `<\/` pass. A single regex over the original string never sees
    it — that is a script breakout. The fast path (`IndexOfAny`) is the safe way
    to speed this up and already bought ~40×.
32. **Never pass an options object to `localeCompare` inside a comparator.** It
    re-resolves collation on every call — 5.6 s of blocked main thread on a
    19,011-row sort. Build one `Intl.Collator` and reuse `collator.compare`.
    This class of bug is invisible to functional tests, so it is pinned at source
    level in the Pester suite.
33. **Pester test names must not contain angle brackets.** Pester 5 parses
    `<...>` in an `It` / `Describe` name as a `-ForEach` template token and tries
    to evaluate it — `It 'escapes </script>'` fails with
    `CommandNotFoundException: The term '$/script' is not recognized`, even
    though the test body is fine. This has cost time **twice** in this repo.
    Describe the thing in words ("a closing script tag", "an expr placeholder")
    and keep the literal `<...>` in the assertion body.

## 6 — Anti-patterns

| Don't | Why | Do instead |
|---|---|---|
| Audit DashHtml calls with `grep` | Calls span lines with backtick continuation; greps found 0 issues where the AST audit found 13 | `Tools\Test-DhV2Upgrade.ps1` or `Update-DhScript` |
| `Icon='X'` or `Icon='shield'` | Bare letter glyphs, look broken | `Icon='🖥'` or omit |
| `Id="dc-$($dc.Name)"` | Collides on repeated names; topology throws | `$n++; Id="dc-$n"`, name in `Label` |
| `$x -eq ''` to test "no value" | `0 -eq ''` is `$true` — a numeric 0 becomes "no data" | `$null -eq $x -or ($x -is [string] -and $x.Length -eq 0)` |
| Chart before its table | Silent no-op | Tables first, then references |
| `-Cards $cards` built from data, ungated | Empty list throws, whole HTML section lost | `if ($hasT -and $cards.Count -gt 0)` |
| Hardcode `#1B6B35` | Breaks the theme toggle | `var(--cell-ok-fg)` |
| `Style='gauge'; Value=$null` without `Rag.NoData=$true` | Throws | Opt in to `NoData` |
| `-Filled` with >10 series | Visual mush | `-Filled` for 1–3 series only |
| Repeat threshold arrays per item | Verbose and drift-prone | Define `$rag` once, reuse via `Rag=$rag` |
| Hand-roll HTML/CSS/JS for a report | Defeats the point of the module | Use the cmdlets; extend the module if something is genuinely missing |
