data "aws_ssm_parameter" "windows_ami" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2019-English-Full-Base"
}

resource "aws_key_pair" "lab" {
  key_name_prefix = "${var.name_prefix}-lab-"
  public_key      = var.ssh_public_key

  tags = {
    Name = "${var.name_prefix}-lab-key"
  }
}

resource "aws_instance" "jumpbox" {
  ami                         = data.aws_ssm_parameter.windows_ami.value
  instance_type               = var.jumpbox_instance_type
  subnet_id                   = aws_subnet.this["management"].id
  vpc_security_group_ids      = [aws_security_group.management.id]
  key_name                    = aws_key_pair.lab.key_name
  associate_public_ip_address = false

  tags = {
    Name = "${var.name_prefix}-windows-jumpbox"
    Role = "jumpbox"
  }
}

resource "aws_eip" "jumpbox" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.lab]

  tags = {
    Name = "${var.name_prefix}-jumpbox-eip"
  }
}

resource "aws_eip_association" "jumpbox" {
  allocation_id        = aws_eip.jumpbox.id
  network_interface_id = aws_instance.jumpbox.primary_network_interface_id
  allow_reassociation  = true
}
