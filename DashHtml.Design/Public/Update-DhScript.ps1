function Update-DhScript {
    <#
    .SYNOPSIS
        Audit - and optionally rewrite - a DashHtml script for the 2.0.0 upgrade.

    .DESCRIPTION
        Parses each .ps1 with the PowerShell AST (it never executes them) and
        reports every call affected by the 2.0.0 changes. With -Apply it rewrites
        the file, writing a timestamped backup first.

        What it looks for:

          ACTION   -AllowHtml default flipped $true -> $false on Add-DhHtmlBlock,
                   Add-DhCollapsible, Add-DhAlertBanner and Add-DhTabs. A call
                   passing markup WITHOUT an explicit -AllowHtml renders that
                   markup as literal text in 2.0.0.
          advisory Add-DhTable -NavGroup: still works unchanged via the compat
                   shim (it maps to 'Group/TableId'). Reported so you can migrate
                   to -NavPath deliberately, never rewritten automatically.
          info     A block cmdlet with -NavSubGroup was UNREACHABLE in 1.x
                   (readme-dev gotcha #26) and starts rendering in 2.0.0.
                   Content may reappear; nothing to fix.

        The rewrite is deliberately conservative: it only ever ADDS
        -AllowHtml:$true to preserve the 1.x appearance, and only when the
        content is a literal string that actually looks like markup. It never
        removes a parameter, never touches nav, and never guesses at a
        non-literal -Content (a variable or expression) - those are reported as
        needing a human.

        AST parsing rather than text matching is not a stylistic choice: these
        calls routinely span several lines with backtick continuation, so a
        line-oriented pattern silently under-reports.

    .PARAMETER Path
        Files or directories to scan. Directories recurse. Default: current dir.

    .PARAMETER Apply
        Rewrite the files. Without it, nothing is modified.

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
        'Add-DhTopologyMap','Add-DhEventFeed','Add-DhTabs','Add-DhFilterCard','Add-DhAlertBanner'
    )
    # The content parameter differs per cmdlet; Add-DhTabs carries markup inside
    # its -Tabs hashtables, which is why it is treated as always-needs-review.
    $contentParam = @{
        'Add-DhHtmlBlock'   = 'Content'
        'Add-DhCollapsible' = 'Content'
        'Add-DhAlertBanner' = 'Message'
    }

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

        $srcLines = Get-Content -LiteralPath $f.FullName
        $edits    = [System.Collections.Generic.List[object]]::new()

        foreach ($c in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            $name = $c.GetCommandName()
            if (-not $name) { continue }
            $params = @($c.CommandElements |
                Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] } |
                ForEach-Object { $_.ParameterName })

            $issue = $null; $sev = 'ACTION'; $fix = $null

            if ($name -eq 'Add-DhTable' -and $params -contains 'NavGroup') {
                $issue = '15.1 table uses the v1 -NavGroup compat API'
                $sev   = 'advisory'
            }
            elseif ($name -in $blockCmds -and $params -contains 'NavSubGroup') {
                $issue = '15.3 block in a subgroup - invisible in 1.x, will now render'
                $sev   = 'info'
            }
            elseif ($name -in $htmlCmds -and $params -notcontains 'AllowHtml') {
                # Decide whether this call actually changes behaviour.
                # Add-DhTabs carries its markup inside the -Tabs hashtables, so a
                # missing top-level content parameter proves nothing there.
                $verdict = 'review'
                if ($contentParam.ContainsKey($name)) {
                    $pName = $contentParam[$name]
                    $val   = $null
                    $found = $false
                    for ($i = 0; $i -lt $c.CommandElements.Count; $i++) {
                        $el = $c.CommandElements[$i]
                        if ($el -is [System.Management.Automation.Language.CommandParameterAst] -and
                            $el.ParameterName -ieq $pName) {
                            $found = $true
                            if ($i + 1 -lt $c.CommandElements.Count) {
                                $next = $c.CommandElements[$i + 1]
                                if ($next -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
                                    $next -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                                    $val = $next.Value
                                }
                            }
                            break
                        }
                    }
                    if (-not $found) {
                        # No content parameter at all - e.g. Add-DhCollapsible -Cards,
                        # which is structured and never passes through the encoder.
                        # Flagging it would send the reader chasing a non-issue.
                        $verdict = 'plain'
                    }
                    elseif ($null -ne $val) {
                        $verdict = if ($val -match '<[a-zA-Z/!]') { 'markup' } else { 'plain' }
                    }
                }
                if ($verdict -eq 'plain') { continue }   # behaviour is unchanged

                $issue = if ($verdict -eq 'markup') {
                    '15.2 markup will be HTML-ENCODED by the new default'
                } else {
                    '15.2 -AllowHtml default flipped; content is not a literal - review by hand'
                }
                $sev = 'ACTION'
                if ($verdict -eq 'markup') {
                    # Insert immediately after the command name so we never have to
                    # reason about where the argument list ends.
                    $fix = @{ Offset = $c.CommandElements[0].Extent.EndOffset; Text = ' -AllowHtml:$true' }
                }
            }

            if (-not $issue) { continue }

            $rec = [pscustomobject]@{
                File      = $f.Name
                FullName  = $f.FullName
                Line      = $c.Extent.StartLineNumber
                Cmdlet    = $name
                Severity  = $sev
                Issue     = $issue
                Fixable   = [bool]$fix
                Source    = $srcLines[$c.Extent.StartLineNumber - 1].Trim()
            }
            $all.Add($rec)
            if ($fix) { $edits.Add($fix) }
        }

        # ---- rewrite ----
        if ($Apply -and $edits.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess($f.FullName, "Add -AllowHtml:`$true to $($edits.Count) call(s)")) {
                $root = Split-Path (Split-Path $f.FullName -Parent) -Parent
                $bkRoot = if ($BackupPath) { $BackupPath } else { Join-Path $root 'Backups' }
                New-Item -ItemType Directory -Path $bkRoot -Force | Out-Null
                $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
                $bk = Join-Path $bkRoot "$($f.BaseName).ps1.bak-$stamp"
                Copy-Item -LiteralPath $f.FullName -Destination $bk -Force

                # Apply back-to-front so earlier offsets stay valid.
                $text = [IO.File]::ReadAllText($f.FullName)
                foreach ($e in ($edits | Sort-Object -Property Offset -Descending)) {
                    $text = $text.Substring(0, $e.Offset) + $e.Text + $text.Substring($e.Offset)
                }
                [IO.File]::WriteAllText($f.FullName, $text)
                Write-Verbose "Update-DhScript: rewrote $($f.Name) ($($edits.Count) edit(s)); backup at $bk"
            }
        }
    }

    if ($PassThru) { return $all }

    if ($all.Count -eq 0) {
        Write-Host 'Update-DhScript: no 2.0.0 upgrade work found.' -ForegroundColor Green
        return
    }

    $all | Sort-Object Severity, File, Line | Format-Table File, Line, Cmdlet, Severity, Issue -AutoSize | Out-Host

    $action = @($all | Where-Object Severity -eq 'ACTION')
    Write-Host ''
    if ($action.Count) {
        Write-Host "ACTION REQUIRED: $($action.Count) call(s)" -ForegroundColor Yellow
        $auto = @($action | Where-Object Fixable)
        if ($auto.Count) {
            Write-Host ("  $($auto.Count) can be rewritten automatically" +
                        $(if ($Apply) { ' (applied)' } else { ' - re-run with -Apply' })) -ForegroundColor DarkGray
        }
        $manual = @($action | Where-Object { -not $_.Fixable })
        if ($manual.Count) {
            Write-Host "  $($manual.Count) need a human (content is not a literal string)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host 'ACTION REQUIRED: none - these scripts upgrade as-is.' -ForegroundColor Green
    }
    Write-Host ''
    Write-Host 'See readme-dev.md section 15 for the conversion tables.' -ForegroundColor DarkGray
}


