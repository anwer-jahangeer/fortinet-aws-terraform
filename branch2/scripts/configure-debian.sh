#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root on the existing Debian internet router." >&2
    exit 1
fi

if ! nft list set inet filter wan_clients >/dev/null 2>&1; then
    echo "The base fortinet-internet-router nftables configuration is not loaded." >&2
    exit 1
fi

nft add element inet filter wan_clients '{ 10.10.113.21, 10.10.102.22 }' 2>/dev/null || true
nft delete table ip branch2_nat 2>/dev/null || true

nft -f - <<'NFTABLES'
table ip branch2_nat {
    chain postrouting {
        type nat hook postrouting priority srcnat;
        policy accept;

        ip saddr 10.10.113.21 snat to 10.10.121.14
        ip saddr 10.10.102.22 snat to 10.10.121.13
    }
}
NFTABLES

installed_script=/usr/local/sbin/configure-fortinet-branch2

if [ "$(readlink -f "$0")" != "$installed_script" ]; then
    install -d -m 0755 /usr/local/sbin
    install -m 0755 "$0" "$installed_script"

    cat >/etc/systemd/system/fortinet-branch2.service <<'UNIT'
[Unit]
Description=Authorize Branch2 through the existing Fortinet Debian router
Wants=fortinet-internet-router.service
After=fortinet-internet-router.service

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

echo "Branch2 is authorized through the existing Branch1 ISP1 and Hub2 ISP2 NAT identities."
