# House rules for ProjectPS report scripts

These are Nicola's standing conventions for the PowerShell scripts that *drive*
DashHtml. They are not derivable from the module source — they come from
repeated feedback across the AD, VMware, SQL Server, Azure and Parallels
projects. Follow them unless the user says otherwise in the current task.

## 1 — Start from the skeleton, never from scratch

**Canonical skeleton:**
`<!--DH_SKELETON_PATH-->C:\Users\nicola.vigano\OneDrive - LUTECH SPA\Desktop\ProjectPS\Documentation\Invoke-ProcedureName.ps1<!--/DH_SKELETON_PATH-->`

**Shared chassis it loads (PsReport.Core <!--DH_CORE_VERSION-->3.1.0<!--/DH_CORE_VERSION-->):**
`<!--DH_CORE_PATH-->C:\Users\nicola.vigano\OneDrive - LUTECH SPA\Desktop\ProjectPS\Documentation\_Common\PsReport.Core.ps1<!--/DH_CORE_PATH-->`

**Build contract:** `ProjectPS\Documentation\readme-dev.md` — **read it before
opening any script in that folder.** The script chassis (parameters, logging,
exports, exit codes, releases) is owned by the **`ps-report-script`** skill; this
file only covers what touches DashHtml.

Every report script in `ProjectPS/Documentation/` starts as a copy of the
skeleton, placed in a product folder (`<Product>\Invoke-<Procedure>.ps1`), and
dot-sources `..\_Common\PsReport.Core.ps1` through the skeleton's loader region.
**The helpers below live in the core, not in the script** — never paste a copy
into a script (the checker flags it as `CORE002`); change the core instead.

- `Write-Log` with levels `INFO` / `SUCCESS` / `WARN` / `ERROR` / `DEBUG` /
  `SECTION` / `TIMING`.
- `Invoke-SafeSection` — per-section try/catch plus stopwatch. Sets
  `$script:ExitCode = 1` and **continues** rather than aborting the run.
  `$ErrorActionPreference = 'Stop'` is set *inside* it, so a cmdlet that only
  *writes* an error also fails the section.
- Startup: `Import-PsReportDashHtml` (**DashHtml ≥ 2.0.0 or exit `2`**),
  `Resolve-PsReportOutputPath`, `Initialize-PsReportRun`,
  `Write-PsReportParameterLog` (credentials masked).
- Exports and the end-of-run banner: `Export-PsReportExcel`, `Export-PsReportCsv`,
  `Export-PsReportPdf`, `Write-PsReportSummary`.
- The DashHtml guard helpers below, and `Join-DhNavPath`.

The script itself keeps `Set-StrictMode -Version Latest`, the `$script:` state
block with an **ordered** `$script:Stats`, `-NavPath` navigation throughout, and
exit codes `0` clean / `1` a section failed / `2` a startup precondition failed.

### The guard helpers — use these instead of hand-rolling the checks

The core ships small functions that enforce the two DashHtml rules that fail
silently (empty data, and declaration order). **Use them; don't re-implement the
checks inline.**

```powershell
Get-DataCount $maybeNull          # [int] - null-safe; 0 for $null, @() wrapped
Test-DhTableRegistered -Report $r -TableId 'vms'   # [bool] - is it actually declared?
Add-DhTableIfData @{ Report=$r; TableId='vms'; Title='VMs'; Data=$vms }   # [bool]
Join-DhNavPath $group $subGroup 'vms'              # 'Group/Sub/vms' - -NavPath from variables
```

**`Add-DhTableIfData` is the main one.** It adds the table only when it has
rows (a skipped table is logged as a `WARN`), **orders the rows on the first
field**, and **returns `$true` when the table was added** — gate every dependent
widget on that value:

```powershell
$hasVms = Add-DhTableIfData @{ Report=$r; TableId='vms'; Title='VMs'; Data=$vms
                               NavPath='Compute/vms'; NavLabel='Virtual machines' }
if ($hasVms) {
    Add-DhBarChart -Report $r -Id 'byCluster' -Title 'By cluster' -TableId 'vms' -Field 'Cluster'
}
```

Design points worth knowing:

- It takes a **splat hashtable**, not mirrored parameters, so it never goes
  stale when DashHtml adds a parameter. Pass any `Add-DhTable` argument through
  the hashtable, including the nav ones. Switches become `$true` values
  (`MultiSelect = $true`).
- It **throws** if the splat is missing `Report`, `TableId`, `Title` or `Data`.
- **House rule: every table is ordered on its first field**, ascending — the
  first entry of `Columns` if given, else the first property of the first row
  (stable sort). Do not pre-sort expecting another order to survive: if a table
  must read in another order, make that field the first column.
- It **re-wraps the data in an array**. A single `[PSCustomObject]` is not an
  `[object[]]`, so PowerShell binds it as a scalar and `Add-DhTable` then
  enumerates its *properties* as rows. See `gotchas.md`.
- Assign the result even when nothing depends on it — `$null = Add-DhTableIfData @{...}` —
  otherwise the `True` it returns is written to the output stream.

`Test-DhTableRegistered` is the escape hatch when a widget's dependency was
added somewhere you can't see the return value — it queries `$Report.Tables`
directly. Note it types `$Report` as an `OrderedDictionary`, which is what
`New-DhDashboard` returns.

A product wrapper around the table call is fine (a nav convention, a label
rule) as long as it **delegates to `Add-DhTableIfData`** and returns its value;
a wrapper that calls `Add-DhTable` itself loses the ordering rule (`DASH010`).

