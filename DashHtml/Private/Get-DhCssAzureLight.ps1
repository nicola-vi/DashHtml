function Get-DhCssAzureLight {
    <#
    .SYNOPSIS  Returns the :root variable block for the AzureLight theme.
               Called by Get-DhThemeCss which appends the shared structural CSS.
    #>
    return @'
:root {
  /* AzureLight — Microsoft Fluent Design System / Azure Portal (light)
     Primary: #0078D4  Font: Segoe UI  Backgrounds: F3F2F1 warm-grey shell */

  --bg-page:          #F3F2F1;
  --bg-header:        #106EBE;
  --bg-surface:       #FFFFFF;
  --bg-table:         #FFFFFF;
  --bg-row-alt:       #FAF9F8;
  --bg-row-hover:     #CFE6F7;
  --bg-row-sel:       #DEECF9;
  --bg-thead:         #F3F2F1;

  --accent-primary:   #0078D4;

  --accent-primary-fg: #ffffff;   /* v1.10.2 - readable text on the accent background */
  --accent-secondary: #106EBE;
  --accent-danger:    #A4262C;

  /* Range-gradient bar stops (v2.1.0) - one continuous scale across the
     0-100 axis, mapped onto this theme's own severity ramp. */
  --range-grad-0:   #107C10;
  --range-grad-50:  #BC4B09;
  --range-grad-100: #A4262C;
  --accent-warn:      #BC4B09;
  --accent-ok:        #107C10;

  --export-csv-bg:    #E6F4EA;  --export-csv-fg:    #107C10;  --export-csv-bdr:   #BAD8BB;
  --export-xlsx-bg:   #E6F4EA;  --export-xlsx-fg:   #217346;  --export-xlsx-bdr:  #BAD8BB;
  --export-pdf-bg:    #FCECEA;  --export-pdf-fg:    #A4262C;  --export-pdf-bdr:   #F4CCCC;

  --text-primary:   #323130;
  --text-secondary: #605E5C;
  --text-muted:     #63605F;
  --text-accent:    #0068B8;
  --text-invert:    #FFFFFF;

  --border-subtle:  #EDEBE9;
  --border-medium:  #D2D0CE;
  --border-strong:  #0078D455;

  /* Segoe UI is the Microsoft / Windows system font — no Google Fonts needed */
  --font-ui:      'Segoe UI', 'Segoe UI Variable', system-ui, -apple-system, sans-serif;
  --font-mono:    'Cascadia Code', 'Cascadia Mono', 'Consolas', monospace;
  --font-display: 'Segoe UI', 'Segoe UI Variable', system-ui, -apple-system, sans-serif;

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

  --shadow-md:   0 2px 8px rgba(0,0,0,0.12);
  --shadow-glow: 0 0 12px rgba(0,120,212,0.18);

  --cell-ok-fg:      #0E700E;  --cell-ok-bg:      rgba(16,124,16,0.08);
  --cell-warn-fg:    #8A3707;  --cell-warn-bg:    rgba(188,75,9,0.08);
  --cell-danger-fg:  #A4262C;  --cell-danger-bg:  rgba(164,38,44,0.08);
  --cell-nodata-fg:  #605E5C;  --cell-nodata-bg:  rgba(96,94,92,0.08);

  --progress-track-bg: rgba(0,0,0,0.07);

  --nav-bg:            #FFFFFF;
  --nav-border:        #EDEBE9;
  --nav-title-fg:      #696765;
  --nav-link-fg:       #323130;
  --nav-link-hover-bg: rgba(0,120,212,0.07);
  --nav-link-hover-fg: #0078D4;
  --nav-active-bg:     rgba(0,120,212,0.10);
  --nav-active-fg:     #0078D4;
  --nav-active-border: rgba(0,120,212,0.45);

  --chart-container-bg: #FAF9F8;
  --chart-1: #0078D4;  --chart-2: #107C10;  --chart-3: #BC4B09;  --chart-4: #A4262C;
  --chart-5: #8764B8;  --chart-6: #004B1C;  --chart-7: #00B294;  --chart-8: #C19C00;

  /* Header text — ensures legibility on both light and dark header backgrounds */
  --header-fg: #FFFFFF;
  --header-fg-muted: rgba(255,255,255,0.94);
}
'@
}
