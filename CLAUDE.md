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

### 핵심기능 
- 터널링 세션 관리 이 app에서 연결한 터널링이 아니여도 다른 앱이나 cli에서 연결한 터널링 정보도 전부 가져와서 표시해야만 한다. 
- user가 직접 타이핑해서 연결할수있는 cli기능이 있어야 한다(메인 화면에서만)
- cli명령어를 주기적으로 실행해서 앱 외부에서 연결된 터널도 표시해야함

### 오버레이 
- Discord 게임 오버레이 스타일, 화면 좌상단 고정
- 현재 **연결된 터널만** compact하게 표시
- 접기 / 펼치기 토글 가능
- 확대 버튼 클릭 → 메인 앱 창 오픈 -> 오버레이 close
- 터널링 연결이 추가 되거나 생성되었을때 자동으로 최신화 해서 표시해야함
- 메인창에서 오버레이 버튼을 누르면 표시
- 새로고침 아이콘으로 새로운 터널링 정보 갱신할수 있어야함 (스스로 갱신하는게 제일 베스트)

### 메인 앱 창
- 전체 터널 목록 표시 (연결 중 + 미연결)
- 터널별 **별칭 설정** 가능 (별칭 없으면 host:port 정보 표시)
- 개별 터널 연결 / 끊기
- 전체 터널 한 번에 끊기
- 최근 연결 터널
- 터널 설정 저장기능 
- 닫기 버튼을 누르면 바로 프로그램 종료 
- 오버레이 창을 누르면 메인 창이 close되고 오버레이 창이 open
- 프로그램이 떴을때 기존 연결 정보와 연결 세션도 자동으로 표시가 되어야함
- 새로고침 아이콘으로 새로운 터널링 정보 갱신할수 있어야함

### 터널 관리 기능
- 연결 (SSH 프로세스 직접 spawn)
- 실시간 모니터링 (연결 상태, PID 추적)
- 개별 끊기 / 전체 끊기
- 이미 연결되어 있는 터널링 표시 (app에서 추가하지 않은 터널링이라도 표시 해야 한다.)

## 기술 스택
- **Electron** (Node.js only, 추가 백엔드 런타임 없음)
- `child_process`으로 [ex) child_process.spawn] ssh 프로세스 직접 실행 및 PID 관리
- `-f` 옵션 사용 시 프로세스 추적 주의 (detached 처리 필요)
- 시스템 트레이 상주 (앱 종료 시에도 트레이에 남음)
- 유저가 원한다면 트레이에 상주하지 않고 완전 종료할수있는 옵션이나 해당 값이 있어야함 
- 터널 설정은 JSON 파일로 로컬 저장 (`userData` 경로)
- typescript 적극사용 
- defu, destr 이 유용한 곳에서는 해당 lib사용

### fe 요구사항 
- 무조건 vue3.5+ 이상버전 사용
- fe쪽은 tailwindcss를 기본으로 설정 필요하다면 나에게 추가적인 ui프레임워크가 필요하다고 요청할것 
- 최신 FSD폴더 구조를 따라갈것 
- 가능하면 file-base-routing를 사용할것 (unplugin vue router) 이부분은 필수가 아니다
- .vue파일 구조는 <script> -> <template> -> <style> 구조로 갈것 
- 최신 vue기능 적극적으로 사용할것 ex) 양방향 바인딩에 emit사용하지 말고 defineModel 매크로 사용할것
- 무조건 composition api 사용하고 <script setup lang="ts"></script> 로 사용 
- 전역 상태 관리가 필요하다면 pinia를 사용
- 가능하면 import같은 ES문법만을 사용 


# 터미널 확인 명령어
app이 아니라 리눅스 혹은 윈도우에서 연결된 터널링 확인 명령어
```
Get-CimInstance Win32_Process -Filter "name='ssh.exe'" | Select-Object CommandLine
```
```
tasklist /FI "IMAGENAME eq ssh.exe" /V
```