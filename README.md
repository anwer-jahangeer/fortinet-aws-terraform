# FortiGate SD-WAN Lab on AWS

This Terraform stack recreates the GCP lab on AWS: two FortiGate hubs, one
FortiGate branch, two independent internet underlays, a shared private MPLS
underlay, one LAN per site, FortiManager, FortiAnalyzer, a Windows jumpbox, and
one Ubuntu test host behind each firewall.

## AWS topology

AWS requires every ENI attached to an EC2 instance to be in the same VPC.
Consequently, the GCP VPC-per-segment design is represented by isolated subnets
and route tables within one `10.10.0.0/16` VPC.

| Segment | CIDR | Purpose |
|---|---:|---|
| management | `10.10.252.0/24` | FortiGate port1/ISP1, FMG, FAZ, jumpbox |
| hub1 LAN | `10.10.20.0/24` | Hub 1 protected network |
| hub2 LAN | `10.10.30.0/24` | Hub 2 protected network |
| branch1 LAN | `10.10.10.0/24` | Branch 1 protected network |
| hub1 ISP2 | `10.10.101.0/24` | Hub 1 second internet underlay |
| hub2 ISP2 | `10.10.102.0/24` | Hub 2 second internet underlay |
| branch1 ISP2 | `10.10.103.0/24` | Branch 1 second internet underlay |
| MPLS | `10.10.200.0/24` | Shared private transport |

Each FortiGate has four ENIs in FortiOS order:

| FortiOS port | AWS segment | Function |
|---|---|---|
| port1 | management | Management and ISP1, with Elastic IP |
| port2 | site LAN | Protected LAN and LAN default-route target |
| port3 | site ISP2 | Second internet path, with Elastic IP |
| port4 | MPLS | Shared private underlay |

Source/destination checks are disabled on all FortiGate ENIs. Each LAN route
table sends `0.0.0.0/0` to its local FortiGate port2 ENI. Management and ISP2
subnets use the Internet Gateway; MPLS has no internet default route.
More-specific routes for the other site LANs also point to the local FortiGate,
overriding the VPC's implicit `/16` local route so inter-site test traffic
cannot bypass the SD-WAN overlay.

## Prerequisites

1. Terraform 1.5 or later and AWS credentials with EC2, VPC, IAM-free EC2 key
   pair, and SSM read permissions.
2. Accept the FortiGate BYOL, FortiManager BYOL, and FortiAnalyzer BYOL offers
   in AWS Marketplace.
3. Find the regional AMI ID for each subscribed product. FortiManager and
   FortiAnalyzer must be the same or a newer release than FortiGate.
4. Ensure the chosen FortiGate instance type supports at least four ENIs.

## Deploy

```powershell
git clone https://github.com/anwer-jahangeer/fortinet-aws-terraform.git
Set-Location "fortinet-aws-terraform"
Copy-Item terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with trusted CIDRs, lab password, public key, and AMI IDs.

terraform init
terraform plan -out forti.tfplan
terraform apply forti.tfplan
```

The three FortiGates are bootstrapped with username `admin` and the
`admin_password` supplied in the ignored `terraform.tfvars` file. The default
administrative CIDR in the example is documentation-only; replace it with your
public IP in `/32` form before deployment. The password is stored in Terraform
state, so use this credential only for an isolated, disposable lab and protect
the state file.

FortiManager and FortiAnalyzer AWS images do not provide a documented
user-data method for replacing their initial password. Their first login is
therefore `admin / <EC2 instance ID>`. Run
`terraform output -json fortinet_initial_logins` to display all initial
credentials, then change the FMG and FAZ admin passwords to the same lab
password after the first login. The Windows jumpbox continues to use its
AWS-generated administrator password.

After deployment, use `terraform output fortigate_public_ips` for the ISP1/ISP2
tunnel endpoints and `terraform output management_public_ips` for FMG, FAZ, and
the jumpbox. Retrieve the Windows password with the emitted
`windows_password_command`.

## FortiManager onboarding

License the three FortiGates, FortiManager, and FortiAnalyzer first. In
FortiManager, add the FortiGates by their port1 private IPs and assign hub/edge
roles:

- `forti-hub1-fgt`: hub
- `forti-hub2-fgt`: hub
- `forti-branch1-fgt`: edge/spoke

Use port1 and port3 as internet underlays and port4 as MPLS in the SD-WAN
overlay template. Direct inter-subnet connectivity inside an AWS VPC is not a
security boundary, so the security groups intentionally permit only required
public ingress while allowing lab traffic internally; FortiGate policy remains
responsible for forwarded site traffic.

## Cost and cleanup

The default stack runs three `c5.2xlarge` FortiGates, two `m5.2xlarge`
management appliances, a Windows host, three Linux hosts, and nine Elastic IPs.
Review current regional pricing and Elastic IP charges before deployment.

```powershell
terraform destroy
```
