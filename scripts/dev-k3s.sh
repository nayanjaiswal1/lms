#!/usr/bin/env bash
# Hot-reload dev on a box running k3s. Everything the app needs comes from the
# cluster, and nothing is exposed beyond 127.0.0.1:
#   - Postgres: database `mindforge_dev` on the cluster's Postgres, port-forwarded to :15432
#     (created by scripts/setup-dev-box.sh). A local host means dev fixtures auto-seed on boot.
#   - labproxy: run natively against that same database (it must see the backend's lab
#     sessions), on :18081, reached remotely through `tailscale serve --set-path /lab-ws`.
#   - piston: port-forwarded from the cluster.
# Redis comes from backend/.env; object storage is the cluster MinIO, port-forwarded to :19000. Remote access: `tailscale serve --bg 3000`
# (tailnet only, never funnel).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$root/backend/.env"
PG_LOCAL_PORT=15432
LABPROXY_LOCAL_PORT=18081
export PATH="$HOME/.bun/bin:$PATH"

command -v bun >/dev/null || { echo "bun not found — run scripts/setup-dev-box.sh" >&2; exit 1; }

# Shell vars exported earlier (e.g. `set -a; source backend/.env`) would override the
# file — godotenv never overrides the environment — so drop whatever the file defines.
unset $(grep -E '^[A-Z_][A-Z0-9_]*=' "$env_file" | cut -d= -f1)

# k3s kubectl defaults to /etc/rancher/k3s/k3s.yaml (root-only), then falls back to localhost:8080.
# Set after the unset above: backend/.env defines KUBECONFIG too (setup-dev-box.sh points it here).
export KUBECONFIG="$HOME/.kube/config"

# Export every KEY=VALUE of backend/.env into the current subshell. Never `source` it: an
# unquoted '&' in a URL would background the line.
load_env() { while IFS= read -r line; do export "$line"; done < <(grep -E '^[A-Z_][A-Z0-9_]*=' "$env_file"); }

# Free the forward/labproxy ports from stale processes left by earlier runs.
pkill -f "kubectl port-forward" || true
pkill -f "cmd/labproxy" || true
sleep 1

# port-forward exits when its pod restarts or the connection resets — keep it alive.
fwd() { while true; do kubectl port-forward "$@" || true; sleep 2; done; }

trap 'kill 0' EXIT
fwd -n mindforge svc/postgres "$PG_LOCAL_PORT":5432 &
fwd -n mindforge-piston svc/piston 2000:2000 &
# Object storage is the k3s MinIO (backend/.env: MINIO_ENDPOINT=127.0.0.1:19000, MINIO_USE_SSL=false). The same
# endpoint is MINIO_PUBLIC_ENDPOINT, so presigned URLs resolve in a browser on this box (or through tailscale serve).
fwd -n mindforge svc/minio 19000:9000 &

# labproxy: same DB and Redis as the backend, same token secret, HMR/terminal origin allowed.
(
  load_env
  origin="$(grep -m1 '^NEXT_ALLOWED_DEV_ORIGINS=' "$root/frontend/.env.local" 2>/dev/null | cut -d= -f2- || true)"
  export LABPROXY_PORT="$LABPROXY_LOCAL_PORT" LABPROXY_DB_URL="$DATABASE_URL" LABPROXY_REDIS_URL="$REDIS_URL" \
         LABPROXY_JWT_ISSUER=mindforge-labproxy LABPROXY_PREVIEW_DOMAIN=localhost \
         LABPROXY_PUBLIC_PATH_PREFIX=/lab-ws \
         LABPROXY_ALLOWED_ORIGINS="${origin:+https://$origin}"
  cd "$root/backend" && until (exec 3<>/dev/tcp/127.0.0.1/"$PG_LOCAL_PORT") 2>/dev/null; do sleep 1; done
  exec go run ./cmd/labproxy
) &

# Air restarts on file change only, so don't launch it until Postgres is reachable.
(
  cd "$root/backend" && until (exec 3<>/dev/tcp/127.0.0.1/"$PG_LOCAL_PORT") 2>/dev/null; do sleep 1; done
  exec go run github.com/air-verse/air@latest -c .air.toml
) &
# Wait for the backend (air rebuild takes a while) so first page loads do not hit ECONNREFUSED on :8090.
(cd "$root/frontend" && bun install --frozen-lockfile && until (exec 3<>/dev/tcp/127.0.0.1/8090) 2>/dev/null; do sleep 1; done && bun run dev -H 127.0.0.1) &
wait
