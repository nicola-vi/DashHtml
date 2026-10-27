#Requires -Version 7.0
<#
.SYNOPSIS  Pester 5 test suite for the DashHtml.Design companion module.
.DESCRIPTION
    Covers the three public functions:
      ConvertTo-DhYaml     report object -> YAML  (lossless layout view)
      ConvertFrom-DhYaml   YAML/JSON     -> .ps1  (runnable build script)
      ConvertFrom-DhScript .ps1          -> YAML  (best-effort static parse)

    Plus the self-contained YAML reader/writer round-trip that underpins them.

    Run:  Invoke-Pester ./Tests -Output Detailed
          ./Build.ps1   (runs automatically as part of the build)
#>

# ---------------------------------------------------------------------------
# Module import — both the core module and the design companion.
# The design module reads core cmdlet metadata, so both must be loaded from
# the LOCAL source (not any installed copy) for the tests to be meaningful.
# ---------------------------------------------------------------------------
BeforeAll {
    $script:corePath   = Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1'
    $script:designPath = Join-Path $PSScriptRoot '../DashHtml.Design/DashHtml.Design.psd1'
    Import-Module $script:corePath   -Force
    Import-Module $script:designPath -Force

    # Build a representative report used by several Describe blocks.
    function New-SampleReport {
        $rows = @(
            [pscustomobject]@{ Name = 'web01'; Env = 'Prod'; CPU = 42 }
            [pscustomobject]@{ Name = 'web02'; Env = 'Dev';  CPU = 88 }
        )
        $r = New-DhDashboard -Title 'Round Trip' -Theme Azure -Subtitle 'sample'
        Add-DhTable        -Report $r -TableId 'srv' -Title 'Servers' -Data $rows -GridSpan 8
        Add-DhSummary      -Report $r -Items @( @{ Label = 'Total'; Value = 2 } )
        Add-DhBarChart     -Report $r -Id 'os' -Title 'By Env' -TableId 'srv' -Field 'Env' -ShowPercent
        Add-DhGlobalFilter -Report $r -Field 'Env' -Label 'Environment'
        return $r
    }
}

AfterAll {
    Remove-Module DashHtml.Design -ErrorAction SilentlyContinue
    Remove-Module DashHtml        -ErrorAction SilentlyContinue
}

# ===========================================================================
#  Self-contained YAML reader/writer round-trip
# ===========================================================================
Describe 'YAML reader/writer round-trip' {

    # These call the module-private emitter/parser via the module scope.
    It 'Round-trips scalars with types preserved' {
        InModuleScope DashHtml.Design {
            $model = [ordered]@{
                str   = 'hello world'
                int   = 42
                dbl   = 0.85
                boolT = $true
                boolF = $false
                nul   = $null
            }
            $yaml = ConvertTo-DhYamlText $model
            $back = ConvertFrom-DhYamlText $yaml
            $back['str']   | Should -Be 'hello world'
            $back['int']   | Should -Be 42
            $back['int']   | Should -BeOfType [int]
            $back['dbl']   | Should -Be 0.85
            $back['dbl']   | Should -BeOfType [double]
            $back['boolT'] | Should -BeTrue
            $back['boolF'] | Should -BeFalse
            $back['nul']   | Should -BeNullOrEmpty
        }
    }

    It 'Emits decimals with a period regardless of host locale' {
        InModuleScope DashHtml.Design {
            $yaml = ConvertTo-DhYamlText ([ordered]@{ ratio = 0.85 })
            $yaml | Should -Match 'ratio:\s*0\.85'
            $yaml | Should -Not -Match '0,85'
        }
    }

    It 'Round-trips a flow array of scalars' {
        InModuleScope DashHtml.Design {
            $back = ConvertFrom-DhYamlText (ConvertTo-DhYamlText ([ordered]@{ tags = @('a', 'b', 'c') }))
            @($back['tags'])       | Should -HaveCount 3
            @($back['tags'])[1]    | Should -Be 'b'
        }
    }

    It 'Round-trips a block sequence of maps (arrays of objects)' {
        InModuleScope DashHtml.Design {
            $model = [ordered]@{
                tables = @(
                    [ordered]@{ id = 'srv'; title = 'Servers' }
                    [ordered]@{ id = 'db';  title = 'Databases' }
                )
            }
            $back = ConvertFrom-DhYamlText (ConvertTo-DhYamlText $model)
            @($back['tables'])           | Should -HaveCount 2
            @($back['tables'])[0]['id']  | Should -Be 'srv'
            @($back['tables'])[1]['title'] | Should -Be 'Databases'
        }
    }

    It 'Round-trips strings containing YAML-significant characters' {
        InModuleScope DashHtml.Design {
            $model = [ordered]@{ a = 'key: value'; b = 'has [brackets]'; c = 'trailing space ' }
            $back  = ConvertFrom-DhYamlText (ConvertTo-DhYamlText $model)
            $back['a'] | Should -Be 'key: value'
            $back['b'] | Should -Be 'has [brackets]'
            $back['c'] | Should -Be 'trailing space '
        }
    }

    It 'Round-trips switch-typed values as booleans (no nested "False")' {
        InModuleScope DashHtml.Design {
            $sw = [System.Management.Automation.SwitchParameter]::new($true)
            $yaml = ConvertTo-DhYamlText ([ordered]@{ ShowPercent = $sw })
            $yaml | Should -Match 'ShowPercent:\s*true'
            $yaml | Should -Not -Match '"(True|False)"'
        }
    }

    It 'Parses a JSON document via the fast path' {
        InModuleScope DashHtml.Design {
            $json = '{ "title": "J", "tables": [ { "id": "t1" } ] }'
            $m = ConvertFrom-DhYamlText $json
            $m['title']                 | Should -Be 'J'
            @($m['tables'])[0]['id']    | Should -Be 't1'
        }
    }
}

