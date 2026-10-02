output "branch2" {
  description = "Branch2 instance and interface addresses."
  value = {
    instance_id     = aws_instance.fortigate.id
    port1_isp1_mgmt = var.branch2_port1_ip
    port2_lan       = var.branch2_lan_ip
    port3_isp2      = var.branch2_port3_ip
    port4_mpls      = var.branch2_port4_ip
    isp1_subnet     = aws_subnet.isp1.id
    isp2_subnet     = aws_subnet.isp2.id
    mpls_subnet     = data.aws_subnet.mpls.id
    isp1_public_ip  = aws_eip.branch2_isp1.public_ip
    isp2_public_ip  = aws_eip.branch2_isp2.public_ip
  }
}

output "license_validation_commands" {
  description = "FortiOS commands used to validate the installed BYOL license."
  value = [
    "get system status",
    "diagnose hardware sysinfo vm full",
    "diagnose debug vm-print-license",
  ]
}

output "inside_host_private_ips" {
  description = "Branch2 Ubuntu test-host LAN and management addresses."
  value = {
    instance_id = aws_instance.inside.id
    lan         = var.branch2_inside_ip
    management  = var.branch2_inside_management_ip
  }
}

output "debian_branch2_configuration" {
  description = "Values required when installing the persistent Branch2 Debian helper."
  value = {
    instance_id     = data.aws_instance.internet_router.id
    isp1_eni_id     = aws_network_interface.internet_router_isp1.id
    isp1_eni_mac    = aws_network_interface.internet_router_isp1.mac_address
    outside_eni_id  = data.aws_network_interface.internet_router_outside.id
    outside_eni_mac = data.aws_network_interface.internet_router_outside.mac_address
    isp1_router_ip  = var.branch2_isp1_router_ip
    isp1_nat_ip     = var.branch2_isp1_nat_ip
    isp2_nat_ip     = var.branch2_isp2_nat_ip
    isp1_public_ip  = aws_eip.branch2_isp1.public_ip
    isp2_public_ip  = aws_eip.branch2_isp2.public_ip
  }
}
