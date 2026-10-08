import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/api_service.dart';

/// Music Provider
/// Manages songs and backend state
class MusicProvider with ChangeNotifier {
  List<Song> _allSongs = [];
  List<Song> _searchResults = [];
  bool _isLoading = false;
  bool _isConnected = false;
  String? _error;
  
  // Getters
  List<Song> get allSongs => _allSongs;
  List<Song> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String? get error => _error;
  
  // Test backend connection
  Future<void> testConnection() async {
    _isConnected = await ApiService.testConnection();
    notifyListeners();
  }
  
  // Load all songs from backend
  Future<void> loadSongs() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _allSongs = await ApiService.getAllSongs();
      _isConnected = true;
      if (kDebugMode) {
        print('✅ Loaded ${_allSongs.length} songs from backend');
      }
    } catch (e) {
      _error = 'Failed to load songs: $e';
      _isConnected = false;
      if (kDebugMode) {
        print('❌ Error loading songs: $e');
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  // Search songs
  Future<void> searchSongs(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      _searchResults = await ApiService.searchSongs(query);
      if (kDebugMode) {
        print('✅ Found ${_searchResults.length} songs for "$query"');
      }
    } catch (e) {
      _error = 'Search failed: $e';
      if (kDebugMode) {
        print('❌ Search error: $e');
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  // Get AI similar songs (Flow or Intent mode)
  Future<List<Song>> getAISimilarSongs(String songId, String mode) async {
    try {
      final songs = await ApiService.getAISimilarSongs(songId, mode);
      if (kDebugMode) {
        print('✅ Got ${songs.length} similar songs in $mode mode');
      }
      return songs;
    } catch (e) {
      if (kDebugMode) {
        print('❌ AI similar error: $e');
      }
      return [];
    }
  }
  
  // Get Smart Mode songs (gym, study, drive)
  Future<List<Song>> getSmartModeSongs(String mode) async {
    try {
      final songs = await ApiService.getSmartModeSongs(mode);
      if (kDebugMode) {
        print('✅ Got ${songs.length} songs for $mode mode');
      }
      return songs;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Smart mode error: $e');
      }
      return [];
    }
  }
  
  // Rescan library
  Future<void> rescanLibrary() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final success = await ApiService.rescanLibrary();
      if (success) {
        await loadSongs(); // Reload songs after rescan
        if (kDebugMode) {
          print('✅ Library rescanned successfully');
        }
      }
    } catch (e) {
      _error = 'Rescan failed: $e';
      if (kDebugMode) {
        print('❌ Rescan error: $e');
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  // Get songs by mood
  List<Song> getSongsByMood(String mood) {
    return _allSongs.where((song) => song.mood == mood).toList();
  }
  
  // Get songs by energy range
  List<Song> getSongsByEnergy(double minEnergy, double maxEnergy) {
    return _allSongs.where((song) => 
      song.energy >= minEnergy && song.energy <= maxEnergy
    ).toList();
  }
  
  // Get high energy songs (for Gym mode)
  List<Song> getHighEnergySongs() {
    return _allSongs.where((song) => 
      song.energy >= 0.7 && song.bpm >= 120
    ).toList();
  }
  
  // Get low energy songs (for Study mode)
  List<Song> getLowEnergySongs() {
    return _allSongs.where((song) => 
      song.energy <= 0.5 && song.bpm <= 100
    ).toList();
  }
  
  // Get medium energy songs (for Drive mode)
  List<Song> getMediumEnergySongs() {
    return _allSongs.where((song) => 
      song.energy >= 0.5 && song.energy <= 0.8
    ).toList();
  }

  // Remove song from active library
  void removeSong(String songId) {
    _allSongs.removeWhere((s) => s.id == songId);
    _searchResults.removeWhere((s) => s.id == songId);
    notifyListeners();
  }
}
