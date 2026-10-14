# Nova-C OS: status and test report

> **Note (0.1.3):** this report covers the first Plasma build (0.1). Since then the installer, automatic updates,
> Hardware Drivers, boot/login splash and the Craft edition were added and tested in VMs; see the
> [README](../README.md) and screenshots 10–27. Several "limits" below are now resolved (there is an installer).
> The screenshots 01–09 were re-taken on a later build, so they can show a newer version than this text.

Build under test: `output/novac.iso`, **1520 MB**, sha256 `1b08c07c3b9da792f12ca3b65dd171fdc7b5a98d5b6135730346b6988d673d7b`.
Tested on 13 Oct 2026 in VirtualBox 7.2.20 (Windows 10 host, Ryzen 5 5500). Everything below was run by
[`scripts/run-ui-tests.ps1`](../scripts/run-ui-tests.ps1) on that exact ISO; screenshots are in `docs/screenshots/`.

## What it is now

| | |
|---|---|
| Base | Debian 13 "trixie", Linux 6.12.111, 1169 packages in the live image |
| Desktop | KDE Plasma 6.3.6 on KWin (Wayland), SDDM login manager |
| Look | Custom `org.novac.desktop` look-and-feel: NovaC colour scheme (deep slate, cyan accent from the logo), Papirus-Dark icons, thin top bar (launcher with the Nova-C logo, clock, tray) and a floating bottom dock (Dolphin, Firefox ESR, Konsole, Kate, Discover, System Settings) |
| Branding | Boot menu and splash, desktop and login wallpaper, `os-release` ("Nova-C OS 0.1, based on Debian GNU/Linux 13"), ISO label `NOVA_C_OS`, hostname `nova-c`, fastfetch greeting with the Nova-C logo |
| Target | Laptops with mouse/touchpad + keyboard first; touchscreens second (on-screen keyboard is configured for touch, see limits) |

Direction change during this session: the first prototype used Phosh (a phone shell). You asked for the look of the two reference screenshots
and said laptops are the main target, so the desktop is now Plasma 6 with a custom theme.

## Test report (laptop mode: mouse + keyboard, no touch; VM 2 GB RAM, 2 vCPU, 1280x800)

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Boot menu (UEFI GRUB), branding, correct text | PASS | ![](screenshots/01-boot-menu.png) |
| 2 | Boots to the desktop with autologin, no lock screen | PASS | ![](screenshots/02-desktop.png) |
| 3 | Launcher menu opens with the Meta key; favourites; user shows as "Nova-C live user" | PASS | ![](screenshots/03-launcher-menu.png) |
| 4 | Terminal via Ctrl+Alt+T; fastfetch shows Nova-C OS, Plasma 6.3.6, KWin (Wayland), theme NovaC, 0 failed systemd units | PASS | ![](screenshots/04-terminal-fastfetch.png) |
| 5 | Window management: Meta+Left / Meta+Right tiling, launching Dolphin from the dock with Meta+1 | PASS | ![](screenshots/05-tiled-windows.png) |
| 6 | Alt+Tab window switcher with thumbnails | PASS | ![](screenshots/06-alt-tab.png) |
| 7 | System Settings opens (Meta+6); Mouse & Touchpad, Keyboard, Touchscreen, Display, Bluetooth and Wi-Fi pages present | PASS | ![](screenshots/07-system-settings.png) |
| 8 | SDDM login screen (autologin disabled): wallpaper, clock, user, password field, Sleep/Restart/Shut Down | PASS | ![](screenshots/08-login-screen.png) |
| 9 | Login with the live password lands on the desktop | PASS | ![](screenshots/09-after-password-login.png) |
| 10 | No on-screen keyboard appears while a hardware keyboard is in use (login screen, desktop, focused search field in Settings) | PASS | screenshots 07, 08, 09 |

Measured in the VM (screenshot 04): **1251 MB used, 703 MB available** of 1954 MB with one terminal open; 13 MB swap used.
This includes the live session's RAM-backed overlay and software rendering, so it overstates what an installed system on real hardware needs.

