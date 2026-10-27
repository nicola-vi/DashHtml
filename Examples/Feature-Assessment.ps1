#Requires -Version 7.0
<#
.SYNOPSIS
    Assessment reporting: verdict and score, findings with proof, property tiles, record lists.

.DESCRIPTION
    MENU
        Summary                      verdict, score, maturity, scope tiles
        Findings
            List                     expandable rows, grouped, with remediation and references
            Split                    list on the left, detail on the right; facts, evidence, change
            Nothing found            a check that passed says so
        Details
            Property tiles           facts about one thing
            Record list              one row per server, expands to tiles, bars, tables, checks
            Side panel               a finding with a detail panel

    Findings link to the table that holds the affected objects ("Show in table" jumps there and
    filters). Change markers (new, worse, better, resolved) come from YOUR comparison with the
    last run; DashHtml only shows them.

.PARAMETER OutputPath
    Where to write the HTML.

.PARAMETER Theme
    Default, Azure, VMware, Grey, Company or Rag.

.PARAMETER OpenInBrowser
    Open the dashboard once generated.

.EXAMPLE
    PS> ./Examples/Feature-Assessment.ps1 -OpenInBrowser
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Feature-Assessment.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Rag',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force

$note = { param([string] $Id, [string] $Path, [string] $Text) Add-DhHtmlBlock -Report $report -Id $Id -Title 'In this view' -Style info -NavPath $Path -Content $Text -AllowHtml:$false }
$servers = @(
    [pscustomobject]@{ Name = 'dc01'; Site = 'HQ';    Os = 'Windows Server 2022'; Cores = 4; RamGB = 8;  CpuPct = 2; Model = 'VMware20,1'; Ip = '10.10.1.11'; Roles = @('PDC', 'GC') }
    [pscustomobject]@{ Name = 'dc02'; Site = 'HQ';    Os = 'Windows Server 2022'; Cores = 4; RamGB = 8;  CpuPct = 4; Model = 'VMware20,1'; Ip = '10.10.1.12'; Roles = @('GC') }
    [pscustomobject]@{ Name = 'dc03'; Site = 'EU';    Os = 'Windows Server 2019'; Cores = 8; RamGB = 16; CpuPct = 3; Model = 'VMware20,1'; Ip = '10.30.1.11'; Roles = @('GC', 'DNS') } )
$dcs = $servers.Name

$report = New-DhDashboard -Title 'Assessment' -Subtitle 'Verdicts, findings, evidence and records' -Theme $Theme -NavTitle 'Assessment' -NavMaxDepth 2 -GeneratedBy 'Feature-Assessment.ps1'

# ============================================================== SUMMARY
& $note 'n-sum' 'Summary' 'The verdict answers the whole question in a sentence and counts findings by severity. The score ring and the maturity ladder come from YOUR rules (the lowest unmet control sets the level); DashHtml only draws them.'
Add-DhSummary -Report $report -NavPath 'Summary' -Items @(
    @{ Style = 'verdict'; Label = 'Overall'; Value = 'Elevated risk'; Caption = 'Two warnings on authentication need action this month.'; Counts = @{ critical = 0; warning = 2; info = 1; ok = 2 } }
    @{ Style = 'score'; Label = 'Security posture'; Value = 69; Caption = 'Elevated risk'; Previous = 66; Facts = @('211 checks', '31 failed', '53 warnings'); NotAssessed = 20
       Rag = @{ Red = @{ Max = 50 }; Amber = @{ Min = 50; Max = 80 }; Green = @{ Min = 80 } } }
    @{ Style = 'maturity'; Label = 'Security maturity'; Value = 'Initial'; Current = 1; Caption = 'The lowest unmet control sets the level.'
       Levels = @(@{ Name = 'Initial'; Description = 'Ad hoc.' }, @{ Name = 'Managed'; Description = 'Basic hygiene in place and monitored.' }, @{ Name = 'Defined'; Description = 'Documented standards.' }, @{ Name = 'Measured'; Description = 'Measured and trended.' }, @{ Name = 'Optimised'; Description = 'Continuous improvement.' })
       Criteria = @(@{ Level = 2; Text = 'Enable the Recycle Bin'; Met = $false }, @{ Level = 2; Text = 'Raise the tombstone lifetime to 180 days'; Met = $false }, @{ Level = 2; Text = 'Disable NTLMv1 on every DC'; Met = $true }) } )

