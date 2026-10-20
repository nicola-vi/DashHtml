#Requires -Version 7.0
<#
.SYNOPSIS
    Microsoft 365 services review: licences, Exchange, Teams, SharePoint, identity and service health (synthetic data).

.DESCRIPTION
    A realistic Microsoft 365 tenant report, laid out as a menu.

    MENU (what opens where)
        Overview                         verdict, headline KPIs, service health today
        Licensing
            Usage                        assigned against purchased, per product
            Unused                       licences nobody uses, and what they cost
        Exchange Online
            Mailboxes                    types, size, quota
            Mail flow                    volume, spam, connectors
        Collaboration
            Teams                        teams with no owner or no activity
            SharePoint                   sites, storage, external sharing
        Identity and security
            MFA                          registration by method, users without MFA
            Conditional Access           policies as expandable records
            Risk                         risky users and sign-in failures
        Service health                   incidents and the last seven days
        Adoption                         which apps people actually use

    WHAT IS GLOBAL AND WHAT IS NOT
        * A "Department" dropdown above everything narrows every table that has a Department
          column, on every view. One banner (the open Exchange incident) is visible everywhere.
        * "Licensing", "Exchange Online" and "Identity and security" each carry a KPI strip
          declared with -NavScope Subtree, so it sits on top of every view in that branch.
        * Everything else is bound to exactly one view.
        * Page order inside a view: banners, global filters, global KPI tiles, blocks in the
          order declared, tables in the order declared (tables always last).

    Run Tools/Show-DhNavMap.ps1 on the result to print the menu and each view's content.

    All data is synthetic and deterministic. Replace the data section with Microsoft Graph and
    Exchange Online PowerShell output when adapting.

.PARAMETER OutputPath
    Where to write the HTML. Defaults to Demo-Microsoft365.html beside this script.

.PARAMETER Theme
    Default, Azure, VMware, Grey, Company or Rag.

.PARAMETER OpenInBrowser
    Open the dashboard once generated.

.EXAMPLE
    PS> ./Examples/Demo-Microsoft365.ps1 -OpenInBrowser
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Demo-Microsoft365.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Company',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force

# ============================================================================
# Data (synthetic, deterministic)
# ============================================================================
$rng = [System.Random]::new(365)
$depts = @('Sales', 'Finance', 'Engineering', 'HR', 'Operations', 'Marketing')
$weeks = @('W37', 'W38', 'W39', 'W40', 'W41', 'W42')

$skus = @(
    [pscustomobject]@{ Product = 'Microsoft 365 E5';      Purchased = 400; Assigned = 388; Active = 361; CostPerUser = 57 }
    [pscustomobject]@{ Product = 'Microsoft 365 E3';      Purchased = 900; Assigned = 842; Active = 706; CostPerUser = 36 }
    [pscustomobject]@{ Product = 'Microsoft 365 F3';      Purchased = 600; Assigned = 412; Active = 395; CostPerUser = 8 }
    [pscustomobject]@{ Product = 'Power BI Pro';          Purchased = 250; Assigned = 240; Active = 120; CostPerUser = 10 }
    [pscustomobject]@{ Product = 'Teams Phone Standard';  Purchased = 300; Assigned = 295; Active = 210; CostPerUser = 8 }
    [pscustomobject]@{ Product = 'Visio Plan 2';          Purchased = 60;  Assigned = 58;  Active = 9;   CostPerUser = 15 }
)

$unused = foreach ($i in 1..14) {
    [pscustomobject]@{
        User = 'user{0:00}@contoso.com' -f $i
        Department = $depts[$i % 6]
        License = @('Microsoft 365 E3', 'Power BI Pro', 'Visio Plan 2', 'Microsoft 365 E5')[$i % 4]
        DaysInactive = 45 + $rng.Next(0, 300)
        MonthlyCost = @(36, 10, 15, 57)[$i % 4]
    }
}

