# Branch2 independent Terraform stack

This stack adds a three-interface Branch2 FortiGate while keeping the original
Terraform state untouched. Existing VPC, WAN subnets, security groups, key
pair, LAN route tables, and FortiGate LAN ENIs are read through data sources.

The stack manages only:

- Branch2 LAN subnet and route table
- Three Branch2 ENIs
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

Branch2 shares the current Branch1 ISP1 and Hub2 ISP2 Debian NAT identities.
It should initiate IPsec tunnels; unsolicited IKE/IPsec traffic to those public
addresses continues to DNAT to the original Branch1 and Hub2 FortiGates.

## Deploy safely

```bash
cd branch2
cp terraform.tfvars.example terraform.tfvars
# Set admin_password and fortigate_ami_id.

terraform init
./scripts/plan-safe.sh branch2.tfplan
terraform apply branch2.tfplan
```

The safe-plan script requires `jq` and refuses to continue when Terraform
reports any delete or replacement action. The accepted plan must contain only
Branch2 creates and additive routes.

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

## Evaluation-license check

The permanent evaluation license permits one CPU, 2 GiB RAM, three interfaces,
three firewall policies, and three routes. `t3.small` provides three ENIs and
2 GiB RAM but exposes two vCPUs, so activation may fail.

```text
get system status
diagnose hardware sysinfo vm full
diagnose debug vm-print-license
```

If activation fails, do not resize this three-ENI instance directly to
`t2.small`. First change the stack to a two-interface design and remove port3,
then plan and apply the resize.
