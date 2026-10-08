import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/drive_provider.dart';
import '../../services/dynamic_island_service.dart';
import '../../services/audio_player_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/library_stats_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showPrivacyPolicyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.primary, width: 1.5)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AxoR Privacy Policy',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Offline-First & Google Drive Integration • Oct 2026',
                            style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.surfaceBorder, height: 24),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    _buildPolicySection(
                      icon: Icons.lock_outline_rounded,
                      title: '1. Zero Telemetry & Tracking',
                      body: 'AxoR is built with an offline-first architecture. We never collect, track, store, or sell any listening activity, audio files, search queries, or analytics to any third party.',
                    ),
                    _buildPolicySection(
                      icon: Icons.cloud_done_outlined,
                      title: '2. Google Drive Access',
                      body: 'When you link your Google Drive account, AxoR only accesses your audio files and the dedicated "AxoR Music" folder for streaming and favoriting songs. Google OAuth credentials remain secured directly within your local device sandbox.',
                    ),
                    _buildPolicySection(
                      icon: Icons.folder_shared_outlined,
                      title: '3. Local Offline Storage',
                      body: 'All downloaded music and cached album covers reside strictly on your device storage. You retain 100% control over these files and can delete them at any time.',
                    ),
                    _buildPolicySection(
                      icon: Icons.security_rounded,
                      title: '4. Android System Features',
                      body: 'Features like Lockscreen wallpaper sync, media notification controls, and Honor Magic Capsule interact exclusively through Android\'s native APIs (MediaSession & WallpaperManager) with zero background analytics.',
                    ),
                    _buildPolicySection(
                      icon: Icons.logout_rounded,
                      title: '5. Complete Revocation & Logout',
                      body: 'You may revoke cloud access at any time by tapping "Log Out Completely" below. This severs active OAuth tokens, deletes session caches, and disconnects Google Drive entirely.',
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('I Understand', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPolicySection({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Profile & Settings', style: AppTextStyles.titleLarge),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 120),
        children: [
          // Profile Banner with Account Labels (PRO / Standard / Free)
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
                      // Name and Account Label beside it (PRO / Standard / Free)
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              auth.userName ?? 'AXOR Explorer',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => auth.cycleAccountTier(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: auth.accountTierColor.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: auth.accountTierColor.withAlpha(140), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    auth.accountTier == 'PRO'
                                        ? Icons.star_rounded
                                        : (auth.accountTier == 'Standard'
                                            ? Icons.verified_user_rounded
                                            : Icons.person_outline_rounded),
                                    color: auth.accountTierColor,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    auth.accountTier,
                                    style: TextStyle(
                                      color: auth.accountTierColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        auth.userEmail ?? 'Personal Local Music Library',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
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

          const LibraryStatsCard(),

          const SizedBox(height: 24),

          // Display & Wallpaper Settings (Cleaned up: Magic Capsule, Media Island, Audio O/P Quality, and Background Stream Mode removed)
          const Text(
            'DISPLAY & WALLPAPER',
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
            child: ListTile(
              leading: const Icon(Icons.wallpaper_rounded, color: AppColors.secondary),
              title: const Text('Lockscreen Cover Wallpaper', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Sync lock screen wallpaper with playing song art', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              trailing: StatefulBuilder(
                builder: (context, setState) {
                  return Switch(
                    value: DynamicIslandService.syncLockscreenWallpaper,
                    activeThumbColor: AppColors.primary,
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
          ),

          const SizedBox(height: 24),

          // Actions & Account Management
          const Text(
            'ACTIONS & SECURITY',
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
                // Privacy Policy (Replaces Rescan Music folder option)
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.cyan),
                  title: const Text('Privacy Policy', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('View data protection & Google Drive privacy policy', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                  onTap: () => _showPrivacyPolicyModal(context),
                ),
                const Divider(color: AppColors.surfaceBorder, height: 1),

                // Connect Google Drive if signed out
                if (!auth.isSignedIn)
                  ListTile(
                    leading: const Icon(Icons.cloud_queue_rounded, color: AppColors.primary),
                    title: const Text('Connect Google Drive', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Stream additional songs from Google Drive', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                    onTap: () async {
                      await auth.signIn();
                    },
                  ),

                // Proper Complete Logout Functionality
                if (auth.isSignedIn)
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                    title: const Text('Log Out Completely', style: TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Disconnect ${auth.userEmail ?? 'account'} and revoke all sessions',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.error),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surfaceCard,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Log Out of AxoR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          content: const Text(
                            'Are you sure you want to log out completely? This will disconnect your Google Drive account, revoke OAuth session tokens, and clear active cloud caches.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Log Out Completely', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await auth.signOut();
                        if (context.mounted) {
                          context.read<DriveProvider>().clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Successfully logged out completely from AxoR'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                  )
                else
                  // Even when offline or not signed into Drive, provide complete session reset
                  ListTile(
                    leading: const Icon(Icons.power_settings_new_rounded, color: AppColors.error),
                    title: const Text('Log Out / Reset App Session', style: TextStyle(color: AppColors.error, fontSize: 14)),
                    subtitle: const Text('Reset local credentials and return to default guest state', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    onTap: () async {
                      await auth.signOut();
                      if (context.mounted) {
                        context.read<DriveProvider>().clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('App session reset to default')),
                        );
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
}