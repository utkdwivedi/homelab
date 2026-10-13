variable "host_ip" {
  description = "IP address of the production virtualization host."
  type        = string
}

variable "ssh_keys" {
  description = "Public SSH keys for the VM login user."
  type        = list(string)
}

variable "user_name" {
  type    = string
  default = "server"
}

variable "node_count" {
  type    = number
  default = 4
}

variable "hostname_base" {
  type    = string
  default = "k3s-node"
}

variable "vm_memory" {
  type    = number
  default = 4096
}

variable "vm_vcpu" {
  type    = number
  default = 2
}

variable "disk_size_gb" {
  type    = number
  default = 40
}

variable "base_image" {
  description = "Fedora Cloud qcow2 image. Download once on the host and reference the local path, or use a pinned URL."
  type        = string
}
