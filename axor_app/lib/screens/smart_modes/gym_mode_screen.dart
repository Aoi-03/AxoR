import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/drive_provider.dart';
import '../../providers/music_provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/download_service.dart';
import '../../services/google_drive_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/song_queue_table.dart';
import '../../utils/mode_manager.dart';
import 'study_mode_screen.dart';
import 'drive_mode_screen.dart';

class GymModeScreen extends StatefulWidget {
  const GymModeScreen({super.key});

  @override
  State<GymModeScreen> createState() => _GymModeScreenState();
}

class _GymModeScreenState extends State<GymModeScreen> {
  Timer? _stopwatchTimer;
  int _secondsElapsed = 0;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    modeManager.setMode(0);
  }

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  void _toggleStopwatch() {
    if (_isRunning) {
      _stopwatchTimer?.cancel();
      setState(() {
        _isRunning = false;
      });
    } else {
      _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _secondsElapsed++;
          });
        }
      });
      setState(() {
        _isRunning = true;
      });

      // Auto-start high energy music if nothing is playing
      final audioPlayer = context.read<AudioPlayerService>();
      if (!audioPlayer.isPlaying) {
        final queue = _getGymQueue();
        if (queue.isNotEmpty) {
          audioPlayer.playSong(queue.first, playlist: queue, index: 0);
        }
      }
    }
  }

  void _resetStopwatch() {
    _stopwatchTimer?.cancel();
    setState(() {
      _isRunning = false;
      _secondsElapsed = 0;
    });
  }

  String get _formattedTime {
    final hours = _secondsElapsed ~/ 3600;
    final minutes = (_secondsElapsed % 3600) ~/ 60;
    final seconds = _secondsElapsed % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  List<DriveAudioFile> _getGymQueue() {
    final musicProvider = context.read<MusicProvider>();
    final downloadService = context.read<DownloadService>();
    final driveProvider = context.read<DriveProvider>();

    final List<DriveAudioFile> queue = [];
    final Set<String> seenIds = {};

    // 1. High energy local/downloaded tracks (BPM >= 120 or energy >= 0.6)
    final highEnergySongs = musicProvider.getHighEnergySongs();
    for (final song in highEnergySongs) {
      if (seenIds.add(song.id)) queue.add(DriveAudioFile.fromSong(song));
    }

    // 2. High energy downloaded songs
    for (final d in downloadService.downloadedSongs) {
      if ((d.energy ?? 0.8) >= 0.6 && (d.bpm ?? 125) >= 115) {
        if (seenIds.add(d.id)) queue.add(d);
      }
    }

    // 3. Drive audio files with high tempo/energy
    for (final f in driveProvider.audioFiles) {
      if ((f.energy ?? 0.8) >= 0.6) {
        if (seenIds.add(f.id)) queue.add(f);
      }
    }

    // Fallback: If empty, use any available local or drive songs
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
    final gymQueue = _getGymQueue();

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
          'GYM WORKOUT MODE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.red,
            letterSpacing: 2,
          ),
        ),
        actions: [
          // Mode Switcher in AppBar
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.red.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.red.withAlpha(60), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeToggle(Icons.fitness_center_rounded, AppColors.red, true, () {}),
                _buildModeToggle(Icons.menu_book_rounded, AppColors.cyan, false, () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const StudyModeScreen()),
                  );
                }),
                _buildModeToggle(Icons.directions_car_rounded, AppColors.green, false, () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const DriveModeScreen()),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // Workout Intensity Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.red.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.red.withAlpha(120), width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.red, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'HIGH BPM & ENERGY AUDIO ENGINE',
                    style: TextStyle(color: AppColors.red, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Stopwatch Circle
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isRunning ? AppColors.red : AppColors.red.withAlpha(80),
                  width: 5,
                ),
                boxShadow: _isRunning
                    ? [
                        BoxShadow(
                          color: AppColors.red.withAlpha(70),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formattedTime,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isRunning ? 'WORKOUT IN PROGRESS' : 'STOPWATCH READY',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isRunning ? AppColors.red : AppColors.lightGray,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Stopwatch Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: CustomButton(
                    text: _isRunning ? 'PAUSE WORKOUT' : 'START WORKOUT',
                    onPressed: _toggleStopwatch,
                    gradient: AppColors.redGradient,
                  ),
                ),
                if (_secondsElapsed > 0) ...[
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.lightGray, size: 26),
                    tooltip: 'Reset Stopwatch',
                    onPressed: _resetStopwatch,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 36),

            // High Energy Queue Table
            SongQueueTable(
              songs: gymQueue,
              accentColor: AppColors.red,
              title: '> High Energy Workout Queue',
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
