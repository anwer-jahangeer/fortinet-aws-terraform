resource "aws_subnet" "lan" {
  vpc_id                  = data.aws_vpc.lab.id
  cidr_block              = var.branch2_lan_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name    = "${var.name_prefix}-branch2-lan"
    Segment = "branch2_lan"
  }
}

resource "aws_network_interface" "port1" {
  subnet_id         = data.aws_subnet.branch1_isp1.id
  private_ips       = [var.branch2_port1_ip]
  security_groups   = [data.aws_security_group.fortigate_management.id]
  source_dest_check = false

  tags = {
    Name = "${var.name_prefix}-branch2-fgt-port1-management-isp1"
  }
}

resource "aws_network_interface" "lan" {
  subnet_id         = aws_subnet.lan.id
  private_ips       = [var.branch2_lan_ip]
  security_groups   = [data.aws_security_group.fortigate_internal.id]
  source_dest_check = false

  tags = {
    Name = "${var.name_prefix}-branch2-fgt-port2-lan"
  }
}

resource "aws_network_interface" "port3" {
  subnet_id         = data.aws_subnet.hub2_isp2.id
  private_ips       = [var.branch2_port3_ip]
  security_groups   = [data.aws_security_group.fortigate_wan.id]
  source_dest_check = false

  tags = {
    Name = "${var.name_prefix}-branch2-fgt-port3-isp2"
  }
}

resource "aws_instance" "fortigate" {
  ami           = var.fortigate_ami_id
  instance_type = var.fortigate_instance_type
  key_name      = data.aws_key_pair.lab.key_name
  user_data = templatefile("${path.module}/bootstrap/fgt-bootstrap.tftpl", {
    hostname        = "${var.name_prefix}-branch2-fgt"
    admin_username  = var.admin_username
    admin_password  = var.admin_password
    management_cidr = var.management_cidr
    port1_gateway   = cidrhost(data.aws_subnet.branch1_isp1.cidr_block, 1)
  })
  user_data_replace_on_change = true

  network_interface {
    network_interface_id = aws_network_interface.port1.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.lan.id
    device_index         = 1
  }

  network_interface {
    network_interface_id = aws_network_interface.port3.id
    device_index         = 2
  }

  tags = {
    Name = "${var.name_prefix}-branch2-fgt"
    Role = "fortigate"
    Site = "branch2"
  }
}

resource "aws_route_table" "lan" {
  vpc_id = data.aws_vpc.lab.id

  tags = {
    Name = "${var.name_prefix}-branch2-lan"
  }
}

resource "aws_route_table_association" "lan" {
  subnet_id      = aws_subnet.lan.id
  route_table_id = aws_route_table.lan.id
}

resource "aws_route" "lan_default" {
  route_table_id         = aws_route_table.lan.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.lan.id

  depends_on = [aws_instance.fortigate]
}

resource "aws_route" "branch2_to_existing_lans" {
  for_each = local.existing_sites

  route_table_id         = aws_route_table.lan.id
  destination_cidr_block = each.value.lan_cidr
  network_interface_id   = aws_network_interface.lan.id

  depends_on = [aws_instance.fortigate]
}

resource "aws_route" "existing_lans_to_branch2" {
  for_each = local.existing_sites

  route_table_id         = data.aws_route_table.existing_lan[each.key].id
  destination_cidr_block = var.branch2_lan_cidr
  network_interface_id   = data.aws_network_interface.existing_fortigate_lan[each.key].id
}
