#Requires -Version 7.0
<#
.SYNOPSIS
    Active Directory operations dashboard (synthetic data).

.DESCRIPTION
    A realistic AD health report, laid out as a menu so that every view answers one question.

    MENU (what opens where)
        Overview                      verdict, score, maturity, headline KPIs, trends
        Replication
            Matrix                    who replicates with whom, with the detail behind each colour
            Topology                  the same links drawn as a map, grouped by site
        Domain controllers            load, headroom, FSMO roles, one row per DC
        Identity
            Accounts                  account states, lockouts, privileged accounts
            Organisation              browse the OU tree, the table follows
            Directory                 objects in their OUs, with group members, member of, nesting
        Findings                      what to fix, with proof per object
        Events                        the last 24 hours

    WHAT IS GLOBAL AND WHAT IS NOT (this is the part to copy)
        * Four compact KPI tiles and one critical banner are declared without a menu path, so
          they stay on screen on EVERY view.
        * "Replication" and "Identity" each have a KPI strip declared with -NavScope Subtree: it
          sits at the top of every view under that menu item, and nowhere else.
        * Everything else has an exact -NavPath and shows on that view only.
        * Inside a view the page order is fixed: banners, global KPI tiles, then blocks in the
          order they were declared, then tables in the order they were declared. So a view reads
          strip, charts, findings, and the table last.

    Run Tools/Show-DhNavMap.ps1 on the result to print the menu and the content of each view.

    All data is synthetic. Replace the data section with real collectors (repadmin, dcdiag,
    Get-ADReplicationPartnerMetadata, Get-ADUser, ...) when adapting.

.PARAMETER OutputPath
    Where to write the HTML. Defaults to Demo-ActiveDirectory.html beside this script.

.PARAMETER Theme
    Default, Azure, VMware, Grey, Company or Rag.

.PARAMETER OpenInBrowser
    Open the dashboard once generated.

.EXAMPLE
    PS> ./Examples/Demo-ActiveDirectory.ps1 -OpenInBrowser
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Demo-ActiveDirectory.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Rag',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force

# ============================================================================
# Data (synthetic, deterministic)
# ============================================================================
$rng = [System.Random]::new(2026)

$dcs = @(
    [pscustomobject]@{ DC='DC01'; Domain='contoso.com';    Site='HQ';    Ip='10.10.1.11'; Os='Windows Server 2022'; Cpu=42; CpuTrend=@(30,42,38,45,48,42,40,42); LdapMs=38; NtdsFree=78; ReplLag=8;   Roles=@('PDC','RID','Schema','Naming','GC') }
    [pscustomobject]@{ DC='DC02'; Domain='contoso.com';    Site='HQ';    Ip='10.10.1.12'; Os='Windows Server 2022'; Cpu=58; CpuTrend=@(40,48,52,58,62,60,58,58); LdapMs=72; NtdsFree=82; ReplLag=14;  Roles=@('Infrastructure','GC') }
    [pscustomobject]@{ DC='DC03'; Domain='contoso.com';    Site='HQ-DR'; Ip='10.20.1.11'; Os='Windows Server 2019'; Cpu=88; CpuTrend=@(60,68,72,80,86,90,92,88); LdapMs=92; NtdsFree=18; ReplLag=180; Roles=@('GC') }
    [pscustomobject]@{ DC='DC04'; Domain='contoso.com';    Site='EU';    Ip='10.30.1.11'; Os='Windows Server 2019'; Cpu=32; CpuTrend=@(28,30,30,32,34,32,30,32); LdapMs=42; NtdsFree=68; ReplLag=22;  Roles=@('GC') }
    [pscustomobject]@{ DC='DC05'; Domain='eu.contoso.com'; Site='EU';    Ip='10.30.2.11'; Os='Windows Server 2022'; Cpu=28; CpuTrend=@(20,22,24,28,30,26,24,28); LdapMs=44; NtdsFree=64; ReplLag=19;  Roles=@('PDC','RID','Infrastructure','GC') }
    [pscustomobject]@{ DC='DC06'; Domain='eu.contoso.com'; Site='APAC';  Ip='10.40.1.11'; Os='Windows Server 2016'; Cpu=$null; CpuTrend=$null; LdapMs=$null; NtdsFree=$null; ReplLag=$null; Roles=@() }
)
$dcNames = $dcs.DC

$hours = @('00:00','02:00','04:00','06:00','08:00','10:00','12:00','14:00','16:00','18:00','20:00','22:00','24:00')

