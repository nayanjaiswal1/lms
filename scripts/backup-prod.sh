#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/backup-prod.sh — Backup the MindForge production stack.
# Run on the target server, from the mindforge/ directory:
#   bash scripts/backup-prod.sh              # incremental (auto-upgrades to full weekly / on first run)
#   bash scripts/backup-prod.sh full          # force a fresh full backup
#
# Backs up:
#   - Postgres: full logical dump (pg_dump -Fc). ponytail: not WAL-incremental —
#     that needs pgBackRest/wal-g running continuously. A compressed custom-format
#     dump of this DB is small/fast enough that redoing it every run is cheaper
#     than the operational cost of streaming WAL archiving. Upgrade path if the
#     DB grows large: swap this step for pgBackRest.
#   - MinIO data volume: incremental tar (GNU tar --listed-incremental) — this is
#     where incremental actually pays off (user-uploaded files only grow).
#   - Caddy TLS state (certs/config volumes): full tar every run, cheap and small.
#
# Restore with scripts/restore-prod.sh.
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

info()    { echo -e "${BLUE}[backup]${NC} $*"; }
success() { echo -e "${GREEN}[backup]${NC} $*"; }
warn()    { echo -e "${YELLOW}[backup]${NC} $*"; }
error()   { echo -e "${RED}[backup]${NC} $*" >&2; exit 1; }

[[ -f .env.prod ]] || error ".env.prod not found. Run this from the mindforge/ directory on the prod server."
set -a
# shellcheck disable=SC1091
source .env.prod
set +a

PG_CONTAINER="mindforge_postgres_prod"
MINIO_VOLUME="mindforge_minio_prod"
CADDY_DATA_VOLUME="mindforge_caddy_data"
CADDY_CONFIG_VOLUME="mindforge_caddy_config"

BACKUP_ROOT="${PROJECT_ROOT}/backups"
STATE_DIR="${BACKUP_ROOT}/.state"
SNAR_FILE="${STATE_DIR}/minio.snar"
LAST_FULL_MARKER="${STATE_DIR}/last_full"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"

mkdir -p "$STATE_DIR"

for c in "$PG_CONTAINER"; do
  docker inspect "$c" &>/dev/null || error "Container '$c' is not running."
done

# ─── 1. Decide full vs incremental ────────────────────────────────────────────
MODE="${1:-incremental}"
[[ "$MODE" == "full" || "$MODE" == "incremental" ]] || error "Usage: $0 [full|incremental]"

if [[ "$MODE" == "incremental" ]]; then
  if [[ ! -f "$SNAR_FILE" ]]; then
    info "No prior backup found — first run is always full."
    MODE="full"
  elif [[ ! -f "$LAST_FULL_MARKER" ]] || [[ $(( ($(date +%s) - $(cat "$LAST_FULL_MARKER")) / 86400 )) -ge 7 ]]; then
    info "Last full backup is 7+ days old — upgrading to full."
    MODE="full"
  fi
fi

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DEST="${BACKUP_ROOT}/${TIMESTAMP}_${MODE}"
mkdir -p "$DEST"
info "Starting $MODE backup -> $DEST"

if [[ "$MODE" == "full" ]]; then
  rm -f "$SNAR_FILE"
  date +%s > "$LAST_FULL_MARKER"
fi

# ─── 2. Postgres dump ──────────────────────────────────────────────────────────
info "Dumping Postgres ($POSTGRES_DB)..."
docker exec "$PG_CONTAINER" pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc > "${DEST}/postgres.dump"
success "Postgres dump: $(du -h "${DEST}/postgres.dump" | cut -f1)"

# ─── 3. MinIO incremental tar (via helper container against the named volume) ─
info "Archiving MinIO volume ($([[ "$MODE" == "full" ]] && echo full || echo incremental))..."
cp -f "$SNAR_FILE" /tmp/minio.snar.work 2>/dev/null || : > /tmp/minio.snar.work
docker run --rm \
  -v "${MINIO_VOLUME}:/data:ro" \
  -v /tmp/minio.snar.work:/snar/minio.snar \
  -v "${DEST}:/out" \
  alpine:3.20 \
  tar --listed-incremental=/snar/minio.snar -czf /out/minio.tar.gz -C /data .
cp -f /tmp/minio.snar.work "$SNAR_FILE"
rm -f /tmp/minio.snar.work
success "MinIO archive: $(du -h "${DEST}/minio.tar.gz" | cut -f1)"

# ─── 4. Caddy TLS state (full every run — small) ──────────────────────────────
info "Archiving Caddy TLS state..."
docker run --rm \
  -v "${CADDY_DATA_VOLUME}:/data:ro" \
  -v "${CADDY_CONFIG_VOLUME}:/config:ro" \
  -v "${DEST}:/out" \
  alpine:3.20 \
  tar -czf /out/caddy.tar.gz -C / data config
success "Caddy archive: $(du -h "${DEST}/caddy.tar.gz" | cut -f1)"

# ─── 5. Manifest ────────────────────────────────────────────────────────────────
cat > "${DEST}/manifest.txt" <<EOF
timestamp=${TIMESTAMP}
mode=${MODE}
postgres_db=${POSTGRES_DB}
EOF

# ─── 6. Prune old backups ──────────────────────────────────────────────────────
# Never prune the current chain (the latest full backup and anything after it) —
# incrementals only restore by replaying on top of their full, so dropping it
# while newer incrementals still exist would break restores. Only prune whole
# superseded chains (a full and its incrementals, all older than the newest full).
info "Pruning superseded backups older than ${RETENTION_DAYS} days..."
LATEST_FULL="$(find "$BACKUP_ROOT" -maxdepth 1 -type d -name "*_full" -printf '%f\n' | sort | tail -1)"
if [[ -n "$LATEST_FULL" ]]; then
  find "$BACKUP_ROOT" -maxdepth 1 -type d -name "20*" -printf '%f\n' | sort | while read -r name; do
    [[ "$name" < "$LATEST_FULL" ]] || continue
    dir="${BACKUP_ROOT}/${name}"
    [[ -n "$(find "$dir" -maxdepth 0 -mtime "+${RETENTION_DAYS}")" ]] || continue
    warn "Removing superseded backup: $name"
    rm -rf "$dir"
  done
fi

success "Backup complete: ${DEST}"
echo "  Restore with: bash scripts/restore-prod.sh ${TIMESTAMP}"
