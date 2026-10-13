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
# WITH_CRAFT=1 adds the Craft app suite and writes output/novac-craft.iso instead of output/novac.iso
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

	# Nova-C's own packages: look, tuning, update source (the same .debs publish-updates.sh publishes)
	bash "$SRC/scripts/build-packages.sh"
	mkdir -p "$WORK/config/packages.chroot"
	# a version that is already published must be byte-identical (builds are reproducible): otherwise apt
	# sees two different packages with one version, and installed systems would never get the change
	PAGES="${PAGES:-$SRC/../nova-c-os-pages}"
	for deb in "$SRC"/packages/dist/*.deb; do
		f=$(basename "$deb"); pub=$(find "$PAGES/pool" -name "$f" 2>/dev/null | head -n1)
		if [ -n "$pub" ] && ! cmp -s "$deb" "$pub"; then
			echo "$f is already published with different content: bump Version in packages/${f%%_*}/control"; exit 1
		fi
		[ -n "$pub" ] || echo "note: $f is not published yet (scripts/publish-updates.ps1)"
		cp "$deb" "$WORK/config/packages.chroot/"
	done

	# optional ArtCraft "Craft" app suite (about +0.5 GB): WITH_CRAFT=1, after scripts/fetch-craft-suite.sh
	if [ "${WITH_CRAFT:-0}" = 1 ]; then
		( cd "$SRC/extras/craft" && sha256sum -c --quiet "$SRC/scripts/craft-suite.sha256" ) \
			|| { echo "Craft debs missing or not matching the pins: run scripts/fetch-craft-suite.sh"; exit 1; }
		cp "$SRC"/extras/craft/*.deb "$WORK/config/packages.chroot/"
		# Recommends of the Craft debs needed at runtime (software Vulkan where the GPU has none)
		printf 'mesa-vulkan-drivers\nlibvulkan1\n' > "$WORK/config/package-lists/craft.list.chroot"
	fi
fi

cd "$WORK"
# RESUME=1 continues an interrupted build (e.g. network blip) from the last finished stage.
# Only use it when config/ has not changed since the interrupted run.
if [ "${RESUME:-0}" != 1 ]; then
	lb clean 2>/dev/null || true   # keeps cache/ (downloads); config is regenerated from auto/config
	lb config
fi
rm -f "$WORK"/*.iso
lb build 2>&1 | tee -a "$WORK/build.log"

# lb can exit 0 after a failed stage (e.g. "E: An unexpected failure occurred"): only a fresh ISO counts
NAME=novac; [ "${WITH_CRAFT:-0}" = 1 ] && NAME=novac-craft
ISO="$(ls -1 "$WORK"/*.iso 2>/dev/null | head -n1)"
[ -n "$ISO" ] || { echo "BUILD FAILED: no ISO produced, see $WORK/build.log"; exit 1; }
cp -v "$ISO" "$OUT/$NAME.iso"
cp -v "$WORK/build.log" "$OUT/build.log"
( cd "$OUT" && sha256sum $NAME.iso | tee $NAME.iso.sha256 )
