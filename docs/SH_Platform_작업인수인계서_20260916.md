# SH Platform — 작업 인수인계서 / 코드 변경 내역서

**작성일** 2026-09-16
**대상** ① 개발 담당자 전달용 ② claude.ai(클라우드)에서 작업 이어가기용 컨텍스트
**프로젝트** 성현회계법인 AX 대전환 — SH Platform (NAS 기반 사내 감사 플랫폼)

---

## 1. 현재 시스템 구성 (NAS)

Synology DS1019+ (`192.168.100.25`, SSH 포트 `3907`) 위에서 Docker로 운영됩니다. 메인 스택은 `/volume1/sh-pf/docker/sh-platform/docker-compose.yml` 하나로 묶여 있고, XBRL Comparator만 별도 컨테이너로 독립 운영됩니다.

| 컨테이너 | 역할 | 포트 |
|---|---|---|
| `sh-nginx` | 리버스 프록시 · 포털/정적앱 서빙 | **8080** (host 네트워크 모드) |
| `sh-streamlit` | 금융기관 조회 앱 (Streamlit) | 8501 (내부) |
| `sh-postgres` | PostgreSQL | 5432 (localhost) |
| `sh-redis` | 캐시 | 6379 (localhost) |
| `sh-db-backup` | 매일 02시 DB 백업 | — |
| **XBRL Comparator** | 별도 독립 컨테이너 | **4000** |

### 접속 경로

| URL | 내용 |
|---|---|
| `http://192.168.100.25:8080/` | SH Portal (메인 진입점) |
| `/audit/` | SH Audit Platform v4 (정적 HTML) |
| `/ifrs18/` | K-IFRS 1118호 분석기 (정적 HTML) |
| `/data/` | 금융기관 조회 (Streamlit 프록시) |
| `http://192.168.100.25:4000/` | XBRL Comparator (포털 외부 포트) |

### NAS 폴더 구조

```
/volume1/sh-pf/docker/
├── sh-platform/              # 메인 compose + nginx 설정
│   ├── docker-compose.yml
│   ├── nginx/default.conf
│   └── streamlit-app/requirements.txt
├── nginx-html/               # nginx 볼륨 마운트 (정적 앱)
│   ├── portal/index.html
│   ├── audit/index.html
│   └── ifrs18/index.html
└── streamlit-apps/           # Streamlit 앱 코드 (/app 으로 마운트)
    ├── default-app.py
    └── user-apps/app.py      # entrypoint.sh 가 이 파일을 실행
```

> ⚠️ **중요 — 인프라 제약 (문서 SH-AX-INFRA-001)**
> Synology Docker는 컨테이너 간 bridge 통신이 동작하지 않습니다. 이 때문에 nginx를 **host 네트워크 모드**로 전환해 `127.0.0.1:8501`로 Streamlit에 접근하도록 구성돼 있습니다. **docker-compose의 nginx 서비스 설정(network_mode, 볼륨 마운트)은 변경하지 마십시오.** 변경 시 전체 서비스 접속이 불가해집니다.

---

## 2. 포털(SH Portal) 구조

포털은 `portal-deploy-v5/index.html` **단일 HTML 파일**이며, 각 앱을 iframe으로 임베드하는 런처 구조입니다. 포털 자체는 백엔드·DB가 없는 정적 파일이고, 대시보드의 통계·프로젝트 목록 등은 **현재 하드코딩된 목업**입니다.

### 앱 연결 방식 (4종)

| 앱 | 연결 방식 | iframe 대상 |
|---|---|---|
| SH Audit Platform | 정적 HTML 동봉 | `/audit/index.html` |
| K-IFRS 1118호 분석기 | 정적 HTML 동봉 | `/ifrs18/index.html` |
| 금융기관 조회 | Streamlit 프록시 | `/data/` |
| **XBRL Comparator** | **외부 포트 직접 연결** | `http://192.168.100.25:4000/` |

