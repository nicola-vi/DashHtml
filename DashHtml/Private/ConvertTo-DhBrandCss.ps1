<#
    Brand colours and font (DashHtml 3.0.0).

    New-DhDashboard -PrimaryColor / -SecondaryColor / -AccentColor / -FontFamily
    are applied as one extra :root block placed after a theme's own :root block,
    in both the light and the dark <style> tag, so nothing in the structural CSS
    or the runtime changes. This file is the one place that turns the brand into
    tokens:

      Primary   --accent-primary, --chart-1 (the colour as given in light mode),
                --accent-primary-fg (black or white, whichever reads better),
                --text-accent, --nav-active-fg, --nav-link-hover-fg (a shade of
                the same hue that clears 4.5:1 on every background the theme
                defines), the row hover / selection tints, the nav tints, the
                strong border and the glow.
      Secondary --bg-header (the header band) and --accent-secondary, with the
                header text black or white. Defaults to a darker shade of Primary.
                --bg-header-end, the gradient's other stop, is the Primary hue as
                bright as the header text allows (5.1:1, so muted text keeps 4.5:1).
      Accent    --chart-2 and --header-line (the line under the header).
      Font      --font-ui and --font-display: the family first, the theme's own
                stack after it.

    Dark mode uses lighter shades of the same hues, found the same way, and a deep
    tint of Secondary for the band (at least 1.30 against the page, the 2.7.0 band
    rule). Status colours (ok / warn / danger / nodata), the RAG and range ramps
    are never touched: severity keeps its meaning in every brand.

    Contrast that cannot be reached is a warning, never an error (rule D4).
#>

function ConvertFrom-DhCssColor {
    <# '#rgb' / '#rrggbb' / '#rrggbbaa' / 'rgba(r,g,b,a)' -> @(r, g, b, a) with r/g/b in 0..1; $null otherwise. #>
    param([string] $Value)
    $v = $Value.Trim()
    if ($v -match '^#([0-9a-fA-F]{3})$') {
        $h = $Matches[1]
        return @(([Convert]::ToInt32("$($h[0])$($h[0])", 16) / 255), ([Convert]::ToInt32("$($h[1])$($h[1])", 16) / 255), ([Convert]::ToInt32("$($h[2])$($h[2])", 16) / 255), 1.0)
    }
    if ($v -match '^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$') {
        $h = $Matches[1]
        $a = if ($Matches[2]) { [Convert]::ToInt32($Matches[2], 16) / 255 } else { 1.0 }
        return @(([Convert]::ToInt32($h.Substring(0, 2), 16) / 255), ([Convert]::ToInt32($h.Substring(2, 2), 16) / 255), ([Convert]::ToInt32($h.Substring(4, 2), 16) / 255), $a)
    }
    if ($v -match '^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)$') {
        $a = if ($Matches[4]) { [double]$Matches[4] } else { 1.0 }
        return @(([double]$Matches[1] / 255), ([double]$Matches[2] / 255), ([double]$Matches[3] / 255), $a)
    }
    return $null
}

function ConvertTo-DhHexColor {
    param([double[]] $Rgb)
    '#' + (($Rgb[0..2] | ForEach-Object { '{0:X2}' -f [int][math]::Round([math]::Min(1.0, [math]::Max(0.0, $_)) * 255) }) -join '')
}

function ConvertTo-DhRgbaCss {
    param([double[]] $Rgb, [double] $Alpha)
    $c = $Rgb[0..2] | ForEach-Object { [int][math]::Round($_ * 255) }
    "rgba($($c[0]),$($c[1]),$($c[2]),$($Alpha.ToString([Globalization.CultureInfo]::InvariantCulture)))"
}

function ConvertTo-DhHsl {
    <# rgb (0..1) -> @(h 0..360, s 0..1, l 0..1) #>
    param([double[]] $Rgb)
    $r, $g, $b = $Rgb[0], $Rgb[1], $Rgb[2]
    $max = [math]::Max($r, [math]::Max($g, $b)); $min = [math]::Min($r, [math]::Min($g, $b))
    $l = ($max + $min) / 2; $d = $max - $min
    if ($d -eq 0) { return @(0.0, 0.0, $l) }
    $s = if ($l -gt 0.5) { $d / (2 - $max - $min) } else { $d / ($max + $min) }
    $h = if ($max -eq $r) { (($g - $b) / $d) + $(if ($g -lt $b) { 6 } else { 0 }) }
         elseif ($max -eq $g) { (($b - $r) / $d) + 2 }
         else { (($r - $g) / $d) + 4 }
    return @(($h * 60), $s, $l)
}

