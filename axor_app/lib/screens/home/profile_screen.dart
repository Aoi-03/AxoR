import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/music_provider.dart';
import '../../services/dynamic_island_service.dart';
import '../../services/audio_player_service.dart';
import '../../widgets/glass_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final music = context.watch<MusicProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Profile & Audio', style: AppTextStyles.titleLarge),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 120),
        children: [
          // Profile Banner
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(50),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: auth.userPhotoUrl != null
                        ? Image.network(auth.userPhotoUrl!, fit: BoxFit.cover)
                        : Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.userName ?? 'AXOR Explorer',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        auth.userEmail ?? 'Personal Local Music Library',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'PREMIUM HD ENGINE',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Library Stats Section
          const Text(
            'LIBRARY STATISTICS',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  icon: Icons.music_note_rounded,
                  value: '${music.allSongs.length}',
                  label: 'Total Songs',
                  color: AppColors.cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  icon: Icons.storage_rounded,
                  value: '~1.3 GB',
                  label: 'Storage Used',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  icon: Icons.speed_rounded,
                  value: '320k',
                  label: 'Audio Bitrate',
                  color: AppColors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Audio Engine Settings
          const Text(
            'AUDIO & ENGINE',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),

          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.graphic_eq_rounded, color: AppColors.primary),
                  title: const Text('Audio Output Quality', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('High Resolution 48kHz / 320kbps MP3', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  trailing: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                ),
                const Divider(color: AppColors.surfaceBorder, height: 1),
                ListTile(
                  leading: const Icon(Icons.wifi_tethering_rounded, color: AppColors.primary),
                  title: const Text('Backend Streaming Mode', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Fast Local Node.js Streaming (Port 3000)', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  trailing: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const Divider(color: AppColors.surfaceBorder, height: 1),
                ListTile(
                  leading: const Icon(Icons.blur_circular_rounded, color: AppColors.cyan),
                  title: const Text('Magic Capsule & Media Island', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Honor Magic Capsule, Lock Screen & AOD controls', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withAlpha(25),
                      border: Border.all(color: AppColors.cyan.withAlpha(120)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('NATIVE ACTIVE', style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ),
                const Divider(color: AppColors.surfaceBorder, height: 1),
                ListTile(
                  leading: const Icon(Icons.wallpaper_rounded, color: AppColors.secondary),
                  title: const Text('Lockscreen Cover Wallpaper', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Sync lock screen wallpaper with playing song art', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  trailing: StatefulBuilder(
                    builder: (context, setState) {
                      return Switch(
                        value: DynamicIslandService.syncLockscreenWallpaper,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() {
                            DynamicIslandService.setSyncLockscreenWallpaper(val);
                          });
                          final song = AudioPlayerService().currentSong;
                          if (val && song != null && song.coverArtUrl != null) {
                            DynamicIslandService.setLockscreenWallpaper(song.coverArtUrl!);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Actions
          const Text(
            'ACTIONS',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),

          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync_rounded, color: AppColors.cyan),
                  title: const Text('Rescan Music Folder', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Rescan D:\\Downloads\\Liked_Songs for new files', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  trailing: music.isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rescanning music library...')),
                    );
                    await music.rescanLibrary();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Scan complete: ${music.allSongs.length} songs ready')),
                      );
                    }
                  },
                ),
                const Divider(color: AppColors.surfaceBorder, height: 1),
                ListTile(
                  leading: Icon(
                    auth.isSignedIn ? Icons.logout_rounded : Icons.cloud_queue_rounded,
                    color: auth.isSignedIn ? AppColors.error : AppColors.primary,
                  ),
                  title: Text(
                    auth.isSignedIn ? 'Sign Out of Google Drive' : 'Connect Google Drive',
                    style: TextStyle(
                      color: auth.isSignedIn ? AppColors.error : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    auth.isSignedIn ? auth.userEmail ?? '' : 'Stream additional songs from Google Drive',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                  onTap: () async {
                    if (auth.isSignedIn) {
                      await auth.signOut();
                    } else {
                      await auth.signIn();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(40), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}