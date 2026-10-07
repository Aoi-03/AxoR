import 'package:flutter/services.dart';

/// Callback typedef for island media control events
typedef IslandControlCallback = void Function(String action);

/// Dynamic Island Bridge Service
/// Manages the floating punch-hole capsule on Android
class DynamicIslandService {
  static const MethodChannel _channel =
      MethodChannel('com.example.axor_app/dynamic_island');

  static bool _enabled = true;
  static bool get isEnabled => _enabled;
  static void setEnabled(bool val) {
    _enabled = val;
    if (!val) {
      hide();
    }
  }

  static bool _syncLockscreenWallpaper = false;
  static bool get syncLockscreenWallpaper => _syncLockscreenWallpaper;
  static void setSyncLockscreenWallpaper(bool val) {
    _syncLockscreenWallpaper = val;
  }

  static IslandControlCallback? onControl;

  static void initialize(IslandControlCallback controlHandler) {
    onControl = controlHandler;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onControlAction') {
        final action = call.arguments as String?;
        if (action != null && onControl != null) {
          onControl!(action);
        }
      }
    });
  }

  /// Check if media service is supported (Native MediaSession needs no special overlay permissions)
  static Future<bool> hasPermission() async {
    return true;
  }

  /// Request permission (noop since native MediaStyle is built-in)
  static Future<bool> requestPermission() async {
    return true;
  }

  /// Show or update the Dynamic Island capsule
  static Future<void> show({
    required String title,
    required String artist,
    bool isPlaying = true,
    String? coverUrl,
    int? positionMs,
    int? durationMs,
  }) async {
    if (!_enabled) return;
    try {
      await _channel.invokeMethod('showIsland', {
        'title': title,
        'artist': artist,
        'isPlaying': isPlaying,
        if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
        if (positionMs != null) 'positionMs': positionMs,
        if (durationMs != null) 'durationMs': durationMs,
      });

      if (_syncLockscreenWallpaper && coverUrl != null && coverUrl.isNotEmpty) {
        setLockscreenWallpaper(coverUrl);
      }
    } catch (_) {}
  }

  /// Update playback state in the island
  static Future<void> update({
    String? title,
    String? artist,
    required bool isPlaying,
    String? coverUrl,
    int? positionMs,
    int? durationMs,
  }) async {
    if (!_enabled) return;
    try {
      await _channel.invokeMethod('updateIsland', {
        if (title != null) 'title': title,
        if (artist != null) 'artist': artist,
        'isPlaying': isPlaying,
        if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
        if (positionMs != null) 'positionMs': positionMs,
        if (durationMs != null) 'durationMs': durationMs,
      });

      if (_syncLockscreenWallpaper && coverUrl != null && coverUrl.isNotEmpty) {
        setLockscreenWallpaper(coverUrl);
      }
    } catch (_) {}
  }

  /// Set the device lockscreen wallpaper to the song cover
  static Future<bool> setLockscreenWallpaper(String coverUrl) async {
    try {
      final res = await _channel.invokeMethod<bool>('setLockscreenWallpaper', {
        'coverUrl': coverUrl,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Hide the Dynamic Island capsule
  static Future<void> hide() async {
    try {
      await _channel.invokeMethod('hideIsland');
    } catch (_) {}
  }
}
