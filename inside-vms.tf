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

resource "aws_network_interface" "inside_lan" {
  for_each = local.sites

  subnet_id       = aws_subnet.this[each.value.lan_subnet].id
  private_ips     = [each.value.inside_ip]
  security_groups = [aws_security_group.inside_hosts.id]

  tags = {
    Name = "${var.name_prefix}-${each.key}-inside-lan"
  }
}

resource "aws_network_interface" "inside_management" {
  for_each = local.sites

  subnet_id       = aws_subnet.this["management"].id
  private_ips     = [each.value.inside_mgmt_ip]
  security_groups = [aws_security_group.inside_hosts.id]

  tags = {
    Name = "${var.name_prefix}-${each.key}-inside-management"
  }
}

resource "aws_instance" "inside" {
  for_each = local.sites

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.inside_instance_type
  key_name      = aws_key_pair.lab.key_name

  network_interface {
    network_interface_id = aws_network_interface.inside_lan[each.key].id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.inside_management[each.key].id
    device_index         = 1
  }

  user_data = <<-EOT
    #!/bin/bash
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y iperf3 curl traceroute
  EOT

  tags = {
    Name = "${var.name_prefix}-${each.key}-inside-vm"
    Role = "test-host"
    Site = each.key
  }
}
