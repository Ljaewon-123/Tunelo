# Tunelo test environment startup script (Docker)

$keyPath = "$env:USERPROFILE\.ssh\id_tunelo_test"
$sshConfigPath = "$env:USERPROFILE\.ssh\config"
$sshHost = "tunelo-test"
$projectRoot = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $projectRoot ".env.test"

# Docker 재시작마다 컨테이너 호스트 키가 바뀌므로
# NUL(Windows 널 장치) 대신 전용 임시 파일을 사용하고 매번 삭제해 키 충돌을 방지한다
# (Git Bash의 OpenSSH는 NUL을 실제 파일로 생성해 이전 키가 남아 충돌 발생)
$knownHostsTemp = "$env:TEMP\tunelo_test_known_hosts"

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
# UserKnownHostsFile: 전용 임시 파일 경로 지정 (NUL은 Git Bash에서 실제 파일로 생성되어 키 충돌 유발)
$configEntry = @"
Host $sshHost
  HostName localhost
  Port 2222
  User testuser
  IdentityFile $keyPath
  StrictHostKeyChecking no
  UserKnownHostsFile $knownHostsTemp
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
Write-Host "SSH config updated: $sshHost" -ForegroundColor Green

# 컨테이너가 재시작되면 호스트 키가 바뀌므로 임시 known_hosts를 항상 초기화
if (Test-Path $knownHostsTemp) { Remove-Item $knownHostsTemp -Force }
# 프로젝트 디렉터리에 남아있을 수 있는 NUL 파일 정리 (이전 실행 잔재)
if (Test-Path (Join-Path $projectRoot "NUL")) { Remove-Item (Join-Path $projectRoot "NUL") -Force }

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
    -o "UserKnownHostsFile=$knownHostsTemp" `
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

# --- Phase 3: Start SSH tunnel (local port forwarding) ---
# -N  : 원격 명령 실행 없이 포트 포워딩 전용으로 연결
# -f  : 인증 후 백그라운드로 전환 (터미널 점유 없이 상주)
# -L  : 로컬 포트(18080) → 원격 컨테이너 내부 포트(8080) 포워딩
# -o ExitOnForwardFailure=yes : 포워딩 바인드 실패 시 즉시 종료 (포트 충돌 감지)
Write-Host ""
Write-Host "[4/4] Starting SSH tunnel  localhost:18080 -> container:8080 ..." -ForegroundColor Cyan

# 이미 18080 포트를 점유한 ssh 프로세스가 있으면 먼저 종료
$existingTunnel = netstat -ano | Select-String "0.0.0.0:18080|127.0.0.1:18080"
if ($existingTunnel) {
  Write-Host "  Port 18080 already in use. Killing existing process..." -ForegroundColor Yellow
  # netstat 출력에서 PID 추출 후 강제 종료
  $pid18080 = ($existingTunnel -split '\s+')[-1] | Select-Object -First 1
  if ($pid18080 -match '^\d+$') { Stop-Process -Id $pid18080 -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Seconds 1
}

# 터널 프로세스 백그라운드 실행
# Start-Process 로 별도 프로세스 생성 → PID 추적 가능
# -f 는 SSH 내부 fork라 Node child_process와 다르게 동작하므로 -N 만 사용하고 Start-Process로 백그라운드 처리
$tunnelArgs = @("-N", "-f", "-L", "18080:localhost:8080", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=$knownHostsTemp", "-o", "ExitOnForwardFailure=yes", "-o", "BatchMode=yes", $sshHost)
$tunnelProc = Start-Process ssh -ArgumentList $tunnelArgs -PassThru -WindowStyle Hidden

# -f 옵션은 SSH 내부적으로 fork하기 때문에 Start-Process 반환 PID와 실제 ssh 프로세스 PID가 다를 수 있음
# 따라서 포트 바인딩 여부로 터널 정상 가동 확인
Write-Host "  Waiting for tunnel to bind port 18080..." -ForegroundColor DarkGray
$tunnelReady = $false
for ($i = 1; $i -le 10; $i++) {
  Start-Sleep -Seconds 1
  $bound = netstat -ano | Select-String "0.0.0.0:18080|127.0.0.1:18080"
  if ($bound) {
    Write-Host "  Tunnel bound (${i}s elapsed)" -ForegroundColor DarkGray
    $tunnelReady = $true
    break
  }
}

if (!$tunnelReady) {
  Write-Host ""
  Write-Host "[ERROR] Tunnel failed to bind port 18080 after 10s" -ForegroundColor Red
  Write-Host "Check SSH key / container status and retry." -ForegroundColor Yellow
  exit 1
}

Write-Host "  Tunnel active!" -ForegroundColor Green

# --- Summary ---
Write-Host ""
Write-Host "--------------------------------------" -ForegroundColor DarkCyan
Write-Host "  Tunelo tunnel config" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor DarkCyan
Write-Host "  SSH alias    : $sshHost  (ssh $sshHost)"
Write-Host "  Host         : localhost"
Write-Host "  Port         : 2222"
Write-Host "  Username     : testuser"
Write-Host "  Identity File: $keyPath"
Write-Host "  Local Port   : 18080  <-- 터널 포워딩 포트"
Write-Host "  Remote Host  : localhost"
Write-Host "  Remote Port  : 8080"
Write-Host "--------------------------------------" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "To stop: .\scripts\test-down-docker.ps1" -ForegroundColor DarkGray
Write-Host ""
