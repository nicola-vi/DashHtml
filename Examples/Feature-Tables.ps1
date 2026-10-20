#Requires -Version 7.0
<#
.SYNOPSIS
    Everything a table can do: cell types, formatting, colour rules, detail panel, links, big data.

.DESCRIPTION
    MENU
        Cells
            Types and formats        text, number, currency, bytes, percent, date, duration
            Colour rules             progress bars, badges, thresholds, whole-row highlight
            Lists and trends         chips, path, sparkline, link cells
        Interaction
            Detail panel             click a row to read all its properties
            Linked tables            click a row, the table below follows
            Selection and totals     multi-select, pinned column, footer totals
            Tree filter              click an OU, the table shows only that OU and below
        Layout
            Column widths            columns fit their text; widths, minimums, a fixed look
            Column picker            hidden by default, remembered per reader
    Since the last run       New / Changed / Removed rows against last run's data
            Large table              50,000 rows, drawn as you scroll
            Nothing found            an empty table that says the check passed

    Every view holds one table and, where it helps, a chart that reads it. The table is always
    the last element on its view. Wide tables scroll sideways inside their frame.

.PARAMETER OutputPath
    Where to write the HTML.

.PARAMETER Theme
    Default, Azure, VMware, Grey, Company or Rag.

.PARAMETER OpenInBrowser
    Open the dashboard once generated.

.EXAMPLE
    PS> ./Examples/Feature-Tables.ps1 -OpenInBrowser
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Feature-Tables.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Default',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force

$rng = [System.Random]::new(5)
$note = { param([string] $Id, [string] $Path, [string] $Text) Add-DhHtmlBlock -Report $report -Id $Id -Title 'In this view' -Style info -NavPath $Path -Content $Text }
$utilRag = @{ Green = @{ Max = 70 }; Amber = @{ Min = 70; Max = 90 }; Red = @{ Min = 90 }; NoData = $true }

$servers = foreach ($i in 1..24) {
    [pscustomobject]@{
        Name = 'srv-{0:000}' -f $i; Site = @('Milan', 'Turin', 'Rome')[$i % 3]
        Os = @('Windows Server 2022', 'Windows Server 2019', 'Ubuntu 22.04', 'RHEL 9')[$i % 4]
        CpuPct = 5 + $rng.Next(0, 92); MemPct = 20 + $rng.Next(0, 78)
        DiskBytes = [long](50GB + $rng.Next(0, 900) * 1GB); Uptime = [int]($rng.Next(1, 400) * 3600 * 24)
        Cost = [math]::Round(40 + $rng.NextDouble() * 900, 2); Change = [math]::Round(($rng.NextDouble() - 0.4) * 0.3, 3)
        Boot = (Get-Date '2026-10-17').AddDays(-1 * $rng.Next(1, 300)).ToString('yyyy-MM-ddTHH:mm:ss')
        Status = @('OK', 'OK', 'OK', 'Warning', 'Critical')[$i % 5]
        Roles = @(@('web'), @('db'), @('app', 'cache'), @('dc', 'dns', 'gc'))[$i % 4]
        Trend = @(1..8 | ForEach-Object { 20 + $rng.Next(0, 70) })
        Doc = 'https://learn.microsoft.com/windows-server/'
        Path = @(@('srv-{0:000}' -f $i, 'Server Admins', 'Tier 0'), @('srv-{0:000}' -f $i, 'Tier 1'))[$i % 2]
    }
}

$report = New-DhDashboard -Title 'Tables' -Subtitle 'Cell types, colour rules, detail panel, links and big data' -Theme $Theme -NavTitle 'Tables' -NavMaxDepth 2 -GeneratedBy 'Feature-Tables.ps1'

