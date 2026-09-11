data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_network_interface" "internet_router_outside" {
  subnet_id         = aws_subnet.this["internet_egress"].id
  private_ips       = local.internet_router_outside_ips
  security_groups   = [aws_security_group.internet_router.id]
  source_dest_check = false

  tags = {
    Name = "${var.name_prefix}-internet-router-outside"
  }
}

resource "aws_network_interface" "internet_router_inside" {
  for_each = local.internet_circuits

  subnet_id         = aws_subnet.this[each.value.subnet].id
  private_ips       = [each.value.router_ip]
  security_groups   = [aws_security_group.internet_router.id]
  source_dest_check = false

  tags = {
    Name      = "${var.name_prefix}-router-${replace(each.key, "_", "-")}"
    Site      = each.value.site
    Transport = each.value.transport
  }
}

resource "aws_eip" "internet_router" {
  for_each = local.internet_circuits

  domain                    = "vpc"
  network_interface         = aws_network_interface.internet_router_outside.id
  associate_with_private_ip = each.value.outside_private_ip

  depends_on = [aws_internet_gateway.lab]

  tags = {
    Name      = "${var.name_prefix}-${replace(each.key, "_", "-")}-eip"
    Site      = each.value.site
    Transport = each.value.transport
  }
}

resource "aws_instance" "internet_router" {
  ami           = data.aws_ami.debian.id
  instance_type = var.internet_router_instance_type
  key_name      = aws_key_pair.lab.key_name

  user_data = templatefile("${path.module}/bootstrap/debian-internet-router.tftpl", {
    vpc_cidr            = var.vpc_cidr
    outside_gateway     = cidrhost(var.subnet_cidrs["internet_egress"], 1)
    outside_mac         = aws_network_interface.internet_router_outside.mac_address
    outside_private_ips = local.internet_router_outside_ips
    allowed_wan_sources = var.wan_ingress_cidrs
    circuits = {
      for name, circuit in local.internet_circuits : name => merge(circuit, {
        inside_mac = aws_network_interface.internet_router_inside[name].mac_address
        public_ip  = aws_eip.internet_router[name].public_ip
      })
    }
  })
  user_data_replace_on_change = true

  network_interface {
    network_interface_id = aws_network_interface.internet_router_outside.id
    device_index         = 0
  }

  dynamic "network_interface" {
    for_each = local.internet_circuits

    content {
      network_interface_id = aws_network_interface.internet_router_inside[network_interface.key].id
      device_index         = network_interface.value.device_index
    }
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 16
    encrypted   = true
  }

  tags = {
    Name = "${var.name_prefix}-debian-internet-router"
    Role = "internet-router"
  }
}
