#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/build-k3s-local-images.sh — Build the backend/labproxy/frontend
# images and import them into k3s's containerd (a separate image store from
# the docker daemon's — a plain `docker build` alone is not visible to k3s).
# No registry involved; images are tagged ":local" and referenced that way by
# k8s/overlays/local/kustomization.yaml.
#
# Run this INSIDE WSL, from the mindforge/ directory, after
# scripts/setup-k3s-local.sh. Re-run whenever backend/labproxy/frontend code
# changes.
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

command -v docker &>/dev/null || error "docker is not installed."
command -v k3s &>/dev/null || error "k3s is not installed — run scripts/setup-k3s-local.sh first."

DOMAIN="mindforge.127.0.0.1.nip.io"

info "Building backend..."
docker build -t mindforge-backend:local -f backend/Dockerfile backend/

info "Building labproxy..."
docker build -t mindforge-labproxy:local -f backend/Dockerfile.labproxy backend/

info "Building frontend (NEXT_PUBLIC_* baked in for https://${DOMAIN})..."
docker build -t mindforge-frontend:local -f frontend/Dockerfile \
  --build-arg NEXT_PUBLIC_API_URL="" \
  --build-arg NEXT_PUBLIC_APP_URL="https://${DOMAIN}" \
  --build-arg NEXT_PUBLIC_MEDIA_URL="https://${DOMAIN}" \
  --build-arg NEXT_PUBLIC_LAB_PROXY_URL="wss://${DOMAIN}/lab-ws" \
  --build-arg NEXT_PUBLIC_GOOGLE_OAUTH_ENABLED="false" \
  --build-arg NEXT_PUBLIC_GITHUB_OAUTH_ENABLED="false" \
  frontend/

info "Importing images into k3s's containerd..."
for img in mindforge-backend mindforge-labproxy mindforge-frontend; do
  docker save "${img}:local" | sudo k3s ctr images import -
done

success "Images built and imported: mindforge-backend:local, mindforge-labproxy:local, mindforge-frontend:local"
echo ""
echo "  Next: bash scripts/deploy-k8s.sh local"
echo ""
