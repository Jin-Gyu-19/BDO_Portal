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
| `design-new/` (예정) | 새 포털 디자인 원본 (PC에서 git으로 올릴 예정) | 배포본에 반영할 재료 |

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

## 포털 구조 (핵심)

`portal-deploy-v5/index.html` — **단일 HTML 파일**. 백엔드·DB·빌드 과정 없음. `fetch`/API 호출이 하나도 없는 정적 파일입니다.

**대시보드의 통계·프로젝트 목록·조서 트리 등은 전부 하드코딩된 목업입니다.** 실데이터 연동은 아직 없습니다. 실제로 동작하는 것은 앱 4개를 iframe으로 여는 런처 기능뿐입니다.

### 연결된 앱 4종

| 앱 키 | 이름 | iframe 대상 | 방식 |
|---|---|---|---|
| `auditapp` | SH Audit Platform | `/audit/index.html` | 정적 HTML |
| `ifrs18app` | K-IFRS 1118호 분석기 | `/ifrs18/index.html` | 정적 HTML |
| `financeapp` | 금융기관 조회 | `/data/` | Streamlit 프록시 |
| `xbrlapp` | XBRL Comparator | `http://192.168.100.25:4000/` | **외부 포트 직접 연결** |

`xbrlapp`만 NAS에서 별도 구동 중인 `:4000` 서비스를 그대로 불러옵니다. 포털에 재구현된 것이 아니므로, 해당 앱을 고칠 일이 있어도 포털은 건드리지 않습니다.

### 앱을 추가/수정할 때 손대야 하는 5곳

1. 사이드바 항목 — `<div class="side-item" data-view="<앱키>">`
2. App 그리드 카드 — `<div class="app-card" data-view="<앱키>">`
3. iframe 뷰어 — `<div class="view" id="v-<앱키>">` 안에 `<iframe id="<앱키>Frame">` + `<div class="app-loading">` 스피너
4. JS 상수 — `const <앱키>Frame = document.getElementById('<앱키>AppFrame')`
5. JS 매핑 — `APP_URLS` 와 `APP_VIEWS` 양쪽 모두

5곳이 하나라도 빠지면 카드가 동작하지 않습니다. 작업 후 반드시 5곳 일관성을 확인하세요.

### 주요 동작 코드

- `go(view)` — 뷰 전환 + iframe 최초 로딩 시 스피너 표시(`viewer.classList.add('loading')`), `iframe load` 완료 시 해제(최소 500ms 노출)
- `exitApp()` — `go('dashboard')` 로 포털 복귀 (각 뷰어 상단 `◀ 포털로 돌아가기` 버튼)
- `enterPortal()` — 로그인 화면에서 호출. **비개발 모드에서는 1118호 앱으로 직접 이동합니다. 이것은 의도된 동작입니다** (포털 미완성이라 일반 사용자에게 노출하지 않음). 임의로 바꾸지 마세요.
- **개발 모드** — URL에 `?dev`를 붙이면 로그인 → 비밀번호 모달 → 대시보드. 비밀번호는 base64 해시(`DEV_PW_HASH`)로 코드에 박혀 있어 보안 수단이 아닙니다. SSO 완료 시 백도어와 함께 정리 대상.
- **임시 백도어** — 로그인 카드의 레드 점(`id="lcDot"`)을 1.5초 이내 간격으로 5번 클릭하면 포털 대시보드 진입. `// ── [임시 백도어]` 주석 블록. **MS SSO 구현 완료 후 이 블록과 `id="lcDot"`를 삭제할 것.**

---

## 배포 방법

```
portal-deploy-v5/deploy-portal-PC.bat   ← 이것만 사용 (Windows PC에서 더블클릭)
```

더블클릭 → NAS 비밀번호 입력 → 원본 자동 백업(`index.html.bak_타임스탬프`) → `portal/index.html`만 교체. nginx 재시작 불필요(정적 파일).

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
한글 Windows의 cmd는 배치파일을 CP949로 해석하므로, UTF-8 한글 주석이 들어가면 파싱이 깨져 `'REM'은 명령이 아닙니다` 류 오류가 발생합니다. (`deploy-portal-PC.bat`는 CRLF 줄바꿈을 유지하세요.)

**6. 배포된 개별 앱 파일(1118호·감사플랫폼·XBRL)은 수정하지 마세요.**
포털 복귀 버튼 등은 전부 포털 쪽 프레임에 있습니다. 개별 앱은 standalone으로도 쓰이므로 포털 관련 코드가 들어가면 안 됩니다.

**7. 비밀번호·키를 저장소에 넣지 마세요.**
`.env`는 NAS에만 있습니다. `infra/reference/docker-compose.yml`에서도 기본 비밀번호 폴백을 제거했습니다.

---

## 현재 상태

- `portal-deploy-v5/index.html`(2026-07-23 판)이 **NAS 배포본보다 최신**입니다. 미배포 변경분이 있으니, 수정 후 `deploy-portal-PC.bat`으로 올리면 그간 작업분이 함께 반영됩니다.
- 포털은 BDO 레드 테마로 리스타일되어 있습니다.
- 롤백은 git 이력 또는 NAS의 `index.html.bak_*`(배포 스크립트가 자동 생성)으로 합니다.
- HTTPS 전환 계획 없음 — 당분간 `http://192.168.100.25:8080` 그대로 운영합니다 (2026-09-16 확인).

### 최근 적용된 변경
1. 임시 백도어(레드 점 5회 클릭 → 대시보드)
2. 금융기관 조회 카드 연결 (5곳)
3. 공통 로딩 스피너 (`.app-loading` + `go()` 연동, 앱 뷰어 4곳)
4. 1118호 전체 리다이렉트 제거 → 포털 내 iframe으로 열림 (뒤로가기 가능)
5. `deploy-portal-PC.bat` 신규 (scp -O 방식)

---

## 남은 작업

1. **MS SSO 로그인 (Entra ID, 테넌트 `bdo.kr`)**
   - 방식: oauth2-proxy 컨테이너 + nginx `auth_request`, 기존 Redis를 세션 저장소로 재활용
   - 권한: Entra 보안그룹 `SH-Platform-Admins` 멤버 = 관리자, 그 외 전원 일반
   - 범위: 전체 게이트(미로그인 시 모든 앱 차단)
   - ⚠️ **선행조건 — HTTPS 필수.** Entra ID는 localhost 외 http redirect URI를 허용하지 않아, 현재 `http://192.168.100.25:8080`으로는 앱 등록 자체가 불가합니다. HTTPS를 안 하기로 한 상태라 이 충돌을 먼저 풀어야 합니다 (도메인·인증서 확보 또는 다른 인증 방식).
2. SSO 완료 후 → 임시 백도어·개발 모드 비밀번호 제거 + 로그인 흐름을 포털 진입으로 전환
3. 포털 대시보드 목업 데이터를 실데이터로 연동 (백엔드 필요)

---

## 로컬에만 있는 것 (이 저장소에 없음)

1. `docker-compose.yml` **운영본**(host 모드 수정본) — NAS에만 존재. 필요 시 `scp -O -P 3907 jinkyu.kim@192.168.100.25:/volume1/sh-pf/docker/sh-platform/docker-compose.yml .`
2. `.env` (실제 DB 비밀번호)
3. XBRL Comparator(:4000) 소스 — `C:\6.Claude_Cowork\김진솔 MANAGER님\` 폴더
4. 1118호 최신 배포본(`UPDATE_20260420_IFRS18_Analyzer`), 금융기관 조회·DSD 배포 패키지 — 원본 zip / OneDrive 폴더
