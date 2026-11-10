# linux-aarch64-mglru

Arch Linux ARM's `linux-aarch64` kernel, rebuilt for low-RAM Qualcomm Chromebooks
(built and tested on a Lenovo IdeaPad Duet 5 / SC7180) with:

- **MGLRU** (multi-gen LRU) enabled by default: the page-reclaim ChromeOS uses to avoid thrashing.
- **zram with zstd** as the default compressor, plus lz4 and multi-compressor recompression (`ZRAM_MULTI_COMP`).
- Only the Qualcomm platform built in (shorter build).

Everything else is the stock Arch Linux ARM config and patches. A GitHub Actions job
checks Arch Linux ARM every day and rebuilds when `core/linux-aarch64` changes, so the
package follows the stock kernel version. The kernel installs side by side with the stock one
(`/boot/Image-mglru`, modules in `*-mglru-ARCH`).

## Install (pacman repo)

```sh
curl -sL https://raw.githubusercontent.com/FreitasCSpace/linux-aarch64-mglru/main/keys/mglru.asc | sudo pacman-key --add -
sudo pacman-key --lsign-key 47AD6E5D716DC0047BB4072112454A9D4A4220AE
sudo tee -a /etc/pacman.conf <<'EOF'

[mglru]
SigLevel = Required
Server = https://github.com/FreitasCSpace/linux-aarch64-mglru/releases/download/repo
EOF
sudo pacman -Sy linux-aarch64-mglru linux-aarch64-mglru-headers
```

## Booting it on a depthcharge Chromebook

`boot/` has the A/B tooling: a second kernel partition (KERN-B) holds this kernel and
the stock kernel in KERN-A stays as the fallback. Each new MGLRU kernel is written as a
one-try trial and marked good 3 minutes after a healthy boot; if it does not boot, the
firmware falls back to KERN-A. See `boot/setup-kernb.sh` (repartitions the eMMC — read it first).

## How the package is derived

`scripts/derive.sh` sparse-clones `archlinuxarm/PKGBUILDs` `core/linux-aarch64` and applies
`mglru.patch` to its PKGBUILD. If upstream changes the lines the patch touches, the build fails
instead of publishing something unchecked.
