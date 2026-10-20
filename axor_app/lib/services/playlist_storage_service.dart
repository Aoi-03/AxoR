import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';

/// Playlist Storage Service
/// Manages local storage of user playlists (The Shelf)
/// Stores only playlist metadata and song IDs, not actual song files
class PlaylistStorageService {
  static const String _playlistsKey = 'user_playlists';
  
  /// Save playlists to local storage
  static Future<bool> savePlaylists(List<Playlist> playlists) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = playlists.map((p) => p.toJson()).toList();
      final jsonString = jsonEncode(playlistsJson);
      return await prefs.setString(_playlistsKey, jsonString);
    } catch (e) {
      if (kDebugMode) print('❌ Error saving playlists: $e');
      return false;
    }
  }
  
  /// Load playlists from local storage
  static Future<List<Playlist>> loadPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_playlistsKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final List<dynamic> playlistsJson = jsonDecode(jsonString);
      return playlistsJson.map((json) => Playlist.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Error loading playlists: $e');
      return [];
    }
  }
  
  /// Add a new playlist
  static Future<bool> addPlaylist(Playlist playlist) async {
    final playlists = await loadPlaylists();
    playlists.add(playlist);
    return await savePlaylists(playlists);
  }
  
  /// Update an existing playlist
  static Future<bool> updatePlaylist(Playlist updatedPlaylist) async {
    final playlists = await loadPlaylists();
    final index = playlists.indexWhere((p) => p.id == updatedPlaylist.id);
    
    if (index == -1) {
      return false;
    }
    
    playlists[index] = updatedPlaylist;
    return await savePlaylists(playlists);
  }
  
  /// Delete a playlist
  static Future<bool> deletePlaylist(String playlistId) async {
    final playlists = await loadPlaylists();
    playlists.removeWhere((p) => p.id == playlistId);
    return await savePlaylists(playlists);
  }
  
  /// Add song to playlist
  static Future<bool> addSongToPlaylist(String playlistId, String songId) async {
    final playlists = await loadPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return false;

    final playlist = playlists[index];
    if (playlist.songIds.contains(songId)) {
      return true; // Already in playlist
    }
    
    final updatedPlaylist = playlist.copyWith(
      songIds: [...playlist.songIds, songId],
      updatedAt: DateTime.now(),
    );
    
    return await updatePlaylist(updatedPlaylist);
  }
  
  /// Remove song from playlist
  static Future<bool> removeSongFromPlaylist(String playlistId, String songId) async {
    final playlists = await loadPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return false;

    final playlist = playlists[index];
    final updatedSongIds = playlist.songIds.where((id) => id != songId).toList();
    final updatedPlaylist = playlist.copyWith(
      songIds: updatedSongIds,
      updatedAt: DateTime.now(),
    );
    
    return await updatePlaylist(updatedPlaylist);
  }
  
  /// Get playlist by ID
  static Future<Playlist?> getPlaylist(String playlistId) async {
    final playlists = await loadPlaylists();
    try {
      return playlists.firstWhere((p) => p.id == playlistId);
    } catch (e) {
      return null;
    }
  }
  
  /// Clear all playlists (for testing/reset)
  static Future<bool> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_playlistsKey);
    } catch (e) {
      if (kDebugMode) print('❌ Error clearing playlists: $e');
      return false;
    }
  }
  
  /// Get storage size estimate (in bytes)
  static Future<int> getStorageSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_playlistsKey);
      return jsonString?.length ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
