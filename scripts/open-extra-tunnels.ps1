# 추가 터널 5개 오픈 (UI 테스트용)
# 이미 test-up-docker.ps1로 tunelo-test SSH 서버가 떠 있어야 함

$knownHostsTemp = "$env:TEMP\tunelo_test_known_hosts"

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
  $tunnelArgs = @(
    "-N", "-f",
    "-L", $forward,
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=$knownHostsTemp",
    "-o", "BatchMode=yes",
    "tunelo-test"
  )
  Start-Process ssh -ArgumentList $tunnelArgs -WindowStyle Hidden
  Write-Host "  Started: $($t.label)  localhost:$($t.local) -> container:$($t.remote)" -ForegroundColor Cyan
}

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Active tunnels on 1808x ports:" -ForegroundColor Green
netstat -ano | Select-String "1808"
