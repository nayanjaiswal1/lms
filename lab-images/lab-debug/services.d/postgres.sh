#!/bin/bash
# PostgreSQL 16 as labuser (no postgres system user, no root needed):
# fsync=off, small shared_buffers, pg_stat_statements loaded so graders can
# count queries (docs/debug-labs.md §2/§4).
set -euo pipefail

PGBIN=/usr/lib/postgresql/16/bin
PGDATA=/var/lib/mindforge-pg
SOCKDIR=/tmp/pg

mkdir -p "$SOCKDIR"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  "$PGBIN/initdb" -D "$PGDATA" -U labuser --auth=trust -E UTF8 --locale=C.UTF-8 --no-sync
  cat >>"$PGDATA/postgresql.conf" <<'CONF'
listen_addresses = '127.0.0.1'
port = 5432
unix_socket_directories = '/tmp/pg'
fsync = off
synchronous_commit = off
full_page_writes = off
shared_buffers = 32MB
max_connections = 100
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
CONF
fi

exec "$PGBIN/postgres" -D "$PGDATA"