# ===========================================================================
#  ConvertTo-DhYaml  (report object -> YAML)
# ===========================================================================
Describe 'ConvertTo-DhYaml' {

    It 'Serialises foundation, summary, tables, blocks, and filters' {
        $yaml = ConvertTo-DhYaml -Report (New-SampleReport)
        $yaml | Should -Match '(?m)^title: Round Trip'
        $yaml | Should -Match '(?m)^subtitle: sample'
        $yaml | Should -Match '(?m)^theme: Azure'
        $yaml | Should -Match '(?m)^summary:'
        $yaml | Should -Match '(?m)^tables:'
        $yaml | Should -Match '(?m)^blocks:'
        $yaml | Should -Match '(?m)^globalFilters:'
        $yaml | Should -Match 'type: barchart'
    }

    It 'Summarises row count as dataRows by default (no raw data leak)' {
        $yaml = ConvertTo-DhYaml -Report (New-SampleReport)
        $yaml | Should -Match 'dataRows:\s*2'
        $yaml | Should -Not -Match 'web01'
    }

    It 'Embeds row data when -IncludeData is supplied' {
        $yaml = ConvertTo-DhYaml -Report (New-SampleReport) -IncludeData
        $yaml | Should -Match 'web01'
        $yaml | Should -Match 'web02'
    }

    It 'Preserves switch parameters as booleans' {
        $yaml = ConvertTo-DhYaml -Report (New-SampleReport)
        $yaml | Should -Match 'ShowPercent:\s*true'
        $yaml | Should -Not -Match '"(True|False)"'
    }

    It 'Accepts the report from the pipeline' {
        $yaml = New-SampleReport | ConvertTo-DhYaml
        $yaml | Should -Match '(?m)^title: Round Trip'
    }

    It 'Writes to -OutFile when given a path' {
        $out = Join-Path ([IO.Path]::GetTempPath()) ("ct_" + [guid]::NewGuid().ToString('N') + '.yaml')
        ConvertTo-DhYaml -Report (New-SampleReport) -OutFile $out
        Test-Path $out               | Should -BeTrue
        (Get-Content $out -Raw)      | Should -Match 'title: Round Trip'
        Remove-Item $out -Force
    }
}

# ===========================================================================
#  ConvertFrom-DhYaml  (YAML -> runnable .ps1)
# ===========================================================================
Describe 'ConvertFrom-DhYaml' {

    BeforeAll {
        $script:sampleYaml = ConvertTo-DhYaml -Report (New-SampleReport) -IncludeData
        $script:yamlFile   = Join-Path ([IO.Path]::GetTempPath()) ("cy_" + [guid]::NewGuid().ToString('N') + '.yaml')
        Set-Content -Path $script:yamlFile -Value $script:sampleYaml -Encoding UTF8
    }
    AfterAll { Remove-Item $script:yamlFile -Force -ErrorAction SilentlyContinue }

    It 'Generates a script that parses cleanly' {
        $ps = ConvertFrom-DhYaml -Path $script:yamlFile
        $errs = $null
        [System.Management.Automation.Language.Parser]::ParseInput($ps, [ref]$null, [ref]$errs) | Out-Null
        @($errs) | Should -HaveCount 0
    }

    It 'Emits calls in dependency order (table before its barchart)' {
        $ps = ConvertFrom-DhYaml -Path $script:yamlFile
        $idxTable = $ps.IndexOf('Add-DhTable')
        $idxChart = $ps.IndexOf('Add-DhBarChart')
        $idxTable | Should -BeGreaterThan 0
        $idxChart | Should -BeGreaterThan $idxTable
    }

    It 'Maps a table id key to -TableId' {
        $ps = ConvertFrom-DhYaml -Path $script:yamlFile
        $ps | Should -Match "-TableId 'srv'"
    }

    It 'Only emits real cmdlet parameters (no dataRows leak into the call)' {
        $ps = ConvertFrom-DhYaml -Path $script:yamlFile
        $ps | Should -Not -Match '-dataRows'
    }

    It 'Round-trips into a runnable script that produces valid HTML' {
        $ps = ConvertFrom-DhYaml -Path $script:yamlFile -OutputPath 'IGNORED.html'
        # Strip the header (#Requires + Import-Module) — the local module is
        # already loaded in this session; re-importing by bare name could shadow
        # it with an installed copy. Re-point Export at a temp file.
        $outHtml = Join-Path ([IO.Path]::GetTempPath()) ("dh_" + [guid]::NewGuid().ToString('N') + '.html')
        $body = ($ps -split "`n" | Where-Object {
            $_ -notmatch '^\s*#Requires' -and $_ -notmatch '^\s*Import-Module\s+DashHtml'
        }) -join "`n"
        $body = $body -replace "IGNORED\.html", ($outHtml -replace '\\', '\\')
        & ([scriptblock]::Create($body))
        Test-Path $outHtml | Should -BeTrue
        $html = Get-Content $outHtml -Raw
        $html | Should -Match '<!DOCTYPE html>'
        $html | Should -Match 'Round Trip'
        $html | Should -Match 'web01'
        $html | Should -Match 'By Env'
        Remove-Item $outHtml -Force -ErrorAction SilentlyContinue
    }

    It 'Turns a dataFile key into an Import-Csv call' {
        $yaml = @"
title: CSV demo
tables:
  - id: t1
    title: From CSV
    dataFile: ./data/servers.csv
"@
        $f = Join-Path ([IO.Path]::GetTempPath()) ("csv_" + [guid]::NewGuid().ToString('N') + '.yaml')
        Set-Content -Path $f -Value $yaml -Encoding UTF8
        $ps = ConvertFrom-DhYaml -Path $f
        $ps | Should -Match "-Data \(Import-Csv"
        Remove-Item $f -Force
    }

    It 'Emits a TODO placeholder when a table has no data' {
        $yaml = "title: T`ntables:`n  - id: t1`n    title: Empty`n"
        $f = Join-Path ([IO.Path]::GetTempPath()) ("todo_" + [guid]::NewGuid().ToString('N') + '.yaml')
        Set-Content -Path $f -Value $yaml -Encoding UTF8
        $ps = ConvertFrom-DhYaml -Path $f
        $ps | Should -Match '-Data @\(\).*TODO'
        Remove-Item $f -Force
    }

    It 'Throws when the file does not exist' {
        { ConvertFrom-DhYaml -Path 'C:\no\such\file_xyz.yaml' } | Should -Throw
    }
}