# ============================================================== CELLS
& $note 'n-types' 'Cells/Types and formats' 'Column Format controls how a value is shown (the data stays raw, so sorting and export stay correct): number, currency, bytes, percent, datetime, duration. Align right for numbers. PinFirst keeps the first column in view while you scroll sideways.'
Add-DhTable -Report $report -TableId 'types' -Title 'Servers' -NavPath 'Cells/Types and formats' -Data $servers -PageSize 8 -Columns @(
    @{ Field = 'Name'; Label = 'Server'; PinFirst = $true; Bold = $true }
    @{ Field = 'Site'; Label = 'Site' }
    @{ Field = 'DiskBytes'; Label = 'Disk'; Format = 'bytes'; Align = 'right' }
    @{ Field = 'Uptime'; Label = 'Uptime'; Format = 'duration'; Align = 'right' }
    @{ Field = 'Cost'; Label = 'Monthly cost'; Format = 'currency'; Currency = 'EUR'; Locale = 'en-IE'; Decimals = 0; Align = 'right' }
    @{ Field = 'Change'; Label = 'Change'; Format = 'percent'; Decimals = 1; Align = 'right' }
    @{ Field = 'Boot'; Label = 'Last boot'; Format = 'datetime'; DatePattern = 'yyyy-MM-dd HH:mm' } )

& $note 'n-colour' 'Cells/Colour rules' 'Rag colours a number by bands; CellType progressbar draws it; badge colours a word with Thresholds; RowHighlight on a column paints the whole row.'
Add-DhTable -Report $report -TableId 'colour' -Title 'Servers' -NavPath 'Cells/Colour rules' -NavLabel 'Colour rules' -Data $servers -PageSize 8 -Columns @(
    @{ Field = 'Name'; Label = 'Server'; PinFirst = $true }
    @{ Field = 'CpuPct'; Label = 'CPU %'; Align = 'right'; CellType = 'progressbar'; ProgressMax = 100; Rag = $utilRag }
    @{ Field = 'MemPct'; Label = 'Memory %'; Align = 'right'; Rag = $utilRag }
    @{ Field = 'Status'; Label = 'Status'; CellType = 'badge'; RowHighlight = $true
       Thresholds = @(@{ Value = 'OK'; Class = 'cell-ok' }, @{ Value = 'Warning'; Class = 'cell-warn' }, @{ Value = 'Critical'; Class = 'cell-danger' }) } )
Add-DhBarChart -Report $report -Id 'colour-bars' -Title 'Servers per status (click a bar to filter)' -NavPath 'Cells/Colour rules' -TableId 'colour' -Field 'Status' -ClickFilters `
    -KeyClass @{ OK = 'cell-ok'; Warning = 'cell-warn'; Critical = 'cell-danger' }

& $note 'n-lists' 'Cells/Lists and trends' 'chips shows a list as tags; path draws a chain (who reaches what); sparkline draws a small trend and sorts by its last, max, min, avg or sum; link turns a URL column into a link (http, https and mailto only).'
Add-DhTable -Report $report -TableId 'lists' -Title 'Servers' -NavPath 'Cells/Lists and trends' -NavLabel 'Lists and trends' -Data $servers -PageSize 8 -Columns @(
    @{ Field = 'Name'; Label = 'Server'; PinFirst = $true }
    @{ Field = 'Roles'; Label = 'Roles'; CellType = 'chips' }
    @{ Field = 'Path'; Label = 'Path to Tier 0'; CellType = 'path' }
    @{ Field = 'Trend'; Label = 'CPU, 8 hours'; CellType = 'sparkline'; SparklineStyle = 'area'; SortBy = 'max' }
    @{ Field = 'Doc'; Label = 'Runbook'; CellType = 'link'; LinkText = 'Open' } )

# ============================================================== INTERACTION
& $note 'n-detail' 'Interaction/Detail panel' 'Click (or press Enter on) a row: every property of the row opens in a side panel, including ones that are not columns. Escape or a click outside closes it. DetailFields chooses and labels the properties.'
Add-DhTable -Report $report -TableId 'detail' -Title 'Servers' -NavPath 'Interaction/Detail panel' -Data $servers -PageSize 8 `
    -DetailDrawer -DetailTitleField 'Name' -DetailFields @('Name', 'Site', 'Os', @{ Field = 'CpuPct'; Label = 'CPU %' }, @{ Field = 'DiskBytes'; Label = 'Disk (bytes)' }, 'Roles', 'Status') -Columns @(
        @{ Field = 'Name'; Label = 'Server' }, @{ Field = 'Site'; Label = 'Site' }, @{ Field = 'Os'; Label = 'Operating system' }
        @{ Field = 'Status'; Label = 'Status'; CellType = 'badge'; Thresholds = @(@{ Value = 'OK'; Class = 'cell-ok' }, @{ Value = 'Warning'; Class = 'cell-warn' }, @{ Value = 'Critical'; Class = 'cell-danger' }) } )

