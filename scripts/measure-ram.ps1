# Boot an ISO in the laptop-style VM and record idle memory use: totals, RAM-backed live overlay, zram, and the
# proportional (PSS) memory of every program, summed by name. Results go to the serial port -> output\serial.log
# and are printed here. Needs a dev build (DEBUG_BOOT=1, serial console on).
# Usage: powershell -File scripts\measure-ram.ps1 [-Iso output\novac.iso] [-IdleSeconds 120]
param(
    [string]$Iso = (Join-Path $PSScriptRoot "..\output\novac.iso"),
    [int]$IdleSeconds = 120
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "vbox-type.ps1")
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$vm = "NovaC-test"
$serial = Join-Path (Split-Path (Resolve-Path $Iso).Path) "serial.log"
function Keys($codes) { & $vbm controlvm $vm keyboardputscancode @($codes -split ' ') | Out-Null }

$ErrorActionPreference = "Continue"   # VBoxManage progress goes to stderr
$null = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-vbox.ps1") -Iso $Iso 2>&1
$ErrorActionPreference = "Stop"
Start-Sleep 11; Keys "1c 9c"                      # boot the default entry
Start-Sleep $IdleSeconds                          # let the session settle (autostart, indexers, notifiers)
Keys "1d 38 14 94 b8 9d"; Start-Sleep 10          # Ctrl+Alt+T
VmType $vm "sudo -i" -Enter; Start-Sleep 3
VmType $vm "exec > /dev/ttyS0 2>&1; echo NOVAC-RAM-BEGIN; free -m; zramctl; df -m /run/live/overlay | tail -1" -Enter
VmType $vm "for p in /proc/[0-9]*; do echo `$(awk '/^Pss:/{print `$2}' `$p/smaps_rollup 2>/dev/null) `$(cat `$p/comm 2>/dev/null | tr ' ' _); done | awk 'NF==2{a[`$2]+=`$1;t+=`$1} END{for(k in a) printf ""%7.1f %s\n"", a[k]/1024, k; printf ""%7.1f TOTAL_PSS\n"", t/1024}' | sort -rn | head -45" -Enter
VmType $vm "systemctl list-units --type=service --state=running --no-legend --plain | cut -d' ' -f1 | tr '\n' ' '; echo; ls /etc/xdg/autostart | tr '\n' ' '; echo; echo NOVAC-RAM-END" -Enter
Start-Sleep 15

$log = Get-Content $serial -Raw
$m = [regex]::Match($log, "NOVAC-RAM-BEGIN(?s)(.*?)NOVAC-RAM-END")
if (-not $m.Success) { throw "no measurement found in $serial" }
$m.Groups[1].Value
