@echo off
setlocal enabledelayedexpansion

echo [1/4] Cleaning project...
call flutter clean

echo [2/4] Fetching dependencies...
call flutter pub get

echo [3/4] Building ABI Split Release APKs...
:: Using --split-per-abi to generate separate APKs for each architecture
:: Note: The output names and ABI includes are further customized in android/app/build.gradle.kts
call flutter build apk --release --split-per-abi

echo [4/4] Opening output directory...
start "" "build\app\outputs\flutter-apk\"

echo.
echo ======================================================
echo Build Complete!
echo ABI-specific APKs have been generated in:
echo build\app\outputs\flutter-apk\
echo ======================================================
pause
