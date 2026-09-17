@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM   SH Portal - update NAS from GitHub (run on PC, double-click)
REM   1) Downloads the latest portal index.html from GitHub
REM   2) Checks the file (size, <title>, </html>)
REM   3) Uploads it to NAS over ssh (ONE password prompt),
REM      backs up the current file, then replaces it
REM   4) Keeps only the newest MAX_BAK backups on NAS (older ones deleted)
REM   - No git clone needed. Keep this .bat anywhere on your PC.
REM   - Needs: Windows 10+ (curl.exe + OpenSSH client are built in)
REM   - ASCII only in this file (Korean cmd reads .bat as CP949)
REM ============================================================

REM ===== Config (edit here if needed) =====
set "GH_OWNER=Jin-Gyu-19"
set "GH_REPO=BDO_Portal"
set "GH_BRANCH=claude/awesome-hopper-cmd4wg"
set "GH_PATH=portal-deploy-v5/index.html"
set "NAS_USER=jinkyu.kim"
set "NAS_HOST=192.168.100.25"
set "NAS_PORT=3907"
set "REMOTE_DIR=/volume1/sh-pf/docker/nginx-html/portal"
set "MIN_BYTES=200000"
set "MAX_BAK=5"
set "SCRIPT_VER=v3 (2026-09-17)"

set "RAW_URL=https://raw.githubusercontent.com/%GH_OWNER%/%GH_REPO%/%GH_BRANCH%/%GH_PATH%"
set "API_URL=https://api.github.com/repos/%GH_OWNER%/%GH_REPO%/commits?sha=%GH_BRANCH%&path=%GH_PATH%&per_page=1"
set "TMP_FILE=%TEMP%\sh-portal-index.html"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%I"

echo ============================================
echo   SH Portal - update NAS from GitHub  [%SCRIPT_VER%]
echo   Branch : %GH_BRANCH%
echo   Target : %NAS_USER%@%NAS_HOST%:%REMOTE_DIR%/index.html
echo   Backup : index.html.bak_%TS%  (keep newest %MAX_BAK%)
echo ============================================
echo.

where curl >nul 2>&1 || (echo [ERROR] curl.exe not found. Windows 10 1803+ required. & pause & exit /b 1)
where ssh  >nul 2>&1 || (echo [ERROR] ssh.exe not found. Install "OpenSSH Client" in Windows optional features. & pause & exit /b 1)

echo [1/3] Downloading latest portal from GitHub...
if exist "%TMP_FILE%" del /q "%TMP_FILE%"
curl -sS -L -f -H "Cache-Control: no-cache" -o "%TMP_FILE%" "%RAW_URL%?nocache=%RANDOM%%RANDOM%"
if errorlevel 1 (
  echo.
  echo [ERROR] Download failed. Check internet / branch name / repo visibility.
  echo         %RAW_URL%
  echo.
  pause
  exit /b 1
)

REM --- sanity checks on the downloaded file ---
for %%A in ("%TMP_FILE%") do set "SIZE=%%~zA"
if !SIZE! LSS %MIN_BYTES% (
  echo [ERROR] Downloaded file is too small: !SIZE! bytes ^(expected ^> %MIN_BYTES%^). Not deploying.
  pause
  exit /b 1
)
findstr /C:"<title>SH Portal" "%TMP_FILE%" >nul || (echo [ERROR] File does not look like SH Portal ^(no title^). Not deploying. & pause & exit /b 1)
findstr /C:"</html>" "%TMP_FILE%" >nul || (echo [ERROR] File looks truncated ^(no ^</html^>^). Not deploying. & pause & exit /b 1)
echo       OK - !SIZE! bytes

REM --- show which commit this is (best effort, needs internet) ---
powershell -NoProfile -Command "try { $c=(Invoke-RestMethod -Uri '%API_URL%' -Headers @{'User-Agent'='sh-portal-updater'})[0]; Write-Host ('      Commit : ' + $c.sha.Substring(0,7) + '  ' + $c.commit.author.date); Write-Host ('      Message: ' + ($c.commit.message -split [char]10)[0]) } catch { Write-Host '      (commit info unavailable)' }"
echo.

echo [2/3] Uploading to NAS and replacing... (enter NAS password ONCE)
ssh -p %NAS_PORT% %NAS_USER%@%NAS_HOST% "cd %REMOTE_DIR% && cat > index.html.new && got=$(wc -c < index.html.new) && if [ $got -ne !SIZE! ]; then echo '  [ERROR] size mismatch: got '$got' expected !SIZE!'; rm -f index.html.new; exit 2; fi && if [ -f index.html ]; then cp index.html index.html.bak_%TS% && echo '  [OK] backup: index.html.bak_%TS%'; else echo '  [INFO] no existing index.html - new deploy'; fi && mv index.html.new index.html && echo '  [OK] replaced' && n=0; for f in $(ls -1r index.html.bak_* 2>/dev/null); do n=$((n+1)); if [ $n -gt %MAX_BAK% ]; then rm -f $f && echo '  [CLEAN] removed old backup: '$f; fi; done; echo '  [OK] backups kept:'; for f in $(ls -1r index.html.bak_* 2>/dev/null); do echo '         '$f; done" < "%TMP_FILE%"
if errorlevel 1 (
  echo.
  echo [ERROR] Upload/replace failed. Nothing was changed if you see 'size mismatch';
  echo         otherwise check: %REMOTE_DIR%/index.html.new
  echo.
  pause
  exit /b 1
)

echo.
echo [3/3] Done.
echo ============================================
echo   In browser press Ctrl+F5, then open:
echo     http://%NAS_HOST%:8080/
echo.
echo   To roll back on NAS:
echo     cp %REMOTE_DIR%/index.html.bak_%TS% %REMOTE_DIR%/index.html
echo ============================================
echo.
del /q "%TMP_FILE%" >nul 2>&1
pause
