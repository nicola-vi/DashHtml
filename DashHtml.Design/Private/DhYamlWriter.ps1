# ---------------------------------------------------------------------------
#  Minimal, self-contained YAML emitter for the DashHtml layout schema.
#  Not a general YAML library — it emits the block-style subset that
#  Read-DhYaml understands, so ConvertTo-DhYaml / ConvertFrom-DhYaml round-trip.
#
#  Supported: block mappings, block sequences (for arrays of maps/arrays),
#  flow sequences [a, b] (for arrays of scalars), scalars typed by value
#  (string / number / bool / null). No anchors, tags, or block scalars.
# ---------------------------------------------------------------------------

function Test-DhYamlBareSafe {
    <# True if a string can be emitted unquoted without ambiguity. #>
    param([string] $s)
    if ([string]::IsNullOrEmpty($s)) { return $false }
    # Reserved words / number-looking / bool-looking must be quoted so they
    # round-trip back as STRINGS rather than being coerced.
    if ($s -match '^(true|false|null|yes|no|on|off|~)$') { return $false }
    if ($s -match '^-?\d+(\.\d+)?$') { return $false }
    # Safe set: starts alnum, then word / space / . - / @ % : (no leading/trailing space)
    if ($s -match '^[A-Za-z0-9][A-Za-z0-9 _.\-/@%]*$' -and $s -notmatch '\s$') { return $true }
    return $false
}

function ConvertTo-DhYamlScalar {
    <# Render a single scalar value with its type preserved. #>
    param([object] $v)
    if ($null -eq $v) { return 'null' }
    if ($v -is [bool] -or $v -is [System.Management.Automation.SwitchParameter]) { return ([bool]$v).ToString().ToLower() }
    if ($v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [single] -or $v -is [decimal]) {
        # InvariantCulture so decimals use a period, not a locale comma.
        return $v.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    $s = [string]$v
    if (Test-DhYamlBareSafe $s) { return $s }
    # Double-quote with JSON-ish escaping
    $esc = $s -replace '\\', '\\' -replace '"', '\"' -replace "`t", '\t' -replace "`r", '\r' -replace "`n", '\n'
    return '"' + $esc + '"'
}

function Test-DhYamlScalar {
    param([object] $v)
    return ($null -eq $v) -or ($v -is [string]) -or ($v -is [bool]) -or `
           ($v -is [System.Management.Automation.SwitchParameter]) -or `
           ($v -is [int]) -or ($v -is [long]) -or ($v -is [double]) -or `
           ($v -is [single]) -or ($v -is [decimal])
}

function Test-DhYamlMap {
    param([object] $v)
    return ($v -is [System.Collections.IDictionary])
}

function Test-DhYamlSeq {
    param([object] $v)
    return ($v -is [System.Collections.IEnumerable]) -and ($v -isnot [string]) -and (-not (Test-DhYamlMap $v))
}

function ConvertTo-DhYamlText {
    <#
    .SYNOPSIS  Recursively emit an object as block-style YAML text.
    .PARAMETER InputObject  Hashtable / array / scalar to emit.
    .PARAMETER Indent       Current indent depth (spaces = Indent * 2).
    #>
    param(
        [object] $InputObject,
        [int]    $Indent = 0
    )
    $sb  = [System.Text.StringBuilder]::new()
    $pad = '  ' * $Indent

    if (Test-DhYamlMap $InputObject) {
        # 2.5.4 - PSBase: with -IncludeData a row can have a Keys / Count field, which .Keys would return
        foreach ($key in $InputObject.PSBase.Keys) {
            $val = $InputObject[$key]
            if (Test-DhYamlScalar $val) {
                [void]$sb.AppendLine("$pad${key}: $(ConvertTo-DhYamlScalar $val)")
            }
            elseif (Test-DhYamlSeq $val) {
                $arr = @($val)
                if ($arr.Count -eq 0) {
                    [void]$sb.AppendLine("$pad${key}: []")
                }
                elseif (@($arr | Where-Object { -not (Test-DhYamlScalar $_) }).Count -eq 0) {
                    # array of scalars -> flow sequence
                    $flow = ($arr | ForEach-Object { ConvertTo-DhYamlScalar $_ }) -join ', '
                    [void]$sb.AppendLine("$pad${key}: [$flow]")
                }
                else {
                    # array of maps/arrays -> block sequence, indented under the key
                    # (one level deeper so the reader's "child indent > key indent" holds)
                    [void]$sb.AppendLine("$pad${key}:")
                    [void]$sb.Append((ConvertTo-DhYamlSeqBlock -Items $arr -Indent ($Indent + 1)))
                }
            }
            else {
                # nested map
                [void]$sb.AppendLine("$pad${key}:")
                [void]$sb.Append((ConvertTo-DhYamlText -InputObject $val -Indent ($Indent + 1)))
            }
        }
    }
    elseif (Test-DhYamlSeq $InputObject) {
        [void]$sb.Append((ConvertTo-DhYamlSeqBlock -Items @($InputObject) -Indent $Indent))
    }
    else {
        [void]$sb.AppendLine("$pad$(ConvertTo-DhYamlScalar $InputObject)")
    }

    return $sb.ToString()
}

function ConvertTo-DhYamlSeqBlock {
    <# Emit an array as a block sequence at the given indent. #>
    param([object[]] $Items, [int] $Indent)
    $sb  = [System.Text.StringBuilder]::new()
    $pad = '  ' * $Indent
    foreach ($item in $Items) {
        if (Test-DhYamlScalar $item) {
            [void]$sb.AppendLine("$pad- $(ConvertTo-DhYamlScalar $item)")
        }
        elseif (Test-DhYamlMap $item) {
            # First key inline after "- ", the rest indented one level deeper.
            $keys = @($item.PSBase.Keys)
            if ($keys.Count -eq 0) { [void]$sb.AppendLine("$pad- {}"); continue }
            $childPad = '  ' * ($Indent + 1)
            $first = $true
            foreach ($k in $keys) {
                $v = $item[$k]
                $prefix = if ($first) { "$pad- " } else { $childPad }
                if (Test-DhYamlScalar $v) {
                    [void]$sb.AppendLine("$prefix${k}: $(ConvertTo-DhYamlScalar $v)")
                }
                elseif (Test-DhYamlSeq $v) {
                    $arr = @($v)
                    if ($arr.Count -eq 0) {
                        [void]$sb.AppendLine("$prefix${k}: []")
                    }
                    elseif (@($arr | Where-Object { -not (Test-DhYamlScalar $_) }).Count -eq 0) {
                        $flow = ($arr | ForEach-Object { ConvertTo-DhYamlScalar $_ }) -join ', '
                        [void]$sb.AppendLine("$prefix${k}: [$flow]")
                    }
                    else {
                        [void]$sb.AppendLine("$prefix${k}:")
                        [void]$sb.Append((ConvertTo-DhYamlSeqBlock -Items $arr -Indent ($Indent + 2)))
                    }
                }
                else {
                    [void]$sb.AppendLine("$prefix${k}:")
                    [void]$sb.Append((ConvertTo-DhYamlText -InputObject $v -Indent ($Indent + 2)))
                }
                $first = $false
            }
        }
        else {
            # nested array element
            [void]$sb.AppendLine("$pad-")
            [void]$sb.Append((ConvertTo-DhYamlText -InputObject $item -Indent ($Indent + 1)))
        }
    }
    return $sb.ToString()
}
