$ErrorActionPreference = 'Stop'

$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Codex (LAN Proxy).lnk'
if (Test-Path -LiteralPath $shortcutPath) {
    Remove-Item -LiteralPath $shortcutPath -Force
    Write-Host "Removed shortcut: $shortcutPath" -ForegroundColor Green
} else {
    Write-Host 'The desktop shortcut is not installed.'
}

Write-Host 'Codex and its data were not modified.'

