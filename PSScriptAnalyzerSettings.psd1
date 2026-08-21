@{
    # PSScriptAnalyzer configuration for DashHtml.
    # Consumed by Build.ps1 (Invoke-ScriptAnalyzer -Settings .\PSScriptAnalyzerSettings.psd1).
    #
    # The build FAILS on any Error-severity finding and reports Warnings without
    # failing. Rules excluded below are documented false-positives for this
    # codebase — each exclusion has a rationale so the list doesn't rot into a
    # blanket "silence everything".

    IncludeDefaultRules = $true

    Severity = @('Error', 'Warning')

    ExcludeRules = @(
        # ── PSUseBOMForUnicodeEncodedFile ────────────────────────────────────
        # Fires on the 35 source files containing non-ASCII characters (theme
        # glyphs, box-drawing comment banners, chevrons in the JS template).
        # The manifest requires PowerShell 7.0+, which reads UTF-8 without a BOM
        # correctly. Adding BOMs would churn every file for a Windows PowerShell
        # 5.1 compatibility we don't claim.
        'PSUseBOMForUnicodeEncodedFile'

        # ── PSReviewUnusedParameter ──────────────────────────────────────────
        # Fires 4x on the `param($m)` in [regex]::Replace MatchEvaluator script
        # blocks in Export-DhDashboard.ps1 (~line 579-582). The MatchEvaluator
        # delegate signature REQUIRES that parameter; the bodies deliberately
        # ignore it and return the JSON verbatim, which is the entire point of
        # using MatchEvaluator over -replace (see the comment block above those
        # lines re: $& / $' backreference expansion corrupting the payload).
        'PSReviewUnusedParameter'

        # ── PSUseSingularNouns ───────────────────────────────────────────────
        # Fires on Add-DhTabs, Build-DhTableSections, ConvertTo-DhRagThresholds.
        # All three genuinely operate on collections — Add-DhTabs adds a tab
        # STRIP (multiple tabs in one block), Build-DhTableSections emits every
        # section in one pass. Renaming to singular would be actively misleading,
        # and Add-DhTabs is a shipped public API we won't break for style.
        'PSUseSingularNouns'

        # ── PSUseShouldProcessForStateChangingFunctions ──────────────────────
        # Fires on New-DhDashboard and Set-DhTableLink. Neither touches system
        # state: New-DhDashboard builds an in-memory OrderedDictionary, and
        # Set-DhTableLink mutates that in-memory object. The only cmdlet that
        # actually writes to disk — Export-DhDashboard — DOES implement
        # SupportsShouldProcess and calls $PSCmdlet.ShouldProcess() correctly.
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
