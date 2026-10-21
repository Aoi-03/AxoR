import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import '../models/song_category.dart';
import '../services/google_drive_service.dart';

/// LocalLibraryService — Persistent local-first song database
///
/// Uses Hive for fast, on-device indexing of all songs (local, downloaded, cloud).
/// Provides:
/// - Local song index (survives app restarts without backend)
/// - Content hash–based duplicate detection
/// - Category management
/// - Metadata caching
/// - Library reconciliation when songs are downloaded
class LocalLibraryService with ChangeNotifier {
  static final LocalLibraryService _instance = LocalLibraryService._internal();
  factory LocalLibraryService() => _instance;
  LocalLibraryService._internal();

  static const String _songsBoxName = 'axor_songs';
  static const String _categoriesBoxName = 'axor_categories';
  static const String _mappingsBoxName = 'axor_category_mappings';
  static const String _cacheBoxName = 'axor_cache_entries';
  static const String _metaBoxName = 'axor_library_meta';

  Box<String>? _songsBox;
  Box<String>? _categoriesBox;
  Box<String>? _mappingsBox;
  Box<String>? _cacheBox;
  Box<String>? _metaBox;

  bool _isInitialized = false;
  bool _isScanning = false;
  int _totalSongs = 0;
  int _localSongs = 0;
  int _downloadedSongs = 0;

  // ── Getters ──
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  int get totalSongs => _totalSongs;
  int get localSongs => _localSongs;
  int get downloadedSongs => _downloadedSongs;

  /// Initialize Hive and open boxes
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final hiveDir = Directory('${dir.path}/axor_hive');
      if (!hiveDir.existsSync()) {
        hiveDir.createSync(recursive: true);
      }

      await Hive.initFlutter(hiveDir.path);

      _songsBox = await Hive.openBox<String>(_songsBoxName);
      _categoriesBox = await Hive.openBox<String>(_categoriesBoxName);
      _mappingsBox = await Hive.openBox<String>(_mappingsBoxName);
      _cacheBox = await Hive.openBox<String>(_cacheBoxName);
      _metaBox = await Hive.openBox<String>(_metaBoxName);

      // Ensure default categories exist
      await _ensureDefaultCategories();

      _isInitialized = true;
      _updateCounts();
      notifyListeners();

