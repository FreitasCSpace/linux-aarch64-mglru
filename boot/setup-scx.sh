#!/bin/bash
# Installs scx_lavd (sched_ext desktop-latency scheduler) and starts it at boot
# via scx_loader. Also refreshes the installed kernel-mglru-pack.
# On a kernel without sched_ext (stock KERN-A fallback) scx_loader simply fails
# to attach the scheduler and the default kernel scheduler keeps running.
# Undo: systemctl disable --now scx_loader
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root" >&2; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)

install -m755 "$here/kernel-mglru-pack" /usr/local/bin/kernel-mglru-pack
pacman -S --needed --noconfirm scx-scheds scx-tools

install -d /etc/scx_loader
cat >/etc/scx_loader/config.toml <<'EOF'
# scx_lavd: latency-criticality aware scheduler (built for interactive/gaming
# use, understands big.LITTLE). Auto mode picks its behaviour from load.
default_sched = "scx_lavd"
default_mode = "Auto"
EOF

systemctl enable scx_loader.service
if [[ -e /sys/kernel/sched_ext/state ]]; then
  systemctl restart scx_loader.service
  sleep 2
  echo "sched_ext state: $(cat /sys/kernel/sched_ext/state) ($(cat /sys/kernel/sched_ext/root/ops 2>/dev/null))"
else
  echo "This kernel has no sched_ext; scx_lavd will start on the next MGLRU kernel boot."
fi
