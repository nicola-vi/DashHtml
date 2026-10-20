#Requires -Version 7.0
<#
.SYNOPSIS
    Azure infrastructure review: cost, compute, network, storage, security and governance (synthetic data).

.DESCRIPTION
    A realistic Azure estate report for three subscriptions, laid out as a menu.

    MENU (what opens where)
        Overview                       verdict, secure score, headline KPIs, cost trend
        Cost
            Trend                      monthly cost by subscription and by service
            Top resources              the most expensive resources
        Compute
            Virtual machines           size, power state, one row per VM
            Kubernetes                 AKS clusters as expandable records
        Network
            Topology                   hub and spoke virtual networks, peering health
            Exposure                   network security group rules open to the internet
        Storage                        storage accounts and their settings
        Security
            Recommendations            Defender findings, with proof per resource
            Posture                    secure score and security maturity
        Governance
            Policy                     compliance by subscription and initiative
            Tags                       tag coverage, resources without an owner

    WHAT IS GLOBAL AND WHAT IS NOT
        * A "Subscription" dropdown above everything narrows every table that has a Subscription
          column, on every view. One banner is visible everywhere.
        * "Cost", "Compute" and "Security" each carry a KPI strip declared with -NavScope Subtree,
          so it sits at the top of every view under that menu item.
        * Everything else is bound to exactly one view.
        * Page order inside a view: banners, global filters, global KPI tiles, blocks in the order
          declared, then tables in the order declared (tables always last).

    Run Tools/Show-DhNavMap.ps1 on the result to print the menu and each view's content.

    All data is synthetic and deterministic. Replace the data section with Azure Resource Graph,
    Cost Management and Defender for Cloud queries when adapting.

.PARAMETER OutputPath
    Where to write the HTML. Defaults to Demo-AzureInfrastructure.html beside this script.

.PARAMETER Theme
    Default, Azure, VMware, Grey, Company or Rag.

.PARAMETER OpenInBrowser
    Open the dashboard once generated.

.EXAMPLE
    PS> ./Examples/Demo-AzureInfrastructure.ps1 -OpenInBrowser
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'Demo-AzureInfrastructure.html'),
    [ValidateSet('Default','Azure','VMware','Grey','Company','Rag')]
    [string] $Theme = 'Azure',
    [switch] $OpenInBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force

# ============================================================================
# Data (synthetic, deterministic)
# ============================================================================
$rng = [System.Random]::new(11)
$subs = @('contoso-prod', 'contoso-nonprod', 'contoso-shared')
$regions = @('westeurope', 'northeurope', 'italynorth')
$months = @('May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct')

$vmSizes = @('Standard_D4s_v5', 'Standard_D8s_v5', 'Standard_E8s_v5', 'Standard_B2ms', 'Standard_F8s_v2')
$vms = foreach ($i in 1..36) {
    $sub = $subs[$i % 3]
    [pscustomobject]@{
        Name = 'vm-{0}-{1:00}' -f $sub.Split('-')[1], $i
        Subscription = $sub
        Region = $regions[$i % 3]
        Size = $vmSizes[$i % 5]
        Os = $(if ($i % 4 -eq 0) { 'Windows Server 2022' } else { 'Ubuntu 22.04' })
        Power = @('Running', 'Running', 'Running', 'Running', 'Deallocated', 'Stopped')[$rng.Next(0, 6)]
        CpuAvg = 8 + $rng.Next(0, 80)
        MonthlyCost = [math]::Round(60 + $rng.Next(0, 900) + $rng.NextDouble(), 2)
        Owner = $(if ($i % 7 -eq 0) { $null } else { @('platform', 'data', 'web', 'erp')[$i % 4] })
        Tags = @($(if ($i % 3 -eq 0) { 'env:prod' } else { 'env:nonprod' }), $(if ($i % 7 -eq 0) { 'owner:missing' } else { 'owner:ok' }))
    }
}

