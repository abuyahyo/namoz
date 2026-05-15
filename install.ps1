# Namoz prayer widget — one-line installer
# Usage:
#   irm https://raw.githubusercontent.com/abuyahyo/namoz/main/install.ps1 | iex

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'

$Repo       = 'abuyahyo/namoz'
$InstallDir = Join-Path $env:USERPROFILE 'PrayerWidget'
$ZipUrl     = "https://github.com/$Repo/archive/refs/heads/main.zip"
$TmpZip     = Join-Path $env:TEMP 'namoz-install.zip'
$TmpExtract = Join-Path $env:TEMP 'namoz-install-extract'

function Step([string]$msg) {
    Write-Host ('  ' + $msg) -NoNewline -ForegroundColor Gray
}
function StepOk { Write-Host '  ✓' -ForegroundColor Green }
function StepFail([string]$err) { Write-Host '  ✗' -ForegroundColor Red; Write-Host "    $err" -ForegroundColor Red }

Write-Host ''
Write-Host '  Namoz vidjetini o''rnatish' -ForegroundColor Cyan
Write-Host '  ──────────────────────────' -ForegroundColor DarkGray
Write-Host ''

# 0. Stop any running instance
Step '1. Eski nusxa to''xtatilmoqda...'
try {
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -eq 'powershell.exe' -and $_.CommandLine -like '*PrayerWidget*widget.ps1*'
    } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 700
    StepOk
} catch { StepFail $_.Exception.Message }

# 1. Download
Step '2. Yuklab olinmoqda...'
try {
    Invoke-WebRequest -Uri $ZipUrl -OutFile $TmpZip -UseBasicParsing
    StepOk
} catch {
    StepFail $_.Exception.Message; exit 1
}

# 2. Extract
Step '3. Arxiv ochilmoqda...'
try {
    if (Test-Path $TmpExtract) { Remove-Item $TmpExtract -Recurse -Force }
    Expand-Archive -Path $TmpZip -DestinationPath $TmpExtract -Force
    $extracted = Get-ChildItem $TmpExtract -Directory | Select-Object -First 1
    StepOk
} catch { StepFail $_.Exception.Message; exit 1 }

# 3. Save user config if exists, then install
Step '4. Fayllar joylashtirilmoqda...'
try {
    $configBackup = $null
    $cfgPath = Join-Path $InstallDir 'config.json'
    if (Test-Path $cfgPath) { $configBackup = Get-Content $cfgPath -Raw -Encoding UTF8 }

    if (Test-Path $InstallDir) {
        # Remove old files except config.json (preserve user position/city)
        Get-ChildItem $InstallDir -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'config.json' } |
            Sort-Object -Property FullName -Descending |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Copy-Item -Path (Join-Path $extracted.FullName '*') -Destination $InstallDir -Recurse -Force

    if ($configBackup) {
        Set-Content -Path $cfgPath -Value $configBackup -Encoding utf8 -NoNewline
    }
    StepOk
} catch { StepFail $_.Exception.Message; exit 1 }

# 4. Create Desktop + Startup shortcuts
Step '5. Yorliqlar yaratilmoqda...'
try {
    $wsh    = New-Object -ComObject WScript.Shell
    $target = Join-Path $InstallDir 'start.vbs'
    $icon   = Join-Path $InstallDir 'namoz.ico'
    foreach ($folder in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Startup'))) {
        $lnk = Join-Path $folder 'Namoz.lnk'
        $sc = $wsh.CreateShortcut($lnk)
        $sc.TargetPath       = $target
        $sc.WorkingDirectory = $InstallDir
        $sc.IconLocation     = "$icon,0"
        $sc.Description      = 'Namoz vaqtlari widgeti'
        $sc.Save()
    }
    [Runtime.InteropServices.Marshal]::ReleaseComObject($wsh) | Out-Null
    StepOk
} catch { StepFail $_.Exception.Message }

# 5. Cleanup
Step '6. Vaqtinchalik fayllar tozalanmoqda...'
try {
    Remove-Item $TmpZip -Force -ErrorAction SilentlyContinue
    Remove-Item $TmpExtract -Recurse -Force -ErrorAction SilentlyContinue
    StepOk
} catch { StepFail $_.Exception.Message }

# 6. Launch
Step '7. Vidjet ishga tushirilmoqda...'
try {
    Start-Process wscript.exe -ArgumentList (Join-Path $InstallDir 'start.vbs')
    StepOk
} catch { StepFail $_.Exception.Message }

Write-Host ''
Write-Host '  ✓ Namoz vidjeti muvaffaqiyatli o''rnatildi' -ForegroundColor Green
Write-Host ''
Write-Host '  Joylashuv:        ' -NoNewline -ForegroundColor DarkGray; Write-Host $InstallDir
Write-Host '  Ish stoli yorlig'': ' -NoNewline -ForegroundColor DarkGray; Write-Host 'Namoz'
Write-Host '  Avtomatik ishga tushish: ' -NoNewline -ForegroundColor DarkGray; Write-Host 'Yoqilgan (Windows yoqilganida ochiladi)'
Write-Host ''
Write-Host '  ⚙ tugmasini bosib shahar va davlatni sozlang.' -ForegroundColor Yellow
Write-Host ''
Write-Host '  Olib tashlash uchun:' -ForegroundColor DarkGray
Write-Host '    irm https://raw.githubusercontent.com/abuyahyo/namoz/main/uninstall.ps1 | iex' -ForegroundColor DarkGray
Write-Host ''
