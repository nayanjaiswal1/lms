#!/bin/bash
# The Ops Console mock API on :8001 (Vite proxies /api to it). Supervised by the
# lab runtime; stdout and stderr land in /var/log/mindforge-lab/api.log.
set -uo pipefail
cd /home/labuser/work || exit 1
exec node server/api.mjs
