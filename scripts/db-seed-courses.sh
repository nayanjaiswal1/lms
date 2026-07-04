#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/db-seed-courses.sh — Load generated course-content fixtures
# Runs backend/db/fixtures/k8s_fastkube.generated.sql inside the Postgres
# container. Idempotent — the SQL uses ON CONFLICT ... DO UPDATE/NOTHING
# throughout, so re-running after `coursegen generate` produces updates, not
# duplicates. Regenerate the file first with:
#   cd backend && go run ./cmd/coursegen generate
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SEED_FILE="${PROJECT_ROOT}/backend/db/fixtures/k8s_fastkube.generated.sql"
CONTAINER="mindforge_postgres_dev"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[seed-courses]${NC}   $*"; }
success() { echo -e "${GREEN}[seed-courses]${NC}   $*"; }
error()   { echo -e "${RED}[seed-courses]${NC}   $*" >&2; exit 1; }

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
  # Non-fatal: this file is generated content, not checked-in-by-default
  # source. dev-reset calls this script unconditionally, so a repo clone
  # that hasn't run `coursegen generate` yet (or content authoring still in
  # progress) must not break the base dev-seed flow.
  info "Generated fixture not found: $SEED_FILE — skipping (run: cd backend && go run ./cmd/coursegen generate)"
  exit 0
fi

info "Loading generated fixture: backend/db/fixtures/k8s_fastkube.generated.sql"
docker cp "$SEED_FILE" "${CONTAINER}:/tmp/k8s_fastkube.generated.sql"
docker exec "$CONTAINER" psql \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -v ON_ERROR_STOP=1 \
  -f /tmp/k8s_fastkube.generated.sql > /dev/null
docker exec "$CONTAINER" rm -f /tmp/k8s_fastkube.generated.sql

success "Generated course content loaded successfully."
