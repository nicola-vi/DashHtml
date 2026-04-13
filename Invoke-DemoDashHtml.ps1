#Requires -Version 7.0
<#
.SYNOPSIS
    Invoke-DemoDashHtml.ps1 — Full feature showcase for the DashHtml module.

.DESCRIPTION
    Demonstrates every DashHtml capability in a single self-contained HTML file:

    NAVIGATION
      Two-tier nav bar: Overview / Infrastructure / Projects / People

    BLOCKS
      Add-DhSummary     — KPI tiles with all Format types (number, currency, bytes, percent)
      Add-DhHtmlBlock   — all 5 styles: info, warn, danger, ok, neutral
      Add-DhCollapsible — card-grid mode AND free-form HTML content mode
      Add-DhFilterCard  — single-select AND multi-select (MultiFilter)
      Add-DhBarChart    — with ShowPercent, with ClickFilters

    TABLES  (Add-DhTable)
      CellType: text | progressbar | badge
      Format:   number | currency | bytes | percent | datetime | duration
      Column:   Bold, Italic, Font (mono), Align, Width
      PinFirst  — pinned first column during horizontal scroll
      Aggregate — sum / avg / count footer rows
      Thresholds — numeric (Min/Max) and string (Value) rules
      RowHighlight — threshold class applied to entire row
      Charts    — pie charts (multiple per table)
      MultiSelect — checkbox row selection
      ExportFileName — custom base name for CSV/XLSX/PDF downloads

    LINKING  (Set-DhTableLink)
      2-level:  Servers -> Services
      3-level:  Departments -> Teams -> Employees

.EXAMPLE
    .\Invoke-DemoDashHtml.ps1
    .\Invoke-DemoDashHtml.ps1 -Theme Azure -OpenInBrowser
    .\Invoke-DemoDashHtml.ps1 -Theme VMware -OutputPath C:\Temp\demo.html -OpenInBrowser
#>
param(
    [string] $LogoPath   = '',
    [string] $OutputPath = (Join-Path $PSScriptRoot 'demo-dashreport.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company')]
    [string] $Theme      = 'Company',
    [switch] $OpenInBrowser
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Module import ──────────────────────────────────────────────────────────────
if (Get-Module -Name DashHtml -ListAvailable -ErrorAction SilentlyContinue) {
    Import-Module DashHtml -Force
} else {
    Import-Module (Join-Path $PSScriptRoot 'DashHtml\DashHtml.psd1') -Force
}

# ==============================================================================
#  SAMPLE DATA
# ==============================================================================

# ── INFRASTRUCTURE: Servers ────────────────────────────────────────────────────
$servers = @(
    [PSCustomObject]@{ Name='srv-web-01';   OS='Windows Server 2022'; Location='DC-West';  Status='Online';     CPU_Pct=42;  RAM_GB=32;  DiskFree_Bytes=128849018880;  MonthlyCost=185.40; Uptime_Sec=7776000;  LastPatch='2026-03-15T02:00:00' }
    [PSCustomObject]@{ Name='srv-web-02';   OS='Windows Server 2022'; Location='DC-West';  Status='Online';     CPU_Pct=38;  RAM_GB=32;  DiskFree_Bytes=107374182400;  MonthlyCost=185.40; Uptime_Sec=7776000;  LastPatch='2026-03-15T02:00:00' }
    [PSCustomObject]@{ Name='srv-app-01';   OS='Windows Server 2022'; Location='DC-West';  Status='Online';     CPU_Pct=71;  RAM_GB=64;  DiskFree_Bytes=214748364800;  MonthlyCost=320.80; Uptime_Sec=7776000;  LastPatch='2026-02-10T03:00:00' }
    [PSCustomObject]@{ Name='srv-app-02';   OS='Windows Server 2019'; Location='DC-East';  Status='Warning';    CPU_Pct=88;  RAM_GB=64;  DiskFree_Bytes=21474836480;   MonthlyCost=310.00; Uptime_Sec=2592000;  LastPatch='2026-01-20T03:00:00' }
    [PSCustomObject]@{ Name='srv-db-01';    OS='Windows Server 2022'; Location='DC-West';  Status='Online';     CPU_Pct=55;  RAM_GB=128; DiskFree_Bytes=536870912000;  MonthlyCost=620.00; Uptime_Sec=15552000; LastPatch='2026-03-01T04:00:00' }
    [PSCustomObject]@{ Name='srv-db-02';    OS='Windows Server 2022'; Location='DC-East';  Status='Online';     CPU_Pct=48;  RAM_GB=128; DiskFree_Bytes=644245094400;  MonthlyCost=620.00; Uptime_Sec=15552000; LastPatch='2026-03-01T04:00:00' }
    [PSCustomObject]@{ Name='lnx-api-01';   OS='Ubuntu 22.04';        Location='DC-West';  Status='Online';     CPU_Pct=29;  RAM_GB=16;  DiskFree_Bytes=53687091200;   MonthlyCost=95.00;  Uptime_Sec=31104000; LastPatch='2026-03-10T01:00:00' }
    [PSCustomObject]@{ Name='lnx-api-02';   OS='Ubuntu 22.04';        Location='DC-West';  Status='Online';     CPU_Pct=31;  RAM_GB=16;  DiskFree_Bytes=48318382080;   MonthlyCost=95.00;  Uptime_Sec=31104000; LastPatch='2026-03-10T01:00:00' }
    [PSCustomObject]@{ Name='lnx-mon-01';   OS='Ubuntu 22.04';        Location='DC-East';  Status='Online';     CPU_Pct=18;  RAM_GB=8;   DiskFree_Bytes=26843545600;   MonthlyCost=45.00;  Uptime_Sec=62208000; LastPatch='2026-02-28T01:00:00' }
    [PSCustomObject]@{ Name='lnx-ci-01';    OS='Rocky Linux 9';       Location='DC-West';  Status='Online';     CPU_Pct=62;  RAM_GB=32;  DiskFree_Bytes=107374182400;  MonthlyCost=155.00; Uptime_Sec=5184000;  LastPatch='2026-03-18T00:00:00' }
    [PSCustomObject]@{ Name='lnx-ci-02';    OS='Rocky Linux 9';       Location='DC-East';  Status='Warning';    CPU_Pct=91;  RAM_GB=32;  DiskFree_Bytes=10737418240;   MonthlyCost=155.00; Uptime_Sec=1296000;  LastPatch='2026-02-01T00:00:00' }
    [PSCustomObject]@{ Name='srv-fs-01';    OS='Windows Server 2019'; Location='DC-West';  Status='Online';     CPU_Pct=22;  RAM_GB=32;  DiskFree_Bytes=1099511627776; MonthlyCost=210.00; Uptime_Sec=46656000; LastPatch='2026-01-15T04:00:00' }
    [PSCustomObject]@{ Name='srv-mgmt-01';  OS='Windows Server 2022'; Location='DC-West';  Status='Online';     CPU_Pct=15;  RAM_GB=16;  DiskFree_Bytes=85899345920;   MonthlyCost=130.00; Uptime_Sec=15552000; LastPatch='2026-03-05T03:00:00' }
    [PSCustomObject]@{ Name='srv-dr-01';    OS='Windows Server 2022'; Location='DC-DR';    Status='Standby';    CPU_Pct=5;   RAM_GB=64;  DiskFree_Bytes=429496729600;  MonthlyCost=280.00; Uptime_Sec=93312000; LastPatch='2026-03-01T04:00:00' }
    [PSCustomObject]@{ Name='lnx-dr-01';    OS='Ubuntu 22.04';        Location='DC-DR';    Status='Standby';    CPU_Pct=3;   RAM_GB=16;  DiskFree_Bytes=53687091200;   MonthlyCost=75.00;  Uptime_Sec=93312000; LastPatch='2026-02-15T01:00:00' }
    [PSCustomObject]@{ Name='srv-bck-01';   OS='Windows Server 2019'; Location='DC-DR';    Status='Online';     CPU_Pct=35;  RAM_GB=32;  DiskFree_Bytes=2199023255552; MonthlyCost=190.00; Uptime_Sec=62208000; LastPatch='2026-01-20T04:00:00' }
    [PSCustomObject]@{ Name='lnx-stg-01';   OS='Rocky Linux 9';       Location='DC-East';  Status='Offline';    CPU_Pct=0;   RAM_GB=8;   DiskFree_Bytes=0;             MonthlyCost=40.00;  Uptime_Sec=0;        LastPatch='2025-12-01T00:00:00' }
    [PSCustomObject]@{ Name='srv-old-01';   OS='Windows Server 2016'; Location='DC-West';  Status='Warning';    CPU_Pct=79;  RAM_GB=16;  DiskFree_Bytes=5368709120;    MonthlyCost=90.00;  Uptime_Sec=86400;    LastPatch='2025-09-01T00:00:00' }
    [PSCustomObject]@{ Name='srv-old-02';   OS='Windows Server 2016'; Location='DC-East';  Status='Offline';    CPU_Pct=0;   RAM_GB=8;   DiskFree_Bytes=0;             MonthlyCost=60.00;  Uptime_Sec=0;        LastPatch='2025-08-15T00:00:00' }
)

