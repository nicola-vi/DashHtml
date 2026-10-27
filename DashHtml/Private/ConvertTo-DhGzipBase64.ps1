function ConvertTo-DhGzipBase64 {
    <#
    .SYNOPSIS
        v2.6.0 - gzip a UTF-8 string and return it as base64 (Export-DhDashboard -CompressData).
        The browser reverses it with atob + DecompressionStream('gzip').
    #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $ms = [IO.MemoryStream]::new()
    $gz = [IO.Compression.GZipStream]::new($ms, [IO.Compression.CompressionLevel]::Optimal)
    try { $gz.Write($bytes, 0, $bytes.Length) } finally { $gz.Dispose() }
    [Convert]::ToBase64String($ms.ToArray())
}