Add-DhKeyValue -Report $report -Id 'scope' -Title 'Scope of this assessment' -NavPath 'Summary' -Columns 4 -Items @(
    @{ Label = 'Forest'; Value = 'corp.example' }, @{ Label = 'Domain controllers'; Value = "$($servers.Count)" }
    @{ Label = 'Collected via'; Value = 'WinRM' }, @{ Label = 'Pending reboot'; Value = 'None'; Status = 'ok' }
    @{ Label = 'NTLMv1'; Value = 'Disabled on all DCs'; Status = 'ok' }, @{ Label = 'Time skew'; Value = 'up to 3 s'; Status = 'warn' } )

# The table the findings point at: declared first, shown on the Findings/List view (last, as tables always are)
Add-DhTable -Report $report -TableId 'servers' -Title 'Domain controllers' -NavPath 'Findings/List' -NavLabel 'List' -Data $servers -DetailDrawer -DetailTitleField 'Name' -Columns @(
    @{ Field = 'Name'; Label = 'DC' }, @{ Field = 'Site'; Label = 'Site' }, @{ Field = 'Os'; Label = 'Operating system' }
    @{ Field = 'RamGB'; Label = 'RAM (GB)'; Align = 'right' }, @{ Field = 'Roles'; Label = 'Roles'; CellType = 'chips' } )

# ============================================================== FINDINGS
& $note 'n-list' 'Findings/List' 'The default layout: one expandable row per finding with severity, description, recommendation, affected objects and links. Counters filter by severity; critical findings start open. "Show in table" jumps to the table below and filters it.'
Add-DhFindings -Report $report -Id 'list' -Title 'Findings (list)' -NavPath 'Findings/List' -ExpandSeverity critical -GroupBy Area -Findings @(
    @{ Severity = 'critical'; Area = 'Replication'; Title = 'Inbound replication on dc03 is stalled'
       Description = 'dc03 has not replicated from dc01 for 12 minutes (error 1722).'
       Recommendation = 'Check RPC between the sites, then run repadmin /syncall dc03 /AdeP.'
       Affected = @('dc03'); AffectedTableId = 'servers'
       References = @(@{ Label = 'Troubleshoot error 1722'; Url = 'https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/replication-error-1722-rpc-server-unavailable' }) }
    @{ Severity = 'warning'; Area = 'Authentication'; Title = 'LDAP signing is not required'; Description = 'Two DCs accept unsigned binds.'
       Recommendation = 'Require signing after checking the client inventory.'; Affected = @('dc01', 'dc02'); AffectedTableId = 'servers' }
    @{ Severity = 'info'; Area = 'Recovery'; Title = 'Recycle Bin is enabled'; Description = 'Enabled on the forest.' } )

& $note 'n-split' 'Findings/Split' 'Split layout: the list on the left, the selected finding on the right. A finding carries Facts (tiles), Evidence (one row per object with its own status), a Change marker, references and an optional Detail panel. Print shows every pane.'
Add-DhFindings -Report $report -Id 'split' -Title 'Protocols and hardening (split)' -NavPath 'Findings/Split' -NavLabel 'Split' -Layout Split -GroupBy Area -Findings @(
    @{ Severity = 'warning'; Area = 'Authentication'; Title = 'NTLM level'; Change = 'new'
       Description = 'LAN Manager authentication level. Below 5 the DC still accepts LM and NTLMv1.'
       Recommendation = 'Raise the level to 5 once no NTLMv1 clients remain.'
       Facts = @(@{ Label = 'Recommended'; Value = '5, NTLMv2 only' }, @{ Label = 'Domain controllers'; Value = '3 of 3 below'; Status = 'warn' })
       Evidence = @($dcs | ForEach-Object { @{ Object = $_; Value = 'Level 4'; Status = 'warn' } })
       Detail = @{ Title = 'NTLM level: how to check'; Sections = @(@{ Kind = 'text'; Text = 'Audit NTLM usage for two weeks (event 8004) before raising the level.' }, @{ Kind = 'checks'; Title = 'Before the change'; Items = @(@{ Label = 'NTLM audit enabled'; Ok = $false }, @{ Label = 'No NTLMv1 clients seen'; Ok = $true }) }) } }
    @{ Severity = 'warning'; Area = 'Authentication'; Title = 'LDAP signing'; Change = 'worse'
       Recommendation = 'Require signing on every DC.'
       Evidence = @(@{ Object = 'dc01'; Value = 'Negotiate'; Status = 'warn' }, @{ Object = 'dc02'; Value = 'Negotiate'; Status = 'warn' }, @{ Object = 'dc03'; Value = 'Require'; Status = 'ok' }) }
    @{ Severity = 'info'; Area = 'Recovery'; Title = 'Recycle Bin'; Change = 'better'; Description = 'Enabled on the forest.'; Facts = @(@{ Label = 'Enabled'; Value = 'Yes'; Status = 'ok' }) }
    @{ Severity = 'ok'; Area = 'Authentication'; Title = 'SMB signing'; Evidence = @($dcs | ForEach-Object { @{ Object = $_; Value = 'Required'; Status = 'ok' } }) }
    @{ Severity = 'ok'; Area = 'Recovery'; Title = 'SMBv1'; Change = 'resolved'; Description = 'Disabled on every DC.' } )

