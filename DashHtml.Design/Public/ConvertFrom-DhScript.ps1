function ConvertFrom-DhScript {
    <#
    .SYNOPSIS
        Best-effort: derive a YAML layout spec from a .ps1 that uses DashHtml
        cmdlets, by static parsing (no execution).

    .DESCRIPTION
        Parses a PowerShell script's abstract syntax tree, finds the
        New-DhDashboard / Add-Dh* / Set-DhTableLink calls, and emits the
        equivalent YAML layout. LITERAL arguments (strings, numbers, booleans,
        constant arrays / hashtables) are captured faithfully; anything dynamic
        — a `-Data $rows`, a value built in a loop, a computed expression — is
        emitted as a clearly-marked  <expr: ...>  placeholder, because static
        analysis cannot know what it evaluates to.

        For a lossless view of a dynamic script, RUN it and pipe the resulting
        report object to ConvertTo-DhYaml instead — that captures everything.

        This tool does NOT execute the script.

    .PARAMETER Path      Path to the .ps1 script.
    .PARAMETER OutFile   Optional path to write the YAML. Else returns the string.

    .EXAMPLE
        ConvertFrom-DhScript -Path .\Examples\Demo-ActiveDirectory.ps1 -OutFile ad-layout.yaml
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [string] $OutFile
    )

    if (-not (Test-Path -LiteralPath $Path)) { throw "ConvertFrom-DhScript: file not found: $Path" }

    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $Path), [ref]$null, [ref]$errors)
    if ($errors) { throw "ConvertFrom-DhScript: '$Path' has parse errors; cannot analyse." }

    $reverse = @{
        'add-dhhtmlblock'='html'; 'add-dhcollapsible'='collapsible'; 'add-dhfiltercard'='filtercardgrid';
        'add-dhbarchart'='barchart'; 'add-dhpiechart'='piechart'; 'add-dhbullet'='bullet';
        'add-dhlinechart'='linechart'; 'add-dheventfeed'='eventfeed'; 'add-dhstatusgrid'='statusgrid';
        'add-dhtabs'='tabs'; 'add-dhheatmap'='heatmap'; 'add-dhtopologymap'='topologymap';
        'add-dhrangebar'='rangebar'
    }

    $commands = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)

    $model  = [ordered]@{}
    $tables = [System.Collections.Generic.List[object]]::new()
    $blocks = [System.Collections.Generic.List[object]]::new()
    $gfs    = [System.Collections.Generic.List[object]]::new()
    $alerts = [System.Collections.Generic.List[object]]::new()
    $links  = [System.Collections.Generic.List[object]]::new()

    foreach ($cmd in $commands) {
        $name = $cmd.GetCommandName()
        if (-not $name) { continue }
        $lname = $name.ToLower()
        if ($lname -ne 'new-dhdashboard' -and $lname -notlike 'add-dh*' -and $lname -ne 'set-dhtablelink') { continue }

        $params = Get-DhScriptParams $cmd

        switch ($lname) {
            'new-dhdashboard' {
                foreach ($k in $params.Keys) {
                    if ($k -ieq 'Report') { continue }
                    $model[(ConvertTo-DhLcFirst $k)] = $params[$k]
                }
            }
            'add-dhtable' {
                $t = [ordered]@{}
                foreach ($k in $params.Keys) {
                    if ($k -ieq 'Report') { continue }
                    if ($k -ieq 'TableId') { $t['id'] = $params[$k]; continue }
                    if ($k -ieq 'Data') {
                        $d = $params[$k]
                        if ($d -is [System.Collections.IEnumerable] -and $d -isnot [string]) { $t['dataRows'] = @($d).Count }
                        else { $t['dataSource'] = [string]$d }
                        continue
                    }
                    $t[$k] = $params[$k]
                }
                [void]$tables.Add($t)
            }
            'add-dhsummary' {
                $hasNav = $params.Keys | Where-Object { $_ -ieq 'NavGroup' } | ForEach-Object { $params[$_] } | Where-Object { $_ }
                if ($hasNav) {
                    $blk = [ordered]@{ type = 'summary' }
                    foreach ($k in $params.Keys) { if ($k -inotin @('Report')) { $blk[$k] = $params[$k] } }
                    [void]$blocks.Add($blk)
                } else {
                    $sum = [ordered]@{}
                    foreach ($k in $params.Keys) { if ($k -inotin @('Report')) { $sum[(ConvertTo-DhLcFirst $k)] = $params[$k] } }
                    $model['summary'] = $sum
                }
            }
            'add-dhglobalfilter'  { $gfs.Add((New-DhScriptItem $params))   | Out-Null }
            'add-dhalertbanner'   { $alerts.Add((New-DhScriptItem $params))| Out-Null }
            'set-dhtablelink'     { $links.Add((New-DhScriptItem $params)) | Out-Null }
            'export-dhdashboard'  { }
            default {
                $type = $reverse[$lname]
                if (-not $type) { break }
                $blk = [ordered]@{ type = $type }
                foreach ($k in $params.Keys) { if ($k -inotin @('Report')) { $blk[$k] = $params[$k] } }
                [void]$blocks.Add($blk)
            }
        }
    }

    if ($tables.Count) { $model['tables'] = $tables.ToArray() }
    if ($blocks.Count) { $model['blocks'] = $blocks.ToArray() }
    if ($gfs.Count)    { $model['globalFilters'] = $gfs.ToArray() }
    if ($alerts.Count) { $model['alertBanners']  = $alerts.ToArray() }
    if ($links.Count)  { $model['links']         = $links.ToArray() }

    $header = "# DashHtml layout — best-effort from $(Split-Path $Path -Leaf) (static parse).`n" +
              "# <expr: ...> markers are dynamic values a static parse can't resolve;`n" +
              "# run the script and pipe the report to ConvertTo-DhYaml for a lossless view.`n"
    $yaml = $header + (ConvertTo-DhYamlText $model)

    if ($OutFile) {
        Set-Content -Path $OutFile -Value $yaml -Encoding UTF8
        Write-Verbose "ConvertFrom-DhScript: wrote $OutFile"
    } else {
        $yaml
    }
}

