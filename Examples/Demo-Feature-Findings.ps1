#Requires -Version 7.0
<#
.SYNOPSIS
    v2.2 showcase: an assessment report - findings, verdict, value bar charts,
    reference links, print and offline export.

.DESCRIPTION
    The shape of an audit report built with DashHtml 2.2.0:

      * Add-DhSummary Style='verdict'   - the overall assessment, with severity chips
      * Add-DhFindings                  - what is wrong, what to do, who is affected,
                                          a jump to the detail table, reference links
      * Add-DhBarChart -ValueField / -Aggregate - bars that measure a value
                                          (average lag, total size), not row counts
      * Add-DhTable -Charts Type='bar'  - the same, inside a table's chart strip
      * CellType='link'                 - Microsoft Learn links in a table column
      * New-DhDashboard -ThemeMode Auto -PrintCover
      * Export-DhDashboard -ExportLibraries

    Print it (the Print button, or Ctrl+P) to see the print layout: a cover
    page, every section in menu order, every finding expanded.

    All data is invented. Run from a clone of the DashHtml repo; it loads the
    local module.

.PARAMETER OutputPath
    Where to write the HTML.

.PARAMETER ExportLibraries
    Cdn (default), Embed (works offline, about 1.3 MB larger) or None.

.EXAMPLE
    PS> .\Examples\Demo-Feature-Findings.ps1 -ExportLibraries Embed -OpenInBrowser
#>

