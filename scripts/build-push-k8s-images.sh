#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/build-push-k8s-images.sh — Build, tag, and push the three MindForge
# images (same Dockerfiles as the VPS deploy) for a Kubernetes deploy, then
# pin the resulting tags into k8s/overlays/prod/kustomization.yaml.
#
# Usage: REGISTRY=ghcr.io/youruser bash scripts/build-push-k8s-images.sh [tag]
#   REGISTRY  Required — e.g. ghcr.io/youruser, docker.io/youruser, a private
#             registry your cluster's nodes can pull from.
#   tag       Optional — defaults to the current git short SHA.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

[[ -n "${REGISTRY:-}" ]] || error "REGISTRY is not set. Usage: REGISTRY=ghcr.io/youruser bash $0 [tag]"
command -v docker &>/dev/null || error "Docker is not installed."
command -v kustomize &>/dev/null || error "kustomize CLI is not installed (kubectl's built-in kustomize can't run 'edit set image'). Install: https://kubectl.docs.kubernetes.io/installation/kustomize/"

TAG="${1:-$(git rev-parse --short HEAD)}"
OVERLAY_DIR="k8s/overlays/prod"
CONFIGMAP_PATCH="${OVERLAY_DIR}/configmap-domain.patch.yaml"

[[ -f "$CONFIGMAP_PATCH" ]] || error "$CONFIGMAP_PATCH not found."

# NEXT_PUBLIC_* values are inlined into the frontend bundle at build time —
# read them from the same patch file the user already edits for their domain,
# so there's one source of truth instead of re-entering them here.
read_configmap_value() {
  local key="$1"
  grep -E "^\s*${key}:" "$CONFIGMAP_PATCH" | head -1 | sed -E 's/^[^:]+:\s*"?([^"]*)"?\s*$/\1/'
}
NEXT_PUBLIC_API_URL="$(read_configmap_value NEXT_PUBLIC_API_URL)"
NEXT_PUBLIC_APP_URL="$(read_configmap_value NEXT_PUBLIC_APP_URL)"
NEXT_PUBLIC_MEDIA_URL="$(read_configmap_value NEXT_PUBLIC_MEDIA_URL)"
NEXT_PUBLIC_LAB_PROXY_URL="$(read_configmap_value NEXT_PUBLIC_LAB_PROXY_URL)"
# These two live in k8s/base/configmap.yaml (not the domain patch) since
# they're not domain-dependent — read from there instead of the patch file.
NEXT_PUBLIC_GOOGLE_OAUTH_ENABLED="$(grep -E '^\s*NEXT_PUBLIC_GOOGLE_OAUTH_ENABLED:' k8s/base/configmap.yaml | head -1 | sed -E 's/^[^:]+:\s*"?([^"]*)"?\s*$/\1/')"
NEXT_PUBLIC_GITHUB_OAUTH_ENABLED="$(grep -E '^\s*NEXT_PUBLIC_GITHUB_OAUTH_ENABLED:' k8s/base/configmap.yaml | head -1 | sed -E 's/^[^:]+:\s*"?([^"]*)"?\s*$/\1/')"

if [[ "$NEXT_PUBLIC_API_URL" == *yourdomain.com* ]]; then
  error "$CONFIGMAP_PATCH still has placeholder yourdomain.com values — fill in your real domain first."
fi

info "Building backend ($TAG)..."
docker build -t "${REGISTRY}/mindforge-backend:${TAG}" -f backend/Dockerfile backend
info "Building labproxy ($TAG)..."
docker build -t "${REGISTRY}/mindforge-labproxy:${TAG}" -f backend/Dockerfile.labproxy backend
info "Building frontend ($TAG)..."
docker build -t "${REGISTRY}/mindforge-frontend:${TAG}" \
  --build-arg NEXT_PUBLIC_API_URL="$NEXT_PUBLIC_API_URL" \
  --build-arg NEXT_PUBLIC_APP_URL="$NEXT_PUBLIC_APP_URL" \
  --build-arg NEXT_PUBLIC_MEDIA_URL="$NEXT_PUBLIC_MEDIA_URL" \
  --build-arg NEXT_PUBLIC_LAB_PROXY_URL="$NEXT_PUBLIC_LAB_PROXY_URL" \
  --build-arg NEXT_PUBLIC_GOOGLE_OAUTH_ENABLED="$NEXT_PUBLIC_GOOGLE_OAUTH_ENABLED" \
  --build-arg NEXT_PUBLIC_GITHUB_OAUTH_ENABLED="$NEXT_PUBLIC_GITHUB_OAUTH_ENABLED" \
  -f frontend/Dockerfile frontend
success "Images built."

info "Pushing images to ${REGISTRY}..."
docker push "${REGISTRY}/mindforge-backend:${TAG}"
docker push "${REGISTRY}/mindforge-labproxy:${TAG}"
docker push "${REGISTRY}/mindforge-frontend:${TAG}"
success "Images pushed."

info "Pinning image tags in ${OVERLAY_DIR}/kustomization.yaml..."
(
  cd "$OVERLAY_DIR"
  kustomize edit set image \
    "mindforge-backend=${REGISTRY}/mindforge-backend:${TAG}" \
    "mindforge-labproxy=${REGISTRY}/mindforge-labproxy:${TAG}" \
    "mindforge-frontend=${REGISTRY}/mindforge-frontend:${TAG}"
)
success "Image tags pinned to ${TAG}."

echo ""
echo "Next: bash scripts/deploy-k8s.sh"
