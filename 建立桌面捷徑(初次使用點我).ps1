# 建立桌面捷徑：先選風格（經典色 / 草莓牛奶），然後在桌面建立「一鍵登出」捷徑。
# 名字固定叫「一鍵登出」，只有圖示隨風格不同。選好的風格會記在「主題.txt」，直接跑 一鍵登出.ps1（沒給 -Theme）也會用同一種。
#
#   建立桌面捷徑(初次使用點我).ps1 跳出選擇視窗
#   建立桌面捷徑(初次使用點我).ps1 -Theme 可愛 不問，直接用指定風格
param([string]$Theme, [string]$Desktop)
Add-Type -AssemblyName System.Windows.Forms, PresentationFramework, PresentationCore, WindowsBase

$Root   = $PSScriptRoot
$Assets = Join-Path $Root '素材'
$Themes = [ordered]@{
    # Tint 是預覽後面的底色，Accent 是「用這個」按鈕和滑鼠移上去時的邊框色
    '經典' = @{ Title = '經典色';   Desc = 'Windows 11 風格，清爽俐落'; Icon = '經典圖示.ico'; Tint = '#E9EEF5'; Accent = '#0067C0' }
    '可愛' = @{ Title = '草莓牛奶'; Desc = '奶油色配莓果粉，圓圓的字';  Icon = '莓果.ico';     Tint = '#FBE3EA'; Accent = '#E2558F' }
}

