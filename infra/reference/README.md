# infra/reference — 초기 인프라 구축본 (참고용)

2026-04-07 `nas-deploy/` 패키지에서 가져온 **초기 설계본**입니다. NAS에서 실제로 돌아가는 운영본과는 다릅니다.

| 파일 | 운영본과의 차이 |
|---|---|
| `docker-compose.yml` | nginx가 여기서는 bridge(`sh-net`) + `ports` 매핑이지만, **운영본은 `network_mode: host` + `nginx-html` 볼륨 마운트**입니다 (`docs/SH-AX-INFRA-001_NAS_인프라_변경보고서.md` 참조). 원본에 박혀 있던 기본 DB 비밀번호 폴백은 제거했습니다 (`.env` 필수). |
| `nginx.conf` | 메인 설정. 운영본과 동일한 것으로 알려져 있음 |
| `.env.example` | 환경변수 틀. 실제 `.env`는 NAS에만 있음 |

현행 nginx 라우팅(`default.conf`)은 `portal-deploy-v5/default.conf`가 최신입니다.
운영본 compose가 필요하면 NAS에서 직접 받으세요:

```
scp -O -P 3907 jinkyu.kim@192.168.100.25:/volume1/sh-pf/docker/sh-platform/docker-compose.yml .
```

이 폴더의 파일을 NAS에 그대로 올리지 마세요. SSO(oauth2-proxy) 등 새 서비스를 설계할 때 구조를 참고하는 용도입니다.
