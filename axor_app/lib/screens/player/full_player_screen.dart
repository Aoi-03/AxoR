import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../services/audio_player_service.dart';
import '../../widgets/axor_image.dart';

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Consumer<AudioPlayerService>(
        builder: (context, audioPlayer, child) {
          final currentSong = audioPlayer.currentSong;
          final isPlaying = audioPlayer.isPlaying;
          final position = audioPlayer.position;
          final duration = audioPlayer.duration;

          return SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Top Bar
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: const Text(
                                  'PLAYING FROM YOUR LIBRARY',
                                  style: TextStyle(
                                    color: AppColors.lightGray,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 48), // Balance the back button
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Album Art
                      AxorImage(
                        imageUrl: currentSong?.coverUrl,
                        width: MediaQuery.of(context).size.width * 0.85,
                        height: MediaQuery.of(context).size.width * 0.85,
                        borderRadius: BorderRadius.circular(16),
                      ),

                      const SizedBox(height: 30),

                      // Song Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          currentSong?.title ?? 'No song playing',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Progress Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppColors.cyan,
                                inactiveTrackColor: AppColors.darkGray,
                                thumbColor: Colors.white,
                                overlayColor: AppColors.cyan.withValues(alpha: 0.2),
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                trackHeight: 3,
                              ),
                              child: Slider(
                                value: duration.inSeconds > 0
                                    ? position.inSeconds.toDouble()
                                    : 0,
                                max: duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1,
                                onChanged: (value) {
                                  audioPlayer.seek(Duration(seconds: value.toInt()));
                                },
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: const TextStyle(
                                    color: AppColors.lightGray,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: const TextStyle(
                                    color: AppColors.lightGray,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Controls
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Like button (left of prev) — saves/removes song from Drive & Favorites
                            IconButton(
                              onPressed: currentSong != null
                                  ? () async {
                                      final isNowLiked = await audioPlayer.toggleLikeCurrentSong();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isNowLiked
                                                  ? 'Saved "${currentSong.displayTitle}" to Drive Favorites'
                                                  : 'Removed "${currentSong.displayTitle}" from Drive Favorites',
                                            ),
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                              icon: Icon(
                                audioPlayer.isCurrentSongLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: audioPlayer.isCurrentSongLiked
                                    ? const Color(0xFFFF3B30)
                                    : AppColors.lightGray,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Previous button
                            IconButton(
                              onPressed: currentSong != null
                                  ? () => audioPlayer.playPrevious()
                                  : null,
                              icon: Icon(
                                Icons.skip_previous,
                                color: currentSong != null
                                    ? Colors.white
                                    : AppColors.darkGray,
                                size: 38,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Play/Pause button
                            Container(
                              width: 68,
                              height: 68,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: currentSong != null
                                    ? () => audioPlayer.togglePlayPause()
                                    : null,
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.black,
                                  size: 38,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Next button
                            IconButton(
                              onPressed: currentSong != null
                                  ? () => audioPlayer.playNext()
                                  : null,
                              icon: Icon(
                                Icons.skip_next,
                                color: currentSong != null
                                    ? Colors.white
                                    : AppColors.darkGray,
                                size: 38,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Shuffle/Repeat/AI cycle button (right of next)
                            IconButton(
                              onPressed: () {
                                // Cycle through states: 0 (repeat) -> 1 (repeat one) -> 2 (shuffle) -> 3 (AI) -> 0
                                final newState = (audioPlayer.shuffleRepeatState + 1) % 4;
                                audioPlayer.setShuffleRepeatState(newState);
                              },
                              icon: Icon(
                                _getShuffleRepeatIcon(audioPlayer.shuffleRepeatState),
                                color: audioPlayer.shuffleRepeatState == 0 
                                    ? AppColors.lightGray 
                                    : AppColors.cyan,
                                size: 26,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  IconData _getShuffleRepeatIcon(int state) {
    switch (state) {
      case 0:
        return Icons.repeat; // Repeat playlist
      case 1:
        return Icons.repeat_one; // Repeat one song
      case 2:
        return Icons.shuffle; // Shuffle
      case 3:
        return Icons.auto_awesome; // AI mode (sparkle icon)
      default:
        return Icons.repeat;
    }
  }
}
