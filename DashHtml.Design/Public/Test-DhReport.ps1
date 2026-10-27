function Test-DhReport {
    <#
    .SYNOPSIS
        One command for every DashHtml check: a report object, a build script, a layout YAML or a built HTML file.

    .DESCRIPTION
        v2.6.0. Runs the checks that apply to what it is given and lists the findings. It never throws on a
        finding and never changes a file.

          Report object (-Report)   Links (tables named by charts, links and actions exist), Menu (the
                                    -StrictNav lint, run even when -StrictNav is off), Size (estimated
                                    data size per table and tree table), Baseline (a table whose rows are
                                    nearly all New, or whose whole baseline was removed: probably a wrong
                                    -KeyField).
          .ps1 script               Script (the Update-DhScript audit: ACTION / advisory / info). The
                                    script is parsed, never run.
          .yaml / .yml / .json      Schema (the layout against Export-DhYamlSchema; each failing table,
                                    block or key is named), then Links and Menu are not available (the
                                    data is not in the layout).
          .html                     Runtime (built with an older DashHtml: the fixes it misses), Size.
                                    With -Deep also the accessibility and contrast audits (needs Edge or
                                    Chrome and the Tools folder of a DashHtml checkout).

        Severities: error (the file cannot be used as is), ACTION (an upgrade change that alters the
        result), warning, advisory, info.

    .PARAMETER Path
        Files to check (.ps1, .yaml, .yml, .json, .html). Wildcards and folders (searched recursively for
        those extensions) are accepted.

    .PARAMETER Report
        A report object from New-DhDashboard (also from the pipeline).

    .PARAMETER Strict
        Set $LASTEXITCODE to 1 when any finding is an error, an ACTION or a warning (for CI and Build.ps1).

    .PARAMETER PassThru
        Return the findings as objects (Check, Severity, Target, Message) instead of printing a summary.

    .PARAMETER Deep
        For .html files, also run Tools\Test-DhA11y.ps1 and Tools\Test-DhContrast.ps1.

    .PARAMETER SizeBudgetMB
        Size above which a report or file is reported (default 15, as Export-DhDashboard -SizeBudgetMB).

    .EXAMPLE
        Test-DhReport -Path .\Reports\ad-audit.ps1

    .EXAMPLE
        $report | Test-DhReport -PassThru | Where-Object Severity -eq 'warning'

    .EXAMPLE
        Test-DhReport -Path .\out\*.html -Strict     # CI: fails when a report was built with an older runtime
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Console summary for a human; structured output is available via -PassThru.')]
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(ParameterSetName = 'Path', Position = 0)]
        [string[]] $Path = @(),
        [Parameter(ParameterSetName = 'Report', Mandatory, ValueFromPipeline)]
        [System.Collections.Specialized.OrderedDictionary] $Report,
        [switch] $Strict,
        [switch] $PassThru,
        [switch] $Deep,
        [ValidateRange(1, 100000)]
        [int]    $SizeBudgetMB = 15
    )

    begin {
        $all = [System.Collections.Generic.List[object]]::new()
        $dh = Get-Module DashHtml | Select-Object -Last 1
        if (-not $dh) { $dh = Import-Module DashHtml -PassThru -ErrorAction Stop }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Report') {
            foreach ($f in (Test-DhReportObject -Report $Report -DashHtml $dh -SizeBudgetMB $SizeBudgetMB -Target ([string]$Report.Title))) { $all.Add($f) }
            return
        }
        $files = foreach ($p in @($Path)) {
            if (Test-Path -LiteralPath $p -PathType Container) {
                Get-ChildItem -LiteralPath $p -Recurse -File | Where-Object { $_.Extension -in '.ps1', '.yaml', '.yml', '.json', '.html' }
            } else {
                $found = @(Get-Item -Path $p -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer })
                if (-not $found.Count) { $all.Add((New-DhFinding 'File' 'error' $p 'File not found.')) }
                $found
            }
        }
        foreach ($file in @($files)) {
            switch ($file.Extension.ToLowerInvariant()) {
                '.ps1'  { foreach ($f in (Test-DhReportScript -File $file)) { $all.Add($f) } }
                '.html' { foreach ($f in (Test-DhReportHtml -File $file -DashHtml $dh -SizeBudgetMB $SizeBudgetMB -Deep:$Deep)) { $all.Add($f) } }
                default { foreach ($f in (Test-DhReportLayout -File $file)) { $all.Add($f) } }
            }
        }
    }

    end {
        if ($Strict -and @($all | Where-Object { $_.Severity -in 'error', 'ACTION', 'warning' }).Count) { $global:LASTEXITCODE = 1 }
        elseif ($Strict) { $global:LASTEXITCODE = 0 }
        if ($PassThru) { return $all.ToArray() }
        if ($all.Count -eq 0) { Write-Host 'Test-DhReport: no findings.' -ForegroundColor Green; return }
        $colour = @{ error = 'Red'; ACTION = 'Red'; warning = 'Yellow'; advisory = 'Cyan'; info = 'Gray' }
        foreach ($g in ($all | Group-Object Target)) {
            Write-Host ''
            Write-Host $g.Name -ForegroundColor White
            foreach ($f in $g.Group) {
                Write-Host ('  {0,-8} {1,-9} {2}' -f $f.Severity, $f.Check, $f.Message) -ForegroundColor $colour[$f.Severity]
            }
        }
        $counts = ($all | Group-Object Severity | ForEach-Object { "$($_.Count) $($_.Name)" }) -join ', '
        Write-Host ''
        Write-Host "Test-DhReport: $($all.Count) finding(s): $counts."
    }
}

