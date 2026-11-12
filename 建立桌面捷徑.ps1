# 在桌面建立「一鍵登出」捷徑：用隱藏的 PowerShell 視窗執行同資料夾的 一鍵登出.ps1
Add-Type -AssemblyName System.Windows.Forms
$script  = Join-Path $PSScriptRoot '一鍵登出.ps1'
$icon    = Join-Path $PSScriptRoot '圖示\一鍵登出.ico'
$desktop = [Environment]::GetFolderPath('Desktop')
$link    = Join-Path $desktop '一鍵登出.lnk'

$s = (New-Object -ComObject WScript.Shell).CreateShortcut($link)
$s.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$s.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$s.WorkingDirectory = $PSScriptRoot
if (Test-Path -LiteralPath $icon) { $s.IconLocation = "$icon,0" }
$s.Description = '登出 Claude、Codex、LINE 和瀏覽器裡的所有網站'
$s.Save()

[System.Windows.Forms.MessageBox]::Show("已在桌面建立捷徑：`n$link", '一鍵登出', 'OK', 'Information') | Out-Null
