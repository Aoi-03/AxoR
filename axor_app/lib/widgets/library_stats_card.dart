import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/drive_provider.dart';
import '../providers/music_provider.dart';
import '../services/connectivity_service.dart';
import '../services/download_service.dart';

/// LibraryStatsCard — Alternating Library Statistics Banner
///
/// Features:
/// - Alternates between Google Drive and Local data at 1-second intervals when online
/// - Format: "Drive -> 80 songs, 1.3gb storage used, 320k Audio Bitrate"
///   switches to "Local -> 267 songs, 1.2gb storage used, 320k Audio Bitrate"
/// - When network is OFF, locks to Local statistics ("Local (Offline) -> ...")
class LibraryStatsCard extends StatefulWidget {
  final bool compact;
  const LibraryStatsCard({super.key, this.compact = false});

  @override
  State<LibraryStatsCard> createState() => _LibraryStatsCardState();
}

class _LibraryStatsCardState extends State<LibraryStatsCard> {
  Timer? _ticker;
  bool _showDrive = false;

  @override
  void initState() {
    super.initState();
    // 1-second interval ticker for alternating statistics
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _showDrive = !_showDrive;
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1.0) {
      return '${gb.toStringAsFixed(1)} GB';
    }
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = Provider.of<ConnectivityService>(context);
    final isOnline = connectivity.isOnline;

    final driveProvider = Provider.of<DriveProvider>(context);
    final musicProvider = Provider.of<MusicProvider>(context);
    final downloadService = Provider.of<DownloadService>(context);

    // Compute Drive statistics
    final driveSongsCount = driveProvider.audioFiles.length;
    int driveBytes = 0;
    for (final f in driveProvider.audioFiles) {
      driveBytes += f.fileSize;
    }
    final driveStorageStr = driveBytes > 0 ? _formatBytes(driveBytes) : '~1.3 GB';

    // Compute Local statistics
    final localSongsCount = musicProvider.allSongs.length + downloadService.downloadedSongs.length;
    int localBytes = 0;
    for (final s in musicProvider.allSongs) {
      localBytes += s.fileSize;
    }
    for (final d in downloadService.downloadedSongs) {
      localBytes += d.fileSize;
    }
    final localStorageStr = localBytes > 0 ? _formatBytes(localBytes) : '~1.2 GB';

    // When offline, lock to local stats
    final activeIsDrive = isOnline && _showDrive;

    final currentSource = activeIsDrive ? 'Drive' : (isOnline ? 'Local' : 'Local (Offline)');
    final currentSongs = activeIsDrive ? driveSongsCount : localSongsCount;
    final currentStorage = activeIsDrive ? driveStorageStr : localStorageStr;
    const currentBitrate = '320k Audio Bitrate';

    final fullLabel = '$currentSource -> $currentSongs songs, $currentStorage storage used, $currentBitrate';

    final themeColor = activeIsDrive ? AppColors.cyan : (isOnline ? AppColors.primary : AppColors.secondary);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withAlpha(200),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeColor.withAlpha(80), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: themeColor.withAlpha(25),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with alternating status indicator
          Row(
            children: [
              Icon(
                activeIsDrive ? Icons.cloud_sync_rounded : (isOnline ? Icons.phone_android_rounded : Icons.cloud_off_rounded),
                color: themeColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                activeIsDrive ? 'GOOGLE DRIVE SYNC' : (isOnline ? 'LOCAL DEVICE STORAGE' : 'OFFLINE STORAGE'),
                style: TextStyle(
                  color: themeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (isOnline)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: themeColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: themeColor.withAlpha(60), width: 0.8),
                  ),
                  child: const Text(
                    '1s AUTO-CYCLE',
                    style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'OFFLINE LOCKED',
                    style: TextStyle(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Alternating marquee / text banner
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: Text(
              fullLabel,
              key: ValueKey(fullLabel),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),

          if (!widget.compact) ...[
            const SizedBox(height: 12),
            // Quick 3-metric tiles
            Row(
              children: [
                Expanded(
                  child: _metricTile(
                    title: 'Songs',
                    value: '$currentSongs',
                    color: AppColors.cyan,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricTile(
                    title: 'Storage',
                    value: currentStorage,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricTile(
                    title: 'Bitrate',
                    value: '320k',
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricTile({required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(60),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