function New-DhFinding {
    param([string] $Check, [string] $Severity, [string] $Target, [string] $Message)
    [pscustomobject]@{ Check = $Check; Severity = $Severity; Target = $Target; Message = $Message }
}

function Test-DhReportObject {
    <# Links, Menu, Size and Baseline checks on a built report object. #>
    param($Report, $DashHtml, [int] $SizeBudgetMB, [string] $Target)
    $known = @($script:DhTypeToCmdlet.Keys)
    foreach ($m in @(& $DashHtml { param($r, $k) Test-DhReportLinks -Report $r -KnownBlockTypes $k } $Report $known)) {
        New-DhFinding 'Links' 'warning' $Target $m
    }
    foreach ($m in @(& $DashHtml { param($r) Test-DhNavLint -Report $r } $Report)) {
        New-DhFinding 'Menu' 'warning' $Target $m
    }

    # Size: the JSON of a sample of rows, scaled to the row count
    $sizes = [System.Collections.Generic.List[object]]::new()
    $estimate = {
        param([object[]] $Rows)
        $n = @($Rows).Count
        if (-not $n) { return 0 }
        $sample = @($Rows | Select-Object -First 200)
        $json = ConvertTo-Json -InputObject $sample -Compress -Depth 6 -WarningAction SilentlyContinue
        [long]([Text.Encoding]::UTF8.GetByteCount($json) / $sample.Count * $n)
    }
    foreach ($t in @($Report.Tables)) { $sizes.Add([pscustomobject]@{ Id = [string]$t.Id; Bytes = (& $estimate @($t.Data)); Rows = @($t.Data).Count }) }
    if ($Report.Contains('Blocks')) {
        foreach ($b in @($Report.Blocks | Where-Object { $_.BlockType -eq 'treetable' })) {
            $sizes.Add([pscustomobject]@{ Id = [string]$b.Id; Bytes = (& $estimate @($b.Rows)); Rows = @($b.Rows).Count })
        }
    }
    $total = ($sizes | Measure-Object Bytes -Sum).Sum
    if ($total -gt [long]$SizeBudgetMB * 1MB) {
        $top = @($sizes | Sort-Object Bytes -Descending | Select-Object -First 3 | ForEach-Object { "'$($_.Id)' ($($_.Rows) rows, about $([math]::Round($_.Bytes / 1MB, 1)) MB)" }) -join ', '
        New-DhFinding 'Size' 'warning' $Target "The data is about $([math]::Round($total / 1MB, 1)) MB, over $SizeBudgetMB MB. Biggest: $top. Consider Export-DhDashboard -CompressData, fewer columns or a split report."
    }

    # Baseline sanity: almost everything New, or the whole baseline Removed, usually means a wrong -KeyField
    foreach ($t in @($Report.Tables | Where-Object { $_.Contains('Baseline') -and $_.Baseline })) {
        $c = $t.Baseline.Counts
        $rows = @($t.Data).Count
        $baseRows = [int]$c.Same + [int]$c.Changed + [int]$c.Removed
        if ($rows -ge 10 -and $baseRows -gt 0 -and [int]$c.New -gt 0.9 * $rows) {
            New-DhFinding 'Baseline' 'warning' $Target "Table '$($t.Id)': $($c.New) of $rows rows are New against a baseline of $baseRows rows. Check -KeyField '$($t.Baseline.KeyField)' (same property, same values, in both runs?)."
        } elseif ($baseRows -gt 0 -and [int]$c.Removed -eq $baseRows) {
            New-DhFinding 'Baseline' 'warning' $Target "Table '$($t.Id)': every baseline row ($baseRows) was removed. Check -KeyField '$($t.Baseline.KeyField)'."
        }
    }
}

