# ============================================================================
# scripts/start-dev.ps1 - Start the MindForge dev stack on Windows
# Usage: from the mindforge/ directory: .\scripts\start-dev.ps1
# ============================================================================

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

function Info    { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Success { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Warn    { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Err     { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

# --- 1. Check Docker is running --------------------------------------------
Info "Checking Docker..."
try { docker info 2>$null | Out-Null; Success "Docker is running." }
catch {
    $dockerExe = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (-not (Test-Path $dockerExe)) { Err "Docker is not running and Docker Desktop.exe was not found at '$dockerExe'." }

    Info "Docker is not running. Starting Docker Desktop..."
    Start-Process $dockerExe

    $attempts = 0
    while ($attempts -lt 60) {
        try { docker info 2>$null | Out-Null; Success "Docker is running."; break }
        catch {}
        $attempts++
        Start-Sleep -Seconds 2
        Write-Host -NoNewline "."
    }
    Write-Host ""
    if ($attempts -ge 60) { Err "Docker Desktop did not start within 2 minutes." }
}

# --- 2. Start infra containers ----------------------------------------------
Info "Starting Docker services (Postgres, Redis, MinIO, backend)..."
Set-Location $Root
docker compose -f docker-compose.dev.yml up -d
Success "Docker services started."

# --- 3. Wait for backend health ---------------------------------------------
Info "Waiting for backend on :8080..."
$attempts = 0
while ($attempts -lt 30) {
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:8080/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        if ($r.StatusCode -eq 200) { Success "Backend is up."; break }
    } catch {}
    $attempts++
    Start-Sleep -Seconds 2
    Write-Host -NoNewline "."
}
if ($attempts -ge 30) { Warn "Backend health check timed out - check: docker compose logs backend" }
Write-Host ""

# --- 4. Start frontend in a new terminal window ------------------------------
Info "Starting Next.js frontend..."
$frontendDir = Join-Path $Root "frontend"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$frontendDir'; npm run dev" -WindowStyle Normal
Success "Frontend launching in new window -> http://localhost:3000"

# --- 5. Summary ----------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  MindForge dev stack is running!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Frontend   -> http://localhost:3000"
Write-Host "  Backend    -> http://localhost:8080"
Write-Host "  Labproxy   -> http://localhost:8081"
Write-Host "  Adminer    -> http://localhost:8082  (server: postgres)"
Write-Host "  MinIO      -> http://localhost:9001"
Write-Host ""
Write-Host "  Dev login (password: Admin123!):"
Write-Host "    jaiswal2062@gmail.com  (all roles)"
Write-Host "    admin@mindforge.dev    (super_admin)"
Write-Host ""
Write-Host "  To stop:  docker compose -f docker-compose.dev.yml down"
Write-Host ""
