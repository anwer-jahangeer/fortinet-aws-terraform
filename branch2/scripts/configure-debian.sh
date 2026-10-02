#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root on the existing Debian internet router." >&2
    exit 1
fi

config_file=/etc/default/fortinet-branch2

if [ "$#" -eq 4 ]; then
    install -d -m 0755 /etc/default
    cat >"$config_file" <<EOF
BRANCH2_ISP1_MAC=$1
OUTSIDE_MAC=$2
BRANCH2_ISP1_PUBLIC_IP=$3
BRANCH2_ISP2_PUBLIC_IP=$4
EOF
fi

if [ ! -f "$config_file" ]; then
    echo "Usage: sudo bash configure-debian.sh <isp1-mac> <outside-mac> <isp1-eip> <isp2-eip>" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$config_file"

find_interface() {
    local mac=$1
    ip -o link show |
        awk -v mac="$mac" 'tolower($0) ~ tolower(mac) {gsub(/:/, "", $2); print $2; exit}'
}

isp1_interface=$(find_interface "$BRANCH2_ISP1_MAC")
outside_interface=$(find_interface "$OUTSIDE_MAC")

if [ -z "$isp1_interface" ] || [ -z "$outside_interface" ]; then
    echo "Unable to identify the Branch2 ISP1 or outside interface." >&2
    exit 1
fi

ip link set dev "$isp1_interface" up
ip address replace 10.10.114.254/24 dev "$isp1_interface"
ip address replace 10.10.121.16/24 dev "$outside_interface"
ip address replace 10.10.121.17/24 dev "$outside_interface"
ip route replace 10.10.104.0/24 via 10.10.121.1 dev "$outside_interface"

sysctl -w "net.ipv4.conf.$isp1_interface.rp_filter=0" >/dev/null
sysctl -w "net.ipv4.conf.$outside_interface.rp_filter=0" >/dev/null

if ! nft list set inet filter wan_clients >/dev/null 2>&1; then
    echo "The base fortinet-internet-router nftables configuration is not loaded." >&2
    exit 1
fi

nft add element inet filter wan_clients '{ 10.10.114.20, 10.10.104.21 }' 2>/dev/null || true
nft delete element inet filter wan_clients '{ 10.10.113.21, 10.10.102.22 }' 2>/dev/null || true

while read -r handle; do
    [ -n "$handle" ] && nft delete rule inet filter forward handle "$handle"
done < <(
    nft -a list chain inet filter forward |
        awk '/comment "branch2-underlay"/ {for (i=1; i<=NF; i++) if ($i=="handle") print $(i+1)}'
)

nft insert rule inet filter forward \
    ip saddr @wan_clients ip daddr @wan_clients \
    accept comment '"branch2-underlay"'

nft delete table ip branch2_nat 2>/dev/null || true
nft -f - <<NFTABLES
table ip branch2_nat {
    chain prerouting {
        type nat hook prerouting priority dstnat;
        policy accept;

        ip daddr { 10.10.121.16, $BRANCH2_ISP1_PUBLIC_IP } udp dport { 500, 4500 } dnat to 10.10.114.20
        ip daddr { 10.10.121.16, $BRANCH2_ISP1_PUBLIC_IP } ip protocol esp dnat to 10.10.114.20
        ip daddr { 10.10.121.16, $BRANCH2_ISP1_PUBLIC_IP } icmp type echo-request dnat to 10.10.114.20

        ip daddr { 10.10.121.17, $BRANCH2_ISP2_PUBLIC_IP } udp dport { 500, 4500 } dnat to 10.10.104.21
        ip daddr { 10.10.121.17, $BRANCH2_ISP2_PUBLIC_IP } ip protocol esp dnat to 10.10.104.21
        ip daddr { 10.10.121.17, $BRANCH2_ISP2_PUBLIC_IP } icmp type echo-request dnat to 10.10.104.21
    }

    chain postrouting {
        type nat hook postrouting priority srcnat;
        policy accept;

        ct status dnat ip saddr 10.10.114.20 snat to $BRANCH2_ISP1_PUBLIC_IP
        ct status dnat ip saddr 10.10.104.21 snat to $BRANCH2_ISP2_PUBLIC_IP
        ip saddr 10.10.114.20 snat to 10.10.121.16
        ip saddr 10.10.104.21 snat to 10.10.121.17
    }
}
NFTABLES

installed_script=/usr/local/sbin/configure-fortinet-branch2

if [ "$(readlink -f "$0")" != "$installed_script" ]; then
    install -d -m 0755 /usr/local/sbin
    install -m 0755 "$0" "$installed_script"

    cat >/etc/systemd/system/fortinet-branch2.service <<'UNIT'
[Unit]
Description=Configure dedicated Branch2 ISP routing and NAT
Wants=fortinet-internet-router.service
After=fortinet-internet-router.service
PartOf=fortinet-internet-router.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/configure-fortinet-branch2
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
    systemctl daemon-reload
    systemctl enable fortinet-branch2.service
    systemctl restart fortinet-branch2.service
fi

echo "Branch2 ISP1 and ISP2 routing/NAT are active."
