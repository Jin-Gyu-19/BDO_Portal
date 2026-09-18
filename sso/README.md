# SH Portal SSO — 적용 순서 (oauth2-proxy + nginx auth_request + Entra ID)

## 구성도
```
브라우저 ──https 8080──▶ DSM 역방향 프록시 ──http 8081──▶ sh-nginx (host 모드)   ※ 2026-09-18 포트 교체(외부 접속용). 그 전엔 https 8081 → http 8080
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
- [ ] `https://192.168.100.25:8080/` 로 포털이 열리고 인증서 경고가 없거나(정식 인증서) 전 직원이 감수 가능
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
1. 시크릿 창에서 `https://192.168.100.25:8080/` → Microsoft 로그인 → 포털 홈, 우측 상단에 **본인 이름** 표시
2. 감사플랫폼 · 1118호 · 금융기관 조회 창이 열림 (금융기관 조회는 WebSocket 확인)
3. `SH-Platform-Admins` 멤버로 로그인 → 프로필 메뉴에 "· 관리자"
4. 프로필 메뉴 → 로그아웃 → Microsoft 로그아웃 → 포털로 돌아오면 다시 로그인 요구
5. `http://192.168.100.25:8081/` 로 열면 자동으로 https 8080 으로 넘어감
6. `curl -s http://127.0.0.1:8080/health` → `{"status":"ok",...,"version":"v6-sso"}`

## 5. 다운로드 파일 쓰기 허용 (2026-09-18 추가 — 포털 "다운로드 파일 관리")
포털 설정 창의 **다운로드 파일 관리**(관리자 전용)가 브라우저에서 PUT/DELETE 한다.
`sh-nginx` 는 포털 폴더를 **읽기 전용(:ro)** 으로 마운트하고 있어 직접 못 쓴다(확인: `sudo docker inspect sh-nginx --format '{{range .Mounts}}{{.Destination}} rw={{.RW}}{{"\n"}}{{end}}'` → `/usr/share/nginx/html rw=false`).
compose 의 nginx 는 건드리지 않으므로, `downloads` 폴더만 쓰기 가능하게 마운트한 미니 nginx **`sh-dl-writer`**(host 모드, `127.0.0.1:4181`, `infra/dl-writer/`)를 띄우고
메인 nginx 의 `/_dlw/downloads/` 가 `auth_request /oauth2/auth_admin`(oauth2-proxy `?allowed_groups=Admin`) 통과 후 거기로 프록시한다. 읽기·목록(JSON)은 메인 nginx 의 `/downloads/`.
```
# (1) downloads 폴더: 컨테이너의 nginx 사용자가 쓸 수 있게
cd /volume1/sh-pf/docker/nginx-html/portal && mkdir -p downloads && sudo chmod 777 downloads && sudo chmod 666 downloads/manifest.json 2>/dev/null; ls -ld downloads
# (2) dl-writer 띄우기
sudo mkdir -p /volume1/sh-pf/docker/sh-platform/dl-writer && cd /volume1/sh-pf/docker/sh-platform/dl-writer
RAW=https://raw.githubusercontent.com/Jin-Gyu-19/BDO_Portal/claude/awesome-hopper-cmd4wg/infra/dl-writer
sudo curl -fsSL -o docker-compose.dl-writer.yml $RAW/docker-compose.dl-writer.yml && sudo curl -fsSL -o dl-writer.conf $RAW/dl-writer.conf
sudo docker-compose -f docker-compose.dl-writer.yml up -d && sleep 3 && sudo docker ps --filter name=sh-dl-writer && sudo docker logs --tail 5 sh-dl-writer
# (3) 메인 nginx 설정 교체 (3번 절차와 동일: 백업 → 복사 → 검사 → reload)
cd /volume1/sh-pf/docker/sh-platform/nginx && sudo cp default.conf default.conf.bak_$(date +%Y%m%d_%H%M%S)
curl -fsSL -o /tmp/default.conf https://raw.githubusercontent.com/Jin-Gyu-19/BDO_Portal/claude/awesome-hopper-cmd4wg/sso/nginx-default.conf && sudo cp /tmp/default.conf default.conf
sudo docker exec sh-nginx nginx -t && sudo docker exec sh-nginx nginx -s reload
```
확인: 포털 → 프로필 메뉴 → "다운로드 파일 관리" → 파일 선택 → 저장 → 아이콘에 배지. 관리자가 아니면 메뉴 자체가 안 보이고, 직접 PUT 해도 401.
한도: 파일 500MB(`client_max_body_size`, 양쪽 nginx). DSM 역방향 프록시(8080)에 별도 본문 한도가 있으면 413 이 날 수 있음 — 그때 DSM 쪽을 조정.
되돌리기: `cd /volume1/sh-pf/docker/sh-platform/dl-writer && sudo docker-compose -f docker-compose.dl-writer.yml down` (메인 nginx 는 그대로 둬도 저장 시 502 만 남).

## 6. 포트 교체 절차 (2026-09-18: https 8081→8080, nginx http 8080→8081)
외부에서 8080 만 열려 있어 정식 주소를 `https://192.168.100.25:8080` 으로 바꿨다. 두 포트가 자리를 맞바꾸므로 DSM 규칙을 한 번에 못 바꾸고 임시 포트를 거친다.
1. Entra 앱 등록 → 인증 → 리디렉션 URI `https://192.168.100.25:8080/oauth2/callback` **추가**(옛것은 확인 후 삭제)
2. DSM 제어판 → 로그인 포털 → 고급 → 역방향 프록시: 포털 규칙(https 8081 → localhost:8080)의 **소스 포트를 임시로 8090** 으로 저장
3. NAS: `.env.sso` 의 `OAUTH2_PROXY_REDIRECT_URL` 포트를 8080 으로, oauth2-proxy 재생성, nginx `default.conf` 교체(listen 8081) → `nginx -t` → reload
   ```
   cd /volume1/sh-pf/docker/sh-platform/sso && sudo sed -i 's#:8081/oauth2/callback#:8080/oauth2/callback#' .env.sso && sudo grep REDIRECT_URL .env.sso
   sudo docker-compose -f docker-compose.sso.yml up -d --force-recreate && sudo docker logs --tail 3 sh-oauth2-proxy
   cd ../nginx && sudo cp default.conf default.conf.bak_$(date +%Y%m%d_%H%M%S)
   curl -fsSL -o /tmp/default.conf https://raw.githubusercontent.com/Jin-Gyu-19/BDO_Portal/claude/awesome-hopper-cmd4wg/sso/nginx-default.conf && sudo cp /tmp/default.conf default.conf
   sudo docker exec sh-nginx nginx -t && sudo docker exec sh-nginx nginx -s reload
   ```
4. DSM 역방향 프록시: 그 규칙을 **소스 https 8080 → 대상 http localhost:8081** 로 저장
5. 확인: 시크릿 창 `https://192.168.100.25:8080/` → MS 로그인 → 홈. `http://192.168.100.25:8081/` → 8080 으로 301
6. 포털 `.bat` 재배포(`NAS_BASE` 갱신), Entra 의 옛 8081 URI 삭제

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
