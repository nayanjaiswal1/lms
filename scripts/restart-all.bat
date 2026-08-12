@echo off
cd /d "%~dp0.."
echo Rebuilding UI and force-restarting all MindForge dev services...
docker compose -f docker-compose.dev.yml up -d --build --force-recreate
echo.
echo Done. Frontend: http://localhost  (via Caddy)
pause