$costRows = @(
    [pscustomobject]@{ Resource = 'aks-prod-weu';        Subscription = 'contoso-prod';    Service = 'Kubernetes';      Cost = 8420; Trend = @(7100, 7400, 7650, 7900, 8100, 8420) }
    [pscustomobject]@{ Resource = 'sql-erp-prod';        Subscription = 'contoso-prod';    Service = 'SQL Database';    Cost = 6120; Trend = @(6000, 6050, 6100, 6080, 6110, 6120) }
    [pscustomobject]@{ Resource = 'vmss-web-prod';       Subscription = 'contoso-prod';    Service = 'Virtual Machines'; Cost = 4980; Trend = @(4100, 4300, 4500, 4700, 4900, 4980) }
    [pscustomobject]@{ Resource = 'stdatalakeprod';      Subscription = 'contoso-prod';    Service = 'Storage';         Cost = 3210; Trend = @(2400, 2600, 2750, 2900, 3050, 3210) }
    [pscustomobject]@{ Resource = 'appgw-hub';           Subscription = 'contoso-shared';  Service = 'Networking';      Cost = 1840; Trend = @(1800, 1810, 1820, 1830, 1835, 1840) }
    [pscustomobject]@{ Resource = 'aks-dev-weu';         Subscription = 'contoso-nonprod'; Service = 'Kubernetes';      Cost = 1620; Trend = @(1900, 1800, 1750, 1700, 1650, 1620) }
    [pscustomobject]@{ Resource = 'log-analytics-shared'; Subscription = 'contoso-shared'; Service = 'Monitoring';      Cost = 1480; Trend = @(900, 1000, 1150, 1250, 1380, 1480) }
    [pscustomobject]@{ Resource = 'fw-hub-premium';      Subscription = 'contoso-shared';  Service = 'Networking';      Cost = 1250; Trend = @(1250, 1250, 1250, 1250, 1250, 1250) }
)

$aks = @(
    [pscustomobject]@{ Name = 'aks-prod-weu'; Subscription = 'contoso-prod'; Version = '1.29.4'; Nodes = 18; Pools = @('system', 'apps', 'gpu'); Status = 'ok';   Notes = 'Up to date' }
    [pscustomobject]@{ Name = 'aks-dev-weu';  Subscription = 'contoso-nonprod'; Version = '1.27.9'; Nodes = 6; Pools = @('system', 'apps'); Status = 'warn'; Notes = 'Kubernetes 1.27 leaves support in 3 weeks' }
    [pscustomobject]@{ Name = 'aks-data-neu'; Subscription = 'contoso-shared'; Version = '1.29.4'; Nodes = 9; Pools = @('system', 'spark'); Status = 'ok'; Notes = 'Up to date' }
)

$storage = foreach ($i in 1..12) {
    [pscustomobject]@{
        Account = 'st{0}{1:00}' -f @('prod', 'dev', 'sh')[$i % 3], $i
        Subscription = $subs[$i % 3]
        Redundancy = @('LRS', 'ZRS', 'GRS', 'GZRS')[$i % 4]
        PublicAccess = $(if ($i % 5 -eq 0) { 'Enabled' } else { 'Disabled' })
        MinTls = $(if ($i % 6 -eq 0) { '1.0' } else { '1.2' })
        SizeTB = [math]::Round(0.2 + $rng.NextDouble() * 18, 1)
    }
}

$nsgRules = @(
    [pscustomobject]@{ Nsg = 'nsg-web-prod';  Subscription = 'contoso-prod';    Rule = 'allow-https-any'; Port = '443';  Source = 'Internet'; Risk = 'Low' }
    [pscustomobject]@{ Nsg = 'nsg-jump-prod'; Subscription = 'contoso-prod';    Rule = 'allow-rdp-any';   Port = '3389'; Source = 'Internet'; Risk = 'High' }
    [pscustomobject]@{ Nsg = 'nsg-db-prod';   Subscription = 'contoso-prod';    Rule = 'allow-sql-any';   Port = '1433'; Source = 'Internet'; Risk = 'High' }
    [pscustomobject]@{ Nsg = 'nsg-dev';       Subscription = 'contoso-nonprod'; Rule = 'allow-ssh-any';   Port = '22';   Source = 'Internet'; Risk = 'Medium' }
    [pscustomobject]@{ Nsg = 'nsg-shared';    Subscription = 'contoso-shared';  Rule = 'allow-dns';       Port = '53';   Source = 'VirtualNetwork'; Risk = 'Low' }
)

