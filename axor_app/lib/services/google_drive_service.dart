import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

/// Resolved database folders in Google Drive
class DatabaseFolders {
  final List<String> musicFolderIds;
  final List<String> logoFolderIds;
  final List<String> lyricsFolderIds;
  final String primaryMusicFolderId;
  final String? primaryLogoFolderId;
  final String? primaryLyricsFolderId;

  DatabaseFolders({
    required this.musicFolderIds,
    required this.logoFolderIds,
    required this.lyricsFolderIds,
    required this.primaryMusicFolderId,
    this.primaryLogoFolderId,
    this.primaryLyricsFolderId,
  });
}

/// Google Drive Service
/// Handles OAuth, file listing, and audio streaming from user's Drive
class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  /// Audio MIME types supported
  static const List<String> _audioMimeTypes = [
    'audio/mpeg',       // .mp3
    'audio/mp4',        // .m4a
    'audio/x-m4a',      // .m4a variant
    'audio/aac',        // .aac
    'audio/ogg',        // .ogg
    'audio/flac',       // .flac
    'audio/wav',        // .wav
    'audio/x-wav',      // .wav variant
    'audio/webm',       // .webm
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveReadonlyScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  http.Client? _httpClient;
  String? _axorFolderId;
  Map<String, String>? _cachedAuthHeaders;

  // ── Getters ──────────────────────────────────────────
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  String? get userEmail => _currentUser?.email;
  String? get userName => _currentUser?.displayName;
  String? get userPhotoUrl => _currentUser?.photoUrl;
  String? get axorFolderId => _axorFolderId;
  Map<String, String>? get cachedAuthHeaders => _cachedAuthHeaders;

  // ── Auth ──────────────────────────────────────────────

  /// Try to sign in silently (for returning users)
  Future<bool> trySilentSignIn() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        await _initDriveApi();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('Silent sign-in failed: $e');
      return false;
    }
  }

  /// Interactive sign-in
  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) {
        await _initDriveApi();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('Sign-in error: $e');
      return false;
    }
  }

  /// Sign out completely
  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _currentUser = null;
    _driveApi = null;
    _httpClient?.close();
    _httpClient = null;
    _axorFolderId = null;
    _cachedAuthHeaders = null;
  }

  /// Initialize Drive API client and resolve dedicated AxoR folder
  Future<void> _initDriveApi() async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient != null) {
      _httpClient = httpClient;
      _driveApi = drive.DriveApi(httpClient);
      await getAuthHeaders(); // Pre-cache bearer headers for image/stream requests
      await getOrCreateAxorFolder();
    }
  }

  /// Helper: Check whether a drive file is an audio track by extension or mimeType
  bool _isAudioDriveFile(drive.File f) {
    final name = (f.name ?? '').toLowerCase().trim();
    final mime = (f.mimeType ?? '').toLowerCase().trim();

    // Positive audio extensions
    for (final ext in [
      '.mp3',
      '.flac',
      '.m4a',
      '.wav',
      '.ogg',
      '.aac',
      '.opus',
      '.wma',
      '.webm'
    ]) {
      if (name.endsWith(ext)) return true;
    }

    // Exclude non-audio files (images, docs, text, json)
    if (name.endsWith('.json') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.lrc') ||
        name.endsWith('.txt') ||
        name.endsWith('.pdf')) {
      return false;
    }

    if (mime.startsWith('audio/')) return true;

    return false;
  }

  /// Finds or automatically creates the dedicated "AxoR DataBase" (or "AxoR Music") folder in the user's Drive.
  /// Uses case-insensitive substring matching so "Axor Database", "AxoR DataBase", "AxoR Music", etc. are always found.
  Future<String?> getOrCreateAxorFolder() async {
    if (_driveApi == null) return null;
    if (_axorFolderId != null) return _axorFolderId;

    try {
      // 1. Broad query to discover ANY candidate folder in the user's Drive
      final query = "mimeType='application/vnd.google-apps.folder' and trashed=false and ("
          "name contains 'AxoR' or name contains 'axor' or name contains 'Axor' or "
          "name contains 'DataBase' or name contains 'Database' or name contains 'database' or "
          "name contains 'Music' or name contains 'music')";

      final fileList = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, modifiedTime)',
        pageSize: 50,
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        drive.File? bestMatch;

        // Priority 1: Exact / Normalized matches for "AxoR DataBase" variants
        for (final f in fileList.files!) {
          final n = (f.name ?? '').toLowerCase().trim().replaceAll('_', ' ').replaceAll('-', ' ');
          if (n == 'axor database' || n == 'axor data base') {
            bestMatch = f;
            break;
          }
        }

        // Priority 2: "AxoR Music" variants
        if (bestMatch == null) {
          for (final f in fileList.files!) {
            final n = (f.name ?? '').toLowerCase().trim().replaceAll('_', ' ').replaceAll('-', ' ');
            if (n == 'axor music') {
              bestMatch = f;
              break;
            }
          }
        }

        // Priority 3: Any folder with "axor" in the name
        if (bestMatch == null) {
          for (final f in fileList.files!) {
            final n = (f.name ?? '').toLowerCase();
            if (n.contains('axor')) {
              bestMatch = f;
              break;
            }
          }
        }

        // Priority 4: Any folder containing "music" or "database"
        if (bestMatch == null) {
          for (final f in fileList.files!) {
            final n = (f.name ?? '').toLowerCase();
            if (n.contains('music') || n.contains('database')) {
              bestMatch = f;
              break;
            }
          }
        }

        bestMatch ??= fileList.files!.first;
        _axorFolderId = bestMatch.id;
        if (kDebugMode) print('📁 Resolved AxoR folder: "${bestMatch.name}" (ID: $_axorFolderId)');
        return _axorFolderId;
      }

      // Auto-create "AxoR DataBase" folder only if completely absent
      final folderMetadata = drive.File()
        ..name = 'AxoR DataBase'
        ..mimeType = 'application/vnd.google-apps.folder'
        ..description = 'Dedicated music database for AxoR Player';

      final createdFolder = await _driveApi!.files.create(folderMetadata);
      _axorFolderId = createdFolder.id;
      if (kDebugMode) print('📁 Created initial AxoR DataBase folder: $_axorFolderId');
      return _axorFolderId;
    } catch (e) {
      if (kDebugMode) print('Error finding or creating AxoR folder: $e');
      return null;
    }
  }

  /// Discovers all database subfolders inside root: Liked_music, Liked_music_logo, Liked_music_lyrics, etc.
  /// Collects folder IDs so searches encompass the root AND all relevant subfolders.
  Future<DatabaseFolders> _resolveDatabaseFolders(String rootFolderId) async {
    final Set<String> musicFolders = {rootFolderId};
    final Set<String> logoFolders = {rootFolderId};
    final Set<String> lyricsFolders = {rootFolderId};
    String? primaryMusic;
    String? primaryLogo;
    String? primaryLyrics;

    if (_driveApi == null) {
      return DatabaseFolders(
        musicFolderIds: musicFolders.toList(),
        logoFolderIds: logoFolders.toList(),
        lyricsFolderIds: lyricsFolders.toList(),
        primaryMusicFolderId: rootFolderId,
      );
    }

    try {
      final query = "mimeType='application/vnd.google-apps.folder' and trashed=false and '$rootFolderId' in parents";
      final list = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
        pageSize: 50,
      );

      if (list.files != null) {
        for (final f in list.files!) {
          final id = f.id;
          if (id == null) continue;
          final n = (f.name ?? '').toLowerCase().trim().replaceAll(' ', '_').replaceAll('-', '_');

          if (n.contains('logo') || n.contains('cover') || n.contains('art') || n.contains('image')) {
            logoFolders.add(id);
            primaryLogo ??= id;
          } else if (n.contains('lyric') || n.contains('lrc') || n.contains('text')) {
            lyricsFolders.add(id);
            primaryLyrics ??= id;
          } else if (n.contains('music') || n.contains('song') || n.contains('track') || n.contains('audio') || n.contains('liked')) {
            musicFolders.add(id);
            primaryMusic ??= id;
          } else {
            // General subfolder (could be an artist/album subfolder)
            musicFolders.add(id);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Folder discovery non-fatal: $e');
    }

    return DatabaseFolders(
      musicFolderIds: musicFolders.toList(),
      logoFolderIds: logoFolders.toList(),
      lyricsFolderIds: lyricsFolders.toList(),
      primaryMusicFolderId: primaryMusic ?? rootFolderId,
      primaryLogoFolderId: primaryLogo,
      primaryLyricsFolderId: primaryLyrics,
    );
  }

  /// Reads and parses index.json if present in candidate folders
  Future<Map<String, Map<String, dynamic>>> _readIndexJsonMap(List<String> folderIds) async {
    final Map<String, Map<String, dynamic>> indexMap = {};
    if (_driveApi == null) return indexMap;

    for (final folderId in folderIds) {
      try {
        final query = "name='index.json' and trashed=false and '$folderId' in parents";
        final list = await _driveApi!.files.list(
          q: query,
          spaces: 'drive',
          $fields: 'files(id, name)',
          pageSize: 1,
        );

        if (list.files != null && list.files!.isNotEmpty) {
          final fileId = list.files!.first.id!;
          final media = await _driveApi!.files.get(
            fileId,
            downloadOptions: drive.DownloadOptions.fullMedia,
          ) as drive.Media;

          final bytes = <int>[];
          await for (final chunk in media.stream) {
            bytes.addAll(chunk);
          }

          final jsonStr = utf8.decode(bytes);
          final dynamic parsed = jsonDecode(jsonStr);
          List items = [];
          if (parsed is List) {
            items = parsed;
          } else if (parsed is Map && parsed['songs'] is List) {
            items = parsed['songs'];
          } else if (parsed is Map && parsed['tracks'] is List) {
            items = parsed['tracks'];
          }

          for (final item in items) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final id = (map['id'] ?? '').toString().toLowerCase().trim();
              final name = (map['name'] ?? '').toString().toLowerCase().trim();
              final title = (map['title'] ?? '').toString().toLowerCase().trim();
              final artist = (map['artist'] ?? '').toString().toLowerCase().trim();
              final base = name.replaceAll(RegExp(r'\.[^.]+$'), '').trim();

              if (id.isNotEmpty) indexMap[id] = map;
              if (name.isNotEmpty) indexMap[name] = map;
              if (base.isNotEmpty) indexMap[base] = map;
              if (title.isNotEmpty) indexMap[title] = map;
              if (artist.isNotEmpty && title.isNotEmpty) {
                indexMap['$artist - $title'] = map;
              }
              final cleanNum = base.replaceFirst(RegExp(r'^\d+[\.\s\-_]+'), '').trim();
              if (cleanNum.isNotEmpty) {
                indexMap[cleanNum] = map;
              }
            }
          }
          if (kDebugMode) print('📖 Loaded ${indexMap.length} index keys from index.json (folder $folderId)');
          break; // Stop after first valid index.json found
        }
      } catch (e) {
        if (kDebugMode) print('Index read non-fatal: $e');
      }
    }
    return indexMap;
  }

  /// Asynchronously auto-generate and synchronize index.json in the AxoR DataBase folder
  Future<void> _syncIndexJson(String rootFolderId, List<DriveAudioFile> songs) async {
    if (_driveApi == null || songs.isEmpty) return;
    try {
      final indexData = jsonEncode(songs.map((s) => s.toJson()).toList());
      final query = "name='index.json' and trashed=false and '$rootFolderId' in parents";
      final existing = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      final media = drive.Media(
        Stream.value(utf8.encode(indexData)),
        utf8.encode(indexData).length,
      );

      if (existing.files != null && existing.files!.isNotEmpty) {
        final fileId = existing.files!.first.id!;
        await _driveApi!.files.update(drive.File(), fileId, uploadMedia: media);
        if (kDebugMode) print('✅ Automatically synced index.json (${songs.length} songs)');
      } else {
        final fileMetadata = drive.File()
          ..name = 'index.json'
          ..parents = [rootFolderId]
          ..mimeType = 'application/json';
        await _driveApi!.files.create(fileMetadata, uploadMedia: media);
        if (kDebugMode) print('✅ Created index.json in AxoR DataBase (${songs.length} songs)');
      }
    } catch (e) {
      if (kDebugMode) print('Index sync non-fatal error: $e');
    }
  }

  // ── File Listing ──────────────────────────────────────

  /// List audio files from Drive with automatic AxoR DataBase structure mapping:
  /// AxoR DataBase -> index.json, Liked_music, Liked_music_lyrics, Liked_music_logo
  Future<List<DriveAudioFile>> listAudioFiles({
    String? folderId,
    String? pageToken,
    int pageSize = 1000,
  }) async {
    if (_driveApi == null) return [];

    try {
      // Pre-refresh headers cache so image and lyrics requests have valid tokens
      await getAuthHeaders();

      final rootFolderId = folderId ?? await getOrCreateAxorFolder();
      if (rootFolderId == null) return [];

      // 1. Resolve subfolders (Liked_music, Liked_music_logo, Liked_music_lyrics)
      final dbFolders = await _resolveDatabaseFolders(rootFolderId);

      // 2. Discover companion artwork/cover images in all logo folders (with full pagination)
      final Map<String, String> logoMap = {};
      try {
        for (final parent in dbFolders.logoFolderIds) {
          final isDedicated = parent != rootFolderId;
          final imgQuery = isDedicated
              ? "trashed=false and '$parent' in parents"
              : "(mimeType contains 'image/' or name contains '.jpg' or name contains '.png' or name contains '.webp') and trashed=false and '$parent' in parents";

          String? pToken;
          do {
            final imgList = await _driveApi!.files.list(
              q: imgQuery,
              spaces: 'drive',
              $fields: 'nextPageToken, files(id, name, thumbnailLink, webContentLink)',
              pageSize: 1000,
              pageToken: pToken,
            );
            if (imgList.files != null) {
              for (final img in imgList.files!) {
                final raw = (img.name ?? '').toLowerCase().trim();
                final base = raw.replaceAll(RegExp(r'\.[^.]+$'), '').trim();

                // High-resolution Google CDN thumbnail or direct Drive API media URL
                final imgUrl = (img.thumbnailLink != null && img.thumbnailLink!.isNotEmpty)
                    ? img.thumbnailLink!.replaceAll(RegExp(r'=s\d+'), '=s500')
                    : 'https://www.googleapis.com/drive/v3/files/${img.id}?alt=media';

                logoMap[base] = imgUrl;
                logoMap[raw] = imgUrl;

                // Stripped track numbers (e.g. "01. Song" -> "song")
                final cleanNum = base.replaceFirst(RegExp(r'^\d+[\.\s\-_]+'), '').trim();
                if (cleanNum.isNotEmpty) {
                  logoMap[cleanNum] = imgUrl;
                }

                final dash = base.lastIndexOf('-');
                if (dash > 0 && dash < base.length - 1) {
                  final artistPart = base.substring(0, dash).trim();
                  final titlePart = base.substring(dash + 1).trim();
                  logoMap[titlePart] = imgUrl;
                  logoMap['$artistPart - $titlePart'] = imgUrl;
                }
              }
            }
            pToken = imgList.nextPageToken;
          } while (pToken != null && pToken.isNotEmpty);
        }
      } catch (e) {
        if (kDebugMode) print('Artwork discovery non-fatal: $e');
      }

      final generalCover = logoMap['cover'] ??
          logoMap['folder'] ??
          logoMap['albumart'] ??
          logoMap['art'] ??
          logoMap['logo'];

      // 3. Discover companion lyrics in all lyrics folders (with full pagination)
      final Map<String, String> lyricsMap = {};
      try {
        for (final parent in dbFolders.lyricsFolderIds) {
          final isDedicated = parent != rootFolderId;
          final lrcQuery = isDedicated
              ? "trashed=false and '$parent' in parents"
              : "(mimeType contains 'text/' or name contains '.lrc' or name contains '.txt') and trashed=false and '$parent' in parents";

          String? pToken;
          do {
            final lrcList = await _driveApi!.files.list(
              q: lrcQuery,
              spaces: 'drive',
              $fields: 'nextPageToken, files(id, name, webContentLink)',
              pageSize: 1000,
              pageToken: pToken,
            );
            if (lrcList.files != null) {
              for (final lrc in lrcList.files!) {
                final raw = (lrc.name ?? '').toLowerCase().trim();
                final base = raw.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
                final lrcUrl = 'https://www.googleapis.com/drive/v3/files/${lrc.id}?alt=media';
                lyricsMap[base] = lrcUrl;
                lyricsMap[raw] = lrcUrl;

                final cleanNum = base.replaceFirst(RegExp(r'^\d+[\.\s\-_]+'), '').trim();
                if (cleanNum.isNotEmpty) {
                  lyricsMap[cleanNum] = lrcUrl;
                }

                final dash = base.lastIndexOf('-');
                if (dash > 0 && dash < base.length - 1) {
                  final artistPart = base.substring(0, dash).trim();
                  final titlePart = base.substring(dash + 1).trim();
                  lyricsMap[titlePart] = lrcUrl;
                  lyricsMap['$artistPart - $titlePart'] = lrcUrl;
                }
              }
            }
            pToken = lrcList.nextPageToken;
          } while (pToken != null && pToken.isNotEmpty);
        }
      } catch (e) {
        if (kDebugMode) print('Lyrics discovery non-fatal: $e');
      }

      // 4. Try reading index.json if present (check rootFolderId first)
      final indexMap = await _readIndexJsonMap([rootFolderId, ...dbFolders.musicFolderIds]);

      // 5. Fetch audio files across all music folders with FULL pagination
      final List<drive.File> candidateFiles = [];
      final Set<String> seenDriveFileIds = {};

      final audioExtQuery = "(mimeType contains 'audio/' or "
          "mimeType = 'video/mp4' or "
          "mimeType = 'application/octet-stream' or "
          "mimeType = 'binary/octet-stream' or "
          "name contains '.mp3' or "
          "name contains '.flac' or "
          "name contains '.m4a' or "
          "name contains '.wav' or "
          "name contains '.ogg' or "
          "name contains '.aac' or "
          "name contains '.opus' or "
          "name contains '.wma')";

      for (final folderId in dbFolders.musicFolderIds) {
        try {
          final isDedicated = folderId != rootFolderId;
          final folderQuery = isDedicated
              ? "mimeType != 'application/vnd.google-apps.folder' and trashed=false and '$folderId' in parents"
              : "$audioExtQuery and trashed=false and '$folderId' in parents";

          String? pToken;
          do {
            final fileList = await _driveApi!.files.list(
              q: folderQuery,
              spaces: 'drive',
              $fields:
                  'nextPageToken, files(id, name, mimeType, size, modifiedTime, parents, thumbnailLink, webContentLink)',
              pageSize: 1000,
              pageToken: pToken,
              orderBy: 'name',
            );

            if (fileList.files != null) {
              for (final f in fileList.files!) {
                if (f.id != null && seenDriveFileIds.add(f.id!)) {
                  if (_isAudioDriveFile(f)) {
                    candidateFiles.add(f);
                  }
                }
              }
            }
            pToken = fileList.nextPageToken;
          } while (pToken != null && pToken.isNotEmpty);
        } catch (e) {
          if (kDebugMode) print('Error scanning folder $folderId: $e');
        }
      }

      // 6. Global Drive-Wide Fallback: If no files found in designated folders, scan entire Drive for audio files with pagination
      if (candidateFiles.isEmpty) {
        if (kDebugMode) print('ℹ️ No audio files in AxoR folder candidates. Searching user Drive globally...');
        try {
          final globalQuery = "trashed=false and (mimeType contains 'audio/' or "
              "name contains '.mp3' or name contains '.flac' or name contains '.m4a' or "
              "name contains '.wav' or name contains '.ogg' or name contains '.opus')";

          String? pToken;
          do {
            final globalList = await _driveApi!.files.list(
              q: globalQuery,
              spaces: 'drive',
              $fields:
                  'nextPageToken, files(id, name, mimeType, size, modifiedTime, parents, thumbnailLink, webContentLink)',
              pageSize: 1000,
              pageToken: pToken,
              orderBy: 'name',
            );
            if (globalList.files != null) {
              for (final f in globalList.files!) {
                if (f.id != null && seenDriveFileIds.add(f.id!)) {
                  if (_isAudioDriveFile(f)) {
                    candidateFiles.add(f);
                  }
                }
              }
            }
            pToken = globalList.nextPageToken;
          } while (pToken != null && pToken.isNotEmpty);
        } catch (e) {
          if (kDebugMode) print('Global fallback search error: $e');
        }
      }

      final List<DriveAudioFile> result = [];
      for (final f in candidateFiles) {
        final name = f.name ?? 'Unknown';
        final baseName = name.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
        final lowerBase = baseName.toLowerCase();
        final cleanBase = baseName.replaceFirst(RegExp(r'^\d+[\.\s\-_]+'), '').trim();
        final lowerClean = cleanBase.toLowerCase();

        // User Rule:
        // Split on the LAST '-' appeared in the title.
        // Before last '-' is artist name
        // After last '-' is song name (which should be displayed prominently / before in app)
        final lastDash = baseName.lastIndexOf('-');
        String parsedArtist;
        String cleanTitle;
        if (lastDash > 0 && lastDash < baseName.length - 1) {
          parsedArtist = baseName.substring(0, lastDash).trim();
          cleanTitle = baseName.substring(lastDash + 1).trim();
        } else {
          parsedArtist = 'Unknown Artist';
          cleanTitle = baseName;
        }
        final lowerTitle = cleanTitle.toLowerCase();

        // Check index.json enrichment
        final indexEntry = indexMap[lowerBase] ??
            indexMap[lowerClean] ??
            indexMap[name.toLowerCase()] ??
            indexMap[lowerTitle];
        if (indexEntry != null) {
          if (indexEntry['title'] != null && indexEntry['title'].toString().isNotEmpty) {
            cleanTitle = indexEntry['title'].toString();
          }
          if (indexEntry['artist'] != null && indexEntry['artist'].toString().isNotEmpty) {
            parsedArtist = indexEntry['artist'].toString();
          }
        }

        // Auto-map logo
        final logoFileRef = indexEntry?['logoFile']?.toString().toLowerCase().trim();
        final logoBaseRef = logoFileRef?.replaceAll(RegExp(r'\.[^.]+$'), '').trim();

        final matchedCover = (logoFileRef != null ? (logoMap[logoFileRef] ?? (logoBaseRef != null ? logoMap[logoBaseRef] : null)) : null) ??
            logoMap[lowerBase] ??
            logoMap[lowerClean] ??
            logoMap['$lowerBase.jpg'] ??
            logoMap['$lowerBase.png'] ??
            logoMap[lowerTitle] ??
            (f.thumbnailLink != null && f.thumbnailLink!.isNotEmpty ? f.thumbnailLink!.replaceAll(RegExp(r'=s\d+'), '=s500') : null) ??
            generalCover;

        // Auto-map lyrics
        final lyricsFileRef = indexEntry?['lyricsFile']?.toString().toLowerCase().trim();
        final lyricsBaseRef = lyricsFileRef?.replaceAll(RegExp(r'\.[^.]+$'), '').trim();

        final matchedLyrics = (lyricsFileRef != null ? (lyricsMap[lyricsFileRef] ?? (lyricsBaseRef != null ? lyricsMap[lyricsBaseRef] : null)) : null) ??
            lyricsMap[lowerBase] ??
            lyricsMap[lowerClean] ??
            lyricsMap['$lowerBase.lrc'] ??
            lyricsMap['$lowerBase.txt'] ??
            lyricsMap[lowerTitle];

        final audioFile = DriveAudioFile(
          id: baseName, // EXACT downloaded name as ID for CSV/AxoR compatibility
          driveFileId: f.id ?? '',
          name: name,
          mimeType: f.mimeType ?? 'audio/mpeg',
          fileSize: int.tryParse(f.size ?? '0') ?? 0,
          modifiedTime: f.modifiedTime,
          thumbnailLink: matchedCover ?? f.thumbnailLink?.replaceAll(RegExp(r'=s\d+'), '=s500'),
          webContentLink: f.webContentLink,
          title: cleanTitle,
          artist: parsedArtist,
          album: indexEntry?['album']?.toString(),
          durationSeconds: indexEntry?['durationSeconds'] ?? indexEntry?['duration'],
          mood: indexEntry?['mood']?.toString(),
          genre: indexEntry?['genre']?.toString(),
          energy: indexEntry?['energy'] != null ? (indexEntry!['energy'] as num).toDouble() : null,
          bpm: indexEntry?['bpm'] != null ? (indexEntry!['bpm'] as num).toInt() : null,
          coverArtUrl: matchedCover,
          lyricsUrl: matchedLyrics,
        );

        result.add(audioFile);
      }

      // 7. Auto-generate index.json ONLY if one didn't already exist (protect user's database)
      if (indexMap.isEmpty) {
        _syncIndexJson(rootFolderId, result);
      }

      if (kDebugMode) {
        print('✅ listAudioFiles loaded ${result.length} audio tracks (folders checked: ${dbFolders.musicFolderIds.length})');
      }

      return result;
    } catch (e) {
      if (kDebugMode) print('Error listing audio files: $e');
      return [];
    }
  }

  /// Search audio files by name
  Future<List<DriveAudioFile>> searchAudioFiles(String query) async {
    if (_driveApi == null || query.trim().isEmpty) return [];

    try {
      final mimeQuery =
          _audioMimeTypes.map((m) => "mimeType='$m'").join(' or ');

      final searchQuery =
          "($mimeQuery) and trashed=false and name contains '${query.replaceAll("'", "\\'")}'";

      final fileList = await _driveApi!.files.list(
        q: searchQuery,
        spaces: 'drive',
        $fields:
            'files(id, name, mimeType, size, modifiedTime, parents, thumbnailLink, webContentLink)',
        pageSize: 50,
        orderBy: 'name',
      );

      return fileList.files
              ?.map((f) => DriveAudioFile.fromDriveFile(f))
              .toList() ??
          [];
    } catch (e) {
      if (kDebugMode) print('Error searching audio files: $e');
      return [];
    }
  }

  /// List folders in Drive (for folder browsing)
  Future<List<DriveFolder>> listFolders({String? parentId}) async {
    if (_driveApi == null) return [];

    try {
      String query = "mimeType='application/vnd.google-apps.folder' and trashed=false";
      if (parentId != null) {
        query += " and '$parentId' in parents";
      }

      final fileList = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, modifiedTime, parents)',
        pageSize: 100,
        orderBy: 'name',
      );

      return fileList.files
              ?.map((f) => DriveFolder(
                    id: f.id ?? '',
                    name: f.name ?? 'Untitled',
                  ))
              .toList() ??
          [];
    } catch (e) {
      if (kDebugMode) print('Error listing folders: $e');
      return [];
    }
  }

  // ── Streaming ─────────────────────────────────────────

  /// Get a streaming URL for a file
  /// Uses webContentLink for direct download/streaming
  Future<String?> getStreamUrl(String fileId) async {
    if (_driveApi == null) return null;

    try {
      // Get file with webContentLink
      final file = await _driveApi!.files.get(
        fileId,
        $fields: 'webContentLink',
      ) as drive.File;

      return file.webContentLink;
    } catch (e) {
      if (kDebugMode) print('Error getting stream URL: $e');
      return null;
    }
  }

  /// Get authenticated headers for streaming
  /// Use these headers with just_audio for authenticated playback
  Future<Map<String, String>?> getAuthHeaders() async {
    try {
      final auth = await _currentUser?.authentication;
      if (auth?.accessToken != null) {
        _cachedAuthHeaders = {
          'Authorization': 'Bearer ${auth!.accessToken}',
        };
        return _cachedAuthHeaders;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error getting auth headers: $e');
      return null;
    }
  }

  // ── Storage Info ──────────────────────────────────────

  /// Get Drive storage usage
  Future<DriveStorageInfo> getStorageInfo() async {
    if (_driveApi == null) {
      return DriveStorageInfo(used: 0, total: 0);
    }

    try {
      final about = await _driveApi!.about.get(
        $fields: 'storageQuota',
      );

      final quota = about.storageQuota;
      return DriveStorageInfo(
        used: int.tryParse(quota?.usage ?? '0') ?? 0,
        total: int.tryParse(quota?.limit ?? '0') ?? 0,
      );
    } catch (e) {
      if (kDebugMode) print('Error getting storage info: $e');
      return DriveStorageInfo(used: 0, total: 0);
    }
  }

  // ── Drive Save / Remove (Like Sync) ─────────────────────

  /// Star or save a song to the user's Google Drive
  Future<bool> saveSongToDrive(DriveAudioFile song) async {
    if (_driveApi == null) return false;
    try {
      // 1. If it's already an existing Drive file, star it
      final targetId = (song.driveFileId != null && song.driveFileId!.isNotEmpty) ? song.driveFileId! : song.id;
      if (targetId.isNotEmpty && !targetId.startsWith('local_')) {
        try {
          final patch = drive.File()..starred = true;
          await _driveApi!.files.update(patch, targetId);
          return true;
        } catch (_) {}
      }

      // 2. If it's a local file, upload it into the Liked_music subfolder of "AxoR DataBase"
      final rootFolderId = await getOrCreateAxorFolder();
      if (rootFolderId == null) return false;

      final subfolders = await _resolveDatabaseFolders(rootFolderId);
      final musicFolderId = subfolders.primaryMusicFolderId;
      final logoFolderId = subfolders.primaryLogoFolderId;
      final lyricsFolderId = subfolders.primaryLyricsFolderId;

      if (song.customStreamUrl != null) {
        final localFile = File(song.customStreamUrl!);
        if (localFile.existsSync()) {
          final metadata = drive.File()
            ..name = song.name
            ..parents = [musicFolderId]
            ..starred = true;
          final media = drive.Media(localFile.openRead(), localFile.lengthSync());
          await _driveApi!.files.create(metadata, uploadMedia: media);

          // Upload companion cover logo if available locally
          final localLogoPath = song.coverArtUrl ?? song.thumbnailLink;
          if (logoFolderId != null && localLogoPath != null) {
            final logoFile = File(localLogoPath);
            if (logoFile.existsSync()) {
              final dotIdx = logoFile.path.lastIndexOf('.');
              final ext = dotIdx != -1 ? logoFile.path.substring(dotIdx) : '.jpg';
              final logoMeta = drive.File()
                ..name = '${song.id}$ext'
                ..parents = [logoFolderId];
              await _driveApi!.files.create(
                logoMeta,
                uploadMedia: drive.Media(logoFile.openRead(), logoFile.lengthSync()),
              );
            }
          }

          // Upload companion lyrics if available locally
          if (lyricsFolderId != null && song.lyricsUrl != null) {
            final lyricsFile = File(song.lyricsUrl!);
            if (lyricsFile.existsSync()) {
              final lyricsMeta = drive.File()
                ..name = '${song.id}.lrc'
                ..parents = [lyricsFolderId];
              await _driveApi!.files.create(
                lyricsMeta,
                uploadMedia: drive.Media(lyricsFile.openRead(), lyricsFile.lengthSync()),
              );
            }
          }

          // Automatically regenerate & synchronize index.json in the background
          listAudioFiles();
          return true;
        }
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('Error saving song to Drive: $e');
      return false;
    }
  }

  /// Unstar or remove a song from Google Drive
  Future<bool> removeSongFromDrive(String songId, {String? driveFileId}) async {
    if (_driveApi == null) return false;
    try {
      final targetId = (driveFileId != null && driveFileId.isNotEmpty) ? driveFileId : songId;
      if (targetId.isNotEmpty && !targetId.startsWith('local_')) {
        final patch = drive.File()..starred = false;
        await _driveApi!.files.update(patch, targetId);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('Error removing song from Drive: $e');
      return false;
    }
  }
}

// ── Data Classes ──────────────────────────────────────────

/// Represents an audio file in Google Drive
class DriveAudioFile {
  final String id; // Base name (e.g. Arijit Singh;Sachet-Parampara - Pal Pal Dil Ke Paas)
  final String? driveFileId; // The internal Google Drive file ID
  final String name;
  final String mimeType;
  final int fileSize;
  final DateTime? modifiedTime;
  final String? thumbnailLink;
  final String? webContentLink;

  // Parsed metadata (filled after ID3 tag reading or index mapping)
  String? title;
  String? artist;
  String? album;
  int? durationSeconds;
  String? coverArtUrl;
  String? lyricsUrl; // Mapped lyrics URL or Drive link
  String? mood;
  String? genre;
  double? energy;
  int? bpm;
  final String? customStreamUrl;

  bool get hasEmbeddedCover =>
      (coverArtUrl != null && coverArtUrl!.isNotEmpty) ||
      (thumbnailLink != null && thumbnailLink!.isNotEmpty);

  String get coverUrl {
    if (coverArtUrl != null && coverArtUrl!.isNotEmpty) {
      if (coverArtUrl!.contains('googleusercontent.com') && coverArtUrl!.contains('=s')) {
        return coverArtUrl!.replaceAll(RegExp(r'=s\d+'), '=s500');
      }
      return coverArtUrl!;
    }
    if (thumbnailLink != null && thumbnailLink!.isNotEmpty) {
      if (thumbnailLink!.contains('googleusercontent.com') && thumbnailLink!.contains('=s')) {
        return thumbnailLink!.replaceAll(RegExp(r'=s\d+'), '=s500');
      }
      return thumbnailLink!;
    }
    final fileId = (driveFileId != null && driveFileId!.isNotEmpty) ? driveFileId! : id;
    if (fileId.isNotEmpty && !fileId.startsWith('local_') && !fileId.contains(' ') && !fileId.contains('.')) {
      return 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';
    }
    return '';
  }

  DriveAudioFile({
    required this.id,
    this.driveFileId,
    required this.name,
    required this.mimeType,
    required this.fileSize,
    this.modifiedTime,
    this.thumbnailLink,
    this.webContentLink,
    this.title,
    this.artist,
    this.album,
    this.durationSeconds,
    this.coverArtUrl,
    this.lyricsUrl,
    this.mood,
    this.genre,
    this.energy,
    this.bpm,
    this.customStreamUrl,
  });

  factory DriveAudioFile.fromSong(Song song) {
    return DriveAudioFile(
      id: song.id,
      driveFileId: song.providerTrackId,
      name: song.fileName ?? '${song.id}.${song.format.toLowerCase()}',
      mimeType: song.format == 'FLAC' ? 'audio/flac' : 'audio/mpeg',
      fileSize: song.fileSize,
      title: song.title,
      artist: song.artist,
      album: song.album,
      durationSeconds: song.duration,
      coverArtUrl: song.artworkReference ?? (song.coverPath != null && song.coverPath != 'embedded' ? song.coverPath : song.coverUrl),
      lyricsUrl: song.lyricsUrl,
      mood: song.mood,
      genre: song.genre,
      energy: song.energy,
      bpm: song.bpm,
      thumbnailLink: song.artworkReference ?? song.coverUrl,
      customStreamUrl: song.localFilePath ?? song.streamUrl,
    );
  }

  factory DriveAudioFile.fromDriveFile(
    drive.File file, {
    String? coverArtUrl,
    String? lyricsUrl,
  }) {
    final name = file.name ?? 'Unknown';
    // Exact downloaded base name without extension
    final baseName = name.replaceAll(RegExp(r'\.[^.]+$'), '').trim();

    // User Rule:
    // Split on the LAST '-' appeared in the title.
    // Before last '-' is artist name
    // After last '-' is song name (which should be displayed prominently / before in app)
    final lastDash = baseName.lastIndexOf('-');
    String parsedArtist;
    String cleanTitle;
    if (lastDash > 0 && lastDash < baseName.length - 1) {
      parsedArtist = baseName.substring(0, lastDash).trim();
      cleanTitle = baseName.substring(lastDash + 1).trim();
    } else {
      parsedArtist = 'Unknown Artist';
      cleanTitle = baseName;
    }

    return DriveAudioFile(
      id: baseName, // EXACT downloaded name as ID for CSV/AxoR compatibility
      driveFileId: file.id ?? '',
      name: name,
      mimeType: file.mimeType ?? 'audio/mpeg',
      fileSize: int.tryParse(file.size ?? '0') ?? 0,
      modifiedTime: file.modifiedTime,
      thumbnailLink: coverArtUrl ?? file.thumbnailLink,
      webContentLink: file.webContentLink,
      title: cleanTitle,
      artist: parsedArtist,
      coverArtUrl: coverArtUrl,
      lyricsUrl: lyricsUrl,
    );
  }

  /// Display title (prefer metadata, fallback to filename)
  String get displayTitle => title ?? name;

  /// Display artist
  String get displayArtist => artist ?? 'Unknown Artist';

  /// Format file size
  String get formattedSize {
    final mb = fileSize / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Format duration
  String get formattedDuration {
    if (durationSeconds == null) return '--:--';
    final m = durationSeconds! ~/ 60;
    final s = durationSeconds! % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Get the streaming URL (custom backend stream or Google Drive alt=media)
  String get streamUrl {
    if (customStreamUrl != null && customStreamUrl!.isNotEmpty) {
      return customStreamUrl!;
    }
    final fileId = (driveFileId != null && driveFileId!.isNotEmpty) ? driveFileId! : id;
    return 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';
  }

  /// Convert this DriveAudioFile into a persistent local-first Song model
  Song toSong() {
    final fmt = (mimeType.contains('/') ? mimeType.split('/').last : 'MP3').toUpperCase();
    return Song(
      id: id,
      title: displayTitle,
      artist: displayArtist,
      album: album ?? '',
      duration: durationSeconds ?? 0,
      bpm: bpm ?? 0,
      energy: energy ?? 0.5,
      mood: mood ?? '',
      genre: genre ?? '',
      filePath: streamUrl,
      coverPath: coverUrl.isNotEmpty ? coverUrl : (thumbnailLink ?? ''),
      fileSize: fileSize,
      format: fmt,
      sampleRate: 44100,
      bitrate: 320,
      fileName: name,
      providerTrackId: (driveFileId != null && driveFileId!.isNotEmpty) ? driveFileId : id,
      availabilityStatus: SongAvailability.cloud,
      downloadStatus: SongDownloadStatus.none,
      artworkReference: coverUrl.isNotEmpty ? coverUrl : thumbnailLink,
      lyricsUrl: lyricsUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'driveFileId': driveFileId,
        'name': name,
        'mimeType': mimeType,
        'fileSize': fileSize,
        'modifiedTime': modifiedTime?.toIso8601String(),
        'title': title,
        'artist': artist,
        'album': album,
        'durationSeconds': durationSeconds,
        'coverArtUrl': coverArtUrl,
        'lyricsUrl': lyricsUrl,
        'mood': mood,
        'genre': genre,
        'energy': energy,
        'bpm': bpm,
        'thumbnailLink': thumbnailLink,
        'customStreamUrl': customStreamUrl,
      };

  factory DriveAudioFile.fromJson(Map<String, dynamic> json) {
    return DriveAudioFile(
      id: json['id'] ?? '',
      driveFileId: json['driveFileId'] ?? json['providerTrackId'],
      name: json['name'] ?? 'Unknown',
      mimeType: json['mimeType'] ?? 'audio/mpeg',
      fileSize: json['fileSize'] ?? 0,
      modifiedTime: json['modifiedTime'] != null
          ? DateTime.tryParse(json['modifiedTime'])
          : null,
      title: json['title'],
      artist: json['artist'],
      album: json['album'],
      durationSeconds: json['durationSeconds'],
      coverArtUrl: json['coverArtUrl'],
      lyricsUrl: json['lyricsUrl'],
      mood: json['mood'],
      genre: json['genre'],
      energy: json['energy']?.toDouble(),
      bpm: json['bpm'],
      thumbnailLink: json['thumbnailLink'],
      customStreamUrl: json['customStreamUrl'],
    );
  }

  DriveAudioFile copyWith({
    String? id,
    String? driveFileId,
    String? name,
    String? mimeType,
    int? fileSize,
    DateTime? modifiedTime,
    String? thumbnailLink,
    String? webContentLink,
    String? title,
    String? artist,
    String? album,
    int? durationSeconds,
    String? coverArtUrl,
    String? lyricsUrl,
    String? mood,
    String? genre,
    double? energy,
    int? bpm,
    String? customStreamUrl,
  }) {
    return DriveAudioFile(
      id: id ?? this.id,
      driveFileId: driveFileId ?? this.driveFileId,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      modifiedTime: modifiedTime ?? this.modifiedTime,
      thumbnailLink: thumbnailLink ?? this.thumbnailLink,
      webContentLink: webContentLink ?? this.webContentLink,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      coverArtUrl: coverArtUrl ?? this.coverArtUrl,
      lyricsUrl: lyricsUrl ?? this.lyricsUrl,
      mood: mood ?? this.mood,
      genre: genre ?? this.genre,
      energy: energy ?? this.energy,
      bpm: bpm ?? this.bpm,
      customStreamUrl: customStreamUrl ?? this.customStreamUrl,
    );
  }
}

/// Represents a folder in Google Drive
class DriveFolder {
  final String id;
  final String name;

  DriveFolder({required this.id, required this.name});
}

/// Drive storage quota info
class DriveStorageInfo {
  final int used;
  final int total;

  DriveStorageInfo({required this.used, required this.total});

  double get usagePercent => total > 0 ? (used / total) * 100 : 0;

  String get usedFormatted {
    final gb = used / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }

  String get totalFormatted {
    final gb = total / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(0)} GB';
  }
}
