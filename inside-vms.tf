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

resource "aws_instance" "inside" {
  for_each = local.sites

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.inside_instance_type
  subnet_id                   = aws_subnet.this[each.value.lan_subnet].id
  private_ip                  = each.value.inside_ip
  vpc_security_group_ids      = [aws_security_group.inside_hosts.id]
  key_name                    = aws_key_pair.lab.key_name
  associate_public_ip_address = false

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
