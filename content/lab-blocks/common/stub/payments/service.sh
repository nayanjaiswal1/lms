#!/bin/bash
# Payments provider stub (supervised). Fault defaults come from .lab/env (PAYMENTS_STUB_* variables).
set -uo pipefail
cd /home/labuser/work || exit 1
. scripts/dev-env.sh
if [ -f .lab/env ]; then . .lab/env; fi
stub="$(find .mf/stubs -maxdepth 2 -name payments_stub.py | head -1)"
[ -n "$stub" ] || { echo "payments stub not found under .mf/stubs" >&2; sleep 5; exit 1; }
exec python3 "$stub"