$mailboxes = foreach ($i in 1..40) {
    $size = [math]::Round(0.3 + $rng.NextDouble() * 48, 1)
    [pscustomobject]@{
        Mailbox = 'mbx{0:00}@contoso.com' -f $i
        Department = $depts[$i % 6]
        Type = @('User', 'User', 'User', 'Shared', 'Room', 'Equipment')[$i % 6]
        SizeGB = $size
        QuotaGB = 50
        UsedPct = [math]::Round($size / 50 * 100)
        Archive = $(if ($i % 3 -eq 0) { 'Enabled' } else { 'Disabled' })
    }
}

$teams = foreach ($i in 1..18) {
    [pscustomobject]@{
        Team = 'Team-{0}-{1:00}' -f $depts[$i % 6], $i
        Department = $depts[$i % 6]
        Owners = $(if ($i % 7 -eq 0) { 0 } else { 1 + ($i % 3) })
        Members = 4 + $rng.Next(0, 80)
        LastActivityDays = $(if ($i % 5 -eq 0) { 120 + $rng.Next(0, 200) } else { $rng.Next(0, 20) })
        Guests = $rng.Next(0, 9)
    }
}

$sites = foreach ($i in 1..16) {
    [pscustomobject]@{
        Site = '/sites/{0}-{1:00}' -f $depts[$i % 6].ToLower(), $i
        Department = $depts[$i % 6]
        StorageGB = [math]::Round(1 + $rng.NextDouble() * 400)
        Sharing = @('Only people in the organisation', 'Existing guests', 'Anyone')[$(if ($i % 8 -eq 0) { 2 } elseif ($i % 3 -eq 0) { 1 } else { 0 })]
        Files = 800 + $rng.Next(0, 90000)
    }
}

$users = foreach ($i in 1..60) {
    $mfa = if ($i % 9 -eq 0) { 'None' } else { @('Authenticator', 'Authenticator', 'FIDO2', 'SMS')[$i % 4] }
    [pscustomobject]@{
        User = 'person{0:00}@contoso.com' -f $i
        Department = $depts[$i % 6]
        Mfa = $mfa
        Admin = ($i % 17 -eq 0)
        RiskLevel = $(if ($i % 23 -eq 0) { 'High' } elseif ($i % 11 -eq 0) { 'Medium' } else { 'None' })
        LastSignIn = (Get-Date '2026-10-17').AddHours(-1 * (1 + $rng.Next(0, 300))).ToString('yyyy-MM-ddTHH:mm:ss')
    }
}

$caPolicies = @(
    [pscustomobject]@{ Name = 'Require MFA for all users';         State = 'On';     Grant = 'MFA';          Scope = 'All users, all apps';        Status = 'ok';   Note = 'Break-glass accounts are excluded.' }
    [pscustomobject]@{ Name = 'Block legacy authentication';       State = 'On';     Grant = 'Block';        Scope = 'All users, legacy clients';  Status = 'ok';   Note = 'No sign-ins matched in 30 days.' }
    [pscustomobject]@{ Name = 'Require compliant device for admins'; State = 'On';   Grant = 'Compliant device'; Scope = 'Admin roles';          Status = 'ok';   Note = '' }
    [pscustomobject]@{ Name = 'Block sign-in from risky locations'; State = 'Report-only'; Grant = 'Block';    Scope = 'All users, 14 countries';    Status = 'warn'; Note = 'Still in report-only mode after 90 days.' }
    [pscustomobject]@{ Name = 'Require MFA for guests';            State = 'Off';    Grant = 'MFA';          Scope = 'Guest users';                Status = 'danger'; Note = 'Disabled on 2026-08-02 and never re-enabled.' }
)

$health = @('Exchange Online', 'SharePoint Online', 'Microsoft Teams', 'Entra ID', 'Intune', 'OneDrive for Business')
$days = @('Oct 11', 'Oct 12', 'Oct 13', 'Oct 14', 'Oct 15', 'Oct 16', 'Oct 17')

