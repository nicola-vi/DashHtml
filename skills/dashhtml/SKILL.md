---
name: dashhtml
description: >-
  Nicola's in-house DashHtml PowerShell 7 module — the required renderer for any
  HTML report or dashboard. Use whenever a task involves building, editing or
  debugging a PowerShell reporting script that produces an HTML dashboard, or
  mentions DashHtml, New-DhDashboard, Add-DhTable, Add-DhSummary, any Add-Dh*
  cmdlet, Export-DhDashboard, -NavPath / -NavGroup navigation, or -AllowHtml.
  Also use when asked to produce an HTML report from PowerShell data (Active
  Directory, VMware, SQL Server, Azure, Parallels, NetApp, Commvault inventories
  and audits) — never hand-roll HTML/CSS/JS for these.
---

# DashHtml

DashHtml is Nicola Viganò's own PowerShell 7 module that turns PowerShell objects
into a **single self-contained interactive HTML file** — no server, no
external assets. Everything (CSS, JS, data) is embedded in one `.html`. The one
exception: by default the XLSX and PDF buttons load SheetJS / jsPDF from cdnjs
on first click. `Export-DhDashboard -ExportLibraries Embed` (2.2+) inlines them
for readers without internet; CSV needs nothing.

**It is _the_ output layer for reports in ProjectPS. Never hand-roll HTML, CSS or
JavaScript instead of it, and never substitute PSWriteHTML or another public
module.**

