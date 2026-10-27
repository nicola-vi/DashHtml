function Get-DhBaselineDiff {
    <#
    .SYNOPSIS
        Compares the rows of a table with the rows of a previous run (Add-DhTable -Baseline).
    .DESCRIPTION
        Rows are matched by KeyField (case-insensitive text). A data row with no match is New; a match whose compared
        fields differ is Changed (the fields and their old values are kept); a baseline row with no match in the data
        is Removed. Values are compared as text with the invariant culture, and null equals an empty string.
        Throws on a duplicate key in either set or a data row without the key. A baseline row without the key is
        ignored and reported in Warnings.
    .OUTPUTS
        [ordered] @{ Changes = [ordered]@{ '<row index>' = @{ State; Fields; Was } }; Removed = @(rows);
                      Counts = @{ New; Changed; Removed; Same }; Warnings = @(text) }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Data,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Baseline,
        [Parameter(Mandatory)] [string] $KeyField,
        [string[]] $Fields = @(),
        [string] $TableId = ''
    )
    $who = if ($TableId) { "Add-DhTable '$TableId'" } else { 'Add-DhTable' }
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $text = {
        param($v)
        if ($null -eq $v) { return '' }
        if ($v -is [datetime]) { return $v.ToString('o', $inv) }
        if ($v -is [double] -or $v -is [single] -or $v -is [decimal]) { return ([System.Convert]::ToString($v, $inv)) }
        if ($v -is [bool]) { return $v.ToString().ToLowerInvariant() }
        if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) { return (@($v | ForEach-Object { [string]$_ }) -join '|') }
        return [string]$v
    }
    $props = {
        param($row)
        $h = [ordered]@{}
        # 2.5.4 - PSBase on every dictionary keyed by data (field names, key values): .Keys / .Count
        # would return the entry of that name when a field or key is called Keys, Values or Count
        if ($row -is [System.Collections.IDictionary]) { foreach ($k in $row.PSBase.Keys) { $h[[string]$k] = $row[$k] } }
        else { foreach ($p in $row.PSObject.Properties) { $h[$p.Name] = $p.Value } }
        $h
    }
    $warnings = [System.Collections.Generic.List[string]]::new()
    $typeClash = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::OrdinalIgnoreCase)   # field -> rows where one side is a date and the other text
    $numClash  = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::OrdinalIgnoreCase)   # field -> rows where a number and its text differ only in format
    $isNum = { param($v) $v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [single] -or $v -is [decimal] -or $v -is [int16] -or $v -is [byte] -or $v -is [uint32] -or $v -is [uint64] }
    $sameNum = {
        param($n, [string] $s)
        $want = [double]$n
        foreach ($c in @([System.Globalization.CultureInfo]::CurrentCulture, $inv, [System.Globalization.CultureInfo]::GetCultureInfo('it-IT'))) {
            $got = 0.0
            if ([double]::TryParse($s.Trim(), [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands, $c, [ref]$got) -and $got -eq $want) { return $true }
        }
        $false
    }

    # baseline index
    $baseByKey = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $dupBase = [System.Collections.Generic.List[string]]::new(); $missingBase = 0
    foreach ($b in $Baseline) {
        $bp = & $props $b
        if (-not $bp.Contains($KeyField)) { $missingBase++; continue }
        $k = & $text $bp[$KeyField]
        if ($baseByKey.ContainsKey($k)) { if ($dupBase.Count -lt 5) { $dupBase.Add($k) }; continue }
        $baseByKey[$k] = $bp
    }
    if ($dupBase.Count) { throw "$who -Baseline: duplicate $KeyField value(s) in the baseline: $($dupBase -join ', '). A key must identify one row." }
    if ($missingBase) { $warnings.Add("$missingBase baseline row(s) have no '$KeyField' property and are ignored.") }

    # data pass
    $changes = [ordered]@{}; $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $dupData = [System.Collections.Generic.List[string]]::new(); $nNew = 0; $nChanged = 0; $nSame = 0; $i = 0
    foreach ($d in $Data) {
        $dp = & $props $d
        if (-not $dp.Contains($KeyField)) { throw "$who -KeyField '$KeyField' is not a property of data row $($i + 1). Fields: $($dp.PSBase.Keys -join ', ')" }
        $k = & $text $dp[$KeyField]
        if (-not $seen.Add($k)) { if ($dupData.Count -lt 5) { $dupData.Add($k) }; $i++; continue }
        if (-not $baseByKey.ContainsKey($k)) {
            $changes["$i"] = [ordered]@{ State = 'new'; Fields = @(); Was = [ordered]@{} }; $nNew++
        } else {
            $bp = $baseByKey[$k]; $diff = [System.Collections.Generic.List[string]]::new(); $was = [ordered]@{}
            $cmp = if (@($Fields).Count) { @($Fields) } else { @($dp.PSBase.Keys) | Where-Object { $_ -ne $KeyField } }
            foreach ($f in $cmp) {
                if ($f -eq $KeyField) { continue }
                $av = if ($dp.Contains($f)) { $dp[$f] } else { $null }
                $ov = if ($bp.Contains($f)) { $bp[$f] } else { $null }
                if (($av -is [datetime] -and $ov -is [string]) -or ($av -is [string] -and $ov -is [datetime])) {
                    if ($typeClash.ContainsKey($f)) { $typeClash[$f]++ } else { $typeClash[$f] = 1 }
                }
                $a = & $text $av
                $o = & $text $ov
                # 2.5.3: a number on one side and text on the other (a baseline read with Import-Csv) that differ as text
                # but read as the same number - an it-IT Export-Csv writes 1.5 as '1,5' - would show as Changed
                if ($a -cne $o) {
                    $numPair = if ((& $isNum $av) -and $ov -is [string]) { @($av, $ov) } elseif ((& $isNum $ov) -and $av -is [string]) { @($ov, $av) } else { $null }
                    if ($numPair -and (& $sameNum $numPair[0] $numPair[1])) {
                        if ($numClash.ContainsKey($f)) { $numClash[$f]++ } else { $numClash[$f] = 1 }
                    }
                }
                if ($a -cne $o) { $diff.Add($f); $was[$f] = $(if ($bp.Contains($f)) { $bp[$f] } else { $null }) }
            }
            if ($diff.Count) { $changes["$i"] = [ordered]@{ State = 'changed'; Fields = @($diff); Was = $was }; $nChanged++ } else { $nSame++ }
        }
        $i++
    }
    if ($dupData.Count) { throw "$who -KeyField '$KeyField': duplicate value(s) in the data: $($dupData -join ', '). A key must identify one row." }
    $removed = [System.Collections.Generic.List[object]]::new()
    foreach ($k in $baseByKey.PSBase.Keys) { if (-not $seen.Contains($k)) { $removed.Add($baseByKey[$k]) } }
    if (-not $Baseline.Count) { $warnings.Add('The baseline is empty: every row is New.') }
    foreach ($f in $typeClash.PSBase.Keys) {
        $warnings.Add("'$f' is a date on one side and text on the other in $($typeClash[$f]) row(s) (a baseline read with Import-Csv keeps dates as text), so it can show as Changed when nothing changed. Save the baseline with Export-Clixml to keep the types, or convert the column before comparing.")
    }
    foreach ($f in $numClash.PSBase.Keys) {
        $warnings.Add("'$f' is a number on one side and text in another format on the other in $($numClash[$f]) row(s) (for example 1.5 and '1,5' from an Import-Csv baseline), so those rows show as Changed although the value is the same. Save the baseline with Export-Clixml to keep the types, or convert the column before comparing.")
    }
    [ordered]@{
        Changes  = $changes
        Removed  = @($removed)
        Counts   = [ordered]@{ New = $nNew; Changed = $nChanged; Removed = $removed.Count; Same = $nSame }
        Warnings = @($warnings)
    }
}