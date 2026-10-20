import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// ConnectivityService — Lightweight offline/online network detector
///
/// Features:
/// - Fast network probe via DNS lookup without heavy external dependencies
/// - Emits online/offline changes to reactive listeners
/// - Automatically pauses probing in the background to let cellular/Wi-Fi modem sleep
/// - Used by Offline Fallback, Dynamic Island, and Alternating Library Statistics
class ConnectivityService with ChangeNotifier, WidgetsBindingObserver {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  ConnectivityService._internal() {
    WidgetsBinding.instance.addObserver(this);
    _startMonitoring();
  }

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _probeTimer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Pause active network probing in background to save battery and let cellular radio sleep
      _probeTimer?.cancel();
      _probeTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      // Resume probing when user returns to foreground
      checkConnection();
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    _probeTimer?.cancel();
    checkConnection();
    // 45s interval to allow LTE/5G baseband to drop to low-power idle states
    _probeTimer = Timer.periodic(const Duration(seconds: 45), (_) => checkConnection());
  }

  /// Fast non-blocking internet probe
  Future<bool> checkConnection() async {
    try {
      final result = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 2));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (_isOnline != online) {
        _isOnline = online;
        notifyListeners();
        if (kDebugMode) {
          print('🌐 Network Status: ${_isOnline ? "ONLINE" : "OFFLINE"}');
        }
      }
      return _isOnline;
    } catch (_) {
      if (_isOnline != false) {
        _isOnline = false;
        notifyListeners();
        if (kDebugMode) print('🌐 Network Status: OFFLINE');
      }
      return false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _probeTimer?.cancel();
    super.dispose();
  }
}
