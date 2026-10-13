# Nova-C OS

Lightweight, Debian-based live/installable desktop OS with a dark slate + cyan KDE Plasma 6 desktop.
Main target: laptops (mouse/touchpad + keyboard); touchscreens are supported but secondary.
Nova-C OS is *based on Debian*; it is not an official Debian release.

- Research: [RESEARCH.md](RESEARCH.md) (written before the Phosh -> Plasma switch)
- Status and test results: [docs/REPORT.md](docs/REPORT.md)
- Logo: [assets/logo.png](assets/logo.png)
- Update repository: <https://jj611a.github.io/nova-c-os/> (signed APT repo, `gh-pages` branch)

## Stack

Debian 13 "trixie" (kernel 6.12) -> SDDM -> KDE Plasma 6.3 on KWin (Wayland), PipeWire, NetworkManager,
Flatpak/Discover, Firefox ESR, Calamares installer. Look: custom `org.novac.desktop` look-and-feel (NovaC colour
scheme, Papirus-Dark icons, top bar + floating bottom dock, generated wallpaper and boot splash).

## Layout

- `auto/` live-build options (`auto/config`)
- `config/package-lists/` packages; `config/hooks/` build-time hooks (desktop, branding, installer);
  `config/includes.chroot/` image-only files (zram size, live user name); `config/bootloaders/` GRUB theme
- `packages/` Nova-C's own Debian packages, installed in the image **and** published as updates:
  - `nova-c-desktop`: look-and-feel, wallpaper, SDDM/KWin/fastfetch defaults, os-release, RAM tuning, automatic updates
  - `nova-c-archive-keyring`: the update repository's signing key and APT source
- `branding/` SVG templates for the boot splash, wallpaper and launcher icon (the logo is embedded at build time)
- `scripts/` build, test, update-publishing and helper scripts

## Build (inside Debian/WSL2)

One-time: `sudo scripts/setup-build-env.sh`

```bash
sudo scripts/build.sh                    # dev build: serial boot log on -> output/novac.iso
sudo DEBUG_BOOT=0 scripts/build.sh       # release build (quiet splash, no serial console)
sudo scripts/fetch-craft-suite.sh && sudo WITH_CRAFT=1 scripts/build.sh   # + ArtCraft "Craft" apps -> output/novac-craft.iso
```

`scripts/unlock.sh` clears a stale live-build lock after a crashed build.

## Updates: how installed systems stay current

Every Nova-C system has `/etc/apt/sources.list.d/nova-c.sources` (from `nova-c-archive-keyring`) and installs updates
automatically once a day with `unattended-upgrades`: Debian security fixes from Debian, Nova-C updates from
<https://jj611a.github.io/nova-c-os/>. Users can also update at once with `sudo apt update && sudo apt full-upgrade`
or Discover.

To ship an update to every installed system:

1. Change files under `packages/<name>/` and bump `Version:` in `packages/<name>/control`
   (for a new OS version also bump `VERSION_ID`/`VERSION`/`PRETTY_NAME` in `packages/nova-c-desktop/root/usr/lib/os-release`).
2. `powershell -File scripts\publish-updates.ps1 -Message "nova-c-desktop 0.1.1: ..."`
   (builds the .debs, signs the repository, pushes `gh-pages`).

New packages a release needs can be added to `Depends:` of `nova-c-desktop`; machines install them with the update.

**Security:** updates run as root on every installed machine, so whoever holds the signing key controls all of them.
The private key is in WSL at `/root/.novac-signing` with a backup made by `scripts/repo-key.sh --backup`; keep that
backup offline and never commit it. Losing the key means installed systems can no longer receive Nova-C updates.

## Test (Windows + VirtualBox)

```powershell
powershell -File scripts\test-vbox.ps1            # laptop-like VM: mouse + keyboard, no touch (default)
powershell -File scripts\test-vbox.ps1 -Touch     # USB multi-touch screen instead of a mouse
powershell -File scripts\test-vbox.ps1 -Accel3d   # enable VirtualBox 3D (tests the GPU/GL path)
powershell -File scripts\run-ui-tests.ps1         # scripted UI test with screenshots (docs/screenshots)
powershell -File scripts\measure-ram.ps1          # idle memory per program (dev build)
```

The dev build mirrors the boot log to `output\serial.log`. `scripts\vbox-type.ps1` types into the VM by scancode
(VirtualBox cannot inject mouse clicks from the command line, so tests drive the desktop with keyboard shortcuts).
Default live login: `user` / `live` (autologin in the live session).
