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
    findings       = 'Add-DhFindings'      # DashHtml 2.2.0
    keyvalue       = 'Add-DhKeyValue'      # DashHtml 2.3.0
    recordlist     = 'Add-DhRecordList'    # DashHtml 2.3.0
    treefilter     = 'Add-DhTreeFilter'    # DashHtml 2.4.0
    networkmap     = 'Add-DhNetworkMap'    # DashHtml 2.4.0
    treetable      = 'Add-DhTreeTable'     # DashHtml 2.5.0
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
        # 2.5.4 - PSBase: a data row with a Keys field would make $Value.Keys return that field's value
        $parts = foreach ($k in $Value.PSBase.Keys) { "$k = $(ConvertTo-DhPsLiteral $Value[$k] $Indent)" }
        # an ordered source stays ordered, so property lists (tree table Properties) keep their order
        $open = if ($Value -is [System.Collections.Specialized.OrderedDictionary]) { '[ordered]@{ ' } else { '@{ ' }
        return $open + ($parts -join '; ') + ' }'
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
function ConvertTo-DhJsonSchemaType {
    # A YAML key may be present with no value (null): every typed shape accepts it as well.
    param([Parameter(Mandatory)] [System.Management.Automation.ParameterMetadata] $Parameter)
    $shape = ConvertTo-DhJsonSchemaTypeCore -Parameter $Parameter
    if ($shape.Contains('type') -and $shape['type'] -is [string]) { $shape['type'] = @($shape['type'], 'null') }
    elseif ($shape.Contains('enum')) { $shape['enum'] = @($shape['enum']) + @($null) }
    return $shape
}

function ConvertTo-DhJsonSchemaTypeCore {
    <#
    .SYNOPSIS  JSON Schema fragment for one cmdlet parameter (switch = boolean, int = integer, ValidateSet = enum).
    #>
    param([Parameter(Mandatory)] [System.Management.Automation.ParameterMetadata] $Parameter)
    $ty = $Parameter.ParameterType
    $set = $Parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | Select-Object -First 1
    if ($set) {
        # the reader is case-insensitive: accept the usual spellings
        $vals = foreach ($v in $set.ValidValues) { $v; $v.ToLowerInvariant(); $v.ToUpperInvariant() }
        return [ordered]@{ enum = @($vals | Select-Object -Unique) }
    }
    if ($ty -eq [System.Management.Automation.SwitchParameter] -or $ty -eq [bool]) { return [ordered]@{ type = 'boolean' } }
    if ($ty -in @([int], [long], [uint32], [int16], [byte])) { return [ordered]@{ type = 'integer' } }
    if ($ty -in @([double], [single], [decimal])) { return [ordered]@{ type = 'number' } }
    if ($ty -eq [string]) { return [ordered]@{ type = 'string' } }
    if ($ty -eq [datetime]) { return [ordered]@{ type = 'string' } }
    if ($ty -eq [string[]]) { return [ordered]@{ type = 'array'; items = [ordered]@{ type = 'string' } } }
    if ($ty -eq [hashtable] -or $ty -eq [System.Collections.IDictionary] -or $ty -eq [System.Collections.Specialized.OrderedDictionary]) { return [ordered]@{ type = 'object' } }
    if ($ty.IsArray) { return [ordered]@{ type = 'array' } }
    return [ordered]@{}
}
