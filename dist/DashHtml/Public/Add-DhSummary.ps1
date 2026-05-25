function Add-DhSummary {
    <#
    .SYNOPSIS
        Add a row of KPI metric tiles at the top of the dashboard body.

    .DESCRIPTION
        Renders a horizontal strip of summary cards. Each tile shows an optional
        icon, a formatted value, a label, and an optional sub-label. Tiles can
        be coloured with the same threshold classes used on table cells.

        By default the strip is wrapped in a collapsible container (same chrome
        as Add-DhCollapsible) with a clickable header bar — handy when the
        dashboard has many tiles and you want to give viewers the option to
        fold them away. Pass -Collapsible:$false to render a flat strip with
        no header.

    .PARAMETER Report   Dashboard object from New-DhDashboard.

    .PARAMETER Items
        Array of tile definition hashtables:
          @{
              Label    = 'Caption text'    # REQUIRED
              Value    = 42               # REQUIRED — the main metric
              Icon     = 'X'              # optional emoji / unicode
              SubLabel = 'of 100 total'   # optional small text below label
              Class    = 'cell-danger'    # optional: cell-ok | cell-warn | cell-danger
              Format   = 'number'         # optional: same as column Format values
              Locale   = 'en-US'          # optional BCP-47 locale
              Decimals = 0                # optional decimal places
              Currency = 'USD'            # optional: for Format='currency'

              # ---- Trend / delta indicator (v1.4+) — optional ----
              Previous     = 219          # baseline for auto-computed delta vs Value
              Trend        = 'up'         # 'auto' (default) | 'up' | 'down' | 'flat'
              TrendIsGood  = $true        # $true=force green, $false=force red, omit=semantic default
              DeltaFormat  = 'both'       # 'percent' | 'absolute' | 'both' (default)

              # ---- Sparkline (v1.4+) — optional inline mini-chart below the value ----
              Sparkline      = @(12,18,15,22,19,24,31)  # raw numeric series
              SparklineMin   = 0                         # optional Y-axis min (default: series min)
              SparklineMax   = 100                       # optional Y-axis max (default: series max)
              SparklineStyle = 'line'                    # 'line' (default) | 'area' | 'bars'
          }

    .PARAMETER Collapsible
        Wrap the summary tile strip in a collapsible container with a header
        bar (same look & feel as Add-DhCollapsible). Defaults to $true. Pass
        -Collapsible:$false for a flat strip with no header.

    .PARAMETER Title
        Header text for the collapsible container. Defaults to 'Summary'.
        Only used when -Collapsible is $true.

    .PARAMETER Icon
        Optional emoji / unicode icon shown before the collapsible header
        title. Only used when -Collapsible is $true.

    .PARAMETER DefaultOpen
        Start expanded (default $true). Only used when -Collapsible is $true.

    .EXAMPLE
        Add-DhSummary -Report $report -Items @(
            @{ Label='Total Items';   Value=247;         Icon='X' }
            @{ Label='Active';        Value=231;         Icon='Y'; Class='cell-ok'     }
            @{ Label='Warnings';      Value=12;          Icon='W'; Class='cell-warn'   }
            @{ Label='Critical';      Value=4;           Icon='E'; Class='cell-danger' }
            @{ Label='Monthly Cost';  Value=12450.75;
               Format='currency'; Locale='en-US'; Currency='USD'; Decimals=2 }
            @{ Label='Total Storage'; Value=1610612736;  Format='bytes' }
            @{ Label='Avg Uptime';    Value=99.87;
               Format='percent'; Locale='en-US'; Decimals=2 }
        )

    .EXAMPLE
        # Custom collapsible header — fold away initially
        Add-DhSummary -Report $report -Title 'Key metrics' -Icon 'K' -DefaultOpen $false `
            -Items @(
                @{ Label='Total'; Value=247 }
                @{ Label='Active'; Value=231; Class='cell-ok' }
            )

    .EXAMPLE
        # Opt out of the collapsible chrome — flat tile strip (pre-1.3.2 behaviour)
        Add-DhSummary -Report $report -Collapsible:$false -Items @(
            @{ Label='Total'; Value=247 }
        )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)] [object[]]  $Items,
        [bool]     $Collapsible = $true,
        [string]   $Title       = 'Summary',
        [string]   $Icon        = '',
        [bool]     $DefaultOpen = $true,

        # ---- v1.4.1 — per-NavGroup summary ----
        # When -NavGroup is set, the strip lives inside the per-panel block
        # flow (hidden / shown by the existing two-tier nav routing) rather
        # than at the top of the page. Each NavGroup can have its own strip
        # with its own tiles. Without -NavGroup, the legacy top-of-page
        # singleton behaviour is preserved.
        [string]   $NavGroup    = '',
        [string]   $NavSubGroup = '',
        # Block Id used when -NavGroup is set (auto-derived from the group name
        # when omitted). Ignored when there's no NavGroup.
        [ValidatePattern('^$|^[A-Za-z0-9_-]+$')]
        [string]   $Id          = ''
    )

    $replacing = $Report.Contains('Summary')

    $normItems = foreach ($item in $Items) {
        if ($item -isnot [hashtable] -and $item -isnot [System.Collections.Specialized.OrderedDictionary]) {
            throw "Add-DhSummary: Each item must be a hashtable. Got: $($item.GetType().Name)"
        }
        if (-not $item.Contains('Label') -or $null -eq $item['Label']) {
            throw "Add-DhSummary: Each item must have a 'Label' key."
        }
        if (-not $item.Contains('Value')) {
            throw "Add-DhSummary: Each item must have a 'Value' key."
        }
        $t = @{} + $item
        if (-not $t.Contains('Icon'))     { $t['Icon']     = '' }
        if (-not $t.Contains('SubLabel')) { $t['SubLabel'] = '' }
        if (-not $t.Contains('Class'))    { $t['Class']    = '' }
        if (-not $t.Contains('Format'))   { $t['Format']   = '' }
        if (-not $t.Contains('Locale'))   { $t['Locale']   = '' }
        if (-not $t.Contains('Decimals')) { $t['Decimals'] = -1 }
        if (-not $t.Contains('Currency')) { $t['Currency'] = '' }

        # ---- Per-tile Action (v1.4.2 — click-to-jump) ----
        # Optional Action=@{TableId;Filter?;Url?;Label?} makes the whole tile
        # clickable. Same shape as Add-DhAlertBanner -Action.
        if ($t.Contains('Action') -and $null -ne $t['Action']) {
            $act = $t['Action']
            if ($act -isnot [hashtable] -and $act -isnot [System.Collections.Specialized.OrderedDictionary]) {
                throw "Add-DhSummary: tile '$($t.Label)' — Action must be a hashtable. Got: $($act.GetType().Name)"
            }
            $hasT = $act.Contains('TableId') -and -not [string]::IsNullOrWhiteSpace([string]$act['TableId'])
            $hasU = $act.Contains('Url')     -and -not [string]::IsNullOrWhiteSpace([string]$act['Url'])
            if (-not $hasT -and -not $hasU) {
                throw "Add-DhSummary: tile '$($t.Label)' — Action requires either a 'TableId' (jump to table) or a 'Url' (external link)."
            }
            if ($hasT -and $hasU) {
                throw "Add-DhSummary: tile '$($t.Label)' — Action must specify EITHER 'TableId' OR 'Url', not both."
            }
            $t['Action'] = @{
                Label   = if ($act.Contains('Label'))  { [string]$act.Label }   else { '' }
                TableId = if ($hasT) { [string]$act.TableId } else { '' }
                Filter  = if ($act.Contains('Filter')) { [string]$act.Filter }  else { '' }
                Url     = if ($hasU) { [string]$act.Url }     else { '' }
            }
        } else {
            $t['Action'] = $null
        }

        # ---- Tile style dispatch (v1.4 F3 + F4) ----
        if (-not $t.Contains('Style') -or [string]::IsNullOrWhiteSpace([string]$t['Style'])) {
            $t['Style'] = 'tile'
        } else {
            $style = ([string]$t['Style']).ToLowerInvariant()
            if ($style -notin @('tile','bignumber','gauge')) {
                throw "Add-DhSummary: tile '$($t.Label)' — Style must be 'tile', 'bignumber', or 'gauge'. Got: $($t['Style'])"
            }
            $t['Style'] = $style
        }

        # Bignumber-specific: optional Caption (small text below the hero value)
        if (-not $t.Contains('Caption')) { $t['Caption'] = '' }

        # ---- Unified Rag → Thresholds + RagNoData (v1.4 F13) ----
        # Done BEFORE the gauge Value check so a null Value combined with
        # Rag.NoData=$true is accepted (gauge renderer paints cell-nodata).
        $t['RagNoData'] = $false
        if ($t.Contains('Rag') -and $null -ne $t['Rag']) {
            $rag = ConvertTo-DhRagThresholds -Rag $t['Rag'] -Context "Add-DhSummary tile '$($t.Label)'"
            $t['Thresholds'] = $rag.Thresholds
            $t['RagNoData']  = $rag.NoData
            # Strip the raw Rag key once consumed — keeps the downstream item shape
            # canonical (Thresholds[] + RagNoData) and avoids double-emit in JSON.
            $t.Remove('Rag')
        }

        # Gauge-specific: Min/Max/Unit/Thresholds
        if ($t['Style'] -eq 'gauge') {
            # Value must be numeric for a gauge — EXCEPT when -Rag NoData=$true is
            # set, in which case a null/missing Value is explicitly allowed and
            # the renderer paints the gauge cell-nodata. Without that opt-in,
            # null/non-numeric is still rejected so authors don't accidentally
            # ship a broken-looking gauge.
            $isMissingValue = ($null -eq $t['Value']) -or ([string]::IsNullOrWhiteSpace([string]$t['Value']))
            $allowNoData = $t.Contains('RagNoData') -and $t['RagNoData']
            if ($isMissingValue -and $allowNoData) {
                # accepted — JS gauge renderer detects the missing value and paints cell-nodata
            } else {
                $gVal = 0.0
                $okGv = [double]::TryParse(
                    [string]$t['Value'],
                    [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [ref]$gVal)
                if (-not $okGv) {
                    throw "Add-DhSummary: tile '$($t.Label)' — Style='gauge' requires a numeric Value. Got: $($t['Value']). (Use -Rag with NoData=`$true to allow null values that render as cell-nodata.)"
                }
            }
            # Don't replace $t['Value'] — keep the user's original (could be an int) for the centre readout
        }
        foreach ($k in 'Min','Max') {
            if ($t.Contains($k) -and $null -ne $t[$k]) {
                $n = 0.0
                $okN = [double]::TryParse(
                    [string]$t[$k],
                    [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [ref]$n)
                if (-not $okN) {
                    throw "Add-DhSummary: tile '$($t.Label)' — $k must be a number, got: $($t[$k])"
                }
                $t[$k] = $n
            } else {
                # Gauge defaults: 0..100. Other styles ignore Min/Max.
                $t[$k] = if ($t['Style'] -eq 'gauge') { if ($k -eq 'Min') { 0.0 } else { 100.0 } } else { $null }
            }
        }
        if (-not $t.Contains('Unit')) { $t['Unit'] = '' }

        # Thresholds for gauge — array of @{ Min=..; Max=..; Class='cell-...' }
        # Same shape as Add-DhTable column thresholds (numeric only — string Value
        # thresholds don't apply to a numeric gauge).
        # When -Rag was used above, Thresholds is already populated and validated;
        # this block is the fallback path for legacy Thresholds=@(...) callers
        # plus a defensive re-validation of Rag-derived thresholds.
        $thOut = @()
        if ($t.Contains('Thresholds') -and $t['Thresholds']) {
            foreach ($th in @($t['Thresholds'])) {
                if ($th -isnot [hashtable] -and $th -isnot [System.Collections.Specialized.OrderedDictionary]) {
                    throw "Add-DhSummary: tile '$($t.Label)' — each Thresholds entry must be a hashtable. Got: $($th.GetType().Name)"
                }
                if (-not $th.Contains('Class') -or [string]::IsNullOrWhiteSpace([string]$th['Class'])) {
                    throw "Add-DhSummary: tile '$($t.Label)' — each Thresholds entry must have a non-empty Class key."
                }
                $thHash = @{ Class = [string]$th['Class'] }
                foreach ($bk in 'Min','Max') {
                    if ($th.Contains($bk) -and $null -ne $th[$bk]) {
                        $n = 0.0
                        $okN = [double]::TryParse(
                            [string]$th[$bk],
                            [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands,
                            [System.Globalization.CultureInfo]::InvariantCulture,
                            [ref]$n)
                        if (-not $okN) {
                            throw "Add-DhSummary: tile '$($t.Label)' — threshold $bk must be a number, got: $($th[$bk])"
                        }
                        $thHash[$bk] = $n
                    }
                }
                $thOut += $thHash
            }
        }
        $t['Thresholds'] = @($thOut)

        # ---- Trend / delta indicator (v1.4 F1) ----
        # Previous (nullable number). Triggers auto-derived delta when present.
        # IMPORTANT: parse with InvariantCulture — PowerShell [string] on a double
        # uses invariant format (period decimal), but [double]::TryParse defaults
        # to CurrentCulture which on locales like it-IT treats period as the
        # thousands separator, silently turning 92330.25 into 9233025.
        if ($t.Contains('Previous') -and $null -ne $t['Previous']) {
            $n = 0.0
            $okN = [double]::TryParse(
                [string]$t['Previous'],
                [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [ref]$n)
            if (-not $okN) {
                throw "Add-DhSummary: tile '$($t.Label)' — Previous must be a number, got: $($t['Previous'])"
            }
            $t['Previous'] = $n
        } else {
            $t['Previous'] = $null
        }

        # Trend ('auto' default | 'up' | 'down' | 'flat'). 'auto' = derive from Previous/Value.
        if (-not $t.Contains('Trend') -or [string]::IsNullOrWhiteSpace([string]$t['Trend'])) {
            $t['Trend'] = 'auto'
        } else {
            $trend = ([string]$t['Trend']).ToLowerInvariant()
            if ($trend -notin @('auto','up','down','flat')) {
                throw "Add-DhSummary: tile '$($t.Label)' — Trend must be 'auto', 'up', 'down', or 'flat'. Got: $($t['Trend'])"
            }
            $t['Trend'] = $trend
        }

        # TrendIsGood (nullable bool). $null = semantic default in JS (up=good, down=bad, flat=neutral).
        if ($t.Contains('TrendIsGood') -and $null -ne $t['TrendIsGood']) {
            $t['TrendIsGood'] = [bool]$t['TrendIsGood']
        } else {
            $t['TrendIsGood'] = $null
        }

        # DeltaFormat ('percent' | 'absolute' | 'both' default).
        if (-not $t.Contains('DeltaFormat') -or [string]::IsNullOrWhiteSpace([string]$t['DeltaFormat'])) {
            $t['DeltaFormat'] = 'both'
        } else {
            $df = ([string]$t['DeltaFormat']).ToLowerInvariant()
            if ($df -notin @('percent','absolute','both')) {
                throw "Add-DhSummary: tile '$($t.Label)' — DeltaFormat must be 'percent', 'absolute', or 'both'. Got: $($t['DeltaFormat'])"
            }
            $t['DeltaFormat'] = $df
        }

        # ---- Sparkline (v1.4 F2) — optional inline mini-chart below the value ----
        # Normalise the series into a numeric array. Anything not parseable as a
        # number is dropped (with a warning) so a bad value doesn't break the SVG.
        # NOTE: parse with InvariantCulture (see Previous note above).
        $sparkArr = @()
        if ($t.Contains('Sparkline') -and $null -ne $t['Sparkline']) {
            $raw = @($t['Sparkline'])
            foreach ($v in $raw) {
                if ($null -eq $v) { continue }
                $n = 0.0
                $okN = [double]::TryParse(
                    [string]$v,
                    [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [ref]$n)
                if ($okN) {
                    $sparkArr += $n
                } else {
                    Write-Warning "Add-DhSummary: tile '$($t.Label)' — Sparkline value '$v' is not numeric and will be skipped."
                }
            }
        }
        $t['Sparkline'] = @($sparkArr)

        # Optional numeric Y-axis bounds — leave as $null when not supplied so JS uses series min/max
        foreach ($k in 'SparklineMin','SparklineMax') {
            if ($t.Contains($k) -and $null -ne $t[$k]) {
                $n = 0.0
                $okN = [double]::TryParse(
                    [string]$t[$k],
                    [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [ref]$n)
                if (-not $okN) {
                    throw "Add-DhSummary: tile '$($t.Label)' — $k must be a number, got: $($t[$k])"
                }
                $t[$k] = $n
            } else {
                $t[$k] = $null
            }
        }

        # Style — 'line' (default) | 'area' | 'bars'
        if (-not $t.Contains('SparklineStyle') -or [string]::IsNullOrWhiteSpace([string]$t['SparklineStyle'])) {
            $t['SparklineStyle'] = 'line'
        } else {
            $style = ([string]$t['SparklineStyle']).ToLowerInvariant()
            if ($style -notin @('line','area','bars')) {
                throw "Add-DhSummary: tile '$($t.Label)' — SparklineStyle must be 'line', 'area', or 'bars'. Got: $($t['SparklineStyle'])"
            }
            $t['SparklineStyle'] = $style
        }

        $t
    }

    # ---- Storage: per-NavGroup strip OR legacy top-of-page singleton ----
    if ([string]::IsNullOrWhiteSpace($NavGroup)) {
        # Legacy path — singleton at the top of the page (unchanged from v1.4.0).
        $Report['Summary'] = @($normItems)
        $Report['SummaryOptions'] = [ordered]@{
            Collapsible = $Collapsible
            Title       = $Title
            Icon        = $Icon
            DefaultOpen = $DefaultOpen
        }
        if ($replacing) {
            Write-Warning "Add-DhSummary: Report already has a global Summary - replacing the existing tiles. (Pass -NavGroup to add a per-panel strip instead.)"
        }
        Write-Verbose "Add-DhSummary: $(@($normItems).Count) tile(s) added at top-of-page.$(if ($Collapsible) { ' (collapsible)' } else { ' (flat)' })"
    } else {
        # v1.4.1+ — per-NavGroup strip; lives in $Report.Blocks so the nav
        # routing hides / shows it with the rest of the panel content.
        if (-not $Report.Contains('Blocks')) {
            $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
        }
        # Auto-derive Id from NavGroup + NavSubGroup if user didn't supply one.
        # Slugify (lowercase + non-alphanum to '-'): 'My Group' → 'my-group'.
        function _slug([string] $s) {
            if ([string]::IsNullOrWhiteSpace($s)) { return '' }
            return ($s.ToLowerInvariant() -replace '[^a-z0-9_-]','-').Trim('-')
        }
        $blockId = $Id
        if ([string]::IsNullOrWhiteSpace($blockId)) {
            $blockId = 'summary-' + (_slug $NavGroup)
            if (-not [string]::IsNullOrWhiteSpace($NavSubGroup)) {
                $blockId += '-' + (_slug $NavSubGroup)
            }
        }
        # Duplicate-Id guard mirroring the other block cmdlets
        foreach ($existing in $Report.Blocks) {
            if ($existing.Id -eq $blockId) {
                throw "Add-DhSummary: A block with Id '$blockId' already exists. Supply -Id to disambiguate, or pick a different -NavGroup."
            }
        }
        $Report.Blocks.Add([ordered]@{
            BlockType   = 'summarystrip'
            Id          = $blockId
            Title       = $Title
            Icon        = $Icon
            Items       = @($normItems)
            Collapsible = [bool]$Collapsible
            DefaultOpen = [bool]$DefaultOpen
            NavGroup    = $NavGroup
            NavSubGroup = $NavSubGroup
        })
        Write-Verbose "Add-DhSummary: $(@($normItems).Count) tile(s) added as block '$blockId' (NavGroup='$NavGroup'$(if ($NavSubGroup) { "', NavSubGroup='$NavSubGroup" }))."
    }
}
