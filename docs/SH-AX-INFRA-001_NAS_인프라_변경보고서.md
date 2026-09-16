# SH Platform — NAS 인프라 변경사항 보고서 & 개발자 요청서

> 원본: `SH_Platform_인프라_변경보고서.docx` (문서번호 **SH-AX-INFRA-001**, v1.0). 저장소에서 읽기 쉽도록 Markdown으로 옮긴 것이며 내용은 원본과 같습니다.

| 항목 | 내용 |
|---|---|
| 문서번호 | SH-AX-INFRA-001 |
| 작성일 | 2026년 4월 8일 |
| 작성자 | 김진규 (NAS 인프라 구축 담당) |
| 수신 | 윤길배 대표 (앱 개발 담당) |
| 버전 | v1.0 |

---

## 1. 개요

본 문서는 성현회계법인 SH Platform NAS 인프라 구축 과정에서 원래 설계(배포 가이드)와 다르게 변경된 사항들을 정리하고, 향후 배포 파일 작성 시 반영해야 할 사항을 요청하기 위해 작성되었습니다.

Synology NAS(DS series) 환경에서 Docker 네트워크가 일반 Linux와 다르게 동작하여, 컨테이너 간 bridge 네트워크 통신이 불가한 문제가 발생했습니다. 이를 해결하기 위해 아래와 같은 변경을 적용하였습니다.

## 2. 환경 정보

| 항목 | 내용 |
|---|---|
| NAS 모델 | Synology DS series (DSM 7.x) |
| NAS IP | 192.168.100.25 |
| SSH 포트 | 3907 |
| Docker Compose 경로 | `/volume1/sh-pf/docker/sh-platform/` |
| 접속 URL | `http://192.168.100.25:8080/` |

## 3. 핵심 문제: Synology Docker 네트워크 제한

Synology NAS의 Docker 구현은 일반 Linux Docker와 달리, bridge 네트워크에서 컨테이너 간 통신이 정상적으로 이루어지지 않습니다.

### 3.1 증상
Nginx 컨테이너에서 Streamlit 컨테이너로 접근 시 타임아웃 발생. 컨테이너 내부에서 자기 자신(`127.0.0.1:8501`)으로는 정상 응답(HTTP 200)하지만, 같은 Docker 네트워크의 다른 컨테이너에서 서비스 이름(`streamlit:8501`), 컨테이너 이름(`sh-streamlit:8501`), 컨테이너 IP(`172.18.0.4:8501`) 어떤 방식으로도 접근이 불가했습니다.

### 3.2 원인
Synology DSM의 Docker 네트워크 스택이 표준 Linux bridge 네트워크와 다르게 구현되어 있어, 컨테이너 간 패킷 라우팅이 되지 않는 것으로 확인됩니다. iptables FORWARD 체인 및 DOCKER-ISOLATION 규칙은 정상이었으나, 실제 패킷 전달이 이루어지지 않았습니다.

### 3.3 해결 방법
Nginx 컨테이너를 **host 네트워크 모드**로 전환하여 NAS의 호스트 네트워크를 직접 사용하도록 변경했습니다. 이를 통해 Nginx가 localhost(`127.0.0.1`)를 통해 Streamlit에 접근할 수 있게 되었습니다.

## 4. 변경사항 상세

### 변경 1: Nginx network_mode 변경
| | |
|---|---|
| 파일 | `docker-compose.yml` (nginx 서비스) |
| 원래 설계 | `networks: - sh-net` (bridge 모드) |
| 변경 후 | `network_mode: host` |
| 사유 | Synology Docker bridge 네트워크에서 컨테이너 간 통신 불가. host 모드로 전환하여 localhost를 통한 접근으로 우회. |

### 변경 2: Nginx listen 포트 변경
| | |
|---|---|
| 파일 | `nginx/default.conf` |
| 원래 설계 | `listen 80;` |
| 변경 후 | `listen 8080;` |
| 사유 | host 모드에서는 Docker의 포트 매핑(8080:80)이 작동하지 않으므로, Nginx가 직접 8080 포트에서 리슨해야 합니다. |

### 변경 3: Nginx upstream 호스트 변경
| | |
|---|---|
| 파일 | `nginx/default.conf` |
| 원래 설계 | `server streamlit:8501;` |
| 변경 후 | `server 127.0.0.1:8501;` |
| 사유 | host 모드에서는 Docker 내부 DNS(서비스명 해석)를 사용할 수 없으므로, localhost를 통해 Streamlit에 접근합니다. Streamlit은 `0.0.0.0:8501`로 리슨 중이며, 호스트 포트 매핑(8501:8501)을 통해 접근 가능합니다. |

### 변경 4: Nginx ports/networks 설정 제거
| | |
|---|---|
| 파일 | `docker-compose.yml` (nginx 서비스) |
| 원래 설계 | `ports: "8080:80", "8443:443"` / `networks: - sh-net` |
| 변경 후 | `ports`, `networks` 항목 삭제 |
| 사유 | `network_mode: host`는 ports 매핑 및 networks와 함께 사용할 수 없습니다 (Docker Compose에서 mutually exclusive 오류 발생). |

