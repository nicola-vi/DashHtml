function Get-DhCssAzureDark {
    <#
    .SYNOPSIS  Returns the :root variable block for the AzureDark theme.
               Called by Get-DhThemeCss which appends the shared structural CSS.
    #>
    return @'
:root {
  /* AzureDark — Microsoft Fluent Design System / Azure Portal (dark)
     Primary: #479EF5 (lightened for dark bg)  Backgrounds: Office dark slate */

  --bg-page:          #1B1A19;
  --bg-header:        #1B1A19;
  --bg-surface:       #252423;
  --bg-table:         #201F1E;
  --bg-row-alt:       #2D2C2B;
  --bg-row-hover:     #525151;
  --bg-row-sel:       #004578;
  --bg-thead:         #2D2C2B;

  --accent-primary:   #479EF5;
  --accent-secondary: #2886DE;
  --accent-danger:    #FC5F5F;
  --accent-warn:      #FCE100;
  --accent-ok:        #6CCB5F;

  --export-csv-bg:    #0F2D12;  --export-csv-fg:    #6CCB5F;  --export-csv-bdr:   #1A4A1A;
  --export-xlsx-bg:   #0F2D12;  --export-xlsx-fg:   #6CCB5F;  --export-xlsx-bdr:  #1A4A1A;
  --export-pdf-bg:    #2D0F0F;  --export-pdf-fg:    #FC5F5F;  --export-pdf-bdr:   #4A1A1A;

  --text-primary:   #F3F2F1;
  --text-secondary: #C8C6C4;
  --text-muted:     #8A8886;
  --text-accent:    #479EF5;
  --text-invert:    #1B1A19;

  --border-subtle:  #3B3A39;
  --border-medium:  #484644;
  --border-strong:  #479EF555;

  --font-ui:      'Segoe UI', 'Segoe UI Variable', system-ui, -apple-system, sans-serif;
  --font-mono:    'Cascadia Code', 'Cascadia Mono', 'Consolas', monospace;
  --font-display: 'Segoe UI', 'Segoe UI Variable', system-ui, -apple-system, sans-serif;

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

  --shadow-md:   0 4px 16px rgba(0,0,0,0.60);
  --shadow-glow: 0 0 16px rgba(71,158,245,0.18);

  --cell-ok-fg:      #6CCB5F;  --cell-ok-bg:      rgba(108,203,95,0.10);
  --cell-warn-fg:    #FCE100;  --cell-warn-bg:    rgba(252,225,0,0.09);
  --cell-danger-fg:  #FC5F5F;  --cell-danger-bg:  rgba(252,95,95,0.10);

  --progress-track-bg: rgba(255,255,255,0.08);

  --nav-bg:            #1B1A19;
  --nav-border:        #3B3A39;
  --nav-title-fg:      #605E5C;
  --nav-link-fg:       #C8C6C4;
  --nav-link-hover-bg: rgba(71,158,245,0.08);
  --nav-link-hover-fg: #479EF5;
  --nav-active-bg:     rgba(71,158,245,0.12);
  --nav-active-fg:     #479EF5;
  --nav-active-border: rgba(71,158,245,0.40);

  --chart-container-bg: #201F1E;
  --chart-1: #479EF5;  --chart-2: #6CCB5F;  --chart-3: #FCE100;  --chart-4: #FC5F5F;
  --chart-5: #C7A3F7;  --chart-6: #F4A460;  --chart-7: #40C4C4;  --chart-8: #A3CF60;

  /* Header text — ensures legibility on both light and dark header backgrounds */
  --header-fg: #F3F2F1;
  --header-fg-muted: #C8C6C4;
}
'@
}
