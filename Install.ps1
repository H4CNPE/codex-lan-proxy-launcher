$ErrorActionPreference = 'Stop'

$launcher = Join-Path $PSScriptRoot 'Start-CodexWithProxy.ps1'
$configPath = Join-Path $PSScriptRoot 'proxy-config.json'
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

if (-not (Test-Path -LiteralPath $launcher)) { throw "Missing launcher: $launcher" }
if (-not (Test-Path -LiteralPath $configPath)) { throw "Missing configuration: $configPath" }

$package = Get-AppxPackage -Name OpenAI.Codex
$icon = Join-Path $package.InstallLocation 'app\ChatGPT.exe'
if (-not (Test-Path -LiteralPath $icon)) { throw 'The Codex Windows app is not installed.' }

$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'Codex (LAN Proxy).lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $powershell
$shortcut.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $launcher + '"'
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.IconLocation = $icon + ',0'
$shortcut.Description = 'Start Codex and its backend through a LAN HTTP proxy'
$shortcut.WindowStyle = 7
$shortcut.Save()

Write-Host "Installed desktop shortcut: $shortcutPath" -ForegroundColor Green
Write-Host 'Fully quit Codex before using the shortcut.'

