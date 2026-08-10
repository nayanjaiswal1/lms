#!/usr/bin/env bash
# Forwards k3s-hosted infra (postgres/redis/minio/piston) to WSL's localhost,
# which WSL2's localhostForwarding then relays to Windows localhost — for
# running frontend/backend natively on Windows against k3s infra instead of
# docker-compose.dev.yml. See docs/local-k3s-dev.md.
set -euo pipefail

kubectl port-forward -n mindforge svc/postgres 5432:5432 &
kubectl port-forward -n mindforge svc/redis 6379:6379 &
kubectl port-forward -n mindforge svc/minio 9000:9000 &
kubectl port-forward -n mindforge svc/labproxy 18081:8081 &  # 8081 is taken by an unrelated local docker-proxy
kubectl port-forward -n mindforge-labs svc/piston 2000:2000 &

trap 'kill $(jobs -p)' EXIT
echo "Port-forwarding postgres:5432 redis:6379 minio:9000 labproxy(18081->8081) piston:2000 — Ctrl+C to stop."
wait
