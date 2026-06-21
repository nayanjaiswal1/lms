# Phase 0 — Infrastructure Bootstrap

## What Phase 0 Is

Phase 0 is infrastructure only. No feature code, no API handlers, no frontend pages. The goal is a single command (`make dev`) that brings up a fully operational local development environment with a seeded database.

When Phase 0 is complete, Phase 1 (auth) can begin immediately without any infrastructure ceremony.

---

## What Gets Set Up and Why

| Component | Why |
|---|---|
| **PostgreSQL 16** | Primary data store. Pinned to 16 for JSONB, logical replication, and `gen_random_uuid()` built-in. |
| **Redis 7** | Shared cache for rate-limit counters, JTI blocklist, and `session_version` lookups (see Redis rationale below). |
| **Adminer** | Lightweight DB UI at `:8080` — inspect tables, run ad-hoc queries, no local psql client required. |
| **Migration system** | `schema_migrations` table tracks applied files. `scripts/db-migrate.sh` is idempotent — safe to run repeatedly. |
| **Dev seed** | Five seeded users (super_admin, org_admin, instructor, mentor, student) so every role can be tested from day 1 with password `Admin123!`. |
| **Caddyfile** | Production reverse-proxy config ready to deploy. Caddy handles TLS automatically via ACME. |
| **Dockerfiles** | Multi-stage builds for both backend (scratch) and frontend (standalone Next.js output) keep prod images minimal. |
| **Makefile** | Consistent developer interface — same commands work on every machine regardless of shell or PATH differences. |

---

## Redis Rationale

Redis serves three distinct functions that share one Redis instance:

### 1. Multi-instance Rate Limiting
In-process rate limiters break when the backend scales horizontally — instance A and instance B each track their own counters, so an attacker can double the allowed attempts by splitting requests across instances. Redis provides a single counter that all instances share.

Keys: `rl:{endpoint}:{ip}:{email}` with TTL matching the window (e.g. 15 min for login).

### 2. Shared JTI Blocklist Cache
When a user logs out, the JWT's `jti` is blocklisted. Every subsequent request must check this blocklist. Hitting Postgres on every authenticated request for a blocklist lookup is expensive at scale. Redis holds blocklisted JTIs with TTL = remaining token lifetime. If Redis is unavailable, the middleware falls back to Postgres.

Keys: `jti:{jti}` with value `1` and TTL = seconds until token expiry.

### 3. Session Version Cache
`session_version` in the `users` table increments whenever all sessions are force-invalidated (e.g., password change, "logout all devices"). Every authenticated request must verify that the token's embedded `session_version` matches the DB value. Redis caches this with a 30-second TTL to avoid a DB read on every request.

Keys: `sv:{user_id}` with value = current session_version and TTL = 30s.

---

## Dev Quickstart

```bash
# 1. Clone and configure
git clone <repo-url> mindforge && cd mindforge
cp .env.example .env          # then fill in secrets

# 2. Start everything
make dev-up

# 3. Run migrations and seed
make migrate && make seed
```

After these three commands:
- PostgreSQL is running at `localhost:5432`
- Redis is running at `localhost:6379`
- Adminer is running at `http://localhost:8080`
- All tables are created and five dev users are seeded

Start the backend (Phase 1): `make backend`
Start the frontend (Phase 1): `make frontend`

---

## Done Criteria

- [ ] `make dev-up` starts all containers without errors
- [ ] `make migrate` applies `001_schema.sql` and creates `schema_migrations` table
- [ ] `make migrate` is idempotent — running it twice produces no errors
- [ ] `make seed` inserts five dev users; re-running is safe (ON CONFLICT DO NOTHING)
- [ ] All five dev user roles present in `org_members` for the default org
- [ ] `make dev-down` stops all containers cleanly
- [ ] `make dev-reset` drops volumes, restarts, migrates, seeds — clean slate
- [ ] `make psql` opens a working psql shell
- [ ] `make redis-cli` opens a working redis-cli shell
- [ ] Adminer accessible at `http://localhost:8080` and can connect to the dev database
- [ ] `backend/Dockerfile` builds successfully with `docker build backend/`
- [ ] `frontend/Dockerfile` builds successfully with `docker build frontend/`
- [ ] `.env.example` contains every variable referenced by the backend and frontend
- [ ] `.gitignore` prevents `.env`, build artifacts, and IDE files from being committed
