# DashHtml

A PowerShell 7 module for generating **interactive, self-contained HTML dashboards** from any structured data — sortable/filterable tables, KPI tiles, bar charts, collapsible sections, and clickable filter cards. The output is a single HTML file with all data and styles embedded — no external dependencies at viewing time.

---

## Features

- **Self-contained output** — one HTML file, no companion CSS or JS files
- **Sortable, filterable, pageable tables** — multi-column sort (Shift+Click), text filter, configurable page size
- **KPI summary tiles** — icons, formatted values, threshold colouring
- **Bar charts** — horizontal proportional bars, click-to-filter support
- **Clickable filter cards** — single or multi-select, instant table filtering
- **Collapsible sections** — key-value card grids or free-form HTML
- **Master-detail table linking** — clicking a row filters a child table
- **Two-tier navigation** — flat nav or grouped primary-tabs + subnav strip
- **Client-side export** — CSV (no CDN), XLSX and PDF (cdnjs, requires internet)
- **Light/dark theme toggle** — both variants embedded, switchable at runtime
- **Five theme families** — Default, Azure, VMware, Grey, Company
- **Column features** — progress bars, badges, threshold colouring, row highlighting, pinned first column, footer aggregates, number/currency/bytes/percent/datetime/duration formatting

---

## Requirements

- PowerShell 7.0 or later

---

## Installation

### From source

```powershell
# Clone the repository, then:
.\Install.ps1                    # CurrentUser scope (no admin required)
.\Install.ps1 -Scope AllUsers    # AllUsers scope (requires admin)
.\Install.ps1 -Force             # Overwrite an existing installation
```

### Manual

Copy the `DashHtml/` folder to a directory in `$env:PSModulePath`, under a versioned subfolder:
```
<modules-root>\DashHtml\1.1.0\
```

---

## Quick start

```powershell
Import-Module DashHtml

# 1. Create the dashboard object
$report = New-DhDashboard -Title 'Server Inventory' -Theme Default

# 2. Add data
$servers = @(
    [PSCustomObject]@{ Name='srv-001'; OS='Windows Server 2022'; CPU=42; Status='OK'   }
    [PSCustomObject]@{ Name='srv-002'; OS='Windows Server 2019'; CPU=78; Status='Warn' }
    [PSCustomObject]@{ Name='srv-003'; OS='Ubuntu 22.04';        CPU=15; Status='OK'   }
)
Add-DhTable -Report $report -TableId 'servers' -Title 'Servers' -Data $servers

# 3. Export
Export-DhDashboard -Report $report -OutputPath '.\dashboard.html' -Force -OpenInBrowser
```

---

## Cmdlet reference

| Cmdlet | Purpose |
|--------|---------|
| `New-DhDashboard` | Create the root dashboard object |
| `Add-DhTable` | Add a sortable/filterable data table |
| `Add-DhSummary` | Add KPI metric tiles |
| `Add-DhBarChart` | Add a horizontal bar chart |
| `Add-DhFilterCard` | Add a clickable card filter grid |
| `Add-DhHtmlBlock` | Add a free-form HTML block |
| `Add-DhCollapsible` | Add a collapsible card/content section |
| `Set-DhTableLink` | Link a master table to a detail table |
| `Export-DhDashboard` | Write the self-contained HTML file |
| `Get-DhTheme` | List or inspect built-in theme families |

Use `Get-Help <cmdlet> -Full` for complete parameter documentation.

---

## Themes

Five built-in families — each includes a light and a dark variant, both always embedded in the output HTML. The toggle button in the nav bar switches at runtime.

| Family | Light | Dark | Font |
|--------|-------|------|------|
| `Default` | Light grey + blue | Near-black + cyan | System UI |
| `Azure` | Warm grey + Azure blue | Office dark + Azure | Segoe UI |
| `VMware` | White/navy + VMware green | Navy + VMware green | Inter |
| `Grey` | Warm grey + steel | Dark neutral + muted grey | System UI |
| `Company` | White + Crimson | Near-black + Crimson | Montserrat |

```powershell
# List all families
Get-DhTheme

# Inspect CSS for a specific family
$css = Get-DhTheme -Name Azure
$css.LightCss
$css.DarkCss

# Save CSS files to disk
Get-DhTheme -Name Company -SaveTo 'C:\Reports\css'
```

---

## Tables

### Basic table

