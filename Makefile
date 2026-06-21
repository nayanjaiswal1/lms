.PHONY: dev dev-up dev-down dev-reset migrate migrate-create seed backend frontend \
        test-backend lint-frontend build-backend build-frontend docker-build logs psql redis-cli

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
