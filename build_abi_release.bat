@echo off
setlocal enabledelayedexpansion

set "REPO_ROOT=%~dp0"
set "APK_OUTPUT_DIR=%REPO_ROOT%build\app\outputs\flutter-apk\"
set "SYNC_SCRIPT=%REPO_ROOT%scripts\sync_milkdown_web.bat"

echo [0/5] Syncing Milkdown runtime web bundle...
if not exist "%SYNC_SCRIPT%" (
  echo [ERROR] Missing script: %SYNC_SCRIPT%
  pause
  exit /b 1
)

call "%SYNC_SCRIPT%"
if errorlevel 1 (
  echo [ERROR] Milkdown runtime bundle sync failed.
  pause
  exit /b 1
)

echo [1/5] Cleaning project...
call flutter clean
if errorlevel 1 (
  echo [ERROR] flutter clean failed
  pause
  exit /b 1
)

echo [2/5] Fetching dependencies...
call flutter pub get
if errorlevel 1 (
  echo [ERROR] flutter pub get failed
  pause
  exit /b 1
)

echo [3/5] Building ABI split release APKs...
call flutter build apk --release --split-per-abi
if errorlevel 1 (
  echo [ERROR] flutter build apk failed
  pause
  exit /b 1
)

echo [4/5] Opening output directory...
if exist "%APK_OUTPUT_DIR%" (
  start "" "%APK_OUTPUT_DIR%"
) else (
  echo [WARN] Output directory not found: %APK_OUTPUT_DIR%
)

echo.
echo ======================================================
echo Build Complete!
echo ABI-specific APKs are generated in:
echo %APK_OUTPUT_DIR%
echo Milkdown runtime bundle sync script:
echo %SYNC_SCRIPT%
echo ======================================================
pause
