#!/usr/bin/env bash
# Build every Kustomize overlay and validate the result.
# Needs: kustomize (or kubectl), and optionally kubeconform for schema checks.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

python3 scripts/check_kustomize_refs.py

if command -v kustomize > /dev/null; then
  build=(kustomize build)
elif command -v kubectl > /dev/null; then
  build=(kubectl kustomize)
else
  echo "kustomize/kubectl not found; only the offline reference check ran." >&2
  exit 0
fi

status=0
for dir in clusters/production clusters/staging \
  infrastructure/production infrastructure/staging \
  monitoring/production monitoring/staging \
  policies/production policies/staging \
  services/production services/staging; do
  echo "> building $dir"
  if ! out="$("${build[@]}" "$dir")"; then
    status=1
    continue
  fi
  if command -v kubeconform > /dev/null; then
    printf '%s\n' "$out" | kubeconform -strict -ignore-missing-schemas -summary \
      -schema-location default \
      -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' || status=1
  fi
done
exit "$status"
