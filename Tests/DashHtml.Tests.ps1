#Requires -Version 7.0
<#
.SYNOPSIS  Pester 5 test suite for the DashHtml module.
.DESCRIPTION
    Covers all public functions:
      New-DhDashboard, Add-DhTable, Set-DhTableLink, Export-DhDashboard,
      Get-DhTheme, Add-DhSummary, Add-DhHtmlBlock,
      Add-DhCollapsible, Add-DhFilterCard, Add-DhBarChart

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

    It 'Returns exactly five theme families when called without parameters' {
        $themes = Get-DhTheme
        $themes.Count | Should -Be 5
    }

    It 'Returned list includes all five family names' {
        $themes = Get-DhTheme
        ($themes | Where-Object Family -eq 'Default') | Should -Not -BeNullOrEmpty
        ($themes | Where-Object Family -eq 'Azure')   | Should -Not -BeNullOrEmpty
        ($themes | Where-Object Family -eq 'VMware')  | Should -Not -BeNullOrEmpty
        ($themes | Where-Object Family -eq 'Grey')    | Should -Not -BeNullOrEmpty
        ($themes | Where-Object Family -eq 'Company') | Should -Not -BeNullOrEmpty
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

    It 'All five families contain panel-mode CSS in both variants' {
        foreach ($family in @('Default','Azure','VMware','Grey','Company')) {
            $result = Get-DhTheme -Name $family
            $result.LightCss | Should -Match 'panel-active' -Because "$family light must include panel CSS"
            $result.DarkCss  | Should -Match 'panel-active' -Because "$family dark must include panel CSS"
        }
    }

    It 'All five families contain cell threshold variables in both variants' {
        foreach ($family in @('Default','Azure','VMware','Grey','Company')) {
            $result = Get-DhTheme -Name $family
            foreach ($css in @($result.LightCss, $result.DarkCss)) {
                $css | Should -Match '--cell-ok-fg'   -Because "$family must have cell-ok-fg"
                $css | Should -Match '--cell-warn-fg' -Because "$family must have cell-warn-fg"
                $css | Should -Match '--nav-bg'       -Because "$family must have nav-bg"
                $css | Should -Match '--chart-1'      -Because "$family must have chart-1"
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
}
