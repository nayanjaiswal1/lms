#!/bin/bash
# Apply migrations to the configured database. A failing migration is reported
# loudly but does not abort the bootstrap, so the app still starts and the
# error can be investigated from the log and a terminal.
cd "$(dirname "$0")/.." || exit 1
. scripts/dev-env.sh
if ! python3 -m alembic upgrade head; then
  echo "bootstrap: alembic upgrade FAILED. Fix the problem and rerun: python3 -m alembic upgrade head" >&2
fi
exit 0
