import 'package:flutter_test/flutter_test.dart';
import 'package:axor_app/models/song.dart';
import 'package:axor_app/models/song_category.dart';
import 'package:axor_app/services/google_drive_service.dart';

void main() {
  group('Song Model Tests', () {
    test('Song serialization roundtrip preserves all local-first fields', () {
      final now = DateTime.now();
      final song = Song(
        id: 'song_123',
        title: 'Cyberpunk Odyssey',
        artist: 'AxoR Synth',
        album: 'Neon Horizon',
        duration: 215,
        bpm: 128,
        energy: 0.85,
        mood: 'energetic',
        genre: 'Synthwave',
        filePath: '/storage/music/song_123.flac',
        coverPath: 'embedded',
        fileSize: 25000000,
        format: 'FLAC',
        sampleRate: 48000,
        bitrate: 1536,
        contentHash: 'a1b2c3d4e5f6',
        providerTrackId: 'drive_file_999',
        availabilityStatus: SongAvailability.downloaded,
        downloadStatus: SongDownloadStatus.downloaded,
        artworkReference: '/storage/covers/song_123.jpg',
        localFilePath: '/storage/downloads/song_123.flac',
        metadataUpdatedAt: now,
        categoryIds: ['cat_gym', 'cat_drive'],
      );

      final json = song.toJson();
      final deserialized = Song.fromJson(json);

      expect(deserialized.id, equals('song_123'));
      expect(deserialized.title, equals('Cyberpunk Odyssey'));
      expect(deserialized.contentHash, equals('a1b2c3d4e5f6'));
      expect(deserialized.providerTrackId, equals('drive_file_999'));
      expect(deserialized.availabilityStatus, equals(SongAvailability.downloaded));
      expect(deserialized.downloadStatus, equals(SongDownloadStatus.downloaded));
      expect(deserialized.localFilePath, equals('/storage/downloads/song_123.flac'));
      expect(deserialized.categoryIds, equals(['cat_gym', 'cat_drive']));
      expect(deserialized.isLocal, isTrue);
      expect(deserialized.isAvailableOffline, isTrue);
      expect(deserialized.formattedDuration, equals('03:35'));
    });

    test('DriveAudioFile serialization preserves customStreamUrl and thumbnailLink', () {
      final file = DriveAudioFile(
        id: 'drive_001',
        name: 'Track01.mp3',
        mimeType: 'audio/mpeg',
        fileSize: 8400000,
        title: 'Starlight',
        artist: 'Luna',
        album: 'Cosmic',
        durationSeconds: 180,
        coverArtUrl: 'https://example.com/cover.jpg',
        thumbnailLink: '/local/path/thumb.jpg',
        customStreamUrl: '/local/downloads/track01.mp3',
      );

      final json = file.toJson();
      expect(json['customStreamUrl'], equals('/local/downloads/track01.mp3'));
      expect(json['thumbnailLink'], equals('/local/path/thumb.jpg'));

      final restored = DriveAudioFile.fromJson(json);
      expect(restored.customStreamUrl, equals('/local/downloads/track01.mp3'));
      expect(restored.thumbnailLink, equals('/local/path/thumb.jpg'));
      expect(restored.displayTitle, equals('Starlight'));
      expect(restored.displayArtist, equals('Luna'));
    });

    test('SongCategory model has default categories initialized', () {
      final defaults = SongCategory.defaults;
      expect(defaults.length, equals(4));
      expect(defaults.map((c) => c.name), containsAll(['Gym', 'Study', 'Drive', 'General']));
    });

    test('CacheEntry model serialization', () {
      final entry = CacheEntry(
        id: 'cache_1',
        cacheType: 'artwork',
        sourceKey: 'https://cdn.example.com/art.jpg',
        localPath: '/data/cache/art.jpg',
        sizeBytes: 15420,
      );

      final json = entry.toJson();
      final restored = CacheEntry.fromJson(json);
      expect(restored.sourceKey, equals('https://cdn.example.com/art.jpg'));
      expect(restored.sizeBytes, equals(15420));
      expect(restored.cacheType, equals('artwork'));
    });
  });
}
