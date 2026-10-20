import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../services/audio_player_service.dart';
import '../screens/player/full_player_screen.dart';
import 'axor_image.dart';

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
        final isLocal = currentSong.customStreamUrl != null &&
            File(currentSong.customStreamUrl!).existsSync();

        return Dismissible(
          key: ValueKey('mini_player_${currentSong.id}'),
          direction: DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              audioPlayer.playNext();
            } else {
              audioPlayer.playPrevious();
            }
            return false; // Don't dismiss widget, just trigger track change
          },
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FullPlayerScreen()),
              );
            },
            child: Container(
              height: 72,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated.withAlpha(245),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withAlpha(50), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(80),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  children: [
                    // Top Progress Bar
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: StreamBuilder<Duration>(
                        stream: audioPlayer.positionStream,
                        builder: (context, snapshot) {
                          final pos = snapshot.data ?? audioPlayer.position;
                          final dur = audioPlayer.duration;
                          final fraction = (dur.inMilliseconds > 0)
                              ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                              : 0.0;

                          return LinearProgressIndicator(
                            value: fraction,
                            minHeight: 2.0,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          );
                        },
                      ),
                    ),

                    // Controls & Info Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          // Album Art with subtle glow
                          AxorImage(
                            imageUrl: currentSong.coverUrl,
                            width: 50,
                            height: 50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          const SizedBox(width: 12),

                          // Song Title & Artist + Local Badge
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isLocal)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4.0),
                                        child: Icon(
                                          Icons.offline_pin_rounded,
                                          size: 13,
                                          color: AppColors.cyan.withAlpha(200),
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        currentSong.displayTitle,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentSong.displayArtist,
                                  style: const TextStyle(
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

                          // Controls: Mode / Like / Play-Pause / Next
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Like Button
                              IconButton(
                                icon: Icon(
                                  audioPlayer.isCurrentSongLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: audioPlayer.isCurrentSongLiked
                                      ? AppColors.primary
                                      : AppColors.textTertiary,
                                  size: 18,
                                ),
                                onPressed: () => audioPlayer.toggleLikeCurrentSong(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                              ),

                              // Play Mode
                              IconButton(
                                icon: Icon(
                                  _getShuffleRepeatIcon(audioPlayer.playMode),
                                  color: _getShuffleRepeatColor(audioPlayer.playMode),
                                  size: 18,
                                ),
                                onPressed: () => audioPlayer.cyclePlayMode(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                              ),
                              const SizedBox(width: 4),

                              // Play / Pause Button
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: () => audioPlayer.togglePlayPause(),
                                  icon: Icon(
                                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 22,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              const SizedBox(width: 2),

                              // Next Button
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  onPressed: () => audioPlayer.playNext(),
                                  icon: const Icon(
                                    Icons.skip_next_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
