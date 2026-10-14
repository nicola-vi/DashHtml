# DashHtml navigation — the `-NavPath` model

> **Current model.** `-NavPath` + `-NavScope` is how navigation is declared from
> 2.0.0 onward. `-NavGroup` / `-NavSubGroup` are a **compatibility shim, kept
> indefinitely** — they still work, they are not deprecated in the "will be
> removed" sense, but they cannot express most of what the path model can.
> **Write all new code with `-NavPath`.**

## 1 — Mental model

Every item on a dashboard — table, chart, banner, KPI strip, anything — sits at a
**path** in one tree, and declares **how far its visibility reaches** from that
path. That is the whole model. There is no separate "table nav" and "block nav"
any more; that asymmetry was the 1.x defect this replaced.

```
                            declared path             scope
Compute/                    Add-DhSummary  'Compute'           Subtree  <- every Compute/* view
├── Compute/vms             Add-DhTable    'Compute/vms'       Exact    <- only this view
├── Compute/hosts           Add-DhTable    'Compute/hosts'     Exact
└── Compute/Capacity/       Add-DhBarChart 'Compute/Capacity'  Subtree
    └── .../cpu             Add-DhTable    'Compute/Capacity/cpu' Exact
Storage/
└── Storage/vols            Add-DhTable    'Storage/vols'      Exact
                            Add-DhAlertBanner (no nav params)  Global   <- everywhere
```

The menu is built from the union of every declared path. You do not declare the
menu separately — **the menu _is_ the set of paths your items declared.**

## 2 — The four parameters

Present on every nav-aware cmdlet (list in `cmdlet-index.md`), with identical meaning on each.

| Parameter | Type | Default | Meaning |
|---|---|---|---|
| `-NavPath` | `string` | `''` | `'A/B/C'` — where this item lives. `''` means page-global. |
| `-NavScope` | `Exact` \| `Subtree` \| `Global` | `Exact` when `-NavPath` is given | How far visibility reaches from that path. |
| `-NavLabel` | `string` | the last path segment | Display text for the node, decoupled from the path key. |
| `-NavOrder` | `int` | `0` | Explicit sibling ordering. `0` = declaration order. |

### Path syntax

- Segments are separated by `/`: `'Storage/Capacity/vols'`.
- **`//` escapes a literal `/`** inside a segment: `'Reports/A//B'` becomes the
  two segments `Reports` and `A/B`.
- Segments are trimmed. An **empty or whitespace-only segment throws** — a
  trailing `/`, a leading `/`, or `//` used as a separator produce an
  unaddressable node, so they are rejected:
  `Nav path 'A/' contains an empty segment. Use '//' for a literal '/'.`
- Matching is **case-sensitive** (`Ordinal`). `'Identity'` and `'identity'` are
  two different nodes — a classic silent duplicate-tab bug.

### Scope semantics

A section is visible for the selected path **iff**:

| Scope | Visible when |
|---|---|
| `Global` | always, regardless of the selected path |
| `Subtree` | the declared path is a **prefix** of the selected path (this node **and everything beneath it**) |
| `Exact` | the declared path **equals** the selected path |

Two rules fall out of this and explain most surprises:

- **An item declared deeper than the current selection can never be visible.**
  `'A/B/C'` is invisible while `'A/B'` is selected, under every scope except
  `Global`.
- **`Subtree` on a leaf behaves exactly like `Exact`** — there is nothing
  beneath it to match.

## 3 — Dashboard-level nav parameters

On `New-DhDashboard`:

| Parameter | Values | Default | Notes |
|---|---|---|---|
| `-NavTitle` | string | the `-Title` | `''` hides the nav bar label entirely. |
| `-NavLayout` | `Auto` \| `Strips` \| `Sidebar` | `Auto` | `Auto` = horizontal strips up to 3 levels, left sidebar rail at 4+. `Strips` forces the 1.x look; `Sidebar` forces the tree rail. |
| `-NavMaxDepth` | `1`–`5` | `3` | **Policy cap, not an architectural limit.** The matcher, URL state and renderer are all depth-agnostic; raising it costs only vertical chrome. |

Why `Auto` switches: three sticky strips cost ~190 px of vertical chrome at
depth 3 and ~225 px at depth 4 — 21% of a 1080p viewport. Deep trees get the
sidebar instead.

