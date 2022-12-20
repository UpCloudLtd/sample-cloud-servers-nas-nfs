output "nfs_client_ip" {
  value = upcloud_server.nfs_client.network_interface[0].ip_address
}

output "nfs_server_ip" {
  value = upcloud_server.nas.network_interface[0].ip_address
}