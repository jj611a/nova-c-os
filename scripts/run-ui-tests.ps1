# Scripted UI smoke test of output\novac.iso in a laptop-style VirtualBox VM (mouse + keyboard, no touch).
# Drives the desktop with keyboard shortcuts (VirtualBox cannot inject mouse clicks) and saves a screenshot per step.
# Runs in its own headless VM (default NovaC-auto), so a person using the NovaC-test window cannot interfere.
# Usage: powershell -File scripts\run-ui-tests.ps1 [-OutDir docs\screenshots] [-Name NovaC-auto]
param(
    [string]$OutDir = (Join-Path $PSScriptRoot "..\docs\screenshots"),
    [string]$Name = "NovaC-auto",
    [switch]$LoginOnly   # skip the desktop run and only redo the login-screen part (the VM must already exist)
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "vbox-type.ps1")
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$vm  = $Name
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path

function Wait([int]$s) { while ($s -gt 0) { $n = [Math]::Min(30, $s); Start-Sleep -Seconds $n; $s -= $n } }
function Shot($name) { & $vbm controlvm $vm screenshotpng (Join-Path $OutDir "$name.png") 2>&1 | Out-Null; Write-Output "shot: $name" }
function Keys($codes) { & $vbm controlvm $vm keyboardputscancode @($codes -split ' ') | Out-Null }
$META = "e0 5b"; $METAUP = "e0 db"

# ---- run 1: boot menu -> autologin desktop ----
if (-not $LoginOnly) {
# VBoxManage prints progress ("0%...10%...") on stderr, which would be fatal under -ErrorAction Stop
$ErrorActionPreference = "Continue"
$null = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-vbox.ps1") -Name $vm -Headless 2>&1
$ErrorActionPreference = "Stop"
if (-not (& $vbm list runningvms | Select-String "`"$vm`"")) { throw "VM $vm did not start" }
Wait 6;  Shot "01-boot-menu"        # the menu boots by itself after 5 s: press keys within ~3 s of it showing
Keys "1c 9c";  Wait 100;  Shot "02-desktop"

Keys "$META $METAUP";  Wait 6;  Shot "03-launcher-menu"
Keys "01 81";  Wait 2
Keys "1d 38 14 94 b8 9d";  Wait 10          # Ctrl+Alt+T
VmType $vm "clear; fastfetch; free -m; echo failed-units: `$(systemctl --failed --no-legend | wc -l); head -1 /etc/issue" -Enter
Wait 6;  Shot "04-terminal-fastfetch"

Keys "$META e0 4b e0 cb $METAUP";  Wait 3   # Meta+Left: tile terminal left
Keys "$META 02 82 $METAUP";  Wait 14         # Meta+1: Dolphin from the dock
Keys "$META e0 4d e0 cd $METAUP";  Wait 4   # Meta+Right: tile Dolphin right
Shot "05-tiled-windows"

Keys "38 0f 8f";  Wait 4;  Shot "06-alt-tab";  Keys "b8";  Wait 2
Keys "$META 07 87 $METAUP";  Wait 14;  Shot "07-system-settings"   # Meta+6: System Settings
Keys "$META 03 83 $METAUP";  Wait 35;  Shot "28-firefox-first-run"   # Meta+2: Firefox (no welcome tour, compact UI)
}

# ---- run 2: login screen (autologin off) -> password login ----
& $vbm controlvm $vm reset | Out-Null
Wait 6
Keys "12 92";  Wait 2                              # 'e' edit the boot entry
Keys "e0 50 e0 d0 e0 50 e0 d0 e0 4f e0 cf"         # down, down, End
VmType $vm " noautologin"
Keys "44 c4"                                       # F10 boot
Wait 100
Keys "2a aa";  Wait 3;  Shot "08-login-screen"      # tap Shift: SDDM shows the login form on first input
VmType $vm "live" -Enter
Wait 40;  Shot "09-after-password-login"
Write-Output "done"