- **Repo / source of truth:** `<!--DH_REPO_PATH-->C:\Users\nicola.vigano\OneDrive - LUTECH SPA\Desktop\ProjectPS\DashHtml<!--/DH_REPO_PATH-->`
- **Installed to:** `Documents\PowerShell\Modules\DashHtml\` (under the current
  user's profile)
- **Module version this skill documents:** <!--DH_VERSION-->2.2.0<!--/DH_VERSION-->
- **Public cmdlets:** <!--DH_CMDLET_COUNT-->22<!--/DH_CMDLET_COUNT--> (<!--DH_NAVAWARE_COUNT-->17<!--/DH_NAVAWARE_COUNT--> of them nav-aware)

## The pipeline

Every dashboard is the same three steps, in this order:

```powershell
$report = New-DhDashboard -Title 'Infrastructure Report' -Theme 'Azure'
Add-DhTable -Report $report -TableId 'vms' -Title 'Virtual Machines' -Data $vms -NavPath 'Compute/vms'
Export-DhDashboard -Report $report -OutputPath 'C:\Reports\infra.html'
```

`New-DhDashboard` returns a hashtable that every `Add-Dh*` mutates in place via
`-Report`. `Export-DhDashboard` renders it.

## Non-negotiables

Check these on every script you write or review. Each one has cost real
debugging time.

1. **Declaration order.** Add a table **before** anything that references its
   `TableId` — `Set-DhTableLink`, `Add-DhBarChart`, `Add-DhPieChart` (Mode A),
   `Add-DhFilterCard`, `Add-DhRangeBar`, `Add-DhAlertBanner -Action`,
   `Add-DhStatusGrid` cell `LinkTableId`, summary tile `Action`, `Add-DhFindings`
   `AffectedTableId`. Out of order, several cmdlets **throw** once any other
   table exists; a reference to a table that never appears is **warned about
   by `Export-DhDashboard`** (2.1.4+). Never ignore export warnings.
2. **Guard every table against empty data.** `Add-DhTable -Data @()` warns and
   renders an empty table; older code paths threw. In ProjectPS scripts use
   `Add-DhTableIfData` from PsReport.Core (it skips empty tables, orders rows on
   the first field and returns `$true` when the table was added) — see
   `references/script-contract.md`. Elsewhere, gate the call on `.Count -gt 0`.
3. **Never audit DashHtml calls with grep.** These calls routinely span many
   lines with backtick continuation, so a line-oriented pattern silently
   under-reports. On `Examples/`, greps found 0 issues where the AST audit found
   13. Use `Tools\Test-DhV2Upgrade.ps1` or `Update-DhScript`.
4. **`Icon` must be an emoji** (`🖥` `⚠` `🔒` `🌐`) or unicode glyph. Bare ASCII
   letters render as broken single characters.
5. **`Add-DhHtmlBlock -Style` is `info|warn|danger|ok|nodata|neutral`.** There is
   no `warning` — that value only exists on `Add-DhAlertBanner -Severity`.
6. **`-AllowHtml` defaults to `$false` since 2.0.0** on the four raw-HTML sinks.
   Pass `-AllowHtml:$true` only for markup you wrote yourself; leave the default
   for anything externally sourced.
7. **Nav matching is case-sensitive.** `'Identity'` and `'identity'` are two
   different nodes.
8. **Use `-NavPath`, not `-NavGroup`/`-NavSubGroup`, in new code.** The old
   parameters still work forever via a compat shim, but mixing the two on one
   call is a **hard throw**.
9. **An `Id` is yours to generate; a `Label` is the data's.** Topology nodes,
   status-grid rows and element ids inside your own HTML come from a counter,
   never from a name — repeated names are normal in real inventories, and a
   duplicate topology id throws.
10. **Test with all datasets empty.** Lists built from data (`-Cards`, `-Items`,
    `-Nodes`) become `@()` and throw on binding; `$x = $rows | ForEach-Object`
    becomes `$null`. Both take the whole HTML section down, and only the empty
    run shows it. Details in `references/gotchas.md` §1.

## Navigation — read this before writing any multi-panel report

`-NavPath 'A/B/C'` + `-NavScope` is the current model and replaces
`-NavGroup`/`-NavSubGroup`. The one-line version:

| Intent | Declaration |
|---|---|
| A table that gets its own menu entry | `-NavPath 'Storage/vols' -NavLabel 'Volumes'` |
| A chart shown across a whole section | `-NavPath 'Storage' -NavScope Subtree` |
| A banner shown on every panel | omit all nav parameters (blocks default to Global) |

**Full guide, migration table and worked examples: `references/navigation.md`.**
Read it whenever a task touches nav, panels, tabs, menu structure, or upgrading
`-NavGroup` calls.

## Reference files — load what the task needs

| File | Read it when |
|---|---|
| `references/navigation.md` | Anything involving nav, panels, `-NavPath`, `-NavGroup` migration, menu layout, deep trees |
| `references/cheatsheet.md` | Choosing a widget, the `-Rag` shape, tile styles, cmdlet signatures |
| `references/gotchas.md` | Debugging odd behaviour, reviewing a script, or before declaring work done |
| `references/script-contract.md` | Writing or changing a report **script** in ProjectPS — skeleton, logging, backups, the audit gates |
| `references/migration-v2.md` | Upgrading a pre-2.0.0 script (`-AllowHtml` flip, table path model) |

## Deeper sources in the repo (when the references above are not enough)

1. `readme-dev.md` — the full developer/AI reference (cheat sheet, decision
   tree, 15 recipes, 26 gotchas, extension guide). This skill is distilled
   from it.
2. `Examples/` — `Demo-ActiveDirectory.ps1`, `Demo-VMware.ps1`,
   `Demo-Feature-NavMultiPanel.ps1`, `Demo-Feature-FullShowcase.ps1`,
   `Demo-Feature-TabsHeatmapTopology.ps1` show every feature with real data.
3. `DashHtml-Reference.html` — generated `Get-Help` output for all 21 cmdlets.
4. `Tests/DashHtml.Tests.ps1` — documents every supported parameter
   combination and validation rule.
5. `CHANGELOG.md` — why a behaviour is the way it is.

## When something looks wrong

Prefer the module's own tooling over guessing:

```powershell
.\Tools\Test-DhV2Upgrade.ps1 -Path 'C:\Scripts' -Detailed   # read-only AST audit
Update-DhScript -Path 'C:\Scripts' -PassThru                # DashHtml.Design; -Apply rewrites
```

Runtime JS is **baked into each generated HTML file**. Updating the module is not
enough — the dashboard must be **regenerated** to pick up a fix.
