# Upgrading a script to DashHtml 2.x

2.0.0 carried **one breaking change**, one advisory, and one behaviour fix.
Everything else is source-compatible.

## 0 — Audit before touching anything

```powershell
# read-only, AST-based, never executes your scripts
.\Tools\Test-DhV2Upgrade.ps1 -Path 'C:\Scripts' -Detailed

# richer report, and the only tool that can rewrite
Update-DhScript -Path 'C:\Scripts'                  # report only
Update-DhScript -Path 'C:\Scripts' -PassThru | Where-Object Severity -eq 'ACTION'
Update-DhScript -Path 'C:\Scripts' -Apply           # rewrites, backs up first
```

`Update-DhScript` lives in the **DashHtml.Design** module, not DashHtml itself.

> **Never audit with grep.** These calls routinely span several lines with
> backtick continuation, so a line-oriented pattern silently under-reports. On
> the bundled `Examples/`, the obvious greps find **0** issues; the AST audit
> finds **13**. Under-reporting is the exact failure class this release exists to
> fix.

Severities:

| Severity | Issue | Meaning |
|---|---|---|
| `ACTION` | `-AllowHtml` default flipped | Real edits required |
| `advisory` | `Add-DhTable -NavGroup` | Still works via the compat shim; migrate deliberately or not at all. **Never rewritten automatically.** |
| `info` | a block with `-NavSubGroup` | Was unreachable in 1.x, starts rendering in 2.0.0. Nothing to fix. |

## 1 — BREAKING: `-AllowHtml` now defaults to `$false`

**What changed.** The default flipped from `$true` (raw markup) to `$false`
(HTML-encoded), on four cmdlets: `Add-DhHtmlBlock`, `Add-DhCollapsible`,
`Add-DhAlertBanner`, `Add-DhTabs`. A call passing markup **without** an explicit
`-AllowHtml` will start rendering that markup as literal text.

This is the injection fix the release exists to deliver, and it had been
announced by a runtime warning since 1.5.x.

**How to decide, per call site:**

| Content source | Do |
|---|---|
| Markup **you** wrote (a `<ul>`, a `<strong>`, a link you built) | add `-AllowHtml:$true` |
| Anything user- or system-supplied — AD attributes, ticket titles, log lines, hostnames, API text | **change nothing**; the new default is the correct one |

**Quickest way to find the affected calls today:** run the script against 1.10.4
and read the warnings. Every call whose behaviour will change already prints one.
A clean 1.10.4 run with no such warnings means there is nothing to do here.

**`Update-DhScript -Apply` is deliberately conservative:** it only ever *adds*
`-AllowHtml:$true`, and only when `-Content` is a literal string that actually
looks like markup. It never removes a parameter, never touches nav, and never
guesses at a variable or expression — those are reported as needing a human.

### Do not "fix" a deliberate exception

In `ProjectPS\Documentation`, four `Add-DhAlertBanner` sites were deliberately
left on the encoding default during the 2.0.0 upgrade (2026-08-26):

- `Azure Docs\Invoke-AzureDocumentation.ps1` — `-Message` is a `-f` format string
  of plain resource counts; no markup.
- `Parallels\Invoke-ParallelsDashboard.ps1` (two sites) and
  `Parallels\Invoke-ParallelsDocumentation.ps1` — licence status text and
  operator broadcast messages that come straight from the Parallels RAS API.

The audit flags them because they are *unchosen*, not because they are wrong.
**Do not add `-AllowHtml:$true`.** Adding an explicit `-AllowHtml:$false` is the
only acceptable change — it silences both the audit and the runtime warning
without altering behaviour. (Line numbers in the older notes were accurate at the
time of the upgrade; verify before acting.)

## 2 — ADVISORY: tables use one uniform path model

In 1.x, `Add-DhTable -NavGroup 'G'` produced its own subnav link through a
table-only code path, while blocks had no equivalent. In 2.0.0 every item —
table or block — sits at the path it declares, under one rule.

**Your scripts keep working with no edit.** The compat shim maps
`-NavGroup 'G'` on a table to `'G/<TableId>'` with `Exact` scope, reproducing the
1.x menu entry exactly.

Migrating to `-NavPath` is **optional** and buys explicit control over the node
key, its label, and its depth. **See `navigation.md` §7 for the full migration
guide, the authoritative mapping table, and the block-scope trap.**

## 3 — Behaviour fix: blocks in a subgroup start appearing

In 1.x, a **block** given both `-NavGroup` and `-NavSubGroup` was permanently
unreachable (gotcha #26): the nav code hid it with an inline
`style.display='none'` *and* by removing `panel-active`, but showed it again by
clearing only the inline style — and `.block-section` is `display:none` without
`panel-active`. It failed silently: zero console output, just an empty panel.

In 2.0.0 it renders correctly. **Content that has been silently missing will
reappear.** Not an error to fix — but if a dashboard was restructured to *dodge*
this bug (for example flattened to top-level tabs), that workaround is now
unnecessary. It stays valid; cleanup is optional.

## 4 — Not breaking, no action needed

| Pattern | Status |
|---|---|
| Blocks with `-NavGroup` only | unchanged — visible across the whole group (`Subtree`) |
| Cmdlets with no nav parameters | unchanged — page-global |
| `-NavGroup` / `-NavSubGroup` themselves | **kept indefinitely** as a compat shim onto `-NavPath`/`-NavScope` |
| Old bookmarked `#{group,panel}` URLs | still resolve via a shim in `URLState.load` |

## 5 — Triage summary

- **No hits at all** → drop-in upgrade, nothing to do.
- **Only `info` hits** → nothing to fix; expect previously invisible content to
  reappear.
- **`ACTION` or `advisory` hits** → real decisions required. Use
  `Update-DhScript -Apply` for the `-AllowHtml` ones, and migrate nav by hand.

## 6 — After upgrading: regenerate

The runtime JS and CSS are **baked into every generated HTML file**. Updating the
module changes nothing about reports already on disk — 2.1.x alone fixed
`-ClickFilters` (which threw `ReferenceError: engines is not defined` and could
inject HTML attributes from a label containing `"`), a malformed table toolbar
present in *every* report ever generated, and column-resize minimums.

**Regenerate every dashboard after a module upgrade**, then open it and click
through.
