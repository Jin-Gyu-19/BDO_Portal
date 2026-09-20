# CLAUDE.md — SH Platform (성현회계법인 AX 대전환)

> 이 파일은 이어받는 Claude를 위한 프로젝트 지침입니다.
> 더 상세한 배경은 `docs/SH_Platform_작업인수인계서_20260916.md` 참조.

---

## 이 저장소 구성

| 경로 | 내용 | 비고 |
|---|---|---|
| `portal-deploy-v5/` | **포털 본체(`index.html`) + 배포 스크립트(`update-portal-from-github.bat`·`deploy-portal-PC.bat`) + 현행 nginx 라우팅(`default.conf`)** | ★ 포털 작업은 여기서 |
| `portal-deploy-v5/apps/` | 포털 창 안에서 여는 **단일 HTML 업무 앱**(JET Workbench·국문/영문 감사보고서 대사검증·영문감사보고서 자동작성). NAS `portal/apps/`로 배포 | 배포는 `update-apps-from-github.bat` |
| `portal-deploy-v5/downloads/` | 다운로드 배지 목록 `manifest.json` 예시 + 사용법(README) | NAS `portal/downloads/`에 File Station으로 직접 관리. `.bat` 배포 대상 아님 |
| `docs/` | 작업 인수인계서, NAS 인프라 변경보고서(SH-AX-INFRA-001) | 배경·제약 사항 |
| `infra/reference/` | 초기 인프라 구축본(compose, nginx.conf, .env.example) | 운영본과 다름. 참고만 |
| `design-new/` | 새 포털 디자인 원본(CDN판, 2026-09-16 수령). 배포본은 이 파일에 앱 연결만 얹은 것 | diff 기준점. 수정하지 말 것 |
| `infra/dl-writer/` | 쓰기 전용 미니 nginx(`sh-dl-writer`, host 모드 `127.0.0.1:4181`) compose + conf. `sh-nginx`의 html 마운트가 `:ro`라 **다운로드 파일(관리자)·내 홈 배치(본인)** 업로드를 이쪽이 받음 | 적용 절차 `sso/README.md` 5번·8번 |
| `infra/db-backup/` | 수리된 `backup.sh`(NAS `scripts/backup.sh`와 동일하게 유지) + 수리 경위 | 2026-09-18 적용 |
| `sso/` | MS SSO 구성: oauth2-proxy compose·`.env.sso.example`·SSO판 nginx `default.conf`(+`/downloads/` 쓰기 location)·Entra 앱 등록 절차·적용 순서(README) | **NAS 적용 완료(2026-09-18)** — NAS의 실제 파일과 동일하게 유지할 것. `/downloads/` 쓰기 설정은 **NAS 미적용**(README 5번) |

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
| 포털 URL | `https://192.168.100.25:8080/` (2026-09-18 포트 교체: DSM https 8080 → nginx 컨테이너 http 8081. http 8081로 직접 오면 301) |
| 포털 배포 경로 | `/volume1/sh-pf/docker/nginx-html/portal/index.html` |

---

## 포털 구조 (핵심) — 2026-09-16 새 디자인

`portal-deploy-v5/index.html` — **단일 HTML 파일**(약 650KB, 아이콘 PNG/WebP 60개 내장, 탭 아이콘은 SVG data URI). Pretendard 폰트는 `@font-face`로 NAS `portal/fonts/PretendardVariable.woff2`를 먼저 찾고 없으면 jsdelivr CDN 폴백(2026-09-19 NAS 적용 완료 — `portal/fonts/PretendardVariable.woff2` 2,057,688바이트, nginx `/fonts/` 캐시 location. 올리는 법: `sso/README.md` 7번). 콘솔의 favicon 404·Edge Tracking Prevention 경고는 이걸로 사라짐. 백엔드·DB·빌드 과정 없음. 정적 파일입니다 (네트워크 호출은 `/oauth2/userinfo`(SSO 사용자)·`/downloads/manifest.json`(다운로드 배지 목록)·`/layouts/me.json`(내 홈 배치 슬롯), 그리고 관리자 전용 다운로드 관리 화면의 `/downloads/` PUT/DELETE 뿐. 없으면 조용히 건너뜀).

