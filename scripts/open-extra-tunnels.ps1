# 추가 터널 5개 오픈 (UI 테스트용)
# 이미 test-up-docker.ps1로 tunelo-test SSH 서버가 떠 있어야 함

# $env:TEMP 8.3 단축경로 문제 방지 - 풀 경로로 해석
$knownHostsTemp = Join-Path (Get-Item $env:TEMP).FullName "tunelo_test_known_hosts"

# 각 터널은 실제 서비스 포트를 흉내내는 로컬 포워딩
# 형식: 로컬포트:원격호스트:원격포트
$tunnels = @(
  @{ local = 18081; remote = 3306;  label = "MySQL" },
  @{ local = 18082; remote = 5432;  label = "PostgreSQL" },
  @{ local = 18083; remote = 6379;  label = "Redis" },
  @{ local = 18084; remote = 9200;  label = "Elasticsearch" },
  @{ local = 18085; remote = 27017; label = "MongoDB" }
)

foreach ($t in $tunnels) {
  $forward = "$($t.local):localhost:$($t.remote)"
  # -N  : 포트 포워딩 전용, 원격 명령 없음
  # -f  제거: Windows OpenSSH fork 시 known_hosts 경로 재해석 버그 → Start-Process로 백그라운드 처리
  $tunnelArgs = @(
    "-N",
    "-L", $forward,
    "tunelo-test"
  )
  Start-Process ssh -ArgumentList $tunnelArgs -WindowStyle Hidden
  Write-Host "  Started: $($t.label)  localhost:$($t.local) -> container:$($t.remote)" -ForegroundColor Cyan
}

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Active tunnels on 1808x ports:" -ForegroundColor Green
netstat -ano | Select-String "1808"
