#!/bin/bash
# One-time: install the image-build toolchain inside Debian (WSL2 or VM). Run as root.
# curl: scripts/fetch-craft-suite.sh; gnupg + reprepro: the update repository (scripts/publish-updates.sh);
# fonts-inter: text in the rendered boot-menu picture and wallpapers; grub-common: scripts/make-grub-assets.sh
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
	live-build debootstrap rsync xorriso squashfs-tools grub-efi-amd64-bin grub-pc-bin \
	mtools dosfstools syslinux syslinux-utils isolinux ca-certificates debian-archive-keyring git librsvg2-bin \
	curl gnupg reprepro fonts-inter fonts-dejavu-core grub-common
echo "release: $(cat /etc/debian_version)"
dpkg -l live-build debootstrap | awk '/^ii/{print $2, $3}'
