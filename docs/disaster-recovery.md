# Disaster recovery

## What is protected

| Item | Protection | Recovery |
| --- | --- | --- |
| Cluster configuration | Git (this repository) | Rebuild: Terraform, Ansible, Flux re-applies everything |
| App data on NFS (Jellyfin config and media, Karakeep, SilverBullet, Grafana, Alertmanager) | TrueNAS ZFS mirror, external SSD, Backblaze B2 | Restore datasets on the NAS; PVs reattach by path |
| Prometheus history | **None** (node `hostPath`) | Lost on node loss; metrics only |
| K3s datastore (etcd/SQLite) | **None** | Not needed: state is rebuilt from Git |
| age private key | Ansible Vault + an offline copy | Required to decrypt secrets after a rebuild |

## Host died

1. Install Fedora on replacement hardware, wired Ethernet, SSH key in place. Give it the same IP (or update `config/<env>.env` and the inventory).
2. `source scripts/env.sh production`
3. `make provision-host && make init apply && make wait-vms && make provision`
4. `make flux-status` until every Kustomization is Ready. PVs on the NAS reattach automatically (`reclaimPolicy: Retain`).

Needs from outside the repo: `.vault_pass`, the Cloudflare tunnel (unchanged, the token is in Git), your SSH key, and the NAS reachable at the configured address.

## NAS died

Restore the datasets from the external SSD or Backblaze B2 (TrueNAS Cloud Sync pull). Keep the same export paths (`/mnt/data/config`, `/mnt/data/media`) so the StorageClasses and PVs match.

## Rehearse it

Untested backups are not backups. At least once, in staging: `make rebuild ENV=staging CONFIRM=staging`, restore one app's data from backup, and confirm the app serves it. Record the time it took here.