# ===========================================================================
#  ConvertFrom-DhScript  (best-effort .ps1 -> YAML)
# ===========================================================================
Describe 'ConvertFrom-DhScript' {

    It 'Extracts foundation, tables, and blocks from a literal script' {
        $src = @'
$r = New-DhDashboard -Title 'Static' -Theme Azure -Subtitle 'parsed'
Add-DhTable    -Report $r -TableId 'srv' -Title 'Servers' -Data $rows
Add-DhBarChart -Report $r -Id 'os' -Title 'By Env' -TableId 'srv' -Field 'Env'
Export-DhDashboard -Report $r -OutputPath './out.html'
'@
        $f = Join-Path ([IO.Path]::GetTempPath()) ("src_" + [guid]::NewGuid().ToString('N') + '.ps1')
        Set-Content -Path $f -Value $src -Encoding UTF8
        $yaml = ConvertFrom-DhScript -Path $f
        $yaml | Should -Match 'title: Static'
        $yaml | Should -Match 'theme: Azure'
        $yaml | Should -Match '(?m)^tables:'
        $yaml | Should -Match 'type: barchart'
        Remove-Item $f -Force
    }

    It 'Marks dynamic (non-literal) argument values with an expr placeholder' {
        $src = @'
$r = New-DhDashboard -Title $myTitle
Add-DhTable -Report $r -TableId 'srv' -Title ("Server " + $count) -Data $rows
'@
        $f = Join-Path ([IO.Path]::GetTempPath()) ("dyn_" + [guid]::NewGuid().ToString('N') + '.ps1')
        Set-Content -Path $f -Value $src -Encoding UTF8
        $yaml = ConvertFrom-DhScript -Path $f
        $yaml | Should -Match '<expr:'
        Remove-Item $f -Force
    }

    It 'Parses the real vSphere example without throwing' {
        $example = Join-Path $PSScriptRoot '../Examples/Demo-VMware.ps1'
        if (-not (Test-Path $example)) { Set-ItResult -Skipped -Because 'example not present'; return }
        $yaml = ConvertFrom-DhScript -Path $example
        $yaml | Should -Match 'title:'
    }

    It 'Throws when the file does not exist' {
        { ConvertFrom-DhScript -Path 'C:\no\such\script_xyz.ps1' } | Should -Throw
    }
}

# ===========================================================================
#  Full round-trip: report -> YAML -> script -> report-shaped YAML
# ===========================================================================
Describe 'Design round-trip integrity' {

    It 'Preserves title/theme/table id across report -> YAML -> script -> YAML' {
        $yaml1 = ConvertTo-DhYaml -Report (New-SampleReport)
        $f1 = Join-Path ([IO.Path]::GetTempPath()) ("rt_" + [guid]::NewGuid().ToString('N') + '.yaml')
        Set-Content -Path $f1 -Value $yaml1 -Encoding UTF8

        $scriptFile = Join-Path ([IO.Path]::GetTempPath()) ("rt_" + [guid]::NewGuid().ToString('N') + '.ps1')
        ConvertFrom-DhYaml -Path $f1 -OutFile $scriptFile

        $yaml2 = ConvertFrom-DhScript -Path $scriptFile
        $yaml2 | Should -Match 'title: Round Trip'
        $yaml2 | Should -Match 'theme: Azure'
        $yaml2 | Should -Match 'type: barchart'

        Remove-Item $f1, $scriptFile -Force -ErrorAction SilentlyContinue
    }
}

