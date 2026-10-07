import 'package:flutter/material.dart';

/// AXOR Design System — "Neon Abyss" Color Palette
/// Premium dark theme with cyan/purple accents and glassmorphism
class AppColors {
  AppColors._();

  // ── Surfaces ──────────────────────────────────────────
  static const Color surface = Color(0xFF0A0A0F);
  static const Color surfaceElevated = Color(0xFF12121A);
  static const Color surfaceCard = Color(0xFF1A1A24);
  static const Color surfaceBorder = Color(0xFF2A2A3A);

  // ── Primary (Cyan) ───────────────────────────────────
  static const Color primary = Color(0xFF00E5FF);
  static const Color primaryDark = Color(0xFF0097A7);
  static const Color primaryMuted = Color(0xFF004D5A);

  // ── Secondary (Purple) ────────────────────────────────
  static const Color secondary = Color(0xFF7C4DFF);
  static const Color secondaryDark = Color(0xFF5C3FBF);

  // ── Accent (Pink) ────────────────────────────────────
  static const Color accent = Color(0xFFFF4081);
  static const Color accentSoft = Color(0xFFFF80AB);

  // ── Text ──────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFF5A5A5E);
  static const Color textOnPrimary = Color(0xFF000000);

  // ── Semantic ──────────────────────────────────────────
  static const Color success = Color(0xFF00E676);
  static const Color error = Color(0xFFFF3D3D);
  static const Color warning = Color(0xFFFFAB00);

  // ── Smart Mode Accents ────────────────────────────────
  static const Color gymMode = Color(0xFFFF3D3D);
  static const Color studyMode = Color(0xFF00E5FF);
  static const Color driveMode = Color(0xFF00E676);

  // ── Legacy aliases (for gradual migration) ────────────
  static const Color black = surface;
  static const Color white = textPrimary;
  static const Color cyan = primary;
  static const Color darkTeal = surfaceCard;
  static const Color lightGray = textSecondary;
  static const Color darkGray = textTertiary;
  static const Color red = gymMode;
  static const Color green = driveMode;

  // ── Gradients ─────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF12121A), Color(0xFF0A0A0F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient gymGradient = LinearGradient(
    colors: [Color(0xFFFF3D3D), Color(0xFFFF6B3D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient studyGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF0088CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient driveGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00C853)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = primaryGradient;
  static const LinearGradient redGradient = gymGradient;
  static const LinearGradient greenGradient = driveGradient;
  static const LinearGradient tealCardGradient = surfaceGradient;

  // ── Glass Effect ──────────────────────────────────────
  static Color glassBackground = const Color(0xFF12121A).withAlpha(184);
  static Color glassBorder = const Color(0xFFFFFFFF).withAlpha(20);
  static Color glassHighlight = const Color(0xFFFFFFFF).withAlpha(8);
}
