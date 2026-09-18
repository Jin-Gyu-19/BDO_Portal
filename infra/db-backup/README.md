# sh-db-backup 수리 (2026-09-18)

## 문제
- `./scripts/backup.sh:/backup.sh:ro` 읽기 전용 마운트인데 시작 명령이 `chmod +x` 를 먼저 해서 컨테이너가 재시작 반복 → 5개월간 백업 없음
- 고친 뒤에도 (1) 알파인 기본 crontab 파일이 있어 등록 조건(`파일 없을 때만`)에 걸려 cron 미등록, (2) bridge 네트워크에서 `postgres` 호스트로 접속 시간 초과(SH-AX-INFRA-001 과 같은 Synology 문제), (3) 파이프라인의 gzip 성공만 보고 "Success" 로 20바이트 빈 파일 생성

## 조치
- `docker-compose.yml` db-backup: `network_mode: host`, `PGHOST: 127.0.0.1`, `PGPORT: "5433"`, `networks` 제거, command `/backup.sh && crond …`
- `scripts/backup.sh` 를 이 폴더의 것으로 교체: cron 줄이 없을 때만 추가, `pg_dump -f` 로 종료 코드 확인, 1KB 미만이면 실패 처리

## 확인
```
sudo docker exec sh-db-backup /backup.sh run          # ✅ Success 와 수십 KB 이상 파일
sudo docker exec sh-db-backup cat /var/spool/cron/crontabs/root | grep backup
```
