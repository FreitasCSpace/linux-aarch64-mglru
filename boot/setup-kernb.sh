#!/bin/bash
# One-time: carve a 256 MiB ChromeOS kernel partition (KERN-B, p3) off the end
# of the btrfs root (p2) on the Duet 5's eMMC, online, without touching p1/p2's
# start. Steps: shrink the btrfs filesystem well below the new partition end,
# shrink p2 in the GPT and in the running kernel (BLKPG resize, allowed while
# mounted), then add p3. btrfs is left ~512 MiB smaller than p2 on purpose.
set -euo pipefail

DISK=/dev/mmcblk1
ROOT=${DISK}p2
SECTOR=512
KERNB_SECTORS=524288            # 256 MiB, same as KERN-A

[[ $(findmnt -nvo SOURCE /) == "$ROOT" ]] || { echo "root is not $ROOT" >&2; exit 1; }
if cgpt show -i 3 "$DISK" >/dev/null 2>&1 && [[ -n $(cgpt show -i 3 -l "$DISK" 2>/dev/null) ]]; then
  echo "partition 3 already exists: $(cgpt show -i 3 -l "$DISK")"; exit 0
fi

p2_start=$(cat /sys/class/block/mmcblk1p2/start)
p2_size=$(cat /sys/class/block/mmcblk1p2/size)
last_usable=$((p2_start + p2_size - 1))
p3_start=$(( (last_usable + 1 - KERNB_SECTORS) / 2048 * 2048 ))
new_p2_size=$((p3_start - p2_start))
btrfs_bytes=$(( new_p2_size * SECTOR - 512 * 1024 * 1024 ))

echo "p2: ${p2_size} -> ${new_p2_size} sectors; p3 KERN-B at ${p3_start} (+${KERNB_SECTORS})"
echo "btrfs: resizing to $((btrfs_bytes / 1024 / 1024)) MiB"

btrfs filesystem resize "1:${btrfs_bytes}" /
sync
dev_bytes=$(btrfs filesystem show --raw / | awk '/devid +1 /{print $4}')
(( dev_bytes <= btrfs_bytes )) || { echo "btrfs did not shrink ($dev_bytes)" >&2; exit 1; }

sgdisk --backup="/root/mmcblk1-gpt-before-kernb.bin" "$DISK" >/dev/null
cgpt add -i 2 -s "$new_p2_size" "$DISK"
resizepart "$DISK" 2 "$new_p2_size"
cgpt add -i 3 -b "$p3_start" -s "$KERNB_SECTORS" -t kernel -l KERN-B -S 0 -T 0 -P 0 "$DISK"
partx -a --nr 3 "$DISK" 2>/dev/null || partx -u --nr 3 "$DISK"
udevadm settle

[[ $(cat /sys/class/block/mmcblk1p2/size) == "$new_p2_size" ]] || { echo "kernel still sees old p2 size" >&2; exit 1; }
[[ -b ${DISK}p3 ]] || { echo "${DISK}p3 did not appear" >&2; exit 1; }
cgpt show "$DISK"
echo "KERN-B ready. GPT backup: /root/mmcblk1-gpt-before-kernb.bin"