$report = New-DhDashboard -Title 'Microsoft 365 Services Review' -Subtitle 'Tenant contoso.onmicrosoft.com, 1,400 users' `
    -Theme $Theme -NavTitle 'M365' -NavMaxDepth 2 -GeneratedBy 'Demo-Microsoft365.ps1' -InfoFields @(
        @{ Label = 'Tenant';    Value = 'contoso.onmicrosoft.com' }
        @{ Label = 'Users';     Value = '1,400 (38 guests)' }
        @{ Label = 'Period';    Value = 'Last 30 days' }
        @{ Label = 'Generated'; Value = (Get-Date -Format 'yyyy-MM-dd HH:mm') } )

# ============================================================================
# GLOBAL
# ============================================================================
Add-DhAlertBanner -Report $report -Id 'exo-incident' -Severity warning -Icon '!' -Dismissible `
    -Message 'Service incident EX123456: some users see delayed mail delivery in Exchange Online. Microsoft is investigating.' `
    -Action @{ Label = 'Open service health'; TableId = 'incidents' }

Add-DhGlobalFilter -Report $report -Field 'Department' -Label 'Department'

# ============================================================================
# OVERVIEW
# ============================================================================
Add-DhSummary -Report $report -NavPath 'Overview' -NavLabel 'Overview' -Items @(
    @{ Style = 'verdict'; Label = 'Overall'; Value = 'Healthy, with gaps'
       Caption = 'One service incident, guest MFA is off, and unused licences cost money.'
       Counts = @{ critical = 1; warning = 4; info = 2 } }
    @{ Style = 'score'; Label = 'Microsoft Secure Score'; Value = 64; Caption = 'Fair'; Previous = 61
       Rag = @{ Red = @{ Max = 50 }; Amber = @{ Min = 50; Max = 75 }; Green = @{ Min = 75 } } }
    @{ Label = 'Licences assigned'; Value = 2235; Format = 'number'; Previous = 2190; TrendIsGood = $true }
    @{ Label = 'MFA coverage'; Value = 89; Unit = '%'; Previous = 84; TrendIsGood = $true; Class = 'cell-warn' }
    @{ Label = 'Open incidents'; Value = 1; Class = 'cell-warn' }
    @{ Label = 'Wasted licence cost'; Value = 6140; Format = 'currency'; Currency = 'EUR'; Locale = 'en-IE'; Decimals = 0; Class = 'cell-danger'; SubLabel = 'per month' }
)

$cells = foreach ($svc in $health) {
    foreach ($d in $days) {
        $st = 'ok'
        if ($svc -eq 'Exchange Online' -and $d -in 'Oct 16', 'Oct 17') { $st = 'warn' }
        if ($svc -eq 'Microsoft Teams' -and $d -eq 'Oct 13') { $st = 'danger' }
        if ($svc -eq 'Intune' -and $d -eq 'Oct 15') { $st = 'warn' }
        @{ Row = $svc; Column = $d; Status = $st }
    }
}
Add-DhStatusGrid -Report $report -Id 'health-grid' -Title 'Service health, last seven days' -NavPath 'Overview' `
    -RowLabel 'Service' -ColumnLabel 'Day' -Rows $health -Columns $days -Cells @($cells)

