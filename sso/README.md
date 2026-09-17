# SH Portal SSO — 적용 순서 (oauth2-proxy + nginx auth_request + Entra ID)

## 구성도
```
브라우저 ──https 8081──▶ DSM 역방향 프록시 ──http 8080──▶ sh-nginx (host 모드)
                                                          │  auth_request /oauth2/auth
                                                          ▼
                                                   sh-oauth2-proxy 127.0.0.1:4180 (host 모드)
                                                          │  세션 → sh-redis 127.0.0.1:6379 (DB 1)
                                                          ▼
                                                   login.microsoftonline.com (테넌트 bdo.kr)
```
- 게이트 대상(1차): 포털 `/`, `/audit/`, `/ifrs18/`, `/data/`, `/uploads/`
- 게이트 밖(1차): XBRL `:4001`, 회의실 `:3501`(자체 SSO)
- 포털은 `/oauth2/userinfo` 로 로그인 사용자를 읽어 이름·이메일 표시, 계정별 홈 배치 저장, App Role `Admin` 이면 관리자 표시
- 로그아웃: 프로필 메뉴 → `/oauth2/sign_out` → Microsoft 로그아웃 → 포털 복귀

## 0. 선행 확인
- [ ] `https://192.168.100.25:8081/` 로 포털이 열리고 인증서 경고가 없거나(정식 인증서) 전 직원이 감수 가능
- [ ] `sh-redis` 컨테이너가 떠 있음 (`sudo docker ps | grep sh-redis`)
- [ ] NAS 가 `quay.io`·`login.microsoftonline.com` 에 나갈 수 있음
- [ ] `sso/entra-app-registration.md` 절차 완료, `.env.sso` 값 5개 확보

## 1. 파일 올리기 (DSM File Station 또는 scp -O)
NAS `/volume1/sh-pf/docker/sh-platform/sso/` 에:
- `docker-compose.sso.yml`
- `.env.sso` (`.env.sso.example` 을 복사해 값 5개 채운 것 — `chmod 600 .env.sso`)

## 2. oauth2-proxy 띄우기 (nginx 는 아직 그대로)
```
ssh -p 3907 jinkyu.kim@192.168.100.25
cd /volume1/sh-pf/docker/sh-platform/sso
sudo docker-compose -f docker-compose.sso.yml up -d
sudo docker logs --tail 30 sh-oauth2-proxy      # "OAuthProxy configured for OpenID Connect Client ID: ..." 가 보이면 정상
curl -s http://127.0.0.1:4180/ping               # OK
```
오류가 나면 대부분 `.env.sso` 값 문제(테넌트 ID·비밀값·쿠키 비밀 길이). 이 단계까지는 사용자 영향 없음.

## 3. nginx 설정 교체 (여기서부터 사용자 영향)
```
cd /volume1/sh-pf/docker/sh-platform/nginx
sudo cp default.conf default.conf.bak_$(date +%Y%m%d_%H%M%S)      # 반드시 백업
# sso/nginx-default.conf 를 이 폴더의 default.conf 로 복사 (File Station 또는 scp -O)
sudo docker exec sh-nginx nginx -t                                # 문법 검사: "syntax is ok / test is successful"
sudo docker exec sh-nginx nginx -s reload                         # 무중단 적용 (검사 실패 시 실행하지 말 것)
```
`nginx -t` 가 실패하면 백업본으로 되돌리고(`sudo cp default.conf.bak_… default.conf`) 오류 문구를 그대로 알려 주세요.

## 4. 확인
1. 시크릿 창에서 `https://192.168.100.25:8081/` → Microsoft 로그인 → 포털 홈, 우측 상단에 **본인 이름** 표시
2. 감사플랫폼 · 1118호 · 금융기관 조회 창이 열림 (금융기관 조회는 WebSocket 확인)
3. `SH-Platform-Admins` 멤버로 로그인 → 프로필 메뉴에 "· 관리자"
4. 프로필 메뉴 → 로그아웃 → Microsoft 로그아웃 → 포털로 돌아오면 다시 로그인 요구
5. `http://192.168.100.25:8080/` 로 열면 자동으로 https 8081 로 넘어감
6. `curl -s http://127.0.0.1:8080/health` → `{"status":"ok",...,"version":"v6-sso"}`

## 롤백 (즉시)
```
cd /volume1/sh-pf/docker/sh-platform/nginx
sudo cp default.conf.bak_<시각> default.conf && sudo docker exec sh-nginx nginx -s reload
```
이것만으로 SSO 이전 상태(게이트 없음)로 돌아갑니다. oauth2-proxy 는 켜 둬도 무해하고, 내리려면
`cd ../sso && sudo docker-compose -f docker-compose.sso.yml down`.

## 운영 메모
- 클라이언트 비밀 만료(24개월) 전 갱신. 만료되면 전원 로그인 불가.
- 세션 12시간(`OAUTH2_PROXY_COOKIE_EXPIRE`). 연장하려면 compose 값 변경 후 `up -d`.
- 관리자 추가/제거는 Entra 의 `SH-Platform-Admins` 그룹 멤버십으로만. 포털 코드 수정 불필요.
- 2차 과제: XBRL 을 nginx `/xbrl/` 경로로 끌어와 게이트 안에 넣기. 회의실은 자체 SSO 유지(팝업 로그인).
