#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/dev-setup.sh — One-shot dev environment bootstrap
# Safe to run multiple times (idempotent).
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ─── 1. Check prerequisites ───────────────────────────────────────────────────
info "Checking prerequisites..."

check_cmd() {
  local cmd="$1"
  local label="${2:-$1}"
  if command -v "$cmd" &>/dev/null; then
    local version
    version=$("$cmd" --version 2>&1 | head -1)
    success "$label: $version"
  else
    error "$label is not installed or not on PATH. Please install it and re-run."
  fi
}

check_cmd docker   "Docker"
check_cmd go       "Go"
check_cmd node     "Node.js"
check_cmd pnpm     "pnpm"

# Check docker compose (v2 plugin syntax)
if docker compose version &>/dev/null; then
  success "Docker Compose: $(docker compose version --short 2>/dev/null || echo 'v2')"
elif command -v docker-compose &>/dev/null; then
  success "Docker Compose (v1): $(docker-compose --version)"
else
  error "Docker Compose is not available. Install Docker Desktop or the Compose plugin."
fi

# ─── 2. Copy .env if missing ──────────────────────────────────────────────────
cd "$PROJECT_ROOT"

if [[ ! -f .env ]]; then
  info "No .env found — copying .env.example to .env..."
  cp .env.example .env
  warn ".env created from .env.example. Edit it and fill in required secrets before continuing."
  warn "Required: POSTGRES_PASSWORD, JWT_SECRET, COOKIE_SECRET, ENCRYPTION_KEY"
  warn "Press Enter to continue (or Ctrl+C to exit and edit .env first)."
  read -r
else
  success ".env already exists — skipping copy."
fi

# Load env vars for container name resolution
set -a
# shellcheck disable=SC1091
source .env
set +a

POSTGRES_USER="${POSTGRES_USER:-mindforge}"
POSTGRES_DB="${POSTGRES_DB:-mindforge_dev}"

# ─── 3. Start dev containers ──────────────────────────────────────────────────
info "Starting dev containers..."
docker compose -f docker-compose.dev.yml up -d
success "Containers started."

# ─── 4. Wait for Postgres to be healthy ──────────────────────────────────────
info "Waiting for Postgres to be ready..."
CONTAINER="mindforge_postgres_dev"
MAX_ATTEMPTS=30
attempt=0

until docker exec "$CONTAINER" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" > /dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [[ $attempt -ge $MAX_ATTEMPTS ]]; then
    error "Postgres did not become ready after ${MAX_ATTEMPTS} attempts. Check: docker logs ${CONTAINER}"
  fi
  echo -n "."
  sleep 2
done
echo ""
success "Postgres is ready."

# ─── 5. Run migrations ────────────────────────────────────────────────────────
info "Running migrations..."
bash "${SCRIPT_DIR}/db-migrate.sh"
success "Migrations applied."

# ─── 6. Run seed ──────────────────────────────────────────────────────────────
info "Loading dev seed data..."
bash "${SCRIPT_DIR}/db-seed.sh"
success "Seed data loaded."

# ─── 7. Done ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  MindForge dev environment is ready!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo "  PostgreSQL  → localhost:5432"
echo "  Redis       → localhost:6379"
echo "  Adminer     → http://localhost:8081  (DB UI)"
echo ""
echo "  Dev users (password: Admin123!):"
echo "    admin@mindforge.dev      (super_admin)"
echo "    orgadmin@mindforge.dev   (org admin)"
echo "    instructor@mindforge.dev (instructor)"
echo "    mentor@mindforge.dev     (mentor)"
echo "    student@mindforge.dev    (student)"
echo ""
echo "  Next steps:"
echo "    make backend    → start the Go API server on :8080"
echo "    make frontend   → start Next.js on :3000"
echo ""
