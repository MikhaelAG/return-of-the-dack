terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.25.0"
    }
  }
}

# Set up providers for each network by project and alias
# Three projects are used for Europe (HQ), Americas, and Asia-Pacific

# Europe Provider
provider "google" {
  # Configuration options
  project     = var.networks.net1.project
  credentials = "terra-dome-420900-6642f8c08c0c.json"
  alias       = "europe"
}

# Americas Provider
provider "google" {
  # Configuration options
  project     = var.networks.net2.project
  credentials = "terra-dome-2-e78b187b47ab.json"
  alias       = "americas"
}

# Asia-Pacific Provider
provider "google" {
  # Configuration options
  project     = var.networks.net3.project
  credentials = "terra-dome-3-d2a5a262dc47.json"
  alias       = "asia"
}

locals {
  subnets = ["10.175.40.0/24", "172.16.65.0/24", "172.16.37.0/24", "192.168.29.0/24"]

  instances = tomap({

    net1 = {
      name   = format("%s-subnet", var.networks.net1.name)
      subnet = element(local.subnets, 0)
      region = "europe-west6" # Zurich, Switzerland
    }

    net2 = {
      name   = format("%s-us-subnet", var.networks.net2.name)
      subnet = element(local.subnets, 1)
      region = "us-west2" # Los Angeles, California, USA
    }

    net3 = {
      name   = format("%s-sa-subnet", var.networks.net2.name)
      subnet = element(local.subnets, 2)
      region = "southamerica-east1" # Sao Paulo, Sao Paulo, Brazil
    }

    net4 = {
      name   = format("%s-subnet", var.networks.net3.name)
      subnet = element(local.subnets, 3)
      region = "asia-northeast3" # Seoul, South Korea
    }
  })
}

# Create VPCs for EUROPE/AMERICAS/ASIA-PACIFIC
resource "google_compute_network" "nets" {
  for_each                = var.networks
  name                    = "${each.value.name}-net"
  project                 = each.value.project
  auto_create_subnetworks = false
}


# Europe subnet
resource "google_compute_subnetwork" "eu-subnet" {
  name                     = local.instances.net1.name
  project                  = var.networks.net1.project
  ip_cidr_range            = local.instances.net1.subnet
  network                  = google_compute_network.nets["net1"].id
  region                   = local.instances.net1.region
  private_ip_google_access = true
}

# North America
resource "google_compute_subnetwork" "na-subnet" {
  name                     = local.instances.net2.name
  project                  = var.networks.net2.project
  ip_cidr_range            = local.instances.net2.subnet
  network                  = google_compute_network.nets["net2"].id
  region                   = local.instances.net2.region
  private_ip_google_access = true
}

# South America
resource "google_compute_subnetwork" "sa-subnet" {
  name                     = local.instances.net3.name
  project                  = var.networks.net2.project
  ip_cidr_range            = local.instances.net3.subnet
  network                  = google_compute_network.nets["net2"].id
  region                   = local.instances.net3.region
  private_ip_google_access = true
}

# Asia-Pacific
resource "google_compute_subnetwork" "ap-subnet" {
  name                     = local.instances.net4.name
  project                  = var.networks.net3.project
  ip_cidr_range            = local.instances.net4.subnet
  network                  = google_compute_network.nets["net3"].id
  region                   = local.instances.net4.region
  private_ip_google_access = true
}

# EUROPE HQ FIREWALL SETTINGS
resource "google_compute_firewall" "hq-sg" {
  name    = format("%s-firewall", var.networks.net1.name)
  project = var.networks.net1.project
  network = google_compute_network.nets["net1"].name

  dynamic "allow" {
    for_each = var.eu_ingress
    content {
      protocol = allow.value.protocol
      ports    = allow.value.port
    }
  }

  source_ranges = concat(local.subnets, ["0.0.0.0/0"])
}

