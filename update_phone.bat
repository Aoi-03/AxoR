@echo off
setlocal enabledelayedexpansion

title AXOR Phone Updater
color 0B

echo =========================================================
echo               AXOR MOBILE APP - 1-CLICK UPDATER
echo =========================================================
echo.

:: Ensure we are in the axor_app directory
cd /d "%~dp0"
if not exist "pubspec.yaml" (
    if exist "axor_app\pubspec.yaml" (
        cd /d "%~dp0axor_app"
    ) else (
        echo [ERROR] Could not locate axor_app directory!
        pause
        exit /b 1
    )
)

:: Auto-detect Flutter if not in PATH
where flutter >nul 2>&1
if errorlevel 1 (
    if exist "C:\flutter\bin" set "PATH=C:\flutter\bin;!PATH!"
    if exist "D:\flutter\bin" set "PATH=D:\flutter\bin;!PATH!"
    if exist "%LOCALAPPDATA%\flutter\bin" set "PATH=%LOCALAPPDATA%\flutter\bin;!PATH!"
)

:: Auto-detect ADB if not in PATH
where adb >nul 2>&1
if errorlevel 1 (
    if exist "C:\Users\LUNA\AppData\Local\Android\Sdk\platform-tools" set "PATH=C:\Users\LUNA\AppData\Local\Android\Sdk\platform-tools;!PATH!"
    if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools" set "PATH=%LOCALAPPDATA%\Android\Sdk\platform-tools;!PATH!"
    if exist "C:\Android\Sdk\platform-tools" set "PATH=C:\Android\Sdk\platform-tools;!PATH!"
)

:: Check if flutter is found now
where flutter >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Flutter was not found on your system!
    echo Please make sure Flutter is installed or add its 'bin' folder to PATH.
    echo Default expected location: C:\flutter\bin
    echo.
    pause
    exit /b 1
)

echo [*] Checking connected Android devices...
adb devices
echo.

adb reconnect offline >nul 2>&1
adb get-state >nul 2>&1
if errorlevel 1 (
    adb reconnect >nul 2>&1
    adb get-state >nul 2>&1
)
if errorlevel 1 goto :no_device

echo [OK] Phone detected!
echo.
echo [*] Building optimized ARM64 release APK (Fast and Lightweight)...
call flutter build apk --split-per-abi
if errorlevel 1 (
    echo.
    echo [ERROR] Flutter build failed with exit code !errorlevel!
    pause
    exit /b 1
)

set "APK_PATH=build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
if not exist "!APK_PATH!" (
    set "APK_PATH=build\app\outputs\flutter-apk\app-release.apk"
)

if not exist "!APK_PATH!" (
    echo.
    echo [ERROR] APK build failed or APK not found!
    pause
    exit /b 1
)

echo.
echo [*] Installing/Updating AXOR on your phone (Keeping all songs and data)...
adb install -r -d "!APK_PATH!"

if errorlevel 1 goto :install_failed

echo.
echo =========================================================
echo [SUCCESS] AXOR has been updated successfully on your phone!
echo =========================================================
echo.
pause
exit /b 0

:no_device
echo [!] No authorized Android phone detected.
echo.
echo Please make sure:
echo   1. Your phone is connected via USB.
echo   2. USB Debugging is turned ON in Developer Options.
echo   3. You tap Allow on the USB Debugging prompt on your phone screen.
echo   4. Or connect wirelessly via: adb connect PHONE_IP:5555
echo.
pause
exit /b 1

:install_failed
echo.
echo [ERROR] Failed to install APK on your phone.
pause
exit /b 1
