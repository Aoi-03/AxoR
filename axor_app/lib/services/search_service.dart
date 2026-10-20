import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/google_drive_service.dart';
import '../services/local_library_service.dart';

/// Search result with confidence score and source indicator
class SearchResult {
  final DriveAudioFile file;
  final double score;
  final SearchSource source;

  SearchResult({
    required this.file,
    required this.score,
    required this.source,
  });
}

/// Where the search result came from
enum SearchSource {
  localExact,     // Exact metadata match in local DB
  localFuzzy,     // Fuzzy text match in local DB
  localCategory,  // Category/mood filter match
  downloaded,     // Downloaded songs
  cloudDrive,     // Google Drive search
  cloudBackend,   // Backend API search
}

/// SearchService — Layered search pipeline
///
/// Priority order:
/// 1. Exact local metadata match (title/artist/album)
/// 2. Normalized fuzzy local text search
/// 3. Category/mood/genre filter match
/// 4. Downloaded songs search
/// 5. Cloud Drive search (only if online)
/// 6. Backend API search (only if online and no local results)
class SearchService {
  final LocalLibraryService _localLibrary;

  SearchService(this._localLibrary);

  /// Execute the layered search pipeline
  ///
  /// [query] — The search text
  /// [isOnline] — Whether network is available
  /// [driveFiles] — Currently loaded Google Drive audio files
  /// [downloadedFiles] — Downloaded songs on device
  /// [backendSongs] — Songs from the backend API
  /// [categoryFilter] — Optional category filter name
  List<SearchResult> search({
    required String query,
    required bool isOnline,
    List<DriveAudioFile> driveFiles = const [],
    List<DriveAudioFile> downloadedFiles = const [],
    List<Song> backendSongs = const [],
    String? categoryFilter,
  }) {
    final q = query.trim().toLowerCase();
    final results = <SearchResult>[];
    final seenIds = <String>{};

    // Layer 1: Exact local metadata match
    if (q.isNotEmpty) {
      final localSongs = _localLibrary.getAllSongs();
      for (final song in localSongs) {
        if (seenIds.contains(song.id)) continue;

        final titleMatch = song.title.toLowerCase() == q;
        final artistMatch = song.artist.toLowerCase() == q;
        final albumMatch = song.album.toLowerCase() == q;

        if (titleMatch || artistMatch || albumMatch) {
          seenIds.add(song.id);
          results.add(SearchResult(
            file: DriveAudioFile.fromSong(song),
            score: 1.0,
            source: SearchSource.localExact,
          ));
        }
      }
    }

    // Layer 2: Fuzzy local text search
    if (q.isNotEmpty) {
      final localSongs = _localLibrary.getAllSongs();
      for (final song in localSongs) {
        if (seenIds.contains(song.id)) continue;

        final combined = '${song.title} ${song.artist} ${song.album} ${song.genre}'.toLowerCase();
        final score = _calculateSimilarity(q, combined);

        if (score >= 0.25 || combined.contains(q)) {
          seenIds.add(song.id);
          results.add(SearchResult(
            file: DriveAudioFile.fromSong(song),
            score: score.clamp(0.0, 0.95),
            source: SearchSource.localFuzzy,
          ));
        }
      }
    }

    // Layer 3: Downloaded songs
    for (final file in downloadedFiles) {
      if (seenIds.contains(file.id)) continue;

      if (q.isEmpty) {
        seenIds.add(file.id);
        results.add(SearchResult(
          file: file,
          score: 0.5,
          source: SearchSource.downloaded,
        ));
      } else {
        final combined = '${file.displayTitle} ${file.displayArtist} ${file.album ?? ''}'.toLowerCase();
        final score = _calculateSimilarity(q, combined);

        if (score >= 0.25 || combined.contains(q)) {
          seenIds.add(file.id);
          results.add(SearchResult(
            file: file,
            score: score.clamp(0.0, 0.9),
            source: SearchSource.downloaded,
          ));
        }
      }
    }

    // Layer 4: Backend songs (may already be loaded, no network needed)
    for (final song in backendSongs) {
      if (seenIds.contains(song.id)) continue;

      if (q.isEmpty) {
        seenIds.add(song.id);
        results.add(SearchResult(
          file: DriveAudioFile.fromSong(song),
          score: 0.4,
          source: SearchSource.cloudBackend,
        ));
      } else {
        final combined = '${song.title} ${song.artist} ${song.album} ${song.genre}'.toLowerCase();
        final score = _calculateSimilarity(q, combined);

        if (score >= 0.25 || combined.contains(q)) {
          seenIds.add(song.id);
          results.add(SearchResult(
            file: DriveAudioFile.fromSong(song),
            score: score.clamp(0.0, 0.85),
            source: SearchSource.cloudBackend,
          ));
        }
      }
    }

    // Layer 5: Cloud Drive search (only if online)
    if (isOnline) {
      for (final file in driveFiles) {
        if (seenIds.contains(file.id)) continue;

        if (q.isEmpty) {
          seenIds.add(file.id);
          results.add(SearchResult(
            file: file,
            score: 0.3,
            source: SearchSource.cloudDrive,
          ));
        } else {
          final combined = '${file.displayTitle} ${file.displayArtist} ${file.album ?? ''}'.toLowerCase();
          final score = _calculateSimilarity(q, combined);

          if (score >= 0.25 || combined.contains(q)) {
            seenIds.add(file.id);
            results.add(SearchResult(
              file: file,
              score: score.clamp(0.0, 0.80),
              source: SearchSource.cloudDrive,
            ));
          }
        }
      }
    }

    // Apply category filter if specified
    if (categoryFilter != null && categoryFilter != 'All') {
      _applyCategoryFilter(results, categoryFilter);
    }

    // Sort by score descending
    results.sort((a, b) => b.score.compareTo(a.score));

    if (kDebugMode && q.isNotEmpty) {
      final localCount = results.where((r) =>
          r.source == SearchSource.localExact ||
          r.source == SearchSource.localFuzzy).length;
      final cloudCount = results.where((r) =>
          r.source == SearchSource.cloudDrive ||
          r.source == SearchSource.cloudBackend).length;
      debugPrint('🔍 Search "$query": $localCount local, $cloudCount cloud, ${results.length} total');
    }

    return results;
  }

