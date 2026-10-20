#Requires -Version 7.0
<#
.SYNOPSIS  Pester 5 tests for the DashHtml 2.0.0 navigation model.
.DESCRIPTION
    Covers the visibility predicate (Test-DhNavMatch) and the path parser
    (ConvertFrom-DhNavPath) that together define nav in 2.0.0.

    These are the PowerShell half of the two-layer strategy in plan-v2.md WP2.
    The JS half lives in Tests/js/ and is driven under Node; a source-level pin
    asserts the two stay in agreement.

    NB: no angle brackets in It names - Pester 5 parses <...> as a -ForEach
    template token (memory: pester-it-name-angle-brackets).
#>

BeforeAll {
    $script:modulePath = Join-Path $PSScriptRoot '../DashHtml/DashHtml.psd1'
    Import-Module $script:modulePath -Force
    # Private helpers: dot-source directly so they can be tested in isolation.
    . (Join-Path $PSScriptRoot '../DashHtml/Private/Test-DhNavMatch.ps1')
}

AfterAll { Remove-Module DashHtml -ErrorAction SilentlyContinue }

Describe 'ConvertFrom-DhNavPath' {

    It 'returns an empty array for an empty or null path' {
        @(ConvertFrom-DhNavPath '').Count      | Should -Be 0
        @(ConvertFrom-DhNavPath $null).Count   | Should -Be 0
        @(ConvertFrom-DhNavPath '   ').Count   | Should -Be 0
    }

    It 'splits a single segment' {
        $r = @(ConvertFrom-DhNavPath 'Storage')
        $r.Count | Should -Be 1
        $r[0]    | Should -Be 'Storage'
    }

    It 'splits multiple segments' {
        $r = @(ConvertFrom-DhNavPath 'Storage/Tagging/Key usage')
        $r.Count | Should -Be 3
        $r[2]    | Should -Be 'Key usage'
    }

    It 'treats a doubled slash as a literal slash inside a segment' {
        $r = @(ConvertFrom-DhNavPath 'Reports/AC//DC')
        $r.Count | Should -Be 2
        $r[1]    | Should -Be 'AC/DC'
    }

    It 'trims surrounding whitespace on each segment' {
        $r = @(ConvertFrom-DhNavPath ' Storage / Tagging ')
        $r[0] | Should -Be 'Storage'
        $r[1] | Should -Be 'Tagging'
    }

    It 'throws on an empty segment rather than creating an unaddressable node' {
        { ConvertFrom-DhNavPath 'Storage/' }    | Should -Throw   # trailing separator
        { ConvertFrom-DhNavPath '/Storage' }    | Should -Throw   # leading separator
        { ConvertFrom-DhNavPath 'A/ /B' }       | Should -Throw   # whitespace-only segment
    }

    It 'allows a segment that ends in an escaped slash' {
        # 'Storage//' is the escape for the single segment 'Storage/', not a
        # trailing separator. Likewise 'A///B' is 'A/' then 'B'.
        $r = @(ConvertFrom-DhNavPath 'Storage//')
        $r.Count | Should -Be 1
        $r[0]    | Should -Be 'Storage/'

        $r2 = @(ConvertFrom-DhNavPath 'A///B')
        $r2.Count | Should -Be 2
        $r2[0]    | Should -Be 'A/'
        $r2[1]    | Should -Be 'B'
    }
}

