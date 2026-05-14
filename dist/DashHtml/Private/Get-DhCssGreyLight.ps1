function Get-DhCssGreyLight {
    <#
    .SYNOPSIS  Returns the :root variable block for the GreyLight theme.
               Called by Get-DhThemeCss which appends the shared structural CSS.
    #>
    return @'
:root {
  /* GreyLight — Neutral warm grey palette, blue-grey steel accent
     No strong colour bias — professional, print-friendly feel */

  --bg-page:          #EEEEEE;
  --bg-header:        #455A64;
  --bg-surface:       #F5F5F5;
  --bg-table:         #FAFAFA;
  --bg-row-alt:       #F0F0F0;
  --bg-row-hover:     #C9D4DB;
  --bg-row-sel:       #CFD8DC;
  --bg-thead:         #E0E0E0;

  --accent-primary:   #546E7A;
  --accent-secondary: #37474F;
  --accent-danger:    #C62828;
  --accent-warn:      #E65100;
  --accent-ok:        #2E7D32;

  --export-csv-bg:    #E8F5E9;  --export-csv-fg:    #2E7D32;  --export-csv-bdr:   #C8E6C9;
  --export-xlsx-bg:   #E8F5E9;  --export-xlsx-fg:   #388E3C;  --export-xlsx-bdr:  #C8E6C9;
  --export-pdf-bg:    #FEECE9;  --export-pdf-fg:    #C62828;  --export-pdf-bdr:   #FFCDD2;

  --text-primary:   #263238;
  --text-secondary: #546E7A;
  --text-muted:     #90A4AE;
  --text-accent:    #37474F;
  --text-invert:    #FFFFFF;

  --border-subtle:  #E0E0E0;
  --border-medium:  #BDBDBD;
  --border-strong:  #546E7A55;

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

  --shadow-md:   0 2px 8px rgba(0,0,0,0.12);
  --shadow-glow: 0 0 12px rgba(84,110,122,0.16);

  --cell-ok-fg:      #2E7D32;  --cell-ok-bg:      rgba(46,125,50,0.08);
  --cell-warn-fg:    #BF360C;  --cell-warn-bg:    rgba(191,54,12,0.08);
  --cell-danger-fg:  #B71C1C;  --cell-danger-bg:  rgba(183,28,28,0.08);

  --progress-track-bg: rgba(0,0,0,0.08);

  --nav-bg:            #ECEFF1;
  --nav-border:        #CFD8DC;
  --nav-title-fg:      #90A4AE;
  --nav-link-fg:       #546E7A;
  --nav-link-hover-bg: rgba(84,110,122,0.08);
  --nav-link-hover-fg: #37474F;
  --nav-active-bg:     rgba(84,110,122,0.12);
  --nav-active-fg:     #263238;
  --nav-active-border: rgba(84,110,122,0.45);

  --chart-container-bg: #F0F0F0;
  --chart-1: #546E7A;  --chart-2: #2E7D32;  --chart-3: #E65100;  --chart-4: #C62828;
  --chart-5: #6A1B9A;  --chart-6: #1565C0;  --chart-7: #00695C;  --chart-8: #827717;

  /* Header text — ensures legibility on both light and dark header backgrounds */
  --header-fg: #FFFFFF;
  --header-fg-muted: rgba(255,255,255,0.80);
}
'@
}
