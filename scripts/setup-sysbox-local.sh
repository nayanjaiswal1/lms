#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/setup-sysbox-local.sh — ONE-TIME: register sysbox-runc as a
# Kubernetes RuntimeClass in the local k3s cluster, so nested-docker lab
# images (LABS_IMAGE_PROFILES=...:nested-docker, e.g. the "docker" course)
# can actually be provisioned under LABS_RUNTIME=kubernetes. Without this,
# KubernetesContainerService.startPod hard-fails every such session before
# creating a Pod — see backend/internal/labs/runtime_kubernetes.go and
# docs/labs.md "Kubernetes runtime has no --cap-add equivalent".
#
# Prerequisite: sysbox-ce already installed and its sysbox-mgr/sysbox-fs
# daemons running (`dpkg -l | grep sysbox-ce`, `pgrep sysbox-mgr`) — this
# script only wires an already-installed sysbox into k3s's containerd, it
# does not install sysbox-ce itself (see nestybox/sysbox releases if it's
# missing on this host).
#
# Run this INSIDE WSL, from the mindforge/ directory. Safe to re-run.
#
# Reference: https://docs.k3s.io/blog/2025/09/27/k3s-sysbox and
# https://docs.k3s.io/advanced ("Configuring containerd").
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ─── 0. Preconditions ────────────────────────────────────────────────────────
command -v sysbox-runc &>/dev/null || error "sysbox-runc not found on PATH — install sysbox-ce first (see nestybox/sysbox releases)."
pgrep -x sysbox-mgr &>/dev/null || error "sysbox-mgr isn't running — check: sudo systemctl status sysbox"
pgrep -x sysbox-fs &>/dev/null || error "sysbox-fs isn't running — check: sudo systemctl status sysbox"
success "sysbox-ce is installed and its daemons are running."

# ─── 1. Register sysbox-runc as a containerd runtime ────────────────────────
# `{{ template "base" . }}` is required first — without it this file REPLACES
# k3s's entire generated containerd config instead of extending it, silently
# dropping the default runc runtime, snapshotter, and every other RuntimeClass
# already registered (crun, nvidia, wasm family). See docs.k3s.io/advanced.
TMPL=/var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl
if sudo test -f "$TMPL" && sudo grep -q 'runtimes.sysbox-runc' "$TMPL"; then
  info "containerd already has a sysbox-runc runtime entry — skipping."
else
  info "Writing $TMPL (needs sudo)..."
  sudo mkdir -p "$(dirname "$TMPL")"
  if sudo test -f "$TMPL"; then
    warn "$TMPL already exists and doesn't mention sysbox-runc — appending rather than overwriting. Verify it still starts with {{ template \"base\" . }}."
    sudo tee -a "$TMPL" >/dev/null <<'EOF'

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.sysbox-runc]
  runtime_type = "io.containerd.runc.v2"
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.sysbox-runc.options]
  SystemdCgroup = false
  BinaryName = "/usr/bin/sysbox-runc"
EOF
  else
    sudo tee "$TMPL" >/dev/null <<'EOF'
{{ template "base" . }}

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.sysbox-runc]
  runtime_type = "io.containerd.runc.v2"
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.sysbox-runc.options]
  SystemdCgroup = false
  BinaryName = "/usr/bin/sysbox-runc"
EOF
  fi
  success "containerd runtime entry written."

  info "Restarting k3s to apply it (brief control-plane blip; port-forwards will drop and need restarting)..."
  sudo systemctl restart k3s
  info "Waiting for the node to be Ready again..."
  for i in $(seq 1 30); do
    kubectl get nodes --no-headers 2>/dev/null | grep -q " Ready " && break
    sleep 2
  done
  kubectl get nodes --no-headers | grep -q " Ready " || error "Node never came back Ready after restart — check: sudo systemctl status k3s; sudo journalctl -u k3s -n 100"
  success "k3s node Ready."
fi