# ── INFRASTRUCTURE: Services (linked from Servers) ─────────────────────────────
$services = @(
    [PSCustomObject]@{ ServiceName='IIS';             ServerName='srv-web-01';  Port=443;  Protocol='HTTPS'; Status='Running'; Uptime_Pct=99.98; ResponseMs=12  }
    [PSCustomObject]@{ ServiceName='IIS';             ServerName='srv-web-02';  Port=443;  Protocol='HTTPS'; Status='Running'; Uptime_Pct=99.97; ResponseMs=14  }
    [PSCustomObject]@{ ServiceName='AppService';      ServerName='srv-app-01';  Port=8080; Protocol='HTTP';  Status='Running'; Uptime_Pct=99.95; ResponseMs=45  }
    [PSCustomObject]@{ ServiceName='AppService';      ServerName='srv-app-02';  Port=8080; Protocol='HTTP';  Status='Degraded';Uptime_Pct=97.20; ResponseMs=420 }
    [PSCustomObject]@{ ServiceName='SQL Server';      ServerName='srv-db-01';   Port=1433; Protocol='TCP';   Status='Running'; Uptime_Pct=99.99; ResponseMs=3   }
    [PSCustomObject]@{ ServiceName='SQL Server';      ServerName='srv-db-02';   Port=1433; Protocol='TCP';   Status='Running'; Uptime_Pct=99.99; ResponseMs=4   }
    [PSCustomObject]@{ ServiceName='SQL Agent';       ServerName='srv-db-01';   Port=0;    Protocol='N/A';   Status='Running'; Uptime_Pct=99.95; ResponseMs=0   }
    [PSCustomObject]@{ ServiceName='REST API';        ServerName='lnx-api-01';  Port=8443; Protocol='HTTPS'; Status='Running'; Uptime_Pct=99.90; ResponseMs=28  }
    [PSCustomObject]@{ ServiceName='REST API';        ServerName='lnx-api-02';  Port=8443; Protocol='HTTPS'; Status='Running'; Uptime_Pct=99.88; ResponseMs=31  }
    [PSCustomObject]@{ ServiceName='Prometheus';      ServerName='lnx-mon-01';  Port=9090; Protocol='HTTP';  Status='Running'; Uptime_Pct=99.99; ResponseMs=8   }
    [PSCustomObject]@{ ServiceName='Grafana';         ServerName='lnx-mon-01';  Port=3000; Protocol='HTTP';  Status='Running'; Uptime_Pct=99.95; ResponseMs=22  }
    [PSCustomObject]@{ ServiceName='Jenkins';         ServerName='lnx-ci-01';   Port=8080; Protocol='HTTP';  Status='Running'; Uptime_Pct=99.60; ResponseMs=95  }
    [PSCustomObject]@{ ServiceName='Jenkins Agent';   ServerName='lnx-ci-02';   Port=50000;Protocol='TCP';   Status='Degraded';Uptime_Pct=85.00; ResponseMs=0   }
    [PSCustomObject]@{ ServiceName='File Share';      ServerName='srv-fs-01';   Port=445;  Protocol='SMB';   Status='Running'; Uptime_Pct=99.99; ResponseMs=5   }
    [PSCustomObject]@{ ServiceName='RDP';             ServerName='srv-mgmt-01'; Port=3389; Protocol='RDP';   Status='Running'; Uptime_Pct=99.90; ResponseMs=18  }
    [PSCustomObject]@{ ServiceName='Veeam Agent';     ServerName='srv-bck-01';  Port=9393; Protocol='TCP';   Status='Running'; Uptime_Pct=99.80; ResponseMs=0   }
    [PSCustomObject]@{ ServiceName='AppService';      ServerName='lnx-stg-01';  Port=8080; Protocol='HTTP';  Status='Stopped'; Uptime_Pct=0;     ResponseMs=0   }
    [PSCustomObject]@{ ServiceName='IIS';             ServerName='srv-old-01';  Port=80;   Protocol='HTTP';  Status='Degraded';Uptime_Pct=91.00; ResponseMs=890 }
)

