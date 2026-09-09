#Requires -Version 7.0
<#
.SYNOPSIS  Pester 5 test suite for the DashHtml.Design companion module.
.DESCRIPTION
    Covers the three public functions:
      ConvertTo-DhYaml     report object -> YAML  (lossless layout view)
      ConvertFrom-DhYaml   YAML/JSON     -> .ps1  (runnable build script)
      ConvertFrom-DhScript .ps1          -> YAML  (best-effort static parse)

    Plus the self-contained YAML reader/writer round-trip that underpins them.

    Run:  Invoke-Pester .\Tests -Output Detailed
          .\Build.ps1   (runs automatically as part of the build)
#>

# ---------------------------------------------------------------------------
# Module import — both the core module and the design companion.
# The design module reads core cmdlet metadata, so both must be loaded from
# the LOCAL source (not any installed copy) for the tests to be meaningful.
# ---------------------------------------------------------------------------
BeforeAll {
    $script:corePath   = Join-Path $PSScriptRoot '..\DashHtml\DashHtml.psd1'
    $script:designPath = Join-Path $PSScriptRoot '..\DashHtml.Design\DashHtml.Design.psd1'
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
    dataFile: .\data\servers.csv
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
Export-DhDashboard -Report $r -OutputPath '.\out.html'
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
        $example = Join-Path $PSScriptRoot '..\Examples\Demo-VMware.ps1'
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
