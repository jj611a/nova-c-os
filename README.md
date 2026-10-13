# Nova-C OS

Lightweight, Debian-based live/installable desktop OS with a dark slate + cyan KDE Plasma 6 desktop.
Main target: laptops (mouse/touchpad + keyboard); touchscreens are supported but secondary.
Nova-C OS is *based on Debian*; it is not an official Debian release.

- Research: [RESEARCH.md](RESEARCH.md) (written before the Phosh -> Plasma switch)
- Status and test results: [docs/REPORT.md](docs/REPORT.md)
- Logo: [assets/logo.png](assets/logo.png)

## Stack

Debian 13 "trixie" (kernel 6.12) -> SDDM -> KDE Plasma 6.3 on KWin (Wayland), PipeWire, NetworkManager,
Flatpak/Discover, Firefox ESR. Look: custom `org.novac.desktop` look-and-feel (NovaC colour scheme,
Papirus-Dark icons, top bar + floating bottom dock, generated wallpaper and boot splash).

## Layout

- `auto/` live-build options (`auto/config`)
- `config/package-lists/` packages; `config/hooks/` build-time hooks; `config/includes.chroot/` files copied into the image
  (look-and-feel package, SDDM/KWin/fastfetch defaults, zram); `config/bootloaders/` GRUB theme
- `branding/` SVG templates for the boot splash, wallpaper and launcher icon (the logo is embedded at build time)
- `scripts/` build and test helpers

## Build (inside Debian/WSL2)

One-time: `sudo scripts/setup-build-env.sh`

```bash
sudo scripts/build.sh                # dev build: serial boot log on
sudo DEBUG_BOOT=0 scripts/build.sh   # release-style build (quiet splash, no serial console)
```

Output: `output/novac.iso` (+ `.sha256`). `scripts/unlock.sh` clears a stale live-build lock after a crashed build.

## Test (Windows + VirtualBox)

```powershell
powershell -File scripts\test-vbox.ps1            # laptop-like VM: mouse + keyboard, no touch (default)
powershell -File scripts\test-vbox.ps1 -Touch     # USB multi-touch screen instead of a mouse
powershell -File scripts\test-vbox.ps1 -Accel3d   # enable VirtualBox 3D (tests the GPU/GL path)
```

The dev build mirrors the boot log to `output\serial.log`. `scripts\vbox-type.ps1` types into the VM by scancode
(VirtualBox cannot inject mouse clicks from the command line, so tests drive the desktop with keyboard shortcuts).
Default live login: `user` / `live` (autologin in the live session).
