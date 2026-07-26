.PHONY: dev dev-up dev-down dev-reset migrate migrate-create seed seed-courses backend frontend \
        test-backend lint-frontend build-backend build-frontend docker-build logs psql redis-cli \
        prod-deploy prod-down prod-logs flowmap-drift \
        prod-update prod-backup prod-backup-full prod-restore

# ─── Dev containers ──────────────────────────────────────────────────────────

dev:
	@docker compose -f docker-compose.dev.yml up

dev-up:
	@docker compose -f docker-compose.dev.yml up -d

dev-down:
	@docker compose -f docker-compose.dev.yml down

dev-reset: dev-down
	@docker compose -f docker-compose.dev.yml down -v
	@docker compose -f docker-compose.dev.yml up -d
	@echo "Waiting for Postgres to be ready..."
	@until docker exec mindforge_postgres_dev pg_isready -U $$(grep '^POSTGRES_USER=' .env | cut -d= -f2) > /dev/null 2>&1; do sleep 1; done
	@bash scripts/db-migrate.sh
	@bash scripts/db-seed.sh
	@bash scripts/db-seed-courses.sh

# ─── Database ────────────────────────────────────────────────────────────────

migrate:
	@bash scripts/db-migrate.sh

migrate-create:
	@bash scripts/db-create-migration.sh "$(name)"

seed:
	@bash scripts/db-seed.sh

# ─── Run services ────────────────────────────────────────────────────────────

backend:
	@cd backend && go run ./cmd/server

frontend:
	@cd frontend && pnpm dev

# ─── Testing & linting ───────────────────────────────────────────────────────

test-backend:
	@cd backend && go test ./...

lint-frontend:
	@cd frontend && pnpm lint:strict

# ─── Build ───────────────────────────────────────────────────────────────────

build-backend:
	@mkdir -p backend/bin
	@cd backend && go build -o bin/server ./cmd/server

build-frontend:
	@cd frontend && pnpm build

docker-build:
	@docker build -t mindforge-backend:latest ./backend
	@docker build -t mindforge-frontend:latest ./frontend

# ─── Utilities ───────────────────────────────────────────────────────────────

logs:
	@docker compose -f docker-compose.dev.yml logs -f

psql:
	@docker exec -it mindforge_postgres_dev psql \
		-U $$(grep '^POSTGRES_USER=' .env | cut -d= -f2) \
		-d $$(grep '^POSTGRES_DB=' .env | cut -d= -f2)

redis-cli:
	@docker exec -it mindforge_redis_dev redis-cli

# ─── Docs ────────────────────────────────────────────────────────────────────

flowmap-drift:
	@python3 scripts/check-flowmap-drift.py

# ─── Production ──────────────────────────────────────────────────────────────

prod-deploy:
	@bash scripts/deploy-prod.sh

prod-down:
	@docker compose --env-file .env.prod -f docker-compose.prod.yml down

prod-logs:
	@docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f

prod-update:
	@bash scripts/update-prod.sh

prod-backup:
	@bash scripts/backup-prod.sh incremental

prod-backup-full:
	@bash scripts/backup-prod.sh full

prod-restore:
	@bash scripts/restore-prod.sh "$(ts)"
