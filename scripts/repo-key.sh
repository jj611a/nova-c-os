#!/bin/bash
# One-time: create the Nova-C archive signing key (signs the APT update repository).
# The PRIVATE key lives only in $GNUPGHOME (WSL, root-only) plus the backup you make with --backup DIR.
# Never commit it. The PUBLIC key is exported into packages/nova-c-archive-keyring/, which ships in the image.
# Lose the private key and installed systems can no longer be updated: keep the backup somewhere safe.
#   sudo scripts/repo-key.sh                 # create (if missing) + export public key
#   sudo scripts/repo-key.sh --backup DIR    # also write the private key to DIR
set -euo pipefail

export GNUPGHOME="${GNUPGHOME:-/root/.novac-signing}"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
UID_STR="Nova-C OS Archive Signing Key"
PUB="$SRC/packages/nova-c-archive-keyring/root/usr/share/keyrings/nova-c-archive-keyring.gpg"

mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME"
if ! gpg --batch --list-secret-keys "$UID_STR" >/dev/null 2>&1; then
	# no passphrase: publishing runs unattended; protection is the root-only directory
	gpg --batch --passphrase '' --quick-generate-key "$UID_STR" ed25519 sign never
fi
FPR=$(gpg --batch --with-colons --list-secret-keys "$UID_STR" | awk -F: '/^fpr:/ { print $10; exit }')

mkdir -p "$(dirname "$PUB")"
gpg --batch --yes --export "$FPR" > "$PUB"
echo "$FPR" > "$SRC/packages/nova-c-archive-keyring/FINGERPRINT"
echo "signing key $FPR"
echo "public key  $PUB"

if [ "${1:-}" = --backup ]; then
	mkdir -p "$2"
	gpg --batch --yes --armor --export-secret-keys "$FPR" > "$2/nova-c-archive-signing-key.PRIVATE.asc"
	chmod 600 "$2/nova-c-archive-signing-key.PRIVATE.asc"
	echo "private key backup: $2/nova-c-archive-signing-key.PRIVATE.asc  (keep it secret, keep it safe)"
fi
