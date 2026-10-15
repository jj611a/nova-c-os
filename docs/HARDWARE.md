# Nova-C OS: hardware support

Nova-C uses Debian 13's kernel (Linux 6.12), Mesa 25 and the Debian firmware packages, so it supports what
mainline Linux supports. Two layers sit on top of that:

1. **In the image** (works offline, from the first boot): open-source drivers plus every redistributable
   firmware package relevant to laptops (list below).
2. **Hardware Drivers** (`nova-c-driver-manager`): drivers that cannot ship in the image are found
   automatically and offered after the computer is online.

## What is in the image

| Area | Covered by |
|---|---|
| Graphics | Kernel drivers for Intel (i915/xe), AMD (amdgpu/radeon), NVIDIA (nouveau), VMs; firmware `firmware-intel-graphics`, `firmware-amd-graphics`, `firmware-nvidia-graphics`, `firmware-misc-nonfree`; Mesa OpenGL (`libgl1-mesa-dri`), Vulkan (`mesa-vulkan-drivers`: Intel ANV, AMD RADV, software lavapipe), video decoding (`intel-media-va-driver` for Broadwell and newer, `i965-va-driver` for older Intel, `mesa-va-drivers` for AMD/nouveau), X11 fallback drivers (`xserver-xorg-video-all`) |
| Wi-Fi | `firmware-iwlwifi` (Intel), `firmware-realtek`, `firmware-atheros`, `firmware-mediatek`, `firmware-brcm80211` (Broadcom FullMAC), `firmware-libertas`, `firmware-ti-connectivity`, `firmware-ath9k-htc`, `firmware-zd1211`, `firmware-carl9170`; `wpasupplicant` (WPA/WPA2/WPA3), `wireless-regdb` (correct channels and power per country), `iw` |
| Bluetooth | firmware in the Wi-Fi packages above plus `bluez-firmware` (Broadcom); BlueZ; headsets/speakers via `libspa-0.2-bluetooth` (PipeWire) |
| Sound | Kernel HDA/SOF/AVS drivers, `firmware-sof-signed` (Intel SOF DSP, Apollo Lake and newer), `firmware-intel-sound`, `firmware-cirrus` (Cirrus amplifiers in many 2021+ laptops), `alsa-ucm-conf` + `alsa-topology-conf` (needed by SOF and most modern laptop audio), PipeWire |
| Wired network | in-kernel drivers; `firmware-realtek` (r8169), `firmware-bnx2` (Broadcom NetXtreme II), `firmware-misc-nonfree` |
| Laptop/tablet | `iio-sensor-proxy` (auto-rotation, light sensor), systemd's hwdb sensor and keyboard quirks, `maliit-keyboard` (on-screen keyboard on touch), `thermald` (Intel thermal), `power-profiles-daemon`, `intel-microcode`/`amd64-microcode` |
| Boot | 64-bit UEFI with Secure Boot (`shim-signed`, `grub-efi-amd64-signed`); the live ISO also boots in BIOS mode |

## Hardware Drivers (automatic detection)

After the computer is online (any boot, live or installed), `nova-c-driver-scan.service` runs once and
recognises the hardware:

- **Hardware IDs → packages** using Debian's isenkram mapping (AppStream metadata, the same data Debian's
  own tools use), for example Broadcom Wi-Fi (`firmware-b43-installer` or `broadcom-sta-dkms`), old Intel
  Wi-Fi (`firmware-ipw2x00`), fingerprint readers, smart-card readers, printers.
- **Missing firmware:** firmware files the running drivers asked for but could not find, mapped to the
  Debian package that ships them.
- **NVIDIA:** `nvidia-detect` picks the right proprietary driver for the card (`nvidia-driver` or
  `nvidia-tesla-535-driver` in Debian 13). This is optional: the open-source nouveau driver already works.
  Cards that only old legacy drivers supported keep using nouveau.

When something is found, a pop-up lists the recognised devices with **Download and install**, **Not now**
and **Don't ask again**. Installing asks for the administrator password, downloads from Debian, and
builds kernel modules where needed (`linux-headers-amd64` is added automatically). With Secure Boot on,
the user is guided through enrolling the signing key (MOK) at the next restart. The same tool is in the
menu as **Hardware Drivers** to check again at any time. Logs: `/var/log/nova-c/driver-install.log`.

Because the tool is a Nova-C package, its detection rules update with normal Nova-C updates.

Not possible on Linux at all, or not packaged in Debian 13: Intel IPU6/IPU7 MIPI webcams on most
2021+ laptops, some Apollo Lake/Gemini Lake MIPI webcams, Broadcom/Realtek out-of-tree USB Wi-Fi drivers,
NVIDIA cards that need the 470 or older legacy drivers (roughly Kepler and older; Debian 13 has no
proprietary driver for them, nouveau is used).