$utilRag = @{ Green = @{ Max = 60 }; Amber = @{ Min = 60; Max = 85 }; Red = @{ Min = 85 }; NoData = $true }

$report = New-DhDashboard -Title 'Azure Infrastructure Review' -Subtitle 'Tenant contoso.onmicrosoft.com, three subscriptions' `
    -Theme $Theme -NavTitle 'Azure' -NavMaxDepth 2 -GeneratedBy 'Demo-AzureInfrastructure.ps1' -InfoFields @(
        @{ Label = 'Tenant';        Value = 'contoso.onmicrosoft.com' }
        @{ Label = 'Subscriptions'; Value = ($subs -join ', ') }
        @{ Label = 'Period';        Value = 'October 2026' }
        @{ Label = 'Generated';     Value = (Get-Date -Format 'yyyy-MM-dd HH:mm') } )

# ============================================================================
# GLOBAL: one banner, one subscription filter
# ============================================================================
Add-DhAlertBanner -Report $report -Id 'rdp-open' -Severity critical -Icon '!' -Dismissible `
    -Message 'RDP (3389) and SQL (1433) are open to the internet on two production network security groups.' `
    -Action @{ Label = 'Show the rules'; TableId = 'nsg'; Filter = 'Internet' }

Add-DhGlobalFilter -Report $report -Field 'Subscription' -Label 'Subscription'

# ============================================================================
# OVERVIEW
# ============================================================================
Add-DhSummary -Report $report -NavPath 'Overview' -NavLabel 'Overview' -Items @(
    @{ Style = 'verdict'; Label = 'Overall'; Value = 'Needs attention'
       Caption = 'Two internet-facing rules and rising cost need action.'
       Counts = @{ critical = 2; warning = 5; info = 3 } }
    @{ Style = 'score'; Label = 'Secure score'; Value = 71; Caption = 'Fair'; Previous = 68
       Facts = @('212 recommendations', '37 unhealthy'); Rag = @{ Red = @{ Max = 50 }; Amber = @{ Min = 50; Max = 80 }; Green = @{ Min = 80 } } }
    @{ Label = 'Resources'; Value = 1842; Format = 'number'; Previous = 1790; TrendIsGood = $true }
    @{ Label = 'Cost this month'; Value = 28920; Previous = 26400; TrendIsGood = $false; Format = 'currency'; Currency = 'EUR'; Locale = 'en-IE'; Decimals = 0; Class = 'cell-warn'
       Sparkline = @(21200, 22400, 23900, 25100, 26400, 28920); SparklineStyle = 'area' }
    @{ Label = 'Non-compliant resources'; Value = 214; Previous = 240; TrendIsGood = $true }
    @{ Label = 'Untagged'; Value = 96; Class = 'cell-warn' }
)

Add-DhLineChart -Report $report -Id 'cost-overview' -Title 'Cost per month (EUR)' -NavPath 'Overview' -Filled -XAxis $months -YAxisMin 0 -Series @(
    @{ Label = 'contoso-prod';    Values = @(14200, 15100, 16300, 17200, 18400, 20100); Class = 'cell-ok' }
    @{ Label = 'contoso-nonprod'; Values = @(4200, 4300, 4100, 4000, 3900, 3700);       Class = 'cell-warn' }
    @{ Label = 'contoso-shared';  Values = @(2800, 3000, 3500, 3900, 4100, 5120);       Color = '#666666' } )

Add-DhPieChart -Report $report -Id 'by-type' -Title 'Resources by type' -NavPath 'Overview' -Style donut -Slices @(
    @{ Label = 'Virtual machines'; Value = 412 }, @{ Label = 'Storage accounts'; Value = 268 }, @{ Label = 'Network'; Value = 534 }
    @{ Label = 'Databases'; Value = 96 }, @{ Label = 'Kubernetes'; Value = 18 }, @{ Label = 'Other'; Value = 514 } )

# ============================================================================
# COST
# ============================================================================
Add-DhSummary -Report $report -NavPath 'Cost' -NavScope Subtree -Items @(
    @{ Label = 'Month to date'; Value = 28920; Format = 'currency'; Currency = 'EUR'; Locale = 'en-IE'; Decimals = 0 }
    @{ Label = 'Forecast'; Value = 41200; Format = 'currency'; Currency = 'EUR'; Locale = 'en-IE'; Decimals = 0; Class = 'cell-warn' }
    @{ Style = 'gauge'; Label = 'Budget used'; Value = 82; Max = 100; Unit = '%'; Rag = @{ Green = @{ Max = 80 }; Amber = @{ Min = 80; Max = 95 }; Red = @{ Min = 95 } } }
    @{ Label = 'Change vs last month'; Value = 9.5; Unit = '%'; Class = 'cell-warn' }
)

Add-DhTable -Report $report -TableId 'cost' -Title 'Most expensive resources' -NavPath 'Cost/Top resources' -NavOrder 2 -Data $costRows -DetailDrawer -DetailTitleField 'Resource' -Columns @(
    @{ Field = 'Resource';     Label = 'Resource'; PinFirst = $true }
    @{ Field = 'Subscription'; Label = 'Subscription' }
    @{ Field = 'Service';      Label = 'Service' }
    @{ Field = 'Cost';         Label = 'Cost (EUR)'; Align = 'right'; Format = 'currency'; Currency = 'EUR'; Locale = 'en-IE'; Decimals = 0; Aggregate = 'sum' }
    @{ Field = 'Trend';        Label = '6 months'; CellType = 'sparkline'; SparklineStyle = 'line'; SortBy = 'last' } )

Add-DhBarChart -Report $report -Id 'cost-by-service' -Title 'Cost by service (EUR)' -NavPath 'Cost/Trend' -NavLabel 'Trend' -NavOrder 1 `
    -TableId 'cost' -Field 'Service' -ValueField 'Cost' -Aggregate sum -Unit 'EUR'

