#Requires -Version 7.0
<#
.SYNOPSIS
    Generates DashHtml-Reference.html from the module's Public PS1 source files.

.DESCRIPTION
    Imports DashHtml from source, extracts all comment-based help via Get-Help,
    reads parameter signatures via Get-Command, and parses default values directly
    from the PS1 files. Produces a self-contained HTML reference document that
    matches the DashHtml visual style.

    Re-run whenever you change any Public/*.ps1 file to keep the reference in sync.

.PARAMETER OutputPath
    Path for the output HTML file.
    Default: <script-dir>\DashHtml-Reference.html

.PARAMETER SourceRoot
    Project root containing the DashHtml\ folder.
    Default: the directory that contains this script.

.PARAMETER Open
    Open the generated file in the default browser after writing.

.EXAMPLE
    .\Build-DhReference.ps1

.EXAMPLE
    .\Build-DhReference.ps1 -Open

.EXAMPLE
    .\Build-DhReference.ps1 -OutputPath 'C:\Docs\DashHtml-Reference.html' -Open
#>
[CmdletBinding()]
param(
    [string] $OutputPath = '',
    [string] $SourceRoot = '',
    [switch] $Open
)

$ErrorActionPreference = 'Stop'

# ── Resolve paths ─────────────────────────────────────────────────────────────
$root      = if ($SourceRoot) { $SourceRoot } else { $PSScriptRoot }
$outFile   = if ($OutputPath) { $OutputPath } else { Join-Path $root 'DashHtml-Reference.html' }
$modSource = Join-Path $root 'DashHtml'
$pubFolder = Join-Path $modSource 'Public'

if (-not (Test-Path $pubFolder)) {
    throw "Public folder not found at: $pubFolder"
}

# Read version from manifest
$version = '?.?.?'
$psd1 = Join-Path $modSource 'DashHtml.psd1'
if (Test-Path $psd1) {
    if ((Get-Content $psd1 -Raw) -match "ModuleVersion\s*=\s*'([^']+)'") {
        $version = $Matches[1]
    }
}

Write-Host "DashHtml Reference Builder" -ForegroundColor Cyan
Write-Host "  Version : $version" -ForegroundColor DarkGray
Write-Host "  Source  : $modSource" -ForegroundColor DarkGray
Write-Host "  Output  : $outFile" -ForegroundColor DarkGray
Write-Host ''

# ── Import module from source (force fresh load) ──────────────────────────────
if (Get-Module DashHtml) { Remove-Module DashHtml -Force }
Import-Module $modSource -Force
Write-Host "  Module imported" -ForegroundColor DarkGray

# ── Cmdlet ordering and metadata ──────────────────────────────────────────────
$cmdMeta = [ordered]@{
    'New-DhDashboard'    = @{ Tag = 'INIT';   Color = '#79c0ff'; Group = 'Foundation'     }
    'Export-DhDashboard' = @{ Tag = 'OUT';    Color = '#ffa657'; Group = 'Foundation'     }
    'Get-DhTheme'        = @{ Tag = 'UTIL';   Color = '#ffa657'; Group = 'Foundation'     }
    'Add-DhTable'        = @{ Tag = 'TABLE';  Color = '#d2a8ff'; Group = 'Content Blocks' }
    'Add-DhSummary'      = @{ Tag = 'KPI';    Color = '#d2a8ff'; Group = 'Content Blocks' }
    'Add-DhBarChart'     = @{ Tag = 'CHART';  Color = '#d2a8ff'; Group = 'Content Blocks' }
    'Add-DhFilterCard'   = @{ Tag = 'FILTER'; Color = '#d2a8ff'; Group = 'Content Blocks' }
    'Add-DhHtmlBlock'    = @{ Tag = 'HTML';   Color = '#d2a8ff'; Group = 'Content Blocks' }
    'Add-DhCollapsible'  = @{ Tag = 'COLL';   Color = '#d2a8ff'; Group = 'Content Blocks' }
    'Set-DhTableLink'    = @{ Tag = 'LINK';   Color = '#3fb950'; Group = 'Linking'        }
}

# Common parameters that PowerShell injects — skip them in the docs
$skipParams = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@('Verbose','Debug','ErrorAction','WarningAction','InformationAction',
                'ErrorVariable','WarningVariable','InformationVariable','OutVariable',
                'OutBuffer','PipelineVariable','ProgressAction','WhatIf','Confirm'),
    [System.StringComparer]::OrdinalIgnoreCase
)

# ── HELPER FUNCTIONS ──────────────────────────────────────────────────────────

function esc([string] $s) {
    [System.Net.WebUtility]::HtmlEncode($s)
}

# Shorten .NET type names for display
function Simplify-TypeName([string] $name) {
    $name = $name -replace 'System\.Collections\.Specialized\.', ''
    $name = $name -replace 'System\.Collections\.Generic\.', ''
    $name = $name -replace 'System\.Management\.Automation\.', ''
    $name -replace 'SwitchParameter', 'switch'
}

# Extract default values from raw PS1 source via regex.
# Get-Command does not expose default values; Get-Help shows "None" for most.
function Get-ParamDefaults([string] $filePath) {
    $src      = Get-Content $filePath -Raw
    $defaults = @{}
    # Match:  [type] $Name = value   OR   [type] $Name = value  # comment
    # The value ends at a comma, newline, or inline comment
    $rx = [regex]'(?m)^\s+\[[^\]]+\]\s+\$([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^,\r\n#]+)'
    foreach ($m in $rx.Matches($src)) {
        $defaults[$m.Groups[1].Value] = $m.Groups[2].Value.Trim().TrimEnd(',').Trim()
    }
    return $defaults
}

# Encode a code string for safe embedding in HTML.
# Syntax highlighting is applied client-side by the JS tokenizer in the generated page,
# so the server side only needs to HTML-encode the raw text.
function Highlight-PS([string] $raw) {
    if (-not $raw) { return '' }
    [System.Net.WebUtility]::HtmlEncode($raw)
}

# Render a description string to HTML.
# Lines indented ≥ 6 spaces that contain code-like tokens are wrapped in <pre>.
# Everything else becomes <p> paragraphs (split on blank lines).
function Format-Desc([string] $text) {
    if (-not $text -or -not $text.Trim()) {
        return '<em style="color:var(--text3)">No description.</em>'
    }
    $lines = ($text.Trim()) -split "`r?`n"

    # Detect whether description contains embedded code blocks
    $codePattern = [regex]'^\s{6,}.*(?:=|\$|@\{|\[|#\s*\w)'
    $hasCode     = $lines | Where-Object { $codePattern.IsMatch($_) }

    if (-not $hasCode) {
        # Simple text: split on blank lines → <p> tags
        $paras = ($text.Trim()) -split '(?:\r?\n){2,}'
        return ($paras | ForEach-Object {
            $p = $_.Trim() -replace '`r?`n', ' '
            if ($p) { "<p>$(esc $p)</p>" }
        }) -join ''
    }

    # Mixed text + code: process line by line
    $html    = [System.Text.StringBuilder]::new()
    $inPre   = $false
    $textBuf = [System.Text.StringBuilder]::new()

    $flushText = {
        $t = $textBuf.ToString().Trim()
        if ($t) {
            $paras = $t -split '(?:\r?\n){2,}'
            foreach ($p in $paras) {
                $pt = $p.Trim()
                if ($pt) { [void]$html.Append("<p>$(esc $pt)</p>") }
            }
        }
        $textBuf.Clear() | Out-Null
    }

    foreach ($line in $lines) {
        if ($codePattern.IsMatch($line)) {
            if (-not $inPre) {
                & $flushText
                [void]$html.Append('<pre class="desc-code">')
                $inPre = $true
            }
            # Reduce indentation by 6 for display
            [void]$html.AppendLine([System.Net.WebUtility]::HtmlEncode(($line -replace '^\s{6}', '')))
        } else {
            if ($inPre) {
                [void]$html.Append('</pre>')
                $inPre = $false
            }
            [void]$textBuf.AppendLine($line)
        }
    }

    if ($inPre) { [void]$html.Append('</pre>') }
    & $flushText

    return $html.ToString()
}

# Build the full <section> HTML for one cmdlet
function Build-CmdletSection {
    param([string] $cmdletName, [hashtable] $meta)

    Write-Host "  $cmdletName" -ForegroundColor DarkGray

    $help = Get-Help $cmdletName -Full -ErrorAction SilentlyContinue
    $cmd  = Get-Command $cmdletName

    # Default values from source file
    $srcFile  = Join-Path $pubFolder "$cmdletName.ps1"
    $defaults = if (Test-Path $srcFile) { Get-ParamDefaults $srcFile } else { @{} }

    # Helper: safely read a nullable property from the Get-Help object
    $getProp = { param($obj, $prop)
        try { $obj.PSObject.Properties[$prop]?.Value } catch { $null }
    }

    # ── Synopsis ──────────────────────────────────────────────────────────────
    $synopsis = try { if ($help.Synopsis) { $help.Synopsis.Trim() } else { '' } } catch { '' }

    # ── Description ───────────────────────────────────────────────────────────
    $descProp = try { $help.PSObject.Properties['description']?.Value } catch { $null }
    $descText = if ($descProp) {
        ($descProp | ForEach-Object { $_.Text }) -join "`n"
    } else { '' }

    # ── Parameters ─────────────────────────────────────────────────────────────
    # Build a lookup of help descriptions keyed by parameter name
    $helpParamDesc = @{}
    $paramsProp = try { $help.PSObject.Properties['parameters']?.Value } catch { $null }
    $helpParamList = if ($paramsProp) {
        try { $paramsProp.PSObject.Properties['parameter']?.Value } catch { $null }
    }
    if ($helpParamList) {
        foreach ($p in @($helpParamList)) {
            $pDesc = try {
                $dProp = $p.PSObject.Properties['description']?.Value
                if ($dProp) { ($dProp | ForEach-Object { $_.Text }) -join "`n" } else { '' }
            } catch { '' }
            $helpParamDesc[$p.name] = $pDesc
        }
    }

    $cmdParams  = $cmd.Parameters
    $paramNames = @($cmdParams.Keys | Where-Object { -not $skipParams.Contains($_) })

    # Sort: mandatory first, then optional — both groups preserve original order
    $mandatory = $paramNames | Where-Object {
        $pm = $cmdParams[$_]
        [bool]($pm.ParameterSets.Values | Where-Object { $_.IsMandatory } | Select-Object -First 1)
    }
    $optional = $paramNames | Where-Object {
        $pm = $cmdParams[$_]
        -not [bool]($pm.ParameterSets.Values | Where-Object { $_.IsMandatory } | Select-Object -First 1)
    }
    $orderedParams = @($mandatory) + @($optional)

    # ── Syntax block ──────────────────────────────────────────────────────────
    $synLines = [System.Text.StringBuilder]::new()
    [void]$synLines.Append("<span class='hl-cmd'>$cmdletName</span>")
    foreach ($pName in $orderedParams) {
        $pm       = $cmdParams[$pName]
        $typeName = esc (Simplify-TypeName $pm.ParameterType.Name)
        $isReq    = [bool]($pm.ParameterSets.Values | Where-Object { $_.IsMandatory } | Select-Object -First 1)
        $isSwitch = $pm.ParameterType.Name -eq 'SwitchParameter'
        $pHtml    = "<span class='hl-param'>-$pName</span>"
        $tHtml    = if (-not $isSwitch) { " <span class='hl-type'>&lt;$typeName&gt;</span>" } else { '' }

        if ($isReq) {
            [void]$synLines.Append("`n    $pHtml$tHtml")
        } else {
            [void]$synLines.Append("`n   [<span class='hl-opt'>$pHtml$tHtml</span>]")
        }
    }

    # ── Parameter table rows ───────────────────────────────────────────────────
    $paramRows = [System.Text.StringBuilder]::new()
    foreach ($pName in $orderedParams) {
        $pm       = $cmdParams[$pName]
        $typeName = esc (Simplify-TypeName $pm.ParameterType.Name)
        $isReq    = [bool]($pm.ParameterSets.Values | Where-Object { $_.IsMandatory } | Select-Object -First 1)
        $defVal   = if ($defaults.ContainsKey($pName)) { $defaults[$pName] } else { '' }
        $descHtml = if ($helpParamDesc.ContainsKey($pName)) { Format-Desc $helpParamDesc[$pName] } else { '' }
        $reqBadge = if ($isReq) { '<span class="param-req req-yes">required</span>' } `
                                else { '<span class="param-req req-no">optional</span>' }
        $defHtml  = if ($defVal) { "<span class='param-default'>default: $(esc $defVal)</span>" } else { '' }

        [void]$paramRows.Append(@"
        <tr>
          <td><span class="param-name">-$pName</span></td>
          <td><span class="param-type">&lt;$typeName&gt;</span></td>
          <td>$reqBadge</td>
          <td class="param-desc">$descHtml$defHtml</td>
        </tr>
"@)
    }

    # ── Examples ──────────────────────────────────────────────────────────────
    $examplesHtml = [System.Text.StringBuilder]::new()
    $exProp  = try { $help.PSObject.Properties['examples']?.Value } catch { $null }
    $exList  = if ($exProp) { try { $exProp.PSObject.Properties['example']?.Value } catch { $null } }
    if ($exList) {
        $exIdx = 0
        foreach ($ex in @($exList)) {
            $exIdx++
            $exCode = $ex.code.Trim()

            # Extract leading comment line as title, remove it from code
            $exTitle = "Example $exIdx"
            if ($exCode -match '(?s)^\s*#\s*(.+?)[\r\n]') {
                $exTitle = $Matches[1].Trim()
                $exCode  = ($exCode -replace '(?s)^\s*#[^\r\n]*[\r\n]+', '').Trim()
            }

            [void]$examplesHtml.Append(@"
      <div class="example-block">
        <div class="example-header">
          <span class="example-label">EXAMPLE $exIdx</span>
          <span class="example-title">$(esc $exTitle)</span>
          <button class="copy-btn" title="Copy to clipboard">Copy</button>
        </div>
        <div class="example-code">$(Highlight-PS $exCode)</div>
      </div>
"@)
        }
    }

    # ── Tag badge ─────────────────────────────────────────────────────────────
    $tagColor = switch ($meta.Color) {
        '#79c0ff' { 'blue'   }
        '#3fb950' { 'green'  }
        '#ffa657' { 'orange' }
        default   { 'purple' }
    }

    # ── Assemble section ──────────────────────────────────────────────────────
    $descBlockHtml = if ($descText) {
        "<div class='desc-block'>$(Format-Desc $descText)</div>"
    } else { '' }

    $paramTableHtml = ''
    if ($paramRows.Length -gt 0) {
        $paramTableHtml = @"
      <div class="syntax-label">Parameters</div>
      <table class="params-table">
        <thead><tr>
          <th>Parameter</th><th>Type</th><th>Required</th><th>Description</th>
        </tr></thead>
        <tbody>
$($paramRows.ToString())
        </tbody>
      </table>
"@
    }

    $exSectionHtml = ''
    if ($examplesHtml.Length -gt 0) {
        $exSectionHtml = @"
      <div class="syntax-label">Examples</div>
$($examplesHtml.ToString())
"@
    }

    return @"
  <!-- ═══ $cmdletName ═══ -->
  <section class="cmd-section" id="$cmdletName">
    <div class="cmd-header">
      <div class="cmd-icon" style="background:color-mix(in srgb,$($meta.Color) 15%,var(--bg3))">
        <span style="color:$($meta.Color);font-size:11px;font-weight:700;font-family:var(--font-mono)">$($meta.Tag)</span>
      </div>
      <div style="flex:1;min-width:0">
        <div class="cmd-name" style="color:$($meta.Color)">$cmdletName</div>
        <div class="cmd-synopsis">$(esc $synopsis)</div>
      </div>
      <span class="cmd-tag badge-$tagColor">$($meta.Tag)</span>
    </div>

    $descBlockHtml

    <div class="syntax-label">Syntax</div>
    <div class="syntax-block">$($synLines.ToString())</div>

    $paramTableHtml
    $exSectionHtml
  </section>
  <hr class="section-rule">

"@
}

# ── BUILD ALL SECTIONS ────────────────────────────────────────────────────────
Write-Host ''
Write-Host "  Generating sections..." -ForegroundColor Cyan

$allSections    = [System.Text.StringBuilder]::new()
$sidebarGroups  = [ordered]@{}  # group label → list of cmdlet names

foreach ($cmdName in $cmdMeta.Keys) {
    $meta  = $cmdMeta[$cmdName]
    $group = $meta.Group
    if (-not $sidebarGroups.Contains($group)) {
        $sidebarGroups[$group] = [System.Collections.Generic.List[string]]::new()
    }
    $sidebarGroups[$group].Add($cmdName)
    [void]$allSections.Append((Build-CmdletSection -cmdletName $cmdName -meta $meta))
}

# ── BUILD SIDEBAR NAV ─────────────────────────────────────────────────────────
$sidebarNavHtml = [System.Text.StringBuilder]::new()
foreach ($group in $sidebarGroups.Keys) {
    [void]$sidebarNavHtml.Append("  <div class=`"nav-section-label`">$group</div>`n")
    foreach ($cn in $sidebarGroups[$group]) {
        $m   = $cmdMeta[$cn]
        [void]$sidebarNavHtml.Append(
            "  <a class=`"nav-item`" href=`"#$cn`"><span class=`"nav-dot`" style=`"background:$($m.Color)`"></span>$cn <span class=`"nav-tag`">$($m.Tag)</span></a>`n"
        )
    }
}
[void]$sidebarNavHtml.Append("  <div class=`"nav-section-label`">Reference</div>`n")
[void]$sidebarNavHtml.Append("  <a class=`"nav-item`" href=`"#ref-formats`"><span class=`"nav-dot`"></span>Format values</a>`n")
[void]$sidebarNavHtml.Append("  <a class=`"nav-item`" href=`"#ref-thresholds`"><span class=`"nav-dot`"></span>Threshold classes</a>`n")
[void]$sidebarNavHtml.Append("  <a class=`"nav-item`" href=`"#ref-themes`"><span class=`"nav-dot`"></span>Theme families</a>`n")
[void]$sidebarNavHtml.Append("  <div class=`"nav-section-label`">Guide</div>`n")
[void]$sidebarNavHtml.Append("  <a class=`"nav-item`" href=`"#guide-readme`"><span class=`"nav-dot`"></span>README</a>`n")

# ── QUICK REFERENCE GRID ──────────────────────────────────────────────────────
$qrGridHtml = [System.Text.StringBuilder]::new()
foreach ($cn in $cmdMeta.Keys) {
    $m       = $cmdMeta[$cn]
    $synopsis = (Get-Help $cn -ErrorAction SilentlyContinue).Synopsis
    if ($synopsis) { $synopsis = $synopsis.Trim() }
    [void]$qrGridHtml.Append(@"
    <a class="qr-card" href="#$cn">
      <div class="qr-cmd-name" style="color:$($m.Color)">$cn</div>
      <div class="qr-cmd-desc">$(esc $synopsis)</div>
    </a>
"@)
}

# ── STATIC REFERENCE SECTIONS ─────────────────────────────────────────────────
$refSections = @'
  <!-- ═══ Format values ═══ -->
  <section class="cmd-section" id="ref-formats">
    <div class="cmd-header">
      <div class="cmd-icon" style="background:color-mix(in srgb,#58a6ff 15%,var(--bg3))">
        <span style="color:#58a6ff;font-size:11px;font-weight:700;font-family:var(--font-mono)">FMT</span>
      </div>
      <div>
        <div class="cmd-name" style="color:#58a6ff">Format values</div>
        <div class="cmd-synopsis">Column Format= values used with Add-DhTable -Columns</div>
      </div>
    </div>
    <table class="params-table">
      <thead><tr><th>Value</th><th>Description</th><th>Example output</th></tr></thead>
      <tbody>
        <tr><td><span class="param-name">text</span></td><td class="param-desc"><p>Default — raw string value</p></td><td><span class="param-type">Hello</span></td></tr>
        <tr><td><span class="param-name">number</span></td><td class="param-desc"><p>Locale-aware integer / decimal. Use Decimals= and Locale=</p></td><td><span class="param-type">12,345.20</span></td></tr>
        <tr><td><span class="param-name">currency</span></td><td class="param-desc"><p>Locale currency symbol. Use Currency= (default EUR) and Decimals=</p></td><td><span class="param-type">$1,234.50</span></td></tr>
        <tr><td><span class="param-name">bytes</span></td><td class="param-desc"><p>Auto-scale B / KB / MB / GB / TB / PB</p></td><td><span class="param-type">1.43 GB</span></td></tr>
        <tr><td><span class="param-name">percent</span></td><td class="param-desc"><p>Value &lt; 1 is multiplied × 100. Value &gt; 1 used as-is. Appends %</p></td><td><span class="param-type">85.60 %</span></td></tr>
        <tr><td><span class="param-name">datetime</span></td><td class="param-desc"><p>Parses ISO string and formats. Use DatePattern= (e.g. <code>dd/MM/yyyy HH:mm</code>)</p></td><td><span class="param-type">19/03/2026 14:00</span></td></tr>
        <tr><td><span class="param-name">duration</span></td><td class="param-desc"><p>Integer seconds → human-readable h m s</p></td><td><span class="param-type">2h 14m 05s</span></td></tr>
      </tbody>
    </table>
  </section>
  <hr class="section-rule">

  <!-- ═══ Threshold classes ═══ -->
  <section class="cmd-section" id="ref-thresholds">
    <div class="cmd-header">
      <div class="cmd-icon" style="background:color-mix(in srgb,#f85149 15%,var(--bg3))">
        <span style="color:#f85149;font-size:11px;font-weight:700;font-family:var(--font-mono)">THR</span>
      </div>
      <div>
        <div class="cmd-name" style="color:#f85149">Threshold classes</div>
        <div class="cmd-synopsis">Built-in CSS classes for cell and row colouring</div>
      </div>
    </div>
    <table class="params-table">
      <thead><tr><th>Class</th><th>Colour</th><th>Typical use</th></tr></thead>
      <tbody>
        <tr><td><span class="param-name">cell-ok</span></td><td><span style="color:#3fb950">■ Green</span></td><td class="param-desc"><p>Healthy, connected, active, passing</p></td></tr>
        <tr><td><span class="param-name">cell-warn</span></td><td><span style="color:#d29922">■ Orange</span></td><td class="param-desc"><p>Warning, degraded, expiring soon</p></td></tr>
        <tr><td><span class="param-name">cell-danger</span></td><td><span style="color:#f85149">■ Red</span></td><td class="param-desc"><p>Critical, failed, unreachable, expired</p></td></tr>
      </tbody>
    </table>
    <div class="syntax-label">Usage in column definition</div>
    <div class="syntax-block"><span class="hl-var">$col</span> = @{
  <span class="hl-param">Field</span>      = <span class="hl-string">'Status'</span>
  <span class="hl-param">Label</span>      = <span class="hl-string">'Status'</span>
  <span class="hl-param">Thresholds</span> = @(
    @{ <span class="hl-param">Value</span> = <span class="hl-string">'OK'</span>;       <span class="hl-param">Class</span> = <span class="hl-string">'cell-ok'</span>     }
    @{ <span class="hl-param">Value</span> = <span class="hl-string">'Warning'</span>;  <span class="hl-param">Class</span> = <span class="hl-string">'cell-warn'</span>   }
    @{ <span class="hl-param">Value</span> = <span class="hl-string">'Critical'</span>; <span class="hl-param">Class</span> = <span class="hl-string">'cell-danger'</span> }
  )
  <span class="hl-param">RowHighlight</span> = <span class="hl-var">$true</span>
}</div>
  </section>
  <hr class="section-rule">

  <!-- ═══ Theme families ═══ -->
  <section class="cmd-section" id="ref-themes">
    <div class="cmd-header">
      <div class="cmd-icon" style="background:color-mix(in srgb,#bc8cff 15%,var(--bg3))">
        <span style="color:#bc8cff;font-size:11px;font-weight:700;font-family:var(--font-mono)">CSS</span>
      </div>
      <div>
        <div class="cmd-name" style="color:#bc8cff">Theme families</div>
        <div class="cmd-synopsis">Five built-in theme families — each embeds light and dark variants</div>
      </div>
    </div>
    <table class="params-table">
      <thead><tr><th>Family</th><th>Light variant</th><th>Dark variant</th><th>Font</th></tr></thead>
      <tbody>
        <tr><td><span class="param-name">Default</span></td><td class="param-desc"><p>Light grey + blue</p></td><td class="param-desc"><p>Near-black + cyan</p></td><td><span class="param-type">System UI</span></td></tr>
        <tr><td><span class="param-name">Azure</span></td><td class="param-desc"><p>Warm grey + Azure blue</p></td><td class="param-desc"><p>Office dark + Azure</p></td><td><span class="param-type">Segoe UI</span></td></tr>
        <tr><td><span class="param-name">VMware</span></td><td class="param-desc"><p>White/navy + VMware green</p></td><td class="param-desc"><p>Navy + VMware green</p></td><td><span class="param-type">Inter (Google)</span></td></tr>
        <tr><td><span class="param-name">Grey</span></td><td class="param-desc"><p>Warm grey + steel</p></td><td class="param-desc"><p>Dark neutral + muted grey</p></td><td><span class="param-type">System UI</span></td></tr>
        <tr><td><span class="param-name">Company</span></td><td class="param-desc"><p>White + Crimson</p></td><td class="param-desc"><p>Near-black + Crimson</p></td><td><span class="param-type">Montserrat (Google)</span></td></tr>
      </tbody>
    </table>
  </section>
'@

# ── README.md SECTION ────────────────────────────────────────────────────────
# Use ConvertFrom-Markdown (PS 7+) to render the README as HTML, then wrap it
# in a styled section that matches the dark reference theme.
$readmeSectionHtml = ''
$readmePath = Join-Path $root 'README.md'
if (Test-Path $readmePath) {
    Write-Host "  Embedding README.md" -ForegroundColor DarkGray
    $mdResult  = Get-Content $readmePath -Raw | ConvertFrom-Markdown
    $mdHtml    = $mdResult.Html

    # Patch the rendered Markdown HTML:
    # • fenced code blocks → add copy button + data attribute for JS highlighter
    # • inline <code> → already styled via CSS
    $mdHtml = $mdHtml -replace '<pre><code class="language-powershell">([\s\S]*?)</code></pre>', {
        $encoded = $_.Groups[1].Value   # already HTML-encoded by ConvertFrom-Markdown
        "<div class='md-code-block'><div class='md-code-header'><span class='md-code-lang'>PowerShell</span><button class='copy-btn' title='Copy'>Copy</button></div><div class='example-code'>$encoded</div></div>"
    }
    # Generic fenced blocks without a language tag
    $mdHtml = $mdHtml -replace '<pre><code>([\s\S]*?)</code></pre>', {
        $encoded = $_.Groups[1].Value
        "<div class='md-code-block'><div class='md-code-header'><span class='md-code-lang'>code</span><button class='copy-btn' title='Copy'>Copy</button></div><div class='example-code'>$encoded</div></div>"
    }

    $readmeSectionHtml = @"
  <!-- ═══ README ═══ -->
  <section class="cmd-section" id="guide-readme">
    <div class="cmd-header">
      <div class="cmd-icon" style="background:color-mix(in srgb,#58a6ff 15%,var(--bg3))">
        <span style="color:#58a6ff;font-size:11px;font-weight:700;font-family:var(--font-mono)">MD</span>
      </div>
      <div>
        <div class="cmd-name" style="color:#58a6ff">README</div>
        <div class="cmd-synopsis">Full module guide — quick start, examples, and feature reference</div>
      </div>
    </div>
    <div class="md-body">
$mdHtml
    </div>
  </section>
"@
} else {
    Write-Warning "README.md not found at $readmePath — skipping guide section."
}

# ── ASSEMBLE FULL HTML ────────────────────────────────────────────────────────
$genDate = Get-Date -Format 'yyyy-MM-dd HH:mm'

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="generator" content="Build-DhReference.ps1">
<title>DashHtml v$version — PowerShell Module Reference</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500&family=Sora:wght@300;400;600;700&display=swap" rel="stylesheet">
<style>
:root {
  --bg:          #0d1117;
  --bg2:         #161b22;
  --bg3:         #21262d;
  --bg4:         #30363d;
  --border:      #30363d;
  --border2:     #484f58;
  --text:        #e6edf3;
  --text2:       #8b949e;
  --text3:       #6e7681;
  --accent:      #58a6ff;
  --accent2:     #1f6feb;
  --accent-dim:  #1c3458;
  --green:       #3fb950;
  --green-dim:   #0f2d18;
  --orange:      #d29922;
  --orange-dim:  #2d1f00;
  --red:         #f85149;
  --red-dim:     #2d0f0f;
  --purple:      #bc8cff;
  --purple-dim:  #1e1230;
  --nav-w:       260px;
  --radius:      8px;
  --radius-lg:   12px;
  --font-ui:     'Sora', system-ui, sans-serif;
  --font-mono:   'JetBrains Mono', 'Cascadia Code', monospace;
}

*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
html { scroll-behavior: smooth; }

body {
  background: var(--bg);
  color: var(--text);
  font-family: var(--font-ui);
  font-size: 15px;
  line-height: 1.7;
  display: flex;
  min-height: 100vh;
}

/* ── Sidebar ── */
aside {
  width: var(--nav-w);
  flex-shrink: 0;
  position: fixed;
  top: 0; left: 0; bottom: 0;
  background: var(--bg2);
  border-right: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  overflow-y: auto;
  z-index: 100;
}
.sidebar-header {
  padding: 24px 20px 16px;
  border-bottom: 1px solid var(--border);
}
.sidebar-logo {
  display: flex; align-items: center; gap: 10px; margin-bottom: 6px;
}
.logo-badge {
  width: 32px; height: 32px;
  background: linear-gradient(135deg, var(--accent2), var(--purple));
  border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  font-size: 14px; font-weight: 700; color: #fff;
}
.sidebar-title { font-size: 15px; font-weight: 700; color: var(--text); letter-spacing: -0.3px; }
.sidebar-version {
  font-size: 11px; color: var(--text3); font-family: var(--font-mono);
  background: var(--bg3); padding: 2px 8px; border-radius: 4px;
  display: inline-block; margin-top: 4px;
}
.nav-section-label {
  font-size: 10px; font-weight: 700; letter-spacing: 1.2px; text-transform: uppercase;
  color: var(--text3); padding: 16px 20px 6px;
}
.nav-item {
  display: flex; align-items: center; gap: 10px; padding: 7px 20px;
  font-size: 13px; color: var(--text2); cursor: pointer;
  border-left: 2px solid transparent;
  transition: all 0.15s; text-decoration: none;
}
.nav-item:hover { color: var(--text); background: var(--bg3); border-left-color: var(--border2); }
.nav-item.active { color: var(--accent); background: var(--accent-dim); border-left-color: var(--accent); }
.nav-dot { width: 6px; height: 6px; border-radius: 50%; background: var(--bg4); flex-shrink: 0; }
.nav-item:hover .nav-dot { background: var(--text2); }
.nav-item.active .nav-dot { background: var(--accent); }
.nav-tag {
  margin-left: auto; font-size: 10px; font-family: var(--font-mono);
  background: var(--bg3); color: var(--text3); padding: 1px 6px; border-radius: 3px;
}