# ===========================================================================
#  DashHtml 2.2.0 blocks survive the YAML round-trip
# ===========================================================================
Describe 'Round-trip of the DashHtml 2.2.0 additions' {
    It 'keeps findings, a verdict tile and a value-aggregated bar chart' {
        $r = New-DhDashboard -Title 'RT 220'
        Add-DhSummary -Report $r -Items @(@{ Label = 'Overall'; Value = 'Review'; Style = 'verdict'; Counts = @{ warning = 2 } })
        Add-DhTable -Report $r -TableId 'repl' -Title 'Repl' -Data @(
            [pscustomobject]@{ DC = 'a'; Lag = 4 }, [pscustomobject]@{ DC = 'b'; Lag = 9 })
        Add-DhBarChart -Report $r -Id 'lag' -Title 'Lag' -TableId 'repl' -Field 'DC' -ValueField 'Lag' -Aggregate avg -Unit 'min'
        Add-DhFindings -Report $r -Id 'f' -Title 'Findings' -Findings @(
            @{ Severity = 'high'; Title = 'Round trip finding'; Area = 'X'; Affected = @('u1', 'u2'); AffectedTableId = 'repl' })

        $yamlFile = Join-Path ([IO.Path]::GetTempPath()) ('rt220_' + [guid]::NewGuid().ToString('N') + '.yaml')
        $outHtml  = Join-Path ([IO.Path]::GetTempPath()) ('rt220_' + [guid]::NewGuid().ToString('N') + '.html')
        try {
            Set-Content -Path $yamlFile -Value (ConvertTo-DhYaml -Report $r -IncludeData) -Encoding UTF8
            $ps = ConvertFrom-DhYaml -Path $yamlFile -OutputPath 'IGNORED.html'
            $ps | Should -Match 'Add-DhFindings'
            $body = ($ps -split "`n" | Where-Object { $_ -notmatch '^\s*#Requires' -and $_ -notmatch '^\s*Import-Module\s+DashHtml' }) -join "`n"
            $body = $body -replace 'IGNORED\.html', ($outHtml -replace '\\', '\\')
            & ([scriptblock]::Create($body))
            $html = Get-Content $outHtml -Raw
            $html | Should -Match '"blockType":"findings"'
            $html | Should -Match 'Round trip finding'
            $html | Should -Match '"severity":"critical"'
            $html | Should -Match '"aggregate":"avg"'
            $html | Should -Match '"style":"verdict"'
        } finally {
            foreach ($f in $yamlFile, $outHtml) { if (Test-Path $f) { Remove-Item $f -Force } }
        }
    }
}

Describe 'DashHtml 2.5.4 data fields named Keys, Values or Count survive the YAML round trip' {
    It 'writes, reads and re-renders every field of the row' {
        $r = New-DhDashboard -Title 'RT 254'
        Add-DhTable -Report $r -TableId 't' -Title 'T' -Data @([pscustomobject]@{ A = 'a1'; Keys = 'First event field'; Values = 'v'; Count = 'c' })
        $yaml = ConvertTo-DhYaml -Report $r -IncludeData
        $yaml | Should -Match 'Keys: First event field'
        $yaml | Should -Match 'Count: c'
        $yamlFile = Join-Path ([IO.Path]::GetTempPath()) ('rt254_' + [guid]::NewGuid().ToString('N') + '.yaml')
        $outHtml  = Join-Path ([IO.Path]::GetTempPath()) ('rt254_' + [guid]::NewGuid().ToString('N') + '.html')
        try {
            Set-Content -Path $yamlFile -Value $yaml -Encoding UTF8
            $ps = ConvertFrom-DhYaml -Path $yamlFile -OutputPath 'IGNORED.html'
            $body = ($ps -split "`n" | Where-Object { $_ -notmatch '^\s*#Requires' -and $_ -notmatch '^\s*Import-Module\s+DashHtml' }) -join "`n"
            $body = $body -replace 'IGNORED\.html', ($outHtml -replace '\\', '\\')
            & ([scriptblock]::Create($body))
            $html = Get-Content $outHtml -Raw
            $html | Should -Match '"Keys":"First event field"'
            $html | Should -Match '"Values":"v"'
            $html | Should -Match '"Count":"c"'
        } finally {
            foreach ($f in $yamlFile, $outHtml) { if (Test-Path $f) { Remove-Item $f -Force } }
        }
    }
}

