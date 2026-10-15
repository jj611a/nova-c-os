# Install the ISO onto a blank virtual disk with the Calamares installer (keyboard only: VirtualBox cannot click),
# then boot the installed system and check it. Screenshots go to -OutDir (default output\install-test).
# Runs in its own headless VM (NovaC-inst). Stages, so a failed step can be repeated without starting over:
#   -Stage 1  create the VM, boot the live ISO, start the installer and walk it to the Users page
#   -Stage 2  fill the Users page, install, wait until it says it is done
#   -Stage 3  detach the ISO, boot the installed system, log in, run the system checks
# Usage: powershell -File scripts\run-install-test.ps1 -Stage 1 [-Iso output\novac.iso]
param(
    [int]$Stage = 1,
    [string]$Iso = (Join-Path $PSScriptRoot "..\output\novac.iso"),
    [string]$OutDir = (Join-Path $PSScriptRoot "..\output\install-test"),
    [string]$Name = "NovaC-inst",
    [string]$Password = "NovaC-Test-2026!",
    [int]$MemMB = 3072,
    [int]$SataPorts = 30      # 2 ports make the guest hang when Calamares scans the disks (VirtualBox AHCI quirk)
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "vbox-type.ps1")
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
function Wait([int]$s) { while ($s -gt 0) { $n = [Math]::Min(30, $s); Start-Sleep -Seconds $n; $s -= $n } }
function Shot($n) { & $vbm controlvm $Name screenshotpng (Join-Path $OutDir "$n.png") 2>&1 | Out-Null; Write-Output "shot: $n" }
function Keys($codes) { & $vbm controlvm $Name keyboardputscancode @($codes -split ' ') | Out-Null }
$META = "e0 5b"; $METAUP = "e0 db"
$ALT_N = "38 31 b1 b8"        # Alt+N: "Next" in Calamares
$TAB = "0f 8f"; $ENTER = "1c 9c"

if ($Stage -eq 1) {
    $ErrorActionPreference = "Continue"
    $null = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-vbox.ps1") -Iso $Iso -Name $Name -MemMB $MemMB -SataPorts $SataPorts -Headless 2>&1
    $ErrorActionPreference = "Stop"
    Wait 6; Keys $ENTER                              # boot the live system
    Wait 100; Shot "01-live-desktop"
    Keys "$META $METAUP"; Wait 5
    VmType $Name "install nova"; Wait 4; Shot "02-menu-search"
    Keys $ENTER; Wait 30; Shot "03-installer-welcome"
    Keys $ALT_N; Wait 6; Shot "04-installer-location"
    Keys $ALT_N; Wait 4; Shot "05-installer-keyboard"
    Keys $ALT_N; Wait 10; Shot "06-installer-partitions"
    Keys $ALT_N; Wait 5; Shot "07-installer-users"
}

if ($Stage -eq 2) {
    # focus starts in the "name" field; Tab goes name -> username -> hostname -> password -> repeat password
    VmType $Name "Test User"
    Keys $TAB; VmType $Name "tester"
    Keys $TAB; VmType $Name "novac-test"
    Keys $TAB; VmType $Name $Password
    Keys $TAB; VmType $Name $Password
    Wait 2; Shot "08-installer-users-filled"
    Keys $ALT_N; Wait 6; Shot "09-installer-summary"
    Keys "38 17 97 b8"; Wait 5; Shot "10-installer-confirm"    # Alt+I: Install
    Keys $ENTER; Wait 20; Shot "11-installer-installing"
    $deadline = (Get-Date).AddMinutes(30)
    while ((Get-Date) -lt $deadline) {
        Wait 60; Shot "11-installer-progress"
    }
}

if ($Stage -eq 3) {
    & $vbm controlvm $Name poweroff 2>&1 | Out-Null; Start-Sleep 5
    & $vbm storageattach $Name --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive 2>&1 | Out-Null
    & $vbm startvm $Name --type headless 2>&1 | Out-Null
    Wait 12; Shot "20-installed-boot-menu"
    Wait 70; Shot "21-installed-login"
    Keys "2a aa"; Wait 3
    VmType $Name $Password -Enter
    Wait 60; Shot "22-installed-desktop"
    Keys "1d 38 14 94 b8 9d"; Wait 10
    VmType $Name "clear; fastfetch; free -m | head -2; systemctl --failed --no-legend | wc -l; ls /usr/share/grub/themes/novac | head -3; which calamares; du -sm / --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run 2>/dev/null | tail -1" -Enter
    Wait 15; Shot "23-installed-checks"
}