Add-DhBarChart -Report $report -Id 'cost-by-sub' -Title 'Cost by subscription (EUR)' -NavPath 'Cost/Trend' `
    -TableId 'cost' -Field 'Subscription' -ValueField 'Cost' -Aggregate sum -Unit 'EUR'

# ============================================================================
# COMPUTE
# ============================================================================
Add-DhSummary -Report $report -NavPath 'Compute' -NavScope Subtree -Items @(
    @{ Label = 'Virtual machines'; Value = 36 }
    @{ Label = 'Running'; Value = 26; Class = 'cell-ok' }
    @{ Label = 'Deallocated or stopped'; Value = 10; Class = 'cell-warn' }
    @{ Label = 'Kubernetes clusters'; Value = 3 }
)

Add-DhTable -Report $report -TableId 'vms' -Title 'Virtual machines' -NavPath 'Compute/Virtual machines' -PageSize 12 -Data $vms `
    -DetailDrawer -DetailTitleField 'Name' -Columns @(
        @{ Field = 'Name';         Label = 'VM'; PinFirst = $true }
        @{ Field = 'Subscription'; Label = 'Subscription' }
        @{ Field = 'Region';       Label = 'Region' }
        @{ Field = 'Size';         Label = 'Size' }
        @{ Field = 'Os';           Label = 'Operating system' }
        @{ Field = 'Power';        Label = 'Power'; CellType = 'badge'
           Thresholds = @(@{ Value = 'Running'; Class = 'cell-ok' }, @{ Value = 'Deallocated'; Class = 'cell-nodata' }, @{ Value = 'Stopped'; Class = 'cell-warn' }) }
        @{ Field = 'CpuAvg';       Label = 'CPU avg %'; Align = 'right'; CellType = 'progressbar'; ProgressMax = 100; Rag = $utilRag }
        @{ Field = 'MonthlyCost';  Label = 'Cost / month'; Align = 'right'; Format = 'currency'; Currency = 'EUR'; Locale = 'en-IE'; Decimals = 0 }
        @{ Field = 'Tags';         Label = 'Tags'; CellType = 'chips' } )

Add-DhBarChart -Report $report -Id 'vm-by-size' -Title 'VMs by size' -NavPath 'Compute/Virtual machines' -TableId 'vms' -Field 'Size' -ClickFilters
Add-DhPieChart -Report $report -Id 'vm-power' -Title 'Power state' -NavPath 'Compute/Virtual machines' -TableId 'vms' -Field 'Power' -Style donut -ClickFilters

