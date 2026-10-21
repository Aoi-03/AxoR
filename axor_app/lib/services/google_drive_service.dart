import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

/// Google Drive Service
/// Handles OAuth, file listing, and audio streaming from user's Drive
class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

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

  /// Finds or automatically creates the dedicated "AxoR DataBase" (or "AxoR Music") folder in the user's Drive.
  Future<String?> getOrCreateAxorFolder() async {
    if (_driveApi == null) return null;
    if (_axorFolderId != null) return _axorFolderId;

    try {
      final query = "mimeType='application/vnd.google-apps.folder' and (name='AxoR DataBase' or name='AxoR Music') and trashed=false";
      final fileList = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        _axorFolderId = fileList.files!.first.id;
        return _axorFolderId;
      }

      // Auto-create "AxoR DataBase" folder on first run
      final folderMetadata = drive.File()
        ..name = 'AxoR DataBase'
        ..mimeType = 'application/vnd.google-apps.folder'
        ..description = 'Dedicated music database for AxoR Player';

      final createdFolder = await _driveApi!.files.create(folderMetadata);
      _axorFolderId = createdFolder.id;
      return _axorFolderId;
    } catch (e) {
      if (kDebugMode) print('Error finding or creating AxoR folder: $e');
      return null;
    }
  }

  /// Discovers database subfolders: Liked_music, Liked_music_logo, Liked_music_lyrics
  Future<Map<String, String>> _resolveDatabaseFolders(String rootFolderId) async {
    final Map<String, String> subfolders = {};
    if (_driveApi == null) return subfolders;

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
          final n = (f.name ?? '').toLowerCase().trim();
          if (n == 'liked_music' || n == 'liked_songs' || n == 'music') {
            subfolders['music'] = f.id!;
          } else if (n == 'liked_music_logo' || n == 'covers' || n == 'logos') {
            subfolders['logo'] = f.id!;
          } else if (n == 'liked_music_lyrics' || n == 'lyrics') {
            subfolders['lyrics'] = f.id!;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Folder discovery error: $e');
    }

    return subfolders;
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

  /// Audio MIME types we support
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

  /// List audio files from Drive with automatic AxoR DataBase structure mapping:
  /// AxoR DataBase -> index.json, Liked_music, Liked_music_lyrics, Liked_music_logo
  Future<List<DriveAudioFile>> listAudioFiles({
    String? folderId,
    String? pageToken,
    int pageSize = 150,
  }) async {
    if (_driveApi == null) return [];

    try {
      // Refresh headers cache
      getAuthHeaders();

      final rootFolderId = folderId ?? await getOrCreateAxorFolder();
      if (rootFolderId == null) return [];

      // 1. Resolve subfolders (Liked_music, Liked_music_logo, Liked_music_lyrics)
      final subfolders = await _resolveDatabaseFolders(rootFolderId);
      final musicFolderId = subfolders['music'] ?? rootFolderId;
      final logoFolderId = subfolders['logo'];
      final lyricsFolderId = subfolders['lyrics'];

      // 2. Discover companion artwork/cover images in Liked_music_logo (and root)
      final Map<String, String> logoMap = {};
      try {
        final List<String> logoParents = [rootFolderId];
        if (logoFolderId != null && logoFolderId != rootFolderId) {
          logoParents.add(logoFolderId);
        }
        for (final parent in logoParents) {
          final imgQuery = "(mimeType='image/jpeg' or mimeType='image/png' or mimeType='image/webp') and trashed=false and '$parent' in parents";
          final imgList = await _driveApi!.files.list(
            q: imgQuery,
            spaces: 'drive',
            $fields: 'files(id, name, thumbnailLink, webContentLink)',
            pageSize: 150,
          );
          if (imgList.files != null) {
            for (final img in imgList.files!) {
              final raw = (img.name ?? '').toLowerCase().trim();
              final base = raw.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
              final imgUrl = 'https://drive.google.com/thumbnail?id=${img.id}&sz=w400';
              logoMap[base] = imgUrl;
              logoMap[raw] = imgUrl;
              final dash = base.lastIndexOf('-');
              if (dash > 0 && dash < base.length - 1) {
                logoMap[base.substring(dash + 1).trim()] = imgUrl;
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('Artwork discovery non-fatal: $e');
      }

      final generalCover = logoMap['cover'] ??
          logoMap['folder'] ??
          logoMap['albumart'] ??
          logoMap['art'] ??
          logoMap['logo'];

      // 3. Discover companion lyrics in Liked_music_lyrics (and root)
      final Map<String, String> lyricsMap = {};
      try {
        final List<String> lyricsParents = [rootFolderId];
        if (lyricsFolderId != null && lyricsFolderId != rootFolderId) {
          lyricsParents.add(lyricsFolderId);
        }
        for (final parent in lyricsParents) {
          final lrcQuery = "(mimeType='text/plain' or name contains '.lrc' or name contains '.txt') and trashed=false and '$parent' in parents";
          final lrcList = await _driveApi!.files.list(
            q: lrcQuery,
            spaces: 'drive',
            $fields: 'files(id, name, webContentLink)',
            pageSize: 150,
          );
          if (lrcList.files != null) {
            for (final lrc in lrcList.files!) {
              final raw = (lrc.name ?? '').toLowerCase().trim();
              final base = raw.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
              final lrcUrl = 'https://www.googleapis.com/drive/v3/files/${lrc.id}?alt=media';
              lyricsMap[base] = lrcUrl;
              lyricsMap[raw] = lrcUrl;
              final dash = base.lastIndexOf('-');
              if (dash > 0 && dash < base.length - 1) {
                lyricsMap[base.substring(dash + 1).trim()] = lrcUrl;
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('Lyrics discovery non-fatal: $e');
      }

      // 4. Fetch audio files from music folder (or root)
      final mimeQuery = _audioMimeTypes.map((m) => "mimeType='$m'").join(' or ');
      String query = '($mimeQuery) and trashed=false and \'$musicFolderId\' in parents';

      final fileList = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields:
            'nextPageToken, files(id, name, mimeType, size, modifiedTime, parents, thumbnailLink, webContentLink)',
        pageSize: pageSize,
        pageToken: pageToken,
        orderBy: 'name',
      );

      final List<DriveAudioFile> result = [];
      if (fileList.files != null) {
        for (final f in fileList.files!) {
          final name = f.name ?? 'Unknown';
          final baseName = name.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
          final lowerBase = baseName.toLowerCase();

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

          // Auto-map logo
          final matchedCover = logoMap[lowerBase] ??
              logoMap['$lowerBase.jpg'] ??
              logoMap['$lowerBase.png'] ??
              logoMap[lowerTitle] ??
              generalCover;

          // Auto-map lyrics
          final matchedLyrics = lyricsMap[lowerBase] ??
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
            thumbnailLink: matchedCover ?? f.thumbnailLink,
            webContentLink: f.webContentLink,
            title: cleanTitle,
            artist: parsedArtist,
            coverArtUrl: matchedCover,
            lyricsUrl: matchedLyrics,
          );

          result.add(audioFile);
        }
      }

      // 5. Asynchronously keep index.json synchronized in the AxoR DataBase folder
      _syncIndexJson(rootFolderId, result);

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

      // 2. If it's a local file, upload it to the "AxoR DataBase" folder
      final folderId = await getOrCreateAxorFolder();
      if (song.customStreamUrl != null) {
        final localFile = File(song.customStreamUrl!);
        if (localFile.existsSync()) {
          final metadata = drive.File()
            ..name = song.name
            ..parents = folderId != null ? [folderId] : null
            ..starred = true;
          final media = drive.Media(localFile.openRead(), localFile.lengthSync());
          await _driveApi!.files.create(metadata, uploadMedia: media);
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
    if (coverArtUrl != null && coverArtUrl!.isNotEmpty) return coverArtUrl!;
    if (thumbnailLink != null && thumbnailLink!.isNotEmpty) return thumbnailLink!;
    final fileId = (driveFileId != null && driveFileId!.isNotEmpty) ? driveFileId! : id;
    if (fileId.isNotEmpty && !fileId.startsWith('local_')) {
      return 'https://drive.google.com/thumbnail?id=$fileId&sz=w220';
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
