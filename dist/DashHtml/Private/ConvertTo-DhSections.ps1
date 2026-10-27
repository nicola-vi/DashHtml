function ConvertTo-DhStatusName {
    <#
    .SYNOPSIS  Normalise a status word or a cell-* class to a lower-case status name (v2.3.0).
    .DESCRIPTION
        'cell-ok' -> 'ok', 'Critical' -> 'critical', $null -> ''. The browser maps the
        word to one of ok / warn / danger / info / nodata and shows anything it does not
        know as nodata, so this never throws: a typo is a grey chip, not a failed export.
    #>
    [OutputType([string])]
    param([AllowNull()] $Value)
    if ($null -eq $Value) { return '' }
    return ([string]$Value).Trim().ToLowerInvariant() -replace '^cell-', ''
}

function ConvertTo-DhSections {
    <#
    .SYNOPSIS  Validate and normalise a list of detail-section specs (v2.3.0).
    .DESCRIPTION
        One section spec is shared by the detail drawer (Add-DhTable -DetailSections),
        Add-DhKeyValue, Add-DhRecordList and the findings split layout; the browser
        draws them all with the same renderSections() function.

            @{ Kind='kv';         Title='System'; Columns=2
               Items=@(@{ Label='Model'; Value='VMware20,1'; Status='ok' }) }
            @{ Kind='bars';       Title='Resources'; Max=100; Unit='%'
               Items=@(@{ Label='CPU'; Value=2; Status='ok' }) }
            @{ Kind='statusList'; Items=@(@{ Label='NTDS'; Status='ok'; Text='Running' }) }
            @{ Kind='checks';     Items=@(@{ Label='Connectivity'; Ok=$true; Note='' }) }
            @{ Kind='table';      Columns=@('Drive','Free'); Rows=@(,@('C:','73 GB')); MaxRows=50 }
            @{ Kind='text';       Text='Free-form paragraph.' }
            @{ Kind='links';      Items=@(@{ Label='MS Learn'; Url='https://learn.microsoft.com/' }) }

        Returns an array of ordered hashtables with lower-case Kind. Throws on a
        malformed spec, naming the context. Status values are normalised, not checked.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [AllowNull()] [object[]] $Sections,
        [Parameter(Mandatory)] [string] $Context
    )

    $kinds = 'kv', 'bars', 'statuslist', 'checks', 'table', 'text', 'links'
    $n = 0
    $out = foreach ($s in @($Sections)) {
        if ($null -eq $s) { continue }
        $n++
        if ($s -isnot [System.Collections.IDictionary]) {
            throw "${Context}: section #$n must be a hashtable. Got: $($s.GetType().Name)"
        }
        $kind = if ($s.Contains('Kind')) { ([string]$s['Kind']).Trim().ToLowerInvariant() } else { 'text' }
        if ($kind -notin $kinds) {
            throw "${Context}: section #$n has Kind '$($s['Kind'])'. Valid: kv, bars, statusList, checks, table, text, links."
        }
        $sc = "$Context section #$n ($kind)"
        $title = if ($s.Contains('Title')) { [string]$s['Title'] } else { '' }
        $items = @(if ($s.Contains('Items') -and $null -ne $s['Items']) { @($s['Items']) | Where-Object { $null -ne $_ } })

        $sec = [ordered]@{ Kind = $kind; Title = $title }
        switch ($kind) {
            'kv' {
                $cols = 2
                if ($s.Contains('Columns') -and $null -ne $s['Columns']) {
                    if (-not [int]::TryParse([string]$s['Columns'], [ref]$cols) -or $cols -lt 1 -or $cols -gt 6) {
                        throw "${sc}: Columns must be a whole number from 1 to 6. Got: $($s['Columns'])"
                    }
                }
                $sec['Columns'] = $cols
                $sec['Items'] = @(foreach ($it in $items) {
                    if ($it -isnot [System.Collections.IDictionary] -or -not $it.Contains('Label')) { throw "${sc}: each item must be @{ Label; Value; Status }." }
                    $st = if ($it.Contains('Status')) { $it['Status'] } elseif ($it.Contains('Class')) { $it['Class'] } else { $null }
                    [ordered]@{
                        Label  = [string]$it['Label']
                        Value  = if ($it.Contains('Value') -and $null -ne $it['Value']) { [string]$it['Value'] } else { '' }
                        Status = ConvertTo-DhStatusName $st
                    }
                })
            }
            'bars' {
                $max = 0.0
                if ($s.Contains('Max') -and $null -ne $s['Max']) {
                    if (-not [double]::TryParse([string]$s['Max'], [System.Globalization.NumberStyles]::Float, [cultureinfo]::InvariantCulture, [ref]$max) -or $max -lt 0) {
                        throw "${sc}: Max must be a number >= 0. Got: $($s['Max'])"
                    }
                }
                $sec['Max']  = $max
                $sec['Unit'] = if ($s.Contains('Unit')) { [string]$s['Unit'] } else { '' }
                $sec['Items'] = @(foreach ($it in $items) {
                    if ($it -isnot [System.Collections.IDictionary] -or -not $it.Contains('Label')) { throw "${sc}: each item must be @{ Label; Value; Status; Display }." }
                    $v = $null
                    if ($it.Contains('Value') -and $null -ne $it['Value'] -and [string]$it['Value'] -ne '') {
                        $d = 0.0
                        if (-not [double]::TryParse([string]$it['Value'], [System.Globalization.NumberStyles]::Float, [cultureinfo]::InvariantCulture, [ref]$d)) {
                            throw "${sc}: item '$($it['Label'])' has a non-numeric Value '$($it['Value'])'."
                        }
                        $v = $d
                    }
                    $st = if ($it.Contains('Status')) { $it['Status'] } elseif ($it.Contains('Class')) { $it['Class'] } else { $null }
                    [ordered]@{
                        Label   = [string]$it['Label']
                        Value   = $v
                        Display = if ($it.Contains('Display') -and $null -ne $it['Display']) { [string]$it['Display'] } else { $null }
                        Status  = ConvertTo-DhStatusName $st
                    }
                })
            }
            'statuslist' {
                $sec['Items'] = @(foreach ($it in $items) {
                    if ($it -isnot [System.Collections.IDictionary] -or -not $it.Contains('Label')) { throw "${sc}: each item must be @{ Label; Status; Text }." }
                    [ordered]@{
                        Label  = [string]$it['Label']
                        Status = ConvertTo-DhStatusName $(if ($it.Contains('Status')) { $it['Status'] } else { $null })
                        Text   = if ($it.Contains('Text') -and $null -ne $it['Text']) { [string]$it['Text'] } else { $null }
                    }
                })
            }
            'checks' {
                $sec['Items'] = @(foreach ($it in $items) {
                    if ($it -isnot [System.Collections.IDictionary] -or -not $it.Contains('Label')) { throw "${sc}: each item must be @{ Label; Ok; Status; Note }." }
                    $ok = $null
                    if ($it.Contains('Ok') -and $null -ne $it['Ok']) { $ok = [bool]$it['Ok'] }
                    [ordered]@{
                        Label  = [string]$it['Label']
                        Ok     = $ok
                        Status = ConvertTo-DhStatusName $(if ($it.Contains('Status')) { $it['Status'] } else { $null })
                        Note   = if ($it.Contains('Note') -and $null -ne $it['Note']) { [string]$it['Note'] } else { '' }
                    }
                })
            }
            'table' {
                if (-not $s.Contains('Columns') -or @($s['Columns']).Count -eq 0) { throw "${sc}: a table section needs Columns." }
                $sec['Columns'] = @(@($s['Columns']) | ForEach-Object { [string]$_ })
                $mr = 50
                if ($s.Contains('MaxRows') -and $null -ne $s['MaxRows']) {
                    if (-not [int]::TryParse([string]$s['MaxRows'], [ref]$mr) -or $mr -lt 1) { throw "${sc}: MaxRows must be a whole number >= 1. Got: $($s['MaxRows'])" }
                }
                $sec['MaxRows'] = $mr
                $rowList = [System.Collections.Generic.List[object]]::new()
                foreach ($r in @($s['Rows'])) {
                    if ($null -eq $r) { continue }
                    $cells = foreach ($c in @($r)) {
                        if ($c -is [System.Collections.IDictionary]) {
                            [ordered]@{ Text = [string]$c['Text']; Status = ConvertTo-DhStatusName $c['Status'] }
                        } else {
                            if ($null -eq $c) { '' } else { [string]$c }
                        }
                    }
                    $rowList.Add(@($cells))
                }
                $sec['Rows'] = $rowList.ToArray()
            }
            'links' {
                $sec['Items'] = @(foreach ($it in $items) {
                    if ($it -isnot [System.Collections.IDictionary]) { throw "${sc}: each item must be @{ Label; Url }." }
                    $url = Test-DhSafeActionUrl -Url ([string]$it['Url']) -Context "$sc link"
                    if (-not $url) { throw "${sc}: a link has no Url." }
                    [ordered]@{ Label = if ($it['Label']) { [string]$it['Label'] } else { $url }; Url = $url }
                })
            }
            'text' {
                $sec['Text'] = if ($s.Contains('Text')) { [string]$s['Text'] } else { '' }
            }
        }
        $sec
    }
    # The comma keeps a single section an array of one: without it the pipeline
    # unrolls it to the bare ordered dictionary, and .Count / [0] then mean keys.
    return , @($out)
}