Add-DhRecordList -Report $report -Id 'aks-list' -Title 'AKS clusters' -NavPath 'Compute/Kubernetes' -NavLabel 'Kubernetes' -Items @(
    foreach ($c in $aks) {
        @{ Title = $c.Name; Subtitle = $c.Subscription; Status = $c.Status
           Metrics = @(@{ Label = 'Version'; Value = $c.Version }, @{ Label = 'Nodes'; Value = "$($c.Nodes)" })
           Sections = @(
               @{ Kind = 'kv'; Title = 'Cluster'; Items = @(@{ Label = 'Kubernetes version'; Value = $c.Version; Status = $c.Status }, @{ Label = 'Node pools'; Value = ($c.Pools -join ', ') }, @{ Label = 'Nodes'; Value = "$($c.Nodes)" }) }
               @{ Kind = 'checks'; Title = 'Checks'; Items = @(@{ Label = 'Supported version'; Ok = ($c.Status -eq 'ok'); Note = $c.Notes }, @{ Label = 'Autoscaler on'; Ok = $true }, @{ Label = 'Private API server'; Ok = ($c.Name -ne 'aks-dev-weu') }) }) }
    } )

# ============================================================================
# NETWORK
# ============================================================================
Add-DhNetworkMap -Report $report -Id 'hub-spoke' -Title 'Hub and spoke topology' -NavPath 'Network/Topology' -NavLabel 'Topology' -Layout layered -Legend `
    -Nodes @(
        @{ Id = 'internet'; Label = 'Internet'; Tier = 0; Status = 'info' }
        @{ Id = 'fw'; Label = 'Azure Firewall'; Tier = 1; Badge = @('Premium'); Status = 'ok' }
        @{ Id = 'hub'; Label = 'vnet-hub'; Tier = 2; Badge = @('hub'); Status = 'ok' }
        @{ Id = 'prod'; Label = 'vnet-prod'; Tier = 3; Badge = @('spoke'); Status = 'ok' }
        @{ Id = 'nonprod'; Label = 'vnet-nonprod'; Tier = 3; Badge = @('spoke'); Status = 'warn'; Tooltip = 'Peering is Disconnected' }
        @{ Id = 'data'; Label = 'vnet-data'; Tier = 3; Badge = @('spoke'); Status = 'ok' }
        @{ Id = 'onprem'; Label = 'On-premises'; Tier = 2; Status = 'ok'; Badge = @('ExpressRoute') } ) `
    -Edges @(
        @{ From = 'internet'; To = 'fw'; Direction = 'both'; Status = 'ok' }
        @{ From = 'fw'; To = 'hub'; Direction = 'both'; Status = 'ok' }
        @{ From = 'onprem'; To = 'hub'; Label = '1 Gb'; Direction = 'both'; Status = 'ok' }
        @{ From = 'hub'; To = 'prod'; Label = 'peering'; Direction = 'both'; Status = 'ok' }
        @{ From = 'hub'; To = 'nonprod'; Label = 'peering'; Direction = 'both'; Status = 'warn'; Style = 'dashed' }
        @{ From = 'hub'; To = 'data'; Label = 'peering'; Direction = 'both'; Status = 'ok' }
        @{ From = 'internet'; To = 'prod'; Label = 'rdp, sql'; Direction = 'forward'; Status = 'danger'; Style = 'dashed'; Tooltip = 'Direct exposure through NSG rules' } )

Add-DhTable -Report $report -TableId 'nsg' -Title 'Network security group rules reachable from the internet' -NavPath 'Network/Exposure' -NavLabel 'Exposure' -Data $nsgRules -Columns @(
    @{ Field = 'Nsg'; Label = 'NSG' }
    @{ Field = 'Subscription'; Label = 'Subscription' }
    @{ Field = 'Rule'; Label = 'Rule' }
    @{ Field = 'Port'; Label = 'Port'; Align = 'right' }
    @{ Field = 'Source'; Label = 'Source' }
    @{ Field = 'Risk'; Label = 'Risk'; CellType = 'badge'
       Thresholds = @(@{ Value = 'High'; Class = 'cell-danger' }, @{ Value = 'Medium'; Class = 'cell-warn' }, @{ Value = 'Low'; Class = 'cell-ok' }) } )

