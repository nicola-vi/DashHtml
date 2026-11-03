function Get-DhCssVMwareDark {
    <#
    .SYNOPSIS  Returns the :root variable block for the VMwareDark theme.
               Called by Get-DhThemeCss which appends the shared structural CSS.
    #>
    return @'
:root {
  /* VMwareDark — VMware by Broadcom (dark, 3.0.0)
     Near-black neutral base; teal-blue #015C89 lightened to #029DE9 so accent text
     reads at 4.5:1; a deep teal-blue header gradient; Broadcom Red #CC092F only as
     the line under the header. */

  --broadcom-red:     #CC092F;
  --vmware-teal:      #015C89;
  --vmware-grey:      #53565A;

  --bg-page:          #101317;
  --bg-header:        #0E3550;
  --bg-header-end:    #1A5A7A;   /* 3.0.0 - the header is a 120deg gradient between the two */
  --bg-surface:       #1A1F26;
  --bg-table:         #161A20;
  --bg-row-alt:       #1F252D;
  --bg-row-hover:     #34495A;
  --bg-row-sel:       #0D3B55;
  --bg-thead:         #242B34;

  --accent-primary:   #029DE9;

  --accent-primary-fg: #10151b;   /* v1.10.2 - readable text on the accent background */
  --accent-secondary: #2B87BF;
  --accent-danger:    #E74C3C;

  /* Range-gradient bar stops (v2.1.0) - one continuous scale across the
     0-100 axis, mapped onto this theme's own severity ramp. */
  --range-grad-0:   #00C49A;
  --range-grad-50:  #F39C12;
  --range-grad-100: #E74C3C;
  --accent-warn:      #F39C12;
  --accent-ok:        #00C49A;

  --export-csv-bg:    #0A2A1E;  --export-csv-fg:    #00C49A;  --export-csv-bdr:   #104428;
  --export-xlsx-bg:   #0A2A1E;  --export-xlsx-fg:   #00B388;  --export-xlsx-bdr:  #104428;
  --export-pdf-bg:    #2A1010;  --export-pdf-fg:    #E74C3C;  --export-pdf-bdr:   #441414;

  --text-primary:   #E8EDF4;
  --text-secondary: #A3AFBC;
  --text-muted:     #B1BBC6;
  --text-accent:    #029DE9;
  --text-invert:    #101317;

  --border-subtle:  #262D36;
  --border-medium:  #363E49;
  --border-strong:  #029DE944;

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

  --shadow-md:   0 4px 16px rgba(0,0,0,0.55);
  --shadow-glow: 0 0 16px rgba(2,157,233,0.16);

  --cell-ok-fg:      #0BD5AA;  --cell-ok-bg:      rgba(0,196,154,0.10);
  --cell-warn-fg:    #F5AA34;  --cell-warn-bg:    rgba(243,156,18,0.10);
  --cell-danger-fg:  #F09187;  --cell-danger-bg:  rgba(231,76,60,0.10);
  --cell-nodata-fg:  #AFB6C0;  --cell-nodata-bg:  rgba(139,150,165,0.10);

  --progress-track-bg: rgba(255,255,255,0.08);

  --nav-bg:            #0C0F12;
  --nav-border:        #262D36;
  --nav-title-fg:      #8D9CAA;
  --nav-link-fg:       #A3AFBC;
  --nav-link-hover-bg: rgba(2,157,233,0.08);
  --nav-link-hover-fg: #029DE9;
  --nav-active-bg:     rgba(2,157,233,0.12);
  --nav-active-fg:     #029DE9;
  --nav-active-border: rgba(2,157,233,0.40);

  --chart-container-bg: #161A20;
  --chart-1: #029DE9;  --chart-2: #8FC3E3;  --chart-3: #F39C12;  --chart-4: #E74C3C;
  --chart-5: #A78BFA;  --chart-6: #FB923C;  --chart-7: #CFD6DE;  --chart-8: #A3E635;

  /* Header text — ensures legibility on both light and dark header backgrounds */
  --header-fg: #E8EDF4;
  --header-fg-muted: #C3CDD8;
  --header-line:     #CC092F;   /* 3.0.0 - the line under the header: Broadcom Red */
}
'@
}