# 預覽用的縮小版「要登出了嗎？」視窗：只留標題，清單畫成線條、按鈕只寫兩個字，縮小了字也不會糊
$BarWidths = 104, 70, 42, 88
function New-MiniPreview($key) {
    $cute = $key -eq '可愛'
    $dot  = if ($cute) { '<Rectangle Width="5" Height="5" Fill="#FF5FA2"/>' } else { '<Ellipse Width="5" Height="5" Fill="#0067C0"/>' }
    $bar  = if ($cute) { '#DCC6CD' } else { '#CFCFCF' }
    $rows = ($BarWidths | ForEach-Object {
        "<StackPanel Orientation='Horizontal' Margin='0,6,0,0'>$dot<Rectangle Width='$_' Height='5' RadiusX='2.5' RadiusY='2.5' Fill='$bar' Margin='6,0,0,0'/></StackPanel>"
    }) -join ''
    $ns = 'xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"'
    $xaml = if ($cute) { @"
<Border $ns Width="184" Background="#FFC8DD" BorderBrush="#3B1E2B" BorderThickness="2" Padding="3" HorizontalAlignment="Center" VerticalAlignment="Center">
  <Border Background="#FFF7EE" BorderBrush="#3B1E2B" BorderThickness="2" Padding="11,9" TextElement.Foreground="#3B1E2B">
    <StackPanel>
      <TextBlock Text="要登出了嗎？" FontSize="13"/>
      <Border Background="White" BorderBrush="#F2C9D8" BorderThickness="1" Padding="8,1,8,7" Margin="0,7,0,0"><StackPanel>$rows</StackPanel></Border>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,9,0,0">
        <Border Background="#FFF7EE" BorderBrush="#3B1E2B" BorderThickness="1.5" Padding="7,1"><TextBlock Text="先不要" FontSize="10"/></Border>
        <Border Background="#FF5FA2" BorderBrush="#3B1E2B" BorderThickness="1.5" Padding="9,1" Margin="5,0,0,0"><TextBlock Text="登出" FontSize="10" Foreground="White"/></Border>
      </StackPanel>
    </StackPanel>
  </Border>
</Border>
"@ } else { @"
<Border $ns Width="184" Background="White" BorderBrush="#E3E3E3" BorderThickness="1" CornerRadius="6" Padding="12,11" HorizontalAlignment="Center" VerticalAlignment="Center" TextElement.Foreground="#1B1B1B">
  <Border.Effect><DropShadowEffect BlurRadius="12" ShadowDepth="2" Direction="270" Opacity="0.12"/></Border.Effect>
  <StackPanel>
    <StackPanel Orientation="Horizontal">
      <Border Width="18" Height="18" CornerRadius="4" Background="#E5F0FB">
        <Path Data="M8,4.5 H5 V13.5 H8 M8.5,9 H13.5 M11.2,6.6 L13.6,9 L11.2,11.4" Stroke="#0067C0" StrokeThickness="1.6"
              StrokeLineJoin="Round" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
      </Border>
      <TextBlock Text="要登出了嗎？" FontSize="12" FontWeight="SemiBold" Margin="6,0,0,0" VerticalAlignment="Center"/>
    </StackPanel>
    <StackPanel Margin="0,2,0,0">$rows</StackPanel>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
      <Border BorderBrush="#D6D6D6" BorderThickness="1" CornerRadius="3" Padding="8,1"><TextBlock Text="先不要" FontSize="10"/></Border>
      <Border Background="#0067C0" CornerRadius="3" Padding="10,1" Margin="5,0,0,0"><TextBlock Text="登出" FontSize="10" Foreground="White"/></Border>
    </StackPanel>
  </StackPanel>
</Border>
"@ }
    $el = [Windows.Markup.XamlReader]::Parse($xaml)
    # 可愛風用附帶的粉圓體，跟真的視窗一樣
    if ($cute) { try { $el.FontFamily = New-Object Windows.Media.FontFamily ([Uri]"$Assets\"), './#Huninn, Microsoft JhengHei UI' } catch {} }
    return $el
}

$PickerXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="一鍵登出" WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="NoResize" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen"
        Topmost="True" UseLayoutRounding="True" SnapsToDevicePixels="True"
        FontFamily="Segoe UI Variable Text, Microsoft JhengHei UI"
        TextOptions.TextFormattingMode="Ideal" TextOptions.TextRenderingMode="ClearType">
  <Window.Resources>
    <!-- 每個選項是一張卡片：預覽圖、圖示和名稱、「用這個」按鈕，整張都可以點。滑鼠移上去邊框變成該風格的顏色 -->
    <ControlTemplate x:Key="OptionCard" TargetType="Button">
      <Border x:Name="Face" Background="#FFFFFF" BorderBrush="#D1D1D1" BorderThickness="1" CornerRadius="8" Padding="10" Margin="8,0">
        <ContentPresenter/>
      </Border>
      <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter TargetName="Face" Property="BorderBrush" Value="{Binding BorderBrush, RelativeSource={RelativeSource TemplatedParent}}"/>
        </Trigger>
        <Trigger Property="IsKeyboardFocused" Value="True">
          <Setter TargetName="Face" Property="BorderBrush" Value="{Binding BorderBrush, RelativeSource={RelativeSource TemplatedParent}}"/>
        </Trigger>
        <Trigger Property="IsPressed" Value="True"><Setter TargetName="Face" Property="Opacity" Value="0.85"/></Trigger>
      </ControlTemplate.Triggers>
    </ControlTemplate>
    <ControlTemplate x:Key="FlatButton" TargetType="Button">
      <Border x:Name="Face" Background="#FFFFFF" BorderBrush="#D6D6D6" BorderThickness="1" CornerRadius="6" MinWidth="104" Height="34" Padding="18,0">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
      </Border>
      <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Face" Property="Background" Value="#F5F5F5"/></Trigger>
      </ControlTemplate.Triggers>
    </ControlTemplate>
  </Window.Resources>
  <Border Margin="24" Background="#FFFFFF" BorderBrush="#E5E5E5" BorderThickness="1" CornerRadius="8"
          Padding="28,24,28,24" TextElement.Foreground="#1B1B1B">
    <Border.Effect><DropShadowEffect BlurRadius="28" ShadowDepth="6" Direction="270" Opacity="0.14" Color="#000000"/></Border.Effect>
    <StackPanel>
      <TextBlock Text="你要哪一種風格？" FontSize="20" FontWeight="SemiBold"/>
      <TextBlock Text="選一個，桌面會多一個「一鍵登出」捷徑，點它就會用這種樣子。" FontSize="13" Foreground="#6E6E6E" Margin="0,6,0,18"/>
      <StackPanel x:Name="Options" Orientation="Horizontal" HorizontalAlignment="Center" Margin="-8,0"/>
      <DockPanel Margin="0,20,0,0" LastChildFill="False">
        <TextBlock Text="之後想換，再執行一次就可以。" DockPanel.Dock="Left" FontSize="13" Foreground="#6E6E6E" VerticalAlignment="Center"/>
        <Button x:Name="Cancel" Content="先不要" Template="{StaticResource FlatButton}" DockPanel.Dock="Right" FontSize="14" IsCancel="True"/>
      </DockPanel>
    </StackPanel>
  </Border>
</Window>
'@

# 跳出選擇視窗，回傳 '經典' / '可愛'，取消回傳 $null
function Show-ThemePicker {
    $win = [Windows.Markup.XamlReader]::Parse($PickerXaml)
    try { $win.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([Uri](Join-Path $Assets '經典圖示.ico')) } catch {}
    $panel = $win.FindName('Options')
    foreach ($key in $Themes.Keys) {
        $t = $Themes[$key]
        $stack = New-Object Windows.Controls.StackPanel -Property @{ Width = 236 }
        # 預覽：縮小版的確認視窗放在有顏色的底上
        $null = $stack.Children.Add((New-Object Windows.Controls.Border -Property @{ Background = $t.Tint; CornerRadius = 6; Height = 156; Child = (New-MiniPreview $key) }))
        # 圖示（就是桌面捷徑會用的）＋名稱和說明
        $row = New-Object Windows.Controls.StackPanel -Property @{ Orientation = 'Horizontal'; Margin = '2,10,2,10' }
        $ico = New-Object Windows.Controls.Image -Property @{ Width = 28; Height = 28; VerticalAlignment = 'Center' }
        try { $ico.Source = [Windows.Media.Imaging.BitmapFrame]::Create([Uri](Join-Path $Assets $t.Icon)) } catch {}
        $text = New-Object Windows.Controls.StackPanel -Property @{ Margin = '10,0,0,0'; VerticalAlignment = 'Center' }
        $null = $text.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $t.Title; FontSize = 15; FontWeight = 'SemiBold' }))
        $null = $text.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $t.Desc; FontSize = 12; Foreground = '#6E6E6E'; Margin = '0,1,0,0' }))
        $null = $row.Children.Add($ico); $null = $row.Children.Add($text)
        $null = $stack.Children.Add($row)
        # 「用這個」只是畫出來的按鈕，整張卡片都可以點
        $use = New-Object Windows.Controls.TextBlock -Property @{ Text = '用這個'; FontSize = 14; FontWeight = 'SemiBold'; Foreground = '#FFFFFF'; HorizontalAlignment = 'Center'; VerticalAlignment = 'Center' }
        $null = $stack.Children.Add((New-Object Windows.Controls.Border -Property @{ Background = $t.Accent; CornerRadius = 4; Height = 34; Child = $use }))
        $btn = New-Object Windows.Controls.Button -Property @{ Template = $win.Resources['OptionCard']; Content = $stack; Tag = $key; Cursor = 'Hand'; BorderBrush = $t.Accent }
        $btn.add_Click({ $w = [Windows.Window]::GetWindow($this); $w.Tag = $this.Tag; $w.Close() })
        $null = $panel.Children.Add($btn)
    }
    $win.FindName('Cancel').add_Click({ [Windows.Window]::GetWindow($this).Close() })
    $win.add_MouseLeftButtonDown({ $this.DragMove() })
    $win.add_Loaded({ $this.Activate() })
    $null = $win.ShowDialog()
    return $win.Tag
}