## 4 — Which cmdlets are nav-aware

**16 accept the nav parameters:** `Add-DhTable`, `Add-DhSummary`,
`Add-DhBarChart`, `Add-DhPieChart`, `Add-DhLineChart`, `Add-DhRangeBar`,
`Add-DhBullet`, `Add-DhStatusGrid`, `Add-DhHeatmap`, `Add-DhTopologyMap`,
`Add-DhTabs`, `Add-DhEventFeed`, `Add-DhFilterCard`, `Add-DhHtmlBlock`,
`Add-DhCollapsible`, `Add-DhAlertBanner`.

**5 do not:** `New-DhDashboard`, `Export-DhDashboard`, `Get-DhTheme`,
`Set-DhTableLink`, `Add-DhGlobalFilter`.

## 5 — Defaults when you declare nothing

This is where tables and blocks genuinely differ, and it is deliberate — it
reproduces the 1.x flat-nav behaviour exactly.

| Item | No nav parameters at all | Why |
|---|---|---|
| **Table** | path = `<TableId>`, scope `Exact` | A plain report shows **one table at a time**, each with its own menu link. Without this, every table would stack on one page. |
| **Block** | path = *(empty)*, scope `Global` | An ungrouped block was visible on every panel in 1.x. |

So a three-table report with no nav parameters anywhere already has a working
three-entry menu. **You do not have to declare nav to get nav.**

## 6 — Recipes

### 6.1 — Flat report, one table per menu entry

```powershell
$r = New-DhDashboard -Title 'AD Report'
Add-DhTable -Report $r -TableId 'users'  -Title 'Users'  -Data $users
Add-DhTable -Report $r -TableId 'groups' -Title 'Groups' -Data $groups
# no nav parameters needed - each table gets its own entry keyed on TableId
```

### 6.2 — Two sections, each with its own tables and its own KPI strip

```powershell
# KPI strip visible across the whole Identity section
Add-DhSummary -Report $r -NavPath 'Identity' -NavScope Subtree -Items $identityKpis

Add-DhTable -Report $r -TableId 'users'  -Title 'Users'  -Data $users `
            -NavPath 'Identity/users'  -NavLabel 'User accounts'
Add-DhTable -Report $r -TableId 'groups' -Title 'Groups' -Data $groups `
            -NavPath 'Identity/groups' -NavLabel 'Security groups'

Add-DhSummary -Report $r -NavPath 'Infrastructure' -NavScope Subtree -Items $infraKpis
Add-DhTable -Report $r -TableId 'srv' -Title 'Servers' -Data $servers `
            -NavPath 'Infrastructure/srv' -NavLabel 'Servers'
```

### 6.3 — Three levels

```powershell
Add-DhTable -Report $r -TableId 'cpu' -Data $cpu -NavPath 'Compute/Capacity/cpu'  -NavLabel 'CPU'
Add-DhTable -Report $r -TableId 'mem' -Data $mem -NavPath 'Compute/Capacity/mem'  -NavLabel 'Memory'
Add-DhTable -Report $r -TableId 'vms' -Data $vms -NavPath 'Compute/Inventory/vms' -NavLabel 'Virtual machines'

# a chart across all of Compute/Capacity, both leaves
Add-DhBarChart -Report $r -TableId 'cpu' -Field 'Cluster' `
               -NavPath 'Compute/Capacity' -NavScope Subtree
```

### 6.4 — Explicit ordering and a friendly label

```powershell
Add-DhTable -Report $r -TableId 'z_summary' -Data $sum `
            -NavPath 'Overview/z_summary' -NavLabel 'Executive summary' -NavOrder 1
Add-DhTable -Report $r -TableId 'a_detail'  -Data $det `
            -NavPath 'Overview/a_detail'  -NavLabel 'Detail'            -NavOrder 2
```

`-NavLabel` matters because the path key should stay stable and machine-ish
(`TableId`) while the visible text can be anything, including spaces and
punctuation that would otherwise need `//` escaping.

### 6.5 — A banner on one panel only, vs everywhere

