function Get-DhCssRagLight {
    <#
    .SYNOPSIS  Returns the :root variable block for the RagLight theme.
               Called by Get-DhThemeCss which appends the shared structural CSS.

    .NOTES
        RagLight uses the IT-infrastructure KPI dashboard specification's exact
        Office/Excel RAG palette (KPI_Dashboard_Specification §7.2):
            GREEN  fg #375623 / bg #E2EFDA
            AMBER  fg #7F4B00 / bg #FFF2CC
            RED    fg #9C0006 / bg #FFDCE1
            GREY   fg #595959 / bg #F2F2F2   (no-data / not applicable)

        Use this theme when strict Office/Excel parity matters for the audience
        — auditors, compliance reviewers, finance reports. Page chrome stays
        deliberately neutral (white surfaces, dark-grey text) so the colour
        cues belong exclusively to the data.
    #>
    return @'
:root {
  /* RagLight — Spec-exact Office/Excel RAG palette (KPI spec §7.2) */
  --bg-page:          #FFFFFF;
  --bg-header:        #404040;
  --bg-surface:       #FFFFFF;
  --bg-table:         #FFFFFF;
  --bg-row-alt:       #F7F7F7;
  --bg-row-hover:     #E8EEF2;
  --bg-row-sel:       #DCE6EC;
  --bg-thead:         #F2F2F2;

  --accent-primary:   #595959;

  --accent-primary-fg: #ffffff;   /* v1.10.2 - readable text on the accent background */
  --accent-secondary: #404040;
  --accent-danger:    #9C0006;

  /* Range-gradient bar stops (v2.1.0) - one continuous scale across the
     0-100 axis, mapped onto this theme's own severity ramp. */
  --range-grad-0:   #375623;
  --range-grad-50:  #7F4B00;
  --range-grad-100: #9C0006;
  --accent-warn:      #7F4B00;
  --accent-ok:        #375623;

  --export-csv-bg:    #E2EFDA;  --export-csv-fg:    #375623;  --export-csv-bdr:   #C6DFB3;
  --export-xlsx-bg:   #E2EFDA;  --export-xlsx-fg:   #375623;  --export-xlsx-bdr:  #C6DFB3;
  --export-pdf-bg:    #FFDCE1;  --export-pdf-fg:    #9C0006;  --export-pdf-bdr:   #FBC2C9;

  --text-primary:   #333333;
  --text-secondary: #595959;
  --text-muted:     #5E5E5E;
  --text-accent:    #404040;
  --text-invert:    #FFFFFF;

  --border-subtle:  #E0E0E0;
  --border-medium:  #BFBFBF;
  --border-strong:  #59595955;

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

  --shadow-md:   0 2px 12px rgba(0,0,0,0.08);
  --shadow-glow: 0 0 12px rgba(89,89,89,0.10);

  /* SPEC-EXACT RAG palette — do NOT retune; the whole point of this family
     is strict parity with Office/Excel conditional-formatting colours. */
  --cell-ok-fg:        #375623;  --cell-ok-bg:        #E2EFDA;
  --cell-warn-fg:      #7F4B00;  --cell-warn-bg:      #FFF2CC;
  --cell-danger-fg:    #9C0006;  --cell-danger-bg:    #FFDCE1;
  --cell-nodata-fg:    #595959;  --cell-nodata-bg:    #F2F2F2;

  --progress-track-bg: rgba(0,0,0,0.08);

  --nav-bg:            #FAFAFA;
  --nav-border:        #E0E0E0;
  --nav-title-fg:      #636363;
  --nav-link-fg:       #595959;
  --nav-link-hover-bg: rgba(89,89,89,0.07);
  --nav-link-hover-fg: #333333;
  --nav-active-bg:     rgba(89,89,89,0.10);
  --nav-active-fg:     #1A1A1A;
  --nav-active-border: rgba(89,89,89,0.40);

  --chart-container-bg: #F7F7F7;
  /* Chart palette: lead with the RAG triad so generated colourings stay on-spec,
     then add neutral analytical colours for higher-cardinality breakdowns. */
  --chart-1: #375623;  --chart-2: #7F4B00;  --chart-3: #9C0006;  --chart-4: #595959;
  --chart-5: #2F5496;  --chart-6: #806000;  --chart-7: #7B7B7B;  --chart-8: #4B4B4B;

  /* Header text — ensures legibility on both light and dark header backgrounds */
  --header-fg: #FFFFFF;
  --header-fg-muted: rgba(255,255,255,0.94);
}
'@
}
