#!/bin/bash
# Generate the fixed boot-menu assets (run by hand when the design changes; the results are committed):
#   - Inter fonts as GRUB .pf2 files (Latin only: that is all a boot menu needs)
#   - the 9-slice "selected item" highlight (a translucent cyan pill)
# into the live ISO theme (config/bootloaders/grub-pc/live-theme) and the installed-system theme
# (packages/nova-c-desktop/root/usr/share/grub/themes/novac).
# The background picture is not here: build.sh and the package's prebuild render it from branding/grub-bg.svg.in.
# Needs (Debian): fonts-inter grub-common librsvg2-bin
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
LIVE="$SRC/config/bootloaders/grub-pc/live-theme"
INST="$SRC/packages/nova-c-desktop/root/usr/share/grub/themes/novac"
FONTS=/usr/share/fonts/opentype/inter
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$LIVE" "$INST"

RANGE=0x20-0x7e,0xa0-0x17f,0x2010-0x2027
for dest in "$LIVE" "$INST"; do
	grub-mkfont -s 24 -r "$RANGE" -o "$dest/inter-regular-24.pf2" "$FONTS/Inter-Regular.otf"
	grub-mkfont -s 20 -r "$RANGE" -o "$dest/inter-regular-20.pf2" "$FONTS/Inter-Regular.otf"
	grub-mkfont -s 24 -r "$RANGE" -n "Inter SemiBold" -o "$dest/inter-semibold-24.pf2" "$FONTS/Inter-SemiBold.otf"
done

# selected-item pill: 9 slices of a rounded rectangle (radius 10) so it scales to any menu width
R=10; W=$((R * 4)); FILL='#4ce1f0" fill-opacity="0.20'
slice() {   # slice NAME WIDTH HEIGHT X Y   (the rect is positioned so the slice shows that part of it)
	printf '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s"><rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s"/></svg>' \
		"$2" "$3" "$4" "$5" "$W" "$W" "$R" "$FILL" > "$TMP/$1.svg"
	rsvg-convert "$TMP/$1.svg" -o "$TMP/$1.png"
}
slice nw $R $R 0 0;                       slice ne $R $R $((R - W)) 0
slice sw $R $R 0 $((R - W));          slice se $R $R $((R - W)) $((R - W))
slice n 1 $R $((-R)) 0;                   slice s 1 $R $((-R)) $((R - W))
slice w $R 1 0 $((-R));                   slice e $R 1 $((R - W)) $((-R))
slice c 1 1 $((-R)) $((-R))
for dest in "$LIVE" "$INST"; do
	for s in nw n ne w c e sw s se; do cp "$TMP/$s.png" "$dest/select_$s.png"; done
done
echo "assets written to $LIVE and $INST"
