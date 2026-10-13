#!/bin/bash
# Build the Nova-C .debs from packages/<name>/ into packages/dist/.
# Each package dir has: control (DEBIAN/control), root/ (files as installed), optional postinst/prerm/postrm.
# Files under /etc become conffiles, so a user's own edits survive updates.
# Release an update: bump Version in packages/<name>/control, then scripts/publish-updates.sh.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$SRC/packages/dist"
rm -rf "$OUT"; mkdir -p "$OUT"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

for dir in "$SRC"/packages/*/; do
	[ -f "$dir/control" ] || continue
	name=$(basename "$dir")
	stage="$TMP/$name"
	mkdir -p "$stage/DEBIAN"
	[ -d "$dir/root" ] && cp -a "$dir/root/." "$stage/"
	# files from /mnt/c arrive as 0777/0755: normalise, keep executables in bin dirs and maintainer scripts
	find "$stage" -type d -exec chmod 755 {} +
	find "$stage" -type f -exec chmod 644 {} +
	find "$stage" -type f \( -path '*/bin/*' -o -path '*/libexec/*' \) -exec chmod 755 {} +
	sed -e '$a\' "$dir/control" > "$stage/DEBIAN/control"
	echo "Installed-Size: $(du -sk --exclude=DEBIAN "$stage" | cut -f1)" >> "$stage/DEBIAN/control"
	for s in preinst postinst prerm postrm; do
		[ -f "$dir/$s" ] && install -m 755 "$dir/$s" "$stage/DEBIAN/$s"
	done
	( cd "$stage" && find etc -type f 2>/dev/null | sed 's#^#/#' | sort ) > "$stage/DEBIAN/conffiles"
	[ -s "$stage/DEBIAN/conffiles" ] || rm "$stage/DEBIAN/conffiles"
	ver=$(sed -n 's/^Version: *//p' "$dir/control")
	arch=$(sed -n 's/^Architecture: *//p' "$dir/control")
	dpkg-deb --root-owner-group -Zxz --build "$stage" "$OUT/${name}_${ver}_${arch}.deb" >/dev/null
	echo "built $OUT/${name}_${ver}_${arch}.deb"
done