function ConvertFrom-DhHsl {
    param([double] $H, [double] $S, [double] $L)
    if ($S -eq 0) { return @($L, $L, $L, 1.0) }
    $q = if ($L -lt 0.5) { $L * (1 + $S) } else { $L + $S - $L * $S }
    $p = 2 * $L - $q
    $hk = $H / 360
    $out = foreach ($t in @(($hk + 1/3), $hk, ($hk - 1/3))) {
        $tt = $t; if ($tt -lt 0) { $tt += 1 }; if ($tt -gt 1) { $tt -= 1 }
        if ($tt -lt 1/6) { $p + ($q - $p) * 6 * $tt }
        elseif ($tt -lt 1/2) { $q }
        elseif ($tt -lt 2/3) { $p + ($q - $p) * (2/3 - $tt) * 6 }
        else { $p }
    }
    return @($out[0], $out[1], $out[2], 1.0)
}

function Get-DhRelativeLuminance {
    <# WCAG 2.x relative luminance of an opaque rgb (0..1). #>
    param([double[]] $Rgb)
    # Plain arithmetic, no pipeline: this runs a few thousand times per brand.
    $r = $Rgb[0]; $g = $Rgb[1]; $b = $Rgb[2]
    $r = if ($r -le 0.03928) { $r / 12.92 } else { [math]::Pow(($r + 0.055) / 1.055, 2.4) }
    $g = if ($g -le 0.03928) { $g / 12.92 } else { [math]::Pow(($g + 0.055) / 1.055, 2.4) }
    $b = if ($b -le 0.03928) { $b / 12.92 } else { [math]::Pow(($b + 0.055) / 1.055, 2.4) }
    return 0.2126 * $r + 0.7152 * $g + 0.0722 * $b
}

function Get-DhContrastRatio {
    param([double[]] $A, [double[]] $B)
    $la = Get-DhRelativeLuminance $A; $lb = Get-DhRelativeLuminance $B
    return ([math]::Max($la, $lb) + 0.05) / ([math]::Min($la, $lb) + 0.05)
}

function Merge-DhColor {
    <# $Fg at $Alpha over an opaque $Bg. #>
    param([double[]] $Fg, [double[]] $Bg, [double] $Alpha)
    return @(($Fg[0] * $Alpha + $Bg[0] * (1 - $Alpha)), ($Fg[1] * $Alpha + $Bg[1] * (1 - $Alpha)), ($Fg[2] * $Alpha + $Bg[2] * (1 - $Alpha)), 1.0)
}

function Find-DhShade {
    <#
        The shade of $Rgb's hue (lightness moved towards black or white) closest to
        the original that reaches $Min contrast against every colour in
        $Backgrounds. Returns @{ Rgb; Ok; Ratio }; Ok is $false when even the
        extreme does not reach it (the extreme is returned).
    #>
    param([double[]] $Rgb, [object[]] $Backgrounds, [double] $Min, [ValidateSet('darker','lighter')] [string] $Direction)
    $hsl = ConvertTo-DhHsl $Rgb
    $worst = { param($c) $m = [double]::MaxValue; foreach ($bg in $Backgrounds) { $r = Get-DhContrastRatio $c $bg; if ($r -lt $m) { $m = $r } }; $m }
    $ratio = & $worst $Rgb
    if ($ratio -ge $Min) { return @{ Rgb = $Rgb; Ok = $true; Ratio = $ratio } }
    $l = $hsl[2]
    $step = if ($Direction -eq 'darker') { -0.01 } else { 0.01 }
    $cand = $Rgb
    while (($Direction -eq 'darker' -and $l -gt 0) -or ($Direction -eq 'lighter' -and $l -lt 1)) {
        $l = [math]::Min(1.0, [math]::Max(0.0, $l + $step))
        $cand = ConvertFrom-DhHsl $hsl[0] $hsl[1] $l
        $ratio = & $worst $cand
        if ($ratio -ge $Min) { return @{ Rgb = $cand; Ok = $true; Ratio = $ratio } }
    }
    return @{ Rgb = $cand; Ok = $false; Ratio = $ratio }
}

