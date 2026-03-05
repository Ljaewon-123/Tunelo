# Tunelo test environment startup script (Docker)

$keyPath = "$env:USERPROFILE\.ssh\id_tunelo_test"
$sshConfigPath = "$env:USERPROFILE\.ssh\config"
$sshHost = "tunelo-test"
$projectRoot = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $projectRoot ".env.test"

# $env:TEMP 가 8.3 단축경로(C:\TEMPFI~1)일 수 있으므로 풀 경로로 해석
# → ssh-keyscan/ssh 가 경로를 올바르게 인식하도록 보장
$knownHostsTemp = Join-Path (Get-Item $env:TEMP).FullName "tunelo_test_known_hosts"

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
# UserKnownHostsFile: ssh-keyscan 으로 매번 갱신하는 전용 임시 파일 사용
# StrictHostKeyChecking yes: known_hosts 에 등록된 키만 허용 (보안 강화)
$configEntry = @"
Host $sshHost
  HostName localhost
  Port 2222
  User testuser
  IdentityFile $keyPath
  StrictHostKeyChecking yes
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

# 이전 known_hosts 초기화 (컨테이너 재시작 시 호스트 키 변경됨)
if (Test-Path $knownHostsTemp) { Remove-Item $knownHostsTemp -Force }
# 이전 실행이 남긴 NUL 파일 정리 (Git Bash OpenSSH 버그 잔재)
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

# --- Phase 2: ssh-keyscan 으로 현재 컨테이너 호스트 키를 known_hosts 에 등록 ---
# StrictHostKeyChecking=no 방식은 auth check 이후 키가 바뀔 수 있어 터널 연결 시 충돌 발생
# ssh-keyscan 으로 최신 키를 직접 파일에 써서 불일치 원천 차단
Write-Host "  Scanning host keys..." -ForegroundColor DarkGray
$keyScanReady = $false
for ($i = 1; $i -le 15; $i++) {
  Start-Sleep -Seconds 2
  # ssh-keyscan: 서버가 제공하는 모든 알고리즘 키를 수집해 known_hosts 형식으로 출력
  $scannedKeys = ssh-keyscan -p 2222 localhost 2>$null
  if ($scannedKeys -and $scannedKeys.Count -gt 0) {
    [System.IO.File]::WriteAllLines($knownHostsTemp, $scannedKeys)
    Write-Host "  Host keys registered (${i * 2}s elapsed)" -ForegroundColor DarkGray
    $keyScanReady = $true
    break
  }
}

if (!$keyScanReady) {
  Write-Host "[ERROR] ssh-keyscan failed after 30s" -ForegroundColor Red
  exit 1
}

# --- Phase 3: Wait for SSH auth (up to 60s) ---
Write-Host "  Waiting for SSH auth..." -ForegroundColor DarkGray
$ready = $false
for ($i = 1; $i -le 30; $i++) {
  Start-Sleep -Seconds 2
  $result = & ssh -o ConnectTimeout=3 $sshHost "echo OK" 2>$null
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

# --- Phase 4: Start SSH tunnel (local port forwarding) ---
# -N  : 원격 명령 실행 없이 포트 포워딩 전용으로 연결
# -f  제거: Windows OpenSSH -f fork가 known_hosts 경로를 재해석해 키 충돌 유발
#           Start-Process -WindowStyle Hidden 으로 대신 백그라운드 처리
# -L  : 로컬 포트(18080) → 원격 컨테이너 내부 포트(8080) 포워딩
# -o ExitOnForwardFailure=yes : 포워딩 바인드 실패 시 즉시 종료 (포트 충돌 감지)
Write-Host ""
Write-Host "[4/4] Starting SSH tunnel  localhost:18080 -> container:8080 ..." -ForegroundColor Cyan

# 18080-18085 전체 포트 선점 여부 확인 후 PID 기반으로만 종료 (무관한 ssh 세션 보호)
foreach ($port in 18080..18085) {
  $line = netstat -ano | Select-String "127\.0\.0\.1:${port}\s|0\.0\.0\.0:${port}\s" | Select-Object -First 1
  if ($line) {
    $existingPid = ($line.ToString() -split '\s+')[-1].Trim()
    if ($existingPid -match '^\d+$') {
      Write-Host "  Port $port in use (PID $existingPid). Killing..." -ForegroundColor Yellow
      Stop-Process -Id $existingPid -Force -ErrorAction SilentlyContinue
    }
  }
}
Start-Sleep -Milliseconds 500

# 터널 프로세스 백그라운드 실행 (Start-Process 로 숨김 창 생성)
$tunnelArgs = @("-N", "-L", "18080:localhost:8080", "-o", "ExitOnForwardFailure=yes", $sshHost)
$tunnelProc = Start-Process ssh -ArgumentList $tunnelArgs -PassThru -WindowStyle Hidden

# 포트 바인딩 여부로 터널 정상 가동 확인
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
