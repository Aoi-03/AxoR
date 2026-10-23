import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'google_drive_service.dart';

/// Single line of lyric with timestamp
class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({required this.timestamp, required this.text});
}

/// Parsed lyrics structure
class LyricsData {
  final List<LyricLine> lines;
  final bool isSynced;
  final String rawText;

  const LyricsData({
    required this.lines,
    required this.isSynced,
    required this.rawText,
  });
}

/// Ultra-lightweight, memory-constrained Lyrics Service
///
/// Optimization Principles:
/// 1. ZERO background preloading: Lyrics are ONLY fetched when explicitly requested.
/// 2. Micro LRU memory cache: Keeps at most 3 songs in memory (< 20 KB RAM total).
/// 3. Zero battery drain: No background loops or persistent pollers.
class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  static const int _maxCacheSize = 3;
  final Map<String, LyricsData> _cache = {};
  final List<String> _cacheOrder = [];

  /// Check if lyrics are already cached in memory
  bool isCached(String songId) => _cache.containsKey(songId);

  /// Fetch and parse lyrics on-demand for a given song
  Future<LyricsData?> getLyrics({
    required String songId,
    String? lyricsUrl,
    String? localFilePath,
    String? title,
    String? artist,
  }) async {
    // 1. Check in-memory micro-cache (instant return, 0 network, 0 RAM growth)
    if (_cache.containsKey(songId)) {
      _cacheOrder.remove(songId);
      _cacheOrder.add(songId);
      return _cache[songId];
    }

    String? content;

    // 2. Try reading from local file if available
    if (localFilePath != null && localFilePath.isNotEmpty) {
      try {
        final f = File(localFilePath);
        if (f.existsSync()) {
          content = await f.readAsString();
        }
      } catch (_) {}
    }

    // 3. Try fetching from URL (Google Drive or backend)
    if (content == null && lyricsUrl != null && lyricsUrl.isNotEmpty) {
      if (lyricsUrl.startsWith('http://') || lyricsUrl.startsWith('https://')) {
        try {
          String resolvedUrl = lyricsUrl;
          if (resolvedUrl.contains('drive.google.com/file/d/') ||
              resolvedUrl.contains('drive.google.com/open') ||
              resolvedUrl.contains('drive.google.com/uc')) {
            final uri = Uri.tryParse(resolvedUrl);
            String? fileId = uri?.queryParameters['id'];
            if (fileId == null || fileId.isEmpty) {
              final match = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(resolvedUrl);
              fileId = match?.group(1);
            }
            if (fileId != null && fileId.isNotEmpty) {
              resolvedUrl = 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';
            }
          }

          final isDrive = resolvedUrl.contains('googleapis.com') ||
              resolvedUrl.contains('drive.google.com');
          final headers = isDrive ? await GoogleDriveService().getAuthHeaders() : null;

          final response = await http
              .get(Uri.parse(resolvedUrl), headers: headers)
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            content = utf8.decode(response.bodyBytes);
          }
        } catch (e) {
          if (kDebugMode) print('Lyrics fetch error: $e');
        }
      } else {
        // Local path
        try {
          final f = File(lyricsUrl);
          if (f.existsSync()) {
            content = await f.readAsString();
          }
        } catch (_) {}
      }
    }

    // 4. Online fallback via LRCLIB if Drive .lrc not found
    if (content == null || content.trim().isEmpty) {
      try {
        final queryTitle = (title != null && title.isNotEmpty)
            ? title.replaceAll(RegExp(r'\(.*?\)'), '').trim()
            : songId;
        final queryArtist = (artist != null && artist != 'Unknown Artist')
            ? artist.split(',')[0].split(';')[0].trim()
            : '';

        final lrcUri = Uri.parse(
          'https://lrclib.net/api/get?artist_name=${Uri.encodeComponent(queryArtist)}&track_name=${Uri.encodeComponent(queryTitle)}',
        );
        final resp = await http.get(lrcUri).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final data = jsonDecode(utf8.decode(resp.bodyBytes));
          if (data is Map) {
            final synced = data['syncedLyrics']?.toString();
            final plain = data['plainLyrics']?.toString();
            if (synced != null && synced.isNotEmpty) {
              content = synced;
            } else if (plain != null && plain.isNotEmpty) {
              content = plain;
            }
          }
        }
      } catch (_) {}
    }

    if (content == null || content.trim().isEmpty) {
      return null;
    }

    // 4. Parse LRC / Plain format
    final parsed = parseLyrics(content);

    // 5. Cache with strict LRU eviction (max 3 items in RAM)
    _addToCache(songId, parsed);

    return parsed;
  }

  /// Parse .lrc or plain text into LyricsData
  static LyricsData parseLyrics(String raw) {
    final lines = <LyricLine>[];
    final rawLines = raw.split(RegExp(r'\r?\n'));
    final lrcRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)');
    bool hasSync = false;

    for (final line in rawLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final match = lrcRegex.firstMatch(trimmed);
      if (match != null) {
        hasSync = true;
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final fractionStr = match.group(3) ?? '0';
        int milliseconds = 0;
        if (fractionStr.length == 1) {
          milliseconds = (int.tryParse(fractionStr) ?? 0) * 100;
        } else if (fractionStr.length == 2) {
          milliseconds = (int.tryParse(fractionStr) ?? 0) * 10;
        } else {
          milliseconds = int.tryParse(fractionStr) ?? 0;
        }

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );
        final text = (match.group(4) ?? '').trim();
        lines.add(LyricLine(timestamp: duration, text: text));
      } else {
        // Skip metadata tags like [ar:Adele] or [offset:0]
        if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) {
          lines.add(LyricLine(timestamp: Duration.zero, text: trimmed));
        }
      }
    }

    // Sort by timestamp if synced
    if (hasSync) {
      lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    return LyricsData(
      lines: lines,
      isSynced: hasSync,
      rawText: raw,
    );
  }

  void _addToCache(String songId, LyricsData data) {
    if (_cache.length >= _maxCacheSize) {
      if (_cacheOrder.isNotEmpty) {
        final oldest = _cacheOrder.removeAt(0);
        _cache.remove(oldest);
      }
    }
    _cache[songId] = data;
    _cacheOrder.add(songId);
  }

  /// Clear in-memory cache to release all memory immediately
  void clearMemory() {
    _cache.clear();
    _cacheOrder.clear();
  }
}

