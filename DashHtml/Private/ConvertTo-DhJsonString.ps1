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
    # Escape '/' after '<' to prevent </script> from breaking out of a <script> block
    $e = $e -replace '</', '<\/'
    # v1.5.3 - escape U+2028 / U+2029 as their explicit \u JSON sequence.
    # Source pattern (double-quoted): PowerShell expands the unicode escape to
    # the actual code point at parse time, so the regex matches the raw char.
    # Replacement (single-quoted) is the literal 6-char JSON escape.
    $e = $e -replace "`u{2028}", '\u2028'
    $e = $e -replace "`u{2029}", '\u2029'
    return "`"$e`""
}