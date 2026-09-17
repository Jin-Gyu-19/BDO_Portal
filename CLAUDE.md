# CLAUDE.md — SH Platform (성현회계법인 AX 대전환)

> 이 파일은 이어받는 Claude를 위한 프로젝트 지침입니다.
> 더 상세한 배경은 `docs/SH_Platform_작업인수인계서_20260916.md` 참조.

---

## 이 저장소 구성

| 경로 | 내용 | 비고 |
|---|---|---|
| `portal-deploy-v5/` | **포털 본체(`index.html`) + 배포 스크립트(`deploy-portal-PC.bat`) + 현행 nginx 라우팅(`default.conf`)** | ★ 포털 작업은 여기서 |
| `docs/` | 작업 인수인계서, NAS 인프라 변경보고서(SH-AX-INFRA-001) | 배경·제약 사항 |
| `infra/reference/` | 초기 인프라 구축본(compose, nginx.conf, .env.example) | 운영본과 다름. 참고만 |
| `design-new/` | 새 포털 디자인 원본(CDN판, 2026-09-16 수령). 배포본은 이 파일에 앱 연결만 얹은 것 | diff 기준점. 수정하지 말 것 |

이전 디자인 시안(sample-1~21, plans/A·A-2·A-3, TODO.md)은 2026-09-16에 저장소에서 삭제했습니다. 필요하면 커밋 `33a3b0e` 이전 이력에서 꺼낼 수 있습니다.

원본 zip에서 **가져오지 않은 것**: `audit.html`·`ifrs18.html`(4/8 구버전), `deploy-v5.sh`(실행 금지 스크립트), `index.html.bak*`(git 이력이 대신함), `app-deploy*`·`pc-build`(초기본), `finance-deploy`·`dsd-deploy`(범위 외), `UPDATE_20260420_IFRS18_Analyzer`(건드리지 말 것).

---

## 현재 작업 범위

**포털(SH Portal)만 작업합니다.** 다른 앱(금융기관 조회, XBRL, 1118호)의 배포·수정은 현재 범위가 아닙니다.

배포본 작업 대상 파일은 사실상 하나입니다: `portal-deploy-v5/index.html`

---

## 프로젝트 개요

성현회계법인 사내 감사 플랫폼. Synology NAS(DS1019+)에 Docker로 운영되며, SH Portal이 각 업무 앱을 iframe으로 묶는 런처 역할을 합니다.

| 항목 | 값 |
|---|---|
| NAS | `192.168.100.25` (SSH 포트 `3907`, 계정 `jinkyu.kim`) |
| 포털 URL | `http://192.168.100.25:8080/` |
| 포털 배포 경로 | `/volume1/sh-pf/docker/nginx-html/portal/index.html` |

---

## 포털 구조 (핵심) — 2026-09-16 새 디자인

`portal-deploy-v5/index.html` — **단일 HTML 파일**(약 650KB, 아이콘 PNG/WebP 60개 내장, Pretendard 폰트는 jsdelivr CDN). 백엔드·DB·빌드 과정 없음. `fetch`/API 호출 없는 정적 파일입니다.

iPad/macOS식 **홈 화면 + 창 시스템**입니다. 위젯(일정·팀 스페이스·타임시트·메모·공지)과 앱 아이콘이 10×5 격자에 놓이고, 앱을 누르면 창이 열립니다. 하단 Dock, ⌘K 검색, "홈 편집" 서랍, 스티커 메모, AI 칼 플로팅 챗봇이 있습니다. **로그인 화면은 없습니다. 접속하면 바로 홈**입니다 (2026-09-16 결정. 인증은 SSO 도입 때 nginx 단에서 처리).

**위젯·목업 앱 내용·사용자(윤길배)·칼의 답변은 전부 하드코딩된 목업입니다.** 실데이터 연동은 없습니다. 실제로 동작하는 것은 아래 앱 5개를 창 안 iframe으로 여는 것뿐입니다.

### 연결된 앱 5종 (`APPS`에 `url`이 있는 항목)

