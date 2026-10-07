import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// API Configuration
/// Backend connection settings
class ApiConfig {
  static String? _cachedBaseUrl;

  static void setBaseUrl(String url) {
    _cachedBaseUrl = url;
  }

  // Dynamically selects backend:
  // - Real phone via USB adb reverse: 127.0.0.1:3000
  // - Real phone via Wi-Fi: 10.244.5.162:3000
  // - Android emulator: 10.0.2.2:3000
  // - Desktop, Web: localhost:3000
  static String get baseUrl {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    if (kIsWeb) return 'http://localhost:3000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    } catch (_) {}
    return 'http://localhost:3000';
  }

  /// Automatically pings candidates to find the active backend host
  static Future<String> detectWorkingBaseUrl() async {
    final candidateHosts = [
      'http://127.0.0.1:3000',
      'http://10.244.5.162:3000',
      'http://10.0.2.2:3000',
      'http://localhost:3000',
    ];

    for (final host in candidateHosts) {
      try {
        final res = await http.get(Uri.parse('$host/health')).timeout(const Duration(milliseconds: 1200));
        if (res.statusCode == 200) {
          _cachedBaseUrl = host;
          return host;
        }
      } catch (_) {}
    }
    return baseUrl;
  }
  
  // API Endpoints
  static const String health = '/health';
  static const String songs = '/api/songs';
  static const String search = '/api/songs/search';
  static const String rescan = '/api/songs/rescan';
  static const String login = '/api/auth/login';
  static const String signup = '/api/auth/signup';
  static const String aiSimilar = '/api/ai/similar';
  static const String smartMode = '/api/ai/smart-mode';
  static const String aiVibes = '/api/ai/vibes'; // NEW
  static const String likeSong = '/api/songs/like';
  static const String likedSongs = '/api/songs/liked';
  static const String playlists = '/api/playlists';
  static const String createPlaylist = '/api/playlists/create'; // NEW
  static const String addToPlaylist = '/api/playlists/add-song'; // NEW
  static const String removeFromPlaylist = '/api/playlists/remove-song'; // NEW
  static const String deletePlaylist = '/api/playlists/delete'; // NEW
  static const String profile = '/api/profile';
  
  // Song streaming URL
  static String getSongUrl(String filePath) {
    return '$baseUrl$filePath';
  }
}