Add-DhLineChart -Report $report -Id 'active-users' -Title 'Daily active users' -NavPath 'Overview' -Filled `
    -XAxis @('Sep 18', 'Sep 25', 'Oct 02', 'Oct 09', 'Oct 16') -YAxisMin 0 -Series @(
        @{ Label = 'Exchange'; Values = @(1180, 1210, 1195, 1230, 1245); Class = 'cell-ok' }
        @{ Label = 'Teams'; Values = @(980, 1010, 1060, 1100, 1130); Color = '#6264A7' }
        @{ Label = 'SharePoint'; Values = @(640, 655, 660, 700, 712); Color = '#038387' } )

# ============================================================================
# LICENSING
# ============================================================================
Add-DhSummary -Report $report -NavPath 'Licensing' -NavScope Subtree -Items @(
    @{ Label = 'Purchased'; Value = 2510; Format = 'number' }
    @{ Label = 'Assigned'; Value = 2235; Format = 'number' }
    @{ Label = 'Assigned but not used (30d)'; Value = 417; Class = 'cell-warn'; Format = 'number' }
    @{ Label = 'Wasted cost / month'; Value = 6140; Format = 'currency'; Currency = 'EUR'; Locale = 'en-IE'; Decimals = 0; Class = 'cell-danger' }
)

Add-DhTable -Report $report -TableId 'skus' -Title 'Products' -NavPath 'Licensing/Usage' -NavLabel 'Usage' -Data $skus -Columns @(
    @{ Field = 'Product'; Label = 'Product'; PinFirst = $true }
    @{ Field = 'Purchased'; Label = 'Purchased'; Align = 'right'; Aggregate = 'sum' }
    @{ Field = 'Assigned'; Label = 'Assigned'; Align = 'right'; Aggregate = 'sum' }
    @{ Field = 'Active'; Label = 'Active (30d)'; Align = 'right'; Aggregate = 'sum' }
    @{ Field = 'CostPerUser'; Label = 'EUR / user / month'; Align = 'right'; Format = 'currency'; Currency = 'EUR'; Locale = 'en-IE'; Decimals = 0 } )

Add-DhBullet -Report $report -Id 'sku-use' -Title 'Active share of assigned licences' -NavPath 'Licensing/Usage' -Items @(
    foreach ($s in $skus) {
        @{ Label = $s.Product; Value = [math]::Round($s.Active / $s.Assigned * 100); Target = 80; Min = 0; Max = 100; Unit = '%'
           Rag = @{ Green = @{ Min = 80 }; Amber = @{ Min = 50; Max = 80 }; Red = @{ Max = 50 } } }
    } )

Add-DhTable -Report $report -TableId 'unused' -Title 'Licences assigned to inactive users' -NavPath 'Licensing/Unused' -NavLabel 'Unused' -Data $unused -PageSize 10 -Columns @(
    @{ Field = 'User'; Label = 'User'; PinFirst = $true }
    @{ Field = 'Department'; Label = 'Department' }
    @{ Field = 'License'; Label = 'Licence' }
    @{ Field = 'DaysInactive'; Label = 'Days inactive'; Align = 'right'; Rag = @{ Green = @{ Max = 60 }; Amber = @{ Min = 60; Max = 120 }; Red = @{ Min = 120 } } }
    @{ Field = 'MonthlyCost'; Label = 'Cost / month'; Align = 'right'; Format = 'currency'; Currency = 'EUR'; Locale = 'en-IE'; Decimals = 0; Aggregate = 'sum' } )

Add-DhBarChart -Report $report -Id 'waste-by-dept' -Title 'Wasted licence cost by department (EUR / month)' -NavPath 'Licensing/Unused' `
    -TableId 'unused' -Field 'Department' -ValueField 'MonthlyCost' -Aggregate sum -Unit 'EUR'

# ============================================================================
# EXCHANGE ONLINE
# ============================================================================
Add-DhSummary -Report $report -NavPath 'Exchange' -NavLabel 'Exchange Online' -NavScope Subtree -Items @(
    @{ Label = 'Mailboxes'; Value = 1486; Format = 'number' }
    @{ Label = 'Over 90% of quota'; Value = 5; Class = 'cell-warn' }
    @{ Label = 'Spam blocked (24h)'; Value = 18420; Format = 'number' }
    @{ Label = 'Delivery delay'; Value = 'Investigating'; Class = 'cell-warn' }
)

Add-DhTable -Report $report -TableId 'mailboxes' -Title 'Mailboxes' -NavPath 'Exchange/Mailboxes' -NavLabel 'Mailboxes' -Data $mailboxes -PageSize 10 -Columns @(
    @{ Field = 'Mailbox'; Label = 'Mailbox'; PinFirst = $true }
    @{ Field = 'Department'; Label = 'Department' }
    @{ Field = 'Type'; Label = 'Type'; CellType = 'badge' }
    @{ Field = 'SizeGB'; Label = 'Size (GB)'; Align = 'right'; Format = 'number'; Decimals = 1 }
    @{ Field = 'UsedPct'; Label = 'Quota used'; Align = 'right'; CellType = 'progressbar'; ProgressMax = 100
       Rag = @{ Green = @{ Max = 70 }; Amber = @{ Min = 70; Max = 90 }; Red = @{ Min = 90 } } }
    @{ Field = 'Archive'; Label = 'Archive'; CellType = 'badge' } )

Add-DhPieChart -Report $report -Id 'mbx-types' -Title 'Mailbox types' -NavPath 'Exchange/Mailboxes' -TableId 'mailboxes' -Field 'Type' -Style donut -ClickFilters