$depts = @('Sales', 'Finance', 'Engineering') | ForEach-Object { [pscustomobject]@{ Department = $_; Head = "$_ lead"; People = 10 * (1 + $_.Length % 5) } }
$staff = foreach ($i in 1..18) { [pscustomobject]@{ Person = 'person{0:00}' -f $i; Department = @('Sales', 'Finance', 'Engineering')[$i % 3]; Title = @('Analyst', 'Manager', 'Engineer')[$i % 3] } }
& $note 'n-link' 'Interaction/Linked tables' 'Set-DhTableLink joins two tables. Both sit on the SAME path so they stack on one view; click a department and the staff table filters to it. Click it again to clear.'
Add-DhTable -Report $report -TableId 'depts' -Title 'Departments (click a row)' -NavPath 'Interaction/Linked tables' -NavLabel 'Linked tables' -Data $depts -Columns @(
    @{ Field = 'Department'; Label = 'Department' }, @{ Field = 'Head'; Label = 'Head' }, @{ Field = 'People'; Label = 'People'; Align = 'right' } )
Add-DhTable -Report $report -TableId 'staff' -Title 'Staff in the selected department' -NavPath 'Interaction/Linked tables' -Data $staff -Columns @(
    @{ Field = 'Person'; Label = 'Person' }, @{ Field = 'Department'; Label = 'Department' }, @{ Field = 'Title'; Label = 'Title' } )
Set-DhTableLink -Report $report -MasterTableId 'depts' -DetailTableId 'staff' -MasterField 'Department' -DetailField 'Department'

& $note 'n-select' 'Interaction/Selection and totals' 'MultiSelect adds checkboxes (export and linked tables honour the selection). Aggregate puts a total, average or count in the footer. Shift-click column headers to sort by several columns.'
Add-DhTable -Report $report -TableId 'select' -Title 'Servers' -NavPath 'Interaction/Selection and totals' -NavLabel 'Selection and totals' -Data $servers -PageSize 8 -MultiSelect -Columns @(
    @{ Field = 'Name'; Label = 'Server'; PinFirst = $true; Aggregate = 'count' }
    @{ Field = 'Site'; Label = 'Site' }
    @{ Field = 'Cost'; Label = 'Monthly cost'; Format = 'currency'; Currency = 'EUR'; Locale = 'en-IE'; Decimals = 0; Align = 'right'; Aggregate = 'sum' }
    @{ Field = 'CpuPct'; Label = 'CPU %'; Align = 'right'; Aggregate = 'avg'; Decimals = 0 } )

$ous = @(
    @{ N = 'corp'; P = 'corp'; O = 0 }, @{ N = 'Headquarters'; P = 'corp/Headquarters'; O = 12 }, @{ N = 'Servers'; P = 'corp/Headquarters/Servers'; O = 48 }
    @{ N = 'Workstations'; P = 'corp/Headquarters/Workstations'; O = 310 }, @{ N = 'Headquarters (old)'; P = 'corp/Headquarters (old)'; O = 3 }
    @{ N = 'Branches'; P = 'corp/Branches'; O = 0 }, @{ N = 'Milan'; P = 'corp/Branches/Milan'; O = 64 }, @{ N = 'Turin'; P = 'corp/Branches/Turin'; O = 41 } ) |
    ForEach-Object { [pscustomobject]@{ OU = $_.N; CanonicalName = $_.P; Objects = $_.O } }
