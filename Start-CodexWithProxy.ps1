$ErrorActionPreference = 'Stop'

$configPath = Join-Path $PSScriptRoot 'proxy-config.json'
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Missing configuration file: $configPath"
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$proxyHost = [string]$config.host
$proxyPort = [int]$config.port
if ([string]::IsNullOrWhiteSpace($proxyHost) -or $proxyPort -lt 1 -or $proxyPort -gt 65535) {
    throw 'proxy-config.json contains an invalid host or port.'
}

$proxyUrl = "http://${proxyHost}:${proxyPort}"
$stateDirectory = Join-Path $env:LOCALAPPDATA 'CodexLanProxyLauncher'
New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
$logPath = Join-Path $stateDirectory 'launcher.log'

function Write-LauncherLog([string]$message) {
    Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format o) $message" -Encoding UTF8
}

function Show-LauncherMessage([string]$message, [string]$icon = 'Information') {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show($message, 'Codex LAN Proxy', 'OK', $icon) | Out-Null
}

Write-LauncherLog "Launcher started for $proxyUrl"

if (Get-Process -Name ChatGPT -ErrorAction SilentlyContinue) {
    Write-LauncherLog 'Launch refused because ChatGPT.exe is already running'
    Show-LauncherMessage 'Codex is already running. Fully quit it from the system tray, then use this shortcut again.'
    exit 1
}

$client = [Net.Sockets.TcpClient]::new()
try {
    $connect = $client.ConnectAsync($proxyHost, $proxyPort)
    if (-not $connect.Wait(3000) -or -not $client.Connected) {
        throw 'The proxy did not respond within 3 seconds.'
    }
}
catch {
    Write-LauncherLog "Proxy connectivity check failed: $($_.Exception.Message)"
    Show-LauncherMessage "Cannot reach the LAN proxy at $proxyUrl. Check the proxy device and LAN connection." 'Error'
    exit 2
}
finally {
    $client.Dispose()
}

foreach ($name in 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy') {
    Set-Item -Path "Env:$name" -Value $proxyUrl
}
$env:NO_PROXY = 'localhost,127.0.0.1,::1'
$env:no_proxy = 'localhost,127.0.0.1,::1'
$env:REQUEST_METHOD = ''

$package = Get-AppxPackage -Name OpenAI.Codex
$executable = Join-Path $package.InstallLocation 'app\ChatGPT.exe'
if (-not (Test-Path -LiteralPath $executable)) {
    Write-LauncherLog "Codex executable was not found at $executable"
    Show-LauncherMessage 'The Codex installation could not be found. Install or update Codex, then try again.' 'Error'
    exit 3
}

$process = Start-Process -FilePath $executable -ArgumentList @(
    "--proxy-server=$proxyUrl"
    '--proxy-bypass-list=localhost;127.0.0.1;::1'
) -PassThru
Write-LauncherLog "Started ChatGPT.exe PID=$($process.Id) with proxy arguments and inherited proxy environment"

