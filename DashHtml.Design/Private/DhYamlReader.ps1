# ---------------------------------------------------------------------------
#  Minimal, self-contained YAML reader for the DashHtml layout schema.
#  Parses the block-style subset emitted by DhYamlWriter (plus flow {} / []),
#  producing nested [ordered] hashtables + arrays with typed scalars.
#  NOT a general YAML parser: no anchors, tags, block scalars, or multi-doc.
# ---------------------------------------------------------------------------

function Remove-DhYamlComment {
    <# Strip a trailing '# ...' comment that is outside quotes. #>
    param([string] $line)
    $inS = $false; $inD = $false
    for ($i = 0; $i -lt $line.Length; $i++) {
        $c = $line[$i]
        if ($c -eq "'" -and -not $inD) { $inS = -not $inS }
        elseif ($c -eq '"' -and -not $inS) { $inD = -not $inD }
        elseif ($c -eq '#' -and -not $inS -and -not $inD) {
            if ($i -eq 0 -or $line[$i - 1] -eq ' ' -or $line[$i - 1] -eq "`t") {
                return $line.Substring(0, $i)
            }
        }
    }
    return $line
}

function Get-DhYamlLines {
    param([string] $text)
    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($raw in ($text -split "`r?`n")) {
        $line = Remove-DhYamlComment $raw
        if ($line.Trim().Length -eq 0) { continue }
        $indent = $line.Length - $line.TrimStart(' ').Length
        [void]$out.Add([pscustomobject]@{ Indent = $indent; Text = $line.Trim() })
    }
    return , $out
}