iPad/macOS식 **홈 화면 + 창 시스템**입니다. 위젯(일정·팀 스페이스·타임시트·메모·공지)과 앱 아이콘이 10×5 격자에 놓이고, 앱을 누르면 창이 열립니다. 하단 Dock, ⌘K 검색, "홈 편집" 서랍, 스티커 메모, AI 칼 플로팅 챗봇이 있습니다. **로그인 화면은 없습니다. 접속하면 바로 홈**입니다 (2026-09-16 결정. 인증은 SSO 도입 때 nginx 단에서 처리).

**위젯·목업 앱 내용·사용자(윤길배)·칼의 답변은 전부 하드코딩된 목업입니다.** 실데이터 연동은 없습니다. 실제로 동작하는 것은 아래 앱 10개를 창 안 iframe으로 여는 것뿐입니다.

### 연결된 앱 10종 (`APPS`에 `url`이 있는 항목)

| 앱 키 | 이름 | iframe 대상 | 방식 |
|---|---|---|---|
| `shaudit` | SH Audit Platform | `/audit/index.html` | 정적 HTML |
| `k1118` | K-IFRS 1118호 자동화 Tool | `/ifrs18/index.html` | 정적 HTML |
| `fin` | 금융기관 조회 | `/data/` | Streamlit 프록시 |
| `xbrl` | XBRL Comparator | `extUrl(4000,4001)` → http면 `http://<접속호스트>:4000/`, https면 `https://<접속호스트>:4001/` | **외부 포트 직접 연결.** 포털을 여는 프로토콜·호스트를 따라감 (DSM 역방향 프록시 4001 → localhost:4000 전제) |
| `jet` | JET Tool | `/apps/jet-workbench.html` | 정적 HTML (2026-09-19 연결. xlsx.js·Google Fonts를 CDN에서 로드) |
| `koaudrep` | 국문감사보고서 대사검증 | `/apps/ko-audit-recon.html` | 정적 HTML (**Pyodide CDN** 사용 — 첫 실행 시 인터넷 필요) |
| `enaudrep` | 영문감사보고서 대사검증 | `/apps/en-audit-recon.html` | 정적 HTML (Pyodide CDN) |
| `enwriter` | 영문감사보고서 자동작성 | `/apps/en-audit-write.html` | 정적 HTML (Pyodide CDN) |
| `room` | 회의실 예약 | `extUrl(3500,3501)+'?embed=1'` → https면 `https://<접속호스트>:3501/?embed=1` (`embed=1`은 회의실 앱의 임베드 모드: 자기 상단 바를 숨김, 2026-09-19) (2026-09-19: IP 고정에서 접속 호스트 따라가기로. VPN처럼 다른 호스트로 열면 크롬이 '공용 페이지→사설망' 차단) | **외부 포트(https, MS SSO 적용) + `auth:'popup'`.** MS 로그인 페이지는 iframe 안에서 열리지 않으므로, 첫 열기 때 창 안에 안내(`.auth-gate`)를 띄우고 "로그인 창 열기"로 팝업에서 로그인 → 팝업이 닫히면 iframe 로드. 같은 호스트라 로그인 쿠키가 iframe에도 적용됨. 완료 표시는 `sessionStorage`(`sh-portal:auth:room`, 탭 세션 동안 유지). 포털을 https(8080)로 열어야 동작 |
| `expense` | 경비청구 | `extUrl(7010,7011)` → http면 `http://<접속호스트>:7010/`, https면 `https://<접속호스트>:7011/` (2026-09-20 7000/7005 에서 옮김 — 경비청구가 7011(HTTPS) → 7010(앱) 구성으로 전환) | **외부 포트 + `auth:'popup'` + `authAlways:true`.** 회의실과 같은 팝업 로그인 방식이지만 **포털과 다른 Entra 앱**이라 MS 로그인이 대화형이고, iframe 안에서는 `X-Frame-Options: DENY` 로 막힌다(실제로 "login.microsoftonline.com 연결을 거부했습니다" 발생). 그래서 포털이 SSO 로그인 상태여도 안내 화면을 건너뛰지 않는다. 한 번 팝업 로그인하면 탭 세션 동안 바로 열림. 창 1280×900 (콘텐츠를 재보지 못해 임시값). 2026-09-20 연결 |

