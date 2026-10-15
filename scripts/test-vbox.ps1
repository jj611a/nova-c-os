# Create (or recreate) a VirtualBox VM and boot the Nova-C OS ISO.
# Usage: powershell -File scripts\test-vbox.ps1 [-Iso output\novac.iso] [-Name NovaC-test] [-Accel3d] [-Touch] [-Headless]
# Default is a laptop-like VM (plain mouse + keyboard); -Touch presents a USB multi-touch screen instead.
# -Headless runs without a window (automated tests: nobody's mouse can interfere).
# Boot log goes to output\serial-<Name>.log (dev builds, DEBUG_BOOT=1).
param(
    [string]$Iso  = (Join-Path $PSScriptRoot "..\output\novac.iso"),
    [string]$Name = "NovaC-test",
    [int]$MemMB   = 2048,
    [int]$Cpus    = 2,
    [int]$SataPorts = 2,   # VirtualBox defaults to 30: the kernel then probes 28 empty links, about 15 s of boot time
    [switch]$Accel3d,  # test the GPU (GLES) path; default off exercises the software-renderer fallback
    [switch]$Touch,
    [switch]$Headless
)
$ErrorActionPreference = "Stop"
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$Iso = (Resolve-Path $Iso).Path
$serial = Join-Path (Split-Path $Iso) "serial-$Name.log"
$vmDir = "$env:USERPROFILE\VirtualBox VMs\$Name"

if (& $vbm list vms | Select-String "`"$Name`"") {
    # may already be powered off, which makes VBoxManage fail (fatal under -ErrorAction Stop)
    try { & $vbm controlvm $Name poweroff 2>&1 | Out-Null } catch { }
    Start-Sleep 3
    & $vbm unregistervm $Name --delete
}
Remove-Item $serial -ErrorAction SilentlyContinue

$accel = if ($Accel3d) { "on" } else { "off" }
$mouse = if ($Touch) { "usbmultitouch" } else { "usbtablet" }
& $vbm createvm --name $Name --ostype Debian_64 --register
& $vbm modifyvm $Name --memory $MemMB --cpus $Cpus --vram 128 --graphicscontroller vmsvga --accelerate-3d $accel `
    --firmware efi64 --usbxhci on --mouse $mouse --keyboard usb --audio-driver default `
    --nic1 nat --clipboard-mode bidirectional --uart1 0x3F8 4 --uart-mode1 file $serial
# firmware (and so GRUB's gfxmode=auto) starts at a laptop-sized 1280x800: the same for every ISO, so boot times compare
& $vbm setextradata $Name "VBoxInternal2/EfiGraphicsResolution" "1280x800"
& $vbm storagectl $Name --name SATA --add sata --controller IntelAhci --portcount $SataPorts
& $vbm createmedium disk --filename "$vmDir\disk.vdi" --size 16384
& $vbm storageattach $Name --storagectl SATA --port 0 --device 0 --type hdd --medium "$vmDir\disk.vdi"
& $vbm storageattach $Name --storagectl SATA --port 1 --device 0 --type dvddrive --medium $Iso
& $vbm startvm $Name --type $(if ($Headless) { "headless" } else { "gui" })
