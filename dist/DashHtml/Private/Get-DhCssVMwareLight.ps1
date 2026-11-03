function Get-DhCssVMwareLight {
    <#
    .SYNOPSIS  Returns the :root variable block for the VMwareLight theme.
               Called by Get-DhThemeCss which appends the shared structural CSS.
    #>
    return @'
:root {
  /* VMwareLight — VMware by Broadcom (3.0.0)
     Teal-blue #015C89 for the accent, links, menu and charts; a black to teal-blue
     header; Broadcom Red #CC092F only as the line under the header. It is never a
     status colour: the danger red keeps its meaning. Font: Inter if installed. */

  --broadcom-red:     #CC092F;
  --vmware-teal:      #015C89;
  --vmware-grey:      #53565A;

  --bg-page:          #F4F5F7;
  --bg-header:        #000000;
  --bg-header-end:    #015C89;   /* 3.0.0 - the header is a 120deg gradient between the two */
  --bg-surface:       #FFFFFF;
  --bg-table:         #FFFFFF;
  --bg-row-alt:       #F4F8FB;
  --bg-row-hover:     #CCE0EA;
  --bg-row-sel:       #DCEAF1;
  --bg-thead:         #EEF1F4;

  --accent-primary:   #015C89;

  --accent-primary-fg: #FFFFFF;   /* v1.10.2 - readable text on the accent background */
  --accent-secondary: #014A6E;
  --accent-danger:    #C0392B;

  /* Range-gradient bar stops (v2.1.0) - one continuous scale across the
     0-100 axis, mapped onto this theme's own severity ramp. */
  --range-grad-0:   #00B388;
  --range-grad-50:  #E67E22;
  --range-grad-100: #C0392B;
  --accent-warn:      #E67E22;
  --accent-ok:        #00B388;

  --export-csv-bg:    #E4F7F1;  --export-csv-fg:    #006E57;  --export-csv-bdr:   #AADDD2;
  --export-xlsx-bg:   #E4F7F1;  --export-xlsx-fg:   #217346;  --export-xlsx-bdr:  #AADDD2;
  --export-pdf-bg:    #FEECE9;  --export-pdf-fg:    #C0392B;  --export-pdf-bdr:   #F4CCCC;

  --text-primary:   #111418;
  --text-secondary: #53565A;
  --text-muted:     #5A6065;
  --text-accent:    #015C89;
  --text-invert:    #FFFFFF;

  --border-subtle:  #E5E7EB;
  --border-medium:  #CED1D5;
  --border-strong:  #015C8955;

  --font-ui:      'Inter', 'Segoe UI', system-ui, -apple-system, sans-serif;
  --font-mono:    'JetBrains Mono', 'Cascadia Code', 'Consolas', monospace;
  --font-display: 'Inter', 'Segoe UI', system-ui, -apple-system, sans-serif;

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

  --shadow-md:   0 2px 10px rgba(0,0,0,0.10);
  --shadow-glow: 0 0 14px rgba(1,92,137,0.16);

  --cell-ok-fg:      #006E57;  --cell-ok-bg:      rgba(0,179,136,0.09);
  --cell-warn-fg:    #934F09;  --cell-warn-bg:    rgba(230,126,34,0.09);
  --cell-danger-fg:  #A0291F;  --cell-danger-bg:  rgba(192,57,43,0.09);
  --cell-nodata-fg:  #59616B;  --cell-nodata-bg:  rgba(123,135,148,0.09);

  --progress-track-bg: rgba(0,0,0,0.07);

  --nav-bg:            #FFFFFF;
  --nav-border:        #E5E7EB;
  --nav-title-fg:      #63686E;
  --nav-link-fg:       #53565A;
  --nav-link-hover-bg: rgba(1,92,137,0.07);
  --nav-link-hover-fg: #015C89;
  --nav-active-bg:     rgba(1,92,137,0.10);
  --nav-active-fg:     #015C89;
  --nav-active-border: rgba(1,92,137,0.45);

  --chart-container-bg: #F4F8FB;
  --chart-1: #015C89;  --chart-2: #3A9AD9;  --chart-3: #53565A;  --chart-4: #E67E22;
  --chart-5: #8E44AD;  --chart-6: #0B2A3D;  --chart-7: #C0392B;  --chart-8: #8FC3E3;

  /* Header text — ensures legibility on both light and dark header backgrounds */
  --header-fg: #FFFFFF;
  --header-fg-muted: rgba(255,255,255,0.94);
  --header-line:     #CC092F;   /* 3.0.0 - the line under the header: Broadcom Red */
}
'@
}