# ── PROJECTS: Projects table ───────────────────────────────────────────────────
$projects = @(
    [PSCustomObject]@{ ProjectId='PRJ-001'; Name='ERP Upgrade';           Department='IT';       Status='In Progress'; Priority='High';   Budget=180000; Spent=112000; Progress=62; StartDate='2026-01-10'; DueDate='2026-06-30' }
    [PSCustomObject]@{ ProjectId='PRJ-002'; Name='Cloud Migration';       Department='IT';       Status='In Progress'; Priority='High';   Budget=320000; Spent=87000;  Progress=27; StartDate='2026-02-01'; DueDate='2026-12-31' }
    [PSCustomObject]@{ ProjectId='PRJ-003'; Name='Security Hardening';    Department='Security'; Status='In Progress'; Priority='High';   Budget=95000;  Spent=71000;  Progress=75; StartDate='2025-11-01'; DueDate='2026-04-30' }
    [PSCustomObject]@{ ProjectId='PRJ-004'; Name='HR Portal Redesign';    Department='HR';       Status='In Progress'; Priority='Medium'; Budget=65000;  Spent=22000;  Progress=34; StartDate='2026-03-01'; DueDate='2026-07-31' }
    [PSCustomObject]@{ ProjectId='PRJ-005'; Name='BI Dashboard v2';       Department='Finance';  Status='Planning';    Priority='Medium'; Budget=48000;  Spent=5000;   Progress=10; StartDate='2026-04-01'; DueDate='2026-08-31' }
    [PSCustomObject]@{ ProjectId='PRJ-006'; Name='DR Site Setup';         Department='IT';       Status='In Progress'; Priority='High';   Budget=210000; Spent=145000; Progress=69; StartDate='2025-10-01'; DueDate='2026-05-31' }
    [PSCustomObject]@{ ProjectId='PRJ-007'; Name='Compliance Audit 2026'; Department='Legal';    Status='In Progress'; Priority='High';   Budget=40000;  Spent=28000;  Progress=70; StartDate='2026-01-01'; DueDate='2026-04-15' }
    [PSCustomObject]@{ ProjectId='PRJ-008'; Name='Mobile App';            Department='Dev';      Status='Planning';    Priority='Low';    Budget=120000; Spent=8000;   Progress=7;  StartDate='2026-05-01'; DueDate='2026-12-31' }
    [PSCustomObject]@{ ProjectId='PRJ-009'; Name='Network Refresh';       Department='IT';       Status='Completed';   Priority='Medium'; Budget=85000;  Spent=81000;  Progress=100;StartDate='2025-09-01'; DueDate='2026-03-31' }
    [PSCustomObject]@{ ProjectId='PRJ-010'; Name='API Gateway v3';        Department='Dev';      Status='In Progress'; Priority='Medium'; Budget=75000;  Spent=31000;  Progress=41; StartDate='2026-02-15'; DueDate='2026-09-30' }
)

# ── PROJECTS: Tasks table (linked from Projects) ───────────────────────────────
$tasks = @(
    [PSCustomObject]@{ TaskId='T-001'; ProjectId='PRJ-001'; Name='Requirements analysis';      Assignee='Alice Martin';  Priority='High';   Status='Done';        EstHours=40;  ActualHours=38  }
    [PSCustomObject]@{ TaskId='T-002'; ProjectId='PRJ-001'; Name='Vendor evaluation';           Assignee='Bob Chen';      Priority='High';   Status='Done';        EstHours=24;  ActualHours=30  }
    [PSCustomObject]@{ TaskId='T-003'; ProjectId='PRJ-001'; Name='UAT environment setup';       Assignee='Alice Martin';  Priority='Medium'; Status='In Progress'; EstHours=16;  ActualHours=10  }
    [PSCustomObject]@{ TaskId='T-004'; ProjectId='PRJ-001'; Name='Data migration scripts';      Assignee='Diana Ross';    Priority='High';   Status='In Progress'; EstHours=60;  ActualHours=25  }
    [PSCustomObject]@{ TaskId='T-005'; ProjectId='PRJ-001'; Name='User training';               Assignee='Eve Turner';    Priority='Low';    Status='Pending';     EstHours=20;  ActualHours=0   }
    [PSCustomObject]@{ TaskId='T-006'; ProjectId='PRJ-002'; Name='Workload assessment';         Assignee='Frank Lee';     Priority='High';   Status='Done';        EstHours=32;  ActualHours=35  }
    [PSCustomObject]@{ TaskId='T-007'; ProjectId='PRJ-002'; Name='Network architecture design'; Assignee='Grace Kim';     Priority='High';   Status='In Progress'; EstHours=48;  ActualHours=20  }
    [PSCustomObject]@{ TaskId='T-008'; ProjectId='PRJ-002'; Name='Pilot migration - Dev env';   Assignee='Frank Lee';     Priority='Medium'; Status='In Progress'; EstHours=40;  ActualHours=12  }
    [PSCustomObject]@{ TaskId='T-009'; ProjectId='PRJ-003'; Name='Vulnerability scan';          Assignee='Henry Park';    Priority='High';   Status='Done';        EstHours=16;  ActualHours=18  }
    [PSCustomObject]@{ TaskId='T-010'; ProjectId='PRJ-003'; Name='Patch management rollout';    Assignee='Henry Park';    Priority='High';   Status='In Progress'; EstHours=24;  ActualHours=20  }
    [PSCustomObject]@{ TaskId='T-011'; ProjectId='PRJ-003'; Name='MFA enforcement';             Assignee='Iris Wang';     Priority='High';   Status='Done';        EstHours=12;  ActualHours=14  }
    [PSCustomObject]@{ TaskId='T-012'; ProjectId='PRJ-003'; Name='Firewall rule review';        Assignee='Henry Park';    Priority='Medium'; Status='In Progress'; EstHours=20;  ActualHours=8   }
    [PSCustomObject]@{ TaskId='T-013'; ProjectId='PRJ-004'; Name='UX research';                 Assignee='Julia Brown';   Priority='Medium'; Status='Done';        EstHours=24;  ActualHours=26  }
    [PSCustomObject]@{ TaskId='T-014'; ProjectId='PRJ-004'; Name='Wireframes';                  Assignee='Julia Brown';   Priority='Medium'; Status='In Progress'; EstHours=16;  ActualHours=8   }
    [PSCustomObject]@{ TaskId='T-015'; ProjectId='PRJ-004'; Name='Backend API';                 Assignee='Kevin Zhao';    Priority='High';   Status='Pending';     EstHours=40;  ActualHours=0   }
    [PSCustomObject]@{ TaskId='T-016'; ProjectId='PRJ-006'; Name='DR site procurement';         Assignee='Frank Lee';     Priority='High';   Status='Done';        EstHours=8;   ActualHours=10  }
    [PSCustomObject]@{ TaskId='T-017'; ProjectId='PRJ-006'; Name='Replication setup';           Assignee='Grace Kim';     Priority='High';   Status='In Progress'; EstHours=60;  ActualHours=45  }
    [PSCustomObject]@{ TaskId='T-018'; ProjectId='PRJ-006'; Name='Failover testing';            Assignee='Frank Lee';     Priority='High';   Status='Pending';     EstHours=32;  ActualHours=0   }
    [PSCustomObject]@{ TaskId='T-019'; ProjectId='PRJ-009'; Name='Switch replacement';          Assignee='Grace Kim';     Priority='Medium'; Status='Done';        EstHours=40;  ActualHours=38  }
    [PSCustomObject]@{ TaskId='T-020'; ProjectId='PRJ-009'; Name='Cabling recertification';     Assignee='Frank Lee';     Priority='Low';    Status='Done';        EstHours=16;  ActualHours=14  }
    [PSCustomObject]@{ TaskId='T-021'; ProjectId='PRJ-010'; Name='API spec design';             Assignee='Kevin Zhao';    Priority='Medium'; Status='Done';        EstHours=20;  ActualHours=22  }
    [PSCustomObject]@{ TaskId='T-022'; ProjectId='PRJ-010'; Name='Gateway implementation';      Assignee='Diana Ross';    Priority='High';   Status='In Progress'; EstHours=48;  ActualHours=18  }
    [PSCustomObject]@{ TaskId='T-023'; ProjectId='PRJ-010'; Name='Load testing';                Assignee='Kevin Zhao';    Priority='Medium'; Status='Pending';     EstHours=16;  ActualHours=0   }
)

