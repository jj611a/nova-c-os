#!/bin/bash
# Build the Nova-C OS ISO. Run as root inside Debian (WSL2 or VM):  sudo scripts/build.sh
# Builds on the native Linux filesystem (live-build breaks on /mnt/c) and copies the ISO back.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-/var/tmp/novac-build}"
# one-time rename from the old working name, keeping the package cache
if [ ! -d "$WORK" ] && [ -d /var/tmp/touchos-build ]; then mv /var/tmp/touchos-build "$WORK"; fi
OUT="$SRC/output"

[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)"; exit 1; }

# dev builds log the boot to the serial port; release: DEBUG_BOOT=0 scripts/build.sh
export DEBUG_BOOT="${DEBUG_BOOT:-1}"

mkdir -p "$WORK" "$OUT"
if [ "${RESUME:-0}" != 1 ]; then
	# sync the project definition only (RESUME=1 skips this: --delete would wipe generated config)
	rsync -a --delete --exclude output --exclude .build --exclude cache --exclude chroot \
		--exclude 'binary*' --exclude '*.iso' --exclude 'live-image-*' --exclude .git \
		"$SRC/auto" "$SRC/config" "$WORK/"
	# files from /mnt/c arrive as 0755: normalise overlay files, keep scripts executable
	find "$WORK/config/includes.chroot" -type f -exec chmod 644 {} +
	chmod +x "$WORK"/auto/* "$WORK"/config/hooks/normal/*.chroot 2>/dev/null || true

	# boot splash: embed the logo into the SVG template (live-build renders it to splash.png)
	mkdir -p "$WORK/config/bootloaders"
	# bash builtins only: the base64 logo (~140 KB) is over the 128 KB single-argument limit for sed/awk
	LOGO_B64="$(base64 -w0 "$SRC/assets/logo.png")"
	TEMPLATE="$(< "$SRC/branding/splash.svg.in")"
	printf '%s\n' "${TEMPLATE//@LOGO_B64@/$LOGO_B64}" > "$WORK/config/bootloaders/splash.svg"

	# desktop wallpaper (also used by the SDDM login screen)
	WALL_DIR="$WORK/config/includes.chroot/usr/share/wallpapers/NovaC/contents/images"
	mkdir -p "$WALL_DIR"
	TEMPLATE="$(< "$SRC/branding/wallpaper.svg.in")"
	printf '%s\n' "${TEMPLATE//@LOGO_B64@/$LOGO_B64}" > "$WORK/wallpaper.svg"
	rsvg-convert -w 1920 -h 1080 "$WORK/wallpaper.svg" -o "$WALL_DIR/1920x1080.png"
	chmod 644 "$WALL_DIR/1920x1080.png"

	# launcher/menu icon ("novac-logo")
	ICON_DIR="$WORK/config/includes.chroot/usr/share/icons/hicolor/128x128/apps"
	mkdir -p "$ICON_DIR"
	TEMPLATE="$(< "$SRC/branding/icon.svg.in")"
	printf '%s\n' "${TEMPLATE//@LOGO_B64@/$LOGO_B64}" > "$WORK/icon.svg"
	rsvg-convert -w 128 -h 128 "$WORK/icon.svg" -o "$ICON_DIR/novac-logo.png"
	chmod 644 "$ICON_DIR/novac-logo.png"
fi

cd "$WORK"
# RESUME=1 continues an interrupted build (e.g. network blip) from the last finished stage.
# Only use it when config/ has not changed since the interrupted run.
if [ "${RESUME:-0}" != 1 ]; then
	lb clean 2>/dev/null || true   # keeps cache/ (downloads); config is regenerated from auto/config
	lb config
fi
lb build 2>&1 | tee -a "$WORK/build.log"

ISO="$(ls -1 "$WORK"/*.iso | head -n1)"
cp -v "$ISO" "$OUT/novac.iso"
cp -v "$WORK/build.log" "$OUT/build.log"
( cd "$OUT" && sha256sum novac.iso | tee novac.iso.sha256 )
