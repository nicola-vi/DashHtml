#Requires -Version 7.4
<#
.SYNOPSIS
    Prints dashboards to PDF with headless Edge/Chrome and reports page count and size.
.DESCRIPTION
    A helper for the manual print check, not a CI gate. Skips with a message when no
    Chromium browser is installed. PDFs go to -OutDir (default: a temp folder).

    -Png (3.0.0) also renders every PDF page to a PNG with pdf.js (vendored, hash-checked:
    Tools\vendor\pdfjs-4.9.124, Apache-2.0) in the same headless browser, and writes
    review.html in -OutDir: every page of every report side by side, to check page
    breaks, clipped maps and wide tables by eye without opening each PDF. pdf.js draws the
    soft-masked gradients Chromium writes (header accent line, hatched cells) as hot pink;
    that is the renderer, not the report.
.PARAMETER Path
    HTML files (default: Examples/*.html).
.PARAMETER OutDir
    Where the PDFs (and PNGs) are written.
.PARAMETER Png
    Render each page to <name>-p<n>.png and write review.html.
.PARAMETER Scale
    PNG scale: 1 = 96 dpi (an A4 page is 794 x 1123 px). Default 1.
.EXAMPLE
    ./Tools/Test-DhPrint.ps1 -Png -OutDir ./Examples/_print
#>
[CmdletBinding()]
param(
    [string[]] $Path = (Join-Path $PSScriptRoot '../Examples/*.html'),
    [string] $OutDir = (Join-Path ([IO.Path]::GetTempPath()) 'dh-print'),
    [switch] $Png,
    [ValidateRange(0.5, 3)] [double] $Scale = 1
)
$ErrorActionPreference = 'Stop'
$browser = & (Join-Path $PSScriptRoot 'Find-DhBrowser.ps1')
if (-not $browser) { Write-Warning 'No Edge or Chrome found; print check skipped.'; return }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path -LiteralPath $OutDir).ProviderPath

$session = $null
if ($Png) {
    . (Join-Path $PSScriptRoot 'BrowserProbe.ps1')
    # The vendored pdf.js, checked against the hashes it was added with (cdnjs, matched on jsDelivr).
    $vendor = Join-Path $PSScriptRoot 'vendor/pdfjs-4.9.124'
    $pins = @{
        'pdf.min.mjs'        = 'fxC9og0KaUwjhnUZmpdzl0G6njIZnnkS/8mWNomcEPWK3GzJzp8elGfMjbh5OmnQ'
        'pdf.worker.min.mjs' = 'crCBoB141cuC+Cg34QibH3jxI+0kRpZIM+ZcpICrs0Cr1BvnkRPE3V++Ct0Dfuih'
    }
    $session = New-DhProbeSession -Browser $browser
    foreach ($n in $pins.Keys) {
        $src = Join-Path $vendor $n
        $got = [Convert]::ToBase64String([Security.Cryptography.SHA384]::HashData([IO.File]::ReadAllBytes($src)))
        if ($got -ne $pins[$n]) { Remove-DhProbeSession $session; throw "Test-DhPrint: $n does not match its pinned hash; not running it." }
        Copy-Item -LiteralPath $src -Destination $session.Work
    }
    $shell = Join-Path $session.Work 'render.html'
    [IO.File]::WriteAllText($shell, "<!doctype html><html><head><meta charset=`"utf-8`"></head><body></body></html>")
}

$results = foreach ($f in @(Get-ChildItem -Path $Path -File)) {
    $pdf = Join-Path $OutDir ($f.BaseName + '.pdf')
    Remove-Item -LiteralPath $pdf -ErrorAction SilentlyContinue
    $uri = ([Uri] $f.FullName).AbsoluteUri
    $prof = Join-Path ([IO.Path]::GetTempPath()) ('dh-print-profile-' + [guid]::NewGuid().ToString('N'))   # Edge can hold it a while
    & $browser --headless=new --disable-gpu --no-pdf-header-footer "--user-data-dir=$prof" "--print-to-pdf=$pdf" --virtual-time-budget=8000 $uri 2>$null | Out-Null
    # 3.0.0 - current Edge returns at once and writes the PDF in the background: wait until the file
    # exists and its size has settled (60 s at most).
    $deadline = [DateTime]::UtcNow.AddSeconds(60); $last = -1
    while ([DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 500
        if (-not (Test-Path -LiteralPath $pdf)) { continue }
        $len = (Get-Item -LiteralPath $pdf).Length
        if ($len -gt 0 -and $len -eq $last) { break }
        $last = $len
    }
    Start-Sleep -Milliseconds 300
    Remove-Item -LiteralPath $prof -Recurse -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path -LiteralPath $pdf)) { [pscustomobject]@{ File = $f.Name; Pages = 0; KB = 0; Pdf = '(failed)'; Png = 0 }; continue }
    $bytes = [IO.File]::ReadAllBytes($pdf)
    $pages = ([regex]::Matches([Text.Encoding]::Latin1.GetString($bytes), '/Type\s*/Page[^s]')).Count
    $pngCount = 0
    if ($Png) {
        Get-ChildItem -LiteralPath $OutDir -Filter "$($f.BaseName)-p*.png" -File | Remove-Item -Force
        $js = @'
(async function () {
  var out = { pages: [], error: '' };
  try {
    var lib = await import('./pdf.min.mjs');
    lib.GlobalWorkerOptions.workerSrc = './pdf.worker.min.mjs';
    var raw = atob('/*%%PDF%%*/'), u8 = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) u8[i] = raw.charCodeAt(i);
    var doc = await lib.getDocument({ data: u8 }).promise;
    for (var p = 1; p <= doc.numPages; p++) {
      var page = await doc.getPage(p), vp = page.getViewport({ scale: /*%%SCALE%%*/1 * 96 / 72 });
      var c = document.createElement('canvas'); c.width = Math.ceil(vp.width); c.height = Math.ceil(vp.height);
      var ctx = c.getContext('2d'); ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, c.width, c.height);
      await page.render({ canvasContext: ctx, viewport: vp }).promise;
      out.pages.push(c.toDataURL('image/png'));
    }
  } catch (e) { out.error = String((e && e.message) || e); }
  try { fetch('http://127.0.0.1:' + /*%%PORT%%*/0 + '/result', { method: 'POST', mode: 'no-cors', body: JSON.stringify(out) }); } catch (e) {}
})();
'@
        $js = $js.Replace('/*%%PDF%%*/', [Convert]::ToBase64String($bytes)).Replace('/*%%SCALE%%*/1', $Scale.ToString([Globalization.CultureInfo]::InvariantCulture))
        $body = Invoke-DhProbe -Session $session -HtmlFile $shell -Script $js -TimeoutSec 180 -ExtraArgs @('--allow-file-access-from-files')
        if (-not $body) { Write-Warning "Test-DhPrint: no PNGs for $($f.Name) (the renderer timed out)." }
        else {
            $res = $body | ConvertFrom-Json
            if ($res.error) { Write-Warning "Test-DhPrint: $($f.Name): pdf.js says: $($res.error)" }
            $n = 0
            foreach ($u in @($res.pages)) {
                $n++
                [IO.File]::WriteAllBytes((Join-Path $OutDir ('{0}-p{1:D2}.png' -f $f.BaseName, $n)), [Convert]::FromBase64String(($u -split ',', 2)[1]))
            }
            $pngCount = $n
        }
    }
    [pscustomobject]@{ File = $f.Name; Pages = $pages; KB = [int]($bytes.Length / 1KB); Pdf = $pdf; Png = $pngCount }
}

