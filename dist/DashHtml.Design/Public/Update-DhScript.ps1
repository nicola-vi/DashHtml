function Update-DhScript {
    <#
    .SYNOPSIS
        Audit - and optionally rewrite - a DashHtml script for the 3.0.0 upgrade.

    .DESCRIPTION
        Parses each .ps1 with the PowerShell AST (it never executes them) and
        reports every call affected by a breaking change. With -Apply it rewrites
        the file, writing a timestamped backup first. It is idempotent: a
        rewritten script reports nothing.

        What it looks for:

          ACTION   -NavGroup / -NavSubGroup (removed in 3.0.0) on any nav-aware
                   cmdlet. Rewritten to -NavPath with the mapping the 2.x compat
                   shim applied, so the menu is unchanged:
                     table  -NavGroup 'G' [-NavSubGroup 'S']  -> -NavPath 'G[/S]/<TableId>'
                     block  -NavGroup 'G' [-NavSubGroup 'S']  -> -NavPath 'G[/S]' -NavScope Subtree
                   (an explicit -NavScope is kept). A value that is not a literal
                   string (a variable or expression) is reported for a human.
          ACTION   A 'Bands' key in a script that calls Add-DhBullet (removed in
                   3.0.0): renamed to 'Thresholds', which has the same shape.
          ACTION   -AllowHtml (2.0.0 default flip $true -> $false) on
                   Add-DhHtmlBlock, Add-DhCollapsible, Add-DhAlertBanner and
                   Add-DhTabs: a call passing literal markup WITHOUT an explicit
                   -AllowHtml renders it as text. Rewritten by adding
                   -AllowHtml:$true; non-literal content is reported for a human.
                   Only scripts written for 1.x hit this.

        AST parsing rather than text matching is not a stylistic choice: these
        calls routinely span several lines with backtick continuation, so a
        line-oriented pattern silently under-reports.

    .PARAMETER Path
        Files or directories to scan. Directories recurse. Default: current dir.

    .PARAMETER Apply
        Rewrite the files. Without it, nothing is modified. A rewritten file is
        parsed again; if it no longer parses, the backup is restored.

    .PARAMETER BackupPath
        Directory for backups when -Apply is used. Default: '<repo>\Backups'.

    .PARAMETER PassThru
        Emit the finding objects instead of a formatted report.

    .EXAMPLE
        Update-DhScript -Path .\Examples

    .EXAMPLE
        Update-DhScript -Path .\Examples -Apply

    .EXAMPLE
        Update-DhScript -Path C:\Scripts -PassThru | Where-Object Severity -eq 'ACTION'
    #>
    # Write-Host is deliberate here: this cmdlet's product IS a console report
    # for a human running an upgrade. Its machine-readable output goes through
    # -PassThru, which emits objects to the pipeline as normal.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive upgrade report; structured output is available via -PassThru.')]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]] $Path = @('.'),
        [switch]   $Apply,
        [string]   $BackupPath = '',
        [switch]   $PassThru
    )

    $htmlCmds = @('Add-DhHtmlBlock','Add-DhCollapsible','Add-DhAlertBanner','Add-DhTabs')
    $blockCmds = @(
        'Add-DhBarChart','Add-DhPieChart','Add-DhLineChart','Add-DhBullet','Add-DhSummary',
        'Add-DhHtmlBlock','Add-DhCollapsible','Add-DhStatusGrid','Add-DhHeatmap',
        'Add-DhTopologyMap','Add-DhEventFeed','Add-DhTabs','Add-DhFilterCard','Add-DhAlertBanner',
        'Add-DhRangeBar',  # v2.1.4 - missed when Add-DhRangeBar shipped in 2.1.0
        'Add-DhFindings',  # DashHtml 2.2.0
        'Add-DhKeyValue','Add-DhRecordList',   # DashHtml 2.3.0
        'Add-DhTreeFilter','Add-DhNetworkMap',   # DashHtml 2.4.0
        'Add-DhTreeTable',  # DashHtml 2.5.0
        'Add-DhGantt'       # DashHtml 3.1.0
    )
    # The content parameter differs per cmdlet; Add-DhTabs carries markup inside
    # its -Tabs hashtables, which is why it is treated as always-needs-review.
    $contentParam = @{
        'Add-DhHtmlBlock'   = 'Content'
        'Add-DhCollapsible' = 'Content'
        'Add-DhAlertBanner' = 'Message'
    }

    # A parameter of a command: its value (literal string or $null), whether the
    # value is a literal, and the extent to replace (the parameter AND its value).
    function Get-DhCallParam {
        param($Command, [string] $Name)
        $els = $Command.CommandElements
        for ($i = 0; $i -lt $els.Count; $i++) {
            $el = $els[$i]
            if ($el -isnot [System.Management.Automation.Language.CommandParameterAst] -or $el.ParameterName -ine $Name) { continue }
            $arg = $el.Argument; $end = $el.Extent.EndOffset
            if (-not $arg -and $i + 1 -lt $els.Count -and $els[$i + 1] -isnot [System.Management.Automation.Language.CommandParameterAst]) {
                $arg = $els[$i + 1]; $end = $arg.Extent.EndOffset
            }
            $isLit = $arg -is [System.Management.Automation.Language.StringConstantExpressionAst]
            # Start of the removable span: the end of the element before it, so a
            # parameter on its own backtick-continued line goes with its line break.
            $prevEnd = if ($i -gt 0) { $els[$i - 1].Extent.EndOffset } else { $el.Extent.StartOffset }
            return [pscustomobject]@{
                Value = if ($isLit) { [string]$arg.Value } else { $null }
                IsLiteral = $isLit
                Start = $el.Extent.StartOffset; End = $end; PrevEnd = $prevEnd
            }
        }
        return $null
    }
    function ConvertTo-DhSq([string] $s) { "'" + $s.Replace("'", "''") + "'" }
    function ConvertTo-DhSeg([string] $s) { $s.Trim().Replace('/', '//') }

    $files = foreach ($p in $Path) {
        if (Test-Path -LiteralPath $p -PathType Container) { Get-ChildItem -LiteralPath $p -Filter *.ps1 -Recurse -File }
        elseif (Test-Path -LiteralPath $p)                 { Get-Item -LiteralPath $p }
        else { Write-Warning "Update-DhScript: not found: $p" }
    }

    $all = [System.Collections.Generic.List[object]]::new()

    foreach ($f in $files) {
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$parseErrors)
        if ($parseErrors) {
            Write-Warning "Update-DhScript: $($f.Name) has $($parseErrors.Count) parse error(s) - skipped."
            continue
        }

        $srcLines = @(Get-Content -LiteralPath $f.FullName)   # 2.6.0 - @(): a one-line file is a string, and [0] would be its first character
        # Each edit replaces Length characters at Offset with Text (Length 0 = insert).
        $edits    = [System.Collections.Generic.List[object]]::new()
        $addRec = {
            param($Ast, [string] $Cmdlet, [string] $Issue, [bool] $Fixable)
            $all.Add([pscustomobject]@{
                File      = $f.Name
                FullName  = $f.FullName
                Line      = $Ast.Extent.StartLineNumber
                Cmdlet    = $Cmdlet
                Severity  = 'ACTION'
                Issue     = $Issue
                Fixable   = $Fixable
                Source    = $srcLines[$Ast.Extent.StartLineNumber - 1].Trim()
            })
        }

        $commands = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true))
        foreach ($c in $commands) {
            $name = $c.GetCommandName()
            if (-not $name) { continue }
            $params = @($c.CommandElements |
                Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] } |
                ForEach-Object { $_.ParameterName })

            # ---- 3.0.0: -NavGroup / -NavSubGroup removed ----
            if (($name -eq 'Add-DhTable' -or $name -in $blockCmds) -and
                ($params -contains 'NavGroup' -or $params -contains 'NavSubGroup')) {
                $g  = Get-DhCallParam $c 'NavGroup'
                $sg = Get-DhCallParam $c 'NavSubGroup'
                $tid = if ($name -eq 'Add-DhTable') { Get-DhCallParam $c 'TableId' } else { $null }
                $why = $null
                if (-not $g)                                        { $why = '-NavSubGroup without -NavGroup' }
                elseif ($params -contains 'NavPath')                { $why = 'also has -NavPath' }
                elseif (-not $g.IsLiteral -or ($sg -and -not $sg.IsLiteral)) { $why = 'the value is not a literal string' }
                elseif ($name -eq 'Add-DhTable' -and -not ($tid -and $tid.IsLiteral)) { $why = '-TableId is not a literal string' }

                if ($why) {
                    & $addRec $c $name "15.1 -NavGroup/-NavSubGroup removed in 3.0.0; $why - convert to -NavPath by hand" $false
                } else {
                    $segs = @(ConvertTo-DhSeg $g.Value)
                    if ($sg -and $sg.Value) { $segs += ConvertTo-DhSeg $sg.Value }
                    if ($name -eq 'Add-DhTable') { $segs += ConvertTo-DhSeg $tid.Value }
                    $text = '-NavPath ' + (ConvertTo-DhSq ($segs -join '/'))
                    if ($name -ne 'Add-DhTable' -and $params -notcontains 'NavScope') { $text += ' -NavScope Subtree' }
                    $edits.Add(@{ Offset = $g.Start; Length = $g.End - $g.Start; Text = $text })
                    if ($sg) { $edits.Add(@{ Offset = $sg.PrevEnd; Length = $sg.End - $sg.PrevEnd; Text = '' }) }
                    & $addRec $c $name "15.1 -NavGroup/-NavSubGroup removed in 3.0.0 -> $text" $true
                }
            }

            # ---- 2.0.0: -AllowHtml default flipped (1.x scripts) ----
            if ($name -in $htmlCmds -and $params -notcontains 'AllowHtml') {
                # Decide whether this call actually changes behaviour.
                # Add-DhTabs carries its markup inside the -Tabs hashtables, so a
                # missing top-level content parameter proves nothing there.
                $verdict = 'review'
                if ($contentParam.ContainsKey($name)) {
                    $cp = Get-DhCallParam $c $contentParam[$name]
                    if (-not $cp) {
                        # No content parameter at all - e.g. Add-DhCollapsible -Cards,
                        # which is structured and never passes through the encoder.
                        $verdict = 'plain'
                    } elseif ($cp.IsLiteral) {
                        $verdict = if ($cp.Value -match '<[a-zA-Z/!]') { 'markup' } else { 'plain' }
                    }
                }
                if ($verdict -ne 'plain') {
                    if ($verdict -eq 'markup') {
                        # Insert immediately after the command name so we never have to
                        # reason about where the argument list ends.
                        $edits.Add(@{ Offset = $c.CommandElements[0].Extent.EndOffset; Length = 0; Text = ' -AllowHtml:$true' })
                        & $addRec $c $name '15.2 markup will be HTML-ENCODED by the 2.0 default' $true
                    } else {
                        & $addRec $c $name '15.2 -AllowHtml default is $false; content is not a literal - review by hand' $false
                    }
                }
            }
        }

        # ---- 3.0.0: Add-DhBullet 'Bands' key removed ----
        if (@($commands | Where-Object { $_.GetCommandName() -eq 'Add-DhBullet' }).Count) {
            foreach ($h in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.HashtableAst] }, $true)) {
                foreach ($kv in $h.KeyValuePairs) {
                    $k = $kv.Item1
                    if ($k -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $k.Value -ieq 'Bands') {
                        $edits.Add(@{ Offset = $k.Extent.StartOffset; Length = $k.Extent.EndOffset - $k.Extent.StartOffset; Text = 'Thresholds' })
                        & $addRec $k 'Add-DhBullet' "15.3 'Bands' key removed in 3.0.0 -> Thresholds" $true
                    }
                }
            }
        }

        # ---- rewrite ----
        if ($Apply -and $edits.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess($f.FullName, "Apply $($edits.Count) upgrade edit(s)")) {
                $root = Split-Path (Split-Path $f.FullName -Parent) -Parent
                $bkRoot = if ($BackupPath) { $BackupPath } else { Join-Path $root 'Backups' }
                New-Item -ItemType Directory -Path $bkRoot -Force | Out-Null
                $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
                $bk = Join-Path $bkRoot "$($f.BaseName).ps1.bak-$stamp"
                Copy-Item -LiteralPath $f.FullName -Destination $bk -Force

                # Apply back-to-front so earlier offsets stay valid. The AST offsets
                # count characters of the text the parser read, BOM excluded, which
                # is what ReadAllText returns too.
                $text = [IO.File]::ReadAllText($f.FullName)
                foreach ($e in ($edits | Sort-Object -Property Offset -Descending)) {
                    $text = $text.Substring(0, $e.Offset) + $e.Text + $text.Substring($e.Offset + $e.Length)
                }
                $enc = if ([IO.File]::ReadAllBytes($f.FullName)[0..2] -join ',' -eq '239,187,191') { [Text.UTF8Encoding]::new($true) } else { [Text.UTF8Encoding]::new($false) }
                [IO.File]::WriteAllText($f.FullName, $text, $enc)
                $reErrors = $null
                $null = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$reErrors)
                if ($reErrors) {
                    Copy-Item -LiteralPath $bk -Destination $f.FullName -Force
                    Write-Warning "Update-DhScript: the rewrite of $($f.Name) did not parse ($($reErrors[0].Message)); the original was restored. Convert it by hand."
                } else {
                    Write-Verbose "Update-DhScript: rewrote $($f.Name) ($($edits.Count) edit(s)); backup at $bk"
                }
            }
        }
    }

    if ($PassThru) { return $all }

    if ($all.Count -eq 0) {
        Write-Host 'Update-DhScript: no upgrade work found.' -ForegroundColor Green
        return
    }

    $all | Sort-Object File, Line | Format-Table File, Line, Cmdlet, Severity, Issue -AutoSize | Out-Host

    Write-Host ''
    Write-Host "ACTION REQUIRED: $($all.Count) item(s)" -ForegroundColor Yellow
    $auto = @($all | Where-Object Fixable)
    if ($auto.Count) {
        Write-Host ("  $($auto.Count) can be rewritten automatically" +
                    $(if ($Apply) { ' (applied)' } else { ' - re-run with -Apply' })) -ForegroundColor DarkGray
    }
    $manual = @($all | Where-Object { -not $_.Fixable })
    if ($manual.Count) {
        Write-Host "  $($manual.Count) need a human (a value that is not a literal string)" -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host 'See readme-dev.md section 15 for the conversion tables.' -ForegroundColor DarkGray
}
