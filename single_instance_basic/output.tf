output "image" {
  value = data.openstack_images_image_v2.image_data.name
}

output "public_ip" {
  value = openstack_networking_floatingip_v2.fip.address
}
