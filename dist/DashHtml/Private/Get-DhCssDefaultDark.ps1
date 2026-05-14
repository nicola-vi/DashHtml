function Get-DhCssDefaultDark {
    <#
    .SYNOPSIS  Returns the :root variable block for the DefaultDark theme.
               Called by Get-DhThemeCss which appends the shared structural CSS.
    #>
    return @'
:root {
  /* DefaultDark — Industrial dark, electric-cyan accents */
  --bg-page:          #0b0f14;
  --bg-header:        #0d1219;
  --bg-surface:       #111720;
  --bg-table:         #0f141b;
  --bg-row-alt:       #131922;
  --bg-row-hover:     #2A3A56;
  --bg-row-sel:       #0a2540;
  --bg-thead:         #161e2b;

  --accent-primary:   #00c8ff;
  --accent-secondary: #0077cc;
  --accent-danger:    #ff4d6a;
  --accent-warn:      #ffc107;
  --accent-ok:        #00e676;

  --export-csv-bg:    #1a3a1a;  --export-csv-fg:    #57d47c;  --export-csv-bdr:   #2a5a2a;
  --export-xlsx-bg:   #1a2f1a;  --export-xlsx-fg:   #4caf50;  --export-xlsx-bdr:  #266926;
  --export-pdf-bg:    #3a1a1a;  --export-pdf-fg:    #ff7070;  --export-pdf-bdr:   #5a2a2a;

  --text-primary:   #e2eaf4;
  --text-secondary: #8899aa;
  --text-muted:     #4a5a6a;
  --text-accent:    #00c8ff;
  --text-invert:    #0b0f14;

  --border-subtle:  #1e2b3a;
  --border-medium:  #2a3a4d;
  --border-strong:  #00c8ff44;

  --font-ui:      'Segoe UI', 'SF Pro Text', system-ui, sans-serif;
  --font-mono:    'JetBrains Mono', 'Cascadia Code', 'Consolas', monospace;
  --font-display: 'Segoe UI', 'SF Pro Display', system-ui, sans-serif;

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

  --shadow-md:   0 4px 16px #00000080;
  --shadow-glow: 0 0 16px #00c8ff22;

  --cell-ok-fg:      #00e676;  --cell-ok-bg:      rgba(0,230,118,0.08);
  --cell-warn-fg:    #ffc107;  --cell-warn-bg:    rgba(255,193,7,0.08);
  --cell-danger-fg:  #ff4d6a;  --cell-danger-bg:  rgba(255,77,106,0.10);

  --progress-track-bg: rgba(255,255,255,0.08);

  --nav-bg:            #0d1219;
  --nav-border:        #1e2b3a;
  --nav-title-fg:      #4a6070;
  --nav-link-fg:       #8899aa;
  --nav-link-hover-bg: rgba(0,200,255,0.08);
  --nav-link-hover-fg: #00c8ff;
  --nav-active-bg:     rgba(0,200,255,0.12);
  --nav-active-fg:     #00c8ff;
  --nav-active-border: rgba(0,200,255,0.35);

  --chart-container-bg: #0f141b;
  --chart-1: #00c8ff;  --chart-2: #00e676;  --chart-3: #ffc107;  --chart-4: #ff4d6a;
  --chart-5: #a855f7;  --chart-6: #f97316;  --chart-7: #06b6d4;  --chart-8: #84cc16;

  /* Header text — ensures legibility on both light and dark header backgrounds */
  --header-fg: #e2eaf4;
  --header-fg-muted: #8899aa;
}
'@
}