# NORTH AMERICA FIREWALL SETTINGS
resource "google_compute_firewall" "na-sg" {
  name    = format("%s-na-firewall", var.networks.net2.name)
  project = var.networks.net2.project
  network = google_compute_network.nets["net2"].name

  dynamic "allow" {
    for_each = var.am_ingress

    content {
      protocol = allow.value.protocol
      ports = allow.value.port
    }
  }

  source_ranges = concat([element(local.subnets, 0)], ["0.0.0.0/0"])
}

# SOUTH AMERICA FIREWALL SETTINGS
resource "google_compute_firewall" "sa-sg" {
  name    = format("%s-sa-firewall", var.networks.net2.name)
  project = var.networks.net2.project
  network = google_compute_network.nets["net2"].name

  dynamic "allow" {
    for_each = var.am_ingress
    
    content {
      protocol = allow.value.protocol
      ports = allow.value.port 
    }
  }

  source_ranges = concat([element(local.subnets, 0)], ["0.0.0.0/0"])
}

# ASIA-PACIFIC FIREWALL SETTINGS
resource "google_compute_firewall" "ap-sg" {
  name    = format("%s-firewall", var.networks.net3.name)
  project = var.networks.net3.project
  network = google_compute_network.nets["net3"].name

  dynamic "allow" {
    for_each = var.ap_ingress
    
    content {
      protocol = allow.value.protocol
      ports = allow.value.port
    }
  }

  source_ranges = ["0.0.0.0/0"]
}

# CREATE INSTANCES 
# EUROPE/N.A./S.A./A.P.


data "google_compute_image" "debian-12" {
  family  = "debian-12"
  project = "debian-cloud"
}

# CREATE SERVICE ACCTS 
# EUROPE/AMERICAS/ASIA-PACIFIC
resource "google_service_account" "service_account" {
  for_each     = var.networks
  project      = each.value.project
  account_id   = "custom-vm-sa"
  display_name = "VM Service Account"
}

