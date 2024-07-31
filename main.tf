variable "app_token" {
  type = string
}

variable "yawm_url" {
  type = string
}

locals {
  regions = toset(["fr-par", "nl-ams"])
  zones   = toset(["fr-par-1", "fr-par-2", "nl-ams-1", "nl-ams-2"])
}

resource "random_uuid" "mesh" {}

resource "scaleway_vpc" "vpc" {
  for_each       = local.regions
  region         = each.key
  name           = "demo"
  enable_routing = true
}

resource "scaleway_vpc_private_network" "pn" {
  for_each = local.regions
  region   = each.key
  name     = "demo"
  vpc_id   = scaleway_vpc.vpc[each.key].id
}

resource "scaleway_ipam_ip" "vip" {
  for_each = local.regions
  region   = each.key
  source {
    private_network_id = scaleway_vpc_private_network.pn[each.key].id
  }
}

resource "scaleway_instance_ip" "ip" {
  for_each = local.zones
  type     = "routed_ipv4"
  zone     = each.key
}

resource "scaleway_instance_security_group" "vpn" {
  for_each                = local.zones
  zone                    = each.key
  name                    = format("vpn-%s", join("-", slice(split("-", each.key), 1, 3)))
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"

  inbound_rule {
    action   = "accept"
    protocol = "TCP"
    port     = "22"
  }

  inbound_rule {
    action   = "accept"
    protocol = "UDP"
    port     = "52435"
  }
}

resource "scaleway_instance_server" "srv" {
  for_each          = local.zones
  zone              = each.key
  name              = join("-", slice(split("-", each.key), 1, 3))
  image             = "ubuntu_jammy"
  type              = "PLAY2-PICO"
  security_group_id = scaleway_instance_security_group.vpn[each.key].id
  ip_id             = scaleway_instance_ip.ip[each.key].id

  private_network {
    pn_id = scaleway_vpc_private_network.pn[join("-", slice(split("-", each.key), 0, 2))].id
  }

  root_volume {
    delete_on_termination = true
  }

  user_data = {
    cloud-init = <<-EOT
    #cloud-config
    runcmd:
    - apt-get update
    - apt-get install wireguard -y
    - "curl -X POST -H \"X-Auth-Token: ${var.app_token}\" ${var.yawm_url}/${random_uuid.mesh.result}"
    - sleep 1m
    - "curl -X GET -H \"X-Auth-Token: ${var.app_token}\" ${var.yawm_url}/${random_uuid.mesh.result} > /etc/wireguard/wg0.conf"
    - systemctl enable --now wg-quick@wg0
    EOT
  }
}

output "servers" {
  value = [for instance in scaleway_instance_server.srv : "${instance.name}: ssh root@${instance.public_ip}"]
}

output "vips" {
  value = [for vip in scaleway_ipam_ip.vip : "${vip.region}: ${split("/", vip.address)[0]}"]
}
