# Security policy

This is a personal homelab repository. Secrets are encrypted with SOPS (age) and Ansible Vault; no plaintext credentials should ever be committed.

## Reporting a problem

If you find a leaked credential or a vulnerability in anything published here, please open a private report through
**Security -> Report a vulnerability** on the repository page rather than a public issue.

## If a secret is ever committed

1. Rotate it immediately (Cloudflare tunnel token, GitHub PAT, age key, application passwords).
2. Remove it from Git history (`git filter-repo`); deleting the file in a new commit does not remove it.
3. Re-encrypt the replacement with `sops` and commit only the encrypted file.
