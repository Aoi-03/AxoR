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
import '../../widgets/song_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'High Energy', 'Calm', 'Fast BPM (>120)', 'Rock / EDM'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Bigram Dice coefficient for word-to-word similarity
  static double _diceSimilarity(String s1, String s2) {
    if (s1.length < 2 || s2.length < 2) {
      return s1 == s2 ? 1.0 : 0.0;
    }
    final s1Bigrams = <String>{};
    for (int i = 0; i < s1.length - 1; i++) {
      s1Bigrams.add(s1.substring(i, i + 2));
    }
    int matches = 0;
    for (int i = 0; i < s2.length - 1; i++) {
      if (s1Bigrams.contains(s2.substring(i, i + 2))) {
        matches++;
      }
    }
    return (2.0 * matches) / ((s1.length - 1) + (s2.length - 1));
  }

  /// Word-to-word similarity algorithm
  /// Compares each word in the query against words in the song title and artist
  static double _calculateSimilarity(String query, String targetText) {
    final q = query.trim().toLowerCase();
    final t = targetText.trim().toLowerCase();
    if (q.isEmpty || t.isEmpty) return 0.0;
    if (t == q) return 1.0;
    if (t.contains(q)) return 0.85;

    final queryWords = q.split(RegExp(r'[\s\-_.,/]+')).where((w) => w.isNotEmpty).toList();
    final textWords = t.split(RegExp(r'[\s\-_.,/]+')).where((w) => w.isNotEmpty).toList();

    if (queryWords.isEmpty || textWords.isEmpty) return 0.0;

    double totalScore = 0.0;
    for (final qWord in queryWords) {
      double bestWordScore = 0.0;
      for (final tWord in textWords) {
        if (tWord == qWord) {
          bestWordScore = 1.0;
          break;
        } else if (tWord.startsWith(qWord) || qWord.startsWith(tWord)) {
          final maxLen = tWord.length > qWord.length ? tWord.length : qWord.length;
          final score = 0.8 * (qWord.length / maxLen);
          if (score > bestWordScore) bestWordScore = score;
        } else if (tWord.contains(qWord)) {
          final score = 0.7 * (qWord.length / tWord.length);
          if (score > bestWordScore) bestWordScore = score;
        } else {
          final dice = _diceSimilarity(qWord, tWord);
          if (dice > 0.55 && dice > bestWordScore) {
            bestWordScore = dice * 0.75;
          }
        }
      }
      totalScore += bestWordScore;
    }

    return totalScore / queryWords.length;
  }

  List<DriveAudioFile> _searchAndRank({
    required String query,
    required bool isOnline,
    required List<DriveAudioFile> driveFiles,
    required List<DriveAudioFile> localFiles,
  }) {
    // 1. Gather candidates based on network status
    final List<DriveAudioFile> candidates = [];
    final Set<String> seenIds = {};

    if (isOnline) {
      // Online: Search both Google Drive (primary) and local library
      for (final file in driveFiles) {
        if (seenIds.add(file.id)) candidates.add(file);
      }
      for (final file in localFiles) {
        if (seenIds.add(file.id)) candidates.add(file);
      }
    } else {
      // Offline: ONLY search local songs
      for (final file in localFiles) {
        if (seenIds.add(file.id)) candidates.add(file);
      }
    }

    // 2. If no query, apply category chip filter only
    if (query.trim().isEmpty) {
      return _applyCategoryFilter(candidates);
    }

    // 3. Score candidates with word-to-word similarity
    final scoredList = <MapEntry<DriveAudioFile, double>>[];
    for (final file in candidates) {
      final combinedText = '${file.displayTitle} ${file.displayArtist} ${file.album ?? ''}';
      final score = _calculateSimilarity(query, combinedText);

      // Keep if score meets threshold or substring match
      if (score >= 0.25 || combinedText.toLowerCase().contains(query.trim().toLowerCase())) {
        scoredList.add(MapEntry(file, score));
      }
    }

    // 4. Rank descending by similarity score
    scoredList.sort((a, b) => b.value.compareTo(a.value));

    final results = scoredList.map((e) => e.key).toList();
    return _applyCategoryFilter(results);
  }

  List<DriveAudioFile> _applyCategoryFilter(List<DriveAudioFile> files) {
    switch (_selectedFilter) {
      case 'High Energy':
        return files.where((s) => (s.energy ?? 0.0) >= 0.7).toList();
      case 'Calm':
        return files.where((s) => (s.energy ?? 0.0) <= 0.45).toList();
      case 'Fast BPM (>120)':
        return files.where((s) => (s.bpm ?? 0) >= 120).toList();
      case 'Rock / EDM':
        return files.where((s) {
          final g = (s.genre ?? '').toLowerCase();
          return g.contains('rock') || g.contains('edm') || g.contains('electronic') || g.contains('metal');
        }).toList();
      case 'All':
      default:
        return files;
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = Provider.of<ConnectivityService>(context);
    final isOnline = connectivity.isOnline;

    final driveProvider = Provider.of<DriveProvider>(context);
    final musicProvider = Provider.of<MusicProvider>(context);
    final downloadService = Provider.of<DownloadService>(context);

    // Build unified local list
    final List<DriveAudioFile> localFiles = [];
    final Set<String> localIds = {};
    for (final d in downloadService.downloadedSongs) {
      if (localIds.add(d.id)) localFiles.add(d);
    }
    for (final s in musicProvider.allSongs) {
      if (localIds.add(s.id)) localFiles.add(DriveAudioFile.fromSong(s));
    }

    final results = _searchAndRank(
      query: _searchController.text,
      isOnline: isOnline,
      driveFiles: driveProvider.audioFiles,
      localFiles: localFiles,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Search', style: AppTextStyles.titleLarge),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<AudioPlayerService>(
        builder: (context, audioPlayer, _) {
          return Column(
            children: [
              // Online / Offline Status Chip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                child: Row(
                  children: [
                    Icon(
                      isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      size: 14,
                      color: isOnline ? AppColors.cyan : AppColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline
                          ? 'Online: Searching Google Drive & Local Library (Word Match)'
                          : 'Offline: Searching Local Library Only',
                      style: TextStyle(
                        color: isOnline ? AppColors.cyan : AppColors.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Search Input Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withAlpha(60), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(20),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: isOnline
                          ? 'Search songs, Drive files, artists, words...'
                          : 'Search local & downloaded songs...',
                      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),

              // Filter Chips
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(filter),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: AppColors.surfaceElevated,
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.black,
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onSelected: (val) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 6),

              // Results Count Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    Text(
                      '${results.length} Matches Found',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    ),
                    const Spacer(),
                    if (_searchController.text.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Similarity Ranked',
                          style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),

              // Results List
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off_rounded, color: AppColors.textTertiary, size: 50),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No songs in this filter'
                                  : 'No songs found for "${_searchController.text}"',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                            ),
                            if (!isOnline)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Connect to internet to search Google Drive',
                                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 100),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final song = results[index];
                          final isCurrentSong = audioPlayer.currentSong?.id == song.id;
                          final isPlaying = isCurrentSong && audioPlayer.isPlaying;
                          final isDownloaded = downloadService.isDownloaded(song.id);
                          final isDownloading = downloadService.isDownloading(song.id);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: SongTile(
                              index: index,
                              title: song.displayTitle,
                              artist: song.displayArtist,
                              duration: song.formattedDuration,
                              albumArtUrl: song.coverUrl.isNotEmpty ? song.coverUrl : song.thumbnailLink,
                              isCurrentSong: isCurrentSong,
                              isPlaying: isPlaying,
                              onTap: () {
                                audioPlayer.playSong(
                                  song,
                                  playlist: results,
                                  index: index,
                                );
                              },
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isDownloading)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else if (isDownloaded)
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.green.withAlpha(20),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.download_done_rounded, color: AppColors.green, size: 16),
                                    )
                                  else
                                    IconButton(
                                      icon: const Icon(Icons.download_rounded, color: AppColors.primary, size: 20),
                                      tooltip: 'Download Song',
                                      onPressed: () async {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Downloading ${song.displayTitle}...')),
                                        );
                                        await downloadService.downloadSong(song);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Downloaded ${song.displayTitle}')),
                                          );
                                        }
                                      },
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
        },
      ),
    );
  }
}
