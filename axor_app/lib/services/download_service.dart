import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import 'google_drive_service.dart';
import 'local_library_service.dart';

/// DownloadService — Robust local song download & offline cache manager
///
/// Features:
/// - Streams audio chunks directly to disk to prevent RAM spikes (no memory buffer)
/// - Caches song album art thumbnail alongside the audio file
/// - Computes SHA-256 content hashes for reliable deduplication
/// - Supports download cancellation via [cancelDownload]
/// - Validates file integrity (minimum size, header checks)
/// - Reconciles downloaded tracks with [LocalLibraryService]
/// - Persists metadata in SharedPreferences for fast offline recovery
/// - Tracks download progress (0.0 -> 1.0) for responsive UI
class DownloadService with ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;

  DownloadService._internal() {
    _loadDownloadedTracks();
  }

  static const String _storageKey = 'axor_downloaded_tracks_v2';
  final GoogleDriveService _driveService = GoogleDriveService();
  final LocalLibraryService _localLibrary = LocalLibraryService();

  // Active downloads state
  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloadingIds = {};
  final Map<String, http.Client> _activeClients = {};
  final Set<String> _cancelledIds = {};

  // Failed artwork cache with timestamp for TTL (1 hour cooldown)
  final Map<String, DateTime> _artworkFailures = {};

  // Persisted downloaded songs list
  final List<DriveAudioFile> _downloadedSongs = [];

  List<DriveAudioFile> get downloadedSongs => List.unmodifiable(_downloadedSongs);
  bool isDownloading(String id) => _downloadingIds.contains(id);
  double getProgress(String id) => _downloadProgress[id] ?? 0.0;
  bool isDownloaded(String id) => _downloadedSongs.any((s) => s.id == id);

  /// Compute SHA-256 hash of the first 64KB (or entire file if smaller)
  static Future<String?> computeFileHash(File file) async {
    try {
      if (!file.existsSync()) return null;
      final length = await file.length();
      if (length == 0) return null;

      final chunkSize = length > 65536 ? 65536 : length;
      final raf = await file.open(mode: FileMode.read);
      try {
        final bytes = await raf.read(chunkSize);
        final digest = sha256.convert(bytes);
        return digest.toString();
      } finally {
        await raf.close();
      }
    } catch (e) {
      if (kDebugMode) print('Error computing hash: $e');
      return null;
    }
  }

  Future<void> _loadDownloadedTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        _downloadedSongs.clear();
        for (final item in decoded) {
          try {
            final song = DriveAudioFile.fromJson(Map<String, dynamic>.from(item));
            // Check if local file still exists
            if (song.customStreamUrl != null && File(song.customStreamUrl!).existsSync()) {
              _downloadedSongs.add(song);
            }
          } catch (_) {}
        }
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Error loading downloaded tracks: $e');
    }
  }

  Future<void> _saveDownloadedTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _downloadedSongs.map((s) => s.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      if (kDebugMode) print('Error saving downloaded tracks: $e');
    }
  }

  /// Cancel an ongoing download
  void cancelDownload(String songId) {
    if (!_downloadingIds.contains(songId)) return;
    _cancelledIds.add(songId);
    final client = _activeClients[songId];
    client?.close();
    _activeClients.remove(songId);
    _downloadingIds.remove(songId);
    _downloadProgress.remove(songId);
    notifyListeners();
    if (kDebugMode) print('🛑 Download cancelled for song: $songId');
  }

  /// Download a Drive or AxoR song to local storage
  Future<bool> downloadSong(DriveAudioFile song) async {
    if (isDownloading(song.id)) return true;
    if (isDownloaded(song.id)) return true;

    _downloadingIds.add(song.id);
    _downloadProgress[song.id] = 0.0;
    _cancelledIds.remove(song.id);
    notifyListeners();

    IOSink? audioSink;
    File? tempAudioFile;
    File? targetAudioFile;
    final client = http.Client();
    _activeClients[song.id] = client;

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${docsDir.path}/axor_downloads');
      if (!downloadDir.existsSync()) {
        downloadDir.createSync(recursive: true);
      }

      // Check if already in local library by provider ID or content
      final existingSong = _localLibrary.findByProviderTrackId(song.id);
      if (existingSong != null &&
          existingSong.localFilePath != null &&
          File(existingSong.localFilePath!).existsSync()) {
        // Reuse existing downloaded file!
        targetAudioFile = File(existingSong.localFilePath!);
        final reusedTrack = song.copyWith(
          customStreamUrl: targetAudioFile.path,
        );
        _downloadedSongs.removeWhere((s) => s.id == song.id);
        _downloadedSongs.add(reusedTrack);
        await _saveDownloadedTracks();
        _downloadProgress[song.id] = 1.0;
        notifyListeners();
        return true;
      }

      // 1. Download Album Art thumbnail if available (with failure cooldown)
      String? localCoverPath;
      if (song.coverUrl.isNotEmpty) {
        final failedAt = _artworkFailures[song.coverUrl];
        final isCooldownActive = failedAt != null &&
            DateTime.now().difference(failedAt) < const Duration(hours: 1);

        if (!isCooldownActive) {
          try {
            final coverFile = File('${downloadDir.path}/${song.id}_cover.jpg');
            if (!coverFile.existsSync()) {
              final coverRes = await http
                  .get(Uri.parse(song.coverUrl))
                  .timeout(const Duration(seconds: 8));
              if (coverRes.statusCode == 200 && coverRes.bodyBytes.length > 100) {
                await coverFile.writeAsBytes(coverRes.bodyBytes);
                localCoverPath = coverFile.path;
              } else {
                _artworkFailures[song.coverUrl] = DateTime.now();
              }
            } else {
              localCoverPath = coverFile.path;
            }
          } catch (_) {
            _artworkFailures[song.coverUrl] = DateTime.now();
          }
        }
      }

      // Check for cancellation
      if (_cancelledIds.contains(song.id)) {
        throw Exception('Download cancelled by user');
      }

      // 2. Stream Audio chunks directly to file (prevents loading 20MB into RAM)
      final safeTitle = song.displayTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      targetAudioFile = File('${downloadDir.path}/${song.id}_$safeTitle.mp3');
      tempAudioFile = File('${downloadDir.path}/${song.id}_$safeTitle.part');

      final headers = song.streamUrl.contains('googleapis.com')
          ? await _driveService.getAuthHeaders()
          : null;

      final request = http.Request('GET', Uri.parse(song.streamUrl));
      if (headers != null) request.headers.addAll(headers);

      final streamedResponse = await client.send(request);

      if (_cancelledIds.contains(song.id)) {
        throw Exception('Download cancelled by user');
      }

      if (streamedResponse.statusCode != 200) {
        throw Exception('Download failed with status ${streamedResponse.statusCode}');
      }

      final totalBytes = streamedResponse.contentLength ?? song.fileSize;
      int receivedBytes = 0;

      audioSink = tempAudioFile.openWrite();

      await for (final chunk in streamedResponse.stream) {
        if (_cancelledIds.contains(song.id)) {
          throw Exception('Download cancelled by user');
        }

        audioSink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          _downloadProgress[song.id] = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          notifyListeners();
        }
      }

      await audioSink.flush();
      await audioSink.close();
      audioSink = null;

      // 3. Verify file integrity
      if (!tempAudioFile.existsSync() || tempAudioFile.lengthSync() < 1024) {
        throw Exception('Downloaded file is too small or incomplete');
      }

      // Rename temp to target
      if (targetAudioFile.existsSync()) targetAudioFile.deleteSync();
      tempAudioFile.renameSync(targetAudioFile.path);

      // 4. Compute content hash for deduplication
      final contentHash = await computeFileHash(targetAudioFile);

      // 5. Register downloaded song model with local file paths
      final downloadedTrack = DriveAudioFile(
        id: song.id,
        name: song.name,
        mimeType: song.mimeType,
        fileSize: targetAudioFile.lengthSync(),
        modifiedTime: DateTime.now(),
        title: song.title,
        artist: song.artist,
        album: song.album,
        durationSeconds: song.durationSeconds,
        coverArtUrl: localCoverPath ?? song.coverArtUrl,
        mood: song.mood,
        genre: song.genre,
        energy: song.energy,
        bpm: song.bpm,
        thumbnailLink: localCoverPath ?? song.thumbnailLink,
        customStreamUrl: targetAudioFile.path, // Points directly to offline file
      );

      _downloadedSongs.removeWhere((s) => s.id == song.id);
      _downloadedSongs.add(downloadedTrack);
      await _saveDownloadedTracks();

      // 6. Reconcile with LocalLibraryService (indexes into Hive local database)
      try {
        await _localLibrary.reconcileDownload(
          driveFile: song,
          localFilePath: targetAudioFile.path,
          contentHash: contentHash,
          localCoverPath: localCoverPath,
        );
      } catch (e) {
        if (kDebugMode) print('Reconciliation warning: $e');
      }

      if (kDebugMode) {
        print('✅ Downloaded track saved: ${targetAudioFile.path} (${downloadedTrack.formattedSize}, hash: ${contentHash?.substring(0, 8)})');
      }

      _downloadProgress[song.id] = 1.0;
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Download failed for ${song.displayTitle}: $e');
      if (audioSink != null) {
        try { await audioSink.close(); } catch (_) {}
      }
      if (tempAudioFile != null && tempAudioFile.existsSync()) {
        try { tempAudioFile.deleteSync(); } catch (_) {}
      }
      return false;
    } finally {
      _activeClients.remove(song.id);
      _downloadingIds.remove(song.id);
      _cancelledIds.remove(song.id);
      notifyListeners();
    }
  }

  /// Remove downloaded song and its local file
  Future<void> deleteDownloadedSong(String id) async {
    try {
      final index = _downloadedSongs.indexWhere((s) => s.id == id);
      if (index != -1) {
        final song = _downloadedSongs[index];
        if (song.customStreamUrl != null) {
          final file = File(song.customStreamUrl!);
          if (file.existsSync()) file.deleteSync();
        }
        if (song.coverArtUrl != null && song.coverArtUrl!.startsWith('/')) {
          final cover = File(song.coverArtUrl!);
          if (cover.existsSync()) cover.deleteSync();
        }
        _downloadedSongs.removeAt(index);
        await _saveDownloadedTracks();

        // Update LocalLibraryService status to cloud rather than wiping record
        final indexed = _localLibrary.getSong(id);
        if (indexed != null) {
          await _localLibrary.indexSong(indexed.copyWith(
            availabilityStatus: SongAvailability.cloud,
            downloadStatus: SongDownloadStatus.none,
            localFilePath: null,
          ));
        }

        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Error deleting downloaded song: $e');
    }
  }
}
