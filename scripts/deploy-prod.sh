#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/deploy-prod.sh — Build and (re)start the MindForge production stack.
# Run on the target server, from the mindforge/ directory: bash scripts/deploy-prod.sh
# Safe to re-run — rebuilds images and recreates only what changed.
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

COMPOSE="docker compose --env-file .env.prod -f docker-compose.prod.yml"

# ─── 1. Check prerequisites ───────────────────────────────────────────────────
command -v docker &>/dev/null || error "Docker is not installed."
docker compose version &>/dev/null || error "Docker Compose v2 plugin is required."

if [[ ! -f .env.prod ]]; then
  error ".env.prod not found. Copy .env.prod.example to .env.prod and fill in every value first."
fi

# ─── 2. Fail fast on placeholder secrets ──────────────────────────────────────
info "Checking .env.prod for unfilled placeholders..."
if grep -qE "change_me|yourdomain\.com|your_(google|smtp)" .env.prod; then
  error "Refusing to deploy: .env.prod still contains change_me / yourdomain.com / placeholder values. Fill in real secrets first."
fi
success ".env.prod looks filled in."

# ─── 3. Ensure the external labs network exists ───────────────────────────────
if ! docker network inspect mindforge-labs &>/dev/null; then
  info "Creating external network mindforge-labs (lab sandbox containers join this)..."
  docker network create mindforge-labs
  success "Network created."
else
  success "Network mindforge-labs already exists."
fi

# ─── 4. Build and start ────────────────────────────────────────────────────────
info "Building images and starting the production stack..."
$COMPOSE up -d --build
success "Stack started."

# ─── 5. Wait for backend health ────────────────────────────────────────────────
info "Waiting for backend to become healthy..."
attempt=0
until [[ "$(docker inspect -f '{{.State.Health.Status}}' mindforge_backend_prod 2>/dev/null)" == "healthy" ]]; do
  attempt=$((attempt + 1))
  if [[ $attempt -ge 30 ]]; then
    warn "Backend did not become healthy in time. Check: $COMPOSE logs backend"
    break
  fi
  echo -n "."
  sleep 2
done
echo ""

# ─── 6. Summary ─────────────────────────────────────────────────────────────────
DOMAIN_VALUE="$(grep -E '^DOMAIN=' .env.prod | cut -d= -f2)"
echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  MindForge production stack is running!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo "  App        -> https://${DOMAIN_VALUE}"
echo ""
echo "  Logs:       $COMPOSE logs -f"
echo "  Stop:       $COMPOSE down"
echo "  Redeploy:   bash scripts/deploy-prod.sh"
echo ""
