#!/bin/bash
# The shop API (FastAPI) on :8000 with auto-reload. Supervised by the lab
# runtime; stdout and stderr land in /var/log/mindforge-lab/api.log.
set -uo pipefail
cd /home/labuser/work || exit 1
# Environment overrides written by the lab (allowed origins, ...).
if [ -f .lab/env ]; then . .lab/env; fi

exec python3 -m uvicorn backend.app.main:create_app --factory --host 0.0.0.0 --port 8000 --reload --reload-dir backend