$interactive = -not $Theme
if ($interactive) { $Theme = Show-ThemePicker }
if (-not $Theme) { exit }
if (-not $Themes.Contains($Theme)) { throw "沒有「$Theme」這種風格，只有：$($Themes.Keys -join '、')" }

# 記住風格，讓直接跑 一鍵登出.ps1 時也用同一種
[IO.File]::WriteAllText((Join-Path $Root '主題.txt'), $Theme, (New-Object Text.UTF8Encoding $true))

# 建立捷徑：名字固定「一鍵登出」，圖示依風格
if (-not $Desktop) { $Desktop = [Environment]::GetFolderPath('Desktop') }
$script = Join-Path $Root '一鍵登出.ps1'
$icon   = Join-Path $Assets $Themes[$Theme].Icon
$link   = Join-Path $Desktop '一鍵登出.lnk'
$s = (New-Object -ComObject WScript.Shell).CreateShortcut($link)
$s.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$s.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Theme $Theme"
$s.WorkingDirectory = $Root
if (Test-Path -LiteralPath $icon) { $s.IconLocation = "$icon,0" }
$s.Description = '登出 Claude、Codex、LINE 和瀏覽器裡的所有網站'
$s.Save()

$msg = "已在桌面建立「一鍵登出」捷徑（$($Themes[$Theme].Title)）。`n$link"
if ($interactive) { [System.Windows.Forms.MessageBox]::Show($msg, '一鍵登出', 'OK', 'Information') | Out-Null } else { $msg }
