resource "aws_network_interface" "inside_lan" {
  subnet_id       = aws_subnet.lan.id
  private_ips     = [var.branch2_inside_ip]
  security_groups = [data.aws_security_group.inside_hosts.id]

  tags = {
    Name = "${var.name_prefix}-branch2-inside-lan"
  }
}

resource "aws_network_interface" "inside_management" {
  subnet_id       = data.aws_subnet.management.id
  private_ips     = [var.branch2_inside_management_ip]
  security_groups = [data.aws_security_group.inside_hosts.id]

  tags = {
    Name = "${var.name_prefix}-branch2-inside-management"
  }
}

resource "aws_instance" "inside" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.inside_instance_type
  key_name      = data.aws_key_pair.lab.key_name

  network_interface {
    network_interface_id = aws_network_interface.inside_lan.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.inside_management.id
    device_index         = 1
  }

  user_data = <<-EOT
    #!/bin/bash
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y iperf3 curl traceroute
  EOT

  tags = {
    Name = "${var.name_prefix}-branch2-inside-vm"
    Role = "test-host"
    Site = "branch2"
  }
}
