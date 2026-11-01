param(
    [switch]$Startup
)

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

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CodexWindow {
    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@

function Get-CodexWindowProcesses {
    @(Get-Process -Name ChatGPT -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 })
}

function Show-CodexWindow {
    $windows = Get-CodexWindowProcesses
    foreach ($window in $windows) {
        [CodexWindow]::ShowWindowAsync($window.MainWindowHandle, 9) | Out-Null
        [CodexWindow]::SetForegroundWindow($window.MainWindowHandle) | Out-Null
    }
    return $windows.Count -gt 0
}

function Hide-CodexWindows {
    $windows = Get-CodexWindowProcesses
    foreach ($window in $windows) {
        [CodexWindow]::ShowWindowAsync($window.MainWindowHandle, 0) | Out-Null
    }
}

Write-LauncherLog "Launcher started for $proxyUrl (Startup=$Startup)"

if (Get-Process -Name ChatGPT -ErrorAction SilentlyContinue) {
    if ($Startup) {
        Write-LauncherLog 'Startup launch skipped because ChatGPT.exe is already running'
        exit 0
    }
    $shown = Show-CodexWindow
    Write-LauncherLog "Existing Codex window restore requested (WindowFound=$shown)"
    exit 0
}

$proxyReady = $false
$deadline = [DateTime]::UtcNow.AddSeconds($(if ($Startup) { 60 } else { 3 }))
do {
    $client = [Net.Sockets.TcpClient]::new()
    try {
        $connect = $client.ConnectAsync($proxyHost, $proxyPort)
        $proxyReady = $connect.Wait(2000) -and $client.Connected
    }
    catch {
        $proxyReady = $false
    }
    finally {
        $client.Dispose()
    }
    if (-not $proxyReady -and $Startup) { Start-Sleep -Seconds 2 }
} while (-not $proxyReady -and [DateTime]::UtcNow -lt $deadline)

if (-not $proxyReady) {
    Write-LauncherLog 'Proxy connectivity check failed'
    if (-not $Startup) {
        Show-LauncherMessage "Cannot reach the LAN proxy at $proxyUrl. Check the proxy device and LAN connection." 'Error'
    }
    exit 2
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

$arguments = @(
    "--proxy-server=$proxyUrl",
    '--proxy-bypass-list=localhost;127.0.0.1;::1'
)
if ($Startup) { $arguments += '--start-minimized' }

$startOptions = @{
    FilePath = $executable
    ArgumentList = $arguments
    PassThru = $true
}
if ($Startup) { $startOptions.WindowStyle = 'Minimized' }

$process = Start-Process @startOptions
Write-LauncherLog "Started ChatGPT.exe PID=$($process.Id) with proxy arguments and inherited proxy environment"

if ($Startup) {
    $hideDeadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 250
        Hide-CodexWindows
    } while ([DateTime]::UtcNow -lt $hideDeadline)
    Write-LauncherLog 'Startup window suppression completed'
}

