function Export-DhYamlSchema {
    <#
    .SYNOPSIS
        Writes (or returns) a JSON Schema for DashHtml layout YAML.
    .DESCRIPTION
        Generated from the LIVE cmdlet metadata (the same source ConvertFrom-DhYaml uses), so it cannot drift from the
        module: top-level keys come from New-DhDashboard, each entry of tables / globalFilters / alertBanners / links
        from its Add-* / Set-* cmdlet, and every block is one entry of a oneOf keyed by its 'type'. Types follow the
        parameter types (switch = boolean, int = integer, ValidateSet = enum). Keys are accepted in PascalCase, camelCase and
        lowercase (the reader is case-insensitive). Unknown keys are rejected, because the reader would otherwise
        ignore a typo silently. Keys the writer itself adds and the reader ignores (NavSegments, NavSeqNo, dataRows)
        are allowed.

        Use it in an editor with a first line   # yaml-language-server: $schema=dashhtml.schema.json
        or validate a layout:  ConvertFrom-DhYaml-style YAML -> object -> ConvertTo-Json -Depth 50 | Test-Json -Schema (Get-Content dashhtml.schema.json -Raw)
    .PARAMETER OutFile
        Write the schema to this file (UTF-8, no BOM, LF). Without it the schema is returned as a JSON string.
    .PARAMETER AsObject
        Return the schema as an ordered hashtable instead of text.
    .EXAMPLE
        Export-DhYamlSchema -OutFile .\dashhtml.schema.json
    #>
    [CmdletBinding()]
    param([string] $OutFile, [switch] $AsObject)

    # PowerShell's [ordered] is case-insensitive: Id and id would collapse into one key, so property maps are ordinal.
    $newMap = { [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal) }
    $casings = {
        param([string] $Name)
        $camel = $Name.Substring(0, 1).ToLowerInvariant() + $Name.Substring(1)
        @($Name, $camel, $Name.ToLowerInvariant()) | Select-Object -Unique   # Pascal, camel, and the all-lowercase the writer uses for summary options
    }
    $propsFor = {
        param([string] $Cmdlet, [string[]] $Skip, [hashtable] $Rename)
        $props = & $newMap
        $meta = (Get-Command $Cmdlet -ErrorAction Stop).Parameters
        foreach ($n in ($meta.Keys | Sort-Object)) {
            if ($n -in $script:DhCommonParams -or $n -in $Skip) { continue }
            $shape = ConvertTo-DhJsonSchemaType -Parameter $meta[$n]
            $key = if ($Rename -and $Rename.ContainsKey($n)) { $Rename[$n] } else { $n }
            foreach ($k in (& $casings $key)) { $props[$k] = $shape }
        }
        $props
    }
    $internal = & $newMap   # keys the writer adds and the reader ignores
    foreach ($n in 'NavSegments', 'NavSeqNo', 'dataRows') { $internal[$n] = [ordered]@{ description = 'written by ConvertTo-DhYaml; ignored when reading' } }

    # ---- top level
    $top = & $propsFor 'New-DhDashboard' @() @{}
    foreach ($k in 'autoRefresh') { $top[$k] = [ordered]@{ oneOf = @([ordered]@{ type = 'integer'; minimum = 0 }, [ordered]@{ type = 'string' }) } }
    $top['infoFields'] = [ordered]@{ type = 'array'; items = [ordered]@{ type = 'object'; properties = [ordered]@{ label = @{ type = 'string' }; value = @{} }; required = @('label') } }
    $top['summary'] = [ordered]@{ type = 'object'; properties = (& $propsFor 'Add-DhSummary' @('Report') @{}); additionalProperties = $false }
    $top['summary'].properties['items'] = [ordered]@{ type = 'array' }
    $top['summary'].properties['Items'] = [ordered]@{ type = 'array' }

    $sectionSchema = {
        param([string] $Cmdlet, [string[]] $Skip, [hashtable] $Rename, [string[]] $Extra)
        $p = & $propsFor $Cmdlet (@('Report') + $Skip) $Rename
        foreach ($k in $internal.Keys) { $p[$k] = $internal[$k] }
        foreach ($k in $Extra) { $p[$k] = [ordered]@{} }
        [ordered]@{ type = 'object'; properties = $p; additionalProperties = $false }
    }
    $top['tables']        = [ordered]@{ type = 'array'; items = (& $sectionSchema 'Add-DhTable' @() @{ TableId = 'Id' } @('id', 'TableId', 'tableId', 'data', 'dataFile')) }
    $top['globalFilters'] = [ordered]@{ type = 'array'; items = (& $sectionSchema 'Add-DhGlobalFilter' @() @{} @()) }
    $top['alertBanners']  = [ordered]@{ type = 'array'; items = (& $sectionSchema 'Add-DhAlertBanner' @() @{} @()) }
    $top['links']         = [ordered]@{ type = 'array'; items = (& $sectionSchema 'Set-DhTableLink' @() @{} @()) }

    # ---- blocks: one oneOf entry per cmdlet, discriminated by 'type'
    $byCmd = [ordered]@{}
    foreach ($t in ($script:DhTypeToCmdlet.Keys | Sort-Object)) {
        $c = $script:DhTypeToCmdlet[$t]
        if (-not $byCmd.Contains($c)) { $byCmd[$c] = [System.Collections.Generic.List[string]]::new() }
        $byCmd[$c].Add($t)
    }
    $variants = foreach ($c in $byCmd.Keys) {
        $p = & $newMap; $p['type'] = [ordered]@{ enum = @($byCmd[$c]) }
        foreach ($kv in (& $propsFor $c @('Report') @{}).GetEnumerator()) { $p[$kv.Key] = $kv.Value }
        foreach ($k in $internal.Keys) { $p[$k] = $internal[$k] }
        foreach ($k in 'Thresholds', 'Badge', 'Mode') { if (-not $p.Contains($k)) { $p[$k] = [ordered]@{} } }   # written for some blocks, ignored when reading
        [ordered]@{ title = $c; type = 'object'; properties = $p; required = @('type'); additionalProperties = $false }
    }
    $top['blocks'] = [ordered]@{ type = 'array'; items = [ordered]@{ oneOf = @($variants) } }

    $schema = [ordered]@{
        '$schema'            = 'http://json-schema.org/draft-07/schema#'
        title                = 'DashHtml layout'
        description          = 'Layout file for ConvertFrom-DhYaml (DashHtml.Design). Generated by Export-DhYamlSchema from the live cmdlet metadata.'
        type                 = 'object'
        properties           = $top
        anyOf                = @([ordered]@{ required = @('title') }, [ordered]@{ required = @('Title') })
        additionalProperties = $false
    }
    if ($AsObject) { return $schema }
    $json = ($schema | ConvertTo-Json -Depth 50) -replace "`r`n", "`n"
    if ($OutFile) {
        # a relative path is relative to the PowerShell location; .NET would resolve it against the process directory
        $OutFile = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutFile)
        [IO.File]::WriteAllText($OutFile, $json + "`n", (New-Object Text.UTF8Encoding($false)))
        Write-Verbose "Export-DhYamlSchema: wrote $OutFile"
    } else { $json }
}