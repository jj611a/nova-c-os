# Measure how long an ISO takes to boot to a finished desktop in the laptop-style VM (works on release ISOs: no
# serial log needed). It watches VirtualBox screenshots:
#   grub    = first frame with a boot menu on screen            (the script then presses Enter after 1 s)
#   change  = first frame that differs from the menu            (kernel / boot splash took over)
#   desktop = first frame that looks like the settled desktop   (compared with the last frame of the run)
# Compare the "Enter -> desktop" number between ISOs: it is the part Nova-C controls (firmware time is the VM's).
# Usage: powershell -File scripts\measure-boot.ps1 [-Iso output\novac.iso] [-Label old] [-Seconds 150] [-Cpus 2] [-MemMB 2048]
# Results are appended to output\boot-times.csv.
param(
    [string]$Iso = (Join-Path $PSScriptRoot "..\output\novac.iso"),
    [string]$Label = "run",
    [int]$Seconds = 150,
    [int]$MemMB = 2048,
    [int]$Cpus = 2,
    [string]$Name = "NovaC-boot"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$Iso = (Resolve-Path $Iso).Path
$out = Join-Path (Split-Path $Iso) "boot-times.csv"
$dir = Join-Path $env:TEMP "novac-boot-$Name"
Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $dir | Out-Null

$ErrorActionPreference = "Continue"   # VBoxManage progress goes to stderr
$null = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-vbox.ps1") -Iso $Iso -Name $Name -MemMB $MemMB -Cpus $Cpus -Headless 2>&1
$sw = [Diagnostics.Stopwatch]::StartNew()

# ---- capture ----
$frames = New-Object System.Collections.Generic.List[object]
$enterAt = $null; $grubAt = $null
while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
    $t = $sw.Elapsed.TotalSeconds
    $f = Join-Path $dir ("{0:000000}.png" -f [int]($t * 1000))
    & $vbm controlvm $Name screenshotpng $f 2>&1 | Out-Null
    if (Test-Path $f) {
        $frames.Add([pscustomobject]@{ T = $t; File = $f; Size = (Get-Item $f).Length })
        if ($null -eq $grubAt -and $frames[$frames.Count - 1].Size -gt 12000) { $grubAt = $t }
        if ($null -ne $grubAt -and $null -eq $enterAt -and ($t - $grubAt) -ge 1.0) {
            & $vbm controlvm $Name keyboardputscancode 1c 9c | Out-Null; $enterAt = $sw.Elapsed.TotalSeconds
        }
    }
}
& $vbm controlvm $Name poweroff 2>&1 | Out-Null
$ErrorActionPreference = "Stop"
if ($null -eq $grubAt) { throw "no boot menu seen" }

# ---- analyse: 48x30 grey thumbnails, mean absolute difference, ignoring the top rows (clock) ----
function Thumb($path) {
    $bmp = [Drawing.Bitmap]::FromFile($path)
    $small = New-Object Drawing.Bitmap 48, 30
    $g = [Drawing.Graphics]::FromImage($small); $g.InterpolationMode = 'HighQualityBilinear'
    $g.DrawImage($bmp, 0, 0, 48, 30); $g.Dispose(); $bmp.Dispose()
    $v = New-Object 'int[]' (48 * 30)
    for ($y = 0; $y -lt 30; $y++) { for ($x = 0; $x -lt 48; $x++) {
        $c = $small.GetPixel($x, $y); $v[$y * 48 + $x] = [int](0.3 * $c.R + 0.59 * $c.G + 0.11 * $c.B)
    } }
    $small.Dispose(); $v
}
function FrameDiff($a, $b) { $s = 0; for ($i = 96; $i -lt $a.Length; $i++) { $s += [Math]::Abs($a[$i] - $b[$i]) }; $s / ($a.Length - 96) }

$stepped = $frames | Where-Object { $_.T -ge $grubAt } | Select-Object -First 1
$grubFrame = Thumb $stepped.File
$final = Thumb $frames[$frames.Count - 1].File
$changeAt = $null; $diffs = @()
foreach ($fr in ($frames | Where-Object { $_.T -ge $enterAt })) {
    $th = Thumb $fr.File
    if ($null -eq $changeAt -and (FrameDiff $th $grubFrame) -gt 6) { $changeAt = $fr.T }
    $diffs += [pscustomobject]@{ T = $fr.T; D = (FrameDiff $th $final) }
}
# desktop = from this frame on, every frame stays close to the final one
$desktopAt = $null
for ($i = $diffs.Count - 1; $i -ge 0; $i--) { if ($diffs[$i].D -gt 3) { break }; $desktopAt = $diffs[$i].T }
if ($null -eq $desktopAt) { throw "never reached a settled desktop in $Seconds s" }

$row = [pscustomobject]@{
    Label = $Label; Iso = (Split-Path $Iso -Leaf); Grub = [Math]::Round($grubAt, 1); Enter = [Math]::Round($enterAt, 1)
    Change = [Math]::Round($changeAt, 1); Desktop = [Math]::Round($desktopAt, 1)
    EnterToDesktop = [Math]::Round($desktopAt - $enterAt, 1)
}
$row | Format-List | Out-String | Write-Output
if (-not (Test-Path $out)) { "Label,Iso,Grub,Enter,Change,Desktop,EnterToDesktop,Date" | Out-File $out -Encoding ascii }
"{0},{1},{2},{3},{4},{5},{6},{7}" -f $row.Label, $row.Iso, $row.Grub, $row.Enter, $row.Change, $row.Desktop, $row.EnterToDesktop, (Get-Date -Format s) | Out-File $out -Append -Encoding ascii
Copy-Item $frames[$frames.Count - 1].File (Join-Path (Split-Path $Iso) "boot-final-$Label.png") -Force
# keep a few frames of the boot for reports: the menu, then 3, 8, 15 and 25 s after Enter
Copy-Item $stepped.File (Join-Path (Split-Path $Iso) "boot-$Label-0-menu.png") -Force
foreach ($off in 3, 8, 15, 25) {
    $fr = $frames | Where-Object { $_.T -ge ($enterAt + $off) } | Select-Object -First 1
    if ($fr) { Copy-Item $fr.File (Join-Path (Split-Path $Iso) ("boot-$Label-+{0:00}s.png" -f $off)) -Force }
}

