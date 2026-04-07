@echo off
setlocal enabledelayedexpansion

set REPO_ROOT=%~dp0
set SYNC_SCRIPT=%REPO_ROOT%scripts\sync_milkdown_web.bat
set WINDOWS_OUTPUT_DIR=%REPO_ROOT%build\windows\x64\runner\Release\

echo ======================================================
echo Windows Release Build Script for MDReader
echo Version: 1.4.4+7
echo ======================================================
echo.

echo [0/6] Setting up NuGet...
set NUGET_EXE=%REPO_ROOT%tools\nuget.exe
if exist "%NUGET_EXE%" (
  echo [INFO] Found NuGet at: %NUGET_EXE%
  set PATH=%REPO_ROOT%tools;%PATH%
) else (
  echo [WARN] NuGet not found
  if not exist "%REPO_ROOT%tools" mkdir "%REPO_ROOT%tools"
  powershell -Command "Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile '%NUGET_EXE%'"
  if exist "%NUGET_EXE%" (
    echo [INFO] NuGet downloaded successfully
    set PATH=%REPO_ROOT%tools;%PATH%
  )
)

echo [1/6] Syncing Milkdown runtime web bundle...
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

echo [4/6] Generating app icons...
call flutter pub run flutter_launcher_icons
if errorlevel 1 (
  echo [WARN] App icon generation failed, continuing...
)

echo [5/6] Building Windows release runner...
call flutter build windows --release
if errorlevel 1 (
  echo [ERROR] flutter build windows failed
  pause
  exit /b 1
)

echo [INFO] Renaming executable...
if exist "%WINDOWS_OUTPUT_DIR%Ushio.exe" (
  if exist "%WINDOWS_OUTPUT_DIR%?.exe" del /F /Q "%WINDOWS_OUTPUT_DIR%?.exe" 2>nul
  ren "%WINDOWS_OUTPUT_DIR%Ushio.exe" "?.exe"
  echo [INFO] Executable renamed to ?.exe
) else if exist "%WINDOWS_OUTPUT_DIR%mdreader.exe" (
  if exist "%WINDOWS_OUTPUT_DIR%?.exe" del /F /Q "%WINDOWS_OUTPUT_DIR%?.exe" 2>nul
  ren "%WINDOWS_OUTPUT_DIR%mdreader.exe" "?.exe"
  echo [INFO] Executable renamed to ?.exe
)

echo [6/6] Opening output directory...
if exist "%WINDOWS_OUTPUT_DIR%" start "" "%WINDOWS_OUTPUT_DIR%"

echo.
echo ======================================================
echo Build Complete!
echo Windows executable: %WINDOWS_OUTPUT_DIR%?.exe
echo ======================================================
pause