Describe 'Test-DhNavMatch truth table' {

    Context 'Scope Global' {
        It 'is visible regardless of declared or selected path' {
            Test-DhNavMatch -DeclaredPath @()          -SelectedPath @()                    -Scope Global | Should -BeTrue
            Test-DhNavMatch -DeclaredPath @()          -SelectedPath @('Storage')           -Scope Global | Should -BeTrue
            Test-DhNavMatch -DeclaredPath @('Network') -SelectedPath @('Storage','Tagging') -Scope Global | Should -BeTrue
        }
    }

    Context 'Scope Exact' {
        It 'matches only at the identical path' {
            Test-DhNavMatch -DeclaredPath @('Storage') -SelectedPath @('Storage') -Scope Exact | Should -BeTrue
        }
        It 'does not match a deeper selection' {
            Test-DhNavMatch -DeclaredPath @('Storage') -SelectedPath @('Storage','Tagging') -Scope Exact | Should -BeFalse
        }
        It 'does not match a shallower selection' {
            Test-DhNavMatch -DeclaredPath @('Storage','Tagging') -SelectedPath @('Storage') -Scope Exact | Should -BeFalse
        }
        It 'does not match a sibling branch' {
            Test-DhNavMatch -DeclaredPath @('Storage') -SelectedPath @('Network') -Scope Exact | Should -BeFalse
        }
    }

    Context 'Scope Subtree' {
        It 'matches at its own node' {
            Test-DhNavMatch -DeclaredPath @('Storage') -SelectedPath @('Storage') -Scope Subtree | Should -BeTrue
        }
        It 'matches any descendant selection' {
            Test-DhNavMatch -DeclaredPath @('Storage') -SelectedPath @('Storage','Tagging')             -Scope Subtree | Should -BeTrue
            Test-DhNavMatch -DeclaredPath @('Storage') -SelectedPath @('Storage','Tagging','Key usage') -Scope Subtree | Should -BeTrue
        }
        It 'does not match an ancestor selection' {
            Test-DhNavMatch -DeclaredPath @('Storage','Tagging') -SelectedPath @('Storage') -Scope Subtree | Should -BeFalse
        }
        It 'does not leak into a sibling branch' {
            Test-DhNavMatch -DeclaredPath @('Storage') -SelectedPath @('Network','X') -Scope Subtree | Should -BeFalse
        }
    }

    Context 'Depth agnosticism' {
        It 'behaves identically at four and five levels' {
            $d4 = @('A','B','C','D'); $d5 = @('A','B','C','D','E')
            Test-DhNavMatch -DeclaredPath $d4 -SelectedPath $d4 -Scope Exact   | Should -BeTrue
            Test-DhNavMatch -DeclaredPath $d4 -SelectedPath $d5 -Scope Subtree | Should -BeTrue
            Test-DhNavMatch -DeclaredPath $d4 -SelectedPath $d5 -Scope Exact   | Should -BeFalse
            Test-DhNavMatch -DeclaredPath $d5 -SelectedPath $d4 -Scope Subtree | Should -BeFalse
        }
    }

    Context 'Matching is case-sensitive' {
        It 'treats Sub A and Sub a as different nodes' {
            Test-DhNavMatch -DeclaredPath @('Sub A') -SelectedPath @('Sub a') -Scope Exact | Should -BeFalse
        }
    }

    Context 'Empty declared path' {
        It 'with Exact is visible only at the root view' {
            Test-DhNavMatch -DeclaredPath @() -SelectedPath @()          -Scope Exact | Should -BeTrue
            Test-DhNavMatch -DeclaredPath @() -SelectedPath @('Storage') -Scope Exact | Should -BeFalse
        }
        It 'with Subtree is visible everywhere' {
            Test-DhNavMatch -DeclaredPath @() -SelectedPath @('Storage','Tagging') -Scope Subtree | Should -BeTrue
        }
    }
}

Describe 'Regression: the 1.x NavSubGroup bug cannot recur' {
    # readme-dev gotcha #26. In 1.x a BLOCK declared with -NavGroup + -NavSubGroup
    # was unreachable: selecting its own subgroup failed to reveal it. Reproduced
    # in a browser during review. Under the 2.0.0 predicate it is reachable, and
    # re-selecting is idempotent.

    It 'makes a block in a non-first subgroup visible at its own node' {
        Test-DhNavMatch -DeclaredPath @('Storage','Tagging') -SelectedPath @('Storage','Tagging') -Scope Subtree |
            Should -BeTrue
    }

    It 'hides it again when a sibling subgroup is selected' {
        Test-DhNavMatch -DeclaredPath @('Storage','Tagging') -SelectedPath @('Storage','Capacity') -Scope Subtree |
            Should -BeFalse
    }

    It 'brings the first subgroup back when re-selected (1.x never did)' {
        Test-DhNavMatch -DeclaredPath @('Storage','Capacity') -SelectedPath @('Storage','Capacity') -Scope Subtree |
            Should -BeTrue
    }

    It 'leaves a group-only block visible across the whole group' {
        Test-DhNavMatch -DeclaredPath @('Storage') -SelectedPath @('Storage','Capacity') -Scope Subtree | Should -BeTrue
        Test-DhNavMatch -DeclaredPath @('Storage') -SelectedPath @('Storage','Tagging')  -Scope Subtree | Should -BeTrue
    }

    It 'is idempotent and route-independent' {
        # The property 1.x lacked: the answer depends only on the arguments.
        $a = Test-DhNavMatch -DeclaredPath @('Storage','Tagging') -SelectedPath @('Storage','Tagging') -Scope Subtree
        $null = Test-DhNavMatch -DeclaredPath @('Storage','Tagging') -SelectedPath @('Network')        -Scope Subtree
        $b = Test-DhNavMatch -DeclaredPath @('Storage','Tagging') -SelectedPath @('Storage','Tagging') -Scope Subtree
        $a | Should -Be $b
    }
}

