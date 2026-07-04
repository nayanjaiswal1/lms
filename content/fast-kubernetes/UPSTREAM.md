# Upstream Provenance — Fast-Kubernetes

This directory (`content/fast-kubernetes/`) is a byte-exact vendored snapshot of the
[omerbsezer/Fast-Kubernetes](https://github.com/omerbsezer/Fast-Kubernetes) repository
(public, MIT licensed — see `LICENSE` in this directory).

## Snapshot details

| Field | Value |
|---|---|
| Upstream URL | https://github.com/omerbsezer/Fast-Kubernetes |
| Vendored commit SHA | `9cc0e2168e28dcefb3871a85b131efd028471e4c` |
| Upstream commit date | 2025-04-14T10:54:11+02:00 |
| Date vendored | 2026-07-03 |
| Clone method | `git clone --depth 1` |
| File count | 67 files (excluding `.git/`) |

No runtime GitHub calls are made anywhere in the MindForge content pipeline — this
snapshot is the sole source of truth for the `fast-kubernetes` course content, and the
importer (`backend/internal/contentpipeline/importer/`) reads only from this directory.

## Contents

- `README.md`, `LICENSE`, `index.html` — repo root files.
- 22 lesson markdown files at repo root (`K8s-*.md`, `K8-CreatingPod-Declerative.md`).
- 3 reference files: `KubernetesCommandCheatSheet.md`, `HelmCheatsheet.md`, `Helm.md`.
- `labs/` — 14 subdirectories (affinity, configmap, cronjob, daemonset, deployment,
  ingress, job, liveness, persistentvolume, pod, secret, service, statefulset,
  tainttoleration), each containing the YAML/txt manifests referenced by that lesson's
  hands-on lab.
- `create_real_cluster/` — install/master scripts for kubeadm cluster setup across
  several OS/Kubernetes version combinations (Ubuntu 20.04/24.04, Windows Server
  2019/2022).

## Re-vendoring procedure

To pull a newer upstream snapshot and review what changed:

1. Clone the latest upstream into a scratch directory (outside this repo):
   ```
   git clone --depth 1 https://github.com/omerbsezer/Fast-Kubernetes.git /tmp/fk-latest
   git -C /tmp/fk-latest rev-parse HEAD
   ```
2. Copy every file from the fresh clone into `content/fast-kubernetes/`, excluding
   `.git/`, overwriting existing files:
   ```
   find /tmp/fk-latest -path /tmp/fk-latest/.git -prune -o -type f -print | while read -r f; do
     dest="content/fast-kubernetes/${f#/tmp/fk-latest/}"
     mkdir -p "$(dirname "$dest")"
     cp "$f" "$dest"
   done
   ```
3. `git diff -- content/fast-kubernetes/` to review exactly what upstream changed.
   Pay special attention to renamed/removed lesson files or `labs/*` directories —
   the importer's section-grouping table (`backend/internal/contentpipeline/importer/sections.go`)
   hardcodes upstream filenames and will need matching updates if files were
   renamed, added, or removed.
4. Update the "Snapshot details" table above with the new commit SHA and vendor date.
5. Re-run `coursegen import` and `coursegen audit` to confirm the scaffolded canonical
   content still has 100% source coverage of the updated snapshot.
6. Delete the scratch clone directory.