```powershell
Add-DhAlertBanner -Report $r -Message 'Collected 2026-09-09' -Severity 'info'   # everywhere (Global)
Add-DhAlertBanner -Report $r -Message 'Storage at 91%' -Severity 'warning' `
                  -NavPath 'Storage' -NavScope Subtree                          # Storage only
```

### 6.6 — A literal `/` in a label

```powershell
Add-DhTable -Report $r -TableId 'rw' -Data $io -NavPath 'Performance/Read//Write'
# -> segments: 'Performance', 'Read/Write'
```

## 7 — Migrating `-NavGroup` / `-NavSubGroup` to `-NavPath`

### 7.1 — Nothing breaks if you do nothing

The shim maps the old parameters onto the new model at `Add-Dh*` time and
reproduces 1.x output exactly. Migration is a **deliberate cleanup**, not a
forced upgrade. `Update-DhScript` reports these as `advisory` and **never
rewrites nav automatically** — nav migration is always a human decision.

### 7.2 — The exact mapping the shim applies

This is the authoritative table (`Private/Resolve-DhNavDeclaration.ps1`). Use it
to produce an identical migration.

| Old declaration | Item | Resolved path | Resolved scope |
|---|---|---|---|
| `-NavGroup 'G'` | **Table** | `G/<TableId>` | `Exact` |
| `-NavGroup 'G' -NavSubGroup 'S'` | **Table** | `G/S/<TableId>` | `Exact` |
| *(none)* | **Table** | `<TableId>` | `Exact` |
| `-NavGroup 'G'` | **Block** | `G` | **`Subtree`** |
| `-NavGroup 'G' -NavSubGroup 'S'` | **Block** | `G/S` | **`Subtree`** |
| *(none)* | **Block** | *(empty)* | **`Global`** |

### 7.3 — The one trap that will bite you

**`-NavPath` defaults to `Exact`. The block shim defaults to `Subtree`.**

So the naive rewrite of a block is **wrong**:

```powershell
# BEFORE - chart visible across the whole Storage section
Add-DhBarChart -Report $r -TableId 'vols' -Field 'Tier' -NavGroup 'Storage'

# WRONG - now visible only on the bare 'Storage' node, and invisible on
#         Storage/vols, Storage/Capacity, ... Content silently disappears.
Add-DhBarChart -Report $r -TableId 'vols' -Field 'Tier' -NavPath 'Storage'

# RIGHT - scope must be restated explicitly
Add-DhBarChart -Report $r -TableId 'vols' -Field 'Tier' -NavPath 'Storage' -NavScope Subtree
```

**Rule: when migrating a _block_, always add `-NavScope Subtree`. When migrating
a _table_, append the `TableId` as the last segment and leave the scope alone.**

### 7.4 — Step by step

1. **Audit first — never with grep.** Calls span lines with backtick
   continuation, so line-oriented patterns under-report badly. On `Examples/`
   the obvious greps found **0** issues where the AST audit found **13**.
   ```powershell
   .\Tools\Test-DhV2Upgrade.ps1 -Path 'C:\Scripts' -Detailed
   Update-DhScript -Path 'C:\Scripts' -PassThru | Where-Object Severity -eq 'advisory'
   ```
2. **Back up** the script (timestamped copy) before editing — house rule.
3. **Convert tables:** `-NavGroup 'G'` becomes `-NavPath 'G/<TableId>'`, and the
   human-readable text moves to `-NavLabel`. The node is keyed on `TableId`
   because that is the only value the module enforces as unique
   (`Add-DhTable.ps1:152`); keying on `Title` would silently **merge** two
   same-titled tables into one node.
4. **Convert blocks:** `-NavGroup 'G'` becomes `-NavPath 'G' -NavScope Subtree`
   (see 7.3); `-NavGroup 'G' -NavSubGroup 'S'` becomes
   `-NavPath 'G/S' -NavScope Subtree`.
5. **Values in variables:** build the path with `Join-DhNavPath` (PsReport.Core
   2.1.0), which applies the shim's own rules — segments trimmed, blank ones
   skipped, a literal `/` escaped as `//`:
   `-NavPath (Join-DhNavPath $group $sub $tableId)` for a table,
   `-NavPath (Join-DhNavPath $group $sub) -NavScope Subtree` for a block.
   For constant values, write the literal path and compare it with what the
   shim would have built — in the 2026-09 migration that comparison (0
   mismatches in every script) was the evidence the menu did not change.