XBRL Comparator만 유일하게 **포털에 재구성하지 않고, NAS에서 이미 별도 서비스 중인 `:4000`을 그대로 iframe으로 불러오는** 방식입니다. 따라서 해당 앱을 수정할 때는 `:4000` 컨테이너만 갱신하면 되고 포털은 건드릴 필요가 없습니다. 반대로 `:4000`이 중지되면 포털 카드는 빈 화면이 됩니다.

### 앱을 추가할 때 수정해야 하는 5개 지점

1. 사이드바 항목 (`side-item` + `data-view`)
2. App 그리드 카드 (`app-card` + `data-view`)
3. iframe 뷰어 div (`v-<앱키>` + `<iframe id="<앱키>Frame">` + 로딩 스피너 div)
4. JS frame 상수 (`const xxxFrame = document.getElementById(...)`)
5. JS `APP_URLS` 및 `APP_VIEWS` 매핑

---

## 3. 이번 작업 변경 내역 (코드 변경 내역서)

모든 변경은 `portal-deploy-v5/index.html` 한 파일에 적용되었으며, **배포된 개별 앱(1118호·감사플랫폼·XBRL)의 원본 파일은 일절 수정하지 않았습니다.**

### 3-1. 임시 개발자 백도어 추가

로그인 화면의 로고 점(●)을 **5번 연속 클릭**하면 포털 대시보드로 진입합니다. 클릭 간격이 1.5초를 넘으면 카운트가 초기화됩니다.

현재 일반 사용자는 로그인 시 1118호 앱으로 직행하도록 되어 있어(포털 미완성) 포털 화면 자체를 볼 수 없습니다. 개발·시연 중 포털에 접근하기 위한 임시 수단입니다.

- 위치: `// ── [임시 백도어] ...` 주석 블록 + 로고 점 `id="lcDot"`
- **MS SSO 로그인 구현 완료 후 해당 블록과 `id="lcDot"`를 삭제하면 원복됩니다.**

### 3-2. 금융기관 조회 앱 포털 연결

앱 그리드의 "금융기관 조회" 카드를 다른 앱과 동일한 iframe 뷰어 방식으로 연결했습니다(위 5개 지점 모두 수정). `APP_URLS`는 NAS 접속 시 `/data/`, 로컬 테스트 시 `http://localhost:8501/`로 자동 분기합니다.

### 3-3. 공통 로딩 스피너 추가

Streamlit 앱의 최초 로딩(콜드 스타트)이 수 초 이상 걸려 화면이 멈춘 것처럼 보이는 문제가 있었습니다. 전체 앱 뷰어에 공통 스피너를 추가했습니다.

- CSS: `.app-loading`, `.spinner`, `@keyframes spin`
- 마크업: 4개 앱 뷰어 각각에 오버레이 div
- JS: `go()` 함수에서 최초 로딩 시에만 표시, `iframe load` 완료 시 해제(최소 0.5초 노출로 깜빡임 방지)
- 상단바는 가리지 않도록 `app-viewer-bar`에 `z-index:2` 부여

### 3-4. 1118호 앱 전체 리다이렉트 제거

기존에는 포털에서 1118호를 클릭하면 `window.location.href`로 **페이지 전체가 이동**해 포털을 벗어났고 뒤로가기도 동작하지 않았습니다. 해당 특수 분기를 제거해 다른 앱과 동일하게 **포털 내 iframe**으로 열리도록 변경했습니다(상단 `◀ 포털로 돌아가기` 바 유지).

> 로그인 직후 1118호로 직행하는 흐름(`enterPortal()`)은 **의도된 동작이므로 그대로 유지**했습니다. 일반 사용자 경험은 변경되지 않았습니다.

### 3-5. 배포 스크립트 신규 작성

`deploy-portal-PC.bat` — PC에서 더블클릭 한 번으로 NAS 원본 자동 백업 후 포털 파일을 교체합니다.

