#!/bin/bash
# Builds the linux-aarch64-mglru package sources in $1 (default: ./build):
# Arch Linux ARM's current core/linux-aarch64 + mglru.patch on its PKGBUILD.
# Prints "<pkgver>-<pkgrel>" of the result on stdout.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
out=${1:-build}
upstream=${UPSTREAM:-https://github.com/archlinuxarm/PKGBUILDs.git}

rm -rf "$out" "$out.upstream"
git clone -q --depth 1 --filter=blob:none --sparse "$upstream" "$out.upstream"
git -C "$out.upstream" sparse-checkout set core/linux-aarch64
cp -r "$out.upstream/core/linux-aarch64" "$out"
rm -rf "$out.upstream"

# Fails loudly if Arch Linux ARM changed the PKGBUILD lines the patch touches.
patch --no-backup-if-mismatch -d "$out" -p0 < "$here/mglru.patch" >&2
cp "$here/linux-aarch64-mglru.install" "$out/"

# localrel > 0 bumps pkgrel to "<upstream>.<localrel>" so a change made only here
# (config, patch) still reaches pacman as an upgrade. Reset to 0 when upstream bumps.
localrel=$(<"$here/localrel")
if (( localrel > 0 )); then
  sed -i "s/^pkgrel=\([0-9]*\)$/pkgrel=\1.$localrel/" "$out/PKGBUILD"
fi

( cd "$out" && source PKGBUILD && echo "${pkgver}-${pkgrel}" )
