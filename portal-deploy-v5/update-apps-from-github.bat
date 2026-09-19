@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM   SH Portal - update NAS APP pages from GitHub (double-click)
REM   Uploads portal-deploy-v5/apps/*.html to NAS portal/apps/
REM   The portal itself is deployed by update-portal-from-github.bat
REM   You will be asked for the NAS password TWICE
REM     1st: prepare the apps folder on NAS (ssh)
REM     2nd: send the files (scp)
REM   - ASCII only in this file (Korean cmd reads .bat as CP949)
REM ============================================================

REM ===== Config (edit here if needed) =====
set "GH_OWNER=Jin-Gyu-19"
set "GH_REPO=BDO_Portal"
set "GH_BRANCH=claude/awesome-hopper-cmd4wg"
set "GH_DIR=portal-deploy-v5/apps"
set "NAS_USER=jinkyu.kim"
set "NAS_HOST=192.168.100.25"
set "NAS_PORT=3907"
set "REMOTE_DIR=/volume1/sh-pf/docker/nginx-html/portal/apps"
set "MIN_BYTES=50000"
set "SCRIPT_VER=v1 (2026-09-19)"

set "FILES=jet-workbench.html ko-audit-recon.html en-audit-recon.html en-audit-write.html"
set "TMP_DIR=%TEMP%\sh-portal-apps"

echo ============================================
echo   SH Portal - update APP pages  [%SCRIPT_VER%]
echo   Branch : %GH_BRANCH%
echo   Target : %NAS_USER%@%NAS_HOST%:%REMOTE_DIR%
echo ============================================
echo.

where curl >nul 2>&1 || (echo [ERROR] curl.exe not found. Windows 10 1803+ required. & pause & exit /b 1)
where scp  >nul 2>&1 || (echo [ERROR] scp.exe not found. Install "OpenSSH Client" in Windows optional features. & pause & exit /b 1)

if exist "%TMP_DIR%" rd /s /q "%TMP_DIR%"
mkdir "%TMP_DIR%"

echo [1/3] Downloading app pages from GitHub...
set "SCP_LIST="
for %%F in (%FILES%) do (
  curl -sS -L -f -H "Cache-Control: no-cache" -o "%TMP_DIR%\%%F" "https://raw.githubusercontent.com/%GH_OWNER%/%GH_REPO%/%GH_BRANCH%/%GH_DIR%/%%F?nocache=%RANDOM%%RANDOM%"
  if errorlevel 1 (
    echo   [ERROR] Download failed: %%F
    echo           Check internet / branch name / file name.
    pause
    exit /b 1
  )
  for %%A in ("%TMP_DIR%\%%F") do set "SIZE=%%~zA"
  if !SIZE! LSS %MIN_BYTES% (
    echo   [ERROR] %%F is too small: !SIZE! bytes. Not deploying.
    pause
    exit /b 1
  )
  findstr /C:"</html>" "%TMP_DIR%\%%F" >nul || (echo   [ERROR] %%F looks truncated. Not deploying. & pause & exit /b 1)
  echo   OK - %%F  (!SIZE! bytes^)
  set "SCP_LIST=!SCP_LIST! "%TMP_DIR%\%%F""
)
echo.

echo [2/3] Preparing folder on NAS... (password 1 of 2)
ssh -p %NAS_PORT% %NAS_USER%@%NAS_HOST% "mkdir -p %REMOTE_DIR% && chmod 755 %REMOTE_DIR% && echo '  [OK] folder ready: %REMOTE_DIR%'"
if errorlevel 1 (
  echo.
  echo [ERROR] Could not prepare the folder on NAS.
  echo.
  pause
  exit /b 1
)
echo.

echo [3/3] Sending files... (password 2 of 2)
scp -O -P %NAS_PORT%%SCP_LIST% %NAS_USER%@%NAS_HOST%:%REMOTE_DIR%/
if errorlevel 1 (
  echo.
  echo [ERROR] Upload failed. Nothing may have been replaced.
  echo.
  pause
  exit /b 1
)

echo.
echo ============================================
echo   Done. In browser press Ctrl+F5, then open:
echo     https://%NAS_HOST%:8080/
echo   Apps: JET Tool / KO-EN audit report tools
echo.
echo   If a page shows 403 on NAS, run once:
echo     ssh -p %NAS_PORT% %NAS_USER%@%NAS_HOST% "chmod 644 %REMOTE_DIR%/*.html"
echo ============================================
echo.
rd /s /q "%TMP_DIR%" >nul 2>&1
pause
