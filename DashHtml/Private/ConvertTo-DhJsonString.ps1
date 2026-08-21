# Characters that force the full escape path below. Built once at module load
# rather than allocated per call. U+0000-U+001F covers tab / CR / LF along with
# the other C0 controls; '<' is included because of the '</' -> '<\/' rule.
$script:DhJsonEscapeChars = [char[]] @( (0x00..0x1F) + 0x5C + 0x22 + 0x3C + 0x2028 + 0x2029 )

function ConvertTo-DhJsonString {
    <#
    .SYNOPSIS  Escape a plain string for safe embedding as a JSON string value (including the surrounding quotes).
    .NOTES
        Complies with RFC 8259, section 7:
        - Escapes backslash, double-quote, tab, carriage-return, newline.
        - Escapes all remaining control characters U+0000-U+001F as \uXXXX.
        - Escapes forward-slash after '<' to prevent </script> from terminating
          an enclosing <script> block (XSS protection).
        - v1.5.3: also escapes U+2028 (LINE SEPARATOR) and U+2029 (PARAGRAPH
          SEPARATOR) as their explicit JSON \u escape - modern JS engines
          accept these inside string literals (ES2019+), but older parsers,
          linters, and log forwarders that scan dashboards still treat them
          as raw line terminators and break the embedded script block.
    #>
    param([string]$s)
    if ($null -eq $s) { return 'null' }
    # PERF fast path - the string contains nothing that any pass below would
    # rewrite, so skip all nine regex passes. Real table data is overwhelmingly
    # plain text, and the passes cost ~1.27 ms per call, which dominates
    # Export-DhDashboard on large reports. The trigger set is deliberately a
    # superset of what is actually rewritten (a lone '<' is harmless but still
    # takes the slow path) so the check can stay a single IndexOfAny.
    if ($s.IndexOfAny($script:DhJsonEscapeChars) -lt 0) { return "`"$s`"" }
    $e = $s `
        -replace '\\', '\\' `
        -replace '"',  '\"' `
        -replace "`t", '\t' `
        -replace "`r", ''   `
        -replace "`n", '\n'
    # Escape remaining control characters U+0000-U+001F (excluding \t \r \n already handled above)
    $e = [regex]::Replace($e, '[\x00-\x08\x0B\x0C\x0E-\x1F]', {
        param($m)
        '\u{0:x4}' -f [int][char]$m.Value[0]
    })
    # Escape '/' after '<' to prevent </script> from breaking out of a <script> block.
    # ORDER IS LOAD-BEARING: this must run AFTER the CR pass. CR is dropped rather
    # than escaped, so "<`r/script>" only collapses into "</script>" at this point
    # and is caught here. Folding these passes into a single regex over the
    # ORIGINAL string would never see that '</' and would emit it raw - a script
    # breakout. Verified: "a<`r/script>b" -> "a<\/script>b".
    $e = $e -replace '</', '<\/'
    # v1.5.3 - escape U+2028 / U+2029 as their explicit \u JSON sequence.
    # Source pattern (double-quoted): PowerShell expands the unicode escape to
    # the actual code point at parse time, so the regex matches the raw char.
    # Replacement (single-quoted) is the literal 6-char JSON escape.
    $e = $e -replace "`u{2028}", '\u2028'
    $e = $e -replace "`u{2029}", '\u2029'
    return "`"$e`""
}