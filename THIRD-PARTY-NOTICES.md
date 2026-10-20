# Third-party notices

DashHtml itself is MIT licensed (see `LICENSE`). This file lists everything that
ships with it that someone else wrote, and the projects that influenced its design.

## 1. Code that ships in the module

These files live in `DashHtml/Vendor/` and are inlined into a report only when you
export with `-ExportLibraries Embed` (the default `Cdn` mode loads the same files
from cdnjs). The full licence text of each is next to it.

| Library | Version | Licence | Licence file |
|---|---|---|---|
| SheetJS Community Edition (`xlsx.full.min.js`) | 0.18.5 | Apache-2.0 | `DashHtml/Vendor/LICENSE-xlsx.txt` |
| jsPDF (`jspdf.umd.min.js`) | 2.5.1 | MIT | `DashHtml/Vendor/LICENSE-jspdf.txt` |
| jsPDF-AutoTable (`jspdf.plugin.autotable.min.js`) | 3.8.2 | MIT | `DashHtml/Vendor/LICENSE-jspdf-autotable.txt` |

## 2. Design references (no code copied)

Some widgets were designed after looking at Active Directory report generators.
Only the idea (a layout, a way of presenting findings) was taken; **no source code,
text, check lists or data were copied**, and each widget is written from scratch.
They are credited here because they were useful.

| Project | Author | Licence | What inspired us |
|---|---|---|---|
| AD-Assessment-PowerShell-Script (AD Audit Suite) | Mohamed ZEGHLACHE | MIT | General ideas for presenting directory data |

## Rule for contributors

Check the licence before copying anything from a third-party project:

- **MIT / Apache-2.0 / BSD:** code may be reused if its copyright notice is kept and listed here.
- **CC BY 4.0:** credit the author, link the licence and say what was changed.
- **GPL / AGPL, or no licence:** idea only. Write it yourself.

If a file is ever taken over, add it to section 1 with its licence text.
