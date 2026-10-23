import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/google_drive_service.dart';
import '../services/audio_player_service.dart';
import '../services/lyrics_service.dart';

/// Performance & Battery Optimized Lyrics Bottom Sheet
///
/// Features:
/// - Fetches lyrics on-demand ONLY when user opens this sheet
/// - Strictly unmounts and cleans up stream subscriptions on dismiss
/// - Uses smooth auto-scrolling with zero battery overhead when closed
class LyricsSheet extends StatefulWidget {
  final DriveAudioFile song;
  final AudioPlayerService audioPlayer;

  const LyricsSheet({
    super.key,
    required this.song,
    required this.audioPlayer,
  });

  static void show(
    BuildContext context, {
    required DriveAudioFile song,
    required AudioPlayerService audioPlayer,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LyricsSheet(
        song: song,
        audioPlayer: audioPlayer,
      ),
    );
  }

  @override
  State<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> {
  final LyricsService _lyricsService = LyricsService();
  final ScrollController _scrollController = ScrollController();

  LyricsData? _lyricsData;
  bool _isLoading = true;
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  Future<void> _loadLyrics() async {
    final data = await _lyricsService.getLyrics(
      songId: widget.song.id,
      lyricsUrl: widget.song.lyricsUrl,
      localFilePath: widget.song.customStreamUrl,
      title: widget.song.displayTitle,
      artist: widget.song.displayArtist,
    );

    if (mounted) {
      setState(() {
        _lyricsData = data;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _findActiveIndex(Duration currentPosition, List<LyricLine> lines) {
    if (lines.isEmpty) return -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (currentPosition >= lines[i].timestamp) {
        return i;
      }
    }
    return 0;
  }

  void _scrollToActive(int index) {
    if (index == _lastActiveIndex || !_scrollController.hasClients) return;
    _lastActiveIndex = index;

    final targetOffset = (index * 48.0) - 120.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.70;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F14).withAlpha(245),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.song.displayTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.song.displayArtist,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  )
                : (_lyricsData == null || _lyricsData!.lines.isEmpty)
                    ? const Center(
                        child: Text(
                          'No synchronized lyrics available',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : StreamBuilder<Duration>(
                        stream: widget.audioPlayer.positionStream,
                        builder: (context, snapshot) {
                          final currentPos = snapshot.data ?? widget.audioPlayer.position;
                          final activeIdx = _lyricsData!.isSynced
                              ? _findActiveIndex(currentPos, _lyricsData!.lines)
                              : -1;

                          if (activeIdx != -1) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _scrollToActive(activeIdx);
                            });
                          }

                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 32,
                            ),
                            itemCount: _lyricsData!.lines.length,
                            itemBuilder: (context, i) {
                              final line = _lyricsData!.lines[i];
                              final isActive = i == activeIdx;

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                  line.text,
                                  style: TextStyle(
                                    color: isActive
                                        ? AppColors.primary
                                        : Colors.white.withAlpha(isActive ? 255 : 90),
                                    fontSize: isActive ? 20 : 16,
                                    fontWeight: isActive
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    shadows: isActive
                                        ? [
                                            Shadow(
                                              color: AppColors.primary.withAlpha(120),
                                              blurRadius: 16,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

