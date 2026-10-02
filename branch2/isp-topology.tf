resource "aws_subnet" "isp1" {
  vpc_id                  = data.aws_vpc.lab.id
  cidr_block              = var.branch2_isp1_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name    = "${var.name_prefix}-branch2-isp1"
    Segment = "branch2_isp1"
  }
}

resource "aws_subnet" "isp2" {
  vpc_id                  = data.aws_vpc.lab.id
  cidr_block              = var.branch2_isp2_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name    = "${var.name_prefix}-branch2-isp2"
    Segment = "branch2_isp2"
  }
}

resource "aws_network_interface" "internet_router_isp1" {
  subnet_id         = aws_subnet.isp1.id
  private_ips       = [var.branch2_isp1_router_ip]
  security_groups   = [data.aws_security_group.internet_router.id]
  source_dest_check = false

  lifecycle {
    precondition {
      condition     = data.aws_ec2_instance_type.internet_router.maximum_network_interfaces >= 8
      error_message = "The Debian internet-router instance type must support at least eight ENIs."
    }
  }

  tags = {
    Name      = "${var.name_prefix}-router-branch2-isp1"
    Site      = "branch2"
    Transport = "isp1"
  }
}

resource "aws_network_interface_attachment" "internet_router_isp1" {
  instance_id          = data.aws_instance.internet_router.id
  network_interface_id = aws_network_interface.internet_router_isp1.id
  device_index         = 7
}

resource "aws_route_table" "isp1" {
  vpc_id = data.aws_vpc.lab.id

  tags = {
    Name      = "${var.name_prefix}-branch2-isp1"
    Site      = "branch2"
    Transport = "isp1"
  }
}

resource "aws_route_table" "isp2" {
  vpc_id = data.aws_vpc.lab.id

  tags = {
    Name      = "${var.name_prefix}-branch2-isp2"
    Site      = "branch2"
    Transport = "isp2"
  }
}

resource "aws_route_table_association" "isp1" {
  subnet_id      = aws_subnet.isp1.id
  route_table_id = aws_route_table.isp1.id
}

resource "aws_route_table_association" "isp2" {
  subnet_id      = aws_subnet.isp2.id
  route_table_id = aws_route_table.isp2.id
}

resource "aws_route" "isp1_default" {
  route_table_id         = aws_route_table.isp1.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.internet_router_isp1.id

  depends_on = [aws_network_interface_attachment.internet_router_isp1]
}

resource "aws_route" "isp2_default" {
  route_table_id         = aws_route_table.isp2.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = data.aws_network_interface.internet_router_outside.id
}

resource "aws_route" "isp1_to_existing_circuits" {
  for_each = local.existing_circuits

  route_table_id         = aws_route_table.isp1.id
  destination_cidr_block = each.value.cidr
  network_interface_id   = aws_network_interface.internet_router_isp1.id

  depends_on = [aws_network_interface_attachment.internet_router_isp1]
}

resource "aws_route" "isp2_to_existing_circuits" {
  for_each = local.existing_circuits

  route_table_id         = aws_route_table.isp2.id
  destination_cidr_block = each.value.cidr
  network_interface_id   = data.aws_network_interface.internet_router_outside.id
}

resource "aws_route" "isp1_to_isp2" {
  route_table_id         = aws_route_table.isp1.id
  destination_cidr_block = var.branch2_isp2_cidr
  network_interface_id   = aws_network_interface.internet_router_isp1.id

  depends_on = [aws_network_interface_attachment.internet_router_isp1]
}

resource "aws_route" "isp2_to_isp1" {
  route_table_id         = aws_route_table.isp2.id
  destination_cidr_block = var.branch2_isp1_cidr
  network_interface_id   = data.aws_network_interface.internet_router_outside.id
}

resource "aws_route" "existing_circuits_to_branch2_isp1" {
  for_each = local.existing_circuits

  route_table_id         = data.aws_route_table.existing_isp[each.key].id
  destination_cidr_block = var.branch2_isp1_cidr
  network_interface_id   = data.aws_network_interface.existing_internet_router[each.key].id
}

resource "aws_route" "existing_circuits_to_branch2_isp2" {
  for_each = local.existing_circuits

  route_table_id         = data.aws_route_table.existing_isp[each.key].id
  destination_cidr_block = var.branch2_isp2_cidr
  network_interface_id   = data.aws_network_interface.existing_internet_router[each.key].id
}

resource "aws_eip" "branch2_isp1" {
  domain = "vpc"

  tags = {
    Name      = "${var.name_prefix}-branch2-isp1-eip"
    Site      = "branch2"
    Transport = "isp1"
  }
}

resource "aws_eip" "branch2_isp2" {
  domain = "vpc"

  tags = {
    Name      = "${var.name_prefix}-branch2-isp2-eip"
    Site      = "branch2"
    Transport = "isp2"
  }
}

resource "aws_eip_association" "branch2_isp1" {
  allocation_id        = aws_eip.branch2_isp1.id
  network_interface_id = data.aws_network_interface.internet_router_outside.id
  private_ip_address   = var.branch2_isp1_nat_ip
  allow_reassociation  = false

  lifecycle {
    precondition {
      condition     = contains(data.aws_network_interface.internet_router_outside.private_ips, var.branch2_isp1_nat_ip)
      error_message = "Run the root Stage 1 apply first so the Debian outside ENI owns branch2_isp1_nat_ip."
    }
  }
}

resource "aws_eip_association" "branch2_isp2" {
  allocation_id        = aws_eip.branch2_isp2.id
  network_interface_id = data.aws_network_interface.internet_router_outside.id
  private_ip_address   = var.branch2_isp2_nat_ip
  allow_reassociation  = false

  lifecycle {
    precondition {
      condition     = contains(data.aws_network_interface.internet_router_outside.private_ips, var.branch2_isp2_nat_ip)
      error_message = "Run the root Stage 1 apply first so the Debian outside ENI owns branch2_isp2_nat_ip."
    }
  }
}