```powershell
$data = @(
    [PSCustomObject]@{ Name='alpha'; Region='us-east';  Count=10; Status='Active'   }
    [PSCustomObject]@{ Name='beta';  Region='eu-west';  Count=5;  Status='Inactive' }
    [PSCustomObject]@{ Name='gamma'; Region='ap-south'; Count=22; Status='Active'   }
)

Add-DhTable -Report $report -TableId 'items' -Title 'Item List' -Data $data
```

### Custom columns

```powershell
$cols = @(
    @{ Field='Name';   Label='Item Name'; Width='180px'; PinFirst=$true }
    @{ Field='Region'; Label='Region';    Width='120px' }
    @{ Field='Count';  Label='Count';     Align='right'; Aggregate='sum' }
    @{ Field='Status'; Label='Status';
       Thresholds=@(
           @{ Value='Active';   Class='cell-ok'     }
           @{ Value='Inactive'; Class='cell-warn'   }
           @{ Value='Error';    Class='cell-danger' }
       )
       RowHighlight=$true
    }
)

Add-DhTable -Report $report -TableId 'items' -Title 'Items' -Data $data -Columns $cols -PageSize 25
```

### Column formatting

```powershell
$cols = @(
    @{ Field='Name';     Label='Name' }
    @{ Field='Cost';     Label='Cost';    Format='currency'; Locale='en-US'; Currency='USD'; Decimals=2 }
    @{ Field='Size';     Label='Size';    Format='bytes'   }
    @{ Field='Uptime';   Label='Uptime';  Format='percent'; Decimals=1 }
    @{ Field='Duration'; Label='Runtime'; Format='duration' }
    @{ Field='Updated';  Label='Updated'; Format='datetime'; DatePattern='yyyy-MM-dd' }
)
```

---

## KPI summary tiles

```powershell
Add-DhSummary -Report $report -Items @(
    @{ Label='Total';    Value=247; Icon='X' }
    @{ Label='Active';   Value=231; Icon='Y'; Class='cell-ok'   }
    @{ Label='Warnings'; Value=12;  Icon='W'; Class='cell-warn' }
    @{ Label='Critical'; Value=4;   Icon='E'; Class='cell-danger' }
    @{ Label='Storage';  Value=1610612736; Format='bytes' }
)
```

---

## Bar charts

```powershell
# Basic distribution chart
Add-DhBarChart -Report $report -Id 'status-chart' `
    -Title 'Items by Status' `
    -TableId 'items' -Field 'Status' -TopN 10 `
    -ShowCount $true -ShowPercent $true

# Click a bar to filter the source table
Add-DhBarChart -Report $report -Id 'region-chart' `
    -Title 'Items by Region' `
    -TableId 'items' -Field 'Region' -ClickFilters
```

---

## Filter cards

```powershell
$regionCards = $data | Group-Object Region | ForEach-Object {
    @{ Label=$_.Name; Value=$_.Name; Count=$_.Count }
}

Add-DhFilterCard -Report $report -Id 'region-filter' `
    -Title 'Filter by Region' `
    -TargetTableId 'items' -FilterField 'Region' `
    -Cards $regionCards

# Multi-select (multiple cards active at once)
Add-DhFilterCard -Report $report -Id 'status-filter' `
    -Title 'Filter by Status' `
    -TargetTableId 'items' -FilterField 'Status' `
    -MultiFilter $true `
    -Cards @(
        @{ Label='Active';   Value='Active';   Count=231 }
        @{ Label='Inactive'; Value='Inactive'; Count=12  }
        @{ Label='Error';    Value='Error';    Count=4   }
    )
```

---

## Linking tables

```powershell
# Master → Detail: click a parent row to filter the child table
Add-DhTable -Report $report -TableId 'groups'  -Title 'Groups' -Data $groups
Add-DhTable -Report $report -TableId 'members' -Title 'Members' -Data $members
Set-DhTableLink -Report $report -MasterTableId 'groups' -DetailTableId 'members' `
                -MasterField 'GroupId' -DetailField 'GroupId'

# Three-level chain: A → B → C
Set-DhTableLink -Report $report -MasterTableId 'categories' -DetailTableId 'groups' `
                -MasterField 'Category' -DetailField 'Category'
Set-DhTableLink -Report $report -MasterTableId 'groups' -DetailTableId 'items' `
                -MasterField 'GroupId' -DetailField 'GroupId'
```

---

## Two-tier navigation

Use `-NavGroup` on **any** cmdlet (`Add-DhTable`, `Add-DhFilterCard`, `Add-DhBarChart`, `Add-DhHtmlBlock`, `Add-DhCollapsible`) to create a grouped navigation with a primary tab bar and a sub-nav strip:

```powershell
$report = New-DhDashboard -Title 'Operations Dashboard'

