# DashHtml.Design

**Design / round-trip companion tools for [DashHtml](../README.md).**

A small, self-contained module that lets you manage a dashboard's *layout* in a
declarative YAML/JSON file instead of (or alongside) PowerShell. It **changes
nothing** in the core DashHtml module — it is a pure transpiler you add only if
you want it.

```
              ConvertFrom-DhYaml
   YAML / JSON  ───────────────▶  runnable .ps1  ──(run)──▶  dashboard.html
        ▲                                │
        │  ConvertTo-DhYaml              │  ConvertFrom-DhScript
        │  (report object)               ▼
   report object  ◀──(New-DhDashboard + Add-Dh*)──  existing .ps1
```

| Cmdlet | Direction | Fidelity |
|--------|-----------|----------|
| `ConvertTo-DhYaml`   | report object → YAML | **lossless** — serialises the already-built object |
| `ConvertFrom-DhYaml` | YAML/JSON → runnable `.ps1` | **exact** — driven by live cmdlet metadata |
| `ConvertFrom-DhScript` | existing `.ps1` → YAML | **best-effort** — static parse, dynamic values flagged |

## Why

The core module is imperative: you *build* a report by calling `New-DhDashboard`
then a series of `Add-Dh*` cmdlets. That is great for scripting against live data,
but it means the *shape* of a dashboard is spread across a script. These tools give
you a second, declarative view of that shape:

- **Author a layout in YAML** and generate the PowerShell that builds it.
- **Snapshot a built report** to YAML to see its structure at a glance, diff two
  dashboards, or hand the layout to someone who doesn't write PowerShell.
- **Reverse-engineer an existing script** into an approximate YAML starting point.

## Install / load

```powershell
# the core module must be importable — the tools read its cmdlet metadata
Import-Module DashHtml
Import-Module DashHtml.Design
```

## Cmdlets

### `ConvertTo-DhYaml` — report object → YAML

Serialises the object returned by `New-DhDashboard` (and mutated by the `Add-Dh*`
cmdlets). Because it serialises the **already-built object**, loops, computed
values and dynamic data are all captured faithfully — no PowerShell parsing is
involved. This is the reliable reverse direction.

```powershell
$r = New-DhDashboard -Title 'Infra' -Theme Azure
Add-DhTable    -Report $r -TableId 'srv' -Title 'Servers' -Data $servers
Add-DhBarChart -Report $r -Id 'byEnv' -TableId 'srv' -Field 'Env' -Title 'By environment'

$r | ConvertTo-DhYaml -OutFile infra-layout.yaml
```

By default each table's rows are summarised as a `dataRows: <count>` line, keeping
the output a **layout** view rather than a data dump. Add `-IncludeData` to embed
the rows (useful for a fully self-contained, runnable round-trip).

| Parameter | Purpose |
|-----------|---------|
| `-Report` | the dashboard object (accepts pipeline input) |
| `-OutFile` | write YAML to a file; omitted → returns the YAML string |
| `-IncludeData` | embed table rows instead of a `dataRows` count |

### `ConvertFrom-DhYaml` — YAML/JSON → runnable `.ps1`

Reads a layout file (the schema `ConvertTo-DhYaml` emits, or hand-written) and
generates a PowerShell build script — `New-DhDashboard`, the `Add-Dh*` calls in
**dependency-correct order** (tables before the charts that reference them), and
`Export-DhDashboard`.

```powershell
ConvertFrom-DhYaml -Path infra-layout.yaml -OutFile build-infra.ps1 -OutputPath .\infra.html
.\build-infra.ps1        # run it to produce infra.html
```

Every emitted parameter is validated against **live cmdlet metadata**
(`Get-Command`), so only real parameters are written and switch-vs-bool is handled
correctly. Keys that are not parameters (e.g. a `dataRows` count) are skipped, and
unknown block types are emitted as a `# (skipped)` comment rather than breaking the
script. Because it reads metadata, this cmdlet stays correct as the core module's
parameters evolve — there is no hand-maintained schema to fall out of date.

**Table data** is resolved in this order:

| YAML key | Generated |
|----------|-----------|
| `dataFile: servers.csv` | `-Data (Import-Csv 'servers.csv')` |
| `data: [ {...}, {...} ]` | `-Data @( @{...}, @{...} )` (inline) |
| *(neither)* | `-Data @()  # TODO: supply data` |

| Parameter | Purpose |
|-----------|---------|
| `-Path` | the `.yaml` / `.yml` / `.json` layout file |
| `-OutFile` | write the `.ps1`; omitted → returns the script text |
| `-OutputPath` | the `-OutputPath` baked into the generated `Export-DhDashboard` |

> The generated script starts with `Import-Module DashHtml`. When you run it, make
> sure the DashHtml version you intend is the one resolved on `$env:PSModulePath`.

### `ConvertFrom-DhScript` — existing `.ps1` → YAML

A **best-effort** static reverse: it parses a script with the PowerShell AST (it
does **not** execute it) and pulls out the `New-DhDashboard` / `Add-Dh*` calls.
Literal argument values are extracted directly; any value the parse can't resolve
statically (a variable, an expression, a subexpression) is written as an
`<expr: ...>` marker so you can see exactly what needs a live value.

