function Get-DhCssGreyDark {
    <#
    .SYNOPSIS  Returns the :root variable block for the GreyDark theme.
               Called by Get-DhThemeCss which appends the shared structural CSS.
    #>
    return @'
:root {
  /* GreyDark — Cool dark neutral grey, blue-grey muted accent
     Easy on the eyes for long sessions, no strong colour cast */

  --bg-page:          #1A1A1A;
  --bg-header:        #1A1A1A;
  --bg-surface:       #242424;
  --bg-table:         #1E1E1E;
  --bg-row-alt:       #2A2A2A;
  --bg-row-hover:     #4A4A4A;
  --bg-row-sel:       #1E3040;
  --bg-thead:         #2D2D2D;

  --accent-primary:   #78909C;
  --accent-secondary: #546E7A;
  --accent-danger:    #EF5350;
  --accent-warn:      #FFB300;
  --accent-ok:        #66BB6A;

  --export-csv-bg:    #0E2A12;  --export-csv-fg:    #66BB6A;  --export-csv-bdr:   #1A4422;
  --export-xlsx-bg:   #0E2A12;  --export-xlsx-fg:   #81C784;  --export-xlsx-bdr:  #1A4422;
  --export-pdf-bg:    #2A1010;  --export-pdf-fg:    #EF5350;  --export-pdf-bdr:   #441414;

  --text-primary:   #E0E0E0;
  --text-secondary: #9E9E9E;
  --text-muted:     #616161;
  --text-accent:    #90A4AE;
  --text-invert:    #1A1A1A;

  --border-subtle:  #303030;
  --border-medium:  #3E3E3E;
  --border-strong:  #78909C44;

  --font-ui:      'Segoe UI', 'SF Pro Text', system-ui, -apple-system, sans-serif;
  --font-mono:    'JetBrains Mono', 'Cascadia Code', 'Consolas', monospace;
  --font-display: 'Segoe UI', 'SF Pro Display', system-ui, -apple-system, sans-serif;

  --size-xs:    0.75rem;
  --size-sm:    0.85rem;
  --size-base:  0.9375rem;
  --size-md:    1.05rem;
  --size-lg:    1.30rem;
  --size-xl:    1.65rem;

  --weight-normal: 400;
  --weight-medium: 500;
  --weight-bold:   700;

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

  --shadow-md:   0 4px 16px rgba(0,0,0,0.65);
  --shadow-glow: 0 0 14px rgba(120,144,156,0.14);

  --cell-ok-fg:      #81C784;  --cell-ok-bg:      rgba(129,199,132,0.10);
  --cell-warn-fg:    #FFB74D;  --cell-warn-bg:    rgba(255,183,77,0.10);
  --cell-danger-fg:  #E57373;  --cell-danger-bg:  rgba(229,115,115,0.10);

  --progress-track-bg: rgba(255,255,255,0.07);

  --nav-bg:            #1A1A1A;
  --nav-border:        #303030;
  --nav-title-fg:      #5A5A5A;
  --nav-link-fg:       #9E9E9E;
  --nav-link-hover-bg: rgba(120,144,156,0.09);
  --nav-link-hover-fg: #B0BEC5;
  --nav-active-bg:     rgba(120,144,156,0.14);
  --nav-active-fg:     #CFD8DC;
  --nav-active-border: rgba(120,144,156,0.40);

  --chart-container-bg: #1E1E1E;
  --chart-1: #78909C;  --chart-2: #81C784;  --chart-3: #FFB74D;  --chart-4: #E57373;
  --chart-5: #CE93D8;  --chart-6: #FFAB40;  --chart-7: #4DD0E1;  --chart-8: #C5E1A5;

  /* Header text — ensures legibility on both light and dark header backgrounds */
  --header-fg: #E0E0E0;
  --header-fg-muted: #9E9E9E;
}
'@
}
