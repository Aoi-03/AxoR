import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'google_drive_service.dart';

/// DownloadService — Robust local song download & offline cache manager
///
/// Features:
/// - Streams audio chunks directly to disk to prevent RAM spikes (no memory buffer)
/// - Caches song album art thumbnail alongside the audio file
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

  // Active downloads state
  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloadingIds = {};

  // Persisted downloaded songs list
  final List<DriveAudioFile> _downloadedSongs = [];

  List<DriveAudioFile> get downloadedSongs => List.unmodifiable(_downloadedSongs);
  bool isDownloading(String id) => _downloadingIds.contains(id);
  double getProgress(String id) => _downloadProgress[id] ?? 0.0;
  bool isDownloaded(String id) => _downloadedSongs.any((s) => s.id == id);

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

  /// Download a Drive or AxoR song to local storage
  Future<bool> downloadSong(DriveAudioFile song) async {
    if (isDownloading(song.id) || isDownloaded(song.id)) return true;

    _downloadingIds.add(song.id);
    _downloadProgress[song.id] = 0.0;
    notifyListeners();

    IOSink? audioSink;
    File? tempAudioFile;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${docsDir.path}/axor_downloads');
      if (!downloadDir.existsSync()) {
        downloadDir.createSync(recursive: true);
      }

      // 1. Download Album Art thumbnail if available
      String? localCoverPath;
      if (song.coverUrl.isNotEmpty) {
        try {
          final coverFile = File('${downloadDir.path}/${song.id}_cover.jpg');
          if (!coverFile.existsSync()) {
            final coverRes = await http.get(Uri.parse(song.coverUrl)).timeout(const Duration(seconds: 10));
            if (coverRes.statusCode == 200) {
              await coverFile.writeAsBytes(coverRes.bodyBytes);
              localCoverPath = coverFile.path;
            }
          } else {
            localCoverPath = coverFile.path;
          }
        } catch (_) {}
      }

      // 2. Stream Audio chunks directly to file (prevents loading 20MB into RAM)
      final safeTitle = song.displayTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final targetAudioFile = File('${downloadDir.path}/${song.id}_$safeTitle.mp3');
      tempAudioFile = File('${downloadDir.path}/${song.id}_$safeTitle.part');

      final headers = song.streamUrl.contains('googleapis.com')
          ? await _driveService.getAuthHeaders()
          : null;

      final request = http.Request('GET', Uri.parse(song.streamUrl));
      if (headers != null) request.headers.addAll(headers);

      final client = http.Client();
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception('Download failed with status ${streamedResponse.statusCode}');
      }

      final totalBytes = streamedResponse.contentLength ?? song.fileSize;
      int receivedBytes = 0;

      audioSink = tempAudioFile.openWrite();

      await for (final chunk in streamedResponse.stream) {
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

      // Rename temp to target
      if (tempAudioFile.existsSync()) {
        if (targetAudioFile.existsSync()) targetAudioFile.deleteSync();
        tempAudioFile.renameSync(targetAudioFile.path);
      }

      // 3. Register downloaded song model with local file paths
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

      if (kDebugMode) {
        print('✅ Downloaded track saved: ${targetAudioFile.path} (${downloadedTrack.formattedSize})');
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
      _downloadingIds.remove(song.id);
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
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Error deleting downloaded song: $e');
    }
  }
}
