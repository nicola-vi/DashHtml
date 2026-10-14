function Test-DhReportLinks {
    <#
    .SYNOPSIS  Export-time cross-reference check (v2.1.4).
               Returns one message per dangling table reference or unknown
               block type. Export-DhDashboard writes each as a warning.

    .DESCRIPTION
        Every reference below is a silent no-op in the browser when the table
        it names does not exist: the chart renders empty, the cell or tile
        click does nothing. Some cmdlets check at Add-time, but only when the
        table was declared first, and several never checked at all. Checking
        once here, against the finished report, catches all of them whatever
        the declaration order.

        Warnings, never throws: a report that exports today must keep
        exporting (plan-v2.2 decision D4).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Report,
        # Block types Export-DhDashboard knows how to serialise. Kept as a
        # parameter so the list lives next to the switch it mirrors.
        [Parameter(Mandatory)] [string[]] $KnownBlockTypes
    )

    $tableIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($t in $Report.Tables) { [void]$tableIds.Add([string]$t.Id) }

    $missing = {
        param([string] $Id)
        -not [string]::IsNullOrWhiteSpace($Id) -and -not $tableIds.Contains($Id)
    }

    # Global summary tiles
    if ($Report.Contains('Summary')) {
        foreach ($it in @($Report.Summary)) {
            if ($it -is [System.Collections.IDictionary] -and $it.Contains('Action') -and $it.Action -is [System.Collections.IDictionary]) {
                $tid = [string]$it.Action['TableId']
                if (& $missing $tid) { "summary tile '$($it.Label)': Action.TableId '$tid' is not a table in this report - the tile click will do nothing." }
            }
        }
    }

    # Alert banners
    if ($Report.Contains('AlertBanners')) {
        foreach ($a in $Report.AlertBanners) {
            if ($a.Contains('Action') -and $a.Action -is [System.Collections.IDictionary]) {
                $tid = [string]$a.Action['TableId']
                if (& $missing $tid) { "alert banner '$($a.Id)': Action.TableId '$tid' is not a table in this report - the action button will do nothing." }
            }
        }
    }

    # Table master/detail links
    if ($Report.Contains('Links')) {
        foreach ($l in @($Report.Links)) {
            foreach ($k in 'MasterTableId', 'DetailTableId') {
                $tid = [string]$l[$k]
                if (& $missing $tid) { "Set-DhTableLink: $k '$tid' is not a table in this report - the link will do nothing." }
            }
        }
    }

    if (-not $Report.Contains('Blocks')) { return }

    foreach ($b in $Report.Blocks) {
        $bt  = [string]$b.BlockType
        $bid = [string]$b.Id
        if ($bt -notin $KnownBlockTypes) {
            "block '$bid': unknown BlockType '$bt' - it is not rendered."
            continue
        }
        switch ($bt) {
            { $_ -in 'barchart', 'piechart', 'rangebar' } {
                $tid = [string]$b['TableId']
                if (& $missing $tid) { "$bt '$bid': TableId '$tid' is not a table in this report - the chart will be empty." }
                # v2.2.0 - a ValueField can only be checked at Add-time when the
                # table came first; check again here for the other order
                elseif ($bt -eq 'barchart' -and $b.Contains('ValueField') -and $b.ValueField) {
                    $tbl = $Report.Tables | Where-Object { $_.Id -eq $tid } | Select-Object -First 1
                    if ($tbl -and [string]$b.ValueField -cnotin (Get-DhTableFieldNames -Table $tbl)) {
                        "barchart '$bid': ValueField '$($b.ValueField)' is not a field of table '$tid' - every bar will be empty."
                    }
                }
            }
            'filtercardgrid' {
                $tid = [string]$b['TargetTableId']
                if (& $missing $tid) { "filter card '$bid': TargetTableId '$tid' is not a table in this report - the cards will filter nothing." }
            }
            'statusgrid' {
                foreach ($c in @($b.Cells)) {
                    $tid = [string]$c['LinkTableId']
                    if (& $missing $tid) { "status grid '$bid' cell ($($c['Row']), $($c['Column'])): LinkTableId '$tid' is not a table in this report - the click will do nothing." }
                }
            }
            'topologymap' {
                foreach ($n in @($b.Nodes)) {
                    $tid = [string]$n['LinkTableId']
                    if (& $missing $tid) { "topology map '$bid' node '$($n['Id'])': LinkTableId '$tid' is not a table in this report - the click will do nothing." }
                }
            }
            'findings' {
                foreach ($f in @($b.Findings)) {
                    $tid = [string]$f['AffectedTableId']
                    if (& $missing $tid) { "findings '$bid' finding '$($f['Title'])': AffectedTableId '$tid' is not a table in this report - 'Show in table' will do nothing." }
                }
            }
            'summarystrip' {
                foreach ($it in @($b.Items)) {
                    if ($it -is [System.Collections.IDictionary] -and $it.Contains('Action') -and $it.Action -is [System.Collections.IDictionary]) {
                        $tid = [string]$it.Action['TableId']
                        if (& $missing $tid) { "summary strip '$bid' tile '$($it.Label)': Action.TableId '$tid' is not a table in this report - the tile click will do nothing." }
                    }
                }
            }
        }
    }
}
