#!/usr/bin/env bash
# One-shot, idempotent setup of a remote Linux dev box (Debian/Ubuntu) for `make dev-k3s`.
# Prereqs: repo cloned, .env and backend/.env copied over (they hold the Neon dev DB URL
# and storage keys), k3s running on this box. Safe to re-run.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

BACKEND_PORT="${BACKEND_PORT:-8090}"   # 8080 is commonly taken (Jenkins)
FRONTEND_PORT=3000

have() { command -v "$1" >/dev/null 2>&1; }
need_file() { [[ -f "$1" ]] || { echo "missing $1 — copy it from your main machine first" >&2; exit 1; }; }

# set_env FILE KEY VALUE [only-if-missing]
set_env() {
  local file="$1" key="$2" val="$3" keep="${4:-}"
  touch "$file"; chmod 600 "$file"
  if grep -q "^${key}=" "$file"; then
    [[ -n "$keep" ]] && return 0
    sed -i "s|^${key}=.*|${key}=${val}|" "$file"
  else
    printf '%s=%s\n' "$key" "$val" >> "$file"
  fi
}

need_file .env
need_file backend/.env
chmod 600 .env backend/.env

# ── Tools ────────────────────────────────────────────────────────────────────
sudo apt-get update -y
sudo apt-get install -y make git curl unzip golang-go postgresql-client openssl
have bun       || curl -fsSL https://bun.sh/install | bash
have kubectl   || { curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
                    && sudo install /tmp/kubectl /usr/local/bin/kubectl; }
have tailscale || curl -fsSL https://tailscale.com/install.sh | sh

grep -q ".bun/bin" ~/.bashrc || echo 'export PATH="$HOME/.bun/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.bun/bin:$PATH"

# ── Cluster access (k3s kubectl defaults to a root-only file, then falls back to localhost:8080) ──
if [[ ! -s "$HOME/.kube/config" ]]; then
  mkdir -p ~/.kube
  sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
  sudo chown "$USER" ~/.kube/config
fi
chmod 600 ~/.kube/config
export KUBECONFIG="$HOME/.kube/config"
grep -q KUBECONFIG ~/.bashrc || echo 'export KUBECONFIG="$HOME/.kube/config"' >> ~/.bashrc
kubectl get pods -n mindforge >/dev/null || { echo "kubectl cannot reach the mindforge namespace" >&2; exit 1; }

# ── Tailscale (tailnet-only HTTPS in front of the localhost-bound Next dev server) ──
tailscale status >/dev/null 2>&1 || sudo tailscale up
sudo tailscale serve --bg "$FRONTEND_PORT"
# The lab terminal websocket goes browser -> labproxy; Tailscale strips the /lab-ws prefix like Caddy does.
sudo tailscale serve --bg --set-path /lab-ws http://127.0.0.1:18081
ts_host="$(tailscale status --json | python3 -c 'import sys,json;print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')"

# ── backend/.env: values that must hold on this box ──────────────────────────
set_env backend/.env PORT "$BACKEND_PORT"
# A .env copied from another machine carries that machine's kubeconfig path.
set_env backend/.env KUBECONFIG "$HOME/.kube/config"
set_env backend/.env PISTON_URL "http://localhost:2000"
set_env backend/.env LABS_RUNTIME "kubernetes"
if ! grep -q '^LAB_TOKEN_SECRET=.\+' backend/.env; then
  # Must equal the in-cluster labproxy's secret (distinct from JWT_SECRET).
  secret="$(kubectl get secret -n mindforge -o name | grep -m1 'secret/mindforge-secrets')"
  set_env backend/.env LAB_TOKEN_SECRET "$(kubectl get "$secret" -n mindforge -o jsonpath='{.data.LAB_TOKEN_SECRET}' | base64 -d)"
fi

# ── frontend/.env.local: proxy target + HMR origin ───────────────────────────
set_env frontend/.env.local BACKEND_URL "http://127.0.0.1:${BACKEND_PORT}"
set_env frontend/.env.local NEXT_ALLOWED_DEV_ORIGINS "$ts_host"
set_env frontend/.env.local NEXT_PUBLIC_LAB_PROXY_URL "wss://${ts_host}/lab-ws"

# ── Dev database: `mindforge_dev` on the cluster's Postgres ──────────────────
# A database (not a schema): the baseline migration hard-codes `public.`, so a schema would not
# isolate anything. Reached through a port-forward on 127.0.0.1, which counts as a local DB, so
# dev fixtures (users, courses, labs) auto-seed on every backend boot — no manual seeding.
DEV_DB=mindforge_dev
PG_LOCAL_PORT=15432
if ! grep -q "^DATABASE_URL=.*@127.0.0.1:${PG_LOCAL_PORT}/${DEV_DB}" backend/.env; then
  cp backend/.env "backend/.env.bak.$(date +%s)"   # holds the previous DATABASE_URL
  pw="$(openssl rand -hex 16)"
  # The postgres image trusts local socket connections, so no superuser secret is needed.
  kubectl exec -i -n mindforge postgres-0 -- sh -c 'psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 -q' <<SQL
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${DEV_DB}') THEN
    CREATE ROLE ${DEV_DB} LOGIN PASSWORD '${pw}';
  ELSE
    ALTER ROLE ${DEV_DB} PASSWORD '${pw}';
  END IF;
END \$\$;
SELECT 'CREATE DATABASE ${DEV_DB} OWNER ${DEV_DB}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DEV_DB}')\gexec
SQL
  set_env backend/.env DATABASE_URL "postgres://${DEV_DB}:${pw}@127.0.0.1:${PG_LOCAL_PORT}/${DEV_DB}?sslmode=disable"
fi
# No remote-DB opt-in needed any more; a leftover one would be harmless but misleading.
sed -i '/^DEV_SEED_REMOTE_DB=/d' backend/.env

# ── Platform debug labs: verified offline (CI labset), never built in the app ─
# Without an import every platform lab stays unpublished. Verifying all recipes
# runs every one through the full matrix in local Docker (slow on first run;
# later runs reuse ~/.cache/mindforge-lab-verify). docs/debug-labs.md
# "Platform labs: CI artifacts".
read -r -p "Verify and import the platform debug labs now (slow first run, needs Docker)? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  docker network inspect mindforge-labs >/dev/null 2>&1 || docker network create mindforge-labs >/dev/null
  docker build -t mindforge/lab-debug:1 -f lab-images/lab-debug/Dockerfile lab-images
  labset="$(mktemp -d)/labset"
  trap 'rm -rf "$(dirname "$labset")"' EXIT   # the labset holds graders/fixes: never keep it around
  (cd backend && go run ./cmd/coursegen blocks verify --parallel 1 --artifact "$labset" --cache "$HOME/.cache/mindforge-lab-verify")
  bash scripts/import-lab-artifacts.sh --target local "$labset"
fi

echo "Ready: make dev-k3s  →  https://${ts_host}"