function ConvertTo-DhLcFirst {
    param([string] $s)
    if ([string]::IsNullOrEmpty($s)) { return $s }
    return $s.Substring(0,1).ToLower() + $s.Substring(1)
}

function New-DhScriptItem {
    param([hashtable] $Params)
    $item = [ordered]@{}
    foreach ($k in $Params.Keys) { if ($k -inotin @('Report')) { $item[(ConvertTo-DhLcFirst $k)] = $Params[$k] } }
    return $item
}

function Get-DhScriptParams {
    <# Extract a {ParamName -> value} map from a CommandAst. Literal values are
       resolved via SafeGetValue; non-literals become '<expr: ...>' strings. #>
    param([System.Management.Automation.Language.CommandAst] $Cmd)
    $out = @{}
    $els = $Cmd.CommandElements
    $i = 1
    while ($i -lt $els.Count) {
        $el = $els[$i]
        if ($el -is [System.Management.Automation.Language.CommandParameterAst]) {
            $pname = $el.ParameterName
            if ($null -ne $el.Argument) {
                $out[$pname] = Resolve-DhAstValue $el.Argument
                $i++
            }
            elseif (($i + 1) -lt $els.Count -and -not ($els[$i + 1] -is [System.Management.Automation.Language.CommandParameterAst])) {
                $out[$pname] = Resolve-DhAstValue $els[$i + 1]
                $i += 2
            }
            else { $out[$pname] = $true; $i++ }   # switch
        }
        else { $i++ }   # positional argument — skipped (best-effort)
    }
    return $out
}

function Resolve-DhAstValue {
    param([System.Management.Automation.Language.Ast] $Ast)
    try {
        $v = $Ast.SafeGetValue()
        return $v
    } catch {
        return "<expr: $($Ast.Extent.Text)>"
    }
}