& $note 'n-tree' 'Interaction/Tree filter' 'The tree is a filter, not a copy of the data. Choose a node: the table shows that path and everything below it (Headquarters does not match Headquarters (old): the separator is part of the test). Choose it again, or use the clear button above the table.'
Add-DhTable -Report $report -TableId 'ous' -Title 'Organisational units' -NavPath 'Interaction/Tree filter' -NavLabel 'Tree filter' -Data $ous -Columns @(
    @{ Field = 'OU'; Label = 'OU' }, @{ Field = 'CanonicalName'; Label = 'Canonical name' }, @{ Field = 'Objects'; Label = 'Objects'; Align = 'right'; Format = 'number' } )
Add-DhTreeFilter -Report $report -Id 'ou-tree' -Title 'Browse by OU' -NavPath 'Interaction/Tree filter' -TableId 'ous' -PathField 'CanonicalName' -CountFromTable -Nodes @(
    @{ Id = 'r'; Label = 'corp'; Path = 'corp' }
    @{ Id = 'hq'; Parent = 'r'; Label = 'Headquarters'; Path = 'corp/Headquarters'; Status = 'ok' }
    @{ Id = 'sv'; Parent = 'hq'; Label = 'Servers'; Path = 'corp/Headquarters/Servers' }
    @{ Id = 'ws'; Parent = 'hq'; Label = 'Workstations'; Path = 'corp/Headquarters/Workstations'; Flags = @('large') }
    @{ Id = 'old'; Parent = 'r'; Label = 'Headquarters (old)'; Path = 'corp/Headquarters (old)'; Flags = @('empty'); Detail = 'Unused since 2023; safe to remove.' }
    @{ Id = 'br'; Parent = 'r'; Label = 'Branches'; Path = 'corp/Branches' }
    @{ Id = 'mi'; Parent = 'br'; Label = 'Milan'; Path = 'corp/Branches/Milan' }
    @{ Id = 'tu'; Parent = 'br'; Label = 'Turin'; Path = 'corp/Branches/Turin' } )

# ============================================================== LAYOUT
$wide = foreach ($i in 1..12) {
    [pscustomobject]@{
        Account = 'CN=Service Account {0:00},OU=Service accounts,OU=Headquarters,DC=corp,DC=contoso,DC=com' -f $i
        Description = 'Runs the nightly import for system {0}; owner is the platform team; rotate the password every 90 days.' -f $i
        Short = 'ok'; Code = 'A{0:00}' -f $i
    }
}
& $note 'n-width' 'Layout/Column widths' 'By default every column is as wide as its widest text (header included), up to -ColumnMaxWidth (800 px). A column Width wins; MinWidth sets a floor; the reader can drag an edge, or double-click it to fit that column. The second table uses -ColumnFit Fixed (cells cut at 340 px, with a tooltip).'
Add-DhTable -Report $report -TableId 'wide-auto' -Title 'Automatic widths' -NavPath 'Layout/Column widths' -Data $wide -PageSize 6 -Columns @(
    @{ Field = 'Account'; Label = 'Distinguished name' }
    @{ Field = 'Description'; Label = 'Description' }
    @{ Field = 'Short'; Label = 'State'; MinWidth = 120 }
    @{ Field = 'Code'; Label = 'Declared 90 px'; Width = '90px' } )
Add-DhTable -Report $report -TableId 'wide-fixed' -Title 'Fixed look (-ColumnFit Fixed)' -NavPath 'Layout/Column widths' -Data $wide -PageSize 6 -ColumnFit Fixed -Columns @(
    @{ Field = 'Account'; Label = 'Distinguished name' }, @{ Field = 'Description'; Label = 'Description' } )