| 앱 키 | 이름 | iframe 대상 | 방식 |
|---|---|---|---|
| `shaudit` | SH Audit Platform | `/audit/index.html` | 정적 HTML |
| `k1118` | K-IFRS 1118호 자동화 Tool | `/ifrs18/index.html` | 정적 HTML |
| `fin` | 금융기관 조회 | `/data/` | Streamlit 프록시 |
| `xbrl` | XBRL Comparator | `extUrl(4000,4443)` → http면 `http://<접속호스트>:4000/`, https면 `https://<접속호스트>:4443/` | **외부 포트 직접 연결.** 포털을 여는 프로토콜·호스트를 따라감 (DSM 역방향 프록시 4443 → localhost:4000 전제) |
| `room` | 회의실 예약 | `/room/index.html` | 정적 HTML — NAS `nginx-html/portal/room/index.html`에 File Station으로 올림 (사용자가 올릴 예정). `:3501` SSO(https) 버전은 iframe 불가라 쓰지 않음 |

- `url`이 있는 앱은 `openApp()`에서 목업 `body()` 대신 `frameBody()`가 만든 iframe 창으로 열립니다. 창 크기는 `w:1600,h:1000`으로 잡아 화면에 거의 꽉 차게(최대화·이동·닫기 가능) 열립니다.
- 주소 해석은 `appUrl()`: NAS(nginx)에서 열면 상대 경로, 파일을 로컬에서 열면 `NAS_BASE`(`http://192.168.100.25:8080`) 절대 주소.
- 로딩 스피너 `.app-loading`은 iframe `load` 시(최소 0.5초 노출) 또는 15초 후 제거.
- 창 이동·크기조정 중에는 `body.winDrag`로 모든 iframe의 포인터 이벤트를 끊습니다.
- 나머지 20개 앱(리뷰함·TAX Agent·JET Tool 등)은 목업 창입니다. 실제 서비스가 생기면 해당 항목에 `url:`만 넣으면 됩니다.
- **다운로드형 앱**(설치 파일·엑셀 매크로 등): 항목에 `dl:{file:'JET_Tool_v1.2.xlsm', ver:'1.2'}`를 넣으면 홈·Dock 아이콘 **우측 하단에 작은 다운로드 배지**(`.dlb`)가 붙습니다. 배지를 누르면 `triggerDownload()`가 NAS의 `/downloads/<file>`을 바로 내려받고, 아이콘 본체는 평소대로 창을 엽니다. 파일은 NAS `/volume1/sh-pf/docker/nginx-html/portal/downloads/`에 DSM File Station으로 올립니다(nginx 루트가 `portal/`이라 설정 변경 불필요). 편집 모드(`body.editing`)에서는 배지를 숨깁니다.

### 앱을 추가/연결할 때 손대야 하는 곳

1. `const APPS = {` — 항목 추가 (`name, sub, short, bg, w, h`, 실제 앱이면 `url`, 다운로드형이면 `dl:{file,ver}`)
2. `const APP_CAT` — 카테고리 (`audit`/`tax`/`admin`/`ai`/`adv`)
3. `const APP_ICON` — `ICONS`의 그림 키 매핑 (없으면 `short` 글자 타일로 표시)
4. 홈 기본 배치에 올리려면 `LAYOUT_DEFAULT` **그리고** `finalMemory` 안의 JSON 스냅샷 **둘 다**에 `{"k":"a","id":"<앱키>",r,c,rs,cs}` 추가. `finalMemory`가 localStorage 없을 때의 실제 기본값이라 여기 빠지면 홈에 안 나옵니다. 그룹(`k:"z"`) 칸 범위 안에 놓아야 그 그룹에 속합니다.

### 주요 동작 코드

- `openApp(id, origin)` / `closeApp` / `minApp` / `maxApp` / `snapTo` — 창 시스템. `wins` Map이 열린 창 상태.
- `renderGrid()` / `renderDock()` / `saveLayout()` / `loadLayout()` — 홈 배치. 저장 키는 `store`가 `sh-final-20260916:` 접두어로 localStorage에 씀.
- **Dock = 최근 사용한 앱 4개** (`DOCK_RECENT=true`, `DOCK_N=4`, 2026-09-17). `openApp()`·`triggerDownload()`·Dock의 메모 클릭이 `noteRecent(id)`를 불러 맨 앞으로 올리고 `sh-portal:<id>:recent` 키에 저장. 4개가 안 차면 `DOCK_DEFAULT`(리뷰함·일정·팀·메모)로 채움. 칼(`ai`)은 제외. 이 모드에서는 Dock 아이콘 드래그·Dock에 놓기가 꺼져 있음(`DOCK_RECENT=false`로 되돌리면 예전 수동 Dock).
- `openKal()` / 칼 답변은 키워드 규칙. `USER` 상수가 표시 이름·이메일.
- 프로필 메뉴 "로그아웃"은 토스트만 띄웁니다 (로그인 화면이 없으므로).

