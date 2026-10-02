#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root on the Debian internet router." >&2
    exit 1
fi

if [ "$#" -eq 0 ]; then
    echo "Usage: sudo set-branch2-isp2-netem.sh delay 100ms [20ms] [loss 1%]" >&2
    exit 1
fi

# shellcheck disable=SC1091
source /etc/default/fortinet-branch2

outside_interface=$(
    ip -o link show |
        awk -v mac="$OUTSIDE_MAC" 'tolower($0) ~ tolower(mac) {gsub(/:/, "", $2); print $2; exit}'
)

if [ -z "$outside_interface" ]; then
    echo "Unable to identify Debian ENI 0." >&2
    exit 1
fi

modprobe ifb
ip link add ifb-branch2-isp2 type ifb 2>/dev/null || true
ip link set dev ifb-branch2-isp2 up

tc qdisc replace dev ifb-branch2-isp2 root netem "$@"
tc qdisc replace dev "$outside_interface" handle ffff: ingress
tc filter replace dev "$outside_interface" parent ffff: protocol ip priority 104 \
    flower src_ip 10.10.104.21 \
    action mirred egress redirect dev ifb-branch2-isp2
tc filter replace dev "$outside_interface" parent ffff: protocol ip priority 105 \
    flower dst_ip 10.10.121.17 \
    action mirred egress redirect dev ifb-branch2-isp2

tc qdisc replace dev "$outside_interface" root handle 1: prio bands 3
tc qdisc replace dev "$outside_interface" parent 1:3 handle 30: netem "$@"
tc filter replace dev "$outside_interface" parent 1: protocol ip priority 104 \
    flower dst_ip 10.10.104.21 flowid 1:3
tc filter replace dev "$outside_interface" parent 1: protocol ip priority 105 \
    flower src_ip 10.10.121.17 flowid 1:3

echo "Branch2 ISP2 impairment enabled on $outside_interface: $*"
