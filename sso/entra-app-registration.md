# Entra ID 앱 등록 절차 — SH Portal SSO

테넌트 `bdo.kr` · 등록 화면: https://entra.microsoft.com → **ID → 애플리케이션 → 앱 등록**
> **결정(2026-09-17): 회의실 예약 시스템(:3501)의 앱 등록을 그대로 재사용합니다.** 새 앱을 만들지 않고 그 앱에
> ① 리디렉션 URI `https://192.168.100.25:8080/oauth2/callback` 추가 ② 앱 역할 `Admin` 추가·그룹 배정 ③ 포털용 클라이언트 비밀 새로 생성
> 만 하면 됩니다. 같은 앱이라 포털 로그인 후 회의실이 창 안에서 화면 없이 통과됩니다. 아래 1절의 '앱 등록'은 건너뛰고 개요에서 ID만 복사하세요.

## 1. 앱 등록
| 항목 | 값 |
|---|---|
| 이름 | `SH Portal` |
| 지원되는 계정 유형 | **이 조직 디렉터리의 계정만** (단일 테넌트) |
| 리디렉션 URI | 플랫폼 **웹**, `https://192.168.100.25:8080/oauth2/callback` (2026-09-18 포트 교체. 그 전엔 8081) |

등록 후 **개요** 화면에서 복사:
- 애플리케이션(클라이언트) ID → `.env.sso` 의 `OAUTH2_PROXY_CLIENT_ID`
- 디렉터리(테넌트) ID → `.env.sso` 의 `TENANT_ID`

## 2. 클라이언트 비밀
**인증서 및 비밀 → 클라이언트 비밀 → 새 클라이언트 비밀** (설명 `sh-portal-oauth2-proxy`, 만료 24개월)
→ 생성 직후 **값(Value)** 열을 복사 (다시 볼 수 없음) → `OAUTH2_PROXY_CLIENT_SECRET`
> 만료일을 달력에 적어 두세요. 만료되면 전 직원 로그인이 막힙니다. 갱신은 새 비밀 만들고 `.env.sso` 교체 → `docker-compose -f docker-compose.sso.yml up -d` 로 재시작.

## 3. 토큰 구성 (이름·이메일 클레임)
**토큰 구성 → 선택적 클레임 추가 → ID** 에서 체크: `email`, `preferred_username`, `upn`
(oauth2-proxy 는 `preferred_username`(UPN)을 이메일로, `name`을 표시 이름으로 씁니다. `name`은 기본 포함.)

## 4. 관리자 판별 — 앱 역할(App Role)
**앱 역할 → 앱 역할 만들기**
| 항목 | 값 |
|---|---|
| 표시 이름 | `Admin` |
| 허용되는 멤버 형식 | 사용자/그룹 |
| 값 | `Admin` ← **정확히 이 문자열** (포털이 `groups` 에 `Admin` 이 있는지로 판별) |
| 설명 | SH Portal 관리자 |

그다음 **엔터프라이즈 애플리케이션 → SH Portal → 사용자 및 그룹 → 사용자/그룹 추가**
→ 그룹 `SH-Platform-Admins` 선택, 역할 `Admin` 배정.
(관리자가 아닌 직원은 아무 역할 없이 로그인만 하면 됩니다. 역할이 없어도 로그인은 허용됩니다.)

## 5. 접근 대상 제한 (선택)
전 직원이 아니라 일부만 쓰게 하려면 **엔터프라이즈 애플리케이션 → SH Portal → 속성 → "할당 필요"** 를 예로 바꾸고, 사용자 및 그룹에 허용 그룹을 추가합니다. 기본은 테넌트 전원 허용.

## 6. API 권한
기본으로 들어 있는 **Microsoft Graph → User.Read (위임)** 이면 충분합니다. 관리자 동의는 필요 없습니다(로그인 시 사용자 동의 화면이 한 번 뜰 수 있음. 전사 동의로 없애려면 "OO에 대한 관리자 동의 허용" 클릭).

## 정리: `.env.sso` 에 들어갈 값
```
OAUTH2_PROXY_OIDC_ISSUER_URL=https://login.microsoftonline.com/<테넌트 ID>/v2.0
OAUTH2_PROXY_CLIENT_ID=<애플리케이션(클라이언트) ID>
OAUTH2_PROXY_CLIENT_SECRET=<클라이언트 비밀 값>
OAUTH2_PROXY_REDIRECT_URL=https://192.168.100.25:8080/oauth2/callback
OAUTH2_PROXY_COOKIE_SECRET=<아래 명령으로 생성>
```
쿠키 비밀 생성 (PC 또는 NAS 아무 데서나):
```
python3 -c "import secrets,base64;print(base64.urlsafe_b64encode(secrets.token_bytes(32)).decode())"
```
