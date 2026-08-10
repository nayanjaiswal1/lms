#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/restore-db-to-k3s.sh — Restore a pg_dump (custom format, -Fc) into
# the postgres StatefulSet running in the local k3s cluster's "mindforge"
# namespace, replacing whatever the backend's embedded migration runner
# auto-applied on first boot (schema + any migration-bundled seed fixtures).
#
# Usage: bash scripts/restore-db-to-k3s.sh /path/to/mindforge_dev.dump
#
# Take the dump from a running docker-compose dev stack with:
#   docker exec mindforge_postgres_dev pg_dump -U mindforge -d mindforge_dev -Fc > mindforge_dev.dump
# (redirect to a file, don't use pg_dump's -f flag — on Windows/Git Bash the
# in-container path gets rewritten to a host path before docker sees it.)
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

DUMP_FILE="${1:-}"
[[ -n "$DUMP_FILE" && -f "$DUMP_FILE" ]] || error "Usage: bash scripts/restore-db-to-k3s.sh /path/to/dump.dump"

command -v kubectl &>/dev/null || error "kubectl is not installed."
kubectl get statefulset postgres -n mindforge &>/dev/null || error "postgres StatefulSet not found in the mindforge namespace — deploy first: bash scripts/deploy-k8s.sh local"

POSTGRES_USER="${POSTGRES_USER:-mindforge}"
POSTGRES_DB="${POSTGRES_DB:-mindforge_dev}"

info "Waiting for postgres-0 to be ready..."
kubectl wait --for=condition=Ready pod/postgres-0 -n mindforge --timeout=120s

info "Dropping and recreating '${POSTGRES_DB}' (clean target for restore — the backend's embedded migration runner already applied schema + bundled seed fixtures on first boot, which this replaces)..."
# Each statement in its own -c: DROP/CREATE DATABASE cannot run inside the
# implicit transaction block psql wraps around multiple -c statements.
kubectl exec -n mindforge postgres-0 -- psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${POSTGRES_DB}' AND pid <> pg_backend_pid();" > /dev/null
kubectl exec -n mindforge postgres-0 -- psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 -c \
  "DROP DATABASE IF EXISTS ${POSTGRES_DB};"
kubectl exec -n mindforge postgres-0 -- psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 -c \
  "CREATE DATABASE ${POSTGRES_DB} OWNER ${POSTGRES_USER};"

info "Restoring ${DUMP_FILE}..."
kubectl exec -i -n mindforge postgres-0 -- pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --no-privileges < "$DUMP_FILE"

success "Restore complete. Restart the backend so it re-checks migration state against the restored data:"
echo "  kubectl rollout restart deployment/backend -n mindforge"
