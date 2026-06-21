#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/db-migrate.sh — Apply pending database migrations
# Tracks applied migrations in the schema_migrations table.
# Idempotent — safe to run multiple times.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MIGRATIONS_DIR="${PROJECT_ROOT}/backend/db/migrations"
CONTAINER="mindforge_postgres_dev"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[migrate]${NC} $*"; }
success() { echo -e "${GREEN}[migrate]${NC} $*"; }
error()   { echo -e "${RED}[migrate]${NC} $*" >&2; exit 1; }

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

# psql helper — runs SQL inside the Postgres container
psql_exec() {
  docker exec "$CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 "$@"
}

# ─── Create schema_migrations table if it does not exist ────────────────────
info "Ensuring schema_migrations table exists..."
psql_exec -c "
CREATE TABLE IF NOT EXISTS schema_migrations (
  filename   TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ DEFAULT now()
);
" > /dev/null

# ─── Find and apply pending migrations ───────────────────────────────────────
# Only process *.sql files that do NOT end in .down.sql, in alphabetical order.
applied=0
skipped=0

while IFS= read -r -d '' filepath; do
  filename="$(basename "$filepath")"

  # Skip down migrations
  [[ "$filename" == *.down.sql ]] && continue

  # Check if already applied
  is_applied=$(psql_exec -t -c "SELECT COUNT(*) FROM schema_migrations WHERE filename = '${filename}';" 2>/dev/null | tr -d '[:space:]')

  if [[ "$is_applied" == "1" ]]; then
    info "Skipping (already applied): $filename"
    skipped=$((skipped + 1))
    continue
  fi

  info "Applying: $filename"

  # Copy the migration file into the container and execute it
  docker cp "$filepath" "${CONTAINER}:/tmp/${filename}"
  psql_exec -f "/tmp/${filename}" > /dev/null
  docker exec "$CONTAINER" rm -f "/tmp/${filename}"

  # Record it as applied
  psql_exec -c "INSERT INTO schema_migrations (filename) VALUES ('${filename}') ON CONFLICT DO NOTHING;" > /dev/null

  success "Applied: $filename"
  applied=$((applied + 1))
done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -name "*.sql" ! -name "*.down.sql" -print0 | sort -z)

echo ""
success "Done. Applied: $applied, Skipped (already up-to-date): $skipped"
