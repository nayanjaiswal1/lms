#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/restore-prod.sh — Restore the MindForge production stack from a backup
# taken by scripts/backup-prod.sh.
#
# Usage:
#   bash scripts/restore-prod.sh latest          # restore the most recent backup
#   bash scripts/restore-prod.sh 20260726_120000 # restore a specific backup
#   bash scripts/restore-prod.sh latest --yes    # skip the confirmation prompt
#
# DESTRUCTIVE: overwrites the current Postgres DB, MinIO data, and Caddy TLS
# state. Stops backend/frontend/labproxy/caddy for the duration.
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

info()    { echo -e "${BLUE}[restore]${NC} $*"; }
success() { echo -e "${GREEN}[restore]${NC} $*"; }
warn()    { echo -e "${YELLOW}[restore]${NC} $*"; }
error()   { echo -e "${RED}[restore]${NC} $*" >&2; exit 1; }

[[ -f .env.prod ]] || error ".env.prod not found. Run this from the mindforge/ directory on the prod server."
set -a
# shellcheck disable=SC1091
source .env.prod
set +a

TARGET="${1:-}"
ASSUME_YES=0
[[ "${2:-}" == "--yes" || "${1:-}" == "--yes" ]] && ASSUME_YES=1
[[ -n "$TARGET" ]] || error "Usage: $0 <timestamp|latest> [--yes]"

PG_CONTAINER="mindforge_postgres_prod"
MINIO_VOLUME="mindforge_minio_prod"
CADDY_DATA_VOLUME="mindforge_caddy_data"
CADDY_CONFIG_VOLUME="mindforge_caddy_config"
COMPOSE="docker compose --env-file .env.prod -f docker-compose.prod.yml"
BACKUP_ROOT="${PROJECT_ROOT}/backups"

# ─── 1. Resolve target backup + its chain (nearest full up through target) ───
[[ -d "$BACKUP_ROOT" ]] || error "No backups/ directory found."

if [[ "$TARGET" == "latest" ]]; then
  TARGET_DIR_NAME="$(find "$BACKUP_ROOT" -maxdepth 1 -type d -name "20*" -printf '%f\n' | sort | tail -1)"
else
  TARGET_DIR_NAME="$(find "$BACKUP_ROOT" -maxdepth 1 -type d -name "${TARGET}_*" -printf '%f\n' | sort | tail -1)"
fi
[[ -n "$TARGET_DIR_NAME" ]] || error "No backup found matching '$TARGET' in $BACKUP_ROOT"

mapfile -t ALL_DIRS < <(find "$BACKUP_ROOT" -maxdepth 1 -type d -name "20*" -printf '%f\n' | sort)

CHAIN=()
for name in "${ALL_DIRS[@]}"; do
  [[ "$name" > "$TARGET_DIR_NAME" ]] && break
  if [[ "$name" == *_full ]]; then
    CHAIN=("$name")   # a full backup restarts the chain
  else
    CHAIN+=("$name")
  fi
  [[ "$name" == "$TARGET_DIR_NAME" ]] && break
done
[[ ${#CHAIN[@]} -gt 0 && "${CHAIN[0]}" == *_full ]] || error "Could not find a full backup at or before '$TARGET_DIR_NAME' — chain is incomplete."

info "Target: $TARGET_DIR_NAME"
info "Restore chain (${#CHAIN[@]} backups): ${CHAIN[*]}"

if [[ "$ASSUME_YES" -ne 1 ]]; then
  warn "This will OVERWRITE the current production database, file storage, and TLS state."
  read -r -p "Type 'restore' to continue: " confirm
  [[ "$confirm" == "restore" ]] || error "Aborted."
fi

# ─── 2. Stop everything that reads/writes the data being restored ────────────
info "Stopping backend, frontend, labproxy, caddy..."
$COMPOSE stop backend frontend labproxy caddy

# ─── 3. Restore Postgres (dumps are always full — use the target's dump only) ─
info "Restoring Postgres from ${TARGET_DIR_NAME}/postgres.dump..."
docker cp "${BACKUP_ROOT}/${TARGET_DIR_NAME}/postgres.dump" "${PG_CONTAINER}:/tmp/restore.dump"
docker exec "$PG_CONTAINER" pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists -1 /tmp/restore.dump
docker exec "$PG_CONTAINER" rm -f /tmp/restore.dump
success "Postgres restored."

# ─── 4. Restore MinIO: wipe volume, replay full + incrementals in order ──────
info "Restoring MinIO data volume (replaying ${#CHAIN[@]} archive(s))..."
docker run --rm -v "${MINIO_VOLUME}:/data" alpine:3.20 sh -c 'rm -rf /data/* /data/..?* /data/.[!.]* 2>/dev/null; true'
for name in "${CHAIN[@]}"; do
  info "  applying ${name}/minio.tar.gz"
  docker run --rm \
    -v "${MINIO_VOLUME}:/data" \
    -v "${BACKUP_ROOT}/${name}:/in:ro" \
    alpine:3.20 \
    tar --incremental -xzf /in/minio.tar.gz -C /data
done
success "MinIO restored."

# ─── 5. Restore Caddy TLS state (always a full archive — target only) ────────
info "Restoring Caddy TLS state from ${TARGET_DIR_NAME}/caddy.tar.gz..."
docker run --rm -v "${CADDY_DATA_VOLUME}:/data" -v "${CADDY_CONFIG_VOLUME}:/config" alpine:3.20 \
  sh -c 'rm -rf /data/* /config/*'
docker run --rm \
  -v "${CADDY_DATA_VOLUME}:/data" \
  -v "${CADDY_CONFIG_VOLUME}:/config" \
  -v "${BACKUP_ROOT}/${TARGET_DIR_NAME}:/in:ro" \
  alpine:3.20 \
  tar -xzf /in/caddy.tar.gz -C /
success "Caddy TLS state restored."

# ─── 6. Bring the stack back up ────────────────────────────────────────────────
info "Starting backend, frontend, labproxy, caddy..."
$COMPOSE up -d backend frontend labproxy caddy

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

success "Restore complete from ${TARGET_DIR_NAME}."
