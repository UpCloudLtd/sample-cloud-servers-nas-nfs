
resource "upcloud_network" "nas_network" {
  name = "nas-network"
  zone = var.zone

  ip_network {
    address            = var.nas_network
    dhcp               = true
    dhcp_default_route = false
    family             = "IPv4"
  }
}

resource "upcloud_storage" "nas_storage" {
  count = 4
  size  = var.storage_size
  tier  = "maxiops"
  title = "nas storage"
  zone  = var.zone
}

resource "upcloud_server" "nas" {
  hostname   = "nfs-server"
  zone       = var.zone
  plan       = var.nas_plan
  depends_on = [upcloud_network.nas_network]
  metadata   = true

  template {
    storage = "Ubuntu Server 22.04 LTS (Jammy Jellyfish)"
  }
  network_interface {
    type = "public"
  }
  network_interface {
    type = "private"
    network = upcloud_network.nas_network.id
  }
  storage_devices {
    storage = upcloud_storage.nas_storage[0].id
    address = "virtio"
  }
  storage_devices {
    storage = upcloud_storage.nas_storage[1].id
    address = "virtio"
  }
  storage_devices {
    storage = upcloud_storage.nas_storage[2].id
    address = "virtio"
  }
  storage_devices {
    storage = upcloud_storage.nas_storage[3].id
    address = "virtio"
  }
  login {
    user = "root"
    keys = [
      var.ssh_key_public,
    ]
    create_password   = false
    password_delivery = "email"
  }

  connection {
    host  = self.network_interface[0].ip_address
    type  = "ssh"
    user  = "root"
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get -y update",
      "apt-get -y install nfs-kernel-server zfsutils-linux",
      "zpool create data mirror /dev/vdb /dev/vdc mirror /dev/vdd /dev/vde",
      "zfs create data/nfs",
      "zfs set sync=disabled data/nfs",
      "mkdir -p /data",
      "echo '/data         ${upcloud_network.nas_network.ip_network[0].address}(rw,sync,no_subtree_check,no_root_squash)' >> /etc/exports",
      "chown nobody:nogroup -R /data/",
      "exportfs -ar"
    ]
  }
}

resource "upcloud_server" "nfs_client" {
  hostname   = "nfs-client"
  zone       = var.zone
  plan       = var.client_plan
  metadata   = true
  depends_on = [upcloud_network.nas_network,upcloud_server.nas]

  template {
    storage = "Ubuntu Server 22.04 LTS (Jammy Jellyfish)"
  }
  network_interface {
    type = "public"
  }
  network_interface {
    type = "private"
    network = upcloud_network.nas_network.id
  }

  login {
    user = "root"
    keys = [
      var.ssh_key_public,
    ]
    create_password   = false
    password_delivery = "email"
  }

  connection {
    host  = self.network_interface[0].ip_address
    type  = "ssh"
    user  = "root"
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get -y install nfs-client nfs-common",
      "mkdir -p /data",
      "mount ${upcloud_server.nas.network_interface[1].ip_address}:/data /data",
      "echo \"${upcloud_server.nas.network_interface[1].ip_address}:/data /data nfs auto,nofail,noatime,nodiratime,nolock,rsize=1048576,wsize=1048576 0 0\" >> /etc/fstab"
    ]
  }
}

