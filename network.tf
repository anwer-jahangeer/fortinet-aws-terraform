resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-sdwan-vpc"
  }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "this" {
  for_each = var.subnet_cidrs

  vpc_id                  = aws_vpc.lab.id
  cidr_block              = each.value
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name    = "${var.name_prefix}-${replace(each.key, "_", "-")}"
    Segment = each.key
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = {
    Name = "${var.name_prefix}-public"
  }
}

resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "mpls" {
  vpc_id = aws_vpc.lab.id

  tags = {
    Name = "${var.name_prefix}-mpls-private"
  }
}

resource "aws_route_table_association" "mpls" {
  subnet_id      = aws_subnet.this["mpls"].id
  route_table_id = aws_route_table.mpls.id
}

resource "aws_route_table" "lan" {
  for_each = local.sites

  vpc_id = aws_vpc.lab.id

  tags = {
    Name = "${var.name_prefix}-${each.key}-lan"
  }
}

resource "aws_route_table_association" "lan" {
  for_each = local.sites

  subnet_id      = aws_subnet.this[each.value.lan_subnet].id
  route_table_id = aws_route_table.lan[each.key].id
}

resource "aws_route" "lan_default_to_fortigate" {
  for_each = local.sites

  route_table_id         = aws_route_table.lan[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.fgt_lan[each.key].id
}

resource "aws_route" "lan_inter_site_to_fortigate" {
  for_each = local.inter_site_routes

  route_table_id         = aws_route_table.lan[each.value.source_site].id
  destination_cidr_block = each.value.destination_cidr
  network_interface_id   = aws_network_interface.fgt_lan[each.value.source_site].id
}