## Problems found and fixed while testing

| Problem | Cause | Fix |
|---|---|---|
| No login possible, desktop never started | live-config only creates the live user when `user-setup` is installed; it is only a Recommends and the build turns recommends off | added `user-setup` |
| Missing runtime pieces (`chvt`, session bus, audio realtime, Mesa/EGL libs) | same: Recommends dropped | listed explicitly (`kbd`, `dbus-user-session`, `rtkit`, `upower`, Mesa packages) |
| Phosh could not start without GPU 3D | VirtualBox without 3D has no EGL | (prototype only) software-renderer fallback script. Plasma's KWin runs on Mesa's software OpenGL in the same VM without any special handling |
| Phone-sized 720x1440 screen | Debian's `phoc.ini` forced VirtualBox's output to a phone mode | moot after the switch to Plasma |
| fastfetch/system said "Debian" | `/etc/os-release` was a plain file, not the symlink the branding hook edited | hook now replaces it with a symlink |
| Splash said "Debian GNU/Linux 0.1" | splash template read the version from our own `os-release` | template text fixed |
| Build failed offline | `firmware-linux` pulled in `firmware-b43-installer`, which downloads firmware from GitHub during the build; live-build's `firmware-chroot` did the same | explicit firmware list, `--firmware-chroot false`; also made the ISO about 140 MB smaller |
| Test scripts failed on VirtualBox progress output | PowerShell treated stderr as fatal | scripts fixed |

## Limits and untested areas (please read)

- **Mouse clicks are untested.** VirtualBox cannot inject mouse clicks from the command line, so the run uses keyboard shortcuts. The pointer is visible and moves, but clicking the dock or menu items with a mouse was not exercised.
- **Touchpad and touchscreen are untested.** The VM has no touchpad. The on-screen keyboard (maliit) is wired into KWin for touch use, but no touch events were sent. Tap-to-click defaults on a real touchpad are not verified.
- **No real hardware yet.** Wi-Fi, Bluetooth, audio, suspend/resume, battery, brightness keys, HiDPI scaling and GPU drivers were not tested. The VM runs with 3D off (software rendering), so the GPU path is untested; try `scripts\test-vbox.ps1 -Accel3d`, and boot the ISO from a USB stick on a spare laptop.
- **Memory:** a 2 GB machine is tight with Plasma (see numbers above). 4 GB or more is a comfortable target; this is heavier than the Phosh prototype, which is the cost of the Plasma look.
- **Live ISO only.** There is no installer yet (Calamares is the next step). The live user is `user` with password `live`, with autologin. Do not treat the live session as secure.
- **Firmware is an explicit list** (Intel, AMD, NVIDIA graphics; Intel, Realtek, Atheros, MediaTek, Broadcom FullMAC, Libertas, TI Wi-Fi; SOF audio; CPU microcode). Old Broadcom b43 Wi-Fi chips and server NIC firmware are not included.
- Secure Boot, ARM64 and 32-bit UEFI tablets are untested or unsupported (amd64 only).
- Firefox, Kate, Discover and Flatpak were not launched in this run.

## How to reproduce

```bash
wsl -d Debian -u root -- bash scripts/build.sh                  # builds output/novac.iso
```

```powershell
powershell -File scripts\test-vbox.ps1                          # boot it in a laptop-style VM
powershell -File scripts\run-ui-tests.ps1                       # repeat this report's tests and screenshots
```

## Suggested next steps

1. Boot the ISO from USB on a real laptop and note what breaks (the quirks list from RESEARCH.md starts there).
2. Add the Calamares installer so it can be installed, not just run live.
3. Test the GPU path (`-Accel3d`) and try to trim idle RAM (disable Baloo/Discover notifier, review autostart).
4. Decide on optional extras. A separate opt-in variant with the Craft app suite is being prepared in another session; it is not part of this ISO.