function Test-DhReportScript {
    <# The Update-DhScript audit of one script (parsed, not run). #>
    param([System.IO.FileInfo] $File)
    foreach ($r in @(Update-DhScript -Path $File.FullName -PassThru)) {
        New-DhFinding 'Script' $r.Severity "$($File.Name):$($r.Line)" "$($r.Cmdlet): $($r.Issue)"
    }
}

function Test-DhReportLayout {
    <# A layout YAML / JSON against the schema; each failing section item is named. #>
    param([System.IO.FileInfo] $File)
    $target = $File.Name
    try {
        $text = Get-Content -LiteralPath $File.FullName -Raw
        $model = if ($File.Extension -ieq '.json') { $text | ConvertFrom-Json -AsHashtable -Depth 64 } else { ConvertFrom-DhYamlText $text }
    } catch {
        return (New-DhFinding 'Schema' 'error' $target "Cannot read the layout: $($_.Exception.Message)")
    }
    if ($model -isnot [System.Collections.IDictionary]) { return (New-DhFinding 'Schema' 'error' $target 'The layout is not a mapping (expected keys such as title, tables, blocks).') }
    $schema = Export-DhYamlSchema
    $check = {
        param($doc)
        $ev = $null
        $ok = Test-Json -Json (ConvertTo-Json -InputObject $doc -Depth 64 -Compress) -Schema $schema -ErrorVariable ev -ErrorAction SilentlyContinue
        # the root accepts title or Title (anyOf), so a valid document still reports the other spelling as missing: drop that noise
        $msgs = @($ev | ForEach-Object { $_.Exception.Message -replace '^The JSON is not valid with the schema: ', '' } |
                  ForEach-Object { ($_ -replace 'Required properties \["(T|t)itle"\] are not present at \x27\x27\s*', '').Trim() } | Where-Object { $_ })
        [pscustomobject]@{ Ok = [bool]$ok; Message = ($msgs -join ' ') }
    }
    # Which keys of a failing mapping are to blame: the ones whose removal makes it pass
    $blame = {
        param([string] $Section, $Item, $Title)
        $bad = foreach ($key in @($Item.Keys)) {
            $copy = [ordered]@{}
            foreach ($k2 in $Item.Keys) { if ($k2 -cne $key) { $copy[$k2] = $Item[$k2] } }
            $doc = [ordered]@{ title = $Title }; $doc[$Section] = @($copy)
            if ((& $check $doc).Ok) { "'$key' ($(ConvertTo-Json -InputObject $Item[$key] -Compress -Depth 3))" }
        }
        @($bad)
    }
    $whole = & $check $model
    if ($whole.Ok) { return }
    $title = if ($model.Contains('title')) { $model['title'] } elseif ($model.Contains('Title')) { $model['Title'] } else { $null }
    $named = 0
    if ($null -eq $title -or "$title" -eq '') { New-DhFinding 'Schema' 'error' $target 'title: missing (every layout needs a title).'; $named++ }
    foreach ($k in @($model.Keys)) {
        if ($k -in 'title', 'Title') { continue }
        $v = $model[$k]
        # assigned in a statement, not as the value of an if: a one-item array would unroll to the item
        $items = $null
        if ($v -is [System.Collections.IList]) { $items = @($v) }
        if ($null -ne $items) {
            for ($i = 0; $i -lt $items.Count; $i++) {
                $doc = [ordered]@{ title = $(if ($null -ne $title) { $title } else { 'x' }) }
                $doc[$k] = @($items[$i])
                $r = & $check $doc
                if (-not $r.Ok) {
                    $isMap = $items[$i] -is [System.Collections.IDictionary]
                    $idv = if ($isMap) { @('id', 'Id', 'TableId', 'tableId') | Where-Object { $items[$i].Contains($_) } | Select-Object -First 1 } else { $null }
                    $label = if ($idv) { " ($idv '$($items[$i][$idv])')" } else { '' }
                    $keys = if ($isMap) { & $blame $k $items[$i] $doc.title } else { @() }
                    $why = if (@($keys).Count) { "unknown key or wrong value: $(@($keys) -join ', ')." } elseif ($r.Message) { $r.Message } else { 'does not match the schema (a required key may be missing).' }
                    New-DhFinding 'Schema' 'error' $target "$k[$i]$label`: $why"; $named++
                }
            }
        } else {
            $doc = [ordered]@{ title = $(if ($null -ne $title) { $title } else { 'x' }) }
            $doc[$k] = $v
            $r = & $check $doc
            if (-not $r.Ok) {
                $why = if (-not $r.Message -or $r.Message -match 'false schema') { 'not a known key (check the spelling).' } else { $r.Message }
                New-DhFinding 'Schema' 'error' $target "$k`: $why"; $named++
            }
        }
    }
    if (-not $named) { New-DhFinding 'Schema' 'error' $target $(if ($whole.Message) { $whole.Message } else { 'The layout does not match the schema (is the title missing?).' }) }
}

