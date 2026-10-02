# Licensed Branch2 independent Terraform stack

This stack deploys a licensed four-interface Branch2 FortiGate, a matching
Ubuntu test host, and two dedicated AWS ISP subnets without changing Hub1,
Hub2, Branch1, or their public addresses.

## Topology

| Component | Address | Routing path |
|---|---:|---|
| Branch2 port1 / ISP1 | `10.10.114.20/24` | Dedicated Debian ENI `10.10.114.254` |
| Branch2 port2 / LAN | `10.10.40.20/24` | Branch2 protected LAN |
| Branch2 port3 / ISP2 | `10.10.104.21/24` | AWS route table targets Debian ENI 0 |
| Branch2 port4 / MPLS | `10.10.200.24/24` | Existing private MPLS subnet |
| Branch2 test VM LAN | `10.10.40.6/24` | Primary interface through port2 |
| Branch2 test VM management | `10.10.252.34/24` | Secondary interface from jumpbox |
| ISP1 private NAT address | `10.10.121.16` | Secondary address on Debian ENI 0 |
| ISP2 private NAT address | `10.10.121.17` | Secondary address on Debian ENI 0 |

Debian currently uses device indexes 0 through 6. Branch2 ISP1 consumes the
final `c5.4xlarge` attachment slot at device index 7. Branch2 ISP2 has its own
subnet and route table but targets Debian ENI 0, which remains the shared
outside interface for every site's internet traffic.

## Prerequisites

1. Back up the current Branch2 FortiGate configuration.
2. Ensure the genuine FortiGate license can be rehosted to the replacement VM.
3. Set `admin_password` and `fortigate_ami_id` in `branch2/terraform.tfvars`.
   Remove any old overrides that still set port1 to `10.10.113.21` or port3
   to `10.10.102.22`; both addresses must use the new dedicated subnets.
4. Confirm the selected FortiGate instance type supports four ENIs.
5. Install `jq` in AWS CloudShell.

## Stage 1: reserve Branch2 NAT addresses

Run this from the repository root using the main Terraform state:

```bash
git pull origin replace-branch2-with-licensed
terraform init
./scripts/plan-branch2-nat-ips-safe.sh branch2-nat-ips.tfplan
terraform apply branch2-nat-ips.tfplan
```

The accepted plan updates only
`aws_network_interface.internet_router_outside`, adding `10.10.121.16` and
`10.10.121.17`. It must not replace `aws_instance.internet_router`. The main
instance resource ignores additive network-interface attachments so future
main-stack refreshes preserve Branch2's eighth Debian ENI.

## Stage 2: migrate Branch2

Run this from the independent Branch2 state:

```bash
cd branch2
terraform init
./scripts/plan-safe.sh --migrate-isps branch2-isp-migration.tfplan
terraform apply branch2-isp-migration.tfplan
```

Expected destructive actions are limited to:

- `aws_instance.fortigate`
- `aws_network_interface.port1`
- `aws_network_interface.port3`

The LAN, MPLS ENI, Branch2 test host, Hub1, Hub2, Branch1, Debian EC2 instance,
and all existing public addresses must remain unchanged.

The apply creates:

- Dedicated Branch2 ISP1 and ISP2 subnets and route tables
- Final Debian ENI at device index 7 for ISP1
- Two new EIPs associated with `.16` and `.17` on Debian ENI 0
- Internal underlay routes between Branch2 and every existing ISP circuit
- Replacement Branch2 FortiGate on the new ISP subnets

## Stage 3: configure Debian

Display the required MAC addresses:

```bash
terraform output debian_branch2_configuration
```

Copy these files to Debian:

```text
scripts/configure-debian.sh
scripts/set-branch2-isp2-netem.sh
scripts/clear-branch2-isp2-netem.sh
```

On the Debian router, run the configuration script with the two MAC addresses
from the Terraform output:

```bash
sudo bash configure-debian.sh \
  <isp1_eni_mac> <outside_eni_mac> <isp1_public_ip> <isp2_public_ip>
sudo install -m 0755 set-branch2-isp2-netem.sh /usr/local/sbin/
sudo install -m 0755 clear-branch2-isp2-netem.sh /usr/local/sbin/
```

Validate:

```bash
sudo systemctl status fortinet-branch2
ip address show
ip route show
sudo nft list set inet filter wan_clients
sudo nft list table ip branch2_nat
```

## Scoped ISP2 impairment

Do not apply an unfiltered root netem directly to Debian ENI 0 because it is
shared by all sites. Use the provided helper, which classifies Branch2 ISP2 by
`10.10.104.21` and `10.10.121.17`:

```bash
sudo set-branch2-isp2-netem.sh delay 100ms 20ms loss 2%
sudo tc -s qdisc show
sudo clear-branch2-isp2-netem.sh
```

ISP1 uses a dedicated Debian ENI and can be impaired independently with a
normal interface-level netem rule.

## FortiManager values

| Variable | Value |
|---|---:|
| `site_name` | `branch2` |
| `port1_ip` | `10.10.114.20` |
| `port1_gateway` | `10.10.114.1` |
| `port2_ip` | `10.10.40.20` |
| `port3_ip` | `10.10.104.21` |
| `port3_gateway` | `10.10.104.1` |
| `port4_ip` | `10.10.200.24` |

Update Branch2's SD-WAN members, ADVPN templates, BGP router ID/metadata, and
public tunnel endpoints before installing the policy package.

## License installation

After the replacement VM boots, enable SCP temporarily and upload the rehosted
license to the new management address:

```powershell
pscp.exe -scp .\branch2.lic admin@10.10.114.20:vmlicense
```

Validate after the automatic reboot:

```text
get system status
diagnose hardware sysinfo vm full
diagnose debug vm-print-license
```