Describe 'DashHtml 2.4.0 blocks and options survive the YAML round trip' {

    It 'round-trips the network map, tree filter, search, nav badges and column options' {
        $r = New-DhDashboard -Title 'rt' -Search -NavBadge
        Add-DhTable -Report $r -TableId 'ous' -Title 'OUs' -NavPath 'A' -ColumnFit Fixed -ColumnMaxWidth 600 `
            -Data @([pscustomobject]@{ Path = 'a/b'; N = 1 }) `
            -Columns @(@{ Field = 'Path'; Label = 'Path'; MinWidth = 150 }, @{ Field = 'N'; Label = 'N' })
        Add-DhTreeFilter -Report $r -Id 'tf' -Title 'Tree' -NavPath 'A' -TableId 'ous' -PathField 'Path' -CountFromTable -Match Suffix -Nodes @(
            @{ Id = 'a'; Label = 'A'; Path = 'a'; Flags = @('empty'); Detail = @{ Sections = @(@{ Kind = 'text'; Text = 'hello' }) } })
        Add-DhNetworkMap -Report $r -Id 'nm' -Title 'Map' -NavPath 'B' -Layout layered -Legend `
            -Nodes @(@{ Id = 'x'; Label = 'X'; Badge = @('PDC'); Tier = 0; Target = $true }) `
            -Edges @(@{ From = 'x'; To = 'x'; Label = 'self'; Style = 'dashed'; Direction = 'both' })

        $yamlFile = Join-Path ([IO.Path]::GetTempPath()) ('dh24_' + [guid]::NewGuid().ToString('N') + '.yaml')
        $outHtml  = Join-Path ([IO.Path]::GetTempPath()) ('dh24_' + [guid]::NewGuid().ToString('N') + '.html')
        try {
            ConvertTo-DhYaml -Report $r -OutFile $yamlFile | Out-Null
            $ps = ConvertFrom-DhYaml -Path $yamlFile -OutputPath 'IGNORED.html'
            $body = ($ps -split "`n" | Where-Object { $_ -notmatch '^\s*#Requires' -and $_ -notmatch '^\s*Import-Module\s+DashHtml' }) -join "`n"
            $body = $body -replace 'IGNORED\.html', ($outHtml -replace '\\', '\\')
            & ([scriptblock]::Create($body)) 3>$null
            $html = Get-Content $outHtml -Raw
            foreach ($m in '"blockType":"treefilter"', '"match":"Suffix"', '"countFromTable":true', '"flags":["empty"]', '"detail":{',
                           '"blockType":"networkmap"', '"layout":"layered"', '"target":true', '"badges":["PDC"]', '"direction":"both"',
                           '"style":"dashed"', '"legend":true', '"columnFit":"fixed"', '"columnMax":600', '"minWidth":150',
                           'data-navbadge="true"', 'id="nav-search-input"') {
                $html.Contains($m) | Should -BeTrue -Because $m
            }
        } finally {
            foreach ($f in $yamlFile, $outHtml) { if (Test-Path $f) { Remove-Item $f -Force } }
        }
    }

    It 'writes the optional report switches only when they are on, so older YAML is unchanged' {
        $yaml = ConvertTo-DhYaml -Report (New-DhDashboard -Title 'plain')
        $yaml | Should -Not -Match 'search:|navBadge:|printCover:|themeMode:'
    }
}

Describe 'DashHtml 2.5.0 directory explorer survives the YAML round trip' {
    It 'round-trips rows, properties, flags, detail and memberships' {
        $r = New-DhDashboard -Title 'rt'
        Add-DhTreeTable -Report $r -Id 'dir' -Title 'Directory' -NavPath 'A' -Rows @(
            @{ Id = 'ou'; Type = 'ou'; Label = 'HQ' }
            @{ Id = 'g'; ParentId = 'ou'; Type = 'group'; Label = 'G'; Flags = @('privileged'); Status = 'warn'; Properties = [ordered]@{ 'DN' = 'CN=G'; 'Scope' = 'Global' }; Detail = 'Some detail.' }
            @{ Id = 'u'; ParentId = 'ou'; Type = 'user'; Label = 'U' } ) -Memberships @(@{ GroupId = 'g'; MemberId = 'u' })
        $yamlFile = Join-Path ([IO.Path]::GetTempPath()) ('dh25_' + [guid]::NewGuid().ToString('N') + '.yaml')
        $outHtml  = Join-Path ([IO.Path]::GetTempPath()) ('dh25_' + [guid]::NewGuid().ToString('N') + '.html')
        try {
            ConvertTo-DhYaml -Report $r -OutFile $yamlFile | Out-Null
            $ps = ConvertFrom-DhYaml -Path $yamlFile -OutputPath 'IGNORED.html'
            $body = ($ps -split "`n" | Where-Object { $_ -notmatch '^\s*#Requires' -and $_ -notmatch '^\s*Import-Module\s+DashHtml' }) -join "`n"
            $body = $body -replace 'IGNORED\.html', ($outHtml -replace '\\', '\\')
            & ([scriptblock]::Create($body)) 3>$null
            $html = Get-Content $outHtml -Raw
            foreach ($m in '"blockType":"treetable"', '"links":[["g","u"]]', '"flags":["privileged"]', '"status":"warn"', '{"label":"DN","value":"CN=G"}', '{"label":"Scope","value":"Global"}', '"detail":{') {
                $html.Contains($m) | Should -BeTrue -Because $m
            }
        } finally { foreach ($f in $yamlFile, $outHtml) { if (Test-Path $f) { Remove-Item $f -Force } } }
    }
}

