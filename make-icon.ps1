# Generate "Намоз" icon — deep green text on light cream background, using Nunito
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$outDir = 'C:\Users\abu_y\PrayerWidget'
$icoPath = Join-Path $outDir 'namoz.ico'
$fontFamily = New-Object System.Windows.Media.FontFamily 'file:///C:/Users/abu_y/PrayerWidget/fonts/#Nunito'

function New-PngBytes([int]$size) {
    $dpi = 96
    $bgColor   = [System.Windows.Media.Color]::FromRgb(245, 244, 240)  # cream
    $textColor = [System.Windows.Media.Color]::FromRgb(20, 110, 64)    # #146E40 darker, richer green

    $visual = New-Object System.Windows.Media.DrawingVisual
    $dc = $visual.RenderOpen()

    # Background — rounded rectangle for modern feel
    $bgBrush = New-Object System.Windows.Media.SolidColorBrush $bgColor
    $cornerR = [Math]::Max(8, [int]($size * 0.18))
    $dc.DrawRoundedRectangle($bgBrush, $null, (New-Object System.Windows.Rect 0, 0, $size, $size), $cornerR, $cornerR)

    # Find largest font size that fits "Намоз" with 12% margin
    $typeface = New-Object System.Windows.Media.Typeface (
        $fontFamily,
        [System.Windows.FontStyles]::Normal,
        [System.Windows.FontWeights]::Black,
        [System.Windows.FontStretches]::Normal
    )
    $maxWidth  = $size * 0.82
    $maxHeight = $size * 0.55
    $fontSize  = $size * 0.55
    $brush = New-Object System.Windows.Media.SolidColorBrush $textColor
    while ($fontSize -gt 6) {
        $ft = New-Object System.Windows.Media.FormattedText (
            'Намоз',
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Windows.FlowDirection]::LeftToRight,
            $typeface,
            $fontSize,
            $brush,
            $dpi
        )
        if ($ft.Width -le $maxWidth -and $ft.Height -le $maxHeight) { break }
        $fontSize = $fontSize * 0.92
    }

    $x = ($size - $ft.Width) / 2
    $y = ($size - $ft.Height) / 2
    $dc.DrawText($ft, (New-Object System.Windows.Point $x, $y))
    $dc.Close()

    $pf = [System.Windows.Media.PixelFormats]::Pbgra32
    $rtb = [System.Windows.Media.Imaging.RenderTargetBitmap]::new($size, $size, $dpi, $dpi, $pf)
    $rtb.Render($visual)

    $encoder = [System.Windows.Media.Imaging.PngBitmapEncoder]::new()
    $source  = [System.Windows.Media.Imaging.BitmapSource]$rtb
    $frame   = [System.Windows.Media.Imaging.BitmapFrame]::Create($source)
    [void]$encoder.Frames.Add($frame)
    $ms = New-Object System.IO.MemoryStream
    $encoder.Save($ms)
    return $ms.ToArray()
}

function Write-IcoFile([string]$path, [hashtable]$pngsBySize) {
    $sizes = $pngsBySize.Keys | Sort-Object
    $count = $sizes.Count

    $fs = [System.IO.File]::Create($path)

    # ICONDIR (6 bytes)
    $fs.WriteByte(0); $fs.WriteByte(0)                # reserved
    $fs.WriteByte(1); $fs.WriteByte(0)                # type = 1 (ICO)
    $fs.WriteByte($count -band 0xFF); $fs.WriteByte(($count -shr 8) -band 0xFF)

    # Each ICONDIRENTRY = 16 bytes. Image data follows after all entries.
    $headerSize = 6 + 16 * $count
    $offset = $headerSize

    foreach ($sz in $sizes) {
        $pngBytes = $pngsBySize[$sz]
        $len = $pngBytes.Length
        # width/height: 0 means 256
        $w = if ($sz -ge 256) { 0 } else { $sz }
        $h = $w
        $fs.WriteByte($w)            # width
        $fs.WriteByte($h)            # height
        $fs.WriteByte(0)             # color count
        $fs.WriteByte(0)             # reserved
        $fs.WriteByte(1); $fs.WriteByte(0)            # color planes = 1
        $fs.WriteByte(32); $fs.WriteByte(0)           # bpp = 32
        # size of image data (4 bytes, little-endian)
        $fs.WriteByte($len -band 0xFF)
        $fs.WriteByte(($len -shr 8) -band 0xFF)
        $fs.WriteByte(($len -shr 16) -band 0xFF)
        $fs.WriteByte(($len -shr 24) -band 0xFF)
        # offset to image data
        $fs.WriteByte($offset -band 0xFF)
        $fs.WriteByte(($offset -shr 8) -band 0xFF)
        $fs.WriteByte(($offset -shr 16) -band 0xFF)
        $fs.WriteByte(($offset -shr 24) -band 0xFF)
        $offset += $len
    }

    foreach ($sz in $sizes) {
        $pngBytes = $pngsBySize[$sz]
        $fs.Write($pngBytes, 0, $pngBytes.Length)
    }

    $fs.Close()
}

$pngs = @{}
foreach ($sz in @(48, 64, 128, 256)) {
    $pngs[$sz] = New-PngBytes -size $sz
    Write-Host "Generated $sz PNG: $($pngs[$sz].Length) bytes"
}

Write-IcoFile -path $icoPath -pngsBySize $pngs
Write-Host "Saved icon: $icoPath ($((Get-Item $icoPath).Length) bytes)"
