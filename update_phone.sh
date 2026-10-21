#!/usr/bin/env bash

# =========================================================
#               AXOR MOBILE APP - 1-CLICK UPDATER (LINUX)
# =========================================================

set -e

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}"

if [ ! -f "${APP_DIR}/pubspec.yaml" ]; then
    if [ -f "${APP_DIR}/axor_app/pubspec.yaml" ]; then
        APP_DIR="${APP_DIR}/axor_app"
    else
        echo "[ERROR] Could not locate axor_app directory or pubspec.yaml!"
        exit 1
    fi
fi

cd "${APP_DIR}"

# Check for required tools
if ! command -v adb &> /dev/null; then
    echo "[!] adb is not installed or not in PATH."
    echo "    On Ubuntu/Debian, install with: sudo apt install adb"
    exit 1
fi

if ! command -v flutter &> /dev/null; then
    echo "[!] flutter is not installed or not in PATH."
    echo "    Note: Flutter is currently installed on your Windows drive."
    echo "    To build from Linux, install Flutter for Linux, or reboot into Windows to run update_phone.bat."
    exit 1
fi

echo "[*] Checking connected Android devices..."
adb devices
echo

if ! adb get-state &> /dev/null; then
    echo "[!] No authorized Android phone detected."
    echo
    echo "Please make sure:"
    echo "  1. Your phone is connected via USB."
    echo "  2. USB Debugging is turned ON in Developer Options."
    echo "  3. You tap 'Allow' on the USB Debugging prompt on your phone screen."
    echo "  4. Or connect wirelessly via: adb connect PHONE_IP:5555"
    echo
    exit 1
fi

echo "[OK] Phone detected!"
echo
echo "[*] Building optimized ARM64 release APK (Fast and Lightweight)..."
flutter build apk --split-per-abi

APK_PATH="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
if [ ! -f "${APK_PATH}" ]; then
    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
fi

if [ ! -f "${APK_PATH}" ]; then
    echo
    echo "[ERROR] APK build failed or APK not found!"
    exit 1
fi

echo
echo "[*] Installing/Updating AXOR on your phone (Keeping all songs and data)..."
adb install -r -d "${APK_PATH}"

echo
echo "========================================================="
echo "[SUCCESS] AXOR has been updated successfully on your phone!"
echo "========================================================="

