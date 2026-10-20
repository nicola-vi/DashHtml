# Shared by Tools\Test-DhContrast.ps1 and Tools\Test-DhA11y.ps1 (dot-source it).
# A headless Chromium opens a COPY of an exported report with a script injected at the end of <body>; the script
# POSTs its JSON result to a loopback listener (current Edge prints nothing for --dump-dom).

function New-DhProbeSession {
    param([Parameter(Mandatory)][string] $Browser)
    $tcp = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0); $tcp.Start(); $port = $tcp.LocalEndpoint.Port; $tcp.Stop()
    $listener = [Net.HttpListener]::new(); $listener.Prefixes.Add("http://127.0.0.1:$port/"); $listener.Start()
    $work = Join-Path ([IO.Path]::GetTempPath()) ('dh-probe-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work | Out-Null
    [pscustomobject]@{ Browser = $Browser; Port = $port; Listener = $listener; Work = $work; Count = 0 }
}

function Remove-DhProbeSession {
    param([Parameter(Mandatory)] $Session)
    $Session.Listener.Stop(); Start-Sleep -Milliseconds 300
    Remove-Item -LiteralPath $Session.Work -Recurse -Force -ErrorAction SilentlyContinue
}

# Returns the POSTed body (string) or $null on timeout. $Script may contain /*%%PORT%%*/0 for the listener port.
function Invoke-DhProbe {
    param([Parameter(Mandatory)] $Session, [Parameter(Mandatory)][string] $HtmlFile, [Parameter(Mandatory)][string] $Script, [int] $TimeoutSec = 60)
    $Session.Count++
    $html = [IO.File]::ReadAllText($HtmlFile)
    $inject = "<script>`n" + $Script.Replace('/*%%PORT%%*/0', [string]$Session.Port) + "`n</script>"
    $idx = $html.LastIndexOf('</body>')
    $html = if ($idx -ge 0) { $html.Insert($idx, $inject) } else { $html + $inject }
    $copy = Join-Path $Session.Work "page$($Session.Count).html"
    [IO.File]::WriteAllText($copy, $html, (New-Object Text.UTF8Encoding($false)))
    $prof = Join-Path $Session.Work "profile$($Session.Count)"
    $start = @{ FilePath = $Session.Browser; ArgumentList = @('--headless=new', '--disable-gpu', "--user-data-dir=$prof", ([Uri]$copy).AbsoluteUri); PassThru = $true }
    if ($IsWindows) { $start.WindowStyle = 'Hidden' }      # -WindowStyle is not supported on Linux / macOS
    $proc = Start-Process @start
    $body = $null
    try {
        $task = $Session.Listener.GetContextAsync()
        if ($task.Wait($TimeoutSec * 1000)) {
            $ctx = $task.Result
            $body = (New-Object IO.StreamReader($ctx.Request.InputStream, [Text.Encoding]::UTF8)).ReadToEnd()
            $ctx.Response.StatusCode = 204; $ctx.Response.Close()
        }
    } finally { if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } }
    return $body
}