6. **Never leave both styles on one call** — that is a hard throw (see §8).
7. **Regenerate and open the HTML.** Click every menu node and confirm nothing
   vanished. Nav bugs fail silently: no console output, just an empty panel.
8. Re-run the audit; expect zero nav findings.

### 7.5 — Worked migration

```powershell
# -- BEFORE (1.x) --------------------------------------------------------
Add-DhSummary  -Report $r -NavGroup 'Storage' -Items $kpis
Add-DhTable    -Report $r -TableId 'vols'  -Title 'Volumes'   -Data $vols  -NavGroup 'Storage'
Add-DhTable    -Report $r -TableId 'snaps' -Title 'Snapshots' -Data $snaps -NavGroup 'Storage' -NavSubGroup 'Protection'
Add-DhBarChart -Report $r -TableId 'vols'  -Field 'Tier'      -NavGroup 'Storage'

# -- AFTER (2.x, identical rendering) ------------------------------------
Add-DhSummary  -Report $r -NavPath 'Storage' -NavScope Subtree -Items $kpis
Add-DhTable    -Report $r -TableId 'vols'  -Title 'Volumes'   -Data $vols  `
               -NavPath 'Storage/vols'  -NavLabel 'Volumes'
Add-DhTable    -Report $r -TableId 'snaps' -Title 'Snapshots' -Data $snaps `
               -NavPath 'Storage/Protection/snaps' -NavLabel 'Snapshots'
Add-DhBarChart -Report $r -TableId 'vols'  -Field 'Tier'      `
               -NavPath 'Storage' -NavScope Subtree
```

### 7.6 — What migration buys you

Only reach for it when you want one of these; otherwise the old calls are fine:

- **Depth beyond 3 levels** — the old model topped out at group + subgroup.
- **An explicit node key decoupled from the label** (`-NavLabel`).
- **Deliberate sibling ordering** (`-NavOrder`).
- **Scope control** — a block pinned to one exact view (`Exact`), or a table
  visible across a subtree, neither of which the old parameters could express.
- **A literal `/` in a label**, via `//`.

## 8 — Errors and what they mean

| Message | Cause | Fix |
|---|---|---|
| `-NavPath cannot be combined with -NavGroup / -NavSubGroup` | Both styles on one call. A deliberate hard error — silent precedence is how 1.x ended up with three competing nav mechanisms. | Pick one style for that call. |
| `-NavSubGroup requires -NavGroup` | A subgroup with no parent has no place in the menu. | Add `-NavGroup`, or switch to `-NavPath`. |
| `Nav path 'X' contains an empty segment. Use '//' for a literal '/'.` | A trailing or leading `/`, or `//` used as a separator rather than an escape. | Fix the path; use `//` only to embed a literal `/`. |

## 9 — Nav gotchas

1. **Case-sensitive.** `'Identity'` is not `'identity'` — you get two tabs and
   half your content on each.
2. **Nav failures are silent.** No exception, no console message — just an empty
   panel. Always click through every node of a regenerated report.
3. **`Add-DhTabs` is not navigation.** Tabs partition content *within one
   block*; `-NavPath` partitions *the whole page*. Don't use tabs as page-level
   nav.
4. **Blocks in a subgroup were unreachable in 1.x** (gotcha #26) and start
   rendering in 2.0.0. If a dashboard was flattened to *dodge* that bug, the
   workaround is now unnecessary — content you forgot about may reappear.
5. **Topology and charts inside a hidden panel start at zero width.** The
   renderer auto-fits via `ResizeObserver` when the panel becomes visible; don't
   "fix" a chart that only looks wrong on the inactive tab.
6. **`Add-DhSummary` without nav parameters is a page-global singleton** at the
   top of `<main>`; with a path it becomes a per-panel strip. Both can coexist —
   one global strip plus many per-panel ones.
7. **Old bookmarked `#{group,panel}` URLs still resolve** via a shim in
   `URLState.load`. Don't break them casually.
8. **Ordering across types.** The exporter emits all blocks before all tables, so
   a shared monotonic declaration sequence keeps menu order equal to the order
   you wrote the calls. Use `-NavOrder` when you need something else.