if ($session) {
    Remove-DhProbeSession $session
    # review.html: every page of every report, in order, for a look by eye
    $enc = { param($s) [System.Net.WebUtility]::HtmlEncode($s) }
    $sections = foreach ($r in @($results | Where-Object Png)) {
        $base = [IO.Path]::GetFileNameWithoutExtension($r.File)
        $imgs = (1..$r.Png | ForEach-Object { $n = '{0}-p{1:D2}.png' -f $base, $_; "<figure><img src=`"$(& $enc $n)`" alt=`"$(& $enc $base) page $_`" loading=`"lazy`"><figcaption>page $_</figcaption></figure>" }) -join ''
        "<section><h2>$(& $enc $r.File) <small>$($r.Pages) page(s), $($r.KB) KB</small></h2><div class=`"pages`">$imgs</div></section>"
    }
    $review = @"
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Print review</title>
<style>body{font-family:system-ui,sans-serif;margin:16px;background:#e9ebee;color:#1a1a1a}h2{font-size:16px;margin:24px 0 8px}small{color:#555;font-weight:400}
.pages{display:flex;flex-wrap:wrap;gap:12px}figure{margin:0;background:#fff;box-shadow:0 1px 4px rgba(0,0,0,.2)}img{display:block;width:300px;height:auto}
figcaption{font-size:12px;color:#555;padding:4px 6px}.note{max-width:70em;color:#333}</style></head><body><h1>Print review</h1>
<p class="note">Rendered with pdf.js. Hot-pink areas are gradients pdf.js cannot draw (the soft-masked shadings Chromium writes,
such as the header accent line and hatched grid cells); the PDF itself shows them correctly. Look for page breaks, clipped
maps and charts, and tables wider than the page.</p>
$($sections -join "`n")</body></html>
"@
    [IO.File]::WriteAllText((Join-Path $OutDir 'review.html'), $review, [Text.UTF8Encoding]::new($false))
    Write-Host "Test-DhPrint: review page at $(Join-Path $OutDir 'review.html')"
}
$results
