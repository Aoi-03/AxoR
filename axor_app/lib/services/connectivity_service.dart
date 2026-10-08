import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// ConnectivityService — Lightweight offline/online network detector
///
/// Features:
/// - Fast network probe via DNS lookup without heavy external dependencies
/// - Emits online/offline changes to reactive listeners
/// - Used by Offline Fallback, Dynamic Island, and Alternating Library Statistics
class ConnectivityService with ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  ConnectivityService._internal() {
    _startMonitoring();
  }

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _probeTimer;

  void _startMonitoring() {
    checkConnection();
    // Periodic probe every 5 seconds to detect online/offline toggles
    _probeTimer = Timer.periodic(const Duration(seconds: 5), (_) => checkConnection());
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
    _probeTimer?.cancel();
    super.dispose();
  }
}
