# Examples

Every script runs from a clone of the repo, loads the local module, and writes one HTML file next to itself. All take `-OutputPath`, `-Theme` and `-OpenInBrowser`. All data is synthetic and deterministic.

```powershell
.\Examples\Demo-ActiveDirectory.ps1 -OpenInBrowser
.\Examples\Feature-Tables.ps1 -Theme Azure
```

## Realistic reports

Each is a menu of views that each answer one question. Read the header of the script for the menu and for what is global and what is not.

| Script | What it shows |
|---|---|
| `Demo-ActiveDirectory.ps1` | Forest health: replication matrix and topology, domain controllers, privileged accounts, OU tree, directory explorer (members and nesting), findings, events |
| `Demo-VMware.ps1` | Two vSphere clusters with a global cluster filter: hosts, VMs, datastores, snapshots, host connectivity map, alarms |
| `Demo-AzureInfrastructure.ps1` | Three subscriptions with a global subscription filter: cost, compute, hub-and-spoke network, storage, Defender findings, policy compliance, tags |
| `Demo-Microsoft365.ps1` | One tenant with a global department filter: licensing, Exchange, Teams and SharePoint, MFA and Conditional Access, service health, adoption |

## One feature at a time

Each view starts with a short note saying what you are looking at.

| Script | What it shows |
|---|---|
| `Feature-Navigation.ps1` | Paths, scopes, labels, order; global, branch and view elements; banners that follow the menu; linked tables |
| `Feature-NavigationSidebar.ps1` | A four-level menu with the sidebar and breadcrumb (`-Layout Strips` to compare) |
| `Feature-Tables.ps1` | Cell types and formats, colour rules, chips and paths, detail panel, linked tables, tree filter, column widths, column picker, changes since the last run, 50,000 rows |
| `Feature-Charts.ps1` | Bars (count, measured value, stacked, coloured), pies, lines, bullets, ranges |
| `Feature-KpiTiles.ps1` | Every tile style, trends, clickable tiles, global / branch / view strips |
| `Feature-Assessment.ps1` | Verdict, score ring, maturity ladder, findings (list and split), property tiles, record list |
| `Feature-MapsAndGrids.ps1` | Status grid, heatmaps, tree, network map (grouped and in tiers, with path tracing) |
| `Feature-FiltersAndSearch.ps1` | Global filters, filter cards, click-to-filter, report search, menu badges |
| `Feature-PageElements.ps1` | Header, banners, text blocks, collapsibles, tabs, events, 12-column grid, print cover |

## How to read a menu (the rules every example follows)

- **A table or block belongs to a path** (`-NavPath 'Compute/Hosts'`). The menu is built from the paths. Give every table a path; without one it gets a menu entry named after its TableId.
- **Scope** says how far it reaches: exact (that view), `-NavScope Subtree` (that node and everything below), `Global` (everywhere). An item with no path is global.
- **Order on a view is fixed:** banners, global filters, global KPI tiles, blocks in declaration order, tables in declaration order. A table is always last, so a chart that reads a table is declared after it but drawn above it.
- **Name a group** by putting `-NavLabel` on an item at the group's own path (the branch KPI strip does that). `-NavLabel` on a leaf renames the leaf.
- **`-NavOrder`** orders an item's own node among its siblings; the first declaration decides the opening view.
- **Tables joined with `Set-DhTableLink`, and charts, cards or trees that filter a table, belong on the same view as that table.**

## Check a menu

```powershell
.\Tools\Show-DhNavMap.ps1 -Path .\Examples\Demo-VMware.html
```

prints the menu, the view it opens on, and what each view contains in page order, and warns about sections with no path (they appear on every view) and views that show nothing. The test suite runs it on every example.

`design\` holds the YAML layout example for `DashHtml.Design`.
