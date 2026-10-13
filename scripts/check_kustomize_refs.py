#!/usr/bin/env python3
"""Offline check that every kustomization.yaml only references paths that exist.

This is not a replacement for `kustomize build` (see validate.sh); it catches the
most common GitOps breakage, a moved or deleted folder, without any extra tooling.
"""
import pathlib
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
SKIP = {".git", ".terraform", "node_modules"}
KEYS = ("resources", "bases", "components", "patchesStrategicMerge")


def main() -> int:
    errors = 0
    checked = 0
    for kfile in sorted(ROOT.rglob("kustomization.yaml")):
        if SKIP & set(kfile.parts):
            continue
        data = yaml.safe_load(kfile.read_text()) or {}
        if data.get("kind") != "Kustomization" or "kustomize.config.k8s.io" not in str(data.get("apiVersion", "")):
            continue  # a Flux Kustomization, not a kustomize one
        checked += 1
        referenced = set()
        for key in KEYS:
            for ref in data.get(key, []) or []:
                if "://" in ref:
                    continue
                target = (kfile.parent / ref).resolve()
                referenced.add(target)
                if target.is_file():
                    try:
                        list(yaml.safe_load_all(target.read_text()))
                    except yaml.YAMLError as exc:
                        print(f"{target.relative_to(ROOT)}: invalid YAML: {exc}")
                        errors += 1
                if target.is_dir():
                    if not (target / "kustomization.yaml").exists():
                        print(f"{kfile.relative_to(ROOT)}: '{ref}' is a directory without kustomization.yaml")
                        errors += 1
                elif not target.exists():
                    print(f"{kfile.relative_to(ROOT)}: '{ref}' does not exist")
                    errors += 1
        # A manifest sitting next to a kustomization.yaml that never lists it is silently never deployed.
        for sibling in sorted(kfile.parent.glob("*.y*ml")):
            if sibling.name == "kustomization.yaml" or sibling.resolve() in referenced:
                continue
            print(f"{sibling.relative_to(ROOT)}: not referenced by {kfile.relative_to(ROOT)} (never deployed)")
            errors += 1
        for patch in data.get("patches", []) or []:
            path = patch.get("path") if isinstance(patch, dict) else None
            if path and not (kfile.parent / path).exists():
                print(f"{kfile.relative_to(ROOT)}: patch '{path}' does not exist")
                errors += 1

    # Flux Kustomization objects must point at a path that exists and has a kustomization.yaml.
    for ffile in sorted((ROOT / "clusters").rglob("*.yaml")):
        for doc in yaml.safe_load_all(ffile.read_text()):
            if not isinstance(doc, dict) or doc.get("kind") != "Kustomization":
                continue
            if "kustomize.toolkit.fluxcd.io" not in str(doc.get("apiVersion", "")):
                continue
            path = doc["spec"]["path"]
            target = (ROOT / path).resolve()
            checked += 1
            if not (target / "kustomization.yaml").exists():
                print(f"{ffile.relative_to(ROOT)}: Flux path '{path}' has no kustomization.yaml")
                errors += 1

    print(f"Checked {checked} kustomizations, {errors} problem(s).")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
