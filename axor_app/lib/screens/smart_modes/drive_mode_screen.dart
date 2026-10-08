import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/drive_provider.dart';
import '../../providers/music_provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/download_service.dart';
import '../../services/google_drive_service.dart';
import '../../widgets/axor_image.dart';
import '../../widgets/song_queue_table.dart';
import '../../utils/mode_manager.dart';
import 'gym_mode_screen.dart';
import 'study_mode_screen.dart';

class DriveModeScreen extends StatefulWidget {
  const DriveModeScreen({super.key});

  @override
  State<DriveModeScreen> createState() => _DriveModeScreenState();
}

class _DriveModeScreenState extends State<DriveModeScreen> {
  Timer? _tripTimer;
  int _tripSeconds = 0;
  bool _isTripActive = false;

  @override
  void initState() {
    super.initState();
    modeManager.setMode(2);
  }

  @override
  void dispose() {
    _tripTimer?.cancel();
    super.dispose();
  }

  void _toggleTripTimer() {
    if (_isTripActive) {
      _tripTimer?.cancel();
      setState(() {
        _isTripActive = false;
      });
    } else {
      _tripTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _tripSeconds++;
          });
        }
      });
      setState(() {
        _isTripActive = true;
      });

      // Auto-start cruising road trip music if not already playing
      final audioPlayer = context.read<AudioPlayerService>();
      if (!audioPlayer.isPlaying) {
        final queue = _getDriveQueue();
        if (queue.isNotEmpty) {
          audioPlayer.playSong(queue.first, playlist: queue, index: 0);
        }
      }
    }
  }

  void _resetTrip() {
    _tripTimer?.cancel();
    setState(() {
      _isTripActive = false;
      _tripSeconds = 0;
    });
  }

  String get _formattedTripTime {
    final hours = _tripSeconds ~/ 3600;
    final minutes = (_tripSeconds % 3600) ~/ 60;
    final seconds = _tripSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  List<DriveAudioFile> _getDriveQueue() {
    final musicProvider = context.read<MusicProvider>();
    final downloadService = context.read<DownloadService>();
    final driveProvider = context.read<DriveProvider>();

    final List<DriveAudioFile> queue = [];
    final Set<String> seenIds = {};

    // 1. Medium energy cruising tracks (energy 0.5 - 0.8)
    final mediumEnergySongs = musicProvider.getMediumEnergySongs();
    for (final song in mediumEnergySongs) {
      if (seenIds.add(song.id)) queue.add(DriveAudioFile.fromSong(song));
    }

    // 2. Downloaded road trip songs
    for (final d in downloadService.downloadedSongs) {
      final e = d.energy ?? 0.65;
      if (e >= 0.45 && e <= 0.85) {
        if (seenIds.add(d.id)) queue.add(d);
      }
    }

    // 3. Drive audio files with cruising tempo
    for (final f in driveProvider.audioFiles) {
      final e = f.energy ?? 0.65;
      if (e >= 0.45 && e <= 0.85) {
        if (seenIds.add(f.id)) queue.add(f);
      }
    }

    // Fallback: If empty, use any available songs
    if (queue.isEmpty) {
      for (final song in musicProvider.allSongs) {
        if (seenIds.add(song.id)) queue.add(DriveAudioFile.fromSong(song));
      }
      for (final f in driveProvider.audioFiles) {
        if (seenIds.add(f.id)) queue.add(f);
      }
    }

    return queue;
  }

  Widget _buildModeToggle(IconData icon, Color color, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? color.withAlpha(50) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Icon(icon, color: isActive ? color : AppColors.lightGray, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driveQueue = _getDriveQueue();
    final audioPlayer = context.watch<AudioPlayerService>();
    final currentSong = audioPlayer.currentSong;
    final isPlaying = audioPlayer.isPlaying;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'DRIVE MODE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.green,
            letterSpacing: 2,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.green.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.green.withAlpha(60), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeToggle(Icons.fitness_center_rounded, AppColors.red, false, () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const GymModeScreen()),
                  );
                }),
                _buildModeToggle(Icons.menu_book_rounded, AppColors.cyan, false, () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const StudyModeScreen()),
                  );
                }),
                _buildModeToggle(Icons.directions_car_rounded, AppColors.green, true, () {}),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Drive Safety Bar & Trip Stopwatch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.green.withAlpha(70)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.speed_rounded, color: AppColors.green, size: 20),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TRIP DURATION',
                        style: TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      Text(
                        _formattedTripTime,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _toggleTripTimer,
                    icon: Icon(_isTripActive ? Icons.pause_rounded : Icons.play_arrow_rounded, color: AppColors.green, size: 18),
                    label: Text(
                      _isTripActive ? 'PAUSE' : 'START TRIP',
                      style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.green.withAlpha(25),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  if (_tripSeconds > 0)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.textTertiary, size: 18),
                      onPressed: _resetTrip,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Giant Now-Playing Card for Drivers
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.green.withAlpha(90), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.green.withAlpha(30),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Album Art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AxorImage(
                      imageUrl: currentSong?.coverArtUrl ?? currentSong?.thumbnailLink,
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title (Extra Large for Road Visibility)
                  Text(
                    currentSong?.displayTitle ?? 'Tap a song or start trip',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Artist
                  Text(
                    currentSong?.displayArtist ?? 'Cruising Audio',
                    style: const TextStyle(
                      color: AppColors.lightGray,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),

                  // Giant Touch Controls (Extra Large for Drivers)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Previous Button (Large)
                      InkWell(
                        onTap: () => audioPlayer.playPrevious(),
                        borderRadius: BorderRadius.circular(36),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.green.withAlpha(25),
                            border: Border.all(color: AppColors.green.withAlpha(60), width: 1.5),
                          ),
                          child: const Icon(Icons.skip_previous_rounded, color: AppColors.green, size: 36),
                        ),
                      ),

                      // Play / Pause Button (Extra Large)
                      InkWell(
                        onTap: () {
                          if (currentSong == null && driveQueue.isNotEmpty) {
                            audioPlayer.playSong(driveQueue.first, playlist: driveQueue, index: 0);
                          } else {
                            audioPlayer.togglePlayPause();
                          }
                        },
                        borderRadius: BorderRadius.circular(44),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.greenGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.green.withAlpha(80),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 48,
                          ),
                        ),
                      ),

                      // Next Button (Large)
                      InkWell(
                        onTap: () => audioPlayer.playNext(),
                        borderRadius: BorderRadius.circular(36),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.green.withAlpha(25),
                            border: Border.all(color: AppColors.green.withAlpha(60), width: 1.5),
                          ),
                          child: const Icon(Icons.skip_next_rounded, color: AppColors.green, size: 36),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Cruising Queue Table
            SongQueueTable(
              songs: driveQueue,
              accentColor: AppColors.green,
              title: '> Road Trip Cruising Queue',
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
