#Requires -Version 7.0
<#
.SYNOPSIS
    DashHtml v1.4 — Active Directory ops dashboard example.

.DESCRIPTION
    Mirrors the IT-infrastructure KPI dashboard specification §4.1 layout:

        Row 1 — KPI Cards (DCs Online, Repl Errors, Lockouts, Failed Logins,
                LDAP ms, DNS Success %)
        Row 2 — Trend charts (Auth Requests/s, Replication Latency, LDAP ops)
        Row 3 — Inventory & Security (Account states donut, DC replication
                status matrix, Top DCs by CPU with sparkline)
        Row 4 — FSMO & Compliance (FSMO roles status grid, NTDS disk progress,
                patch compliance bullet)
        Row 5 — Event feed (recent errors & warnings)

    All data is SYNTHETIC — this file is a runnable showcase of the v1.4
    cmdlet set. Replace the data hashes with output from your real source
    (DCDIAG, RepAdmin, Get-ADReplicationFailure, etc.) when adapting.

.EXAMPLE
    PS> .\Examples\AD-Dashboard.ps1
    Opens an HTML dashboard in the default browser.
#>

Import-Module "$PSScriptRoot\..\DashHtml\DashHtml.psd1" -Force

# Reusable RAG bands — defined once and shared across tiles, gauges, columns ----
$utilRag = @{
    Green = @{ Max = 70 }
    Amber = @{ Min = 70; Max = 90 }
    Red   = @{ Min = 90 }
    NoData = $true
}
$lagRag = @{   # replication lag in seconds — lower is better
    Green = @{ Max = 30 }
    Amber = @{ Min = 30; Max = 60 }
    Red   = @{ Min = 60 }
    NoData = $true
}

# --- New dashboard --------------------------------------------------------------
$report = New-DhDashboard -Title 'Active Directory Operations' `
    -Subtitle 'Forest contoso.com — last 24 hours' `
    -Theme Rag `
    -InfoFields @(
        @{ Label='Forest';     Value='contoso.com' }
        @{ Label='Domains';    Value='contoso.com, eu.contoso.com' }
        @{ Label='Sites';      Value='5' }
        @{ Label='Generated';  Value=(Get-Date -Format 'yyyy-MM-dd HH:mm') }
    )

# --- Row 5 — Event feed defined first so we can link to it from cards ---------
# (Added at end of body declaration; defining the data up-front keeps it close
#  to the rest of the dataset.)
$events = @(
    @{ Timestamp='2026-05-22 14:32'; Severity='critical'; Source='DC03';    Message='Replication failure from DC01 (KDC: error 1722)' }
    @{ Timestamp='2026-05-22 14:18'; Severity='warning';  Source='DC02';    Message='LDAP bind time > 80 ms (avg over 60s window)' }
    @{ Timestamp='2026-05-22 13:55'; Severity='warning';  Source='DC04';    Message='High NTDS disk usage: 82% on E:\NTDS' }
    @{ Timestamp='2026-05-22 12:42'; Severity='ok';       Source='Backup';  Message='Nightly DIT snapshot completed in 38 minutes' }
    @{ Timestamp='2026-05-22 11:18'; Severity='warning';  Source='DC02';    Message='Disk free 18% on NTDS volume — investigate' }
    @{ Timestamp='2026-05-22 10:05'; Severity='info';     Source='Patch';   Message='KB5044277 deployed to 12 DCs' }
    @{ Timestamp='2026-05-22 09:30'; Severity='critical'; Source='Auth';    Message='Sustained spike in failed logons (1200/min from EU egress range)' }
    @{ Timestamp='2026-05-22 08:14'; Severity='info';     Source='GPO';     Message='Policy {3F4E2B…} processed across 8 DCs in 12s' }
    @{ Timestamp='2026-05-22 07:02'; Severity='info';     Source='Replica'; Message='vt_change_notify completed across all sites' }
    @{ Timestamp='2026-05-22 02:00'; Severity='ok';       Source='Cron';    Message='Site link cost recalculation complete' }
)

# ============================================================================
# Row 1 — KPI tiles (with deltas and sparklines)
#
# Tip: -Style='bignumber' renders a full-width hero metric. Mix it with the
# default compact tiles to give the headline number proportional weight.
# The Icon field accepts any string — emoji like '🖥' / '⚠' / '🔒' render
# cross-platform, or pass HTML if you use a font-icon library. Leave it
# unset for a clean iconless tile (used here for readability).
# ============================================================================
Add-DhSummary -Report $report -Title 'Active Directory health at a glance' -Items @(
    @{ Style='bignumber'; Label='Current AD uptime'; Value='99.94%'
       Caption='Target 99.9% — met over the last 30 days'; Class='cell-ok' }

    @{ Label='DCs Online';    Value='12/12';   Class='cell-ok' }
    @{ Label='Repl Errors';   Value=3;         Previous=0; TrendIsGood=$false
       Class='cell-warn'; Sparkline=@(0,0,1,2,2,3,3); SparklineStyle='bars' }
    @{ Label='Lockouts (1h)'; Value=12;        Previous=18; TrendIsGood=$true
       Sparkline=@(22,18,20,14,11,12,12); SparklineStyle='line' }
    @{ Label='Failed logons'; Value=842;       Previous=920; TrendIsGood=$true
       Format='number' }
    @{ Label='LDAP bind p95'; Value=68;        Previous=54; TrendIsGood=$false
       SubLabel='ms'; Class='cell-warn' }
    @{ Label='DNS success';   Value=99.94;     Previous=99.92; Format='percent'; Decimals=2
       Class='cell-ok' }
)

# Top alert that pairs with the KPI strip
Add-DhAlertBanner -Report $report -Id 'top-alert' `
    -Severity 'critical' -Icon '!' -Dismissible `
    -Message '3 critical replication errors open — DC03 ↔ DC01 inbound queue stalled 12 minutes ago.' `
    -Action @{ Label='View events'; TableId='top-dcs'; Filter='DC03' }

