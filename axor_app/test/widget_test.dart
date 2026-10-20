import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:axor_app/widgets/axor_image.dart';
import 'package:axor_app/widgets/song_tile.dart';

void main() {
  testWidgets('AxorImage renders fallback placeholder when URL is empty', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AxorImage(
            imageUrl: '',
            width: 60,
            height: 60,
          ),
        ),
      ),
    );

    // Verify music note icon placeholder is displayed
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
  });

  testWidgets('SongTile renders title, artist, and duration correctly', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongTile(
            index: 0,
            title: 'Resonance',
            artist: 'HOME',
            duration: '03:32',
            albumArtUrl: '',
            isCurrentSong: false,
            isPlaying: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Resonance'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('03:32'), findsOneWidget);

    // Tap the tile
    await tester.tap(find.text('Resonance'));
    expect(tapped, isTrue);
  });
}
