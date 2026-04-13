function ConvertTo-DhJsonString {
    <#
    .SYNOPSIS  Escape a plain string for safe embedding as a JSON string value (including the surrounding quotes).
    .NOTES
        Complies with RFC 8259 §7:
        - Escapes backslash, double-quote, tab, carriage-return, newline.
        - Escapes all remaining control characters U+0000–U+001F as \uXXXX.
        - Escapes forward-slash after '<' to prevent </script> from terminating
          an enclosing <script> block (XSS protection).
    #>
    param([string]$s)
    if ($null -eq $s) { return 'null' }
    $e = $s `
        -replace '\\', '\\' `
        -replace '"',  '\"' `
        -replace "`t", '\t' `
        -replace "`r", ''   `
        -replace "`n", '\n'
    # Escape remaining control characters U+0000–U+001F (excluding \t \r \n already handled above)
    $e = [regex]::Replace($e, '[\x00-\x08\x0B\x0C\x0E-\x1F]', {
        param($m)
        '\u{0:x4}' -f [int][char]$m.Value[0]
    })
    # Escape '/' after '<' to prevent </script> from breaking out of a <script> block
    $e = $e -replace '</', '<\/'
    return "`"$e`""
}