[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Demo-Feature-Findings.html'),
    [ValidateSet('Cdn','Embed','None')]
    [string] $ExportLibraries = 'Cdn',
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Default',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..\DashHtml\DashHtml.psd1'
Import-Module $modulePath -Force

# ---------------------------------------------------------------------------
# Data (invented, deterministic)
# ---------------------------------------------------------------------------
$learn = 'https://learn.microsoft.com/en-us/windows-server/identity/ad-ds'

$accounts = @(
    [pscustomobject]@{ Account='svc_backup';  Type='Service'; Issue='AS-REP roastable';      LastLogon='2026-09-30'; Doc="$learn/manage/understand-security-identifiers" }
    [pscustomobject]@{ Account='svc_legacy';  Type='Service'; Issue='AS-REP roastable';      LastLogon='2025-11-02'; Doc="$learn/manage/understand-security-identifiers" }
    [pscustomobject]@{ Account='adm.rossi';   Type='Admin';   Issue='SPN on privileged user'; LastLogon='2026-10-12'; Doc="$learn/plan/security-best-practices/best-practices-for-securing-active-directory" }
    [pscustomobject]@{ Account='test1';       Type='User';    Issue='Password never expires'; LastLogon='2024-03-15'; Doc="$learn/plan/security-best-practices/best-practices-for-securing-active-directory" }
    [pscustomobject]@{ Account='kiosk02';     Type='User';    Issue='Password never expires'; LastLogon='2026-10-01'; Doc="$learn/plan/security-best-practices/best-practices-for-securing-active-directory" }
    [pscustomobject]@{ Account='old.contractor'; Type='User'; Issue='Stale (no logon > 180 days)'; LastLogon='2025-12-20'; Doc='' }
)

$dcs  = 'DC01', 'DC02', 'DC03', 'DC04'
$repl = foreach ($i in 0..39) {
    $from = $dcs[$i % 4]; $to = $dcs[($i + 1 + [math]::Floor($i / 4) % 3) % 4]
    $lag  = (($i * 17) % 23) + $(if ($from -eq 'DC03') { 35 } else { 0 })
    [pscustomobject]@{ Source=$from; Partner=$to; Partition=@('Domain','Configuration','Schema','DomainDnsZones')[$i % 4]
                       LagMin=$lag; Result=$(if ($lag -gt 40) { 'Failing' } else { 'OK' }) }
}

$sizes = foreach ($dc in $dcs) {
    foreach ($vol in 'NTDS', 'SYSVOL', 'Logs') {
        [pscustomobject]@{ DC=$dc; Volume=$vol; UsedGB=[math]::Round((($dc[-1] -as [int]) * 3.5 + $vol.Length * 2.25), 1) }
    }
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
$report = New-DhDashboard -Title 'AD Security Assessment' `
    -Subtitle 'contoso.com - findings and evidence' -Theme $Theme `
    -ThemeMode Auto -PrintCover `
    -InfoFields @(
        @{ Label='Forest';   Value='contoso.com' }
        @{ Label='Assessor'; Value='DashHtml demo' }
        @{ Label='Scope';    Value='2 domains, 4 DCs' }
    )

$failing = @($repl | Where-Object Result -eq 'Failing').Count

# Verdict first, full width; ordinary tiles after it.
Add-DhSummary -Report $report -Title 'Assessment' -Items @(
    @{ Style='verdict'; Label='Overall verdict'; Value='Action required'; Icon='⚠'
       Caption='Fix the critical findings before the next audit window.'
       Counts=@{ critical=2; warning=2; info=1; ok=1 } }
    @{ Label='Accounts reviewed'; Value=1284 }
    @{ Label='Failing replication links'; Value=$failing; Class=$(if ($failing) { 'cell-danger' } else { 'cell-ok' })
       Action=@{ TableId='repl'; Filter='Failing'; Label='Show failing links' } }
)

# Tables first: everything below links to them.
Add-DhTable -Report $report -TableId 'accounts' -Title 'Accounts with findings' -Data $accounts `
    -NavPath 'Evidence/Accounts' -NavLabel 'Accounts' -Columns @(
        @{ Field='Account';   Label='Account'; PinFirst=$true }
        @{ Field='Type';      Label='Type' }
        @{ Field='Issue';     Label='Issue' }
        @{ Field='LastLogon'; Label='Last logon'; Format='datetime'; DatePattern='yyyy-MM-dd' }
        # The URL lives in Doc, which is not a visible column; the cell shows fixed text.
        @{ Field='Reference'; Label='Reference'; CellType='link'; UrlField='Doc'; LinkText='Microsoft Learn' }
    )

Add-DhTable -Report $report -TableId 'repl' -Title 'Replication partners' -Data $repl `
    -NavPath 'Evidence/Replication' -NavLabel 'Replication' -PageSize 10 `
    -Charts @(
        # a bar chart in the table's chart strip: average lag per source DC
        @{ Field='Source'; Type='bar'; ValueField='LagMin'; Aggregate='avg'; Unit='min'; Decimals=1; Title='Average lag by source DC' }
        @{ Field='Result'; Title='Link result' }
    ) -Columns @(
        @{ Field='Source';    Label='Source' }
        @{ Field='Partner';   Label='Partner' }
        @{ Field='Partition'; Label='Partition' }
        @{ Field='LagMin';    Label='Lag (min)'; Align='right'
           Rag=@{ Green=@{ Max=15 }; Amber=@{ Min=15; Max=40 }; Red=@{ Min=40 } } }
        @{ Field='Result';    Label='Result' }
    )

Add-DhTable -Report $report -TableId 'sizes' -Title 'Volume usage' -Data $sizes `
    -NavPath 'Evidence/Capacity' -NavLabel 'Capacity'

# Value bar charts: the bars measure a column, not the number of rows.
Add-DhBarChart -Report $report -Id 'lag-max' -Title 'Worst replication lag by source DC' `
    -TableId 'repl' -Field 'Source' -ValueField 'LagMin' -Aggregate max -Unit 'min' -ClickFilters `
    -NavPath 'Evidence/Replication' -GridSpan 6
Add-DhBarChart -Report $report -Id 'size-total' -Title 'Used space by DC' `
    -TableId 'sizes' -Field 'DC' -ValueField 'UsedGB' -Aggregate sum -Unit 'GB' -Decimals 1 -ShowPercent `
    -NavPath 'Evidence/Capacity' -GridSpan 6
Add-DhBarChart -Report $report -Id 'size-stack' -Title 'Used space by DC and volume' `
    -TableId 'sizes' -Field 'DC' -SeriesField 'Volume' -ValueField 'UsedGB' -Aggregate sum -Unit 'GB' `
    -NavPath 'Evidence/Capacity' -GridSpan 6

Add-DhFindings -Report $report -Id 'findings' -Title 'Findings' -NavPath 'Findings' `
    -GroupBy Area -ExpandSeverity critical -MaxAffectedShown 5 -Findings @(
        @{ Severity='critical'; Title='AS-REP roastable service accounts'; Area='Accounts'
           Description="Accounts with 'Do not require Kerberos preauthentication' let anyone request an encrypted ticket and crack it offline."
           Recommendation='Clear DONT_REQ_PREAUTH on every listed account, then rotate their passwords.'
           Affected=@('svc_backup','svc_legacy'); AffectedTableId='accounts'; AffectedFilter='AS-REP'
           References=@(@{ Label='Kerberos preauthentication'; Url="$learn/plan/security-best-practices/best-practices-for-securing-active-directory" }) }
        @{ Severity='high'; Title='Privileged user with an SPN (Kerberoastable)'; Area='Accounts'
           Description='A service principal name on a privileged account exposes a ticket encrypted with its password.'
           Recommendation='Move the SPN to a dedicated gMSA; remove it from adm.rossi.'
           Affected=@('adm.rossi'); AffectedTableId='accounts'; AffectedFilter='SPN' }
        @{ Severity='warning'; Title="Replication failing on $failing link(s)"; Area='Replication'
           Description="Links from DC03 exceed 40 minutes of lag.`nThe other DCs are within target."
           Recommendation='Run repadmin /showrepl DC03 and check RPC connectivity to its partners.'
           AffectedCount=$failing; AffectedTableId='repl'; AffectedFilter='Failing' }
        @{ Severity='medium'; Title='Passwords that never expire'; Area='Accounts'
           Recommendation='Remove the flag, or document an exception per account.'
           Affected=@('test1','kiosk02'); AffectedTableId='accounts'; AffectedFilter='never expires' }
        @{ Severity='low'; Title='Stale user accounts'; Area='Hygiene'
           Description='No logon for more than 180 days.'; Affected=@('old.contractor') }
        @{ Severity='ok'; Title='SMBv1 disabled on every DC'; Area='Hygiene' }
    )

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser `
    -ExportLibraries $ExportLibraries
Write-Host "Wrote $OutputPath"
