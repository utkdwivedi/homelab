# Homelab orchestration. Run `make` for the list of targets.
.DEFAULT_GOAL := help
SHELL := /bin/bash

ENV ?= production
ifeq ($(filter $(ENV),production staging),)
$(error ENV must be 'production' or 'staging', got '$(ENV)')
endif

# HOST_IP and HOST_NAME come from config/<env>.env
-include config/$(ENV).env

REPO_ROOT       := $(abspath $(CURDIR))
ANSIBLE_DIR     := $(REPO_ROOT)/provisioning/ansible
TERRAFORM_DIR   := $(REPO_ROOT)/provisioning/terraform/$(ENV)
INVENTORY       := inventory/inventory.$(ENV).ini
# Use provisioning/ansible/.vault_pass (gitignored, one line) when present, otherwise prompt.
VAULT_OPTS      := $(if $(wildcard $(ANSIBLE_DIR)/.vault_pass),--vault-password-file $(ANSIBLE_DIR)/.vault_pass,--ask-vault-pass)
ANSIBLE_OPTS    := -i $(INVENTORY) $(VAULT_OPTS)
KUBECONFIG_FILE := $(REPO_ROOT)/$(ENV)_kubeconfig.yaml

# Destructive targets need CONFIRM=<env> (for example: make destroy ENV=staging CONFIRM=staging).
define require_confirm
	@if [ "$(CONFIRM)" != "$(ENV)" ]; then \
	  echo "Refusing to run: this is destructive for '$(ENV)'. Re-run with CONFIRM=$(ENV)."; \
	  exit 1; \
	fi
endef

.PHONY: help deps ping init plan apply destroy get-ips wait-vms rebuild auto-rebuild \
        provision-host provision edit-vault flux-status lint validate check-secrets

help: ## Show this help
	@echo "Usage: make <target> [ENV=production|staging]   (current: $(ENV), host $(HOST_IP))"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*## ' Makefile | sed -E 's/:.*## /\t/' | awk -F'\t' '{printf "  %-16s %s\n", $$1, $$2}'

deps: ## Install Ansible collections (kubernetes.core, community.libvirt, ansible.posix)
	cd $(ANSIBLE_DIR) && ansible-galaxy collection install -r requirements.yml

ping: ## Test Ansible connectivity to every host
	cd $(ANSIBLE_DIR) && ansible everything $(ANSIBLE_OPTS) -m ping

init: ## terraform init
	cd $(TERRAFORM_DIR) && terraform init

plan: ## terraform plan
	cd $(TERRAFORM_DIR) && terraform plan

apply: ## terraform apply (create the VMs)
	cd $(TERRAFORM_DIR) && terraform apply

destroy: ## terraform destroy (needs CONFIRM=<env>)
	$(require_confirm)
	cd $(TERRAFORM_DIR) && terraform destroy

get-ips: ## Refresh and print the VM IP addresses reported by the guest agent
	cd $(TERRAFORM_DIR) && terraform apply -refresh-only -auto-approve > /dev/null && terraform output vm_ips

wait-vms: ## Wait until every VM answers over SSH (up to ~5 minutes)
	cd $(ANSIBLE_DIR) && for i in $$(seq 1 30); do \
	  ansible vms $(ANSIBLE_OPTS) -m ping > /dev/null 2>&1 && echo "All VMs reachable" && exit 0; \
	  echo "Waiting for VMs ($$i/30)..."; sleep 10; \
	done; echo "VMs did not become reachable"; exit 1

rebuild: ## Destroy and recreate the VMs, then wait for them (needs CONFIRM=<env>)
	$(require_confirm)
	$(MAKE) destroy apply wait-vms ENV=$(ENV) CONFIRM=$(CONFIRM)

auto-rebuild: ## Non-interactive rebuild + provision (needs CONFIRM=<env>)
	$(require_confirm)
	cd $(TERRAFORM_DIR) && terraform destroy -auto-approve
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve
	$(MAKE) wait-vms ENV=$(ENV)
	$(MAKE) provision ENV=$(ENV)
	$(MAKE) get-ips ENV=$(ENV)

provision-host: ## Configure the virtualization host (KVM, bridge, Tailscale)
	cd $(ANSIBLE_DIR) && ansible-playbook $(ANSIBLE_OPTS) playbooks/host.yaml --ask-become-pass

provision: ## Bootstrap K3s, Cilium and Flux on the VMs
	cd $(ANSIBLE_DIR) && ansible-playbook $(ANSIBLE_OPTS) playbooks/vms.yaml

edit-vault: ## Edit the Ansible Vault (uses provisioning/ansible/.vault_pass)
	ansible-vault edit $(ANSIBLE_DIR)/inventory/group_vars/all/secrets.yml $(VAULT_OPTS)

flux-status: ## Show Flux sources and kustomizations for this environment
	KUBECONFIG=$(KUBECONFIG_FILE) kubectl get gitrepositories,kustomizations,helmreleases -A

lint: ## yamllint, ansible-lint and terraform fmt
	yamllint .
	cd $(ANSIBLE_DIR) && ansible-lint
	terraform fmt -check -recursive provisioning/terraform

validate: ## Build every Kustomize overlay and check manifests
	./scripts/validate.sh

check-secrets: ## Fail if any *.sops.yaml is not encrypted
	./scripts/check-sops.sh