# Filter card and bar chart placed at the top of the Identity group
Add-DhFilterCard -Report $report -Id 'status-fc' -NavGroup 'Identity' `
    -Title 'Filter by Status' -TargetTableId 'users' -FilterField 'Status' `
    -Cards @( @{Label='Active'; Value='Active'}, @{Label='Disabled'; Value='Disabled'} )

Add-DhTable -Report $report -TableId 'users'   -Title 'Users'   -Data $users   -NavGroup 'Identity'
Add-DhTable -Report $report -TableId 'groups'  -Title 'Groups'  -Data $groups  -NavGroup 'Identity'
Add-DhTable -Report $report -TableId 'servers' -Title 'Servers' -Data $servers -NavGroup 'Infrastructure'
Add-DhTable -Report $report -TableId 'disks'   -Title 'Disks'   -Data $disks   -NavGroup 'Infrastructure'

Export-DhDashboard -Report $report -OutputPath '.\ops.html' -Force
```

Result: primary nav shows **Identity** and **Infrastructure** group tabs. Clicking a group tab shows the subnav for that group. Blocks with a matching `-NavGroup` appear as persistent content above the sub-nav panel (e.g. filter cards remain visible while switching between tables in the same group). Groups composed entirely of blocks (no tables) are supported — the subnav strip is hidden automatically for those groups.

---

## Collapsible sections

```powershell
Add-DhCollapsible -Report $report -Id 'accounts' -Title 'Accounts' -DefaultOpen $true `
    -Cards @(
        @{
            Title      = 'Production'
            Badge      = 'Active'
            BadgeClass = 'cell-ok'
            Fields     = @(
                @{ Label='Account ID'; Value='acc-001' }
                @{ Label='Region';     Value='us-east-1' }
            )
        }
    )
```

---

## HTML blocks

```powershell
Add-DhHtmlBlock -Report $report -Id 'intro' -Title 'Overview' -Style 'info' -Content @"
<p>This dashboard is generated automatically. Data is refreshed daily.</p>
<ul>
  <li><strong>Section A</strong> — identity and access</li>
  <li><strong>Section B</strong> — infrastructure inventory</li>
</ul>
"@
```

---

## Logo and header fields

```powershell
$report = New-DhDashboard -Title 'Infrastructure Dashboard' `
    -Subtitle 'Environment: Production' `
    -LogoPath 'C:\img\logo.png' `
    -Theme Company `
    -NavTitle 'Infra' `
    -InfoFields @(
        @{ Label='Environment'; Value='Production' }
        @{ Label='Region';      Value='us-east-1'  }
        @{ Label='Generated';   Value=(Get-Date -Format 'yyyy-MM-dd') }
    )
```

---

## Building and testing

```powershell
# Run tests
Invoke-Pester .\Tests -Output Detailed

# Build (validate + test + stage dist/ + zip)
.\Build.ps1

# Build and bump patch version
.\Build.ps1 -BumpVersion

# Build without running tests
.\Build.ps1 -SkipTests
```

---

## Project structure

```
DashHtml/
  DashHtml.psd1          Module manifest
  DashHtml.psm1          Module loader
  Public/
    New-DhDashboard.ps1
    Add-DhTable.ps1
    Add-DhSummary.ps1
    Add-DhBarChart.ps1
    Add-DhFilterCard.ps1
    Add-DhHtmlBlock.ps1
    Add-DhCollapsible.ps1
    Set-DhTableLink.ps1
    Export-DhDashboard.ps1
    Get-DhTheme.ps1
  Private/
    Get-DhJsContent.ps1
    Get-DhCssBase.ps1
    Get-DhThemeCss.ps1
    Get-DhCssDefaultLight.ps1
    Get-DhCssDefaultDark.ps1
    Get-DhCssAzureLight.ps1
    Get-DhCssAzureDark.ps1
    Get-DhCssVMwareLight.ps1
    Get-DhCssVMwareDark.ps1
    Get-DhCssGreyLight.ps1
    Get-DhCssGreyDark.ps1
    Get-DhCssCompanyLight.ps1
    Get-DhCssCompanyDark.ps1
    Build-DhTableSections.ps1
    ConvertTo-DhJsonString.ps1
Tests/
  DashHtml.Tests.ps1
Build.ps1
Install.ps1
CHANGELOG.md
README.md
```

---

## License

MIT