---

## 배포 방법

**기본: `portal-deploy-v5/update-portal-from-github.bat`** (Windows PC에서 더블클릭, 저장소 클론 불필요)

1. GitHub `claude/awesome-hopper-cmd4wg` 브랜치의 `portal-deploy-v5/index.html`을 raw로 내려받음 (캐시 우회)
2. 검사: 200KB 이상 · `<title>SH Portal` 포함 · `</html>`로 끝남. 하나라도 실패하면 배포 안 함
3. ssh 한 번(비밀번호 1회)으로 NAS에 전송 → 바이트 수 대조 → 원본 `index.html.bak_타임스탬프` 백업 → 교체. 크기 불일치면 아무것도 안 바꿈
4. NAS의 백업은 **최신 5개만 유지**(`MAX_BAK`), 더 오래된 `index.html.bak_*`는 자동 삭제. 실행 끝에 남은 백업 목록과 롤백 명령을 출력

즉 흐름은 **여기서 푸시 → 사용자가 PC에서 .bat 더블클릭 → 비밀번호 1회**. 배포 브랜치를 바꾸려면 .bat 상단 `GH_BRANCH`만 수정. nginx 재시작 불필요(정적 파일).

**예비: `portal-deploy-v5/deploy-portal-PC.bat`** — .bat과 같은 폴더의 `index.html`(로컬 클론본)을 scp로 올림. GitHub에 접근이 안 될 때만.

이 저장소(클라우드 세션)에서는 NAS에 접근할 수 없습니다. 여기서는 코드·문서 작업까지만 하고, 배포는 데스크톱에서 합니다.

---

## 절대 규칙

**1. `deploy-v5.sh`를 실행하지 마세요.** (이 저장소에는 일부러 넣지 않았습니다)
전체 배포 스크립트라 같은 폴더의 `ifrs18.html`(4/8 구버전, 280KB)로 NAS의 최신 1118호(4/20, 1.2MB)를 덮어써 **롤백시킵니다.** 포털 배포는 반드시 `deploy-portal-PC.bat`만 사용합니다.

**2. NAS의 다른 서비스에 영향을 주지 마세요.**
`nginx` / `postgres` / `redis` / `db-backup` / `streamlit` 컨테이너는 건드리지 않습니다. 포털 작업은 `nginx-html/portal/index.html` 파일 하나만 바꾸면 되며, 컨테이너 재시작조차 필요 없습니다.

**3. `docker-compose.yml`의 nginx 설정을 변경하지 마세요.**
Synology Docker는 컨테이너 간 bridge 통신이 동작하지 않아 nginx를 `network_mode: host`로 운영 중입니다. 변경 시 전체 서비스 접속 불가. 새 컨테이너(예: oauth2-proxy)를 붙일 때도 이 제약을 전제로 설계합니다 (`docs/SH-AX-INFRA-001_NAS_인프라_변경보고서.md`).

**4. 파일 전송은 `scp -O`.**
Synology는 SFTP 하위시스템이 비활성이라 옵션 없이 쓰면 `subsystem request failed on channel 0` 오류가 납니다.

**5. `.bat` 스크립트는 ASCII(영문)로만 작성.**
한글 Windows의 cmd는 배치파일을 CP949로 해석하므로, UTF-8 한글 주석이 들어가면 파싱이 깨져 `'REM'은 명령이 아닙니다` 류 오류가 발생합니다. (`.bat`은 CRLF 줄바꿈을 유지하세요.) 또한 **.bat 안의 ssh 원격 명령에 `\"`를 쓰지 마세요.** cmd는 `\"`를 만나면 따옴표 상태가 뒤집혀 그 뒤의 `^`·`<`·`>`·`|`를 잡아먹습니다(2026-09-17 실제 발생: `sed 's/^/…/'`의 `^`가 사라져 오류). 원격 셸 문자열은 작은따옴표만 사용합니다.

**6. 배포된 개별 앱 파일(1118호·감사플랫폼·XBRL)은 수정하지 마세요.**
창 프레임·스피너 등은 전부 포털 쪽에 있습니다. 개별 앱은 standalone으로도 쓰이므로 포털 관련 코드가 들어가면 안 됩니다.

