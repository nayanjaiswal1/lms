#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/deploy-k8s.sh — Apply the MindForge Kubernetes manifests to whatever
# cluster your current kubectl context points at.
# Run from the mindforge/ directory: bash scripts/deploy-k8s.sh
# Safe to re-run — kubectl apply -k is idempotent.
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

OVERLAY_DIR="k8s/overlays/prod"

# ─── 1. Check prerequisites ───────────────────────────────────────────────────
command -v kubectl &>/dev/null || error "kubectl is not installed."

info "Checking cluster connectivity (current context: $(kubectl config current-context 2>/dev/null || echo 'none'))..."
kubectl cluster-info &>/dev/null || error "Cannot reach the cluster for the current kubectl context. Run 'kubectl config get-contexts' and switch if needed."
success "Cluster reachable."

# ─── 2. Guard against placeholder secrets/domain ──────────────────────────────
if [[ ! -f "${OVERLAY_DIR}/secrets.env" ]]; then
  error "${OVERLAY_DIR}/secrets.env not found. Copy secrets.env.example to secrets.env and fill in every value first."
fi
if grep -qE "change_me|your_(google|smtp)" "${OVERLAY_DIR}/secrets.env"; then
  error "Refusing to deploy: ${OVERLAY_DIR}/secrets.env still contains change_me / placeholder values."
fi
if grep -q "yourdomain.com" "${OVERLAY_DIR}/configmap-domain.patch.yaml" "${OVERLAY_DIR}/ingress-domain.patch.yaml"; then
  error "Refusing to deploy: ${OVERLAY_DIR}/configmap-domain.patch.yaml or ingress-domain.patch.yaml still has the placeholder domain (app.yourdomain.com)."
fi
if grep -q "REPLACE_ME_REGISTRY" "${OVERLAY_DIR}/kustomization.yaml"; then
  error "Refusing to deploy: image tags aren't pinned yet. Run scripts/build-push-k8s-images.sh first."
fi
success "Overlay looks filled in."

# ─── 3. Apply ───────────────────────────────────────────────────────────────────
info "Applying ${OVERLAY_DIR}..."
kubectl apply -k "$OVERLAY_DIR"
success "Manifests applied."

# ─── 4. Wait for rollouts ────────────────────────────────────────────────────────
info "Waiting for rollouts..."
for deploy in backend labproxy frontend; do
  kubectl rollout status "deployment/${deploy}" -n mindforge --timeout=180s || warn "${deploy} rollout did not complete in time — check: kubectl get pods -n mindforge"
done
kubectl rollout status statefulset/postgres -n mindforge --timeout=180s || warn "postgres rollout did not complete in time"
kubectl rollout status statefulset/minio -n mindforge --timeout=180s || warn "minio rollout did not complete in time"
kubectl rollout status deployment/piston -n mindforge-labs --timeout=180s || warn "piston rollout did not complete in time — if this cluster forbids privileged Pods, point PISTON_URL at an external instance instead (see README)"

# ─── 5. Summary ─────────────────────────────────────────────────────────────────
DOMAIN_VALUE="$(grep -E '^\s*DOMAIN:' "${OVERLAY_DIR}/configmap-domain.patch.yaml" | head -1 | sed -E 's/^[^:]+:\s*"?([^"]*)"?\s*$/\1/')"
echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  MindForge is deployed to Kubernetes!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo "  App        -> https://${DOMAIN_VALUE}  (once DNS + cert-manager finish issuing the certificate)"
echo ""
echo "  Logs:       kubectl logs -n mindforge -l app=backend -f"
echo "  App pods:   kubectl get pods -n mindforge"
echo "  Lab pods:   kubectl get pods -n mindforge-labs"
echo "  Redeploy:   bash scripts/deploy-k8s.sh"
echo ""
