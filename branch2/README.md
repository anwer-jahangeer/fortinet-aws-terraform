# Licensed Branch2 independent Terraform stack

This stack replaces the earlier evaluation Branch2 FortiGate with a licensed
four-interface FortiGate while keeping the original Terraform state untouched.
Existing VPC, WAN and MPLS subnets, security groups, key pair, LAN route tables,
and FortiGate LAN ENIs are read through data sources.

The stack manages only:

- Branch2 LAN subnet and route table
- Four Branch2 ENIs
- Branch2 FortiGate instance
- Branch2 Ubuntu test host with LAN and management ENIs
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
./scripts/plan-safe.sh --replace-fortigate branch2.tfplan
terraform apply branch2.tfplan
```

The safe-plan script requires `jq`. Pass `--replace-fortigate` only when the
FortiGate must be replaced; ordinary additions use a normal non-destructive
plan. It refuses any destructive action other than the explicitly requested
Branch2 FortiGate replacement.

The replacement instance uses `c5.2xlarge` by default to match Hub1, Hub2, and
Branch1 and to support four ENIs. Confirm that the genuine FortiGate license
entitlement supports the required CPU count before applying.

If `terraform.tfvars` was copied from the evaluation deployment, update its
explicit override before planning:

```hcl
fortigate_instance_type = "c5.2xlarge"
```

The stack validates the selected EC2 type through AWS and stops before apply
when it supports fewer than four ENIs. If an apply already destroyed the old
VM before failing, rerun `plan-safe.sh`; it detects the missing instance and
creates the licensed VM without requiring another replacement.

## Branch2 test host

The stack creates an Ubuntu test host matching the existing site pattern:

| Interface | Address | Purpose |
|---|---:|---|
| Primary LAN ENI | `10.10.40.6` | Test traffic through Branch2 port2 |
| Secondary management ENI | `10.10.252.34` | Direct SSH from the jumpbox |

Create it without replacing the FortiGate:

```bash
./scripts/plan-safe.sh branch2-inside.tfplan
terraform apply branch2-inside.tfplan
terraform output inside_host_private_ips
```

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
