# Tunelo test environment startup script (Docker)

$keyPath = "$env:USERPROFILE\.ssh\id_tunelo_test"
$sshConfigPath = "$env:USERPROFILE\.ssh\config"
$sshHost = "tunelo-test"
$projectRoot = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $projectRoot ".env.test"

# --- Check Docker ---
if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Host "[ERROR] Docker not found. Install Docker Desktop first." -ForegroundColor Red
  exit 1
}

# --- Generate SSH key if missing ---
if (!(Test-Path $keyPath)) {
  Write-Host "SSH key not found. Generating..." -ForegroundColor Cyan
  ssh-keygen -t ed25519 -f $keyPath -N ""
  Write-Host "Key generated: $keyPath" -ForegroundColor Green
}

# --- Write .env file for docker compose ---
$pubKey = (Get-Content "$keyPath.pub" -Raw).Trim()
[System.IO.File]::WriteAllText($envFile, "SSH_PUBLIC_KEY=$pubKey")

# --- Always overwrite SSH config entry (host key changes every restart) ---
# NUL = Windows null device (equivalent of /dev/null), prevents known_hosts caching
$configEntry = @"
Host $sshHost
  HostName localhost
  Port 2222
  User testuser
  IdentityFile $keyPath
  StrictHostKeyChecking no
  UserKnownHostsFile NUL
  LogLevel ERROR
  BatchMode yes
"@

if (!(Test-Path $sshConfigPath)) {
  New-Item -ItemType File -Path $sshConfigPath -Force | Out-Null
}

# Replace existing block or append
$configContent = Get-Content $sshConfigPath -Raw -ErrorAction SilentlyContinue
if ($configContent -match "(?ms)Host $sshHost\b.*?(?=\nHost |\z)") {
  $newContent = $configContent -replace "(?ms)Host $sshHost\b.*?(?=\nHost |\z)", $configEntry
  [System.IO.File]::WriteAllText($sshConfigPath, $newContent)
} else {
  Add-Content -Path $sshConfigPath -Value "`n$configEntry"
}
Write-Host "SSH config updated: $sshHost (UserKnownHostsFile=NUL)" -ForegroundColor Green

# --- Start container ---
Write-Host ""
Write-Host "[1/3] Starting SSH container..." -ForegroundColor Cyan
Push-Location $projectRoot
docker compose --env-file $envFile -f docker-compose.test.yml down --remove-orphans 2>&1 | Out-Null
docker compose --env-file $envFile -f docker-compose.test.yml up -d
Pop-Location

# --- Phase 1: Wait for TCP port 2222 (up to 30s) ---
Write-Host "[2/3] Waiting for port 2222..." -ForegroundColor Cyan
$tcpReady = $false
for ($i = 1; $i -le 30; $i++) {
  Start-Sleep -Seconds 1
  $tcp = Test-NetConnection -ComputerName localhost -Port 2222 -InformationLevel Quiet -WarningAction SilentlyContinue
  if ($tcp) {
    Write-Host "  Port 2222 open (${i}s elapsed)" -ForegroundColor DarkGray
    $tcpReady = $true
    break
  }
}

if (!$tcpReady) {
  Write-Host ""
  Write-Host "[ERROR] Port 2222 not open after 30s" -ForegroundColor Red
  Write-Host "Container logs:" -ForegroundColor Yellow
  & docker compose --env-file $envFile -f (Join-Path $projectRoot "docker-compose.test.yml") logs --tail 40
  exit 1
}

# --- Phase 2: Wait for SSH auth (up to 60s) ---
# Pass options directly on CLI to bypass any stale config / known_hosts issues
Write-Host "  Waiting for SSH auth..." -ForegroundColor DarkGray
$ready = $false
for ($i = 1; $i -le 30; $i++) {
  Start-Sleep -Seconds 2
  $result = & ssh `
    -o StrictHostKeyChecking=no `
    -o "UserKnownHostsFile=NUL" `
    -o ConnectTimeout=3 `
    -o BatchMode=yes `
    $sshHost "echo OK" 2>$null
  if ($result -match "OK") {
    Write-Host "  Auth OK ($($i * 2)s elapsed)" -ForegroundColor DarkGray
    $ready = $true
    break
  }
}

if (!$ready) {
  Write-Host ""
  Write-Host "[ERROR] SSH auth failed after 60s" -ForegroundColor Red
  Write-Host ""
  Write-Host "Container logs:" -ForegroundColor Yellow
  & docker compose --env-file $envFile -f (Join-Path $projectRoot "docker-compose.test.yml") logs --tail 40
  Write-Host ""
  exit 1
}

# --- Success ---
Write-Host "[3/3] Connection verified!" -ForegroundColor Green
Write-Host ""
Write-Host "--------------------------------------" -ForegroundColor DarkCyan
Write-Host "  Tunelo tunnel config" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor DarkCyan
Write-Host "  SSH alias    : $sshHost  (ssh $sshHost)"
Write-Host "  Host         : localhost"
Write-Host "  Port         : 2222"
Write-Host "  Username     : testuser"
Write-Host "  Identity File: $keyPath"
Write-Host "  Local Port   : 18080"
Write-Host "  Remote Host  : localhost"
Write-Host "  Remote Port  : 8080"
Write-Host "--------------------------------------" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "To stop: .\scripts\test-down-docker.ps1" -ForegroundColor DarkGray
Write-Host ""