& $note 'n-clear' 'Findings/Nothing found' 'A check that found nothing says so, with a check mark and your sentence, instead of an empty block.'
Add-DhFindings -Report $report -Id 'clear' -Title 'Delegation findings' -NavPath 'Findings/Nothing found' -NavLabel 'Nothing found' -AllClearText 'No unconstrained delegation found.' -Findings @()

# ============================================================== DETAILS
& $note 'n-kv' 'Details/Property tiles' 'Property tiles show facts about one thing: label, value, and an optional status colour on the edge. Use them instead of a two-column table.'
Add-DhKeyValue -Report $report -Id 'kv' -Title 'dc01' -NavPath 'Details/Property tiles' -NavLabel 'Property tiles' -Columns 3 -Items @(
    @{ Label = 'Manufacturer'; Value = 'VMware, Inc.' }, @{ Label = 'Model'; Value = 'VMware20,1' }, @{ Label = 'BIOS'; Value = 'VMW201.00V.24504846' }
    @{ Label = 'Total memory'; Value = '8 GB' }, @{ Label = 'CPU usage'; Value = '2%'; Status = 'ok' }, @{ Label = 'C: free'; Value = '73 GB (74%)'; Status = 'ok' } )

& $note 'n-rec' 'Details/Record list' 'One row per record with a status dot and up to four metrics. Open a row for tiles, bars, tables and checks. Filter box and expand-all included; print shows every row open.'
Add-DhRecordList -Report $report -Id 'records' -Title 'Hardware and performance' -NavPath 'Details/Record list' -NavLabel 'Record list' -Items @(
    foreach ($s in $servers) {
        @{ Title = $s.Name; Subtitle = "corp.example, $($s.Site)"; Status = $(if ($s.CpuPct -gt 3) { 'warn' } else { 'ok' })
           Metrics = @(@{ Label = 'RAM'; Value = "$($s.RamGB) GB" }, @{ Label = 'Cores'; Value = "$($s.Cores)" }, @{ Label = 'CPU'; Value = "$($s.CpuPct)%" })
           Sections = @(
               @{ Kind = 'kv'; Title = 'System'; Items = @(@{ Label = 'Model'; Value = $s.Model }, @{ Label = 'OS'; Value = $s.Os }, @{ Label = 'IP'; Value = $s.Ip }) }
               @{ Kind = 'bars'; Title = 'Performance'; Max = 100; Unit = '%'; Items = @(@{ Label = 'CPU'; Value = $s.CpuPct; Status = 'ok' }, @{ Label = 'Memory'; Value = 45; Status = 'ok' }, @{ Label = 'C: used'; Value = 26; Status = 'ok' }) }
               @{ Kind = 'table'; Title = 'Volumes'; Columns = @('Drive', 'Size', 'Free'); Rows = @(, @('C:', '99.4 GB', '73.2 GB')) }
               @{ Kind = 'checks'; Title = 'Health checks'; Items = @(@{ Label = 'Connectivity'; Ok = $true }, @{ Label = 'Replication'; Ok = $true }, @{ Label = 'Time sync'; Status = 'warn'; Note = 'skew 3 s' }) }) }
    } )

& $note 'n-panel' 'Details/Side panel' 'Table rows, status-grid cells, findings and map nodes all open their detail in the same side panel. Escape or a click outside closes it, and focus returns to where you were.'
Add-DhTable -Report $report -TableId 'panel-table' -Title 'Click a row' -NavPath 'Details/Side panel' -NavLabel 'Side panel' -Data $servers -DetailDrawer -DetailTitleField 'Name' `
    -DetailFields @('Name', 'Site', 'Os', @{ Field = 'RamGB'; Label = 'RAM (GB)' }, 'Cores', 'Model', 'Ip', 'Roles') -Columns @(
        @{ Field = 'Name'; Label = 'DC' }, @{ Field = 'Site'; Label = 'Site' }, @{ Field = 'Ip'; Label = 'IP address' } )

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
