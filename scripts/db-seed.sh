#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/db-seed.sh — Load dev fixture data
# Runs backend/db/fixtures/dev_seed.sql inside the Postgres container.
# Idempotent — the SQL uses ON CONFLICT DO NOTHING throughout.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SEED_FILE="${PROJECT_ROOT}/backend/db/fixtures/dev_seed.sql"
CONTAINER="mindforge_postgres_dev"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[seed]${NC}   $*"; }
success() { echo -e "${GREEN}[seed]${NC}   $*"; }
error()   { echo -e "${RED}[seed]${NC}   $*" >&2; exit 1; }

# Load .env from project root if available
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/.env"
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-mindforge}"
POSTGRES_DB="${POSTGRES_DB:-mindforge_dev}"

# Verify the container is running
if ! docker inspect "$CONTAINER" &>/dev/null; then
  error "Container '$CONTAINER' is not running. Start it with: make dev-up"
fi

if [[ ! -f "$SEED_FILE" ]]; then
  error "Seed file not found: $SEED_FILE"
fi

info "Loading seed file: backend/db/fixtures/dev_seed.sql"
docker cp "$SEED_FILE" "${CONTAINER}:/tmp/dev_seed.sql"
docker exec "$CONTAINER" psql \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -v ON_ERROR_STOP=1 \
  -f /tmp/dev_seed.sql > /dev/null
docker exec "$CONTAINER" rm -f /tmp/dev_seed.sql

success "Seed data loaded successfully."
info "Dev users (password: Admin123!):"
info "  admin@mindforge.dev      → super_admin + org admin"
info "  orgadmin@mindforge.dev   → org admin"
info "  instructor@mindforge.dev → instructor"
info "  mentor@mindforge.dev     → mentor"
info "  student@mindforge.dev    → student"