```powershell
ConvertFrom-DhScript -Path .\Examples\Demo-VMware.ps1
```

Use it to get a quick structural picture or a YAML starting point. For a
**faithful** layout of a script that builds its report from live data, run the
script and pipe the report object to `ConvertTo-DhYaml` instead.

| Parameter | Purpose |
|-----------|---------|
| `-Path` | the `.ps1` script to analyse |
| `-OutFile` | write YAML to a file; omitted → returns the YAML string |

### `Test-DhReport` — one command for every check (2.6.0)

```powershell
$report | Test-DhReport                       # links, menu lint, size estimate, baseline sanity
Test-DhReport -Path .\build.ps1               # the Update-DhScript audit (parsed, never run)
Test-DhReport -Path .\layout.yaml             # the schema, naming the failing table / block and key
Test-DhReport -Path .\out\*.html -Strict      # built with an older DashHtml? lists the missed fixes; $LASTEXITCODE 1
Test-DhReport -Path .\out\ad.html -Deep       # also Tools\Test-DhA11y and Test-DhContrast (checkout + Edge/Chrome)
```

It never throws on a finding and never changes a file. `-PassThru` returns objects with `Check`, `Severity`
(`error`, `ACTION`, `warning`, `advisory`, `info`), `Target` and `Message`; without it a short summary is printed.
`-Strict` sets `$LASTEXITCODE` to 1 when there is an error, an ACTION or a warning. `-SizeBudgetMB` (default 15) is the
size above which a report is reported.
## The layout schema

A layout document is a mapping with these top-level keys (all optional except
`title`):

```yaml
title: Infrastructure                 # New-DhDashboard -Title
subtitle: Production estate            # -Subtitle
theme: Azure                          # -Theme (theme family name)
navTitle: Infra                       # -NavTitle
autoRefresh: 300                      # seconds (int) or a string like '5m'
generatedBy: ops-team

infoFields:                           # header key/value chips
  - { label: Owner, value: SRE }

summary:                              # global KPI strip (Add-DhSummary)
  items:
    - { Label: Hosts, Value: 128 }
    - { Label: Alerts, Value: 3 }

tables:                               # Add-DhTable — declared before blocks
  - id: srv                           # → -TableId
    title: Servers
    gridSpan: 8
    dataFile: .\data\servers.csv      # or `data:` inline, or omit for a TODO
    columns:
      - { Field: Name, Label: Host }
      - { Field: Env,  Label: Environment }

blocks:                               # every Add-Dh* widget; `type` picks the cmdlet
  - type: barchart                    # → Add-DhBarChart
    id: byEnv
    tableId: srv
    field: Env
    title: By environment
    showPercent: true

globalFilters:                        # Add-DhGlobalFilter
  - { field: Env, label: Environment, type: facet }

alertBanners:                         # Add-DhAlertBanner
  - { message: Maintenance window Sat 02:00, severity: warning }

links:                                # Set-DhTableLink
  - { fromTable: srv, toTable: vms, onField: Name }
```

`type` values map to cmdlets as follows:

| `type` | cmdlet |
|--------|--------|
| `summary`, `summarystrip` | `Add-DhSummary` |
| `html` | `Add-DhHtmlBlock` |
| `collapsible` | `Add-DhCollapsible` |
| `filtercardgrid` | `Add-DhFilterCard` |
| `barchart` | `Add-DhBarChart` |
| `piechart` | `Add-DhPieChart` |
| `bullet` | `Add-DhBullet` |
| `linechart` | `Add-DhLineChart` |
| `eventfeed` | `Add-DhEventFeed` |
| `statusgrid` | `Add-DhStatusGrid` |
| `tabs` | `Add-DhTabs` |
| `heatmap` | `Add-DhHeatmap` |
| `topologymap` | `Add-DhTopologyMap` |

Keys are matched to cmdlet parameters **case-insensitively**, so `tableId`,
`TableId` and `tableid` all bind to `-TableId`.

## Notes & caveats

- **JSON is accepted anywhere YAML is.** A document that starts with `{` or `[`
  is parsed via the native JSON reader (JSON is a subset of the supported YAML).
- **No external dependency.** The module ships its own compact YAML reader/writer
  (a block-style subset: block mappings, block sequences, flow sequences of
  scalars, typed scalars, comments). It does **not** require `powershell-yaml`.
- **`ConvertFrom-DhScript` is best-effort by design.** A static parse cannot know
  the value of a variable or the result of an expression; those become
  `<expr: ...>` markers. It is a starting point, not a guaranteed round-trip. The
  guaranteed reverse is *run the script → `ConvertTo-DhYaml`*.
- **Numbers are locale-safe.** Decimals are always emitted with a `.` (invariant
  culture), so a layout authored on an `it-IT` host reads correctly everywhere.

## Requirements

- PowerShell 7.0+
- The core **DashHtml** module importable (its cmdlet metadata drives the codegen).

MIT License — see [LICENSE](../LICENSE).
