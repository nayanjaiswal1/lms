#!/bin/bash
# The orders API. Supervised by the lab runtime; stdout and stderr land in /var/log/mindforge-lab/app.log (written by the supervisor).
# Runs uvicorn under debugpy (attach on :5678) without the autoreloader.
set -uo pipefail
cd /home/labuser/work || exit 1
. scripts/dev-env.sh
# Environment overrides written by the lab (payments faults, pool sizes, ...).
if [ -f .lab/env ]; then . .lab/env; fi

until pg_isready -q -h 127.0.0.1 -p 5432; do sleep 0.3; done

exec python3 -m debugpy --listen 127.0.0.1:5678 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
