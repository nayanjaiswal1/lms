@echo off
cd /d "%~dp0.."

rem Postgres (Neon) and Redis (Upstash) are the same remote services every
rem dev entry point uses now - see root .env - so nothing to point at here.

echo Starting backend (remote Postgres + Redis - no local db/cache/piston/minio) + Caddy...
docker compose -f docker-compose.dev.yml up -d --no-deps backend
docker compose -f docker-compose.dev.yml up -d --no-deps caddy

echo.
echo Starting frontend dev server (hot reload, no rebuild) in a new window...
start "MindForge Frontend Dev" cmd /k "cd /d "%~dp0..\frontend" && pnpm dev"

echo.
echo Backend + MCP: http://localhost/api , http://localhost/mcp  (via Caddy)
echo Frontend UI:   http://localhost:3000  (hot reload)
echo.
echo (No local postgres/redis/piston/minio/labproxy/adminer containers started -
echo  use "MindForge Restart All" for the full stack.)
pause
