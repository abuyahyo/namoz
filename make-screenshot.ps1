# Render a static PNG preview of the widget for README screenshots.
# Reads real timings from cache.json when present.
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$cachePath = Join-Path $root 'cache.json'
$outPath   = Join-Path $root 'screenshot.png'

$prayers = @(
    @{ Code = 'Fajr';    Name = 'Бомдод' }
    @{ Code = 'Sunrise'; Name = 'Қуёш'   }
    @{ Code = 'Dhuhr';   Name = 'Пешин'  }
    @{ Code = 'Asr';     Name = 'Аср'    }
    @{ Code = 'Maghrib'; Name = 'Шом'    }
    @{ Code = 'Isha';    Name = 'Хуфтон' }
)

# Sample timings (fallback) — typical Cairo Egyptian method
$timings = [pscustomobject]@{
    Fajr = '04:22'; Sunrise = '06:01'; Dhuhr = '12:51'
    Asr  = '16:28'; Maghrib = '19:41'; Isha  = '21:09'
}
if (Test-Path $cachePath) {
    try { $timings = Get-Content $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
}

$fontFamily = [System.Windows.Media.FontFamily]::new('file:///' + ($root -replace '\\','/') + '/fonts/#Nunito')
$boldFace   = [System.Windows.Media.Typeface]::new($fontFamily, [System.Windows.FontStyles]::Normal, [System.Windows.FontWeights]::Bold, [System.Windows.FontStretches]::Normal)
$semiFace   = [System.Windows.Media.Typeface]::new($fontFamily, [System.Windows.FontStyles]::Normal, [System.Windows.FontWeights]::SemiBold, [System.Windows.FontStretches]::Normal)

# --- Geometry (matches widget.ps1) ---
$width  = 220 + 44  # Grid Width 220 + Border padding via outer 22 left/right margin ... actually XAML wraps width entirely
# Recompute layout: outer Border CornerRadius=22, inner Grid Width=220, internal margins built in.
# We'll render at 264x350 to mirror typical observed size, scaled 2x for crisp output.
$scale  = 2
$w = 220
$h = 320  # will be computed after content
$dpi = 96

# --- Layout ---
# Top tray height ~32, prayer list 6 rows * ~30 = 180, bottom bar ~52 → 264 total approx
$rowH = 30
$topH = 32
$timesPadTop = 4
$timesPadBot = 18
$timesMarginX = 22
$bottomBarPad = 12
$bottomBarH = 52
$prayerListH = $rowH * $prayers.Count
$contentH = $topH + $timesPadTop + $prayerListH + $timesPadBot + $bottomBarH
$h = $contentH

function New-Brush([string]$hex) {
    [System.Windows.Media.BrushConverter]::new().ConvertFromString($hex)
}

# Compute active/next prayer indexes based on current time
$now = Get-Date
$today = Get-Date -Hour 0 -Minute 0 -Second 0
$activeIdx = -1; $nextIdx = -1
$nextDt = $null
for ($i = 0; $i -lt $prayers.Count; $i++) {
    $code = $prayers[$i].Code
    if ($code -eq 'Sunrise') { continue }
    $t = $timings.$code
    if (-not $t) { continue }
    $hm = $t -split ':'
    $dt = $today.AddHours([int]$hm[0]).AddMinutes([int]$hm[1])
    if ($dt -le $now -and ($activeIdx -lt 0 -or $dt -gt $prayers[$activeIdx].Dt)) {
        $activeIdx = $i
        $prayers[$i].Dt = $dt
    }
    if ($dt -gt $now -and (-not $nextDt -or $dt -lt $nextDt)) { $nextDt = $dt; $nextIdx = $i }
}
if ($nextIdx -lt 0) { $nextIdx = 0; $nextDt = $today.AddDays(1).AddHours(4).AddMinutes(22) }
$delta = $nextDt - $now
$countdown = '{0:D2}:{1:D2}:{2:D2}' -f [int][math]::Floor($delta.TotalHours), $delta.Minutes, $delta.Seconds

# --- Draw ---
$visual = [System.Windows.Media.DrawingVisual]::new()
$dc = $visual.RenderOpen()

# Outer rounded rect (background)
$bgBrush = New-Brush '#FF1C1E22'
$rectAll = [System.Windows.Rect]::new(0, 0, $w, $h)
$dc.DrawRoundedRectangle($bgBrush, $null, $rectAll, 22, 22)

# Subtle inner border
$borderPen = [System.Windows.Media.Pen]::new((New-Brush '#22FFFFFF'), 1)
$dc.DrawRoundedRectangle($null, $borderPen, $rectAll, 22, 22)

# Top tray (⚙ left, ✕ right)
$muted = New-Brush '#B5B7BB'
$ftGear = [System.Windows.Media.FormattedText]::new(
    [char]0x2699, [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Windows.FlowDirection]::LeftToRight, $semiFace, 13, $muted, $dpi)
$ftClose = [System.Windows.Media.FormattedText]::new(
    [char]0x2715, [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Windows.FlowDirection]::LeftToRight, $semiFace, 11, $muted, $dpi)
$dc.DrawText($ftGear,  [System.Windows.Point]::new(14, 10))
$dc.DrawText($ftClose, [System.Windows.Point]::new($w - 14 - $ftClose.Width, 10))

# Prayer rows
$textBrush = New-Brush '#FFFFFF'
$pillBrush = New-Brush '#5A5E66'
$rowsTop = $topH + $timesPadTop
for ($i = 0; $i -lt $prayers.Count; $i++) {
    $p = $prayers[$i]
    $rowTop = $rowsTop + $i * $rowH

    $nameText = [System.Windows.Media.FormattedText]::new(
        $p.Name, [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Windows.FlowDirection]::LeftToRight, $boldFace, 16, $textBrush, $dpi)

    $tval = $timings.($p.Code); if (-not $tval) { $tval = '--:--' }
    $timeText = [System.Windows.Media.FormattedText]::new(
        $tval, [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Windows.FlowDirection]::LeftToRight, $boldFace, 16, $textBrush, $dpi)

    $nameX = $timesMarginX
    $nameY = $rowTop + 5
    $timeX = $w - $timesMarginX - $timeText.Width
    $timeY = $nameY

    if ($i -eq $activeIdx) {
        $pillW = $timeText.Width + 20
        $pillH = $timeText.Height + 4
        $pillX = $timeX - 10
        $pillY = $timeY - 2
        $pillRect = [System.Windows.Rect]::new($pillX, $pillY, $pillW, $pillH)
        $dc.DrawRoundedRectangle($pillBrush, $null, $pillRect, 6, 6)
    }

    $dc.DrawText($nameText, [System.Windows.Point]::new($nameX, $nameY))
    $dc.DrawText($timeText, [System.Windows.Point]::new($timeX, $timeY))
}

# Bottom mint bar
$barTop = $h - $bottomBarH
$barBrush = New-Brush '#FF1F8A5C'
$geo = [System.Windows.Media.PathGeometry]::new()
$figure = [System.Windows.Media.PathFigure]::new()
$figure.StartPoint = [System.Windows.Point]::new(0, $barTop)
[void]$figure.Segments.Add([System.Windows.Media.LineSegment]::new([System.Windows.Point]::new($w, $barTop), $true))
[void]$figure.Segments.Add([System.Windows.Media.LineSegment]::new([System.Windows.Point]::new($w, $h - 22), $true))
[void]$figure.Segments.Add([System.Windows.Media.ArcSegment]::new([System.Windows.Point]::new($w - 22, $h), [System.Windows.Size]::new(22, 22), 0, $false, [System.Windows.Media.SweepDirection]::Clockwise, $true))
[void]$figure.Segments.Add([System.Windows.Media.LineSegment]::new([System.Windows.Point]::new(22, $h), $true))
[void]$figure.Segments.Add([System.Windows.Media.ArcSegment]::new([System.Windows.Point]::new(0, $h - 22), [System.Windows.Size]::new(22, 22), 0, $false, [System.Windows.Media.SweepDirection]::Clockwise, $true))
[void]$figure.Segments.Add([System.Windows.Media.LineSegment]::new([System.Windows.Point]::new(0, $barTop), $true))
$figure.IsClosed = $true
[void]$geo.Figures.Add($figure)
$dc.DrawGeometry($barBrush, $null, $geo)

$nameLabel = $prayers[$nextIdx].Name
$nextNameText = [System.Windows.Media.FormattedText]::new(
    $nameLabel, [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Windows.FlowDirection]::LeftToRight, $boldFace, 15, $textBrush, $dpi)
$nextTimeText = [System.Windows.Media.FormattedText]::new(
    $countdown, [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Windows.FlowDirection]::LeftToRight, $boldFace, 15, $textBrush, $dpi)
$dc.DrawText($nextNameText, [System.Windows.Point]::new(22, $barTop + ($bottomBarH - $nextNameText.Height) / 2))
$dc.DrawText($nextTimeText, [System.Windows.Point]::new($w - 22 - $nextTimeText.Width, $barTop + ($bottomBarH - $nextTimeText.Height) / 2))

$dc.Close()

# Render at 2x scale for sharp PNG
$rw = [int]($w * $scale); $rh = [int]($h * $scale)
$pf = [System.Windows.Media.PixelFormats]::Pbgra32
$rtb = [System.Windows.Media.Imaging.RenderTargetBitmap]::new($rw, $rh, $dpi * $scale, $dpi * $scale, $pf)
$rtb.Render($visual)

$encoder = [System.Windows.Media.Imaging.PngBitmapEncoder]::new()
[void]$encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create([System.Windows.Media.Imaging.BitmapSource]$rtb))
$fs = [System.IO.File]::Create($outPath)
$encoder.Save($fs); $fs.Close()
Write-Host ("Saved: {0} ({1}x{2}, {3} bytes)" -f $outPath, $rw, $rh, (Get-Item $outPath).Length)
