#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/db-reset.sh — Drop and recreate the dev database
# Gives you a completely clean slate: drops, recreates, migrates, seeds.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER="mindforge_postgres_dev"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[reset]${NC}  $*"; }
success() { echo -e "${GREEN}[reset]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[reset]${NC}  $*"; }
error()   { echo -e "${RED}[reset]${NC}  $*" >&2; exit 1; }

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

warn "This will DROP the '$POSTGRES_DB' database and recreate it. All data will be lost."
warn "Press Enter to continue or Ctrl+C to abort."
read -r

# ─── Drop the database ────────────────────────────────────────────────────────
info "Dropping database '$POSTGRES_DB'..."
# Connect to 'postgres' (system DB) to drop the target DB
docker exec "$CONTAINER" psql \
  -U "$POSTGRES_USER" \
  -d postgres \
  -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS \"${POSTGRES_DB}\";" > /dev/null
success "Database dropped."

# ─── Recreate the database ────────────────────────────────────────────────────
info "Creating database '$POSTGRES_DB'..."
docker exec "$CONTAINER" psql \
  -U "$POSTGRES_USER" \
  -d postgres \
  -v ON_ERROR_STOP=1 \
  -c "CREATE DATABASE \"${POSTGRES_DB}\";" > /dev/null
success "Database created."

# ─── Run migrations ───────────────────────────────────────────────────────────
info "Running migrations..."
bash "${SCRIPT_DIR}/db-migrate.sh"

# ─── Load seed data ───────────────────────────────────────────────────────────
info "Loading seed data..."
bash "${SCRIPT_DIR}/db-seed.sh"

echo ""
success "Database reset complete. Clean state with all migrations applied and seed data loaded."