# ── PEOPLE: Departments ────────────────────────────────────────────────────────
$departments = @(
    [PSCustomObject]@{ DeptName='IT';       Manager='Frank Lee';    HeadCount=18; Budget=1200000; Utilization=78; Status='Active' }
    [PSCustomObject]@{ DeptName='Dev';      Manager='Diana Ross';   HeadCount=24; Budget=1800000; Utilization=91; Status='Active' }
    [PSCustomObject]@{ DeptName='Security'; Manager='Henry Park';   HeadCount=8;  Budget=620000;  Utilization=85; Status='Active' }
    [PSCustomObject]@{ DeptName='Finance';  Manager='Alice Martin'; HeadCount=12; Budget=480000;  Utilization=62; Status='Active' }
    [PSCustomObject]@{ DeptName='HR';       Manager='Julia Brown';  HeadCount=9;  Budget=360000;  Utilization=54; Status='Active' }
    [PSCustomObject]@{ DeptName='Legal';    Manager='Eve Turner';   HeadCount=5;  Budget=290000;  Utilization=70; Status='Active' }
)

# ── PEOPLE: Teams (linked from Departments) ────────────────────────────────────
$teams = @(
    [PSCustomObject]@{ TeamName='Infrastructure'; DeptName='IT';       Lead='Grace Kim';    Members=7;  ActiveProjects=3 }
    [PSCustomObject]@{ TeamName='Support';        DeptName='IT';       Lead='Bob Chen';     Members=6;  ActiveProjects=1 }
    [PSCustomObject]@{ TeamName='SysAdmin';       DeptName='IT';       Lead='Frank Lee';    Members=5;  ActiveProjects=2 }
    [PSCustomObject]@{ TeamName='Backend';        DeptName='Dev';      Lead='Diana Ross';   Members=9;  ActiveProjects=4 }
    [PSCustomObject]@{ TeamName='Frontend';       DeptName='Dev';      Lead='Kevin Zhao';   Members=8;  ActiveProjects=3 }
    [PSCustomObject]@{ TeamName='QA';             DeptName='Dev';      Lead='Iris Wang';    Members=7;  ActiveProjects=3 }
    [PSCustomObject]@{ TeamName='AppSec';         DeptName='Security'; Lead='Henry Park';   Members=4;  ActiveProjects=2 }
    [PSCustomObject]@{ TeamName='Compliance';     DeptName='Security'; Lead='Iris Wang';    Members=4;  ActiveProjects=1 }
    [PSCustomObject]@{ TeamName='Controlling';    DeptName='Finance';  Lead='Alice Martin'; Members=5;  ActiveProjects=1 }
    [PSCustomObject]@{ TeamName='Reporting';      DeptName='Finance';  Lead='Bob Chen';     Members=7;  ActiveProjects=1 }
    [PSCustomObject]@{ TeamName='Talent';         DeptName='HR';       Lead='Julia Brown';  Members=5;  ActiveProjects=1 }
    [PSCustomObject]@{ TeamName='Contracts';      DeptName='Legal';    Lead='Eve Turner';   Members=5;  ActiveProjects=1 }
)

# ── PEOPLE: Employees (linked from Teams) ─────────────────────────────────────
$employees = @(
    [PSCustomObject]@{ FullName='Frank Lee';     TeamName='SysAdmin';      DeptName='IT';       Role='Team Lead';       Salary=92000; YearsExp=11; Performance=88 }
    [PSCustomObject]@{ FullName='Grace Kim';     TeamName='Infrastructure'; DeptName='IT';       Role='Team Lead';       Salary=95000; YearsExp=9;  Performance=92 }
    [PSCustomObject]@{ FullName='Bob Chen';      TeamName='Support';       DeptName='IT';       Role='Team Lead';       Salary=78000; YearsExp=7;  Performance=76 }
    [PSCustomObject]@{ FullName='Marco Bianchi'; TeamName='Infrastructure'; DeptName='IT';       Role='Network Engineer'; Salary=72000; YearsExp=6;  Performance=81 }
    [PSCustomObject]@{ FullName='Sara Ricci';    TeamName='SysAdmin';      DeptName='IT';       Role='Sys Administrator'; Salary=68000; YearsExp=4;  Performance=79 }
    [PSCustomObject]@{ FullName='Luca Esposito'; TeamName='Support';       DeptName='IT';       Role='Support Engineer'; Salary=52000; YearsExp=2;  Performance=65 }
    [PSCustomObject]@{ FullName='Diana Ross';    TeamName='Backend';       DeptName='Dev';      Role='Team Lead';       Salary=105000; YearsExp=12; Performance=95 }
    [PSCustomObject]@{ FullName='Kevin Zhao';    TeamName='Frontend';      DeptName='Dev';      Role='Team Lead';       Salary=98000; YearsExp=8;  Performance=90 }
    [PSCustomObject]@{ FullName='Iris Wang';     TeamName='QA';            DeptName='Dev';      Role='Team Lead';       Salary=88000; YearsExp=7;  Performance=85 }
    [PSCustomObject]@{ FullName='Tom Fischer';   TeamName='Backend';       DeptName='Dev';      Role='Senior Developer'; Salary=96000; YearsExp=9;  Performance=88 }
    [PSCustomObject]@{ FullName='Maria Gomez';   TeamName='Backend';       DeptName='Dev';      Role='Developer';       Salary=74000; YearsExp=4;  Performance=80 }
    [PSCustomObject]@{ FullName='James Okafor';  TeamName='Frontend';      DeptName='Dev';      Role='Senior Developer'; Salary=91000; YearsExp=7;  Performance=87 }
    [PSCustomObject]@{ FullName='Anna Kovacs';   TeamName='Frontend';      DeptName='Dev';      Role='Developer';       Salary=71000; YearsExp=3;  Performance=75 }
    [PSCustomObject]@{ FullName='Carlos Ruiz';   TeamName='QA';            DeptName='Dev';      Role='QA Engineer';     Salary=67000; YearsExp=4;  Performance=72 }
    [PSCustomObject]@{ FullName='Henry Park';    TeamName='AppSec';        DeptName='Security'; Role='Team Lead';       Salary=102000; YearsExp=10; Performance=93 }
    [PSCustomObject]@{ FullName='Sofia Alves';   TeamName='AppSec';        DeptName='Security'; Role='Security Analyst'; Salary=85000; YearsExp=5;  Performance=86 }
    [PSCustomObject]@{ FullName='Riku Tanaka';   TeamName='Compliance';    DeptName='Security'; Role='Compliance Analyst'; Salary=79000; YearsExp=5;  Performance=82 }
    [PSCustomObject]@{ FullName='Alice Martin';  TeamName='Controlling';   DeptName='Finance';  Role='Team Lead';       Salary=88000; YearsExp=9;  Performance=89 }
    [PSCustomObject]@{ FullName='Paul Schmidt';  TeamName='Reporting';     DeptName='Finance';  Role='BI Developer';    Salary=76000; YearsExp=5;  Performance=83 }
    [PSCustomObject]@{ FullName='Julia Brown';   TeamName='Talent';        DeptName='HR';       Role='Team Lead';       Salary=82000; YearsExp=8;  Performance=87 }
    [PSCustomObject]@{ FullName='Nina Petrov';   TeamName='Talent';        DeptName='HR';       Role='HR Specialist';   Salary=61000; YearsExp=3;  Performance=74 }
    [PSCustomObject]@{ FullName='Eve Turner';    TeamName='Contracts';     DeptName='Legal';    Role='Team Lead';       Salary=94000; YearsExp=10; Performance=90 }
    [PSCustomObject]@{ FullName='Omar Faruk';    TeamName='Contracts';     DeptName='Legal';    Role='Legal Counsel';   Salary=88000; YearsExp=7;  Performance=85 }
)