# EUROPE INSTANCE
resource "google_compute_instance" "eu_instance" {
  name         = format("%s-instance", var.networks.net1.name)
  project      = var.networks.net1.project
  machine_type = "e2-medium"
  zone         = format("%s-a", local.instances.net1.region)

  tags = ["net", "worth"]

  boot_disk {
    auto_delete = true
    # add Debian 12 image to boot disk
    initialize_params {
      image = data.google_compute_image.debian-12.self_link
      size  = 10
      type  = "pd-balanced"
      labels = {
        my_label = "value"
      }
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.eu-subnet.id
    access_config {
      // Ephemeral public IP
      network_tier = "STANDARD"
    }
  }

  metadata = {
    startup-script = file("startup_script.sh")
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.service_account["net1"].email
    scopes = ["cloud-platform"]
  }
  depends_on = [google_compute_network.nets]
}

# NORTH AMERICA INSTANCE
resource "google_compute_instance" "na_instance" {
  name         = format("%s-instance", var.networks.net2.name)
  project      = var.networks.net2.project
  machine_type = "e2-medium"
  zone         = format("%s-a", local.instances.net2.region)

  tags = ["net", "worth"]

  boot_disk {
    auto_delete = true
    # add Debian 12 image to boot disk
    initialize_params {
      image = data.google_compute_image.debian-12.self_link
      size  = 10
      type  = "pd-balanced"
      labels = {
        my_label = "value"
      }
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.na-subnet.id
    access_config {
      // Ephemeral public IP
      network_tier = "STANDARD"
    }
  }

  metadata = {
    startup-script = file("startup_script.sh")
  }

  service_account {
    email  = google_service_account.service_account["net2"].email
    scopes = ["cloud-platform"]
  }
  depends_on = [google_compute_network.nets]
}

# SOUTH AMERICA INSTANCE
resource "google_compute_instance" "sa_instance" {
  name         = format("%s-sa-instance", var.networks.net2.name)
  project      = var.networks.net2.project
  machine_type = "e2-medium"
  zone         = format("%s-a", local.instances.net3.region)

  tags = ["net", "worth"]

  boot_disk {
    auto_delete = true

    initialize_params {
      image = data.google_compute_image.debian-12.self_link
      size  = 10
      type  = "pd-balanced"
      labels = {
        my_label = "value"
      }
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.sa-subnet.id
    access_config {
      // Ephemeral public IP
      network_tier = "STANDARD"
    }
  }

  metadata = {
    startup-script = file("startup_script.sh")
  }

  service_account {
    email  = google_service_account.service_account["net2"].email
    scopes = ["cloud-platform"]
  }
  depends_on = [google_compute_network.nets]
}

# ASIA-PACIFIC INSTANCE

# For Windows RDP CX
data "google_compute_image" "windows-22" {
  family  = "windows-2022"
  project = "windows-cloud"
}

resource "google_compute_instance" "ap_instance" {
  name         = format("%s-instance", var.networks.net3.name)
  project      = var.networks.net3.project
  machine_type = "n2-standard-2"
  zone         = format("%s-a", local.instances.net4.region)

  tags = ["net", "worth"]

  boot_disk {
    auto_delete = true
    # add Windows 2022 Server image to boot disk
    initialize_params {
      image = data.google_compute_image.windows-22.self_link
      size  = 50
      type  = "pd-balanced"
      labels = {
        my_label = "value"
      }
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.ap-subnet.id
    access_config {
      // Ephemeral public IP
      network_tier = "STANDARD"
    }
  }

  metadata = {
    startup-script = file("startup_script.sh")
  }

  service_account {
    email  = google_service_account.service_account["net3"].email
    scopes = ["cloud-platform"]
  }

  depends_on = [google_compute_network.nets]
}

# ESTABLISH PEERING FROM AMERICAS TO EUROPE

# 1. AMERICAS PEER TO EUROPE
resource "google_compute_network_peering" "am2eu" {
  name         = "am-peering-2-eu"
  network      = google_compute_network.nets["net2"].id
  peer_network = google_compute_network.nets["net1"].id
}

# 2. EUROPE PEER TO AMERICAS
resource "google_compute_network_peering" "eu2am" {
  name         = "eu-peering-2-am"
  network      = google_compute_network.nets["net1"].id
  peer_network = google_compute_network.nets["net2"].id
}

# SET UP VPN FROM ASIA-PACIFIC TO EUROPE

# 1. CREATE STATIC IPs FOR ASIA-PACIFIC AND EUROPE

# ASIA-PACIFIC STATIC IP
resource "google_compute_address" "apsip" {
  name    = format("%s-static-ip", var.networks.net3.name)
  project = var.networks.net3.project
  region  = local.instances.net4.region
}

# EUROPE STATIC IP
resource "google_compute_address" "eusip" {
  name    = format("%s-static-ip", var.networks.net1.name)
  project = var.networks.net1.project
  region  = local.instances.net1.region
}

# ESTABLISH IPSEC CX FOR ASIA-PACIFIC TO EUROPE
resource "google_compute_vpn_gateway" "ap2eu" {
  name    = format("%s-gwy", var.networks.net3.name)
  project = var.networks.net3.project
  network = google_compute_network.nets["net3"].id
  region  = local.instances.net4.region
}

# ESTABLISH IPSEC CX FOR EUROPE TO ASIA-PACIFIC
resource "google_compute_vpn_gateway" "eu2ap" {
  name    = format("%s-gwy", var.networks.net1.name)
  project = var.networks.net1.project
  network = google_compute_network.nets["net1"].id
  region  = local.instances.net1.region
}

# FWD RULES FOR ASIA-PACIFIC TO EUROPE
resource "google_compute_forwarding_rule" "ap2eu" {
  for_each = var.vpn_fwd_rules

  name        = format("ap-2-eu-vpn-fwd-%s", each.key)
  project     = var.networks.net3.project
  target      = google_compute_vpn_gateway.ap2eu.id
  ip_address  = google_compute_address.apsip.address
  ip_protocol = each.value.ip_protocol
  port_range  = each.value.port_range
  region      = local.instances.net4.region
}

# FWD RULES FOR EUROPE TO ASIA-PACIFIC
resource "google_compute_forwarding_rule" "eu2ap" {
  for_each = var.vpn_fwd_rules

  name        = format("eu-2-ap-vpn-fwd-%s", each.key)
  project     = var.networks.net1.project
  target      = google_compute_vpn_gateway.eu2ap.id
  ip_address  = google_compute_address.eusip.address
  ip_protocol = each.value.ip_protocol
  port_range  = each.value.port_range
  region      = local.instances.net1.region
}

# VPN TUNNEL FROM ASIA-PACIFIC TO EUROPE
resource "google_compute_vpn_tunnel" "ap2eu" {
  name                    = "ap-2-eu-tunnel"
  project                 = var.networks.net3.project
  region                  = local.instances.net4.region
  peer_ip                 = google_compute_address.eusip.address
  shared_secret           = sensitive("itsasseacreature") # NEVER EXPOSE SECRETS/SENSITIVE INFO IN TF MODULE
  target_vpn_gateway      = google_compute_vpn_gateway.ap2eu.id
  local_traffic_selector  = [element(local.subnets, 3)]
  remote_traffic_selector = [element(local.subnets, 0)]

  depends_on = [google_compute_forwarding_rule.ap2eu["rule1"],
    google_compute_forwarding_rule.ap2eu["rule2"],
  google_compute_forwarding_rule.ap2eu["rule3"]]
}

# VPN TUNNEL FROM EUROPE TO ASIA-PACIFIC
resource "google_compute_vpn_tunnel" "eu2ap" {
  name                    = "eu-2-ap-tunnel"
  project                 = var.networks.net1.project
  region                  = local.instances.net1.region
  peer_ip                 = google_compute_address.apsip.address
  shared_secret           = sensitive("itsaseacreature") # NEVER EXPOSE SECRETS/SENSITIVE INFO IN TF MODULE
  target_vpn_gateway      = google_compute_vpn_gateway.eu2ap.id
  local_traffic_selector  = [element(local.subnets, 0)]
  remote_traffic_selector = [element(local.subnets, 3)]

  depends_on = [google_compute_forwarding_rule.eu2ap["rule1"],
    google_compute_forwarding_rule.eu2ap["rule2"],
  google_compute_forwarding_rule.eu2ap["rule3"]]
}

# Set up Next Hop FROM ASIA-PACIFIC to EUROPE
resource "google_compute_route" "ap2eu" {
  name                = "ap-hop-2-eu"
  project             = var.networks.net3.project
  dest_range          = element(local.subnets, 0)              # set dest_range to the Europe subnet
  network             = google_compute_network.nets["net3"].id # set network to ASIA-PACIFIC net
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.ap2eu.id     # set next_hop_vpn_tunnel to ap2eu tunnel

  depends_on = [google_compute_vpn_tunnel.ap2eu]
}

# Set up Next Hop FROM EUROPE TO ASIA-PACIFIC
resource "google_compute_route" "eu2ap" {
  name                = "eu-hop-2-ap"
  project             = var.networks.net1.project
  dest_range          = element(local.subnets, 3)              # set dest_range to the ASIA-PACIFIC subnet
  network             = google_compute_network.nets["net1"].id # set network to ASIA-PACIFIC net
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.eu2ap.id     # set next_hop_vpn_tunnel to eu2ap tunnel

  depends_on = [google_compute_vpn_tunnel.eu2ap]
}

output "Task_3" {
  value = "Solutions."
}

output "_1_subnet_europe-hq" {
  value = element(local.subnets, 0)
}

output "_1_subnet_northamerica" {
  value = element(local.subnets, 1)
}

output "_1_subnet_southamerica" {
  value = element(local.subnets, 2)
}

output "_1_subnet_asiapacific" {
  value = element(local.subnets, 3)
}

output "_2_internal_ip_europe" {
  value = google_compute_instance.eu_instance.network_interface[0].network_ip
}

output "_2_nat_ip_europe" {
  value = google_compute_instance.eu_instance.network_interface[0].access_config[0].nat_ip
}

output "_3_vpn_static_ip_europe" {
  value = google_compute_address.eusip.address
}

output "_4_vpn_static_ip_asia-pacific" {
  value = google_compute_address.apsip.address
}