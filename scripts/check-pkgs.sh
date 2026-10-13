#!/bin/bash
# Print the candidate version of each package in config/package-lists (or "MISSING").
cd "$(dirname "$0")/.."
grep -hvE '^\s*(#|$)' config/package-lists/*.chroot | while read -r p; do
	v=$(apt-cache policy "$p" 2>/dev/null | sed -n 's/ *Candidate: //p')
	printf '%-28s %s\n' "$p" "${v:-MISSING}"
done