# ==============================================================================
#  COMPUTED KPIS
# ==============================================================================
$onlineServers  = ($servers | Where-Object Status -eq 'Online').Count
$offlineServers = ($servers | Where-Object Status -eq 'Offline').Count
$warnServers    = ($servers | Where-Object Status -eq 'Warning').Count
$totalCost      = ($servers | Measure-Object MonthlyCost -Sum).Sum
$totalDisk      = ($servers | Measure-Object DiskFree_Bytes -Sum).Sum
$avgCPU         = [math]::Round(($servers | Measure-Object CPU_Pct -Average).Average, 1)
$runningServices  = ($services | Where-Object Status -eq 'Running').Count
$degradedServices = ($services | Where-Object { $_.Status -ne 'Running' -and $_.Status -ne 'Stopped' }).Count
$activeProjects   = ($projects | Where-Object Status -eq 'In Progress').Count
$totalBudget      = ($projects | Measure-Object Budget -Sum).Sum
$totalSpent       = ($projects | Measure-Object Spent  -Sum).Sum
$totalHeadcount   = ($departments | Measure-Object HeadCount -Sum).Sum

# ==============================================================================
#  THRESHOLD DEFINITIONS
# ==============================================================================
$cpuThresholds = @(
    @{ Max=60;  Class='cell-ok'     }
    @{ Max=80;  Class='cell-warn'   }
    @{          Class='cell-danger' }
)
$serverStatusThresholds = @(
    @{ Value='Online';  Class='cell-ok'     }
    @{ Value='Standby'; Class='cell-warn'   }
    @{ Value='Warning'; Class='cell-warn'   }
    @{ Value='Offline'; Class='cell-danger' }
)
$serviceStatusThresholds = @(
    @{ Value='Running';  Class='cell-ok'     }
    @{ Value='Degraded'; Class='cell-warn'   }
    @{ Value='Stopped';  Class='cell-danger' }
)
$taskPriorityThresholds = @(
    @{ Value='Low';    Class='cell-ok'     }
    @{ Value='Medium'; Class='cell-warn'   }
    @{ Value='High';   Class='cell-danger' }
)
$taskStatusThresholds = @(
    @{ Value='Done';        Class='cell-ok'     }
    @{ Value='In Progress'; Class='cell-warn'   }
    @{ Value='Pending';     Class=''            }
)
$projectStatusThresholds = @(
    @{ Value='Completed';   Class='cell-ok'     }
    @{ Value='In Progress'; Class='cell-warn'   }
    @{ Value='Planning';    Class=''            }
)
$performanceThresholds = @(
    @{ Min=85;      Class='cell-ok'     }
    @{ Min=70;      Class='cell-warn'   }
    @{              Class='cell-danger' }
)
$budgetVsSpentThresholds = @(
    @{ Max=40;  Class='cell-ok'     }
    @{ Max=75;  Class='cell-warn'   }
    @{          Class='cell-danger' }
)

# ==============================================================================
#  BUILD DASHBOARD
# ==============================================================================
$report = New-DhDashboard `
    -Title    'DashHtml Feature Showcase' `
    -Subtitle "Full module demo  |  Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm')" `
    -LogoPath $LogoPath `
    -Theme    $Theme `
    -NavTitle 'DashHtml Demo' `
    -InfoFields @(
        @{ Label='Organization';    Value='Contoso Corporation'    }
        @{ Label='Environment';     Value='Demo / Non-production'  }
        @{ Label='Servers';         Value="$($servers.Count)"      }
        @{ Label='Services';        Value="$($services.Count)"     }
        @{ Label='Projects';        Value="$($projects.Count)"     }
        @{ Label='Headcount';       Value="$totalHeadcount people" }
    )

# ==============================================================================
#  GROUP: OVERVIEW  (no NavGroup = flat links in primary bar)
# ==============================================================================

# ── KPI Summary tiles — demonstrates all Format types ─────────────────────────
Add-DhSummary -Report $report -Items @(
    @{ Label='Servers Online';   Value=$onlineServers;     Icon='✅'; Class='cell-ok' }
    @{ Label='Servers Warning';  Value=$warnServers;       Icon='⚠';
       Class=$(if ($warnServers -gt 0) { 'cell-warn' } else { 'cell-ok' }) }
    @{ Label='Servers Offline';  Value=$offlineServers;    Icon='🔴';
       Class=$(if ($offlineServers -gt 0) { 'cell-danger' } else { 'cell-ok' }) }
    @{ Label='Avg CPU';          Value=($avgCPU/100);      Icon='⚙';  Format='percent'; Decimals=1 }
    @{ Label='Free Disk (total)';Value=$totalDisk;         Icon='💾'; Format='bytes'   }
    @{ Label='Infra Cost/mo';    Value=$totalCost;         Icon='💰'; Format='currency'; Locale='en-US'; Currency='USD'; Decimals=2 }
    @{ Label='Active Projects';  Value=$activeProjects;    Icon='📋' }
    @{ Label='Budget Spent';     Value=($totalSpent/$totalBudget); Icon='📊'; Format='percent'; Decimals=1 }
    @{ Label='Headcount';        Value=$totalHeadcount;    Icon='👥'; Format='number'  }
    @{ Label='Services Running'; Value=$runningServices;   Icon='🔗'; Class='cell-ok'  }
)