**해결한 함정 2가지 (재발 방지를 위해 기록)**

| 문제 | 원인 | 해결 |
|---|---|---|
| 한글 깨짐 / `'REM'은 명령이 아닙니다` 오류 | .bat을 UTF-8로 저장했으나 한글 Windows cmd는 **CP949로 해석** → 주석이 깨지며 파싱 실패 | .bat 내부를 **전부 ASCII(영문)로** 작성 |
| `subsystem request failed on channel 0` | 최신 scp는 SFTP 하위시스템을 사용하는데 **Synology는 SFTP가 기본 비활성** | `scp -O` (구형 SCP 프로토콜 강제) 사용 |

---

## 4. 다른 채팅에서 진행된 관련 작업

| 채팅 | 작업 내용 |
|---|---|
| **Kim Jinsol manager project** | XBRL Comparator를 포털에 연결(위 5개 지점, `:4000` 직접 iframe). 이후 **NAS → Cloudflare 이전** 방안 검토 (정적앱 → Pages, XBRL → Cloudflare Containers, Streamlit → Cloud Run 권장). NAS 성능 한계가 배경. |
| XBRL 관련 세션 | 비교 로그 추출 작업(로그는 NAS 호스트 폴더 위치, `scp -O` 필수), 외부 반출용 안전번들 생성은 **회사명 잔존으로 자체검증 실패** 상태 |
| NAS site deployment | `seminar-realtime` 실시간 공유 백엔드(Python + SQLite, 포트 3500) 제작·테스트 완료, NAS 배포 대기 — *SH Platform과는 별건* |

또한 포털은 다른 채팅에서 **BDO 레드 테마로 리스타일**되었습니다. 본 문서의 변경분은 리스타일 이후에도 모두 유지되고 있음을 확인했습니다.

---

## 5. 산출물 위치

모두 `…\Claude\Projects\윤길배 대표님\윤길배 대표님 클로드 작업\` 하위입니다.

| 경로 | 내용 | 상태 |
|---|---|---|
| `portal-deploy-v5/index.html` | 포털 본체 (위 변경 전부 반영) | **배포 필요** |
| `portal-deploy-v5/deploy-portal-PC.bat` | 포털 원클릭 배포 | 사용 가능 |
| `finance-deploy/` | 금융기관 조회 앱 NAS 배포 패키지 | **미배포** |
| `dsd-deploy/` | DSD↔IXD(XBRL) 앱 배포 패키지 | **보류** (아래 참조) |

### `finance-deploy/` 상세

금융기관 조회 Streamlit 앱을 NAS에 배포하는 패키지입니다. `deploy-finance-PC.bat` 더블클릭 시 업로드 → 백업 → `requirements.txt` 갱신 → **streamlit 컨테이너 1개만 재빌드**까지 자동 수행합니다.

- 추가 의존성: `anthropic`, `PyMuPDF`, `Pillow`
- **easyocr(torch)는 의도적으로 제외** — 스캔 PDF는 Clova OCR(키가 코드에 내장) + Claude Vision으로 처리되어 기능 손실이 사실상 없고, 이미지 용량과 NAS 부하를 크게 줄일 수 있기 때문
- Anthropic API 키는 앱 사이드바에서 **사용자가 직접 입력**하는 구조 (배포물에 키 없음)
- DB 미사용

### `dsd-deploy/` 상세 — ⚠️ 배포 보류 중

`C:\6.Claude_Cowork\김진솔 MANAGER님\dsd_to_ixd`의 FastAPI 앱을 독립 컨테이너(`sh-dsd`, 호스트 포트 4000)로 띄우는 패키지입니다. 개발자 코드는 한 줄도 수정하지 않았습니다.

**보류 사유:** 해당 위치(`:4000`)에 이미 XBRL Comparator가 운영 중입니다. 이 패키지를 그대로 실행하면 포트가 충돌하거나 기존 서비스를 덮어쓸 수 있습니다.

---

## 6. 미완료 작업 / 다음 단계

**① `dsd_to_ixd`와 `:4000` 운영본의 관계 확정 (선행 필요)**
같은 앱인지(=배포 불필요), 새 버전인지(=기존 컨테이너 교체), 별개 앱인지(=다른 포트 + 포털 카드 추가)를 먼저 확인해야 합니다. NAS에서 `docker ps`로 `:4000` 점유 컨테이너를 확인하는 것이 가장 확실합니다.

**② MS SSO 로그인 (관리자/일반 권한 분리)**
- 방식: **oauth2-proxy 컨테이너 + Nginx `auth_request`** (기존 Redis를 세션 저장소로 재활용)
- 권한: Entra ID 보안 그룹 `SH-Platform-Admins` 멤버십으로 관리자 판별, 그 외 전원 일반 사용자
- 범위: 전체 게이트 (미로그인 시 모든 앱 차단)
- 테넌트: `bdo.kr`, 앱 등록 권한 보유
- ⚠️ **선행조건 — HTTPS 필수.** Entra ID는 `localhost` 외 http redirect URI를 허용하지 않으므로, 현재 `http://192.168.100.25:8080`으로는 앱 등록이 불가합니다. NAS에 도메인·인증서 확보가 0단계입니다.

