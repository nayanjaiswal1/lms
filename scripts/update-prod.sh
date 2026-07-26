#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/update-prod.sh — Single-command update: pull latest code, back up
# first as a safety net, then rebuild and redeploy.
# Run on the target server, from the mindforge/ directory: bash scripts/update-prod.sh
#
# On failure: nothing is auto-restored (data rollback is a judgment call, not
# something to do blindly). The script prints the exact commands to reverse
# the code deploy and, if needed, restore data from the backup it just took.
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

info()    { echo -e "${BLUE}[update]${NC} $*"; }
success() { echo -e "${GREEN}[update]${NC} $*"; }
warn()    { echo -e "${YELLOW}[update]${NC} $*"; }
error()   { echo -e "${RED}[update]${NC} $*" >&2; exit 1; }

command -v git &>/dev/null || error "git is not installed."
git rev-parse --is-inside-work-tree &>/dev/null || error "Not inside a git repository."

PREV_COMMIT="$(git rev-parse HEAD)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# ─── 1. Safety-net backup before touching anything ────────────────────────────
info "Taking a pre-update backup..."
bash scripts/backup-prod.sh incremental
BACKUP_TS="$(find "${PROJECT_ROOT}/backups" -maxdepth 1 -type d -name "20*" -printf '%f\n' | sort | tail -1 | cut -d_ -f1-2)"

# ─── 2. Pull latest code ───────────────────────────────────────────────────────
info "Pulling latest '${BRANCH}'..."
git fetch origin "$BRANCH"
git merge --ff-only "origin/${BRANCH}" || error "Local branch has diverged from origin/${BRANCH} — resolve manually (fast-forward only, refusing to guess a merge)."
NEW_COMMIT="$(git rev-parse HEAD)"

if [[ "$NEW_COMMIT" == "$PREV_COMMIT" ]]; then
  info "Already up to date at ${PREV_COMMIT:0:12} — redeploying anyway (in case of local-only changes to compose/env)."
else
  success "Updated ${PREV_COMMIT:0:12} -> ${NEW_COMMIT:0:12}"
fi

# ─── 3. Build + deploy ─────────────────────────────────────────────────────────
info "Deploying..."
if bash scripts/deploy-prod.sh; then
  success "Update complete. Now running ${NEW_COMMIT:0:12}."
  exit 0
fi

# ─── 4. Deploy failed — surface rollback options, don't act automatically ────
error_msg="Deploy failed after updating to ${NEW_COMMIT:0:12}."
echo ""
echo -e "${RED}══════════════════════════════════════════════${NC}"
echo -e "${RED}  $error_msg${NC}"
echo -e "${RED}══════════════════════════════════════════════${NC}"
echo ""
echo "  Roll back code:    git reset --hard ${PREV_COMMIT} && bash scripts/deploy-prod.sh"
echo "  Roll back data:    bash scripts/restore-prod.sh ${BACKUP_TS}"
echo "  Inspect first:     docker compose --env-file .env.prod -f docker-compose.prod.yml logs backend"
echo ""
exit 1
