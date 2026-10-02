#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root on the Debian internet router." >&2
    exit 1
fi

# shellcheck disable=SC1091
source /etc/default/fortinet-branch2

outside_interface=$(
    ip -o link show |
        awk -v mac="$OUTSIDE_MAC" 'tolower($0) ~ tolower(mac) {gsub(/:/, "", $2); print $2; exit}'
)

tc qdisc del dev "$outside_interface" ingress 2>/dev/null || true
tc qdisc del dev "$outside_interface" root 2>/dev/null || true
tc qdisc del dev ifb-branch2-isp2 root 2>/dev/null || true
ip link set dev ifb-branch2-isp2 down 2>/dev/null || true
ip link delete ifb-branch2-isp2 type ifb 2>/dev/null || true

echo "Branch2 ISP2 impairment cleared."
