import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary Colors
  static const Color primaryColor = Color(0xFF00ADB5); // Cyan
  static const Color primaryLight = Color(0xFF2DC4CC);
  static const Color primaryDark = Color(0xFF008B92);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF1C1F26);
  static const Color darkCard = Color(0xFF2C3440);
  static const Color darkSurface = Color(0xFF3A4149);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB8B8B8);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFE8ECEF);
  static const Color lightText = Color(0xFF2C3440);
  static const Color lightTextSecondary = Color(0xFF6B7280);

  // Accent Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFFFB020);
  static const Color error = Color(0xFFFF6B6B);
  static const Color info = Color(0xFF00ADB5);

  // Subject Colors
  static const List<Color> subjectColors = [
    Color(0xFF00ADB5), // Cyan
    Color(0xFF10B981), // Green
    Color(0xFFFFB020), // Orange
    Color(0xFFFF6B6B), // Red
    Color(0xFF8B5CF6), // Purple
    Color(0xFF3B82F6), // Blue
  ];

  // Legacy static properties (default to dark theme)
  static const Color backgroundColor = darkBackground;
  static const Color surfaceColor = darkSurface;
  static const Color textPrimary = darkText;
  static const Color textSecondary = darkTextSecondary;
  static const Color textLight = Color(0xFF808080);

  // Dynamic color methods based on theme
  static Color getBackgroundColor(bool isDark) => isDark ? darkBackground : lightBackground;
  static Color getCardColor(bool isDark) => isDark ? darkCard : lightCard;
  static Color getSurfaceColor(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color getTextPrimary(bool isDark) => isDark ? darkText : lightText;
  static Color getTextSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color getTextLight(bool isDark) => isDark ? const Color(0xFF808080) : const Color(0xFF9CA3AF);

  // Text Styles
  static TextStyle get headingLarge => GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static TextStyle get headingMedium => GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle get headingSmall => GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle get bodyLarge => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static TextStyle get bodyMedium => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static TextStyle get bodySmall => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  static TextStyle get labelMedium => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  // Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  // Border Radius
  static BorderRadius get borderRadiusSmall => BorderRadius.circular(8);
  static BorderRadius get borderRadiusMedium => BorderRadius.circular(12);
  static BorderRadius get borderRadiusLarge => BorderRadius.circular(16);
  static BorderRadius get borderRadiusXLarge => BorderRadius.circular(24);
}
