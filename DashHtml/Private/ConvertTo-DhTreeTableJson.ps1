<#
    Tree-table JSON (v3.0.0). Add-DhTreeTable takes up to 100,000 rows and as many
    memberships; the generic per-row pipeline spent most of a large export in
    ForEach-Object and function-call overhead (about 17 s for 50,000 rows, now 4).
    Each row is checked once for characters the escaper would rewrite; a plain row
    is written with one interpolated string, anything else goes through
    ConvertTo-DhJsonString, so the output is byte-identical to the generic path.
    Properties are read through .PSBase: a property may be named Count or Keys.
#>

function ConvertTo-DhTreeTableRowsJson {
    <# The rows array body (no brackets): {"id","parent","type","label","status"[,"flags"][,"props"][,"detail"]}, ... #>
    param([object[]] $Rows)
    $esc   = $script:DhJsonEscapeChars
    $parts = [System.Collections.Generic.List[string]]::new(@($Rows).Count)
    foreach ($tr in $Rows) {
        $id = [string]$tr.Id; $pa = [string]$tr.ParentId; $ty = [string]$tr.Type; $lb = [string]$tr.Label; $st = [string]$tr.Status
        $row = if (($id + $pa + $ty + $lb + $st).IndexOfAny($esc) -lt 0) {
            "{`"id`":`"$id`",`"parent`":`"$pa`",`"type`":`"$ty`",`"label`":`"$lb`",`"status`":`"$st`""
        } else {
            '{"id":' + (ConvertTo-DhJsonString $id) + ',"parent":' + (ConvertTo-DhJsonString $pa) + ',"type":' + (ConvertTo-DhJsonString $ty) +
                ',"label":' + (ConvertTo-DhJsonString $lb) + ',"status":' + (ConvertTo-DhJsonString $st)
        }
        $fl = @($tr.Flags)
        if ($fl.Count) {
            $row += if (($fl -join "`u{1}").IndexOfAny($esc) -lt 0) { ',"flags":["' + ($fl -join '","') + '"]' }
                    else { ',"flags":[' + ((@(foreach ($f in $fl) { ConvertTo-DhJsonString ([string]$f) })) -join ',') + ']' }
        }
        $pr = $tr.Properties
        if ($pr.PSBase.Count) {
            $pp = foreach ($k in $pr.PSBase.Keys) {
                $kl = [string]$k; $kv = [string]$pr[$k]
                if (($kl + $kv).IndexOfAny($esc) -lt 0) { "{`"label`":`"$kl`",`"value`":`"$kv`"}" }
                else { '{"label":' + (ConvertTo-DhJsonString $kl) + ',"value":' + (ConvertTo-DhJsonString $kv) + '}' }
            }
            $row += ',"props":[' + (@($pp) -join ',') + ']'
        }
        if ($tr.Detail) { $row += ',"detail":' + (ConvertTo-DhDetailJson $tr.Detail) }
        $parts.Add($row + '}')
    }
    return $parts -join ','
}

function ConvertTo-DhTreeTableLinksJson {
    <# The memberships array body: ["groupId","memberId"], ... #>
    param([object[]] $Links)
    $esc   = $script:DhJsonEscapeChars
    $parts = [System.Collections.Generic.List[string]]::new(@($Links).Count)
    foreach ($l in $Links) {
        $g = [string]$l.GroupId; $m = [string]$l.MemberId
        $parts.Add($(if (($g + $m).IndexOfAny($esc) -lt 0) { "[`"$g`",`"$m`"]" } else { '[' + (ConvertTo-DhJsonString $g) + ',' + (ConvertTo-DhJsonString $m) + ']' }))
    }
    return $parts -join ','
}
