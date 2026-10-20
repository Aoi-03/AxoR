# AXOR Phone Updater for PowerShell
$ErrorActionPreference = "Stop"

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "              AXOR MOBILE APP - 1-CLICK UPDATER          " -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "$scriptDir\pubspec.yaml") {
    Set-Location "$scriptDir"
} elseif (Test-Path "$scriptDir\axor_app\pubspec.yaml") {
    Set-Location "$scriptDir\axor_app"
} else {
    Write-Host "[ERROR] Could not locate axor_app directory!" -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    exit 1
}

Write-Host "[*] Checking connected Android devices..." -ForegroundColor Yellow
& adb devices
Write-Host ""

$adbState = (& adb get-state 2>$null)
if ($LASTEXITCODE -ne 0 -or $adbState.Trim() -ne "device") {
    Write-Host "[!] No authorized Android phone detected." -ForegroundColor Red
    Write-Host ""
    Write-Host "Please make sure:"
    Write-Host "  1. Your phone is connected via USB."
    Write-Host "  2. USB Debugging is turned ON in Developer Options."
    Write-Host "  3. You tap 'Allow' on the USB Debugging prompt on your phone screen."
    Write-Host "  4. Or connect wirelessly via: adb connect <PHONE_IP>:5555"
    Write-Host ""
    Read-Host "Press Enter to exit..."
    exit 1
}

Write-Host "[OK] Phone detected!" -ForegroundColor Green
Write-Host ""
Write-Host "[*] Building optimized ARM64 release APK..." -ForegroundColor Yellow
& flutter build apk --split-per-abi

$apkPath = "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
if (-not (Test-Path $apkPath)) {
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
}

if (-not (Test-Path $apkPath)) {
    Write-Host "[ERROR] APK build failed or APK not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    exit 1
}

Write-Host ""
Write-Host "[*] Installing/Updating AXOR on your phone (Keeping all songs and data)..." -ForegroundColor Yellow
& adb install -r -d "$apkPath"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host "[SUCCESS] AXOR has been updated successfully on your phone!" -ForegroundColor Green
    Write-Host "=========================================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[ERROR] Failed to install APK on your phone." -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit..."
