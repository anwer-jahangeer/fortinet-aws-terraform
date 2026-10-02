data "aws_vpc" "lab" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-sdwan-vpc"]
  }
}

data "aws_ec2_instance_type" "fortigate" {
  instance_type = var.fortigate_instance_type
}

data "aws_instance" "internet_router" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-debian-internet-router"]
  }

  filter {
    name   = "instance-state-name"
    values = ["pending", "running", "stopping", "stopped"]
  }
}

data "aws_ec2_instance_type" "internet_router" {
  instance_type = data.aws_instance.internet_router.instance_type
}

data "aws_network_interface" "internet_router_outside" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-internet-router-outside"]
  }
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

data "aws_security_group" "internet_router" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-internet-router"]
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
  existing_circuits = {
    hub1_isp1 = {
      cidr                = "10.10.111.0/24"
      route_table         = "${var.name_prefix}-hub1-isp1"
      internet_router_eni = "${var.name_prefix}-router-hub1-isp1"
    }
    hub1_isp2 = {
      cidr                = "10.10.101.0/24"
      route_table         = "${var.name_prefix}-hub1-isp2"
      internet_router_eni = "${var.name_prefix}-router-hub1-isp2"
    }
    hub2_isp1 = {
      cidr                = "10.10.112.0/24"
      route_table         = "${var.name_prefix}-hub2-isp1"
      internet_router_eni = "${var.name_prefix}-router-hub2-isp1"
    }
    hub2_isp2 = {
      cidr                = "10.10.102.0/24"
      route_table         = "${var.name_prefix}-hub2-isp2"
      internet_router_eni = "${var.name_prefix}-router-hub2-isp2"
    }
    branch1_isp1 = {
      cidr                = "10.10.113.0/24"
      route_table         = "${var.name_prefix}-branch1-isp1"
      internet_router_eni = "${var.name_prefix}-router-branch1-isp1"
    }
    branch1_isp2 = {
      cidr                = "10.10.103.0/24"
      route_table         = "${var.name_prefix}-branch1-isp2"
      internet_router_eni = "${var.name_prefix}-router-branch1-isp2"
    }
  }

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

data "aws_route_table" "existing_isp" {
  for_each = local.existing_circuits

  filter {
    name   = "tag:Name"
    values = [each.value.route_table]
  }

  vpc_id = data.aws_vpc.lab.id
}

data "aws_network_interface" "existing_internet_router" {
  for_each = local.existing_circuits

  filter {
    name   = "tag:Name"
    values = [each.value.internet_router_eni]
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