function Get-DhThemeTokens {
    <# '--name: value;' pairs of a theme's :root block, as an ordered name -> value map. #>
    param([string] $RootCss)
    $t = [ordered]@{}
    foreach ($m in [regex]::Matches($RootCss, '--([a-z0-9-]+)\s*:\s*([^;]+);')) { $t[$m.Groups[1].Value] = $m.Groups[2].Value.Trim() }
    return $t
}

function ConvertTo-DhBrandCss {
    <#
    .SYNOPSIS
        The brand override :root block for one theme variant, and the contrast
        warnings it raises.

    .PARAMETER Brand
        The report's Brand map: PrimaryColor, SecondaryColor, AccentColor (hex,
        each optional) and FontFamily.

    .PARAMETER Theme
        The internal theme name (DefaultLight, CompanyDark ...). Its own tokens
        are the backgrounds the derived colours are checked against.

    .OUTPUTS
        @{ Css = [string]; Warnings = [string[]] }   Css is '' when nothing applies.
    #>
    param(
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Brand,
        [Parameter(Mandatory)] [string] $Theme
    )

    $tok  = Get-DhThemeTokens (Get-DhThemeCss -Theme $Theme -RootOnly)
    $dark = $Theme -like '*Dark'
    $mode = if ($dark) { 'dark' } else { 'light' }
    $dir  = if ($dark) { 'lighter' } else { 'darker' }
    $warn = [System.Collections.Generic.List[string]]::new()
    $out  = [System.Collections.Generic.List[string]]::new()
    $col  = { param($name) if ($tok.Contains($name)) { ConvertFrom-DhCssColor $tok[$name] } else { $null } }
    $opaque = { param($c, $under) if ($null -eq $c) { $null } elseif ($c[3] -lt 1) { Merge-DhColor $c $under $c[3] } else { $c } }
    $hex  = { param($c) ConvertTo-DhHexColor $c }
    $fmt  = { param([double] $r) $r.ToString('0.00', [Globalization.CultureInfo]::InvariantCulture) }

    $page    = & $col 'bg-page'
    $surface = & $col 'bg-surface'
    $table   = & $col 'bg-table'
    if (-not $table) { $table = $surface }
    $navBg   = & $col 'nav-bg'
    if (-not $navBg) { $navBg = $surface }
    # Every background accent-coloured text can land on (the 2.7.0 token contract, rule 2).
    $textBgs = @(foreach ($n in 'bg-surface', 'bg-page', 'bg-row-alt', 'bg-thead', 'chart-container-bg', 'bg-table') {
        $c = & $col $n; if ($c) { , (& $opaque $c $page) }   # the comma keeps each colour one array
    })
    $white = @(1.0, 1.0, 1.0, 1.0)
    $ink   = ConvertFrom-DhCssColor '#10151B'
    $pickFg = { param($bg) if ((Get-DhContrastRatio $white $bg) -ge (Get-DhContrastRatio $ink $bg)) { $white } else { $ink } }

    $primary = if ($Brand.Contains('PrimaryColor') -and $Brand.PrimaryColor) { ConvertFrom-DhCssColor $Brand.PrimaryColor } else { $null }
    if ($primary) {
        # Light: the colour as given. Dark: a lighter shade of it that reads on the page.
        $accent = $primary
        if ($dark) { $accent = (Find-DhShade $primary $textBgs 4.5 'lighter').Rgb }
        elseif ((Get-DhContrastRatio $accent $surface) -lt 4.5) {
            $warn.Add("-PrimaryColor $($Brand.PrimaryColor) measures $(& $fmt (Get-DhContrastRatio $accent $surface)):1 on the $mode surface; links and accent-coloured values need 4.5:1 - a darker shade reads better (the menu and accent text use one automatically).")
        }
        $txt = Find-DhShade $accent $textBgs 4.5 $dir
        if (-not $txt.Ok) { $warn.Add("-PrimaryColor: no shade of the hue reaches 4.5:1 on every $mode background (best $(& $fmt $txt.Ratio):1).") }
        $aAct = if ($dark) { 0.14 } else { 0.08 }
        $aHov = if ($dark) { 0.10 } else { 0.06 }
        $navBgs = @($navBg, (Merge-DhColor $accent $navBg $aAct), (Merge-DhColor $accent $navBg $aHov))
        $nav = Find-DhShade $accent $navBgs 4.5 $dir
        if (-not $nav.Ok) { $warn.Add("-PrimaryColor: the selected menu item measures $(& $fmt $nav.Ratio):1 in $mode mode (needs 4.5:1).") }
        $hover = Merge-DhColor $accent $table $(if ($dark) { 0.24 } else { 0.14 })
        $sel   = Merge-DhColor $accent $table $(if ($dark) { 0.16 } else { 0.09 })
        $textPrimary = & $opaque (& $col 'text-primary') $page
        if ($textPrimary -and (Get-DhContrastRatio $textPrimary $hover) -lt 4.5) {
            $warn.Add("-PrimaryColor: row text on the hover tint measures $(& $fmt (Get-DhContrastRatio $textPrimary $hover)):1 in $mode mode (needs 4.5:1).")
        }
        $out.Add("  /* -PrimaryColor $($Brand.PrimaryColor) */")
        $out.Add("  --accent-primary:    $(& $hex $accent);")
        $out.Add("  --accent-primary-fg: $(& $hex (& $pickFg $accent));")
        $out.Add("  --text-accent:       $(& $hex $txt.Rgb);")
        $out.Add("  --chart-1:           $(& $hex $accent);")
        $out.Add("  --nav-active-fg:     $(& $hex $nav.Rgb);")
        $out.Add("  --nav-link-hover-fg: $(& $hex $nav.Rgb);")
        $out.Add("  --nav-active-bg:     $(ConvertTo-DhRgbaCss $accent $aAct);")
        $out.Add("  --nav-link-hover-bg: $(ConvertTo-DhRgbaCss $accent $aHov);")
        $out.Add("  --nav-active-border: $(ConvertTo-DhRgbaCss $accent $(if ($dark) { 0.35 } else { 0.40 }));")
        $out.Add("  --bg-row-hover:      $(& $hex $hover);")
        $out.Add("  --bg-row-sel:        $(& $hex $sel);")
        $out.Add("  --border-strong:     $(ConvertTo-DhRgbaCss $accent $(if ($dark) { 0.27 } else { 0.33 }));")
        $out.Add("  --shadow-glow:       0 0 $(if ($dark) { 16 } else { 12 })px $(ConvertTo-DhRgbaCss $accent $(if ($dark) { 0.13 } else { 0.15 }));")
    }

    # Secondary: given, or a darker shade of Primary so one colour rebrands the whole report.
    $second = if ($Brand.Contains('SecondaryColor') -and $Brand.SecondaryColor) { ConvertFrom-DhCssColor $Brand.SecondaryColor } else { $null }
    $secondLabel = if ($second) { "-SecondaryColor $($Brand.SecondaryColor)" } else { '' }
    if (-not $second -and $primary) {
        $h = ConvertTo-DhHsl $primary
        $second = ConvertFrom-DhHsl $h[0] $h[1] ($h[2] * 0.72)
        $secondLabel = "-SecondaryColor (from -PrimaryColor) $(& $hex $second)"
    }
    if ($second) {
        $band = $second
        if ($dark) {
            # A deep tint of the hue, just lighter than the page (2.7.0 band rule: >= 1.30).
            $h = ConvertTo-DhHsl $second
            $l = 0.10
            do { $band = ConvertFrom-DhHsl $h[0] ([math]::Min([double]$h[1], 0.6)) $l; $l += 0.01 }
            while ((Get-DhContrastRatio $band $page) -lt 1.30 -and $l -lt 0.5)
        }
        $headFg = & $pickFg $band
        $headRatio = Get-DhContrastRatio $headFg $band
        if ($headRatio -lt 4.5) { $warn.Add("${secondLabel}: header text measures $(& $fmt $headRatio):1 on the $mode header band (needs 4.5:1).") }
        # The gradient end: the Primary hue (else Secondary's), as bright as the header text
        # allows - 5.1:1 against it, so the 94% muted text still clears 4.5:1.
        $endSrc = if ($primary) { $primary } else { $second }
        $hEnd = ConvertTo-DhHsl $endSrc
        $bandL = (ConvertTo-DhHsl $band)[2]
        $end = $band
        if ($dark) {
            for ($l = $bandL; $l -le 0.34; $l += 0.005) {
                $c = ConvertFrom-DhHsl $hEnd[0] ([math]::Min([double]$hEnd[1], 0.65)) $l
                if ((Get-DhContrastRatio $headFg $c) -ge 5.1) { $end = $c } else { break }
            }
        } else {
            $endDir = if ($headFg[0] -gt 0.5) { 'darker' } else { 'lighter' }
            $end = (Find-DhShade $endSrc @(, $headFg) 5.1 $endDir).Rgb
            if ((Get-DhContrastRatio $headFg $end) -lt 4.5) { $end = $band }
        }
        # Deep colour on the left, as in every theme: swap when the brand put it on the right.
        $endDeeper = (Get-DhRelativeLuminance $end) -lt (Get-DhRelativeLuminance $band)
        if ($endDeeper -eq ($headFg[0] -gt 0.5)) { $band, $end = $end, $band }
        $sec = if ($dark) { (Find-DhShade $second @(, $surface) 3.0 'lighter').Rgb } else { $second }
        $out.Add("  /* $secondLabel */")
        $out.Add("  --bg-header:         $(& $hex $band);")
        $out.Add("  --bg-header-end:     $(& $hex $end);")
        $out.Add("  --accent-secondary:  $(& $hex $sec);")
        $out.Add("  --header-fg:         $(& $hex $headFg);")
        $out.Add("  --header-fg-muted:   $(ConvertTo-DhRgbaCss $headFg 0.94);")
    }

    $third = if ($Brand.Contains('AccentColor') -and $Brand.AccentColor) { ConvertFrom-DhCssColor $Brand.AccentColor } else { $null }
    if ($third) {
        $chartBg = & $opaque (& $col 'chart-container-bg') $page
        if (-not $chartBg) { $chartBg = $surface }
        $c2 = if ($dark) { (Find-DhShade $third @(, $chartBg) 3.0 'lighter').Rgb } else { $third }
        if ((Get-DhContrastRatio $c2 $chartBg) -lt 3.0) { $warn.Add("-AccentColor $($Brand.AccentColor) measures $(& $fmt (Get-DhContrastRatio $c2 $chartBg)):1 on the $mode chart background (chart marks need 3:1).") }
        $out.Add("  /* -AccentColor $($Brand.AccentColor) */")
        $out.Add("  --chart-2:           $(& $hex $c2);")
        $out.Add("  --header-line:       $(& $hex $third);")
    }

    if ($Brand.Contains('FontFamily') -and $Brand.FontFamily) {
        $out.Add("  /* -FontFamily $($Brand.FontFamily) */")
        foreach ($n in 'font-ui', 'font-display') {
            $stack = if ($tok.Contains($n)) { $tok[$n] } else { "'Segoe UI', system-ui, sans-serif" }
            $out.Add("  --${n}: '$($Brand.FontFamily)', $stack;")
        }
    }

    $css = if ($out.Count) { ":root {`n  /* DashHtml 3.0.0 brand ($mode) */`n" + ($out -join "`n") + "`n}`n" } else { '' }
    return @{ Css = $css; Warnings = @($warn) }
}

function Get-DhBrandFontFace {
    <# The @font-face rule for an embedded -FontFile, or '' when there is none. #>
    param([System.Collections.IDictionary] $Brand)
    if (-not ($Brand.Contains('FontData') -and $Brand.FontData -and $Brand.FontFamily)) { return '' }
    $fmt = switch ($Brand.FontMime) { 'font/woff2' { 'woff2' } 'font/woff' { 'woff' } 'font/otf' { 'opentype' } default { 'truetype' } }
    "@font-face { font-family: '$($Brand.FontFamily)'; src: url(data:$($Brand.FontMime);base64,$($Brand.FontData)) format('$fmt'); font-display: swap; }"
}
