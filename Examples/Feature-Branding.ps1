#Requires -Version 7.4
<#
.SYNOPSIS
    Brand colours and font on top of a theme (DashHtml 3.0.0).

.DESCRIPTION
    MENU
        What the brand changes       header band, menu, links, row hover, chart series 1 and 2
        What it never changes        ok / warning / critical colours, badges, findings

    One report has one brand, so try it with your own colours:
        ./Examples/Feature-Branding.ps1 -PrimaryColor '#C8102E' -OpenInBrowser
        ./Examples/Feature-Branding.ps1 -PrimaryColor '#00594F' -SecondaryColor '#1D252D' -AccentColor '#F2A900' -Theme Grey
    Switch to dark mode with the button in the menu bar: the same hues, in shades that read on a
    dark page. A colour that cannot reach the WCAG minimum prints a warning when the report is built.

.PARAMETER OutputPath
    Where to write the HTML.

.PARAMETER Theme
    Default, Azure, VMware, Grey, Company or Rag: the base the brand sits on.

.PARAMETER PrimaryColor
    The brand colour ('#rrggbb').

.PARAMETER SecondaryColor
    The header band. Empty: a darker shade of the primary colour.

.PARAMETER AccentColor
    The second chart series.

.PARAMETER FontFamily
    The report font. Georgia is on Windows and macOS, so the change is visible without a font file.

.PARAMETER FontFile
    A .woff2 / .woff / .ttf / .otf to embed, so the font shows on every machine.

.PARAMETER OpenInBrowser
    Open the dashboard once generated.

.EXAMPLE
    PS> ./Examples/Feature-Branding.ps1 -OpenInBrowser
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Feature-Branding.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Default',
    [string] $PrimaryColor = '#0055A4',
    [string] $SecondaryColor = '',
    [string] $AccentColor = '#C86E00',
    [string] $FontFamily = 'Georgia',
    [string] $FontFile = '',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force

$note = { param([string] $Id, [string] $Path, [string] $Text) Add-DhHtmlBlock -Report $report -Id $Id -Title 'In this view' -Style info -NavPath $Path -Content $Text -AllowHtml:$false }

$brand = @{ PrimaryColor = $PrimaryColor; AccentColor = $AccentColor; FontFamily = $FontFamily }
if ($SecondaryColor) { $brand.SecondaryColor = $SecondaryColor }
if ($FontFile)       { $brand.FontFile = $FontFile }
$report = New-DhDashboard -Title 'Branding' -Subtitle "Primary $PrimaryColor on the $Theme theme" -Theme $Theme -NavTitle 'Brand' `
    -GeneratedBy 'Feature-Branding.ps1' @brand

$sites = 'Milan', 'Rome', 'Turin', 'Naples', 'Bologna', 'Florence'
$servers = @(for ($i = 1; $i -le 36; $i++) {
    [pscustomobject]@{
        Name   = 'SRV{0:D3}' -f $i
        Site   = $sites[$i % $sites.Count]
        Role   = @('Web', 'App', 'Database', 'File')[$i % 4]
        CpuPct = (17 * $i) % 100
        Owner  = @('Platform', 'Apps', 'Data')[$i % 3]
        Status = @('Healthy', 'Healthy', 'Healthy', 'Warning', 'Critical')[$i % 5]
    }
})

# ============================================================== WHAT THE BRAND CHANGES
& $note 'n-brand' 'Changes' 'The header band is the secondary colour (here a darker shade of the primary, because -SecondaryColor is empty). The selected menu item, links, the row you point at and the first chart series are the primary colour; the second series in the stacked chart is the accent colour. The font is -FontFamily, with the theme fonts behind it.'
Add-DhTable -Report $report -TableId 'servers' -Title 'Servers' -NavPath 'Changes' -NavLabel 'What the brand changes' -Data $servers -PageSize 12 -Columns @(
    @{ Field = 'Name'; Label = 'Server' }
    @{ Field = 'Site'; Label = 'Site'; CellType = 'link'; UrlTemplate = 'https://portal.example.com/sites/{Site}' }
    @{ Field = 'Role'; Label = 'Role' }
    @{ Field = 'CpuPct'; Label = 'CPU'; CellType = 'progressbar' }
    @{ Field = 'Owner'; Label = 'Owner' } )
Add-DhBarChart -Report $report -Id 'by-site' -Title 'Servers by site' -TableId 'servers' -Field 'Site' -NavPath 'Changes'
Add-DhBarChart -Report $report -Id 'by-role' -Title 'Roles by owner (two series)' -TableId 'servers' -Field 'Owner' -Stacked -SeriesField 'Role' -NavPath 'Changes'

# ============================================================== WHAT IT NEVER CHANGES
& $note 'n-status' 'Status' 'Severity keeps its meaning in every brand: ok, warning and critical use the theme colours, whatever -PrimaryColor is.'
Add-DhSummary -Report $report -NavPath 'Status' -NavLabel 'What it never changes' -Items @(
    @{ Label = 'Healthy';  Value = @($servers | Where-Object Status -eq 'Healthy').Count;  Class = 'cell-ok' }
    @{ Label = 'Warning';  Value = @($servers | Where-Object Status -eq 'Warning').Count;  Class = 'cell-warn' }
    @{ Label = 'Critical'; Value = @($servers | Where-Object Status -eq 'Critical').Count; Class = 'cell-danger' } )
Add-DhTable -Report $report -TableId 'status' -Title 'Status' -NavPath 'Status/status' -NavLabel 'Servers by status' -Data $servers -PageSize 12 -Columns @(
    @{ Field = 'Name'; Label = 'Server' }
    @{ Field = 'Status'; Label = 'Status'; CellType = 'badge'; Thresholds = @(
        @{ Value = 'Healthy'; Class = 'cell-ok' }, @{ Value = 'Warning'; Class = 'cell-warn' }, @{ Value = 'Critical'; Class = 'cell-danger' }) } )

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
