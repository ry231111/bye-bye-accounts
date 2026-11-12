# 一鍵登出：Claude 桌面版、Claude Code、VS Code（含 Codex 擴充功能）、LINE、Chrome / Edge 裡的所有網站
# 只會關閉這幾個程式，並刪除「登入用的 cookie / token」。不會刪書籤、歷史紀錄、密碼、LINE 聊天紀錄，也不會改系統設定。
#
# 用法：
#   一鍵登出.ps1                    正式執行（會先跳出確認視窗）
#   一鍵登出.ps1 -DryRun            演練：不關程式、不刪任何東西，只回報「會刪掉什麼」
#   一鍵登出.ps1 -TestRoot <資料夾>  測試：只對該資料夾裡的假資料動手，不關程式、不碰真正的登入資料
#   一鍵登出.ps1 -Theme 可愛        用可愛風（草莓牛奶版）的視窗（預設是經典色；「建立桌面捷徑」會記住你選的風格）
param([switch]$DryRun, [switch]$Yes, [string]$TestRoot, [int]$WatchPid, [string]$Theme)

Add-Type -AssemblyName System.Windows.Forms, PresentationFramework, PresentationCore, WindowsBase

# LINE 的主程式和它附帶的小程式（通話、播放器、更新程式等）
$LineProcs = 'LINE', 'LineLauncher', 'LineAppMgr', 'LineConnector', 'LineUpdater', 'LineCall', 'LineMediaPlayer'

$Local   = if ($TestRoot) { "$TestRoot\Local" }   else { $env:LOCALAPPDATA }
$Roaming = if ($TestRoot) { "$TestRoot\Roaming" } else { $env:APPDATA }
$HomeDir = if ($TestRoot) { "$TestRoot\Home" }    else { $env:USERPROFILE }
$WorkDir = if ($TestRoot) { $TestRoot }           else { $env:TEMP }

$Live   = -not $DryRun -and -not $TestRoot   # 會真的關閉程式
$Change = -not $DryRun                       # 會真的改檔案
$Done   = if ($Change) { '已登出' } else { '目前是登入狀態，正式執行時會登出' }

# 執行紀錄，出問題時可以看是哪一步失敗
$LogFile   = Join-Path $WorkDir '一鍵登出-紀錄.txt'
# 已完成的步驟。主程序中途被關掉時，備援程序靠這個檔案接手沒做完的部分
$StateFile = Join-Path $WorkDir '一鍵登出-狀態.txt'

function Log($m) {
    try { Add-Content -LiteralPath $LogFile -Value ('{0:MM/dd HH:mm:ss.fff} [{1}] {2}' -f (Get-Date), $PID, $m) -Encoding UTF8 } catch {}
}
trap { Log "錯誤：$_"; continue }

function Show-Box($text, $buttons = 'OK', $icon = 'Information') {
    [System.Windows.Forms.MessageBox]::Show($text, '一鍵登出', $buttons, $icon,
        'Button1', 'DefaultDesktopOnly')
}

# ---- 風格 ----
# 兩種視窗外觀：經典（Windows 11 風格）、可愛（草莓牛奶版）。
# 順序：參數 > 同資料夾的「主題.txt」（建立桌面捷徑時寫入）> 經典
$ThemeFile = Join-Path $PSScriptRoot '主題.txt'
if (-not $Theme) { try { $Theme = (Get-Content -LiteralPath $ThemeFile -Encoding UTF8 -ErrorAction Stop | Select-Object -First 1).Trim() } catch {} }
if ($Theme -notin '經典', '可愛') { $Theme = '經典' }