/* ── Main ── */
main { margin-left: var(--nav-w); flex: 1; max-width: 920px; padding: 48px 48px 80px; }

/* ── Page header ── */
.page-header { margin-bottom: 48px; padding-bottom: 32px; border-bottom: 1px solid var(--border); }
.header-eyebrow {
  font-size: 11px; font-weight: 600; letter-spacing: 1.5px; text-transform: uppercase;
  color: var(--accent); margin-bottom: 10px; font-family: var(--font-mono);
}
.page-title { font-size: 36px; font-weight: 700; color: var(--text); letter-spacing: -0.8px; line-height: 1.2; margin-bottom: 12px; }
.page-desc { font-size: 16px; color: var(--text2); line-height: 1.65; max-width: 620px; }
.module-badges { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 18px; }
.badge { font-size: 11px; font-family: var(--font-mono); padding: 4px 10px; border-radius: 20px; border: 1px solid; }
.badge-blue   { background: var(--accent-dim);  color: var(--accent);  border-color: var(--accent2); }
.badge-green  { background: var(--green-dim);   color: var(--green);   border-color: #1a4d22; }
.badge-purple { background: var(--purple-dim);  color: var(--purple);  border-color: #4a2580; }
.badge-orange { background: var(--orange-dim);  color: var(--orange);  border-color: #5a3a00; }

/* ── Quick reference grid ── */
.qr-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px,1fr)); gap: 10px; margin-bottom: 48px; }
.qr-card {
  background: var(--bg2); border: 1px solid var(--border); border-radius: var(--radius);
  padding: 14px 16px; cursor: pointer; transition: all 0.15s; text-decoration: none; display: block;
}
.qr-card:hover { border-color: var(--accent2); background: var(--accent-dim); transform: translateY(-1px); box-shadow: 0 4px 12px rgba(0,0,0,0.3); }
.qr-cmd-name { font-family: var(--font-mono); font-size: 12.5px; font-weight: 600; margin-bottom: 4px; }
.qr-cmd-desc { font-size: 12px; color: var(--text2); line-height: 1.45; }

