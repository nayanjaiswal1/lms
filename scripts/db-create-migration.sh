#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/db-create-migration.sh — Create a new migration file pair
# Usage: bash scripts/db-create-migration.sh <migration_name>
# Example: bash scripts/db-create-migration.sh add_courses
# Creates:
#   backend/db/migrations/002_add_courses.sql
#   backend/db/migrations/002_add_courses.down.sql
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MIGRATIONS_DIR="${PROJECT_ROOT}/backend/db/migrations"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[create]${NC} $*"; }
success() { echo -e "${GREEN}[create]${NC} $*"; }
error()   { echo -e "${RED}[create]${NC} $*" >&2; exit 1; }

# ─── Validate argument ────────────────────────────────────────────────────────
if [[ $# -lt 1 ]] || [[ -z "$1" ]]; then
  error "Usage: $0 <migration_name>"
  error "Example: $0 add_courses"
fi

NAME="$1"

# Normalize: lowercase, replace spaces/hyphens with underscores, strip special chars
NORMALIZED_NAME="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' -' '_' | tr -cd '[:alnum:]_')"

if [[ -z "$NORMALIZED_NAME" ]]; then
  error "Migration name '$NAME' is invalid after normalization. Use alphanumeric characters and underscores."
fi

# ─── Determine next sequence number ──────────────────────────────────────────
# Find all existing migration files (up migrations only, not .down.sql)
# Extract the numeric prefix and find the highest one.
LAST_NUM=0
while IFS= read -r -d '' filepath; do
  filename="$(basename "$filepath")"
  # Extract leading digits (e.g., "002" from "002_add_courses.sql")
  if [[ "$filename" =~ ^([0-9]+)_ ]]; then
    num="${BASH_REMATCH[1]}"
    # Strip leading zeros for arithmetic
    num_int=$((10#$num))
    if [[ $num_int -gt $LAST_NUM ]]; then
      LAST_NUM=$num_int
    fi
  fi
done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -name "*.sql" ! -name "*.down.sql" -print0 2>/dev/null)

NEXT_NUM=$((LAST_NUM + 1))
# Zero-pad to 3 digits
PADDED_NUM=$(printf "%03d" "$NEXT_NUM")

UP_FILE="${MIGRATIONS_DIR}/${PADDED_NUM}_${NORMALIZED_NAME}.sql"
DOWN_FILE="${MIGRATIONS_DIR}/${PADDED_NUM}_${NORMALIZED_NAME}.down.sql"

# ─── Check for conflicts ──────────────────────────────────────────────────────
if [[ -f "$UP_FILE" ]]; then
  error "Migration file already exists: $UP_FILE"
fi

# ─── Create the migration files ──────────────────────────────────────────────
cat > "$UP_FILE" <<EOF
-- ═════════════════════════════════════════════════════════════════════════
-- Migration ${PADDED_NUM} — ${NORMALIZED_NAME}
-- ═════════════════════════════════════════════════════════════════════════

EOF

cat > "$DOWN_FILE" <<EOF
-- ═════════════════════════════════════════════════════════════════════════
-- Migration ${PADDED_NUM} — ${NORMALIZED_NAME} (rollback)
-- ═════════════════════════════════════════════════════════════════════════

EOF

success "Created migration pair:"
info "  UP:   backend/db/migrations/${PADDED_NUM}_${NORMALIZED_NAME}.sql"
info "  DOWN: backend/db/migrations/${PADDED_NUM}_${NORMALIZED_NAME}.down.sql"
echo ""
info "Edit both files, then run: make migrate"
