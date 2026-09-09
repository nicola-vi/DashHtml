#Requires -Version 7.0
<#
.SYNOPSIS
    DashHtml v1.4.1 — per-NavGroup KPI summaries example.

.DESCRIPTION
    Demonstrates the v1.4.1 multi-summary feature: each nav panel can carry
    its own KPI strip, declared by passing -NavGroup / -NavSubGroup to
    Add-DhSummary. The legacy unscoped Add-DhSummary call still works and
    renders as a single global strip at the top of every panel.

    Layout:
        Top-of-page    : global summary (no NavGroup) — visible on every panel
        Identity panel : its own KPI strip + a table
        Infrastructure : its own KPI strip + a status grid
        Finance        : its own KPI strip + a line chart with target line

    Open the dashboard, switch between the three group tabs in the nav bar,
    and watch the per-panel strip change while the global strip stays put.

.PARAMETER OutputPath
    Where to write the generated HTML. Defaults to Demo-Feature-NavMultiPanel.html
    beside this script.

.PARAMETER OpenInBrowser
    Open the dashboard in the default browser once generated.

.EXAMPLE
    PS> .\Examples\Demo-Feature-NavMultiPanel.ps1 -OpenInBrowser

.EXAMPLE
    PS> .\Examples\Demo-Feature-NavMultiPanel.ps1 -OutputPath C:\Temp\panels.html
#>
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Demo-Feature-NavMultiPanel.html'),
    [switch] $OpenInBrowser
)

Import-Module "$PSScriptRoot\..\DashHtml\DashHtml.psd1" -Force

