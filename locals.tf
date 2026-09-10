locals {
  sites = {
    hub1 = {
      lan_subnet = "hub1_lan"
      wan_subnet = "hub1_wan2"
      mgmt_ip    = "10.10.252.21"
      lan_ip     = "10.10.20.20"
      wan_ip     = "10.10.101.21"
      mpls_ip    = "10.10.200.21"
      inside_ip  = "10.10.20.6"
    }
    hub2 = {
      lan_subnet = "hub2_lan"
      wan_subnet = "hub2_wan2"
      mgmt_ip    = "10.10.252.22"
      lan_ip     = "10.10.30.20"
      wan_ip     = "10.10.102.21"
      mpls_ip    = "10.10.200.22"
      inside_ip  = "10.10.30.6"
    }
    branch1 = {
      lan_subnet = "branch1_lan"
      wan_subnet = "branch1_wan2"
      mgmt_ip    = "10.10.252.23"
      lan_ip     = "10.10.10.20"
      wan_ip     = "10.10.103.21"
      mpls_ip    = "10.10.200.23"
      inside_ip  = "10.10.10.6"
    }
  }

  public_subnets = toset([
    "management",
    "hub1_wan2",
    "hub2_wan2",
    "branch1_wan2",
  ])

  lan_subnets = toset([
    "hub1_lan",
    "hub2_lan",
    "branch1_lan",
  ])

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
