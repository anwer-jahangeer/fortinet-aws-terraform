variable "aws_region" {
  description = "AWS region in which to deploy the lab."
  type        = string
  default     = "us-east-2"
}

variable "availability_zone" {
  description = "Availability Zone for all lab subnets and instances."
  type        = string
  default     = "us-east-2a"
}

variable "name_prefix" {
  description = "Prefix applied to every AWS resource."
  type        = string
  default     = "forti"
}

variable "tags" {
  description = "Tags applied to all taggable resources."
  type        = map(string)
  default = {
    Environment = "test"
    Lab         = "fortigate-sdwan"
    ManagedBy   = "terraform"
  }
}

variable "vpc_cidr" {
  description = "CIDR for the AWS lab VPC. All FortiGate ENIs must be in one VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_cidrs" {
  description = "Subnet address plan for management, site LANs, six ISP circuits, Debian egress, and MPLS."
  type        = map(string)
  default = {
    management      = "10.10.252.0/24"
    hub1_lan        = "10.10.20.0/24"
    hub2_lan        = "10.10.30.0/24"
    branch1_lan     = "10.10.10.0/24"
    hub1_isp1       = "10.10.111.0/24"
    hub2_isp1       = "10.10.112.0/24"
    branch1_isp1    = "10.10.113.0/24"
    hub1_wan2       = "10.10.101.0/24"
    hub2_wan2       = "10.10.102.0/24"
    branch1_wan2    = "10.10.103.0/24"
    internet_egress = "10.10.121.0/24"
    mpls            = "10.10.200.0/24"
  }

  validation {
    condition = length(var.subnet_cidrs) == 12 && alltrue([
      for required_key in [
        "management",
        "hub1_lan",
        "hub2_lan",
        "branch1_lan",
        "hub1_isp1",
        "hub2_isp1",
        "branch1_isp1",
        "hub1_wan2",
        "hub2_wan2",
        "branch1_wan2",
        "internet_egress",
        "mpls",
      ] : contains(keys(var.subnet_cidrs), required_key)
    ])
    error_message = "subnet_cidrs must define every management, LAN, ISP1, ISP2, internet_egress, and MPLS subnet."
  }
}

variable "admin_ingress_cidrs" {
  description = "Trusted public CIDRs allowed to reach the Windows jumpbox. Replace the lab default with your public IP/32."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "wan_ingress_cidrs" {
  description = "Peer public CIDRs allowed to reach FortiGate WAN interfaces for IPsec and ICMP."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_username" {
  description = "FortiGate administrator configured by the bootstrap configuration."
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "FortiGate administrator password for this isolated lab. Supply it through the ignored terraform.tfvars file."
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key used to create the EC2 key pair."
  type        = string
}

variable "fortigate_ami_id" {
  description = "Subscribed FortiGate BYOL Marketplace AMI ID for aws_region."
  type        = string
}

variable "fortigate_instance_type" {
  description = "EC2 instance type for each four-interface FortiGate."
  type        = string
  default     = "c5.2xlarge"
}

variable "internet_router_instance_type" {
  description = "Debian virtual internet router type. It must support at least seven ENIs."
  type        = string
  default     = "c5.4xlarge"
}

variable "jumpbox_instance_type" {
  description = "EC2 instance type for the Windows management jumpbox."
  type        = string
  default     = "t3.medium"
}

variable "inside_instance_type" {
  description = "EC2 instance type for Linux traffic-generation hosts."
  type        = string
  default     = "t3.small"
}
