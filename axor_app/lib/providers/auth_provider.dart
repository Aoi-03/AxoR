import 'package:flutter/foundation.dart';
import '../services/google_drive_service.dart';

/// Authentication Provider
/// Manages Google Sign-In state throughout the app
class AuthProvider with ChangeNotifier {
  final GoogleDriveService _driveService = GoogleDriveService();

  bool _isLoading = false;
  bool _isSignedIn = false;
  String? _errorMessage;

  // ── Getters ──────────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get isSignedIn => _isSignedIn;
  String? get errorMessage => _errorMessage;
  String? get userName => _driveService.userName;
  String? get userEmail => _driveService.userEmail;
  String? get userPhotoUrl => _driveService.userPhotoUrl;
  String get displayName => userName ?? userEmail?.split('@').first ?? 'User';

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

  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _driveService.signOut();
      _isSignedIn = false;
    } catch (e) {
      if (kDebugMode) print('Sign-out error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
