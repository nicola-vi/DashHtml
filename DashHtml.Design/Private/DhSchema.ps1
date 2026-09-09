# ---------------------------------------------------------------------------
#  Schema helpers shared by the DashHtml.Design cmdlets.
#  - Type <-> cmdlet map.
#  - PowerShell-literal emitter (for ConvertFrom-DhYaml codegen).
#  Codegen is driven off LIVE cmdlet metadata (Get-Command ...Parameters), so
#  it stays correct as the core module's parameters evolve — no hand-kept list.
# ---------------------------------------------------------------------------

# Block-type (as stored in $Report.Blocks[].BlockType) -> Add-* cmdlet.
$script:DhTypeToCmdlet = @{
    summary        = 'Add-DhSummary'
    summarystrip   = 'Add-DhSummary'
    html           = 'Add-DhHtmlBlock'
    collapsible    = 'Add-DhCollapsible'
    filtercardgrid = 'Add-DhFilterCard'
    barchart       = 'Add-DhBarChart'
    piechart       = 'Add-DhPieChart'
    bullet         = 'Add-DhBullet'
    linechart      = 'Add-DhLineChart'
    eventfeed      = 'Add-DhEventFeed'
    statusgrid     = 'Add-DhStatusGrid'
    tabs           = 'Add-DhTabs'
    heatmap        = 'Add-DhHeatmap'
    rangebar       = 'Add-DhRangeBar'
    topologymap    = 'Add-DhTopologyMap'
}

$script:DhCommonParams = @(
    'Verbose','Debug','ErrorAction','WarningAction','InformationAction',
    'ErrorVariable','WarningVariable','InformationVariable','OutVariable',
    'OutBuffer','PipelineVariable','WhatIf','Confirm','ProgressAction'
)

function Get-DhCmdletParams {
    <# Real parameter names of a cmdlet (excluding common params). $null if absent. #>
    param([string] $CmdletName)
    $cmd = Get-Command $CmdletName -ErrorAction SilentlyContinue
    if (-not $cmd) { return $null }
    return @($cmd.Parameters.Keys | Where-Object { $_ -notin $script:DhCommonParams })
}

function ConvertTo-DhPsLiteral {
    <#
    .SYNOPSIS  Render a value as a PowerShell literal (single-quoted strings,
               @{...} hashtables, @(...) arrays). Safe: no interpolation.
    #>
    param([object] $Value, [int] $Indent = 0)

    if ($null -eq $Value) { return '$null' }
    if ($Value -is [bool] -or $Value -is [System.Management.Automation.SwitchParameter]) { return $(if ([bool]$Value) { '$true' } else { '$false' }) }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) {
        return $Value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [string]) {
        return "'" + ($Value -replace "'", "''") + "'"
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $parts = foreach ($k in $Value.Keys) { "$k = $(ConvertTo-DhPsLiteral $Value[$k] $Indent)" }
        return '@{ ' + ($parts -join '; ') + ' }'
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $items = @($Value)
        if ($items.Count -eq 0) { return '@()' }
        $allScalar = @($items | Where-Object {
            $_ -isnot [System.Collections.IDictionary] -and
            (($_ -isnot [System.Collections.IEnumerable]) -or ($_ -is [string]))
        }).Count -eq $items.Count
        if ($allScalar) {
            return '@(' + (($items | ForEach-Object { ConvertTo-DhPsLiteral $_ $Indent }) -join ', ') + ')'
        }
        # array of maps/arrays -> multiline for readability
        $pad = '    ' * ($Indent + 1)
        $lines = $items | ForEach-Object { $pad + (ConvertTo-DhPsLiteral $_ ($Indent + 1)) }
        return "@(`n" + ($lines -join "`n") + "`n" + ('    ' * $Indent) + ')'
    }
    return "'" + ([string]$Value -replace "'", "''") + "'"
}
