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
sudo apt-get install -y make git curl unzip golang-go postgresql-client
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
ts_host="$(tailscale status --json | python3 -c 'import sys,json;print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')"

# ── backend/.env: values that must hold on this box ──────────────────────────
set_env backend/.env PORT "$BACKEND_PORT"
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

# ── Dev users (admin@mindforge.dev / Admin123!) — only once the backend has migrated ──
# Read the URL with grep, never `source` the file: its unquoted '&' would background the line.
DATABASE_URL="$(grep -m1 '^DATABASE_URL=' backend/.env | cut -d= -f2-)"
db_host="$(sed -E 's#.*@([^/:?]+).*##' <<<"$DATABASE_URL")"
has_users="$(psql "$DATABASE_URL" -Atc 'select count(*) from users' 2>/dev/null || echo none)"
if [[ "$has_users" == "0" ]]; then
  read -r -p "Seed dev users into database host $db_host? It must NOT be prod. [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] && psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/db/fixtures/dev_seed.sql
elif [[ "$has_users" == "none" ]]; then
  echo "Users table not there yet — run 'make dev-k3s' once (it migrates), then re-run this script to seed."
fi

echo "Ready: make dev-k3s  →  https://${ts_host}"
