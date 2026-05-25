function ConvertTo-DhRagThresholds {
    <#
    .SYNOPSIS
        Normalises a Rag hashtable into the legacy Thresholds array shape.

    .DESCRIPTION
        v1.4 introduces a unified -Rag parameter shape that maps cleanly onto the
        IT-infrastructure KPI dashboard specification's GREEN / AMBER / RED / GREY
        bands:

            $rag = @{
                Green  = @{ Max = 70 }              # cell-ok
                Amber  = @{ Min = 70; Max = 90 }    # cell-warn
                Red    = @{ Min = 90 }              # cell-danger
                NoData = $true                      # cell-nodata for null/missing
            }

        This helper converts that shape into the existing per-column /
        per-tile Thresholds array shape:

            @(
                @{ Max = 70;             Class = 'cell-ok'     }
                @{ Min = 70; Max = 90;   Class = 'cell-warn'   }
                @{ Min = 90;             Class = 'cell-danger' }
            )

        So downstream code (Export-DhDashboard JSON emission, JS threshold
        matcher) stays unchanged — only the Add-* normalisers need to call this
        helper when a user supplies -Rag.

        Returns a PSCustomObject:
            Thresholds (object[])  — the converted threshold array (may be empty)
            NoData     (bool)      — whether to colour null/missing values
                                     with cell-nodata at render time

    .PARAMETER Rag
        A hashtable / ordered dict with any subset of these keys:
          Green, Amber, Red  — each a hashtable with Min and/or Max numeric bounds
          NoData             — boolean opt-in for cell-nodata on missing values

    .EXAMPLE
        $result = ConvertTo-DhRagThresholds -Rag @{
            Green = @{ Max = 70 }
            Amber = @{ Min = 70; Max = 90 }
            Red   = @{ Min = 90 }
            NoData = $true
        }
        $result.Thresholds   # → array of three Min/Max/Class hashtables
        $result.NoData       # → $true
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [object] $Rag,

        # Caller passes its own label-of-thing-being-validated (column id, tile label, etc.)
        # so error messages are useful at the call site.
        [string] $Context = 'Rag'
    )

    if ($Rag -isnot [hashtable] -and $Rag -isnot [System.Collections.Specialized.OrderedDictionary]) {
        throw "${Context}: -Rag must be a hashtable. Got: $($Rag.GetType().Name)"
    }

    # Reject any unknown keys early so typos surface as errors
    $allowed = @('Green','Amber','Red','NoData')
    foreach ($k in $Rag.Keys) {
        if ($k -notin $allowed) {
            throw "${Context}: unknown -Rag key '$k'. Allowed: Green, Amber, Red, NoData."
        }
    }

    # Band → class binding
    $bandToClass = [ordered]@{
        Green = 'cell-ok'
        Amber = 'cell-warn'
        Red   = 'cell-danger'
    }

    $thresholds = @()
    foreach ($band in $bandToClass.Keys) {
        if (-not $Rag.Contains($band)) { continue }
        $spec = $Rag[$band]
        if ($spec -isnot [hashtable] -and $spec -isnot [System.Collections.Specialized.OrderedDictionary]) {
            throw "${Context}: -Rag.$band must be a hashtable (e.g. @{ Min=70; Max=90 }). Got: $($spec.GetType().Name)"
        }
        # Reject unknown band-level keys
        foreach ($bk in $spec.Keys) {
            if ($bk -notin @('Min','Max')) {
                throw "${Context}: -Rag.$band has unknown key '$bk'. Allowed: Min, Max."
            }
        }
        $row = @{ Class = $bandToClass[$band] }
        foreach ($bk in 'Min','Max') {
            if ($spec.Contains($bk) -and $null -ne $spec[$bk]) {
                $n = 0.0
                $ok = [double]::TryParse(
                    [string]$spec[$bk],
                    [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [ref]$n)
                if (-not $ok) {
                    throw "${Context}: -Rag.$band.$bk must be a number, got: $($spec[$bk])"
                }
                $row[$bk] = $n
            }
        }
        # A band with neither Min nor Max is a catch-all — still valid (acts as default colour)
        $thresholds += $row
    }

    $noData = $false
    if ($Rag.Contains('NoData') -and $null -ne $Rag['NoData']) {
        $noData = [bool]$Rag['NoData']
    }

    return [PSCustomObject]@{
        Thresholds = @($thresholds)
        NoData     = $noData
    }
}
