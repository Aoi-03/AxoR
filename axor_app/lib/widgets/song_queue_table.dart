import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../services/audio_player_service.dart';
import '../services/google_drive_service.dart';
import '../utils/mode_manager.dart';
import 'axor_image.dart';

class SongQueueTable extends StatelessWidget {
  final List<DriveAudioFile>? songs;
  final Color? accentColor;
  final String title;

  const SongQueueTable({
    super.key,
    this.songs,
    this.accentColor,
    this.title = '> Song Queue',
  });

  @override
  Widget build(BuildContext context) {
    final modeColor = accentColor ?? modeManager.getModeColor();
    final audioPlayer = context.watch<AudioPlayerService>();
    final queue = songs ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: modeColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              '${queue.length} Tracks',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: modeColor.withAlpha(25),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            border: Border.all(color: modeColor.withAlpha(40), width: 1),
          ),
          child: const Row(
            children: [
              SizedBox(width: 24, child: Text('#', style: TextStyle(color: AppColors.lightGray, fontSize: 12, fontWeight: FontWeight.bold))),
              SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text('Title', style: TextStyle(color: AppColors.lightGray, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 2,
                child: Text('Artist', style: TextStyle(color: AppColors.lightGray, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 48,
                child: Text('Time', textAlign: TextAlign.right, style: TextStyle(color: AppColors.lightGray, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // Song List
        Container(
          height: 320,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(80),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            border: Border(
              left: BorderSide(color: modeColor.withAlpha(40), width: 1),
              right: BorderSide(color: modeColor.withAlpha(40), width: 1),
              bottom: BorderSide(color: modeColor.withAlpha(40), width: 1),
            ),
          ),
          child: queue.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.playlist_play_rounded, color: modeColor.withAlpha(100), size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'No songs available in this mode queue',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final song = queue[index];
                    final isCurrent = audioPlayer.currentSong?.id == song.id;
                    final isPlaying = isCurrent && audioPlayer.isPlaying;

                    return InkWell(
                      onTap: () {
                        audioPlayer.playSong(
                          song,
                          playlist: queue,
                          index: index,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isCurrent ? modeColor.withAlpha(30) : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.darkGray.withAlpha(60),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Index or Playing Icon
                            SizedBox(
                              width: 24,
                              child: isPlaying
                                  ? Icon(Icons.graphic_eq_rounded, color: modeColor, size: 16)
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: isCurrent ? modeColor : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),

                            // Album Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: AxorImage(
                                imageUrl: song.coverUrl.isNotEmpty ? song.coverUrl : song.thumbnailLink,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Song Title
                            Expanded(
                              flex: 3,
                              child: Text(
                                song.displayTitle,
                                style: TextStyle(
                                  color: isCurrent ? modeColor : Colors.white,
                                  fontSize: 13,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Artist
                            Expanded(
                              flex: 2,
                              child: Text(
                                song.displayArtist,
                                style: const TextStyle(
                                  color: AppColors.lightGray,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Timeline
                            SizedBox(
                              width: 48,
                              child: Text(
                                song.formattedDuration,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: AppColors.lightGray,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