**7. 비밀번호·키를 저장소에 넣지 마세요.**
`.env`는 NAS에만 있습니다. `infra/reference/docker-compose.yml`에서도 기본 비밀번호 폴백을 제거했습니다.

---

## 현재 상태

- `portal-deploy-v5/index.html`은 **2026-09-16 새 디자인으로 전면 교체**되었고 아직 **미배포**입니다. `deploy-portal-PC.bat`으로 올리면 NAS 포털이 새 디자인으로 바뀝니다. 이전 BDO 레드 사이드바 디자인은 git 이력(커밋 `d92fbc6` 시점)에 있습니다.
- 새 디자인 전환으로 로그인 화면·1118호 직행·임시 백도어·`?dev` 모드는 **모두 사라졌습니다.** 접속하면 바로 홈입니다.
- 롤백은 git 이력 또는 NAS의 `index.html.bak_*`(배포 스크립트가 자동 생성)으로 합니다.
- **HTTPS 전환 진행 중 (2026-09-17 결정).** 방식: DSM 역방향 프록시가 https를 종단 — `HTTPS 8443 → http://localhost:8080`(포털·감사플랫폼·1118호·금융기관 조회, WebSocket 헤더 켜기), `HTTPS 4443 → http://localhost:4000`(XBRL). 우리 nginx 컨테이너·compose는 그대로. 포털은 `extUrl()`로 http/https 양쪽에서 동작하므로 파일 수정 없이 두 주소 모두 사용 가능. 인증서는 DSM 제어판 → 보안 → 인증서에서 다른 https 페이지와 같은 것을 배정. 회의실(:3501 SSO)은 https로 바꿔도 iframe 불가(MS 로그인 페이지 프레임 거부) — 정적 HTML로 대체.

### 최근 적용된 변경 (2026-09-16)
1. 새 디자인(`design-new/` CDN판)으로 포털 전면 교체
2. 실제 앱 4종을 창 안 iframe으로 연결 (`url` 필드 + `frameBody()` + 스피너)
3. SH Audit Platform 앱 신설(`shaudit`, 감사 그룹, 아이콘 `sh_audit`) — 감사 그룹을 6칸으로 넓혀 홈에 배치
4. 로그인 화면·백도어·개발 모드 제거 (디자인 파일에 없던 것을 되살리지 않음)

---

## 남은 작업

1. **MS SSO 로그인 (Entra ID, 테넌트 `bdo.kr`)**
   - 방식: oauth2-proxy 컨테이너 + nginx `auth_request`, 기존 Redis를 세션 저장소로 재활용
   - 권한: Entra 보안그룹 `SH-Platform-Admins` 멤버 = 관리자, 그 외 전원 일반
   - 범위: 전체 게이트(미로그인 시 모든 앱 차단)
   - ⚠️ **선행조건 — HTTPS 필수.** Entra ID는 localhost 외 http redirect URI를 허용하지 않아, 현재 `http://192.168.100.25:8080`으로는 앱 등록 자체가 불가합니다. HTTPS를 안 하기로 한 상태라 이 충돌을 먼저 풀어야 합니다 (도메인·인증서 확보 또는 다른 인증 방식).
2. SSO 완료 후 → `USER` 상수(이름·이메일·이니셜)를 로그인 정보로 채우고, 프로필 메뉴 로그아웃을 실제 로그아웃(`/oauth2/sign_out`)으로 연결
3. 홈 위젯·목업 앱·칼 답변을 실데이터로 연동 (백엔드 필요)
4. `sh_audit` 아이콘이 'Ai' 그림이라 SH Audit Platform과 안 어울림 — 전용 아이콘 교체 검토

---

## 로컬에만 있는 것 (이 저장소에 없음)

1. `docker-compose.yml` **운영본**(host 모드 수정본) — NAS에만 존재. 필요 시 `scp -O -P 3907 jinkyu.kim@192.168.100.25:/volume1/sh-pf/docker/sh-platform/docker-compose.yml .`
2. `.env` (실제 DB 비밀번호)
3. XBRL Comparator(:4000) 소스 — `C:\6.Claude_Cowork\김진솔 MANAGER님\` 폴더
4. 1118호 최신 배포본(`UPDATE_20260420_IFRS18_Analyzer`), 금융기관 조회·DSD 배포 패키지 — 원본 zip / OneDrive 폴더