# ============================================================================
# Row 2 — Trend charts
# ============================================================================
$hours = @('00:00','02:00','04:00','06:00','08:00','10:00','12:00','14:00','16:00','18:00','20:00','22:00','24:00')

Add-DhLineChart -Report $report -Id 'auth-trend' -Title 'Authentication requests / sec (24h)' `
    -Filled `
    -XAxis $hours `
    -Series @(
        @{ Label='Kerberos AS';  Values=@(180,160,150,200,420,820,1100,1180,1240,1100,820,520,290); Class='cell-ok'   }
        @{ Label='Kerberos TGS'; Values=@(420,380,360,480,920,1820,2400,2520,2680,2440,1820,1180,640); Color='#4B5B6B' }
        @{ Label='NTLM (legacy)';Values=@( 80, 70, 60, 90,180,320,420,440,460,400,310,180,120);    Class='cell-warn' }
    ) `
    -YAxisMin 0 -YAxisUnit ' req/s'

Add-DhLineChart -Report $report -Id 'repl-latency' -Title 'Replication latency per DC pair' `
    -XAxis $hours `
    -Series @(
        @{ Label='DC01→DC02'; Values=@(8,7,9,8,12,10,14,18,22,16,14,12,11);                    Class='cell-ok'   }
        @{ Label='DC01→DC03'; Values=@(14,16,18,22,38,44,72,180,$null,$null,68,42,32);         Class='cell-warn' }
        @{ Label='DC01→DC04'; Values=@(11,10,12,14,18,22,26,32,38,30,24,20,18);                Color='#666666' }
    ) `
    -TargetLine 60 -TargetLabel 'SLA 60s' `
    -YAxisMin 0 -YAxisUnit ' s'

Add-DhLineChart -Report $report -Id 'ldap-ops' -Title 'LDAP operations / sec' `
    -Filled `
    -XAxis $hours `
    -Series @(
        @{ Label='Search';   Values=@(620,540,510,640,1200,2400,3200,3460,3680,3320,2480,1620,920); Class='cell-ok' }
        @{ Label='Bind';     Values=@( 80, 70, 65, 90,180,320,420,440,460,420,310,200,140);         Color='#7B5B9B' }
        @{ Label='Modify';   Values=@( 12, 10,  8, 16, 40, 84,140,160,180,140, 96, 54, 28);         Color='#9B5B5B' }
    ) `
    -YAxisMin 0 -YAxisUnit ' ops/s'

