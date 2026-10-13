variable "env" {
  description = "Environment name (production or staging). Used in resource names."
  type        = string
}

variable "node_count" {
  description = "Total number of VMs. Node 0 becomes the K3s server, the rest are agents."
  type        = number
  default     = 4

  validation {
    condition     = var.node_count >= 1
    error_message = "node_count must be at least 1."
  }
}

variable "hostname_base" {
  description = "VM hostname prefix; VMs are named <hostname_base>-0, <hostname_base>-1, ..."
  type        = string
  default     = "k3s-node"
}

variable "user_name" {
  description = "Login user created by cloud-init (must match ansible_user in the inventory)."
  type        = string
  default     = "server"
}

variable "ssh_keys" {
  description = "Public SSH keys authorised for user_name. Password login is disabled."
  type        = list(string)

  validation {
    condition     = length(var.ssh_keys) > 0
    error_message = "Provide at least one SSH public key."
  }
}

variable "vm_memory" {
  description = "Memory per VM in MiB."
  type        = number
  default     = 4096
}

variable "vm_vcpu" {
  description = "vCPUs per VM."
  type        = number
  default     = 2
}

variable "disk_size_gb" {
  description = "Root disk size per VM in GiB."
  type        = number
  default     = 40
}

variable "base_image" {
  description = "Fedora Cloud base image (qcow2) URL or local path on the host. Pin a specific release."
  type        = string
}

variable "storage_pool" {
  description = "libvirt storage pool for the disks."
  type        = string
  default     = "default"
}

variable "bridge" {
  description = "Host bridge the VMs attach to (created by the Ansible 'bridge' role)."
  type        = string
  default     = "br0"
}
