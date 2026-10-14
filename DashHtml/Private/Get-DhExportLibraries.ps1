function Get-DhExportLibraries {
    <#
    .SYNOPSIS  The XLSX / PDF export libraries: the ONE place their versions,
               CDN URLs and SRI hashes are listed (v2.2.0).
    .DESCRIPTION
        Order matters: jsPDF must load before AutoTable, which patches it.
        Upgrading a library means changing the entry here and the file in
        DashHtml\Vendor\ (see Vendor\README.md); the SRI test pins both.
    #>
    [CmdletBinding()]
    param()
    @(
        [ordered]@{ Key = 'xlsx';      File = 'xlsx.full.min.js';              Version = '0.18.5'
                    Url = 'https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js'
                    Sri = 'sha384-vtjasyidUo0kW94K5MXDXntzOJpQgBKXmE7e2Ga4LG0skTTLeBi97eFAXsqewJjw' }
        [ordered]@{ Key = 'jspdf';     File = 'jspdf.umd.min.js';              Version = '2.5.1'
                    Url = 'https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js'
                    Sri = 'sha384-JcnsjUPPylna1s1fvi1u12X5qjY5OL56iySh75FdtrwhO/SWXgMjoVqcKyIIWOLk' }
        [ordered]@{ Key = 'autotable'; File = 'jspdf.plugin.autotable.min.js'; Version = '3.8.2'
                    Url = 'https://cdnjs.cloudflare.com/ajax/libs/jspdf-autotable/3.8.2/jspdf.plugin.autotable.min.js'
                    Sri = 'sha384-fCAW/rDWORTbQXSiB7mOg0QtQ5c+r0f544y6XoKjuVva0nMBlCpNUjiFeG5iMdS3' }
    )
}

function Get-DhExportLibraryConfigJson {
    <#
    .SYNOPSIS  JSON for the runtime's EXPORT_LIBS: the mode plus, for Cdn, where
               to fetch each library and the hash it must match.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [ValidateSet('cdn','embed','none')] [string] $Mode)
    $libs = (Get-DhExportLibraries | ForEach-Object {
        "$(ConvertTo-DhJsonString $_.Key):{`"url`":$(ConvertTo-DhJsonString $_.Url),`"sri`":$(ConvertTo-DhJsonString $_.Sri)}"
    }) -join ','
    "{`"mode`":$(ConvertTo-DhJsonString $Mode),`"libs`":{$libs}}"
}

function Get-DhEmbeddedExportLibraries {
    <#
    .SYNOPSIS  <script> elements that inline the vendored libraries (-ExportLibraries Embed).
    .DESCRIPTION
        Each file is checked against its pinned SRI hash before it is embedded,
        so Embed always runs exactly the code Cdn would load, and a tampered or
        half-written file is refused rather than shipped.

        Each library gets its own <script> element and is inlined UNCHANGED.
        Rewriting minified code to escape markup is not safe (inside a regex
        literal, '<\s' no longer means '<s'), so instead the two sequences that
        could end or derail an inline script are refused:
          - '</script'  closes the element early;
          - '<!--' together with '<script' in the same element puts the HTML
            parser in a state where '</script>' no longer closes it.
        The pinned versions contain neither combination.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    $vendor = Join-Path (Split-Path $PSScriptRoot -Parent) 'Vendor'
    $sb = [System.Text.StringBuilder]::new()
    $total = 0
    foreach ($lib in Get-DhExportLibraries) {
        $path = Join-Path $vendor $lib.File
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Export-DhDashboard -ExportLibraries Embed: '$($lib.File)' is missing from $vendor. Reinstall the module, or use -ExportLibraries Cdn."
        }
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $hash  = 'sha384-' + [System.Convert]::ToBase64String([System.Security.Cryptography.SHA384]::HashData($bytes))
        if ($hash -ne $lib.Sri) {
            throw "Export-DhDashboard -ExportLibraries Embed: $path does not match its pinned hash ($($lib.Key) $($lib.Version)). Refusing to embed it."
        }
        $code = [System.Text.Encoding]::UTF8.GetString($bytes)
        if ($code -match '(?i)</script' -or ($code.Contains('<!--') -and $code -match '(?i)<script')) {
            throw "Export-DhDashboard -ExportLibraries Embed: $($lib.File) contains markup that would break out of an inline <script>. Refusing to embed it."
        }
        $total += $bytes.Length
        [void]$sb.AppendLine("  <script data-dh-lib=`"$($lib.Key)`" data-dh-version=`"$($lib.Version)`">")
        [void]$sb.AppendLine($code)
        [void]$sb.AppendLine('  </script>')
        if ($lib.Key -eq 'jspdf') {
            # jsPDF 2.x UMD exposes window.jspdf.jsPDF; AutoTable looks for window.jsPDF
            [void]$sb.AppendLine('  <script>if(window.jspdf&&window.jspdf.jsPDF&&!window.jsPDF){window.jsPDF=window.jspdf.jsPDF;}</script>')
        }
    }
    # Verbose, not a warning: Embed is an explicit choice, and a warning on every
    # run would teach people to ignore warnings. The size is in the help text.
    Write-Verbose ("Export-DhDashboard: -ExportLibraries Embed adds {0:N1} MB of XLSX/PDF library code to the report." -f ($total / 1MB))
    $sb.ToString()
}
