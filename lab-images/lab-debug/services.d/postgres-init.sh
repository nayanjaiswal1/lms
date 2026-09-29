#!/bin/bash
# One-shot cluster bootstrap that then idles (the supervisor restarts services
# that exit): waits for PostgreSQL, enables pg_stat_statements in template1 so
# EVERY database created later (dev DB, grader DBs) has it, and creates the
# scenario's dev database "app".
set -euo pipefail

export PGHOST=127.0.0.1 PGPORT=5432 PGUSER=labuser

until pg_isready -q; do
  sleep 0.3
done

psql -v ON_ERROR_STOP=1 -q -d template1 -c 'CREATE EXTENSION IF NOT EXISTS pg_stat_statements'
if ! psql -tAq -d template1 -c "SELECT 1 FROM pg_database WHERE datname='app'" | grep -q 1; then
  createdb app
fi

exec sleep infinity
