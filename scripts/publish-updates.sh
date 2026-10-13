#!/bin/bash
# Build the Nova-C packages and export them into the signed APT repository tree in SITE (the gh-pages
# checkout that GitHub Pages serves as https://jj611a.github.io/nova-c-os/). Run as root in Debian/WSL2;
# scripts/publish-updates.ps1 calls this and then commits + pushes SITE.
# A package version that is already published cannot be replaced: bump Version in packages/<name>/control.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
SITE="${1:?usage: publish-updates.sh SITE_DIR}"
export GNUPGHOME="${GNUPGHOME:-/root/.novac-signing}"
FPR="$(cat "$SRC/packages/nova-c-archive-keyring/FINGERPRINT")"
gpg --batch --list-secret-keys "$FPR" >/dev/null || { echo "signing key $FPR not in $GNUPGHOME (restore the backup)"; exit 1; }

# reprepro's database lives on the Linux filesystem; the exported repository goes to SITE
BASE=/var/tmp/novac-apt
mkdir -p "$BASE/conf" "$SITE"
cat > "$BASE/conf/distributions" <<EOF
Origin: NovaC
Label: Nova-C OS
Codename: trixie
Suite: stable
Architectures: amd64
Components: main
Description: Nova-C OS updates (https://github.com/jj611a/nova-c-os)
SignWith: $FPR
EOF
cat > "$BASE/conf/options" <<EOF
outdir $SITE
EOF

bash "$SRC/scripts/build-packages.sh"
for deb in "$SRC"/packages/dist/*.deb; do
	reprepro -b "$BASE" includedeb trixie "$deb"
done
reprepro -b "$BASE" export trixie
reprepro -b "$BASE" list trixie

# public key for manual setup, plus a small landing page; .nojekyll: serve the tree as-is
gpg --batch --yes --export "$FPR" > "$SITE/nova-c-archive-keyring.gpg"
gpg --batch --yes --armor --export "$FPR" > "$SITE/nova-c-archive-keyring.asc"
touch "$SITE/.nojekyll"
cat > "$SITE/index.html" <<EOF
<!doctype html><meta charset="utf-8"><title>Nova-C OS updates</title>
<style>body{font:16px/1.5 system-ui,sans-serif;max-width:46rem;margin:2rem auto;padding:0 1rem;background:#0a0f18;color:#dfeef2}
a{color:#4ce1f0}code,pre{background:#14202e;padding:.15rem .35rem;border-radius:4px}pre{padding:.8rem;overflow:auto}</style>
<h1>Nova-C OS update repository</h1>
<p>APT repository for <a href="https://github.com/jj611a/nova-c-os">Nova-C OS</a>. Installed systems already use it and
install updates automatically. Signing key fingerprint: <code>$FPR</code>.</p>
<pre>$(reprepro -b "$BASE" list trixie)</pre>
<p>Manual setup on a Debian 13 system:</p>
<pre>sudo curl -fsSLo /usr/share/keyrings/nova-c-archive-keyring.gpg https://jj611a.github.io/nova-c-os/nova-c-archive-keyring.gpg
printf 'Types: deb\nURIs: https://jj611a.github.io/nova-c-os/\nSuites: trixie\nComponents: main\nSigned-By: /usr/share/keyrings/nova-c-archive-keyring.gpg\n' \\
  | sudo tee /etc/apt/sources.list.d/nova-c.sources
sudo apt update && sudo apt install nova-c-desktop</pre>
EOF
echo "exported to $SITE"
