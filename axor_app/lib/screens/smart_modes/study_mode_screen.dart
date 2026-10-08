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
import 'gym_mode_screen.dart';
import 'drive_mode_screen.dart';

class StudyModeScreen extends StatefulWidget {
  const StudyModeScreen({super.key});

  @override
  State<StudyModeScreen> createState() => _StudyModeScreenState();
}

class _StudyModeScreenState extends State<StudyModeScreen> {
  Timer? _pomodoroTimer;
  int _secondsRemaining = 25 * 60; // 25-minute Pomodoro focus session
  bool _isRunning = false;
  bool _isBreak = false; // Focus vs Break

  @override
  void initState() {
    super.initState();
    modeManager.setMode(1);
  }

  @override
  void dispose() {
    _pomodoroTimer?.cancel();
    super.dispose();
  }

  void _togglePomodoro() {
    if (_isRunning) {
      _pomodoroTimer?.cancel();
      setState(() {
        _isRunning = false;
      });
    } else {
      _pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          if (_secondsRemaining > 0) {
            setState(() {
              _secondsRemaining--;
            });
          } else {
            // Timer finished
            _pomodoroTimer?.cancel();
            setState(() {
              _isRunning = false;
              _isBreak = !_isBreak;
              _secondsRemaining = _isBreak ? 5 * 60 : 25 * 60;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isBreak ? '🎉 Focus session complete! Take a 5-min break.' : '⏰ Break is over! Ready to focus.'),
                backgroundColor: AppColors.cyan,
              ),
            );
          }
        }
      });
      setState(() {
        _isRunning = true;
      });

      // Auto-start calm focus music if not playing
      final audioPlayer = context.read<AudioPlayerService>();
      if (!audioPlayer.isPlaying) {
        final queue = _getStudyQueue();
        if (queue.isNotEmpty) {
          audioPlayer.playSong(queue.first, playlist: queue, index: 0);
        }
      }
    }
  }

  void _resetPomodoro({bool isBreak = false}) {
    _pomodoroTimer?.cancel();
    setState(() {
      _isRunning = false;
      _isBreak = isBreak;
      _secondsRemaining = isBreak ? 5 * 60 : 25 * 60;
    });
  }

  String get _formattedTime {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  List<DriveAudioFile> _getStudyQueue() {
    final musicProvider = context.read<MusicProvider>();
    final downloadService = context.read<DownloadService>();
    final driveProvider = context.read<DriveProvider>();

    final List<DriveAudioFile> queue = [];
    final Set<String> seenIds = {};

    // 1. Low energy calm songs (energy <= 0.5, bpm <= 110)
    final lowEnergySongs = musicProvider.getLowEnergySongs();
    for (final song in lowEnergySongs) {
      if (seenIds.add(song.id)) queue.add(DriveAudioFile.fromSong(song));
    }

    // 2. Downloaded lo-fi / calm songs
    for (final d in downloadService.downloadedSongs) {
      if ((d.energy ?? 0.4) <= 0.6) {
        if (seenIds.add(d.id)) queue.add(d);
      }
    }

    // 3. Drive audio files with calm mood or title containing lofi, chill, study, piano
    for (final f in driveProvider.audioFiles) {
      final name = f.displayTitle.toLowerCase();
      if ((f.energy ?? 0.4) <= 0.5 || name.contains('lofi') || name.contains('chill') || name.contains('piano') || name.contains('ambient')) {
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
    final studyQueue = _getStudyQueue();
    final progress = 1.0 - (_secondsRemaining / (_isBreak ? 5 * 60 : 25 * 60));

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
          'STUDY & FOCUS MODE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.cyan,
            letterSpacing: 2,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.cyan.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cyan.withAlpha(60), width: 1),
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
                _buildModeToggle(Icons.menu_book_rounded, AppColors.cyan, true, () {}),
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

            // Pomodoro Mode Selector Chips
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('25 MIN FOCUS'),
                  selected: !_isBreak,
                  selectedColor: AppColors.cyan,
                  backgroundColor: AppColors.surfaceElevated,
                  labelStyle: TextStyle(
                    color: !_isBreak ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) _resetPomodoro(isBreak: false);
                  },
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('5 MIN BREAK'),
                  selected: _isBreak,
                  selectedColor: AppColors.cyan,
                  backgroundColor: AppColors.surfaceElevated,
                  labelStyle: TextStyle(
                    color: _isBreak ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) _resetPomodoro(isBreak: true);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Circular Focus Timer
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 5,
                    color: AppColors.cyan,
                    backgroundColor: AppColors.cyan.withAlpha(40),
                  ),
                ),
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: _isRunning
                        ? [
                            BoxShadow(
                              color: AppColors.cyan.withAlpha(50),
                              blurRadius: 25,
                              spreadRadius: 1,
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
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isBreak
                              ? 'SHORT REST BREAK'
                              : (_isRunning ? 'DEEP FOCUS SESSION' : 'READY TO FOCUS'),
                          style: TextStyle(
                            fontSize: 11,
                            color: _isRunning ? AppColors.cyan : AppColors.lightGray,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Timer Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: CustomButton(
                    text: _isRunning ? 'PAUSE FOCUS' : 'START FOCUS',
                    onPressed: _togglePomodoro,
                    gradient: AppColors.cyanGradient,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.lightGray, size: 26),
                  tooltip: 'Reset Pomodoro',
                  onPressed: () => _resetPomodoro(isBreak: _isBreak),
                ),
              ],
            ),
            const SizedBox(height: 36),

            // Calm / Focus Music Queue
            SongQueueTable(
              songs: studyQueue,
              accentColor: AppColors.cyan,
              title: '> Calm & Ambient Focus Queue',
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
