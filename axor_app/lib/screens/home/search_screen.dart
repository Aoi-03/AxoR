import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/text_styles.dart';
import '../../models/song.dart';
import '../../providers/music_provider.dart';
import '../../services/audio_player_service.dart';
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

  List<Song> _filterSongs(List<Song> allSongs, String query) {
    var filtered = allSongs;

    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      filtered = filtered.where((s) =>
          s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q) ||
          s.genre.toLowerCase().contains(q)).toList();
    }

    switch (_selectedFilter) {
      case 'High Energy':
        return filtered.where((s) => s.energy >= 0.7).toList();
      case 'Calm':
        return filtered.where((s) => s.energy <= 0.45).toList();
      case 'Fast BPM (>120)':
        return filtered.where((s) => s.bpm >= 120).toList();
      case 'Rock / EDM':
        return filtered.where((s) {
          final g = s.genre.toLowerCase();
          return g.contains('rock') || g.contains('edm') || g.contains('electronic') || g.contains('metal');
        }).toList();
      case 'All':
      default:
        return filtered;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Search', style: AppTextStyles.titleLarge),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer2<MusicProvider, AudioPlayerService>(
        builder: (context, music, audioPlayer, _) {
          final results = _filterSongs(music.allSongs, _searchController.text);

          return Column(
            children: [
              // Search Input Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                      hintText: 'Search 267 songs, artists, genres...',
                      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
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
                height: 42,
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

              const SizedBox(height: 8),

              // Results Count Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Row(
                  children: [
                    Text(
                      '${results.length} Matches Found',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
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
                                  playlist: results,
                                  index: index,
                                );
                              },
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