# ============================================================================
# Row 3 — Inventory & Security
# ============================================================================
Add-DhPieChart -Report $report -Id 'account-states' -Title 'Account states' `
    -Style 'donut' `
    -Slices @(
        @{ Label='Enabled';            Value=15420; Color='#375623' }   # spec GREEN
        @{ Label='Disabled';           Value=  820; Color='#7F4B00' }   # spec AMBER
        @{ Label='Locked';             Value=   42; Color='#9C0006' }   # spec RED
        @{ Label='Stale (>180d)';      Value=  214; Color='#595959' }   # spec GREY
    )

Add-DhStatusGrid -Report $report -Id 'dc-replication-matrix' `
    -Title 'DC replication matrix (inbound)' `
    -RowLabel 'Target' -ColumnLabel 'Source' `
    -Rows    @('DC01','DC02','DC03','DC04','DC05','DC06') `
    -Columns @('DC01','DC02','DC03','DC04','DC05','DC06') `
    -CellSize 'normal' `
    -Cells @(
        # DC01 inbound from each other DC
        @{ Row='DC01'; Column='DC02'; Status='ok' }
        @{ Row='DC01'; Column='DC03'; Status='warn'; Tooltip='Last sync 4m ago' }
        @{ Row='DC01'; Column='DC04'; Status='ok' }
        @{ Row='DC01'; Column='DC05'; Status='ok' }
        @{ Row='DC01'; Column='DC06'; Status='ok' }
        # DC02
        @{ Row='DC02'; Column='DC01'; Status='ok' }
        @{ Row='DC02'; Column='DC03'; Status='warn'; Tooltip='Last sync 6m ago' }
        @{ Row='DC02'; Column='DC04'; Status='ok' }
        @{ Row='DC02'; Column='DC05'; Status='ok' }
        @{ Row='DC02'; Column='DC06'; Status='ok' }
        # DC03 — failing inbound from DC01
        @{ Row='DC03'; Column='DC01'; Status='danger'; Tooltip='RPC unavailable 12m'; LinkTableId='top-dcs'; LinkFilter='DC03' }
        @{ Row='DC03'; Column='DC02'; Status='ok' }
        @{ Row='DC03'; Column='DC04'; Status='ok' }
        @{ Row='DC03'; Column='DC05'; Status='ok' }
        @{ Row='DC03'; Column='DC06'; Status='nodata' }
        # DC04..DC06 — fewer issues
        @{ Row='DC04'; Column='DC01'; Status='ok' }
        @{ Row='DC04'; Column='DC02'; Status='ok' }
        @{ Row='DC04'; Column='DC03'; Status='warn'; Tooltip='Catching up' }
        @{ Row='DC04'; Column='DC05'; Status='ok' }
        @{ Row='DC04'; Column='DC06'; Status='ok' }
        @{ Row='DC05'; Column='DC01'; Status='ok' }
        @{ Row='DC05'; Column='DC02'; Status='ok' }
        @{ Row='DC05'; Column='DC03'; Status='warn' }
        @{ Row='DC05'; Column='DC04'; Status='ok' }
        @{ Row='DC05'; Column='DC06'; Status='ok' }
        @{ Row='DC06'; Column='DC01'; Status='ok' }
        @{ Row='DC06'; Column='DC02'; Status='ok' }
        @{ Row='DC06'; Column='DC03'; Status='nodata' }
        @{ Row='DC06'; Column='DC04'; Status='ok' }
        @{ Row='DC06'; Column='DC05'; Status='ok' }
    )