Add-DhLineChart -Report $report -Id 'mailflow' -Title 'Mail per hour (thousands)' -NavPath 'Exchange/Mail flow' -NavLabel 'Mail flow' `
    -XAxis @('06', '08', '10', '12', '14', '16', '18', '20') -YAxisMin 0 -Series @(
        @{ Label = 'Received'; Values = @(4, 9, 14, 12, 13, 14, 8, 3); Class = 'cell-ok' }
        @{ Label = 'Sent'; Values = @(1, 4, 7, 6, 7, 8, 4, 1); Color = '#666666' }
        @{ Label = 'Spam blocked'; Values = @(2, 3, 5, 4, 5, 6, 3, 1); Class = 'cell-warn' } )

Add-DhKeyValue -Report $report -Id 'mailauth' -Title 'Domain protection' -NavPath 'Exchange/Mail flow' -Columns 4 -Items @(
    @{ Label = 'SPF'; Value = 'Pass, hard fail'; Status = 'ok' }
    @{ Label = 'DKIM'; Value = 'Enabled, 2 of 3 domains'; Status = 'warn' }
    @{ Label = 'DMARC'; Value = 'p=quarantine'; Status = 'warn' }
    @{ Label = 'MTA-STS'; Value = 'Not configured'; Status = 'danger' } )

# ============================================================================
# COLLABORATION
# ============================================================================
Add-DhTable -Report $report -TableId 'teams' -Title 'Teams' -NavPath 'Collaboration/Teams' -NavLabel 'Teams' -Data $teams -PageSize 10 -DetailDrawer -DetailTitleField 'Team' -Columns @(
    @{ Field = 'Team'; Label = 'Team'; PinFirst = $true }
    @{ Field = 'Department'; Label = 'Department' }
    @{ Field = 'Owners'; Label = 'Owners'; Align = 'right'; Rag = @{ Red = @{ Max = 0 }; Green = @{ Min = 1 } } }
    @{ Field = 'Members'; Label = 'Members'; Align = 'right' }
    @{ Field = 'Guests'; Label = 'Guests'; Align = 'right' }
    @{ Field = 'LastActivityDays'; Label = 'Days since activity'; Align = 'right'; Rag = @{ Green = @{ Max = 30 }; Amber = @{ Min = 30; Max = 90 }; Red = @{ Min = 90 } } } )

Add-DhBarChart -Report $report -Id 'teams-by-dept' -Title 'Teams per department' -NavPath 'Collaboration/Teams' -TableId 'teams' -Field 'Department'

Add-DhTable -Report $report -TableId 'sites' -Title 'SharePoint sites' -NavPath 'Collaboration/SharePoint' -NavLabel 'SharePoint' -Data $sites -PageSize 10 -Columns @(
    @{ Field = 'Site'; Label = 'Site'; PinFirst = $true }
    @{ Field = 'Department'; Label = 'Department' }
    @{ Field = 'StorageGB'; Label = 'Storage (GB)'; Align = 'right'; Format = 'number'; Aggregate = 'sum' }
    @{ Field = 'Files'; Label = 'Files'; Align = 'right'; Format = 'number' }
    @{ Field = 'Sharing'; Label = 'Sharing'; CellType = 'badge'
       Thresholds = @(@{ Value = 'Anyone'; Class = 'cell-danger' }, @{ Value = 'Existing guests'; Class = 'cell-warn' }, @{ Value = 'Only people in the organisation'; Class = 'cell-ok' }) } )

Add-DhPieChart -Report $report -Id 'sharing-mix' -Title 'External sharing setting' -NavPath 'Collaboration/SharePoint' -TableId 'sites' -Field 'Sharing' -Style donut -ClickFilters

# ============================================================================
# IDENTITY AND SECURITY
# ============================================================================
Add-DhSummary -Report $report -NavPath 'Identity' -NavLabel 'Identity and security' -NavScope Subtree -Items @(
    @{ Label = 'Users without MFA'; Value = 7; Class = 'cell-danger' }
    @{ Label = 'Admins without MFA'; Value = 0; Class = 'cell-ok' }
    @{ Label = 'High-risk users'; Value = 2; Class = 'cell-danger' }
    @{ Label = 'Risky sign-ins (7d)'; Value = 31; Previous = 44; TrendIsGood = $true }
)

Add-DhTable -Report $report -TableId 'users' -Title 'Users and their sign-in protection' -NavPath 'Identity/MFA' -NavLabel 'MFA' -Data $users -PageSize 10 -DetailDrawer -DetailTitleField 'User' -Columns @(
    @{ Field = 'User'; Label = 'User'; PinFirst = $true }
    @{ Field = 'Department'; Label = 'Department' }
    @{ Field = 'Mfa'; Label = 'MFA method'; CellType = 'badge'
       Thresholds = @(@{ Value = 'None'; Class = 'cell-danger' }, @{ Value = 'SMS'; Class = 'cell-warn' }, @{ Value = 'Authenticator'; Class = 'cell-ok' }, @{ Value = 'FIDO2'; Class = 'cell-ok' }) }
    @{ Field = 'Admin'; Label = 'Admin' }
    @{ Field = 'RiskLevel'; Label = 'Risk'; CellType = 'badge'
       Thresholds = @(@{ Value = 'High'; Class = 'cell-danger' }, @{ Value = 'Medium'; Class = 'cell-warn' }, @{ Value = 'None'; Class = 'cell-ok' }) }
    @{ Field = 'LastSignIn'; Label = 'Last sign-in'; Format = 'datetime'; DatePattern = 'yyyy-MM-dd HH:mm' } )

# declared after its table; it still renders above it
Add-DhBarChart -Report $report -Id 'mfa-methods' -Title 'MFA registration by method' -NavPath 'Identity/MFA' `
    -TableId 'users' -Field 'Mfa' -ClickFilters -KeyClass @{ None = 'cell-danger'; SMS = 'cell-warn'; Authenticator = 'cell-ok'; FIDO2 = 'cell-ok' }

