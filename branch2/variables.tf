variable "aws_region" {
  description = "AWS region containing the existing Fortinet lab."
  type        = string
  default     = "us-east-2"
}

variable "availability_zone" {
  description = "Availability Zone used by the existing lab."
  type        = string
  default     = "us-east-2a"
}

variable "name_prefix" {
  description = "Prefix used by the existing lab resources."
  type        = string
  default     = "forti"
}

variable "tags" {
  description = "Tags applied to resources managed by this Branch2 stack."
  type        = map(string)
  default = {
    Environment = "test"
    Lab         = "fortigate-sdwan"
    ManagedBy   = "terraform"
  }
}

variable "admin_username" {
  description = "Branch2 FortiGate administrator."
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Branch2 FortiGate administrator password."
  type        = string
  sensitive   = true
}

variable "fortigate_ami_id" {
  description = "Subscribed FortiGate BYOL Marketplace AMI ID for aws_region."
  type        = string
}

variable "fortigate_instance_type" {
  description = "Licensed Branch2 instance type. It must support at least four ENIs."
  type        = string
  default     = "c5.2xlarge"
}

variable "branch2_lan_cidr" {
  description = "CIDR for the new Branch2 protected LAN."
  type        = string
  default     = "10.10.40.0/24"
}

variable "branch2_port1_ip" {
  description = "Branch2 port1 address in the existing Branch1 ISP1 subnet."
  type        = string
  default     = "10.10.113.21"
}

variable "branch2_lan_ip" {
  description = "Branch2 port2 address in the new Branch2 LAN."
  type        = string
  default     = "10.10.40.20"
}

variable "branch2_port3_ip" {
  description = "Branch2 port3 address in the existing Hub2 ISP2 subnet."
  type        = string
  default     = "10.10.102.22"
}

variable "branch2_port4_ip" {
  description = "Branch2 port4 address in the existing shared MPLS subnet."
  type        = string
  default     = "10.10.200.24"
}

variable "management_cidr" {
  description = "Existing management subnet CIDR used for the Branch2 management route."
  type        = string
  default     = "10.10.252.0/24"
}
