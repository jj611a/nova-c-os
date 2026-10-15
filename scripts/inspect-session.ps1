# Boot an ISO in the headless test VM and screenshot what runs in the desktop session: biggest processes,
# who started the background helpers, autostart files and user services. Used to find idle RAM to save.
# Usage: powershell -File scripts\inspect-session.ps1 [-Iso output\novac.iso] [-Label old] [-OutDir output]
param(
    [string]$Iso = (Join-Path $PSScriptRoot "..\output\novac.iso"),
    [string]$Label = "run",
    [string]$OutDir = (Join-Path $PSScriptRoot "..\output"),
    [string]$Name = "NovaC-inspect",
    [int]$MemMB = 2048,
    [int]$Cpus = 2
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "vbox-type.ps1")
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$OutDir = (Resolve-Path $OutDir).Path
function Keys($codes) { & $vbm controlvm $Name keyboardputscancode @($codes -split ' ') | Out-Null }
function Shot($n) { & $vbm controlvm $Name screenshotpng (Join-Path $OutDir "inspect-$Label-$n.png") 2>&1 | Out-Null; Write-Output "shot: inspect-$Label-$n.png" }

$ErrorActionPreference = "Continue"
$null = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-vbox.ps1") -Iso $Iso -Name $Name -MemMB $MemMB -Cpus $Cpus -Headless 2>&1
$ErrorActionPreference = "Stop"
Start-Sleep 8; Keys "1c 9c"
Start-Sleep 110
Keys "1d 38 14 94 b8 9d"; Start-Sleep 10
VmType $Name "clear; ps -eo ppid,rss,args --sort=-rss | head -22 | cut -c1-118" -Enter
Start-Sleep 6; Shot "ps"
VmType $Name "clear; ls /etc/xdg/autostart | cut -c1-60; systemctl --user list-units --type=service --no-legend | cut -c1-76" -Enter
Start-Sleep 6; Shot "autostart"
VmType $Name "clear; ps -o pid,ppid,args -C kaccess,DiscoverNotifier,ksmserver,xdg-desktop-portal | cut -c1-118; ps -o pid,comm -p `$(ps -o ppid= -C kaccess | tr -d ' ')" -Enter
Start-Sleep 5; Shot "parents"
$ErrorActionPreference = "Continue"
& $vbm controlvm $Name poweroff 2>&1 | Out-Null