- `url`이 있는 앱은 `openApp()`에서 목업 `body()` 대신 `frameBody()`가 만든 iframe 창으로 열립니다. **창 크기는 `APPS`의 `w`×`h` 그대로**(실제 앱은 `w:1600,h:1000`), 화면이 더 작으면 화면에 맞춰 줄입니다. 2026-09-20에 원본 디자인의 `×1.3` 배율을 뺐습니다(1600×1000에 1.3을 곱하니 어떤 화면에서도 꽉 차 너무 컸음). **창이 크거나 작으면 해당 앱의 `w`·`h`만 고치면 됩니다.**
- **앱별 창 크기**(2026-09-20): `apps/` 4종은 페이지 콘텐츠 폭을 헤드리스로 재서 맞췄습니다 — `jet` 1420×920(콘텐츠 1350), `koaudrep` 860×900(760), `enaudrep` 880×900(780), `enwriter` 920×900(820). 이 페이지들은 가운데 고정 폭 칼럼이라 1600으로 열면 좌우가 텅 빕니다. NAS에만 있는 앱(`shaudit`·`k1118`·`fin`·`xbrl`·`room`)은 재보지 못해 1600×1000 그대로입니다.
- 주소 해석은 `appUrl()`: NAS(nginx)에서 열면 상대 경로, 파일을 로컬에서 열면 `NAS_BASE`(`http://192.168.100.25:8080`) 절대 주소.
- 로딩 스피너 `.app-loading`은 iframe `load` 시(최소 0.5초 노출) 또는 15초 후 제거.
- 창 이동·크기조정 중에는 `body.winDrag`로 모든 iframe의 포인터 이벤트를 끊습니다.
- 나머지 앱(리뷰함·TAX Agent·JET Tool 등)은 목업 창입니다. 실제 서비스가 생기면 해당 항목에 `url:`만 넣으면 됩니다.
- **AI 활용사례 그룹(2026-09-19)**: 사용자 제공 아이콘 8종(`icons/aicase-*-20260919.webp`, 512px WebP로 변환해 `PORTAL_ASSETS`에 내장)으로 새 앱 6개 추가 — `ifrs18wp`(IFRS18_wp, 기존 `k1118`과 별개), `startend`(Start and End: JET·LEAD·DSD입력), `qms`, `prerisk`(계약전위험평가조서), `enreport`(영문보고서 초안), `vuln`(취약점 진단), 그리고 2차분 `koaudrep`(국문감사보고서 대사검증)·`enaudrep`(영문감사보고서 대사검증)·`enwriter`(영문감사보고서 자동작성). 아이콘은 사용자가 누끼 처리한 512px 투명 PNG(portal_all_icons_transparent.zip) → WebP(알파). 기존 `toolkit`→"Staff Toolkit", `markettool`→"베타·주가변동성 산출 도구"로 이름·아이콘 교체. **홈 기본 배치에는 올리지 않음**(사용자가 직접 배치하기로) — "모든 App" 서랍(카테고리 `ai`)에서 끌어다 놓음.
- **앱 이름·부제 관리자 수정(2026-09-19)**: `downloads/manifest.json` 항목의 `name`·`sub`를 `applyDlManifest()`가 `APPS[id].name/sub`에 덮어씀(원래 값은 `APPS[id]._orig`에 보관, 비우면 복귀). 관리자 화면(설정 → "앱 관리 · 이름 · 다운로드 파일", 프로필 메뉴 "앱 관리")의 각 줄 ✎ → 인라인 입력 → `dlAdminRenameSave()`가 manifest를 PUT. 파일 저장·해제는 name/sub를 보존.
- **SSO 앱**(`auth:'popup'`): `frameBody()`가 iframe에 `src` 대신 `data-src`를 두고 `.auth-gate`를 띄움. `authLogin()`이 팝업을 열고 닫힘을 감지해 `authRelease()`로 iframe을 로드. "이미 로그인했어요"는 게이트를 건너뜀. **포털에 SSO로 로그인한 상태(`USER.sso`)면 게이트를 띄우지 않고 바로 iframe** — 같은 Entra 앱·같은 MS 세션이라 회의실의 MS 리다이렉트가 화면 없이 통과함. 창 제목줄의 자물쇠 버튼(`data-act="relogin"`)이 `authRelogin()` → 팝업 로그인 후 iframe을 새로 불러옴(로그인이 풀려 화면이 빌 때). 다른 SSO 앱이 생기면 항목에 `auth:'popup'`만 추가. **포털과 다른 Entra 앱을 쓰는 앱은 `authAlways:true` 도 같이** — MS 로그인이 대화형이면 iframe 안에서 거부되므로 `USER.sso` 지름길을 타면 안 된다(경비청구 사례).
- **다운로드형 앱**(설치 파일·엑셀 매크로 등): 파일이 있는 앱은 홈·Dock 아이콘 **우측 하단에 작은 다운로드 배지**(`.dlb`)가 붙고 배지를 누르면 `triggerDownload()`. **`url`이 없는(창이 없는) 앱은 아이콘 본체를 눌러도 바로 내려받음**(`dlDirect()`, `openApp()` 첫머리 분기. 2026-09-19). `url`이 있는 앱은 아이콘 본체 = 창, 배지 = 다운로드. 파일은 NAS `/volume1/sh-pf/docker/nginx-html/portal/downloads/`에 DSM File Station으로 올립니다(nginx 루트가 `portal/`이라 설정 변경 불필요). 편집 모드(`body.editing`)에서는 배지를 숨깁니다.
  - **목록은 NAS의 `portal/downloads/manifest.json`로 관리**(2026-09-18): `{"jet":{"file":"JET_Tool_v1.2.xlsm","ver":"1.2","name":"(선택)","sub":"(선택)"}}` 형식. `loadDlManifest()`가 포털이 열릴 때 한 번 읽어 `APPS[키].dl`을 채우고 홈·Dock을 다시 그림. **파일 올리고 json 한 줄 고치면 포털 재배포 없이 배지가 붙음.** 404·형식 오류면 조용히 무시. `file:""`면 그 앱 배지 끔. 코드의 `dl:{file,ver}` 항목도 여전히 동작(manifest가 덮어씀). 예시·앱 키 표는 `portal-deploy-v5/downloads/README.md`.
  - **관리자 화면**(2026-09-18): 프로필 메뉴 "다운로드 파일 관리"(`data-mact="dladmin"`, `body.is-admin`일 때만 표시) → 설정 창의 `#dlAdmin` 섹션(`dlAdminHtml()`). "파일 선택…→저장"이 `dlApi()`로 **브라우저에서 nginx에 직접** `PUT /downloads/<파일명>` → `PUT /downloads/manifest.json` 하고 `applyDlManifest()`로 즉시 반영. "해제"는 manifest에서 키 제거, "서버의 파일" 목록은 `GET /downloads/`(nginx autoindex JSON), 삭제는 `DELETE`. 쓰기는 nginx가 `/_dlw/downloads/`로 넘겨 `auth_request /oauth2/auth_admin`(oauth2-proxy `?allowed_groups=Admin`)으로 관리자만 통과시킨 뒤 **`sh-dl-writer`(127.0.0.1:4181, `infra/dl-writer/`)로 프록시** — `sh-nginx`는 포털 폴더가 `:ro`라 직접 못 씀(`sso/nginx-default.conf`, 적용 절차 `sso/README.md` 5번). NAS 폴더는 `chmod 777 downloads`(컨테이너 nginx 사용자가 씀).