# ---- 經典：Windows 11 風格視窗 ----
# 只用系統內建字型
$DialogXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="一鍵登出" WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="NoResize" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen"
        Topmost="True" UseLayoutRounding="True" SnapsToDevicePixels="True"
        FontFamily="Segoe UI Variable Text, Microsoft JhengHei UI"
        TextOptions.TextFormattingMode="Ideal" TextOptions.TextRenderingMode="ClearType">
  <Window.Resources>
    <!-- 按鈕：Tag 是滑鼠移上去時的底色 -->
    <ControlTemplate x:Key="FlatButton" TargetType="Button">
      <Border x:Name="Face" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
              BorderThickness="1" CornerRadius="6" MinWidth="104" Height="34" Padding="18,0">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
      </Border>
      <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter TargetName="Face" Property="Background" Value="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}"/>
        </Trigger>
        <Trigger Property="IsPressed" Value="True"><Setter TargetName="Face" Property="Opacity" Value="0.8"/></Trigger>
        <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Face" Property="BorderBrush" Value="#1B1B1B"/></Trigger>
      </ControlTemplate.Triggers>
    </ControlTemplate>
  </Window.Resources>
  <!-- 外面留 24 給陰影 -->
  <Border Margin="24" Background="#FFFFFF" BorderBrush="#E5E5E5" BorderThickness="1" CornerRadius="8"
          Padding="28,24,28,24" TextElement.Foreground="#1B1B1B">
    <Border.Effect><DropShadowEffect BlurRadius="28" ShadowDepth="6" Direction="270" Opacity="0.14" Color="#000000"/></Border.Effect>
    <StackPanel Width="400">
      <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
        <Border Width="36" Height="36" CornerRadius="8" Background="#EAF2FB" Margin="0,0,12,0" VerticalAlignment="Center">
          <Path Fill="#0067C0" Width="18" Height="18" Stretch="Uniform"
                Data="M3,3 H11 V5 H5 V19 H11 V21 H3 Z M15,7 L20,12 L15,17 V13.5 H9 V10.5 H15 Z"/>
        </Border>
        <TextBlock x:Name="Head" FontSize="20" FontWeight="SemiBold" VerticalAlignment="Center"/>
      </StackPanel>
      <TextBlock x:Name="Intro" FontSize="14" LineHeight="22" TextWrapping="Wrap" Margin="0,0,0,8"/>
      <StackPanel x:Name="Items" Margin="2,0,0,8"/>
      <TextBlock x:Name="Note" FontSize="13" LineHeight="20" Foreground="#6E6E6E" TextWrapping="Wrap" Margin="0,8,0,0"/>
      <DockPanel Margin="0,24,0,0" LastChildFill="False">
        <TextBlock x:Name="HintText" DockPanel.Dock="Left" FontSize="13" Foreground="#6E6E6E" VerticalAlignment="Center"/>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
          <Button x:Name="No" Template="{StaticResource FlatButton}" Background="#FFFFFF" Tag="#F5F5F5" BorderBrush="#D6D6D6"
                  Foreground="#1B1B1B" FontSize="14" IsCancel="True" Margin="0,0,8,0"/>
          <Button x:Name="Yes" Template="{StaticResource FlatButton}" Background="#0067C0" Tag="#1975C5" BorderBrush="#0067C0"
                  Foreground="#FFFFFF" FontSize="14" FontWeight="SemiBold" IsDefault="True"/>
        </StackPanel>
      </DockPanel>
    </StackPanel>
  </Border>
</Window>
'@

# $hint 會放在按鈕左邊
function New-Dialog($head, $intro, [string[]]$items, $note, $okText, $cancelText, $hint) {
    $win = [Windows.Markup.XamlReader]::Parse($DialogXaml)
    try { $win.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([Uri](Join-Path $PSScriptRoot '素材\經典圖示.ico')) } catch {}   # 工作列和 Alt-Tab 用的圖示
    $win.FindName('Head').Text = $head
    foreach ($pair in @(@('Intro', $intro), @('Note', $note), @('HintText', $hint))) {
        $tb = $win.FindName($pair[0])
        if ($pair[1]) { $tb.Text = $pair[1] } else { $tb.Visibility = 'Collapsed' }
    }
    # 清單：每項前面一個藍色小圓點
    $list = $win.FindName('Items')
    foreach ($i in $items) {
        $row = New-Object Windows.Controls.DockPanel
        $row.Margin = '0,0,0,6'
        $dot = New-Object Windows.Shapes.Ellipse -Property @{ Width = 5; Height = 5; Fill = '#0067C0'; Margin = '0,8,10,0'; VerticalAlignment = 'Top' }
        $text = New-Object Windows.Controls.TextBlock -Property @{ Text = $i; FontSize = 14; LineHeight = 21; TextWrapping = 'Wrap' }
        $null = $row.Children.Add($dot); $null = $row.Children.Add($text)
        $null = $list.Children.Add($row)
    }
    $okBtn = $win.FindName('Yes'); $noBtn = $win.FindName('No')
    $okBtn.Content = $okText
    if ($cancelText) { $noBtn.Content = $cancelText } else { $noBtn.Visibility = 'Collapsed'; $okBtn.IsCancel = $true }
    $okBtn.add_Click({ $w = [Windows.Window]::GetWindow($this); $w.Tag = $true; $w.Close() })
    $noBtn.add_Click({ [Windows.Window]::GetWindow($this).Close() })
    $win.add_MouseLeftButtonDown({ $this.DragMove() })   # 沒有標題列，按住任何地方都能拖
    $win.add_Loaded({ $this.Activate() })
    return $win
}

