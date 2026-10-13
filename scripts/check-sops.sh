#!/usr/bin/env bash
# Fail if any *.sops.yaml file is not SOPS-encrypted, or if a plaintext Secret manifest is committed.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

status=0
while IFS= read -r -d '' file; do
  if ! grep -q '^sops:' "$file" || ! grep -q 'ENC\[AES256_GCM' "$file"; then
    echo "NOT ENCRYPTED: $file" >&2
    status=1
  fi
done < <(git ls-files -z -- '*.sops.yaml' '*.sops.yml' ':!:.sops.yaml')

# Any Secret manifest that is not named *.sops.yaml must not exist.
while IFS= read -r file; do
  case "$file" in
    *.sops.yaml | *.sops.yml) ;;
    *)
      if grep -qE '^kind:[[:space:]]*Secret[[:space:]]*$' "$file"; then
        echo "PLAINTEXT SECRET (rename to *.sops.yaml and encrypt): $file" >&2
        status=1
      fi
      ;;
  esac
done < <(git ls-files '*.yaml' '*.yml' | grep -v '^provisioning/ansible/' | grep -v 'gotk-components.yaml' | grep -v 'helm' || true)

# The Ansible vault must be encrypted.
vault="provisioning/ansible/inventory/group_vars/all/secrets.yml"
if [ -f "$vault" ] && ! head -n1 "$vault" | grep -q '^\$ANSIBLE_VAULT;'; then
  echo "ANSIBLE VAULT NOT ENCRYPTED: $vault" >&2
  status=1
fi

[ "$status" -eq 0 ] && echo "All secrets are encrypted."
exit "$status"
