function Add-DhBullet {
    <#
    .SYNOPSIS
        Add a bullet-chart block (actual vs target with performance bands).

    .DESCRIPTION
        Renders one horizontal bullet bar per item — the canonical visualisation
        for "actual vs target with qualitative ranges" per the IT-infrastructure
        KPI dashboard specification (§2 Widget Types).

        Each bullet row shows:
          • a full-width track from Min to Max
          • optional coloured performance bands (RAG ranges)
          • a centred solid value bar from Min to Value
          • an optional vertical target marker
          • a readout (Value + Unit + optional 'target N') on the right

        Multiple items stack vertically inside a single block. Pair this with
        Add-DhSummary for high-level KPI tiles and use bullets for the
        actual-vs-SLA detail (latency vs target, headroom vs minimum, etc.).

    .PARAMETER Report
        Dashboard object from New-DhDashboard.

    .PARAMETER Id
        Unique identifier (alphanumeric, dash, underscore).

    .PARAMETER Title
        Block heading shown above the bullets.

    .PARAMETER Items
        Array of bullet definition hashtables:
          @{
              Label  = 'DC01'           # REQUIRED — left-side row label
              Value  = 42               # REQUIRED — the actual numeric value
              Target = 50               # optional — vertical marker on the track
              Min    = 0                # optional — track start (default 0)
              Max    = 120              # optional — track end (default 100)
              Unit   = 'ms'             # optional — suffix in the readout
              Class  = 'cell-warn'      # optional — explicit value-bar colour;
                                        #            wins over auto threshold match

              # ---- Performance bands (one of these) ----
              # Modern shape (v1.4+):
              Rag = @{
                  Green = @{ Max = 50 }
                  Amber = @{ Min = 50; Max = 80 }
                  Red   = @{ Min = 80 }
                  NoData = $false
              }
              # OR legacy array shape (also accepted under alias 'Bands'):
              Thresholds = @(
                  @{           Max = 50;  Class = 'cell-ok'     }
                  @{ Min = 50; Max = 80;  Class = 'cell-warn'   }
                  @{ Min = 80;             Class = 'cell-danger' }
              )
          }

        When both Rag and Thresholds (or Bands) are supplied, Rag wins.

    .PARAMETER NavGroup
        Primary nav group label (enables two-tier nav).

    .PARAMETER NavSubGroup
        Optional second-level group under NavGroup (enables three-tier nav).

    .EXAMPLE
        # Three rows sharing one RAG band definition
        $latencyRag = @{
            Green = @{ Max = 50 }
            Amber = @{ Min = 50; Max = 80 }
            Red   = @{ Min = 80 }
        }
        Add-DhBullet -Report $report -Id 'auth-latency' -Title 'LDAP Bind Time' `
            -Items @(
                @{ Label='DC01'; Value=42; Target=50; Max=120; Unit='ms'; Rag=$latencyRag }
                @{ Label='DC02'; Value=68; Target=50; Max=120; Unit='ms'; Rag=$latencyRag }
                @{ Label='DC03'; Value=92; Target=50; Max=120; Unit='ms'; Rag=$latencyRag }
            )

    .EXAMPLE
        # Headroom — bigger is better, so flip the RAG semantics
        Add-DhBullet -Report $report -Id 'cpu-headroom' -Title 'CPU Headroom per Host' `
            -Items @(
                @{ Label='esxi-01'; Value=42; Target=30; Min=0; Max=100; Unit='%'
                   Rag=@{ Green=@{Min=30}; Amber=@{Min=15;Max=30}; Red=@{Max=15} }
                }
            )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string] $Id,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [object[]] $Items,
        [bool]   $Collapsible = $true,    # wrap the block in a collapsible header (chevron + click-to-toggle)
        [bool]   $DefaultOpen = $true,    # whether the collapsible body starts expanded (only used when -Collapsible is $true)
        [ValidateRange(0,12)]
        [int]    $GridSpan    = 0,   # v1.10.0 - columns (1-12) to span in -report-grid layout; 0 = default flow
        [string] $NavGroup    = '',
        [string] $NavSubGroup = '',
        # ---- v2.0.0 navigation (see readme-dev.md section 15) ----
        [string] $NavPath      = '',   # 'A/B/C' - where this item lives. '//' escapes a literal '/'
        [ValidateSet('','Exact','Subtree','Global')]
        [string] $NavScope     = '',   # Exact (default) | Subtree (this node and below) | Global (everywhere)
        [string] $NavLabel     = '',   # display text for this node, decoupled from the path key
        [int]    $NavOrder     = 0     # explicit sibling ordering; 0 = declaration order
    )

    # v2.0.0 - resolve nav declaration once, in one place. Throws if -NavPath is
    # combined with -NavGroup/-NavSubGroup rather than silently preferring one.
    $navDecl = Resolve-DhNavDeclaration -NavPath $NavPath -NavScope $NavScope `
                    -NavGroup $NavGroup -NavSubGroup $NavSubGroup `
                    -ItemKind 'Block' -Context 'Add-DhBullet'
    # Monotonic declaration number, shared by tables and blocks. The exporter
    # emits ALL blocks before ALL tables, so without this the menu would order
    # nodes by section type instead of by the order the author wrote them.
    if (-not $Report.Contains('_DhNavSeq')) { $Report['_DhNavSeq'] = 0 }
    $navSeqNo = [int]$Report['_DhNavSeq']; $Report['_DhNavSeq'] = $navSeqNo + 1

    if (-not $Report.Contains('Blocks')) {
        $Report['Blocks'] = [System.Collections.Generic.List[hashtable]]::new()
    }

    # Duplicate-Id guard (same rule applied by other block cmdlets)
    foreach ($existing in $Report.Blocks) {
        if ($existing.Id -eq $Id) {
            throw "Add-DhBullet: A block with Id '$Id' already exists in this report. Use a unique Id."
        }
    }

    # Helper — parse with InvariantCulture (see locale note in Add-DhSummary)
    function _tryNum {
        param([object] $v, [string] $label, [string] $ctx)
        $n = 0.0
        $ok = [double]::TryParse(
            [string]$v,
            [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$n)
        if (-not $ok) {
            throw "Add-DhBullet: $ctx — $label must be a number, got: $v"
        }
        return $n
    }

    $normItems = foreach ($item in $Items) {
        if ($item -isnot [hashtable] -and $item -isnot [System.Collections.Specialized.OrderedDictionary]) {
            throw "Add-DhBullet: each item must be a hashtable. Got: $($item.GetType().Name)"
        }
        if (-not $item.Contains('Label') -or [string]::IsNullOrWhiteSpace([string]$item['Label'])) {
            throw "Add-DhBullet: each item must have a non-empty 'Label' key."
        }
        if (-not $item.Contains('Value')) {
            throw "Add-DhBullet: each item must have a 'Value' key."
        }
        $b = @{} + $item
        $ctx = "bullet item '$($b.Label)'"

        # ---- Threshold band resolution (v1.4 F13) — done FIRST so the gauge-style
        # NoData escape hatch is known before the Value type check below.
        # Precedence: Rag > Thresholds > Bands (Bands is a documented alias).
        $b['RagNoData'] = $false
        if ($b.Contains('Rag') -and $null -ne $b['Rag']) {
            $rag = ConvertTo-DhRagThresholds -Rag $b['Rag'] -Context "Add-DhBullet $ctx"
            $b['Thresholds'] = $rag.Thresholds
            $b['RagNoData']  = $rag.NoData
            $b.Remove('Rag')
            if ($b.Contains('Bands')) { $b.Remove('Bands') }
        } elseif ($b.Contains('Thresholds') -and $b['Thresholds']) {
            if ($b.Contains('Bands')) { $b.Remove('Bands') }
        } elseif ($b.Contains('Bands') -and $b['Bands']) {
            $b['Thresholds'] = @($b['Bands'])
            $b.Remove('Bands')
        }
        if (-not $b.Contains('Thresholds')) { $b['Thresholds'] = @() }

        # Value — numeric, UNLESS Rag.NoData=$true was opted in (then $null is OK
        # and the row renders cell-nodata at 0% width). Mirrors Add-DhSummary gauge.
        $isMissingValue = ($null -eq $b['Value']) -or ([string]::IsNullOrWhiteSpace([string]$b['Value']))
        if ($isMissingValue -and $b['RagNoData']) {
            # accepted — leave Value as $null; JS renderer handles the nodata fallback
        } else {
            $b['Value'] = _tryNum $b['Value'] 'Value' $ctx
        }

        # Target — optional numeric
        if ($b.Contains('Target') -and $null -ne $b['Target']) {
            $b['Target'] = _tryNum $b['Target'] 'Target' $ctx
        } else {
            $b['Target'] = $null
        }

        # Min / Max — default 0..100
        if ($b.Contains('Min') -and $null -ne $b['Min']) { $b['Min'] = _tryNum $b['Min'] 'Min' $ctx } else { $b['Min'] = 0.0 }
        if ($b.Contains('Max') -and $null -ne $b['Max']) { $b['Max'] = _tryNum $b['Max'] 'Max' $ctx } else { $b['Max'] = 100.0 }
        if ($b['Max'] -le $b['Min']) {
            throw "Add-DhBullet: $ctx — Max ($($b.Max)) must be greater than Min ($($b.Min))."
        }

        # Unit / Class
        if (-not $b.Contains('Unit'))  { $b['Unit']  = '' }
        if (-not $b.Contains('Class')) { $b['Class'] = '' }

        # Validate / normalise the resulting threshold array
        $thOut = @()
        foreach ($th in @($b['Thresholds'])) {
            if ($th -isnot [hashtable] -and $th -isnot [System.Collections.Specialized.OrderedDictionary]) {
                throw "Add-DhBullet: $ctx — each Thresholds/Bands entry must be a hashtable. Got: $($th.GetType().Name)"
            }
            if (-not $th.Contains('Class') -or [string]::IsNullOrWhiteSpace([string]$th['Class'])) {
                throw "Add-DhBullet: $ctx — each Thresholds/Bands entry must have a non-empty Class key."
            }
            $row = @{ Class = [string]$th['Class'] }
            foreach ($bk in 'Min','Max') {
                if ($th.Contains($bk) -and $null -ne $th[$bk]) {
                    $row[$bk] = _tryNum $th[$bk] "threshold $bk" $ctx
                }
            }
            $thOut += $row
        }
        $b['Thresholds'] = @($thOut)

        $b
    }

    $Report.Blocks.Add([ordered]@{
        BlockType    = 'bullet'
        Id           = $Id
        Title        = $Title
        Items        = @($normItems)
        NavGroup     = $NavGroup
        NavSubGroup = $NavSubGroup
        NavPath     = $NavPath
        NavSegments     = $navDecl.Path
        NavSeqNo     = $navSeqNo
        NavScope    = $navDecl.Scope
        NavLabel    = $NavLabel
        NavOrder    = $NavOrder
        GridSpan    = $GridSpan
        Collapsible = $Collapsible
        DefaultOpen = $DefaultOpen
    })
    Write-Verbose "Add-DhBullet: '$Id' ($(@($normItems).Count) row(s))."
}


