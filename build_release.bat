@echo off
setlocal enabledelayedexpansion

set "REPO_ROOT=%~dp0"
set "VERSION=1.4.4"
set "RELEASE_DIR=%REPO_ROOT%release"

echo ======================================================
echo Release Build Script for 汐
echo Version: %VERSION%
echo ======================================================
echo.

REM Parse command line arguments
set "BUILD_WINDOWS=1"
set "BUILD_ANDROID=1"
set "BUILD_INSTALLER=1"
set "BUILD_ZIP=1"

:parse_args
if "%~1"=="" goto end_parse
if /i "%~1"=="--no-android" set "BUILD_ANDROID=0"
if /i "%~1"=="--no-windows" set "BUILD_WINDOWS=0"
if /i "%~1"=="--no-installer" set "BUILD_INSTALLER=0"
if /i "%~1"=="--no-zip" set "BUILD_ZIP=0"
if /i "%~1"=="--installer-only" (
  set "BUILD_ANDROID=0"
  set "BUILD_WINDOWS=0"
  set "BUILD_ZIP=0"
)
shift
goto parse_args

:end_parse

echo Build Options:
echo   - Android APK: %BUILD_ANDROID%
echo   - Windows: %BUILD_WINDOWS%
echo   - Installer: %BUILD_INSTALLER%
echo   - ZIP Package: %BUILD_ZIP%
echo.

REM Create release directory
if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"

REM Build Windows version
if %BUILD_WINDOWS%==1 (
  echo [Step 1/4] Building Windows application...
  call "%REPO_ROOT%build_windows_release.bat"
  if errorlevel 1 (
    echo [ERROR] Windows build failed!
    pause
    exit /b 1
  )
)

REM Build Android version
if %BUILD_ANDROID%==1 (
  echo [Step 2/4] Building Android APK...
  call "%REPO_ROOT%build_abi_release.bat"
  if errorlevel 1 (
    echo [ERROR] Android build failed!
    pause
    exit %BUILD_ANDROID%
  )
)

REM Create ZIP package for Windows
if %BUILD_ZIP%==1 (
  if exist "%REPO_ROOT%build\windows\x64\runner\Release\汐.exe" (
    echo [Step 3/4] Creating ZIP package for Windows...
    set "ZIP_FILE=%RELEASE_DIR%\汐-%VERSION%-Windows-x64.zip"
    powershell -Command "& {Compress-Archive -Path '%REPO_ROOT%build\windows\x64\runner\Release\*' -DestinationPath '!ZIP_FILE!' -Force}"
    if errorlevel 1 (
      echo [WARN] Failed to create ZIP package
    ) else (
      echo [INFO] Created: !ZIP_FILE!
    )
  )
)

REM Build installer
if %BUILD_INSTALLER%==1 (
  if exist "%REPO_ROOT%build\windows\x64\runner\Release\汐.exe" (
    echo [Step 4/4] Building installer...
    call "%REPO_ROOT%build_installer.bat"
    if errorlevel 1 (
      echo [WARN] Installer build failed, skipping...
    ) else (
      REM Copy installer to release directory
      if exist "%REPO_ROOT%installer\汐-Setup-%VERSION%.exe" (
        copy /Y "%REPO_ROOT%installer\汐-Setup-%VERSION%.exe" "%RELEASE_DIR%\" >nul
        echo [INFO] Installer copied to release directory
      )
    )
  )
)

REM Copy Android APKs to release directory
if %BUILD_ANDROID%==1 (
  if exist "%REPO_ROOT%build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" (
    echo [INFO] Copying Android APKs...
    copy /Y "%REPO_ROOT%build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "%RELEASE_DIR%\汐-%VERSION%-arm64-v8a.apk" >nul
    copy /Y "%REPO_ROOT%build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "%RELEASE_DIR%\汐-%VERSION%-armeabi-v7a.apk" >nul
    copy /Y "%REPO_ROOT%build\app\outputs\flutter-apk\app-x86_64-release.apk" "%RELEASE_DIR%\汐-%VERSION%-x86_64.apk" >nul
    echo [INFO] Android APKs copied to release directory
  )
)

REM Create release notes
echo [INFO] Creating release notes...
(
  echo # 汐 %VERSION% Release
  echo.
  echo ## 下载说明
  echo.
  echo ### Windows 用户
  echo - **汐-%VERSION%-Windows-x64.zip** - 便携版，解压即用
  echo - **汐-Setup-%VERSION%.exe** - 安装版，推荐普通用户使用
  echo.
  echo ### Android 用户
  echo - **汐-%VERSION%-arm64-v8a.apk** - 适用于大多数现代 Android 设备 ^(推荐^)
  echo - **汐-%VERSION%-armeabi-v7a.apk** - 适用于较旧的 32 位 Android 设备
  echo - **汐-%VERSION%-x86_64.apk** - 适用于模拟器或 x86 设备
  echo.
  echo ## 系统要求
  echo.
  echo ### Windows
  echo - Windows 10/11 ^(64-bit^)
  echo - WebView2 运行时 ^(Windows 11 默认包含^)
  echo.
  echo ### Android
  echo - Android 5.0 ^(API 21^) 或更高版本
  echo.
  echo ## 更新日志
  echo.
  echo - 添加 Windows 平台支持
  echo - 统一构建脚本
  echo - 优化应用性能
  echo.
  echo ## 反馈与支持
  echo.
  echo GitHub: https://github.com/jiuxina/ushio-md
  echo.
) > "%RELEASE_DIR%\RELEASE_NOTES.md"

echo.
echo ======================================================
echo Release Build Complete!
echo ======================================================
echo.
echo Output directory: %RELEASE_DIR%
echo.

REM List all release files
echo Release files:
dir /B "%RELEASE_DIR%\*" | findstr /V "^$"

echo.
echo Next steps:
echo 1. Test the Windows installer on a clean machine
echo 2. Test the Android APKs on different devices
echo 3. Upload release files to GitHub Releases
echo.
pause