# ─── 1b. Label this node as sysbox-capable ──────────────────────────────────
# The RuntimeClass (k8s/base/runtimeclass-sysbox.yaml) declares
# scheduling.nodeSelector: mindforge.io/sysbox=true — Kubernetes' own
# RuntimeClass admission controller merges that onto every Pod using
# runtimeClassName: sysbox-runc, so an unlabeled node can never be handed one
# of these Pods (fails scheduling instead of failing at container-create
# time). Real (multi-node) clusters label only the node pool that actually
# has sysbox installed; this is a single-node cluster, so that's just "the
# node" — see docs/local-k3s-dev.md "Known local-only limitations" for why
# this script does NOT also apply the mindforge.io/sysbox-only taint that
# production uses to dedicate a node pool: tainting the only node here would
# block every other Pod (postgres, redis, backend, ...) from scheduling too.
NODE="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')"
kubectl label node "$NODE" mindforge.io/sysbox=true --overwrite
success "Node $NODE labeled mindforge.io/sysbox=true."

# ─── 2. RuntimeClass ──────────────────────────────────────────────────────────
kubectl apply -f k8s/base/runtimeclass-sysbox.yaml
success "RuntimeClass sysbox-runc registered."

# ─── 2b. Nested-docker lab images ────────────────────────────────────────────
# scripts/push-lab-images.sh builds every lab-images/* Dockerfile (including
# mindforge/lab-docker-sysbox:27, mindforge/lab-docker:27, and
# mindforge/lab-k8s:1.31) and pushes it to a registry k3s's containerd pulls
# from directly — run it (with LABS_IMAGE_REGISTRY set to match) before
# provisioning a nested-docker lab. Not run automatically from here since it
# rebuilds every lab image, not just the sysbox-profile ones this script
# cares about.

# ─── 3. Smoke test — a throwaway Pod, not the real lab image ────────────────
# mindforge-labs is normally created by deploy-k8s.sh (via k8s/base/namespace.yaml,
# applied through the overlay) — but this script runs BEFORE that step in
# scripts/bootstrap-k3s-local.sh's ordering, so on a cluster that's never been
# deployed to yet the namespace doesn't exist and the smoke test Pod below
# fails with "namespaces mindforge-labs not found". Applying the same
# manifest here is idempotent — deploy-k8s.sh re-applying it later is a no-op.
kubectl apply -f k8s/base/namespace.yaml >/dev/null

info "Smoke-testing with a throwaway Pod in mindforge-labs..."
kubectl delete pod sysbox-smoketest -n mindforge-labs --ignore-not-found --now &>/dev/null
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: sysbox-smoketest
  namespace: mindforge-labs
spec:
  runtimeClassName: sysbox-runc
  hostUsers: false
  restartPolicy: Never
  containers:
  - name: test
    image: busybox:1.36
    command: ["sh", "-c", "echo sysbox-ok && sleep 30"]
EOF

ok=false
for i in $(seq 1 30); do
  phase="$(kubectl get pod sysbox-smoketest -n mindforge-labs -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  if [[ "$phase" == "Running" || "$phase" == "Succeeded" ]]; then ok=true; break; fi
  if [[ "$phase" == "Failed" ]]; then break; fi
  sleep 2
done

if [[ "$ok" == true ]]; then
  success "Smoke test Pod reached $phase — sysbox-runc works in this cluster."
  kubectl logs sysbox-smoketest -n mindforge-labs 2>&1 | grep -q sysbox-ok && success "Container output confirmed."
else
  kubectl describe pod sysbox-smoketest -n mindforge-labs || true
  kubectl delete pod sysbox-smoketest -n mindforge-labs --ignore-not-found --now &>/dev/null
  error "Smoke test Pod never reached Running/Succeeded — see events above. Common cause: sysbox-ce version predates the containerd-integration fix (see https://docs.k3s.io/blog/2025/09/27/k3s-sysbox); may need building sysbox-runc from source."
fi
kubectl delete pod sysbox-smoketest -n mindforge-labs --ignore-not-found --now &>/dev/null

echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  sysbox-runc ready as a k3s RuntimeClass${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo "  Set in backend/.env:  LABS_NESTED_DOCKER_RUNTIME_CLASS=sysbox-runc"
echo "  Then restart the backend (air doesn't reload on .env changes)."
echo ""
echo "  Next: bash scripts/push-lab-images.sh, then set LABS_IMAGE_REGISTRY"
echo "  (see its output) alongside LABS_NESTED_DOCKER_RUNTIME_CLASS above."
echo ""