## Medion Akoya E3216 / E3222

Both are 13.3" Full-HD touchscreen convertibles (360° hinge) with 4 GB RAM and 64 GB eMMC storage.

| | E3216 (e.g. MD60900, MD61800) | E3222 (e.g. MD62450, MD63720) |
|---|---|---|
| CPU / GPU | Intel Pentium N4200 (Apollo Lake) / HD Graphics 505 | Intel Celeron N4100 or Pentium Silver N5000 (Gemini Lake) / UHD 600/605 |
| Wi-Fi / BT | Intel Wireless-AC 3165 / BT 4.1 | Intel Wireless-AC 9462 (CNVi) / BT 5.0 |

What Nova-C does for them:

| Part | Status in Nova-C |
|---|---|
| Graphics | i915 driver; DMC/GuC/HuC firmware for Apollo Lake (`bxt_*`) and Gemini Lake (`glk_*`) is in the image; video decoding via `intel-media-va-driver` |
| Wi-Fi + Bluetooth | `iwlwifi` with firmware for the AC 3165 (7265D) and AC 9462 (9000 series); Intel Bluetooth firmware; `wpasupplicant` |
| Sound | Intel SOF firmware `sof-apl` / `sof-glk` and the ALSA UCM profiles are in the image; HDA fallback otherwise |
| Screen rotation | systemd's hwdb in Debian 13 has the accelerometer mount matrix for the Akoya E3216 MD60900, E3222 MD62450 and other Akoya E models (`KIOX010A`/`KIOX020A`); `iio-sensor-proxy` rotates the screen |
| Touchscreen | I2C-HID multitouch (no device-specific firmware needed; these models are not in the kernel's Silead/Goodix quirk table) |
| Tablet mode | Intel VBTN/HID switch; Plasma switches to touch mode. The on-screen keyboard (maliit) is not in the default image since 0.2 (it is about 200 MB nobody with a keyboard needs): on these convertibles run `sudo apt install nova-c-touch` once, online |
| Storage / boot | Installs to the eMMC (`/dev/mmcblk0`); 64-bit UEFI, Secure Boot works through Debian's signed shim |

Known limits (from user reports, **not yet verified on a real device**):
- **E3216 webcam:** reported as poorly supported on Linux.
- **E3222 touchpad:** reported not working at first on some older Ubuntu kernels (the touchscreen worked).
  Debian 13's 6.12 kernel is much newer; please report what you see.
- If the laptop will not boot the USB stick, disable Secure Boot in the firmware setup once, and check that
  the stick is chosen from the firmware's boot menu.

Please report results (working or not) as a GitHub issue with the output of
`sudo /usr/libexec/nova-c/driver-scan` and `inxi -Fxz` (if installed) or `lspci -nnk`.

## Graphics drivers and the boot splash (0.2)

To keep the boot files small (a USB stick has to be read in full before anything starts), the early boot image only
carries the Intel graphics driver and the virtual GPUs. AMD, NVIDIA (nouveau) and legacy Radeon load a moment later,
from the system image: the screen stays on the firmware framebuffer until then, then switches to the native mode.
Intel laptops, including the Akoya models above, keep the early, flicker-free path. If an AMD or NVIDIA laptop shows
a black screen where it used to show the splash, or boots to a text console, please report it with
`sudo dmesg | grep -iE 'amdgpu|nouveau|drm'`.

## Fingerprint readers (0.2.1)

`fprintd` and its PAM module are part of the system, and Nova-C switches the PAM profile on (Debian ships it off). Nothing
changes until a finger is enrolled, so laptops without a reader are not affected.

- **Enrol:** System Settings > Users > *Configure Fingerprint Authentication*, or `fprintd-enroll` in a terminal.
- **Used for:** the lock screen, the login screen, `sudo`, `pkexec` and the administrator pop-ups. Touch the sensor, or wait
  about 10 seconds and type the password as usual.
- **After a fingerprint login** KDE Wallet stays locked (it needs the password), so an app that stores secrets there (for
  example saved Wi-Fi passwords in the network applet) may ask for the wallet password once. Log in with the password
  if that bothers you.
- **Supported readers:** the ones Debian's `libfprint` 1.94 drives (most Validity, Elan, Synaptics, AuthenTec and many Goodix
  sensors). Some readers need a proprietary driver that Debian does not package; `fprintd-list $USER` says
  "No devices available" for those.
- **Turn it off:** `sudo pam-auth-update` and untick *Fingerprint authentication*. An update will not switch it back on.
- Not tested on real hardware (VirtualBox cannot pass a reader through): please report what works, with the output of
  `lsusb` and `fprintd-list $USER`.