### 변경 5: HTML 파일 배포 방식 변경
| | |
|---|---|
| 파일 | `docker-compose.yml` + deploy 스크립트 |
| 원래 설계 | `docker cp` 명령어로 Nginx 컨테이너 내부에 파일 복사 |
| 변경 후 | NAS 볼륨 마운트 방식으로 변경: `/volume1/sh-pf/docker/nginx-html:/usr/share/nginx/html:ro` — HTML 파일은 NAS 경로에 직접 복사 |
| 사유 | `docker cp`로 넣은 파일은 컨테이너 재시작 시 소실됩니다. 볼륨 마운트를 사용하면 파일이 NAS 디스크에 영구 저장되어 재시작에도 유지됩니다. |

### 변경 6: Nginx 루트 location 설정 변경
| | |
|---|---|
| 파일 | `nginx/default.conf` |
| 원래 설계 | `location = / { ... }` |
| 변경 후 | `location / { ... }` |
| 사유 | `location = /`는 정확히 `/` 경로만 매칭하여, 포털 페이지의 하위 리소스 로딩이 실패합니다. `=` 기호를 제거하면 `/` 이하 모든 경로를 매칭하여 정상 동작합니다. |

### 변경 7: 배포 스크립트 sudo 권한 필요
| | |
|---|---|
| 파일 | `deploy-v4.sh`, `deploy-v5.sh` 등 모든 배포 스크립트 |
| 원래 설계 | `./deploy-v4.sh` |
| 변경 후 | `sudo ./deploy-v4.sh` |
| 사유 | Docker 데몬 소켓 접근에 sudo 권한이 필요합니다. 일반 사용자로 실행 시 permission denied 오류가 발생합니다. |

## 5. 현재 NAS 폴더 구조

변경 후 반영된 실제 NAS 폴더 구조입니다:

```
/volume1/sh-pf/docker/sh-platform/
  docker-compose.yml          (수정됨: nginx host 모드)
  nginx/
    default.conf              (수정됨: listen 8080, 127.0.0.1)
    nginx.conf

/volume1/sh-pf/docker/nginx-html/   (새로 생성됨: Nginx 볼륨 마운트)
  portal/index.html           (SH Portal 메인)
  audit/index.html            (SH Audit Platform)
  ifrs18/index.html           (K-IFRS 1118호 분석기)

/volume1/sh-pf/docker/streamlit-apps/
  default-app.py              (기본 환영 페이지)
  user-apps/app.py            (감사자동화 Streamlit 앱)
```

## 6. 현재 적용된 docker-compose.yml (Nginx 부분)

아래는 현재 NAS에 적용된 Nginx 서비스 설정입니다:

```yaml
nginx:
  image: nginx:alpine
  container_name: sh-nginx
  restart: unless-stopped
  network_mode: host                    # 변경됨
  environment:
    TZ: Asia/Seoul
  volumes:
    - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    - /volume1/sh-pf/docker/nginx-html:/usr/share/nginx/html:ro  # 추가됨
  depends_on:
    - streamlit
  # ports, networks 항목 삭제됨 (host 모드와 호환 불가)
```

## 7. 개발자 요청사항

향후 배포 파일(default.conf, deploy 스크립트 등) 작성 시 아래 사항을 반드시 반영해 주시기 바랍니다.

### 요청 1: default.conf 작성 시
| 항목 | 적용 값 |
|---|---|
| listen 포트 | `listen 8080;` |
| upstream server | `server 127.0.0.1:8501;` |
| 루트 location | `location / { ... }` (`=` 기호 없이) |
| 헬스체크 URL | `http://localhost:8080/health` |

### 요청 2: deploy 스크립트 작성 시
| 항목 | 적용 방법 |
|---|---|
| HTML 파일 배포 | `docker cp` 대신 NAS 경로에 직접 복사: `/volume1/sh-pf/docker/nginx-html/` |
| 실행 방법 | `sudo ./deploy-v5.sh` |
| Nginx 재시작 | `docker restart sh-nginx` |

### 요청 3: docker-compose.yml 변경 금지
현재 적용된 docker-compose.yml의 nginx 서비스 설정(`network_mode: host`, 볼륨 마운트 등)은 변경하지 마세요. 변경 시 서비스 접속이 불가해질 수 있습니다. 새로운 기능 추가 시에는 본 문서의 변경사항을 반영한 상태에서 작업해 주시기 바랍니다.

## 8. 변경사항 요약

| # | 항목 | 원래 | 변경 후 | 사유 |
|---|---|---|---|---|
| 1 | Nginx 네트워크 | bridge (sh-net) | `network_mode: host` | 컨테이너 간 통신 불가 |
| 2 | listen 포트 | `listen 80` | `listen 8080` | host 모드 포트 매핑 불가 |
| 3 | upstream | `streamlit:8501` | `127.0.0.1:8501` | Docker DNS 사용 불가 |
| 4 | ports/networks | `8080:80`, sh-net | 삭제 | host 모드 호환 불가 |
| 5 | HTML 배포 | `docker cp` | 볼륨 마운트 | 재시작 시 파일 소실 |
| 6 | 루트 location | `location = /` | `location /` | 하위 리소스 매칭 불가 |
| 7 | deploy 실행 | `./deploy.sh` | `sudo ./deploy.sh` | Docker 권한 필요 |

---

*성현회계법인 AX 대전환 프로젝트 | SH-AX-INFRA-001 v1.0 | 2026.04.08*
