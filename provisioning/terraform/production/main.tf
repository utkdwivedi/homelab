module "k3s_vms" {
  source = "../modules/k3s-vms"

  env           = "production"
  node_count    = var.node_count
  hostname_base = var.hostname_base
  user_name     = var.user_name
  ssh_keys      = var.ssh_keys
  vm_memory     = var.vm_memory
  vm_vcpu       = var.vm_vcpu
  disk_size_gb  = var.disk_size_gb
  base_image    = var.base_image
}

provider "libvirt" {
  uri = "qemu+ssh://${var.user_name}@${var.host_ip}/system"
}

output "vm_ips" {
  value = module.k3s_vms.vm_ips
}
