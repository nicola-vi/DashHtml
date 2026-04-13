function Get-DhCssVMwareDark {
    <#
    .SYNOPSIS  Returns the :root variable block for the VMwareDark theme.
               Called by Get-DhThemeCss which appends the shared structural CSS.
    #>
    return @'
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
:root {
  /* VMwareDark — Broadcom VMware brand (dark)
     Green: #00C49A (brightened for dark bg)  Navy: #1D2437 base */

  --vmware-green:     #00B388;
  --vmware-green-dk:  #007D63;
  --vmware-navy:      #1D2437;
  --vmware-grey:      #53565A;

  --bg-page:          #1D2437;
  --bg-header:        #151C2C;
  --bg-surface:       #243047;
  --bg-table:         #1E2940;
  --bg-row-alt:       #26344C;
  --bg-row-hover:     #2F3F5C;
  --bg-row-sel:       #0B3D2E;
  --bg-thead:         #2A3750;

  --accent-primary:   #00C49A;
  --accent-secondary: #00B388;
  --accent-danger:    #E74C3C;
  --accent-warn:      #F39C12;
  --accent-ok:        #00C49A;

  --export-csv-bg:    #0A2A1E;  --export-csv-fg:    #00C49A;  --export-csv-bdr:   #104428;
  --export-xlsx-bg:   #0A2A1E;  --export-xlsx-fg:   #00B388;  --export-xlsx-bdr:  #104428;
  --export-pdf-bg:    #2A1010;  --export-pdf-fg:    #E74C3C;  --export-pdf-bdr:   #441414;

  --text-primary:   #E8EDF4;
  --text-secondary: #9BAAB8;
  --text-muted:     #5A6A7A;
  --text-accent:    #00C49A;
  --text-invert:    #1D2437;

  --border-subtle:  #2A3750;
  --border-medium:  #374463;
  --border-strong:  #00C49A44;

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

  --shadow-md:   0 4px 16px rgba(0,0,0,0.55);
  --shadow-glow: 0 0 16px rgba(0,196,154,0.16);

  --cell-ok-fg:      #00C49A;  --cell-ok-bg:      rgba(0,196,154,0.10);
  --cell-warn-fg:    #F39C12;  --cell-warn-bg:    rgba(243,156,18,0.10);
  --cell-danger-fg:  #E74C3C;  --cell-danger-bg:  rgba(231,76,60,0.10);

  --progress-track-bg: rgba(255,255,255,0.08);

  --nav-bg:            #151C2C;
  --nav-border:        #2A3750;
  --nav-title-fg:      #5A6A7A;
  --nav-link-fg:       #9BAAB8;
  --nav-link-hover-bg: rgba(0,196,154,0.08);
  --nav-link-hover-fg: #00C49A;
  --nav-active-bg:     rgba(0,196,154,0.12);
  --nav-active-fg:     #00C49A;
  --nav-active-border: rgba(0,196,154,0.40);

  --chart-container-bg: #1E2940;
  --chart-1: #00C49A;  --chart-2: #479EF5;  --chart-3: #F39C12;  --chart-4: #E74C3C;
  --chart-5: #A78BFA;  --chart-6: #FB923C;  --chart-7: #22D3EE;  --chart-8: #A3E635;

  /* Header text — ensures legibility on both light and dark header backgrounds */
  --header-fg: #E8EDF4;
  --header-fg-muted: #9BAAB8;
}
'@
}
