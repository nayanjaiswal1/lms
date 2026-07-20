#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/db-seed-courses.sh — Load generated course-content fixtures
# Runs every backend/db/fixtures/*.generated.sql inside the Postgres
# container. Idempotent — the SQL uses ON CONFLICT ... DO UPDATE/NOTHING
# throughout, so re-running after `coursegen generate` produces updates, not
# duplicates. Regenerate a course's fixture first with:
#   cd backend && go run ./cmd/coursegen generate --in ../content/courses/<slug> --out db/fixtures/<slug>.generated.sql
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FIXTURES_DIR="${PROJECT_ROOT}/backend/db/fixtures"
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

shopt -s nullglob
FIXTURE_FILES=("${FIXTURES_DIR}"/*.generated.sql)
shopt -u nullglob

if [[ ${#FIXTURE_FILES[@]} -eq 0 ]]; then
  # Non-fatal: these files are generated content, not checked-in-by-default
  # source. dev-reset calls this script unconditionally, so a repo clone
  # that hasn't run `coursegen generate` yet (or content authoring still in
  # progress) must not break the base dev-seed flow.
  info "No generated fixtures found in backend/db/fixtures/ — skipping (run: cd backend && go run ./cmd/coursegen generate)"
  exit 0
fi

for seed_file in "${FIXTURE_FILES[@]}"; do
  fixture_name="$(basename "$seed_file")"
  info "Loading generated fixture: backend/db/fixtures/${fixture_name}"
  # Pipe over stdin instead of `docker cp` + `-f <in-container path>` — the
  # latter needs an in-container /tmp/... path as a CLI arg, which Git Bash
  # on Windows rewrites into a host path before docker ever sees it. Stdin
  # redirection is opened by bash itself, so no in-container path is ever
  # passed as an argument and there's nothing to mangle or clean up.
  docker exec -i "$CONTAINER" psql \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -v ON_ERROR_STOP=1 \
    < "$seed_file" > /dev/null
done

success "Generated course content loaded successfully."
