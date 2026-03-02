# Tunelo test environment startup script (Docker)

$keyPath = "$env:USERPROFILE\.ssh\id_tunelo_test"

# --- Check Docker ---
if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Host "[ERROR] Docker not found. Install Docker Desktop first." -ForegroundColor Red
  exit 1
}

# --- Generate SSH key if missing ---
if (!(Test-Path $keyPath)) {
  Write-Host "SSH key not found. Generating..." -ForegroundColor Cyan
  ssh-keygen -t ed25519 -f $keyPath -N '""'
  Write-Host "Key generated: $keyPath" -ForegroundColor Green
}

# --- Start container ---
Write-Host ""
Write-Host "[1/3] Starting SSH container..." -ForegroundColor Cyan
$env:SSH_PUBLIC_KEY = (Get-Content "$keyPath.pub")
docker compose -f docker-compose.test.yml up -d

# --- Wait for SSH to be ready ---
Write-Host "[2/3] Waiting for SSH server to be ready..." -ForegroundColor Cyan
$ready = $false
for ($i = 0; $i -lt 15; $i++) {
  Start-Sleep -Seconds 1
  $check = ssh `
    -i $keyPath `
    -o BatchMode=yes `
    -o ConnectTimeout=2 `
    -o StrictHostKeyChecking=accept-new `
    -p 2222 `
    "testuser@localhost" echo "OK" 2>$null
  if ($check -eq "OK") {
    $ready = $true
    break
  }
}

if (!$ready) {
  Write-Host ""
  Write-Host "[ERROR] SSH connection failed after 15s" -ForegroundColor Red
  Write-Host "Check container logs:" -ForegroundColor Yellow
  Write-Host "  docker compose -f docker-compose.test.yml logs"
  Write-Host ""
  exit 1
}

# --- Success ---
Write-Host "[3/3] Connection verified!" -ForegroundColor Green
Write-Host ""
Write-Host "--------------------------------------" -ForegroundColor DarkCyan
Write-Host "  Tunelo tunnel config" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor DarkCyan
Write-Host "  Host          : localhost"
Write-Host "  Port          : 2222"
Write-Host "  Username      : testuser"
Write-Host "  Identity File : $keyPath"
Write-Host "  Local Port    : 18080"
Write-Host "  Remote Host   : localhost"
Write-Host "  Remote Port   : 8080"
Write-Host "--------------------------------------" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "To stop: .\scripts\test-down-docker.ps1" -ForegroundColor DarkGray
Write-Host ""
