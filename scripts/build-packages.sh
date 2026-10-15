#!/bin/bash
# Build the Nova-C .debs from packages/<name>/ into packages/dist/.
# Each package dir has: control (DEBIAN/control), root/ (files as installed), optional preinst/postinst/prerm/postrm,
# and an optional prebuild script (run with the staging dir) that generates files.
# Files under /etc become conffiles, so a user's own edits survive updates.
# Builds are reproducible (fixed timestamps), so the same sources and version always give the same bytes:
# build.sh relies on that to check the image against what is already published.
# Release an update: bump Version in packages/<name>/control, then scripts/publish-updates.ps1.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$SRC/packages/dist"
rm -rf "$OUT"; mkdir -p "$OUT"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export SOURCE_DATE_EPOCH=1767225600   # 2026-01-01: fixed file times in the archives

for dir in "$SRC"/packages/*/; do
	[ -f "$dir/control" ] || continue
	name=$(basename "$dir")
	stage="$TMP/$name"
	mkdir -p "$stage/DEBIAN"
	[ -d "$dir/root" ] && cp -a "$dir/root/." "$stage/"
	# optional generated content (e.g. images rendered from branding/ templates)
	[ -f "$dir/prebuild" ] && bash "$dir/prebuild" "$stage" "$SRC"
	# files from /mnt/c arrive as 0777/0755: normalise, keep executables in bin, libexec and hook dirs executable
	find "$stage" -type d -exec chmod 755 {} +
	find "$stage" -type f -exec chmod 644 {} +
	find "$stage" -type f \( -path '*/bin/*' -o -path '*/libexec/*' -o -path '*/dispatcher.d/*' -o -path '*/initramfs-tools/hooks/*' \) -exec chmod 755 {} +
	sed -e '$a\' "$dir/control" > "$stage/DEBIAN/control"
	echo "Installed-Size: $(du -sk --exclude=DEBIAN "$stage" | cut -f1)" >> "$stage/DEBIAN/control"
	for s in preinst postinst prerm postrm; do
		[ -f "$dir/$s" ] && install -m 755 "$dir/$s" "$stage/DEBIAN/$s"
	done
	[ -f "$dir/triggers" ] && install -m 644 "$dir/triggers" "$stage/DEBIAN/triggers"
	( cd "$stage" && { find etc -type f 2>/dev/null || true; } | sed 's#^#/#' | sort ) > "$stage/DEBIAN/conffiles"
	[ -s "$stage/DEBIAN/conffiles" ] || rm "$stage/DEBIAN/conffiles"
	find "$stage" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
	ver=$(sed -n 's/^Version: *//p' "$dir/control")
	arch=$(sed -n 's/^Architecture: *//p' "$dir/control")
	dpkg-deb --root-owner-group -Zxz --build "$stage" "$OUT/${name}_${ver}_${arch}.deb" >/dev/null
	echo "built $OUT/${name}_${ver}_${arch}.deb"
done