**③ 포털 완성 후 로그인 흐름 전환**
현재 로그인 → 1118호 직행을 → 포털 대시보드 진입으로 되돌리고, 임시 백도어를 제거합니다.

**④ Cloudflare 이전 검토 (선택)**
NAS 성능 한계가 지속되면 정적앱은 Pages, XBRL은 Containers, Streamlit은 Cloud Run으로 분리 이전하는 방안이 검토되었습니다. 단, 외부 노출 시 **인증(Cloudflare Access 등)이 반드시 선행**되어야 합니다. 현재 앱들은 인증 없이 사내망 신뢰를 전제로 하고 있습니다.

---

## 7. 개발자 준수사항

1. **docker-compose의 nginx 서비스 설정을 변경하지 마십시오** (host 모드·볼륨 마운트). Synology 네트워크 제약에 대응한 구성입니다.
2. **서비스 격리** — 변경이 필요한 경우 해당 서비스만 재시작·재빌드하십시오 (예: `docker-compose up -d --build streamlit`). 다른 컨테이너에 영향을 주어서는 안 됩니다.
3. **작업 전 백업** — 본 프로젝트의 모든 배포 스크립트는 타임스탬프 백업과 롤백 명령 출력을 포함합니다.
4. **파일 전송 시 `scp -O`** 필수 (Synology SFTP 비활성).
5. **.bat 스크립트는 ASCII로만** 작성 (CP949/UTF-8 충돌 방지).
6. **포털 HTTPS 전환 시** `http://…:4000` iframe이 mixed-content로 차단됩니다. 이 경우 nginx에 `/xbrl/` 프록시 라우트를 추가하고 포털 iframe을 상대경로로 변경해야 합니다.

---

## 8. claude.ai(클라우드)에서 이어서 작업하기

**자동으로 이어지는 것**
- 계정 메모리 (NAS 배포 격리 원칙 등 프로젝트 맥락)
- 동일 Project의 커스텀 지시 및 프로젝트 지식

**이어지지 않는 것**
- 로컬 파일 접근 — 위 산출물은 로컬 OneDrive 폴더에 있어 웹에서 직접 읽을 수 없습니다. **이 문서와 주요 파일을 Project 지식으로 업로드**하십시오.
- NAS 조작 — SSH·scp·`.bat` 실행·docker 재빌드는 데스크톱 환경에서만 가능합니다.

따라서 클라우드에서는 **기획·문서·코드 생성·검토**를 진행하고, **실제 배포는 데스크톱에서** 수행하는 분업이 적합합니다.

---

*본 문서는 2026-09-16 기준이며, 이후 변경 시 갱신이 필요합니다.*
