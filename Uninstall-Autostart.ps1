$ErrorActionPreference = 'Stop'

$startupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'Codex LAN Proxy Startup.lnk'
if (Test-Path -LiteralPath $startupShortcut) {
    Remove-Item -LiteralPath $startupShortcut -Force
    Write-Host "Removed startup shortcut: $startupShortcut" -ForegroundColor Green
}

$stateDirectory = Join-Path $env:LOCALAPPDATA 'CodexLanProxyLauncher'
$backupPath = Join-Path $stateDirectory 'original-startup-state.json'
if (Test-Path -LiteralPath $backupPath) {
    $backup = Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json
    $startupKey = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\$($backup.packageFamilyName)\App"
    if (Test-Path -LiteralPath $startupKey) {
        Set-ItemProperty -LiteralPath $startupKey -Name State -Value ([int]$backup.state)
        Write-Host "Restored original Codex startup state: $($backup.state)" -ForegroundColor Green
    }
    Remove-Item -LiteralPath $backupPath -Force
}

