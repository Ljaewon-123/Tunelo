# Tunelo 테스트 환경 스크립트

## 실행 순서

```
1. test-up-docker.ps1       ← SSH 컨테이너 기동 + 기본 터널(18080) 연결
2. open-extra-tunnels.ps1   ← 추가 터널 5개(18081~18085) 연결  [선택]
```

```powershell
# 터미널에서 실행
.\scripts\test-up-docker.ps1
.\scripts\open-extra-tunnels.ps1   # UI 다중 터널 테스트 시
```

---

## 종료 순서

```
1. test-down-docker.ps1     ← 터널 프로세스(18080~18085) 종료 + 컨테이너 제거
```

```powershell
.\scripts\test-down-docker.ps1
```

> 컨테이너가 종료되면 연결된 터널 프로세스도 함께 끊김.
> down 스크립트는 포트 기반으로 PID를 찾아 kill하므로 무관한 SSH 세션에 영향 없음.

---

## 터널링 연결 명령어

### 기본 터널 (test-up-docker.ps1 이 자동으로 실행)
```
로컬 18080  →  컨테이너:8080
```

### 수동으로 터널 연결 (SSH config 등록 후)
```powershell
# 단일 터널
ssh -N -L <로컬포트>:localhost:<원격포트> tunelo-test

# 예시
ssh -N -L 18080:localhost:8080 tunelo-test   # App
ssh -N -L 18081:localhost:3306 tunelo-test   # MySQL
ssh -N -L 18082:localhost:5432 tunelo-test   # PostgreSQL
ssh -N -L 18083:localhost:6379 tunelo-test   # Redis
ssh -N -L 18084:localhost:9200 tunelo-test   # Elasticsearch
ssh -N -L 18085:localhost:27017 tunelo-test  # MongoDB
```

### SSH 옵션 설명
| 옵션 | 설명 |
|------|------|
| `-N` | 원격 명령 없이 포워딩만 유지 |
| `-L local:host:remote` | 로컬 포트 → 원격 포트 포워딩 |
| `-f` | 인증 후 백그라운드 fork (Windows에서 known_hosts 경로 버그로 **사용 안 함**) |
| `-o ExitOnForwardFailure=yes` | 포트 바인드 실패 시 즉시 종료 |
| `-o BatchMode=yes` | 비대화형 모드, 비밀번호 프롬프트 없음 |

---

## 현재 연결된 터널 확인

```powershell
# Windows (PowerShell)
netstat -ano | Select-String "1808"

# 앱 외부에서 연결된 SSH 터널 전체 확인
Get-CimInstance Win32_Process -Filter "name='ssh.exe'" | Select-Object CommandLine
```

---

## SSH 서버 정보 (테스트 컨테이너)

| 항목 | 값 |
|------|----|
| Host alias | `tunelo-test` |
| HostName | `localhost` |
| Port | `2222` |
| User | `testuser` |
| IdentityFile | `~/.ssh/id_tunelo_test` |
| Image | `lscr.io/linuxserver/openssh-server:latest` |

---

## 주의사항

- 컨테이너 재시작 시 호스트 키가 변경됨 → `test-up-docker.ps1`이 `ssh-keyscan`으로 자동 갱신
- `-f` 옵션은 Windows OpenSSH에서 8.3 단축경로(`C:\TEMPFI~1`) 문제로 known_hosts 충돌 유발 → 사용 금지
- `$pid`는 PowerShell 예약 변수 → 포트 PID 변수는 `$portPid` / `$existingPid` 사용
