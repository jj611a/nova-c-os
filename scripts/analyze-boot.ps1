# Boot an ISO in the headless test VM and screenshot what `systemd-analyze` says inside the guest: total boot time,
# the slowest units and the critical chain. Complements measure-boot.ps1 (which only sees the screen).
# Usage: powershell -File scripts\analyze-boot.ps1 [-Iso output\novac.iso] [-Label old] [-OutDir output]
param(
    [string]$Iso = (Join-Path $PSScriptRoot "..\output\novac.iso"),
    [string]$Label = "run",
    [string]$OutDir = (Join-Path $PSScriptRoot "..\output"),
    [string]$Name = "NovaC-analyze",
    [int]$MemMB = 2048,
    [int]$Cpus = 2,
    [string]$Append = ""     # extra kernel parameters for this run, e.g. "plymouth.enable=0"
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "vbox-type.ps1")
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$OutDir = (Resolve-Path $OutDir).Path
function Keys($codes) { & $vbm controlvm $Name keyboardputscancode @($codes -split ' ') | Out-Null }
function Shot($n) { & $vbm controlvm $Name screenshotpng (Join-Path $OutDir "analyze-$Label-$n.png") 2>&1 | Out-Null; Write-Output "shot: analyze-$Label-$n.png" }

$ErrorActionPreference = "Continue"
$null = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-vbox.ps1") -Iso $Iso -Name $Name -MemMB $MemMB -Cpus $Cpus -Headless 2>&1
$ErrorActionPreference = "Stop"
Start-Sleep 8
if ($Append) {
    Keys "12 92"; Start-Sleep 2                      # 'e': edit the first entry
    Keys "e0 50 e0 d0 e0 50 e0 d0 e0 4f e0 cf"       # down, down, End: the end of the linux line
    VmType $Name " $Append"
    Keys "44 c4"                                     # F10: boot
} else { Keys "1c 9c" }                              # boot the default menu entry
Start-Sleep 110                             # desktop + settle
Keys "1d 38 14 94 b8 9d"; Start-Sleep 10    # Ctrl+Alt+T: terminal
VmType $Name "clear; systemd-analyze; systemd-analyze blame --no-pager | head -14" -Enter
Start-Sleep 6; Shot "blame"
VmType $Name "clear; systemd-analyze critical-chain --no-pager | head -24" -Enter
Start-Sleep 5; Shot "chain"
VmType $Name "clear; free -m | head -2; systemctl list-units --type=service --state=running --no-legend | wc -l; ps -eo rss,comm --sort=-rss | head -12" -Enter
Start-Sleep 5; Shot "memory"
VmType $Name "clear; sudo journalctl -b -u live-config --no-pager -o short-monotonic | cut -c1-110 | tail -n 40" -Enter
Start-Sleep 5; Shot "liveconfig"
VmType $Name "clear; systemd-analyze blame --no-pager | sed -n 15,40p | paste - - | cut -c1-150" -Enter
Start-Sleep 5; Shot "blame2"
VmType $Name "clear; sudo dmesg | grep -E 'squashfs|loop0|overlay|Mounted|systemd[1]|Run /init|sr0|iso9660|ata[0-9]|Attached SCSI' | cut -c1-118 | tail -n 22" -Enter
Start-Sleep 6; Shot "dmesg"
$ErrorActionPreference = "Continue"
& $vbm controlvm $Name poweroff 2>&1 | Out-Null