# ---- 可愛：草莓牛奶版視窗 ----
# 字型用「素材」資料夾裡的粉圓體（不用安裝），找不到就用微軟正黑體
$FontDir = Join-Path $PSScriptRoot '素材'

$CuteXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="一鍵登出" WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="NoResize" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen"
        Topmost="True" UseLayoutRounding="True" SnapsToDevicePixels="True">
  <Window.Resources>
    <ControlTemplate x:Key="PixelButton" TargetType="Button">
      <Border x:Name="Face" Background="{TemplateBinding Background}" BorderBrush="#3B1E2B" BorderThickness="3">
        <Border x:Name="Shade" BorderBrush="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}"
                BorderThickness="0,0,3,3" Padding="18,5,15,4">
          <ContentPresenter HorizontalAlignment="Center"/>
        </Border>
      </Border>
      <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Face" Property="BorderBrush" Value="#FF5FA2"/></Trigger>
        <Trigger Property="IsPressed" Value="True"><Setter TargetName="Shade" Property="BorderThickness" Value="4,4,0,0"/></Trigger>
      </ControlTemplate.Triggers>
    </ControlTemplate>
  </Window.Resources>
  <!-- 草莓牛奶配色：外圈淡粉、內層奶油色、可可色框線，粉紅只留給按鈕和勾勾 -->
  <Border Background="#FFC8DD" BorderBrush="#3B1E2B" BorderThickness="4" Padding="8" TextElement.Foreground="#3B1E2B">
    <Border Background="#FFF7EE" BorderBrush="#3B1E2B" BorderThickness="3" Padding="22,18">
      <StackPanel Width="368">
        <TextBlock x:Name="Head" FontSize="24"/>
        <TextBlock x:Name="Intro" FontSize="13.5" Foreground="#8A5E70" TextWrapping="Wrap" Margin="0,4,0,0"/>
        <Border Background="White" BorderBrush="#F2C9D8" BorderThickness="2" Padding="12,8" Margin="0,16,0,0">
          <ScrollViewer x:Name="ItemsScroll" VerticalScrollBarVisibility="Auto">
            <StackPanel x:Name="Items"/>
          </ScrollViewer>
        </Border>
        <TextBlock x:Name="Note" FontSize="13.5" Foreground="#8A5E70" TextWrapping="Wrap" Margin="0,10,0,0"/>
        <DockPanel Margin="0,16,0,0" LastChildFill="False">
          <StackPanel x:Name="Hint" DockPanel.Dock="Left" Orientation="Horizontal" VerticalAlignment="Center">
            <Image x:Name="Clock" Width="18" Height="18" Margin="0,0,6,0" VerticalAlignment="Center" RenderOptions.EdgeMode="Aliased"/>
            <TextBlock x:Name="HintText" FontSize="14" Foreground="#8A5E70" VerticalAlignment="Center"/>
          </StackPanel>
          <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
            <Button x:Name="No" Template="{StaticResource PixelButton}" Background="#FFF7EE" Tag="#E6CBD5"
                    Foreground="#3B1E2B" FontSize="15" IsCancel="True" Margin="0,0,12,0"/>
            <Button x:Name="Yes" Template="{StaticResource PixelButton}" Background="#FF5FA2" Tag="#C7357A"
                    Foreground="White" FontSize="15" IsDefault="True"/>
          </StackPanel>
        </DockPanel>
      </StackPanel>
    </Border>
  </Border>
</Window>
'@

# 結果清單前面的像素勾勾和叉叉
$CheckRows = @('.......K', '......KK', 'K....KK.', 'KK..KK..', '.KKKK...', '..KK....')
$CrossRows = @('K....K', 'KK..KK', '.KKKK.', '.KKKK.', 'KK..KK', 'K....K')

# 按鈕左邊「大約需要5秒」前面的像素小時鐘
$ClockRows = @(
    '..KKKKK..',
    '.KLLLLLK.',
    'KLLLKLLLK',
    'KLLLKLLLK',
    'KLLLKKKLK',
    'KLLLLLLLK',
    'KLLLLLLLK',
    '.KLLLLLK.',
    '..KKKKK..'
)
$ClockColors = @{ K = '#3B1E2B'; L = '#FFC8DD' }

