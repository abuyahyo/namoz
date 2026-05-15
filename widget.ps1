# Prayer Times Widget — Cairo, MWL, UZ/RU, Sajda-style flat dark
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:Mutex = New-Object System.Threading.Mutex($false, 'Global\PrayerTimesWidgetSingleton_abu_y')
if (-not $script:Mutex.WaitOne(0)) { exit 0 }

$script:ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ConfigPath = Join-Path $script:ScriptDir 'config.json'
$script:CachePath  = Join-Path $script:ScriptDir 'cache.json'

$script:Strings = @{
    uz = @{
        Loading = 'Юкланмоқда...'
        Offline = 'Интернет йўқ'
        Next    = 'Кейинги'
        Prayers = @(
            @{ Code = 'Fajr';    Name = 'Бомдод' }
            @{ Code = 'Sunrise'; Name = 'Қуёш'   }
            @{ Code = 'Dhuhr';   Name = 'Пешин'  }
            @{ Code = 'Asr';     Name = 'Аср'    }
            @{ Code = 'Maghrib'; Name = 'Шом'    }
            @{ Code = 'Isha';    Name = 'Хуфтон' }
        )
    }
}

$script:Config = @{ Left = $null; Top = $null; Lang = 'uz'; City = 'Cairo'; Country = 'Egypt' }
if (Test-Path $script:ConfigPath) {
    try {
        $loaded = Get-Content $script:ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $loaded.Left)    { $script:Config.Left    = [double]$loaded.Left }
        if ($null -ne $loaded.Top)     { $script:Config.Top     = [double]$loaded.Top  }
        if ($loaded.Lang)              { $script:Config.Lang    = [string]$loaded.Lang }
        if ($loaded.City)              { $script:Config.City    = [string]$loaded.City }
        if ($loaded.Country)           { $script:Config.Country = [string]$loaded.Country }
    } catch { }
}

function Save-Config {
    try { $script:Config | ConvertTo-Json | Out-File -FilePath $script:ConfigPath -Encoding utf8 -Force } catch { }
}

# Pick Aladhan calculation method by country.
# Codes: https://aladhan.com/calculation-methods
function Get-MethodForCountry([string]$country) {
    if (-not $country) { return 3 }
    $c = $country.Trim().ToLower()
    switch -Regex ($c) {
        '^(egypt|misr|египет|миср)$'                                                                 { return 5 }
        '^(saudi arabia|saudi|саудия|саудия аравия|саудовская аравия)$'                              { return 4 }
        '^(russia|russian federation|россия|русия)$'                                                 { return 14 }
        '^(uzbekistan|узбекистан|ўзбекистон|o''zbekiston)$'                                          { return 14 }
        '^(kazakhstan|казахстан|қозоғистон)$'                                                        { return 14 }
        '^(kyrgyzstan|kirghizia|киргизия|қирғизистон)$'                                              { return 14 }
        '^(tajikistan|таджикистан|тожикистон)$'                                                      { return 14 }
        '^(turkmenistan|туркменистан|туркманистон)$'                                                 { return 14 }
        '^(azerbaijan|азербайджан|озарбойжон)$'                                                      { return 14 }
        '^(belarus|беларусь|белоруссия)$'                                                            { return 14 }
        '^(ukraine|украина|украйина)$'                                                               { return 14 }
        '^(pakistan|пакистан)$'                                                                      { return 1 }
        '^(afghanistan|афганистан|афғонистон)$'                                                      { return 1 }
        '^(india|индия)$'                                                                            { return 1 }
        '^(bangladesh|бангладеш)$'                                                                   { return 1 }
        '^(iran|иран)$'                                                                              { return 7 }
        '^(turkey|türkiye|туркия|туркия)$'                                                           { return 13 }
        '^(united arab emirates|uae|оаэ|дубай|dubai)$'                                               { return 16 }
        '^(kuwait|кувейт)$'                                                                          { return 9 }
        '^(qatar|катар)$'                                                                            { return 10 }
        '^(bahrain|бахрейн)$'                                                                        { return 8 }
        '^(oman|оман)$'                                                                              { return 8 }
        '^(singapore|сингапур)$'                                                                     { return 11 }
        '^(france|франция)$'                                                                         { return 12 }
        '^(malaysia|малайзия)$'                                                                      { return 17 }
        '^(tunisia|тунис)$'                                                                          { return 18 }
        '^(algeria|алжир)$'                                                                          { return 19 }
        '^(indonesia|индонезия)$'                                                                    { return 20 }
        '^(morocco|марокко)$'                                                                        { return 21 }
        '^(portugal|португалия)$'                                                                    { return 22 }
        '^(jordan|иордания)$'                                                                        { return 23 }
        '^(usa|united states|сша)$'                                                                  { return 2 }
        '^(canada|канада)$'                                                                          { return 2 }
        default                                                                                      { return 3 }
    }
}

