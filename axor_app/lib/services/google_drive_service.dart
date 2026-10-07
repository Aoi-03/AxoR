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

  // ── Getters ──────────────────────────────────────────
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  String? get userEmail => _currentUser?.email;
  String? get userName => _currentUser?.displayName;
  String? get userPhotoUrl => _currentUser?.photoUrl;
  String? get axorFolderId => _axorFolderId;

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

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
    _httpClient?.close();
    _httpClient = null;
  }

  /// Initialize Drive API client and resolve dedicated AxoR folder
  Future<void> _initDriveApi() async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient != null) {
      _httpClient = httpClient;
      _driveApi = drive.DriveApi(httpClient);
      await getOrCreateAxorFolder();
    }
  }

  /// Finds or automatically creates the dedicated "AxoR Music" folder in the user's Drive.
  /// With driveFileScope, the app only accesses files inside this folder, keeping all other
  /// user Drive files completely isolated and private.
  Future<String?> getOrCreateAxorFolder() async {
    if (_driveApi == null) return null;
    if (_axorFolderId != null) return _axorFolderId;

    try {
      final query = "mimeType='application/vnd.google-apps.folder' and name='AxoR Music' and trashed=false";
      final fileList = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        _axorFolderId = fileList.files!.first.id;
        return _axorFolderId;
      }

      // Auto-create "AxoR Music" folder on first run
      final folderMetadata = drive.File()
        ..name = 'AxoR Music'
        ..mimeType = 'application/vnd.google-apps.folder'
        ..description = 'Dedicated music folder for AxoR Player';

      final createdFolder = await _driveApi!.files.create(folderMetadata);
      _axorFolderId = createdFolder.id;
      return _axorFolderId;
    } catch (e) {
      if (kDebugMode) print('Error finding or creating AxoR folder: $e');
      return null;
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

  /// List audio files from Drive (defaults to the dedicated "AxoR Music" folder)
  Future<List<DriveAudioFile>> listAudioFiles({
    String? folderId,
    String? pageToken,
    int pageSize = 100,
  }) async {
    if (_driveApi == null) return [];

    try {
      // Build MIME type query
      final mimeQuery =
          _audioMimeTypes.map((m) => "mimeType='$m'").join(' or ');

      final targetFolder = folderId ?? _axorFolderId;
      String query = '($mimeQuery) and trashed=false';
      if (targetFolder != null) {
        query += " and '$targetFolder' in parents";
      }

      final fileList = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields:
            'nextPageToken, files(id, name, mimeType, size, modifiedTime, parents, thumbnailLink, webContentLink)',
        pageSize: pageSize,
        pageToken: pageToken,
        orderBy: 'name',
      );

      return fileList.files
              ?.map((f) => DriveAudioFile.fromDriveFile(f))
              .toList() ??
          [];
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
        return {
          'Authorization': 'Bearer ${auth!.accessToken}',
        };
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
}

// ── Data Classes ──────────────────────────────────────────

/// Represents an audio file in Google Drive
class DriveAudioFile {
  final String id;
  final String name;
  final String mimeType;
  final int fileSize;
  final DateTime? modifiedTime;
  final String? thumbnailLink;
  final String? webContentLink;

  // Parsed metadata (filled after ID3 tag reading)
  String? title;
  String? artist;
  String? album;
  int? durationSeconds;
  String? coverArtUrl;
  String? mood;
  String? genre;
  double? energy;
  int? bpm;
  final String? customStreamUrl;

  bool get hasEmbeddedCover => (coverArtUrl != null && coverArtUrl!.isNotEmpty) || (thumbnailLink != null && thumbnailLink!.isNotEmpty);
  String get coverUrl => coverArtUrl ?? thumbnailLink ?? '';

  DriveAudioFile({
    required this.id,
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
    this.mood,
    this.genre,
    this.energy,
    this.bpm,
    this.customStreamUrl,
  });

  factory DriveAudioFile.fromSong(Song song) {
    return DriveAudioFile(
      id: song.id,
      name: song.fileName ?? '${song.title}.${song.format.toLowerCase()}',
      mimeType: song.format == 'FLAC' ? 'audio/flac' : 'audio/mpeg',
      fileSize: song.fileSize,
      title: song.title,
      artist: song.artist,
      album: song.album,
      durationSeconds: song.duration,
      coverArtUrl: song.coverUrl,
      mood: song.mood,
      genre: song.genre,
      energy: song.energy,
      bpm: song.bpm,
      thumbnailLink: song.coverUrl,
      customStreamUrl: song.streamUrl,
    );
  }

  factory DriveAudioFile.fromDriveFile(drive.File file) {
    final name = file.name ?? 'Unknown';
    // Parse title from filename (strip extension)
    final parsedTitle = name.replaceAll(RegExp(r'\.[^.]+$'), '');
    // Try to extract artist from "Artist - Title" format
    String? parsedArtist;
    String? cleanTitle;
    if (parsedTitle.contains(' - ')) {
      final parts = parsedTitle.split(' - ');
      parsedArtist = parts[0].trim();
      cleanTitle = parts.sublist(1).join(' - ').trim();
    }

    return DriveAudioFile(
      id: file.id ?? '',
      name: name,
      mimeType: file.mimeType ?? 'audio/mpeg',
      fileSize: int.tryParse(file.size ?? '0') ?? 0,
      modifiedTime: file.modifiedTime,
      thumbnailLink: file.thumbnailLink,
      webContentLink: file.webContentLink,
      title: cleanTitle ?? parsedTitle,
      artist: parsedArtist ?? 'Unknown Artist',
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
  String get streamUrl =>
      customStreamUrl ?? 'https://www.googleapis.com/drive/v3/files/$id?alt=media';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mimeType': mimeType,
        'fileSize': fileSize,
        'modifiedTime': modifiedTime?.toIso8601String(),
        'title': title,
        'artist': artist,
        'album': album,
        'durationSeconds': durationSeconds,
        'coverArtUrl': coverArtUrl,
        'mood': mood,
        'genre': genre,
        'energy': energy,
        'bpm': bpm,
      };

  factory DriveAudioFile.fromJson(Map<String, dynamic> json) {
    return DriveAudioFile(
      id: json['id'] ?? '',
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
      mood: json['mood'],
      genre: json['genre'],
      energy: json['energy']?.toDouble(),
      bpm: json['bpm'],
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
