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
│   ├── internal/               37 domain packages, one per feature area:
│   │   ├── ai/                 LLMProvider interface — Anthropic, Gemini, NoOp
│   │   ├── api/                router wiring
│   │   ├── assessment/         tests, attempts, batches, invitations
│   │   ├── auth/                JWT, middleware, OAuth, password, tokens
│   │   ├── authz/               RBAC engine
│   │   ├── calendar/            calendar sync, entity schedules
│   │   ├── config/               env var parsing and validation
│   │   ├── contentpipeline/     course/lesson ingestion
│   │   ├── courses/              course tree, enrollment, progress
│   │   ├── db/                   pgxpool setup, migrations, fixtures
│   │   ├── experience/           feedback/experience reports
│   │   ├── features/             feature flags, entitlements
│   │   ├── feedback/             rating/feedback capture
│   │   ├── highlights/           text highlights + AI explanations
│   │   ├── httputil/             response helpers, validation utilities
│   │   ├── interviewprep/        AI interview practice sessions
│   │   ├── jobs/                 background job queue + handlers
│   │   ├── labs/                 sandboxed terminal/code/guided labs
│   │   ├── llm/                  shared LLM plumbing
│   │   ├── mentoring/            mentor tickets, reports, chat
│   │   ├── messaging/            batch messages, reactions, FAQs
│   │   ├── middleware/           shared HTTP middleware
│   │   ├── onboarding/           user onboarding flow
│   │   ├── orgs/                 org management handlers
│   │   ├── payments/             billing/subscription
│   │   ├── practice/             coding challenges, quizzes, SRS
│   │   ├── profile/               user profile
│   │   ├── revisionplan/          spaced-repetition revision plans
│   │   ├── rewards/               XP, achievements
│   │   ├── roadmap/               AI-generated personalized roadmaps
│   │   ├── session/               session management
│   │   ├── sheets/                sheet tracker (Blind 75, NeetCode, etc.)
│   │   ├── srs/                   spaced-repetition cards
│   │   ├── storage/               MinIO presigned URL client
│   │   ├── systemdesign/          system design canvas
│   │   ├── whatnow/               task suggestions
│   │   └── wiki/                  wiki spaces, pages, versioning
│   ├── db/
│   │   ├── migrations/        001_baseline.sql (+ .down.sql) — squashed history; new work adds 002_*, 003_*, ...
│   │   └── fixtures/          dev_seed.sql — dev-only test data
│   ├── Dockerfile             Multi-stage production build
│   ├── go.mod
│   ├── go.sum
│   └── .env.example           Backend-only env var reference
│
├── frontend/                  Next.js 16 app
│   ├── app/                   App Router pages and layouts — (app), (public), auth, org, platform, onboarding
│   ├── components/            Shared UI components
│   ├── lib/                   Utilities, auth, API client
│   ├── Dockerfile             Multi-stage standalone build
│   └── .env.example           Frontend env var reference
│
├── k8s/                       Kustomize manifests (base/ + overlays/prod/) — see Kubernetes Deployment below
│
├── scripts/
│   ├── dev-setup.sh           One-shot dev environment setup
│   ├── start-dev.ps1          One-click Windows dev launcher (Docker services + frontend)
│   ├── deploy-prod.sh         Build and (re)start the production stack
│   ├── deploy-k8s.sh          Apply k8s manifests, wait for rollout
│   ├── build-push-k8s-images.sh Build, push, pin image tags for k8s
│   ├── db-migrate.sh          Apply pending migrations
│   ├── db-seed.sh             Load dev fixtures
│   ├── db-reset.sh            Drop and recreate the database
│   └── db-create-migration.sh Create a new migration file pair
│
├── docker-compose.dev.yml     Dev services: postgres, redis, minio, piston, backend, labproxy, adminer
├── docker-compose.prod.yml    Prod services: postgres, redis, minio, piston, backend, labproxy, frontend, caddy
├── Caddyfile                  Reverse proxy config (prod) — routes /api, /lab-ws, object storage, and the frontend
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
| 8081 | labproxy (terminal lab WebSocket relay) |
| 8082 | Adminer (DB UI) |
| 5432 | PostgreSQL |
| 6379 | Redis |
| 9000 | MinIO (S3 API) |
| 9001 | MinIO Console |
| 2000 | Piston (code execution) |

---

## Production Deployment

`docker-compose.prod.yml` + `Caddyfile` run the full stack (postgres, redis, minio, piston, backend, labproxy, frontend) on a single server behind Caddy, which handles automatic HTTPS via Let's Encrypt. Only ports 80/443 are exposed publicly — everything else stays on the internal Docker network.

**Prerequisites:**
- A server with Docker + the Compose v2 plugin installed
- A domain with DNS `A`/`AAAA` records pointing at the server (required for Caddy to obtain a TLS certificate)

**Steps:**
```bash
git clone <this repo> && cd mindforge
cp .env.prod.example .env.prod
# Edit .env.prod — fill in every value (DOMAIN, all secrets, SMTP, OAuth, etc.)

make prod-deploy          # builds images, creates the mindforge-labs network, starts the stack
```