/* ── Workflow strip ── */
.workflow {
  display: flex; align-items: center; flex-wrap: wrap; gap: 4px;
  background: var(--bg2); border: 1px solid var(--border);
  border-radius: var(--radius-lg); padding: 16px 20px; margin-bottom: 48px;
}
.wf-step { display: flex; align-items: center; gap: 8px; font-size: 12px; font-family: var(--font-mono); color: var(--text2); }
.wf-step code {
  background: var(--bg3); border: 1px solid var(--border); color: var(--accent);
  padding: 3px 8px; border-radius: 5px; font-size: 12px;
}
.wf-arrow { color: var(--text3); margin: 0 6px; font-size: 14px; }

/* ── Command sections ── */
.cmd-section { margin-bottom: 64px; scroll-margin-top: 24px; }
.cmd-header {
  display: flex; align-items: center; gap: 14px;
  margin-bottom: 20px; padding-bottom: 14px; border-bottom: 1px solid var(--border);
}
.cmd-icon {
  width: 38px; height: 38px; border-radius: var(--radius);
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.cmd-name { font-size: 22px; font-weight: 700; font-family: var(--font-mono); letter-spacing: -0.3px; }
.cmd-synopsis { font-size: 14px; color: var(--text2); margin-top: 2px; }
.cmd-tag { font-size: 10px; font-family: var(--font-mono); padding: 3px 10px; border-radius: 20px; flex-shrink: 0; }

/* ── Description block ── */
.desc-block {
  background: var(--bg2); border: 1px solid var(--border); border-radius: var(--radius);
  padding: 16px 20px; font-size: 14px; color: var(--text2); line-height: 1.7; margin-bottom: 20px;
}
.desc-block p { margin-bottom: 8px; }
.desc-block p:last-child { margin-bottom: 0; }
.desc-code {
  background: var(--bg); border: 1px solid var(--border); border-radius: 4px;
  padding: 8px 12px; font-family: var(--font-mono); font-size: 12px; line-height: 1.7;
  overflow-x: auto; margin: 8px 0; white-space: pre; color: var(--text2);
}

/* ── Syntax block ── */
.syntax-label {
  font-size: 10px; font-weight: 700; letter-spacing: 1.2px; text-transform: uppercase;
  color: var(--text3); margin-bottom: 6px; margin-top: 20px;
}
.syntax-block {
  background: #010409; border: 1px solid var(--border); border-radius: var(--radius);
  padding: 16px 20px; font-family: var(--font-mono); font-size: 13px; line-height: 1.8;
  overflow-x: auto; margin-bottom: 20px; white-space: pre;
}

/* ── Parameters table ── */
.params-table { width: 100%; border-collapse: collapse; font-size: 13px; margin-bottom: 20px; }
.params-table thead th {
  background: var(--bg3); color: var(--text3); font-size: 10px; font-weight: 700;
  letter-spacing: 1px; text-transform: uppercase; padding: 8px 12px; text-align: left;
  border: 1px solid var(--border);
}
.params-table tbody tr { border: 1px solid var(--border); transition: background 0.1s; }
.params-table tbody tr:hover { background: var(--bg2); }
.params-table td { padding: 10px 12px; vertical-align: top; border: 1px solid var(--border); }
.param-name   { font-family: var(--font-mono); color: var(--purple); white-space: nowrap; font-size: 12.5px; }
.param-type   { font-family: var(--font-mono); color: var(--green);  font-size: 11.5px; white-space: nowrap; }
.param-req    { display: inline-block; font-size: 10px; font-family: var(--font-mono); padding: 1px 6px; border-radius: 3px; white-space: nowrap; }
.req-yes      { background: #2d0f0f; color: var(--red);   border: 1px solid #5a1f1f; }
.req-no       { background: var(--bg3); color: var(--text3); border: 1px solid var(--border); }
.param-desc   { color: var(--text2); line-height: 1.6; font-size: 13px; }
.param-desc p { margin-bottom: 4px; }
.param-desc p:last-child { margin-bottom: 0; }
.param-default { font-family: var(--font-mono); color: var(--orange); font-size: 11px; display: block; margin-top: 4px; }

/* ── Examples ── */
.example-block { background: #010409; border: 1px solid var(--border); border-radius: var(--radius); margin-bottom: 14px; overflow: hidden; }
.example-header {
  background: var(--bg3); border-bottom: 1px solid var(--border);
  padding: 8px 16px; display: flex; align-items: center; justify-content: space-between;
}
.example-label { font-size: 11px; font-weight: 600; color: var(--text3); font-family: var(--font-mono); letter-spacing: 0.5px; }
.example-title { font-size: 12px; color: var(--text2); font-family: var(--font-mono); }
.example-code  { padding: 16px 20px; font-family: var(--font-mono); font-size: 12.5px; line-height: 1.8; white-space: pre; overflow-x: auto; color: var(--text2); }

/* ── PS Syntax highlighting ── */
.hl-cmd     { color: #79c0ff; }
.hl-param   { color: #d2a8ff; }
.hl-type    { color: #3fb950; }
.hl-var     { color: #ffa657; }
.hl-string  { color: #a5d6ff; }
.hl-comment { color: #6e7681; font-style: italic; }
.hl-kw      { color: #ff7b72; }
.hl-num     { color: #79c0ff; }
.hl-pipe    { color: #e3b341; }
.hl-opt     { opacity: 0.75; }

/* ── Copy button ── */
.copy-btn {
  background: var(--bg4); border: 1px solid var(--border2); color: var(--text3);
  font-size: 10px; font-family: var(--font-mono); padding: 2px 8px; border-radius: 4px;
  cursor: pointer; transition: all 0.15s; white-space: nowrap;
}
.copy-btn:hover { background: var(--accent-dim); border-color: var(--accent); color: var(--accent); }
.copy-btn.copied { background: var(--green-dim); border-color: var(--green); color: var(--green); }

/* ── Markdown body (README section) ── */
.md-body { font-size: 14px; color: var(--text2); line-height: 1.75; }
.md-body h1 { font-size: 24px; font-weight: 700; color: var(--text); margin: 32px 0 12px; padding-bottom: 8px; border-bottom: 1px solid var(--border); }
.md-body h2 { font-size: 18px; font-weight: 700; color: var(--text); margin: 28px 0 10px; padding-bottom: 6px; border-bottom: 1px solid var(--border); }
.md-body h3 { font-size: 15px; font-weight: 600; color: var(--accent); margin: 20px 0 8px; }
.md-body p  { margin-bottom: 12px; }
.md-body ul, .md-body ol { margin: 8px 0 12px 24px; }
.md-body li { margin-bottom: 4px; }
.md-body a  { color: var(--accent); text-decoration: none; }
.md-body a:hover { text-decoration: underline; }
.md-body strong { color: var(--text); font-weight: 600; }
.md-body code { font-family: var(--font-mono); font-size: 12px; background: var(--bg3); color: var(--accent); padding: 1px 5px; border-radius: 4px; border: 1px solid var(--border); }
.md-body table { width: 100%; border-collapse: collapse; font-size: 13px; margin: 12px 0 20px; }
.md-body thead th { background: var(--bg3); color: var(--text3); font-size: 10px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; padding: 8px 12px; text-align: left; border: 1px solid var(--border); }
.md-body tbody tr { border: 1px solid var(--border); }
.md-body tbody tr:hover { background: var(--bg2); }
.md-body td { padding: 8px 12px; border: 1px solid var(--border); }
.md-body hr { border: none; border-top: 1px solid var(--border); margin: 28px 0; }
.md-code-block { background: #010409; border: 1px solid var(--border); border-radius: var(--radius); margin: 12px 0 20px; overflow: hidden; }
.md-code-header { background: var(--bg3); border-bottom: 1px solid var(--border); padding: 7px 16px; display: flex; align-items: center; justify-content: space-between; }
.md-code-lang { font-size: 11px; font-family: var(--font-mono); color: var(--text3); }

/* ── Misc ── */
.section-rule { border: none; border-top: 1px solid var(--border); margin: 48px 0; }
code { font-family: var(--font-mono); font-size: 12px; background: var(--bg3); color: var(--accent); padding: 1px 5px; border-radius: 4px; border: 1px solid var(--border); }
.page-footer { margin-top: 64px; padding-top: 24px; border-top: 1px solid var(--border); font-size: 12px; color: var(--text3); font-family: var(--font-mono); }
:target { scroll-margin-top: 24px; }
::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: var(--bg4); border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: var(--border2); }
</style>
</head>
<body>

<!-- ═══════════════════════════════ SIDEBAR ══════════════════════════════ -->
<aside>
  <div class="sidebar-header">
    <div class="sidebar-logo">
      <div class="logo-badge">D</div>
      <span class="sidebar-title">DashHtml</span>
    </div>
    <span class="sidebar-version">v$version · PS 7.0+</span>
  </div>
  <div class="nav-section-label">Overview</div>
  <a class="nav-item" href="#overview"><span class="nav-dot"></span>Getting started</a>
$($sidebarNavHtml.ToString())
</aside>

<!-- ═══════════════════════════════ MAIN ═════════════════════════════════ -->
<main>

  <div class="page-header" id="overview">
    <div class="header-eyebrow">PowerShell Module Reference</div>
    <h1 class="page-title">DashHtml</h1>
    <p class="page-desc">Generate interactive, self-contained HTML dashboards from PowerShell — sortable tables, KPI tiles, bar charts, filter cards, collapsible sections, drill-down linking, and client-side CSV / XLSX / PDF export. Five theme families, embedded light/dark variants, no external dependencies at viewing time.</p>
    <div class="module-badges">
      <span class="badge badge-blue">PowerShell 7.0+</span>
      <span class="badge badge-green">$($cmdMeta.Count) exported functions</span>
      <span class="badge badge-purple">5 theme families</span>
      <span class="badge badge-orange">MIT License</span>
    </div>
  </div>

  <!-- Quick reference grid -->
  <div class="qr-grid">
$($qrGridHtml.ToString())
  </div>

  <!-- Workflow strip -->
  <div id="workflow" style="scroll-margin-top:24px; margin-bottom:48px">
    <div class="syntax-label">Typical workflow</div>
    <div class="workflow">
      <div class="wf-step"><code>New-DhDashboard</code></div>
      <span class="wf-arrow">→</span>
      <div class="wf-step"><code>Add-DhSummary</code></div>
      <span class="wf-arrow">→</span>
      <div class="wf-step"><code>Add-DhTable</code></div>
      <span class="wf-arrow">→</span>
      <div class="wf-step"><code>Add-Dh*</code> <span style="color:var(--text3);font-size:11px">(blocks)</span></div>
      <span class="wf-arrow">→</span>
      <div class="wf-step"><code>Set-DhTableLink</code></div>
      <span class="wf-arrow">→</span>
      <div class="wf-step"><code>Export-DhDashboard</code></div>
    </div>
  </div>

  <hr class="section-rule">

$($allSections.ToString())
$refSections

$readmeSectionHtml

  <div class="page-footer">
    Generated by Build-DhReference.ps1 · DashHtml v$version · $genDate
  </div>

</main>

<script>
/* =========================================================
   PS TOKENIZER — safe one-pass highlighter.
   Reads raw textContent (no HTML), tokenises, then writes innerHTML.
   Never processes its own output so span attributes stay clean.
   ========================================================= */
(function () {
  var KW = new Set(['if','else','elseif','foreach','for','while','do','return',
    'switch','break','continue','throw','try','catch','finally',
    'function','param','begin','process','end','in','where','select']);

  function esc(s) {
    return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  }

  function span(cls, txt) { return '<span class="hl-'+cls+'">'+esc(txt)+'</span>'; }

  function tokenise(src) {
    var out = '', i = 0, n = src.length;
    while (i < n) {
      var ch = src[i];

      /* Line comment */
      if (ch === '#') {
        var end = src.indexOf('\n', i);
        if (end === -1) end = n;
        out += span('comment', src.slice(i, end));
        i = end; continue;
      }

      /* Single-quoted string */
      if (ch === "'") {
        var j = i + 1;
        while (j < n && src[j] !== "'") j++;
        out += span('string', src.slice(i, j + 1));
        i = j + 1; continue;
      }

      /* Double-quoted string */
      if (ch === '"') {
        var j = i + 1;
        while (j < n && src[j] !== '"') { if (src[j] === '`') j++; j++; }
        out += span('string', src.slice(i, j + 1));
        i = j + 1; continue;
      }

      /* Variable */
      if (ch === '$') {
        var j = i + 1;
        while (j < n && /[\w]/.test(src[j])) j++;
        out += span('var', src.slice(i, j));
        i = j; continue;
      }

      /* Parameter  -Name  (must be preceded by whitespace, backtick, ( or ,) */
      if (ch === '-' && i > 0 && /[\s`(,]/.test(src[i - 1]) && i + 1 < n && /[A-Za-z]/.test(src[i + 1])) {
        var j = i + 1;
        while (j < n && /[\w]/.test(src[j])) j++;
        out += span('param', src.slice(i, j));
        i = j; continue;
      }

      /* Word: cmdlet Verb-Noun, keyword, or plain identifier */
      if (/[A-Za-z_]/.test(ch)) {
        var j = i;
        while (j < n && /[\w]/.test(src[j])) j++;
        var word = src.slice(i, j);

        /* Check Verb-Noun pattern for cmdlets */
        if (/^[A-Z][a-z]+-[A-Z][a-zA-Z0-9]+$/.test(word)) {
          out += span('cmd', word);
        } else if (KW.has(word.toLowerCase())) {
          out += span('kw', word);
        } else {
          out += esc(word);
        }
        i = j; continue;
      }

      /* Number */
      if (/[0-9]/.test(ch) && (i === 0 || /[\s(,=+\-*\/]/.test(src[i-1]))) {
        var j = i;
        while (j < n && /[\d.]/.test(src[j])) j++;
        out += span('num', src.slice(i, j));
        i = j; continue;
      }

      /* Pipe */
      if (ch === '|') { out += span('pipe', '|'); i++; continue; }

      /* Everything else — HTML-encode and emit */
      out += esc(ch);
      i++;
    }
    return out;
  }

  function highlightAll() {
    document.querySelectorAll('.example-code, .syntax-block').forEach(function (el) {
      var raw = el.textContent || el.innerText || '';
      if (raw.trim()) el.innerHTML = tokenise(raw);
    });
  }

  /* ── Copy buttons ── */
  function initCopyButtons() {
    document.querySelectorAll('.copy-btn').forEach(function (btn) {
      btn.addEventListener('click', function () {
        /* Find the nearest .example-code sibling */
        var block = btn.closest('.example-block, .md-code-block');
        var codeEl = block ? block.querySelector('.example-code') : null;
        if (!codeEl) return;
        var text = codeEl.textContent || codeEl.innerText || '';
        navigator.clipboard.writeText(text.trim()).then(function () {
          btn.textContent = 'Copied!';
          btn.classList.add('copied');
          setTimeout(function () { btn.textContent = 'Copy'; btn.classList.remove('copied'); }, 1800);
        }).catch(function () {
          btn.textContent = 'Error';
          setTimeout(function () { btn.textContent = 'Copy'; }, 1500);
        });
      });
    });
  }

  /* ── Active nav highlight on scroll ── */
  function initScrollSpy() {
    var items    = document.querySelectorAll('.nav-item[href^="#"]');
    var sections = [];
    items.forEach(function (a) {
      var id = a.getAttribute('href').slice(1);
      var el = document.getElementById(id);
      if (el) sections.push({ el: el, a: a });
    });
    function onScroll() {
      var top    = window.scrollY + 80;
      var active = null;
      for (var i = sections.length - 1; i >= 0; i--) {
        if (sections[i].el.offsetTop <= top) { active = sections[i]; break; }
      }
      items.forEach(function (a) { a.classList.remove('active'); });
      if (active) active.a.classList.add('active');
    }
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

  document.addEventListener('DOMContentLoaded', function () {
    highlightAll();
    initCopyButtons();
    initScrollSpy();
  });
})();
</script>

</body>
</html>
"@

# ── Write output ──────────────────────────────────────────────────────────────
Set-Content -Path $outFile -Value $html -Encoding UTF8
$sizeKb = [math]::Round((Get-Item $outFile).Length / 1KB, 1)
Write-Host ''
Write-Host "  Done: $outFile  ($sizeKb KB)" -ForegroundColor Green

if ($Open) {
    Start-Process $outFile
}
