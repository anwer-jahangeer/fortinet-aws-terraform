# FortiGate SD-WAN Lab on AWS

This Terraform stack recreates the GCP lab on AWS: two FortiGate hubs, one
FortiGate branch, two independent internet underlays, a shared private MPLS
underlay, one LAN per site, a Windows jumpbox, one Ubuntu test host behind each
firewall, and one Debian virtual internet gateway hosting all six ISP circuits.

## AWS topology

AWS requires every ENI attached to an EC2 instance to be in the same VPC.
Consequently, the GCP VPC-per-segment design is represented by isolated subnets
and route tables within one `10.10.0.0/16` VPC.

| Segment | CIDR | Purpose |
|---|---:|---|
| management | `10.10.252.0/24` | Jumpbox and test-VM management |
| hub1 LAN | `10.10.20.0/24` | Hub 1 protected network |
| hub2 LAN | `10.10.30.0/24` | Hub 2 protected network |
| branch1 LAN | `10.10.10.0/24` | Branch 1 protected network |
| hub1 ISP1 | `10.10.111.0/24` | Hub 1 port1 and Debian |
| hub2 ISP1 | `10.10.112.0/24` | Hub 2 port1 and Debian |
| branch1 ISP1 | `10.10.113.0/24` | Branch 1 port1 and Debian |
| hub1 ISP2 | `10.10.101.0/24` | Hub 1 second internet underlay |
| hub2 ISP2 | `10.10.102.0/24` | Hub 2 second internet underlay |
| branch1 ISP2 | `10.10.103.0/24` | Branch 1 second internet underlay |
| internet egress | `10.10.121.0/24` | Debian outside ENI and six EIPs |
| MPLS | `10.10.200.0/24` | Shared private transport |

Each FortiGate has four ENIs in FortiOS order:

| FortiOS port | AWS segment | Function |
|---|---|---|
| port1 | site ISP1 | ISP1 and private management through jumpbox |
| port2 | site LAN | Protected LAN and LAN default-route target |
| port3 | site ISP2 | Second private internet path |
| port4 | MPLS | Shared private underlay |

FortiGate WAN ENIs have no public IPs. Their default routes target one of six
inside ENIs on the Debian router. Debian performs persistent `nftables`
SNAT/DNAT and sends internet traffic from its outside ENI through the AWS
Internet Gateway. The six existing EIPs are preserved and reassociated with
six private addresses on that outside ENI.

| Circuit | FortiGate IP | Debian inside IP | Debian outside IP |
|---|---:|---:|---:|
| Hub1 ISP1 | `10.10.111.20` | `10.10.111.254` | `10.10.121.10` |
| Hub1 ISP2 | `10.10.101.21` | `10.10.101.254` | `10.10.121.11` |
| Hub2 ISP1 | `10.10.112.20` | `10.10.112.254` | `10.10.121.12` |
| Hub2 ISP2 | `10.10.102.21` | `10.10.102.254` | `10.10.121.13` |
| Branch1 ISP1 | `10.10.113.20` | `10.10.113.254` | `10.10.121.14` |
| Branch1 ISP2 | `10.10.103.21` | `10.10.103.254` | `10.10.121.15` |

Each Ubuntu test VM has two ENIs:

| VM | Primary LAN address | Secondary management address |
|---|---:|---:|
| hub1 inside | `10.10.20.6` | `10.10.252.31` |
| hub2 inside | `10.10.30.6` | `10.10.252.32` |
| branch1 inside | `10.10.10.6` | `10.10.252.33` |

The LAN ENI remains the primary interface so application and SD-WAN test
traffic follows the local FortiGate. Use the secondary management address to
SSH directly from the Windows jumpbox without crossing a FortiGate.

Source/destination checks are disabled on all FortiGate ENIs. Each LAN route
table sends `0.0.0.0/0` to its local FortiGate port2 ENI. Only the management
and Debian internet-egress subnets route directly to the AWS Internet Gateway;
all six ISP subnets route through Debian, and MPLS has no internet default.
More-specific routes for the other site LANs also point to the local FortiGate,
overriding the VPC's implicit `/16` local route so inter-site test traffic
cannot bypass the SD-WAN overlay.

## Prerequisites