`scripts/deploy-prod.sh` (what `make prod-deploy` runs) refuses to start if `.env.prod` still has placeholder values, creates the external `mindforge-labs` Docker network the lab sandbox containers join, builds all images, and waits for the backend health check before reporting the stack ready.

**Day-to-day:**
```bash
make prod-logs             # tail logs from every service
make prod-down             # stop the stack
bash scripts/deploy-prod.sh   # redeploy after a `git pull` (rebuilds changed images)
```

**Notes:**
- `NEXT_PUBLIC_*` frontend vars are baked in at build time — changing them requires `make prod-deploy` again, not just a restart.
- Piston (code execution sandbox) runs `privileged: true` — required for it to sandbox untrusted user code. Only expose this stack on infrastructure you control.
- Postgres and Redis data live in named Docker volumes (`mindforge_pg_prod`, etc.) — back these up outside of Docker before any destructive `docker compose down -v`.

---

## Kubernetes Deployment

`k8s/` (Kustomize: `base/` + `overlays/prod/`) deploys the same stack to a cluster instead of a single VPS. The one real architectural difference: lab sandboxes run as native Kubernetes Pods (`backend/internal/labs/runtime_kubernetes.go`, via the in-cluster API) instead of `docker run` against a mounted host socket — that pattern doesn't work on managed clusters (containerd, not dockerd; mounting the host socket is a real security hole). Toggle which sandbox runtime the backend uses with `LABS_RUNTIME=docker|kubernetes` (default `docker`) — no other code changes needed either way.

**Prerequisites:**
- A cluster with `ingress-nginx` and `cert-manager` (plus a `ClusterIssuer` named `letsencrypt-prod`) already installed — these manifests don't install cluster-wide addons, same relationship the VPS deploy has to Docker itself
- A container registry your cluster's nodes can pull from (ghcr.io, Docker Hub, a private registry)
- A domain with DNS pointing at your ingress controller's external IP
- `kubectl` and the standalone `kustomize` CLI (`kubectl`'s built-in kustomize can render but can't run `kustomize edit`)
- Run `docker network create mindforge-labs`-equivalent step is not needed here — `k8s/base/namespace.yaml` creates the `mindforge-labs` namespace instead

**Steps:**
```bash
git clone <this repo> && cd mindforge
cp k8s/overlays/prod/secrets.env.example k8s/overlays/prod/secrets.env
# Edit secrets.env — fill in every value
# Edit k8s/overlays/prod/configmap-domain.patch.yaml and ingress-domain.patch.yaml —
# replace every "app.yourdomain.com" with your real domain

REGISTRY=ghcr.io/youruser bash scripts/build-push-k8s-images.sh   # build, push, pin image tags
bash scripts/deploy-k8s.sh                                        # apply manifests, wait for rollout
```

**Day-to-day:**
```bash
kubectl logs -n mindforge -l app=backend -f
kubectl get pods -n mindforge          # app tier
kubectl get pods -n mindforge-labs     # piston + live lab sessions
bash scripts/deploy-k8s.sh             # redeploy after re-running build-push-k8s-images.sh
```

**Known limitations, called out rather than papered over:**
- **Root `setup_script`s**: Docker's `docker exec --user root` can run as a different user than the container's own default; Kubernetes Pod exec cannot — it always runs as whatever user the image's `USER` directive sets. Under `LABS_RUNTIME=kubernetes`, a lab's `setup_script` runs as the image's own default user, not root. `lab-images/lab-k8s` already self-provisions everything as `labuser` at container boot and is unaffected; any future lab image whose `setup_script` assumes root needs that logic moved into the image's own entrypoint instead.
- **Pause/Unpause**: no code path currently transitions a lab session to `paused`, so this is dead code today under both runtimes. The Kubernetes runtime implements `Unpause` as a no-op (Pods have no pause primitive) — same effective behavior as Docker's unexercised path.
- **Piston needs a privileged Pod** (`k8s/base/piston.yaml`) — some managed clusters (GKE Autopilot, hardened EKS/AKS node groups) forbid privileged Pods outright regardless of namespace labels. If `piston` can't schedule, remove it from `k8s/base/kustomization.yaml` and point `PISTON_URL` (in `configmap-domain.patch.yaml`) at an external Piston instance — no backend code change needed.
- **Stateful services run in-cluster** (Postgres/Redis/MinIO as StatefulSets) — self-contained and mirrors the Compose setup, but for a cluster you actually depend on, managed equivalents (RDS/CloudSQL, managed Redis, S3) are the standard recommendation. Swapping is a pure config change (`DATABASE_URL`/`REDIS_URL`/`MINIO_*` in `secrets.env`/the ConfigMap) — no manifest restructuring required.
- **Lab pod egress is not restricted** beyond what the base manifests already isolate (see `k8s/base/networkpolicy-labs.yaml`'s own comment) — doing that safely needs this cluster's actual Pod/Service CIDR, which varies by cloud/CNI and isn't something these generic manifests can guess without either doing nothing or breaking lab content that expects outbound internet access.
