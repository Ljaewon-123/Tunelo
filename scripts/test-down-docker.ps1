# Tunelo test environment teardown script (Docker)

$projectRoot = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $projectRoot ".env.test"
# $env:TEMP 8.3 단축경로 문제 방지
$knownHostsTemp = Join-Path (Get-Item $env:TEMP).FullName "tunelo_test_known_hosts"

# 테스트 터널이 사용하는 포트 목록 (up + open-extra-tunnels 합산)
$tunnelPorts = 18080..18085

Write-Host ""

# --- 포트 기반 PID 타게팅으로 터널 프로세스만 종료 ---
# 전체 ssh.exe kill 금지: 사용자의 무관한 SSH 세션을 보호한다
Write-Host "Killing tunnel processes (ports $($tunnelPorts[0])-$($tunnelPorts[-1]))..." -ForegroundColor Cyan
$killed = 0
foreach ($port in $tunnelPorts) {
  # netstat 으로 해당 포트를 LISTEN 중인 PID 추출
  $line = netstat -ano | Select-String "127\.0\.0\.1:${port}\s|0\.0\.0\.0:${port}\s" | Select-Object -First 1
  if ($line) {
    $portPid = ($line.ToString() -split '\s+')[-1].Trim()
    if ($portPid -match '^\d+$') {
      Stop-Process -Id $portPid -Force -ErrorAction SilentlyContinue
      $killed++
      Write-Host "  Killed PID $portPid on port $port" -ForegroundColor DarkGray
    }
  }
}
if ($killed -eq 0) {
  Write-Host "  No tunnel processes found" -ForegroundColor DarkGray
}

# --- Stop and remove container ---
Write-Host "Stopping SSH container..." -ForegroundColor Cyan
# --env-file 전달: SSH_PUBLIC_KEY 미설정 경고 억제
if (Test-Path $envFile) {
  docker compose --env-file $envFile -f (Join-Path $projectRoot "docker-compose.test.yml") down
} else {
  # .env.test 없으면 빈 값으로 경고 없이 처리
  $env:SSH_PUBLIC_KEY = ""
  docker compose -f (Join-Path $projectRoot "docker-compose.test.yml") down
  Remove-Item env:SSH_PUBLIC_KEY -ErrorAction SilentlyContinue
}

# --- 임시 known_hosts 파일 정리 ---
if (Test-Path $knownHostsTemp) {
  Remove-Item $knownHostsTemp -Force -ErrorAction SilentlyContinue
  Write-Host "Cleaned up temp known_hosts" -ForegroundColor DarkGray
}

# --- 포트 해제 최종 확인 ---
Start-Sleep -Milliseconds 500
$remaining = @()
foreach ($port in $tunnelPorts) {
  $bound = netstat -ano | Select-String "127\.0\.0\.1:${port}\s|0\.0\.0\.0:${port}\s"
  if ($bound) { $remaining += $port }
}

if ($remaining.Count -gt 0) {
  Write-Host "[WARNING] Ports still in use: $($remaining -join ', ')" -ForegroundColor Yellow
} else {
  Write-Host "All tunnel ports released" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "[OK] Test environment cleaned up" -ForegroundColor Green
Write-Host ""
