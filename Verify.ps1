$ErrorActionPreference = 'Stop'

$config = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'proxy-config.json') -Raw | ConvertFrom-Json
$proxyHost = [string]$config.host
$proxyPort = [int]$config.port
$proxyUrl = "http://${proxyHost}:${proxyPort}"

$chat = Get-CimInstance Win32_Process -Filter "Name='ChatGPT.exe'"
$main = $chat | Where-Object { $_.CommandLine -match ('--proxy-server=' + [regex]::Escape($proxyUrl)) }
$codex = Get-CimInstance Win32_Process -Filter "Name='codex.exe'" | Where-Object { $_.ParentProcessId -in @($main.ProcessId) }
$processIds = @($chat.ProcessId) + @($codex.ProcessId)
$connections = Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object {
    $_.OwningProcess -in $processIds -and $_.State -in 'Established', 'SynSent'
}
$proxyConnections = @($connections | Where-Object {
    $_.RemoteAddress -eq $proxyHost -and $_.RemotePort -eq $proxyPort
})
$directConnections = @($connections | Where-Object {
    -not ($_.RemoteAddress -eq $proxyHost -and $_.RemotePort -eq $proxyPort) -and
    $_.RemoteAddress -notin '127.0.0.1', '::1'
})

[pscustomobject]@{
    Proxy = $proxyUrl
    MainProcessHasProxyArguments = [bool]$main
    CodexBackendProcessCount = @($codex).Count
    ProxyConnectionCount = $proxyConnections.Count
    NonProxyInternetConnectionCount = $directConnections.Count
    Verified = [bool]$main -and @($codex).Count -gt 0 -and $proxyConnections.Count -gt 0 -and $directConnections.Count -eq 0
} | Format-List

if ($directConnections.Count -gt 0) {
    Write-Host 'Unexpected non-proxy connections:' -ForegroundColor Red
    $directConnections | Select-Object OwningProcess, State, RemoteAddress, RemotePort | Format-Table -AutoSize
    exit 1
}

