data "openstack_images_image_v2" "image_data" {
  most_recent = true
  properties = {
    os_distro  = "almalinux"
    os_version = "90"
  }
}

data "openstack_networking_network_v2" "external_network" {
  name = "FloatingIP Net"
}

resource "openstack_networking_network_v2" "network" {
  name           = "network_name"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "subnet" {
  name        = "subnet_name"
  network_id  = openstack_networking_network_v2.network.id
  cidr        = "192.168.10.0/24"
  ip_version  = 4
  enable_dhcp = true
  depends_on  = [openstack_networking_network_v2.network]
}

resource "openstack_networking_router_v2" "router" {
  name                = "router_name"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external_network.id
}

resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id  = openstack_networking_router_v2.router.id
  subnet_id  = openstack_networking_subnet_v2.subnet.id
  depends_on = [openstack_networking_router_v2.router]
}

resource "openstack_compute_secgroup_v2" "security_group" {
  name        = "sg_name"
  description = "open ssh and http"
  dynamic "rule" {
    for_each = ["22", "80"]
    content {
      from_port   = rule.value
      to_port     = rule.value
      ip_protocol = "tcp"
      cidr        = "0.0.0.0/0"
    }
  }
  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_compute_instance_v2" "instance" {
  name            = "instance_name"
  flavor_name     = "d1.ram1cpu1"
  security_groups = [openstack_compute_secgroup_v2.security_group.id]
  config_drive    = true
  depends_on      = [openstack_networking_subnet_v2.subnet]
  user_data       = file("${path.module}/cloud-config/user_data.yml")

  network {
    uuid = openstack_networking_network_v2.network.id
  }

  block_device {
    source_type           = "image"
    uuid                  = data.openstack_images_image_v2.image_data.id
    destination_type      = "volume"
    volume_type           = "ceph-ssd" # "ceph-ssd" "ceph-hdd" "ceph-backup" "kz-ala-1-san-nvme-h1"
    volume_size           = 10
    delete_on_termination = true
  }
}

resource "openstack_networking_floatingip_v2" "fip" {
  pool = data.openstack_networking_network_v2.external_network.name
}

resource "openstack_compute_floatingip_associate_v2" "fip_association" {
  floating_ip = openstack_networking_floatingip_v2.fip.address
  instance_id = openstack_compute_instance_v2.instance.id
  fixed_ip    = openstack_compute_instance_v2.instance.access_ip_v4
}
