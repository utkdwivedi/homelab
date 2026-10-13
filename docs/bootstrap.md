# Bootstrap: from bare host to running cluster

Everything below is run from your workstation. `ENV` defaults to `production`; add `ENV=staging` to every `make` command for staging.

## 1. Prerequisites

- A Fedora Server/Workstation host on **wired Ethernet** (the bridge `br0` cannot use Wi-Fi), with VT-x/AMD-V enabled in the BIOS and your SSH public key in `~/.ssh/authorized_keys`.
- Tools installed locally (versions in `.tool-versions`): `terraform`, `ansible`, `kubectl`, `sops`, `age`, `make`.
- A NAS exporting NFS shares for the paths in `infrastructure/base/storage/`.
- A Cloudflare Zero Trust tunnel and its token (see [secrets.md](secrets.md)).

## 2. Configure

1. `make deps` installs the Ansible collections (`kubernetes.core`, `community.libvirt`, `ansible.posix`).
2. Edit `config/<env>.env` (host IP) and `provisioning/ansible/inventory/inventory.<env>.ini` (VM IPs). VM IPs are assigned by DHCP; reserve them in your router so they stay stable.
3. Create the Terraform variables (key-only SSH, there is no password):
   ```bash
   cd provisioning/terraform/production
   cp terraform.tfvars.example terraform.tfvars   # gitignored
   ```
4. Create the Ansible Vault password file `provisioning/ansible/.vault_pass` (one line, gitignored), then add the two bootstrap secrets with `make edit-vault`:
   ```yaml
   vault_github_token: "<fine-grained PAT, contents:read on this repo only>"
   sops_age_private_key: "AGE-SECRET-KEY-..."
   ```

## 3. Build

```bash
source scripts/env.sh production
make provision-host     # KVM/libvirt, bridge br0, Tailscale (asks for the sudo password)
make init apply         # creates the VMs; node 0 is the K3s server
make wait-vms           # waits until every VM answers over SSH
make provision          # K3s + Cilium + Flux bootstrap
```

`make provision` writes `<env>_kubeconfig.yaml` in the repo root (gitignored). `source scripts/env.sh` points `KUBECONFIG` at it.

## 4. Verify

```bash
make flux-status                      # GitRepository ready, Kustomizations Ready=True
kubectl get nodes -o wide             # all nodes Ready
kubectl -n kube-system exec ds/cilium -- cilium status --brief   # OK
kubectl get ciliumloadbalancerippool  # pool present
kubectl get pods -A                   # nothing stuck in Pending/CrashLoopBackOff
```

Flux order: `infrastructure` first, then `monitoring`, `policies` and `services`. If a Kustomization is stuck, `flux get kustomizations` and `kubectl -n flux-system describe kustomization <name>` show why. A common cause is a missing `sops-age` secret.

## Rebuilding

`make rebuild ENV=staging CONFIRM=staging` destroys and recreates the VMs. The same `CONFIRM=<env>` guard protects `destroy` and `auto-rebuild`.
