# AXOR Music Player

A high-performance, battery-optimized music streaming and local player built with Flutter and Node.js.

## Highlights
- **Cloud & Offline Sync**: Seamless streaming from your personal Google Drive database with local-first offline caching via Hive.
- **Dynamic Island & Lockscreen**: Floating mini-player with synchronized album artwork lockscreen wallpaper.
- **Synced Lyrics**: Embedded and real-time synchronized `.lrc` lyrics with LRCLIB integration.
- **Battery & Memory Optimized**: Constrained image caches, strict LRU eviction, and zero background drain.
- **1-Click Phone Updater**: Automated batch updater script with auto-reconnecting ADB recovery.

---

## Project Structure

```
├── axor_app/              # Flutter mobile application
│   ├── lib/               # Dart source code (providers, screens, services, widgets)
│   ├── android/           # Android platform configuration (Impeller enabled)
│   └── update_phone.bat   # 1-Click build & phone updater
│
├── tools/                 # Database indexing & asset extraction tools
│   ├── axor_database_sync.py      # Synchronize AxoR DataBase structure
│   └── extract_database_assets.py # Extract artwork and synced lyrics
│
├── update_phone.bat       # Root 1-click phone updater
└── axor/                  # Backend & Architecture documentation
    └── axor_app_backend/  # Node.js backend server
```

---

## Google Drive Database Structure

AxoR organizes your personal cloud music library under a dedicated `AxoR DataBase` folder:

```
AxoR DataBase/
├── index.json             # Enriched metadata (titles, artists, mood, energy, bpm)
├── Liked_music/           # Audio files (.mp3, .flac, .m4a, .wav, .opus)
├── Liked_music_logo/      # High-res album covers & track logos (.jpg, .png, .webp)
└── Liked_music_lyrics/    # Synchronized lyrics (.lrc, .txt)
```

### Automatic Name Parsing Rule:
- **Song ID**: Preserves exact downloaded base name for library reconciliation.
- **Artist & Title**: Split on the **last `-`** in the file name:
  - Text before the last `-` = Artist(s)
  - Text after the last `-` = Song Title (displayed prominently)

---

## Quick Start

### 1-Click Phone Update
Connect your phone with **USB Debugging** enabled and run:
```bat
.\update_phone.bat
```
The script auto-detects Flutter, ADB platform-tools, re-establishes offline devices, builds an optimized ARM64 release APK, and streams the update to your phone while keeping all user data intact.

### Flutter App (Local Development)
```bash
cd axor_app
flutter pub get
flutter run
```

---

## Tech Stack
- **Frontend**: Flutter 3 (Impeller engine), Provider state management, `just_audio`
- **Storage & Caching**: Google Drive API v3, Hive offline NoSQL, CachedNetworkImage
- **Lyrics & Metadata**: Synced `.lrc` parser, LRCLIB API fallback
- **Backend**: Node.js, Express

---

## License
MIT License • Built with ❤️ by Aoi
