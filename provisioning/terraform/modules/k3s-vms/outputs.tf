output "vm_ips" {
  description = "IP addresses reported by the QEMU guest agent, keyed by VM name. Empty until the guests have booted; run `make get-ips`."
  value = {
    for d in libvirt_domain.node : d.name => try(flatten(d.network_interface[*].addresses), [])
  }
}