& $note 'n-picker' 'Layout/Column picker' 'The Columns button lists every column. A column with Hidden = $true starts unticked (here Ip, Cores and Owner); the button then says how many are hidden. With -RememberColumns the choice is kept for this reader in this browser and restored next time, even after the report is regenerated; Default columns in the picker puts the author''s choice back and forgets the saved one. Nothing is stored unless -RememberColumns is on.'
Add-DhTable -Report $report -TableId 'picker' -Title 'Servers (try the Columns button)' -NavPath 'Layout/Column picker' -NavLabel 'Column picker' -Data $servers -PageSize 8 -RememberColumns -Columns @(
    @{ Field = 'Name'; Label = 'Server'; PinFirst = $true }
    @{ Field = 'Site'; Label = 'Site' }
    @{ Field = 'Os'; Label = 'Operating system' }
    @{ Field = 'CpuPct'; Label = 'CPU %'; Align = 'right' }
    @{ Field = 'MemPct'; Label = 'Memory %'; Align = 'right' }
    @{ Field = 'Doc'; Label = 'Runbook'; Hidden = $true }
    @{ Field = 'Uptime'; Label = 'Uptime (s)'; Align = 'right'; Hidden = $true }
    @{ Field = 'Cost'; Label = 'Monthly cost'; Align = 'right'; Hidden = $true } )

# Last run's rows, for the baseline view: two servers gone, three new, a few changed
$lastRun = @($servers | Where-Object { $_.Name -notin @($servers[2].Name, $servers[5].Name) } | ForEach-Object {
        $r = $_.PSObject.Copy(); if ($_.Name -in @($servers[1].Name, $servers[4].Name, $servers[7].Name)) { $r.CpuPct = [math]::Max(1, $_.CpuPct - 35) }; $r })
$lastRun += [pscustomobject]@{ Name = 'srv-retired-01'; Site = $servers[0].Site; Os = $servers[0].Os; CpuPct = 12; MemPct = 30 }
$lastRun += [pscustomobject]@{ Name = 'srv-retired-02'; Site = $servers[1].Site; Os = $servers[1].Os; CpuPct = 51; MemPct = 62 }
& $note 'n-baseline' 'Layout/Since the last run' '-Baseline takes last run''s rows and -KeyField names the property that identifies a row. New and Changed rows carry a tag and a coloured edge, a changed cell shows its old value on hover, the line under the toolbar counts them, the chips filter the table, and the rows that disappeared wait in a collapsed group under the table. Exports gain a Change column.'
Add-DhTable -Report $report -TableId 'baseline' -Title 'Servers since last night' -NavPath 'Layout/Since the last run' -NavLabel 'Since the last run' -Data $servers -PageSize 8 `
    -Baseline $lastRun -KeyField Name -BaselineLabel 'last night' -Columns @(
    @{ Field = 'Name'; Label = 'Server'; PinFirst = $true }, @{ Field = 'Site'; Label = 'Site' }, @{ Field = 'Os'; Label = 'Operating system' }
    @{ Field = 'CpuPct'; Label = 'CPU %'; Align = 'right' }, @{ Field = 'MemPct'; Label = 'Memory %'; Align = 'right' } )

$big = foreach ($i in 1..50000) { [pscustomobject]@{ Id = $i; Path = 'OU=Level{0},OU=Group{1},DC=corp,DC=contoso,DC=com' -f ($i % 7), ($i % 13); Value = $i * 3 } }
& $note 'n-big' 'Layout/Large table' 'Fifty thousand rows, not paged: only the rows in view are drawn, so scrolling stays smooth, and filter and sort still use every row. Column widths come from all rows, not just the visible ones.'
Add-DhTable -Report $report -TableId 'big' -Title 'Large table' -NavPath 'Layout/Large table' -NavLabel 'Large table' -Pageable:$false -Data $big -Columns @(
    @{ Field = 'Id'; Label = 'Id'; Format = 'number'; Align = 'right' }, @{ Field = 'Path'; Label = 'Path' }, @{ Field = 'Value'; Label = 'Value'; Format = 'number'; Align = 'right' } )

& $note 'n-empty' 'Layout/Nothing found' 'A check that found nothing should say so. -AllClearText replaces an empty grid with a check mark and your sentence.'
Add-DhTable -Report $report -TableId 'clear' -Title 'Servers without a patch in 90 days' -NavPath 'Layout/Nothing found' -NavLabel 'Nothing found' -Data @() `
    -AllClearText 'Every server has been patched in the last 90 days.'

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