function New-PixelImage([string[]]$rows, $colors) {
    $group = New-Object Windows.Media.DrawingGroup
    foreach ($c in $colors.Keys) {
        $geo = New-Object Windows.Media.GeometryGroup
        for ($y = 0; $y -lt $rows.Count; $y++) {
            for ($x = 0; $x -lt $rows[$y].Length; $x++) {
                if ([string]$rows[$y][$x] -eq $c) { $geo.Children.Add([Windows.Media.RectangleGeometry]::new([Windows.Rect]::new($x, $y, 1, 1))) }
            }
        }
        $brush = [Windows.Media.BrushConverter]::new().ConvertFrom($colors[$c])
        $group.Children.Add([Windows.Media.GeometryDrawing]::new($brush, $null, $geo))
    }
    return [Windows.Media.DrawingImage]::new($group)
}

# $hint 會放在按鈕左邊，前面有小時鐘
function New-CuteWindow($head, $intro, [string[]]$items, $note, $okText, $cancelText, $hint) {
    $win = [Windows.Markup.XamlReader]::Parse($CuteXaml)
    try { $win.FontFamily = New-Object Windows.Media.FontFamily ([Uri]"$FontDir\"), './#Huninn, Microsoft JhengHei UI' }
    catch { $win.FontFamily = 'Microsoft JhengHei UI' }
    # 工作列上的圖示，和捷徑同一顆莓果奶油磚（視窗裡不畫圖示，標題就是純文字）
    try { $win.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([Uri](Join-Path $FontDir '莓果.ico')) } catch {}
    if ($hint) {
        $win.FindName('Clock').Source = New-PixelImage $ClockRows $ClockColors
        $win.FindName('HintText').Text = $hint
    } else { $win.FindName('Hint').Visibility = 'Collapsed' }
    $win.FindName('Head').Text = $head
    foreach ($pair in @(@('Intro', $intro), @('Note', $note))) {
        $tb = $win.FindName($pair[0])
        if ($pair[1]) { $tb.Text = $pair[1] } else { $tb.Visibility = 'Collapsed' }
    }
    # 清單：失敗的打紅叉，登出了的打粉勾（只留名稱），其他（確認視窗的項目、演練模式）用粉色小方塊
    $list = $win.FindName('Items')
    # 失敗的項目會帶錯誤訊息，太多時清單改成可以捲，視窗才不會超出螢幕（上下其他部分約佔 260）
    $win.FindName('ItemsScroll').MaxHeight = [Math]::Max(150, [Math]::Min(320, [Windows.SystemParameters]::WorkArea.Height - 260))
    foreach ($i in $items) {
        $row = New-Object Windows.Controls.DockPanel
        $row.Margin = '0,4,0,4'
        $mark = New-Object Windows.Controls.Image -Property @{ Width = 16; Height = 14; Margin = '0,3,10,0'; VerticalAlignment = 'Top' }
        [Windows.Media.RenderOptions]::SetEdgeMode($mark, 'Aliased')
        $text = New-Object Windows.Controls.TextBlock -Property @{ Text = $i; FontSize = 14.5; TextWrapping = 'Wrap' }
        if ($i -match '：失敗') {
            $mark.Source = New-PixelImage $CrossRows @{ K = '#D94A4A' }
            $text.Foreground = '#B23A3A'
        } elseif ($i -match '^(.+)：已登出') {
            $mark.Source = New-PixelImage $CheckRows @{ K = '#FF5FA2' }
            $text.Text = $Matches[1]
        } elseif ($i -match '：本來就沒登入') {
            $mark.Source = New-PixelImage $CheckRows @{ K = '#FF5FA2' }
        } else {
            $mark = New-Object Windows.Shapes.Rectangle -Property @{ Width = 7; Height = 7; Fill = '#FF5FA2'; Margin = '2,7,17,0'; VerticalAlignment = 'Top' }
        }
        $null = $row.Children.Add($mark); $null = $row.Children.Add($text)
        $null = $list.Children.Add($row)
    }
    $okBtn = $win.FindName('Yes'); $noBtn = $win.FindName('No')
    $okBtn.Content = $okText
    if ($cancelText) { $noBtn.Content = $cancelText } else { $noBtn.Visibility = 'Collapsed'; $okBtn.IsCancel = $true }
    $okBtn.add_Click({ $w = [Windows.Window]::GetWindow($this); $w.Tag = $true; $w.Close() })
    $noBtn.add_Click({ [Windows.Window]::GetWindow($this).Close() })
    $win.add_MouseLeftButtonDown({ $this.DragMove() })   # 沒有標題列，按住任何地方都能拖
    $win.add_Loaded({ $this.Activate() })
    return $win
}

# 按下 okText 回傳 $true。依風格選視窗；視窗出錯時改用一般的 Windows 視窗，確保一定看得到
function Show-Dialog($head, $intro, [string[]]$items, $note, $okText = '好', $cancelText, $hint) {
    try {
        $win = if ($Theme -eq '可愛') { New-CuteWindow $head $intro $items $note $okText $cancelText $hint }
               else { New-Dialog $head $intro $items $note $okText $cancelText $hint }
        $null = $win.ShowDialog()
        return [bool]$win.Tag
    } catch {
        Log "視窗失敗（$Theme），改用一般視窗：$($_.Exception.Message)"
        $text = (@($head, $intro) + @($items | ForEach-Object { "• $_" }) + @($note, $hint) | Where-Object { $_ }) -join "`n"
        $buttons = if ($cancelText) { 'YesNo' } else { 'OK' }
        return (Show-Box $text $buttons) -in 'Yes', 'OK'
    }
}

# 用 Windows 內建的 winsqlite3.dll 操作 Chrome / Edge 的 cookie 資料庫，不需安裝任何東西
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WinSqlite {
    [DllImport("winsqlite3.dll", CharSet = CharSet.Unicode)] static extern int sqlite3_open16(string file, out IntPtr db);
    [DllImport("winsqlite3.dll")] static extern int sqlite3_close(IntPtr db);
    [DllImport("winsqlite3.dll")] static extern int sqlite3_busy_timeout(IntPtr db, int ms);
    [DllImport("winsqlite3.dll")] static extern int sqlite3_exec(IntPtr db, byte[] sql, IntPtr cb, IntPtr arg, out IntPtr err);
    [DllImport("winsqlite3.dll")] static extern int sqlite3_changes(IntPtr db);
    [DllImport("winsqlite3.dll")] static extern IntPtr sqlite3_errmsg16(IntPtr db);

    // 執行一句 SQL，回傳受影響的列數
    public static int Exec(string file, string sql) {
        IntPtr db;
        if (sqlite3_open16(file, out db) != 0) {
            string m = Marshal.PtrToStringUni(sqlite3_errmsg16(db));
            sqlite3_close(db);
            throw new Exception(m);
        }
        try {
            sqlite3_busy_timeout(db, 1000);
            IntPtr err;
            if (sqlite3_exec(db, System.Text.Encoding.UTF8.GetBytes(sql + "\0"), IntPtr.Zero, IntPtr.Zero, out err) != 0)
                throw new Exception(Marshal.PtrToStringUni(sqlite3_errmsg16(db)));
            return sqlite3_changes(db);
        } finally {
            sqlite3_close(db);
        }
    }
}
'@

$Results = [ordered]@{}
$State = @{}

# ---- 關閉程式 ----
# 先請程式自己關（視窗收到關閉訊息），等不到就強制結束
function Request-Close([string[]]$names) {
    if (-not $Live) { return }
    foreach ($n in $names) { & cmd.exe /c "taskkill /IM $n.exe >nul 2>&1" }
}
function Stop-Now([string[]]$names, [int]$waitMs = 0) {
    if (-not $Live) { return }
    $deadline = (Get-Date).AddMilliseconds($waitMs)
    while ((Get-Process -Name $names -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 100
    }
    for ($i = 0; $i -lt 30; $i++) {
        $left = Get-Process -Name $names -ErrorAction SilentlyContinue
        if (-not $left) { return }
        $left | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 100
    }
    Log "關不掉：$((Get-Process -Name $names -ErrorAction SilentlyContinue).Name -join ', ')"
}

# 做一件事，失敗就再關一次程式後重試。
# 昨天的紀錄顯示 Claude 被關掉 1 秒內就會重新啟動並鎖住檔案，所以要緊接著做、短間隔重試
function Invoke-WithRetry([string[]]$procs, [scriptblock]$body) {
    $max = if ($Live) { 20 } else { 1 }
    for ($try = 1; ; $try++) {
        try { return (& $body) }
        catch {
            if ($try -ge $max) { throw }
            Log "第 $try 次失敗，重試：$($_.Exception.Message)"
            Stop-Now $procs
            Start-Sleep -Milliseconds 100
        }
    }
}

# 執行一個步驟並記下結果。上一個程序已經做完的步驟會跳過
function Step($key, [scriptblock]$body) {
    $label = $StepNames[$key]
    if ($State.ContainsKey($key)) { $Results[$key] = $State[$key]; return }
    try { $msg = "${label}：$(& $body)"; $ok = $true }
    catch {
        $ok = $false
        $msg = if ($Change) { "${label}：失敗（$($_.Exception.Message)）" }
               else { "${label}：程式開著、檔案被鎖住，演練模式看不到" }
    }
    Log $msg
    $Results[$key] = $msg
    if ($ok -and $Change) { Add-Content -LiteralPath $StateFile -Value "$key`t$msg" -Encoding UTF8 }
}

# ---- 各項登出動作（都可以重複執行）----
function Remove-LoginFile($path) {
    if (-not (Test-Path -LiteralPath $path)) { return '本來就沒登入' }
    if ($Change) { Remove-Item -LiteralPath $path -Force -ErrorAction Stop }
    return $Done
}

# 演練模式下，SQL 只在複製出來的檔案上執行，原檔完全不動
function Invoke-Sql($file, $sql) {
    if ($Change) { return [WinSqlite]::Exec($file, $sql) }
    $copy = Join-Path $env:TEMP ("logout-dryrun-" + [guid]::NewGuid().ToString() + '.db')
    try { Copy-Item -LiteralPath $file -Destination $copy -ErrorAction Stop; return [WinSqlite]::Exec($copy, $sql) }
    finally { Remove-Item -LiteralPath $copy -Force -ErrorAction SilentlyContinue }
}

function Clear-Browser($root, [string[]]$procs) {
    if (-not (Test-Path -LiteralPath $root)) { return '沒有安裝' }
    $profiles = @(Get-ChildItem -LiteralPath $root -Directory)
    $cookies = 0; $tokens = 0
    foreach ($p in $profiles) {
        $f = Join-Path $p.FullName 'Network\Cookies'
        if (Test-Path -LiteralPath $f) {
            # 所有網站的 cookie 都刪掉（Google、GitHub、ChatGPT……全部登出）
            $cookies += Invoke-WithRetry $procs { Invoke-Sql $f 'DELETE FROM cookies' }
        }
        # 瀏覽器本身登入的 Google 帳號（同步用的帳號 token）
        $w = Join-Path $p.FullName 'Web Data'
        if (Test-Path -LiteralPath $w) {
            $tokens += Invoke-WithRetry $procs { Invoke-Sql $w 'DELETE FROM token_service' }
        }
    }
    return "刪除 $cookies 個 cookie（所有網站）、$tokens 個瀏覽器帳號 token"
}

# LINE 沒開「自動登入」時，關掉就等於登出。
# qci_*.bin 是隱藏檔，第一次登入時建立、每次登入都會更新，存的是登入資料；一併刪掉，下次一定要重新登入。
# 聊天紀錄（db 資料夾）不動
function Clear-Line {
    $files = @(Get-ChildItem -LiteralPath "$Local\LINE\Data" -Filter 'qci_*.bin' -Force -File -ErrorAction SilentlyContinue)
    if (-not $files) { return '本來就沒登入' }
    if ($Change) { $files | Remove-Item -Force -ErrorAction Stop }
    return $Done
}

# VS Code 自己登入的帳號（GitHub、微軟……）和擴充功能存的密碼，都放在 state.vscdb 裡 secret:// 開頭的資料。
# VS Code 關閉時會把記憶體裡的資料寫回去，所以一定要等它關掉再刪。備份檔也一起清，免得被還原回來
# 新版 VS Code 把 GitHub 登入（github.auth）改存在跨 App 共用的 ~\.vscode-shared\sharedStorage\state.vscdb，兩個地方都要清。
# publicClients-* 是微軟登入元件的設定，VS Code 每次開都會寫，沒登入也有，所以不算帳號（只算帳號的話，演練才不會一直說「是登入狀態」）
function Clear-VSCode {
    $dbs = @("$Roaming\Code\User\globalStorage\state.vscdb", "$HomeDir\.vscode-shared\sharedStorage\state.vscdb") |
           Where-Object { Test-Path -LiteralPath $_ }
    if (-not $dbs) { return '沒有安裝' }
    $sql = "DELETE FROM ItemTable WHERE key LIKE 'secret://%'"
    $n = 0
    foreach ($db in $dbs) {
        $n += Invoke-Sql $db "$sql AND key NOT LIKE '%publicClients-%'"
        $null = Invoke-Sql $db $sql
        if (Test-Path -LiteralPath "$db.backup") { $null = Invoke-Sql "$db.backup" $sql }
    }
    $git = Clear-GitCredential
    if (-not $n -and -not $git) { return '本來就沒登入' }
    $parts = @(if ($n) { "$n 個帳號資料" }) + @(if ($git) { "$git 個 Git 的 GitHub 帳號" })
    return "$Done（$($parts -join '、')）"
}

# VS Code 裡 push / pull 用的 GitHub 帳號，是 Git 存在 Windows 認證管理員裡（git:https://github.com），不在 VS Code 的資料裡。
# 不刪的話，就算 VS Code 帳號登出了，原始檔控制還是用上一個人的帳號。cmdkey 的輸出在中文 Windows 也是 target=...
function Clear-GitCredential {
    if ($TestRoot) { return 0 }   # 測試模式不碰真正的認證管理員
    $targets = @(cmdkey /list | ForEach-Object { if ($_ -match 'target=(git:https?://\S*github\.com\S*)') { $Matches[1] } })
    if ($Change) { foreach ($t in $targets) { $null = cmdkey "/delete:$t" } }
    return $targets.Count
}

$ClaudeTokenKeys ='oauth:tokenCache', 'oauth:tokenCacheV2', 'lastKnownAccountUuid'
function Clear-ClaudeDesktop {
    $roots = @(Get-ChildItem -LiteralPath "$Local\Claude-Data" -Directory -ErrorAction SilentlyContinue) +
             @(Get-Item -LiteralPath "$Roaming\Claude" -ErrorAction SilentlyContinue) | Where-Object { $_ }
    $files = 0; $keys = 0
    foreach ($r in $roots) {
        # cookie 整個檔案刪掉，Claude 下次啟動會自己重建
        # 只看固定的幾個位置，不整個資料夾搜尋，才搶得贏 Claude 重新啟動
        $dirs = @("$($r.FullName)\Network") +
                @(Get-ChildItem -LiteralPath "$($r.FullName)\Partitions" -Directory -ErrorAction SilentlyContinue | ForEach-Object { "$($_.FullName)\Network" })
        $found = $dirs | ForEach-Object { "$_\Cookies", "$_\Cookies-journal" } |
                 Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object { Get-Item -LiteralPath $_ -Force }
        foreach ($f in $found) {
            if ($Change) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop }
            if ($f.Name -eq 'Cookies') { $files++ }
        }
        $cfgPath = Join-Path $r.FullName 'config.json'
        if (-not (Test-Path -LiteralPath $cfgPath)) { continue }
        $cfg = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $hit = @($ClaudeTokenKeys | Where-Object { $cfg.PSObject.Properties[$_] })
        if (-not $hit) { continue }
        $keys += $hit.Count
        if ($Change) {
            foreach ($k in $hit) { $cfg.PSObject.Properties.Remove($k) }
            $json = $cfg | ConvertTo-Json -Depth 100
            $null = $json | ConvertFrom-Json   # 確認寫回去的內容是合法 JSON 才存檔
            [IO.File]::WriteAllText($cfgPath, $json, (New-Object Text.UTF8Encoding $false))
        }
    }
    if (-not $files -and -not $keys) { return '本來就沒登入' }
    return "$Done（$files 個 cookie 檔、$keys 個帳號 token）"
}

# ---- 備援程序：等主程序結束，沒做完就接手 ----
$Resumed = $false
if ($WatchPid) {
    $main = Get-Process -Id $WatchPid -ErrorAction SilentlyContinue
    if ($main) {
        $null = $main.Handle   # 先握住，結束後才讀得到結束代碼
        if (-not $main.WaitForExit(120000)) { exit }
        Log "主程序 $WatchPid 已結束，結束代碼 $($main.ExitCode)"
    }
    $lines = @(Get-Content -LiteralPath $StateFile -Encoding UTF8 -ErrorAction SilentlyContinue)
    if ($lines -contains 'DONE') { exit }
    Log '主程序沒做完，由備援程序接手'
    foreach ($l in $lines) { $k, $v = $l -split "`t", 2; if ($v) { $State[$k] = $v } }
    $Resumed = $true
}

# ---- 0. 確認 ----
if ($Live -and -not $Yes -and -not $Resumed) {
    # 兩種風格共用同一套文字，只有外觀不同
    $what = 'Claude 桌面版 / Claude Code', 'VS Code（含擴充功能）', 'LINE', 'Chrome、Edge 裡的所有網站'
    $ok = Show-Dialog '要登出了嗎？' '會關閉 Chrome、Edge、Claude、VS Code、LINE，並登出：' $what '' '登出' '先不要' '大約需要 5 秒'
    if (-not $ok) { exit }
}

# 所有步驟，依執行順序。結果視窗也照這個順序列
$StepNames = [ordered]@{
    codex = 'Codex（VS Code）'; claudecode = 'Claude Code'; claude = 'Claude 桌面版'; line = 'LINE'
    vscode = 'VS Code 帳號'; chrome = 'Chrome'; edge = 'Edge'
}
$BackupPid = $null

Log "==== 開始（演練=$DryRun 測試=$([bool]$TestRoot) 接手=$Resumed）===="

try {
    if (-not $Resumed -and $Change) { Set-Content -LiteralPath $StateFile -Value $null -Encoding UTF8 }

    # 啟動備援程序。它由 Windows 的 WMI 服務啟動，不屬於 Claude 或 VS Code，關掉它們時不會被連帶關掉
    if ($Live -and -not $Resumed) {
        $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -WatchPid $PID -Theme $Theme"
        $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmd }
        Log "備援程序：代碼 $($r.ReturnValue)，PID $($r.ProcessId)"
        if ($r.ReturnValue -eq 0) { $BackupPid = $r.ProcessId }
    }

    $codexFile  = "$HomeDir\.codex\auth.json"
    $claudeFile = "$HomeDir\.claude\.credentials.json"

    # ---- 1. 最快的先做：刪登入檔，並請瀏覽器和 VS Code 開始關閉 ----
    Step 'codex'      { Remove-LoginFile $codexFile }
    Step 'claudecode' { Remove-LoginFile $claudeFile }
    Request-Close 'Code', 'chrome', 'msedge'

    # ---- 2. Claude 桌面版：直接強制結束，緊接著清除（它正常關閉要 7 秒，而且會自己重開）----
    Step 'claude' {
        Stop-Now 'claude'
        Invoke-WithRetry 'claude' { Clear-ClaudeDesktop }
    }

    # ---- 3. LINE：關閉時只會縮到右下角，所以直接強制結束 ----
    Step 'line' {
        Stop-Now $LineProcs
        Invoke-WithRetry $LineProcs { Clear-Line }
    }

    # ---- 4. VS Code：關掉後再刪一次登入檔，避免它在關閉前把 token 寫回去；再登出 VS Code 本身的帳號 ----
    Stop-Now 'Code', 'codex' 2000
    foreach ($f in $codexFile, $claudeFile) {
        if ($Change -and (Test-Path -LiteralPath $f)) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue; Log "再次刪除 $f" }
    }
    Step 'vscode' { Invoke-WithRetry 'Code' { Clear-VSCode } }

    # ---- 5. Chrome / Edge：刪掉所有網站的 cookie ----
    Step 'chrome' { Stop-Now 'chrome' 1500; Clear-Browser "$Local\Google\Chrome\User Data" 'chrome' }
    Step 'edge'   { Stop-Now 'msedge' 1500; Clear-Browser "$Local\Microsoft\Edge\User Data" 'msedge' }

    if ($Change) { Add-Content -LiteralPath $StateFile -Value 'DONE' -Encoding UTF8 }
}
finally {
    # ---- 6. 結果：不管中途發生什麼事都要顯示 ----
    # 中途停掉、還有步驟沒做：先不跳結果，直接結束讓備援程序接手重做
    $missing = @($StepNames.Keys | Where-Object { -not $Results.Contains($_) })
    if ($missing -and $BackupPid -and (Get-Process -Id $BackupPid -ErrorAction SilentlyContinue)) {
        Log "還有 $($missing.Count) 個步驟沒做，交給備援程序重做"
        exit 1
    }
    # 重做之後還是沒做到的，就當作失敗
    foreach ($k in $missing) { $Results[$k] = "$($StepNames[$k])：失敗（沒做完）" }
    $failed = @($Results.Values | Where-Object { $_ -match '失敗' })
    $head, $sub = if ($DryRun) { '演練模式', '沒有真的刪除任何東西' }
                  elseif ($TestRoot) { '測試模式', '只動了測試資料夾' }
                  elseif ($failed) { '需要手動登出QQ', '' }
                  else { '登出完成！', '' }
    $title = "$head$sub"
    $text = $title + "`n`n" + ($Results.Values -join "`n")
    Log "==== 結束：$title ===="
    Write-Output $text
    if (-not $Yes -and -not $TestRoot) {
        # 有失敗時只列要自己登出的那幾項，其他成功的不列
        $shown = if ($failed -and -not $DryRun) { $failed } else { @($Results.Values) }
        Show-Dialog $head '' $shown $sub '好' | Out-Null
    }
}