### 앱을 추가/연결할 때 손대야 하는 곳

1. `const APPS = {` — 항목 추가 (`name, sub, short, bg, w, h`, 실제 앱이면 `url`. 다운로드형은 코드보다 NAS `downloads/manifest.json`에 넣는 것을 우선)
2. `const APP_CAT` — 카테고리 (`audit`/`tax`/`admin`/`ai`/`adv`)
3. `const APP_ICON` — `ICONS`의 그림 키 매핑 (없으면 `short` 글자 타일로 표시)
4. 홈 기본 배치에 올리려면 `LAYOUT_DEFAULT` **그리고** `finalMemory` 안의 JSON 스냅샷 **둘 다**에 `{"k":"a","id":"<앱키>",r,c,rs,cs}` 추가. `finalMemory`가 localStorage 없을 때의 실제 기본값이라 여기 빠지면 홈에 안 나옵니다. 그룹(`k:"z"`) 칸 범위 안에 놓아야 그 그룹에 속합니다.

### 주요 동작 코드

- `openApp(id, origin)` / `closeApp` / `minApp` / `maxApp` / `snapTo` — 창 시스템. `wins` Map이 열린 창 상태.
- `renderGrid()` / `renderDock()` / `saveLayout()` / `loadLayout()` — 홈 배치. 저장 키는 `store`가 `sh-final-20260916:` 접두어로 localStorage에 씀.
- **Dock = 최근 사용한 앱 4개** (`DOCK_RECENT=true`, `DOCK_N=4`, 2026-09-17). `openApp()`·`triggerDownload()`·Dock의 메모 클릭이 `noteRecent(id)`를 불러 맨 앞으로 올리고 `sh-portal:<id>:recent` 키에 저장. 4개가 안 차면 `DOCK_DEFAULT`(리뷰함·일정·팀·메모)로 채움. 칼(`ai`)은 제외. 이 모드에서는 Dock 아이콘 드래그·Dock에 놓기가 꺼져 있음(`DOCK_RECENT=false`로 되돌리면 예전 수동 Dock).
- `openKal()` / 칼 답변은 키워드 규칙. `USER` 상수가 표시 이름·이메일.
- **SSO 사용자**: 스크립트 맨 앞 `loadSsoUser()`가 `/oauth2/userinfo`를 **동기 XHR**로 읽어 `USER`를 덮어씀(id·mail=`preferredUsername`(UPN) 소문자, name=`email` 항목 — oauth2-proxy 설정 `OIDC_EMAIL_CLAIM=name` 으로 표시 이름을 email 자리에 실음. `user`는 sub 라 쓰지 않음, admin=`groups`에 `Admin`, sso=true). 저장 키(`LKEY`·`MKEY`·`RKEY`·`KKEY`)가 `USER.id`로 만들어지므로 **계정별 배치**가 됨. 프록시가 없으면(404·로컬 파일) 목업 윤길배 유지. `paintUser()`가 인사말·프로필 버튼·프로필 카드에 반영하고 `body.is-admin`/`is-sso` 클래스를 붙임.
- **내 홈 배치 슬롯 — NAS 저장**(2026-09-20): **저장**은 상태 표시줄의 "현재 배치 저장" 버튼(`#laySaveBtn`, 배치 초기화 왼쪽) → 작은 플로팅창(`#layPop`)에서 슬롯 1~5 중 하나를 골라 이름 붙여 저장. 두 버튼 모두 **저장하지 않은 변동사항이 있을 때만** 나타남(`paintLayActions()`): 슬롯에 저장하거나 슬롯을 불러오면 그 상태가 기준(`layBase`, 저장 키 `BKEY`)이 되어 버튼이 사라지고, 다시 옮기면 나타남. 한 번도 저장한 적 없으면 기준은 기본 배치. 이미 기본 배치면 "배치 초기화"는 숨김(되돌릴 게 없으므로). **불러오기·삭제**는 그대로 프로필 메뉴 "내 홈 배치 (저장 · 불러오기)"(`data-mact="layhome"`) → 설정 창의 `#layHome` 섹션. **계정마다 최대 5개**(`LAY_MAX`) 슬롯에 이름을 붙여 저장하고, 다른 PC에서 로그인해도 그대로 불러옴. 배치·Dock·배경·그룹·최근 앱만 저장하고 **메모는 넣지 않음**(불러와도 메모는 그대로).
  - 주소는 항상 `/layouts/me.json` 하나. **실제 파일은 nginx 가 로그인 계정(`X-Auth-Request-Preferred-Username`)으로 정하므로 남의 배치는 읽지도 덮어쓰지도 못함**(`sso/nginx-default.conf` 의 `location = /layouts/me.json`). 쓰기는 `/_lw/layouts/` → `sh-dl-writer`(포털 폴더가 `:ro`). 적용 절차는 `sso/README.md` 8번, NAS 폴더는 `chmod 777 layouts`.
  - 플로팅창 코드: `layPopOpen/Close/Render/Save/Place()`, 고른 슬롯은 `layPopSel`(null이면 새 슬롯). CSS 클래스는 전역 `.empty`·`.hd`·`.no`·`.cnt`·`.x`와 부딪혀서 **전부 `lp-` 접두어**를 붙였음(`.lp-sl`·`.lp-on`·`.lp-empty`…). 새로 넣을 때도 접두어 유지할 것.
  - 코드: `layFetch()`(GET, 404면 빈 목록) · `layPut()`(PUT) · `laySaveSlot(name,replaceId)`(덮어쓰기는 기존 이름 유지) · `layApplySlot()`(기존 `portalBackupValidate()`로 검증 후 `store.set` → 새로고침) · `layDeleteSlot()` · `layRender()`. 설정 창을 열 때 `layRefresh()`.
  - **파일로 주고받기**(`portalBackupDownload/Import`, `data-portal-backup`)는 같은 섹션 안에 링크로 남겨둠 — 메모까지 포함한 전체 백업이 필요하거나 NAS 저장이 안 될 때 쓰는 폴백.
