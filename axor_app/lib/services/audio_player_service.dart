import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/google_drive_service.dart';
import '../services/dynamic_island_service.dart';
import '../services/download_service.dart';
import '../services/connectivity_service.dart';
import '../models/song.dart';

/// Audio Player Service — AXOR 2.0
/// Manages audio playback with just_audio and Google Drive streaming
class AudioPlayerService with ChangeNotifier {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;

  AudioPlayerService._internal() {
    _loadLikedSongs();
    _init();
  }

  final AudioPlayer _player = AudioPlayer();
  final GoogleDriveService _driveService = GoogleDriveService();

  DriveAudioFile? _currentSong;
  List<DriveAudioFile> _queue = [];
  int _currentIndex = 0;
  int _playMode = 0; // 0: repeat, 1: repeat one, 2: shuffle, 3: AI
  final Set<String> _likedSongIds = {};

  // ── Getters ──────────────────────────────────────────
  AudioPlayer get player => _player;
  DriveAudioFile? get currentSong => _currentSong;
  List<DriveAudioFile> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  int get playMode => _playMode;
  int get shuffleRepeatState => _playMode;
  bool get hasSong => _currentSong != null;
  bool get hasQueue => _queue.isNotEmpty;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  // ── Like State & Persistence ─────────────────────────
  bool isLiked(String id) => _likedSongIds.contains(id);
  bool get isCurrentSongLiked => _currentSong != null && isLiked(_currentSong!.id);

