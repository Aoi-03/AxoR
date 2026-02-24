/// API Configuration
/// Backend connection settings
class ApiConfig {
  // For Android Emulator (AVD)
  // static const String baseUrl = 'http://10.0.2.2:3001';
  
  // For Real Device via USB (adb reverse)
  // static const String baseUrl = 'http://localhost:3001';
  
  // For Real Device - WiFi Connection (Same Network)
  // static const String baseUrl = 'http://192.168.0.103:3001';
  
  // For Render Deployment (Works from anywhere!)
  static const String baseUrl = 'https://axor.onrender.com';
  
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