1. Terraform 1.5 or later and AWS credentials with EC2, VPC, IAM-free EC2 key
   pair, and SSM read permissions.
2. Accept the FortiGate BYOL offer in AWS Marketplace.
3. Find the FortiGate AMI ID for the selected AWS region.
4. Ensure the chosen FortiGate instance type supports at least four ENIs.
5. Ensure the Debian router instance type supports at least seven ENIs. The
   default is `c5.4xlarge`.

## Deploy

From AWS CloudShell:

```bash
git clone https://github.com/anwer-jahangeer/fortinet-aws-terraform.git
cd fortinet-aws-terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with trusted CIDRs, lab password, public key, and AMI ID.

terraform init
terraform plan -out forti.tfplan
terraform apply forti.tfplan
```

> **Existing deployment warning:** Moving FortiGate port1 from the shared
> management subnet into dedicated ISP1 subnets replaces all three FortiGate
> instances. Back up FortiOS configuration and license information before
> applying this revision. The EIP `moved` blocks preserve the six public IPs.

The three FortiGates are bootstrapped with username `admin` and the
`admin_password` supplied in the ignored `terraform.tfvars` file. The default
administrative CIDR in the example is documentation-only; replace it with your
public IP in `/32` form before deployment. The password is stored in Terraform
state, so use this credential only for an isolated, disposable lab and protect
the state file.

Run `terraform output -json fortinet_initial_logins` to display the FortiGate
credential. The Windows jumpbox uses its AWS-generated administrator password.

After deployment, use `terraform output fortigate_public_ips` for the ISP1/ISP2
tunnel endpoints and `terraform output jumpbox_public_ip` for the jumpbox.
Retrieve the Windows password with the emitted `windows_password_command`.
Run `terraform output inside_host_private_ips` for both LAN and management
addresses of the Ubuntu test hosts.

RDP to the jumpbox and manage the FortiGates using their private port1 IPs:

| Device | Management URL |
|---|---|
| Hub1 | `https://10.10.111.20` |
| Hub2 | `https://10.10.112.20` |
| Branch1 | `https://10.10.113.20` |

From the jumpbox, the Debian router is reachable by SSH as
`admin@10.10.121.10`. Validate its bootstrap with:

```bash
cloud-init status --wait
sudo systemctl status fortinet-internet-router
sudo nft list ruleset
sysctl net.ipv4.ip_forward
```

Configure the FortiGate hub-and-spoke SD-WAN overlay directly on the three
FortiGates: port1 and port3 are internet underlays, and port4 is MPLS.

## FortiManager interface provisioning

The `fortimanager` directory contains one reusable FortiManager 7.6 Jinja CLI
template and the exact per-device metadata values:

- `fortimanager/aws-interface-template.j2`
- `fortimanager/device-metadata.csv`
- `fortimanager/README.md`

The template configures all four interfaces, ISP1 primary routing, ISP2 backup
routing, and a dedicated jumpbox management route. Preview and install it on
Branch1 first before assigning it to both hubs.

## Cost and cleanup

The default stack runs three `c5.2xlarge` FortiGates, one `c5.4xlarge` Debian
router, a Windows host, three Linux hosts, and seven Elastic IPs. Review current
regional pricing, vCPU quota, ENI limits, and Elastic IP charges before
deployment.

## Partial-apply recovery

EIP allocation and association are separate resources so preserved allocations
can be cleanly disassociated from replaced instances and reassociated with
Debian. If an earlier interrupted apply created an ENI without recording it in
state, locate it by its fixed address and import it before applying again:

```bash
aws ec2 describe-network-interfaces \
  --region us-east-2 \
  --filters Name=addresses.private-ip-address,Values=10.10.252.32 \
  --query 'NetworkInterfaces[*].{ID:NetworkInterfaceId,Status:Status,Instance:Attachment.InstanceId,Name:TagSet[?Key==`Name`]|[0].Value}' \
  --output table

terraform import \
  'aws_network_interface.inside_management["hub2"]' \
  eni-REPLACE_WITH_RESULT
```

Import only when the returned ENI is the expected
`forti-hub2-inside-management` interface. If it belongs to another resource,
resolve that address conflict rather than importing it.

```bash
terraform destroy
```
