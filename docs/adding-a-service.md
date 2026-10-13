# Adding a service

1. Create `services/base/<app>/` with `deployment.yaml`, `service.yaml`, `pvc.yaml` (use a StorageClass from `infrastructure/base/storage/`), `ingress.yaml` if it is exposed, and a `kustomization.yaml` listing every file. Files not listed there are never deployed (`make validate` flags them).
2. Namespace: add it to `infrastructure/base/namespaces/namespaces.yaml`.
3. Secrets: create `secret.sops.yaml` (see [secrets.md](secrets.md)) and list it in the kustomization.
4. Write resource requests and a **memory limit** on every container (Kyverno `require-resource-limits`); do not set CPU limits (`forbid-cpu-limits`). Pin the image to a version, not `latest`.
5. Select it per environment: add `services/production/<app>/kustomization.yaml` (and staging) containing `resources: [../../base/<app>]`, then list `<app>` in `services/<env>/kustomization.yaml`.
6. Expose it: add the hostname in the Cloudflare Zero Trust tunnel's public hostnames, pointing at the Cilium ingress. Consider a Cloudflare Access policy for anything with an admin UI.
7. Check before pushing: `make lint validate check-secrets`, open a PR, and confirm CI is green. Flux picks the change up from `main` within a few minutes.
