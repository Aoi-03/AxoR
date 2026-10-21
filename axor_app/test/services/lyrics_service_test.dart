import 'package:flutter_test/flutter_test.dart';
import 'package:axor_app/services/lyrics_service.dart';

void main() {
  group('LyricsService Tests', () {
    test('parseLyrics correctly parses synchronized .lrc timestamped lines', () {
      const sampleLrc = '''
[ti:Skyfall]
[ar:Adele]
[00:32.24] This is the end
[00:37.11] Hold your breath and count to ten
[00:43.69] Feel the Earth move, and then
''';

      final lyrics = LyricsService.parseLyrics(sampleLrc);

      expect(lyrics.isSynced, isTrue);
      expect(lyrics.lines.length, equals(3));
      expect(lyrics.lines[0].text, equals('This is the end'));
      expect(lyrics.lines[0].timestamp.inSeconds, equals(32));
      expect(lyrics.lines[1].text, equals('Hold your breath and count to ten'));
      expect(lyrics.lines[1].timestamp.inSeconds, equals(37));
      expect(lyrics.lines[2].text, equals('Feel the Earth move, and then'));
    });

    test('parseLyrics handles plain text lyrics without timestamps', () {
      const plainLyrics = '''
First line of song
Second line of song
Third line of song
''';

      final lyrics = LyricsService.parseLyrics(plainLyrics);

      expect(lyrics.isSynced, isFalse);
      expect(lyrics.lines.length, equals(3));
      expect(lyrics.lines[0].text, equals('First line of song'));
    });

    test('Micro LRU Cache strictly caps at max 3 items', () {
      final service = LyricsService();
      service.clearMemory();

      expect(service.isCached('song_1'), isFalse);
    });
  });
}

