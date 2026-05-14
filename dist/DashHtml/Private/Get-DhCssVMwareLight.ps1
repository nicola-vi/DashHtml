function Get-DhCssVMwareLight {
    <#
    .SYNOPSIS  Returns the :root variable block for the VMwareLight theme.
               Called by Get-DhThemeCss which appends the shared structural CSS.
    #>
    return @'
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
:root {
  /* VMwareLight — Broadcom VMware brand
     Green: #00B388 (Pantone 354C)  Grey: #53565A (Cool Gray 11C)
     Font: Inter (closest available to VMware's Metropolis)
     Dark navy header — VMware portal style */

  --vmware-green:     #00B388;
  --vmware-green-dk:  #007D63;
  --vmware-navy:      #1D2437;
  --vmware-grey:      #53565A;

  --bg-page:          #F5F5F5;
  --bg-header:        #1D2437;
  --bg-surface:       #FFFFFF;
  --bg-table:         #FFFFFF;
  --bg-row-alt:       #F5FCFA;
  --bg-row-hover:     #C5EBDD;
  --bg-row-sel:       #C8EEE6;
  --bg-thead:         #F0F0F0;

  --accent-primary:   #00B388;
  --accent-secondary: #007D63;
  --accent-danger:    #C0392B;
  --accent-warn:      #E67E22;
  --accent-ok:        #00B388;

  --export-csv-bg:    #E4F7F1;  --export-csv-fg:    #007D63;  --export-csv-bdr:   #AADDD2;
  --export-xlsx-bg:   #E4F7F1;  --export-xlsx-fg:   #00B388;  --export-xlsx-bdr:  #AADDD2;
  --export-pdf-bg:    #FEECE9;  --export-pdf-fg:    #C0392B;  --export-pdf-bdr:   #F4CCCC;

  --text-primary:   #1D2437;
  --text-secondary: #53565A;
  --text-muted:     #9EA3A8;
  --text-accent:    #00A07A;
  --text-invert:    #FFFFFF;

  --border-subtle:  #E5E7EB;
  --border-medium:  #CED1D5;
  --border-strong:  #00B38855;

  --font-ui:      'Inter', 'Segoe UI', system-ui, -apple-system, sans-serif;
  --font-mono:    'JetBrains Mono', 'Cascadia Code', 'Consolas', monospace;
  --font-display: 'Inter', 'Segoe UI', system-ui, -apple-system, sans-serif;

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

  --shadow-md:   0 2px 10px rgba(0,0,0,0.10);
  --shadow-glow: 0 0 14px rgba(0,179,136,0.16);

  --cell-ok-fg:      #007D63;  --cell-ok-bg:      rgba(0,179,136,0.09);
  --cell-warn-fg:    #A0560A;  --cell-warn-bg:    rgba(230,126,34,0.09);
  --cell-danger-fg:  #A0291F;  --cell-danger-bg:  rgba(192,57,43,0.09);

  --progress-track-bg: rgba(0,0,0,0.07);

  --nav-bg:            #FFFFFF;
  --nav-border:        #E5E7EB;
  --nav-title-fg:      #9EA3A8;
  --nav-link-fg:       #53565A;
  --nav-link-hover-bg: rgba(0,179,136,0.07);
  --nav-link-hover-fg: #00B388;
  --nav-active-bg:     rgba(0,179,136,0.10);
  --nav-active-fg:     #00B388;
  --nav-active-border: rgba(0,179,136,0.45);

  --chart-container-bg: #F5FCFA;
  --chart-1: #00B388;  --chart-2: #007D63;  --chart-3: #1D2437;  --chart-4: #E67E22;
  --chart-5: #2980B9;  --chart-6: #8E44AD;  --chart-7: #C0392B;  --chart-8: #00CCAA;

  /* Header text — ensures legibility on both light and dark header backgrounds */
  --header-fg: #FFFFFF;
  --header-fg-muted: rgba(255,255,255,0.75);
}
'@
}
