# 建立桌面捷徑：先選風格（經典色 / 可愛粉），然後在桌面建立「一鍵登出」捷徑。
# 名字固定叫「一鍵登出」，只有圖示隨風格不同。選好的風格會記在「主題.txt」，雙擊 一鍵登出.cmd 也會用同一種。
#
#   建立桌面捷徑.ps1              跳出選擇視窗
#   建立桌面捷徑.ps1 -Theme 可愛   不問，直接用指定風格
param([string]$Theme, [string]$Desktop)
Add-Type -AssemblyName System.Windows.Forms, PresentationFramework, PresentationCore, WindowsBase

$Root   = $PSScriptRoot
$Assets = Join-Path $Root '素材'
$Themes = [ordered]@{
    '經典' = @{ Title = '經典色'; Desc = 'Windows 11 風格，清爽俐落'; Icon = '經典圖示.ico'; Preview = '預覽-經典.png' }
    '可愛' = @{ Title = '可愛粉'; Desc = '粉色像素風，粉圓體';       Icon = '關門鍵.ico';   Preview = '預覽-可愛.png' }
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
    <!-- 每個選項是一張卡片：預覽圖、名稱、說明。滑鼠移上去邊框變藍 -->
    <ControlTemplate x:Key="OptionCard" TargetType="Button">
      <Border x:Name="Face" Background="#FFFFFF" BorderBrush="#E5E5E5" BorderThickness="1" CornerRadius="8" Padding="12" Margin="6,0">
        <ContentPresenter/>
      </Border>
      <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter TargetName="Face" Property="BorderBrush" Value="#0067C0"/>
          <Setter TargetName="Face" Property="Background" Value="#F7FAFD"/>
        </Trigger>
        <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Face" Property="BorderBrush" Value="#0067C0"/></Trigger>
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
      <TextBlock Text="之後會在桌面建立一個叫「一鍵登出」的捷徑，點它就會用這種風格。" FontSize="13" Foreground="#6E6E6E" Margin="0,6,0,20"/>
      <StackPanel x:Name="Options" Orientation="Horizontal" HorizontalAlignment="Center"/>
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
        $stack = New-Object Windows.Controls.StackPanel -Property @{ Width = 300 }
        $img = New-Object Windows.Controls.Image -Property @{ Width = 300; Stretch = 'Uniform'; Margin = '0,0,0,10' }
        try { $img.Source = [Windows.Media.Imaging.BitmapFrame]::Create([Uri](Join-Path $Assets $t.Preview)) } catch {}
        $null = $stack.Children.Add($img)
        $null = $stack.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $t.Title; FontSize = 15; FontWeight = 'SemiBold' }))
        $null = $stack.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $t.Desc; FontSize = 13; Foreground = '#6E6E6E'; Margin = '0,2,0,0' }))
        $btn = New-Object Windows.Controls.Button -Property @{ Template = $win.Resources['OptionCard']; Content = $stack; Tag = $key; Cursor = 'Hand' }
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

# 記住風格，讓 一鍵登出.cmd 也用同一種
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
