# 📱 Universal Phone Update & Upload Guide (AXOR)

This guide contains **all universal commands and 1-click methods** to build, update, and upload the AXOR app directly to your Android phone without needing to ask anyone.

---

## ⚡ 1-Click Instant Update (Easiest Method)

We have created an automated update script: **`update_phone.bat`**.

Whenever your phone is connected (via USB or Wi-Fi):
1. Open PowerShell or Command Prompt in `axor_app`:
   ```bat
   .\update_phone.bat
   ```
   *(Or simply double-click `update_phone.bat` in Windows File Explorer)*
2. It automatically checks for your phone, builds an optimized release APK, and updates the app **without losing your songs, login, or settings** (`-r` flag).

---

## 🚀 Universal Commands Cheat Sheet

Run all commands from the `axor_app` folder (`d:\AOI_ABHIJIT\My study\Programming\AxoR\axor_app`):

### 1. Fast Development / Testing (with Hot Reload)
Run and test changes live on your phone:
```bash
# Detect attached devices
flutter devices

# Run directly on your connected phone
flutter run
```
> **Pro Tip**: Press `r` in the terminal for instant Hot Reload, or `R` for Hot Restart.

---

### 2. Fast Release Install (Full Production Performance)
Installs the full-speed release version directly on your phone:
```bash
flutter run --release
```

---

### 3. Build & Install via ADB (Safe Update - Keeps User Data)
If you want to compile the standalone APK and push it to your device:

```bash
# Step 1: Build lightweight, phone-optimized APK (ARM64)
flutter build apk --split-per-abi

# Step 2: Install/Update on phone (-r keeps all existing app data & accounts)
adb install -r -d build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

*(If you ever need a universal APK that works on any phone architecture:)*
```bash
flutter build apk --release
adb install -r -d build\app\outputs\flutter-apk\app-release.apk
```

---

### 4. Fast Reinstall (Without Rebuilding If APK Exists)
```bash
flutter install -r
```

---

## 📶 Wireless Update (Update Without Any USB Cable)

You can update the AXOR app on your phone completely over your home Wi-Fi!

### One-Time Setup:
1. Connect your phone to your PC with a USB cable **once**.
2. Enable port 5555 on your phone:
   ```bash
   adb tcpip 5555
   ```
3. Disconnect the USB cable.
4. On your phone, go to **Settings → Wi-Fi → Tap your connected Wi-Fi** to find your phone's IP address (e.g., `192.168.1.5` or `192.168.0.102`).
5. Connect your PC to your phone over Wi-Fi:
   ```bash
   adb connect <PHONE_IP>:5555
   # Example: adb connect 192.168.1.5:5555
   ```
6. Verify connection:
   ```bash
   adb devices
   ```
   You will see `<PHONE_IP>:5555    device`.

### From now on:
Anytime your phone is on the same Wi-Fi, you can run:
```bash
flutter run
# OR
adb install -r -d build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```
No cable required!

---

## 🛠️ Phone Setup Checklist (Do This Once on Your Phone)

If your PC does not detect your phone:
1. **Developer Options**:
   - Go to **Settings → About Phone**.
   - Tap **Build Number** 7 times until you see *"You are now a developer!"*.
2. **USB Debugging**:
   - Go to **Settings → System / Additional Settings → Developer Options**.
   - Turn **ON** `USB Debugging`.
   - On brands like Xiaomi, Honor, Realme, Vivo, Oppo: also turn **ON** `Install via USB`.
3. **Connect to PC**:
   - Select **File Transfer (MTP)** mode on phone notification.
   - A popup will appear on your phone asking *"Allow USB debugging from this computer?"* → Check **"Always allow"** and tap **OK**.

---

## 🔧 Useful Troubleshooting Commands

| Situation | Command |
| :--- | :--- |
| Check if phone is detected | `adb devices` |
| Restart ADB server if frozen | `adb kill-server && adb start-server` |
| Clear Flutter cache before clean build | `flutter clean && flutter pub get` |
| View live Android logs from app | `adb logcat -s Flutter AXOR` |
| Uninstall app completely (if needed) | `adb uninstall com.example.axor_app` |
