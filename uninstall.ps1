# Namoz prayer widget — uninstaller
# Usage:
#   irm https://raw.githubusercontent.com/abuyahyo/namoz/main/uninstall.ps1 | iex

$ErrorActionPreference = 'Continue'
$InstallDir = Join-Path $env:USERPROFILE 'PrayerWidget'

Write-Host ''
Write-Host '  Namoz vidjetini olib tashlash' -ForegroundColor Cyan
Write-Host '  ──────────────────────────────' -ForegroundColor DarkGray
Write-Host ''

# 1. Stop running widget
Write-Host '  Vidjet to''xtatilmoqda...' -NoNewline -ForegroundColor Gray
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -eq 'powershell.exe' -and $_.CommandLine -like '*PrayerWidget*widget.ps1*'
} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 700
Write-Host '  ✓' -ForegroundColor Green

# 2. Remove shortcuts
Write-Host '  Yorliqlar o''chirilmoqda...' -NoNewline -ForegroundColor Gray
foreach ($folder in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Startup'))) {
    foreach ($name in @('Namoz.lnk','Namoz vaqtlari.lnk')) {
        $lnk = Join-Path $folder $name
        if (Test-Path $lnk) { Remove-Item $lnk -Force -ErrorAction SilentlyContinue }
    }
}
Write-Host '  ✓' -ForegroundColor Green

# 3. Remove install folder
Write-Host '  Fayllar o''chirilmoqda...' -NoNewline -ForegroundColor Gray
if (Test-Path $InstallDir) {
    Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host '  ✓' -ForegroundColor Green

Write-Host ''
Write-Host '  ✓ Vidjet to''liq olib tashlandi' -ForegroundColor Green
Write-Host ''
