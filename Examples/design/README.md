# DashHtml.Design — example

Demonstrates the declarative (YAML) workflow provided by the
[DashHtml.Design](../../DashHtml.Design/README.md) companion module.

## Files

- **`infra-layout.yaml`** — a hand-written dashboard layout (foundation, a global
  KPI summary, a table with inline data, a bar chart, a global filter).

## Try it

```powershell
Import-Module DashHtml
Import-Module DashHtml.Design

# YAML -> runnable build script -> HTML
ConvertFrom-DhYaml -Path .\infra-layout.yaml -OutFile .\build-infra.ps1 -OutputPath .\infra.html
.\build-infra.ps1
Invoke-Item .\infra.html
```

## The reverse direction

Snapshot any built report back to YAML — this is the **lossless** reverse, because
it serialises the object rather than parsing a script:

```powershell
$r = New-DhDashboard -Title 'Infra' -Theme Azure
Add-DhTable -Report $r -TableId 'srv' -Title 'Servers' -Data $servers
$r | ConvertTo-DhYaml -OutFile .\snapshot.yaml            # layout only
$r | ConvertTo-DhYaml -OutFile .\snapshot.yaml -IncludeData  # + row data
```

Or take a best-effort structural picture of an existing script (dynamic values are
flagged with `<expr: ...>` markers):

```powershell
ConvertFrom-DhScript -Path ..\Demo-VMware.ps1
```
