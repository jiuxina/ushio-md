@echo off
setlocal enabledelayedexpansion

set "REPO_ROOT=%~dp0"
set "BUILD_DIR=%REPO_ROOT%build\windows\x64\runner\Release"
set "INSTALLER_DIR=%REPO_ROOT%installer"
set "INNO_SETUP_COMPILER="

echo ======================================================
echo Windows Installer Build Script for 汐
echo Version: 1.4.4
echo ======================================================
echo.

REM Check if Inno Setup is installed
echo [1/5] Checking Inno Setup installation...
where iscc >nul 2>&1
if %errorlevel%==0 (
  set "INNO_SETUP_COMPILER=iscc"
  echo [INFO] Found Inno Setup in PATH
) else (
  REM Check common installation paths
  if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
    set "INNO_SETUP_COMPILER=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
    echo [INFO] Found Inno Setup at: !INNO_SETUP_COMPILER!
  ) else if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" (
    set "INNO_SETUP_COMPILER=%ProgramFiles%\Inno Setup 6\ISCC.exe"
    echo [INFO] Found Inno Setup at: !INNO_SETUP_COMPILER!
  ) else (
    echo [ERROR] Inno Setup 6 not found!
    echo [INFO] Please install Inno Setup 6 from: https://jrsoftware.org/isdl.php
    echo [INFO] After installation, add Inno Setup to PATH or run this script again.
    pause
    exit /b 1
  )
)

REM Check if build exists
echo [2/5] Checking build output...
if not exist "%BUILD_DIR%\汐.exe" (
  echo [ERROR] Build output not found!
  echo [INFO] Please run build_windows_release.bat first.
  pause
  exit /b 1
)

if not exist "%BUILD_DIR%\flutter_windows.dll" (
  echo [ERROR] Build output incomplete!
  echo [INFO] Please run build_windows_release.bat first.
  pause
  exit /b 1
)

echo [INFO] Build output found at: %BUILD_DIR%

REM Create app icon for installer
echo [3/5] Preparing installer resources...
if not exist "%REPO_ROOT%app.ico" (
  echo [INFO] Converting app.png to app.ico...
  if exist "%REPO_ROOT%app.png" (
    REM Try to use ImageMagick if available
    where magick >nul 2>&1
    if %errorlevel%==0 (
      magick convert "%REPO_ROOT%app.png" -resize 256x256 "%REPO_ROOT%app.ico"
      echo [INFO] Icon created successfully
    ) else (
      echo [WARN] ImageMagick not found, using default icon
      echo [INFO] You can manually create app.ico from app.png
      echo [INFO] Or install ImageMagick from: https://imagemagick.org/
    )
  ) else (
    echo [WARN] app.png not found, installer will use default icon
  )
)

REM Create installer output directory
if not exist "%INSTALLER_DIR%" mkdir "%INSTALLER_DIR%"

REM Build installer
echo [4/5] Building installer...
"%INNO_SETUP_COMPILER%" "%REPO_ROOT%installer.iss" /O"%INSTALLER_DIR%" /F"汐-Setup-1.4.4"
if errorlevel 1 (
  echo [ERROR] Installer build failed!
  pause
  exit /b 1
)

REM Open output directory
echo [5/5] Opening output directory...
if exist "%INSTALLER_DIR%" (
  start "" "%INSTALLER_DIR%"
) else (
  echo [WARN] Output directory not found: %INSTALLER_DIR%
)

echo.
echo ======================================================
echo Installer Build Complete!
echo Location: %INSTALLER_DIR%
echo ======================================================
echo.

REM Display file info
if exist "%INSTALLER_DIR%\汐-Setup-1.4.4.exe" (
  for %%F in ("%INSTALLER_DIR%\汐-Setup-1.4.4.exe" do (
    echo Installer: %%F
    echo Size: %%~zF bytes
  )
)

echo.
pause
