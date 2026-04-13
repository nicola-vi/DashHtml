function Get-DhCssCompanyDark {
    <#
    .SYNOPSIS  Returns the :root variable block for the CompanyDark theme.
               Called by Get-DhThemeCss which appends the shared structural CSS.
    #>
    return @'
@import url('https://fonts.googleapis.com/css2?family=Montserrat:wght@300;400;500;600;700&display=swap');
:root {
  /* CompanyDark — Company brand: Crimson Glory #BE0036, Montserrat, near-black */
  --company-crimson:   #BE0036;
  --company-jet:       #333333;

  --bg-page:          #0E0709;
  --bg-header:        #130B0E;
  --bg-surface:       #1A0E12;
  --bg-table:         #160C10;
  --bg-row-alt:       #1E1015;
  --bg-row-hover:     #2A141A;
  --bg-row-sel:       #3D0017;
  --bg-thead:         #220E14;

  --accent-primary:   #BE0036;
  --accent-secondary: #E81B44;
  --accent-danger:    #FF3355;
  --accent-warn:      #FF8C00;
  --accent-ok:        #44CC66;

  --export-csv-bg:    #0E2A12;  --export-csv-fg:    #66CC88;  --export-csv-bdr:   #1A4A22;
  --export-xlsx-bg:   #0E2A12;  --export-xlsx-fg:   #55BB77;  --export-xlsx-bdr:  #1A4422;
  --export-pdf-bg:    #2A0A10;  --export-pdf-fg:    #FF6680;  --export-pdf-bdr:   #4A1020;

  --text-primary:   #F0E4E8;
  --text-secondary: #BB8899;
  --text-muted:     #7A5060;
  --text-accent:    #E81B44;
  --text-invert:    #0E0709;

  --border-subtle:  #2A1018;
  --border-medium:  #3D1825;
  --border-strong:  #BE003655;

  --font-ui:      'Montserrat', 'Segoe UI', system-ui, sans-serif;
  --font-mono:    'JetBrains Mono', 'Cascadia Code', 'Consolas', monospace;
  --font-display: 'Montserrat', 'Segoe UI', system-ui, sans-serif;

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

  --shadow-md:   0 4px 16px #00000090;
  --shadow-glow: 0 0 16px #BE003622;

  --cell-ok-fg:      #44CC66;  --cell-ok-bg:      rgba(68,204,102,0.10);
  --cell-warn-fg:    #FF8C00;  --cell-warn-bg:    rgba(255,140,0,0.10);
  --cell-danger-fg:  #FF3355;  --cell-danger-bg:  rgba(255,51,85,0.12);

  --progress-track-bg: rgba(255,255,255,0.07);

  --nav-bg:            #130B0E;
  --nav-border:        #2A1018;
  --nav-title-fg:      #7A5060;
  --nav-link-fg:       #BB8899;
  --nav-link-hover-bg: rgba(190,0,54,0.10);
  --nav-link-hover-fg: #E81B44;
  --nav-active-bg:     rgba(190,0,54,0.15);
  --nav-active-fg:     #E81B44;
  --nav-active-border: rgba(190,0,54,0.40);

  --chart-container-bg: #160C10;
  --chart-1: #E81B44;  --chart-2: #FF8C00;  --chart-3: #44CC66;  --chart-4: #00BBDD;
  --chart-5: #AA55EE;  --chart-6: #FF5533;  --chart-7: #00CCAA;  --chart-8: #FFCC00;

  /* Header text — ensures legibility on both light and dark header backgrounds */
  --header-fg: #F0E4E8;
  --header-fg-muted: #BB8899;
}
'@
}
