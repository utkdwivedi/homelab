# Secrets

| Secret | Stored in | Used by |
| --- | --- | --- |
| Kubernetes secrets (Cloudflare tunnel token, Grafana admin, SilverBullet and Karakeep credentials) | `*.sops.yaml`, encrypted with age | Flux (decrypts in-cluster) |
| age private key | Ansible Vault (`sops_age_private_key`), **and a copy outside this repo** (password manager) | Bootstrap creates the `sops-age` secret |
| GitHub token for Flux | Ansible Vault (`vault_github_token`) | Bootstrap creates the `flux-system` secret |
| Vault password | `provisioning/ansible/.vault_pass` (gitignored) | Ansible |

## Add or change a Kubernetes secret

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
sops services/base/<app>/secret.sops.yaml      # edit in place; only data/stringData is encrypted
```

New file? Write the manifest, name it `*.sops.yaml`, then `sops --encrypt --in-place <file>`. `.sops.yaml` selects the recipient and encrypts only `data`/`stringData`. `make check-secrets` (also run in CI) fails if a `*.sops.yaml` is not encrypted or a plaintext `kind: Secret` exists anywhere else.

## Rotate

- **Cloudflare token / app passwords:** edit with `sops`, commit; Flux applies it. Restart the workload if it reads the secret at start-up.
- **age key:** generate a new key, update the recipient in `.sops.yaml`, run `sops updatekeys` on every `*.sops.yaml`, update `sops_age_private_key` in the vault, and replace the `sops-age` secret in the cluster.
- **GitHub token:** create a new fine-grained token (read-only, this repository, with an expiry date), update the vault, and replace the `flux-system` secret.

## If something leaks

Rotate first, then purge from history (`git filter-repo`). Deleting the file in a new commit does not remove it from history. CI runs gitleaks on every push.

## Back up the age key

If you lose the age private key, every `*.sops.yaml` is unrecoverable. Keep a copy outside this repository and outside the cluster.