$privileged = @(
    [pscustomobject]@{ Account='adm.rossi';     Type='Admin';   LastLogon='2026-10-16T08:14:00'; PasswordAgeDays=41;  MemberOf=@('Domain Admins','Server Admins'); Path=@('adm.rossi','Server Admins','Tier 0'); Status='OK' }
    [pscustomobject]@{ Account='adm.bianchi';   Type='Admin';   LastLogon='2026-10-15T17:02:00'; PasswordAgeDays=77;  MemberOf=@('Domain Admins'); Path=@('adm.bianchi','Domain Admins','Tier 0'); Status='OK' }
    [pscustomobject]@{ Account='svc_sql';       Type='Service'; LastLogon='2026-10-17T02:00:00'; PasswordAgeDays=1460; MemberOf=@('SQL Admins','Server Operators'); Path=@('svc_sql','SQL Admins','Domain Admins','Tier 0'); Status='Review' }
    [pscustomobject]@{ Account='svc_backup';    Type='Service'; LastLogon='2026-10-17T01:30:00'; PasswordAgeDays=980;  MemberOf=@('Backup Operators'); Path=@('svc_backup','Backup Operators','Tier 0'); Status='Review' }
    [pscustomobject]@{ Account='svc_old_erp';   Type='Service'; LastLogon='2025-12-02T10:11:00'; PasswordAgeDays=2210; MemberOf=@('Account Operators'); Path=@('svc_old_erp','Account Operators','Tier 0'); Status='Stale' }
    [pscustomobject]@{ Account='adm.verdi';     Type='Admin';   LastLogon='2026-03-04T09:45:00'; PasswordAgeDays=230;  MemberOf=@('Enterprise Admins'); Path=@('adm.verdi','Enterprise Admins','Tier 0'); Status='Stale' }
    [pscustomobject]@{ Account='helpdesk.l1';   Type='User';    LastLogon='2026-10-17T07:50:00'; PasswordAgeDays=12;   MemberOf=@('Account Operators'); Path=@('helpdesk.l1','Account Operators','Tier 0'); Status='Review' }
    [pscustomobject]@{ Account='adm.neri';      Type='Admin';   LastLogon='2026-10-14T13:20:00'; PasswordAgeDays=58;   MemberOf=@('Schema Admins'); Path=@('adm.neri','Schema Admins','Tier 0'); Status='OK' }
)

$ouRows = @(
    @{ Name='contoso.com';           Path='contoso.com';                              Objects=0   }
    @{ Name='Headquarters';          Path='contoso.com/Headquarters';                 Objects=12  }
    @{ Name='Servers';               Path='contoso.com/Headquarters/Servers';         Objects=48  }
    @{ Name='Workstations';          Path='contoso.com/Headquarters/Workstations';    Objects=310 }
    @{ Name='Service accounts';      Path='contoso.com/Headquarters/Service accounts'; Objects=27 }
    @{ Name='Headquarters (legacy)'; Path='contoso.com/Headquarters (legacy)';        Objects=3   }
    @{ Name='Branches';              Path='contoso.com/Branches';                     Objects=0   }
    @{ Name='Milan';                 Path='contoso.com/Branches/Milan';               Objects=64  }
    @{ Name='Turin';                 Path='contoso.com/Branches/Turin';               Objects=41  }
    @{ Name='Disabled';              Path='contoso.com/Disabled';                     Objects=0   }
) | ForEach-Object {
    [pscustomobject]@{
        OU = $_.Name; CanonicalName = $_.Path
        DistinguishedName = 'OU=' + (($_.Path -split '/')[-1]) + ',DC=contoso,DC=com'
        Objects = $_.Objects
        LinkedGpos = ('Default Domain Policy', 'Workstation baseline', 'Server hardening', 'Audit policy', 'Kerberos settings')[0..([math]::Min(4, $_.Objects % 5))] -join '; '
    }
}

$utilRag = @{ Green = @{ Max = 70 }; Amber = @{ Min = 70; Max = 90 }; Red = @{ Min = 90 }; NoData = $true }
$freeRag = @{ Green = @{ Min = 30 }; Amber = @{ Min = 15; Max = 30 }; Red = @{ Max = 15 }; NoData = $true }

