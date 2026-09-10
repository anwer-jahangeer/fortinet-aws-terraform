resource "aws_security_group" "fortigate_management" {
  name_prefix = "${var.name_prefix}-fgt-mgmt-"
  description = "FortiGate management and ISP1 access"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "HTTPS administration"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = var.admin_ingress_cidrs
  }

  ingress {
    description = "SSH administration"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = var.admin_ingress_cidrs
  }

  ingress {
    description = "FortiManager device management"
    protocol    = "tcp"
    from_port   = 541
    to_port     = 541
    cidr_blocks = [var.subnet_cidrs["management"]]
  }

  ingress {
    description = "IKE and IPsec NAT traversal"
    protocol    = "udp"
    from_port   = 500
    to_port     = 500
    cidr_blocks = var.wan_ingress_cidrs
  }

  ingress {
    description = "IPsec NAT traversal"
    protocol    = "udp"
    from_port   = 4500
    to_port     = 4500
    cidr_blocks = var.wan_ingress_cidrs
  }

  ingress {
    description = "IPsec ESP"
    protocol    = "50"
    from_port   = 0
    to_port     = 0
    cidr_blocks = var.wan_ingress_cidrs
  }

  ingress {
    description = "ICMP diagnostics"
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = var.wan_ingress_cidrs
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-fgt-management"
  }
}

resource "aws_security_group" "fortigate_wan" {
  name_prefix = "${var.name_prefix}-fgt-wan-"
  description = "FortiGate ISP2 IPsec underlay"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "IKE"
    protocol    = "udp"
    from_port   = 500
    to_port     = 500
    cidr_blocks = var.wan_ingress_cidrs
  }

  ingress {
    description = "IPsec NAT traversal"
    protocol    = "udp"
    from_port   = 4500
    to_port     = 4500
    cidr_blocks = var.wan_ingress_cidrs
  }

  ingress {
    description = "IPsec ESP"
    protocol    = "50"
    from_port   = 0
    to_port     = 0
    cidr_blocks = var.wan_ingress_cidrs
  }

  ingress {
    description = "ICMP diagnostics"
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = var.wan_ingress_cidrs
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-fgt-wan"
  }
}

resource "aws_security_group" "fortigate_internal" {
  name_prefix = "${var.name_prefix}-fgt-internal-"
  description = "FortiGate LAN and MPLS interfaces"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "Lab VPC traffic"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-fgt-internal"
  }
}

resource "aws_security_group" "management" {
  name_prefix = "${var.name_prefix}-management-"
  description = "FortiManager, FortiAnalyzer, and Windows jumpbox"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "Management from trusted public networks"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = var.admin_ingress_cidrs
  }

  ingress {
    description = "HTTPS from trusted public networks"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = var.admin_ingress_cidrs
  }

  ingress {
    description = "RDP from trusted public networks"
    protocol    = "tcp"
    from_port   = 3389
    to_port     = 3389
    cidr_blocks = var.admin_ingress_cidrs
  }

  ingress {
    description = "Fortinet management and logging inside the VPC"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-management"
  }
}

resource "aws_security_group" "inside_hosts" {
  name_prefix = "${var.name_prefix}-inside-"
  description = "Linux test hosts behind the FortiGates"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "Lab traffic"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-inside-hosts"
  }
}