Describe 'Structural: no content can be unreachable' {
    # The failure class the reported bug belongs to. Every declared section must
    # be visible for at least one reachable path.
    It 'finds a reachable path for every declared section' {
        $sections = @(
            @{ Id='chartCap'; Path=@('Storage','Capacity');        Scope='Subtree' }
            @{ Id='chartTag'; Path=@('Storage','Tagging');         Scope='Subtree' }
            @{ Id='tblA';     Path=@('Storage','Capacity','tblA'); Scope='Exact'   }
            @{ Id='tblB';     Path=@('Storage','Tagging','tblB');  Scope='Exact'   }
            @{ Id='grpOnly';  Path=@('Storage');                   Scope='Subtree' }
            @{ Id='banner';   Path=@();                            Scope='Global'  }
            @{ Id='netTbl';   Path=@('Network','tblC');            Scope='Exact'   }
        )
        # Every prefix of every declared path is a reachable view.
        $paths = [System.Collections.Generic.List[object]]::new()
        $paths.Add(@())
        foreach ($s in $sections) {
            for ($i = 1; $i -le $s.Path.Count; $i++) { $paths.Add(@($s.Path[0..($i-1)])) }
        }
        $unreachable = foreach ($s in $sections) {
            $hit = $false
            foreach ($p in $paths) {
                if (Test-DhNavMatch -DeclaredPath $s.Path -SelectedPath $p -Scope $s.Scope) { $hit = $true; break }
            }
            if (-not $hit) { $s.Id }
        }
        @($unreachable) | Should -HaveCount 0
    }
}

Describe 'Resolve-DhNavDeclaration' {
    BeforeAll { . (Join-Path $PSScriptRoot '../DashHtml/Private/Resolve-DhNavDeclaration.ps1') }

    Context 'v2 API' {
        It 'parses a path and defaults scope to Exact' {
            $r = Resolve-DhNavDeclaration -NavPath 'Storage/Tagging'
            @($r.Path).Count | Should -Be 2
            $r.Path[1]       | Should -Be 'Tagging'
            $r.Scope         | Should -Be 'Exact'
        }
        It 'honours an explicit scope' {
            (Resolve-DhNavDeclaration -NavPath 'Storage' -NavScope 'Subtree').Scope | Should -Be 'Subtree'
        }
    }

    Context 'v1 compat mapping (proposed.md section 5)' {
        It 'maps a block with NavGroup only to that path with Subtree scope' {
            $r = Resolve-DhNavDeclaration -NavGroup 'Storage' -ItemKind Block
            @($r.Path).Count | Should -Be 1
            $r.Path[0]       | Should -Be 'Storage'
            $r.Scope         | Should -Be 'Subtree'
        }
        It 'maps a block with NavGroup + NavSubGroup to a 2-segment Subtree path' {
            $r = Resolve-DhNavDeclaration -NavGroup 'Storage' -NavSubGroup 'Tagging' -ItemKind Block
            @($r.Path).Count | Should -Be 2
            $r.Scope         | Should -Be 'Subtree'
        }
        It 'appends TableId as a leaf for a grouped table, keyed on TableId not Title' {
            $r = Resolve-DhNavDeclaration -NavGroup 'Storage' -ItemKind Table -TableId 'vols'
            @($r.Path).Count | Should -Be 2
            $r.Path[1]       | Should -Be 'vols'
            $r.Scope         | Should -Be 'Exact'
        }
        It 'appends TableId under a subgroup too' {
            $r = Resolve-DhNavDeclaration -NavGroup 'Storage' -NavSubGroup 'Capacity' -ItemKind Table -TableId 'vols'
            @($r.Path) -join '/' | Should -Be 'Storage/Capacity/vols'
        }
        It 'throws when a table uses the compat API without a TableId' {
            { Resolve-DhNavDeclaration -NavGroup 'S' -ItemKind Table } | Should -Throw
        }
    }

    Context 'No nav parameters' {
        It 'is page-global' {
            $r = Resolve-DhNavDeclaration
            @($r.Path).Count | Should -Be 0
            $r.Scope         | Should -Be 'Global'
        }
    }

    Context 'Conflicts are hard errors, never silent precedence' {
        It 'rejects NavPath combined with NavGroup' {
            { Resolve-DhNavDeclaration -NavPath 'A/B' -NavGroup 'A' } | Should -Throw
        }
        It 'rejects NavPath combined with NavSubGroup' {
            { Resolve-DhNavDeclaration -NavPath 'A/B' -NavSubGroup 'B' } | Should -Throw
        }
        It 'rejects NavSubGroup without NavGroup' {
            { Resolve-DhNavDeclaration -NavSubGroup 'B' } | Should -Throw
        }
    }

    Context 'Round-trip through the predicate' {
        It 'reproduces 1.x visibility for a group-only block' {
            $r = Resolve-DhNavDeclaration -NavGroup 'Storage' -ItemKind Block
            Test-DhNavMatch -DeclaredPath $r.Path -SelectedPath @('Storage','Capacity') -Scope $r.Scope | Should -BeTrue
        }
        It 'makes the previously invisible subgroup block reachable' {
            $r = Resolve-DhNavDeclaration -NavGroup 'Storage' -NavSubGroup 'Tagging' -ItemKind Block
            Test-DhNavMatch -DeclaredPath $r.Path -SelectedPath @('Storage','Tagging') -Scope $r.Scope | Should -BeTrue
        }
        It 'keeps a compat table selectable at its own leaf' {
            $r = Resolve-DhNavDeclaration -NavGroup 'Storage' -ItemKind Table -TableId 'vols'
            Test-DhNavMatch -DeclaredPath $r.Path -SelectedPath @('Storage','vols') -Scope $r.Scope | Should -BeTrue
            Test-DhNavMatch -DeclaredPath $r.Path -SelectedPath @('Storage')        -Scope $r.Scope | Should -BeFalse
        }
    }
}

