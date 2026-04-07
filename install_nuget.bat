@echo off
setlocal enabledelayedexpansion

echo ======================================================
echo NuGet Installation Script for MDReader Windows Build
echo ======================================================
echo.

REM Check if nuget is already installed
where nuget >nul 2>&1
if %errorlevel%==0 (
  echo [INFO] NuGet is already installed:
  where nuget
  nuget help | findstr /C:"NuGet Version"
  pause
  exit /b 0
)

echo [1/3] Downloading NuGet...
set "NUGET_URL=https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
set "NUGET_DIR=%LOCALAPPDATA%\Microsoft\WindowsApps"
set "NUGET_EXE=%NUGET_DIR%\nuget.exe"

REM Create directory if it doesn't exist
if not exist "%NUGET_DIR%" (
  mkdir "%NUGET_DIR%"
)

REM Download nuget.exe
powershell -Command "& {Invoke-WebRequest -Uri '%NUGET_URL%' -OutFile '%NUGET_EXE%'}"
if errorlevel 1 (
  echo [ERROR] Failed to download NuGet
  pause
  exit /b 1
)

echo [2/3] Verifying NuGet installation...
"%NUGET_EXE%" help | findstr /C:"NuGet Version"
if errorlevel 1 (
  echo [ERROR] NuGet verification failed
  pause
  exit /b 1
)

echo [3/3] Adding NuGet to PATH...
REM The directory should already be in PATH on Windows 10/11
echo [INFO] NuGet installed to: %NUGET_EXE%
echo [INFO] You may need to restart your terminal or run:
echo        refreshenv
echo        or
echo        Restart your command prompt/PowerShell

echo.
echo ======================================================
echo NuGet Installation Complete!
echo Location: %NUGET_EXE%
echo ======================================================
echo.
echo Please restart your terminal and run the build script again.
pause
