# Vendored export libraries

Used only by `Export-DhDashboard -ExportLibraries Embed` (DashHtml 2.2.0+), which
inlines them into the report so the XLSX and PDF buttons work with no network.
The default mode (`Cdn`) loads the very same files from cdnjs on first click.

| File | Library | Version | Licence | Source |
|---|---|---|---|---|
| `xlsx.full.min.js` | SheetJS Community Edition | 0.18.5 | Apache-2.0 (`LICENSE-xlsx.txt`) | https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js |
| `jspdf.umd.min.js` | jsPDF | 2.5.1 | MIT (`LICENSE-jspdf.txt`) | https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js |
| `jspdf.plugin.autotable.min.js` | jsPDF-AutoTable | 3.8.2 | MIT (`LICENSE-jspdf-autotable.txt`) | https://cdnjs.cloudflare.com/ajax/libs/jspdf-autotable/3.8.2/jspdf.plugin.autotable.min.js |

Downloaded 2026-10-13. Each file was verified byte-for-byte against the sha384
SRI hash that `Export-DhDashboard` pins for the CDN copy, so `Embed` and `Cdn`
run identical code. `Export-DhDashboard` re-checks the hash every time it embeds
a file and refuses a file that does not match.

To upgrade a library: download the new version, update the URL and hash in
`Private/Get-DhExportLibraries.ps1` (the single place they are listed), and
replace the file and its licence here.