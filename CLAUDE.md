패키지 요약:

electron ^34 + electron-vite ^3
vue ^3.5.13 + @vitejs/plugin-vue
TypeScript ^5.7 + vue-tsc
Node >=24 조건 (engines 필드)
@electron-toolkit/preload + @electron-toolkit/utils (lib 역할)

# TunnelOverlay — Project Context

## 프로젝트 개요
Windows 로컬 환경에서 Linux 내부망 서버에 접속할 때 사용하는
SSH 터널링들을 통합 관리하는 Electron 데스크탑 앱.

## 개발 환경
- 로컬: Windows
- 서버: Linux (내부망, SSH 접속)

## 터널링 현황
- 실행 방식: **Tabby**, **CMD**, **VSCode Remote SSH** 3가지 병행 사용
- 사용 SSH 옵션: `-L` (로컬 포트 포워딩), `-N` (포워딩 전용, 명령 없음), `-f` (백그라운드 실행) 조합
- 터널 종류: 인프라 연결용 터널 + VSCode 코딩 작업용 터널

## 앱 요구사항

### 오버레이 (항상 위에 표시)
- Discord 게임 오버레이 스타일, 화면 좌상단 고정
- 현재 **연결된 터널만** compact하게 표시
- 접기 / 펼치기 토글 가능
- 확대 버튼 클릭 → 메인 앱 창 오픈

### 메인 앱 창
- 전체 터널 목록 표시 (연결 중 + 미연결)
- 터널별 **별칭 설정** 가능 (별칭 없으면 host:port 정보 표시)
- 개별 터널 연결 / 끊기
- 전체 터널 한 번에 끊기
- 최근 연결 터널 혹은 터널 설정 저장기능 (가능하면 db미사용 최대한 가볍기를 원함 일시적 메모리 저장 허용 혹은 json파일 사용할것)

### 터널 관리 기능
- 연결 (SSH 프로세스 직접 spawn)
- 실시간 모니터링 (연결 상태, PID 추적)
- 개별 끊기 / 전체 끊기

## 기술 스택
- **Electron** (Node.js only, 추가 백엔드 런타임 없음)
- `child_process`으로 [ex) child_process.spawn] ssh 프로세스 직접 실행 및 PID 관리
- `-f` 옵션 사용 시 프로세스 추적 주의 (detached 처리 필요)
- 시스템 트레이 상주 (앱 종료 시에도 트레이에 남음)
- 유저가 원한다면 트레이에 상주하지 않고 완전 종료할수있는 옵션이나 해당 값이 있어야함 
- 터널 설정은 JSON 파일로 로컬 저장 (`userData` 경로)
- fe쪽은 tailwindcss를 기본으로 설정 필요하다면 나에게 추가적인 ui프레임워크가 필요하다고 요청할것 
- 최신 FSD폴더 구조를 따라갈것 
- 가능하면 file-base-routing를 사용할것 (unplugin vue router) 이부분은 필수가 아니다