  /// Apply category filter to results in-place
  void _applyCategoryFilter(List<SearchResult> results, String filter) {
    results.removeWhere((r) {
      switch (filter) {
        case 'High Energy':
          return (r.file.energy ?? 0.0) < 0.7;
        case 'Calm':
          return (r.file.energy ?? 0.0) > 0.45;
        case 'Fast BPM (>120)':
          return (r.file.bpm ?? 0) < 120;
        case 'Rock / EDM':
          final g = (r.file.genre ?? '').toLowerCase();
          return !(g.contains('rock') || g.contains('edm') ||
              g.contains('electronic') || g.contains('metal'));
        default:
          return false;
      }
    });
  }

  // ── Fuzzy Matching (Dice Bigram Coefficient) ──

  /// Bigram Dice coefficient for word-to-word similarity
  static double _diceSimilarity(String s1, String s2) {
    if (s1.length < 2 || s2.length < 2) {
      return s1 == s2 ? 1.0 : 0.0;
    }
    final s1Bigrams = <String>{};
    for (int i = 0; i < s1.length - 1; i++) {
      s1Bigrams.add(s1.substring(i, i + 2));
    }
    int matches = 0;
    for (int i = 0; i < s2.length - 1; i++) {
      if (s1Bigrams.contains(s2.substring(i, i + 2))) {
        matches++;
      }
    }
    return (2.0 * matches) / ((s1.length - 1) + (s2.length - 1));
  }

  /// Word-to-word similarity algorithm
  static double _calculateSimilarity(String query, String targetText) {
    final q = query.trim().toLowerCase();
    final t = targetText.trim().toLowerCase();
    if (q.isEmpty || t.isEmpty) return 0.0;
    if (t == q) return 1.0;
    if (t.contains(q)) return 0.85;

    final queryWords = q.split(RegExp(r'[\s\-_.,/]+')).where((w) => w.isNotEmpty).toList();
    final textWords = t.split(RegExp(r'[\s\-_.,/]+')).where((w) => w.isNotEmpty).toList();

    if (queryWords.isEmpty || textWords.isEmpty) return 0.0;

    double totalScore = 0.0;
    for (final qWord in queryWords) {
      double bestWordScore = 0.0;
      for (final tWord in textWords) {
        if (tWord == qWord) {
          bestWordScore = 1.0;
          break;
        } else if (tWord.startsWith(qWord) || qWord.startsWith(tWord)) {
          final maxLen = tWord.length > qWord.length ? tWord.length : qWord.length;
          final score = 0.8 * (qWord.length / maxLen);
          if (score > bestWordScore) bestWordScore = score;
        } else if (tWord.contains(qWord)) {
          final score = 0.7 * (qWord.length / tWord.length);
          if (score > bestWordScore) bestWordScore = score;
        } else {
          final dice = _diceSimilarity(qWord, tWord);
          if (dice > 0.55 && dice > bestWordScore) {
            bestWordScore = dice * 0.75;
          }
        }
      }
      totalScore += bestWordScore;
    }

    return totalScore / queryWords.length;
  }
}