$report = New-DhDashboard -Title 'Multi-panel dashboard' `
    -Subtitle 'Per-NavGroup KPI summaries (v1.4.1+)' `
    -Theme Rag `
    -InfoFields @(
        @{ Label='Organisation'; Value='Contoso' }
        @{ Label='Generated';    Value=(Get-Date -Format 'yyyy-MM-dd HH:mm') }
    )

# ============================================================================
# GLOBAL SUMMARY — no -NavGroup, shown on every panel at the top of the page.
# This is the same singleton Add-DhSummary you've been using since 1.3.x.
# ============================================================================
Add-DhSummary -Report $report -Title 'Global health' -Items @(
    @{ Style='bignumber'; Label='Overall SLA (30d)'; Value='99.96%'; Caption='Target 99.9% — met'; Class='cell-ok' }
    @{ Label='Open incidents'; Value=4;   Previous=7; TrendIsGood=$true }
    @{ Label='Users online';   Value=842; Previous=820; TrendIsGood=$true; Format='number'
       Sparkline=@(780,800,810,820,830,840,842); SparklineStyle='line' }
)

# ============================================================================
# PANEL 1 — Identity
# Its own KPI strip + a table.
# ============================================================================
$authRag = @{ Green=@{Max=50}; Amber=@{Min=50;Max=80}; Red=@{Min=80}; NoData=$true }

# Per-panel summary: lives in the block flow, only visible when 'Identity' tab is active
Add-DhSummary -Report $report -NavGroup 'Identity' -Title 'Identity KPIs' -Items @(
    @{ Style='bignumber'; Label='Active users'; Value=231; Class='cell-ok'
       Caption='Across all directory partitions' }
    @{ Label='Failed logons (1h)'; Value=842; Previous=920; TrendIsGood=$true; Format='number'
       Sparkline=@(1100,1050,950,920,890,860,842); SparklineStyle='bars'; Class='cell-warn' }
    @{ Label='Locked accounts';    Value=12;  Previous=18; TrendIsGood=$true }
    @{ Style='gauge'; Label='LDAP bind p95';   Value=42; Max=120; Unit='ms'; Rag=$authRag }
)

$identityRows = @(
    [PSCustomObject]@{ User='alice@contoso.com';   Role='Admin';   LastLogon='2026-05-23 09:14'; FailedAttempts=0;  Status='OK'   }
    [PSCustomObject]@{ User='bob@contoso.com';     Role='User';    LastLogon='2026-05-23 08:42'; FailedAttempts=2;  Status='OK'   }
    [PSCustomObject]@{ User='svc-backup';          Role='Service'; LastLogon='2026-05-23 02:00'; FailedAttempts=0;  Status='OK'   }
    [PSCustomObject]@{ User='carol@contoso.com';   Role='User';    LastLogon='2026-05-22 17:18'; FailedAttempts=12; Status='Locked' }
)
Add-DhTable -Report $report -TableId 'identity-recent' -Title 'Recent activity (Identity panel)' -Data $identityRows -Columns @(
    @{ Field='User';           Label='User'; PinFirst=$true }
    @{ Field='Role';           Label='Role'; CellType='badge'
       Thresholds=@(
           @{ Value='Admin';   Class='cell-warn'   }
           @{ Value='Service'; Class='cell-nodata' }
           @{ Value='User';    Class='cell-ok'     }
       )
    }
    @{ Field='LastLogon';      Label='Last logon' }
    @{ Field='FailedAttempts'; Label='Failed'; Align='right'
       Rag=@{ Green=@{Max=3}; Amber=@{Min=3;Max=10}; Red=@{Min=10} } }
    @{ Field='Status';         Label='Status'; CellType='badge'
       Thresholds=@(
           @{ Value='OK';     Class='cell-ok'     }
           @{ Value='Locked'; Class='cell-danger' }
       )
       RowHighlight=$true
    }
) -NavGroup 'Identity'

# ============================================================================
# PANEL 2 — Infrastructure
# Different KPI strip (note the different metrics) + a status grid.
# ============================================================================
$utilRag = @{ Green=@{Max=70}; Amber=@{Min=70;Max=90}; Red=@{Min=90}; NoData=$true }

Add-DhSummary -Report $report -NavGroup 'Infrastructure' -Title 'Infrastructure KPIs' -Items @(
    @{ Style='bignumber'; Label='Hosts up'; Value='38/40'; Class='cell-warn'
       Caption='2 in maintenance window' }
    @{ Style='gauge'; Label='Cluster CPU';  Value=68; Max=100; Unit='%'; Rag=$utilRag }
    @{ Style='gauge'; Label='Cluster Mem';  Value=82; Max=100; Unit='%'; Rag=$utilRag }
    @{ Style='gauge'; Label='Datastore';    Value=74; Max=100; Unit='%'; Rag=$utilRag }
    @{ Label='Active alarms'; Value=3; Previous=1; TrendIsGood=$false; Class='cell-warn' }
)

Add-DhStatusGrid -Report $report -Id 'infra-health' `
    -Title 'Service health (Infrastructure panel)' `
    -RowLabel 'Service' -ColumnLabel 'Region' `
    -Rows    @('Auth','Billing','Search','Mail') `
    -Columns @('us-east','us-west','eu-west','ap-south') `
    -Cells @(
        @{ Row='Auth';    Column='us-east'; Status='ok' }
        @{ Row='Auth';    Column='us-west'; Status='ok' }
        @{ Row='Auth';    Column='eu-west'; Status='warn'; Tooltip='latency spike' }
        @{ Row='Auth';    Column='ap-south'; Status='ok' }
        @{ Row='Billing'; Column='us-east'; Status='danger'; Tooltip='down 12m' }
        @{ Row='Billing'; Column='us-west'; Status='ok' }
        @{ Row='Billing'; Column='eu-west'; Status='ok' }
        @{ Row='Billing'; Column='ap-south'; Status='nodata' }
        @{ Row='Search';  Column='us-east'; Status='ok' }
        @{ Row='Search';  Column='eu-west'; Status='ok' }
        @{ Row='Mail';    Column='us-east'; Status='ok' }
        @{ Row='Mail';    Column='us-west'; Status='ok' }
    ) `
    -NavGroup 'Infrastructure'

# ============================================================================
# PANEL 3 — Finance
# Another KPI strip with currency formatting + a line chart with a target line.
# ============================================================================
Add-DhSummary -Report $report -NavGroup 'Finance' -Title 'Finance KPIs' -Items @(
    @{ Style='bignumber'; Label='MTD Revenue'; Value=1240500; Previous=1180000; TrendIsGood=$true
       Format='currency'; Locale='en-US'; Currency='USD'; Decimals=0; Class='cell-ok' }
    @{ Label='Burn rate'; Value=82400; Previous=84200; TrendIsGood=$true
       Format='currency'; Locale='en-US'; Currency='USD'; Decimals=0 }
    @{ Label='Runway';    Value=18.4; SubLabel='months'; Class='cell-ok'
       Sparkline=@(14,15,16,17,17,18,18.4); SparklineStyle='area' }
    @{ Style='gauge'; Label='Budget consumed'; Value=62; Max=100; Unit='%'
       Rag=@{ Green=@{Max=80}; Amber=@{Min=80;Max=95}; Red=@{Min=95} } }
)

$months = @('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec')
Add-DhLineChart -Report $report -Id 'finance-revenue-trend' `
    -Title 'Monthly revenue vs target (Finance panel)' `
    -Filled `
    -XAxis $months `
    -Series @(
        @{ Label='Revenue (USD k)'; Values=@(820,840,910,985,1040,1120,1180,1240,$null,$null,$null,$null)
           Class='cell-ok' }
    ) `
    -TargetLine 1000 -TargetLabel 'Monthly target' `
    -YAxisMin 0 -YAxisUnit 'k' `
    -NavGroup 'Finance'

# ============================================================================
Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
