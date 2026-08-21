@{
    RootModule        = 'DashHtml.Design.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b7e4c1a9-6d2f-4a83-9c15-2e8f7a4b1d60'
    Author            = 'DashHtml Contributors'
    CompanyName       = 'DashHtml Contributors'
    Copyright         = '(c) 2026 DashHtml Contributors. MIT License.'
    Description       = 'Design / round-trip companion tools for DashHtml: convert a DashHtml report object to a declarative YAML layout spec, generate a runnable PowerShell build script from YAML/JSON, and derive a best-effort YAML layout from an existing DashHtml .ps1 script. Self-contained (no YAML dependency); makes no changes to the core DashHtml module.'
    PowerShellVersion = '7.0'

    # DashHtml.Design is a companion, not a standalone module: ConvertFrom-DhYaml
    # drives its codegen off the core module's live cmdlet metadata (Get-Command),
    # and every generated build script starts with 'Import-Module DashHtml'.
    # Declaring the dependency makes Install-PSResource / Install-Module pull the
    # core in automatically and shows it on the gallery page.
    # 1.10.0 is the floor: -GridSpan (1.10.0) and Add-DhGlobalFilter (1.9.0) are
    # both in the type/parameter map. ModuleVersion here means "minimum".
    RequiredModules   = @(
        @{ ModuleName = 'DashHtml'; ModuleVersion = '1.10.0' }
    )

    FunctionsToExport = @(
        'ConvertTo-DhYaml'
        'ConvertFrom-DhYaml'
        'ConvertFrom-DhScript'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('DashHtml','YAML','Dashboard','CodeGen','Design','Layout')
            LicenseUri   = 'https://github.com/nicola-vi/DashHtml/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/nicola-vi/DashHtml'
            ReleaseNotes = '1.0.0 — Initial release. ConvertTo-DhYaml (report -> YAML, lossless), ConvertFrom-DhYaml (YAML/JSON -> runnable .ps1 build script, driven by live cmdlet metadata), ConvertFrom-DhScript (best-effort static .ps1 -> YAML). Self-contained YAML reader/writer, no external dependency. Companion to DashHtml; no core changes.'
        }
    }
}

