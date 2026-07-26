#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/dev-tunnel.sh — expose the local dev stack (frontend + backend, incl.
# the AI Connector's OAuth/MCP routes) through a disposable Cloudflare quick
# tunnel, so it's reachable from another device (a phone, a real Claude/ChatGPT
# client) without deploying anything.
#
# A quick tunnel has no stable identity — every run mints a brand new random
# *.trycloudflare.com URL. Re-run this script any time the tunnel needs
# restarting rather than hand-editing FRONTEND_URL / MCP_PUBLIC_URL /
# NEXT_PUBLIC_API_URL yourself; it propagates the new URL into both .env files
# and restarts the backend + frontend for you.
#
# Testing-only. Not part of docker-compose.dev.yml on purpose — this is opt-in
# exposure, never started implicitly by `make dev-up`.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail
export MSYS_NO_PATHCONV=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
NETWORK="mindforge_mindforge_dev"
BACKEND_ENV="${PROJECT_ROOT}/backend/.env"
FRONTEND_ENV="${PROJECT_ROOT}/frontend/.env.local"

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[tunnel]${NC} $*"; }
success() { echo -e "${GREEN}[tunnel]${NC} $*"; }
error()   { echo -e "${RED}[tunnel]${NC} $*" >&2; exit 1; }

docker network inspect "$NETWORK" &>/dev/null || error "Network '$NETWORK' not found — start the stack first with: make dev-up"

# ─── Caddy: fronts frontend (host.docker.internal:3000) and backend, incl.
# /oauth, /.well-known, /mcp (not just /api/*), behind one origin ───────────
if ! docker inspect mindforge_caddy_dev &>/dev/null; then
  info "Starting Caddy (Caddyfile.dev)..."
  docker run -d --name mindforge_caddy_dev --network "$NETWORK" \
    -v "${PROJECT_ROOT}/Caddyfile.dev:/etc/caddy/Caddyfile" \
    caddy:2-alpine >/dev/null
else
  info "Caddy already running, reusing it."
fi

# ─── Tunnel: always recreated — the old URL dies the moment we do this ─────
info "Requesting a fresh quick tunnel..."
docker rm -f mindforge_tunnel &>/dev/null || true
docker run -d --name mindforge_tunnel --network "$NETWORK" \
  cloudflare/cloudflared:latest tunnel --url http://mindforge_caddy_dev:80 --no-autoupdate >/dev/null

URL=""
for _ in $(seq 1 30); do
  URL=$(docker logs mindforge_tunnel 2>&1 | grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' | head -1 || true)
  [[ -n "$URL" ]] && break
  sleep 1
done
[[ -n "$URL" ]] || error "Tunnel URL did not appear within 30s — check: docker logs mindforge_tunnel"
success "Tunnel URL: $URL"

# ─── Propagate into both .env files (append if the key is missing) ─────────
update_var() {
  local file="$1" key="$2" value="$3"
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

info "Updating backend/.env and frontend/.env.local..."
update_var "$BACKEND_ENV" "FRONTEND_URL" "$URL"
update_var "$BACKEND_ENV" "MCP_PUBLIC_URL" "$URL"
update_var "$FRONTEND_ENV" "NEXT_PUBLIC_API_URL" "$URL"
update_var "$FRONTEND_ENV" "MCP_PUBLIC_URL" "$URL"

# ─── Restart backend (picks up FRONTEND_URL/MCP_PUBLIC_URL — WebAuthn RPID,
# CORS-allowed origin, and OAuth discovery all derive from these) ───────────
info "Restarting backend..."
# Relative filename, run from inside PROJECT_ROOT: an absolute path here gets
# mangled by Git Bash's MSYS path conversion on Windows even with
# MSYS_NO_PATHCONV set (docker compose's own arg parsing seems to re-trigger
# it) — a relative name sidesteps the conversion entirely.
( cd "$PROJECT_ROOT" && docker compose -f docker-compose.dev.yml restart backend >/dev/null )

# ─── Restart frontend (host process — Next.js only reads .env.local at boot) ─
info "Restarting frontend..."
FRONTEND_PID=$(netstat -ano 2>/dev/null | grep ":3000 " | grep LISTENING | awk '{print $5}' | head -1 || true)
if [[ -n "$FRONTEND_PID" ]]; then
  taskkill //PID "$FRONTEND_PID" //F &>/dev/null || true
fi
( cd "${PROJECT_ROOT}/frontend" && nohup pnpm dev > /tmp/frontend.log 2>&1 & disown ) 2>/dev/null

sleep 3
success "Ready. MindForge (and the AI Connector) reachable at: $URL"
info "Note: any passkey registered under the previous URL's RPID will need re-registering under this one."
info "Tear down when done: docker rm -f mindforge_tunnel mindforge_caddy_dev"
