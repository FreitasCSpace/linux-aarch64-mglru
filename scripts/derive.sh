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

( cd "$out" && source PKGBUILD && echo "${pkgver}-${pkgrel}" )