Describe 'Nav layout resolution (v2.0.0 WP3)' {
    BeforeAll {
        $script:navTmp = Join-Path ([IO.Path]::GetTempPath()) ("dhnav_$([guid]::NewGuid().ToString('N'))")
        New-Item -ItemType Directory -Path $script:navTmp -Force | Out-Null
        function script:Build-NavReport {
            param([string[]] $Paths, [string] $Layout = 'Auto', [int] $MaxDepth = 5)
            $rows = 1..2 | ForEach-Object { [pscustomobject]@{ N = "i$_" } }
            $r = New-DhDashboard -Title 'layout' -NavLayout $Layout -NavMaxDepth $MaxDepth
            $i = 0
            foreach ($p in $Paths) { $i++; Add-DhTable -Report $r -TableId "t$i" -Title "T$i" -Data $rows -NavPath $p }
            $f = Join-Path $script:navTmp "l$([guid]::NewGuid().ToString('N')).html"
            Export-DhDashboard -Report $r -OutputPath $f -Force
            $h = Get-Content $f -Raw
            Remove-Item $f -Force
            $m = [regex]::Match($h, 'data-navlayout="([^"]*)"\s+data-navdepth="([^"]*)"')
            return @{ Layout = $m.Groups[1].Value; Depth = [int]$m.Groups[2].Value; Html = $h }
        }
    }
    AfterAll { Remove-Item $script:navTmp -Recurse -Force -ErrorAction SilentlyContinue }

    It 'uses strips at three levels or fewer' {
        (Build-NavReport -Paths @('Storage/Capacity/tA')).Layout | Should -Be 'strips'
        (Build-NavReport -Paths @('Storage/Capacity')).Layout    | Should -Be 'strips'
        (Build-NavReport -Paths @('Storage')).Layout             | Should -Be 'strips'
    }

    It 'switches to the sidebar at four levels' {
        $r = Build-NavReport -Paths @('Network/Edge/Firewall/d1')
        $r.Depth  | Should -Be 4
        $r.Layout | Should -Be 'sidebar'
    }

    It 'honours an explicit -NavLayout Strips even when deep' {
        (Build-NavReport -Paths @('A/B/C/D') -Layout 'Strips').Layout | Should -Be 'strips'
    }

    It 'honours an explicit -NavLayout Sidebar even when shallow' {
        (Build-NavReport -Paths @('A') -Layout 'Sidebar').Layout | Should -Be 'sidebar'
    }

    It 'emits both menu hosts so the runtime can switch without re-export' {
        $h = (Build-NavReport -Paths @('A/B')).Html
        $h | Should -Match 'id="nav-strips"'
        $h | Should -Match 'id="nav-sidebar"'
        $h | Should -Match 'id="nav-crumb"'
    }

    It 'warns when the tree is deeper than -NavMaxDepth' {
        $rows = 1..2 | ForEach-Object { [pscustomobject]@{ N = "i$_" } }
        $r = New-DhDashboard -Title 'deep' -NavMaxDepth 2
        Add-DhTable -Report $r -TableId 't1' -Title 'T1' -Data $rows -NavPath 'A/B/C/D'
        $f = Join-Path $script:navTmp 'warn.html'
        $w = $null
        Export-DhDashboard -Report $r -OutputPath $f -Force -WarningVariable w -WarningAction SilentlyContinue
        @($w) -join ' ' | Should -Match 'NavMaxDepth'
        Test-Path $f | Should -BeTrue   # still exports; depth is a policy, not an error
        Remove-Item $f -Force
    }

    It 'defaults to Auto with a max depth of 3' {
        $r = New-DhDashboard -Title 'defaults'
        $r.NavLayout   | Should -Be 'Auto'
        $r.NavMaxDepth | Should -Be 3
    }
}