function Get-Timings {
    $today   = (Get-Date).ToString('dd-MM-yyyy')
    $city    = $script:Config.City
    $country = $script:Config.Country
    $method  = Get-MethodForCountry $country

    if (Test-Path $script:CachePath) {
        try {
            $cached = Get-Content $script:CachePath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cached.Date -eq $today -and $cached.City -eq $city -and $cached.Country -eq $country) { return $cached }
        } catch { }
    }
    try {
        $cityEnc    = [System.Uri]::EscapeDataString($city)
        $countryEnc = [System.Uri]::EscapeDataString($country)
        $url  = "https://api.aladhan.com/v1/timingsByCity/$today" + "?city=$cityEnc&country=$countryEnc&method=$method"
        $resp = Invoke-RestMethod -Uri $url -TimeoutSec 15
        $t = $resp.data.timings
        $result = [pscustomobject]@{
            Date = $today; City = $city; Country = $country; Method = $method
            Fajr = $t.Fajr; Sunrise = $t.Sunrise; Dhuhr = $t.Dhuhr
            Asr = $t.Asr; Maghrib = $t.Maghrib; Isha = $t.Isha; Offline = $false
        }
        $result | ConvertTo-Json | Out-File -FilePath $script:CachePath -Encoding utf8 -Force
        return $result
    } catch {
        if (Test-Path $script:CachePath) {
            try {
                $cached = Get-Content $script:CachePath -Raw -Encoding UTF8 | ConvertFrom-Json
                $cached | Add-Member -NotePropertyName Offline -NotePropertyValue $true -Force
                return $cached
            } catch { }
        }
        return $null
    }
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" SizeToContent="WidthAndHeight"
        ResizeMode="NoResize" WindowStartupLocation="Manual"
        FontFamily="file:///C:/Users/abu_y/PrayerWidget/fonts/#Nunito">
  <Border CornerRadius="22" Background="#FA1C1E22" BorderBrush="#44000000" BorderThickness="1">
    <Border.Effect>
      <DropShadowEffect Color="Black" BlurRadius="22" ShadowDepth="4" Opacity="0.55"/>
    </Border.Effect>
    <Grid Width="220">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <DockPanel Grid.Row="0" LastChildFill="False" Margin="14,10,14,2">
        <Button x:Name="BtnSettings" DockPanel.Dock="Left" Content="&#x2699;"
                Width="22" Height="20" Background="Transparent" Foreground="#B5B7BB"
                BorderThickness="0" FontSize="13" Cursor="Hand"
                ToolTip="Созламалар"/>
        <Button x:Name="BtnClose" DockPanel.Dock="Right" Content="&#x2715;"
                Width="20" Height="20" Background="Transparent" Foreground="#B5B7BB"
                BorderThickness="0" FontSize="11" Cursor="Hand"
                ToolTip="Ёпиш"/>
      </DockPanel>

      <StackPanel x:Name="TimesPanel" Grid.Row="1" Margin="22,4,22,18"/>

      <Border x:Name="BottomBar" Grid.Row="2" CornerRadius="0,0,22,22" Background="#1F8A5C" Padding="22,12,22,12">
        <DockPanel LastChildFill="False">
          <TextBlock x:Name="NextNameText" DockPanel.Dock="Left" Foreground="White"
                     FontWeight="Bold" FontSize="15" VerticalAlignment="Center" Text=""/>
          <TextBlock x:Name="NextTimeText" DockPanel.Dock="Right" Foreground="White"
                     FontWeight="Bold" FontSize="15" Typography.NumeralAlignment="Tabular"
                     VerticalAlignment="Center" Text="--:--:--"/>
        </DockPanel>
      </Border>
    </Grid>
  </Border>
