#!/bin/bash
# Download the optional ArtCraft "Craft" suite (github.com/storytold, Apache-2.0, Rust): PhotoCraft, VectorCraft,
# FilmCraft, LightCraft, EffectCraft, DesignCraft, PdfCraft, as the official linux-x86_64 .debs.
# Files land in extras/craft/; `WITH_CRAFT=1 scripts/build.sh` puts them into the image (about +0.5 GB ISO).
#
# Every file must match the hash pinned in scripts/craft-suite.sha256, so a re-published upstream release
# fails here instead of being accepted silently. To update an app: download the new .deb, check it, and
# replace its line in craft-suite.sha256 (the version comes from the filename).
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
PINS="$SRC/scripts/craft-suite.sha256"
DEST="${DEST:-$SRC/extras/craft}"
mkdir -p "$DEST"
command -v curl >/dev/null || { echo "curl missing: run scripts/setup-build-env.sh"; exit 1; }

while read -r sum deb; do
	[ -n "$deb" ] || continue
	# photocraft-0.8.2-linux-x86_64.deb -> app photocraft, version 0.8.2
	app=${deb%%-*}; rest=${deb#*-}; ver=${rest%%-*}
	if [ -f "$DEST/$deb" ] && echo "$sum  $DEST/$deb" | sha256sum -c --quiet - >/dev/null 2>&1; then
		echo "ok       $deb"
		continue
	fi
	curl -fL --retry 3 -o "$DEST/$deb.part" "https://github.com/storytold/$app/releases/download/v$ver/$deb"
	echo "$sum  $DEST/$deb.part" | sha256sum -c --quiet - || { rm -f "$DEST/$deb.part"; echo "HASH MISMATCH (not pinned): $deb"; exit 1; }
	mv "$DEST/$deb.part" "$DEST/$deb"
	echo "fetched  $deb"
done < "$PINS"

# drop anything not pinned (old versions, partial downloads)
for f in "$DEST"/*; do
	[ -e "$f" ] || continue
	grep -q "  $(basename "$f")\$" "$PINS" || { rm -f "$f"; echo "removed  $(basename "$f")"; }
done