### Other house conventions

- **`-Theme` default:** `Grey`; scripts for VMware products use `VMware`, Azure
  ones `Azure`.
- **`-WhatIf`:** either no `SupportsShouldProcess` at all, or honour it with **one**
  decision made before anything is written —
  `$doWrite = $PSCmdlet.ShouldProcess($OutputPath, 'Generate ...')` — and gate
  the output folder, the log file, the HTML section and every export on it.
  A half-honoured `-WhatIf` is worse than none: `Export-DhDashboard` honours
  `-WhatIf` by itself, but the log file, the workbook and the CSVs do not.
- `utf8BOM` encoding everywhere, and **comments in English**.

> Do **not** use `SyncALwaysONUsers\Sync-AgLogins.ps1` as a reference — Nicola
> asked that it be ignored, and its comments are in Italian, unlike the skeleton.

The skeleton exercises every DashHtml widget, so it doubles as a live API
reference.
## 2 — Back up before you edit. Always.

**Before changing any script, take a timestamped copy.** Two conventions are in
use; match whichever the project already uses:

```powershell
# sidecar file
Copy-Item .\Invoke-ADDashboard.ps1 ".\Invoke-ADDashboard.ps1.$(Get-Date -f 'yyyyMMdd-HHmm').bak"

# per-round backup directory (preferred where a Backups\ or backup\ folder exists)
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
New-Item -ItemType Directory -Force "backup\$stamp" | Out-Null
Copy-Item *.ps1, README.md, tests -Destination "backup\$stamp" -Recurse
```

One backup **per edit round**, not per file. Mention the backup path when
reporting what changed.

**Why:** these scripts run against production Active Directory, live vCenters and
customer SQL estates. Several of these folders are not version-controlled, so the
backup is the only rollback. A silent regression is expensive to trace.

## 3 — Propose, then apply

Do not apply edits unprompted, even obvious-looking ones. The expected sequence:

**review → present numbered findings grouped by severity → ask which to apply →
back up → edit.**

## 4 — Two gates before any script is "done"

All must return **zero findings** (the first one is the house contract, see the
`ps-report-script` skill):

```powershell
& 'C:\...\ProjectPS\Documentation\.claude\skills\ps-report-script\scripts\Test-PsReportCompliance.ps1' -Path .\Invoke-Something.ps1
Invoke-ScriptAnalyzer -Path .\Invoke-Something.ps1 -Settings .\PSScriptAnalyzerSettings.psd1
& 'C:\...\ProjectPS\DashHtml\Tools\Test-DhV2Upgrade.ps1' -Path .\Invoke-Something.ps1 -Detailed
```

**Never audit DashHtml calls with `grep`** — they span lines with backtick
continuation, so line-oriented patterns silently under-report. Both tools parse
the AST and never execute the script.

## 5 — Three runs before you call it working

A happy-path run proves almost nothing. Run all three:

1. **Happy path** — real data in every section.
2. **All datasets empty** — the previous skeleton passed its happy path and
   broke here.
3. **One section throwing** — confirm `Invoke-SafeSection` catches it, sets
   `$script:ExitCode = 1`, and the rest of the report still renders.

Run 2 is the one that finds bugs. In the 2026-09 migration it caught two
HTML sections that crashed on empty data (an empty `-Cards` list, a `$null`
pipeline result read with `.Count`) — both had been hidden for months behind an
exit code `0` and a summary line naming an HTML file that was never written.
No real system is needed for runs 2 and 3: put stub modules (same name,
version `99.0.0`, functions that return nothing or throw) first on
`$env:PSModulePath` for a child `pwsh`.

Then **open the generated HTML and click every nav node.** Nav and rendering bugs
fail silently — no console output, just an empty panel.

## 6 — Authoring host vs deployment host

Some collectors are authored in the OneDrive folder but **run somewhere else**
(e.g. the VMware stats collector runs from `C:\PowerCLI-Stats` on a separate
host, against its own vCenter). Where that is the case:

- Edits made in the repo do **not** reach the running deployment on their own —
  remind the user to copy the updated file across before re-running.
- Never assume a deployment path is testable locally. Validate with the offline
  test suite instead.
- Errors the user pastes come from a machine whose state cannot be inspected
  from the session.

## 7 — Data classification comes from the catalogue, not from you

Where a project maintains an external classification source (for example the SQL
Server permissions and roles catalogue), **join against it — never invent
category names or authorisation levels, and always report predefined roles under
their real names.** If the catalogue does not know a role, it is genuinely
custom: name it, don't guess.

## 8 — Quick checklist

- [ ] Copied from the skeleton into a product folder; loads PsReport.Core; comments in English
- [ ] Timestamped backup taken before editing
- [ ] Changes proposed and approved before applying
- [ ] Every table through `Add-DhTableIfData` (never `Add-DhTable` directly)
- [ ] Tables declared before anything referencing their `TableId`; dependents gated on the returned flag
- [ ] Widget / node `Id`s from counters, data only in `Label`; no empty list passed to `-Cards` / `-Items` / `-Nodes`
- [ ] `-NavPath` used, not `-NavGroup`; scope restated for blocks
- [ ] `-AllowHtml` chosen explicitly on the four raw-HTML sinks
- [ ] `Test-PsReportCompliance.ps1` clean (no Error)
- [ ] `Invoke-ScriptAnalyzer` clean
- [ ] `Test-DhV2Upgrade.ps1` clean
- [ ] Three runs: happy / all-empty / one section throwing
- [ ] Generated HTML opened, every nav node clicked
