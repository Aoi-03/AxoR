import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../models/song.dart';

/// API Service
/// Handles all backend communication
class ApiService {
  // Test backend connection
  static Future<bool> testConnection() async {
    try {
      final host = await ApiConfig.detectWorkingBaseUrl();
      final response = await http.get(
        Uri.parse('$host${ApiConfig.health}'),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      print('Connection error: $e');
      return false;
    }
  }
  
  // Get all songs
  static Future<List<Song>> getAllSongs() async {
    try {
      await ApiConfig.detectWorkingBaseUrl();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.songs}'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> songsJson = data['songs'];
        return songsJson.map((json) => Song.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching songs: $e');
      return [];
    }
  }
  
  // Search songs
  static Future<List<Song>> searchSongs(String query) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.search}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> resultsJson = data['results'];
        return resultsJson.map((json) => Song.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error searching songs: $e');
      return [];
    }
  }
  
  // Get AI similar songs (for AI auto-play mode)
  Future<List<Song>> getSimilarSongs(String songId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiSimilar}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'songId': songId}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> songsJson = data['songs'];
        return songsJson.map((json) => Song.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting similar songs: $e');
      return [];
    }
  }
  
  // Get AI similar songs (Flow or Intent mode)
  static Future<List<Song>> getAISimilarSongs(String songId, String mode) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiSimilar}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'songId': songId, 'mode': mode}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> songsJson = data['songs'];
        return songsJson.map((json) => Song.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting AI similar songs: $e');
      return [];
    }
  }
  
  // Get Smart Mode songs (gym, study, drive)
  static Future<List<Song>> getSmartModeSongs(String mode) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.smartMode}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'mode': mode, 'userId': 'user_test1'}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> songsJson = data['songs'];
        return songsJson.map((json) => Song.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting smart mode songs: $e');
      return [];
    }
  }
  
  // Login
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error logging in: $e');
      return null;
    }
  }
  
  // Rescan library
  static Future<bool> rescanLibrary() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.rescan}'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error rescanning library: $e');
      return false;
    }
  }
  
  // Get AI Vibes (dynamic playlists)
  static Future<List<Map<String, dynamic>>> getVibes({String? timeOfDay, String? mood}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiVibes}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': 'user_test1',
          'timeOfDay': timeOfDay,
          'mood': mood,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> vibesJson = data['vibes'];
        return vibesJson.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error getting vibes: $e');
      return [];
    }
  }
}
