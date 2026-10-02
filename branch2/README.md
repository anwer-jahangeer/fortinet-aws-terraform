# Licensed Branch2 independent Terraform stack

This stack replaces the earlier evaluation Branch2 FortiGate with a licensed
four-interface FortiGate while keeping the original Terraform state untouched.
Existing VPC, WAN and MPLS subnets, security groups, key pair, LAN route tables,
and FortiGate LAN ENIs are read through data sources.

The stack manages only:

- Branch2 LAN subnet and route table
- Four Branch2 ENIs
- Branch2 FortiGate instance
- Additive routes between Branch2 and the existing site LANs

It does not manage or modify the Debian EC2 instance, its ENIs, its instance
type, its user data, or the existing FortiGate instances.

## Interface plan

| Port | Address | Segment |
|---|---:|---|
| port1 | `10.10.113.21` | Existing Branch1 ISP1 |
| port2 | `10.10.40.20` | New Branch2 LAN |
| port3 | `10.10.102.22` | Existing Hub2 ISP2 |
| port4 | `10.10.200.24` | Existing shared MPLS |

Branch2 shares the current Branch1 ISP1 and Hub2 ISP2 Debian NAT identities.
It should initiate IPsec tunnels; unsolicited IKE/IPsec traffic to those public
addresses continues to DNAT to the original Branch1 and Hub2 FortiGates.

## Replace the evaluation VM safely

```bash
cd branch2
cp terraform.tfvars.example terraform.tfvars
# Set admin_password and the subscribed BYOL fortigate_ami_id.

terraform init
./scripts/plan-safe.sh branch2.tfplan
terraform apply branch2.tfplan
```

The safe-plan script requires `jq`, explicitly plans
`-replace=aws_instance.fortigate`, and refuses to continue unless the old
Branch2 FortiGate is the only resource being deleted. The Branch2 subnet,
routes, and existing ENIs are retained; the new MPLS ENI is added.

The replacement instance uses `c5.2xlarge` by default to match Hub1, Hub2, and
Branch1 and to support four ENIs. Confirm that the genuine FortiGate license
entitlement supports the required CPU count before applying.

After apply, copy `scripts/configure-debian.sh` to the existing Debian router
and run it as root:

```bash
sudo bash configure-debian.sh
sudo systemctl status fortinet-branch2
sudo nft list set inet filter wan_clients
sudo nft list table ip branch2_nat
```

This installs a separate systemd unit and nftables NAT table. It does not
rewrite the existing Debian router configuration.

## Install and validate the license

After the replacement VM boots, upload the genuine `.lic` file to the special
SCP destination from a trusted Windows host. A successful installation reboots
the FortiGate:

```powershell
pscp.exe -scp .\branch2.lic admin@10.10.113.21:vmlicense
```

Enable `admin-scp` temporarily before the upload and disable it after license
installation. Then validate:

```text
get system status
diagnose hardware sysinfo vm full
diagnose debug vm-print-license
```