- 프로필 메뉴 "로그아웃": SSO면 `ssoLogout()` → `/oauth2/sign_out?rd=<MS logout>` → 포털 복귀. 아니면 토스트만.

---

## 배포 방법

**기본: `portal-deploy-v5/update-all-from-github.bat`** (2026-09-19 신설. Windows PC에서 더블클릭, **비밀번호 1회로 포털 + 앱 페이지 전부**)

포털 `index.html`과 `apps/*.html` 4종을 GitHub에서 받아 각각 검사(크기·`<title>`·`</html>`)한 뒤, **tar로 묶어 ssh 한 번**에 보냅니다. 원격에서 풀고 → 크기 대조 → `index.html.bak_타임스탬프` 백업 → 교체 → 앱 권한(`chmod 644`) 정리 → 백업 최신 5개만 유지. 크기가 안 맞으면 아무것도 바꾸지 않습니다(`index.html.new` 삭제 후 종료). Windows 10 1803+ 내장 `tar.exe` 사용.

아래 두 개는 **예비**(tar가 없거나 합본이 실패할 때)로 남겨둡니다.

**예비 1: `portal-deploy-v5/update-portal-from-github.bat`** (포털만, 비밀번호 1회)

1. GitHub `claude/awesome-hopper-cmd4wg` 브랜치의 `portal-deploy-v5/index.html`을 raw로 내려받음 (캐시 우회)
2. 검사: 200KB 이상 · `<title>SH Portal` 포함 · `</html>`로 끝남. 하나라도 실패하면 배포 안 함
3. ssh 한 번(비밀번호 1회)으로 NAS에 전송 → 바이트 수 대조 → 원본 `index.html.bak_타임스탬프` 백업 → 교체. 크기 불일치면 아무것도 안 바꿈
4. NAS의 백업은 **최신 5개만 유지**(`MAX_BAK`), 더 오래된 `index.html.bak_*`는 자동 삭제. 실행 끝에 남은 백업 목록과 롤백 명령을 출력