      if (kDebugMode) {
        print('📦 LocalLibraryService initialized (${_songsBox!.length} songs indexed)');
      }
    } catch (e) {
      if (kDebugMode) print('❌ LocalLibraryService init error: $e');
    }
  }

  // ── Song CRUD ──

  /// Get all indexed songs
  List<Song> getAllSongs() {
    if (_songsBox == null) return [];
    return _songsBox!.values
        .map((json) {
          try {
            return Song.fromJson(jsonDecode(json));
          } catch (_) {
            return null;
          }
        })
        .where((s) => s != null)
        .cast<Song>()
        .toList();
  }

  /// Get a song by ID
  Song? getSong(String id) {
    if (_songsBox == null) return null;
    final json = _songsBox!.get(id);
    if (json == null) return null;
    try {
      return Song.fromJson(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }

  /// Index a song (upsert)
  Future<void> indexSong(Song song) async {
    if (_songsBox == null) return;
    await _songsBox!.put(song.id, jsonEncode(song.toJson()));
    _updateCounts();
    notifyListeners();
  }

  /// Index multiple songs in batch
  Future<void> indexSongs(List<Song> songs) async {
    if (_songsBox == null) return;
    final entries = <String, String>{};
    for (final song in songs) {
      entries[song.id] = jsonEncode(song.toJson());
    }
    await _songsBox!.putAll(entries);
    _updateCounts();
    notifyListeners();
  }

  /// Remove a song from the index (does NOT delete the audio file)
  Future<void> removeSong(String songId) async {
    if (_songsBox == null) return;
    await _songsBox!.delete(songId);
    // Also remove category mappings
    await removeSongCategories(songId);
    _updateCounts();
    notifyListeners();
  }

  /// Check if a song exists by ID
  bool hasSong(String id) => _songsBox?.containsKey(id) ?? false;

  // ── Duplicate Detection ──

  /// Find songs matching a content hash
  List<Song> findByContentHash(String contentHash) {
    return getAllSongs()
        .where((s) => s.contentHash == contentHash && contentHash.isNotEmpty)
        .toList();
  }

  /// Find songs matching a provider track ID (e.g., Google Drive file ID)
  Song? findByProviderTrackId(String providerTrackId) {
    if (providerTrackId.isEmpty) return null;
    return getAllSongs().firstWhere(
      (s) => s.providerTrackId == providerTrackId,
      orElse: () => Song(
        id: '', title: '', artist: '', album: '',
        duration: 0, bpm: 0, energy: 0, mood: '', genre: '',
        filePath: '', fileSize: 0, format: '', sampleRate: 0, bitrate: 0,
      ),
    );
  }

  /// Find potential duplicates for a DriveAudioFile
  Song? findDuplicate(DriveAudioFile file) {
    final songs = getAllSongs();

    // 1. Exact ID or Provider Track ID match
    for (final song in songs) {
      if (song.id == file.id) return song;
      if (file.driveFileId != null && file.driveFileId!.isNotEmpty && song.providerTrackId == file.driveFileId) return song;
      if (song.providerTrackId == file.id && file.id.isNotEmpty) return song;
    }

    // 2. Same title + artist (case insensitive) + similar duration
    final title = file.displayTitle.toLowerCase().trim();
    final artist = file.displayArtist.toLowerCase().trim();

    for (final song in songs) {
      final sTitle = song.title.toLowerCase().trim();
      final sArtist = song.artist.toLowerCase().trim();

      if (sTitle == title && sArtist == artist) {
        // Check duration is within 5 seconds to avoid matching different versions
        if (file.durationSeconds != null && song.duration > 0) {
          final diff = (song.duration - file.durationSeconds!).abs();
          if (diff <= 5) return song;
        } else {
          return song; // No duration to compare — assume match by title+artist
        }
      }
    }

    return null;
  }

  // ── Library Reconciliation ──

  /// Reconcile a downloaded file with the existing library.
  /// Returns the (possibly updated) song record.
  Future<Song> reconcileDownload({
    required DriveAudioFile driveFile,
    required String localFilePath,
    String? contentHash,
    String? localCoverPath,
  }) async {
    final existing = findDuplicate(driveFile);

    final trackId = (driveFile.driveFileId != null && driveFile.driveFileId!.isNotEmpty)
        ? driveFile.driveFileId!
        : driveFile.id;

    if (existing != null && existing.id.isNotEmpty) {
      // Update existing record with download info
      final updated = existing.copyWith(
        availabilityStatus: SongAvailability.downloaded,
        downloadStatus: SongDownloadStatus.downloaded,
        localFilePath: localFilePath,
        contentHash: contentHash ?? existing.contentHash,
        artworkReference: localCoverPath ?? existing.artworkReference,
        providerTrackId: trackId.isNotEmpty ? trackId : existing.providerTrackId,
        lyricsUrl: driveFile.lyricsUrl ?? existing.lyricsUrl,
        metadataUpdatedAt: DateTime.now(),
      );
      await indexSong(updated);

      if (kDebugMode) {
        print('🔄 Reconciled: "${updated.title}" — updated existing record');
      }
      return updated;
    }

    // Create new record
    final newSong = Song(
      id: driveFile.id.isNotEmpty ? driveFile.id : 'local_${DateTime.now().millisecondsSinceEpoch}',
      title: driveFile.displayTitle,
      artist: driveFile.displayArtist,
      album: driveFile.album ?? 'Unknown Album',
      duration: driveFile.durationSeconds ?? 0,
      bpm: driveFile.bpm ?? 120,
      energy: driveFile.energy ?? 0.5,
      mood: driveFile.mood ?? 'neutral',
      genre: driveFile.genre ?? 'Unknown',
      filePath: localFilePath,
      fileSize: driveFile.fileSize,
      format: driveFile.mimeType.contains('flac') ? 'FLAC' : 'MP3',
      sampleRate: 44100,
      bitrate: 1411,
      providerTrackId: trackId,
      availabilityStatus: SongAvailability.downloaded,
      downloadStatus: SongDownloadStatus.downloaded,
      localFilePath: localFilePath,
      contentHash: contentHash,
      artworkReference: localCoverPath,
      lyricsUrl: driveFile.lyricsUrl,
      metadataUpdatedAt: DateTime.now(),
    );

    await indexSong(newSong);

    if (kDebugMode) {
      print('📥 Indexed new download: "${newSong.title}"');
    }
    return newSong;
  }

  // ── Search ──

  /// Search the local library with fuzzy matching
  List<Song> searchLocal(String query) {
    if (query.trim().isEmpty) return getAllSongs();

    final q = query.trim().toLowerCase();
    final songs = getAllSongs();
    final scored = <MapEntry<Song, double>>[];

    for (final song in songs) {
      final combined = '${song.title} ${song.artist} ${song.album} ${song.genre}'.toLowerCase();

      // Exact substring match
      if (combined.contains(q)) {
        scored.add(MapEntry(song, 0.9));
        continue;
      }

      // Word-level matching
      double score = _fuzzyMatch(q, combined);
      if (score >= 0.3) {
        scored.add(MapEntry(song, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  /// Get songs available offline
  List<Song> getOfflineSongs() {
    return getAllSongs().where((s) => s.isAvailableOffline).toList();
  }

  /// Get songs by category
  List<Song> getSongsByCategory(String categoryId) {
    final mappings = getAllMappings()
        .where((m) => m.categoryId == categoryId)
        .map((m) => m.songId)
        .toSet();
    return getAllSongs().where((s) => mappings.contains(s.id)).toList();
  }

  // ── Categories ──

  /// Get all categories
  List<SongCategory> getAllCategories() {
    if (_categoriesBox == null) return SongCategory.defaults;
    return _categoriesBox!.values
        .map((json) {
          try {
            return SongCategory.fromJson(jsonDecode(json));
          } catch (_) {
            return null;
          }
        })
        .where((c) => c != null)
        .cast<SongCategory>()
        .toList();
  }

  /// Add a category
  Future<void> addCategory(SongCategory category) async {
    if (_categoriesBox == null) return;
    await _categoriesBox!.put(category.id, jsonEncode(category.toJson()));
    notifyListeners();
  }

  /// Remove a category
  Future<void> removeCategory(String categoryId) async {
    if (_categoriesBox == null) return;
    await _categoriesBox!.delete(categoryId);
    // Remove all mappings for this category
    final mappings = getAllMappings().where((m) => m.categoryId == categoryId);
    for (final mapping in mappings) {
      await _mappingsBox!.delete('${mapping.songId}_${mapping.categoryId}');
    }
    notifyListeners();
  }

  /// Add a song to a category
  Future<void> addSongToCategory(String songId, String categoryId) async {
    if (_mappingsBox == null) return;
    final key = '${songId}_$categoryId';
    final mapping = SongCategoryMapping(songId: songId, categoryId: categoryId);
    await _mappingsBox!.put(key, jsonEncode(mapping.toJson()));

    // Also update the song's categoryIds
    final song = getSong(songId);
    if (song != null && !song.categoryIds.contains(categoryId)) {
      final updated = song.copyWith(
        categoryIds: [...song.categoryIds, categoryId],
      );
      await indexSong(updated);
    }
    notifyListeners();
  }

  /// Remove a song from a category
  Future<void> removeSongFromCategory(String songId, String categoryId) async {
    if (_mappingsBox == null) return;
    await _mappingsBox!.delete('${songId}_$categoryId');

    // Update song's categoryIds
    final song = getSong(songId);
    if (song != null) {
      final updated = song.copyWith(
        categoryIds: song.categoryIds.where((c) => c != categoryId).toList(),
      );
      await indexSong(updated);
    }
    notifyListeners();
  }

  /// Remove all category mappings for a song
  Future<void> removeSongCategories(String songId) async {
    if (_mappingsBox == null) return;
    final keys = _mappingsBox!.keys
        .where((k) => k.toString().startsWith('${songId}_'))
        .toList();
    for (final key in keys) {
      await _mappingsBox!.delete(key);
    }
  }

  /// Get categories for a specific song
  List<SongCategory> getCategoriesForSong(String songId) {
    final mappings = getAllMappings()
        .where((m) => m.songId == songId)
        .map((m) => m.categoryId)
        .toSet();
    return getAllCategories().where((c) => mappings.contains(c.id)).toList();
  }

  /// Get all category mappings
  List<SongCategoryMapping> getAllMappings() {
    if (_mappingsBox == null) return [];
    return _mappingsBox!.values
        .map((json) {
          try {
            return SongCategoryMapping.fromJson(jsonDecode(json));
          } catch (_) {
            return null;
          }
        })
        .where((m) => m != null)
        .cast<SongCategoryMapping>()
        .toList();
  }

  // ── Cache Management ──

  /// Get total cache size in bytes
  int getTotalCacheSize() {
    if (_cacheBox == null) return 0;
    int total = 0;
    for (final json in _cacheBox!.values) {
      try {
        final entry = CacheEntry.fromJson(jsonDecode(json));
        total += entry.sizeBytes;
      } catch (_) {}
    }
    return total;
  }

  /// Add a cache entry
  Future<void> addCacheEntry(CacheEntry entry) async {
    if (_cacheBox == null) return;
    await _cacheBox!.put(entry.id, jsonEncode(entry.toJson()));
  }

  /// Get cache entry by source key
  CacheEntry? getCacheEntry(String sourceKey) {
    if (_cacheBox == null) return null;
    for (final json in _cacheBox!.values) {
      try {
        final entry = CacheEntry.fromJson(jsonDecode(json));
        if (entry.sourceKey == sourceKey) return entry;
      } catch (_) {}
    }
    return null;
  }

  /// Clear all cache entries (does NOT delete audio files, only metadata)
  Future<void> clearCacheEntries() async {
    if (_cacheBox == null) return;
    await _cacheBox!.clear();
    notifyListeners();
  }

  // ── Library Stats ──

  /// Get a summary of the library
  Map<String, dynamic> getLibraryStats() {
    final songs = getAllSongs();
    final localCount = songs.where((s) => s.availabilityStatus == SongAvailability.local).length;
    final downloadedCount = songs.where((s) => s.availabilityStatus == SongAvailability.downloaded).length;
    final cloudCount = songs.where((s) => s.availabilityStatus == SongAvailability.cloud).length;
    final totalSize = songs.fold<int>(0, (sum, s) => sum + s.fileSize);

    return {
      'total': songs.length,
      'local': localCount,
      'downloaded': downloadedCount,
      'cloud': cloudCount,
      'categories': getAllCategories().length,
      'totalSizeBytes': totalSize,
      'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(1),
      'cacheEntries': _cacheBox?.length ?? 0,
      'cacheSizeBytes': getTotalCacheSize(),
    };
  }

  // ── Private ──

  Future<void> _ensureDefaultCategories() async {
    if (_categoriesBox == null) return;
    if (_categoriesBox!.isEmpty) {
      for (final cat in SongCategory.defaults) {
        await _categoriesBox!.put(cat.id, jsonEncode(cat.toJson()));
      }
      if (kDebugMode) print('📂 Created default categories');
    }
  }

  void _updateCounts() {
    if (_songsBox == null) return;
    final songs = getAllSongs();
    _totalSongs = songs.length;
    _localSongs = songs.where((s) => s.availabilityStatus == SongAvailability.local).length;
    _downloadedSongs = songs.where((s) => s.availabilityStatus == SongAvailability.downloaded).length;
  }

  /// Simple bigram-based fuzzy match (reuse from SearchScreen pattern)
  static double _fuzzyMatch(String query, String target) {
    if (query.length < 2 || target.length < 2) {
      return query == target ? 1.0 : 0.0;
    }

    final queryWords = query.split(RegExp(r'[\s\-_.,/]+'))
        .where((w) => w.isNotEmpty).toList();
    final targetWords = target.split(RegExp(r'[\s\-_.,/]+'))
        .where((w) => w.isNotEmpty).toList();

    if (queryWords.isEmpty || targetWords.isEmpty) return 0.0;

    double totalScore = 0.0;
    for (final qw in queryWords) {
      double bestScore = 0.0;
      for (final tw in targetWords) {
        if (tw == qw) {
          bestScore = 1.0;
          break;
        } else if (tw.startsWith(qw) || qw.startsWith(tw)) {
          final s = 0.8 * (qw.length / (tw.length > qw.length ? tw.length : qw.length));
          if (s > bestScore) bestScore = s;
        } else if (tw.contains(qw)) {
          final s = 0.7 * (qw.length / tw.length);
          if (s > bestScore) bestScore = s;
        }
      }
      totalScore += bestScore;
    }

    return totalScore / queryWords.length;
  }

  @override
  void dispose() {
    _songsBox?.close();
    _categoriesBox?.close();
    _mappingsBox?.close();
    _cacheBox?.close();
    _metaBox?.close();
    super.dispose();
  }
}
