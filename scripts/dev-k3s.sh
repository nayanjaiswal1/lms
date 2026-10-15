#!/usr/bin/env bash
# Hot-reload dev against k3s-hosted infra: port-forwards redis/minio/piston/labproxy,
# then runs Air (Go) and `next dev` natively. Postgres/Redis URLs come from backend/.env.
# Everything binds to 127.0.0.1; reach it remotely via `tailscale serve --bg 3000` (tailnet only, never funnel).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

trap 'kill 0' EXIT
bash "$root/scripts/port-forward-k3s-infra.sh" &
(cd "$root/backend" && go run github.com/air-verse/air@latest -c .air.toml) &
(cd "$root/frontend" && bun install --frozen-lockfile && bun run dev -H 127.0.0.1) &
wait