  Future<void> _loadLikedSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('axor_liked_song_ids') ?? [];
      _likedSongIds.clear();
      _likedSongIds.addAll(list);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveLikedSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('axor_liked_song_ids', _likedSongIds.toList());
    } catch (_) {}
  }

  /// Toggle like for current song and sync with Google Drive
  Future<bool> toggleLikeCurrentSong() async {
    if (_currentSong == null) return false;
    return toggleLikeSong(_currentSong!);
  }

  /// Toggle like for any song and sync with Google Drive
  Future<bool> toggleLikeSong(DriveAudioFile song) async {
    final currentlyLiked = isLiked(song.id);
    if (currentlyLiked) {
      _likedSongIds.remove(song.id);
      await _saveLikedSongs();
      notifyListeners();
      _driveService.removeSongFromDrive(song.id);
      if (_currentSong?.id == song.id) {
        DynamicIslandService.update(
          isPlaying: isPlaying,
          isLiked: false,
        );
      }
      return false;
    } else {
      _likedSongIds.add(song.id);
      await _saveLikedSongs();
      notifyListeners();
      _driveService.saveSongToDrive(song);
      if (_currentSong?.id == song.id) {
        DynamicIslandService.update(
          isPlaying: isPlaying,
          isLiked: true,
        );
      }
      return true;
    }
  }

  // ── Play Mode Labels ──────────────────────────────────
  String get playModeLabel {
    switch (_playMode) {
      case 0: return 'Repeat';
      case 1: return 'Repeat One';
      case 2: return 'Shuffle';
      case 3: return 'AI Flow';
      default: return 'Repeat';
    }
  }

  // ── Init ──────────────────────────────────────────────
  void _init() {
    DynamicIslandService.initialize((action) {
      if (action == 'previous') {
        playPrevious();
      } else if (action == 'playPause') {
        togglePlayPause();
      } else if (action == 'next') {
        playNext();
      } else if (action == 'toggleLike') {
        toggleLikeCurrentSong();
      }
    });

    _player.playerStateStream.listen((state) {
      notifyListeners();
      if (_currentSong != null) {
        DynamicIslandService.update(
          title: _currentSong!.displayTitle,
          artist: _currentSong!.displayArtist,
          isPlaying: state.playing,
          isLiked: isCurrentSongLiked,
          coverUrl: _currentSong!.coverArtUrl,
          positionMs: _player.position.inMilliseconds,
          durationMs: _player.duration?.inMilliseconds ??
              ((_currentSong!.durationSeconds ?? 0) * 1000),
        );
      }
      if (state.processingState == ProcessingState.completed) {
        _handleSongComplete();
      }
    });

    _player.positionStream.listen((pos) {
      notifyListeners();
    });
  }

  // ── Playback Controls ─────────────────────────────────

  /// Play a song from Drive or Local storage with offline fallback
  Future<void> playSong(
    DriveAudioFile song, {
    List<DriveAudioFile>? playlist,
    int? index,
  }) async {
    try {
      var activeSong = song;

      // ── Offline Fallback Check ──
      final isOnline = ConnectivityService().isOnline;
      final isRemoteDrive = activeSong.streamUrl.contains('googleapis.com');

      if (!isOnline && isRemoteDrive) {
        // Find if downloaded locally
        final downloadedMatch = DownloadService().downloadedSongs.where(
          (d) => d.id == song.id || d.displayTitle.toLowerCase() == song.displayTitle.toLowerCase(),
        ).firstOrNull;

        if (downloadedMatch != null) {
          activeSong = downloadedMatch;
          if (kDebugMode) print('🔄 Offline fallback: Playing downloaded copy for ${song.displayTitle}');
        } else if (DownloadService().downloadedSongs.isNotEmpty) {
          activeSong = DownloadService().downloadedSongs.first;
          if (kDebugMode) print('🔄 Offline fallback: Song not downloaded, playing local library: ${activeSong.displayTitle}');
        }
      }

      _currentSong = activeSong;
      if (playlist != null) {
        _queue = playlist;
        _currentIndex = index ?? 0;
      }

      if (kDebugMode) {
        print('🎵 Playing: ${activeSong.displayTitle} — ${activeSong.displayArtist}');
      }

      await _player.stop();

      // Check if local file path
      final isLocalFile = activeSong.customStreamUrl != null &&
          File(activeSong.customStreamUrl!).existsSync();

      if (isLocalFile) {
        // Zero-latency direct local file playback
        await _player.setAudioSource(
          AudioSource.file(activeSong.customStreamUrl!),
        );
      } else {
        // Get auth headers only if streaming from Google Drive
        final isDrive = activeSong.streamUrl.contains('googleapis.com');
        final headers = isDrive ? await _driveService.getAuthHeaders() : null;

        // Stream audio source
        await _player
            .setAudioSource(
              AudioSource.uri(
                Uri.parse(activeSong.streamUrl),
                headers: headers,
              ),
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw Exception('Stream timeout'),
            );
      }

      await _player.play();

      DynamicIslandService.show(
        title: activeSong.displayTitle,
        artist: activeSong.displayArtist,
        isPlaying: true,
        isLiked: isLiked(activeSong.id),
        coverUrl: activeSong.coverArtUrl,
        positionMs: 0,
        durationMs: (activeSong.durationSeconds ?? 0) * 1000,
      );

      if (kDebugMode) print('✅ Playback started');
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Error playing: $e');
      _currentSong = null;
      DynamicIslandService.hide();
      notifyListeners();
      rethrow;
    }
  }

  /// Play a Song model from the local backend
  Future<void> playAxorSong(
    Song song, {
    List<Song>? playlist,
    int? index,
  }) async {
    final driveSong = DriveAudioFile.fromSong(song);
    final drivePlaylist = playlist?.map((s) => DriveAudioFile.fromSong(s)).toList();
    await playSong(driveSong, playlist: drivePlaylist, index: index);
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
      DynamicIslandService.update(
        isPlaying: false,
        isLiked: isCurrentSongLiked,
        coverUrl: _currentSong?.coverArtUrl,
        positionMs: _player.position.inMilliseconds,
        durationMs: _player.duration?.inMilliseconds,
      );
    } else {
      await _player.play();
      if (_currentSong != null) {
        DynamicIslandService.show(
          title: _currentSong!.displayTitle,
          artist: _currentSong!.displayArtist,
          isPlaying: true,
          isLiked: isCurrentSongLiked,
          coverUrl: _currentSong!.coverArtUrl,
          positionMs: _player.position.inMilliseconds,
          durationMs: _player.duration?.inMilliseconds,
        );
      }
    }
    notifyListeners();
  }

  /// Play next
  Future<void> playNext() async {
    if (_queue.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _queue.length;
    await playSong(_queue[_currentIndex], playlist: _queue, index: _currentIndex);
  }

  /// Play previous
  Future<void> playPrevious() async {
    if (_queue.isEmpty) return;
    // If more than 3 seconds in, restart; otherwise go previous
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    await playSong(_queue[_currentIndex], playlist: _queue, index: _currentIndex);
  }

  /// Seek
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Stop
  Future<void> stop() async {
    await _player.stop();
    _currentSong = null;
    DynamicIslandService.hide();
    notifyListeners();
  }

  /// Set play mode
  void setPlayMode(int mode) {
    _playMode = mode;
    notifyListeners();
  }

  /// Alias for setPlayMode
  void setShuffleRepeatState(int state) => setPlayMode(state);

  /// Cycle play mode
  void cyclePlayMode() {
    _playMode = (_playMode + 1) % 4;
    notifyListeners();
  }

  // ── Private ───────────────────────────────────────────

  Future<void> _handleSongComplete() async {
    switch (_playMode) {
      case 0: // Repeat
        await playNext();
        break;
      case 1: // Repeat one
        await _player.seek(Duration.zero);
        await _player.play();
        break;
      case 2: // Shuffle
        await _playRandom();
        break;
      case 3: // AI (for now, just shuffle — future: similarity-based)
        await _playRandom();
        break;
    }
  }

  Future<void> _playRandom() async {
    if (_queue.isEmpty) return;
    final idx = DateTime.now().millisecondsSinceEpoch % _queue.length;
    _currentIndex = idx;
    await playSong(_queue[_currentIndex], playlist: _queue, index: _currentIndex);
  }

  // ── Utility ───────────────────────────────────────────

  /// Format duration
  static String formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
