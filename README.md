# Homelab — GitOps Kubernetes Cluster

[![document](https://img.shields.io/website?label=document&logo=gitbook&logoColor=white&style=flat-square&url=https%3A%2F%2Fhomelab.khuedoan.com)](https://homelab.khuedoan.com)
[![license](https://img.shields.io/github/license/utkdwivedi/homelab?style=flat-square&logo=gnu&logoColor=white)](https://www.gnu.org/licenses/gpl-3.0.html)
[![stars](https://img.shields.io/github/stars/utkdwivedi/homelab?logo=github&logoColor=white&color=gold&style=flat-square)](https://github.com/utkdwivedi/homelab)

An automated, declarative **K3s Kubernetes homelab** running self-hosted services with end-to-end Infrastructure as Code (IaC) and GitOps reconciliation.

Maintained by **Utkarsh Dwivedi** ([@utkdwivedi](https://github.com/utkdwivedi)).

---

## Overview

This repository automates the entire lifecycle of a production-grade homelab cluster:
- **Bare-metal & Virtualization**: Host provisioning with Fedora, KVM/QEMU, and libvirt.
- **Infrastructure as Code**: Terraform module to spin up bridged Fedora Cloud VMs with cloud-init.
- **Configuration Management**: Ansible playbooks for system hardening, K3s installation, Cilium CNI bootstrapping, and storage configuration.
- **GitOps Continuous Delivery**: FluxCD controllers reconciling cluster state directly from this Git repository.
- **Observability**: Complete monitoring stack with Prometheus, Grafana, AlertManager, kube-state-metrics, and node-exporter.
- **Policy Enforcement**: Kyverno validating policies for resource boundaries.
- **Encrypted Secrets**: SOPS + age encryption integrated directly with FluxCD and Ansible Vault.
- **Zero-Trust Access**: Cloudflare Tunnel for secure external connectivity without opening firewall ports.

---

## Architecture

```mermaid
flowchart TD
    subgraph Hardware ["Hardware Layer"]
        Host["Linux Host (Fedora + KVM/QEMU)"]
        NAS["NAS Storage (TrueNAS / NFS: 192.168.0.104)"]
        WS["Admin Workstation"]
    end

    subgraph IaC ["IaC & Bootstrapping Pipeline"]
        TF["Terraform (libvirt provider)"]
        Ansible["Ansible Playbooks"]
        TF -->|"Provisions bridged VMs"| Host
        Ansible -->|"Bootstraps K3s & Cilium"| Host
    end

    subgraph Cluster ["K3s Kubernetes Cluster"]
        Cilium["Cilium CNI & L2 Load Balancer"]
        Flux["FluxCD GitOps Engine"]
        Storage["NFS Subdir Provisioner"]
        Kyverno["Kyverno Policy Engine"]
        Cloudflare["Cloudflare Tunnel (cloudflared)"]
    end

    subgraph Apps ["Workloads & Services"]
        Jellyfin["Jellyfin (Media Server)"]
        SilverBullet["SilverBullet (Notes)"]
        Karakeep["Karakeep (Bookmarks + Search)"]
    end

    subgraph Observability ["Monitoring Stack"]
        Prom["Prometheus"]
        Graf["Grafana"]
        Alert["AlertManager"]
        KSM["kube-state-metrics"]
        NodeExp["node-exporter"]
    end

    WS -->|"make apply && make provision"| IaC
    IaC --> Cluster
    Flux -->|"Reconciles manifests"| Cluster
    Flux --> Apps
    Flux --> Observability
    Storage -->|"NFS persistent volumes"| NAS
    Cloudflare -->|"Secure ingress (*.utkdwivedi.com)"| Apps
    Cloudflare -->|"Secure ingress"| Graf
```

---

## Setup & Deployment

### Prerequisites

| Item | Default Value | Description |
|------|---------------|-------------|
| **Production Host IP** | `192.168.0.111` | Primary Fedora virtualization host |
| **Staging Host IP** | `192.168.0.109` | Optional staging virtualization host |
| **NAS Storage IP** | `192.168.0.104` | NFS server hosting persistent volume shares |
| **Cilium LB IP Pool** | `192.168.0.200/29` | IP range allocated for cluster load balancers |

> [!NOTE]
> If your local network configuration differs, adjust the IPs in `Makefile`, `scripts/env.sh`, and `provisioning/terraform/*/variables.tf`.

1. **Prepare Fedora Host:**
   - Fresh install of Fedora Server or Workstation.
   - Connected via Ethernet (required for NetworkManager `br0` bridge).
   - Ensure hardware virtualization (VT-x / AMD-V) is enabled in BIOS.
   - Add your workstation SSH key to `~/.ssh/authorized_keys`.

2. **Configure Terraform Variables:**
   Create `terraform.tfvars` under `provisioning/terraform/production` (and `staging/` if using dual environments):
   ```hcl
   # Credentials
   server_password = "YOUR_VM_PASSWORD"
   ssh_keys = [
     "YOUR_PUBLIC_SSH_KEY"
   ]

   # Node Specifications
   node_count    = 3
   vm_memory     = "4096"
   vm_vcpu       = 2
   user_name     = "server"
   hostname_base = "k3s-node"
   env           = "production"
   host_ip       = "192.168.0.111"
   ```

3. **Ansible Secrets & SOPS Key:**
   - Ensure an age keypair is generated: `age-keygen -o key.txt`
   - Place public key in `.sops.yaml`.
   - Store the age private key and your GitHub PAT in Ansible Vault (`provisioning/ansible/inventory/group_vars/all/secrets.yml`).

4. **Execute Provisioning Pipeline:**
   ```bash
   source scripts/env.sh   # Sets up environment variables and SSH agent

   make provision-host     # Configures KVM/libvirt, bridge (br0), and base packages
   make apply              # Deploys VMs using Terraform
   make provision          # Bootstraps K3s, Cilium CNI, and FluxCD
   ```

5. **External Ingress via Cloudflare Tunnel:**
   Services are exposed securely using Cloudflare Zero-Trust Tunnel (no open inbound router ports required):
   - Create a tunnel in Cloudflare Zero Trust Dashboard.
   - Add the tunnel token into `infrastructure/base/networking/secret.sops.yaml` using SOPS.
   - Point your domain CNAMEs to `<tunnel-id>.cfargotunnel.com`.

---

## Repository Structure

```
.
├── clusters/                # FluxCD GitOps entrypoints
│   ├── production/          # Production cluster kustomizations
│   └── staging/             # Staging cluster kustomizations
├── infrastructure/          # Core Kubernetes infrastructure
│   ├── base/                # Base manifests
│   │   ├── kyverno/         # Policy engine deployment
│   │   ├── namespaces/      # Cluster namespaces
│   │   ├── networking/      # Cilium IP pool, L2 policies, Cloudflare Tunnel
│   │   └── storage/         # NFS subdir external provisioner & StorageClasses
│   ├── production/          # Environment overlays
│   └── staging/
├── monitoring/              # Observability stack
│   ├── base/
│   │   ├── alertmanager/    # Alert routing
│   │   ├── grafana/         # Dashboards and visualization
│   │   ├── kube-state-metrics/
│   │   ├── node-exporter/   # Host metrics collector
│   │   └── prometheus/      # Metrics engine and storage
│   ├── production/
│   └── staging/
├── policies/                # Kyverno validation and governance policies
│   ├── base/
│   ├── production/
│   └── staging/
├── provisioning/            # Infrastructure as Code
│   ├── terraform/           # Libvirt/QEMU VM provisioning modules
│   └── ansible/             # Host and node configuration playbooks
├── resources/               # Dashboard templates & static assets
├── scripts/                 # Shell automation and environment helpers
├── services/                # Application workloads
│   ├── base/
│   │   ├── jellyfin/        # Media streaming
│   │   ├── karakeep/        # Bookmark manager with search & headless browser
│   │   └── silverbullet/    # Extensible markdown notebook
│   ├── production/
│   └── staging/
├── Makefile                 # Top-level orchestration
└── LICENSE                  # MIT License
```

---

## Tooling overview

### Hardware
| Logo | Device | Role |
|:-:|-----|-------------|
| ![Lenovo](https://cdn.simpleicons.org/lenovo?size=32) | Lenovo Thinkpad T14 Gen 1 | Production |
| ![Lenovo](https://cdn.simpleicons.org/lenovo?size=32) | Lenovo Thinkcentre M700 | Staging |
| ![HP](https://cdn.simpleicons.org/hp?size=32) | HP EliteDesk 800 G2 SFF 2x1TB WD Red | NAS |
| ![Lenovo](https://cdn.simpleicons.org/lenovo?size=32) | Lenovo Legion 5 Slim | Workstation |

### Infrastructure
| Logo | Name | Description |
|:-:|-----|-------------|
| ![Fedora](https://cdn.simpleicons.org/fedora?size=32) | Fedora | Linux Distribution used on Host, VMs and Workstation |
| ![TrueNAS](https://cdn.simpleicons.org/truenas?size=32) | TrueNAS | Open-source unified storage operating system based on OpenZFS |
| ![QEMU](https://cdn.simpleicons.org/qemu?size=32) | QEMU/KVM | Hypervisor for running virtual machines |
| ![K3s](https://cdn.simpleicons.org/k3s?size=32) | K3s | Lightweight Kubernetes engine |
| ![FluxCD](https://cdn.simpleicons.org/flux?size=32) | FluxCD | GitOps tool for managing Kubernetes declaratively |
| ![Terraform](https://cdn.simpleicons.org/terraform?size=32) | Terraform | IaC tool for provisioning infrastructure declaratively |
| ![Ansible](https://cdn.simpleicons.org/ansible/f00?size=32) | Ansible | Automation tool for post-provisioning configuration and orchestration |
| ![SOPS](https://cdn.simpleicons.org/privateinternetaccess/000?size=32) | SOPS | Secret OPerationS - tool for managing secrets |
| ![Cilium](https://cdn.simpleicons.org/cilium/size=32) | Cilium | Solution for providing, securing, and observing network connectivity |
| <img src="https://raw.githubusercontent.com/kyverno/artwork/5be18d691ae2b42beb898ffc1312024975749bd8/Kyverno.svg" width="32" height="32" /> | Kyverno | Unified Policy as Code solution |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/cloudflare-zero-trust.png" width="32" height="32" />  | Cloudflare | Zero-Trust Tunnel for exposing services securely on a the internet |



### Monitoring
| Logo | Name | Description |
|:-:|-----|-------------|
| ![Prometheus](https://cdn.simpleicons.org/prometheus?size=32) | Prometheus | Scrapes infrastructure metrics for visualization in Grafana |
| ![AlertManager](https://cdn.simpleicons.org/prometheus/f51d1d?size=32) | AlertManager | Sends notifications and alerts based on Prometheus metrics |
| ![Grafana](https://cdn.simpleicons.org/grafana?size=32) | Grafana | Dashboard and visualization for metrics collected by Prometheus |
| ![kube-state-metrics](https://cdn.simpleicons.org/cncf/5EC5EB?size=32) | kube-state-metrics | Exposes Kubernetes cluster-level metrics for Prometheus |
| ![node-exporter](https://cdn.simpleicons.org/prometheus?size=32) | node-exporter | Collects host-level metrics for Prometheus |
| ![K9s](https://cdn.simpleicons.org/kubernetes?size=32) | k9s | CLI tool to interactively view Kubernetes resources |
| ![K9s](https://cdn.simpleicons.org/uptimekuma?size=32) | Uptime Kuma | Alternative monitoring running as TrueNAS App |

### Services
| Logo | Name | Description |
|:-:|-----|-------------|
| ![Jellyfin](https://cdn.simpleicons.org/jellyfin?size=32) | Jellyfin | Media streaming service | 
| <img src="https://repository-images.githubusercontent.com/459944886/a6e61d23-9090-4cc4-946d-c5d9c189240f" width="32" height="32" /> | SilverBullet.md | Programmable browser-based Markdown editor |
| ![Karakeep](https://cdn.simpleicons.org/karakeep?size=32) | Karakeep | Bookmark manager | 


### Backup Strategy

The homelab follows a **3-2-1 backup strategy**:

| Logo | Name | Description |
|:-:|-----|-------------|
| ![TrueNAS](https://cdn.simpleicons.org/truenas?size=32) | TrueNAS | Primary local storage - 2x 1TB WD Red ZFS mirror |
| <img src="https://images.icon-icons.com/61/PNG/128/lightbrown_external_drive_usb_folder_12286.png" width="32" height="32" /> | External SSD | Secondary local copy for critical data |
| ![Backblaze](https://cdn.simpleicons.org/backblaze?size=32) | Backblaze B2 | Offsite cloud storage via TrueNAS Cloud Sync |

>[!TIP]
> Infrastructure configs and other version-controlled assets also live on GitHub, adding a fourth copy for the most critical data.


## License

Distributed under the MIT License. See [LICENSE](LICENSE) for full details.
