import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/text_styles.dart';
import '../../providers/drive_provider.dart';
import '../../providers/music_provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/download_service.dart';
import '../../services/google_drive_service.dart';
import '../../widgets/library_stats_card.dart';
import '../../widgets/song_tile.dart';

enum ArrangeOrder {
  titleAsc,
  titleDesc,
  artistAsc,
  durationDesc,
  durationAsc,
  recent,
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedTab = 0; // 0: Local Liked Songs, 1: Google Drive
  String _filterQuery = '';
  ArrangeOrder _arrangeOrder = ArrangeOrder.titleAsc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final musicProvider = context.read<MusicProvider>();
      if (musicProvider.allSongs.isEmpty && !musicProvider.isLoading) {
        musicProvider.loadSongs();
      }

      final driveProvider = context.read<DriveProvider>();
      if (driveProvider.audioFiles.isEmpty && !driveProvider.isLoadingFiles) {
        driveProvider.loadAudioFiles();
      }
    });
  }

  String _getArrangeLabel(ArrangeOrder order) {
    switch (order) {
      case ArrangeOrder.titleAsc:
        return 'Title (A - Z)';
      case ArrangeOrder.titleDesc:
        return 'Title (Z - A)';
      case ArrangeOrder.artistAsc:
        return 'Artist (A - Z)';
      case ArrangeOrder.durationDesc:
        return 'Duration (Longest)';
      case ArrangeOrder.durationAsc:
        return 'Duration (Shortest)';
      case ArrangeOrder.recent:
        return 'Recently Added';
    }
  }

  List<DriveAudioFile> _sortDriveFiles(List<DriveAudioFile> files) {
    final list = List<DriveAudioFile>.from(files);
    switch (_arrangeOrder) {
      case ArrangeOrder.titleAsc:
        list.sort((a, b) => a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()));
        break;
      case ArrangeOrder.titleDesc:
        list.sort((a, b) => b.displayTitle.toLowerCase().compareTo(a.displayTitle.toLowerCase()));
        break;
      case ArrangeOrder.artistAsc:
        list.sort((a, b) => a.displayArtist.toLowerCase().compareTo(b.displayArtist.toLowerCase()));
        break;
      case ArrangeOrder.durationDesc:
        list.sort((a, b) => (b.durationSeconds ?? 0).compareTo(a.durationSeconds ?? 0));
        break;
      case ArrangeOrder.durationAsc:
        list.sort((a, b) => (a.durationSeconds ?? 0).compareTo(b.durationSeconds ?? 0));
        break;
      case ArrangeOrder.recent:
        if (list.isNotEmpty && list.first.modifiedTime != null) {
          list.sort((a, b) {
            final ma = a.modifiedTime ?? DateTime(1970);
            final mb = b.modifiedTime ?? DateTime(1970);
            return mb.compareTo(ma);
          });
        }
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = Provider.of<ConnectivityService>(context);
    final isOnline = connectivity.isOnline;

    // Offline Fallback: If disconnected and on Google Drive tab, auto-switch to Local tab
    if (!isOnline && _selectedTab == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedTab = 0);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline mode: Automatically defaulted to Local library'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Your Library', style: AppTextStyles.titleLarge),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Rescan / Refresh',
            onPressed: () {
              if (_selectedTab == 0) {
                context.read<MusicProvider>().rescanLibrary();
              } else {
                context.read<DriveProvider>().refresh();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Alternating Library Statistics Banner (1-second cycle when online, local when offline)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: LibraryStatsCard(compact: true),
          ),

          // Offline Notice Banner
          if (!isOnline)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: AppColors.secondary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.secondary.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: AppColors.secondary, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Offline Mode Active — Defaulting to Local & Downloaded Tracks',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('OFFLINE', style: TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Tab Toggle: Local Library vs Google Drive
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withAlpha(40), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? AppColors.primary.withAlpha(50)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Center(
                          child: Consumer2<MusicProvider, DownloadService>(
                            builder: (context, music, download, _) {
                              final count = music.allSongs.length + download.downloadedSongs.length;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.favorite_rounded,
                                    size: 16,
                                    color: _selectedTab == 0 ? AppColors.primary : AppColors.textTertiary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Local & Liked${count > 0 ? ' ($count)' : ''}',
                                    style: TextStyle(
                                      color: _selectedTab == 0 ? Colors.white : AppColors.textTertiary,
                                      fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!isOnline) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cannot access Google Drive while offline. Playing local library.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          setState(() => _selectedTab = 0);
                        } else {
                          setState(() => _selectedTab = 1);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? AppColors.primary.withAlpha(50)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Center(
                          child: Consumer<DriveProvider>(
                            builder: (context, drive, _) {
                              final count = drive.audioFiles.length;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_rounded,
                                    size: 16,
                                    color: _selectedTab == 1 ? AppColors.primary : AppColors.textTertiary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Google Drive${count > 0 ? ' ($count)' : ''}',
                                    style: TextStyle(
                                      color: _selectedTab == 1 ? Colors.white : AppColors.textTertiary,
                                      fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (!isOnline)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4.0),
                                      child: Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textTertiary),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content based on tab
          Expanded(
            child: _selectedTab == 0
                ? _buildLocalLikedSongsTab()
                : _buildGoogleDriveTab(),
          ),
        ],
      ),
    );
  }

  // ── Tab 0: Local Liked & Downloaded Songs ─────────────────────────
  Widget _buildLocalLikedSongsTab() {
    return Consumer3<MusicProvider, AudioPlayerService, DownloadService>(
      builder: (context, music, audioPlayer, downloadService, _) {
        if (music.isLoading && music.allSongs.isEmpty && downloadService.downloadedSongs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text('Loading songs from library...', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        // Build unified local track list: Downloaded songs + Backend songs
        final List<DriveAudioFile> allLocalFiles = [];
        final Set<String> seenIds = {};

        // Downloaded files first (100% available offline)
        for (final d in downloadService.downloadedSongs) {
          if (seenIds.add(d.id)) {
            allLocalFiles.add(d);
          }
        }

        // Backend songs
        for (final s in music.allSongs) {
          if (seenIds.add(s.id)) {
            allLocalFiles.add(DriveAudioFile.fromSong(s));
          }
        }

        if (allLocalFiles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_off_rounded, color: AppColors.textTertiary, size: 54),
                const SizedBox(height: 16),
                const Text(
                  'No local or downloaded songs found',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect to Google Drive or download tracks to play offline',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rescan Library'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => music.rescanLibrary(),
                ),
              ],
            ),
          );
        }

        // Filter
        var filtered = _filterQuery.isEmpty
            ? allLocalFiles
            : allLocalFiles.where((s) =>
                s.displayTitle.toLowerCase().contains(_filterQuery.toLowerCase()) ||
                s.displayArtist.toLowerCase().contains(_filterQuery.toLowerCase())).toList();

        // Arrange Order
        final displayedFiles = _sortDriveFiles(filtered);

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceCard,
          onRefresh: () => music.loadSongs(),
          child: Column(
            children: [
              // Quick Filter Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withAlpha(40)),
                  ),
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: (val) => setState(() => _filterQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Filter in ${allLocalFiles.length} local tracks...',
                      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.primary),
                      suffixIcon: _filterQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                              onPressed: () => setState(() => _filterQuery = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),

              // Header bar: Arrange Order + Shuffle Play
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Row(
                  children: [
                    // Arrange Order Selector
                    PopupMenuButton<ArrangeOrder>(
                      initialValue: _arrangeOrder,
                      onSelected: (order) => setState(() => _arrangeOrder = order),
                      color: AppColors.surfaceElevated,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withAlpha(80), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort_rounded, color: AppColors.primary, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              _getArrangeLabel(_arrangeOrder),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 16),
                          ],
                        ),
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: ArrangeOrder.titleAsc, child: Text('Title (A - Z)')),
                        const PopupMenuItem(value: ArrangeOrder.titleDesc, child: Text('Title (Z - A)')),
                        const PopupMenuItem(value: ArrangeOrder.artistAsc, child: Text('Artist (A - Z)')),
                        const PopupMenuItem(value: ArrangeOrder.durationDesc, child: Text('Duration (Longest)')),
                        const PopupMenuItem(value: ArrangeOrder.durationAsc, child: Text('Duration (Shortest)')),
                        const PopupMenuItem(value: ArrangeOrder.recent, child: Text('Recently Added')),
                      ],
                    ),
                    const Spacer(),
                    // Shuffle Play
                    TextButton.icon(
                      onPressed: () {
                        if (displayedFiles.isNotEmpty) {
                          audioPlayer.setPlayMode(2); // Shuffle mode
                          audioPlayer.playSong(
                            displayedFiles[0],
                            playlist: displayedFiles,
                            index: 0,
                          );
                        }
                      },
                      icon: const Icon(Icons.shuffle_rounded, color: AppColors.primary, size: 16),
                      label: const Text(
                        'Shuffle',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primary.withAlpha(25),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),

              // Song list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 100),
                  itemCount: displayedFiles.length,
                  itemBuilder: (context, index) {
                    final file = displayedFiles[index];
                    final isCurrentSong = audioPlayer.currentSong?.id == file.id;
                    final isPlaying = isCurrentSong && audioPlayer.isPlaying;
                    final isLocalDownloaded = downloadService.isDownloaded(file.id);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: SongTile(
                        index: index,
                        title: file.displayTitle,
                        artist: file.displayArtist,
                        duration: file.formattedDuration,
                        albumArtUrl: file.coverUrl.isNotEmpty ? file.coverUrl : file.thumbnailLink,
                        isCurrentSong: isCurrentSong,
                        isPlaying: isPlaying,
                        onTap: () {
                          audioPlayer.playSong(
                            file,
                            playlist: displayedFiles,
                            index: index,
                          );
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isLocalDownloaded)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withAlpha(20),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.green.withAlpha(60)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.download_done_rounded, color: AppColors.green, size: 12),
                                    SizedBox(width: 4),
                                    Text('LOCAL', style: TextStyle(color: AppColors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.primary.withAlpha(30)),
                                ),
                                child: const Text(
                                  '320k',
                                  style: TextStyle(
                                    color: AppColors.cyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
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
          ),
        );
      },
    );
  }

  // ── Tab 1: Google Drive ──────────────────────────────────────
  Widget _buildGoogleDriveTab() {
    return Consumer<DriveProvider>(
      builder: (context, drive, child) {
        if (drive.isLoadingFiles) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (drive.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  drive.errorMessage!,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => drive.refresh(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }

        if (drive.audioFiles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, color: AppColors.textTertiary, size: 48),
                const SizedBox(height: 16),
                Text(
                  'No audio files found in your Drive',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          );
        }

        final sortedDriveFiles = _sortDriveFiles(drive.audioFiles);

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceCard,
          onRefresh: () => drive.refresh(),
          child: Column(
            children: [
              // Header bar: Arrange Order for Drive
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Row(
                  children: [
                    PopupMenuButton<ArrangeOrder>(
                      initialValue: _arrangeOrder,
                      onSelected: (order) => setState(() => _arrangeOrder = order),
                      color: AppColors.surfaceElevated,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withAlpha(80), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort_rounded, color: AppColors.primary, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              _getArrangeLabel(_arrangeOrder),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 16),
                          ],
                        ),
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: ArrangeOrder.titleAsc, child: Text('Title (A - Z)')),
                        const PopupMenuItem(value: ArrangeOrder.titleDesc, child: Text('Title (Z - A)')),
                        const PopupMenuItem(value: ArrangeOrder.artistAsc, child: Text('Artist (A - Z)')),
                        const PopupMenuItem(value: ArrangeOrder.durationDesc, child: Text('Duration (Longest)')),
                        const PopupMenuItem(value: ArrangeOrder.durationAsc, child: Text('Duration (Shortest)')),
                        const PopupMenuItem(value: ArrangeOrder.recent, child: Text('Recently Added')),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '${sortedDriveFiles.length} Tracks',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Drive files list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 100),
                  itemCount: sortedDriveFiles.length,
                  itemBuilder: (context, index) {
                    final file = sortedDriveFiles[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Consumer2<AudioPlayerService, DownloadService>(
                        builder: (context, audioPlayer, downloadService, _) {
                          final isCurrentSong = audioPlayer.currentSong?.id == file.id;
                          final isPlaying = isCurrentSong && audioPlayer.isPlaying;
                          final isDownloading = downloadService.isDownloading(file.id);
                          final isDownloaded = downloadService.isDownloaded(file.id);

                          return SongTile(
                            index: index,
                            title: file.displayTitle,
                            artist: file.displayArtist,
                            duration: file.formattedDuration,
                            albumArtUrl: file.coverUrl.isNotEmpty ? file.coverUrl : file.thumbnailLink,
                            isCurrentSong: isCurrentSong,
                            isPlaying: isPlaying,
                            onTap: () {
                              audioPlayer.playSong(
                                file,
                                playlist: sortedDriveFiles,
                                index: index,
                              );
                            },
                            trailing: isDownloading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : isDownloaded
                                    ? Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.green.withAlpha(20),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.download_done_rounded, color: AppColors.green, size: 18),
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.download_rounded, color: AppColors.primary),
                                        onPressed: () async {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Downloading ${file.displayTitle}...')),
                                          );
                                          await downloadService.downloadSong(file);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Downloaded ${file.displayTitle}')),
                                            );
                                          }
                                        },
                                      ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
