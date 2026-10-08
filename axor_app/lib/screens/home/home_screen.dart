import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/text_styles.dart';
import '../../providers/music_provider.dart';
import '../../services/audio_player_service.dart';
import '../smart_modes/gym_mode_screen.dart';
import '../smart_modes/study_mode_screen.dart';
import '../smart_modes/drive_mode_screen.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/axor_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final musicProvider = context.read<MusicProvider>();
      if (musicProvider.allSongs.isEmpty && !musicProvider.isLoading) {
        musicProvider.loadSongs();
      }
    });
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: AppColors.primary, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('AXOR', style: AppTextStyles.titleLarge.copyWith(letterSpacing: 2)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Consumer<MusicProvider>(
            builder: (context, music, _) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${music.allSongs.length} Tracks',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer2<MusicProvider, AudioPlayerService>(
        builder: (context, music, audioPlayer, _) {
          final songs = music.allSongs;

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceCard,
            onRefresh: () => music.loadSongs(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                // Greeting Hero Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTimeGreeting(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Ready to Vibe?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                if (songs.isNotEmpty) {
                                  audioPlayer.setPlayMode(2); // Shuffle
                                  audioPlayer.playAxorSong(songs[0], playlist: songs, index: 0);
                                }
                              },
                              icon: const Icon(Icons.shuffle_rounded, size: 18),
                              label: const Text('Shuffle All'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                if (songs.isNotEmpty) {
                                  audioPlayer.setPlayMode(0);
                                  audioPlayer.playAxorSong(songs[0], playlist: songs, index: 0);
                                }
                              },
                              icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 20),
                              label: const Text('Play First', style: TextStyle(color: Colors.white)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.primary.withAlpha(80)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Smart Modes Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SMART MODES',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Activity Tuned',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Smart Modes Cards Row
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildModeCard(
                        context: context,
                        title: 'GYM MODE',
                        subtitle: 'High BPM Energy',
                        icon: Icons.fitness_center_rounded,
                        accentColor: AppColors.red,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GymModeScreen())),
                      ),
                      const SizedBox(width: 12),
                      _buildModeCard(
                        context: context,
                        title: 'STUDY MODE',
                        subtitle: 'Calm Focus Flow',
                        icon: Icons.menu_book_rounded,
                        accentColor: AppColors.cyan,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyModeScreen())),
                      ),
                      const SizedBox(width: 12),
                      _buildModeCard(
                        context: context,
                        title: 'DRIVE MODE',
                        subtitle: 'Cruising Vibes',
                        icon: Icons.directions_car_rounded,
                        accentColor: AppColors.green,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriveModeScreen())),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Featured / Liked Spotlight
                if (songs.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'YOUR SOUNDTRACK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          'Top Picks',
                          style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Horizontal Cards
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: songs.length > 15 ? 15 : songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        final isCurrent = audioPlayer.currentSong?.id == song.id;

                        return Container(
                          width: 130,
                          margin: const EdgeInsets.only(right: 14),
                          child: GestureDetector(
                            onTap: () => audioPlayer.playAxorSong(song, playlist: songs, index: index),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      width: 130,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isCurrent ? AppColors.primary : Colors.white.withAlpha(20),
                                          width: isCurrent ? 2 : 1,
                                        ),
                                      ),
                                      child: AxorImage(
                                        imageUrl: song.coverUrl,
                                        width: 130,
                                        height: 120,
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isCurrent ? AppColors.primary : Colors.black.withAlpha(180),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isCurrent && audioPlayer.isPlaying ? Icons.pause : Icons.play_arrow,
                                          color: isCurrent ? Colors.black : Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  song.title,
                                  style: TextStyle(
                                    color: isCurrent ? AppColors.primary : Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  song.artist,
                                  style: const TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Quick Access Song List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: const Text(
                      'RECENT TRACKS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Show first 8 songs directly on home
                  ...List.generate(
                    songs.length > 8 ? 8 : songs.length,
                    (index) {
                      final song = songs[index];
                      final isCurrentSong = audioPlayer.currentSong?.id == song.id;
                      final isPlaying = isCurrentSong && audioPlayer.isPlaying;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: SongTile(
                          index: index,
                          title: song.title,
                          artist: song.artist,
                          duration: song.formattedDuration,
                          albumArtUrl: song.coverUrl,
                          isCurrentSong: isCurrentSong,
                          isPlaying: isPlaying,
                          onTap: () {
                            audioPlayer.playAxorSong(song, playlist: songs, index: index);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withAlpha(70), width: 1),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withAlpha(35),
              AppColors.surfaceElevated,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: accentColor, size: 24),
                Icon(Icons.arrow_forward_ios_rounded, color: accentColor.withAlpha(120), size: 14),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