# ── HTML blocks — all 5 styles ─────────────────────────────────────────────────
Add-DhHtmlBlock -Report $report -Id 'block-info' -Title 'How to use this dashboard' `
    -Icon '📋' -Style 'info' -Content @"
Navigate using the <strong>top tab bar</strong>. Each group exposes a subnav below.
<ul style="margin:6px 0 0 16px">
  <li><strong>Infrastructure</strong> — bar charts, filter cards, server/service tables with master→detail drill-down</li>
  <li><strong>Projects</strong> — project portfolio linked to task detail</li>
  <li><strong>People</strong> — 3-level chain: Departments → Teams → Employees</li>
</ul>
<p style="margin-top:6px">
  <kbd>Shift+Click</kbd> column headers for multi-column sort &nbsp;|&nbsp;
  Right-click a cell to copy its value &nbsp;|&nbsp;
  <strong>⊞ Columns</strong> button toggles column visibility
</p>
"@

Add-DhHtmlBlock -Report $report -Id 'block-warn' -Style 'warn' -Content `
    '<strong>Attention:</strong> 3 servers are in Warning state and 2 are Offline. Review the Infrastructure section for details.'

Add-DhHtmlBlock -Report $report -Id 'block-danger' -Style 'danger' -Content `
    '<strong>Critical:</strong> <em>srv-old-01</em> and <em>srv-old-02</em> are running Windows Server 2016 — end of mainstream support reached. Plan upgrade immediately.'

Add-DhHtmlBlock -Report $report -Id 'block-ok' -Style 'ok' -Content `
    'All primary database services (SQL Server) are healthy. Last backup verified 2026-04-11 03:15.'

Add-DhHtmlBlock -Report $report -Id 'block-neutral' -Style 'neutral' -Content `
    "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') &nbsp;|&nbsp; Module: DashHtml &nbsp;|&nbsp; Data is synthetic — for demonstration purposes only."

# ── Collapsible: card-grid mode ────────────────────────────────────────────────
Add-DhCollapsible -Report $report -Id 'org-cards' `
    -Title 'Organisation at a glance' -Icon '🏢' -DefaultOpen $true `
    -Cards ($departments | ForEach-Object {
        $d = $_
        @{
            Title      = $d.DeptName
            Badge      = "$($d.HeadCount) people"
            BadgeClass = ''
            Fields     = @(
                @{ Label='Manager';     Value=$d.Manager }
                @{ Label='Budget';      Value=('${0:N0}' -f $d.Budget) }
                @{ Label='Utilization'; Value="$($d.Utilization) %" }
                @{ Label='Status';      Value=$d.Status; Class='cell-ok' }
            )
        }
    })

# ── Collapsible: free-form HTML content mode ───────────────────────────────────
Add-DhCollapsible -Report $report -Id 'feature-notes' `
    -Title 'DashHtml — Feature reference' -Icon '📖' -DefaultOpen $false `
    -Content @"
<table style="border-collapse:collapse;width:100%;font-size:0.88rem">
  <thead><tr style="background:var(--bg-thead)">
    <th style="padding:6px 12px;text-align:left;border-bottom:1px solid var(--border-medium)">Feature</th>
    <th style="padding:6px 12px;text-align:left;border-bottom:1px solid var(--border-medium)">Cmdlet / Parameter</th>
    <th style="padding:6px 12px;text-align:left;border-bottom:1px solid var(--border-medium)">Where in this demo</th>
  </tr></thead>
  <tbody>
    <tr><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">KPI tiles</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Add-DhSummary</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Overview — top strip</td></tr>
    <tr><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">HTML blocks (5 styles)</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Add-DhHtmlBlock -Style</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Overview — info/warn/danger/ok/neutral</td></tr>
    <tr><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Collapsible cards</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Add-DhCollapsible -Cards</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Overview — Organisation</td></tr>
    <tr><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Collapsible free HTML</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Add-DhCollapsible -Content</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">This panel</td></tr>
    <tr><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Bar chart + click filter</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Add-DhBarChart -ClickFilters</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Infrastructure</td></tr>
    <tr><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Filter card (single)</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Add-DhFilterCard</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Infrastructure — Status</td></tr>
    <tr><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Filter card (multi)</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Add-DhFilterCard -MultiFilter</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Infrastructure — Location</td></tr>
    <tr><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Progress bar cells</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">CellType='progressbar'</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Servers (CPU%), Projects (Progress)</td></tr>
    <tr><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Badge cells</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">CellType='badge'</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Servers (Status), Services (Status), Tasks (Priority)</td></tr>
    <tr><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">All Format types</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Format= number/currency/bytes/percent/datetime/duration</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Servers table</td></tr>
    <tr><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Aggregate footer</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Aggregate= sum/avg/count</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Servers, Projects, Employees</td></tr>
    <tr><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Pinned first column</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">PinFirst=$true</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Servers, Projects, Employees</td></tr>
    <tr><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Row highlighting</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">RowHighlight=$true</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Servers (Status), Tasks (Priority)</td></tr>
    <tr><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">2-level table link</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Set-DhTableLink</td><td style="padding:5px 12px;border-bottom:1px solid var(--border-subtle)">Servers → Services, Projects → Tasks</td></tr>
    <tr><td style="padding:5px 12px">3-level table chain</td><td style="padding:5px 12px">Set-DhTableLink (chained)</td><td style="padding:5px 12px">Departments → Teams → Employees</td></tr>
  </tbody>
</table>
"@

# ==============================================================================
#  GROUP: INFRASTRUCTURE
# ==============================================================================

# ── Bar chart: Servers by OS — ShowPercent only (no click filter, for contrast)
Add-DhBarChart -Report $report -Id 'chart-os' `
    -Title 'Servers by OS' `
    -TableId 'servers' -Field 'OS' -TopN 8 `
    -ShowCount $true -ShowPercent `
    -NavGroup 'Infrastructure'

# ── Bar chart: Servers by Type — ClickFilters enabled ─────────────────────────
Add-DhBarChart -Report $report -Id 'chart-status' `
    -Title 'Servers by Status (click bar to filter table)' `
    -TableId 'servers' -Field 'Status' -TopN 6 `
    -ShowCount $true -ShowPercent -ClickFilters `
    -NavGroup 'Infrastructure'

# ── Filter cards: Status — single-select ──────────────────────────────────────
$statusCards = $servers | Group-Object Status | Sort-Object Count -Descending | ForEach-Object {
    @{ Label=$_.Name; Value=$_.Name; Count=$_.Count }
}
Add-DhFilterCard -Report $report -Id 'filter-status' `
    -Title 'Filter Servers by Status' `
    -TargetTableId 'servers' -FilterField 'Status' `
    -Cards $statusCards `
    -NavGroup 'Infrastructure'

# ── Filter cards: Location — multi-select ────────────────────────────────────
$locationCards = $servers | Group-Object Location | Sort-Object Count -Descending | ForEach-Object {
    @{ Label=$_.Name; Value=$_.Name; Count=$_.Count }
}
Add-DhFilterCard -Report $report -Id 'filter-location' `
    -Title 'Filter Servers by Location (multi-select)' `
    -TargetTableId 'servers' -FilterField 'Location' `
    -MultiFilter $true `
    -Cards $locationCards `
    -NavGroup 'Infrastructure'

