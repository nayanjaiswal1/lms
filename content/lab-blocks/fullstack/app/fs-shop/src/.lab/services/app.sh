#!/bin/bash
# The storefront dev server (Vite, hot reload) on :5173; it proxies /api to the
# backend on :8000. Supervised by the lab runtime; stdout and stderr land in
# /var/log/mindforge-lab/app.log.
set -uo pipefail
cd /home/labuser/work || exit 1
# Environment overrides written by the lab (build-time variables, ...).
if [ -f .lab/env ]; then . .lab/env; fi

# scripts/bootstrap.sh links node_modules during setup.
until [ -f node_modules/vite/bin/vite.js ]; do sleep 0.3; done
exec node node_modules/vite/bin/vite.js --host 0.0.0.0 --port 5173 --strictPort
