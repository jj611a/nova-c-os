# Building a Lightweight, Debian-Based, Touch-Friendly OS for (Almost) Any Mobile Computer

*Simple research notes. Versions and package names reflect what I know as of late 2026. Verify them against Debian's current stable release before you commit to them.*

---

## 1. TL;DR

1. **Don't write a kernel or an OS from scratch.** Build a *Debian derivative* (a "remaster/spin"). Debian already gives you the kernel, drivers, firmware, packages and security updates.
2. **"Compatible with any mobile computer" is a direction, not a literal goal.** You get the broadest reach with:
   - **Two architectures:** `amd64` (x86 tablets, 2-in-1s, laptops) and `arm64` (SBCs, ARM laptops/tablets, some phones).
   - A **recent kernel + full firmware set** (Debian stable + backports kernel).
   - A **hardware-quirks layer** (touch firmware, sensors, rotation, audio).
3. **Recommended stack:** Debian stable → Linux (backports) → Wayland → **Phosh** (touch-first shell) → PipeWire, NetworkManager, Flatpak. Use **Plasma Mobile** as the alternative.
4. **Build tool:** `live-build` for x86/generic UEFI ISOs. Use `debos` or `mobian-recipes`-style image builds for per-device ARM images.
5. **Be honest about tiers.** Promise "Tier 1: tested and works" and "Tier 2: should boot" rather than "everything works everywhere".

---

## 2. What "compatible with any mobile computer" really means

"Mobile computer" covers very different hardware, and each class has a different difficulty.

| Class | Examples | Boot method | Difficulty | Notes |
|---|---|---|---|---|
| x86-64 laptops / 2-in-1 / tablets | Surface-like, Lenovo Yoga, Chuwi, old Windows tablets | UEFI, GRUB | Easy to medium | One generic ISO works. Touch, sensors and audio need quirks. |
| x86 with **32-bit UEFI** | Intel Atom Bay/Cherry Trail tablets | 32-bit UEFI + 64-bit CPU | Hard | Needs `bootia32.efi`. Debian no longer ships an i386 installer or kernel, so you ship a 64-bit kernel with a 32-bit EFI loader. |
| ARM64 SystemReady (UEFI) devices | Some ARM servers/laptops, VMs | UEFI | Easy | One generic image works. |
| ARM64 SBCs / tablets | Raspberry Pi, Pine64, Rockchip | U-Boot + device tree | Medium | Needs a per-board image or U-Boot config. |
| Qualcomm / Apple Silicon laptops | Snapdragon X, M-series | Device tree / custom loader | Hard | Needs vendor-specific kernel patches (e.g. Asahi). Out of scope for v1. |
| Android phones | Pixel, OnePlus, etc. | Vendor bootloader | Very hard | Each device has its own kernel, modem and GPU blobs. Use existing work (postmarketOS, Droidian, Mobian). |

**Realistic scope for v1:** generic x86-64 UEFI + generic ARM64 UEFI + 2-3 popular ARM boards.

---

## 3. Why Debian as the base

- **Stable and predictable.** Long support window and conservative updates, which suits a "just works" OS.
- **Huge hardware reach.** A large kernel with the `linux-firmware` and `firmware-*` packages. Since Debian 12 the official images include non-free firmware, which matters for Wi-Fi, GPUs and touch controllers.
- **Native multi-arch.** `amd64`, `arm64`, `armhf` and more from one repository.
- **Proven build tools.** `debootstrap`, `live-build`, `debos`, `cubic`.
- **Precedent.** Mobian (Debian on phones) and Raspberry Pi OS are Debian-based. The Debian mobile team already packages Phosh, Plasma Mobile and Lomiri.

**Which release?** Use **Debian stable** (13 "Trixie", kernel 6.12 LTS at release) as the base. Add `trixie-backports` for a newer kernel and Mesa on new hardware. Avoid Testing/Unstable for an OS meant to be "lite and reliable".

---

## 4. Touch-first user interface options

Touch compatibility is mostly a **shell + display server + input stack** question.

### Display server
- **Wayland, not X11.** It has better multi-touch gestures, per-monitor scaling, smooth rotation and lower overhead. Keep XWayland for legacy apps.

### Input stack
- `libinput` handles touch, gestures and palm rejection.
- `iio-sensor-proxy` handles auto-rotation (accelerometer), ambient light and compass.
- A touch-friendly **on-screen keyboard**: `squeekboard` (Phosh) or `maliit` (Plasma Mobile). `onboard` works as a fallback on desktop shells.
- `hid-multitouch` and vendor drivers (Goodix, Elan, Wacom, Silead) live in the kernel. Some need **firmware files** that vary per device (see section 6).

### Shell candidates

