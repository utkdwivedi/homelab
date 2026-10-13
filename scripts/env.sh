#!/usr/bin/env bash
# Prepare a shell for working on one environment. Must be sourced:
#   source scripts/env.sh [production|staging]
# Sets ENV, ANSIBLE_CONFIG, ANSIBLE_INVENTORY and KUBECONFIG and loads your SSH key.

if ! (return 0 2>/dev/null); then
  echo "Error: this script must be sourced." >&2
  echo "Usage: source scripts/env.sh [production|staging]" >&2
  exit 1
fi

_homelab_env() {
  local repo_root env config key kubeconfig server
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  env="${1:-${ENV:-production}}"

  case "$env" in
    production | staging) ;;
    *)
      echo "Error: environment must be 'production' or 'staging', got '$env'." >&2
      return 1
      ;;
  esac

  config="$repo_root/config/$env.env"
  if [ ! -f "$config" ]; then
    echo "Error: missing $config" >&2
    return 1
  fi

  # shellcheck disable=SC1090
  set -a && . "$config" && set +a

  key="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
  if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    echo "> Starting SSH agent..."
    eval "$(ssh-agent -s)" > /dev/null
  fi
  if [ -f "$key" ] && ! ssh-add -l 2> /dev/null | grep -qF "$(ssh-keygen -lf "$key" | awk '{print $2}')"; then
    echo "> Adding SSH key $key..."
    ssh-add "$key"
  fi

  export ENV="$env"
  export ANSIBLE_CONFIG="$repo_root/provisioning/ansible/ansible.cfg"
  export ANSIBLE_INVENTORY="$repo_root/provisioning/ansible/inventory/inventory.$env.ini"

  kubeconfig="$repo_root/${env}_kubeconfig.yaml"
  if [ -f "$kubeconfig" ]; then
    export KUBECONFIG="$kubeconfig"
    server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2> /dev/null)"
  else
    echo "> No $kubeconfig yet; it is created by 'make provision'."
  fi

  echo "------------------------------"
  echo "ENV:               $ENV"
  echo "HOST_IP:           ${HOST_IP:-unset}"
  echo "ANSIBLE_CONFIG:    $ANSIBLE_CONFIG"
  echo "ANSIBLE_INVENTORY: $ANSIBLE_INVENTORY"
  echo "KUBECONFIG:        ${KUBECONFIG:-unset}"
  echo "K3S API SERVER:    ${server:-unknown}"
  echo "> $env env ready"
  echo "------------------------------"
}

_homelab_env "$@"
_homelab_status=$?
unset -f _homelab_env
return "$_homelab_status"
