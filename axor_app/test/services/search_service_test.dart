import 'package:flutter_test/flutter_test.dart';
import 'package:axor_app/services/google_drive_service.dart';
import 'package:axor_app/services/local_library_service.dart';
import 'package:axor_app/services/search_service.dart';

void main() {
  group('SearchService Layered Pipeline Tests', () {
    late SearchService searchService;

    setUp(() {
      searchService = SearchService(LocalLibraryService());
    });

    test('Offline search excludes remote Google Drive files', () {
      final List<DriveAudioFile> driveFiles = [
        DriveAudioFile(
          id: 'cloud_1',
          name: 'Midnight Run.mp3',
          mimeType: 'audio/mpeg',
          fileSize: 5000000,
          title: 'Midnight Run',
          artist: 'Neon Rider',
        ),
      ];

      final List<DriveAudioFile> downloadedFiles = [
        DriveAudioFile(
          id: 'local_1',
          name: 'Daylight Dream.mp3',
          mimeType: 'audio/mpeg',
          fileSize: 4000000,
          title: 'Daylight Dream',
          artist: 'Solar Ray',
          customStreamUrl: '/local/daylight.mp3',
        ),
      ];

      // Offline search
      final results = searchService.search(
        query: 'Midnight',
        isOnline: false,
        driveFiles: driveFiles,
        downloadedFiles: downloadedFiles,
      );

      // Cloud song should NOT appear because offline
      expect(results.any((r) => r.file.id == 'cloud_1'), isFalse);
    });

    test('Online search includes both Google Drive and downloaded files', () {
      final List<DriveAudioFile> driveFiles = [
        DriveAudioFile(
          id: 'cloud_1',
          name: 'Midnight Run.mp3',
          mimeType: 'audio/mpeg',
          fileSize: 5000000,
          title: 'Midnight Run',
          artist: 'Neon Rider',
        ),
      ];

      final List<DriveAudioFile> downloadedFiles = [
        DriveAudioFile(
          id: 'local_1',
          name: 'Midnight City.mp3',
          mimeType: 'audio/mpeg',
          fileSize: 4000000,
          title: 'Midnight City',
          artist: 'M83',
          customStreamUrl: '/local/m83.mp3',
        ),
      ];

      final results = searchService.search(
        query: 'Midnight',
        isOnline: true,
        driveFiles: driveFiles,
        downloadedFiles: downloadedFiles,
      );

      expect(results.length, equals(2));
      expect(results.any((r) => r.file.id == 'cloud_1'), isTrue);
      expect(results.any((r) => r.file.id == 'local_1'), isTrue);
    });

    test('Category filtering filters by energy and bpm correctly', () {
      final List<DriveAudioFile> files = [
        DriveAudioFile(
          id: 'high_energy_1',
          name: 'Hardstyle Beats.mp3',
          mimeType: 'audio/mpeg',
          fileSize: 6000000,
          title: 'Hardstyle Beats',
          artist: 'DJ Turbo',
          energy: 0.9,
          bpm: 150,
          genre: 'EDM',
        ),
        DriveAudioFile(
          id: 'calm_1',
          name: 'Peaceful Rain.mp3',
          mimeType: 'audio/mpeg',
          fileSize: 3000000,
          title: 'Peaceful Rain',
          artist: 'Chillout Sound',
          energy: 0.2,
          bpm: 70,
          genre: 'Ambient',
        ),
      ];

      final gymResults = searchService.search(
        query: '',
        isOnline: true,
        driveFiles: files,
        categoryFilter: 'High Energy',
      );
      expect(gymResults.length, equals(1));
      expect(gymResults.first.file.id, equals('high_energy_1'));

      final calmResults = searchService.search(
        query: '',
        isOnline: true,
        driveFiles: files,
        categoryFilter: 'Calm',
      );
      expect(calmResults.length, equals(1));
      expect(calmResults.first.file.id, equals('calm_1'));

      final fastBpmResults = searchService.search(
        query: '',
        isOnline: true,
        driveFiles: files,
        categoryFilter: 'Fast BPM (>120)',
      );
      expect(fastBpmResults.length, equals(1));
      expect(fastBpmResults.first.file.id, equals('high_energy_1'));
    });

    test('Fuzzy matching matches partial queries and ranks accordingly', () {
      final List<DriveAudioFile> files = [
        DriveAudioFile(
          id: 's1',
          name: 'Resonance.mp3',
          mimeType: 'audio/mpeg',
          fileSize: 4000000,
          title: 'Resonance',
          artist: 'HOME',
        ),
        DriveAudioFile(
          id: 's2',
          name: 'Something Else.mp3',
          mimeType: 'audio/mpeg',
          fileSize: 4000000,
          title: 'Something Else',
          artist: 'Unknown',
        ),
      ];

      final results = searchService.search(
        query: 'Reson',
        isOnline: true,
        driveFiles: files,
      );

      expect(results.isNotEmpty, isTrue);
      expect(results.first.file.id, equals('s1'));
      expect(results.first.score, greaterThan(0.5));
    });
  });
}
