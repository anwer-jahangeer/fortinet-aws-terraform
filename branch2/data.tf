data "aws_vpc" "lab" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-sdwan-vpc"]
  }
}

data "aws_ec2_instance_type" "fortigate" {
  instance_type = var.fortigate_instance_type
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_subnet" "management" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-management"]
  }
}

data "aws_subnet" "branch1_isp1" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-branch1-isp1"]
  }
}

data "aws_subnet" "hub2_isp2" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-hub2-wan2"]
  }
}

data "aws_subnet" "mpls" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-mpls"]
  }
}

data "aws_security_group" "fortigate_management" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-fgt-management"]
  }

  vpc_id = data.aws_vpc.lab.id
}

data "aws_security_group" "fortigate_wan" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-fgt-wan"]
  }

  vpc_id = data.aws_vpc.lab.id
}

data "aws_security_group" "fortigate_internal" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-fgt-internal"]
  }

  vpc_id = data.aws_vpc.lab.id
}

data "aws_security_group" "inside_hosts" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-inside-hosts"]
  }

  vpc_id = data.aws_vpc.lab.id
}

data "aws_key_pair" "lab" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-lab-key"]
  }
}

locals {
  existing_sites = {
    hub1 = {
      lan_cidr      = "10.10.20.0/24"
      route_table   = "${var.name_prefix}-hub1-lan"
      fortigate_eni = "${var.name_prefix}-hub1-fgt-port2-lan"
    }
    hub2 = {
      lan_cidr      = "10.10.30.0/24"
      route_table   = "${var.name_prefix}-hub2-lan"
      fortigate_eni = "${var.name_prefix}-hub2-fgt-port2-lan"
    }
    branch1 = {
      lan_cidr      = "10.10.10.0/24"
      route_table   = "${var.name_prefix}-branch1-lan"
      fortigate_eni = "${var.name_prefix}-branch1-fgt-port2-lan"
    }
  }
}

data "aws_route_table" "existing_lan" {
  for_each = local.existing_sites

  filter {
    name   = "tag:Name"
    values = [each.value.route_table]
  }

  vpc_id = data.aws_vpc.lab.id
}

data "aws_network_interface" "existing_fortigate_lan" {
  for_each = local.existing_sites

  filter {
    name   = "tag:Name"
    values = [each.value.fortigate_eni]
  }
}