</Window>
'@

$reader        = New-Object System.Xml.XmlNodeReader $xaml
$script:Window = [Windows.Markup.XamlReader]::Load($reader)

$script:TimesPanel    = $script:Window.FindName('TimesPanel')
$script:BtnClose      = $script:Window.FindName('BtnClose')
$script:BtnSettings   = $script:Window.FindName('BtnSettings')
$script:BottomBar     = $script:Window.FindName('BottomBar')
$script:NextNameText  = $script:Window.FindName('NextNameText')
$script:NextTimeText  = $script:Window.FindName('NextTimeText')

if ($null -ne $script:Config.Left) { $script:Window.Left = $script:Config.Left }
if ($null -ne $script:Config.Top)  { $script:Window.Top  = $script:Config.Top  }

$script:Window.Add_Loaded({
    $wa = [System.Windows.SystemParameters]::WorkArea
    if ($null -eq $script:Config.Left) { $script:Window.Left = $wa.Right - $script:Window.ActualWidth - 20 }
    if ($null -eq $script:Config.Top)  { $script:Window.Top  = $wa.Top + 20 }
})

$script:Window.Add_MouseLeftButtonDown({
    param($s, $e)
    if ($e.LeftButton -eq 'Pressed') { $script:Window.DragMove() }
})

$script:BtnClose.Add_Click({ $script:Window.Close() })

function Show-SettingsDialog {
    [xml]$dlgXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Созламалар" Width="320" SizeToContent="Height"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        FontFamily="file:///C:/Users/abu_y/PrayerWidget/fonts/#Nunito">
  <Border CornerRadius="16" Background="#FA1C1E22" BorderBrush="#44000000" BorderThickness="1" Padding="20">
    <Border.Effect>
      <DropShadowEffect Color="Black" BlurRadius="22" ShadowDepth="4" Opacity="0.55"/>
    </Border.Effect>
    <StackPanel>
      <TextBlock x:Name="Header" Text="Созламалар" Foreground="White" FontWeight="Bold" FontSize="17" Margin="0,0,0,14"/>

      <TextBlock Text="Шаҳар" Foreground="#9AA0A6" FontSize="11" Margin="0,0,0,4"/>
      <TextBox x:Name="CityBox" Padding="10,7,10,7" Background="#2C2F35"
               Foreground="White" BorderBrush="#3D4148" BorderThickness="1"
               FontSize="14" CaretBrush="White" SelectionBrush="#1F8A5C"/>

      <TextBlock Text="Давлат" Foreground="#9AA0A6" FontSize="11" Margin="0,14,0,4"/>
      <TextBox x:Name="CountryBox" Padding="10,7,10,7" Background="#2C2F35"
               Foreground="White" BorderBrush="#3D4148" BorderThickness="1"
               FontSize="14" CaretBrush="White" SelectionBrush="#1F8A5C"/>

      <TextBlock x:Name="HintText" Foreground="#7A7E85" FontSize="10" Margin="0,8,0,0"
                 TextWrapping="Wrap" Text="Шаҳар ва давлат номини инглизча ёзинг (масалан: Tashkent / Uzbekistan, Cairo / Egypt)."/>

      <DockPanel LastChildFill="False" Margin="0,18,0,0">
        <Button x:Name="BtnSave" DockPanel.Dock="Right" Content="Сақлаш"
                Padding="14,7,14,7" Background="#1F8A5C" Foreground="White"
                BorderThickness="0" FontWeight="Bold" FontSize="13" Cursor="Hand"/>
        <Button x:Name="BtnCancel" DockPanel.Dock="Right" Content="Бекор"
                Padding="14,7,14,7" Margin="0,0,8,0" Background="#3D4148" Foreground="White"
                BorderThickness="0" FontSize="13" Cursor="Hand"/>
      </DockPanel>
    </StackPanel>
  </Border>
</Window>
'@
    $reader = New-Object System.Xml.XmlNodeReader $dlgXaml
    $dlg = [Windows.Markup.XamlReader]::Load($reader)
    $cityBox    = $dlg.FindName('CityBox')
    $countryBox = $dlg.FindName('CountryBox')
    $btnSave    = $dlg.FindName('BtnSave')
    $btnCancel  = $dlg.FindName('BtnCancel')

    $cityBox.Text    = $script:Config.City
    $countryBox.Text = $script:Config.Country

    $script:DialogResult = $false
    $btnCancel.Add_Click({ $dlg.Close() })
    $btnSave.Add_Click({
        $c  = $cityBox.Text.Trim()
        $cc = $countryBox.Text.Trim()
        if ($c -and $cc) {
            $script:Config.City    = $c
            $script:Config.Country = $cc
            Save-Config
            Remove-Item $script:CachePath -Force -ErrorAction SilentlyContinue
            $script:Timings = $null
            $script:LastFetchDate = ''
            $script:DialogResult = $true
            $dlg.Close()
        }
    })

    # Allow dragging the dialog
    $dlg.Add_MouseLeftButtonDown({
        param($s,$e)
        if ($e.LeftButton -eq 'Pressed' -and $e.OriginalSource -isnot [System.Windows.Controls.TextBox]) {
            $dlg.DragMove()
        }
    })

    $dlg.Owner = $script:Window
    [void]$dlg.ShowDialog()
    return $script:DialogResult
}

