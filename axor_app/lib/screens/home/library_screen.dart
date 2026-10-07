import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/text_styles.dart';
import '../../providers/drive_provider.dart';
import '../../providers/music_provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/download_service.dart';
import '../../widgets/song_tile.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedTab = 0; // 0: Local Liked Songs, 1: Google Drive
  String _filterQuery = '';

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

  @override
  Widget build(BuildContext context) {
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
          // Tab Toggle: Local Library vs Google Drive
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                          child: Consumer<MusicProvider>(
                            builder: (context, music, _) {
                              final count = music.allSongs.length;
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
                                    'Liked Songs${count > 0 ? ' ($count)' : ''}',
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
                      onTap: () => setState(() => _selectedTab = 1),
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

  // ── Tab 0: Local Liked Songs ──────────────────────────────────
  Widget _buildLocalLikedSongsTab() {
    return Consumer2<MusicProvider, AudioPlayerService>(
      builder: (context, music, audioPlayer, _) {
        if (music.isLoading && music.allSongs.isEmpty) {
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

        if (music.allSongs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_off_rounded, color: AppColors.textTertiary, size: 54),
                const SizedBox(height: 16),
                const Text(
                  'No songs found in your library',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Make sure your backend is running on port 3000',
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

        final displayedSongs = _filterQuery.isEmpty
            ? music.allSongs
            : music.allSongs.where((s) =>
                s.title.toLowerCase().contains(_filterQuery.toLowerCase()) ||
                s.artist.toLowerCase().contains(_filterQuery.toLowerCase())).toList();

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
                      hintText: 'Filter in ${music.allSongs.length} songs...',
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

              // Header bar: Shuffle Play & Count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Text(
                      '${displayedSongs.length} Tracks',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        if (displayedSongs.isNotEmpty) {
                          audioPlayer.setPlayMode(2); // Shuffle mode
                          audioPlayer.playAxorSong(
                            displayedSongs[0],
                            playlist: displayedSongs,
                            index: 0,
                          );
                        }
                      },
                      icon: const Icon(Icons.shuffle_rounded, color: AppColors.primary, size: 18),
                      label: const Text(
                        'Shuffle Play',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primary.withAlpha(25),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),

              // Song list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 100),
                  itemCount: displayedSongs.length,
                  itemBuilder: (context, index) {
                    final song = displayedSongs[index];
                    final isCurrentSong = audioPlayer.currentSong?.id == song.id;
                    final isPlaying = isCurrentSong && audioPlayer.isPlaying;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: SongTile(
                        index: index,
                        title: song.title,
                        artist: song.artist,
                        duration: song.formattedDuration,
                        albumArtUrl: song.coverUrl,
                        isCurrentSong: isCurrentSong,
                        isPlaying: isPlaying,
                        onTap: () {
                          audioPlayer.playAxorSong(
                            song,
                            playlist: displayedSongs,
                            index: index,
                          );
                        },
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.primary.withAlpha(30)),
                          ),
                          child: Text(
                            song.format,
                            style: const TextStyle(
                              color: AppColors.cyan,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceCard,
          onRefresh: () => drive.refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
            itemCount: drive.audioFiles.length,
            itemBuilder: (context, index) {
              final file = drive.audioFiles[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Consumer2<AudioPlayerService, DownloadService>(
                  builder: (context, audioPlayer, downloadService, _) {
                    final isCurrentSong = audioPlayer.currentSong?.id == file.id;
                    final isPlaying = isCurrentSong && audioPlayer.isPlaying;
                    final isDownloading = downloadService.isDownloading(file.id);

                    return SongTile(
                      index: index,
                      title: file.displayTitle,
                      artist: file.displayArtist,
                      duration: file.formattedDuration,
                      albumArtUrl: file.thumbnailLink,
                      isCurrentSong: isCurrentSong,
                      isPlaying: isPlaying,
                      onTap: () {
                        audioPlayer.playSong(
                          file,
                          playlist: drive.audioFiles,
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
        );
      },
    );
  }
}
