@echo off
setlocal enabledelayedexpansion

set "REPO_ROOT=%~dp0"
set "SYNC_SCRIPT=%REPO_ROOT%scripts\sync_milkdown_web.bat"
set "APK_OUTPUT_DIR=%REPO_ROOT%build\app\outputs\flutter-apk\"
set "WINDOWS_OUTPUT_DIR=%REPO_ROOT%build\windows\x64\runner\Release\"

echo [0/6] Syncing Milkdown runtime web bundle...
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

echo [1/6] Cleaning project...
call flutter clean
if errorlevel 1 (
  echo [ERROR] flutter clean failed
  pause
  exit /b 1
)

echo [2/6] Fetching dependencies...
call flutter pub get
if errorlevel 1 (
  echo [ERROR] flutter pub get failed
  pause
  exit /b 1
)

echo [3/6] Building Android ABI split release APKs...
call flutter build apk --release --split-per-abi
if errorlevel 1 (
  echo [ERROR] flutter build apk failed
  pause
  exit /b 1
)

echo [4/6] Building Windows release runner...
call flutter build windows --release
if errorlevel 1 (
  echo [ERROR] flutter build windows failed
  pause
  exit /b 1
)

echo [5/6] Opening output directories...
if exist "%APK_OUTPUT_DIR%" start "" "%APK_OUTPUT_DIR%"
if exist "%WINDOWS_OUTPUT_DIR%" start "" "%WINDOWS_OUTPUT_DIR%"

echo.
echo ======================================================
echo Build Complete!
echo Android output:
echo %APK_OUTPUT_DIR%
echo Windows output:
echo %WINDOWS_OUTPUT_DIR%
echo ======================================================
pause
