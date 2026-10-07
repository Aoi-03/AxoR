import 'package:flutter/foundation.dart';
import '../services/google_drive_service.dart';

/// Drive Provider
/// Manages Google Drive file listing, searching, and caching
class DriveProvider with ChangeNotifier {
  final GoogleDriveService _driveService = GoogleDriveService();

  List<DriveAudioFile> _audioFiles = [];
  List<DriveAudioFile> _searchResults = [];
  List<DriveFolder> _folders = [];
  DriveStorageInfo? _storageInfo;

  bool _isLoadingFiles = false;
  bool _isSearching = false;
  bool _isLoadingStorage = false;
  String? _currentFolderId;
  String? _errorMessage;

  // ── Getters ──────────────────────────────────────────
  List<DriveAudioFile> get audioFiles => _audioFiles;
  List<DriveAudioFile> get searchResults => _searchResults;
  List<DriveFolder> get folders => _folders;
  DriveStorageInfo? get storageInfo => _storageInfo;
  bool get isLoadingFiles => _isLoadingFiles;
  bool get isSearching => _isSearching;
  bool get isLoadingStorage => _isLoadingStorage;
  String? get currentFolderId => _currentFolderId;
  String? get errorMessage => _errorMessage;
  int get totalFiles => _audioFiles.length;

  // ── File Actions ──────────────────────────────────────

  /// Load all audio files from Drive
  Future<void> loadAudioFiles({String? folderId}) async {
    _isLoadingFiles = true;
    _errorMessage = null;
    _currentFolderId = folderId;
    notifyListeners();

    try {
      _audioFiles = await _driveService.listAudioFiles(folderId: folderId);
      if (kDebugMode) {
        print('📁 Loaded ${_audioFiles.length} audio files from Drive');
      }
    } catch (e) {
      _errorMessage = 'Failed to load files from Drive';
      if (kDebugMode) print('Error loading files: $e');
    } finally {
      _isLoadingFiles = false;
      notifyListeners();
    }
  }

  /// Search audio files
  Future<void> searchFiles(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await _driveService.searchAudioFiles(query);
    } catch (e) {
      if (kDebugMode) print('Search error: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Load folders for browsing
  Future<void> loadFolders({String? parentId}) async {
    try {
      _folders = await _driveService.listFolders(parentId: parentId);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error loading folders: $e');
    }
  }

  /// Load storage info
  Future<void> loadStorageInfo() async {
    _isLoadingStorage = true;
    notifyListeners();

    try {
      _storageInfo = await _driveService.getStorageInfo();
    } catch (e) {
      if (kDebugMode) print('Error loading storage info: $e');
    } finally {
      _isLoadingStorage = false;
      notifyListeners();
    }
  }

  /// Get streaming URL for a file
  Future<String?> getStreamUrl(String fileId) async {
    return _driveService.getStreamUrl(fileId);
  }

  /// Get auth headers for streaming
  Future<Map<String, String>?> getAuthHeaders() async {
    return _driveService.getAuthHeaders();
  }

  /// Clear search results
  void clearSearch() {
    _searchResults = [];
    _isSearching = false;
    notifyListeners();
  }

  /// Refresh files
  Future<void> refresh() async {
    await loadAudioFiles(folderId: _currentFolderId);
  }
}
