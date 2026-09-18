#!/bin/sh
# ============================================================
#  PostgreSQL 자동 백업 (sh-db-backup 컨테이너)
#  - 매일 02:00 실행 (cron), 14일분 보존
#  - 컨테이너는 host 네트워크 모드: 127.0.0.1:5433 (sh-postgres 가 호스트에 연 포트)
#  - 인자 없이 실행: cron 등록만 (컨테이너 시작 시)  /  "run": 실제 백업
#  NAS 경로: /volume1/sh-pf/docker/sh-platform/scripts/backup.sh  (컨테이너의 /backup.sh 로 마운트)
# ============================================================
BACKUP_DIR="/backups"
KEEP_DAYS=14
PGHOST="${PGHOST:-127.0.0.1}"; PGPORT="${PGPORT:-5433}"
PGUSER="${PGUSER:-sh_admin}"; PGDATABASE="${PGDATABASE:-sh_platform}"
export PGHOST PGPORT PGUSER PGDATABASE PGPASSWORD

# ── cron 등록 (이미 있으면 건너뜀). 출력은 컨테이너 로그(PID 1 stdout)로 ──
CRON_FILE=/var/spool/cron/crontabs/root
if ! grep -qs '/backup.sh run' "$CRON_FILE"; then
  mkdir -p /var/spool/cron/crontabs
  echo "0 2 * * * /backup.sh run >> /proc/1/fd/1 2>&1" >> "$CRON_FILE"
  chmod 600 "$CRON_FILE"
  echo "[backup] cron job registered: daily at 02:00 (${PGHOST}:${PGPORT})"
fi

[ "$1" = "run" ] || exit 0

# ── 실제 백업 ──
DATE=$(date +%Y%m%d_%H%M%S)
FILE="${BACKUP_DIR}/sh_platform_${DATE}.sql.gz"
TMP="${BACKUP_DIR}/.sh_platform_${DATE}.sql.part"
echo "[backup] Starting backup: $(basename "$FILE")  (${PGHOST}:${PGPORT}/${PGDATABASE})"

if ! pg_dump --no-password -f "$TMP"; then
  rm -f "$TMP"
  echo "[backup] ❌ FAILED: pg_dump error (host ${PGHOST}:${PGPORT})"
  exit 1
fi
SIZE_BYTES=$(wc -c < "$TMP")
if [ "$SIZE_BYTES" -lt 1024 ]; then
  rm -f "$TMP"
  echo "[backup] ❌ FAILED: dump too small (${SIZE_BYTES} bytes)"
  exit 1
fi
gzip -c "$TMP" > "$FILE" && rm -f "$TMP"
echo "[backup] ✅ Success: $(basename "$FILE") ($(du -h "$FILE" | cut -f1))"

# ── 오래된 백업 삭제 ──
find "$BACKUP_DIR" -name "sh_platform_*.sql.gz" -mtime +${KEEP_DAYS} -delete
echo "[backup] Cleanup done. Remaining backups: $(ls -1 "$BACKUP_DIR"/sh_platform_*.sql.gz 2>/dev/null | wc -l)"