$script:BtnSettings.Add_Click({
    $changed = Show-SettingsDialog
    if ($changed) {
        $script:Timings = Get-Timings
        if ($script:Timings) { $script:LastFetchDate = $script:Timings.Date }
        Render-Widget
    }
})

$script:Window.Add_Closing({
    $script:Config.Left = $script:Window.Left
    $script:Config.Top  = $script:Window.Top
    Save-Config
})

function New-Brush([string]$hex) {
    [System.Windows.Media.BrushConverter]::new().ConvertFromString($hex)
}

$script:TimeRows = @{}

function Build-Rows {
    $script:TimesPanel.Children.Clear()
    $script:TimeRows = @{}
    $s = $script:Strings.uz
    $textBrush = New-Brush '#FFFFFF'
    foreach ($p in $s.Prayers) {
        $row = New-Object System.Windows.Controls.DockPanel
        $row.LastChildFill = $false
        $row.Margin = '0,7,0,7'

        $name = New-Object System.Windows.Controls.TextBlock
        $name.Text = $p.Name
        $name.Foreground = $textBrush
        $name.FontSize = 16
        $name.FontWeight = 'Bold'
        [System.Windows.Controls.DockPanel]::SetDock($name, [System.Windows.Controls.Dock]::Left)

        $timeBorder = New-Object System.Windows.Controls.Border
        $timeBorder.CornerRadius = New-Object System.Windows.CornerRadius 6
        $timeBorder.Padding = New-Object System.Windows.Thickness 8, 2, 8, 2
        $timeBorder.Background = [System.Windows.Media.Brushes]::Transparent
        [System.Windows.Controls.DockPanel]::SetDock($timeBorder, [System.Windows.Controls.Dock]::Right)

        $time = New-Object System.Windows.Controls.TextBlock
        $time.Text = '--:--'
        $time.Foreground = $textBrush
        $time.FontSize = 16
        $time.FontWeight = 'Bold'
        [System.Windows.Documents.Typography]::SetNumeralAlignment($time, [System.Windows.FontNumeralAlignment]::Tabular)
        $timeBorder.Child = $time

        [void]$row.Children.Add($name)
        [void]$row.Children.Add($timeBorder)
        [void]$script:TimesPanel.Children.Add($row)
        $script:TimeRows[$p.Code] = @{ Name = $name; Time = $time; Border = $timeBorder }
    }
}

