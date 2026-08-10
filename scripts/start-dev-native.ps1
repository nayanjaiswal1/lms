# Brings MindForge dev up after a reboot/shutdown: infra stays in the WSL k3s
# cluster (port-forwarded), frontend + backend run natively on Windows for
# hot reload. See docs/local-k3s-dev.md for the cluster itself; this script
# only handles "how do I get back to a working dev environment".
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts\start-dev-native.ps1

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

Write-Host "-- Stopping any leftover processes from a previous run --" -ForegroundColor Cyan
Get-Process -Name server, air -ErrorAction SilentlyContinue | Stop-Process -Force
wsl -e bash -c "pkill -f 'kubectl port-forward' 2>/dev/null; true"

Write-Host "-- Port-forwarding k3s infra (postgres, redis, minio, labproxy, piston) --" -ForegroundColor Cyan
# Each forward runs as its own hidden Windows process (wsl.exe kept alive in the
# foreground of that process), not backgrounded+disowned inside a single
# one-shot `wsl -e bash -c` call. The nohup/disown pattern is unreliable on
# WSL2: when the invoking wsl.exe returns to Windows, its interop pty session
# tears down and can kill still-attached children before they even open their
# log file (nohup/disown only block the shell's own SIGHUP, not that teardown)
# — silently producing zero running processes and zero log output.
$forwards = @(
    @{ Name = "postgres"; Namespace = "mindforge";      Svc = "svc/postgres"; Ports = "5432:5432" },
    @{ Name = "redis";    Namespace = "mindforge";      Svc = "svc/redis";    Ports = "6379:6379" },
    @{ Name = "minio";    Namespace = "mindforge";      Svc = "svc/minio";    Ports = "9000:9000" },
    @{ Name = "labproxy"; Namespace = "mindforge";      Svc = "svc/labproxy"; Ports = "18081:8081" },
    @{ Name = "piston";   Namespace = "mindforge-labs";  Svc = "svc/piston";   Ports = "2000:2000" }
)
foreach ($f in $forwards) {
    $cmd = "kubectl port-forward -n $($f.Namespace) $($f.Svc) $($f.Ports)"
    # Windows PowerShell 5.1's Start-Process -ArgumentList just joins array
    # elements with spaces into one raw command line — it does NOT quote
    # elements containing spaces. Passing $cmd as a separate array element
    # silently split it back into bare words on wsl.exe's argv, so `bash -c`
    # only ever received "kubectl" as its script (the rest became ignored
    # positional params) and kubectl printed its usage help instead of
    # forwarding anything. Quoting it ourselves keeps it one token.
    Start-Process wsl -ArgumentList "-e bash -c `"$cmd`"" -WindowStyle Hidden
}
Start-Sleep -Seconds 3

foreach ($p in 5432, 6379, 9000, 18081, 2000) {
    $ok = (Test-NetConnection -ComputerName 127.0.0.1 -Port $p -WarningAction SilentlyContinue).TcpTestSucceeded
    if (-not $ok) { Write-Warning "Port $p is not reachable yet - check wsl: kubectl get pods -n mindforge" }
}

Write-Host "-- Starting backend (air hot-reload) in a new window --" -ForegroundColor Cyan
$airPath = Join-Path (go env GOPATH) "bin\air.exe"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$repoRoot\backend'; & '$airPath'" -WindowStyle Normal

Write-Host "-- Starting frontend (pnpm dev) in a new window --" -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$repoRoot\frontend'; pnpm dev" -WindowStyle Normal

Write-Host ""
Write-Host "Backend:  http://localhost:8080/health" -ForegroundColor Green
Write-Host "Frontend: http://localhost:3000" -ForegroundColor Green
Write-Host "(each opened its own window - close it, or Ctrl+C inside it, to stop that piece)"