function ConvertFrom-DhYamlScalarText {
    <# Coerce an unquoted / quoted scalar token to a typed value. #>
    param([string] $s)
    $s = $s.Trim()
    if ($s.Length -eq 0) { return $null }
    if ($s.StartsWith('"') -and $s.EndsWith('"') -and $s.Length -ge 2) {
        $inner = $s.Substring(1, $s.Length - 2)
        return ($inner -replace '\\n', "`n" -replace '\\r', "`r" -replace '\\t', "`t" -replace '\\"', '"' -replace '\\\\', '\')
    }
    if ($s.StartsWith("'") -and $s.EndsWith("'") -and $s.Length -ge 2) {
        return $s.Substring(1, $s.Length - 2) -replace "''", "'"
    }
    switch -Regex ($s) {
        '^(null|~)$'      { return $null }
        '^true$'          { return $true }
        '^false$'         { return $false }
        '^-?\d+$'         { $n = 0L; if ([long]::TryParse($s, [ref]$n)) { if ($n -ge [int]::MinValue -and $n -le [int]::MaxValue) { return [int]$n } return $n } }
        '^-?\d+\.\d+$'    { $d = 0.0; if ([double]::TryParse($s, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return $d } }
    }
    return $s
}

function ConvertFrom-DhYamlFlow {
    <# Parse a flow scalar / mapping / sequence starting at $pos.Value. #>
    param([string] $s, [ref] $pos)
    while ($pos.Value -lt $s.Length -and $s[$pos.Value] -eq ' ') { $pos.Value++ }
    if ($pos.Value -ge $s.Length) { return $null }
    $c = $s[$pos.Value]
    if ($c -eq '{') {
        $pos.Value++
        $map = [ordered]@{}
        while ($true) {
            while ($pos.Value -lt $s.Length -and ($s[$pos.Value] -eq ' ' -or $s[$pos.Value] -eq ',')) { $pos.Value++ }
            if ($pos.Value -ge $s.Length -or $s[$pos.Value] -eq '}') { $pos.Value++; break }
            $key = ConvertFrom-DhYamlFlowToken $s $pos ':'
            while ($pos.Value -lt $s.Length -and ($s[$pos.Value] -eq ' ' -or $s[$pos.Value] -eq ':')) { $pos.Value++ }
            $val = ConvertFrom-DhYamlFlow $s $pos
            $map["$key"] = $val
        }
        return $map
    }
    elseif ($c -eq '[') {
        $pos.Value++
        $seq = [System.Collections.Generic.List[object]]::new()
        while ($true) {
            while ($pos.Value -lt $s.Length -and ($s[$pos.Value] -eq ' ' -or $s[$pos.Value] -eq ',')) { $pos.Value++ }
            if ($pos.Value -ge $s.Length -or $s[$pos.Value] -eq ']') { $pos.Value++; break }
            [void]$seq.Add((ConvertFrom-DhYamlFlow $s $pos))
        }
        return , $seq.ToArray()
    }
    else {
        $tok = ConvertFrom-DhYamlFlowToken $s $pos ',]}'
        return ConvertFrom-DhYamlScalarText $tok
    }
}

function ConvertFrom-DhYamlFlowToken {
    <# Read a bare-or-quoted token up to one of $stop chars (outside quotes). #>
    param([string] $s, [ref] $pos, [string] $stop)
    while ($pos.Value -lt $s.Length -and $s[$pos.Value] -eq ' ') { $pos.Value++ }
    $start = $pos.Value
    if ($pos.Value -lt $s.Length -and ($s[$pos.Value] -eq '"' -or $s[$pos.Value] -eq "'")) {
        $q = $s[$pos.Value]; $pos.Value++
        while ($pos.Value -lt $s.Length -and $s[$pos.Value] -ne $q) {
            if ($s[$pos.Value] -eq '\' -and $q -eq '"') { $pos.Value++ }
            $pos.Value++
        }
        $pos.Value++  # closing quote
        return $s.Substring($start, $pos.Value - $start)
    }
    while ($pos.Value -lt $s.Length -and $stop.IndexOf($s[$pos.Value]) -lt 0) { $pos.Value++ }
    return $s.Substring($start, $pos.Value - $start).Trim()
}

function ConvertFrom-DhYamlValue {
    <# A value after 'key:' — flow collection or plain scalar. #>
    param([string] $text)
    $t = $text.Trim()
    if ($t.StartsWith('{') -or $t.StartsWith('[')) {
        $pos = 0
        return ConvertFrom-DhYamlFlow $t ([ref]$pos)
    }
    return ConvertFrom-DhYamlScalarText $t
}

function Split-DhYamlKeyValue {
    <# Split 'key: value' at the first top-level colon-space (or trailing colon). #>
    param([string] $line)
    $inS = $false; $inD = $false
    for ($i = 0; $i -lt $line.Length; $i++) {
        $c = $line[$i]
        if ($c -eq "'" -and -not $inD) { $inS = -not $inS }
        elseif ($c -eq '"' -and -not $inS) { $inD = -not $inD }
        elseif ($c -eq ':' -and -not $inS -and -not $inD) {
            if ($i -eq $line.Length - 1) { return @{ Key = $line.Substring(0, $i).Trim(); Value = '' } }
            if ($line[$i + 1] -eq ' ') { return @{ Key = $line.Substring(0, $i).Trim(); Value = $line.Substring($i + 1).Trim() } }
        }
    }
    return $null
}

function ConvertFrom-DhYamlBlock {
    <# Parse a block (map or seq) at $indent starting at $ix.Value. #>
    param([System.Collections.Generic.List[object]] $lines, [ref] $ix, [int] $indent)
    $first = $lines[$ix.Value]
    if ($first.Text.StartsWith('- ') -or $first.Text -eq '-') {
        return ConvertFrom-DhYamlSeq $lines $ix $indent
    }
    return ConvertFrom-DhYamlMap $lines $ix $indent
}

function ConvertFrom-DhYamlMap {
    param([System.Collections.Generic.List[object]] $lines, [ref] $ix, [int] $indent)
    $map = [ordered]@{}
    while ($ix.Value -lt $lines.Count) {
        $ln = $lines[$ix.Value]
        if ($ln.Indent -lt $indent) { break }
        if ($ln.Text.StartsWith('- ') -or $ln.Text -eq '-') { break }
        $kv = Split-DhYamlKeyValue $ln.Text
        if ($null -eq $kv) { throw "DhYaml: cannot parse line: '$($ln.Text)'" }
        if ($kv.Value -ne '') {
            $map[$kv.Key] = ConvertFrom-DhYamlValue $kv.Value
            $ix.Value++
        }
        else {
            $ix.Value++
            if ($ix.Value -lt $lines.Count -and $lines[$ix.Value].Indent -gt $indent) {
                $map[$kv.Key] = ConvertFrom-DhYamlBlock $lines $ix ($lines[$ix.Value].Indent)
            }
            else { $map[$kv.Key] = $null }
        }
    }
    return $map
}

function ConvertFrom-DhYamlSeq {
    param([System.Collections.Generic.List[object]] $lines, [ref] $ix, [int] $indent)
    $seq = [System.Collections.Generic.List[object]]::new()
    while ($ix.Value -lt $lines.Count) {
        $ln = $lines[$ix.Value]
        if ($ln.Indent -lt $indent) { break }
        if (-not ($ln.Text.StartsWith('- ') -or $ln.Text -eq '-')) { break }
        $item = if ($ln.Text -eq '-') { '' } else { $ln.Text.Substring(2).Trim() }

        if ($item -eq '') {
            $ix.Value++
            if ($ix.Value -lt $lines.Count -and $lines[$ix.Value].Indent -gt $indent) {
                [void]$seq.Add((ConvertFrom-DhYamlBlock $lines $ix ($lines[$ix.Value].Indent)))
            } else { [void]$seq.Add($null) }
        }
        elseif ($item.StartsWith('{') -or $item.StartsWith('[')) {
            [void]$seq.Add((ConvertFrom-DhYamlValue $item))
            $ix.Value++
        }
        else {
            $kv = Split-DhYamlKeyValue $item
            if ($null -ne $kv) {
                # Inline first key of a map; the map's remaining keys sit at indent+2.
                $childIndent = $ln.Indent + 2
                $map = [ordered]@{}
                if ($kv.Value -ne '') {
                    $map[$kv.Key] = ConvertFrom-DhYamlValue $kv.Value
                    $ix.Value++
                }
                else {
                    $ix.Value++
                    if ($ix.Value -lt $lines.Count -and $lines[$ix.Value].Indent -gt $childIndent) {
                        $map[$kv.Key] = ConvertFrom-DhYamlBlock $lines $ix ($lines[$ix.Value].Indent)
                    } else { $map[$kv.Key] = $null }
                }
                # Continue reading the rest of this map's keys at childIndent
                while ($ix.Value -lt $lines.Count -and $lines[$ix.Value].Indent -eq $childIndent -and
                       -not ($lines[$ix.Value].Text.StartsWith('- ') -or $lines[$ix.Value].Text -eq '-')) {
                    $sub = ConvertFrom-DhYamlMap $lines $ix $childIndent
                    foreach ($k in $sub.Keys) { $map[$k] = $sub[$k] }
                }
                [void]$seq.Add($map)
            }
            else {
                [void]$seq.Add((ConvertFrom-DhYamlScalarText $item))
                $ix.Value++
            }
        }
    }
    return , $seq.ToArray()
}

function ConvertFrom-DhYamlText {
    <#
    .SYNOPSIS  Parse the DashHtml YAML subset (or JSON) into nested hashtables.
    #>
    param([string] $Text)
    $trimmed = $Text.TrimStart()
    if ($trimmed.StartsWith('{') -or $trimmed.StartsWith('[')) {
        # JSON fast path — a strict subset of our needs, native + bulletproof.
        return ($Text | ConvertFrom-Json -Depth 40 -AsHashtable)
    }
    $lines = Get-DhYamlLines $Text
    if ($lines.Count -eq 0) { return [ordered]@{} }
    $ix = 0
    return ConvertFrom-DhYamlBlock $lines ([ref]$ix) ($lines[0].Indent)
}
