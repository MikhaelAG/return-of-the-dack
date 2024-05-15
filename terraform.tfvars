am_ingress = {
    "ingress1" = {
        protocol = "icmp"
        port = null
    }
    "ingress2" = {
        protocol = "tcp"
        port = [80]
    }
    "ingress3" = {
        protocol = "tcp"
        port = [22]
    }
}

ap_ingress = {
    "ingress1" = {
        protocol = "icmp"
        port = null
    }
    "ingress2" = {
        protocol = "tcp"
        port = [3389]
    }
}

eu_ingress = {
  "ingress1" = {
    protocol = "icmp"
    port    = null
  }
  "ingress2" = {
    protocol = "tcp"
    port    = [22]
  }
  "ingress3" = {
    protocol = "tcp"
    port    = [80]
  }
  "ingress4" = {
    protocol = "tcp"
    port    = [3389]
  }
}

networks = {
  "net1" = {
    name    = "spiel-mit-mir-hq"
    project = "terra-dome-420900"
  }
  "net2" = {
    name    = "spiel-mit-mir-americas"
    project = "terra-dome-2"
  }
  "net3" = {
    name    = "spiel-mit-mir-asia-pacific"
    project = "terra-dome-3"
  }
}

vpn_fwd_rules = { # vpn forwarding rules for Asia-Pacific and Europe
  rule1 = {
    ip_protocol = "ESP"
    port_range  = null
  }

  rule2 = {
    ip_protocol = "UDP"
    port_range  = "500"
  }

  rule3 = {
    ip_protocol = "UDP"
    port_range  = "4500"
  }
}