Describe 'DashHtml 2.5.0 column picker survives the YAML round trip' {
    It 'keeps -RememberColumns and a Hidden column' {
        $r = New-DhDashboard -Title 'rt' -GeneratedBy 'rt.ps1'
        Add-DhTable -Report $r -TableId 'tb' -Title 'T' -RememberColumns -NavPath 'A' -Data @([pscustomobject]@{ a = 1; b = 2 }) -Columns @(@{ Field = 'a'; Label = 'A' }, @{ Field = 'b'; Label = 'B'; Hidden = $true })
        $yamlFile = Join-Path ([IO.Path]::GetTempPath()) ('dh25c_' + [guid]::NewGuid().ToString('N') + '.yaml')
        $outHtml  = Join-Path ([IO.Path]::GetTempPath()) ('dh25c_' + [guid]::NewGuid().ToString('N') + '.html')
        try {
            ConvertTo-DhYaml -Report $r -OutFile $yamlFile | Out-Null
            $ps = ConvertFrom-DhYaml -Path $yamlFile -OutputPath 'IGNORED.html'
            $body = ($ps -split "`n" | Where-Object { $_ -notmatch '^\s*#Requires' -and $_ -notmatch '^\s*Import-Module\s+DashHtml' }) -join "`n"
            $body = $body -replace 'IGNORED\.html', ($outHtml -replace '\\', '\\')
            & ([scriptblock]::Create($body)) 3>$null
            $html = Get-Content $outHtml -Raw
            $html | Should -Match '"remember":"[0-9a-f]{16}"'
            $html | Should -Match '"field":"b","label":"B","hidden":true'
        } finally { foreach ($f in $yamlFile, $outHtml) { if (Test-Path $f) { Remove-Item $f -Force } } }
    }
}
Describe 'DashHtml 2.5.1 report-level menu options survive the YAML round trip' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force
        Import-Module (Join-Path $PSScriptRoot '../DashHtml.Design/DashHtml.Design.psd1') -Force
        $script:r = New-DhDashboard -Title 'RT' -NavLayout Sidebar -NavMaxDepth 4 -NavAllLabel @{ Storage = 'All storage' } `
            -NavTree @(@{ Path = 'A'; Label = 'Aa'; Order = 2 }, @{ Path = 'A/B' }) -StrictNav -NavOverflow Wrap
        Add-DhTable -Report $script:r -TableId 'x' -Title 'X' -Data @([pscustomobject]@{ a = 1 }) -NavPath 'A/B'
        $y = $script:r | ConvertTo-DhYaml
        $d = Join-Path ([IO.Path]::GetTempPath()) ('dhrt_' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $d | Out-Null
        $script:dir = $d
        Set-Content (Join-Path $d 'l.yaml') $y
        $script:out = Join-Path $d 'o.html'
        ConvertFrom-DhYaml -Path (Join-Path $d 'l.yaml') -OutFile (Join-Path $d 'b.ps1') -OutputPath $script:out | Out-Null
        $script:ps1 = Get-Content (Join-Path $d 'b.ps1') -Raw
    }
    AfterAll { Remove-Item $script:dir -Recurse -Force -ErrorAction SilentlyContinue }
    It 'writes every option and the rebuilt script passes it back' {
        foreach ($k in '-NavLayout ''Sidebar''', '-NavMaxDepth 4', '-NavAllLabel', '-NavTree', '-StrictNav', '-NavOverflow ''Wrap''') { $script:ps1 | Should -Match ([regex]::Escape($k)) }
    }
    It 'rebuilds an equal report' {
        & (Join-Path $script:dir 'b.ps1') 2>&1 | Out-Null
        $h = Get-Content $script:out -Raw
        $h | Should -Match 'data-navstrict'
        $h | Should -Match 'data-navoverflow="wrap"'
        $h | Should -Match 'data-navtree'
    }
    It 'default menu options are not written (plain YAML unchanged)' {
        $y = New-DhDashboard -Title 'P' | ConvertTo-DhYaml
        $y | Should -Not -Match 'navAllLabel|navTree|strictNav|navOverflow|navLayout|navMaxDepth'
    }
    It 'keeps the order of tree table properties' {
        $r = New-DhDashboard -Title 'O'
        Add-DhTreeTable -Report $r -Id 'tt' -Title 'T' -Rows @(@{ Id = 'o1'; ParentId = ''; Type = 'ou'; Label = 'Root'; Properties = [ordered]@{ Zeta = '1'; Alpha = '2'; Mid = '3' } }) -Memberships @()
        Set-Content (Join-Path $script:dir 'p.yaml') ($r | ConvertTo-DhYaml)
        ConvertFrom-DhYaml -Path (Join-Path $script:dir 'p.yaml') -OutFile (Join-Path $script:dir 'p.ps1') | Out-Null
        (Get-Content (Join-Path $script:dir 'p.ps1') -Raw) | Should -Match 'Zeta = ''1''; Alpha = ''2''; Mid = ''3'''
    }
}
Describe 'DashHtml 2.5.2 JSON Schema for the layout YAML' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1') -Force
        Import-Module (Join-Path $PSScriptRoot '../DashHtml.Design/DashHtml.Design.psd1') -Force
        $script:schemaPath = Join-Path $PSScriptRoot '../DashHtml.Design/dashhtml.schema.json'
        $script:schema = Get-Content -LiteralPath $script:schemaPath -Raw
        $r = New-DhDashboard -Title 'Schema' -NavTitle 'S' -NavLayout Sidebar -NavAllLabel @{ A = 'All a' } -NavTree @(@{ Path = 'A'; Label = 'Aa' }) -StrictNav -Search
        Add-DhSummary -Report $r -Items @(@{ Label = 'One'; Value = 1 })
        Add-DhTable -Report $r -TableId 't' -Title 'T' -Data @([pscustomobject]@{ a = 1; b = 'x' }) -NavPath 'A/B' -RememberColumns -Columns @(@{ Field = 'a'; Label = 'A'; Aggregate = 'sum' }, @{ Field = 'b'; Label = 'B'; Hidden = $true })
        Add-DhFindings -Report $r -Id 'f' -Title 'F' -NavPath 'A/B' -Findings @(@{ Id = 'a'; Title = 'A'; Severity = 'warning'; Description = 'd' })
        Add-DhTreeTable -Report $r -Id 'tt' -Title 'TT' -NavPath 'A/C' -Rows @(@{ Id = 'o'; ParentId = ''; Type = 'ou'; Label = 'Root'; Properties = [ordered]@{ Z = '1'; A = '2' } }) -Memberships @()
        Add-DhHtmlBlock -Report $r -Id 'h' -Title 'H' -Content 'c' -NavPath 'A/B'
        Add-DhAlertBanner -Report $r -Id 'b' -Severity info -Message 'm'
        $script:yaml = $r | ConvertTo-DhYaml
        $script:validate = { param($Json) Test-Json -Json $Json -Schema $script:schema -ErrorAction SilentlyContinue }
        $script:toJson = { param($Yaml) (& (Get-Module DashHtml.Design | Select-Object -Last 1) { param($t) ConvertFrom-DhYamlText $t } $Yaml) | ConvertTo-Json -Depth 50 }
    }
    It 'is exported as Export-DhYamlSchema' {
        (Get-Command Export-DhYamlSchema -Module DashHtml.Design).CommandType | Should -Be 'Function'
    }
    It 'matches the committed dashhtml.schema.json (regenerate it when a cmdlet parameter changes)' {
        # compare the parsed content, so the JSON formatter of a different PowerShell version cannot cause a false alarm
        $sortKeys = $null
        $sortKeys = { param($v)
            if ($v -is [System.Collections.IDictionary]) { $o = [ordered]@{}; foreach ($k in ($v.Keys | Sort-Object { $_ }  -CaseSensitive)) { $o[$k] = & $sortKeys $v[$k] }; return $o }
            if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) { return , @($v | ForEach-Object { & $sortKeys $_ }) }
            return $v }
        $canon = { param($j) (& $sortKeys ($j | ConvertFrom-Json -AsHashtable)) | ConvertTo-Json -Depth 60 -Compress }
        (& $canon (Export-DhYamlSchema)) | Should -BeExactly (& $canon $script:schema)
    }
    It 'writes a relative -OutFile under the PowerShell location, not the process directory (2.5.3)' {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ('dhschema_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir | Out-Null
        $name = 'rel-' + [guid]::NewGuid().ToString('N') + '.json'
        Push-Location $dir
        try {
            Export-DhYamlSchema -OutFile $name
            Test-Path -LiteralPath (Join-Path $dir $name) | Should -BeTrue
            if ([Environment]::CurrentDirectory -ne $dir) { Test-Path -LiteralPath (Join-Path ([Environment]::CurrentDirectory) $name) | Should -BeFalse }
        } finally {
            Pop-Location
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    It 'accepts what ConvertTo-DhYaml writes for a report with tables, blocks, tree table, banner and menu options' {
        (& $script:validate (& $script:toJson $script:yaml)) | Should -BeTrue
    }
    It 'rejects <Name>' -ForEach @(
        @{ Name = 'a mistyped top-level key';  Json = '{"title":"x","navTitel":"a"}' }
        @{ Name = 'a wrong value type';        Json = '{"title":"x","tables":[{"Id":"a","Title":"A","PageSize":"many"}]}' }
        @{ Name = 'a value outside the enum';  Json = '{"title":"x","navOverflow":"Scroll"}' }
        @{ Name = 'an unknown block type';     Json = '{"title":"x","blocks":[{"type":"nope"}]}' }
        @{ Name = 'a mistyped block key';      Json = '{"title":"x","blocks":[{"type":"html","Id":"h","Contnt":"c"}]}' }
        @{ Name = 'a layout without a title';  Json = '{"subtitle":"x"}' }) {
        (& $script:validate $Json) | Should -BeFalse
    }
    It 'accepts Pascal, camel and lower-case spellings of the same key' {
        foreach ($k in 'NavTitle', 'navTitle', 'navtitle') { (& $script:validate ('{"title":"x","' + $k + '":"a"}')) | Should -BeTrue }
    }
}
Describe 'DashHtml 2.6.0 Test-DhReport' {
    BeforeAll {
        $script:tdr = Join-Path ([IO.Path]::GetTempPath()) ('dhtdr_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tdr | Out-Null
        $script:find = { param($Findings, [string] $Check) @($Findings | Where-Object Check -eq $Check) }
    }
    AfterAll { Remove-Item -LiteralPath $script:tdr -Recurse -Force -ErrorAction SilentlyContinue }

    It 'returns nothing for a clean report' {
        @(New-SampleReport | Test-DhReport -PassThru).Count | Should -Be 0
    }
    It 'reports a dangling table reference, a menu typo and a baseline keyed on the wrong field' {
        $rows = 1..20 | ForEach-Object { [pscustomobject]@{ Name = "s$_"; Cpu = $_ } }
        $old  = 1..20 | ForEach-Object { [pscustomobject]@{ Name = "S-$_"; Cpu = $_ } }
        $r = New-DhDashboard -Title 'x'
        Add-DhTable -Report $r -TableId 'a' -Title 'A' -Data $rows -Baseline $old -KeyField 'Name' -NavPath 'Storage/A' -WarningAction SilentlyContinue
        Add-DhTable -Report $r -TableId 'b' -Title 'B' -Data $rows -NavPath 'Storag/B'
        Add-DhBarChart -Report $r -Id 'bc' -Title 'bc' -TableId 'a' -Field 'Cpu'
        $r.Blocks[-1].TableId = 'nope'
        $f = $r | Test-DhReport -PassThru
        (& $script:find $f 'Links').Message | Should -Match "TableId 'nope'"
        (& $script:find $f 'Menu').Message | Should -Match "'Storage' and 'Storag'"
        (& $script:find $f 'Baseline').Message | Should -Match "20 of 20 rows are New"
        @($f | Where-Object Severity -ne 'warning').Count | Should -Be 0
    }
    It 'estimates the data size and names the biggest table' {
        $r = New-DhDashboard -Title 'x'
        Add-DhTable -Report $r -TableId 'wide' -Title 'W' -Data (1..300 | ForEach-Object { [pscustomobject]@{ Name = "n$_"; Text = ('x' * 5000) } })
        $f = $r | Test-DhReport -PassThru -SizeBudgetMB 1
        (& $script:find $f 'Size').Message | Should -Match "'wide' \(300 rows"
    }
    It 'audits a script without running it' {
        $p = Join-Path $script:tdr 'build.ps1'
        "throw 'must not run'`n`$r = New-DhDashboard -Title x`nAdd-DhHtmlBlock -Report `$r -Id h -Content '<b>x</b>'" | Set-Content $p
        $f = Test-DhReport -Path $p -PassThru
        $f.Check | Should -Be 'Script'
        $f.Severity | Should -Be 'ACTION'
        $f.Target | Should -Be 'build.ps1:3'
    }
    It 'names the failing table and key of a layout, and a missing title' {
        $p = Join-Path $script:tdr 'l.yaml'
        "title: t`ntables:`n  - id: ok`n    title: fine`n  - id: bad`n    title: bad`n    pageSize: lots`nbogusKey: 1" | Set-Content $p
        $m = @(Test-DhReport -Path $p -PassThru).Message
        $m | Should -Contain "tables[1] (id 'bad'): unknown key or wrong value: 'pageSize' (`"lots`")."
        $m | Should -Contain 'bogusKey: not a known key (check the spelling).'
        $p2 = Join-Path $script:tdr 'n.yaml'
        "tables:`n  - id: x`n    title: y" | Set-Content $p2
        @(Test-DhReport -Path $p2 -PassThru).Message | Should -Be 'title: missing (every layout needs a title).'
    }
    It 'accepts what ConvertTo-DhYaml writes (with the 2.6.0 keys)' {
        $r = New-DhDashboard -Title 'rt' -LinkState
        Add-DhTable -Report $r -TableId 'a' -Title 'A' -Data @([pscustomobject]@{ N = 1; U = 'x' }) -Columns @(@{ Field = 'N'; Label = 'N' }, @{ Field = 'U'; Label = 'U'; CellType = 'link'; UrlTemplate = 'p.html?n={N}'; LinkTarget = 'same' })
        $p = Join-Path $script:tdr 'rt.yaml'
        $r | ConvertTo-DhYaml -OutFile $p
        (Get-Content $p -Raw) | Should -Match 'linkState: true'
        @(Test-DhReport -Path $p -PassThru).Count | Should -Be 0
    }
    It 'lists the fixes an HTML built with an older runtime misses' {
        $r = New-DhDashboard -Title 'x'
        $p = Join-Path $script:tdr 'r.html'
        Export-DhDashboard -Report $r -OutputPath $p -Force
        @(Test-DhReport -Path $p -PassThru).Count | Should -Be 0
        (Get-Content $p -Raw) -replace 'DashHtml</strong> v[\d.]+', 'DashHtml</strong> v2.5.1' | Set-Content $p
        $f = Test-DhReport -Path $p -PassThru
        $f.Check | Should -Be 'Runtime'
        $f.Message | Should -Match 'Built with DashHtml 2\.5\.1'
        $f.Message | Should -Match '2\.5\.2 \(keyboard access'
        $f.Message | Should -Not -Match '2\.5\.1 \('
    }
    It 'sets LASTEXITCODE with -Strict' {
        $p = Join-Path $script:tdr 'strict.ps1'
        "Add-DhHtmlBlock -Report `$r -Id h -Content '<i>x</i>'" | Set-Content $p
        Test-DhReport -Path $p -Strict -PassThru | Out-Null
        $LASTEXITCODE | Should -Be 1
        Test-DhReport -Path (Join-Path $script:tdr 'rt.yaml') -Strict -PassThru | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
    It 'reports a missing file instead of throwing' {
        (Test-DhReport -Path (Join-Path $script:tdr 'nope.html') -PassThru).Severity | Should -Be 'error'
    }
}