# Top DCs by CPU — table with sparkline cells for at-a-glance trend
$dcRows = @(
    [PSCustomObject]@{ DC='DC01'; Site='HQ';      Cpu=42; CpuTrend=@(30,42,38,45,48,42,40,42); LdapMs=38; NtdsFree=78 }
    [PSCustomObject]@{ DC='DC02'; Site='HQ';      Cpu=58; CpuTrend=@(40,48,52,58,62,60,58,58); LdapMs=72; NtdsFree=82 }
    [PSCustomObject]@{ DC='DC03'; Site='HQ-DR';   Cpu=88; CpuTrend=@(60,68,72,80,86,90,92,88); LdapMs=92; NtdsFree=18 }
    [PSCustomObject]@{ DC='DC04'; Site='EU';      Cpu=32; CpuTrend=@(28,30,30,32,34,32,30,32); LdapMs=42; NtdsFree=68 }
    [PSCustomObject]@{ DC='DC05'; Site='EU-DR';   Cpu=28; CpuTrend=@(20,22,24,28,30,26,24,28); LdapMs=44; NtdsFree=64 }
    [PSCustomObject]@{ DC='DC06'; Site='APAC';    Cpu=$null; CpuTrend=$null;                   LdapMs=$null; NtdsFree=$null }
)
Add-DhTable -Report $report -TableId 'top-dcs' -Title 'Top DCs — load & headroom' -Data $dcRows -Columns @(
    @{ Field='DC';       Label='DC';                   PinFirst=$true }
    @{ Field='Site';     Label='Site' }
    @{ Field='Cpu';      Label='CPU %';      Align='right';
       CellType='progressbar'; ProgressMax=100; Rag=$utilRag }
    @{ Field='CpuTrend'; Label='CPU 8h';     CellType='sparkline'; SortBy='max'; SparklineStyle='area' }
    @{ Field='LdapMs';   Label='LDAP ms';    Align='right'
       Rag=@{ Green=@{ Max=50 }; Amber=@{ Min=50; Max=80 }; Red=@{ Min=80 }; NoData=$true } }
    @{ Field='NtdsFree'; Label='NTDS Free %'; Align='right'
       Rag=@{ Green=@{ Min=30 }; Amber=@{ Min=15; Max=30 }; Red=@{ Max=15 }; NoData=$true } }
)

# ============================================================================
# Row 4 — FSMO roles + capacity bullets
# ============================================================================
Add-DhStatusGrid -Report $report -Id 'fsmo-roles' -Title 'FSMO Role Holders' `
    -RowLabel 'Role' -ColumnLabel 'Status' `
    -Rows @('PDC Emulator','RID Master','Infrastructure Master','Schema Master','Domain Naming Master') `
    -Columns @('Status') `
    -CellSize 'large' `
    -Cells @(
        @{ Row='PDC Emulator';          Column='Status'; Status='ok'; Tooltip='DC01 — online, last verified 30s ago' }
        @{ Row='RID Master';            Column='Status'; Status='ok'; Tooltip='DC01' }
        @{ Row='Infrastructure Master'; Column='Status'; Status='ok'; Tooltip='DC02' }
        @{ Row='Schema Master';         Column='Status'; Status='ok'; Tooltip='DC01' }
        @{ Row='Domain Naming Master';  Column='Status'; Status='ok'; Tooltip='DC01' }
    )

# Capacity / compliance bullets
Add-DhBullet -Report $report -Id 'ntds-disk' -Title 'NTDS database disk free %' -Items @(
    @{ Label='DC01'; Value=78; Target=20; Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{ Min=30 }; Amber=@{ Min=15; Max=30 }; Red=@{ Max=15 } } }
    @{ Label='DC02'; Value=82; Target=20; Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{ Min=30 }; Amber=@{ Min=15; Max=30 }; Red=@{ Max=15 } } }
    @{ Label='DC03'; Value=18; Target=20; Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{ Min=30 }; Amber=@{ Min=15; Max=30 }; Red=@{ Max=15 } } }
    @{ Label='DC04'; Value=68; Target=20; Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{ Min=30 }; Amber=@{ Min=15; Max=30 }; Red=@{ Max=15 } } }
)

Add-DhBullet -Report $report -Id 'patch-level' -Title 'Patch compliance (latest cumulative)' -Items @(
    @{ Label='Domain Controllers'; Value=92; Target=100; Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{ Min=95 }; Amber=@{ Min=80; Max=95 }; Red=@{ Max=80 } } }
    @{ Label='Member Servers';     Value=87; Target=95;  Min=0; Max=100; Unit='%'
       Rag=@{ Green=@{ Min=95 }; Amber=@{ Min=80; Max=95 }; Red=@{ Max=80 } } }
)

# ============================================================================
# Row 5 — Event feed (chronological audit trail)
# ============================================================================
Add-DhEventFeed -Report $report -Id 'recent-events' -Title 'Recent events (24h)' `
    -MaxItems 50 -GroupBy 'Severity' -Events $events

# ============================================================================
# Render
# ============================================================================
$out = Join-Path $PSScriptRoot 'AD-Dashboard.html'
Export-DhDashboard -Report $report -OutputPath $out -Force -OpenInBrowser
Write-Host "Wrote $out"
