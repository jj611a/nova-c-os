#!/bin/bash
# One-time: install the image-build toolchain inside Debian (WSL2 or VM). Run as root.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
	live-build debootstrap rsync xorriso squashfs-tools grub-efi-amd64-bin grub-pc-bin \
	mtools dosfstools syslinux syslinux-utils isolinux ca-certificates debian-archive-keyring git librsvg2-bin
echo "release: $(cat /etc/debian_version)"
dpkg -l live-build debootstrap | awk '/^ii/{print $2, $3}'
