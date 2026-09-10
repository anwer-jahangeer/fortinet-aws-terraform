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

resource "aws_instance" "fortimanager" {
  ami                         = var.fortimanager_ami_id
  instance_type               = var.fortimgmt_instance_type
  subnet_id                   = aws_subnet.this["management"].id
  private_ip                  = "10.10.252.110"
  vpc_security_group_ids      = [aws_security_group.management.id]
  key_name                    = aws_key_pair.lab.key_name
  associate_public_ip_address = false

  tags = {
    Name = "${var.name_prefix}-fortimanager"
    Role = "fortimanager"
  }
}

resource "aws_instance" "fortianalyzer" {
  ami                         = var.fortianalyzer_ami_id
  instance_type               = var.fortimgmt_instance_type
  subnet_id                   = aws_subnet.this["management"].id
  private_ip                  = "10.10.252.111"
  vpc_security_group_ids      = [aws_security_group.management.id]
  key_name                    = aws_key_pair.lab.key_name
  associate_public_ip_address = false

  tags = {
    Name = "${var.name_prefix}-fortianalyzer"
    Role = "fortianalyzer"
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

resource "aws_eip" "management" {
  for_each = {
    fortimanager  = aws_instance.fortimanager.primary_network_interface_id
    fortianalyzer = aws_instance.fortianalyzer.primary_network_interface_id
    jumpbox       = aws_instance.jumpbox.primary_network_interface_id
  }

  domain            = "vpc"
  network_interface = each.value

  depends_on = [aws_internet_gateway.lab]

  tags = {
    Name = "${var.name_prefix}-${each.key}-eip"
  }
}