function ConvertTo-DhDetailSpec {
    <#
    .SYNOPSIS  Normalise a "Detail" value to @{ Title; Subtitle; Sections } or $null (v2.3.0).
    .DESCRIPTION
        Accepted shapes, for a status-grid cell, a finding or a record:
          'multi-line text'                      one text section
          @{ Kind='kv'; Items=... }              one section
          @( @{Kind=..}, @{Kind=..} )            several sections
          @{ Title='..'; Subtitle='..'; Sections=@(...) }   the full form
        Empty input returns $null, so "no detail" costs nothing in the JSON.
    #>
    [CmdletBinding()]
    param([AllowNull()] $Detail, [Parameter(Mandatory)] [string] $Context)

    if ($null -eq $Detail) { return $null }
    $title = ''; $sub = ''; $secs = $null
    if ($Detail -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Detail)) { return $null }
        $secs = @(@{ Kind = 'text'; Text = $Detail })
    }
    elseif ($Detail -is [System.Collections.IDictionary]) {
        if ($Detail.Contains('Sections')) {
            $title = if ($Detail.Contains('Title')) { [string]$Detail['Title'] } else { '' }
            $sub   = if ($Detail.Contains('Subtitle')) { [string]$Detail['Subtitle'] } else { '' }
            $secs  = @($Detail['Sections'])
        }
        elseif ($Detail.Contains('Kind')) { $secs = @($Detail) }
        else { throw "${Context}: Detail hashtable needs Sections (or a Kind for a single section)." }
    }
    elseif ($Detail -is [System.Collections.IEnumerable]) { $secs = @($Detail) }
    else { throw "${Context}: Detail must be text, a section hashtable, or an array of sections. Got: $($Detail.GetType().Name)" }

    $norm = ConvertTo-DhSections -Sections $secs -Context "$Context Detail"
    if ($norm.Count -eq 0 -and -not $title) { return $null }
    return [ordered]@{ Title = $title; Subtitle = $sub; Sections = $norm }
}
