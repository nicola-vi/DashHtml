<#
.SYNOPSIS
    Returns the path of an installed Edge, Chrome or Chromium (Windows, Linux, macOS), or $null.
#>
$candidates = @(
    "${env:ProgramFiles(x86)}/Microsoft/Edge/Application/msedge.exe", "$env:ProgramFiles/Microsoft/Edge/Application/msedge.exe",
    "$env:ProgramFiles/Google/Chrome/Application/chrome.exe", "${env:ProgramFiles(x86)}/Google/Chrome/Application/chrome.exe",
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
) | Where-Object { $_ -and $_ -notmatch '^[/\\]?(Microsoft|Google)/' -and (Test-Path -LiteralPath $_) }
if ($candidates) { return @($candidates)[0] }
foreach ($n in 'microsoft-edge', 'microsoft-edge-stable', 'google-chrome', 'google-chrome-stable', 'chromium', 'chromium-browser') {
    $c = Get-Command $n -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
}
return $null