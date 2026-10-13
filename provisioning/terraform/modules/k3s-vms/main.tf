locals {
  name_prefix = "${var.hostname_base}-%d"
}

resource "libvirt_volume" "base" {
  name   = "${var.hostname_base}-${var.env}-base.qcow2"
  pool   = var.storage_pool
  source = var.base_image
  format = "qcow2"
}

resource "libvirt_volume" "node" {
  count          = var.node_count
  name           = "${var.hostname_base}-${var.env}-${count.index}.qcow2"
  pool           = var.storage_pool
  base_volume_id = libvirt_volume.base.id
  format         = "qcow2"
  size           = var.disk_size_gb * 1024 * 1024 * 1024
}

resource "libvirt_cloudinit_disk" "node" {
  count = var.node_count
  name  = "${var.hostname_base}-${var.env}-init-${count.index}.iso"
  pool  = var.storage_pool

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    hostname  = format(local.name_prefix, count.index)
    user_name = var.user_name
    ssh_keys  = var.ssh_keys
  })
}

resource "libvirt_domain" "node" {
  count     = var.node_count
  name      = "${format(local.name_prefix, count.index)}-${var.env}"
  memory    = var.vm_memory
  vcpu      = var.vm_vcpu
  autostart = true

  # Needed so libvirt can report the guest IP on a bridged network.
  qemu_agent = true
  cloudinit  = libvirt_cloudinit_disk.node[count.index].id

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.node[count.index].id
  }

  network_interface {
    bridge = var.bridge
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  lifecycle {
    # The base image URL changes over time; do not rebuild running nodes because of it.
    ignore_changes = [cloudinit]
  }
}