즉 흐름은 **여기서 푸시 → 사용자가 PC에서 .bat 더블클릭 → 비밀번호 1회**. 배포 브랜치를 바꾸려면 .bat 상단 `GH_BRANCH`만 수정(합본은 `GH_BRANCH`·`APPS` 목록). **앱 HTML을 `apps/`에 추가하면 합본 .bat의 `APPS` 변수에도 파일명을 넣어야 배포됩니다.** nginx 재시작 불필요(정적 파일).

**예비 2: `portal-deploy-v5/update-apps-from-github.bat`** — 앱 페이지만 올립니다(ssh 폴더 준비 → `scp -O`, 비밀번호 2회).

nginx는 `location /`의 root가 `portal/`이라 `/apps/`도 자동 서빙되고 SSO 게이트가 그대로 걸립니다(설정 변경 불필요).

**예비 3: `portal-deploy-v5/deploy-portal-PC.bat`** — .bat과 같은 폴더의 `index.html`(로컬 클론본)을 scp로 올림. GitHub에 접근이 안 될 때만.

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
- **MS SSO 적용 완료 (2026-09-18 새벽).** NAS에 `sh-oauth2-proxy` 컨테이너 가동(`/volume1/sh-pf/docker/sh-platform/sso/`), nginx `default.conf`는 SSO판으로 교체됨(백업 `default.conf.bak_20260917_224603`). `https://192.168.100.25:8081/` 접속 시 Microsoft 인증 → 포털에 로그인 사용자 이름(한글)·이메일 표시 확인. Entra 앱은 새로 만든 **"BDO Korea Portal"**(클라이언트 ID `68c537dc-…`), 회의실 앱과 별개.
- **관리자 판별 해결(2026-09-18)**: 프로필 카드에 "김진규 [Jinkyu Kim] · 관리자" 표시 확인. 원인은 엔터프라이즈 앱 "사용자 및 그룹"의 배정이 App Role이 아닌 **"기본 액세스"**로 잡혀 있던 것 → 배정을 삭제하고 역할 `Admin`을 골라 다시 배정하니 `roles` 클레임이 실림. 같은 증상이 나면 이 순서로: 앱 등록 → 개요의 "로컬 디렉터리의 관리되는 애플리케이션" 링크로 **그 클라이언트 ID의** 엔터프라이즈 앱에 들어가 → 사용자 및 그룹에서 배정 삭제 → "사용자/그룹 추가"에서 역할을 명시적으로 선택해 재배정 → 포털 로그아웃 후 재로그인. 진단용으로 열었던 `https://jwt.ms` 리디렉션 URI와 "ID 토큰" 암시적 허용은 제거함.
- **미해결 ①**(닫힘) — 위 항목으로 대체.
- **미해결 ②**: 인증서가 자체서명이라 브라우저에 "안전하지 않음". 방향(`portal.bdo.kr` DNS + Let's Encrypt / Synology DDNS / 사내 CA) 미정.
- **DB 백업 수리 완료(2026-09-18)**: `sh-db-backup`을 host 모드(`127.0.0.1:5433`)로 바꾸고 `scripts/backup.sh`를 `infra/db-backup/backup.sh`로 교체. 수동 백업 성공·cron(02:00) 등록 확인. `sh_platform` DB는 **테이블이 없는 빈 상태**(어떤 앱도 아직 DB를 쓰지 않음). 자세한 경위는 `infra/db-backup/README.md`.
- **미확인**: `.env`·`.env.sso` `chmod 600` 실행 여부. Entra 앱 이름은 "BDO Korea Portal"로 정리됨.
- **포트 교체(2026-09-18)**: 외부에서 8080만 열려 있어 정식 주소를 `https://192.168.100.25:8080`으로. DSM 역방향 프록시 `HTTPS 8080 → http://localhost:8081`, nginx 컨테이너 `listen 8081`(301 대상·`X-Forwarded-Host`·oauth2-proxy `REDIRECT_URL`·Entra 리디렉션 URI·포털 `NAS_BASE` 모두 8080). 절차는 `sso/README.md` 6번. 아래 8081 서술은 교체 전 기록. **VPN에서 로그인이 `http://…:8081/oauth2/start`로 튀어 멈추던 문제**는 nginx `absolute_redirect off`로 해결(`@signin`의 302가 절대 주소로 나가 8081이 막힌 망에서 끊겼음). **VPN에서 포털 로그인 확인 완료.** **VPN에서 XBRL·회의실까지 완료(2026-09-19)**: 방화벽 세 곳(SSL-VPN FortiGate 정책 `SSLVPN_To_seoul_NAS` → 서울 FortiGate IPsec 터널→내부망 정책 → DSM 방화벽)에 각각 TCP 4001·3501 허용 추가. 그 뒤 회의실만 크롬 "공용 페이지에서 사설망 연결 차단"으로 막혀 `room.url`을 IP 고정에서 `extUrl(3500,3501)`(접속 호스트 따라가기)로 변경해 해결. 새 포트를 열 땐 이 세 곳을 모두 거쳐야 함.
- HTTPS 전환 완료(2026-09-17). DSM 역방향 프록시 8081 → 8080 동작 확인. 방식: DSM 역방향 프록시가 https를 종단 — `HTTPS 8081 → http://localhost:8080`(포털·감사플랫폼·1118호·금융기관 조회, WebSocket 헤더 켜기), `HTTPS 4001 → http://localhost:4000`(XBRL). 우리 nginx 컨테이너·compose는 그대로. 포털은 `extUrl()`로 http/https 양쪽에서 동작하므로 파일 수정 없이 두 주소 모두 사용 가능. 인증서는 DSM 제어판 → 보안 → 인증서에서 다른 https 페이지와 같은 것을 배정. 회의실(:3501 SSO)은 https로 바꿔도 iframe 불가(MS 로그인 페이지 프레임 거부) — 정적 HTML로 대체.

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
   - 결정(2026-09-17): 관리자 판별은 **Entra App Role `Admin`**(그룹 `SH-Platform-Admins` 배정), 1차 게이트는 포털·감사·1118호·금융기관(XBRL·회의실은 2차), 홈 배치는 **계정별**. HTTPS는 8080으로 확보됨(2026-09-18 교체 전 8081). 구성 파일은 `sso/`에 있고 포털 코드는 반영 완료. **2026-09-18 NAS 적용·관리자 판별까지 완료**(적용 절차는 `sso/README.md`). 남은 것: XBRL(`/xbrl/`)·회의실 2차 게이트, 인증서(미해결 ②).
2. (완료) 포털 `USER`를 SSO 사용자로 채우고 로그아웃 연결 — NAS 적용 후 실제 동작 확인 필요
3. 홈 위젯·목업 앱·칼 답변을 실데이터로 연동 (백엔드 필요)
4. `sh_audit` 아이콘이 'Ai' 그림이라 SH Audit Platform과 안 어울림 — 전용 아이콘 교체 검토

---

## 로컬에만 있는 것 (이 저장소에 없음)

1. `docker-compose.yml` **운영본**(host 모드 수정본) — NAS에만 존재. 필요 시 `scp -O -P 3907 jinkyu.kim@192.168.100.25:/volume1/sh-pf/docker/sh-platform/docker-compose.yml .`
2. `.env` (실제 DB 비밀번호)
3. XBRL Comparator(:4000) 소스 — `C:\6.Claude_Cowork\김진솔 MANAGER님\` 폴더
4. 1118호 최신 배포본(`UPDATE_20260420_IFRS18_Analyzer`), 금융기관 조회·DSD 배포 패키지 — 원본 zip / OneDrive 폴더
