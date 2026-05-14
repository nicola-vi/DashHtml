function Get-DhCssDefaultLight {
    <#
    .SYNOPSIS  Returns the :root variable block for the DefaultLight theme.
               Called by Get-DhThemeCss which appends the shared structural CSS.
    #>
    return @'
:root {
  /* DefaultLight — Clean light, blue accents */
  --bg-page:          #F0F4F8;
  --bg-header:        #FFFFFF;
  --bg-surface:       #FFFFFF;
  --bg-table:         #FFFFFF;
  --bg-row-alt:       #F7FAFE;
  --bg-row-hover:     #C7E4FF;
  --bg-row-sel:       #D0E8FF;
  --bg-thead:         #EEF2F7;

  --accent-primary:   #0088BB;
  --accent-secondary: #005F8A;
  --accent-danger:    #CC2200;
  --accent-warn:      #C87000;
  --accent-ok:        #007A3D;

  --export-csv-bg:    #E8F5E9;  --export-csv-fg:    #2E7D32;  --export-csv-bdr:   #C8E6C9;
  --export-xlsx-bg:   #E3F2E3;  --export-xlsx-fg:   #388E3C;  --export-xlsx-bdr:  #C8E6C9;
  --export-pdf-bg:    #FEECE9;  --export-pdf-fg:    #C62828;  --export-pdf-bdr:   #FFCDD2;

  --text-primary:   #1A2332;
  --text-secondary: #445566;
  --text-muted:     #8899AA;
  --text-accent:    #0077BB;
  --text-invert:    #FFFFFF;

  --border-subtle:  #DDE4EE;
  --border-medium:  #C0CEDC;
  --border-strong:  #0088BB55;

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

  --shadow-md:   0 2px 12px rgba(0,0,0,0.10);
  --shadow-glow: 0 0 12px rgba(0,136,187,0.15);

  --cell-ok-fg:      #1B6B35;  --cell-ok-bg:      rgba(27,107,53,0.08);
  --cell-warn-fg:    #8B5200;  --cell-warn-bg:    rgba(139,82,0,0.08);
  --cell-danger-fg:  #AA1100;  --cell-danger-bg:  rgba(170,17,0,0.08);

  --progress-track-bg: rgba(0,0,0,0.08);

  --nav-bg:            #FFFFFF;
  --nav-border:        #DDE4EE;
  --nav-title-fg:      #8899AA;
  --nav-link-fg:       #445566;
  --nav-link-hover-bg: rgba(0,136,187,0.07);
  --nav-link-hover-fg: #0077BB;
  --nav-active-bg:     rgba(0,136,187,0.10);
  --nav-active-fg:     #0066AA;
  --nav-active-border: rgba(0,136,187,0.40);

  --chart-container-bg: #F7FAFE;
  --chart-1: #0077BB;  --chart-2: #009955;  --chart-3: #E08800;  --chart-4: #CC2200;
  --chart-5: #8844CC;  --chart-6: #E06600;  --chart-7: #0099AA;  --chart-8: #667700;

  /* Header text — ensures legibility on both light and dark header backgrounds */
  --header-fg: #1A2332;
  --header-fg-muted: #8899AA;
}
'@
}
