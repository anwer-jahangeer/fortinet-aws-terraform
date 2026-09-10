output "vpc_id" {
  description = "AWS VPC containing the complete SD-WAN lab."
  value       = aws_vpc.lab.id
}

output "subnet_ids" {
  description = "Subnet IDs by logical network segment."
  value       = { for name, subnet in aws_subnet.this : name => subnet.id }
}

output "fortigate_private_ips" {
  description = "FortiGate private interface addresses by site."
  value = {
    for site, config in local.sites : site => {
      port1_management_isp1 = config.mgmt_ip
      port2_lan             = config.lan_ip
      port3_isp2            = config.wan_ip
      port4_mpls            = config.mpls_ip
    }
  }
}

output "fortigate_public_ips" {
  description = "Static public IPs for both internet transports at each FortiGate site."
  value = {
    for site in keys(local.sites) : site => {
      isp1 = aws_eip.fortigate_isp1[site].public_ip
      isp2 = aws_eip.fortigate_isp2[site].public_ip
    }
  }
}

output "management_public_ips" {
  description = "Public addresses for FortiManager, FortiAnalyzer, and the Windows jumpbox."
  value       = { for name, eip in aws_eip.management : name => eip.public_ip }
}

output "management_private_ips" {
  description = "Private management addresses."
  value = {
    fortimanager  = aws_instance.fortimanager.private_ip
    fortianalyzer = aws_instance.fortianalyzer.private_ip
    jumpbox       = aws_instance.jumpbox.private_ip
  }
}

output "fortinet_initial_logins" {
  description = "Initial appliance login details. Change FMG/FAZ to the lab password after first login."
  value = {
    fortigates = {
      username = var.admin_username
      password = var.admin_password
    }
    fortimanager = {
      username = "admin"
      password = aws_instance.fortimanager.id
    }
    fortianalyzer = {
      username = "admin"
      password = aws_instance.fortianalyzer.id
    }
  }
  sensitive = true
}

output "inside_host_private_ips" {
  description = "Linux test-host addresses behind each FortiGate."
  value       = { for site, instance in aws_instance.inside : site => instance.private_ip }
}

output "windows_password_command" {
  description = "Command used after Windows initialization to retrieve the jumpbox password."
  value       = "aws ec2 get-password-data --region ${var.aws_region} --instance-id ${aws_instance.jumpbox.id} --priv-launch-key <path-to-private-key>"
}
