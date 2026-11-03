#Requires -Version 7.4
<#
.SYNOPSIS
    Gantt timelines with Add-DhGantt (DashHtml 3.1.0).

.DESCRIPTION
    MENU
        Recovery test        steps on a clock axis, phases sharing one row, application
                             groups from a common origin with the critical path
        Nightly backups      one bar per job from a table (it follows the table filter),
                             overlapping jobs of one client packed into sub-lines, the
                             backup window as a band
        Certificates         validity over years, a "today" marker, expired and expiring

    All data is invented (Contoso). Times are drawn as the wall clock they carry, whatever the
    reader's time zone: the browser never parses a date.

.PARAMETER OutputPath
    Where to write the HTML.

.PARAMETER Theme
    Default, Azure, VMware, Grey, Company or Rag.

.PARAMETER OpenInBrowser
    Open the dashboard once generated.

.EXAMPLE
    PS> ./Examples/Feature-Gantt.ps1 -OpenInBrowser
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Feature-Gantt.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Default',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force

$note = { param([string] $Id, [string] $Path, [string] $Text) Add-DhHtmlBlock -Report $report -Id $Id -Title 'In this view' -Style info -NavPath $Path -Content $Text -AllowHtml:$false }

$report = New-DhDashboard -Title 'Gantt timelines' -Subtitle 'Add-DhGantt: tasks, jobs and validity on a time axis' -NavTitle 'Gantt' -Theme $Theme `
    -GeneratedBy 'Feature-Gantt.ps1'

# ============================================================== RECOVERY TEST
$t0 = [datetime]'2026-06-13 06:10:00'
& $note 'n-dr' 'Recovery' 'A recovery test at Contoso: three steps on a clock axis, the phases of the compute step as segments of one row, and the application start order as elapsed time from a common origin.'

Add-DhGantt -Report $report -Id 'dr-steps' -Title 'Recovery steps' -NavPath 'Recovery' -NavLabel 'Recovery test' -Items @(
    @{ Id = 'st'; Label = 'Storage: clone and map volumes'; Start = $t0;                 End = $t0.AddSeconds(269);  Status = 'ok' }
    @{ Id = 'cp'; Label = 'Compute: register and start';    Start = $t0.AddSeconds(270); End = $t0.AddSeconds(3364); Status = 'ok'; Critical = $true; DependsOn = 'st' }
    @{ Id = 'ap'; Label = 'Applications: start in order';   Start = $t0.AddSeconds(3364); End = $t0.AddSeconds(4426); Status = 'warn'; DependsOn = 'cp'
       Detail = @{ Title = 'Applications'; Sections = @(
           @{ Kind = 'kv'; Items = @(
               @{ Label = 'Groups'; Value = '8 of 8 started' }
               @{ Label = 'Slowest VM'; Value = 'app-rpt01, 76 s to tools and IP'; Status = 'warn' }) }
           @{ Kind = 'text'; Text = 'One group waited for its database twice; the plan allowed it.' }) } }
    @{ Label = 'Sign-off'; Start = $t0.AddSeconds(4500) }
) -Markers @(@{ At = $t0.AddMinutes(90); Label = 'RTO target'; Status = 'warn' }) -ShowDataTable

Add-DhGantt -Report $report -Id 'dr-phases' -Title 'Compute step, phase by phase' -NavPath 'Recovery' -Items @(
    @{ Row = 'Compute'; Label = 'Connect';            Start = 0;    End = 33;   Category = 'Preparation' }
    @{ Row = 'Compute'; Label = 'Rescan storage';     Start = 33;   End = 111;  Category = 'Storage' }
    @{ Row = 'Compute'; Label = 'Resignature';        Start = 111;  End = 538;  Category = 'Storage' }
    @{ Row = 'Compute'; Label = 'Register VMs';       Start = 538;  End = 772;  Category = 'Inventory' }
    @{ Row = 'Compute'; Label = 'Remap networks';     Start = 772;  End = 1257; Category = 'Network' }
    @{ Row = 'Compute'; Label = 'Domain controllers'; Start = 1257; End = 1968; Category = 'Core services' }
    @{ Row = 'Compute'; Label = 'Infrastructure';     Start = 1968; End = 3057; Category = 'Core services' }
    @{ Row = 'Compute'; Label = 'Final inventory';    Start = 3057; End = 3094; Category = 'Inventory' }
) -Unit s

Add-DhGantt -Report $report -Id 'dr-apps' -Title 'Application groups (seconds from the start of the step)' -NavPath 'Recovery' -Unit s -Items @(
    @{ Id = 'db';  Group = 'Data';         Label = 'Database';  Start = 0;   End = 446;  Critical = $true }
    @{ Id = 'au';  Group = 'Business';     Label = 'Identity';  Start = 16;  End = 116 }
    @{ Id = 'ap';  Group = 'Business';     Label = 'App';       Start = 451; End = 573;  DependsOn = 'db' }
    @{ Id = 'be';  Group = 'Business';     Label = 'Backend';   Start = 470; End = 894;  DependsOn = 'db'; Critical = $true }
    @{ Id = 'ot';  Group = 'Business';     Label = 'Other';     Start = 709; End = 752;  DependsOn = 'ap' }
    @{ Id = 'wb';  Group = 'Presentation'; Label = 'Web';       Start = 578; End = 704;  DependsOn = 'ap' }
    @{ Id = 'fe';  Group = 'Presentation'; Label = 'Frontend';  Start = 898; End = 1015; DependsOn = 'be' }
    @{ Id = 'rp';  Group = 'Presentation'; Label = 'Reporting'; Start = 918; End = 1051; DependsOn = 'be'; Critical = $true; Status = 'warn'; Tooltip = 'One VM took 76 s' }
) -Markers @(@{ At = 900; Label = '15 min'; Status = 'info' })

# ============================================================== NIGHTLY BACKUPS
$night = [datetime]'2026-06-12 22:00:00'
$clients = 'srv-db01', 'srv-db02', 'srv-file01', 'srv-file02', 'srv-app01', 'srv-app02', 'srv-mail01', 'srv-web01'
$jobs = [System.Collections.Generic.List[object]]::new()
$i = 0
foreach ($c in $clients) {
    $i++
    $start = $night.AddMinutes(($i * 37) % 180)
    $len   = 60 + ($i * 53) % 240
    $res   = if ($c -eq 'srv-file02') { 'Failed' } elseif ($i % 4 -eq 0) { 'Warning' } else { 'OK' }
    $jobs.Add([ordered]@{ Client = $c; Job = "$c full"; Type = 'Full'; Started = $start; Ended = $start.AddMinutes($len); Result = $res; SizeGB = 40 + ($i * 17) % 300 })
    # a second job that overlaps the first: it shows as a sub-line of the same client
    $s2 = $start.AddMinutes(20 + ($i * 11) % 40)
    $jobs.Add([ordered]@{ Client = $c; Job = "$c logs"; Type = 'Log'; Started = $s2; Ended = $s2.AddMinutes(15 + $i * 3); Result = 'OK'; SizeGB = 2 + $i })
}
# one job that overruns the window
$jobs.Add([ordered]@{ Client = 'srv-arch01'; Job = 'srv-arch01 full'; Type = 'Full'; Started = $night.AddHours(3); Ended = $night.AddHours(8.5); Result = 'Warning'; SizeGB = 1900 })

& $note 'n-bk' 'Backups' 'One bar per job of the table below, one line per client: overlapping jobs of a client are packed into sub-lines. Open Jobs and filter the table: the chart follows it. The shaded band is the backup window.'
Add-DhTable -Report $report -TableId 'jobs' -Title 'Backup jobs' -NavPath 'Backups/jobs' -NavLabel 'Jobs' -Data $jobs -PageSize 10 -Columns @(
    @{ Field = 'Client'; Label = 'Client' }, @{ Field = 'Job'; Label = 'Job' }, @{ Field = 'Type'; Label = 'Type' }
    @{ Field = 'Started'; Label = 'Started'; Format = 'datetime'; DatePattern = 'yyyy-MM-dd HH:mm' }, @{ Field = 'Ended'; Label = 'Ended'; Format = 'datetime'; DatePattern = 'yyyy-MM-dd HH:mm' }
    @{ Field = 'Result'; Label = 'Result'; CellType = 'badge'; Thresholds = @(
        @{ Value = 'OK'; Class = 'cell-ok' }, @{ Value = 'Warning'; Class = 'cell-warn' }, @{ Value = 'Failed'; Class = 'cell-danger' }) }
    @{ Field = 'SizeGB'; Label = 'Size (GB)'; Format = 'number' })
Add-DhGantt -Report $report -Id 'bk-gantt' -Title 'Last night' -NavPath 'Backups' -NavScope Subtree -NavLabel 'Nightly backups' `
    -TableId 'jobs' -LabelField 'Job' -StartField 'Started' -EndField 'Ended' -RowField 'Client' -StatusField 'Result' `
    -SortBy Start -Bands @(@{ From = $night; To = $night.AddHours(8); Label = 'Backup window 22:00-06:00' })

# ============================================================== CERTIFICATES
$today = (Get-Date).Date
$certs = @(
    @{ Name = 'www.contoso.example';     Issuer = 'Public CA';   From = $today.AddDays(-300); To = $today.AddDays(65) }
    @{ Name = 'mail.contoso.example';    Issuer = 'Public CA';   From = $today.AddDays(-350); To = $today.AddDays(15) }
    @{ Name = 'vpn.contoso.example';     Issuer = 'Public CA';   From = $today.AddDays(-380); To = $today.AddDays(-15) }
    @{ Name = 'api.contoso.example';     Issuer = 'Public CA';   From = $today.AddDays(-30);  To = $today.AddDays(335) }
    @{ Name = 'Domain controllers';      Issuer = 'Contoso CA';  From = $today.AddDays(-400); To = $today.AddDays(330) }
    @{ Name = 'Intranet';                Issuer = 'Contoso CA';  From = $today.AddDays(-600); To = $today.AddDays(495) }
    @{ Name = 'Code signing';            Issuer = 'Contoso CA';  From = $today.AddDays(-200); To = $today.AddDays(900) }
    @{ Name = 'Contoso Issuing CA';      Issuer = 'Contoso Root'; From = $today.AddDays(-900); To = $today.AddDays(1200) }
) | ForEach-Object {
    $days = ($_.To - $today).Days
    [ordered]@{
        Certificate = $_.Name; Issuer = $_.Issuer; NotBefore = $_.From; NotAfter = $_.To; DaysLeft = $days
        Status = $(if ($days -lt 0) { 'danger' } elseif ($days -lt 30) { 'warn' } else { 'ok' })
    }
}
& $note 'n-ct' 'Certificates' 'Validity of each certificate, grouped by issuer, with today as a marker: red has expired, amber expires within 30 days.'
Add-DhTable -Report $report -TableId 'certs' -Title 'Certificates' -NavPath 'Certificates/certs' -NavLabel 'Certificates' -Data $certs -Columns @(
    @{ Field = 'Certificate'; Label = 'Certificate' }, @{ Field = 'Issuer'; Label = 'Issuer' }
    @{ Field = 'NotBefore'; Label = 'Not before'; Format = 'datetime'; DatePattern = 'yyyy-MM-dd' }, @{ Field = 'NotAfter'; Label = 'Not after'; Format = 'datetime'; DatePattern = 'yyyy-MM-dd' }
    @{ Field = 'DaysLeft'; Label = 'Days left'; Format = 'number' }
    @{ Field = 'Status'; Label = 'Status'; CellType = 'badge'; Thresholds = @(
        @{ Value = 'ok'; Class = 'cell-ok' }, @{ Value = 'warn'; Class = 'cell-warn' }, @{ Value = 'danger'; Class = 'cell-danger' }) })
Add-DhGantt -Report $report -Id 'ct-gantt' -Title 'Validity' -NavPath 'Certificates' -NavScope Subtree -NavLabel 'Validity' `
    -TableId 'certs' -LabelField 'Certificate' -StartField 'NotBefore' -EndField 'NotAfter' -GroupField 'Issuer' -StatusField 'Status' `
    -SortBy End -ShowDuration $false -Markers @(@{ At = $today; Label = 'Today'; Status = 'info' })

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