Add-DhBarChart -Report $report -Id 'nsg-risk' -Title 'Rules by risk' -NavPath 'Network/Exposure' -TableId 'nsg' -Field 'Risk' -ClickFilters `
    -KeyClass @{ High = 'cell-danger'; Medium = 'cell-warn'; Low = 'cell-ok' }

# ============================================================================
# STORAGE
# ============================================================================
Add-DhTable -Report $report -TableId 'storage' -Title 'Storage accounts' -NavPath 'Storage' -NavLabel 'Storage' -Data $storage -Columns @(
    @{ Field = 'Account'; Label = 'Account'; PinFirst = $true }
    @{ Field = 'Subscription'; Label = 'Subscription' }
    @{ Field = 'Redundancy'; Label = 'Redundancy'; CellType = 'badge' }
    @{ Field = 'PublicAccess'; Label = 'Public access'; CellType = 'badge'
       Thresholds = @(@{ Value = 'Enabled'; Class = 'cell-danger' }, @{ Value = 'Disabled'; Class = 'cell-ok' }) }
    @{ Field = 'MinTls'; Label = 'Minimum TLS'; CellType = 'badge'
       Thresholds = @(@{ Value = '1.0'; Class = 'cell-danger' }, @{ Value = '1.2'; Class = 'cell-ok' }) }
    @{ Field = 'SizeTB'; Label = 'Size (TB)'; Align = 'right'; Aggregate = 'sum' } )

Add-DhBarChart -Report $report -Id 'st-redundancy' -Title 'Accounts by redundancy' -NavPath 'Storage' -TableId 'storage' -Field 'Redundancy'
Add-DhPieChart -Report $report -Id 'st-public' -Title 'Public access' -NavPath 'Storage' -TableId 'storage' -Field 'PublicAccess' -Style donut -ClickFilters

# ============================================================================
# SECURITY
# ============================================================================
Add-DhSummary -Report $report -NavPath 'Security' -NavScope Subtree -Items @(
    @{ Label = 'Unhealthy recommendations'; Value = 37; Previous = 44; TrendIsGood = $true }
    @{ Label = 'High severity'; Value = 6; Class = 'cell-danger' }
    @{ Label = 'Open to the internet'; Value = 2; Class = 'cell-danger' }
    @{ Label = 'Defender plans on'; Value = '7 of 9'; Class = 'cell-warn' }
)

Add-DhFindings -Report $report -Id 'defender' -Title 'Defender for Cloud recommendations' -NavPath 'Security/Recommendations' -NavLabel 'Recommendations' -Layout Split -GroupBy Area -AllClearText 'No open recommendations.' -Findings @(
    @{ Severity = 'critical'; Area = 'Network'; Title = 'Management ports are open to the internet'; Change = 'new'
       Description = 'RDP and SQL are reachable from any address on two production network security groups.'
       Recommendation = 'Remove the rules and use Azure Bastion and private endpoints.'
       Facts = @(@{ Label = 'Affected NSGs'; Value = '2'; Status = 'danger' }, @{ Label = 'Exposure'; Value = 'Internet' })
       Evidence = @(@{ Object = 'nsg-jump-prod'; Value = '3389 from Internet'; Status = 'danger' }, @{ Object = 'nsg-db-prod'; Value = '1433 from Internet'; Status = 'danger' })
       AffectedTableId = 'nsg' }
    @{ Severity = 'warning'; Area = 'Storage'; Title = 'Storage accounts allow public access or old TLS'
       Recommendation = 'Disable public blob access and require TLS 1.2.'
       Evidence = @(foreach ($s in ($storage | Where-Object { $_.PublicAccess -eq 'Enabled' -or $_.MinTls -eq '1.0' })) { @{ Object = $s.Account; Value = "public: $($s.PublicAccess), TLS $($s.MinTls)"; Status = 'warn' } })
       AffectedTableId = 'storage' }
    @{ Severity = 'warning'; Area = 'Compute'; Title = 'Virtual machines are missing the owner tag'; Change = 'worse'
       Recommendation = 'Tag every VM with an owner so alerts can reach someone.'
       Evidence = @(foreach ($v in ($vms | Where-Object { -not $_.Owner } | Select-Object -First 8)) { @{ Object = $v.Name; Value = 'owner tag missing'; Status = 'warn' } })
       AffectedTableId = 'vms' }
    @{ Severity = 'warning'; Area = 'Kubernetes'; Title = 'A cluster runs a Kubernetes version leaving support soon'
       Affected = @('aks-dev-weu'); Recommendation = 'Upgrade to 1.29 before support ends.' }
    @{ Severity = 'info'; Area = 'Identity'; Title = 'Two service principals have secrets older than a year'; Change = 'resolved' } )

Add-DhSummary -Report $report -NavPath 'Security/Posture' -NavLabel 'Posture' -Items @(
    @{ Style = 'score'; Label = 'Secure score'; Value = 71; Caption = 'Fair'; Previous = 68; Rag = @{ Red = @{ Max = 50 }; Amber = @{ Min = 50; Max = 80 }; Green = @{ Min = 80 } } }
    @{ Style = 'maturity'; Label = 'Cloud security maturity'; Value = 'Defined'; Current = 3
       Levels = @(@{ Name = 'Initial' }, @{ Name = 'Managed' }, @{ Name = 'Defined' }, @{ Name = 'Measured' }, @{ Name = 'Optimised' })
       Criteria = @(@{ Level = 4; Text = 'Measure policy compliance every week'; Met = $true }, @{ Level = 4; Text = 'No internet-facing management ports'; Met = $false }, @{ Level = 4; Text = 'All subscriptions on the secure score target'; Met = $false }) } )

Add-DhLineChart -Report $report -Id 'score-trend' -Title 'Secure score, last six months' -NavPath 'Security/Posture' -XAxis $months -YAxisMin 0 -YAxisMax 100 -YAxisUnit '%' `
    -TargetLine 80 -TargetLabel 'Target' -Series @(@{ Label = 'Secure score'; Values = @(58, 61, 63, 66, 68, 71); Class = 'cell-warn' })

