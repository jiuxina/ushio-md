@echo off
setlocal enabledelayedexpansion

set "REPO_ROOT=%~dp0"
set "WEB_DIR=%REPO_ROOT%web\milkdown"
set "WEB_DIST=%WEB_DIR%\dist\index.html"
set "WEB_ASSET=%REPO_ROOT%assets\milkdown_web\index.html"
set "APK_OUTPUT_DIR=%REPO_ROOT%build\app\outputs\flutter-apk\"

echo [0/6] Checking Node.js environment...
where node >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Node.js is not installed or not in PATH.
  echo Please install Node.js LTS from https://nodejs.org/
  pause
  exit /b 1
)

echo [1/6] Building Milkdown web bundle...
if not exist "%WEB_DIR%\package.json" (
  echo [ERROR] Missing web package.json: %WEB_DIR%\package.json
  pause
  exit /b 1
)

cd /d "%WEB_DIR%"
if errorlevel 1 (
  echo [ERROR] Failed to enter web directory: %WEB_DIR%
  pause
  exit /b 1
)

call npm ci
if errorlevel 1 (
  echo [ERROR] npm ci failed in %WEB_DIR%
  pause
  exit /b 1
)

call npm run build
if errorlevel 1 (
  echo [ERROR] npm run build failed in %WEB_DIR%
  pause
  exit /b 1
)

if not exist "%WEB_DIST%" (
  echo [ERROR] Missing built file: %WEB_DIST%
  pause
  exit /b 1
)

copy /Y "%WEB_DIST%" "%WEB_ASSET%" >nul
if errorlevel 1 (
  echo [ERROR] Failed to sync web bundle to assets: %WEB_ASSET%
  pause
  exit /b 1
)

cd /d "%REPO_ROOT%"
if errorlevel 1 (
  echo [ERROR] Failed to return to repo root: %REPO_ROOT%
  pause
  exit /b 1
)

echo [2/6] Cleaning project...
call flutter clean
if errorlevel 1 (
  echo [ERROR] flutter clean failed
  pause
  exit /b 1
)

echo [3/6] Fetching dependencies...
call flutter pub get
if errorlevel 1 (
  echo [ERROR] flutter pub get failed
  pause
  exit /b 1
)

echo [4/6] Building ABI split release APKs...
call flutter build apk --release --split-per-abi
if errorlevel 1 (
  echo [ERROR] flutter build apk failed
  pause
  exit /b 1
)

echo [5/6] Opening output directory...
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
echo Milkdown runtime bundle synced to:
echo %WEB_ASSET%
echo ======================================================
pause
