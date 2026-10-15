<div align="center">

<img src="assets/logo.png" alt="Nova-C OS logo" width="160">

# Nova-C OS

**A fast, light, good-looking Linux desktop for laptops, built on Debian 13.**

Dark slate and cyan, a clean dock, a boot that gets out of your way, real drivers, and updates that install themselves.

![Base](https://img.shields.io/badge/base-Debian%2013%20trixie-a80030?style=flat-square&logo=debian&logoColor=white)
![Desktop](https://img.shields.io/badge/desktop-KDE%20Plasma%206.3-1d99f3?style=flat-square&logo=kde&logoColor=white)
![Kernel](https://img.shields.io/badge/kernel-Linux%206.12%20LTS-f5c400?style=flat-square&logo=linux&logoColor=black)
![Session](https://img.shields.io/badge/session-Wayland-4ce1f0?style=flat-square)
![Arch](https://img.shields.io/badge/arch-amd64%20%C2%B7%20UEFI-0c2233?style=flat-square)
![Status](https://img.shields.io/badge/status-0.2.0%20early%20release-9ff4ff?style=flat-square)

<img src="docs/screenshots/02-desktop.png" alt="Nova-C OS desktop" width="820">

</div>

---

## ✨ Highlights

| | |
|---|---|
| 💻 **Laptop first** | Built for mouse, touchpad and keyboard; touchscreens and 2-in-1s work too (on-screen keyboard, auto-rotation) |
| 🎨 **Its own look** | Nova-C boot splash, login screen, login splash, wallpaper and colour scheme: no stock Debian or KDE branding in sight |
| 🔄 **Self-updating** | Every installed system pulls Nova-C updates from this repository and Debian security fixes, automatically, once a day |
| 🧰 **Hardware Drivers** | Detects hardware that needs extra drivers (NVIDIA, Broadcom Wi-Fi, missing firmware…) and offers to install them once you're online |
| 💾 **Easy install** | Graphical installer: erase disk or partition by hand (for dual boot), optional disk encryption, UEFI with Secure Boot |
| ⚡ **Quick to start** | Half-size boot files, no slow first-boot jobs, a calm splash that does not eat CPU: about 25% less time to a desktop than 0.1.3 in the test VM ([numbers](#-lighter-and-faster-in-02)) |
| 🪶 **Kept lean** | 15% smaller ISO; docs, stock wallpapers and most translations are not unpacked; indexer, update notifier and other background helpers off; compressed RAM swap (zram) and an out-of-memory guard |
| 🎬 **Creative edition** | An optional ISO ships the seven open-source **ArtCraft** apps: Photoshop, Illustrator, Premiere, Lightroom, After Effects, InDesign and Acrobat alternatives |

## ⚡ Lighter and faster in 0.2

Measured in the same VirtualBox laptop VM (2 vCPU, 2 GB RAM, software rendering) with the scripts in this repository, 0.1.3 against 0.2.0:

| | 0.1.3 | 0.2.0 |
|---|---|---|
| ISO, everyday | 1.75 GB | **1.48 GB** (-16%) |
| ISO, Craft edition | 2.26 GB | **2.02 GB** (-11%) |
| Pressing Enter in the menu to a finished desktop | 41.9 s (41.9, 41.9) | **31.6 s** (30.7, 32.4): -25% |
| Start of userspace to the graphical target | 9.7 s | **5.1 s** |
| Boot files the loader reads before the kernel starts (initramfs) | 153 MB | **69 MB** |
| Memory in use at an idle desktop | 1191 MB | **1167 MB** |

Where the time went, and what was done:

- **Every boot re-ran a 6-second `ldconfig`** from the slow medium, because the image's files looked newer than systemd's "already updated" stamps. They are stamped at build time now (also 0.6 s of hwdb).
- **The initramfs carried every graphics driver and its firmware** (about 85 MB of AMD and NVIDIA files alone). Those now load a moment later from the system image, as on any `MODULES=dep` system; Intel graphics and the virtual GPUs stay early. See [docs/HARDWARE.md](docs/HARDWARE.md#graphics-drivers-and-the-boot-splash-02).
- **The live system is compressed with zstd** instead of xz: a little bigger per file, several times faster to read, which is what a laptop CPU feels at boot.
- **`live-config` skips the time-zone step and the live locale is generated at build time** (5.9 s down to 2.0 s).
- **Plasma helpers that were meant to be off were running** (the update notifier at about 135 MB, the accessibility daemon, the X11 tray proxies) because systemd's autostart generator still found the renamed files. They are really off now.
- **The boot splash redraws a third as often** (it measurably slowed the boot on a slow screen) and eases its progress bar instead of jumping.
- **A smaller image:** docs, man pages, Plasma's stock wallpapers and translations for languages outside a list of 23 (Arabic, Kurdish and others) are not unpacked (and stay out on updates; see `/etc/dpkg/dpkg.cfg.d/90-nova-c-lean` to switch that off), the on-screen keyboard (about 200 MB, only useful on a touchscreen) is the opt-in package `nova-c-touch`, and the installer removes itself from the installed system.

What it looks like now: a GRUB menu at the screen's native resolution with the same typeface as the desktop (Inter), a calm boot splash, Papirus folders in the accent colour, eight wallpapers (the circuit logo, a crimson temple, ink mountains, a nebula city and a ronin under the moon, plus Nova-C, Aurora and Graphite; the circuit one is the default, change it in Settings > Wallpaper), a Nova-C terminal palette, window shadows that lift windows off the dark background, and a floating top bar to match the dock.

Not measured: a real laptop (all numbers are from the VM, where software rendering dominates the last 20 seconds). The method and raw results are in [docs/REPORT.md](docs/REPORT.md).

## 📸 A quick tour

<table>
<tr>
<td align="center" width="50%"><img src="docs/screenshots/01-boot-menu.png" alt="Boot menu"><br><sub><b>Boot menu</b>: sharp at the screen's own resolution, boots by itself after 5 seconds</sub></td>
<td align="center" width="50%"><img src="docs/screenshots/17-boot-splash.png" alt="Boot splash"><br><sub><b>Boot splash</b>: logo, glow and a progress bar instead of scrolling text</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/08-login-screen.png" alt="Login screen"><br><sub><b>Login screen</b></sub></td>
<td align="center"><img src="docs/screenshots/16-login-splash.png" alt="Login splash"><br><sub><b>Login splash</b> while the desktop loads (replaces KDE's)</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/03-launcher-menu.png" alt="Launcher menu"><br><sub><b>App launcher</b>: press the Meta (Windows) key</sub></td>
<td align="center"><img src="docs/screenshots/05-tiled-windows.png" alt="Tiled windows"><br><sub><b>Snap windows</b> side by side with Meta+←/→; cyan folders</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/04-terminal-fastfetch.png" alt="Terminal"><br><sub><b>Terminal</b> with the Nova-C palette and a greeting</sub></td>
<td align="center"><img src="docs/screenshots/28-firefox-first-run.png" alt="Firefox"><br><sub><b>Firefox</b>: no welcome tour, compact layout, hardware video decoding on</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/10a-installer-welcome.png" alt="Installer"><br><sub><b>Installer</b>, Nova-C branded</sub></td>
<td align="center"><img src="docs/screenshots/12-installer-done.png" alt="Installer done"><br><sub>Installed in about 10 minutes (VM)</sub></td>
</tr>
</table>

## 🚀 Get it

Nova-C is built from this repository (see [Build](#-build-it-yourself)). Two flavours:

| ISO | Size | For |
|---|---|---|
| `Nova-C-OS-0.2.0.iso` | 1.48 GB | Everyday laptop use |
| `Nova-C-OS-0.2.0-Craft.iso` | 2.02 GB | The same, plus the seven ArtCraft creative apps |

**Try it:**

1. Write the ISO to a USB stick with [Rufus](https://rufus.ie) (choose *DD image* mode) or [balenaEtcher](https://etcher.balena.io).
2. Boot the laptop from the stick (usually F12, F11, F8 or Esc at power-on chooses the boot device).
3. The boot menu starts the live system by itself after 5 seconds. You land on the live desktop, logged in automatically. The live password is `live` (user `user`).
4. To install, open the menu and choose **Install Nova-C OS**.

> If the laptop refuses to boot the stick, turn Secure Boot off once in the firmware settings, or pick the stick from the firmware's boot menu.

## 🎬 The Craft edition

The Craft ISO adds [ArtCraft](https://getartcraft.com)'s open-source creative suite ([github.com/storytold](https://github.com/storytold), Apache-2.0, written in Rust), installed and in the menu:

<table>
<tr>
<td align="center" width="33%"><img src="docs/screenshots/20-photocraft.png" alt="PhotoCraft"><br><b>PhotoCraft</b><br><sub>image editing (Photoshop-style)</sub></td>
<td align="center" width="33%"><img src="docs/screenshots/21-vectorcraft.png" alt="VectorCraft"><br><b>VectorCraft</b><br><sub>vector art (Illustrator-style)</sub></td>
<td align="center" width="33%"><img src="docs/screenshots/22-filmcraft.png" alt="FilmCraft"><br><b>FilmCraft</b><br><sub>video editing (Premiere-style)</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/23-lightcraft.png" alt="LightCraft"><br><b>LightCraft</b><br><sub>photo library and RAW (Lightroom-style)</sub></td>
<td align="center"><img src="docs/screenshots/24-effectcraft.png" alt="EffectCraft"><br><b>EffectCraft</b><br><sub>motion graphics (After Effects-style)</sub></td>
<td align="center"><img src="docs/screenshots/25-designcraft.png" alt="DesignCraft"><br><b>DesignCraft</b><br><sub>page layout (InDesign-style)</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/26-pdfcraft.png" alt="PdfCraft"><br><b>PdfCraft</b><br><sub>PDF editing (Acrobat-style)</sub></td>
<td align="center" colspan="2"><img src="docs/screenshots/27-craft-menu.png" alt="Craft apps in the menu" width="80%"><br><sub>All seven in the app menu: search "craft"</sub></td>
</tr>
</table>

The apps are young (early alpha) and move fast. Their exact versions are pinned by checksum in
[`scripts/craft-suite.sha256`](scripts/craft-suite.sha256), so a build never silently picks up a changed download.

## 🔄 How updates work

Nova-C's own parts (look, settings, tools) are ordinary Debian packages that live in this repository and are
published as a signed APT repository on GitHub Pages: <https://jj611a.github.io/nova-c-os/>.

```mermaid
flowchart LR
    A["packages/ in this repo<br/>bump a version"] -->|scripts/publish-updates.ps1| B["Signed APT repository<br/>gh-pages → GitHub Pages"]
    D["Debian security<br/>and point releases"] --> C
    B --> C["Every installed Nova-C<br/>daily automatic update"]
    C --> E["New version on next use<br/>(or at once with apt full-upgrade)"]
```

This has been tested end to end: a machine installed from 0.1.1 updated itself to 0.1.2 and then 0.1.3
and picked up the new boot splash with no user action ([screenshot](docs/screenshots/15-auto-update-0.1.3.png)).
0.2.0 reaches installed systems the same way: the look, fonts, boot menu, boot splash and speed-ups arrive with `nova-c-desktop`.
The upgrade from 0.1.3 was exercised in a clean copy of the image (old diversions undone, helpers masked, initramfs rebuilt slim).

| Package | What it carries |
|---|---|
| `nova-c-desktop` | Look and feel, fonts, wallpapers, boot menu, boot and login splash, OS identity, boot-speed and RAM tuning, automatic-update settings |
| `nova-c-driver-manager` | **Hardware Drivers**: detection and the "download and install" pop-up |
| `nova-c-touch` | Optional (`sudo apt install nova-c-touch`): the on-screen keyboard and auto-rotation for touchscreen laptops and 2-in-1s |
| `nova-c-archive-keyring` | The repository's signing key and APT source |

**Ship an update:** edit files under `packages/<name>/`, bump `Version:` in its `control`, then
`powershell -File scripts\publish-updates.ps1 -Message "what changed"`.

> 🔐 Updates run as root on every installed machine, so the signing key is the keys to the kingdom. The private key
> lives only in the build machine's WSL (`/root/.novac-signing`) plus an offline backup made by
> `scripts/repo-key.sh --backup`. It is never committed. Lose it and installed systems can no longer be updated.

## 🧰 Hardware

Debian 13's kernel 6.12 and Mesa 25, plus every redistributable firmware package that matters on laptops:
Intel, AMD and NVIDIA graphics; Intel, Realtek, Atheros, MediaTek and Broadcom Wi-Fi and Bluetooth; Intel SOF and
Cirrus audio. What can't ship in the image (NVIDIA's own driver, Broadcom `wl`, some firmware) is offered by
**Hardware Drivers** after first boot.

Full details, including notes for the **Medion Akoya E3216 / E3222**: [docs/HARDWARE.md](docs/HARDWARE.md).

## 🛠 Build it yourself

Builds run in Debian 13 (WSL2 works) with `live-build`; testing uses VirtualBox on Windows.

```bash
sudo scripts/setup-build-env.sh                  # once: build tools
sudo DEBUG_BOOT=0 scripts/build.sh               # release ISO   -> output/novac.iso
sudo scripts/build.sh                            # debug ISO (boot log on the serial port)
sudo scripts/fetch-craft-suite.sh && \
sudo WITH_CRAFT=1 DEBUG_BOOT=0 scripts/build.sh  # Craft edition -> output/novac-craft.iso
```

```powershell
powershell -File scripts\test-vbox.ps1            # laptop-like VM (mouse + keyboard, no touch)
powershell -File scripts\test-vbox.ps1 -Touch     # touchscreen VM
powershell -File scripts\run-ui-tests.ps1         # scripted UI test, screenshots into docs/screenshots
powershell -File scripts\measure-ram.ps1          # idle memory per program (debug build)
powershell -File scripts\measure-boot.ps1 -Label x    # menu-to-desktop time, read from screenshots (any ISO)
powershell -File scripts\analyze-boot.ps1 -Label x    # systemd-analyze, kernel log and memory of a booted ISO
powershell -File scripts\run-install-test.ps1 -Stage 1  # walk the installer in a VM (stages 1 to 3)
```

A build fails loudly if live-build produced no ISO or dropped any package we ship.

<details>
<summary><b>Repository layout</b></summary>

| Path | What |
|---|---|
| `auto/config` | live-build options |
| `config/package-lists/` | Everything installed in the image, with notes on why |
| `config/hooks/` | Build-time hooks: desktop, branding, installer |
| `config/includes.chroot/` | Image-only files (zram, live user, live session tweaks) |
| `config/bootloaders/` | GRUB menu theme |
| `packages/` | Nova-C's own Debian packages (also published as updates) |
| `branding/` | SVG templates for boot menu, wallpaper and icons; the logo is embedded at build time |
| `scripts/` | Build, publish, test and helper scripts |
| `docs/` | [Test report](docs/REPORT.md), [hardware notes](docs/HARDWARE.md), screenshots |
| `RESEARCH.md` | The original research notes |

</details>

## 📋 Status and honest limits

Nova-C is young. Tested in VirtualBox; **not yet on real laptops**: Wi-Fi, sound, suspend, touchpads and GPUs
on real hardware need feedback. Please [open an issue](https://github.com/jj611a/nova-c-os/issues) with what works and what doesn't
(`lspci -nnk` output helps).

- amd64 with 64-bit UEFI (or BIOS for the live ISO); no ARM yet
- Touchscreen laptops: install the on-screen keyboard once with `sudo apt install nova-c-touch` (it is not in the default image)
- Translations: these are kept (English, Arabic, Persian, Kurdish, Turkish, French, German, Spanish, Portuguese, Italian, Russian, Ukrainian, Polish, Dutch, Czech, Indonesian, Hindi, Vietnamese, Chinese, Japanese, Korean, Greek, Hebrew); other languages show English
- AMD and NVIDIA graphics now start a moment after the boot splash instead of inside the boot files (Intel is unchanged); please report any black screen
- 4 GB RAM is comfortable; 2 GB works but is tight with Plasma
- Tested installs used "Erase disk"; dual boot, disk encryption and Secure Boot are untested so far
- The live session is for trying and installing: its password is public

## 🙏 Built on

[Debian](https://www.debian.org) · [KDE Plasma](https://kde.org/plasma-desktop/) · [Calamares](https://calamares.io) ·
[Plymouth](https://www.freedesktop.org/wiki/Software/Plymouth/) · [live-build](https://wiki.debian.org/DebianLive) ·
[isenkram](https://wiki.debian.org/Isenkram) · [ArtCraft](https://getartcraft.com) · [Papirus icons](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme)

<sub>Nova-C OS is <i>based on</i> Debian; it is not an official Debian release and is not affiliated with Debian, KDE or ArtCraft.</sub>