Add-DhRecordList -Report $report -Id 'ca-policies' -Title 'Conditional Access policies' -NavPath 'Identity/Conditional Access' -NavLabel 'Conditional Access' -Items @(
    foreach ($p in $caPolicies) {
        @{ Title = $p.Name; Subtitle = $p.Scope; Status = $p.Status
           Metrics = @(@{ Label = 'State'; Value = $p.State }, @{ Label = 'Grant'; Value = $p.Grant })
           Sections = @(
               @{ Kind = 'kv'; Items = @(@{ Label = 'State'; Value = $p.State; Status = $p.Status }, @{ Label = 'Applies to'; Value = $p.Scope }, @{ Label = 'Control'; Value = $p.Grant }) }
               @{ Kind = 'text'; Text = $(if ($p.Note) { $p.Note } else { 'No remarks.' }) }) }
    } )

Add-DhLineChart -Report $report -Id 'signin-failures' -Title 'Failed sign-ins per day' -NavPath 'Identity/Risk' -NavLabel 'Risk' -XAxis $days -YAxisMin 0 -Series @(
    @{ Label = 'Failed'; Values = @(210, 190, 260, 240, 410, 330, 280); Class = 'cell-warn' }
    @{ Label = 'Blocked by policy'; Values = @(80, 75, 110, 95, 190, 150, 120); Class = 'cell-ok' } )

Add-DhFindings -Report $report -Id 'identity-findings' -Title 'Identity findings' -NavPath 'Identity/Risk' -Layout Split -AllClearText 'No findings.' -Findings @(
    @{ Severity = 'critical'; Area = 'Conditional Access'; Title = 'MFA for guests is switched off'; Change = 'new'
       Description = 'The policy "Require MFA for guests" was disabled on 2026-08-02 and never re-enabled.'
       Recommendation = 'Re-enable the policy, or replace it with one that covers guests and service principals.'
       Facts = @(@{ Label = 'Guests'; Value = '38' }, @{ Label = 'Without MFA'; Value = '38'; Status = 'danger' }) }
    @{ Severity = 'warning'; Area = 'Users'; Title = 'Users with a high risk level'
       Evidence = @(foreach ($u in ($users | Where-Object RiskLevel -eq 'High')) { @{ Object = $u.User; Value = 'High risk'; Status = 'danger' } })
       Recommendation = 'Require a password reset and review recent sign-ins.'; AffectedTableId = 'users' }
    @{ Severity = 'warning'; Area = 'Users'; Title = 'Users still on SMS as the only second factor'
       Recommendation = 'Move them to the Authenticator app or a security key.'; AffectedTableId = 'users' } )

