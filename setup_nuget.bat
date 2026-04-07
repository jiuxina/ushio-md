@echo off
setlocal enabledelayedexpansion

echo ======================================================
echo NuGet Setup Script for MDReader Windows Build
echo ======================================================
echo.

REM Check if Visual Studio is installed
set "VS_WHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VS_WHERE%" (
  echo [ERROR] Visual Studio Installer not found
  pause
  exit /b 1
)

REM Find Visual Studio installation
for /f "usebackq tokens=*" %%i in (`"%VS_WHERE%" -latest -products * -requires Microsoft.Component.MSBuild -property installationPath`) do (
  set "VS_INSTALL_PATH=%%i"
)

if not defined VS_INSTALL_PATH (
  echo [ERROR] Visual Studio installation not found
  pause
  exit /b 1
)

echo [INFO] Found Visual Studio at: %VS_INSTALL_PATH%

REM Try to use NuGet from Visual Studio
set "VS_NUGET=%VS_INSTALL_PATH%\Common7\IDE\CommonExtensions\Microsoft\NuGet\NuGet.exe"
if exist "%VS_NUGET%" (
  echo [INFO] Using NuGet from Visual Studio: %VS_NUGET%
  set "NUGET_EXE=%VS_NUGET%"
  goto :build
)

REM Try to use NuGet from NuGet VSIX
set "VS_NUGET_VSIX=%VS_INSTALL_PATH%\Common7\IDE\Extensions\Microsoft\NuGet\NuGet.exe"
if exist "%VS_NUGET_VSIX%" (
  echo [INFO] Using NuGet from VSIX: %VS_NUGET_VSIX%"
  set "NUGET_EXE=%VS_NUGET_VSIX%"
  goto :build
)

REM Download NuGet
echo [INFO] NuGet not found in Visual Studio, downloading...
set "NUGET_URL=https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
set "NUGET_DIR=%REPO_ROOT%tools"
set "NUGET_EXE=%NUGET_DIR%\nuget.exe"

if not exist "%NUGET_DIR%" mkdir "%NUGET_DIR%"
if not exist "%NUGET_EXE%" (
  powershell -Command "& {Invoke-WebRequest -Uri '%NUGET_URL%' -OutFile '%NUGET_EXE%'}"
  if errorlevel 1 (
    echo [ERROR] Failed to download NuGet
    pause
    exit /b 1
  )
)

:build
echo [INFO] NuGet location: %NUGET_EXE%
echo [INFO] Adding NuGet to PATH for this session
set "PATH=%PATH%;%NUGET_DIR%"

REM Restore packages for the Windows build
echo.
echo [INFO] Restoring NuGet packages...
cd /d "%~dp0"
"%NUGET_EXE%" restore windows\CMakeLists.txt -Source "https://api.nuget.org/v3/index.json" || (
  echo [WARN] NuGet restore failed, continuing with flutter build...
)

echo.
echo ======================================================
echo NuGet setup complete!
echo NuGet location: %NUGET_EXE%
echo ======================================================
pause
