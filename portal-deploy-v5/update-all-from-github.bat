@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM   SH Portal - update EVERYTHING on NAS from GitHub
REM   (portal index.html + app pages in one go, ONE password)
REM
REM   1) Downloads the portal and every app page from GitHub
REM   2) Checks each file (size, marker, </html>)
REM   3) Sends them all through a single ssh connection (tar),
REM      backs up the current portal, then replaces it
REM   4) Keeps only the newest MAX_BAK portal backups on NAS
REM
REM   - No git clone needed. Keep this .bat anywhere on your PC.
REM   - Needs: Windows 10 1803+ (curl.exe, tar.exe, ssh.exe built in)
REM   - If this fails, the older pair still works:
REM       update-portal-from-github.bat  +  update-apps-from-github.bat
REM   - ASCII only in this file (Korean cmd reads .bat as CP949)
REM ============================================================

REM ===== Config (edit here if needed) =====
set "GH_OWNER=Jin-Gyu-19"
set "GH_REPO=BDO_Portal"
set "GH_BRANCH=claude/awesome-hopper-cmd4wg"
set "GH_PORTAL=portal-deploy-v5/index.html"
set "GH_APPDIR=portal-deploy-v5/apps"
set "NAS_USER=jinkyu.kim"
set "NAS_HOST=192.168.100.25"
set "NAS_PORT=3907"
set "REMOTE_DIR=/volume1/sh-pf/docker/nginx-html/portal"
set "MIN_PORTAL=200000"
set "MIN_APP=50000"
set "MAX_BAK=5"
set "SCRIPT_VER=v1 (2026-09-19)"

set "APPS=jet-workbench.html ko-audit-recon.html en-audit-recon.html en-audit-write.html"
set "RAW=https://raw.githubusercontent.com/%GH_OWNER%/%GH_REPO%/%GH_BRANCH%"
set "TMP_DIR=%TEMP%\sh-portal-all"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%I"

echo ============================================
echo   SH Portal - update ALL from GitHub  [%SCRIPT_VER%]
echo   Branch : %GH_BRANCH%
echo   Target : %NAS_USER%@%NAS_HOST%:%REMOTE_DIR%
echo   Backup : index.html.bak_%TS%  (keep newest %MAX_BAK%)
echo ============================================
echo.

where curl >nul 2>&1 || (echo [ERROR] curl.exe not found. Windows 10 1803+ required. & pause & exit /b 1)
where tar  >nul 2>&1 || (echo [ERROR] tar.exe not found. Use the older pair of .bat files instead. & pause & exit /b 1)
where ssh  >nul 2>&1 || (echo [ERROR] ssh.exe not found. Install "OpenSSH Client" in Windows optional features. & pause & exit /b 1)

if exist "%TMP_DIR%" rd /s /q "%TMP_DIR%"
mkdir "%TMP_DIR%"
mkdir "%TMP_DIR%\apps"

echo [1/3] Downloading portal and app pages...
curl -sS -L -f -H "Cache-Control: no-cache" -o "%TMP_DIR%\index.html.new" "%RAW%/%GH_PORTAL%?nocache=%RANDOM%%RANDOM%"
if errorlevel 1 (
  echo   [ERROR] Portal download failed. Check internet / branch name / repo visibility.
  pause
  exit /b 1
)
for %%A in ("%TMP_DIR%\index.html.new") do set "PSIZE=%%~zA"
if !PSIZE! LSS %MIN_PORTAL% (
  echo   [ERROR] Portal file is too small: !PSIZE! bytes. Not deploying.
  pause
  exit /b 1
)
findstr /C:"<title>SH Portal" "%TMP_DIR%\index.html.new" >nul || (echo   [ERROR] Not an SH Portal file ^(no title^). Not deploying. & pause & exit /b 1)
findstr /C:"</html>" "%TMP_DIR%\index.html.new" >nul || (echo   [ERROR] Portal file looks truncated. Not deploying. & pause & exit /b 1)
echo   OK - index.html  (!PSIZE! bytes^)

for %%F in (%APPS%) do (
  curl -sS -L -f -H "Cache-Control: no-cache" -o "%TMP_DIR%\apps\%%F" "%RAW%/%GH_APPDIR%/%%F?nocache=%RANDOM%%RANDOM%"
  if errorlevel 1 (
    echo   [ERROR] App download failed: %%F
    pause
    exit /b 1
  )
  for %%A in ("%TMP_DIR%\apps\%%F") do set "ASIZE=%%~zA"
  if !ASIZE! LSS %MIN_APP% (
    echo   [ERROR] %%F is too small: !ASIZE! bytes. Not deploying.
    pause
    exit /b 1
  )
  findstr /C:"</html>" "%TMP_DIR%\apps\%%F" >nul || (echo   [ERROR] %%F looks truncated. Not deploying. & pause & exit /b 1)
  echo   OK - apps/%%F  (!ASIZE! bytes^)
)
echo.

REM --- show which commit the portal came from (best effort) ---
powershell -NoProfile -Command "try { $c=(Invoke-RestMethod -Uri 'https://api.github.com/repos/%GH_OWNER%/%GH_REPO%/commits?sha=%GH_BRANCH%&per_page=1' -Headers @{'User-Agent'='sh-portal-updater'})[0]; Write-Host ('      Commit : ' + $c.sha.Substring(0,7) + '  ' + $c.commit.author.date); Write-Host ('      Message: ' + ($c.commit.message -split [char]10)[0]) } catch { Write-Host '      (commit info unavailable)' }"
echo.

echo [2/3] Sending everything to NAS... (enter NAS password ONCE)
tar --format ustar -cf - -C "%TMP_DIR%" index.html.new apps | ssh -p %NAS_PORT% %NAS_USER%@%NAS_HOST% "cd %REMOTE_DIR% && mkdir -p apps && tar -xf - && got=$(wc -c < index.html.new) && if [ $got -ne %PSIZE% ]; then echo '  [ERROR] size mismatch: got '$got' expected %PSIZE%'; rm -f index.html.new; exit 2; fi && if [ -f index.html ]; then cp index.html index.html.bak_%TS% && echo '  [OK] backup: index.html.bak_%TS%'; else echo '  [INFO] no existing index.html - new deploy'; fi && mv index.html.new index.html && echo '  [OK] portal replaced' && chmod 644 apps/*.html && chmod 755 apps && echo '  [OK] app pages updated:' && ls -1 apps && n=0; for f in $(ls -1r index.html.bak_* 2>/dev/null); do n=$((n+1)); if [ $n -gt %MAX_BAK% ]; then rm -f $f && echo '  [CLEAN] removed old backup: '$f; fi; done; echo '  [OK] backups kept:'; for f in $(ls -1r index.html.bak_* 2>/dev/null); do echo '         '$f; done"
if errorlevel 1 (
  echo.
  echo [ERROR] Transfer failed. If you saw 'size mismatch', nothing was changed.
  echo         Otherwise check: %REMOTE_DIR%/index.html.new
  echo         You can also fall back to the older pair:
  echo           update-portal-from-github.bat  +  update-apps-from-github.bat
  echo.
  pause
  exit /b 1
)

echo.
echo [3/3] Done.
echo ============================================
echo   In browser press Ctrl+F5, then open:
echo     https://%NAS_HOST%:8080/
echo.
echo   To roll back the portal on NAS:
echo     cp %REMOTE_DIR%/index.html.bak_%TS% %REMOTE_DIR%/index.html
echo ============================================
echo.
rd /s /q "%TMP_DIR%" >nul 2>&1
pause