# ============================================================================
# SERVICE HEALTH
# ============================================================================
Add-DhEventFeed -Report $report -Id 'health-feed' -Title 'Service health updates' -NavPath 'Health' -NavLabel 'Service health' -GroupBy Severity -Events @(
    @{ Timestamp = '2026-10-17 09:40'; Severity = 'warning'; Source = 'Exchange Online'; Message = 'EX123456: delayed mail delivery for some users. Mitigation in progress.' }
    @{ Timestamp = '2026-10-16 17:05'; Severity = 'warning'; Source = 'Exchange Online'; Message = 'EX123401: intermittent connection errors for Outlook on the web.' }
    @{ Timestamp = '2026-10-15 11:20'; Severity = 'info'; Source = 'Intune'; Message = 'IT123377: device compliance reports are delayed.' }
    @{ Timestamp = '2026-10-13 14:00'; Severity = 'critical'; Source = 'Microsoft Teams'; Message = 'TM123288: users could not join meetings (resolved after 2 h).' }
    @{ Timestamp = '2026-10-13 16:10'; Severity = 'ok'; Source = 'Microsoft Teams'; Message = 'TM123288 is resolved.' } )

Add-DhTable -Report $report -TableId 'incidents' -Title 'Incidents this week' -NavPath 'Health' -Data @(
    [pscustomobject]@{ Id = 'EX123456'; Service = 'Exchange Online'; Status = 'Investigating'; Started = '2026-10-17 09:00'; Impact = 'Delayed delivery' }
    [pscustomobject]@{ Id = 'EX123401'; Service = 'Exchange Online'; Status = 'Resolved'; Started = '2026-10-16 16:30'; Impact = 'Outlook on the web errors' }
    [pscustomobject]@{ Id = 'IT123377'; Service = 'Intune'; Status = 'Resolved'; Started = '2026-10-15 10:50'; Impact = 'Delayed compliance reports' }
    [pscustomobject]@{ Id = 'TM123288'; Service = 'Microsoft Teams'; Status = 'Resolved'; Started = '2026-10-13 12:00'; Impact = 'Meetings could not be joined' } ) -Columns @(
        @{ Field = 'Id'; Label = 'Incident' }, @{ Field = 'Service'; Label = 'Service' }
        @{ Field = 'Status'; Label = 'Status'; CellType = 'badge'; Thresholds = @(@{ Value = 'Investigating'; Class = 'cell-warn' }, @{ Value = 'Resolved'; Class = 'cell-ok' }) }
        @{ Field = 'Started'; Label = 'Started' }, @{ Field = 'Impact'; Label = 'Impact' } )

# ============================================================================
# ADOPTION
# ============================================================================
$apps = @('Outlook', 'Teams', 'SharePoint', 'OneDrive', 'Word', 'Excel', 'PowerPoint', 'Planner')
Add-DhHeatmap -Report $report -Id 'adoption' -Title 'Active users by app and week' -NavPath 'Adoption' -NavLabel 'Adoption' `
    -Rows $apps -Columns $weeks -RowLabel 'App' -ColumnLabel 'Week' -ColorScale sequential -ShowValues -Cells @(
        foreach ($a in $apps) { $base = 300 + $apps.IndexOf($a) * 90; $k = 0; foreach ($w in $weeks) { @{ Row = $a; Column = $w; Value = [math]::Max(40, $base - $apps.IndexOf($a) * 50 + $k * 12 + ($rng.Next(-20, 20))) }; $k++ } } )

Add-DhRangeBar -Report $report -Id 'adoption-range' -Title 'Weekly active users per app (min, average, max)' -NavPath 'Adoption' `
    -Unit ' users' -Items @(
        foreach ($a in $apps) {
            $i = $apps.IndexOf($a)
            @{ Name = $a; Low = 0; High = 520; Min = 200 - $i * 15; Avg = 330 - $i * 20; Max = 480 - $i * 28 }
        } )
Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
