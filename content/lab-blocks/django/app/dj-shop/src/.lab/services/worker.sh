#!/bin/bash
# Celery worker for the shop (order emails, alerts). Supervised by the lab runtime.
set -uo pipefail
cd /home/labuser/work || exit 1
. scripts/dev-env.sh
if [ -f .lab/env ]; then . .lab/env; fi

until pg_isready -q -h 127.0.0.1 -p 5432; do sleep 0.3; done
until redis-cli -h 127.0.0.1 ping >/dev/null 2>&1; do sleep 0.3; done
exec python3 -m celery -A config worker -l INFO --concurrency 2
