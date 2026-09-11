locals {
  sites = {
    hub1 = {
      lan_subnet     = "hub1_lan"
      isp1_subnet    = "hub1_isp1"
      wan_subnet     = "hub1_wan2"
      mgmt_ip        = "10.10.111.20"
      lan_ip         = "10.10.20.20"
      wan_ip         = "10.10.101.21"
      mpls_ip        = "10.10.200.21"
      inside_ip      = "10.10.20.6"
      inside_mgmt_ip = "10.10.252.31"
    }
    hub2 = {
      lan_subnet     = "hub2_lan"
      isp1_subnet    = "hub2_isp1"
      wan_subnet     = "hub2_wan2"
      mgmt_ip        = "10.10.112.20"
      lan_ip         = "10.10.30.20"
      wan_ip         = "10.10.102.21"
      mpls_ip        = "10.10.200.22"
      inside_ip      = "10.10.30.6"
      inside_mgmt_ip = "10.10.252.32"
    }
    branch1 = {
      lan_subnet     = "branch1_lan"
      isp1_subnet    = "branch1_isp1"
      wan_subnet     = "branch1_wan2"
      mgmt_ip        = "10.10.113.20"
      lan_ip         = "10.10.10.20"
      wan_ip         = "10.10.103.21"
      mpls_ip        = "10.10.200.23"
      inside_ip      = "10.10.10.6"
      inside_mgmt_ip = "10.10.252.33"
    }
  }

  public_subnets = toset([
    "management",
    "internet_egress",
  ])

  internet_circuits = {
    hub1_isp1 = {
      device_index       = 1
      subnet             = "hub1_isp1"
      router_ip          = "10.10.111.254"
      fortigate_ip       = "10.10.111.20"
      outside_private_ip = "10.10.121.10"
      site               = "hub1"
      transport          = "isp1"
    }
    hub1_isp2 = {
      device_index       = 2
      subnet             = "hub1_wan2"
      router_ip          = "10.10.101.254"
      fortigate_ip       = "10.10.101.21"
      outside_private_ip = "10.10.121.11"
      site               = "hub1"
      transport          = "isp2"
    }
    hub2_isp1 = {
      device_index       = 3
      subnet             = "hub2_isp1"
      router_ip          = "10.10.112.254"
      fortigate_ip       = "10.10.112.20"
      outside_private_ip = "10.10.121.12"
      site               = "hub2"
      transport          = "isp1"
    }
    hub2_isp2 = {
      device_index       = 4
      subnet             = "hub2_wan2"
      router_ip          = "10.10.102.254"
      fortigate_ip       = "10.10.102.21"
      outside_private_ip = "10.10.121.13"
      site               = "hub2"
      transport          = "isp2"
    }
    branch1_isp1 = {
      device_index       = 5
      subnet             = "branch1_isp1"
      router_ip          = "10.10.113.254"
      fortigate_ip       = "10.10.113.20"
      outside_private_ip = "10.10.121.14"
      site               = "branch1"
      transport          = "isp1"
    }
    branch1_isp2 = {
      device_index       = 6
      subnet             = "branch1_wan2"
      router_ip          = "10.10.103.254"
      fortigate_ip       = "10.10.103.21"
      outside_private_ip = "10.10.121.15"
      site               = "branch1"
      transport          = "isp2"
    }
  }

  internet_router_outside_ips = [
    "10.10.121.10",
    "10.10.121.11",
    "10.10.121.12",
    "10.10.121.13",
    "10.10.121.14",
    "10.10.121.15",
  ]

  fortigate_wan_source_cidrs = concat(
    var.wan_ingress_cidrs,
    [var.subnet_cidrs["internet_egress"]],
    [for eip in aws_eip.internet_router : "${eip.public_ip}/32"],
  )

  isp_isolation_routes = merge([
    for source_name, source in local.internet_circuits : {
      for destination_name, destination in local.internet_circuits :
      "${source_name}-to-${destination_name}" => {
        source_circuit   = source_name
        destination_cidr = var.subnet_cidrs[destination.subnet]
      } if source_name != destination_name
    }
  ]...)

  # More-specific routes override the VPC's implicit /16 local route, ensuring
  # inter-site LAN traffic enters the local FortiGate instead of bypassing it.
  inter_site_routes = merge([
    for source_site, source in local.sites : {
      for destination_site, destination in local.sites :
      "${source_site}-to-${destination_site}" => {
        source_site      = source_site
        destination_cidr = var.subnet_cidrs[destination.lan_subnet]
      } if source_site != destination_site
    }
  ]...)
}