function Render-Widget {
    $s   = $script:Strings.uz
    $now = Get-Date

    if ($script:TimeRows.Count -eq 0 -or $script:TimeRows.Count -ne $s.Prayers.Count) {
        Build-Rows
    }

    if (-not $script:Timings) {
        $script:NextNameText.Text = $s.Loading
        $script:NextTimeText.Text = ''
        return
    }

    $today    = Get-Date -Hour 0 -Minute 0 -Second 0
    $pillBg   = New-Brush '#5A5E66'
    $clearBg  = [System.Windows.Media.Brushes]::Transparent

    $prayerDts = @{}
    foreach ($p in $s.Prayers) {
        $tval = $script:Timings.($p.Code)
        if ($tval) {
            $hm = $tval -split ':'
            $prayerDts[$p.Code] = $today.AddHours([int]$hm[0]).AddMinutes([int]$hm[1])
        }
    }

    $activeCode = $null; $activeDt = $null
    foreach ($p in $s.Prayers) {
        if ($p.Code -eq 'Sunrise') { continue }
        $dt = $prayerDts[$p.Code]
        if (-not $dt) { continue }
        if ($dt -le $now -and (-not $activeDt -or $dt -gt $activeDt)) { $activeDt = $dt; $activeCode = $p.Code }
    }

    $nextCode = $null; $nextDt = $null; $nextName = $null
    foreach ($p in $s.Prayers) {
        if ($p.Code -eq 'Sunrise') { continue }
        $dt = $prayerDts[$p.Code]
        if (-not $dt) { continue }
        if ($dt -gt $now -and (-not $nextDt -or $dt -lt $nextDt)) {
            $nextDt = $dt; $nextCode = $p.Code; $nextName = $p.Name
        }
    }

    foreach ($p in $s.Prayers) {
        $row = $script:TimeRows[$p.Code]
        $tval = $script:Timings.($p.Code)
        if ($tval) { $row.Time.Text = $tval }
        $row.Border.Background = if ($p.Code -eq $activeCode) { $pillBg } else { $clearBg }
    }

    if ($script:Timings.PSObject.Properties['Offline'] -and $script:Timings.Offline) {
        $script:BottomBar.Background = New-Brush '#E8A845'
        $script:NextNameText.Text = $s.Offline
        $script:NextTimeText.Text = ''
    } else {
        $script:BottomBar.Background = New-Brush '#1F8A5C'
        if ($nextDt) {
            $delta = $nextDt - $now
            $script:NextNameText.Text = $nextName
            $script:NextTimeText.Text = '{0:D2}:{1:D2}:{2:D2}' -f [int][math]::Floor($delta.TotalHours), $delta.Minutes, $delta.Seconds
        } else {
            $pName = $s.Prayers[0].Name
            $tomorrowFajr = $today.AddDays(1)
            if ($script:Timings.Fajr) {
                $hm = $script:Timings.Fajr -split ':'
                $tomorrowFajr = $tomorrowFajr.AddHours([int]$hm[0]).AddMinutes([int]$hm[1])
            }
            $delta = $tomorrowFajr - $now
            $script:NextNameText.Text = $pName
            $script:NextTimeText.Text = '{0:D2}:{1:D2}:{2:D2}' -f [int][math]::Floor($delta.TotalHours), $delta.Minutes, $delta.Seconds
        }
    }
}

$script:Timings       = Get-Timings
$script:LastFetchDate = if ($script:Timings) { $script:Timings.Date } else { '' }
Render-Widget

$script:Timer = New-Object System.Windows.Threading.DispatcherTimer
$script:Timer.Interval = [TimeSpan]::FromSeconds(1)
$script:Timer.Add_Tick({
    $today = (Get-Date).ToString('dd-MM-yyyy')
    if ($today -ne $script:LastFetchDate -or -not $script:Timings) {
        $fresh = Get-Timings
        if ($fresh) { $script:Timings = $fresh; $script:LastFetchDate = $fresh.Date }
    }
    Render-Widget
})
$script:Timer.Start()

[void]$script:Window.ShowDialog()
