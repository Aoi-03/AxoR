import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'google_drive_service.dart';

class DownloadService with ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;

  DownloadService._internal();

  final GoogleDriveService _driveService = GoogleDriveService();
  
  // Set of IDs currently downloading to show progress in UI
  final Set<String> _downloadingIds = {};
  
  bool isDownloading(String id) => _downloadingIds.contains(id);

  Future<void> downloadSong(DriveAudioFile song) async {
    if (isDownloading(song.id)) return;
    
    _downloadingIds.add(song.id);
    notifyListeners();

    try {
      final headers = await _driveService.getAuthHeaders();
      
      if (kDebugMode) print('⬇️ Starting download: ${song.displayTitle}');
      
      final response = await http.get(
        Uri.parse(song.streamUrl),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        
        // Use a safe filename
        final safeTitle = song.displayTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final file = File('${dir.path}/$safeTitle.mp3');
        
        await file.writeAsBytes(response.bodyBytes);
        
        if (kDebugMode) print('✅ Download complete: ${file.path}');
        
        // Note: we can add this to Hive database in the future to track downloaded files.
      } else {
        if (kDebugMode) print('❌ Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Download error: $e');
    } finally {
      _downloadingIds.remove(song.id);
      notifyListeners();
    }
  }
}
