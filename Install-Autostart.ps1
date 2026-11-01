$ErrorActionPreference = 'Stop'

$launcher = Join-Path $PSScriptRoot 'Start-CodexWithProxy.ps1'
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $launcher)) { throw "Missing launcher: $launcher" }

$package = Get-AppxPackage -Name OpenAI.Codex
$icon = Join-Path $package.InstallLocation 'app\ChatGPT.exe'
if (-not (Test-Path -LiteralPath $icon)) { throw 'The Codex Windows app is not installed.' }

$stateDirectory = Join-Path $env:LOCALAPPDATA 'CodexLanProxyLauncher'
New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
$backupPath = Join-Path $stateDirectory 'original-startup-state.json'
$startupKey = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\$($package.PackageFamilyName)\App"

if (Test-Path -LiteralPath $startupKey) {
    $currentState = (Get-ItemProperty -LiteralPath $startupKey -Name State -ErrorAction SilentlyContinue).State
    if ($null -ne $currentState -and -not (Test-Path -LiteralPath $backupPath)) {
        @{ packageFamilyName = $package.PackageFamilyName; state = [int]$currentState } |
            ConvertTo-Json | Set-Content -LiteralPath $backupPath -Encoding UTF8
    }
    Set-ItemProperty -LiteralPath $startupKey -Name State -Value 1
}

$startupFolder = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupFolder 'Codex LAN Proxy Startup.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $powershell
$shortcut.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $launcher + '" -Startup'
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.IconLocation = $icon + ',0'
$shortcut.Description = 'Start Codex silently through the configured LAN proxy at sign-in'
$shortcut.WindowStyle = 7
$shortcut.Save()

Write-Host 'Disabled the original Codex startup task.' -ForegroundColor Green
Write-Host "Installed silent proxy startup shortcut: $shortcutPath" -ForegroundColor Green