# ── Table: Servers — demonstrates every column feature ────────────────────────
$serverCols = @(
    @{ Field='Name';          Label='Server Name';   Width='155px'; Bold=$true;  PinFirst=$true }
    @{ Field='OS';            Label='OS';            Width='185px' }
    @{ Field='Location';      Label='Location';      Width='100px' }
    @{ Field='Status';        Label='Status';        Width='100px'; CellType='badge';
       Thresholds=$serverStatusThresholds; RowHighlight=$true }
    @{ Field='CPU_Pct';       Label='CPU %';         Width='120px'; CellType='progressbar'; ProgressMax=100;
       Thresholds=$cpuThresholds }
    @{ Field='RAM_GB';        Label='RAM';           Width='80px';  Align='right';
       Format='number'; Decimals=0; Aggregate='sum' }
    @{ Field='DiskFree_Bytes';Label='Free Disk';     Width='100px'; Align='right';
       Format='bytes'; Aggregate='sum' }
    @{ Field='MonthlyCost';   Label='Cost/mo (USD)'; Width='120px'; Align='right';
       Format='currency'; Locale='en-US'; Currency='USD'; Decimals=2; Aggregate='sum' }
    @{ Field='Uptime_Sec';    Label='Uptime';        Width='110px'; Format='duration' }
    @{ Field='LastPatch';     Label='Last Patched';  Width='145px'; Format='datetime';
       DatePattern='yyyy-MM-dd'; Italic=$true }
)
Add-DhTable -Report $report -TableId 'servers' -Title 'Servers' `
    -Description 'Full server inventory. Click a row to filter the Services table below. Bars = CPU utilisation. Cost aggregate in footer.' `
    -Data $servers -Columns $serverCols -PageSize 10 `
    -ExportFileName 'servers-export' `
    -Charts @(
        @{ Title='By OS';       Field='OS';       Type='pie' }
        @{ Title='By Status';   Field='Status';   Type='pie' }
        @{ Title='By Location'; Field='Location'; Type='pie' }
    ) `
    -NavGroup 'Infrastructure'

# ── Table: Services (linked from Servers) ─────────────────────────────────────
$serviceCols = @(
    @{ Field='ServiceName'; Label='Service';     Width='160px'; Bold=$true; PinFirst=$true }
    @{ Field='ServerName';  Label='Server';      Width='150px'; Font='mono' }
    @{ Field='Protocol';    Label='Protocol';    Width='85px'  }
    @{ Field='Port';        Label='Port';        Width='65px';  Align='right'; Format='number'; Decimals=0 }
    @{ Field='Status';      Label='Status';      Width='100px'; CellType='badge';
       Thresholds=$serviceStatusThresholds; RowHighlight=$true }
    @{ Field='Uptime_Pct';  Label='Uptime %';    Width='120px'; CellType='progressbar'; ProgressMax=100;
       Thresholds=@(@{ Min=99; Class='cell-ok' }; @{ Min=95; Class='cell-warn' }; @{ Class='cell-danger' }) }
    @{ Field='ResponseMs';  Label='Response ms'; Width='110px'; Align='right';
       Format='number'; Decimals=0;
       Thresholds=@(@{ Max=50; Class='cell-ok' }; @{ Max=200; Class='cell-warn' }; @{ Class='cell-danger' })
       Aggregate='avg' }
)
Add-DhTable -Report $report -TableId 'services' -Title 'Services' `
    -Description 'Services running on each server. Filtered automatically when a server row is selected above.' `
    -Data $services -Columns $serviceCols -PageSize 20 `
    -ExportFileName 'services-export' `
    -Charts @( @{ Title='By Status'; Field='Status'; Type='pie' } ) `
    -NavGroup 'Infrastructure'

# ── Link: Servers → Services ──────────────────────────────────────────────────
Set-DhTableLink -Report $report `
    -MasterTableId 'servers' -DetailTableId 'services' `
    -MasterField 'Name' -DetailField 'ServerName'

# ==============================================================================
#  GROUP: PROJECTS
# ==============================================================================

# ── Table: Projects ───────────────────────────────────────────────────────────
$projectCols = @(
    @{ Field='ProjectId'; Label='ID';          Width='90px';  Font='mono'; Bold=$true; PinFirst=$true }
    @{ Field='Name';      Label='Project';     Width='210px'; Bold=$true }
    @{ Field='Department';Label='Dept';        Width='100px' }
    @{ Field='Status';    Label='Status';      Width='115px'; CellType='badge';
       Thresholds=$projectStatusThresholds }
    @{ Field='Priority';  Label='Priority';    Width='95px';  CellType='badge';
       Thresholds=$taskPriorityThresholds; RowHighlight=$true }
    @{ Field='Progress';  Label='Progress';    Width='130px'; CellType='progressbar'; ProgressMax=100;
       Thresholds=@(@{ Min=75; Class='cell-ok' }; @{ Min=40; Class='cell-warn' }; @{ Class='cell-danger' }) }
    @{ Field='Budget';    Label='Budget (USD)'; Width='120px'; Align='right';
       Format='currency'; Locale='en-US'; Currency='USD'; Decimals=0; Aggregate='sum' }
    @{ Field='Spent';     Label='Spent (USD)';  Width='120px'; Align='right';
       Format='currency'; Locale='en-US'; Currency='USD'; Decimals=0; Aggregate='sum' }
    @{ Field='StartDate'; Label='Start';       Width='100px'; Format='datetime'; DatePattern='yyyy-MM-dd' }
    @{ Field='DueDate';   Label='Due';         Width='100px'; Format='datetime'; DatePattern='yyyy-MM-dd'; Italic=$true }
)
Add-DhTable -Report $report -TableId 'projects' -Title 'Projects' `
    -Description 'Project portfolio. Select a row to filter the Tasks table below. Budget and Spent totals in footer.' `
    -Data $projects -Columns $projectCols -PageSize 10 `
    -ExportFileName 'projects-export' `
    -Charts @(
        @{ Title='By Status';     Field='Status';     Type='pie' }
        @{ Title='By Priority';   Field='Priority';   Type='pie' }
        @{ Title='By Department'; Field='Department'; Type='pie' }
    ) `
    -NavGroup 'Projects'

# ── Table: Tasks (linked from Projects) ───────────────────────────────────────
$taskCols = @(
    @{ Field='TaskId';      Label='ID';         Width='80px';  Font='mono'; Italic=$true; PinFirst=$true }
    @{ Field='ProjectId';   Label='Project';    Width='95px';  Font='mono' }
    @{ Field='Name';        Label='Task';       Width='240px'; Bold=$true }
    @{ Field='Assignee';    Label='Assignee';   Width='145px' }
    @{ Field='Priority';    Label='Priority';   Width='95px';  CellType='badge';
       Thresholds=$taskPriorityThresholds; RowHighlight=$true }
    @{ Field='Status';      Label='Status';     Width='115px'; CellType='badge';
       Thresholds=$taskStatusThresholds }
    @{ Field='EstHours';    Label='Est. hrs';   Width='85px';  Align='right';
       Format='number'; Decimals=0; Aggregate='sum' }
    @{ Field='ActualHours'; Label='Actual hrs'; Width='90px';  Align='right';
       Format='number'; Decimals=0; Aggregate='sum' }
)
Add-DhTable -Report $report -TableId 'tasks' -Title 'Tasks' `
    -Description 'Task list filtered by the selected project above. Row colour = priority. Est/Actual hour totals in footer.' `
    -Data $tasks -Columns $taskCols -PageSize 15 `
    -ExportFileName 'tasks-export' `
    -Charts @(
        @{ Title='By Status';   Field='Status';   Type='pie' }
        @{ Title='By Priority'; Field='Priority'; Type='pie' }
    ) `
    -NavGroup 'Projects'

