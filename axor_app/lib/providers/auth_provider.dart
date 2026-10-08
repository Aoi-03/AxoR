import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/google_drive_service.dart';
import '../constants/colors.dart';

/// Authentication Provider
/// Manages Google Sign-In state and account tier (Standard, Free, PRO)
class AuthProvider with ChangeNotifier {
  final GoogleDriveService _driveService = GoogleDriveService();

  bool _isLoading = false;
  bool _isSignedIn = false;
  String? _errorMessage;
  String _accountTier = 'PRO';

  AuthProvider() {
    _loadAccountTier();
  }

  // ── Getters ──────────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get isSignedIn => _isSignedIn;
  String? get errorMessage => _errorMessage;
  String? get userName => _driveService.userName;
  String? get userEmail => _driveService.userEmail;
  String? get userPhotoUrl => _driveService.userPhotoUrl;
  String get displayName => userName ?? userEmail?.split('@').first ?? 'User';
  String get accountTier => _accountTier;

  Color get accountTierColor {
    switch (_accountTier) {
      case 'PRO':
        return AppColors.primary;
      case 'Standard':
        return AppColors.cyan;
      case 'Free':
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _loadAccountTier() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accountTier = prefs.getString('axor_account_tier') ?? (_isSignedIn ? 'PRO' : 'Free');
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setAccountTier(String tier) async {
    _accountTier = tier;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('axor_account_tier', tier);
    } catch (_) {}
  }

  void cycleAccountTier() {
    if (_accountTier == 'PRO') {
      setAccountTier('Standard');
    } else if (_accountTier == 'Standard') {
      setAccountTier('Free');
    } else {
      setAccountTier('PRO');
    }
  }

  /// Get greeting based on time of day
  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Late Night';
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Late Night';
  }

  /// Get time-appropriate emoji
  String get greetingEmoji {
    final hour = DateTime.now().hour;
    if (hour < 5) return '🌙';
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    if (hour < 21) return '🌅';
    return '🌙';
  }

  // ── Auth Actions ──────────────────────────────────────

  /// Try silent sign-in (for returning users)
  Future<bool> trySilentSignIn() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _isSignedIn = await _driveService.trySilentSignIn();
      if (_isSignedIn && _accountTier == 'Free') {
        _accountTier = 'PRO';
      }
      return _isSignedIn;
    } catch (e) {
      _errorMessage = 'Silent sign-in failed';
      if (kDebugMode) print('Silent sign-in error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Interactive sign-in
  Future<bool> signIn() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _isSignedIn = await _driveService.signIn();
      if (!_isSignedIn) {
        _errorMessage = 'Sign-in was cancelled';
      } else {
        await setAccountTier('PRO');
      }
      return _isSignedIn;
    } catch (e) {
      _errorMessage = 'Sign-in failed. Please try again.';
      if (kDebugMode) print('Sign-in error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign out completely
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _driveService.signOut();
      _isSignedIn = false;
      await setAccountTier('Free');
    } catch (e) {
      if (kDebugMode) print('Sign-out error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
