import 'package:flutter/material.dart';

/// The visual system for Sweetspot.
///
/// Built on Apple's dark system greys so the app sits naturally on macOS.
/// The rule that governs everything here: the room plan is a technical
/// drawing, and colour in it carries acoustic meaning. Structure — walls,
/// speakers, the listening position — is drawn in neutrals and one blue.
/// Green, amber and red are reserved entirely for how good the placement is,
/// so a glance at the plan tells you whether you have a problem.
class AppTheme {
  AppTheme._();

  // ── Surfaces (Apple dark system greys) ─────────────────────────────────
  static const Color background = Color(0xFF1C1C1E); // systemGray6
  static const Color surface = Color(0xFF1C1C1E);
  static const Color surfaceVariant = Color(0xFF2C2C2E); // systemGray5
  static const Color primary = Color(0xFF2C2C2E);
  static const Color border = Color(0xFF38383A);
  static const Color borderSoft = Color(0xFF2C2C2E);

  /// The plan sits in a well, recessed below the chrome around it.
  static const Color canvasField = Color(0xFF131315);

  /// The room floor, lifted just enough to read as an object on the field.
  static const Color roomFloor = Color(0xFF1A1A1C);

  // ── Accent ─────────────────────────────────────────────────────────────
  /// systemBlue (dark). Interactive affordances only.
  static const Color accent = Color(0xFF0A84FF);
  static const Color highlight = accent; // kept for compatibility

  // ── Semantic ───────────────────────────────────────────────────────────
  static const Color success = Color(0xFF30D158); // systemGreen
  static const Color warning = Color(0xFFFF9F0A); // systemOrange
  static const Color error = Color(0xFFFF453A); // systemRed

  // ── Text ───────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93); // systemGray
  static const Color textTertiary = Color(0xFF636366); // systemGray2

  // ── Plan drawing ───────────────────────────────────────────────────────
  static const Color gridLine = Color(0xFF232325);
  static const Color gridLineMajor = Color(0xFF2E2E30);
  static const Color roomBorder = Color(0xFF48484A);

  /// A stereo pair is symmetric, so both speakers are drawn identically and
  /// told apart by their L/R label. Giving them separate hues implied a
  /// difference between them that does not exist.
  static const Color speaker = Color(0xFFE5E5EA);
  static const Color leftSpeaker = speaker; // compatibility
  static const Color rightSpeaker = speaker; // compatibility

  /// The listening position is the one thing you place, so it carries the
  /// interactive colour.
  static const Color listeningPos = accent;
  static const Color triangleLine = Color(0xFF5A5A5E);

  /// Reflections are information, not an alarm — muted, so amber stays
  /// available to mean "this placement has a problem".
  static const Color reflectionPoint = Color(0xFF7D8590);
  static const Color reflectionRay = Color(0xFF4A4A4E);

  static const Color blockerFill = Color(0xFF2A2A2C);
  static const Color blockerBorder = Color(0xFF3A3A3C);

  // ── Placement quality ──────────────────────────────────────────────────
  static const Color sweetSpotGreen = success;
  static const Color sweetSpotYellow = warning;
  static const Color sweetSpotRed = error;

  /// The single colour ramp that carries quality, used on the score, the
  /// sweet-spot marker and the quality bar so they always agree.
  static Color quality(double accuracy) {
    if (accuracy >= 0.85) return success;
    if (accuracy >= 0.65) return warning;
    return error;
  }

  // ── Motion ─────────────────────────────────────────────────────────────
  static const Duration motionFast = Duration(milliseconds: 180);
  static const Duration motionMedium = Duration(milliseconds: 320);
  static const Duration motionSlow = Duration(milliseconds: 520);

  /// Critically damped: it arrives and settles, it never overshoots.
  static const Curve easeStandard = Curves.easeOutCubic;
  static const Curve easeEmphasized = Curves.easeInOutCubic;

  // ── Metrics ────────────────────────────────────────────────────────────
  static const double radiusLarge = 12;
  static const double radiusMedium = 8;
  static const double radiusSmall = 6;

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      // Left unset so Flutter resolves the platform's own face — SF on macOS.
      // It already ships optical sizing and tracking tables.
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceVariant,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
        hintStyle: const TextStyle(color: textTertiary, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 9,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: surfaceVariant,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: surfaceVariant,
        thumbColor: Colors.white,
        overlayColor: accent.withValues(alpha: 0.16),
        trackHeight: 4,
        trackShape: const RoundedRectSliderTrackShape(),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 8,
          elevation: 2,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSoft,
        thickness: 1,
        space: 1,
      ),
      // Type scale: tracking tightens as size grows, which is how SF is drawn.
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          color: textPrimary,
          fontSize: 34,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.9,
          height: 1.05,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleSmall: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 14, letterSpacing: -0.1),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 13, letterSpacing: -0.05),
        bodySmall: TextStyle(color: textSecondary, fontSize: 11),
        labelLarge: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(color: textSecondary, fontSize: 11),
        labelSmall: TextStyle(color: textTertiary, fontSize: 10),
      ),
    );
  }
}
