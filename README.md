# MindForge

Multi-tenant learning platform. LeetCode + KodeKloud + Udemy + Notion, self-hosted, no vendor lock.

**Stack:** Go 1.26.4 + Chi v5 + pgx/v5 · Next.js 16.2.9 + React 19 + Tailwind v4 · PostgreSQL 16 · Redis 7 · Docker Compose

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Docker + Docker Compose | Latest stable | [docs.docker.com](https://docs.docker.com/get-docker/) |
| Go | 1.26.4+ | [go.dev/dl](https://go.dev/dl/) |
| Node.js | 20+ | [nodejs.org](https://nodejs.org/) |
| pnpm | 9+ | `npm install -g pnpm` |

---

## Quick Start

```bash
# 1. Clone the repository
git clone <repo-url> mindforge && cd mindforge

# 2. Copy the example env file and fill in secrets
cp .env.example .env

# 3. Start dev environment, run migrations, and seed
make dev-reset
```

That's it. All containers start, the database is created with schema applied, and five dev users are seeded.

**Dev URLs:**
| Service | URL |
|---|---|
| Frontend | http://localhost:3000 |
| Backend API | http://localhost:8080 |
| Adminer (DB UI) | http://localhost:8081 |
| PostgreSQL | localhost:5432 |
| Redis | localhost:6379 |

**Dev login credentials (password: `Admin123!`):**
| Email | Role |
|---|---|
| admin@mindforge.dev | super_admin (platform) |
| orgadmin@mindforge.dev | org admin |
| instructor@mindforge.dev | instructor |
| mentor@mindforge.dev | mentor |
| student@mindforge.dev | student |

---

## Common Make Targets

Run `make <target>` from the project root.

### Development

| Target | What it does |
|---|---|
| `make dev` | Start all dev containers in the foreground (Ctrl+C to stop) |
| `make dev-up` | Start all dev containers in the background |
| `make dev-down` | Stop and remove dev containers (data volumes preserved) |
| `make dev-reset` | Full reset: stop → delete volumes → start → migrate → seed |
| `make logs` | Tail logs from all running dev containers |
| `make psql` | Open psql shell inside the Postgres container |
| `make redis-cli` | Open redis-cli shell inside the Redis container |

### Database

| Target | What it does |
|---|---|
| `make migrate` | Apply all pending migrations in order |
| `make migrate-create name=add_courses` | Create a new migration file pair (up + down) |
| `make seed` | Load dev fixtures (idempotent) |

### Running Services

| Target | What it does |
|---|---|
| `make backend` | Run the Go server with `.env` loaded (`go run ./cmd/server`) |
| `make frontend` | Run the Next.js dev server (`pnpm dev` in `frontend/`) |

### Testing & Linting

| Target | What it does |
|---|---|
| `make test-backend` | Run all Go tests (`go test ./...`) |
| `make lint-frontend` | Run `pnpm lint:strict` in `frontend/` (zero-warning enforcement) |

### Building

| Target | What it does |
|---|---|
| `make build-backend` | Compile the Go binary to `backend/bin/server` |
| `make build-frontend` | Build the Next.js app for production (`pnpm build`) |
| `make docker-build` | Build production Docker images for backend and frontend |

---

## Project Structure

```
mindforge/
├── backend/                    Go API server
│   ├── cmd/
│   │   └── server/            main.go — entry point
│   ├── internal/
│   │   ├── config/            env var parsing and validation
│   │   ├── db/                pgxpool setup
│   │   ├── auth/              JWT, middleware, OAuth, password, tokens
│   │   ├── orgs/              org management handlers
│   │   └── shared/            response helpers, validation utilities
│   ├── db/
│   │   ├── migrations/        *.sql migration files (numbered, ordered)
│   │   └── fixtures/          dev_seed.sql — dev-only test data
│   ├── Dockerfile             Multi-stage production build
│   ├── go.mod
│   ├── go.sum
│   └── .env.example           Backend-only env var reference
│
├── frontend/                  Next.js 16 app
│   ├── app/                   App Router pages and layouts
│   ├── components/            Shared UI components
│   ├── lib/                   Utilities, auth, API client
│   ├── Dockerfile             Multi-stage standalone build
│   └── .env.example           Frontend env var reference
│
├── scripts/
│   ├── dev-setup.sh           One-shot dev environment setup
│   ├── db-migrate.sh          Apply pending migrations
│   ├── db-seed.sh             Load dev fixtures
│   ├── db-reset.sh            Drop and recreate the database
│   └── db-create-migration.sh Create a new migration file pair
│
├── docker-compose.dev.yml     Dev services: postgres, redis, adminer
├── docker-compose.prod.yml    Prod services: postgres, redis, backend, frontend, caddy
├── Caddyfile                  Reverse proxy config (prod)
├── Makefile                   Developer interface
├── .env.example               Complete env var reference (all services)
├── .env.prod.example          Production env var reference
└── .gitignore
```

---

## How to Add a New Migration

Migrations are plain SQL files in `backend/db/migrations/`, numbered sequentially.

```bash
# Create a new migration pair (up + down)
make migrate-create name=add_courses

# This creates:
#   backend/db/migrations/002_add_courses.sql
#   backend/db/migrations/002_add_courses.down.sql

# Edit both files, then apply:
make migrate
```

Rules:
- Never edit a migration that has already been applied to any environment
- Every `up` migration must have a corresponding `down` migration
- Migrations run in alphabetical order by filename — the numeric prefix enforces order
- The `schema_migrations` table tracks which files have been applied

---

## How to Reset the Dev Database

```bash
# Full reset: drops the database, recreates it, runs migrations, loads seed data
make dev-reset

# Or just reset the schema (keeps the container running):
bash scripts/db-reset.sh
```

---

## Environment Variables

Copy `.env.example` to `.env` for local development.

### Database

| Variable | Required | Default | Description |
|---|---|---|---|
| `POSTGRES_USER` | Yes | — | PostgreSQL superuser name |
| `POSTGRES_PASSWORD` | Yes | — | PostgreSQL superuser password |
| `POSTGRES_DB` | Yes | — | Database name |
| `DATABASE_URL` | Yes | — | Full DSN: `postgres://user:pass@host:5432/db` |

### Redis

| Variable | Required | Default | Description |
|---|---|---|---|
| `REDIS_URL` | Yes | — | Redis connection URL: `redis://localhost:6379/0` |

### JWT / Session

| Variable | Required | Default | Description |
|---|---|---|---|
| `JWT_SECRET` | Yes | — | Min 32 bytes random. Signs access tokens. |
| `COOKIE_SECRET` | Yes | — | Min 32 bytes random. Signs state cookies. |
| `ENCRYPTION_KEY` | Yes | — | Exactly 32 bytes. AES-256-GCM for sensitive fields. |
| `ACCESS_TOKEN_TTL` | No | `15m` | Access token lifetime. |
| `REFRESH_TOKEN_TTL` | No | `720h` | Refresh token lifetime (30 days). |
| `PASSWORD_RESET_TTL` | No | `30m` | Password reset link lifetime. |
| `EMAIL_VERIFICATION_TTL` | No | `24h` | Email verification link lifetime. |

### Tenant

| Variable | Required | Default | Description |
|---|---|---|---|
| `DEFAULT_ORG_ID` | Yes | `00000000-0000-0000-0000-000000000001` | UUID of the default org for self-registrations. |

### OAuth

| Variable | Required | Default | Description |
|---|---|---|---|
| `GOOGLE_CLIENT_ID` | No | — | Google OAuth app client ID. |
| `GOOGLE_CLIENT_SECRET` | No | — | Google OAuth app client secret. |
| `GITHUB_CLIENT_ID` | No | — | GitHub OAuth app client ID. |
| `GITHUB_CLIENT_SECRET` | No | — | GitHub OAuth app client secret. |
| `FRONTEND_URL` | Yes | `http://localhost:3000` | Redirect target after OAuth callback. |

### Email (SMTP)

| Variable | Required | Default | Description |
|---|---|---|---|
| `SMTP_HOST` | Yes | — | SMTP server hostname. |
| `SMTP_PORT` | No | `587` | SMTP server port. |
| `SMTP_USER` | Yes | — | SMTP authentication username. |
| `SMTP_PASS` | Yes | — | SMTP authentication password. |
| `EMAIL_FROM` | No | `noreply@mindforge.dev` | Sender address for all outbound email. |

### Server

| Variable | Required | Default | Description |
|---|---|---|---|
| `PORT` | No | `8080` | Port the Go server listens on. |
| `ENV` | No | `development` | `production` enables Secure cookies and stricter logging. |

### Frontend

| Variable | Required | Default | Description |
|---|---|---|---|
| `NEXT_PUBLIC_API_URL` | Yes | `http://localhost:8080` | Backend API base URL (exposed to browser). |
| `NEXT_PUBLIC_APP_URL` | Yes | `http://localhost:3000` | Frontend public URL (used for OG/canonical URLs). |
| `BACKEND_URL` | No | `http://localhost:8080` | Server-to-server backend URL (not exposed to browser). |

### Optional

| Variable | Required | Default | Description |
|---|---|---|---|
| `MAXMIND_DB_PATH` | No | — | Path to GeoLite2-City.mmdb. Enables impossible-travel detection on login. |

---

## Ports Used in Dev

| Port | Service |
|---|---|
| 3000 | Next.js frontend |
| 8080 | Go backend API |
| 8081 | Adminer (DB UI) |
| 5432 | PostgreSQL |
| 6379 | Redis |