# ── Bar chart: tasks by assignee ──────────────────────────────────────────────
Add-DhBarChart -Report $report -Id 'chart-assignee' `
    -Title 'Tasks by Assignee' `
    -TableId 'tasks' -Field 'Assignee' -TopN 10 `
    -ShowCount $true -ShowPercent `
    -NavGroup 'Projects'

# ── Bar chart: tasks by priority — ClickFilters ───────────────────────────────
Add-DhBarChart -Report $report -Id 'chart-priority' `
    -Title 'Tasks by Priority (click to filter)' `
    -TableId 'tasks' -Field 'Priority' -TopN 5 `
    -ShowCount $true -ShowPercent -ClickFilters `
    -NavGroup 'Projects'

# ── Link: Projects → Tasks ────────────────────────────────────────────────────
Set-DhTableLink -Report $report `
    -MasterTableId 'projects' -DetailTableId 'tasks' `
    -MasterField 'ProjectId' -DetailField 'ProjectId'

# ==============================================================================
#  GROUP: PEOPLE  (3-level chain: Departments → Teams → Employees)
# ==============================================================================

# ── Table: Departments ────────────────────────────────────────────────────────
$deptCols = @(
    @{ Field='DeptName';    Label='Department'; Width='130px'; Bold=$true; PinFirst=$true }
    @{ Field='Manager';     Label='Manager';    Width='140px' }
    @{ Field='HeadCount';   Label='People';     Width='80px';  Align='right';
       Format='number'; Decimals=0; Aggregate='sum' }
    @{ Field='Budget';      Label='Budget (USD)'; Width='130px'; Align='right';
       Format='currency'; Locale='en-US'; Currency='USD'; Decimals=0; Aggregate='sum' }
    @{ Field='Utilization'; Label='Utilization'; Width='130px'; CellType='progressbar'; ProgressMax=100;
       Thresholds=@(@{ Min=85; Class='cell-danger' }; @{ Min=70; Class='cell-warn' }; @{ Class='cell-ok' }) }
    @{ Field='Status';      Label='Status';     Width='90px';  CellType='badge';
       Thresholds=@(@{ Value='Active'; Class='cell-ok' }) }
)
Add-DhTable -Report $report -TableId 'departments' -Title 'Departments' `
    -Description 'Select a department row to filter the Teams table. Budget totals in footer.' `
    -Data $departments -Columns $deptCols -PageSize 10 `
    -Charts @( @{ Title='Headcount distribution'; Field='DeptName'; Type='pie' } ) `
    -NavGroup 'People'

# ── Bar chart: headcount by department ────────────────────────────────────────
Add-DhBarChart -Report $report -Id 'chart-dept' `
    -Title 'Headcount by Department (click to filter Teams)' `
    -TableId 'departments' -Field 'DeptName' -TopN 10 `
    -ShowCount $true -ClickFilters `
    -NavGroup 'People'

# ── Table: Teams (linked from Departments) ────────────────────────────────────
$teamCols = @(
    @{ Field='TeamName';      Label='Team';        Width='150px'; Bold=$true; PinFirst=$true }
    @{ Field='DeptName';      Label='Department';  Width='120px' }
    @{ Field='Lead';          Label='Team Lead';   Width='145px' }
    @{ Field='Members';       Label='Members';     Width='80px';  Align='right';
       Format='number'; Decimals=0; Aggregate='sum' }
    @{ Field='ActiveProjects';Label='Active Proj'; Width='100px'; Align='right';
       Thresholds=@(@{ Max=1; Class='' }; @{ Max=3; Class='cell-warn' }; @{ Class='cell-danger' })
       Aggregate='sum' }
)
Add-DhTable -Report $report -TableId 'teams' -Title 'Teams' `
    -Description 'Teams filtered by the selected department. Select a team row to filter the Employees table.' `
    -Data $teams -Columns $teamCols -PageSize 15 `
    -NavGroup 'People'

# ── Table: Employees (linked from Teams) ──────────────────────────────────────
$empCols = @(
    @{ Field='FullName';   Label='Name';         Width='160px'; Bold=$true; PinFirst=$true }
    @{ Field='Role';       Label='Role';         Width='175px' }
    @{ Field='TeamName';   Label='Team';         Width='140px' }
    @{ Field='DeptName';   Label='Department';   Width='115px' }
    @{ Field='Salary';     Label='Salary (USD)'; Width='125px'; Align='right';
       Format='currency'; Locale='en-US'; Currency='USD'; Decimals=0; Aggregate='avg' }
    @{ Field='YearsExp';   Label='Experience';   Width='100px'; Align='right';
       Format='number'; Decimals=0; Aggregate='avg' }
    @{ Field='Performance';Label='Performance';  Width='130px'; CellType='progressbar'; ProgressMax=100;
       Thresholds=$performanceThresholds }
)
Add-DhTable -Report $report -TableId 'employees' -Title 'Employees' `
    -Description 'Employee roster filtered by the selected team. Performance bar coloured by threshold. Avg salary and experience in footer.' `
    -Data $employees -Columns $empCols -PageSize 15 -MultiSelect `
    -ExportFileName 'employees-export' `
    -NavGroup 'People'

# ── Links: 3-level chain Departments → Teams → Employees ─────────────────────
Set-DhTableLink -Report $report `
    -MasterTableId 'departments' -DetailTableId 'teams' `
    -MasterField 'DeptName' -DetailField 'DeptName'

Set-DhTableLink -Report $report `
    -MasterTableId 'teams' -DetailTableId 'employees' `
    -MasterField 'TeamName' -DetailField 'TeamName'

# ==============================================================================
#  EXPORT
# ==============================================================================
Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser

Write-Host ''
Write-Host "  Dashboard : $OutputPath" -ForegroundColor Cyan
Write-Host "  Theme     : $Theme"      -ForegroundColor White
Write-Host "  Servers   : $($servers.Count)    Services: $($services.Count)"   -ForegroundColor DarkGray
Write-Host "  Projects  : $($projects.Count)   Tasks:    $($tasks.Count)"    -ForegroundColor DarkGray
Write-Host "  Depts     : $($departments.Count)      Teams:    $($teams.Count)    Employees: $($employees.Count)" -ForegroundColor DarkGray
Write-Host ''
Write-Host "  XLSX/PDF export requires internet (cdnjs.cloudflare.com)." -ForegroundColor DarkYellow
Write-Host ''
