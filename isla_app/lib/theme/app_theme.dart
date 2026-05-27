import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class AppTheme {
  static const Color primaryColor = IslaColors.primaryFixed;
  static const Color primaryLight = IslaColors.primary;
  static const Color primaryDark = IslaColors.primaryDim;

  static const Color darkBackground = IslaColors.background;
  static const Color darkCard = IslaColors.surfaceContainer;
  static const Color darkSurface = IslaColors.surfaceContainerHigh;
  static const Color darkText = IslaColors.onSurface;
  static const Color darkTextSecondary = IslaColors.onSurfaceVariant;

  static const Color lightBackground = Color(0xFFF4FBFE);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFEAF2F6);
  static const Color lightText = Color(0xFF0F1A1F);
  static const Color lightTextSecondary = Color(0xFF596770);

  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFFB561);
  static const Color error = IslaColors.error;
  static const Color info = IslaColors.tertiary;

  static const Color libraryBackgroundBase = IslaColors.background;
  static const Color libraryBackgroundTop = IslaColors.surfaceDim;
  static const Color libraryBackgroundBottom = IslaColors.background;
  static const Color libraryDivider = Color(0xFF242A2E);

  static const BoxDecoration libraryBackgroundDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [libraryBackgroundTop, libraryBackgroundBottom],
    ),
  );

  static BoxDecoration getBackgroundDecoration(bool isDark) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [libraryBackgroundTop, libraryBackgroundBottom]
            : const [Color(0xFFF9FCFE), Color(0xFFEEF6FA)],
      ),
    );
  }

  static BoxDecoration getCardDecoration(
    bool isDark, {
    Color? accent,
    double accentAlpha = 0,
    double borderAlpha = 0.18,
    bool elevated = true,
  }) {
    final base = getCardColor(isDark);
    final topColor = accent != null && accentAlpha > 0
        ? Color.alphaBlend(accent.withValues(alpha: accentAlpha), base)
        : base;

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          topColor,
          base.withValues(alpha: (base.a + 0.02).clamp(0.0, 1.0)),
        ],
      ),
      borderRadius: borderRadiusLarge,
      border: Border.all(
        color:
            (accent ?? getSurfaceColor(isDark)).withValues(alpha: borderAlpha),
      ),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                blurRadius: isDark ? 18 : 12,
                offset: const Offset(0, 6),
              ),
            ]
          : const [],
    );
  }

  static const List<Color> subjectColors = [
    Color(0xFF00E3FD),
    Color(0xFF6BB9FF),
    Color(0xFF4DD7C8),
    Color(0xFFFFB561),
    Color(0xFFFF8A80),
    Color(0xFF8EE59E),
  ];

  // Brand accents / helpers
  static Color get primaryAccent => primaryLight;

  static LinearGradient getPrimaryGradient(bool isDark) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryLight, primaryColor],
      );

  static Color getGlowColor(bool isDark) =>
      isDark ? const Color(0xFF00E3FD) : const Color(0xFF00A8D8);

  static Color getAppBarBg(bool isDark) =>
      isDark ? const Color(0xEE030D1B) : const Color(0xF8FFFFFF);


  static const Color backgroundColor = darkBackground;
  static const Color surfaceColor = darkSurface;
  static const Color textPrimary = darkText;
  static const Color textSecondary = darkTextSecondary;
  static const Color textLight = Color(0xFF8E9499);

  static Color getBackgroundColor(bool isDark) =>
      isDark ? darkBackground : lightBackground;
  static Color getCardColor(bool isDark) =>
      isDark ? darkCard.withValues(alpha: 0.88) : lightCard;
  static Color getSurfaceColor(bool isDark) =>
      isDark ? darkSurface.withValues(alpha: 0.72) : lightSurface;
  static Color getTextPrimary(bool isDark) => isDark ? darkText : lightText;
  static Color getTextSecondary(bool isDark) =>
      isDark ? darkTextSecondary : lightTextSecondary;
  static Color getTextLight(bool isDark) =>
      isDark ? const Color(0xFF808080) : const Color(0xFF9CA3AF);

  static TextStyle get headingLarge => GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w800,
      );

  static TextStyle get headingMedium => GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get headingSmall => GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];

  static BorderRadius get borderRadiusSmall => BorderRadius.circular(8);
  static BorderRadius get borderRadiusMedium => BorderRadius.circular(12);
  static BorderRadius get borderRadiusLarge => BorderRadius.circular(18);
  static BorderRadius get borderRadiusXLarge => BorderRadius.circular(24);
}
