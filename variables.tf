variable "am_ingress" {
    type = map(object({
        protocol = string
        port = list(number)
    }))
}

variable "ap_ingress" {
  type = map(object({
        protocol = string
        port = list(number)
  }))
}

variable "eu_ingress" {
  type = map(object({
    protocol = string
    port    = list(number)
  }))
}

variable "networks" {
  type = map(object({
    name    = string
    project = string
  }))
}

variable "vpn_fwd_rules" {
  type = map(object({ # vpn forwarding rules for Asia-Pacific and Europe

    ip_protocol = string
    port_range  = string
    }
    )
  )
}