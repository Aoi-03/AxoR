import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../models/song.dart';
import '../../services/api_service.dart';
import '../../services/playlist_storage_service.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final bool isVibe;
  final Map<String, dynamic>? vibeData;
  final String? playlistId;

  const PlaylistDetailScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.isVibe = false,
    this.vibeData,
    this.playlistId,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final Set<int> _likedSongs = {}; // Track liked songs by index
  final bool _isPremiumUser = true; // TODO: Get from backend
  List<Song> songs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => isLoading = true);
    
    if (widget.isVibe && widget.vibeData != null) {
      // Load songs from vibe data
      final vibeSongs = widget.vibeData!['songs'] as List<dynamic>?;
      if (vibeSongs != null) {
        setState(() {
          songs = vibeSongs.map((s) => Song.fromJson(s)).toList();
          isLoading = false;
        });
      }
    } else if (!widget.isVibe && widget.playlistId != null) {
      // Load songs from user playlist
      final playlist = await PlaylistStorageService.getPlaylist(widget.playlistId!);
      if (playlist != null) {
        // Fetch full song data from backend
        final allSongs = await ApiService.getAllSongs();
        setState(() {
          songs = allSongs.where((s) => playlist.songIds.contains(s.id)).toList();
          isLoading = false;
        });
      }
    } else {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
          : songs.isEmpty
              ? const Center(
                  child: Text(
                    'No songs in this playlist',
                    style: TextStyle(color: AppColors.lightGray),
                  ),
                )
              : ListView.builder(
                  itemCount: songs.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: AppColors.darkTeal,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.music_note,
                              size: 60,
                              color: AppColors.cyan,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.subtitle != null)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                widget.subtitle!,
                                style: const TextStyle(
                                  color: AppColors.lightGray,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              '${songs.length} songs',
                              style: const TextStyle(
                                color: AppColors.lightGray,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  // TODO: Backend - Play playlist
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Play will work with backend'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Play'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.cyan,
                                  foregroundColor: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: () {
                                  // TODO: Backend - Shuffle playlist
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Shuffle will work with backend'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.shuffle, color: AppColors.cyan),
                              ),
                              if (_isPremiumUser)
                                IconButton(
                                  onPressed: () {
                                    // TODO: Backend - Download entire playlist
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Download playlist will work with backend'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.download, color: AppColors.cyan),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: AppColors.darkGray),
                        ],
                      );
                    }
                    
                    final songIndex = index - 1;
                    final song = songs[songIndex];
                    final isLiked = _likedSongs.contains(songIndex);
                    
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.darkTeal,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: AppColors.cyan,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        song.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        song.artist,
                        style: const TextStyle(color: AppColors.lightGray),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isPremiumUser)
                            IconButton(
                              onPressed: () {
                                // TODO: Backend - Download to local cache
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Download will work with backend'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.download,
                                color: AppColors.lightGray,
                                size: 20,
                              ),
                            ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (isLiked) {
                                  _likedSongs.remove(songIndex);
                                } else {
                                  _likedSongs.add(songIndex);
                                }
                              });
                              // TODO: Backend - Like = Download/Save
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isLiked 
                                      ? 'Unlike will work with backend' 
                                      : 'Like = Download/Save (will work with backend)'
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            icon: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? AppColors.cyan : AppColors.lightGray,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        // TODO: Play this song
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Playing ${song.title}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
