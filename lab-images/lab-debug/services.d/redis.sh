#!/bin/bash
# Redis for cache/Celery scenarios: loopback only, no persistence.
set -euo pipefail
exec redis-server --port 6379 --bind 127.0.0.1 --save "" --appendonly no --dir /tmp
