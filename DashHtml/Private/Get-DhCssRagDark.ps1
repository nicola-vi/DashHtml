function Get-DhCssRagDark {
    <#
    .SYNOPSIS  Returns the :root variable block for the RagDark theme.
               Called by Get-DhThemeCss which appends the shared structural CSS.

    .NOTES
        RagDark is the dark-mode partner of RagLight. The IT-infrastructure KPI
        dashboard specification (KPI_Dashboard_Specification §7.2) only defines
        light-mode RGB values, so the dark variant uses the standard
        Office "Dark Mode" RAG companions (high-contrast pastels at low
        opacity over a near-black surface). The semantic mapping is identical:
            GREEN  fg #A9D08E  (Office light-green dark companion)
            AMBER  fg #FFD966  (Office gold dark companion)
            RED    fg #FF7E7E  (Office light-red dark companion)
            GREY   fg #A6A6A6  (Office grey-30 dark companion)
    #>
    return @'
:root {
  /* RagDark — Office-compatible RAG palette on near-black surface */
  --bg-page:          #0E0E0E;
  --bg-header:        #282828;
  --bg-surface:       #1A1A1A;
  --bg-table:         #161616;
  --bg-row-alt:       #1C1C1C;
  --bg-row-hover:     #2F353B;
  --bg-row-sel:       #232A33;
  --bg-thead:         #1F1F1F;

  --accent-primary:   #A6A6A6;

  --accent-primary-fg: #10151b;   /* v1.10.2 - readable text on the accent background */
  --accent-secondary: #BFBFBF;
  --accent-danger:    #FF7E7E;

  /* Range-gradient bar stops (v2.1.0) - one continuous scale across the
     0-100 axis, mapped onto this theme's own severity ramp. */
  --range-grad-0:   #A9D08E;
  --range-grad-50:  #FFD966;
  --range-grad-100: #FF7E7E;
  --accent-warn:      #FFD966;
  --accent-ok:        #A9D08E;

  --export-csv-bg:    #1F2D1A;  --export-csv-fg:    #A9D08E;  --export-csv-bdr:   #3A5A2E;
  --export-xlsx-bg:   #1F2D1A;  --export-xlsx-fg:   #A9D08E;  --export-xlsx-bdr:  #3A5A2E;
  --export-pdf-bg:    #2D1A1C;  --export-pdf-fg:    #FF7E7E;  --export-pdf-bdr:   #5A2A2E;

  --text-primary:   #F2F2F2;
  --text-secondary: #BFBFBF;
  --text-muted:     #9D9D9D;
  --text-accent:    #D9D9D9;
  --text-invert:    #0E0E0E;

  --border-subtle:  #2A2A2A;
  --border-medium:  #404040;
  --border-strong:  #A6A6A655;

  --font-ui:      'Segoe UI', 'SF Pro Text', system-ui, sans-serif;
  --font-mono:    'JetBrains Mono', 'Cascadia Code', 'Consolas', monospace;
  --font-display: 'Segoe UI', 'SF Pro Display', system-ui, sans-serif;

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

  --shadow-md:   0 4px 16px #00000080;
  --shadow-glow: 0 0 16px #A6A6A622;

  /* Office-compatible RAG pastels for dark mode */
  --cell-ok-fg:        #A9D08E;  --cell-ok-bg:        rgba(169,208,142,0.12);
  --cell-warn-fg:      #FFD966;  --cell-warn-bg:      rgba(255,217,102,0.12);
  --cell-danger-fg:    #FF7E7E;  --cell-danger-bg:    rgba(255,126,126,0.12);
  --cell-nodata-fg:    #A6A6A6;  --cell-nodata-bg:    rgba(166,166,166,0.10);

  --progress-track-bg: rgba(255,255,255,0.08);

  --nav-bg:            #141414;
  --nav-border:        #2A2A2A;
  --nav-title-fg:      #939393;
  --nav-link-fg:       #BFBFBF;
  --nav-link-hover-bg: rgba(217,217,217,0.08);
  --nav-link-hover-fg: #F2F2F2;
  --nav-active-bg:     rgba(217,217,217,0.12);
  --nav-active-fg:     #FFFFFF;
  --nav-active-border: rgba(217,217,217,0.35);

  --chart-container-bg: #161616;
  --chart-1: #A9D08E;  --chart-2: #FFD966;  --chart-3: #FF7E7E;  --chart-4: #A6A6A6;
  --chart-5: #8FB3FF;  --chart-6: #FFC080;  --chart-7: #D9D9D9;  --chart-8: #BFBFBF;

  /* Header text — ensures legibility on both light and dark header backgrounds */
  --header-fg: #F2F2F2;
  --header-fg-muted: #BFBFBF;
}
'@
}