$report = New-DhDashboard -Title 'Active Directory Operations' `
    -Subtitle 'Forest contoso.com, last 24 hours' -Theme $Theme -NavTitle 'AD' -NavMaxDepth 2 `
    -GeneratedBy 'Demo-ActiveDirectory.ps1' -InfoFields @(
        @{ Label = 'Forest';    Value = 'contoso.com' }
        @{ Label = 'Domains';   Value = 'contoso.com, eu.contoso.com' }
        @{ Label = 'Sites';     Value = '5' }
        @{ Label = 'Generated'; Value = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
    )

# ============================================================================
# GLOBAL: no menu path, so these stay on screen on every view
# ============================================================================
Add-DhAlertBanner -Report $report -Id 'repl-alert' -Severity critical -Icon '!' -Dismissible `
    -Message 'Inbound replication from DC01 to DC03 has failed for 12 minutes (error 1722, RPC server unavailable).' `
    -Action @{ Label = 'Show DC03'; TableId = 'dcs'; Filter = 'DC03' }

Add-DhSummary -Report $report -Items @(
    @{ Label = 'DCs online';    Value = '5/6';  Class = 'cell-warn' }
    @{ Label = 'Repl errors';   Value = 3;      Previous = 0;  TrendIsGood = $false; Class = 'cell-warn' }
    @{ Label = 'Lockouts (1h)'; Value = 12;     Previous = 18; TrendIsGood = $true }
    @{ Label = 'Failed logons'; Value = 842;    Previous = 920; TrendIsGood = $true; Format = 'number' }
)

# ============================================================================
# OVERVIEW
# ============================================================================
Add-DhSummary -Report $report -NavPath 'Overview' -NavLabel 'Overview' -Items @(
    @{ Style = 'verdict'; Label = 'Overall'; Value = 'Attention needed'
       Caption = 'Replication to DC03 and two account findings need action.'
       Counts = @{ critical = 1; warning = 3; info = 1 } }
    @{ Style = 'score'; Label = 'AD health score'; Value = 78; Caption = 'Fair'; Previous = 74
       Facts = @('64 checks', '9 failed', '11 warnings'); NotAssessed = 6
       Rag = @{ Red = @{ Max = 50 }; Amber = @{ Min = 50; Max = 80 }; Green = @{ Min = 80 } } }
    @{ Style = 'maturity'; Label = 'Operational maturity'; Value = 'Managed'; Current = 2
       Caption = 'Monitoring is in place; standards are not yet written down.'
       Levels = @(
           @{ Name = 'Initial';   Description = 'Ad hoc.' }
           @{ Name = 'Managed';   Description = 'Monitored, basic hygiene.' }
           @{ Name = 'Defined';   Description = 'Documented standards, applied everywhere.' }
           @{ Name = 'Measured';  Description = 'Compliance measured and trended.' }
           @{ Name = 'Optimised'; Description = 'Continuous improvement.' })
       Criteria = @(
           @{ Level = 3; Text = 'Document the DC build standard'; Met = $false }
           @{ Level = 3; Text = 'Alert on every replication failure'; Met = $true }
           @{ Level = 3; Text = 'Review privileged group membership quarterly'; Met = $false }) }
    @{ Style = 'bignumber'; Label = 'AD uptime (30 days)'; Value = '99.94%'
       Caption = 'Target 99.9%, met'; Class = 'cell-ok' }
    @{ Label = 'LDAP bind p95'; Value = 68; Previous = 54; TrendIsGood = $false; SubLabel = 'ms'; Class = 'cell-warn'
       Sparkline = @(41, 44, 48, 52, 58, 64, 68); SparklineStyle = 'line' }
    @{ Label = 'DNS success'; Value = 99.94; Previous = 99.92; Format = 'percent'; Decimals = 2; Class = 'cell-ok' }
)

Add-DhLineChart -Report $report -Id 'auth-trend' -Title 'Authentication requests per second (24h)' -NavPath 'Overview' `
    -Filled -XAxis $hours -YAxisMin 0 -YAxisUnit ' req/s' -Series @(
        @{ Label = 'Kerberos AS';   Values = @(180,160,150,200,420,820,1100,1180,1240,1100,820,520,290);       Class = 'cell-ok' }
        @{ Label = 'Kerberos TGS';  Values = @(420,380,360,480,920,1820,2400,2520,2680,2440,1820,1180,640);    Color = '#4B5B6B' }
        @{ Label = 'NTLM (legacy)'; Values = @(80,70,60,90,180,320,420,440,460,400,310,180,120);               Class = 'cell-warn' } )

Add-DhPieChart -Report $report -Id 'account-states' -Title 'Account states' -NavPath 'Overview' -Style donut -Slices @(
    @{ Label = 'Enabled';       Value = 15420; Color = '#375623' }
    @{ Label = 'Disabled';      Value = 820;   Color = '#7F4B00' }
    @{ Label = 'Locked';        Value = 42;    Color = '#9C0006' }
    @{ Label = 'Stale (>180d)'; Value = 214;   Color = '#595959' } )

# ============================================================================
# REPLICATION  (a strip for the whole branch, then one view per question)
# ============================================================================
Add-DhSummary -Report $report -NavPath 'Replication' -NavScope Subtree -Items @(
    @{ Label = 'Failing links';  Value = 1; Previous = 0; TrendIsGood = $false; Class = 'cell-danger' }
    @{ Label = 'Max lag';        Value = 180; SubLabel = 'seconds'; Class = 'cell-danger' }
    @{ Label = 'Partners';       Value = 30 }
    @{ Label = 'Last full sync'; Value = '14:32' }
)

# Matrix
$bad = 'DC03|DC01'     # target|source
$cells = foreach ($to in $dcNames) {
    foreach ($from in $dcNames) {
        if ($to -eq $from) { continue }
        $key = "$to|$from"
        $st = if ($key -eq $bad) { 'danger' } elseif ($to -eq 'DC06' -or $from -eq 'DC06') { 'nodata' } elseif ($to -eq 'DC03' -or $from -eq 'DC03') { 'warn' } else { 'ok' }
        $ncs = 'Domain', 'Configuration', 'Schema', 'DomainDnsZones'
        @{ Row = $to; Column = $from; Status = $st
           Glyph = $(if ($st -eq 'ok') { [string][char]0x2713 } elseif ($st -eq 'danger') { [string][char]0x2717 } else { '' })
           Tooltip = "$to replicates from $from"; LinkTableId = 'dcs'; LinkFilter = $to
           Detail = @{ Title = "$to from $from"; Sections = @(
               @{ Kind = 'kv'; Title = 'Partnership'; Columns = 2; Items = @(
                   @{ Label = 'Destination'; Value = $to }, @{ Label = 'Source'; Value = $from }
                   @{ Label = 'Last success'; Value = $(if ($st -eq 'danger') { '12 minutes ago' } elseif ($st -eq 'nodata') { 'no data' } else { '3 minutes ago' }); Status = $st }
                   @{ Label = 'Failures in a row'; Value = $(if ($st -eq 'danger') { '4' } else { '0' }) }) }
               @{ Kind = 'statusList'; Title = 'Naming contexts'; Items = @($ncs | ForEach-Object {
                   @{ Label = $_; Status = $(if ($st -eq 'danger' -and $_ -eq 'Configuration') { 'danger' } elseif ($st -eq 'nodata') { 'nodata' } else { 'ok' })
                      Text = $(if ($st -eq 'danger' -and $_ -eq 'Configuration') { 'Failing' } elseif ($st -eq 'nodata') { 'Unknown' } else { 'In sync' }) } }) }
               @{ Kind = 'text'; Title = 'What to do'; Text = $(if ($st -eq 'danger') { 'Check RPC between the two sites, then run repadmin /syncall /AdeP.' } else { 'Nothing to do.' }) }) } }
    }
}
Add-DhStatusGrid -Report $report -Id 'repl-matrix' -Title 'Inbound replication matrix' -NavPath 'Replication/Matrix' -NavLabel 'Matrix' `
    -RowLabel 'Destination' -ColumnLabel 'Source' -Rows $dcNames -Columns $dcNames -SelfDiagonal -Cells @($cells)

Add-DhLineChart -Report $report -Id 'repl-latency' -Title 'Replication latency per link' -NavPath 'Replication/Matrix' `
    -XAxis $hours -YAxisMin 0 -YAxisUnit ' s' -TargetLine 60 -TargetLabel 'SLA 60 s' -Series @(
        @{ Label = 'DC01 to DC02'; Values = @(8,7,9,8,12,10,14,18,22,16,14,12,11);                Class = 'cell-ok' }
        @{ Label = 'DC01 to DC03'; Values = @(14,16,18,22,38,44,72,180,$null,$null,68,42,32);     Class = 'cell-warn' }
        @{ Label = 'DC01 to DC04'; Values = @(11,10,12,14,18,22,26,32,38,30,24,20,18);            Color = '#666666' } )

# Topology (same data as the matrix, drawn as a map)
Add-DhNetworkMap -Report $report -Id 'repl-map' -Title 'Replication topology' -NavPath 'Replication/Topology' -NavLabel 'Topology' -Legend `
    -Groups @(
        @{ Id = 'hq';   Label = 'HQ site' }
        @{ Id = 'hqdr'; Label = 'HQ-DR site'; Status = 'warn' }
        @{ Id = 'eu';   Label = 'EU site' }
        @{ Id = 'apac'; Label = 'APAC site'; Status = 'nodata' } ) `
    -Nodes @(
        @{ Id = 'DC01'; Label = 'DC01'; Group = 'hq';   Badge = @('PDC', 'RID', 'GC'); Status = 'ok'; LinkTableId = 'dcs'; LinkFilter = 'DC01' }
        @{ Id = 'DC02'; Label = 'DC02'; Group = 'hq';   Badge = @('GC'); Status = 'ok'; LinkTableId = 'dcs'; LinkFilter = 'DC02' }
        @{ Id = 'DC03'; Label = 'DC03'; Group = 'hqdr'; Badge = @('GC'); Status = 'danger'; Tooltip = 'Inbound from DC01 failing for 12 minutes'
           Detail = @{ Title = 'DC03'; Sections = @(@{ Kind = 'kv'; Items = @(@{ Label = 'Site'; Value = 'HQ-DR' }, @{ Label = 'Last inbound success'; Value = '12 minutes ago'; Status = 'danger' }) }) }
           LinkTableId = 'dcs'; LinkFilter = 'DC03' }
        @{ Id = 'DC04'; Label = 'DC04'; Group = 'eu';   Badge = @('GC'); Status = 'ok'; LinkTableId = 'dcs'; LinkFilter = 'DC04' }
        @{ Id = 'DC05'; Label = 'DC05'; Group = 'eu';   Badge = @('PDC', 'GC'); Status = 'ok'; LinkTableId = 'dcs'; LinkFilter = 'DC05' }
        @{ Id = 'DC06'; Label = 'DC06'; Group = 'apac'; Status = 'nodata'; Tooltip = 'No data collected' } ) `
    -Edges @(
        @{ From = 'DC01'; To = 'DC02'; Label = '15 s'; Direction = 'both'; Status = 'ok' }
        @{ From = 'DC04'; To = 'DC05'; Label = '15 s'; Direction = 'both'; Status = 'ok' }
        @{ From = 'DC01'; To = 'DC03'; Label = 'cost 100, 15 min'; Direction = 'forward'; Status = 'danger'; Style = 'dashed'; Tooltip = 'Failing: error 1722' }
        @{ From = 'DC03'; To = 'DC01'; Label = 'cost 100, 15 min'; Direction = 'forward'; Status = 'ok' }
        @{ From = 'DC01'; To = 'DC04'; Label = 'cost 200, 30 min'; Direction = 'both'; Status = 'ok' }
        @{ From = 'DC05'; To = 'DC06'; Label = 'cost 400, 60 min'; Direction = 'both'; Status = 'nodata'; Style = 'dashed' } )

# ============================================================================
# DOMAIN CONTROLLERS  (table last on the page; the charts above it read from it)
# ============================================================================
Add-DhTable -Report $report -TableId 'dcs' -Title 'Domain controllers' -NavPath 'DomainControllers' -NavLabel 'Domain controllers' `
    -Data $dcs -DetailDrawer -DetailTitleField 'DC' -Columns @(
        @{ Field = 'DC';       Label = 'DC'; PinFirst = $true }
        @{ Field = 'Domain';   Label = 'Domain' }
        @{ Field = 'Site';     Label = 'Site' }
        @{ Field = 'Os';       Label = 'Operating system' }
        @{ Field = 'Roles';    Label = 'Roles'; CellType = 'chips' }
        @{ Field = 'Cpu';      Label = 'CPU %'; Align = 'right'; CellType = 'progressbar'; ProgressMax = 100; Rag = $utilRag }
        @{ Field = 'CpuTrend'; Label = 'CPU 8h'; CellType = 'sparkline'; SortBy = 'max'; SparklineStyle = 'area' }
        @{ Field = 'LdapMs';   Label = 'LDAP ms'; Align = 'right'; Rag = @{ Green = @{ Max = 50 }; Amber = @{ Min = 50; Max = 80 }; Red = @{ Min = 80 }; NoData = $true } }
        @{ Field = 'NtdsFree'; Label = 'NTDS free %'; Align = 'right'; Rag = $freeRag }
        @{ Field = 'ReplLag';  Label = 'Repl lag (s)'; Align = 'right'; Rag = @{ Green = @{ Max = 30 }; Amber = @{ Min = 30; Max = 60 }; Red = @{ Min = 60 }; NoData = $true } }
    )

Add-DhBarChart -Report $report -Id 'ldap-by-site' -Title 'Average LDAP bind time by site' -NavPath 'DomainControllers' `
    -TableId 'dcs' -Field 'Site' -ValueField 'LdapMs' -Aggregate avg -Unit 'ms' -Decimals 0

Add-DhBullet -Report $report -Id 'ntds-free' -Title 'NTDS volume free space' -NavPath 'DomainControllers' -Items @(
    foreach ($d in $dcs) { @{ Label = $d.DC; Value = $d.NtdsFree; Target = 30; Min = 0; Max = 100; Unit = '%'; Rag = $freeRag } } )

Add-DhKeyValue -Report $report -Id 'fsmo' -Title 'FSMO role holders' -NavPath 'DomainControllers' -Columns 4 -Items @(
    @{ Label = 'PDC emulator (contoso.com)';             Value = 'DC01'; Status = 'ok' }
    @{ Label = 'RID master (contoso.com)';               Value = 'DC01'; Status = 'ok' }
    @{ Label = 'Infrastructure master (contoso.com)';    Value = 'DC02'; Status = 'ok' }
    @{ Label = 'Schema master (forest)';                 Value = 'DC01'; Status = 'ok' }
    @{ Label = 'Domain naming master (forest)';          Value = 'DC01'; Status = 'ok' }
    @{ Label = 'PDC emulator (eu.contoso.com)';          Value = 'DC05'; Status = 'ok' }
    @{ Label = 'RID master (eu.contoso.com)';            Value = 'DC05'; Status = 'ok' }
    @{ Label = 'Infrastructure master (eu.contoso.com)'; Value = 'DC05'; Status = 'ok' } )

# ============================================================================
# IDENTITY
# ============================================================================
Add-DhSummary -Report $report -NavPath 'Identity' -NavScope Subtree -Items @(
    @{ Label = 'Privileged accounts'; Value = 8 }
    @{ Label = 'Stale privileged';    Value = 2; Previous = 1; TrendIsGood = $false; Class = 'cell-warn' }
    @{ Label = 'Password never expires'; Value = 37; Previous = 41; TrendIsGood = $true }
    @{ Label = 'Locked now';          Value = 42; Class = 'cell-warn' }
)

Add-DhLineChart -Report $report -Id 'lockouts' -Title 'Account lockouts per hour' -NavPath 'Identity/Accounts' -NavLabel 'Accounts' `
    -XAxis $hours -YAxisMin 0 -TargetLine 20 -TargetLabel 'Alert threshold' -Series @(
        @{ Label = 'Lockouts'; Values = @(2,1,1,3,8,14,12,9,11,10,6,3,2); Class = 'cell-warn' } )

Add-DhTable -Report $report -TableId 'privileged' -Title 'Privileged accounts' -NavPath 'Identity/Accounts' `
    -Data $privileged -DetailDrawer -DetailTitleField 'Account' -Columns @(
        @{ Field = 'Account';  Label = 'Account'; PinFirst = $true }
        @{ Field = 'Type';     Label = 'Type'; CellType = 'badge'
           Thresholds = @(@{ Value = 'Admin'; Class = 'cell-warn' }, @{ Value = 'Service'; Class = 'cell-nodata' }, @{ Value = 'User'; Class = 'cell-ok' }) }
        @{ Field = 'MemberOf'; Label = 'Member of'; CellType = 'chips' }
        @{ Field = 'Path';     Label = 'Path to Tier 0'; CellType = 'path' }
        @{ Field = 'LastLogon'; Label = 'Last logon'; Format = 'datetime'; DatePattern = 'yyyy-MM-dd HH:mm' }
        @{ Field = 'PasswordAgeDays'; Label = 'Password age (days)'; Align = 'right'; Format = 'number'
           Rag = @{ Green = @{ Max = 90 }; Amber = @{ Min = 90; Max = 365 }; Red = @{ Min = 365 } } }
        @{ Field = 'Status';   Label = 'Status'; CellType = 'badge'
           Thresholds = @(@{ Value = 'OK'; Class = 'cell-ok' }, @{ Value = 'Review'; Class = 'cell-warn' }, @{ Value = 'Stale'; Class = 'cell-danger' }) }
    )

Add-DhBarChart -Report $report -Id 'privileged-by-type' -Title 'Privileged accounts by type' -NavPath 'Identity/Accounts' `
    -TableId 'privileged' -Field 'Type' -ClickFilters -KeyClass @{ Admin = 'cell-warn'; Service = 'cell-nodata'; User = 'cell-ok' }

Add-DhTable -Report $report -TableId 'ous' -Title 'Organisational units' -NavPath 'Identity/Organisation' -NavLabel 'Organisation' `
    -Data $ouRows -DetailDrawer -DetailTitleField 'OU' -Columns @(
        @{ Field = 'OU';                Label = 'OU' }
        @{ Field = 'CanonicalName';     Label = 'Canonical name' }
        @{ Field = 'DistinguishedName'; Label = 'Distinguished name' }
        @{ Field = 'Objects';           Label = 'Objects'; Align = 'right'; Format = 'number' }
        @{ Field = 'LinkedGpos';        Label = 'Linked GPOs' } )

Add-DhTreeFilter -Report $report -Id 'ou-tree' -Title 'Browse by OU' -NavPath 'Identity/Organisation' `
    -TableId 'ous' -PathField 'CanonicalName' -CountFromTable -Nodes @(
        @{ Id = 'root'; Label = 'contoso.com'; Path = 'contoso.com' }
        @{ Id = 'hq';   Parent = 'root'; Label = 'Headquarters'; Path = 'contoso.com/Headquarters'; Status = 'ok' }
        @{ Id = 'srv';  Parent = 'hq';   Label = 'Servers'; Path = 'contoso.com/Headquarters/Servers' }
        @{ Id = 'wks';  Parent = 'hq';   Label = 'Workstations'; Path = 'contoso.com/Headquarters/Workstations'; Flags = @('large') }
        @{ Id = 'svc';  Parent = 'hq';   Label = 'Service accounts'; Path = 'contoso.com/Headquarters/Service accounts'; Status = 'warn'
           Detail = @{ Sections = @(@{ Kind = 'text'; Text = 'Accounts here have passwords that never expire. See the Findings view.' }) } }
        @{ Id = 'leg';  Parent = 'root'; Label = 'Headquarters (legacy)'; Path = 'contoso.com/Headquarters (legacy)'; Flags = @('empty') }
        @{ Id = 'brn';  Parent = 'root'; Label = 'Branches'; Path = 'contoso.com/Branches' }
        @{ Id = 'mil';  Parent = 'brn';  Label = 'Milan'; Path = 'contoso.com/Branches/Milan' }
        @{ Id = 'tur';  Parent = 'brn';  Label = 'Turin'; Path = 'contoso.com/Branches/Turin' }
        @{ Id = 'dis';  Parent = 'root'; Label = 'Disabled'; Path = 'contoso.com/Disabled'; Flags = @('empty') } )

# Directory explorer: objects in their OUs, with group membership and nesting.
# The data is two flat lists (Rows and Memberships), so a collector can emit it without recursion.
Add-DhTreeTable -Report $report -Id 'directory' -Title 'Directory objects' -NavPath 'Identity/Directory' -NavLabel 'Directory' -DefaultOpenDepth 1 -Rows @(
    @{ Id = 'ou-hq';   Type = 'ou'; Label = 'Headquarters' }
    @{ Id = 'ou-grp';  ParentId = 'ou-hq'; Type = 'ou'; Label = 'Groups' }
    @{ Id = 'ou-svc';  ParentId = 'ou-hq'; Type = 'ou'; Label = 'Service accounts' }
    @{ Id = 'ou-adm';  ParentId = 'ou-hq'; Type = 'ou'; Label = 'Administrators' }
    @{ Id = 'ou-srv';  ParentId = 'ou-hq'; Type = 'ou'; Label = 'Servers' }
    @{ Id = 'g-da';    ParentId = 'ou-grp'; Type = 'group'; Label = 'Domain Admins'; Status = 'warn'; Flags = @('privileged')
       Properties = [ordered]@{ 'Distinguished name' = 'CN=Domain Admins,OU=Groups,OU=Headquarters,DC=contoso,DC=com'; 'Scope' = 'Global'; 'Description' = 'Designated administrators of the domain' } }
    @{ Id = 'g-sql';   ParentId = 'ou-grp'; Type = 'group'; Label = 'SQL Admins'; Flags = @('nested')
       Properties = [ordered]@{ 'Scope' = 'Global'; 'Managed by' = 'Database team' } }
    @{ Id = 'g-srv';   ParentId = 'ou-grp'; Type = 'group'; Label = 'Server Admins'; Properties = [ordered]@{ 'Scope' = 'Global' } }
    @{ Id = 'g-bkp';   ParentId = 'ou-grp'; Type = 'group'; Label = 'Backup Operators'; Flags = @('privileged'); Status = 'warn' }
    @{ Id = 'g-ops';   ParentId = 'ou-grp'; Type = 'group'; Label = 'Operations'; Status = 'danger'; Flags = @('circular')
       Detail = 'Operations is a member of SQL Admins and SQL Admins is a member of Operations. Remove one of the two memberships.' }
    @{ Id = 'u-rossi'; ParentId = 'ou-adm'; Type = 'user'; Label = 'adm.rossi'; Properties = [ordered]@{ 'Last logon' = '2026-10-16 08:14'; 'Password age' = '41 days' } }
    @{ Id = 'u-bianchi'; ParentId = 'ou-adm'; Type = 'user'; Label = 'adm.bianchi'; Properties = [ordered]@{ 'Last logon' = '2026-10-15 17:02'; 'Password age' = '77 days' } }
    @{ Id = 'u-sql';   ParentId = 'ou-svc'; Type = 'user'; Label = 'svc_sql'; Status = 'danger'; Flags = @('stale password')
       Properties = [ordered]@{ 'Last logon' = '2026-10-17 02:00'; 'Password age' = '1460 days'; 'Service principal' = 'MSSQLSvc/sql01.contoso.com' } }
    @{ Id = 'u-bkp';   ParentId = 'ou-svc'; Type = 'user'; Label = 'svc_backup'; Status = 'warn'; Properties = [ordered]@{ 'Password age' = '980 days' } }
    @{ Id = 'c-sql01'; ParentId = 'ou-srv'; Type = 'computer'; Label = 'SQL01'; Properties = [ordered]@{ 'Operating system' = 'Windows Server 2022'; 'Site' = 'HQ' } }
    @{ Id = 'c-app01'; ParentId = 'ou-srv'; Type = 'computer'; Label = 'APP01'; Properties = [ordered]@{ 'Operating system' = 'Windows Server 2019'; 'Site' = 'HQ' } } ) `
    -Memberships @(
        @{ GroupId = 'g-da';  MemberId = 'u-bianchi' }
        @{ GroupId = 'g-da';  MemberId = 'g-srv' }
        @{ GroupId = 'g-da';  MemberId = 'g-sql' }
        @{ GroupId = 'g-srv'; MemberId = 'u-rossi' }
        @{ GroupId = 'g-srv'; MemberId = 'c-app01' }
        @{ GroupId = 'g-sql'; MemberId = 'u-sql' }
        @{ GroupId = 'g-sql'; MemberId = 'g-ops' }
        @{ GroupId = 'g-ops'; MemberId = 'g-sql' }
        @{ GroupId = 'g-ops'; MemberId = 'c-sql01' }
        @{ GroupId = 'g-bkp'; MemberId = 'u-bkp' } )
# ============================================================================
# FINDINGS
# ============================================================================
Add-DhFindings -Report $report -Id 'ad-findings' -Title 'Findings' -NavPath 'Findings' -NavLabel 'Findings' -Layout Split -GroupBy Area `
    -AllClearText 'Nothing to fix.' -Findings @(
    @{ Severity = 'critical'; Area = 'Replication'; Title = 'Inbound replication from DC01 to DC03 is stalled'; Change = 'new'
       Description = 'DC03 has not completed inbound replication from DC01 for 12 minutes (error 1722, RPC server unavailable).'
       Recommendation = 'Check RPC connectivity from DC03 to DC01, then run repadmin /syncall DC03 /AdeP.'
       Facts = @(@{ Label = 'Threshold'; Value = '15 min intra-site' }, @{ Label = 'Stalled for'; Value = '12 min'; Status = 'danger' })
       Evidence = @(@{ Object = 'DC03 from DC01'; Value = 'error 1722'; Status = 'danger'; Note = 'RPC server unavailable' }, @{ Object = 'DC03 from DC02'; Value = 'OK'; Status = 'ok' })
       AffectedTableId = 'dcs'
       References = @(@{ Label = 'Troubleshoot error 1722'; Url = 'https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/replication-error-1722-rpc-server-unavailable' }) }
    @{ Severity = 'warning'; Area = 'Capacity'; Title = 'NTDS volume is low on DC03'; Change = 'worse'
       Description = '18% free on the NTDS volume.'; Recommendation = 'Extend the volume or move the transaction logs.'
       Affected = @('DC03'); AffectedTableId = 'dcs'
       Evidence = @(@{ Object = 'DC03'; Value = '18% free'; Status = 'warn' }, @{ Object = 'DC02'; Value = '82% free'; Status = 'ok' }) }
    @{ Severity = 'warning'; Area = 'Identity'; Title = 'Service accounts in privileged groups have very old passwords'
       Description = 'Three service accounts have a password older than three years and can reach Tier 0.'
       Recommendation = 'Move them to group-managed service accounts, or rotate the passwords and remove the group memberships.'
       Affected = @('svc_sql', 'svc_backup', 'svc_old_erp'); AffectedTableId = 'privileged'
       Evidence = @(@{ Object = 'svc_old_erp'; Value = '2210 days'; Status = 'danger' }, @{ Object = 'svc_sql'; Value = '1460 days'; Status = 'danger' }, @{ Object = 'svc_backup'; Value = '980 days'; Status = 'warn' }) }
    @{ Severity = 'warning'; Area = 'Identity'; Title = 'Two privileged accounts have not logged on for months'
       Recommendation = 'Disable or remove adm.verdi and svc_old_erp.'; Affected = @('adm.verdi', 'svc_old_erp'); AffectedTableId = 'privileged' }
    @{ Severity = 'info'; Area = 'Monitoring'; Title = 'No data from DC06'; Change = 'resolved'
       Description = 'The APAC DC returned no performance data in this run.'; Affected = @('DC06') }
)

# ============================================================================
# EVENTS
# ============================================================================
Add-DhEventFeed -Report $report -Id 'events' -Title 'Recent events (24h)' -NavPath 'Events' -NavLabel 'Events' -MaxItems 50 -GroupBy Severity -Events @(
    @{ Timestamp = '2026-10-17 14:32'; Severity = 'critical'; Source = 'DC03';    Message = 'Replication failure from DC01 (error 1722)' }
    @{ Timestamp = '2026-10-17 14:18'; Severity = 'warning';  Source = 'DC02';    Message = 'LDAP bind time above 80 ms (60 s average)' }
    @{ Timestamp = '2026-10-17 13:55'; Severity = 'warning';  Source = 'DC03';    Message = 'NTDS volume 82% used' }
    @{ Timestamp = '2026-10-17 12:42'; Severity = 'ok';       Source = 'Backup';  Message = 'Nightly DIT snapshot completed in 38 minutes' }
    @{ Timestamp = '2026-10-17 10:05'; Severity = 'info';     Source = 'Patch';   Message = 'Cumulative update deployed to 5 DCs' }
    @{ Timestamp = '2026-10-17 09:30'; Severity = 'critical'; Source = 'Auth';    Message = 'Sustained spike in failed logons (1200/min from one egress range)' }
    @{ Timestamp = '2026-10-17 08:14'; Severity = 'info';     Source = 'GPO';     Message = 'Policy processed across 5 DCs in 12 s' }
    @{ Timestamp = '2026-10-17 02:00'; Severity = 'ok';       Source = 'Sites';   Message = 'Site link cost recalculation complete' } )

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
