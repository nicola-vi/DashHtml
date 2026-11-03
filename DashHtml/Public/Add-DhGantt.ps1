function Add-DhGantt {
    <#
    .SYNOPSIS
        Add a Gantt timeline - one bar per task from Start to End on a shared time axis (v3.1.0).

    .DESCRIPTION
        Rows of start/end bars, grouped into lanes, coloured by status or category, with
        milestones, critical-path marks, vertical marker lines and shaded bands. The axis
        runs from seconds to years: backup and job windows, patch and migration waves,
        certificate and contract validity, boot order, project plans.

        Two ways to supply data, mutually exclusive:

          -Items     explicit tasks (static)
          -TableId   one bar per row of a table already added to the report. The chart
                     follows the table's filters, like a table-fed bar chart.

        Time rule: the browser never parses a date. Every Start / End / marker / band is
        turned into seconds from an origin here, in PowerShell, and the page draws the
        wall clock those values carry, whatever the reader's time zone. A [DateTimeOffset]
        shows its own clock (.DateTime); a [datetime] is taken as given (its Kind is not
        converted). A bar across a daylight-saving change is placed by wall clock.

    .PARAMETER Report
        Dashboard object from New-DhDashboard.

    .PARAMETER Id
        Unique identifier (alphanumeric, dash, underscore).

    .PARAMETER Title
        Block heading.

    .PARAMETER Items
        Tasks. Array of hashtables:

          @{
              Label     = 'Restore database'      # required: the bar (and row) text
              Start     = [datetime] | '2026-11-03 22:00' | 0      # required
              End       = [datetime] | '...' | 446                 # missing: a milestone (diamond)
              Id        = 'db'                    # unique; needed by DependsOn
              Group     = 'Applications'          # lane header
              Row       = 'srv-db01'              # items with the same Row share a line
              Status    = 'ok'                    # ok | warn | danger | info | nodata (and the usual aliases)
              Category  = 'Full backup'           # colour from the chart palette, with a legend (ignored with Status)
              Critical  = $true                   # marked as critical path
              Text      = '7m 26s'                # replaces the automatic duration text
              Tooltip   = 'extra line'
              DependsOn = @('net')                # Ids, shown as "after: ..."
              Detail    = <drawer spec>           # text, a section, sections, or @{ Title; Subtitle; Sections }
              LinkTableId = 'jobs'; LinkFilter = 'srv-db01'
          }

        Start and End are all dates (a [datetime], a [DateTimeOffset] or an invariant date
        string such as '2026-11-03 22:00' or '2026-11-03T22:00:00') or all numbers (elapsed
        -Unit). A string that reads as a number is a number. Mixing the two throws.

    .PARAMETER TableId
        Source table (add it first). One bar per row; rows whose start does not read as a
        date or number are left out and counted in a note under the chart.

    .PARAMETER LabelField
        Column with the bar text.

    .PARAMETER StartField
        Column with the start.

    .PARAMETER EndField
        Column with the end. Empty or missing: the row is a milestone.

    .PARAMETER GroupField
        Column whose value is the lane.

    .PARAMETER RowField
        Column whose value is the row: bars with the same value share a line (for example
        every job of one backup client).

    .PARAMETER StatusField
        Column with ok / warn / danger / info / nodata (or the usual aliases).

    .PARAMETER CategoryField
        Column whose value picks the bar colour from the chart palette.

    .PARAMETER Origin
        Zero of the elapsed axis. 'first' (default): the earliest start. A date: the axis
        clock starts there, and numeric items become offsets from it (so they can show a
        clock axis too).

    .PARAMETER AxisFormat
        Auto (default): Clock below two days of span, Date above, Elapsed for numbers
        without a date -Origin. Clock and Date need dates or a date -Origin.

    .PARAMETER Unit
        Unit of numeric Start / End / markers: s (default), min, h or d.

    .PARAMETER Markers
        Vertical lines: @(@{ At = <date or number>; Label = 'RTO target'; Status = 'warn' }).

    .PARAMETER Bands
        Shaded windows: @(@{ From = ...; To = ...; Label = 'Backup window' }).

    .PARAMETER SortBy
        None (declaration / table order, default), Start, End, Duration or Label. Rows are
        sorted inside their lane.

    .PARAMETER ShowDuration
        Show the duration (or Text) next to each bar. Default $true.

    .PARAMETER ShowDataTable
        A "Show data table" toggle under the chart: every task with start, end, duration and
        status. The accessible and printable alternative.

    .PARAMETER MaxItems
        Bars drawn at most (default 500). Mode A warns above it and draws the first ones;
        the page says how many were left out. Mode B draws the first -MaxItems filtered rows.

    .PARAMETER Legend
        Show the legend (statuses, categories, critical path, milestone). Default $true.

    .EXAMPLE
        # Steps of a recovery test on a clock axis, with a target line
        Add-DhGantt -Report $report -Id 'steps' -Title 'Recovery steps' -Items @(
            @{ Label = 'Storage';      Start = '2026-11-03 07:19:02'; End = '2026-11-03 07:23:31'; Status = 'ok' }
            @{ Label = 'Compute';      Start = '2026-11-03 07:23:32'; End = '2026-11-03 08:15:06'; Status = 'ok'; Critical = $true }
            @{ Label = 'Applications'; Start = '2026-11-03 08:15:06'; End = '2026-11-03 08:32:48'; Status = 'warn' }
        ) -Markers @(@{ At = '2026-11-03 08:30'; Label = 'RTO target'; Status = 'warn' })

    .EXAMPLE
        # Nightly backup jobs from a table, one line per client, with the backup window
        Add-DhGantt -Report $report -Id 'jobs-g' -Title 'Last night' -TableId 'jobs' `
            -LabelField 'Job' -StartField 'Started' -EndField 'Ended' -RowField 'Client' `
            -StatusField 'Result' -Bands @(@{ From = $night; To = $night.AddHours(8); Label = 'Backup window' })

    .EXAMPLE
        # Elapsed seconds from a common origin
        Add-DhGantt -Report $report -Id 'boot' -Title 'Start order' -Unit s -Items @(
            @{ Label = 'Database'; Start = 0;   End = 446; Critical = $true; Id = 'db' }
            @{ Label = 'Web';      Start = 451; End = 573; DependsOn = 'db' }
        )
    #>
    [CmdletBinding(DefaultParameterSetName = 'Items')]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string] $Id,
        [Parameter(Mandatory)] [string] $Title,

        # ---- Mode A: explicit tasks ----
        [Parameter(Mandatory, ParameterSetName = 'Items')] [object[]] $Items,

        # ---- Mode B: one bar per table row ----
        [Parameter(Mandatory, ParameterSetName = 'FromTable')] [string] $TableId,
        [Parameter(Mandatory, ParameterSetName = 'FromTable')] [string] $LabelField,
        [Parameter(Mandatory, ParameterSetName = 'FromTable')] [string] $StartField,
        [Parameter(ParameterSetName = 'FromTable')] [string] $EndField      = '',
        [Parameter(ParameterSetName = 'FromTable')] [string] $GroupField    = '',
        [Parameter(ParameterSetName = 'FromTable')] [string] $RowField      = '',
        [Parameter(ParameterSetName = 'FromTable')] [string] $StatusField   = '',
        [Parameter(ParameterSetName = 'FromTable')] [string] $CategoryField = '',

        # ---- Axis and presentation ----
        [object] $Origin = 'first',
        [ValidateSet('Auto','Clock','Date','Elapsed')]
        [string] $AxisFormat = 'Auto',
        [ValidateSet('s','min','h','d')]
        [string] $Unit = 's',
        [object[]] $Markers = @(),
        [object[]] $Bands   = @(),
        [ValidateSet('None','Start','End','Duration','Label')]
        [string] $SortBy = 'None',
        [bool]   $ShowDuration = $true,
        [switch] $ShowDataTable,
        [ValidateRange(1, 2000)]
        [int]    $MaxItems = 500,
        [bool]   $Legend = $true,
        [bool]   $Collapsible = $true,    # wrap the block in a collapsible header (chevron + click-to-toggle)
        [bool]   $DefaultOpen = $true,    # whether the collapsible body starts expanded (only used when -Collapsible is $true)
        [ValidateRange(0,12)]
        [int]    $GridSpan    = 0,        # columns (1-12) to span in -report-grid layout; 0 = default flow
        [string] $NavPath     = '',       # 'A/B/C' - where this item lives. '//' escapes a literal '/'
        [ValidateSet('','Exact','Subtree','Global')]
        [string] $NavScope    = '',       # Exact (default) | Subtree (this node and below) | Global (everywhere)
        [string] $NavLabel    = '',       # display text for this node, decoupled from the path key
        [int]    $NavOrder    = 0         # explicit sibling ordering; 0 = declaration order
    )

    $navDecl = Resolve-DhNavDeclaration -NavPath $NavPath -NavScope $NavScope -ItemKind 'Block' -Context 'Add-DhGantt'
    if (-not $Report.Contains('_DhNavSeq')) { $Report['_DhNavSeq'] = 0 }
    $navSeqNo = [int]$Report['_DhNavSeq']; $Report['_DhNavSeq'] = $navSeqNo + 1

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhGantt: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }

    $inv      = [System.Globalization.CultureInfo]::InvariantCulture
    $epoch    = [datetime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Unspecified)
    $unitSec  = switch ($Unit) { 's' { 1.0 } 'min' { 60.0 } 'h' { 3600.0 } 'd' { 86400.0 } }
    $numStyle = [System.Globalization.NumberStyles]::Float

    # One time value -> @{ K = 'date' | 'number'; V = seconds } (dates: wall-clock seconds since
    # 1970-01-01, the Kind ignored; numbers: seconds), $null when empty, K = 'bad' when unreadable.
    function _gtTime {
        param([AllowNull()] [object] $Value)
        if ($null -eq $Value) { return $null }
        if ($Value -is [System.Management.Automation.PSObject]) { $Value = $Value.PSObject.BaseObject }
        if ($Value -is [DateTimeOffset]) { return @{ K = 'date'; V = ($Value.DateTime - $epoch).TotalSeconds } }
        if ($Value -is [datetime])       { return @{ K = 'date'; V = ($Value - $epoch).TotalSeconds } }
        if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal] -or
            $Value -is [single] -or $Value -is [int16] -or $Value -is [byte]) {
            return @{ K = 'number'; V = [double]$Value * $unitSec }
        }
        $s = ([string]$Value).Trim()
        if ($s -eq '') { return $null }
        $n = 0.0
        if ([double]::TryParse($s, $numStyle, $inv, [ref]$n)) { return @{ K = 'number'; V = $n * $unitSec } }
        $dto = [DateTimeOffset]::MinValue
        if ([DateTimeOffset]::TryParse($s, $inv, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$dto)) {
            return @{ K = 'date'; V = ($dto.DateTime - $epoch).TotalSeconds }
        }
        return @{ K = 'bad'; V = 0.0 }
    }
    function _gtNum([double] $v) { $v.ToString('R', $inv) }

    $mode  = $PSCmdlet.ParameterSetName
    $kind  = ''                 # 'date' | 'number', set by the first value seen
    $norm  = [System.Collections.Generic.List[object]]::new()
    $times = $null              # mode B: per table row [start, end] or $null

    # ---- Origin ---------------------------------------------------------------------------
    $originWall = $null
    if (-not ($Origin -is [string] -and $Origin -eq 'first')) {
        $o = _gtTime $Origin
        if ($null -eq $o -or $o.K -ne 'date') {
            throw "Add-DhGantt: -Origin must be 'first' or a date. Got: $Origin"
        }
        $originWall = [double]$o.V
    }

    if ($mode -eq 'Items') {
        if (@($Items).Count -lt 1) { throw "Add-DhGantt: -Items must contain at least one task." }
        $ids = @{}
        $i = 0
        foreach ($item in $Items) {
            $i++
            if ($item -isnot [System.Collections.IDictionary]) {
                throw "Add-DhGantt: each item must be a hashtable. Item $i is a $($item.GetType().Name)."
            }
            $label = if ($item.Contains('Label')) { [string]$item['Label'] } else { '' }
            if ([string]::IsNullOrWhiteSpace($label)) { throw "Add-DhGantt: item $i has no Label." }
            $ctx = "item $i ('$label')"
            $st = _gtTime $(if ($item.Contains('Start')) { $item['Start'] } else { $null })
            if ($null -eq $st) { throw "Add-DhGantt: $ctx has no Start." }
            if ($st.K -eq 'bad') { throw "Add-DhGantt: $ctx - Start '$($item['Start'])' is neither a date nor a number." }
            $en = _gtTime $(if ($item.Contains('End')) { $item['End'] } else { $null })
            if ($null -ne $en -and $en.K -eq 'bad') { throw "Add-DhGantt: $ctx - End '$($item['End'])' is neither a date nor a number." }
            if (-not $kind) { $kind = $st.K }
            foreach ($t in @($st, $en)) {
                if ($null -ne $t -and $t.K -ne $kind) {
                    throw "Add-DhGantt: $ctx mixes dates and numbers; use one kind of Start / End in a chart."
                }
            }
            if ($null -ne $en -and $en.V -lt $st.V) { throw "Add-DhGantt: $ctx ends before it starts." }

            $itemId = if ($item.Contains('Id') -and $item['Id']) { [string]$item['Id'] } else { '' }
            if ($itemId) {
                if ($ids.ContainsKey($itemId)) { throw "Add-DhGantt: duplicate item Id '$itemId'." }
                $ids[$itemId] = $label
            }
            $detail = ConvertTo-DhDetailSpec -Detail $(if ($item.Contains('Detail')) { $item['Detail'] } else { $null }) -Context "Add-DhGantt '$Id' $ctx"
            $norm.Add([ordered]@{
                Label       = $label
                S           = [double]$st.V
                E           = $(if ($null -ne $en) { [double]$en.V } else { $null })
                Id          = $itemId
                Group       = $(if ($item.Contains('Group'))    { [string]$item['Group'] }    else { '' })
                Row         = $(if ($item.Contains('Row'))      { [string]$item['Row'] }      else { '' })
                Status      = ConvertTo-DhStatusName $(if ($item.Contains('Status')) { $item['Status'] } else { $null })
                Category    = $(if ($item.Contains('Category')) { [string]$item['Category'] } else { '' })
                Critical    = [bool]($item.Contains('Critical') -and $item['Critical'])
                Text        = $(if ($item.Contains('Text'))     { [string]$item['Text'] }     else { '' })
                Tooltip     = $(if ($item.Contains('Tooltip'))  { [string]$item['Tooltip'] }  else { '' })
                DependsOn   = @($(if ($item.Contains('DependsOn') -and $null -ne $item['DependsOn']) { @($item['DependsOn']) | ForEach-Object { [string]$_ } | Where-Object { $_ } }))
                Detail      = $detail
                LinkTableId = $(if ($item.Contains('LinkTableId')) { [string]$item['LinkTableId'] } else { '' })
                LinkFilter  = $(if ($item.Contains('LinkFilter'))  { [string]$item['LinkFilter'] }  else { '' })
            })
        }
        # DependsOn names Ids of this chart; shown as the labels they point at
        foreach ($n in $norm) {
            $after = foreach ($d in $n.DependsOn) {
                if (-not $ids.ContainsKey($d)) { throw "Add-DhGantt: item '$($n.Label)' depends on unknown Id '$d'." }
                $ids[$d]
            }
            $n['After'] = @($after)
        }
        if ($norm.Count -gt $MaxItems) {
            Write-Warning "Add-DhGantt '$Id': $($norm.Count) items, over -MaxItems ($MaxItems). The chart draws the first $MaxItems and says how many were left out."
        }
    }
    else {
        $tbl = $null
        if ($Report.Contains('Tables') -and $Report.Tables) { $tbl = $Report.Tables | Where-Object { $_.Id -eq $TableId } | Select-Object -First 1 }
        if (-not $tbl) { throw "Add-DhGantt: Source table '$TableId' not found. Add the table before the Gantt chart." }
        $known = Get-DhTableFieldNames -Table $tbl
        foreach ($pair in @(
                @{ N = 'LabelField'; V = $LabelField }, @{ N = 'StartField'; V = $StartField }, @{ N = 'EndField'; V = $EndField },
                @{ N = 'GroupField'; V = $GroupField }, @{ N = 'RowField'; V = $RowField },
                @{ N = 'StatusField'; V = $StatusField }, @{ N = 'CategoryField'; V = $CategoryField })) {
            if ($pair.V -and $pair.V -cnotin $known) {
                throw "Add-DhGantt: -$($pair.N) '$($pair.V)' is not a field of table '$TableId'. Known fields: $(($known | Sort-Object) -join ', ')"
            }
        }
        # Every row's start / end in seconds, by row position: the page reads them instead of
        # parsing the cells (a [datetime] cell reaches the browser in the invariant US format).
        $times = [System.Collections.Generic.List[object]]::new()
        $skipped = 0
        foreach ($r in @($tbl.Data)) {
            $sv = if ($r -is [System.Collections.IDictionary] -and $r.Contains($StartField)) { $r[$StartField] } else { $null }
            $ev = if ($EndField -and $r -is [System.Collections.IDictionary] -and $r.Contains($EndField)) { $r[$EndField] } else { $null }
            $st = _gtTime $sv
            $en = _gtTime $ev
            $ok = $null -ne $st -and $st.K -ne 'bad' -and ($null -eq $en -or $en.K -ne 'bad')
            if ($ok -and -not $kind) { $kind = $st.K }
            if ($ok) { $ok = $st.K -eq $kind -and ($null -eq $en -or $en.K -eq $kind) }
            if ($ok -and $null -ne $en -and $en.V -lt $st.V) { $ok = $false }
            if ($ok) { $times.Add(@([double]$st.V, $(if ($null -ne $en) { [double]$en.V } else { $null }))) }
            else     { $times.Add($null); $skipped++ }
        }
        if ($times.Count -gt 0 -and $skipped -eq $times.Count) {
            throw "Add-DhGantt: no row of table '$TableId' has a '$StartField' that reads as a date or a number."
        }
        if ($skipped -gt 0) {
            Write-Warning "Add-DhGantt '$Id': $skipped of $($times.Count) rows of '$TableId' have no valid start / end (empty, unreadable, a different kind, or ending before they start). They are left out of the chart."
        }
    }

    # ---- Markers and bands (same kind as the tasks) ------------------------------------------
    $mkNorm = foreach ($m in @($Markers)) {
        if ($null -eq $m) { continue }
        if ($m -isnot [System.Collections.IDictionary]) { throw "Add-DhGantt: each marker must be a hashtable @{ At; Label; Status }." }
        $t = _gtTime $(if ($m.Contains('At')) { $m['At'] } else { $null })
        if ($null -eq $t -or $t.K -eq 'bad') { throw "Add-DhGantt: marker '$($m['Label'])' needs an At that is a date or a number." }
        if ($kind -and $t.K -ne $kind) { throw "Add-DhGantt: marker '$($m['Label'])' is a $($t.K), the tasks are $($kind)s." }
        [ordered]@{ V = [double]$t.V; Label = [string]$m['Label']; Status = ConvertTo-DhStatusName $(if ($m.Contains('Status')) { $m['Status'] } else { $null }) }
    }
    $bdNorm = foreach ($bd in @($Bands)) {
        if ($null -eq $bd) { continue }
        if ($bd -isnot [System.Collections.IDictionary]) { throw "Add-DhGantt: each band must be a hashtable @{ From; To; Label }." }
        $f = _gtTime $(if ($bd.Contains('From')) { $bd['From'] } else { $null })
        $t = _gtTime $(if ($bd.Contains('To'))   { $bd['To'] }   else { $null })
        if ($null -eq $f -or $null -eq $t -or $f.K -eq 'bad' -or $t.K -eq 'bad') { throw "Add-DhGantt: band '$($bd['Label'])' needs From and To that are dates or numbers." }
        if ($kind -and ($f.K -ne $kind -or $t.K -ne $kind)) { throw "Add-DhGantt: band '$($bd['Label'])' is not the same kind (date or number) as the tasks." }
        if ($t.V -lt $f.V) { throw "Add-DhGantt: band '$($bd['Label'])' ends before it starts." }
        [ordered]@{ From = [double]$f.V; To = [double]$t.V; Label = [string]$bd['Label'] }
    }
    $mkNorm = @($mkNorm); $bdNorm = @($bdNorm)

    # ---- Origin and axis ---------------------------------------------------------------------
    # Dates: every value becomes seconds from the origin (the earliest start unless -Origin).
    # Numbers: seconds as given; a date -Origin only lends them a clock.
    # @(...) around the if: a one-item chart would otherwise unroll to a scalar
    $starts = @(if ($mode -eq 'Items') { $norm | ForEach-Object { $_.S } } else { $times | Where-Object { $null -ne $_ } | ForEach-Object { $_[0] } })
    $shift = 0.0
    if ($kind -eq 'date') {
        if ($null -eq $originWall) { $originWall = [double](($starts | Measure-Object -Minimum).Minimum) }
        $shift = $originWall
    }
    $ends = @(if ($mode -eq 'Items') { $norm | ForEach-Object { if ($null -ne $_.E) { $_.E } else { $_.S } } } else { $times | Where-Object { $null -ne $_ } | ForEach-Object { if ($null -ne $_[1]) { $_[1] } else { $_[0] } } })
    $span = 0.0
    if ($starts.Count) { $span = [double](($ends | Measure-Object -Maximum).Maximum) - [double](($starts | Measure-Object -Minimum).Minimum) }

    $axis = $AxisFormat
    if ($axis -eq 'Auto') {
        $axis = if ($null -eq $originWall) { 'Elapsed' } elseif ($span -lt 172800) { 'Clock' } else { 'Date' }
    }
    elseif ($axis -ne 'Elapsed' -and $null -eq $originWall) {
        throw "Add-DhGantt: -AxisFormat $axis needs dates, or numbers with a date -Origin."
    }

    # ---- JSON (built here; Export-DhDashboard only places it) --------------------------------
    $q = { param($s) ConvertTo-DhJsonString ([string]$s) }
    $itemsJson = ''
    if ($mode -eq 'Items') {
        $itemsJson = (@($norm) | ForEach-Object {
            $n = $_
            $x = ''
            if ($null -ne $n.E)  { $x += ',"e":' + (_gtNum ($n.E - $shift)) }
            if ($n.Id)           { $x += ',"id":' + (& $q $n.Id) }
            if ($n.Group)        { $x += ',"group":' + (& $q $n.Group) }
            if ($n.Row)          { $x += ',"row":' + (& $q $n.Row) }
            if ($n.Status)       { $x += ',"status":' + (& $q $n.Status) }
            if ($n.Category)     { $x += ',"category":' + (& $q $n.Category) }
            if ($n.Critical)     { $x += ',"critical":true' }
            if ($n.Text)         { $x += ',"text":' + (& $q $n.Text) }
            if ($n.Tooltip)      { $x += ',"tooltip":' + (& $q $n.Tooltip) }
            if (@($n.After).Count) { $x += ',"after":[' + ((@($n.After) | ForEach-Object { & $q $_ }) -join ',') + ']' }
            if ($n.Detail)       { $x += ',"detail":' + (ConvertTo-DhDetailJson $n.Detail) }
            if ($n.LinkTableId)  { $x += ',"linkTableId":' + (& $q $n.LinkTableId) }
            if ($n.LinkFilter)   { $x += ',"linkFilter":' + (& $q $n.LinkFilter) }
            "{`"label`":$(& $q $n.Label),`"s`":$(_gtNum ($n.S - $shift))$x}"
        }) -join ','
    }
    $timesJson = ''
    if ($mode -eq 'FromTable') {
        $sb = [System.Text.StringBuilder]::new()
        $first = $true
        foreach ($t in $times) {
            if (-not $first) { [void]$sb.Append(',') }
            $first = $false
            if ($null -eq $t) { [void]$sb.Append('null') }
            elseif ($null -eq $t[1]) { [void]$sb.Append('[').Append((_gtNum ($t[0] - $shift))).Append(']') }
            else { [void]$sb.Append('[').Append((_gtNum ($t[0] - $shift))).Append(',').Append((_gtNum ($t[1] - $shift))).Append(']') }
        }
        $timesJson = $sb.ToString()
    }
    $mkJson = (@($mkNorm) | ForEach-Object {
        $x = if ($_.Status) { ',"status":' + (& $q $_.Status) } else { '' }
        "{`"at`":$(_gtNum ($_.V - $shift)),`"label`":$(& $q $_.Label)$x}"
    }) -join ','
    $bdJson = (@($bdNorm) | ForEach-Object {
        "{`"from`":$(_gtNum ($_.From - $shift)),`"to`":$(_gtNum ($_.To - $shift)),`"label`":$(& $q $_.Label)}"
    }) -join ','

    $fields = ''
    if ($mode -eq 'FromTable') {
        $fields = ",`"tableId`":$(& $q $TableId),`"labelField`":$(& $q $LabelField)"
        foreach ($pair in @(@('groupField', $GroupField), @('rowField', $RowField), @('statusField', $StatusField), @('categoryField', $CategoryField))) {
            if ($pair[1]) { $fields += ",`"$($pair[0])`":$(& $q $pair[1])" }
        }
        $fields += ",`"times`":[$timesJson]"
    }
    $originJson = if ($null -ne $originWall) { _gtNum $originWall } else { 'null' }
    $json = "`"mode`":$(if ($mode -eq 'Items') { '"items"' } else { '"fromtable"' }),`"axis`":$(& $q $axis.ToLowerInvariant()),`"origin`":$originJson," +
            "`"sortBy`":$(& $q $SortBy.ToLowerInvariant()),`"showDuration`":$(([bool]$ShowDuration).ToString().ToLower()),`"showDataTable`":$(([bool]$ShowDataTable).ToString().ToLower())," +
            "`"maxItems`":$MaxItems,`"legend`":$(([bool]$Legend).ToString().ToLower()),`"items`":[$itemsJson],`"markers`":[$mkJson],`"bands`":[$bdJson]$fields"

    $Report.Blocks.Add([ordered]@{
        BlockType     = 'gantt'
        Id            = $Id
        Title         = $Title
        Mode          = $(if ($mode -eq 'Items') { 'items' } else { 'fromtable' })
        Items         = $(if ($mode -eq 'Items') { @($Items) } else { @() })   # as given, so ConvertTo-DhYaml round-trips them
        TableId       = $TableId
        LabelField    = $LabelField
        StartField    = $StartField
        EndField      = $EndField
        GroupField    = $GroupField
        RowField      = $RowField
        StatusField   = $StatusField
        CategoryField = $CategoryField
        AxisFormat    = $AxisFormat
        Origin        = $Origin
        Unit          = $Unit
        Markers       = $Markers
        Bands         = $Bands
        SortBy        = $SortBy
        ShowDuration  = $ShowDuration
        ShowDataTable = [bool]$ShowDataTable
        MaxItems      = $MaxItems
        Legend        = $Legend
        GanttJson     = $json                # the browser JSON, seconds from the origin (ConvertTo-DhYaml drops it)
        NavPath       = $NavPath
        NavSegments   = $navDecl.Path
        NavSeqNo      = $navSeqNo
        NavScope      = $navDecl.Scope
        NavLabel      = $NavLabel
        NavOrder      = $NavOrder
        GridSpan      = $GridSpan
        Collapsible   = $Collapsible
        DefaultOpen   = $DefaultOpen
    })
    Write-Verbose "Add-DhGantt: '$Id' - $(if ($mode -eq 'Items') { "$($norm.Count) items" } else { "from table '$TableId'" }), $kind values, $axis axis."
}
