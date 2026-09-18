@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM   SH Portal index.html deploy (run on PC)
REM   - Uses scp (binary transfer): no Hangul encoding corruption
REM   - Backs up the existing NAS file, then replaces it
REM   - Static HTML: no nginx restart needed
REM   - Replaces ONLY portal/index.html (other apps untouched)
REM   - You will enter the NAS password TWICE (scp + ssh)
REM ============================================================

REM ===== Config (edit here if needed) =====
set "NAS_USER=jinkyu.kim"
set "NAS_HOST=192.168.100.25"
set "NAS_PORT=3907"
set "REMOTE_DIR=/volume1/sh-pf/docker/nginx-html/portal"
set "LOCAL_FILE=%~dp0index.html"
set "MAX_BAK=5"

REM ===== Timestamp (yyyyMMdd_HHmmss) =====
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%I"

echo ============================================
echo   SH Portal index.html deploy (scp)
echo   Target: %NAS_USER%@%NAS_HOST%:%REMOTE_DIR%
echo   Backup: index.html.bak_%TS%
echo ============================================
echo.

if not exist "%LOCAL_FILE%" (
  echo [ERROR] index.html not found:
  echo         %LOCAL_FILE%
  echo         Put this .bat in the same folder as index.html.
  echo.
  pause
  exit /b 1
)

echo [1/2] Uploading new file... (enter NAS password)
REM -O forces legacy SCP protocol (Synology often has SFTP subsystem disabled)
scp -O -P %NAS_PORT% "%LOCAL_FILE%" %NAS_USER%@%NAS_HOST%:%REMOTE_DIR%/index.html.new
if errorlevel 1 (
  echo.
  echo [ERROR] scp upload failed. Check network / password / path.
  echo.
  pause
  exit /b 1
)

echo.
echo [2/2] Backup and replace... (enter NAS password again)
ssh -p %NAS_PORT% %NAS_USER%@%NAS_HOST% "cd %REMOTE_DIR% && if [ -f index.html ]; then cp index.html index.html.bak_%TS% && echo '  [OK] backup: index.html.bak_%TS%'; else echo '  [INFO] no existing index.html - new deploy'; fi && mv index.html.new index.html && echo '  [OK] replaced' && n=0; for f in $(ls -1r index.html.bak_* 2>/dev/null); do n=$((n+1)); if [ $n -gt %MAX_BAK% ]; then rm -f $f && echo '  [CLEAN] removed old backup: '$f; fi; done; echo '  [OK] backups kept:'; for f in $(ls -1r index.html.bak_* 2>/dev/null); do echo '         '$f; done"
if errorlevel 1 (
  echo.
  echo [ERROR] ssh replace failed. Temp file may remain: %REMOTE_DIR%/index.html.new
  echo.
  pause
  exit /b 1
)

echo.
echo ============================================
echo   DONE!
echo   In browser press Ctrl+F5, then open:
echo     https://%NAS_HOST%:8080/
echo.
echo   To restore on NAS:
echo     cp %REMOTE_DIR%/index.html.bak_%TS% %REMOTE_DIR%/index.html
echo ============================================
echo.
pause
