@{
    RootModule        = 'DashHtml.Design.psm1'
    ModuleVersion     = '2.5.3'
    GUID              = 'b7e4c1a9-6d2f-4a83-9c15-2e8f7a4b1d60'
    Author            = 'Nicola Viganò'
    CompanyName       = 'Nicola Viganò'
    Copyright         = '(c) 2026 Nicola Viganò. MIT License.'
    Description       = 'Design / round-trip companion tools for DashHtml: convert a DashHtml report object to a declarative YAML layout spec, generate a runnable PowerShell build script from YAML/JSON, and derive a best-effort YAML layout from an existing DashHtml .ps1 script. Self-contained (no YAML dependency); makes no changes to the core DashHtml module.'
    PowerShellVersion = '7.0'

    # DashHtml.Design is a companion, not a standalone module: ConvertFrom-DhYaml
    # drives its codegen off the core module's live cmdlet metadata (Get-Command),
    # and every generated build script starts with 'Import-Module DashHtml'.
    # Declaring the dependency makes Install-PSResource / Install-Module pull the
    # core in automatically and shows it on the gallery page.
    # 2.0.0 is the floor: Update-DhScript audits the 2.0.0 upgrade, and the
    # codegen picks up -NavPath / -NavScope from live cmdlet metadata.
    # ModuleVersion here means "minimum".
    RequiredModules   = @(
        @{ ModuleName = 'DashHtml'; ModuleVersion = '2.5.2' }
    )

    FunctionsToExport = @(
        'ConvertTo-DhYaml'
        'ConvertFrom-DhYaml'
        'ConvertFrom-DhScript'
        'Export-DhYamlSchema'
        'Update-DhScript'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('DashHtml','YAML','Dashboard','CodeGen','Design','Layout')
            LicenseUri   = 'https://github.com/nicola-vi/DashHtml/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/nicola-vi/DashHtml'
            ReleaseNotes = '2.5.3 - Export-DhYamlSchema -OutFile with a relative path now writes under the current PowerShell location (it used the process directory). 2.5.2 - New Export-DhYamlSchema and dashhtml.schema.json: a JSON Schema of the layout YAML generated from the live cmdlet metadata (editor completion, typo detection). Requires DashHtml 2.5.2. 2.5.1 - ConvertTo-DhYaml writes the 2.5.0 menu options (navLayout, navMaxDepth, navAllLabel, navTree, strictNav, navOverflow) that were dropped before, and generated scripts keep ordered hashtables. Requires DashHtml 2.5.1. 2.5.0 - Add-DhTreeTable and the 2.5.0 options round-trip through YAML. 2.4.0 and older - Network map, tree filter, findings, key/value and record list blocks round-trip; Update-DhScript audits them (see CHANGELOG.md). 2.0.0 - Update-DhScript, ConvertTo-DhYaml, ConvertFrom-DhYaml, ConvertFrom-DhScript.'
        }
    }
}