# ============================================================================
# GOVERNANCE
# ============================================================================
$initiatives = @('Azure Security Benchmark', 'CIS 2.0', 'ISO 27001', 'Tagging standard')
$compliance = @{ 'contoso-prod' = @(88, 79, 84, 62); 'contoso-nonprod' = @(74, 66, 70, 41); 'contoso-shared' = @(93, 90, 91, 78) }
Add-DhHeatmap -Report $report -Id 'policy-heat' -Title 'Policy compliance (%)' -NavPath 'Governance/Policy' -NavLabel 'Policy' `
    -Rows $subs -Columns $initiatives -RowLabel 'Subscription' -ColumnLabel 'Initiative' -ColorScale sequential -Unit '%' -ShowValues -Cells @(
        foreach ($s in $subs) { for ($k = 0; $k -lt 4; $k++) { @{ Row = $s; Column = $initiatives[$k]; Value = $compliance[$s][$k] } } } )

Add-DhBarChart -Report $report -Id 'tag-coverage' -Title 'VMs by owner tag' -NavPath 'Governance/Tags' -NavLabel 'Tags' -TableId 'vms' -Field 'Owner' -ShowPercent

Add-DhTable -Report $report -TableId 'untagged' -Title 'Resources without an owner' -NavPath 'Governance/Tags' `
    -Data @($vms | Where-Object { -not $_.Owner } | Select-Object Name, Subscription, Region, Size, MonthlyCost) `
    -AllClearText 'Every VM has an owner tag.' -Columns @(
        @{ Field = 'Name'; Label = 'VM' }, @{ Field = 'Subscription'; Label = 'Subscription' }, @{ Field = 'Region'; Label = 'Region' }
        @{ Field = 'Size'; Label = 'Size' }, @{ Field = 'MonthlyCost'; Label = 'Cost / month'; Align = 'right'; Format = 'currency'; Currency = 'EUR'; Locale = 'en-IE'; Decimals = 0 } )

Export-DhDashboard -Report $report -OutputPath $OutputPath -Force -OpenInBrowser:$OpenInBrowser
Write-Host "Wrote $OutputPath"
