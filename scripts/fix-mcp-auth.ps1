# Fixes the recurring MindForge MCP connector breakage:
#   - a killed Claude Desktop sometimes leaves its child `mcp-remote` process
#     orphaned, still squatting the OAuth callback port with stale auth state
#   - mcp-remote's disk cache (~/.mcp-auth) can point at a client_id the
#     backend no longer knows about (e.g. after a DB reset/switch), which
#     makes every /oauth/authorize call 400 before the consent screen ever
#     shows up
# It also restarts the backend container first: its `air` hot-reloader can
# drop its file watch on Windows bind mounts (bulk "input/output error" on
# every path in its log), silently freezing the running binary while still
# answering health checks - a plain restart clears that.
# This kills any stray mcp-remote/Claude Desktop processes, wipes the mcp-remote
# auth cache so it re-registers clean, relaunches Claude Desktop, then prints
# the backend's own oauth/mcp log lines so you can see whether it worked.

$claudeDesktopExe = "C:\Program Files\WindowsApps\Claude_1.28929.0.0_x64__pzs8sxrjxfjjc\app\Claude.exe"
$backendContainer  = "mindforge_backend_dev"

Write-Host "== Restarting backend container ==" -ForegroundColor Cyan
docker restart $backendContainer | Out-Null
Write-Host "  waiting for it to come back healthy..."
$deadline = (Get-Date).AddSeconds(60)
do {
    Start-Sleep -Seconds 2
    $health = docker inspect -f '{{.State.Health.Status}}' $backendContainer 2>$null
} while ($health -ne "healthy" -and (Get-Date) -lt $deadline)
Write-Host "  backend status: $health"

Write-Host "== Killing stray mcp-remote processes ==" -ForegroundColor Cyan
Get-CimInstance Win32_Process -Filter "Name='node.exe' or Name='cmd.exe'" |
    Where-Object { $_.CommandLine -like "*mcp-remote*" } |
    ForEach-Object {
        Write-Host "  killing pid $($_.ProcessId): $($_.CommandLine)"
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }

Write-Host "== Killing Claude Desktop (leaving the Claude Code CLI alone) ==" -ForegroundColor Cyan
Get-Process -Name Claude -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "*WindowsApps*" } |
    ForEach-Object {
        Write-Host "  killing pid $($_.Id)"
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }

Write-Host "== Clearing mcp-remote auth cache ($env:USERPROFILE\.mcp-auth) ==" -ForegroundColor Cyan
Remove-Item -Recurse -Force "$env:USERPROFILE\.mcp-auth" -ErrorAction SilentlyContinue

Start-Sleep -Seconds 1

Write-Host "== Relaunching Claude Desktop ==" -ForegroundColor Cyan
if (Test-Path $claudeDesktopExe) {
    Start-Process $claudeDesktopExe
} else {
    Write-Host "  Couldn't find Claude Desktop at:`n  $claudeDesktopExe`n  (probably updated to a new version folder) - launch it manually from the Start Menu." -ForegroundColor Yellow
}

Write-Host "== Waiting for it to attempt the MCP connection... ==" -ForegroundColor Cyan
Start-Sleep -Seconds 10

Write-Host "== Recent backend /oauth and /mcp activity ==" -ForegroundColor Cyan
$logs = docker logs --since 30s $backendContainer 2>&1 | Select-String -Pattern "mcp|oauth"
if (-not $logs) {
    Write-Host "  No activity yet. Either Claude Desktop is still starting, or nothing has tried to" -ForegroundColor Yellow
    Write-Host "  call a mindforge tool yet - ask it something that needs one and re-run this script." -ForegroundColor Yellow
} else {
    $logs | ForEach-Object { Write-Host "  $_" }
    if ($logs -match "/oauth/authorize.*\s302\s") {
        Write-Host "`n  SUCCESS: /oauth/authorize redirected (302) - check your browser for the consent screen and approve it." -ForegroundColor Green
    } elseif ($logs -match "\s400\s") {
        Write-Host "`n  STILL FAILING (400) - the backend rejected the request. Check docker logs $backendContainer for the exact reason." -ForegroundColor Red
    }
}

Write-Host "`nDone." -ForegroundColor Cyan
Read-Host "Press Enter to close"
