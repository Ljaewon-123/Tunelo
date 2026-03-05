# open-extra-tunnels.ps1 - Open 5 extra SSH tunnels for UI testing
# Requires: test-up-docker.ps1 already ran successfully (tunelo-test host config must exist)

# Resolve $env:TEMP 8.3 short path to full path to avoid known_hosts path mismatch
$knownHostsTemp = Join-Path (Get-Item $env:TEMP).FullName "tunelo_test_known_hosts"

# Tunnel definitions: local port -> remote container port
$tunnels = @(
  @{ local = 18081; remote = 3306;  label = "MySQL" },
  @{ local = 18082; remote = 5432;  label = "PostgreSQL" },
  @{ local = 18083; remote = 6379;  label = "Redis" },
  @{ local = 18084; remote = 9200;  label = "Elasticsearch" },
  @{ local = 18085; remote = 27017; label = "MongoDB" }
)

foreach ($t in $tunnels) {
  $port = $t.local

  # Kill any process already occupying this port (by PID only, not all ssh.exe)
  $line = netstat -ano | Select-String "127\.0\.0\.1:${port}\s|0\.0\.0\.0:${port}\s" | Select-Object -First 1
  if ($line) {
    $existingPid = ($line.ToString() -split '\s+')[-1].Trim()
    if ($existingPid -match '^\d+$') {
      Write-Host "  Port $port in use (PID $existingPid). Killing..." -ForegroundColor Yellow
      Stop-Process -Id $existingPid -Force -ErrorAction SilentlyContinue
      Start-Sleep -Milliseconds 300
    }
  }

  # -N : forward only, no remote command
  # Note: -f removed because Windows OpenSSH -f fork reinterprets known_hosts path (8.3 bug)
  #       Use Start-Process -WindowStyle Hidden instead for background execution
  $forward = "$($t.local):localhost:$($t.remote)"
  $tunnelArgs = @("-N", "-L", $forward, "tunelo-test")
  Start-Process ssh -ArgumentList $tunnelArgs -WindowStyle Hidden
  Write-Host "  Started: $($t.label)  localhost:$($t.local) -> container:$($t.remote)" -ForegroundColor Cyan
}

# Wait then verify all ports actually bound
Start-Sleep -Seconds 2

$bound = 0
$failed = @()
foreach ($t in $tunnels) {
  $p = $t.local
  $ok = netstat -ano | Select-String "127\.0\.0\.1:${p}\s|0\.0\.0\.0:${p}\s"
  if ($ok) {
    $bound++
  } else {
    $failed += "$($t.label)(:$p)"
  }
}

Write-Host ""
if ($failed.Count -gt 0) {
  Write-Host "[WARNING] $($failed.Count) tunnel(s) failed to bind: $($failed -join ', ')" -ForegroundColor Yellow
} else {
  Write-Host "All $bound extra tunnels active" -ForegroundColor Green
}

Write-Host ""
netstat -ano | Select-String "1808[1-5]"
