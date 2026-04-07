@echo off
setlocal enabledelayedexpansion

set "REPO_ROOT=%~dp0"

echo ======================================================
echo MSIX Package Build Script for 汐
echo Version: 1.4.4
echo ======================================================
echo.

echo [1/4] Checking prerequisites...

REM Check if Flutter is available
where flutter >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Flutter not found in PATH!
  pause
  exit /b 1
)

REM Check if MSIX is installed
flutter pub global list | findstr msix >nul
if errorlevel 1 (
  echo [INFO] MSIX package not found, installing...
  call flutter pub global activate msix
  if errorlevel 1 (
    echo [ERROR] Failed to install MSIX package!
    pause
    exit /b 1
  )
)

echo [INFO] MSIX package is available

REM Build Windows app first
echo [2/4] Building Windows application...
if not exist "%REPO_ROOT%build\windows\x64\runner\Release\汐.exe" (
  echo [INFO] Running Windows build...
  call flutter build windows --release
  if errorlevel 1 (
    echo [ERROR] Windows build failed!
    pause
    exit /b 1
  )
) else (
  echo [INFO] Windows build found, skipping...
)

REM Create MSIX package
echo [3/4] Creating MSIX package...
cd /d "%REPO_ROOT%"
call flutter pub run msix:create
if errorlevel 1 (
  echo [ERROR] MSIX package creation failed!
  echo [INFO] Make sure you have Windows SDK installed.
  pause
  exit /b 1
)

REM Open output directory
echo [4/4] Opening output directory...
if exist "%REPO_ROOT%build\msix" (
  start "" "%REPO_ROOT%build\msix"
) else (
  echo [WARN] Output directory not found
)

echo.
echo ======================================================
echo MSIX Package Build Complete!
echo Location: %REPO_ROOT%build\msix
echo ======================================================
echo.
echo [INFO] To install the MSIX package, you may need to:
echo   1. Enable Developer Mode in Windows Settings
echo   2. Or sign the package with a valid certificate
echo.
pause
