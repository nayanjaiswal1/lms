#!/usr/bin/env bash
# Hot-reload dev against k3s-hosted infra: port-forwards labproxy/piston,
# then runs Air (Go) and `next dev` natively. Postgres/Redis URLs come from
# backend/.env (Neon/Upstash); the backend applies migrations on boot.
# Everything binds to 127.0.0.1; reach it remotely via `tailscale serve --bg 3000` (tailnet only, never funnel).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.bun/bin:$PATH"
# k3s kubectl defaults to /etc/rancher/k3s/k3s.yaml (root-only), then falls back to localhost:8080.
[[ -z "${KUBECONFIG:-}" && -f "$HOME/.kube/config" ]] && export KUBECONFIG="$HOME/.kube/config"

command -v bun >/dev/null || { echo "bun not found â€” run scripts/setup-dev-box.sh" >&2; exit 1; }

# port-forward exits when its pod restarts or the connection resets — keep it alive.
fwd() { while true; do kubectl port-forward "$@" || true; sleep 2; done; }

trap 'kill 0' EXIT
fwd -n mindforge svc/labproxy 18081:8081 &
fwd -n mindforge-piston svc/piston 2000:2000 &
(cd "$root/backend" && go run github.com/air-verse/air@latest -c .air.toml) &
(cd "$root/frontend" && bun install --frozen-lockfile && bun run dev -H 127.0.0.1) &
wait
