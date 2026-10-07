import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../services/audio_player_service.dart';
import '../screens/player/full_player_screen.dart';

class MusicPlayerBottom extends StatelessWidget {
  const MusicPlayerBottom({super.key});

  IconData _getShuffleRepeatIcon(int state) {
    switch (state) {
      case 0: return Icons.repeat;
      case 1: return Icons.repeat_one;
      case 2: return Icons.shuffle;
      case 3: return Icons.auto_awesome;
      default: return Icons.repeat;
    }
  }

  Color _getShuffleRepeatColor(int state) {
    if (state == 0) return AppColors.textTertiary;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, audioPlayer, child) {
        final currentSong = audioPlayer.currentSong;
        if (currentSong == null) return const SizedBox.shrink(); // Hide if nothing is playing

        final isPlaying = audioPlayer.isPlaying;
        
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FullPlayerScreen()),
            );
          },
          child: Container(
            height: 70,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withAlpha(240),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withAlpha(50), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ]
            ),
            child: Row(
              children: [
                // Album Art
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (currentSong.coverUrl.isNotEmpty) 
                        ? Image.network(
                            currentSong.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.music_note,
                              color: AppColors.textTertiary,
                              size: 24,
                            ),
                          )
                        : const Icon(Icons.music_note, color: AppColors.textTertiary, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Song Title & Artist
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentSong.displayTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentSong.displayArtist,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 4),
                
                // Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cycle Play Mode (Shuffle/Repeat/AI)
                    IconButton(
                      icon: Icon(
                        _getShuffleRepeatIcon(audioPlayer.playMode),
                        color: _getShuffleRepeatColor(audioPlayer.playMode),
                        size: 20,
                      ),
                      onPressed: () => audioPlayer.cyclePlayMode(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    const SizedBox(width: 4),
                    // Play/Pause
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => audioPlayer.togglePlayPause(),
                        icon: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Next
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        onPressed: () => audioPlayer.playNext(),
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
