
# StormRaven Deployment Script

$releasePath = $PSScriptRoot
$shellExe = Join-Path $releasePath "StormRaven.Shell\StormRaven.Shell.exe"

Write-Host "Starting StormRaven Deployment..." -ForegroundColor Cyan

# 1. Check Prerequisite: Python
if (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
    Write-Warning "Python is not found in PATH. Please install Python to ensure full functionality."
} else {
    Write-Host "Python detected." -ForegroundColor Green
}

# 2. Create Desktop Shortcut
$desktopPath = [System.Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktopPath "StormRaven Shell.lnk"
$wshShell = New-Object -ComObject WScript.Shell
$shortcut = $wshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $shellExe
$shortcut.WorkingDirectory = Join-Path $releasePath "StormRaven.Shell"
$shortcut.Save()

Write-Host "Shortcut created at: $shortcutPath" -ForegroundColor Green
Write-Host "Deployment Complete. You can now launch StormRaven Shell from your desktop." -ForegroundColor Cyan