| Shell | Base | Weight | Touch quality | Verdict |
|---|---|---|---|---|
| **Phosh** | GNOME/GTK4 + `phoc` (wlroots) | Light to medium | Excellent. Built for touch, gestures and an on-screen keyboard. | **Recommended default.** In Debian, used by Mobian and PureOS. |
| **Plasma Mobile** | KDE Plasma | Medium | Very good | Strong alternative with more features. Heavier. |
| **Lomiri** | Ubuntu Touch shell | Medium | Excellent | Packaged in Debian, but a smaller ecosystem. |
| **GNOME Shell** | GNOME | Medium to heavy | Good on tablets | Good for 2-in-1s. Heavier on low-RAM devices. |
| **Sxmo** | Sway + scripts | Very light | Gesture-based, niche | Too niche for general users. |
| **Custom** | `labwc`/`wayfire` + own panel | Lightest | Whatever you build | Max control, most work. Consider later. |

**Convertible laptops (laptop and tablet modes):** Phosh is touch-first and weaker with a mouse and keyboard. Consider shipping **two session profiles** (touch/tablet and desktop) with automatic switching on the lid/tablet-mode event (`SW_TABLET_MODE`).

---

## 5. Making it "lite"

Targets to aim for (measure, don't assume):

- **ISO size:** about 1.5 GB or less.
- **Idle RAM:** about 600-800 MB with the full touch shell. Boot on 2 GB devices.
- **Boot to home screen:** under 20 s on eMMC/SSD.

Techniques:

1. **Minimal package set.** Install with `--no-install-recommends` / `apt-recommends false`. Start from `task-` or bare `debootstrap --variant=minbase` and add only what you need.
2. **No snap.** Use **Flatpak** for apps. It sandboxes, keeps the base small, and gives touch-adaptive GTK4/libadwaita apps from Flathub.
3. **Light services.** `systemd` with unneeded units disabled. Use `PipeWire` (replaces PulseAudio/JACK). Use `NetworkManager` + `ModemManager` + `iwd` (optional).
4. **Memory tricks.** `zram` (compressed swap in RAM) via `zram-tools`/`systemd-zram-generator`, plus `earlyoom` to prevent hangs on low-RAM devices.
5. **Power.** `power-profiles-daemon` (or `tlp`), and `thermald` on Intel. Mobile devices live or die by battery life.
6. **Filesystems.** `ext4` for most devices, `f2fs` for flash/eMMC, and `squashfs` (zstd) for the live image.
7. **Strip documentation and locales.** Keep `man` and extra locales optional, and use `localepurge`.
8. **Don't ship a browser monster by default.** Offer Firefox ESR or Epiphany (GNOME Web); both work with touch.

---

## 6. Compatibility "pro max": the hardware quirks layer

This is where an OS becomes compatible with "any" mobile computer. The kernel gets you 90% of the way. The last 10% is quirks.

| Problem | Typical devices | Fix |
|---|---|---|
| Wi-Fi / Bluetooth not detected | Broadcom, Realtek, MediaTek | Include `firmware-*` packages. Enable `non-free-firmware`. |
| Touchscreen dead | Silead, Goodix, some Elan | Per-device firmware (e.g. `silead_ts.fw`) plus a DMI-based quirk table. Ship a **firmware database** and match by DMI (`/sys/class/dmi/id/`). |
| Screen upside-down / sideways | Many Atom/Chinese tablets | A `udev` hwdb rule (`60-sensor.hwdb`) for the accelerometer mounting matrix and a kernel `fbcon`/DRM panel-orientation quirk. |
| Auto-rotate not working | Tablets | `iio-sensor-proxy` + correct hwdb entries. |
| No sound | Intel Bay/Cherry Trail, newer Intel laptops | `sof-firmware`, ALSA UCM profiles. |
| GPU / graphics glitches | Old Intel, new AMD, ARM Mali | Newer kernel + Mesa from backports. Fall back to software rendering (`llvmpipe`) if needed. |
| Won't boot on 32-bit UEFI | Cheap Atom tablets | Add `bootia32.efi` to the ISO (GRUB `i386-efi` target). |
| Secure Boot | Many modern devices | Use Debian's signed `shim` + `grub`. Provide MOK enrollment help. |
| Fingerprint, cameras (MIPI/IPU) | Newer laptops/tablets | Partial support. Mark as "best effort". |
| Suspend/resume issues | Many tablets | Kernel parameters per device (`mem_sleep_default=deep`), quirk list. |
| HiDPI scaling | Tablets with 2K+ screens | Wayland fractional scaling (the shell handles this). |

**Practical approach:**
1. Ship a **`hardware-quirks` package** that maps DMI strings to fixes (kernel params, hwdb, firmware).
2. Build an **opt-in hardware telemetry/report tool** so users can submit "my device works/doesn't work" (a probe, not tracking).
3. Maintain a public **compatibility list** with tiers (Tested / Reported working / Unknown).

---

## 7. How to build it (pipeline)

### 7.1 Tools
- **`live-build`**: builds Debian Live ISOs (BIOS + UEFI hybrid). Best for the x86/generic UEFI image.
- **`debos` / `debootstrap`**: scripted image builds. Best for ARM images and SD-card/eMMC images.
- **Calamares**: a graphical installer that works with a touchscreen and on-screen keyboard. (Alternatives: `debian-installer`, which is less touch-friendly.)
- **QEMU**: test `amd64` and `arm64` images without hardware.
- **CI** (GitHub Actions or GitLab CI): build nightly images per architecture.

> On Windows: run `live-build` inside a **Debian VM** (VirtualBox, Hyper-V or VMware) or a privileged Docker container. WSL2 often breaks `live-build` chroot and loop-device steps.

### 7.2 Minimal `live-build` starting point (amd64)

```bash
sudo apt install live-build
mkdir myos && cd myos

lb config \
  --distribution trixie \
  --architectures amd64 \
  --archive-areas "main contrib non-free-firmware" \
  --binary-images iso-hybrid \
  --debian-installer none \
  --apt-recommends false \
  --bootappend-live "boot=live components quiet splash"

# Package list: the lite touch stack
cat > config/package-lists/touch.list.chroot <<'EOF'
phosh
phoc
squeekboard
iio-sensor-proxy
network-manager
pipewire
pipewire-pulse
wireplumber
flatpak
zram-tools
earlyoom
power-profiles-daemon
firmware-linux
firmware-misc-nonfree
firmware-iwlwifi
firmware-realtek
firmware-atheros
sof-firmware
calamares
EOF

sudo lb build
```

For the ARM64 version, use `--architectures arm64` or switch to `debos`, because ARM boards often need a board-specific bootloader and device tree.

### 7.3 Repo layout suggestion

```
myos/
├── config/              # live-build config
│   ├── package-lists/
│   ├── includes.chroot/ # your files overlaid on the rootfs (configs, hwdb, branding)
│   └── hooks/           # scripts run during build
├── hardware-quirks/     # DMI → fix tables, firmware db
├── installer/           # Calamares branding/config
├── arm-images/          # debos recipes per board
├── ci/                  # pipeline definitions
└── docs/
```

---

## 8. Roadmap

| Phase | Goal | Output |
|---|---|---|
| 0. Prototype (1-2 weeks) | Boot Debian + Phosh in a VM | A working ISO in QEMU/VirtualBox |
| 1. x86 touch MVP (1-2 months) | Real 2-in-1/tablet: touch, rotation, keyboard, Wi-Fi, suspend | Tier-1 device list (3-5 devices) |
| 2. Installer and polish | Touch-friendly Calamares, branding, Flatpak store, updates | Installable image |
| 3. Lite tuning | RAM/boot/battery optimization, zram, trimmed packages | Benchmarks vs. targets |
| 4. ARM64 | Generic UEFI image, then 2-3 boards (e.g. Raspberry Pi, Pine64) | `arm64` images |
| 5. Quirks and community | `hardware-quirks` package, compatibility database, bug reporter | Public device list |
| 6. Phones (optional) | Build on Mobian/postmarketOS work | Device-specific ports |

---

## 9. Risks and honest limits

- **Vendor lock-in:** phones and some tablets have locked bootloaders and closed drivers (modem, GPU, camera). You can't fix these from the OS layer.
- **Firmware licensing:** non-free firmware is allowed in the official Debian images now, but you must handle licenses if you redistribute modified images.
- **Maintenance burden:** touch quirks mean a long tail of device-specific fixes. Plan community contributions.
- **Security updates:** tracking Debian stable keeps you safe. Forking the kernel makes it harder, so stay as close to upstream as you can.
- **Naming and trademarks:** don't use "Debian" in your product name. Say "based on Debian".
- **Shell maturity:** Phosh/Plasma Mobile are good but still evolving on tablets and desktop-class screens. Test your target UX early.

---

## 10. Projects to study before writing anything

| Project | Why look at it |
|---|---|
| **Mobian** | Debian on phones/tablets using Phosh. The closest match to your goal. |
| **postmarketOS** | Alpine-based, but the best reference for mobile hardware enablement and device ports. |
| **Droidian** | Debian on Android phones via Halium. |
| **Ubuntu Touch / Lomiri** | Mature mobile shell and convergence ideas. |
| **PureOS (Librem)** | Debian-based and privacy-focused, uses Phosh. |
| **Raspberry Pi OS** | Debian-based, ARM, official touch display support. |
| **antiX / MX Linux / Q4OS** | Lightweight Debian derivatives. Study how they stay small. |
| **Debian Live / `live-build` manual** | The official way to build what you want. |

---

## 11. Recommended next step

Build **Phase 0** this week:

1. Spin up a Debian 13 VM.
2. Run the `live-build` snippet above for `amd64`.
3. Boot the ISO in QEMU/VirtualBox and confirm Phosh starts.
4. Then test it on one real touchscreen device (any old Windows tablet or 2-in-1) and record what breaks. That list becomes your quirks backlog.

If you tell me your target devices (for example, "old Windows tablets" or "Raspberry Pi + touchscreen"), I can narrow this into a concrete build plan and generate the starter `live-build` project folder.
