resource "aws_network_interface" "fgt_management" {
  for_each = local.sites

  subnet_id         = aws_subnet.this["management"].id
  private_ips       = [each.value.mgmt_ip]
  security_groups   = [aws_security_group.fortigate_management.id]
  source_dest_check = false

  tags = {
    Name = "${var.name_prefix}-${each.key}-fgt-port1-management-isp1"
  }
}

resource "aws_network_interface" "fgt_lan" {
  for_each = local.sites

  subnet_id         = aws_subnet.this[each.value.lan_subnet].id
  private_ips       = [each.value.lan_ip]
  security_groups   = [aws_security_group.fortigate_internal.id]
  source_dest_check = false

  tags = {
    Name = "${var.name_prefix}-${each.key}-fgt-port2-lan"
  }
}

resource "aws_network_interface" "fgt_wan" {
  for_each = local.sites

  subnet_id         = aws_subnet.this[each.value.wan_subnet].id
  private_ips       = [each.value.wan_ip]
  security_groups   = [aws_security_group.fortigate_wan.id]
  source_dest_check = false

  tags = {
    Name = "${var.name_prefix}-${each.key}-fgt-port3-isp2"
  }
}

resource "aws_network_interface" "fgt_mpls" {
  for_each = local.sites

  subnet_id         = aws_subnet.this["mpls"].id
  private_ips       = [each.value.mpls_ip]
  security_groups   = [aws_security_group.fortigate_internal.id]
  source_dest_check = false

  tags = {
    Name = "${var.name_prefix}-${each.key}-fgt-port4-mpls"
  }
}

resource "aws_instance" "fortigate" {
  for_each = local.sites

  ami           = var.fortigate_ami_id
  instance_type = var.fortigate_instance_type
  key_name      = aws_key_pair.lab.key_name
  user_data = templatefile("${path.module}/bootstrap/fgt-bootstrap.tftpl", {
    hostname       = "${var.name_prefix}-${each.key}-fgt"
    admin_username = var.admin_username
    admin_password = var.admin_password
  })
  user_data_replace_on_change = true

  network_interface {
    network_interface_id = aws_network_interface.fgt_management[each.key].id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.fgt_lan[each.key].id
    device_index         = 1
  }

  network_interface {
    network_interface_id = aws_network_interface.fgt_wan[each.key].id
    device_index         = 2
  }

  network_interface {
    network_interface_id = aws_network_interface.fgt_mpls[each.key].id
    device_index         = 3
  }

  tags = {
    Name = "${var.name_prefix}-${each.key}-fgt"
    Role = "fortigate"
    Site = each.key
  }
}

resource "aws_eip" "fortigate_isp1" {
  for_each = local.sites

  domain                    = "vpc"
  network_interface         = aws_network_interface.fgt_management[each.key].id
  associate_with_private_ip = each.value.mgmt_ip

  depends_on = [aws_internet_gateway.lab]

  tags = {
    Name      = "${var.name_prefix}-${each.key}-isp1-eip"
    Transport = "isp1"
  }
}

resource "aws_eip" "fortigate_isp2" {
  for_each = local.sites

  domain                    = "vpc"
  network_interface         = aws_network_interface.fgt_wan[each.key].id
  associate_with_private_ip = each.value.wan_ip

  depends_on = [aws_internet_gateway.lab]

  tags = {
    Name      = "${var.name_prefix}-${each.key}-isp2-eip"
    Transport = "isp2"
  }
}
