@echo off
setlocal enabledelayedexpansion

set "REPO_ROOT=%~dp0"
set "SYNC_SCRIPT=%REPO_ROOT%scripts\sync_milkdown_web.bat"
set "APK_OUTPUT_DIR=%REPO_ROOT%build\app\outputs\flutter-apk\"
set "WINDOWS_OUTPUT_DIR=%REPO_ROOT%build\windows\x64\runner\Release\"

echo ======================================================
echo Universal Build Script for MDReader
echo Version: 1.4.4+7
echo ======================================================
echo.

echo [0/7] Setting up NuGet for Windows build...
set "NUGET_EXE=%REPO_ROOT%tools\nuget.exe"
if exist "%NUGET_EXE%" (
  echo [INFO] Found NuGet at: %NUGET_EXE%
  set "PATH=%REPO_ROOT%tools;%PATH%"
) else (
  echo [WARN] NuGet not found at %NUGET_EXE%
  if %BUILD_WINDOWS%==1 (
    echo [WARN] Downloading NuGet for Windows build...
    if not exist "%REPO_ROOT%tools" mkdir "%REPO_ROOT%tools"
    powershell -Command "& {Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile '%NUGET_EXE%'}"
    if exist "%NUGET_EXE%" (
      echo [INFO] NuGet downloaded successfully
      set "PATH=%REPO_ROOT%tools;%PATH%"
    ) else (
      echo [ERROR] Failed to download NuGet, Windows build may fail
    )
  )
)

REM Parse command line arguments
set "BUILD_ANDROID=0"
set "BUILD_WINDOWS=0"

:parse_args
if "%~1"=="" goto end_parse
if /i "%~1"=="android" set "BUILD_ANDROID=1"
if /i "%~1"=="windows" set "BUILD_WINDOWS=1"
if /i "%~1"=="all" (
  set "BUILD_ANDROID=1"
  set "BUILD_WINDOWS=1"
)
shift
goto parse_args

:end_parse

REM If no arguments, build all
if %BUILD_ANDROID%==0 if %BUILD_WINDOWS%==0 (
  set "BUILD_ANDROID=1"
  set "BUILD_WINDOWS=1"
)

echo Build Targets:
if %BUILD_ANDROID%==1 echo   - Android APK (split-per-abi)
if %BUILD_WINDOWS%==1 echo   - Windows Executable
echo.

echo [1/7] Syncing Milkdown runtime web bundle...
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

echo [2/7] Cleaning project...
call flutter clean
if errorlevel 1 (
  echo [ERROR] flutter clean failed
  pause
  exit /b 1
)

echo [3/7] Fetching dependencies...
call flutter pub get
if errorlevel 1 (
  echo [ERROR] flutter pub get failed
  pause
  exit /b 1
)

echo [4/7] Generating app icons...
call flutter pub run flutter_launcher_icons
if errorlevel 1 (
  echo [WARN] App icon generation failed, continuing...
)

set "STEP=4"
set "TOTAL=6"

if %BUILD_ANDROID%==1 (
  echo [5/7] Building Android ABI split release APKs...
  call flutter build apk --release --split-per-abi
  if errorlevel 1 (
    echo [ERROR] flutter build apk failed
    pause
    exit /b 1
  )
  set /a STEP+=1
)

if %BUILD_WINDOWS%==1 (
  echo [%STEP%/7] Building Windows release runner...
  call flutter build windows --release
  if errorlevel 1 (
    echo [ERROR] flutter build windows failed
    pause
    exit /b 1
  )
  
  REM Rename executable to Chinese name
  echo [INFO] Renaming executable to 汐.exe...
  if exist "%WINDOWS_OUTPUT_DIR%Ushio.exe" (
    if exist "%WINDOWS_OUTPUT_DIR%汐.exe" del /F /Q "%WINDOWS_OUTPUT_DIR%汐.exe"
    ren "%WINDOWS_OUTPUT_DIR%Ushio.exe" "汐.exe"
    echo [INFO] Executable renamed successfully
  ) else if exist "%WINDOWS_OUTPUT_DIR%mdreader.exe" (
    if exist "%WINDOWS_OUTPUT_DIR%汐.exe" del /F /Q "%WINDOWS_OUTPUT_DIR%汐.exe"
    ren "%WINDOWS_OUTPUT_DIR%mdreader.exe" "汐.exe"
    echo [INFO] Executable renamed successfully
  )
  
  set /a STEP+=1
)

echo [7/7] Opening output directories...
if %BUILD_ANDROID%==1 (
  if exist "%APK_OUTPUT_DIR%" (
    start "" "%APK_OUTPUT_DIR%"
  ) else (
    echo [WARN] APK output directory not found
  )
)

if %BUILD_WINDOWS%==1 (
  if exist "%WINDOWS_OUTPUT_DIR%" (
    start "" "%WINDOWS_OUTPUT_DIR%"
  ) else (
    echo [WARN] Windows output directory not found
  )
)

echo.
echo ======================================================
echo Build Complete!
echo ======================================================

if %BUILD_ANDROID%==1 (
  echo Android APKs:
  echo %APK_OUTPUT_DIR%
  echo.
)

if %BUILD_WINDOWS%==1 (
  echo Windows Executable:
  echo %WINDOWS_OUTPUT_DIR%mdreader.exe
  echo.
)

echo Build Information:
echo - Version: 1.4.4+7
echo - Build Mode: Release
if %BUILD_ANDROID%==1 echo - Android: Split APKs (arm64-v8a, armeabi-v7a, x86_64)
if %BUILD_WINDOWS%==1 echo - Windows: x64 Executable
echo ======================================================
echo.

pause
