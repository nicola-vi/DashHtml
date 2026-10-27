function Get-DhCssCompanyLight {
    <#
    .SYNOPSIS  Returns the :root variable block for the CompanyLight theme.
               Called by Get-DhThemeCss which appends the shared structural CSS.
    #>
    return @'
:root {
  /* CompanyLight — Company brand: Crimson Glory #BE0036, Montserrat, white */
  --company-crimson:   #BE0036;
  --company-jet:       #333333;

  --bg-page:          #FFFFFF;
  --bg-header:        #8C0031;
  --bg-surface:       #FFFFFF;
  --bg-table:         #FFFFFF;
  --bg-row-alt:       #FAFBFC;
  --bg-row-hover:     #FFD4DD;
  --bg-row-sel:       #FFE0E6;
  --bg-thead:         #F5F5F5;

  --accent-primary:   #BE0036;

  --accent-primary-fg: #ffffff;   /* v1.10.2 - readable text on the accent background */
  --accent-secondary: #8C0031;
  --accent-danger:    #BE0036;

  /* Range-gradient bar stops (v2.1.0) - one continuous scale across the
     0-100 axis, mapped onto this theme's own severity ramp. */
  --range-grad-0:   #1B7A2E;
  --range-grad-50:  #E05000;
  --range-grad-100: #BE0036;
  --accent-warn:      #E05000;
  --accent-ok:        #1B7A2E;

  --export-csv-bg:    #E8F5E9;  --export-csv-fg:    #2E7D32;  --export-csv-bdr:   #C8E6C9;
  --export-xlsx-bg:   #E8F5E9;  --export-xlsx-fg:   #388E3C;  --export-xlsx-bdr:  #A5D6A7;
  --export-pdf-bg:    #FEECE9;  --export-pdf-fg:    #BE0036;  --export-pdf-bdr:   #FFCDD2;

  --text-primary:   #333333;
  --text-secondary: #555555;
  --text-muted:     #626262;
  --text-accent:    #BE0036;
  --text-invert:    #FFFFFF;

  --border-subtle:  #EBEBEB;
  --border-medium:  #D5D5D5;
  --border-strong:  #BE003655;

  --font-ui:      'Montserrat', 'Segoe UI', system-ui, sans-serif;
  --font-mono:    'JetBrains Mono', 'Cascadia Code', 'Consolas', monospace;
  --font-display: 'Montserrat', 'Segoe UI', system-ui, sans-serif;

  --size-2xs:    0.72rem;  /* 11.5px - hard floor, badges and chips only */

  --size-xs:    0.75rem;
  --size-sm:    0.85rem;
  --size-base:  0.9375rem;
  --size-md:    1.05rem;
  --size-lg:    1.30rem;
  --size-xl:    1.65rem;

  --weight-normal: 400;
  --weight-medium: 500;
  --weight-bold:   700;

  --track-tight:  -0.02em;   /* display numerals, report title */
  --track-none:   0;
  --track-label:  0.04em;    /* the few remaining uppercase labels */

  --space-xs:  4px;
  --space-sm:  8px;
  --space-md:  16px;
  --space-lg:  24px;
  --space-xl:  36px;

  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;

  --trans-fast:   150ms ease;
  --trans-normal: 250ms ease;

  --row-height:    40px;
  --header-height: 76px;
  --nav-height:    44px;

  --shadow-md:   0 2px 10px rgba(0,0,0,0.08);
  --shadow-glow: 0 0 12px rgba(190,0,54,0.15);

  --cell-ok-fg:      #186E29;  --cell-ok-bg:      rgba(27,122,46,0.08);
  --cell-warn-fg:    #A23F00;  --cell-warn-bg:    rgba(184,72,0,0.08);
  --cell-danger-fg:  #BE0036;  --cell-danger-bg:  rgba(190,0,54,0.08);
  --cell-nodata-fg:  #5F5F5F;  --cell-nodata-bg:  rgba(122,122,122,0.08);

  --progress-track-bg: rgba(0,0,0,0.07);

  --nav-bg:            #FFFFFF;
  --nav-border:        #EBEBEB;
  --nav-title-fg:      #676767;
  --nav-link-fg:       #555555;
  --nav-link-hover-bg: rgba(190,0,54,0.06);
  --nav-link-hover-fg: #BE0036;
  --nav-active-bg:     rgba(190,0,54,0.08);
  --nav-active-fg:     #BE0036;
  --nav-active-border: rgba(190,0,54,0.40);

  --chart-container-bg: #FAFBFC;
  --chart-1: #BE0036;  --chart-2: #E81B44;  --chart-3: #E05000;  --chart-4: #1B7A2E;
  --chart-5: #0077BB;  --chart-6: #8844CC;  --chart-7: #007A6A;  --chart-8: #8C0031;

  /* Header text — ensures legibility on both light and dark header backgrounds */
  --header-fg: #FFFFFF;
  --header-fg-muted: rgba(255,255,255,0.94);
}
'@
}