# Fixes by release, for "built with an older runtime". Newest first; only releases since 2.4.0.
$script:DhRuntimeFixes = [ordered]@{
    '2.7.0' = 'readable muted text in every theme, a branded header band in light and dark, no type below 11.5px, sentence-case titles, -Density'
    '2.6.0' = 'link columns with relative URLs and templates, windowed tree tables, compressed data, table state in the address'
    '2.5.4' = 'data fields named Keys, Values or Count were dropped'
    '2.5.3' = 'menu "More" after one row instead of two'
    '2.5.2' = 'keyboard access to collapsible sections, CSV formula guard, baseline markers'
    '2.5.1' = 'print without shadows, readable heatmap values in dark mode, contrast fixes in 10 themes'
    '2.5.0' = 'tree tables, menu keyboard support, column picker memory'
    '2.4.1' = 'banner and menu order fixes'
}

function Test-DhReportHtml {
    <# A built report: runtime version against the installed module, file size, and (-Deep) the browser audits. #>
    param([System.IO.FileInfo] $File, $DashHtml, [int] $SizeBudgetMB, [switch] $Deep)
    $target = $File.Name
    $head = [IO.File]::ReadAllText($File.FullName)
    $m = [regex]::Match($head, 'Generated by <strong>DashHtml</strong> v(\d+\.\d+\.\d+)')
    if (-not $m.Success) {
        New-DhFinding 'Runtime' 'info' $target 'Not a DashHtml report (no "Generated by DashHtml" footer).'
    } else {
        $built = [version]$m.Groups[1].Value
        $now = $DashHtml.Version
        if ($built -lt $now) {
            $missed = @($script:DhRuntimeFixes.Keys | Where-Object { [version]$_ -gt $built -and [version]$_ -le $now } | ForEach-Object { "$_ ($($script:DhRuntimeFixes[$_]))" })
            $list = if ($missed.Count) { ' Missing: ' + ($missed -join '; ') + '.' } else { '' }
            New-DhFinding 'Runtime' 'advisory' $target "Built with DashHtml $built; $now is installed. Regenerate the report to pick up the fixes.$list"
        }
    }
    if ($File.Length -gt [long]$SizeBudgetMB * 1MB) {
        New-DhFinding 'Size' 'warning' $target "The file is $([math]::Round($File.Length / 1MB, 1)) MB, over $SizeBudgetMB MB. Consider Export-DhDashboard -CompressData."
    }
    if ($Deep) {
        $tools = Join-Path (Split-Path $DashHtml.ModuleBase -Parent) 'Tools'
        $a11y = Join-Path $tools 'Test-DhA11y.ps1'; $contrast = Join-Path $tools 'Test-DhContrast.ps1'
        if (-not (Test-Path -LiteralPath $a11y)) {
            New-DhFinding 'Deep' 'info' $target "Skipped: the audits live in the Tools folder of a DashHtml checkout (not found at $tools)."
        } else {
            foreach ($r in @(& $a11y -Path $File.FullName -PassThru)) {
                New-DhFinding 'A11y' $(if ($r.Severity -eq 'error') { 'warning' } else { 'info' }) $target "$($r.Rule): $($r.Count) (e.g. $($r.Sample))"
            }
            if (Test-Path -LiteralPath $contrast) {
                foreach ($r in @(& $contrast -Path $File.FullName -PassThru)) {
                    New-DhFinding 'Contrast' 'warning' $target "$($r.Mode) $($r.Selector): $($r.Ratio):1, needs $($r.Min):1 ('$($r.Text)')"
                }
            }
        }
    }
}
