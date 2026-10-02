output "branch2" {
  description = "Branch2 instance and interface addresses."
  value = {
    instance_id     = aws_instance.fortigate.id
    port1_isp1_mgmt = var.branch2_port1_ip
    port2_lan       = var.branch2_lan_ip
    port3_isp2      = var.branch2_port3_ip
    port4_mpls      = var.branch2_port4_ip
    isp1_subnet     = data.aws_subnet.branch1_isp1.id
    isp2_subnet     = data.aws_subnet.hub2_isp2.id
    mpls_subnet     = data.aws_subnet.mpls.id
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
