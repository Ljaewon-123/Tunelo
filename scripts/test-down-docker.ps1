# Tunelo test environment teardown script (Docker)

Write-Host ""

# --- Stop and remove container ---
Write-Host "Stopping SSH container..." -ForegroundColor Cyan
docker compose -f docker-compose.test.yml down

# --- Kill any remaining SSH tunnel processes ---
$sshProcs = Get-Process -Name ssh -ErrorAction SilentlyContinue
if ($sshProcs) {
  Write-Host "Killing $($sshProcs.Count) SSH process(es)..." -ForegroundColor Yellow
  $sshProcs | Stop-Process -Force
}

# --- Check port 18080 ---
$port = netstat -ano | Select-String ":18080"
if ($port) {
  Write-Host "[WARNING] Port 18080 is still in use:" -ForegroundColor Yellow
  Write-Host $port
} else {
  Write-Host "Port 18080 released" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "[OK] Test environment cleaned up" -ForegroundColor Green
Write-Host ""
