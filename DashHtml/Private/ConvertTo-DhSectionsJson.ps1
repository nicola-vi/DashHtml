function ConvertTo-DhSectionsJson {
    <#
    .SYNOPSIS  Serialise normalised detail sections (see ConvertTo-DhSections) to a JSON array (v2.3.0).
    .DESCRIPTION
        Keys are lower-camel, in a fixed order, so the same input always gives the
        same bytes. Numbers use the invariant culture. Every string goes through
        ConvertTo-DhJsonString, so '</script' cannot break out of the page.
    #>
    [OutputType([string])]
    param([AllowNull()] [object[]] $Sections)

    $inv = [cultureinfo]::InvariantCulture
    $str = { param($s) ConvertTo-DhJsonString ([string]$s) }
    $parts = foreach ($s in @($Sections)) {
        if ($null -eq $s) { continue }
        $kind = [string]$s.Kind
        $head = "`"kind`":$(& $str $kind),`"title`":$(& $str $s.Title)"
        switch ($kind) {
            'kv' {
                $items = (@($s.Items) | ForEach-Object {
                    "{`"label`":$(& $str $_.Label),`"value`":$(& $str $_.Value),`"status`":$(& $str $_.Status)}"
                }) -join ','
                "{$head,`"columns`":$([int]$s.Columns),`"items`":[$items]}"
            }
            'bars' {
                $items = (@($s.Items) | ForEach-Object {
                    $v = if ($null -eq $_.Value) { 'null' } else { ([double]$_.Value).ToString('R', $inv) }
                    $d = if ($null -eq $_.Display) { 'null' } else { & $str $_.Display }
                    "{`"label`":$(& $str $_.Label),`"value`":$v,`"display`":$d,`"status`":$(& $str $_.Status)}"
                }) -join ','
                "{$head,`"max`":$(([double]$s.Max).ToString('R', $inv)),`"unit`":$(& $str $s.Unit),`"items`":[$items]}"
            }
            'statuslist' {
                $items = (@($s.Items) | ForEach-Object {
                    $t = if ($null -eq $_.Text) { 'null' } else { & $str $_.Text }
                    "{`"label`":$(& $str $_.Label),`"status`":$(& $str $_.Status),`"text`":$t}"
                }) -join ','
                "{$head,`"items`":[$items]}"
            }
            'checks' {
                $items = (@($s.Items) | ForEach-Object {
                    $ok = if ($null -eq $_.Ok) { 'null' } else { ([bool]$_.Ok).ToString().ToLowerInvariant() }
                    "{`"label`":$(& $str $_.Label),`"ok`":$ok,`"status`":$(& $str $_.Status),`"note`":$(& $str $_.Note)}"
                }) -join ','
                "{$head,`"items`":[$items]}"
            }
            'table' {
                $cols = (@($s.Columns) | ForEach-Object { & $str $_ }) -join ','
                $rows = (@($s.Rows) | ForEach-Object {
                    '[' + ((@($_) | ForEach-Object {
                        if ($_ -is [System.Collections.IDictionary]) { "{`"text`":$(& $str $_.Text),`"status`":$(& $str $_.Status)}" }
                        else { & $str $_ }
                    }) -join ',') + ']'
                }) -join ','
                "{$head,`"columns`":[$cols],`"maxRows`":$([int]$s.MaxRows),`"rows`":[$rows]}"
            }
            'links' {
                $items = (@($s.Items) | ForEach-Object { "{`"label`":$(& $str $_.Label),`"url`":$(& $str $_.Url)}" }) -join ','
                "{$head,`"items`":[$items]}"
            }
            default {
                "{$head,`"text`":$(& $str $s.Text)}"
            }
        }
    }
    return '[' + (@($parts) -join ',') + ']'
}

function ConvertTo-DhDetailJson {
    <#
    .SYNOPSIS  Serialise a normalised Detail spec (see ConvertTo-DhDetailSpec) to a JSON object, or 'null' (v2.3.0).
    #>
    [OutputType([string])]
    param([AllowNull()] $Detail)
    if ($null -eq $Detail) { return 'null' }
    return "{`"title`":$(ConvertTo-DhJsonString ([string]$Detail.Title)),`"subtitle`":$(ConvertTo-DhJsonString ([string]$Detail.Subtitle)),`"sections`":$(ConvertTo-DhSectionsJson $Detail.Sections)}"
}
